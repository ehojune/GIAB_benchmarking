#!/bin/bash
# 진행 대시보드 (읽기 전용, 로그인 노드).
#   scripts/20_status.sh [dsid ...]     인자 없으면 run_table 전체
#   DU=1 scripts/20_status.sh           디스크 사용량도 표시 (NFS라 느릴 수 있음)
#
# input 열: ready = 전부 받아짐 / settling = 크기는 맞지만 최근 쓰인 파일 있음(다운로드 중일 수 있음)
#           / miss k/n = 아직 없거나 크기 불일치
# ACDSPH 열: A=정렬BAM C=Clair3 D=DeepVariant S=Sniffles P=phased VCF H=haplotag BAM
#            '=' 는 aligned_bam 진입(GIAB BAM 그대로 사용), '.' 는 이 런에서 안 돌리는 단계(R9의 DeepVariant)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

flag() { [ -s "$1" ] && printf '%s' "$2" || printf -- '-'; }

if [ $# -gt 0 ]; then dsids=("$@"); else mapfile -t dsids < <(p2_dsids); fi
p2_qstat_refresh

printf '%-48s %-13s %-5s %-7s %s\n' dsid input job ACDSPH dup_of
n_ready=0; n_queued=0; n_done=0
for dsid in "${dsids[@]}"; do
    r=$(p2_row "$dsid")
    [ -n "$r" ] || { echo "?? $dsid: run_table.tsv에 없음"; continue; }
    sample=$(p2_col "$r" 2); dataset=$(p2_col "$r" 3); entry=$(p2_col "$r" 4)
    dv=$(p2_col "$r" 10); dup=$(p2_col "$r" 12)
    base="$RUN_BASE/$sample/ONT/$dataset"
    id="$sample.$dataset.$REF_NAME"

    inp=$(p2_inputs_state "$dsid"); [ "$inp" = ready ] && n_ready=$((n_ready + 1))
    js=$(p2_job_state "$dsid");     [ "$js" != - ] && n_queued=$((n_queued + 1))

    if [ "$entry" = aligned_bam ]; then A='='; else A=$(flag "$base/02_alignedBAM/$id.bam" A); fi
    C=$(flag "$base/03_VCF/clair3/$id.clair3.vcf.gz" C)
    if [ "$dv" = - ]; then D='.'; else D=$(flag "$base/03_VCF/deepvariant/$id.deepvariant.vcf.gz" D); fi
    S=$(flag "$base/03_VCF/SV_sniffles/$id.sniffles.vcf.gz" S)
    P=$(flag "$base/03_VCF/phased_longphase/$id.clair3.phased.vcf.gz" P)
    H=$(flag "$base/02_alignedBAM/haplotagged/$id.haplotagged.bam" H)
    p2_vcf_done "$sample" "$dataset" "$dv" && n_done=$((n_done + 1))

    printf '%-48s %-13s %-5s %s%s%s%s%s%s %s\n' "$dsid" "$inp" "$js" "$A" "$C" "$D" "$S" "$P" "$H" "$dup"
done

echo
echo "입력 준비 $n_ready/${#dsids[@]} | 큐/실행 중 $n_queued | 변이 호출 완료 $n_done"
if [ "${DU:-0}" = 1 ]; then
    du -sh "$RUN_BASE" "$INFRA/work" 2>/dev/null || true
fi
