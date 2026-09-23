#!/bin/bash
# 벤치마크 신뢰구간 안/밖으로 갈라 ts/tv 를 직접 센다 (로그인 노드, 런당 1~3분).
#
#   bash phase1_pacbio_hifi/scripts/62_tstv_regions.sh                 # truth 있는 런 전부
#   bash phase1_pacbio_hifi/scripts/62_tstv_regions.sh HG002.PacBio_HiFi-Revio_20231031
#   TSV=out.tsv bash phase1_pacbio_hifi/scripts/62_tstv_regions.sh     # 표를 파일로도
#
# phase2_ont/scripts/62_tstv_regions.sh 를 그대로 이식했다. 달라진 곳은 셋뿐이다 —
# 산출 경로(ONT -> PacBio), caller(phase1 은 전 런이 DeepVariant+Clair3 둘 다라 dv_model 열이
# 없다), dup_of 열 위치(12 -> 8). 로직을 고치면 두 phase 를 같이 고친다.
#
# **phase1 에서 왜 보나.** hap.py 는 benchmark BED 안만 채점한다. phase1 SNP 는 그 안에서
# F1 .9984~.9994 로 포화라 런 차이가 안 보이는데, 구간 밖(어려운 영역)은 채점 도구가 없다.
# ts/tv 는 truth 없이도 쓸 수 있는 몇 안 되는 품질 신호라 구간 밖 비교에 쓴다. ONT 는 구간 밖
# 1.09~1.48 이었다 — 같은 샘플에서 HiFi 가 어디에 서는지가 플랫폼 비교의 한 축이 된다.
#
# phase2 원판의 동기: 2026-08-27 에 "전 런 ts/tv 가 germline 기대치 2.0~2.1 보다 낮다"를
# 열린 질문으로 남겼고, 2026-09-18 에 구간 밖 값을 **빼기로 추정**했다 (R9/HG005 1.33).
# 그 추정은 "구간 안 ts/tv = 2.1" 가정에 기대서, 이 스크립트는 구간 안을 가정하지 않고
# **직접 센다.**
#
# 세 번 센다 — 구간 안(-R), 구간 밖(-T ^), 전체. 앞의 둘을 더하면 전체가 나와야 한다.
# **이 대조가 이 스크립트의 핵심이다.** bcftools 가 `-T ^file` 의 여집합을 기대대로 다루지
# 않거나 BED 가 엉뚱하면 조용히 틀린 값이 나오는데, 그 경우 합이 안 맞아 여기서 죽는다.
# 전체를 따로 세는 비용(1/3)은 그 보험값이다.
#
# ts/tv 는 파생값이라 직접 다루지 않고 bcftools 가 주는 ts·tv **카운트**를 쓴다. 비(比)를
# 수로 가중평균하면 틀린다 — 2026-09-21 에 그렇게 1.15 를 적었다가 정정했다(decisions).
#
# phase2 첫 실행(2026-09-22): 10건 전부 대조 통과, 구간 안 2.0972~2.1400.
# 수치·해석: docs/reference/2026-09-22-ont-r10-benchmark.md
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"
RT="$HERE/../run_table.tsv"

# 61_benchmark_sv.sh 와 같은 방식 — 파이프라인이 실제로 쓴 판을 그대로 쓴다.
# RUN_BASE 도 따로 바인드한다 — env.local.sh 로 GIAB_ROOT 밖에 두면 안 보인다 (PR #38 Codex 지적. phase2 판은 아직 GIAB_ROOT 만).
BT_IMG="$(p1_img_path "$(p1_container_uris | grep '/bcftools:')")"
[ -s "$BT_IMG" ] || { echo "ERROR: bcftools 컨테이너가 없다 ($BT_IMG) — 01_prepare_login_node.sh 먼저" >&2; exit 1; }
bt() { singularity exec -B "$GIAB_ROOT:$GIAB_ROOT" -B "$RUN_BASE:$RUN_BASE" "$BT_IMG" bcftools "$@"; }

