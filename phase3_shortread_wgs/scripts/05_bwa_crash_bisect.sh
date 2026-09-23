#!/bin/bash
# bwa-mem2가 매번 같은 청크에서 죽을 때(2026-09-23 MGISEQ HG002: 두 번 다 946,145,492 리드 처리 뒤 segfault)
# 그 청크를 잘라내 재현하고, 이분법으로 죽이는 리드 쌍을 찾는다. SIMD 빌드별(avx512bw/avx2/sse42)로도 같은 청크를 돌려 본다.
#
#   qsub -N bwa_bisect -pe pe_slots 10 -l h_vmem=60G ... 05_bwa_crash_bisect.sh <RUN_DIR> <OUT_DIR>
#     RUN_DIR: 죽은 재정렬 dir — R1.trimmed.fastq.gz, R2.trimmed.fastq.gz, bwa.stderr (repairs/mgi_hg002_recheck.sh 산출)
#     OUT_DIR: 새로 만든다. 결과는 OUT_DIR/result.txt
#   환경변수: BWA_DIR(bwa-mem2 빌드들이 있는 dir), REF, THREADS(기본 NSLOTS 또는 10), PIGZ(기본 pigz)
#     BWA_EXTRA  bwa-mem2 mem 에 덧붙일 인자
#     CHUNK_R1/CHUNK_R2  이미 잘라 둔 청크(예: 앞 실행의 min_R1.fq). 주면 1·2단계(위치 계산·추출)를 건너뛴다. FULL_R1/FULL_R2는 5단계 확인용 큰 청크
#     SKIP_BUILDS=1  SIMD 빌드별 비교를 건너뛴다
# 2026-09-24 첫 실행: 청크 재현은 됐지만 651 페어 창에서 두 반쪽이 다 안 죽었다. 죽는 곳은 worker_bwt(시드 찾기)이고 그 청크의
# 삽입 크기 추정보다 **앞**이라 분포 탓은 아니다. 한 리드가 힙을 망가뜨리고, 실제로 죽는지는 배치의 메모리 배치에 달린 것으로 본다.
# 그래서 창이 4 페어보다 크게 남으면 5단계: 이상 리드 훑기 + 블록 빼기 → 한 쌍 빼기로 '빼면 안 죽는' 쌍을 찾고, 큰 청크에서 그 쌍만
# 빼도 안 죽는지 확인한다(힙 오염이면 아무 쌍이나 빼도 배치가 바뀌어 안 죽을 수 있어서, 후보는 큰 청크에서 다시 본다).
#
# 원본을 바꾸지 않는다. 청크 추출은 gzip이라 그 지점까지 순차 해제가 필요하다(87 GB 파일의 65% 지점 — 수십 분).
set -uo pipefail
RUN_DIR=${1:?RUN_DIR}; OUT=${2:?OUT_DIR}
BWA_DIR=${BWA_DIR:-/BiO/scratch/dyl/kbb/UTILS/Tools/bwa-mem2_amd/bwa-mem2-2.2.1}
REF=${REF:-/BiO/scratch/dyl/kbb/UTILS/Reference/GATK_bundle/Homo_sapiens_assembly38.fasta}
THREADS=${THREADS:-${NSLOTS:-10}}; PIGZ=${PIGZ:-pigz}
mkdir -p "$OUT" || exit 2
log() { echo "[$(date '+%F %T')] $*" | tee -a "$OUT/result.txt"; }
log "RUN_DIR=$RUN_DIR HOST=$(hostname) THREADS=$THREADS BWA_DIR=$BWA_DIR"

if [ -n "${CHUNK_R1:-}" ]; then
  cp "$CHUNK_R1" "$OUT/chunk_R1.fq" && cp "$CHUNK_R2" "$OUT/chunk_R2.fq" || exit 2
  NP=$(($(wc -l < "$OUT/chunk_R1.fq") / 4)); START=${CHUNK_START:-0}
  log "주어진 청크 사용: $CHUNK_R1 ($NP 페어, 전체 페어 기준 시작 $START) BWA_EXTRA='${BWA_EXTRA:-}'"
else
# 1) 죽은 청크의 위치: 끝까지 처리된 리드 수 합 = 청크 시작(리드 단위, mate 둘 다 센다). 그 뒤 '읽었지만 처리 못 한' 청크 둘을 덮는다
read -r P NPROC < <(grep "Processed .* reads" "$RUN_DIR/bwa.stderr" | awk '{s+=$4; n++} END{print s+0, n+0}')
mapfile -t RD < <(grep -o "kt_pipeline\] read [0-9]* sequences" "$RUN_DIR/bwa.stderr" | awk '{print $3}')
C1=${RD[$NPROC]:-0}; C2=${RD[$((NPROC + 1))]:-0}
[ "$P" -gt 0 ] && [ $((P % 2)) = 0 ] && [ "$C1" -gt 0 ] || { log "ERROR: bwa.stderr에서 청크 위치를 못 구함 P=$P NPROC=$NPROC C1=$C1"; exit 2; }
START=$((P / 2)); NP=$(((C1 + C2) / 2))
log "처리된 청크 $NPROC개 = 리드 $P → 죽은 청크는 페어 $START 부터 (청크 리드 $C1 + 다음 $C2 → 페어 $NP개 추출)"

