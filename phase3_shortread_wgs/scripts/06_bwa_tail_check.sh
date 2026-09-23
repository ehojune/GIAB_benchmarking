#!/bin/bash
# 죽은 지점 뒤의 리드도 bwa-mem2 를 통과하는지 본다(05 이분법의 짝). 페어 FROM(0-based)부터 끝까지를 trimmed FASTQ 에서 흘려
# 같은 인자로 정렬하고 출력은 버린다. 결과: rc(0이면 끝까지 통과, >128이면 신호로 죽음)와 처리된 리드 수.
#   qsub ... 06_bwa_tail_check.sh <RUN_DIR> <FROM_PAIR> <OUT_DIR>      # RUN_DIR 에 R1/R2.trimmed.fastq.gz
#   환경변수: BWA_DIR, REF, THREADS(기본 NSLOTS 또는 10), PIGZ(기본 pigz), BWA_EXTRA
#     EXPECTED_READS  보낸 리드 수(mate 둘 다). 주면 처리 수와 대조해 PASS/FAIL, 안 주면 rc=0이어도 '미검증'
#     EXCLUDE=a:b  페어 [a,b)(0-based, 전체 기준)를 빼고 흘린다 — '그 창을 뺀 입력이 끝까지 통과하나'를 본다.
#     FROM을 죽은 청크의 시작으로 두면 그 앞 배치는 원래 실행과 똑같아(-K는 염기 수로 자른다) 이미 통과한 것이므로,
#     이 검사가 통과하면 창을 뺀 입력 전체가 같은 인자의 bwa-mem2를 통과한다.
set -uo pipefail
RUN_DIR=${1:?RUN_DIR}; FROM=${2:?FROM_PAIR}; OUT=${3:?OUT_DIR}
BWA_DIR=${BWA_DIR:-/BiO/scratch/dyl/kbb/UTILS/Tools/bwa-mem2_amd/bwa-mem2-2.2.1}
REF=${REF:-/BiO/scratch/dyl/kbb/UTILS/Reference/GATK_bundle/Homo_sapiens_assembly38.fasta}
THREADS=${THREADS:-${NSLOTS:-10}}; PIGZ=${PIGZ:-pigz}
mkdir -p "$OUT" || exit 2
log() { echo "[$(date '+%F %T')] $*" | tee -a "$OUT/result.txt"; }
log "RUN_DIR=$RUN_DIR FROM_PAIR=$FROM HOST=$(hostname) THREADS=$THREADS BWA_EXTRA='${BWA_EXTRA:-}'"
S=$((FROM * 4)); XA=0; XB=0
if [ -n "${EXCLUDE:-}" ]; then XA=$((${EXCLUDE%:*} * 4)); XB=$((${EXCLUDE#*:} * 4)); log "EXCLUDE 페어 [${EXCLUDE%:*},${EXCLUDE#*:})"; fi
RG='@RG\tID:tail\tSM:tail\tPL:ILLUMINA\tLB:UNKNOWN'
pick() { "$PIGZ" -dc "$1" | awk -v s=$S -v a=$XA -v b=$XB 'NR>s && !(NR>a && NR<=b)'; }
# shellcheck disable=SC2086
"$BWA_DIR/bwa-mem2" mem -Y -R "$RG" -v 3 -t "$THREADS" -K 100000000 ${BWA_EXTRA:-} "$REF" \
    <(pick "$RUN_DIR/R1.trimmed.fastq.gz") <(pick "$RUN_DIR/R2.trimmed.fastq.gz") > /dev/null 2> "$OUT/bwa.stderr"
rc=$?
got=$(grep "Processed .* reads" "$OUT/bwa.stderr" | awk '{s+=$4} END{print s+0}')
# rc=0 만으로는 통과가 아니다 — 압축 해제·읽기 실패로 줄어든 입력도 bwa는 rc=0으로 받는다(프로세스 치환의 실패는 pipefail에 안 잡힌다,
# Codex 리뷰). 기대 리드 수(EXPECTED_READS: 보낸 페어 × 2)를 주면 처리 수와 대조하고, 안 주면 '미검증'으로 적는다.
if [ "$rc" = 134 ] || [ "$rc" = 139 ]; then v="죽음(rc $rc) — 뒤쪽에도 죽는 자리가 있다"
elif [ "$rc" != 0 ]; then v="판정 불가(rc $rc)"
elif [ -z "${EXPECTED_READS:-}" ]; then v="rc=0이지만 미검증(EXPECTED_READS 없음)"
elif [ "$got" = "$EXPECTED_READS" ]; then v="PASS(기대 $EXPECTED_READS 와 일치)"
else v="FAIL: 처리 $got != 기대 $EXPECTED_READS — 입력이 중간에 끊겼다"; fi
log "bwa-mem2 rc=$rc, 처리된 리드 $got (페어 $((got / 2))) → $v"
log "DONE"
