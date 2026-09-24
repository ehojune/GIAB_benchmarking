#!/bin/bash
# 국통바빅(biko) set 하나를 Java 17 래퍼로 제출한다 — 2026-09-21 Codex 앱 세션의 래퍼(submit-example.sh)와 같은 내용.
# 공용 파이프라인(/BiO/scratch/dyl/kbb/zz.code/regermline.sh)은 건드리지 않고, 잡 안에서 JAVA_HOME/PATH만 Java 17로 바꾼다
# (GATK 4.6.1.0 MarkDuplicatesSpark가 Java 17을 요구). regermline.sh = germline.sh + --rerun-triggers mtime --rerun-incomplete 라
# 처음 돌리는 set에도 그대로 쓴다.
#
#   bash 10_submit_java17.sh <SET_DIR> [HOLD_JID] [PRIORITY]      # 제출하고 잡 번호를 stdout 마지막 줄에
#   DRY=1 bash 10_submit_java17.sh <SET_DIR>                      # 검사만
# 멈추는 경우(제출 안 함, exit 3): __DONE__ 가 Success · .snakemake/locks 비지 않음 · 같은 이름 잡이 큐에 있음 ·
#   샘플 dir 중 _1/_2.fastq.gz 가 링크도 완성 파일도 아닌 것(병합 lock·.part 남음)이 있음.
set -uo pipefail
SET=$(cd "${1:?SET_DIR}" && pwd); HOLD=${2:-}; PRIO=${3:-0}
HOSTS=${SGE_HOSTS:-(octopus-2-8|octopus-2-9|octopus-2-10|octopus-2-11|shepherd-1-8|shepherd-1-9)}
NAME="regermline_java17_$(basename "$SET")"
no() { echo "SKIP $(basename "$SET"): $*" >&2; exit 3; }
grep -q "Success" "$SET/__DONE__" 2>/dev/null && no "__DONE__ 가 이미 Success — 다시 돌리지 않는다"
[ -n "$(ls -A "$SET/.snakemake/locks" 2>/dev/null)" ] && no "Snakemake lock 있음(도는 중이거나 죽은 실행의 흔적)"
qstat -u "$USER" -r 2>/dev/null | grep -q "Full jobname: *$NAME\$" && no "같은 이름 잡($NAME)이 이미 큐에 있다"
n=0; bad=""
for sd in "$SET"/outcome/*/; do
  b=$(basename "$sd"); n=$((n + 1))
  [ -d "$sd/.concat.lock" ] && { bad="$bad $b(병합중)"; continue; }
  for m in 1 2; do   # mate마다 따로: 살아 있는 링크이거나 완성된 파일이어야 하고 .part가 없어야 한다(Codex 리뷰)
    f="$sd/${b}_$m.fastq.gz"
    { [ -s "$f" ] && [ ! -e "$f.part" ]; } || bad="$bad $b(_$m)"
  done
done
[ "$n" -gt 0 ] || no "outcome/ 아래 샘플이 없다"
[ -z "$bad" ] || no "준비 안 된 샘플:$bad"
echo "OK $(basename "$SET"): 샘플 $n, hold=${HOLD:-없음}, priority=$PRIO"
[ "${DRY:-0}" = 1 ] && exit 0
mkdir -p "$SET/log"
cd "$SET" || exit 2
out=$(qsub -terse -N "$NAME" -p "$PRIO" ${HOLD:+-hold_jid "$HOLD"} -q octopus.q,shepherd.q -pe pe_slots 60 -l h_vmem=300G -l "h=$HOSTS" \
  -S /bin/bash -cwd -V -j y -o "$SET/log" <<'JOB'
#!/bin/bash
set -eo pipefail
source /BiO/scratch/dyl/kbb/bashrc.txt
export JAVA_HOME=/BiO/scratch/dyl/apps/miniconda3/lib/jvm
test -x "$JAVA_HOME/bin/java"
export PATH="$JAVA_HOME/bin:$PATH"
hash -r
command -v java
java -version
/BiO/scratch/dyl/kbb/UTILS/Tools/gatk/gatk-4.6.1.0/gatk --java-options '-Xmx512m' --version
exec /bin/bash /BiO/scratch/dyl/kbb/zz.code/regermline.sh "$PWD"
JOB
) || { echo "FAIL qsub: $out" >&2; exit 1; }
echo "$out"