# 2) 추출: 페어 [START, START+NP) = 줄 (START*4, (START+NP)*4]. awk가 끝에서 나가면 pigz는 SIGPIPE — 정상
S=$((START * 4)); E=$(((START + NP) * 4))
for m in 1 2; do
  ( "$PIGZ" -dc "$RUN_DIR/R$m.trimmed.fastq.gz" 2>/dev/null | awk -v s=$S -v e=$E 'NR>s && NR<=e {print} NR>e {exit}' > "$OUT/chunk_R$m.fq" ) &
done
wait
n1=$(wc -l < "$OUT/chunk_R1.fq"); n2=$(wc -l < "$OUT/chunk_R2.fq")
h1=$(head -1 "$OUT/chunk_R1.fq" | cut -d' ' -f1 | sed 's#/1$##'); h2=$(head -1 "$OUT/chunk_R2.fq" | cut -d' ' -f1 | sed 's#/2$##')
log "추출: R1 $n1 줄, R2 $n2 줄 (기대 $((NP * 4))), 첫 이름 $h1 / $h2"
[ "$n1" = $((NP * 4)) ] && [ "$n2" = "$n1" ] && [ "$h1" = "$h2" ] || { log "ERROR: 추출 줄 수·짝 불일치"; exit 2; }
fi

# 3) 재현: 같은 인자(-Y -K 100000000 -t THREADS). 신호로 죽으면 rc>128
RG='@RG\tID:bisect\tSM:bisect\tPL:ILLUMINA\tLB:UNKNOWN'
try() {   # try <binary> <R1> <R2> -> rc (stdout 버림)
  # shellcheck disable=SC2086
  "$1" mem -Y -R "$RG" -v 1 -t "$THREADS" -K 100000000 ${BWA_EXTRA:-} "$REF" "$2" "$3" > /dev/null 2> "$OUT/last.stderr"; echo $?
}
BIN=$BWA_DIR/bwa-mem2
rc=$(try "$BIN" "$OUT/chunk_R1.fq" "$OUT/chunk_R2.fq"); mode=$(grep -o "Executing in [A-Z0-9]* mode" "$OUT/last.stderr" | head -1)
log "재현(디스패처, $mode): rc=$rc"
for b in $([ "${SKIP_BUILDS:-0}" = 1 ] || echo avx2 sse42); do
  [ -x "$BWA_DIR/bwa-mem2.$b" ] || continue
  log "같은 청크, bwa-mem2.$b: rc=$(try "$BWA_DIR/bwa-mem2.$b" "$OUT/chunk_R1.fq" "$OUT/chunk_R2.fq")"
done
if [ "$rc" -le 128 ]; then log "청크만으로는 재현 안 됨(rc=$rc) — 앞 청크들과의 상호작용이거나 비결정적. 이분법 생략"; exit 0; fi

# 4) 이분법: [lo,hi) 페어 구간 중 죽는 쪽을 남긴다. 양쪽 다 안 죽으면 그 크기에서 멈추고 창을 남긴다
sub() {   # sub <lo> <hi> -> $OUT/sub_R{1,2}.fq
  for m in 1 2; do sed -n "$(($1 * 4 + 1)),$(($2 * 4))p" "$OUT/chunk_R$m.fq" > "$OUT/sub_R$m.fq"; done
}
lo=0; hi=$NP; step=0
while [ $((hi - lo)) -gt 1 ]; do
  step=$((step + 1)); mid=$(((lo + hi) / 2))
  sub $lo $mid; r=$(try "$BIN" "$OUT/sub_R1.fq" "$OUT/sub_R2.fq")
  if [ "$r" -gt 128 ]; then hi=$mid; log "step $step: [$lo,$mid) rc=$r → 여기"; continue; fi
  sub $mid $hi; r2=$(try "$BIN" "$OUT/sub_R1.fq" "$OUT/sub_R2.fq")
  if [ "$r2" -gt 128 ]; then lo=$mid; log "step $step: [$lo,$hi) rc=$r2 → 여기(앞쪽 rc=$r)"; continue; fi
  log "step $step: 두 반쪽 다 안 죽음(rc=$r/$r2) — 창 [$lo,$hi) ($((hi - lo)) 페어)에서 멈춘다. 리드 조합이 필요한 버그"; break
done
sub $lo $hi; cp "$OUT/sub_R1.fq" "$OUT/min_R1.fq"; cp "$OUT/sub_R2.fq" "$OUT/min_R2.fq"
log "최소 창: 청크 안 페어 [$lo,$hi) = 전체 페어 [$((START + lo)),$((START + hi))) — min_R1.fq/min_R2.fq"
if [ $((hi - lo)) -le 4 ]; then
  log "리드:"; paste -d'\n' <(awk 'NR%4==1' "$OUT/min_R1.fq") <(awk 'NR%4==1' "$OUT/min_R2.fq") | tee -a "$OUT/result.txt" >/dev/null
  awk 'NR%4==2{print "R1 len="length($0)" N="gsub(/N/,"N")" "substr($0,1,80)}' "$OUT/min_R1.fq" >> "$OUT/result.txt"
  awk 'NR%4==2{print "R2 len="length($0)" N="gsub(/N/,"N")" "substr($0,1,80)}' "$OUT/min_R2.fq" >> "$OUT/result.txt"
