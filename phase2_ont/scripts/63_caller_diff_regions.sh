#!/bin/bash
# 두 caller 가 **서로 다르게 부른 것**을 구간 안/밖으로 갈라 ts/tv 로 센다 (qsub, 수 분).
#
#   bash phase2_ont/scripts/63_caller_diff_regions.sh           잡 제출 (기본: HG002 R10)
#   bash phase2_ont/scripts/63_caller_diff_regions.sh --show    결과 표
#   DRY=1 bash phase2_ont/scripts/63_caller_diff_regions.sh     잡 스크립트만 만들고 제출 안 함
#   (--run 은 잡 안에서 부르는 모드다. 직접 쓰지 않는다)
#
# **왜 필요한가.** 62_tstv_regions.sh 로 구간 밖 ts/tv 를 쟀더니 Clair3 1.1454 / DeepVariant
# 1.0916 이었고, 두 caller 의 **순 차이**(C3 − DV)가 ts 60,401 / tv 27,753 = **2.18** 이었다.
# germline 신호(~2.1)에 가깝다 — DV 가 구간 밖에서 버리는 것이 FP 가 아니라 진짜 변이일 수 있다.
# 그런데 순 차이는 "DV 가 버린 집합"이 아니다. 두 caller 는 서로 다른 것을 부르고, 한쪽만 부른
# 것끼리 상쇄된 나머지가 순 차이다. 이 스크립트는 bcftools isec 로 **실제 차집합**을 만든다.
#
#   0000 = Clair3 만 부른 것     0001 = DeepVariant 만 부른 것     0002 = 둘 다 부른 것
#
# 판정은 구간 **밖** C3-only 의 ts/tv 로 한다. 2 근처면 DV 가 진짜 변이를 버리고 있다(구간 밖에서
# 지나치게 보수적), 0.5~1 이면 C3 의 추가분이 FP 이고 DV 가 옳다. 구간 **안**은 hap.py 가 이미
# truth 로 채점했으므로(DV 우세) 여기서는 대조용이다.
#
# SNV 만 본다(ts/tv 는 SNV 의 지표). 대립유전자까지 같아야 공유로 친다(-c none) — 다중대립
# 레코드를 두 caller 가 다르게 쪼개면 한쪽만 부른 것으로 잡힌다. 그 몫은 작지만 0 은 아니다.
#
# **2026-09-23 첫 실행 (잡 156585, 63초)**: 구간 밖 Clair3 단독 0.8696 / DV 단독 0.6700 /
# 공유 1.3142. 2.18 은 두 단독 집합의 차(2.16)로 재현되는 부산물이었다 — germline 같은 집합은 없다.
# **단, 이 ts/tv 로 단독 콜을 FP 로 분류하지 않는다**: 구간 밖 진짜 변이의 ts/tv 를 모른다(공유조차
# 1.31). 아래 판정 문구의 "2 근처 / 0.5~1" 은 방향만 본다. 진짜 답은 v5.0q smvar 로 채점할 때 나온다.
# **2026-09-24 답 (64 + v5.0q 층화, 잡 156640)**: DV 가 v4.2.1 밖에서도 FN·FP 둘 다 적다. 그리고 여기 ts/tv
# 방향(Clair3 단독 0.87 > DV 단독 0.67)은 FP 양의 방향과 **반대**였다 — ts/tv 로 FP 를 판정하지 말 것.
# 교차 대조는 Clair3 0.16% · DV 0.19% 어긋났다(다중대립 분할).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"
PHASE2="$P2_DIR"

DSID="${DSID:-HG002.ONT-R10_giab2025.01_PAW70337}"
SLOTS="${CDIFF_SLOTS:-4}"
VMEM="${CDIFF_VMEM:-16G}"

row=$(p2_row "$DSID")
[ -n "$row" ] || { echo "ERROR: run_table 에 없음 — $DSID" >&2; exit 1; }
SAMPLE=$(p2_col "$row" 2); DATASET=$(p2_col "$row" 3); DV_MODEL=$(p2_col "$row" 10)
[ "$DV_MODEL" != - ] || { echo "ERROR: $DSID 는 DeepVariant 를 안 돈 런이다 (dv_model='-')" >&2; exit 1; }
BASE="$RUN_BASE/$SAMPLE/ONT/$DATASET"
ID="$SAMPLE.$DATASET.$REF_NAME"
OUTDIR="$BASE/05_BENCH/caller_diff"
TSV="$OUTDIR/$ID.caller_diff.tsv"

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

