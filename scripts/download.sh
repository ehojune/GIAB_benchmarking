#!/usr/bin/env bash
# GIAB downloader. manifest(파일경로+크기)를 읽어 DEST 아래에 GIAB 원본 경로 그대로 받는다.
# 이미 받은 파일(크기 일치)은 건너뛰므로 중단 후 재실행해도 안전하다.
#
# Usage:
#   ./scripts/download.sh <category|all|release> [SAMPLE ...]
#     category: pacbio_hifi ont pacbio_clr illumina_wgs bgi_mgi linked_reads exome complete_genomics other
#     SAMPLE:   HG001..HG008 (생략 시 전체; HG008 = tumor-normal, T/N-D/N-P 통합)
#
# Env:
#   DEST=/BiO/scratch/ehojune/GIAB_benchmark   다운로드 루트
#   TOOL=wget|aria2|s3                         기본 wget (s3 권장: aws cli 필요)
#   JOBS=1                                     동시에 받을 파일 수
#
# Examples:
#   ./scripts/download.sh pacbio_hifi
#   ./scripts/download.sh ont HG002 HG005
#   TOOL=s3 JOBS=4 ./scripts/download.sh pacbio_clr
#   ./scripts/download.sh release

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DEST:-/BiO/scratch/ehojune/GIAB_benchmark}"
TOOL="${TOOL:-wget}"
JOBS="${JOBS:-1}"
HTTP_BASE="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab"
S3_BASE="s3://giab"
FAIL_LOG="$DEST/.download_failed.log"

ALL_SAMPLES=(HG001 HG002 HG003 HG004 HG005 HG006 HG007 HG008)
CATEGORIES=(pacbio_hifi ont pacbio_clr illumina_wgs bgi_mgi linked_reads exome complete_genomics other)

usage() { sed -n '2,20p' "$0"; exit 1; }
[ $# -ge 1 ] || usage
CAT="$1"; shift
SAMPLES=("$@"); [ ${#SAMPLES[@]} -gt 0 ] || SAMPLES=("${ALL_SAMPLES[@]}")

# 대상 manifest 목록 결정
MANIFESTS=()
if [ "$CAT" = "release" ]; then
    MANIFESTS+=("$REPO_DIR/manifests/release_truthsets.tsv")
elif [ "$CAT" = "all" ]; then
    for s in "${SAMPLES[@]}"; do
        for m in "$REPO_DIR/manifests/$s"/*.tsv; do [ -e "$m" ] && MANIFESTS+=("$m"); done
    done
else
    ok=0; for c in "${CATEGORIES[@]}"; do [ "$c" = "$CAT" ] && ok=1; done
    [ $ok -eq 1 ] || { echo "unknown category: $CAT"; usage; }
    for s in "${SAMPLES[@]}"; do
        m="$REPO_DIR/manifests/$s/$CAT.tsv"
        [ -e "$m" ] && MANIFESTS+=("$m") || echo "skip: $s has no $CAT data"
    done
fi
[ ${#MANIFESTS[@]} -gt 0 ] || { echo "no manifests matched"; exit 1; }

mkdir -p "$DEST"

dl_line() {
    local line="$1"
    local key="${line%%$'\t'*}"
    local size="${line#*$'\t'}"
    local out="$DEST/$key"

    if [ -f "$out" ]; then
        local have; have=$(stat -c%s "$out" 2>/dev/null || echo 0)
        [ "$have" = "$size" ] && return 0
    fi
    mkdir -p "$(dirname "$out")"

    local rc=1
    case "$TOOL" in
        wget)
            wget -c -q -O "$out.part" "$HTTP_BASE/$key" && mv "$out.part" "$out" && rc=0
            ;;
        aria2)
            aria2c -c -x4 -s4 --console-log-level=warn --file-allocation=none \
                -d "$(dirname "$out")" -o "$(basename "$out").part" "$HTTP_BASE/$key" \
                && mv "$out.part" "$out" && rc=0
            ;;
        s3)
            aws s3 cp --no-sign-request --only-show-errors "$S3_BASE/$key" "$out" && rc=0
            ;;
        *) echo "unknown TOOL: $TOOL" >&2; return 2 ;;
    esac

    if [ $rc -eq 0 ]; then
        local have; have=$(stat -c%s "$out" 2>/dev/null || echo 0)
        if [ "$have" = "$size" ]; then
            echo "OK   $key"
            return 0
        fi
        echo "SIZE MISMATCH $key (expected $size, got $have)" | tee -a "$FAIL_LOG" >&2
        return 1
    fi
    echo "FAIL $key" | tee -a "$FAIL_LOG" >&2
    return 1
}
export -f dl_line
export DEST TOOL HTTP_BASE S3_BASE FAIL_LOG

for m in "${MANIFESTS[@]}"; do
    n=$(wc -l < "$m")
    echo "=== $(basename "$(dirname "$m")")/$(basename "$m")  ($n files) ==="
    if [ "$JOBS" -gt 1 ]; then
        xargs -d '\n' -P "$JOBS" -n1 bash -c 'dl_line "$1"' _ < "$m" || true
    else
        while IFS= read -r line; do dl_line "$line" || true; done < "$m"
    fi
done

echo "done. 실패 목록: $FAIL_LOG (없으면 전부 성공). ./scripts/verify.sh 로 최종 확인."
