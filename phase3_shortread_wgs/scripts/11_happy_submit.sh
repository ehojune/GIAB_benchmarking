#!/bin/bash
# #7 최소 비교: 국통바빅 gVCF → GenotypeGVCFs(같은 GATK 4.6.1.0) → hap.py(phase1 이미지) vs NIST v4.2.1.
# 국통바빅 산출물은 gVCF뿐이다(<NON_REF> 블록) — 그대로 채점하지 않고 단일 샘플 genotyping 후 채점한다.
#   bash 11_happy_submit.sh [manifest.csv]        # 준비된 행만 제출, 잡 번호를 표로 출력
#   DRY=1 bash 11_happy_submit.sh                  # 검사만
# manifest는 CSV(hiware 전송이 탭을 지운다). 건너뜀: summary.csv 이미 있음 · 같은 이름 잡이 큐에 있음 · gVCF/tbi 없음.
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
MAN=${1:-$HERE/happy_manifest.csv}
G=/BiO/scratch/dyl/kbb/G000
GIAB=/BiO/scratch/ehojune/GIAB_benchmark
INFRA=$GIAB/processed_data_ehojune/_infra
OUT=$GIAB/processed_data_ehojune/phase3_shortread_wgs/07_happy
REF=/BiO/scratch/dyl/kbb/UTILS/Reference/GATK_bundle/Homo_sapiens_assembly38.fasta
IMG=$INFRA/containers/jmcdani20-hap.py-v0.3.12.img
GATK=/BiO/scratch/dyl/kbb/UTILS/Tools/gatk/gatk-4.6.1.0/gatk
HOSTS=${SGE_HOSTS:-(octopus-2-8|octopus-2-9|octopus-2-10|octopus-2-11|shepherd-1-8|shepherd-1-9)}
queued=$(qstat -u "$USER" -r 2>/dev/null | sed -n 's/.*Full jobname: *//p')
mkdir -p "$OUT/logs"
tail -n +2 "$MAN" | while IFS=, read -r label src hg plat set s; do
  d=$OUT/$label; name=happy7.$label
  gv=$G/$set/outcome/$s/${s}_v1.1.0.g.vcf.gz
  case $hg in HG002) tr=HG002_NA24385_son;; HG003) tr=HG003_NA24149_father;; HG004) tr=HG004_NA24143_mother;; *) echo "SKIP $label: HGID $hg"; continue;; esac
  t=$GIAB/release/AshkenazimTrio/$tr/NISTv4.2.1/GRCh38/${hg}_GRCh38_1_22_v4.2.1_benchmark
  [ -s "$d/$label.summary.csv" ] && { echo "SKIP $label: 이미 채점됨"; continue; }
  grep -qx "$name" <<<"$queued" && { echo "SKIP $label: 큐에 있음"; continue; }
  [ -s "$gv" ] && [ -s "$gv.tbi" ] || { echo "SKIP $label: gVCF 없음 $gv"; continue; }
  [ -s "$t.vcf.gz.tbi" ] && [ -s "${t}_noinconsistent.bed" ] || { echo "SKIP $label: truth 없음"; continue; }
  [ "${DRY:-0}" = 1 ] && { echo "READY $label"; continue; }
  mkdir -p "$d"
  jid=$(qsub -terse -N "$name" -q octopus.q,shepherd.q -pe pe_slots 16 -l h_vmem=56G -l "h=$HOSTS" \
    -S /bin/bash -V -j y -o "$OUT/logs/$label.\$JOB_ID.log" -wd "$d" <<JOB 2>&1
#!/bin/bash
set -eo pipefail
export APPTAINER_TMPDIR=$INFRA/tmp SINGULARITY_TMPDIR=$INFRA/tmp   # phase1 env.sh와 같게(SIF 풀기용)
SING=/home/ehojune/anaconda3/envs/nfcore312/bin/singularity   # phase1 env.sh의 conda env(apptainer+singularity 심링크). 잡 PATH엔 없다(156705–730 실패)
test -x \$SING || { echo "ERROR: \$SING 없음" >&2; exit 2; }
source /BiO/scratch/dyl/kbb/bashrc.txt   # bashrc가 unset 변수를 읽으므로 set -u는 그 뒤에
set -u
export JAVA_HOME=/BiO/scratch/dyl/apps/miniconda3/lib/jvm PATH=/BiO/scratch/dyl/apps/miniconda3/lib/jvm/bin:\$PATH
vcf=$d/$label.genotyped.vcf.gz
if [ ! -s "\$vcf.tbi" ]; then
  $GATK --java-options '-Xmx16g' GenotypeGVCFs -R $REF -V $gv -O \$vcf.part.vcf.gz
  mv \$vcf.part.vcf.gz \$vcf; mv \$vcf.part.vcf.gz.tbi \$vcf.tbi
fi
mkdir -p $d/tmp
\$SING exec -B $GIAB:$GIAB -B /BiO/scratch/dyl/kbb:/BiO/scratch/dyl/kbb $IMG /opt/hap.py/bin/hap.py \
  $t.vcf.gz \$vcf -f ${t}_noinconsistent.bed -r $REF -o $d/$label --threads \${NSLOTS:-16} \
  --scratch-prefix $d/tmp --logfile $d/$label.hap.py.log
echo "ALL DONE $label"
JOB
) || { echo "FAIL $label: $jid"; continue; }
  printf 'SUBMITTED\t%s\t%s\t%s\n' "$label" "$jid" "$d"
done
