#!/bin/bash
# 진행 대시보드 (읽기 전용, 로그인 노드).
#   scripts/20_status.sh [dsid ...]     인자 없으면 38개 전부
#   DU=1 scripts/20_status.sh           디스크 사용량도 표시 (NFS라 느릴 수 있음)
#
# stages 열: A=정렬BAM D=DeepVariant C=Clair3 S=pbsv P=phased VCF
#            '=' 는 aligned_bam 진입(GIAB BAM 그대로 사용, 02_alignedBAM 미발행이 정상)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
PHASE1="$(cd "$HERE/.." && pwd)"
RT="$PHASE1/run_table.tsv"
IM="$PHASE1/inputs_manifest.tsv"

QSTAT="$(qstat -u "${USER:-$(whoami)}" 2>/dev/null || true)"

row() { awk -F'\t' -v d="$1" '$1==d {print; exit}' "$RT"; }
col() { echo "$1" | cut -f"$2"; }

inputs_state() {  # dsid -> "ready" | "miss k/n"
    local tot=0 miss=0 f rel sz
    while IFS=$'\t' read -r _ rel sz; do
        tot=$((tot + 1))
        f="$GIAB_ROOT/$rel"
        if [ ! -f "$f" ] || [ "$(stat -c%s "$f" 2>/dev/null || echo -1)" != "$sz" ]; then
            miss=$((miss + 1))
        fi
    done < <(awk -F'\t' -v d="$1" '$1==d' "$IM")
    if [ "$miss" = 0 ]; then echo ready; else echo "miss $miss/$tot"; fi
}

job_state() {  # dsid -> qstat state (r/qw/Eqw...) 또는 '-'
    local idf="$INFRA/jobs/$1.jobid" jid st
    [ -f "$idf" ] || { echo -; return; }
    jid=$(cat "$idf")
    st=$(echo "$QSTAT" | awk -v j="$jid" 'NR>2 && $1==j {print $5; exit}')
    echo "${st:--}"
}

flag() { [ -s "$1" ] && printf '%s' "$2" || printf -- '-'; }

if [ $# -gt 0 ]; then dsids=("$@"); else mapfile -t dsids < <(awk -F'\t' 'NR>1 {print $1}' "$RT"); fi

printf '%-46s %-10s %-5s %-6s %s\n' dsid input job ADCSP dup_of
n_ready=0; n_queued=0; n_done=0
for dsid in "${dsids[@]}"; do
    r=$(row "$dsid")
    [ -n "$r" ] || { echo "?? $dsid: run_table.tsv에 없음"; continue; }
    sample=$(col "$r" 2); dataset=$(col "$r" 3); entry=$(col "$r" 4); dup=$(col "$r" 8)
    base="$RUN_BASE/$sample/PacBio/$dataset"
    id="$sample.$dataset.$REF_NAME"

    inp=$(inputs_state "$dsid"); [ "$inp" = ready ] && n_ready=$((n_ready + 1))
    js=$(job_state "$dsid");     [ "$js" != - ] && n_queued=$((n_queued + 1))

    if [ "$entry" = aligned_bam ]; then A='='; else A=$(flag "$base/02_alignedBAM/$id.bam" A); fi
    D=$(flag "$base/03_VCF/deepvariant/$id.deepvariant.vcf.gz" D)
    C=$(flag "$base/03_VCF/clair3/$id.clair3.vcf.gz" C)
    S=$(flag "$base/03_VCF/SV_pbsv/$id.pbsv.vcf.gz" S)
    P=$(flag "$base/03_VCF/phased_whatshap/$id.deepvariant.phased.vcf.gz" P)
    [ "$D$C$S" = DCS ] && n_done=$((n_done + 1))

    printf '%-46s %-10s %-5s %s%s%s%s%s %s\n' "$dsid" "$inp" "$js" "$A" "$D" "$C" "$S" "$P" "$dup"
done

echo
echo "입력 준비 $n_ready/${#dsids[@]} | 큐/실행 중 $n_queued | VCF 3종 완료 $n_done"
if [ "${DU:-0}" = 1 ]; then
    du -sh "$RUN_BASE" "$INFRA/work" 2>/dev/null || true
fi
