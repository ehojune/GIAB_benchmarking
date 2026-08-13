#!/usr/bin/env bash
# download.sh를 SGE job으로 제출. manifest(샘플x카테고리) 하나당 job 하나.
# 기본: shepherd-1-9 노드 고정, TOOL=s3, JOBS=4.
#
# 사전 준비 (제출 셸에서):
#   conda activate <awscli 깔린 env>    # aws --version 확인
#   qsub -V 로 제출되므로 활성화된 env의 PATH가 job에 그대로 전달됨
#
# Usage:
#   ./scripts/sge_download.sh <category|all|release> [SAMPLE ...]
#
# Env:
#   QUEUE=shepherd.q@shepherd-1-9.kobic   대상 큐/노드
#   TOOL=s3  JOBS=4  DEST=...             download.sh로 전달
#   PE=                                   지정 시 -pe $PE $JOBS 로 슬롯 확보 (예: PE=smp)
#
# Examples:
#   ./scripts/sge_download.sh pacbio_hifi
#   ./scripts/sge_download.sh ont HG002
#   JOBS=8 ./scripts/sge_download.sh release

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE="${QUEUE:-shepherd.q@shepherd-1-9.kobic}"
TOOL="${TOOL:-s3}"
JOBS="${JOBS:-4}"
DEST="${DEST:-/BiO/scratch/ehojune/GIAB_benchmark}"
PE="${PE:-}"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"

ALL_SAMPLES=(HG001 HG002 HG003 HG004 HG005 HG006 HG007 HG008)
[ $# -ge 1 ] || { echo "usage: $0 <category|all|release> [SAMPLE ...]"; exit 1; }
CAT="$1"; shift
SAMPLES=("$@"); [ ${#SAMPLES[@]} -gt 0 ] || SAMPLES=("${ALL_SAMPLES[@]}")

if [ "$TOOL" = "s3" ] && ! command -v aws >/dev/null; then
    echo "aws cli가 PATH에 없음. conda activate 후 제출할 것 (qsub -V로 PATH 전달됨)" >&2
    exit 1
fi

submit() {
    local cat="$1" sample="$2"   # sample=""이면 release
    local name="giab_${sample:-release}_${cat}"
    local pe_opt=()
    [ -n "$PE" ] && pe_opt=(-pe "$PE" "$JOBS")
    qsub -N "$name" -q "$QUEUE" -V -j y -o "$LOG_DIR/$name.log" \
        -S /bin/bash "${pe_opt[@]}" <<EOF
export TOOL="$TOOL" JOBS="$JOBS" DEST="$DEST"
"$REPO_DIR/scripts/download.sh" "$cat" $sample
EOF
}

if [ "$CAT" = "release" ]; then
    submit release ""
elif [ "$CAT" = "all" ]; then
    for s in "${SAMPLES[@]}"; do
        for m in "$REPO_DIR/manifests/$s"/*.tsv; do
            [ -e "$m" ] || continue
            submit "$(basename "$m" .tsv)" "$s"
        done
    done
else
    for s in "${SAMPLES[@]}"; do
        [ -e "$REPO_DIR/manifests/$s/$CAT.tsv" ] || { echo "skip: $s has no $CAT data"; continue; }
        submit "$CAT" "$s"
    done
fi

echo "제출 완료. 모니터링: qstat -q $QUEUE / 로그: $LOG_DIR/ / 진행률: ./scripts/verify.sh $CAT"
