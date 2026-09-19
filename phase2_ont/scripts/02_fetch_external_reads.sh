#!/bin/bash
# GIAB FTP에 없는 리드를 외부 공개 출처에서 받는다 (로그인 노드).
#
# 대상 둘:
#  1. HG001 ONT-UL — GIAB FTP의 data/NA12878/Ultralong_OxfordNanopore 에는 GRCh37/38 정렬 BAM만
#     있고 리드가 없다. 원본은 **nanopore-wgs-consortium**(Jain et al. 2018, GIAB과 별개 컨소시엄)의
#     공개 버킷 s3://nanopore-human-wgs 에 있고 GIAB README가 "rel6 based called reads"라고 밝힌다.
#  2. HG002 R10.4.1 — GIAB FTP에는 HG002의 R10 ONT가 아예 없다(ONT 디렉토리 셋 전부 R9 시절).
#     ONT 공개 데이터 giab_2025.01(s3://ont-open-data)에서 정렬 BAM으로 받는다.
#     **CC BY-NC 4.0 = 비상업 연구 한정** — 이 제약은 데이터와 함께 따라다닌다.
#
#   scripts/02_fetch_external_reads.sh                 리드 + 증거 파일 전부
#   VERIFY_ONLY=1 scripts/02_fetch_external_reads.sh   받지 않고 상태만 점검
#   KIND=reads scripts/02_fetch_external_reads.sh      리드만 (sequencing summary·인덱스 생략)
#   SKIP_MD5=1 scripts/02_fetch_external_reads.sh      md5 검증 생략 (160 GiB는 몇 분 걸린다)
#
# 대상·크기·md5·URL은 ext_manifest.tsv가 전부. wget -c 라서 중단 후 재실행하면 이어받는다.
# md5 칸이 '-' 인 항목은 출처가 md5를 공개하지 않은 것이다 (S3 ETag는 멀티파트라 md5가 아니다) —
# 그때는 크기 + 내용 샘플링으로만 본다. md5를 한 번 통과하면 <파일>.md5ok 를 남겨 다시 계산하지 않는다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
MAN="$HERE/../ext_manifest.tsv"
LOG="$INFRA/logs/ext_fetch.log"
mkdir -p "$INFRA/logs"
# 로그는 exec로 복제한다. `while ... | tee` 로 묶으면 루프가 서브셸로 가서 rc가 유실된다.
exec > >(tee -a "$LOG") 2>&1

# rel6은 2016~2017년 R9.4 MinION 데이터다. 평균 리드 길이가 6~10 kb 수준이어야 하고
# (Ultra 킷 12셀만 20 kb대), 여기서 크게 벗어나면 다른 파일을 받은 것이다.
MEAN_LEN_MIN=3000
MEAN_LEN_MAX=40000

check_reads() {
    local f=$1 got
    got=$( { zcat "$f" 2>/dev/null || true; } \
           | awk 'NR%4==2 {n++; t+=length($0)} n>=20000 {exit} END {if(n) printf "%d", t/n}' )
    if [ -z "$got" ]; then
        echo "  ERROR: 리드를 읽지 못함 (gzip 손상?): $f"; return 1
    fi
    if [ "$got" -lt "$MEAN_LEN_MIN" ] || [ "$got" -gt "$MEAN_LEN_MAX" ]; then
        echo "  ERROR: 앞부분 평균 리드 길이 ${got}bp — ONT rel6로 보기 어렵다: $f"; return 1
    fi
    echo "  리드 평균 길이 ${got}bp (앞 20k 리드)"
    return 0
}

# 정렬 BAM은 리드 길이로 검증할 수 없다. 잘림(EOF 블록)과 베이스콜 모델을 본다.
# 로그인 노드에 samtools가 없어 캐시된 컨테이너로 돌린다 (03_dup_evidence.sh와 같은 방식).
check_bam() {
    local f=$1 st model
    st="$NXF_SINGULARITY_CACHEDIR/quay.io-biocontainers-samtools-1.24--h9dcdb79_1.img"
    if [ ! -s "$st" ]; then
        echo "  건너뜀: samtools 컨테이너가 없어 BAM 검증 생략 — 01_prepare_login_node.sh 먼저"
        return 0
    fi
    if ! singularity exec -B "$GIAB_ROOT:$GIAB_ROOT" "$st" samtools quickcheck "$f"; then
        echo "  ERROR: samtools quickcheck 실패 (잘렸거나 BAM이 아니다): $f"; return 1
    fi
    # dorado는 @PG/@RG 에 베이스콜 모델을 남긴다. R9 파일을 잘못 받은 경우를 여기서 잡는다.
    model=$( { singularity exec -B "$GIAB_ROOT:$GIAB_ROOT" "$st" samtools view -H "$f" 2>/dev/null || true; } \
             | grep -m1 -oE 'dna_r[0-9]+[._][0-9]+[^[:space:]]*' )
    case "$model" in
        dna_r10*) echo "  BAM OK — 베이스콜 모델 $model" ;;
        "")       echo "  BAM OK — 헤더에 베이스콜 모델이 없다 (치명적이지 않음)" ;;
        *)        echo "  ERROR: R10이 아닌 베이스콜 모델이다 ($model): $f"; return 1 ;;
    esac
    return 0
}

