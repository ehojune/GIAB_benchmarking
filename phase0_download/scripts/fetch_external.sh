#!/usr/bin/env bash
# GIAB FTP 밖 URL 에서 받는 범용 fetcher (로그인 노드 — 계산 노드는 외부망이 없다).
# 대상·크기·URL·md5는 phase0_download/ext_manifest.tsv 가 전부 (phase3 ext_manifest 와 같은 스키마:
# dsid / relpath / bytes / url / md5 / kind / note). 현재 내용: HG008-T BioSkryb×UG100 단일세포 CRAM·VCF (giab-aws S3).
#
#   bash phase0_download/scripts/fetch_external.sh                 전부 받고 검증
#   VERIFY_ONLY=1 bash phase0_download/scripts/fetch_external.sh   받지 않고 상태만 점검
#   JOBS=6 DSID=HG008-T.Bioskryb_UG100_singlecell bash ...          동시 파일 수 / 실행 단위 지정
#   KIND=index bash ...                                             종류만 (reads/index/variants)
#
# wget -c 라서 중단 후 재실행하면 이어받는다. 판정: 크기 일치 필수, md5 는 매니페스트에 있는 행만(S3 단일 파트 ETag).
# 멀티파트 업로드(큰 CRAM·VCF)는 ETag 가 md5 가 아니라 '-' 로 두었다 — 크기로만 본다.
# md5 를 한 번 통과하면 <파일>.md5ok 를 남겨 다시 계산하지 않는다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIAB_ROOT="${GIAB_ROOT:-/BiO/scratch/ehojune/GIAB_benchmark}"
MAN="${MAN:-$HERE/../ext_manifest.tsv}"
JOBS="${JOBS:-4}"
LOG="${LOG:-$GIAB_ROOT/ext/phase0_ext_fetch.log}"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
echo "== $(date '+%F %T') GIAB_ROOT=$GIAB_ROOT VERIFY_ONLY=${VERIFY_ONLY:-0} DSID=${DSID:-all} KIND=${KIND:-all} JOBS=$JOBS"
[ -s "$MAN" ] || { echo "ERROR: 매니페스트 없음: $MAN"; exit 1; }

fetch_one() {   # relpath bytes url md5
    local relpath="$1" bytes="$2" url="$3" md5="$4" out have got dl_rc
    out="$GIAB_ROOT/$relpath"
    mkdir -p "$(dirname "$out")"
    have=-1; [ -f "$out" ] && have=$(stat -c%s "$out" 2>/dev/null || echo -1)
    if [ "$have" != "$bytes" ]; then
        if [ "${VERIFY_ONLY:-0}" = 1 ]; then printf 'MISS %s (have=%s want=%s)\n' "$relpath" "$have" "$bytes"; return 1; fi
        echo "GET  $relpath ($(awk -v b="$bytes" 'BEGIN{printf "%.2f", b/1073741824}') GiB)"
        if command -v wget >/dev/null; then
            wget -c -q -O "$out" "$url"; dl_rc=$?
        else
            curl -sS -L -C - -o "$out" "$url"; dl_rc=$?      # wget 없는 환경(개발 머신) 폴백. -C - 로 이어받기
            [ "$dl_rc" -eq 33 ] && dl_rc=0                    # 33 = 서버가 Range 를 거부했지만 파일은 이미 완성
        fi
        if [ "$dl_rc" -ne 0 ]; then echo "  ERROR: 다운로드 실패(rc=$dl_rc) — $url (재실행하면 이어받는다)"; return 1; fi
        have=$(stat -c%s "$out" 2>/dev/null || echo -1)
        if [ "$have" != "$bytes" ]; then echo "  ERROR: 크기 불일치 $relpath (have=$have want=$bytes)"; return 1; fi
    fi
    if [ "$md5" != "-" ] && [ -n "$md5" ] && [ ! -f "$out.md5ok" ]; then
        if [ "${VERIFY_ONLY:-0}" = 1 ]; then printf 'SIZE_OK_MD5_UNCHECKED %s\n' "$relpath"; return 0; fi
        got=$(md5sum "$out" | awk '{print $1}')
        if [ "$got" != "$md5" ]; then echo "  ERROR: md5 불일치 $relpath (got=$got want=$md5)"; return 1; fi
        printf '%s  %s\n' "$got" "$(basename "$out")" > "$out.md5ok"
    fi
    printf 'OK   %s\n' "$relpath"
}
export -f fetch_one
export GIAB_ROOT VERIFY_ONLY

# 헤더 제외, DSID/KIND 필터. 탭 구분 + 빈 칸 유지를 위해 awk 로 골라 4열만 넘긴다.
sel=$(mktemp)
awk -F'\t' -v d="${DSID:-}" -v k="${KIND:-}" 'NR>1 && (d=="" || $1==d) && (k=="" || $6==k) {print $2 "\t" $3 "\t" $4 "\t" $5}' "$MAN" > "$sel"
n=$(wc -l < "$sel")
[ "$n" -gt 0 ] || { echo "선택된 파일 없음 (DSID=${DSID:-all} KIND=${KIND:-all})"; rm -f "$sel"; exit 1; }
echo "대상 $n files, $(awk -F'\t' '{s+=$2} END{printf "%.2f TiB", s/1099511627776}' "$sel")"

res=$(mktemp)
tr '\t' '\n' < "$sel" | xargs -d '\n' -n4 -P "$JOBS" bash -c 'fetch_one "$1" "$2" "$3" "$4" || echo "FAILMARK $1"' _ > "$res" 2>&1
grep -v '^FAILMARK' "$res"
fails=$(grep -c '^FAILMARK' "$res" || true)
rm -f "$sel" "$res"
echo "== $(date '+%F %T') 끝: 실패 $fails / $n"
[ "$fails" -eq 0 ] || { echo "일부 실패 (위 ERROR/MISS 확인). 재실행하면 이어받는다."; exit 1; }
echo "전부 OK"
