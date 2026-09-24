#!/usr/bin/env bash
# md5_verify_all.sh 를 SGE 잡으로 제출한다. 107 TiB를 읽는 일이라 로그인 노드에서 돌리지 않는다.
#
#   bash phase0_download/scripts/sge_md5_verify.sh            # 전체 (재실행하면 검사한 파일은 건너뜀)
#   SLOTS=16 bash phase0_download/scripts/sge_md5_verify.sh   # 동시 md5 수 = 슬롯 수
#
# Env: SLOTS=8  SGE_QUEUE='shepherd.q,octopus.q'  SGE_HOSTS='(octopus-2-8|octopus-2-9|shepherd-1-8|shepherd-1-9)'
#      DEST=/BiO/scratch/ehojune/GIAB_benchmark
#
# 계산 노드는 외부망이 없다. current.tree 가 없으면 여기(로그인 노드)서 먼저 받는다.
# 끝나면: SUMMARY=1 bash phase0_download/scripts/md5_verify_all.sh all
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
DEST="${DEST:-/BiO/scratch/ehojune/GIAB_benchmark}"
SLOTS="${SLOTS:-8}"
SGE_QUEUE="${SGE_QUEUE:-shepherd.q,octopus.q}"
SGE_HOSTS="${SGE_HOSTS:-(octopus-2-8|octopus-2-9|shepherd-1-8|shepherd-1-9)}"
TREE="$DEST/.current.tree"

if [ ! -s "$TREE" ]; then
    echo "current.tree 없음 — 로그인 노드에서 받는다"
    wget -q -O "$TREE.new" "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/current.tree" && [ -s "$TREE.new" ] \
        && mv "$TREE.new" "$TREE" || { echo "current.tree 다운로드 실패"; exit 1; }
fi
mkdir -p "$REPO_ROOT/logs"
out=$(cd "$REPO_ROOT" && qsub -N giab_md5_all -q "$SGE_QUEUE" -pe pe_slots "$SLOTS" -l "h=$SGE_HOSTS" \
        -j y -o "logs/md5_all.sge.log" -b y -V -cwd \
        env JOBS="$SLOTS" DEST="$DEST" bash phase0_download/scripts/md5_verify_all.sh all < /dev/null 2>&1) \
    || { echo "qsub 거부 — $out"; exit 1; }
echo "$out"
echo "확인: qstat -u \$USER | grep giab_md5   /   중간 집계: SUMMARY=1 bash phase0_download/scripts/md5_verify_all.sh all"
