#!/bin/bash
# somatic SNV/INDEL 채점 — NIST HG008-T smvar DraftBenchmark V0.3 대비 aardvark.
# 플랫폼 무관 공통 스크립트다. 숏리드(phase3) callset 도 같은 인자로 넣는다.
#
#   bash phase1_pacbio_hifi/scripts/62_benchmark_somatic.sh <label> <somatic.vcf.gz> [sample]
#   bash phase1_pacbio_hifi/scripts/62_benchmark_somatic.sh --collect [out.tsv]
#   무거우면 qsub_task.sh 로 감싼다: qsub_task.sh som.<label> -s 8 -- bash .../62_benchmark_somatic.sh <label> <vcf>
#
# 채점 조건 (truth README 기준, 2026-09-25 숏리드 세션과 합의):
#   truth  : HG008-T_somatic_smvar_benchmark_v0.3_tumorvariants.vcf.gz (README 권장, GT 0/1, truncal 만)
#   구간   : nogermlineinterference.bed (기본) + all.bed (보조). 둘 다 chr1~22·chrX
#   query  : FILTER PASS(또는 .) + FORMAT/VAF >= SOMATIC_MIN_VAF(기본 0.05). README 가 "VAF 5~10% 미만을 걸러
#            비교하라" 고 권한다 — truth 가 truncal/clonal 만 담기 때문이다
#   GT     : query GT 를 전부 0/1 로 맞춘다. truth 가 0/1 규약이고 somatic caller 의 GT(0/1·1/1)는 LOH·
#            순도에 따라 흔들려 somatic 여부와 무관하다. aardvark GT 모드가 이 차이를 FN/FP 로 세지 않게 한다
#   도구   : aardvark compare (README 권장). reference 는 우리 정렬에 쓴 no_alt analysis set 이다 — README 예시는
#            GIABv3 masked 판이지만 chr1~22·X 서열 좌표는 같고 aardvark 는 콜이 있는 구간 서열만 쓴다
#
# **해석 범위** (phase1_pacbio_hifi/somatic_pairs.tsv 의 truth_scope):
#   full        — tumor 가 truth 배치(0823p23)와 같다. recall·precision 둘 다 해석한다
#   recall_only — 다른 배치·계대·클론. 고유 변이가 truth 밖이라 FP 로 잡혀 precision 은 해석하지 않는다
# HG009 는 검증된 somatic truth 가 없다 — 이 스크립트로 채점하지 않는다.
#
# 산출: $SOMATIC_BENCH_DIR/<label>/{query.pass_vaf.vcf.gz, nogermlineinterference/, all/} — 각 폴더에 aardvark summary.tsv
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

TRUTH_VCF="$SOMATIC_TRUTH_DIR/HG008-T_somatic_smvar_benchmark_v0.3_tumorvariants.vcf.gz"
TIERS="${SOMATIC_BED_TIERS:-nogermlineinterference all}"
BT_IMG="$(p1_img_path "$(p1_container_uris | grep '/bcftools:')")"
# 입력 VCF 폴더와 산출 폴더도 따로 바인드한다 — 숏리드 콜셋은 /BiO/scratch/dyl/... 처럼 세 루트 밖에 있다 (PR #67 Codex).
EXTRA_B=()
bt() { singularity exec -B "$GIAB_ROOT:$GIAB_ROOT" -B "$RUN_BASE:$RUN_BASE" -B "$INFRA:$INFRA" ${EXTRA_B[@]+"${EXTRA_B[@]}"} "$BT_IMG" "$@"; }

collect() {
    local out="${1:-$P1_DIR/phase1_somatic_summary.tsv}" f n=0
    {
        printf 'label\ttier\tvariant_type\ttruth_total\ttruth_tp\ttruth_fn\tquery_total\tquery_tp\tquery_fp\trecall\tprecision\tf1\n'
        for f in "$SOMATIC_BENCH_DIR"/*/*/summary.tsv; do
            [ -s "$f" ] || continue
            local tier label
            tier=$(basename "$(dirname "$f")"); label=$(basename "$(dirname "$(dirname "$f")")")
            awk -F'\t' -v L="$label" -v T="$tier" '
                NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
                $h["comparison"]=="GT" && $h["region_label"]=="ALL" && ($h["variant_type"]=="Snv" || $h["variant_type"]=="JointIndel" || $h["variant_type"]=="ALL") {
                    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", L, T, $h["variant_type"],
                        $h["truth_total"], $h["truth_tp"], $h["truth_fn"], $h["query_total"], $h["query_tp"], $h["query_fp"],
                        $h["metric_recall"], $h["metric_precision"], $h["metric_f1"] }' "$f"
            n=$((n + 1))
        done
    } > "$out"
    echo "-> $out ($n summary 파일)"
    echo "해석 범위는 somatic_pairs.tsv 의 truth_scope — recall_only 행의 precision 은 읽지 않는다."
}

case "${1:-}" in
    ""|-h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
    --collect) shift; collect "${1:-}"; exit 0 ;;
esac

