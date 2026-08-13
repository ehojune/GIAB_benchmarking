#!/usr/bin/env bash
# aws s3 vs wget 다운로드 속도 비교 (2.4 GiB HiFi fastq 1개, 끝나면 삭제).
# 노드에서 직접 실행하거나 qsub로:
#   qsub -N giab_speedtest -q shepherd.q@shepherd-1-9.kobic -V -j y -o speedtest.log -S /bin/bash scripts/speedtest.sh
#
# Env: TMPDIR_TEST=/BiO/scratch/ehojune/GIAB_benchmark/.speedtest  SKIP_WGET=0

set -uo pipefail

KEY="${KEY:-data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb/m54328_180928_230446.Q20.fastq}"
SIZE="${SIZE:-2575745766}"
TMPDIR_TEST="${TMPDIR_TEST:-/BiO/scratch/ehojune/GIAB_benchmark/.speedtest}"
SKIP_WGET="${SKIP_WGET:-0}"

mkdir -p "$TMPDIR_TEST"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
mb=$(( SIZE / 1000000 ))

echo "test file: $KEY (${mb} MB)"
echo

run() {
    local label="$1"; shift
    local out="$TMPDIR_TEST/$label.dat"
    local t0 t1
    t0=$(date +%s)
    if "$@" ; then
        t1=$(date +%s)
        local dt=$(( t1 - t0 )); [ "$dt" -gt 0 ] || dt=1
        local have; have=$(stat -c%s "$out" 2>/dev/null || echo 0)
        echo "$label: $(( have / 1000000 )) MB in ${dt}s = $(( have / 1000000 / dt )) MB/s"
    else
        echo "$label: FAILED"
    fi
    rm -f "$out"
}

if command -v aws >/dev/null; then
    run s3 aws s3 cp --no-sign-request --only-show-errors "s3://giab/$KEY" "$TMPDIR_TEST/s3.dat"
else
    echo "s3: aws cli 없음 (conda install -c conda-forge awscli)"
fi

if [ "$SKIP_WGET" != "1" ]; then
    run wget wget -q -O "$TMPDIR_TEST/wget.dat" "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/$KEY"
fi

echo
echo "참고: s3가 파일 하나에서 이미 빠르면 JOBS(동시 파일 수)는 4 정도로 충분."
echo "s3 단일 파일 속도가 낮으면 aws configure set default.s3.max_concurrent_requests 20 을 시도."
