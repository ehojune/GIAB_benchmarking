#!/bin/bash
# 파이프라인과 같은 fastp → bwa-mem2 → 정렬을 따로 돌려, 리드 수가 맞는 정렬 BAM을 만든다(검증 포함). 파이프라인 파일은 안 건드린다.
# repairs/mgi_hg002_recheck.sh(Codex, 2026-09-21)의 --rebuild 부분을 입력 경로를 받게 옮긴 것 — fastp·bwa 인자는 그 스크립트
# (= 2026-09-21에 확인한 파이프라인 규칙)와 같다. 다른 점: 입력을 인자로 받고, bwa 스레드를 NSLOTS로 쓴다(-K가 배치를 염기 수로 자르므로
# 스레드 수는 결과를 안 바꾼다), 원본 FASTQ 전수 검사(1~2시간)는 생략한다 — 뒤의 primary 리드 수 대조가 같은 것을 잡는다.
#
#   qsub -pe pe_slots 30 ... 08_rebuild_sorted_bam.sh <R1.fastq.gz> <R2.fastq.gz> <SAMPLE> <OUT_DIR>
#     SAMPLE: @RG ID/SM 에 들어가는 파이프라인 샘플 이름 (예: GIAB-publicData-MGISEQ2000-PCRfree-HG002)
#   끝나면 OUT_DIR/VALIDATED.txt (primary 리드 수 = fastp after_filtering). 실패면 exit ≠ 0, VALIDATED.txt 없음.
set -eo pipefail
R1=${1:?R1}; R2=${2:?R2}; S=${3:?SAMPLE}; OUT=${4:?OUT_DIR}
[ -n "${JOB_ID:-}" ] || { echo "qsub으로 낼 것(로그인 노드에서 전체 WGS를 돌리지 않는다)" >&2; exit 2; }
source /BiO/scratch/dyl/kbb/bashrc.txt
set -u
tools=/BiO/scratch/dyl/kbb/UTILS/Tools
py=/BiO/scratch/dyl/kbb/opt/kobic_env/venv_snakemake/bin/python
fastp="$tools/fastp/bin/fastp"
bwa="$tools/bwa-mem2_amd/bwa-mem2-2.2.1/bwa-mem2"
samtools="$tools/samtools/samtools-1.20/bin/samtools"
ref=/BiO/scratch/dyl/kbb/UTILS/Reference/GATK_bundle/Homo_sapiens_assembly38.fasta
T=${NSLOTS:-10}
test -r "$R1" && test -r "$R2"
mkdir -p "$OUT" && cd "$OUT"
[ -e VALIDATED.txt ] && { echo "이미 VALIDATED — 할 일 없음"; exit 0; }
printf 'R1=%s\nR2=%s\nSAMPLE=%s\nHOST=%s\nTHREADS=%s\nSTART=%s\n' "$R1" "$R2" "$S" "$(hostname)" "$T" "$(date '+%F %T')"
trap 'rc=$?; printf "EXIT_STATUS=%s OUT=%s %s\n" "$rc" "$OUT" "$(date "+%F %T")"' EXIT
json_reads() { "$py" -c 'import json,sys; print(json.load(open(sys.argv[1]))["summary"][sys.argv[2]]["total_reads"])' "$1" "$2"; }

# fastp: 파이프라인 규칙과 같은 인자 (repairs/mgi_hg002_recheck.sh 에서 그대로)
"$fastp" --thread 4 --in1 "$R1" --in2 "$R2" --out1 R1.trimmed.fastq.gz --out2 R2.trimmed.fastq.gz \
    --json fastp.json --html fastp.html --report_title "$S" \
    --n_base_limit 5 --trim_front1 0 --trim_front2 0 --length_required 70 \
    --cut_mean_quality 30 --detect_adapter_for_pe \
    --adapter_sequence AGATCGGAAGAGCACACGTCTGAACTCCAGTCA \
    --adapter_sequence_r2 AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT --trim_poly_g \
    > fastp.stdout 2> fastp.stderr
raw=$(json_reads fastp.json before_filtering); expected=$(json_reads fastp.json after_filtering)
echo "fastp: before $raw → after $expected reads $(date '+%T')"

# bwa-mem2: 파이프라인과 같은 -Y -K 100000000. pipefail이 bwa 실패를 view 성공으로 가리지 않게 한다
"$bwa" mem -Y -R "@RG\tID:$S\tSM:$S\tPL:ILLUMINA\tLB:UNKNOWN" -v 3 -t "$T" -K 100000000 "$ref" \
    R1.trimmed.fastq.gz R2.trimmed.fastq.gz 2> bwa.stderr | "$samtools" view -@ 4 -bS -h -o aligned.bam.partial - 2> view.stderr
"$samtools" quickcheck -v aligned.bam.partial
actual=$("$samtools" view -@ 8 -c -F 0x900 aligned.bam.partial)
echo "primary reads $actual / expected $expected $(date '+%T')"
[ "$actual" = "$expected" ] || { echo "FAIL: primary 리드 수가 fastp 출력과 다르다. 정렬하지 않는다." >&2; exit 1; }
mv aligned.bam.partial aligned.bam
mkdir -p sort_tmp
"$samtools" sort -m 2500M -T sort_tmp/part -@ 10 -O bam --write-index -o "${S}_sort.bam##idx##${S}_sort.bam.bai" aligned.bam \
    > sort.stdout 2> sort.stderr
"$samtools" quickcheck -v "${S}_sort.bam"
sorted=$("$samtools" view -@ 8 -c -F 0x900 "${S}_sort.bam")
[ "$sorted" = "$expected" ] || { echo "FAIL: 정렬 BAM primary 리드 수가 다르다." >&2; exit 1; }
rm -rf sort_tmp
printf 'VALIDATED_PRIMARY_READS=%s\nFASTP_BEFORE=%s\nNEW_BAM=%s\nINPUT_R1=%s\nINPUT_R2=%s\n' "$sorted" "$raw" "$OUT/${S}_sort.bam" "$R1" "$R2" > VALIDATED.txt
cat VALIDATED.txt
echo "파이프라인 파일은 그대로다. 교체는 사람이 판단한다."
