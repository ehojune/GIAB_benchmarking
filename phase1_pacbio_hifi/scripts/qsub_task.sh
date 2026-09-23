#!/bin/bash
# 로그인 노드용 스크립트를 SGE 잡 하나로 감싸 돌린다.
#
#   bash phase1_pacbio_hifi/scripts/qsub_task.sh <이름> [-s 슬롯] [-w jobid] -- <명령...>
#
#   예) ts/tv 전 런:   qsub_task.sh tstv -s 2 -- env TSV=/경로/out.tsv bash phase1_pacbio_hifi/scripts/62_tstv_regions.sh
#       잡 끝난 뒤 QC: qsub_task.sh qc -w 156072 -- bash -c 'bash .../30_verify_outputs.sh; python3 .../35_review_qc.py --pass-counts'
#
# 왜: 35_review_qc.py --pass-counts 나 62_tstv_regions.sh 는 런당 수 분이라 전 런이면 한두 시간을
# 로그인 노드에 붙잡는다. 로그인 노드는 공용이고 접속 세션이 끊기면 같이 죽는다.
#
# - 명령은 제출한 디렉토리에서 돈다 (상대경로가 그대로 통한다). 셸 기능(; > |)이 필요하면 bash -c '...'.
# - -w 는 qsub -hold_jid. 앞 잡이 끝나야 시작한다 (성공 여부는 안 본다 — SGE 규약).
# - 출력: $INFRA/logs/task.<이름>.<jobid>.log
# - 큐·노드 해석은 다른 제출 스크립트와 같다 (lib.sh 의 p1_require_sge_targets).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[ $# -ge 1 ] || usage
name=$1; shift
case "$name" in -*|"") usage ;; esac
[[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ERROR: 이름은 영문·숫자·._- 만 ($name)"; exit 1; }
slots=4 hold=""
while [ $# -gt 0 ]; do
    case "$1" in
        -s) slots=${2:?}; shift 2 ;;
        -w) hold=${2:?}; shift 2 ;;
        --) shift; break ;;
        *)  usage ;;
    esac
done
[ $# -gt 0 ] || usage
[[ "$slots" =~ ^[0-9]+$ ]] || { echo "ERROR: 슬롯은 정수 ($slots)"; exit 1; }

p1_qstat_refresh
p1_require_sge_targets || exit 1
q="$(p1_sge_queue_arg)"
mkdir -p "$INFRA/jobs" "$INFRA/logs"

job="$INFRA/jobs/task.$name.sh"
printf -v cmd '%q ' "$@"
# 로그에 찍을 명령은 따로 파일로 둔다. %q 출력(여러 줄이면 $'...' 꼴)을 echo "..." 안에 넣으면
# 따옴표가 깨지거나 $(...) 가 로그 찍을 때 한 번 더 실행된다 (PR #38 Codex 지적).
printf '%s\n' "$cmd" > "$job.cmd" || { echo "FAIL: $job.cmd 를 못 썼다"; exit 1; }
if ! cat > "$job" <<EOF
#!/bin/bash
#\$ -N t.$name
#\$ -q $q
#\$ -pe $SGE_PE $slots
#\$ -S /bin/bash
#\$ -V
#\$ -j y
#\$ -o $INFRA/logs/task.$name.\$JOB_ID.log
#\$ -l h='$SGE_HOSTS'
#\$ -wd $PWD
set -euo pipefail
source "$P1_DIR/env.sh"
echo "== \$(date '+%F %T') \$(hostname) slots=\${NSLOTS:-?} =="
echo "== cmd:"; cat "$job.cmd"
$cmd
echo "== DONE \$(date '+%F %T') =="
EOF
then
    echo "FAIL: 잡 스크립트를 못 썼다 — $job"; exit 1
fi
chmod +x "$job"

args=()
[ -n "$hold" ] && args+=(-hold_jid "$hold")
out=$(qsub ${args[@]+"${args[@]}"} "$job" < /dev/null 2>&1) || { echo "FAIL: qsub 거부 — $out"; exit 1; }
jid=$(echo "$out" | grep -oE '[0-9]+' | head -1)
[ -n "$jid" ] || { echo "FAIL: qsub 출력에서 jobid를 못 읽었다 — $out"; exit 1; }
echo "OK  t.$name jobid=$jid slots=$slots${hold:+ hold=$hold}  log: $INFRA/logs/task.$name.$jid.log"
