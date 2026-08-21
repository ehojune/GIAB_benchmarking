#!/bin/bash
# 산출물 검증. 기대 파일이 전부 있고 비어 있지 않으면 dsid당 OK 한 줄.
# 사용법: scripts/30_verify_outputs.sh [dsid ...]    인자 없으면 run_table 전체. 미완이 있으면 exit 1.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
RT="$HERE/../run_table.tsv"

verify_one() {  # dsid -> 0 완전 / 1 미완 (누락 목록 출력)
    local dsid=$1 r sample dataset entry base id bad=0 f
    r=$(awk -F'\t' -v d="$dsid" '$1==d {print; exit}' "$RT")
    [ -n "$r" ] || { echo "?? $dsid: run_table.tsv에 없음"; return 1; }
    sample=$(echo "$r" | cut -f2); dataset=$(echo "$r" | cut -f3); entry=$(echo "$r" | cut -f4)
    base="$RUN_BASE/$sample/PacBio/$dataset"
    id="$sample.$dataset.$REF_NAME"

    local files=(
        "03_VCF/deepvariant/$id.deepvariant.vcf.gz"
        "03_VCF/deepvariant/$id.deepvariant.vcf.gz.tbi"
        "03_VCF/clair3/$id.clair3.vcf.gz"
        "03_VCF/clair3/$id.clair3.vcf.gz.tbi"
        "03_VCF/SV_pbsv/$id.pbsv.vcf.gz"
        "03_VCF/SV_pbsv/$id.pbsv.vcf.gz.tbi"
        "03_VCF/phased_whatshap/$id.deepvariant.phased.vcf.gz"
        "03_VCF/phased_whatshap/$id.deepvariant.phased.vcf.gz.tbi"
        "03_VCF/SNV_deepvariant/$id.deepvariant.snv.vcf.gz"
        "03_VCF/INDEL_deepvariant/$id.deepvariant.indel.vcf.gz"
        "03_VCF/SNV_clair3/$id.clair3.snv.vcf.gz"
        "03_VCF/INDEL_clair3/$id.clair3.indel.vcf.gz"
    )
    # aligned_bam 단독 입력은 재정렬·재발행 없이 원본 BAM을 그대로 쓰므로 02_alignedBAM이 비어 있는 게 정상
    if [ "$entry" != aligned_bam ]; then
        files+=("02_alignedBAM/$id.bam" "02_alignedBAM/$id.bam.bai")
    fi

    for f in "${files[@]}"; do
        [ -s "$base/$f" ] || { [ "$bad" = 0 ] && echo "-- $dsid"; echo "   누락: $base/$f"; bad=1; }
    done
    [ "$bad" = 0 ] && echo "OK $dsid"
    return "$bad"
}

if [ $# -gt 0 ]; then dsids=("$@"); else mapfile -t dsids < <(awk -F'\t' 'NR>1 {print $1}' "$RT"); fi
fail=0; done_n=0
for d in "${dsids[@]}"; do
    if verify_one "$d"; then done_n=$((done_n+1)); else fail=1; fi
done
echo "완료 $done_n / ${#dsids[@]}"
exit "$fail"
