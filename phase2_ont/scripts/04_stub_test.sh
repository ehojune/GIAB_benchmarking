#!/bin/bash
# 파이프라인 배선 스모크 테스트 (로그인 노드, 1분 안). 컨테이너·데이터 없이 채널 배선과
# 산출 파일명 규약만 본다 — 빈 파일 + `-stub` 으로 프로세스의 stub 블록만 실행한다.
#
#   bash phase2_ont/scripts/04_stub_test.sh
#   KEEP=1 bash phase2_ont/scripts/04_stub_test.sh   끝나고 산출물/work을 남긴다
#
# **nextflow를 직접 부르지 말고 이 스크립트를 쓸 것.** 서버 기본 nextflow는 26.x이고
# 그 strict config 파서는 `def` 선언을 거부한다 ("Variable declarations cannot be mixed
# with config statements"). nextflow.config와 conf/kobic.config가 둘 다 def를 쓰므로
# env.sh의 NXF_VER=24.10.5 고정을 반드시 거쳐야 한다.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
PIPE="$(cd "$HERE/../pipeline/ont-wgs" && pwd)"

OUT="$INFRA/tmp/stub"
WORK="$INFRA/tmp/stub_work"
LAUNCH="$INFRA/tmp/stub_launch"
rm -rf "$OUT" "$WORK" "$LAUNCH"
mkdir -p "$OUT" "$WORK" "$LAUNCH"

# repo 루트에서 돌리면 .nextflow/cache(LevelDB)가 커밋되는 사고가 있었다 (phase1 교훈)
cd "$LAUNCH"
echo "== nextflow 버전 (24.10.x여야 한다) =="
nextflow -version | grep -m1 version

echo "== stub 실행 =="
nextflow run "$PIPE" -profile test -stub \
    -work-dir "$WORK" -ansi-log false --outdir "$OUT"

echo
echo "== 산출 파일명 검증 =="
# test 프로파일: sample=TEST dataset=ont_smoke ref_name=test -> id = TEST.ont_smoke
B="$OUT/TEST/ONT/ont_smoke"
ID="TEST.ont_smoke.test"
need=(
    "02_alignedBAM/$ID.bam"
    "02_alignedBAM/$ID.bam.bai"
    "02_alignedBAM/haplotagged/$ID.haplotagged.bam"
    "03_VCF/clair3/$ID.clair3.vcf.gz"
    "03_VCF/deepvariant/$ID.deepvariant.vcf.gz"
    "03_VCF/SV_sniffles/$ID.sniffles.vcf.gz"
    "03_VCF/phased_longphase/$ID.clair3.phased.vcf.gz"
    "03_VCF/phased_longphase/$ID.clair3.sv_phased.vcf.gz"
    "03_VCF/SNV_clair3/$ID.clair3.snv.vcf.gz"
    "03_VCF/INDEL_clair3/$ID.clair3.indel.vcf.gz"
    "04_QC/mosdepth/$ID.mosdepth.summary.txt"
    "04_QC/samtools/$ID.stats.txt"
)
bad=0
for f in "${need[@]}"; do
    if [ -f "$B/$f" ]; then printf '  OK   %s\n' "$f"
    else printf '  누락 %s\n' "$f"; bad=1; fi
done
[ -f "$OUT/multiqc/run/multiqc_report.html" ] && echo "  OK   multiqc/run/multiqc_report.html" \
    || { echo "  누락 multiqc/run/multiqc_report.html"; bad=1; }

echo
if [ "$bad" = 0 ]; then
    echo "배선 OK — 프로세스 22개가 다 돌고 파일명 규약도 맞다."
    echo "(stub이라 내용은 빈 파일이다. 실제 계산은 10_submit.sh 로.)"
else
    echo "FAIL: 위 누락 항목을 확인할 것. $WORK 의 .command.err 에 이유가 있다."
fi
if [ "${KEEP:-0}" != 1 ]; then
    rm -rf "$OUT" "$WORK" "$LAUNCH"
else
    echo "산출물 유지: $OUT (work: $WORK)"
fi
exit "$bad"
