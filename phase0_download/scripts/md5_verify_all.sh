#!/usr/bin/env bash
# 전수 md5 검증. 참조는 current.tree(1순위) + 로컬 sidecar(2순위).
# 결과를 $DEST/.md5_results.tsv 에 누적하므로 중단 후 재실행하면 이어서 검사한다.
#
# Usage:
#   nohup bash scripts/md5_verify_all.sh all > logs/md5_all.log 2>&1 &
#   ./scripts/md5_verify_all.sh pacbio_hifi HG002        # 부분 검증
#   SUMMARY=1 ./scripts/md5_verify_all.sh all            # 검사 없이 현재 집계만 출력
#
# Env: JOBS=8 (동시 md5 수 — 디스크가 병목이므로 8~16 권장), DEST, RESULTS(기본 $DEST/.md5_results.tsv)
#
# 예상 소요: 전체 107.6 TiB, JOBS=8 기준 대략 1~2일 (스토리지 읽기 속도에 좌우)
# FAIL 재처리: awk -F'\t' '$2=="FAIL"{print $1}' $DEST/.md5_results.tsv 로 목록 확인 →
#   해당 파일 rm 후 download.sh 재실행 → RESULTS에서 그 줄 지우고 본 스크립트 재실행

set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DEST:-/BiO/scratch/ehojune/GIAB_benchmark}"
RESULTS="${RESULTS:-$DEST/.md5_results.tsv}"
JOBS="${JOBS:-8}"
TREE="$DEST/.current.tree"
SUMMARY="${SUMMARY:-0}"

[ $# -ge 1 ] || { echo "usage: $0 <category|all|release|rnaseq|trio_analysis> [SAMPLE ...]"; exit 1; }
CAT="$1"; shift
ALL_SAMPLES=(HG001 HG002 HG003 HG004 HG005 HG006 HG007 HG008 HG009)
SAMPLES=("$@"); [ ${#SAMPLES[@]} -gt 0 ] || SAMPLES=("${ALL_SAMPLES[@]}")

MANIFESTS=()
case "$CAT" in
    release)       MANIFESTS+=("$REPO_DIR/manifests/release_truthsets.tsv");;
    rnaseq)        MANIFESTS+=("$REPO_DIR/manifests/rnaseq_all.tsv");;
    trio_analysis) MANIFESTS+=("$REPO_DIR/manifests/trio_analysis.tsv");;
    all)
        for s in "${SAMPLES[@]}"; do
            for m in "$REPO_DIR/manifests/$s"/*.tsv; do [ -e "$m" ] && MANIFESTS+=("$m"); done
        done
        for m in release_truthsets rnaseq_all trio_analysis; do
            [ -e "$REPO_DIR/manifests/$m.tsv" ] && MANIFESTS+=("$REPO_DIR/manifests/$m.tsv")
        done;;
    *)
        for s in "${SAMPLES[@]}"; do
            m="$REPO_DIR/manifests/$s/$CAT.tsv"; [ -e "$m" ] && MANIFESTS+=("$m")
        done;;
esac
[ ${#MANIFESTS[@]} -gt 0 ] || { echo "no manifests matched"; exit 1; }
touch "$RESULTS"

summary() {
    awk -F'\t' '{c[$2]++} END{printf "PASS %d / FAIL %d / NOREF %d / MISS %d (누적 %d)\n",
        c["PASS"], c["FAIL"], c["NOREF"], c["MISS"], NR}' "$RESULTS"
    awk -F'\t' '$2=="FAIL"{print "  FAIL:", $1}' "$RESULTS"
}
if [ "$SUMMARY" = "1" ]; then summary; exit 0; fi

if [ ! -s "$TREE" ]; then
    echo "current.tree 다운로드 중 (20 MB)..."
    wget -q -O "$TREE" "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/current.tree" \
        || { echo "current.tree 다운로드 실패"; exit 1; }
fi

WORK=$(mktemp)
trap 'rm -f "$WORK" "$WORK.keys"' EXIT

# 작업 목록: manifest 키 − 이미 검사된 키, tree md5를 미리 붙임 (key \t expect_md5_or_-)
cat "${MANIFESTS[@]}" | cut -f1 | sort -u > "$WORK.keys"
awk -F'\t' -v r="$RESULTS" -v t="$TREE" '
    FILENAME==r  { done[$1]=1; next }
    FILENAME==t  { k=$1; sub(/^ftp\//,"",k); md5[k]=$5; next }
    !($1 in done){ print $1 "\t" (($1 in md5)? md5[$1] : "-") }
' "$RESULTS" "$TREE" "$WORK.keys" > "$WORK"
total_todo=$(wc -l < "$WORK")
echo "[$(date '+%F %T')] 검사 대상 $total_todo files (JOBS=$JOBS, 결과: $RESULTS)"

check_one() {
    local key="$1" expect="$2" f status actual
    f="$DEST/$key"
    if [ ! -f "$f" ]; then status="MISS"; actual="-"
    else
        if [ "$expect" = "-" ]; then
            local base dir; base=$(basename "$f"); dir=$(dirname "$f")
            for sc in "$dir"/md5.in "$dir"/MD5 "$dir"/md5sum.txt "$dir/$base.md5" "$dir/${base}_md5sum" "$dir"/*.md5sums; do
                [ -f "$sc" ] || continue
                expect=$(grep -F "$base" "$sc" 2>/dev/null | grep -oE '\b[0-9a-f]{32}\b' | head -1) && [ -n "$expect" ] && break
            done
            [ -n "$expect" ] && [ "$expect" != "-" ] || { echo -e "$key\tNOREF\t-" >> "$RESULTS"; return; }
        fi
        actual=$(md5sum "$f" | awk '{print $1}')
        [ "$actual" = "$expect" ] && status="PASS" || status="FAIL"
    fi
    echo -e "$key\t$status\t$actual" >> "$RESULTS"
    [ "$status" = "FAIL" ] && echo "FAIL $key (expect $expect got $actual)" >&2 || true
}
export -f check_one
export DEST RESULTS

tr '\t' '\n' < "$WORK" | xargs -d'\n' -n2 -P "$JOBS" bash -c 'check_one "$1" "$2"' _

echo "[$(date '+%F %T')] 완료"
summary