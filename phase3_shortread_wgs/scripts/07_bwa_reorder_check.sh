#!/bin/bash
# 입력 순서를 바꾸면 bwa-mem2가 끝까지 통과하는지 본다(MGISEQ HG002, 2026-09-24).
# 배경: bwa-mem2 2.2.1이 한 청크에서 매번 죽는데(05·06), 한 리드를 빼서는 안 없어진다 — 배치 구성·메모리 배치에 달린 힙 오염으로 본다.
# 리드끼리는 독립이라 순서는 정렬 뒤 결과에 상관없다. 병합 순서를 L03+L04 → L04+L03으로 바꾸면 L04 쪽 배치가 전부 달라진다(-K는 염기 수로 자른다).
# fastp는 리드 단위로 결정적이라(세 실행이 같은 리드 수에서 죽었다) trimmed 파일을 같은 식으로 재배열한 것이 곧 재배열된 원본을
# 파이프라인 fastp에 넣었을 때 bwa가 보게 될 입력이다. 그래서 fastp를 다시 돌리지 않고 trimmed 파일을 재배열해 흘린다.
#
#   qsub ... 07_bwa_reorder_check.sh <RUN_DIR> <FIRST_RE> <EXPECTED_READS> <OUT_DIR>
#     RUN_DIR       R1/R2.trimmed.fastq.gz 가 있는 dir
#     FIRST_RE      이 이름으로 시작하는 첫 리드부터 끝까지를 먼저, 그 앞을 나중에 흘린다. 예: '^@V100002807L4'
#     EXPECTED_READS  trimmed 총 리드 수(mate 둘 다) — 끝까지 처리됐는지 대조
#   환경변수: BWA_DIR, REF, THREADS(기본 NSLOTS 또는 10), PIGZ(기본 pigz)
set -uo pipefail
RUN_DIR=${1:?RUN_DIR}; RE=${2:?FIRST_RE}; EXP=${3:?EXPECTED_READS}; OUT=${4:?OUT_DIR}
BWA_DIR=${BWA_DIR:-/BiO/scratch/dyl/kbb/UTILS/Tools/bwa-mem2_amd/bwa-mem2-2.2.1}
REF=${REF:-/BiO/scratch/dyl/kbb/UTILS/Reference/GATK_bundle/Homo_sapiens_assembly38.fasta}
THREADS=${THREADS:-${NSLOTS:-10}}; PIGZ=${PIGZ:-pigz}
mkdir -p "$OUT" || exit 2
log() { echo "[$(date '+%F %T')] $*" | tee -a "$OUT/result.txt"; }
log "RUN_DIR=$RUN_DIR FIRST_RE=$RE EXPECTED_READS=$EXP HOST=$(hostname) THREADS=$THREADS"
# 머리줄(NR%4==1)에서만 이름을 본다 — 품질 줄도 '@'로 시작할 수 있다
reorder() {
  "$PIGZ" -dc "$1" | awk -v re="$RE" 'NR%4==1 && !f && $0 ~ re {f=1} f'
  "$PIGZ" -dc "$1" | awk -v re="$RE" 'NR%4==1 && $0 ~ re {exit} {print}'
}
RG='@RG\tID:reorder\tSM:reorder\tPL:ILLUMINA\tLB:UNKNOWN'
"$BWA_DIR/bwa-mem2" mem -Y -R "$RG" -v 3 -t "$THREADS" -K 100000000 "$REF" \
    <(reorder "$RUN_DIR/R1.trimmed.fastq.gz") <(reorder "$RUN_DIR/R2.trimmed.fastq.gz") > /dev/null 2> "$OUT/bwa.stderr"
rc=$?
got=$(grep "Processed .* reads" "$OUT/bwa.stderr" | awk '{s+=$4} END{print s+0}')
if [ "$rc" = 0 ] && [ "$got" = "$EXP" ]; then v="PASS — 순서를 바꾼 입력은 끝까지 통과"; else v="FAIL"; fi
log "bwa-mem2 rc=$rc, 처리된 리드 $got / 기대 $EXP → $v"
log "DONE"
