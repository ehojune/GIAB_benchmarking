#!/bin/bash
# germline small variant 정확도 평가. GIAB truth set 대비 hap.py.
# phase1의 60_benchmark.sh와 같은 구조이고, ONT에서 달라지는 부분만 아래에 적었다.
#
#   scripts/60_benchmark.sh --list             대상/상태 훑기
#   scripts/60_benchmark.sh --ready            VCF 완료 + truth set 있는 것 전부 제출
#   scripts/60_benchmark.sh <dsid> [dsid ...]  지정 제출
#   scripts/60_benchmark.sh --collect          끝난 결과를 한 TSV로 모음
#   BENCH_TRUTH_VER=v5.0q BENCH_STRAT_TSV=<tsv> scripts/60_benchmark.sh <dsid>
#                                              v5.0q smvar 로 채점 + 구간별 (아래 "v5.0q" 절)
#   BENCH_TRUTH_VER=v5.0q scripts/60_benchmark.sh --collect-strata
#                                              층화 결과(extended.csv 의 Subset 행)를 모음
#
# 환경 변수: DRY=1     qsub 하지 않고 잡 스크립트만 생성
#            FORCE=1   결과가 이미 있어도 재제출
#            CALLERS="clair3"  평가할 caller 고정 (기본은 런마다 자동 판정 — 아래)
#            DUP_OK=1  dup_of 표시분도 제출
#
# ── ONT가 phase1과 다른 점 ─────────────────────────────────────────────────
# 1. **caller를 런마다 정한다.** phase1은 전 런이 DeepVariant+Clair3였지만 ONT는 R9.4.1에
#    DeepVariant ONT 모델이 없어 Clair3 단독으로 돈다. run_table.tsv의 dv_model 열이 '-'면
#    clair3만, 아니면 둘 다 평가한다 (10_submit.sh·35_review_qc.py와 같은 판정 축).
# 2. **평가 대상은 9런** — HG001~HG007 의 R9 8런(Clair3 단독) + HG002 R10 1런(Clair3+DV).
#    처음엔 R9 8런뿐이라 "phase2 에서 DeepVariant 는 벤치마크되지 않는다" 고 적었다 — truth 있는
#    샘플은 전부 R9 이고 DV 가 도는 R10 은 전부 HG008(germline truth 없음)이라 겹치는 런이 없었다.
#    2026-09-19 에 HG002 R10 을 외부에서 들여와 그 공백을 메웠고, 2026-09-22 에 **DV 가 처음
#    채점됐다.** 코드 수정은 없었다 — 이 스크립트는 dv_model 열로 자동 판정한다.
#    HG008 6런은 여전히 germline truth 가 없어 빠진다(draft benchmark 가 somatic-stvar/CNV 뿐이다).
# 3. ts/tv 열린 질문(docs/reference/2026-08-27-ont-qc-first-pass.md)은 R9·R10 양쪽에서 닫혔다 —
#    62_tstv_regions.sh 로 구간 안/밖을 직접 쟀다(구간 안 2.10~2.14, 밖 1.09~1.48).
#
# **v5.0q — v4.2.1 밖을 truth 로 센다 (2026-09-23).** v4.2.1 구간 밖 콜은 truth 가 없어 ts/tv 같은
# 간접 지표밖에 없었다(63_caller_diff_regions.sh). HG002 에는 T2T-Q100 유래 v5.0q smvar 가 있어 v4.2.1 이
# 빼놓은 어려운 영역 상당 부분까지 truth 가 있다.
#   python scripts/64_v5q_strata.py <v5.0q.bed> <v4.2.1.bed> <dir>     겹침 / v5.0q에만 두 층 BED + strata.tsv
#   BENCH_TRUTH_VER=v5.0q BENCH_STRAT_TSV=<dir>/strata.tsv scripts/60_benchmark.sh <dsid>
#   BENCH_TRUTH_VER=v5.0q scripts/60_benchmark.sh --collect-strata
# **v5.0q 결과에서 v4.2.1 결과를 빼서 "밖" 을 구하지 않는다.** 두 truth 는 겹치는 구간에서도 다르므로
# 차이에 truth 의 차이가 섞인다 — 순 차이 함정(2026-09-23 decisions). 한 번의 채점 안에서 층화로 가른다.
# 결과·잡·jobid·임시 디렉토리는 KEY=bench_v5.0q / 05_BENCH/happy_v5.0q 로 따로 둔다. v4.2.1 기본 실행의
# 잡 스크립트는 이 기능이 생기기 전과 바이트 단위로 같다(검증함).
#
# 왜 raw VCF를 넣는가 (phase1과 동일): hap.py는 FILTER를 자체 처리해 summary.csv에 ALL 행과
# PASS 행을 둘 다 낸다. 파이프라인의 03_VCF/<caller>/*.vcf.gz는 RefCall을 포함하지만
# (PASS 필터 없음) 그대로 넣고 PASS 행을 읽으면 된다. SNV/INDEL 분리본을 넣으면 hap.py 자체
# 분류와 어긋나므로 쓰지 않는다.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

