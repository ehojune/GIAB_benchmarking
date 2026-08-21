#!/bin/bash
# 진행 대시보드 (읽기 전용, 로그인 노드).
#   scripts/20_status.sh [dsid ...]     인자 없으면 38개 전부
#   DU=1 scripts/20_status.sh           디스크 사용량도 표시 (NFS라 느릴 수 있음)
#
# input 열: ready = 전부 받아짐 / settling = 크기는 맞지만 최근 쓰인 파일 있음(다운로드 중일 수 있음)
#           / miss k/n = 아직 없거나 크기 불일치
# ADCSP 열: A=정렬BAM D=DeepVariant C=Clair3 S=pbsv P=phased VCF
#           '=' 는 aligned_bam 진입(GIAB BAM 그대로 사용, 02_alignedBAM 미발행이 정상)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

flag() { [ -s "$1" ] && printf '%s' "$2" || printf -- '-'; }

if [ $# -gt 0 ]; then dsids=("$@"); else mapfile -t dsids < <(p1_dsids); fi
p1_qstat_refresh

printf '%-46s %-13s %-5s %-6s %s\n' dsid input job ADCSP dup_of
n_ready=0; n_queued=0; n_done=0
for dsid in "${dsids[@]}"; do
    r=$(p1_row "$dsid")
    [ -n "$r" ] || { echo "?? $dsid: run_table.tsv에 없음"; continue; }
    sample=$(p1_col "$r" 2); dataset=$(p1_col "$r" 3); entry=$(p1_col "$r" 4); dup=$(p1_col "$r" 8)
    base="$RUN_BASE/$sample/PacBio/$dataset"
    id="$sample.$dataset.$REF_NAME"

    inp=$(p1_inputs_state "$dsid"); [ "$inp" = ready ] && n_ready=$((n_ready + 1))
    js=$(p1_job_state "$dsid");     [ "$js" != - ] && n_queued=$((n_queued + 1))

    if [ "$entry" = aligned_bam ]; then A='='; else A=$(flag "$base/02_alignedBAM/$id.bam" A); fi
    D=$(flag "$base/03_VCF/deepvariant/$id.deepvariant.vcf.gz" D)
    C=$(flag "$base/03_VCF/clair3/$id.clair3.vcf.gz" C)
    S=$(flag "$base/03_VCF/SV_pbsv/$id.pbsv.vcf.gz" S)
    P=$(flag "$base/03_VCF/phased_whatshap/$id.deepvariant.phased.vcf.gz" P)
    [ "$D$C$S" = DCS ] && n_done=$((n_done + 1))

    printf '%-46s %-13s %-5s %s%s%s%s%s %s\n' "$dsid" "$inp" "$js" "$A" "$D" "$C" "$S" "$P" "$dup"
done

echo
echo "입력 준비 $n_ready/${#dsids[@]} | 큐/실행 중 $n_queued | VCF 3종 완료 $n_done"
if [ "${DU:-0}" = 1 ]; then
    du -sh "$RUN_BASE" "$INFRA/work" 2>/dev/null || true
fi