# 60_benchmark.sh 의 bench_truth 와 같은 해석. BED 만 쓴다.
truth_bed() {
    local s=$1 ver="$BENCH_TRUTH_VER" d bed
    for d in "$GIAB_ROOT"/release/*/*/NIST"$ver"/"$REF_NAME" \
             "$GIAB_ROOT"/release/*/NIST"$ver"/"$REF_NAME"; do
        [ -d "$d" ] || continue
        bed=$(ls "$d/${s}_"*_"$ver"_benchmark.bed \
                 "$d/${s}_"*_"$ver"_benchmark_noinconsistent.bed 2>/dev/null \
              | grep -v '/\._' | head -1) || true
        [ -n "$bed" ] || continue
        echo "$bed"; return 0
    done
    return 1
}

# bcftools stats 한 번 -> "snp<TAB>indel<TAB>ts<TAB>tv". 인자는 stats 에 그대로 넘긴다.
# TSTV 행의 ts·tv 는 카운트다 (5열의 ts/tv 는 그 둘의 비라 여기서 다시 계산한다).
count_region() {
    local out
    out=$(bt stats -f PASS "$@" 2>/dev/null) || { echo "ERROR: bcftools stats 실패 ($*)" >&2; return 1; }
    printf '%s\n' "$out" | awk -F'\t' '
        $1=="SN" && $3=="number of SNPs:"   {snp=$4}
        $1=="SN" && $3=="number of indels:" {ind=$4}
        $1=="TSTV" {ts=$3; tv=$4}
        END {printf "%d\t%d\t%d\t%d\n", snp+0, ind+0, ts+0, tv+0}'
}

ratio() { awk -v a="$1" -v b="$2" 'BEGIN{ if (b+0==0) print "NA"; else printf "%.4f", a/b }'; }

rows=()
run_one() {  # dsid sample dataset
    local dsid=$1 sample=$2 dataset=$3 bed id base c vcf
    bed=$(truth_bed "$sample") || { echo "SKIP $dsid: $sample 의 $BENCH_TRUTH_VER benchmark BED 없음"; return 0; }
    base="$RUN_BASE/$sample/PacBio/$dataset"; id="$sample.$dataset.$REF_NAME"

    for c in clair3 deepvariant; do
        vcf="$base/03_VCF/$c/$id.$c.vcf.gz"
        if [ ! -s "$vcf" ] || [ ! -s "$vcf.tbi" ]; then
            echo "SKIP $dsid/$c: VCF 또는 인덱스 없음 ($vcf)"; continue
        fi
        echo "  세는 중: $dsid / $c" >&2

        local a_snp a_ind a_ts a_tv i_snp i_ind i_ts i_tv o_snp o_ind o_ts o_tv
        IFS=$'\t' read -r a_snp a_ind a_ts a_tv < <(count_region "$vcf")
        IFS=$'\t' read -r i_snp i_ind i_ts i_tv < <(count_region -R "$bed" "$vcf")
        IFS=$'\t' read -r o_snp o_ind o_ts o_tv < <(count_region -T "^$bed" "$vcf")

        # count_region 이 죽어도 read 는 성공한다 (빈 값). 빈 문자열은 $(( )) 에서 0 이 되므로
        # 세 번 다 실패하면 0+0==0 으로 아래 대조를 통과해 버린다 — 먼저 값이 왔는지 본다.
        for v in "$a_snp" "$a_ts" "$a_tv" "$i_snp" "$i_ts" "$i_tv" "$o_snp" "$o_ts" "$o_tv"; do
            [ -n "$v" ] || { echo "ERROR: $dsid/$c bcftools stats 가 값을 안 냈다" >&2; return 1; }
        done
        [ "$a_snp" -gt 0 ] || { echo "ERROR: $dsid/$c PASS SNP 가 0 이다 — VCF 를 확인할 것" >&2; return 1; }

        # 여기서 막는다. 합이 안 맞으면 구간 분할이 우리 생각과 다르게 된 것이고,
        # 그 상태의 숫자는 쓰면 안 된다 (조용히 틀린 값이 문서에 박히는 경로다).
        if [ $((i_snp + o_snp)) -ne "$a_snp" ] || [ $((i_ts + o_ts)) -ne "$a_ts" ] \
           || [ $((i_tv + o_tv)) -ne "$a_tv" ]; then
            echo "ERROR: $dsid/$c 구간 분할 불일치 — 안+밖 != 전체" >&2
            echo "  SNP  안 $i_snp + 밖 $o_snp = $((i_snp + o_snp))  vs 전체 $a_snp" >&2
            echo "  ts   안 $i_ts + 밖 $o_ts = $((i_ts + o_ts))  vs 전체 $a_ts" >&2
            echo "  tv   안 $i_tv + 밖 $o_tv = $((i_tv + o_tv))  vs 전체 $a_tv" >&2
            return 1
        fi

        rows+=("$dsid	$c	all	$a_snp	$a_ind	$a_ts	$a_tv	$(ratio "$a_ts" "$a_tv")")
        rows+=("$dsid	$c	in	$i_snp	$i_ind	$i_ts	$i_tv	$(ratio "$i_ts" "$i_tv")")
        rows+=("$dsid	$c	out	$o_snp	$o_ind	$o_ts	$o_tv	$(ratio "$o_ts" "$o_tv")")
    done
}

want=("$@")
n=0
# 열 위치를 손으로 세지 않는다 — awk 가 필요한 셋만 골라 넘긴다.
# (dsid 1 / sample 2 / dataset 3 / dup_of 8. 헤더가 정본이다.)
while IFS=$'\t' read -r dsid sample dataset; do
    [ -n "$dsid" ] || continue
    if [ ${#want[@]} -gt 0 ]; then
        printf '%s\n' "${want[@]}" | grep -qxF "$dsid" || continue
    fi
    run_one "$dsid" "$sample" "$dataset" || exit 1
    n=$((n + 1))
done < <(awk -F'\t' 'NR>1 && NF && $8=="" {print $1"\t"$2"\t"$3}' "$RT")

[ "$n" -gt 0 ] || { echo "대상이 없다 — dsid 를 확인할 것"; exit 1; }

echo
printf '%-46s %-12s %-5s %10s %9s %10s %10s %7s\n' dsid caller region SNP INDEL ts tv ts/tv
printf '%s\n' "${rows[@]}" | awk -F'\t' '{printf "%-46s %-12s %-5s %10d %9d %10d %10d %7s\n", $1,$2,$3,$4,$5,$6,$7,$8}'

if [ -n "${TSV:-}" ]; then
    { printf 'dsid\tcaller\tregion\tsnp\tindel\tts\ttv\ttstv\n'; printf '%s\n' "${rows[@]}"; } > "$TSV"
    echo; echo "-> $TSV"
fi

echo
echo "region: in = benchmark BED 안, out = 그 밖, all = 전체 (in+out 과 대조 통과)."
echo "ts/tv 는 ts·tv 카운트의 비다. 구간별 비를 다시 평균하지 말 것 — 섞으려면 카운트를 더한다."