# 잡의 -q 에 들어갈 값. preflight 가 qstat 과 대조해 실재하는 큐만 남긴 값으로 덮는다.
# preflight 를 거치지 않는 경로(--list 등)를 위한 기본값이 이것이다.
SGE_Q_ARG="$SGE_QUEUE"
PHASE2="$P2_DIR"
BENCH_SUB="05_BENCH/happy"
KEY=bench
# **v4.2.1 이 아닌 truth 로 돌릴 때는 결과·잡·임시 디렉토리를 전부 따로 둔다.** 같은 경로면
# v4.2.1 결과를 덮고, 중복 제출 가드(jobid 파일)와 hap.py 임시 디렉토리까지 공유한다.
# v4.2.1 은 기존 값 그대로라 기본 실행의 잡 스크립트는 한 글자도 안 바뀐다.
if [ "$BENCH_TRUTH_VER" != v4.2.1 ]; then
    BENCH_SUB="05_BENCH/happy_$BENCH_TRUTH_VER"; KEY="bench_$BENCH_TRUTH_VER"
fi

# dsid의 caller 목록. CALLERS로 고정하지 않았으면 dv_model 열로 판정한다.
run_callers() {  # dv_model -> "clair3" | "clair3 deepvariant"
    if [ -n "${CALLERS:-}" ]; then echo "$CALLERS"; return; fi
    if [ "$1" = - ]; then echo "clair3"; else echo "clair3 deepvariant"; fi
}

