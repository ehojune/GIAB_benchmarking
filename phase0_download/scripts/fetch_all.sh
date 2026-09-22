#!/usr/bin/env bash
# 이 저장소가 받는 데이터 **전부**를 하나로 받는 진입점. 취득 경로가 네 군데로 갈라져 있어
# 어느 하나를 빼먹기 쉬웠다 — 그래서 순서와 검증을 여기 한 곳에 모은다.
#
# | 단계   | 무엇을                                   | 하위 스크립트                                        | 규모                |
# |--------|------------------------------------------|------------------------------------------------------|---------------------|
# | phase0 | GIAB FTP/S3 본체                         | phase0_download/scripts/run_priority.sh              | 81,302 files 113.8 TiB |
# | phase1 | HG001·HG005 SequelII 11kb (ENA)          | phase1_pacbio_hifi/scripts/02_fetch_sra_reads.sh     | 12 files 135 GiB    |
# | phase2 | HG001 rel6 + HG002 R10.4.1 (ONT 공개)    | phase2_ont/scripts/02_fetch_external_reads.sh        | 4 files 297 GiB     |
# | phase3 | 숏리드 업체 비교군 (Google GCS, HPRC S3) | phase3_shortread_wgs/scripts/02_fetch_external_reads.sh | 12 files 359 GiB |
#
#   bash phase0_download/scripts/fetch_all.sh                  전부 받는다 (이미 받은 파일은 건너뜀)
#   VERIFY_ONLY=1 bash phase0_download/scripts/fetch_all.sh    받지 않고 현재 상태만 점검
#   STAGES="phase1 phase2" bash phase0_download/scripts/fetch_all.sh   일부 단계만
#
# Env: GIAB_ROOT=/BiO/scratch/ehojune/GIAB_benchmark  저장 루트 (phase1~3이 쓰는 이름)
#      DEST=$GIAB_ROOT                                phase0이 쓰는 이름. 비우면 GIAB_ROOT를 따라간다
#      TOOL=s3  JOBS=8                                phase0에 전달
#      STAGES="phase0 phase1 phase2 phase3"           실행할 단계와 순서
#      PHASE0_VERIFY_CAT=all                          VERIFY_ONLY에서 phase0이 볼 범위.
#                                                     verify.sh는 파일당 stat 한 번이라 81,302개면 오래 걸린다 —
#                                                     스모크 테스트는 PHASE0_VERIFY_CAT=trio_analysis 처럼 좁혀서 돌린다
#
# 한 단계가 실패해도 다음 단계로 넘어간다 (네트워크·서버 사정으로 한 출처만 죽는 일이 흔하다).
# 마지막에 단계별 결과표를 찍고, 하나라도 실패했으면 종료코드 1.
#
# 주의: 계산 노드에는 외부 egress가 없다. 로그인 노드에서 돌릴 것.
#       phase1~3은 phase0과 달리 각 phase의 env.sh를 source 한다 — nbb2 밖에서는 경로가 없어 실패하는 게 정상이다.
#
# 여기 없는 것 (일부러 뺐다):
#  - 처리용 자산(레퍼런스 FASTA, TRF BED, Clair3 모델, 컨테이너 이미지)은 각 phase의
#    01_prepare_login_node.sh 담당이다. 받는 시점과 재실행 조건이 데이터와 달라 섞지 않는다.
#  - manifest 자체를 갱신하는 FTP 크롤(crawl_data.py, crawl_release.py)은 다운로드가 아니라 목록 재생성이다.
#  - md5 검증(md5_verify_all.sh)이 받는 current.tree, 속도 측정(speedtest.sh)이 받았다 지우는 표본 파일.
#  - 업체(gd001~004) 산출물은 우리가 받는 것이 아니라 서버에 이미 놓인 데이터다 (phase3 비교의 arm A).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE0_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PHASE0_DIR/.." && pwd)"

GIAB_ROOT="${GIAB_ROOT:-/BiO/scratch/ehojune/GIAB_benchmark}"
DEST="${DEST:-$GIAB_ROOT}"
export GIAB_ROOT DEST
export TOOL="${TOOL:-s3}"
export JOBS="${JOBS:-8}"
VERIFY_ONLY="${VERIFY_ONLY:-0}"
STAGES="${STAGES:-phase0 phase1 phase2 phase3}"

LOG_DIR="$REPO_ROOT/logs/fetch_all"
mkdir -p "$LOG_DIR"