# ── 결과 보기 ────────────────────────────────────────────────────────────
if [ "${1:-}" = --show ]; then
    [ -s "$TSV" ] || { echo "결과 없음 — $TSV (잡이 아직 안 끝났거나 안 돌았다)"; exit 1; }
    awk -F'\t' 'NR==1 {printf "%-14s %-6s %10s %10s %10s %7s\n", "set","region","SNV","ts","tv","ts/tv"; next}
                {printf "%-14s %-6s %10d %10d %10d %7s\n", $1,$2,$3,$4,$5,$6}' "$TSV"
    echo
    echo "읽는 법: 구간 밖 단독 집합의 ts/tv 를 공유 집합과 비교한다. 이것만으로 단독 콜을 FP 로 분류하지 않는다 —"
    echo "        구간 밖 진짜 변이의 ts/tv 를 모른다. FN·FP 를 직접 세려면 v5.0q smvar 로 채점한다."
    exit 0
fi

# ── 계산 (잡 안에서) ─────────────────────────────────────────────────────
if [ "${1:-}" = --run ]; then
    BT_IMG="$(p2_img_path "$(p2_container_uris | grep '/bcftools:')")"
    [ -s "$BT_IMG" ] || { echo "ERROR: bcftools 컨테이너 없음 ($BT_IMG)" >&2; exit 1; }
    bt() { singularity exec -B "$GIAB_ROOT:$GIAB_ROOT" "$BT_IMG" bcftools "$@"; }

    BED=$(truth_bed "$SAMPLE") || { echo "ERROR: $SAMPLE 의 $BENCH_TRUTH_VER benchmark BED 없음" >&2; exit 1; }
    C3="$BASE/03_VCF/clair3/$ID.clair3.vcf.gz"
    DV="$BASE/03_VCF/deepvariant/$ID.deepvariant.vcf.gz"
    for f in "$C3" "$DV"; do
        [ -s "$f" ] && [ -s "$f.tbi" ] || { echo "ERROR: VCF 또는 인덱스 없음 — $f" >&2; exit 1; }
    done

    mkdir -p "$OUTDIR"
    W="$OUTDIR/.work.${JOB_ID:-$$}"
    rm -rf "$W"
    echo "== isec: $ID (PASS SNV, 대립유전자 일치) =="
    echo "   BED: $BED"
    bt isec -f PASS -c none -i 'TYPE="snp"' -p "$W" -Oz "$C3" "$DV"
    for s in 0000 0001 0002 0003; do
        [ -s "$W/$s.vcf.gz" ] || { echo "ERROR: isec 산출 없음 — $W/$s.vcf.gz" >&2; exit 1; }
        bt index -t -f "$W/$s.vcf.gz"
    done

    # stats 한 번 -> "snv<TAB>ts<TAB>tv". 62_tstv_regions.sh 와 같은 파싱.
    count() {
        local out
        out=$(bt stats "$@" 2>/dev/null) || { echo "ERROR: bcftools stats 실패 ($*)" >&2; return 1; }
        printf '%s\n' "$out" | awk -F'\t' '
            $1=="SN" && $3=="number of SNPs:" {snp=$4}
            $1=="TSTV" {ts=$3; tv=$4}
            END {printf "%d\t%d\t%d\n", snp+0, ts+0, tv+0}'
    }
    ratio() { awk -v a="$1" -v b="$2" 'BEGIN{ if (b+0==0) print "NA"; else printf "%.4f", a/b }'; }

    tmp="$TSV.tmp.${JOB_ID:-$$}"
    printf 'set\tregion\tsnv\tts\ttv\ttstv\n' > "$tmp"
    declare -A ALL
    for pair in "0000:clair3_only" "0001:deepvariant_only" "0002:shared"; do
        s=${pair%%:*}; name=${pair#*:}; f="$W/$s.vcf.gz"
        IFS=$'\t' read -r a_n a_ts a_tv < <(count "$f")
        IFS=$'\t' read -r i_n i_ts i_tv < <(count -R "$BED" "$f")
        IFS=$'\t' read -r o_n o_ts o_tv < <(count -T "^$BED" "$f")
        for v in "$a_n" "$a_ts" "$a_tv" "$i_n" "$i_ts" "$i_tv" "$o_n" "$o_ts" "$o_tv"; do
            [ -n "$v" ] || { echo "ERROR: $name — stats 가 값을 안 냈다" >&2; exit 1; }
        done
        # 62 와 같은 보험: 안 + 밖 = 전체 가 아니면 구간 분할이 틀린 것이다. 그 숫자는 쓰지 않는다.
        if [ $((i_n + o_n)) -ne "$a_n" ] || [ $((i_ts + o_ts)) -ne "$a_ts" ] || [ $((i_tv + o_tv)) -ne "$a_tv" ]; then
            echo "ERROR: $name 구간 분할 불일치 — 안 $i_n + 밖 $o_n != 전체 $a_n" >&2; exit 1
        fi
        ALL[$name]=$a_n
        printf '%s\tall\t%s\t%s\t%s\t%s\n' "$name" "$a_n" "$a_ts" "$a_tv" "$(ratio "$a_ts" "$a_tv")" >> "$tmp"
        printf '%s\tin\t%s\t%s\t%s\t%s\n'  "$name" "$i_n" "$i_ts" "$i_tv" "$(ratio "$i_ts" "$i_tv")" >> "$tmp"
        printf '%s\tout\t%s\t%s\t%s\t%s\n' "$name" "$o_n" "$o_ts" "$o_tv" "$(ratio "$o_ts" "$o_tv")" >> "$tmp"
    done

    # 교차 대조 — 62_tstv_regions.sh 가 잰 caller 별 PASS SNV 총수와 맞아야 한다.
    # 다중대립을 caller 가 다르게 쪼개면 조금 어긋날 수 있어 **경고만** 한다(중단하지 않는다).
    shared_dv=$(count "$W/0003.vcf.gz" | cut -f1)
    echo "== 교차 대조 =="
    echo "   Clair3      = clair3_only + shared    = ${ALL[clair3_only]} + ${ALL[shared]} = $(( ${ALL[clair3_only]} + ${ALL[shared]} ))"
    echo "   DeepVariant = deepvariant_only + 0003 = ${ALL[deepvariant_only]} + $shared_dv = $(( ${ALL[deepvariant_only]} + shared_dv ))"
    echo "   (62_tstv_regions.sh 실측: Clair3 4,562,462 / DeepVariant 4,476,450 — 다중대립 몫만큼 다를 수 있다)"

    mv -f "$tmp" "$TSV"
    rm -rf "$W"
    echo "== 완료: $TSV =="
    exit 0
fi

# ── 제출 ────────────────────────────────────────────────────────────────
p2_qstat_refresh
p2_require_sge_targets || exit 1
SGE_Q_ARG="$(p2_sge_queue_arg)"
name="c2.$DSID"
if qstat -u "$USER" 2>/dev/null | awk 'NR>2 {print $3}' | grep -qx "${name:0:10}"; then
    echo "SKIP: 같은 이름의 잡이 이미 큐에 있다 (${name:0:10}) — qstat 로 확인할 것"; exit 0
fi

mkdir -p "$INFRA/jobs" "$INFRA/logs" "$INFRA/launch/cdiff.$DSID"
job="$INFRA/jobs/cdiff.$DSID.sh"
# 잡 파일에는 헤더와 호출 한 줄만 둔다. 로직은 이 스크립트의 --run 이 갖는다 —
# heredoc 안에 로직을 넣으면 생성 시점 확장(백틱·${:+}) 사고가 난다(2026-09-17).
if ! cat > "$job" <<EOF
#!/bin/bash
#\$ -N $name
#\$ -q $SGE_Q_ARG
#\$ -pe $SGE_PE $SLOTS
#\$ -S /bin/bash
#\$ -V
#\$ -j y
#\$ -o $INFRA/logs/cdiff.$DSID.\$JOB_ID.log
#\$ -l h_vmem=$VMEM
#\$ -l h='$SGE_HOSTS'
#\$ -wd $INFRA/launch/cdiff.$DSID
set -euo pipefail
DSID='$DSID' bash "$PHASE2/scripts/63_caller_diff_regions.sh" --run
EOF
then
    echo "FAIL: 잡 스크립트를 못 썼다 — $job"; exit 1
fi

if [ "${DRY:-0}" = 1 ]; then echo "DRY: $job 생성만 함"; exit 0; fi
if ! out=$(qsub "$job" < /dev/null 2>&1); then echo "FAIL: qsub 거부 — $out"; exit 1; fi
jid=$(echo "$out" | grep -oE '[0-9]+' | head -1)
[ -n "$jid" ] || { echo "FAIL: qsub 출력에서 jobid 를 못 읽었다 — $out"; exit 1; }
echo "OK  $DSID: jobid=$jid  ->  끝나면: bash $0 --show"
