#!/usr/bin/env bash
# manifest에서 무작위 표본을 뽑아 로컬 md5를 GIAB 공식 체크섬과 대조한다.
# 참조 1순위: FTP current.tree(경로/크기/날짜/md5, 20MB 자동 다운로드)
# 참조 2순위: 같은 디렉토리에 이미 받아둔 sidecar (md5.in, *.md5, *_md5sum 등) — HG009처럼 tree 이후 추가분용
#
# Usage:
#   ./scripts/md5_spotcheck.sh all                # 모든 manifest에서 표본
#   ./scripts/md5_spotcheck.sh pacbio_hifi HG002  # 특정 카테고리/샘플만
#
# Env:
#   N_PER_MANIFEST=2   manifest당 표본 수
#   MAX_GIB=20         표본 후보 크기 상한 (md5는 전체를 읽으므로 시간 제어용)
#   DEST=/BiO/scratch/ehojune/GIAB_benchmark
#
# 종료코드: FAIL 있으면 1. FAIL 파일은 지우고 다시 받으면 됨:
#   rm <파일> && JOBS=4 ./scripts/download.sh <category> <sample>

set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DEST:-/BiO/scratch/ehojune/GIAB_benchmark}"
N="${N_PER_MANIFEST:-2}"
MAX_GIB="${MAX_GIB:-20}"
TREE="$DEST/.current.tree"

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

if [ ! -s "$TREE" ]; then
    echo "current.tree 다운로드 중 (20 MB)..."
    wget -q -O "$TREE" "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/current.tree" \
        || { echo "current.tree 다운로드 실패"; exit 1; }
fi

# sidecar 파일에서 md5 찾기: 대상 파일과 같은 디렉토리의 md5 목록 파일에서 basename 매칭
sidecar_md5() {
    local f="$1" base dir
    base=$(basename "$f"); dir=$(dirname "$f")
    for sc in "$dir"/md5.in "$dir"/MD5 "$dir"/md5sum.txt "$dir/$base.md5" "$dir/${base}_md5sum" "$dir"/*.md5sums; do
        [ -f "$sc" ] || continue
        grep -F "$base" "$sc" 2>/dev/null | grep -oE '\b[0-9a-f]{32}\b' | head -1 && return 0
    done
    return 1
}

pass=0; fail=0; noref=0; miss=0
declare -a fails
for m in "${MANIFESTS[@]}"; do
    name="$(basename "$(dirname "$m")")/$(basename "$m" .tsv)"
    [ "$(basename "$(dirname "$m")")" = "manifests" ] && name="$(basename "$m" .tsv)"
    # 크기 상한 이내 후보에서 N개 무작위 추출 (md5/체크섬 파일 자체는 제외)
    mapfile -t picks < <(awk -F'\t' -v max=$((MAX_GIB*1024*1024*1024)) \
        '$2 <= max && $1 !~ /(md5|MD5)/ {print $1}' "$m" | shuf -n "$N")
    for key in "${picks[@]}"; do
        f="$DEST/$key"
        if [ ! -f "$f" ]; then echo "MISS   $name  $key (로컬에 없음)"; miss=$((miss+1)); continue; fi
        expect=$(awk -F'\t' -v k="ftp/$key" '$1==k{print $5; exit}' "$TREE")
        [ -n "${expect:-}" ] || expect=$(sidecar_md5 "$f" || true)
        if [ -z "${expect:-}" ]; then
            echo "NOREF  $name  $key (공식 md5 없음 — 크기 검증만 유효)"; noref=$((noref+1)); continue
        fi
        actual=$(md5sum "$f" | awk '{print $1}')
        if [ "$actual" = "$expect" ]; then
            echo "PASS   $name  $key"; pass=$((pass+1))
        else
            echo "FAIL   $name  $key (expect $expect got $actual)"; fail=$((fail+1)); fails+=("$key")
        fi
    done
done

echo
echo "=== md5 표본 검사: PASS $pass / FAIL $fail / 참조없음 $noref / 로컬없음 $miss ==="
if [ $fail -gt 0 ]; then
    echo "FAIL 파일은 삭제 후 해당 카테고리를 재실행하면 다시 받아진다:"
    for k in "${fails[@]}"; do echo "  rm \"$DEST/$k\""; done
    exit 1
fi