if [ "$DEST" != "$GIAB_ROOT" ]; then
    echo "주의: DEST($DEST) != GIAB_ROOT($GIAB_ROOT). phase0과 phase1~3이 다른 트리에 받는다." >&2
fi

# 단계 정의: 키|사람이 읽을 이름|스크립트 상대경로
stage_script() {
    case "$1" in
        phase0) echo "phase0_download/scripts/run_priority.sh" ;;
        phase1) echo "phase1_pacbio_hifi/scripts/02_fetch_sra_reads.sh" ;;
        phase2) echo "phase2_ont/scripts/02_fetch_external_reads.sh" ;;
        phase3) echo "phase3_shortread_wgs/scripts/02_fetch_external_reads.sh" ;;
        *) return 1 ;;
    esac
}
stage_label() {
    case "$1" in
        phase0) echo "GIAB FTP/S3 본체" ;;
        phase1) echo "ENA PacBio SequelII 11kb" ;;
        phase2) echo "ONT 외부 (rel6 + R10.4.1)" ;;
        phase3) echo "숏리드 외부 (Google, HPRC)" ;;
    esac
}

declare -a DONE_KEYS=() DONE_STATE=() DONE_NOTE=()
record() { DONE_KEYS+=("$1"); DONE_STATE+=("$2"); DONE_NOTE+=("$3"); }

run_stage() {
    local key="$1" rel log rc
    rel="$(stage_script "$key")" || { record "$key" "SKIP" "알 수 없는 단계 이름"; return; }
    local abs="$REPO_ROOT/$rel"
    if [ ! -f "$abs" ]; then
        record "$key" "SKIP" "스크립트 없음: $rel"
        return
    fi
    log="$LOG_DIR/$key.log"
    echo "[$(date '+%F %T')] START $key — $(stage_label "$key")  (VERIFY_ONLY=$VERIFY_ONLY)"
    echo "    로그: $log"

    if [ "$key" = "phase0" ]; then
        # phase0만 검증 스크립트가 따로다. verify.sh all 은 샘플별 + release/rnaseq/trio_analysis 를 모두 집계한다.
        if [ "$VERIFY_ONLY" = "1" ]; then
            bash "$PHASE0_DIR/scripts/verify.sh" "${PHASE0_VERIFY_CAT:-all}" > "$log" 2>&1
            rc=$?
        else
            bash "$abs" > "$log" 2>&1
            rc=$?
        fi
    else
        # phase1~3은 같은 규약: VERIFY_ONLY=1 이면 받지 않고 점검만 한다.
        VERIFY_ONLY="$VERIFY_ONLY" bash "$abs" > "$log" 2>&1
        rc=$?
    fi

    local tail_line
    tail_line="$(tail -n 1 "$log" 2>/dev/null | cut -c1-90)"
    if [ "$rc" -eq 0 ]; then
        record "$key" "OK" "$tail_line"
    else
        record "$key" "FAIL(rc=$rc)" "$tail_line"
    fi
    echo "[$(date '+%F %T')] END   $key rc=$rc"
}

for s in $STAGES; do run_stage "$s"; done

# phase0은 verify.sh 합계 줄에서 진행률을 뽑아 따로 보여준다 (rc=0이어도 미완료일 수 있다).
p0_progress=""
if [ -f "$LOG_DIR/phase0.log" ]; then
    p0_progress="$(grep -E '^TOTAL' "$LOG_DIR/phase0.log" | tail -1 | cut -c1-100)"
fi

echo
echo "================ fetch_all 결과 ================"
printf "%-8s %-28s %-12s %s\n" "단계" "대상" "상태" "마지막 줄"
fail=0
for i in "${!DONE_KEYS[@]}"; do
    printf "%-8s %-28s %-12s %s\n" \
        "${DONE_KEYS[$i]}" "$(stage_label "${DONE_KEYS[$i]}")" "${DONE_STATE[$i]}" "${DONE_NOTE[$i]}"
    case "${DONE_STATE[$i]}" in FAIL*) fail=1 ;; esac
done
[ -n "$p0_progress" ] && { echo; echo "phase0 진행률: $p0_progress"; }
echo "로그: $LOG_DIR/"
echo "================================================"

# 검증 모드에서 phase0이 100%가 아니면 실패로 본다 — verify.sh 자체는 미완료여도 rc=0이라 여기서 판정한다.
if [ "$VERIFY_ONLY" = "1" ] && [ -n "$p0_progress" ] && ! printf '%s' "$p0_progress" | grep -q '(100.0%)'; then
    echo "phase0 미완료 — 위 진행률 참고" >&2
    fail=1
fi

exit "$fail"
