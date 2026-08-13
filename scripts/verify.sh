#!/usr/bin/env bash
# manifest 대비 다운로드 진행률/무결성(파일 크기) 확인.
#
# Usage:
#   ./scripts/verify.sh <category|all|release> [SAMPLE ...]
#   MISSING=1 ./scripts/verify.sh pacbio_hifi   # 미완료 파일 목록도 출력
#
# Env: DEST=/BiO/scratch/ehojune/GIAB_benchmark

set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DEST:-/BiO/scratch/ehojune/GIAB_benchmark}"
MISSING="${MISSING:-0}"

ALL_SAMPLES=(HG001 HG002 HG003 HG004 HG005 HG006 HG007 HG008)
[ $# -ge 1 ] || { echo "usage: $0 <category|all|release> [SAMPLE ...]"; exit 1; }
CAT="$1"; shift
SAMPLES=("$@"); [ ${#SAMPLES[@]} -gt 0 ] || SAMPLES=("${ALL_SAMPLES[@]}")

MANIFESTS=()
if [ "$CAT" = "release" ]; then
    MANIFESTS+=("$REPO_DIR/manifests/release_truthsets.tsv")
elif [ "$CAT" = "rnaseq" ]; then
    MANIFESTS+=("$REPO_DIR/manifests/rnaseq_all.tsv")
elif [ "$CAT" = "all" ]; then
    for s in "${SAMPLES[@]}"; do
        for m in "$REPO_DIR/manifests/$s"/*.tsv; do [ -e "$m" ] && MANIFESTS+=("$m"); done
    done
else
    for s in "${SAMPLES[@]}"; do
        m="$REPO_DIR/manifests/$s/$CAT.tsv"
        [ -e "$m" ] && MANIFESTS+=("$m")
    done
fi

g_total=0; g_done=0; g_tb=0; g_done_b=0
for m in "${MANIFESTS[@]}"; do
    total=0; done_n=0; total_b=0; done_b=0
    while IFS=$'\t' read -r key size; do
        total=$((total+1)); total_b=$((total_b+size))
        have=$(stat -c%s "$DEST/$key" 2>/dev/null || echo -1)
        if [ "$have" = "$size" ]; then
            done_n=$((done_n+1)); done_b=$((done_b+size))
        elif [ "$MISSING" = "1" ]; then
            echo "MISSING $key ($have/$size)"
        fi
    done < "$m"
    name="$(basename "$(dirname "$m")")/$(basename "$m" .tsv)"
    awk -v n="$name" -v d="$done_n" -v t="$total" -v db="$done_b" -v tb="$total_b" \
        'BEGIN{printf "%-40s %6d/%-6d files  %8.1f/%.1f GiB (%.1f%%)\n", n, d, t, db/2^30, tb/2^30, (tb>0? 100*db/tb : 100)}'
    g_total=$((g_total+total)); g_done=$((g_done+done_n))
    g_tb=$((g_tb+total_b)); g_done_b=$((g_done_b+done_b))
done
awk -v d="$g_done" -v t="$g_total" -v db="$g_done_b" -v tb="$g_tb" \
    'BEGIN{printf "%-40s %6d/%-6d files  %8.1f/%.1f GiB (%.1f%%)\n", "TOTAL", d, t, db/2^30, tb/2^30, (tb>0? 100*db/tb : 100)}'