# md5 칸이 '-' 면 출처가 공개하지 않은 것이다. 한 번 통과하면 <파일>.md5ok 를 남겨 다시 계산하지
# 않는다 — 160 GiB를 실행할 때마다 다시 읽으면 못 쓴다.
check_md5() {
    local f=$1 want=$2 got sz
    [ "$want" = - ] && { echo "  md5 미공개 — 크기로만 확인"; return 0; }
    [ "${SKIP_MD5:-0}" = 1 ] && { echo "  md5 검증 생략 (SKIP_MD5=1)"; return 0; }
    # 스탬프에 검증한 값을 적어 둔다. 값 없이 존재만 보면, 매니페스트의 기대 md5가 바뀌었을 때
    # (항목 정정, 같은 경로의 새 판) 낡은 스탬프가 조용히 통과시킨다.
    if [ -f "$f.md5ok" ] && [ "$(cat "$f.md5ok" 2>/dev/null)" = "$want" ]; then
        echo "  md5 확인됨 (이전 실행)"; return 0
    fi
    sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
    echo "  md5 계산 중 ($(awk -v b="$sz" 'BEGIN{printf "%.1f", b/1073741824}') GiB)..."
    got=$(md5sum "$f" | cut -d' ' -f1)
    if [ "$got" != "$want" ]; then
        echo "  ERROR: md5 불일치 (got=$got want=$want): $f"; rm -f "$f.md5ok"; return 1
    fi
    printf '%s\n' "$got" > "$f.md5ok"
    echo "  md5 일치"
    return 0
}

rc=0
# 탭 구분 파일을 IFS 탭으로 직접 읽으면 안 된다 — 탭은 IFS 공백류라 연속 구분자가 하나로 접혀
# 빈 칸이 있는 행에서 필드가 통째로 밀린다 (phase3에서 실제로 당했다). awk가 0x1F로 바꿔 넘긴다.
SEP=$(printf '\037')
while IFS="$SEP" read -r dsid relpath bytes md5 url kind note; do
    [ -z "${dsid:-}" ] && continue
    [ -n "${KIND:-}" ] && [ "$kind" != "$KIND" ] && continue
    out="$GIAB_ROOT/$relpath"
    mkdir -p "$(dirname "$out")"
    have=-1
    [ -f "$out" ] && have=$(stat -c%s "$out" 2>/dev/null || echo -1)

    if [ "$have" != "$bytes" ]; then
        if [ "${VERIFY_ONLY:-0}" = 1 ]; then
            printf 'MISS %s (have=%s want=%s)\n' "$relpath" "$have" "$bytes"; rc=1; continue
        fi
        echo "GET  $relpath ($(awk -v b="$bytes" 'BEGIN{printf "%.1f", b/1073741824}') GiB)"
        if ! wget -c -q --show-progress -O "$out" "$url"; then
            echo "  ERROR: 다운로드 실패 — $url (재실행하면 이어받는다)"; rc=1; continue
        fi
        have=$(stat -c%s "$out" 2>/dev/null || echo -1)
        if [ "$have" != "$bytes" ]; then
            echo "  ERROR: 크기 불일치 $relpath (got=$have want=$bytes)"; rc=1; continue
        fi
    fi
    if [ "${VERIFY_ONLY:-0}" = 1 ]; then
        printf 'HAVE %s\n' "$relpath"; continue
    fi
    check_md5 "$out" "$md5" || { rc=1; continue; }
    if [ "$kind" = reads ]; then
        case "$out" in
            *.bam) check_bam   "$out" || { rc=1; continue; } ;;
            *)     check_reads "$out" || { rc=1; continue; } ;;
        esac
    fi
    echo "OK   $relpath"
done < <(awk -F'\t' -v OFS="$SEP" 'NR>1 && NF {$1=$1; print}' "$MAN")

echo
if [ "$rc" = 0 ]; then
    echo "완료. 다음:"
    echo "  bash $HERE/03_dup_evidence.sh HG001   # GIAB BAM과 rel6이 같은 리드인지 대조"
    echo "  bash $HERE/10_submit.sh HG002.ONT-R10_giab2025.01_PAW70337   # R10 런 제출"
else
    echo "일부 실패 (위 ERROR 확인). 재실행하면 이어받는다."
fi
exit "$rc"
