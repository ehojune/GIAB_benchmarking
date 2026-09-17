#!/bin/bash
# phase3 외부 숏리드를 받는다 (nbb2 로그인 노드). 대상·크기·URL·md5는 ext_manifest.tsv가 전부.
#
# 왜 외부인가: (1) HG002/3/4 NovaSeq 6000 PCR-free 30x는 GIAB FTP에 없고 Google 공개 버킷(brain-genomics-public)에 있다.
# 업체(gd001~004) 산출물과 장비·리드 길이·깊이·PCR-free가 맞는 유일한 공개 트리오다.
# (2) HiSeq 30x 서브샘플은 GIAB FTP에 HG002만 있고, 그 README가 HG003/HG004 사본을 HPRC S3로 가리킨다.
#
#   bash scripts/02_fetch_external_reads.sh                 전부 받고 검증
#   VERIFY_ONLY=1 bash scripts/02_fetch_external_reads.sh   받지 않고 상태만 점검
#   DSID=HG003.NovaSeq_PCRfree_30x bash scripts/02_fetch_external_reads.sh   한 실행 단위만
#
# wget -c 라서 중단 후 재실행하면 이어받는다. md5가 있는 행(Google)은 md5sum으로, 없는 행(HPRC; S3 ETag는 멀티파트라
# md5가 아니다)은 크기 + 앞 20k 리드 평균 길이(140~160 bp)로 본다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIAB_ROOT="${GIAB_ROOT:-/BiO/scratch/ehojune/GIAB_benchmark}"
MAN="$HERE/../ext_manifest.tsv"
LOG="${LOG:-$GIAB_ROOT/ext/phase3_ext_fetch.log}"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
echo "== $(date '+%F %T') GIAB_ROOT=$GIAB_ROOT VERIFY_ONLY=${VERIFY_ONLY:-0} DSID=${DSID:-all}"

MEAN_LEN_MIN=140
MEAN_LEN_MAX=160

check_reads() {   # 앞 20k 리드 평균 길이. 2x148(HiSeq) / 2x151(NovaSeq) 이어야 한다
    local f=$1 got
    got=$( { zcat "$f" 2>/dev/null || true; } \
           | awk 'NR%4==2 {n++; t+=length($0)} n>=20000 {exit} END {if(n) printf "%d", t/n}' )
    if [ -z "$got" ]; then echo "  ERROR: 리드를 읽지 못함 (gzip 손상?): $f"; return 1; fi
    if [ "$got" -lt "$MEAN_LEN_MIN" ] || [ "$got" -gt "$MEAN_LEN_MAX" ]; then
        echo "  ERROR: 앞부분 평균 리드 길이 ${got}bp — 기대 범위(${MEAN_LEN_MIN}~${MEAN_LEN_MAX}) 밖: $f"; return 1
    fi
    echo "  리드 평균 길이 ${got}bp (앞 20k 리드)"
}

check_md5() {
    local f=$1 want=$2 got
    got=$(md5sum "$f" | awk '{print $1}')
    if [ "$got" != "$want" ]; then echo "  ERROR: md5 불일치 $f (got=$got want=$want)"; return 1; fi
    echo "  md5 OK"
}

rc=0
while IFS=$'\t' read -r dsid relpath bytes url md5 kind note; do
    [ "$dsid" = dsid ] && continue
    [ -z "${dsid:-}" ] && continue
    [ -n "${DSID:-}" ] && [ "$dsid" != "$DSID" ] && continue
    [ "$kind" != reads ] && continue
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
    if [ -n "$md5" ]; then check_md5 "$out" "$md5" || { rc=1; continue; }; fi
    check_reads "$out" || { rc=1; continue; }
    echo "OK   $relpath"
done < "$MAN"

echo
if [ "$rc" = 0 ]; then
    echo "완료. samplesheets/HG00?.NovaSeq_PCRfree_30x.csv, HG003|HG004.Illumina_PCRfree_30x.csv 의 경로가 이제 실존한다."
else
    echo "일부 실패 (위 ERROR 확인). 재실행하면 이어받는다."
fi
exit "$rc"