label=$1 vcf=$2 sample=${3:-}
[[ "$label" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ERROR: label 은 영문·숫자·._- 만 ($label)"; exit 1; }
for f in "$vcf" "$TRUTH_VCF" "$REF_FASTA" "$AARDVARK" "$BT_IMG"; do
    [ -s "$f" ] || { echo "ERROR: 없음 — $f"; exit 1; }
done
for t in $TIERS; do
    [ -s "$SOMATIC_TRUTH_DIR/HG008-T_somatic_smvar_benchmark_v0.3_$t.bed" ] \
        || { echo "ERROR: truth BED 없음 — $t (zip 을 풀었는지 확인)"; exit 1; }
done
vdir=$(cd "$(dirname "$vcf")" && pwd); vcf="$vdir/$(basename "$vcf")"
mkdir -p "$SOMATIC_BENCH_DIR"; odir=$(cd "$SOMATIC_BENCH_DIR" && pwd)
EXTRA_B=(-B "$vdir:$vdir" -B "$odir:$odir")
# grep -q 는 찾자마자 끝나 bcftools 가 SIGPIPE 를 받고, pipefail 이 그걸 "VAF 없음" 으로 만든다 — 끝까지 읽는다
bt bcftools view -h "$vcf" | grep '^##FORMAT=<ID=VAF,' > /dev/null \
    || { echo "ERROR: $vcf 에 FORMAT/VAF 가 없다 — VAF 필터를 적용할 수 없다"; exit 1; }

out="$SOMATIC_BENCH_DIR/$label"
mkdir -p "$out"
q="$out/query.pass_vaf.vcf.gz"
sarg=(); [ -n "$sample" ] && sarg=(-s "$sample")
ns=$(bt bcftools query -l "$vcf" | wc -l)
if [ "$ns" -gt 1 ] && [ -z "$sample" ]; then
    echo "ERROR: $vcf 는 샘플이 $ns 개다 — 세 번째 인자로 tumor 샘플 이름을 준다 ($(bt bcftools query -l "$vcf" | paste -sd, -))"; exit 1
fi
# 순서가 중요하다 (PR #67 Codex 지적):
#   1) 샘플을 먼저 고른다 — bcftools 는 -i 를 -s 보다 먼저 평가해, 한 명령에 두면 첫 샘플(normal 일 수 있다)의 VAF 로 거른다
#   2) PASS/.
#   3) 다중 대립유전자를 나눈다 — VAF 는 Number=A 라 norm -m 이 대립유전자별로 나눠 준다. 그래야 둘째 ALT 만 기준을
#      넘는 기록도 남고, GT 1/2 를 통째로 0/1 로 바꿔 G 콜을 잃는 일이 없다
#   4) 대립유전자별 VAF 필터
#   5) 이 기록의 ALT 를 실제로 부른 것(GT 에 0 아닌 대립유전자)만 남기고 GT 를 0/1 로 통일
bt bcftools view ${sarg[@]+"${sarg[@]}"} "$vcf" \
  | bt bcftools view -f 'PASS,.' \
  | bt bcftools norm -m -any \
  | bt bcftools view -i "FORMAT/VAF[0:0]>=$SOMATIC_MIN_VAF" \
  | awk -F'\t' 'BEGIN{OFS="\t"} /^#/ {print; next} {
        n=split($9, f, ":"); gi=0; for (i=1;i<=n;i++) if (f[i]=="GT") gi=i
        if (!gi) next
        m=split($10, v, ":"); if (v[gi] !~ /[1-9]/) next
        v[gi]="0/1"; s=v[1]; for (i=2;i<=m;i++) s=s":"v[i]; $10=s
        print }' \
  | bt bcftools view -Oz -o "$q"
bt bcftools index -f -t "$q"
nq=$(bt bcftools view -H "$q" | wc -l)
echo "query: $nq records (PASS, VAF>=$SOMATIC_MIN_VAF) <- $vcf"
[ "$nq" -gt 0 ] || { echo "ERROR: 필터 뒤 query 가 비었다"; exit 1; }

for t in $TIERS; do
    rm -rf "$out/$t"
    "$AARDVARK" compare \
        --reference "$REF_FASTA" \
        --truth-vcf "$TRUTH_VCF" \
        --query-vcf "$q" \
        --regions "$SOMATIC_TRUTH_DIR/HG008-T_somatic_smvar_benchmark_v0.3_$t.bed" \
        --output-dir "$out/$t" \
        --compare-label "${label}_$t" \
        --threads "${NSLOTS:-4}"
    echo "== $label / $t"
    awk -F'\t' 'NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
        $h["comparison"]=="GT" && $h["region_label"]=="ALL" && ($h["variant_type"]=="Snv" || $h["variant_type"]=="JointIndel") {
        printf "  %-10s truth %7s  TP %7s  FN %7s  FP %7s  recall %.4f  precision %.4f  F1 %.4f\n",
            $h["variant_type"], $h["truth_total"], $h["truth_tp"], $h["truth_fn"], $h["query_fp"],
            $h["metric_recall"], $h["metric_precision"], $h["metric_f1"] }' "$out/$t/summary.tsv"
done
