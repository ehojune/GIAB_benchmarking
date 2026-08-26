#!/bin/bash
# 완료된 HiFi 런 전부의 QC를 **하나의 MultiQC 리포트**로 합친다 (로그인 노드, 읽기 전용 입력).
#
# 파이프라인은 런마다 multiqc/<dsid>/multiqc_report.html 을 따로 만든다 (--outdir을 공유하니
# run_label로 네임스페이스를 갈라 놨다). 런 사이를 비교하려면 38개를 번갈아 열어야 해서
# 이 스크립트가 전 런의 04_QC + 위상 통계를 한 번에 스캔해 리포트 하나로 만든다.
# phase2_ont/scripts/36_multiqc_all.sh 와 같은 스크립트다 (경로만 PacBio/phased_whatshap).
#
#   bash phase1_pacbio_hifi/scripts/36_multiqc_all.sh              완료된 런 전부
#   bash phase1_pacbio_hifi/scripts/36_multiqc_all.sh <dsid> ...   지정한 런만
#   OUT=<경로> bash ...                                            출력 위치 (기본 $RUN_BASE/multiqc/_all_hifi)
#
# 산출: $OUT/multiqc_report.html  (브라우저로 열면 런별 커버리지·매핑률·변이수·위상이 한 표에)
#       $OUT/multiqc_report_data/ (MultiQC가 파싱한 원본 수치. TSV로 떨어져 재사용 가능)
#       $OUT/included_runs.txt    (어떤 런이 들어갔는지 — 리포트만 보고는 알 수 없어서 남긴다)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

OUT="${OUT:-$RUN_BASE/multiqc/_all_hifi}"
NF_CONFIG="$HERE/../pipeline/pacbio-hifi-wgs/nextflow.config"
MQ_URI=$(grep -oE "container_multiqc *= *'[^']+'" "$NF_CONFIG" | cut -d"'" -f2)
IMG="$NXF_SINGULARITY_CACHEDIR/$(echo "$MQ_URI" | sed 's#[/:]#-#g').img"
[ -s "$IMG" ] || { echo "ERROR: multiqc 컨테이너가 없다 ($IMG) — 01_prepare_login_node.sh 먼저"; exit 1; }

if [ $# -gt 0 ]; then dsids=("$@"); else mapfile -t dsids < <(p1_dsids); fi

mkdir -p "$OUT"
: > "$OUT/included_runs.txt"
scan=()
n_done=0 n_skip=0
for dsid in "${dsids[@]}"; do
    r=$(p1_row "$dsid")
    [ -n "$r" ] || { echo "?? $dsid: run_table.tsv에 없음"; continue; }
    sample=$(p1_col "$r" 2); dataset=$(p1_col "$r" 3)
    base="$RUN_BASE/$sample/PacBio/$dataset"
    if ! p1_vcf_done "$sample" "$dataset"; then
        n_skip=$((n_skip + 1)); continue
    fi
    # 04_QC = mosdepth/samtools/bcftools stats, phased_whatshap = whatshap stats
    [ -d "$base/04_QC" ] && scan+=("$base/04_QC")
    [ -d "$base/03_VCF/phased_whatshap" ] && scan+=("$base/03_VCF/phased_whatshap")
    printf '%s\t%s\n' "$dsid" "$(p1_col "$r" 6)" >> "$OUT/included_runs.txt"
    n_done=$((n_done + 1))
done

[ "$n_done" -gt 0 ] || { echo "합칠 완료 런이 없다 (미완 $n_skip건). 20_status.sh 로 확인할 것"; exit 1; }
echo "완료 런 $n_done건을 합친다 (미완 $n_skip건 제외). 스캔 대상 디렉토리 ${#scan[@]}개"

# 파일명이 <sample>.<dataset>.<ref>.* 라서 MultiQC가 런을 구분해 이름을 붙인다.
singularity exec --bind "$RUN_BASE" "$IMG" \
    multiqc -f -o "$OUT" -n multiqc_report.html \
        --title "GIAB PacBio HiFi phase1 (${n_done} runs)" \
        --comment "phase1_pacbio_hifi/scripts/36_multiqc_all.sh — 런 목록은 included_runs.txt" \
        "${scan[@]}"

echo
echo "리포트: $OUT/multiqc_report.html"
echo "  런 목록: $OUT/included_runs.txt  (dsid / clair3 모델)"
echo "  파싱된 수치: $OUT/multiqc_report_data/"
echo
echo "수치를 표로 보려면: python $HERE/35_review_qc.py --tsv qc_review_hifi.tsv"
