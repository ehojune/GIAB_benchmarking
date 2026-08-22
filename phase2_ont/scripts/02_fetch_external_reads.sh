#!/bin/bash
# HG001 ONT-UL 리드를 외부에서 받는다 (로그인 노드).
#
# 왜 외부인가: GIAB FTP의 data/NA12878/Ultralong_OxfordNanopore 에는 GRCh37/38 정렬 BAM만 있고
# 리드가 없다. 원본 리드는 **nanopore-wgs-consortium**(Jain et al. 2018, GIAB과 별개 컨소시엄)의
# 공개 AWS 버킷 s3://nanopore-human-wgs 에 있고, GIAB README가 "rel6 based called reads"라고 밝힌다.
#
#   scripts/02_fetch_external_reads.sh                 리드 + 증거 파일 전부
#   VERIFY_ONLY=1 scripts/02_fetch_external_reads.sh   받지 않고 상태만 점검
#   KIND=reads scripts/02_fetch_external_reads.sh      리드만 (sequencing summary 생략)
#
# 대상·크기·URL은 ext_manifest.tsv가 전부. wget -c 라서 중단 후 재실행하면 이어받는다.
# md5는 공개되어 있지 않다 (S3 ETag는 멀티파트라 md5가 아니다) — 크기 + 리드 길이 샘플링으로 본다.
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

rc=0
while IFS=$'\t' read -r dsid relpath bytes url kind note; do
    [ "$dsid" = dsid ] && continue
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
    if [ "$kind" = reads ]; then
        check_reads "$out" || { rc=1; continue; }
    fi
    echo "OK   $relpath"
done < "$MAN"

echo
if [ "$rc" = 0 ]; then
    echo "완료. 다음: bash $HERE/03_dup_evidence.sh HG001   # GIAB BAM과 rel6이 같은 리드인지 대조"
else
    echo "일부 실패 (위 ERROR 확인). 재실행하면 이어받는다."
fi
exit "$rc"