# sample -> "truth_vcf<TAB>truth_bed". 없으면 비어 있음.
# 디렉토리 깊이가 샘플마다 다르다: HG001은 release/NA12878_HG001/NISTv4.2.1/,
# HG002~HG007은 release/<Trio>/<Sample_dir>/NISTv4.2.1/. BED 이름도 갈린다 —
# Ashkenazim 트리오(HG002~HG004)는 _benchmark_noinconsistent.bed를 쓴다.
bench_truth() {
    local s=$1 ver="$BENCH_TRUTH_VER" d vcf bed
    for d in "$GIAB_ROOT"/release/*/*/NIST"$ver"/"$REF_NAME" \
             "$GIAB_ROOT"/release/*/NIST"$ver"/"$REF_NAME"; do
        [ -d "$d" ] || continue
        vcf=$(ls "$d/${s}_"*_"$ver"_benchmark.vcf.gz 2>/dev/null | grep -v '/\._' | head -1) || true
        [ -n "$vcf" ] || continue
        # hap.py는 truth VCF의 tabix 인덱스를 요구한다. 없으면 잡이 한참 뒤에 죽으므로 여기서 걸러낸다.
        [ -s "$vcf.tbi" ] || continue
        bed=$(ls "$d/${s}_"*_"$ver"_benchmark.bed \
                 "$d/${s}_"*_"$ver"_benchmark_noinconsistent.bed 2>/dev/null \
              | grep -v '/\._' | head -1) || true
        [ -n "$bed" ] || continue
        printf '%s\t%s\n' "$vcf" "$bed"
        return 0
    done
    # v5.0q 부터 GIAB 는 NIST 접두사·참조 하위 디렉토리 없이 release/<trio>/<sample>/<ver>/ 에 smvar·stvar 를
    # 같이 둔다. 61_benchmark_sv.sh 의 sv_truth 가 stvar 를 찾는 것과 같은 배치다.
    for d in "$GIAB_ROOT"/release/*/*/"$ver" "$GIAB_ROOT"/release/*/"$ver"; do
        [ -d "$d" ] || continue
        vcf="$d/${s}_${REF_NAME}_${ver}_smvar.vcf.gz"
        bed="$d/${s}_${REF_NAME}_${ver}_smvar.benchmark.bed"
        [ -s "$vcf" ] && [ -s "$vcf.tbi" ] && [ -s "$bed" ] || continue
        printf '%s\t%s\n' "$vcf" "$bed"
        return 0
    done
    return 1
}

bench_done() {  # sample dataset caller -> 0 if summary.csv 존재
    local base="$RUN_BASE/$1/ONT/$2" id="$1.$2.$REF_NAME"
    [ -s "$base/$BENCH_SUB/$id.$3.summary.csv" ]
}

list_all() {
    printf '%-46s %-5s %-9s %-7s %-8s %s\n' dsid chem vcf truth happy dup_of
    local dsid r sample dataset dup dv chem t v h c
    for dsid in $(p2_dsids); do
        r=$(p2_row "$dsid"); sample=$(p2_col "$r" 2); dataset=$(p2_col "$r" 3)
        dv=$(p2_col "$r" 10); dup=$(p2_col "$r" 12)
        case "$(p2_col "$r" 7)" in *R10*) chem=R10 ;; *) chem=R9 ;; esac
        v=-; p2_vcf_done "$sample" "$dataset" "$dv" && v=OK
        t=none; bench_truth "$sample" >/dev/null 2>&1 && t="$BENCH_TRUTH_VER"
        h=""
        for c in $(run_callers "$dv"); do bench_done "$sample" "$dataset" "$c" && h="$h${c:0:2}"; done
        printf '%-46s %-5s %-9s %-7s %-8s %s\n' "$dsid" "$chem" "$v" "$t" "${h:--}" "$dup"
    done
    echo
    echo "truth=none 은 germline truth set이 없는 것 (HG008 — draft benchmark가 somatic이라 못 쓴다)."
    echo "happy 열의 cl/de 는 완료된 caller. R9 런은 DeepVariant를 안 돌리므로 cl만 나온다."
}

preflight() {
    p2_qstat_refresh
    # 큐 x 노드가 안 겹치면 잡이 조용히 qw로 남는다 — 제출 전에 막는다 (lib.sh 설명).
    p2_require_sge_targets || exit 1
    SGE_Q_ARG="$(p2_sge_queue_arg)"
    [ -s "$REF_FASTA" ] || { echo "ERROR: 레퍼런스 없음 ($REF_FASTA) — 01_prepare_login_node.sh 먼저"; exit 1; }
    # hap.py는 레퍼런스 옆의 .fai를 요구하는데 이걸 만드는 곳이 없다 — 파이프라인의 SAMTOOLS_FAIDX는
    # publishDir 없이 Nextflow work 디렉토리 안에만 만들고, 01_prepare는 FASTA 압축만 푼다.
    # 여기서 1회 생성한다 (로그인 노드에 samtools가 없어 컨테이너로 — 03_dup_evidence.sh와 같은 방식).
    if [ ! -s "$REF_FASTA.fai" ]; then
        local st refdir
        st="$(p2_img_path "$(p2_container_uris | grep '/samtools:')")"
        refdir="$(dirname "$REF_FASTA")"
        [ -s "$st" ] || { echo "ERROR: $REF_FASTA.fai 없고 samtools 컨테이너도 없다 — 01_prepare_login_node.sh 먼저"; exit 1; }
        echo "  $REF_FASTA.fai 생성 (hap.py 요구, 1회)"
        singularity exec -B "$refdir:$refdir" "$st" samtools faidx "$REF_FASTA"             || { echo "ERROR: samtools faidx 실패 — $REF_FASTA 확인"; exit 1; }
    fi
    local i; i=$(p2_img_path "$HAPPY_IMG")
    [ -s "$i" ] || { echo "ERROR: hap.py 이미지 없음 ($i) — 01_prepare_login_node.sh 재실행"; exit 1; }
    mkdir -p "$INFRA/jobs" "$INFRA/logs" "$INFRA/launch"
}

submit_one() {
    local dsid=$1 r sample dataset dup dv tv truth_vcf truth_bed base id c todo=""
    r=$(p2_row "$dsid")
    [ -n "$r" ] || { echo "SKIP $dsid: run_table.tsv에 없음"; return 1; }
    sample=$(p2_col "$r" 2); dataset=$(p2_col "$r" 3)
    dv=$(p2_col "$r" 10); dup=$(p2_col "$r" 12)

    if [ -n "$dup" ] && [ "${DUP_OK:-0}" != 1 ]; then
        echo "SKIP $dsid: $dup 와 같은 플로우셀의 재베이스콜. 그래도 돌리려면 DUP_OK=1"; return 0
    fi
    if ! tv=$(bench_truth "$sample"); then
        echo "SKIP $dsid: $sample 의 $BENCH_TRUTH_VER germline truth set 없음"; return 0
    fi
    truth_vcf=${tv%%$'\t'*}; truth_bed=${tv#*$'\t'}
    if ! p2_vcf_done "$sample" "$dataset" "$dv"; then
        echo "SKIP $dsid: VCF 미완 — 30_verify_outputs.sh 확인"; return 0
    fi
    base="$RUN_BASE/$sample/ONT/$dataset"; id="$sample.$dataset.$REF_NAME"
    for c in $(run_callers "$dv"); do
        if bench_done "$sample" "$dataset" "$c" && [ "${FORCE:-0}" != 1 ]; then continue; fi
        [ -s "$base/03_VCF/$c/$id.$c.vcf.gz" ] || { echo "  ! $dsid: $c VCF 없음, 건너뜀"; continue; }
        todo="$todo $c"
    done
    if [ -z "$todo" ]; then
        echo "SKIP $dsid: 평가 완료 (재실행은 FORCE=1)"; return 0
    fi
    if p2_job_alive "$KEY.$dsid"; then
        echo "SKIP $dsid: 이미 큐/실행 중"; return 0
    fi

    mkdir -p "$base/$BENCH_SUB" "$INFRA/launch/$KEY.$dsid"
    local job="$INFRA/jobs/$KEY.$dsid.sh" simg strat_arg=""
    # 층화 TSV 는 잡마다 사본을 둔다 — 큐에서 기다리는 동안 원본이 바뀌어도 제출 시점 목록으로 돈다.
    # 인자는 앞 공백을 포함해 --logfile 줄 끝에 붙인다: 비면 기본 잡이 한 글자도 안 바뀐다(phase1 과 같다).
    if [ -n "${BENCH_STRAT_TSV:-}" ]; then
        [ -s "$BENCH_STRAT_TSV" ] || { echo "FAIL $dsid: BENCH_STRAT_TSV 없음 — $BENCH_STRAT_TSV"; return 1; }
        cp "$BENCH_STRAT_TSV" "$INFRA/launch/$KEY.$dsid/strata.tsv" || { echo "FAIL $dsid: 층화 TSV 복사 실패"; return 1; }
        strat_arg=" --stratification $INFRA/launch/$KEY.$dsid/strata.tsv"
    fi
    simg=$(p2_img_path "$HAPPY_IMG")

    # 쓰기가 실패하면(디스크 참, 권한) 예전 잡 스크립트가 남아 엉뚱한 걸 제출하게 된다.
    # 호출부의 `|| rc=1` 때문에 이 함수 안에서는 errexit가 꺼져 있으니 직접 본다.
    if ! cat > "$job" <<EOF
#!/bin/bash
#\$ -N b2.$dsid
#\$ -q $SGE_Q_ARG
#\$ -pe $SGE_PE $BENCH_SLOTS
#\$ -S /bin/bash
#\$ -V
#\$ -j y
#\$ -o $INFRA/logs/$KEY.$dsid.\$JOB_ID.log
#\$ -l h_vmem=$BENCH_VMEM
#\$ -l h='$SGE_HOSTS'
#\$ -wd $INFRA/launch/$KEY.$dsid
set -euo pipefail
source "$PHASE2/env.sh"

THREADS="\${NSLOTS:-$BENCH_SLOTS}"
TMP="$INFRA/launch/$KEY.$dsid/tmp"
mkdir -p "\$TMP"

for c in$todo; do
    echo "== hap.py \$c : $id =="
    singularity exec \\
        -B "$GIAB_ROOT:$GIAB_ROOT" \\
        -B "$RUN_BASE:$RUN_BASE" \\
        -B "$INFRA:$INFRA" \\
        "$simg" \\
        /opt/hap.py/bin/hap.py \\
            "$truth_vcf" \\
            "$base/03_VCF/\$c/$id.\$c.vcf.gz" \\
            -f "$truth_bed" \\
            -r "$REF_FASTA" \\
            -o "$base/$BENCH_SUB/$id.\$c" \\
            --threads "\$THREADS" \\
            --scratch-prefix "\$TMP" \\
            --logfile "$base/$BENCH_SUB/$id.\$c.hap.py.log"$strat_arg
done
echo "ALL DONE $dsid"
EOF
    then
        echo "FAIL $dsid: 잡 스크립트를 못 썼다 — $job"; return 1
    fi
    chmod +x "$job" || { echo "FAIL $dsid: chmod 실패 — $job"; return 1; }

    if [ "${DRY:-0}" = 1 ]; then
        echo "DRY $dsid: $job 생성만 함 (callers:$todo)"; return 0
    fi
    # 호출부가 실패를 모아 처리하므로 errexit에 기대지 않고 qsub 결과를 직접 본다.
    # 안 그러면 빈 jobid 파일을 쓰고 OK 를 찍는다 (아무것도 큐에 안 들어갔는데).
    local out jid
    if ! out=$(qsub "$job" < /dev/null 2>&1); then   # stderr 까지 잡아야 FAIL 메시지가 쓸모 있다
        echo "FAIL $dsid: qsub 거부 — $out"; return 1
    fi
    jid=$(echo "$out" | grep -oE '[0-9]+' | head -1)
    [ -n "$jid" ] || { echo "FAIL $dsid: qsub 출력에서 jobid를 못 읽었다 — $out"; return 1; }
    # jobid 기록이 실패하면 중복 제출 가드가 그 dsid에 대해 무력해진다 — 잡은 이미 들어갔으므로
    # 실패로 보고하되 잡 번호를 반드시 보여준다(사람이 qdel 할 수 있어야 한다).
    echo "$jid" > "$INFRA/jobs/$KEY.$dsid.jobid"         || { echo "FAIL $dsid: jobid=$jid 로 제출됐으나 기록 실패 — $INFRA/jobs/$KEY.$dsid.jobid"; return 1; }
    echo "OK  $dsid: jobid=$jid callers:$todo truth=$(basename "$truth_vcf")"
}

# summary.csv를 한 장으로 모은다. hap.py는 Type(SNP/INDEL) x Filter(ALL/PASS)로 행을 낸다.
# PASS 행이 실제 성능이다 (RefCall이 빠진 값).
# chem 열을 같이 넣는다 — ONT는 R9/R10에서 특히 indel 성능이 갈려서 이 축 없이는 표를 못 읽는다.
collect() {
    local def="$PHASE2/phase2_bench_summary.tsv"
    [ "$BENCH_TRUTH_VER" = v4.2.1 ] || def="$PHASE2/phase2_bench_summary.$BENCH_TRUTH_VER.tsv"
    local out="${1:-$def}" dsid r sample dataset dv chem bc id base c f
    {
        printf 'dsid\tsample\tdataset\tchem\tbasecaller\tcaller\ttype\tfilter\ttruth_total\ttp\tfn\tfp\trecall\tprecision\tf1\n'
        for dsid in $(p2_dsids); do
            r=$(p2_row "$dsid"); sample=$(p2_col "$r" 2); dataset=$(p2_col "$r" 3)
            dv=$(p2_col "$r" 10)
            case "$(p2_col "$r" 7)" in *R10*) chem=R10 ;; *) chem=R9 ;; esac
            bc=$(p2_col "$r" 8)
            base="$RUN_BASE/$sample/ONT/$dataset"; id="$sample.$dataset.$REF_NAME"
            for c in $(run_callers "$dv"); do
                f="$base/$BENCH_SUB/$id.$c.summary.csv"
                [ -s "$f" ] || continue
                awk -F, -v d="$dsid" -v s="$sample" -v ds="$dataset" -v ch="$chem" -v b="$bc" -v cl="$c" '
                    NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
                    {
                      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                        d, s, ds, ch, b, cl, $h["Type"], $h["Filter"],
                        $h["TRUTH.TOTAL"], $h["TRUTH.TP"], $h["TRUTH.FN"], $h["QUERY.FP"],
                        $h["METRIC.Recall"], $h["METRIC.Precision"], $h["METRIC.F1_Score"]
                    }' "$f"
            done
        done
    } > "$out"
    echo "-> $out ($(($(wc -l < "$out") - 1)) rows)"
    echo
    echo "PASS 행만 보기:"
    echo "  awk -F'\\t' 'NR==1 || \$8==\"PASS\"' $out | column -t -s\$'\\t' | head -30"
    echo
    echo "INDEL은 베이스콜러로 갈린다 (실측: guppy 3.2.x가 4.2.2보다 indel 3.5배)."
    echo "  awk -F'\\t' 'NR==1 || (\$8==\"PASS\" && \$7==\"INDEL\")' $out | column -t -s\$'\\t'"
}

# 층화 결과를 모은다. hap.py 는 --stratification 을 주면 extended.csv 에 Subset 별 행을 낸다
# (Subset=* 가 전체, 나머지가 구간). summary.csv 는 전체만 담아 여기서는 extended.csv 를 읽는다.
# 행 수가 많아(구간 x Type x Subtype x Filter x Genotype) PASS·전 Subtype·전 유전형 행만 남긴다.
collect_strata() {
    local def="$PHASE2/phase2_bench_strata.$BENCH_TRUTH_VER.tsv"
    local out="${1:-$def}" dsid r sample dataset dv id base c f n=0
    {
        printf 'dsid\tcaller\tsubset\ttype\tfilter\ttruth_total\ttp\tfn\tfp\trecall\tprecision\tf1\n'
        for dsid in $(p2_dsids); do
            r=$(p2_row "$dsid"); sample=$(p2_col "$r" 2); dataset=$(p2_col "$r" 3); dv=$(p2_col "$r" 10)
            base="$RUN_BASE/$sample/ONT/$dataset"; id="$sample.$dataset.$REF_NAME"
            for c in $(run_callers "$dv"); do
                f="$base/$BENCH_SUB/$id.$c.extended.csv"
                [ -s "$f" ] || continue
                awk -F, -v d="$dsid" -v cl="$c" '
                    NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
                    # Subtype 도 * 로 묶어야 한다 — 안 그러면 indel 길이(C1_5, D6_15 ...)별로 한 구간이 여러 행이 된다
                    # (ONT 공개 extended.csv 로 확인: 이 조건이면 Type x Subset 당 정확히 한 행)
                    $h["Filter"]=="PASS" && $h["Genotype"]=="*" && $h["Subtype"]=="*" {
                      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                        d, cl, $h["Subset"], $h["Type"], $h["Filter"],
                        $h["TRUTH.TOTAL"], $h["TRUTH.TP"], $h["TRUTH.FN"], $h["QUERY.FP"],
                        $h["METRIC.Recall"], $h["METRIC.Precision"], $h["METRIC.F1_Score"]
                    }' "$f"
            done
        done
    } > "$out"
    n=$(($(wc -l < "$out") - 1))
    echo "-> $out ($n rows)"
    [ "$n" -gt 0 ] || echo "  (층화 결과가 없다 — BENCH_STRAT_TSV 를 주고 돌렸는지, BENCH_TRUTH_VER 가 같은지 확인)"
}

# 같은 dsid가 두 번 들어오면 같은 출력 경로에 잡 둘이 동시에 쓴다.
# p2_job_alive는 preflight 때 뜬 qstat 스냅샷을 보므로 방금 넣은 잡을 못 본다 — 입력에서 잘라낸다.
dedup_dsids() { awk 'NF && !seen[$0]++'; }

# 여러 dsid를 제출하고, 하나라도 실패하면 non-zero로 끝낸다.
# 개별 실패로 루프를 멈추지는 않는다 — 나머지는 넣어 두는 편이 낫다.
submit_many() {
    local d rc=0
    for d in $(printf '%s\n' "$@" | dedup_dsids); do
        submit_one "$d" || rc=1
    done
    return $rc
}

case "${1:-}" in
    --list)    list_all ;;
    --collect) shift; collect "${1:-}" ;;
    --collect-strata) shift; collect_strata "${1:-}" ;;
    --ready)
        preflight
        # shellcheck disable=SC2046
        submit_many $(p2_dsids_primary) ;;
    "") echo "사용법: $0 --list | --ready | --collect [out.tsv] | <dsid> [dsid ...]"; exit 1 ;;
    *)  preflight
        submit_many "$@" ;;
esac