fi
rm -f "$OUT/sub_R1.fq" "$OUT/sub_R2.fq"
W=$((hi - lo))
[ "$W" -le 4 ] && { log "DONE"; exit 0; }

# 5) 이상 리드 훑기 — ACGTN 밖 문자, 길이, N 개수, 가장 긴 단일 염기 반복
for m in 1 2; do
  awk -v m=$m 'NR%4==1{n=$1} NR%4==2{L=length($0); x=$0; bad=gsub(/[^ACGTN]/,"",x); y=$0; nn=gsub(/N/,"",y);
     best=0; run=1; for(i=2;i<=L;i++){ if(substr($0,i,1)==substr($0,i-1,1)){run++; if(run>best)best=run}else run=1 }
     if(bad>0 || nn>10 || best>=40 || L<70) printf "R%s %s len=%d nonACGTN=%d N=%d homopolymer=%d
", m, n, L, bad, nn, best}' "$OUT/min_R$m.fq"
done > "$OUT/anomalies.txt"
log "이상 리드 후보 $(wc -l < "$OUT/anomalies.txt")건 (ACGTN 밖 문자·N>10·단일염기 반복≥40·길이<70) — anomalies.txt"
head -5 "$OUT/anomalies.txt" | while read -r l; do log "  $l"; done

# 6) 블록 빼기 → 한 쌍 빼기. without <lo> <hi> <src_prefix> : src 에서 페어 [lo,hi) 를 뺀 sub_R{1,2}.fq
without() {
  for m in 1 2; do awk -v a=$(($1 * 4)) -v b=$(($2 * 4)) 'NR<=a || NR>b' "$3_R$m.fq" > "$OUT/sub_R$m.fq"; done
}
B=$(((W + 19) / 20)); cand=""
for ((b0 = 0; b0 < W; b0 += B)); do
  b1=$((b0 + B)); [ $b1 -gt $W ] && b1=$W
  without $b0 $b1 "$OUT/min"; r=$(try "$BIN" "$OUT/sub_R1.fq" "$OUT/sub_R2.fq")
  log "블록 [$b0,$b1) 빼면 rc=$r"; [ "$r" -le 128 ] && cand="$cand $b0:$b1"
done
[ -z "$cand" ] && { log "어느 블록을 빼도 죽는다 — 원인 리드가 여럿이거나 창 전체 배치 문제. 여기서 멈춤"; log "DONE"; exit 0; }
nc=$(echo $cand | wc -w)
[ "$nc" -gt 3 ] && { log "빼면 안 죽는 블록이 $nc개 — 어느 블록이든 빼면 배치가 바뀌어 안 죽는 것으로 보인다(힙 배치 의존). 한 쌍 빼기는 생략"; log "DONE"; exit 0; }
one=""
for c in $cand; do
  b0=${c%:*}; b1=${c#*:}
  for ((i = b0; i < b1; i++)); do
    without $i $((i + 1)) "$OUT/min"; r=$(try "$BIN" "$OUT/sub_R1.fq" "$OUT/sub_R2.fq")
    [ "$r" -le 128 ] && { one="$one $i"; log "  페어 $i (전체 $((START + lo + i))) 하나만 빼면 rc=$r"; }
  done
done
[ -z "$one" ] && { log "한 쌍만 빼서 안 죽는 쌍은 없다"; log "DONE"; exit 0; }

# 7) 후보를 큰 청크(FULL_R1/2, 없으면 이번 청크 전체)에서 빼도 안 죽는지 — 힙 배치 우연이 아닌지 확인
FULL=${FULL_R1:+${FULL_R1%_R1.fq}}; FULL=${FULL:-$OUT/chunk}; FULL_START=${FULL_START:-$START}   # FULL 첫 페어의 전체 기준 번호
for i in $one; do
  g=$((START + lo + i - FULL_START))   # FULL 안 위치
  without $g $((g + 1)) "$FULL"; r=$(try "$BIN" "$OUT/sub_R1.fq" "$OUT/sub_R2.fq")
  n1=$(sed -n "$((i * 4 + 1))p" "$OUT/min_R1.fq"); s1=$(sed -n "$((i * 4 + 2))p" "$OUT/min_R1.fq"); s2=$(sed -n "$((i * 4 + 2))p" "$OUT/min_R2.fq")
  log "확인: 큰 청크($(($(wc -l < "${FULL}_R1.fq") / 4)) 페어)에서 페어 $i 만 빼면 rc=$r $([ "$r" -le 128 ] && echo '→ 원인 후보 확정' || echo '→ 여전히 죽음, 배치 우연')"
  log "  $n1 R1 len=${#s1} $s1"; log "  R2 len=${#s2} $s2"
done
rm -f "$OUT/sub_R1.fq" "$OUT/sub_R2.fq"
log "DONE"
