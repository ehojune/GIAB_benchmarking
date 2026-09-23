#!/bin/bash
# germline small variant 정확도 평가. GIAB truth set 대비 hap.py.
#
#   scripts/60_benchmark.sh --list             대상/상태 훑기
#   scripts/60_benchmark.sh --ready            VCF 완료 + truth set 있는 것 전부 제출
#   scripts/60_benchmark.sh <dsid> [dsid ...]  지정 제출
#   scripts/60_benchmark.sh --collect          끝난 결과를 한 TSV로 모음
#
# 환경 변수: DRY=1     qsub 하지 않고 잡 스크립트만 생성
#            FORCE=1   결과가 이미 있어도 재제출
#            CALLERS="deepvariant clair3"  평가할 caller (기본 둘 다)
#            DUP_OK=1  dup_of 표시분도 제출
#            STRAT=1   구간별(층화) 평가. 아래 설명
#
# **STRAT=1 — 구간별 평가.** 기본 실행은 benchmark BED 전체를 한 덩어리로 채점한다. 그 점수로는
# Sequel I 의 INDEL 격차가 호모폴리머 때문인지, Revio 에서 Clair3 가 DeepVariant 에 지는 곳이
# 어디인지 알 수 없다. STRAT=1 은 GIAB genome-stratifications($BENCH_STRAT_VER)에서 고른 구간을
# hap.py --stratification 으로 함께 센다. 산출은 05_BENCH/happy_strat/ 에 따로 둔다 — 기본 결과를
# 덮지 않고, `*` 행이 기본 결과와 같은지로 두 실행을 대조한다(--collect 가 확인).
#   STRAT=1 scripts/60_benchmark.sh --ready / <dsid> / --collect
# 고른 구간 목록은 env.sh 의 BENCH_STRAT_SET. "all" 이면 GIAB 목록 전체(188개).
#
# 왜 raw VCF 를 넣는가: hap.py 는 FILTER 를 자체 처리해 summary.csv 에 ALL 행과 PASS 행을
# 둘 다 낸다. 파이프라인의 03_VCF/<caller>/*.vcf.gz 는 RefCall 을 포함하지만(PASS 필터 없음)
# 그대로 넣고 PASS 행을 읽으면 된다. SNV/INDEL 분리본을 넣으면 hap.py 자체 분류와 어긋나므로
# 쓰지 않는다.
#
# 대상: v4.2.1 truth set 이 있는 HG001~HG007 만. HG008-*/HG009* 는 germline truth 가 없어
# 자동으로 빠진다. HG008 somatic draft benchmark 는 디스크에 있지만 germline caller 출력에
# 그대로 댈 수 없어 별도 경로다 (docs/backlog.md #9).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

# 잡의 -q 에 들어갈 값. preflight 가 qstat 과 대조해 실재하는 큐만 남긴 값으로 덮는다.
# preflight 를 거치지 않는 경로(--list 등)를 위한 기본값이 이것이다.
SGE_Q_ARG="$SGE_QUEUE"
PHASE1="$P1_DIR"
CALLERS="${CALLERS:-deepvariant clair3}"
STRAT="${STRAT:-0}"
# 모드별로 갈리는 것은 여기 넷이 전부다. 잡 이름·jobid 키가 다르므로 두 모드가 같은 dsid 로
# 동시에 큐에 있어도 서로를 "이미 실행 중" 으로 보지 않는다.
if [ "$STRAT" = 1 ]; then
    BENCH_SUB="05_BENCH/happy_strat"; KEY=bstrat; JOBP=b2
    SLOTS="$BENCH_STRAT_SLOTS"; VMEM="$BENCH_STRAT_VMEM"
else
    BENCH_SUB="05_BENCH/happy"; KEY=bench; JOBP=b1
    SLOTS="$BENCH_SLOTS"; VMEM="$BENCH_VMEM"
fi
STRAT_DIR="$GIAB_ROOT/release/genome-stratifications/$BENCH_STRAT_VER/${REF_NAME}@all"
STRAT_SRC="$STRAT_DIR/${REF_NAME}-all-stratifications.tsv"
STRAT_TSV="$INFRA/reference/strat/${REF_NAME}_${BENCH_STRAT_VER}_selected.tsv"

# 이미지 경로는 lib.sh의 p1_img_path를 쓴다 (01_prepare_login_node.sh와 같은 규약).

# sample -> "truth_vcf<TAB>truth_bed". 없으면 비어 있음.
# 디렉토리 깊이가 샘플마다 다르다: HG001 은 release/NA12878_HG001/NISTv4.2.1/,
# HG002~HG007 은 release/<Trio>/<Sample_dir>/NISTv4.2.1/. BED 이름도 갈린다 —
# Ashkenazim 트리오(HG002~HG004)는 _benchmark_noinconsistent.bed 를 쓴다.
bench_truth() {
    local s=$1 ver="$BENCH_TRUTH_VER" d vcf bed
    for d in "$GIAB_ROOT"/release/*/*/NIST"$ver"/"$REF_NAME" \
             "$GIAB_ROOT"/release/*/NIST"$ver"/"$REF_NAME"; do
        [ -d "$d" ] || continue
        vcf=$(ls "$d/${s}_"*_"$ver"_benchmark.vcf.gz 2>/dev/null | grep -v '/\._' | head -1) || true
        [ -n "$vcf" ] || continue
        # hap.py 는 truth VCF 의 tabix 인덱스를 요구한다. 없으면 잡이 한참 뒤에 죽으므로 여기서 걸러낸다.
        [ -s "$vcf.tbi" ] || continue
        bed=$(ls "$d/${s}_"*_"$ver"_benchmark.bed \
                 "$d/${s}_"*_"$ver"_benchmark_noinconsistent.bed 2>/dev/null \
              | grep -v '/\._' | head -1) || true
        [ -n "$bed" ] || continue
        printf '%s\t%s\n' "$vcf" "$bed"
        return 0
    done
    return 1
}

bench_done() {  # sample dataset caller -> 0 if summary.csv 존재
    local base="$RUN_BASE/$1/PacBio/$2" id="$1.$2.$REF_NAME"
    [ -s "$base/$BENCH_SUB/$id.$3.summary.csv" ]
}

list_all() {
    printf '%-46s %-9s %-7s %-8s %s\n' dsid vcf truth happy dup_of
    local dsid r sample dataset dup t v h c
    for dsid in $(p1_dsids); do
        r=$(p1_row "$dsid"); sample=$(p1_col "$r" 2); dataset=$(p1_col "$r" 3); dup=$(p1_col "$r" 8)
        v=-; p1_vcf_done "$sample" "$dataset" && v=OK
        t=none; bench_truth "$sample" >/dev/null 2>&1 && t="$BENCH_TRUTH_VER"
        h=""
        for c in $CALLERS; do bench_done "$sample" "$dataset" "$c" && h="$h${c:0:2}"; done
        printf '%-46s %-9s %-7s %-8s %s\n' "$dsid" "$v" "$t" "${h:--}" "$dup"
    done
    echo
    echo "truth=none 은 germline truth set 이 없는 것 (HG008/HG009). happy 열의 de/cl 은 완료된 caller."
}

preflight() {
    p1_qstat_refresh
    # 큐 x 노드가 안 겹치면 잡이 조용히 qw로 남는다 — 제출 전에 막는다 (lib.sh 설명).
    p1_require_sge_targets || exit 1
    SGE_Q_ARG="$(p1_sge_queue_arg)"
    [ -s "$REF_FASTA" ] || { echo "ERROR: 레퍼런스 없음 ($REF_FASTA) — 01_prepare_login_node.sh 먼저"; exit 1; }
    # hap.py는 레퍼런스 옆의 .fai를 요구하는데 이걸 만드는 곳이 없다 — 파이프라인의 SAMTOOLS_FAIDX는
    # publishDir 없이 Nextflow work 디렉토리 안에만 만들고, 01_prepare는 FASTA 압축만 푼다.
    # 여기서 1회 생성한다 (로그인 노드에 samtools가 없어 컨테이너로 — 03_dup_evidence.sh와 같은 방식).
    if [ ! -s "$REF_FASTA.fai" ]; then
        local st refdir
        st="$(p1_img_path "$(p1_container_uris | grep '/samtools:')")"
        refdir="$(dirname "$REF_FASTA")"
        [ -s "$st" ] || { echo "ERROR: $REF_FASTA.fai 없고 samtools 컨테이너도 없다 — 01_prepare_login_node.sh 먼저"; exit 1; }
        echo "  $REF_FASTA.fai 생성 (hap.py 요구, 1회)"
        singularity exec -B "$refdir:$refdir" "$st" samtools faidx "$REF_FASTA" \
            || { echo "ERROR: samtools faidx 실패 — $REF_FASTA 확인"; exit 1; }
    fi
    local i; i=$(p1_img_path "$HAPPY_IMG")
    [ -s "$i" ] || { echo "ERROR: hap.py 이미지 없음 ($i) — 01_prepare_login_node.sh 재실행"; exit 1; }
    mkdir -p "$INFRA/jobs" "$INFRA/logs" "$INFRA/launch"
    if [ "$STRAT" = 1 ]; then build_strat_tsv || exit 1; fi
}

# BENCH_STRAT_SET 의 이름을 GIAB 목록에서 찾아 **절대경로** TSV 를 만든다.
# GIAB 목록은 상대경로라 hap.py 가 어디서 도느냐에 따라 해석이 갈릴 수 있다 — 절대경로로 못박는다.
# 이름 하나라도 목록에 없거나 파일이 비어 있으면 제출 전에 멈춘다. hap.py 는 층화 BED 를 못 읽으면
# 한참 돌다 죽거나, 판에 따라 그 구간을 조용히 빼고 끝낸다.
build_strat_tsv() {
    local names name rel n=0 bad=0 tmp
    [ -s "$STRAT_SRC" ] || { echo "ERROR: 층화 목록 없음 ($STRAT_SRC) — BENCH_STRAT_VER 확인"; return 1; }
    if [ "$BENCH_STRAT_SET" = all ]; then names=$(cut -f1 "$STRAT_SRC"); else names="$BENCH_STRAT_SET"; fi
    mkdir -p "$(dirname "$STRAT_TSV")"
    tmp="$STRAT_TSV.tmp.$$"
    : > "$tmp"
    for name in $names; do
        rel=$(awk -F'\t' -v n="$name" '$1==n {print $2; exit}' "$STRAT_SRC")
        if [ -z "$rel" ]; then echo "  ! 목록에 없는 층화: $name"; bad=1; continue; fi
        if [ ! -s "$STRAT_DIR/$rel" ]; then echo "  ! 파일 없음: $STRAT_DIR/$rel"; bad=1; continue; fi
        printf '%s\t%s\n' "$name" "$STRAT_DIR/$rel" >> "$tmp"
        n=$((n + 1))
    done
    if [ "$bad" != 0 ] || [ "$n" = 0 ]; then
        rm -f "$tmp"; echo "ERROR: 층화 TSV 를 못 만들었다 ($STRAT_SRC)"; return 1
    fi
    mv "$tmp" "$STRAT_TSV"
    echo "  층화 $n 개 ($BENCH_STRAT_VER) -> $STRAT_TSV"
}

submit_one() {
    local dsid=$1 r sample dataset dup tv truth_vcf truth_bed base id c todo=""
    r=$(p1_row "$dsid")
    [ -n "$r" ] || { echo "SKIP $dsid: run_table.tsv에 없음"; return 1; }
    sample=$(p1_col "$r" 2); dataset=$(p1_col "$r" 3); dup=$(p1_col "$r" 8)

    if [ -n "$dup" ] && [ "${DUP_OK:-0}" != 1 ]; then
        echo "SKIP $dsid: $dup 와 동일 movie 세트. 그래도 돌리려면 DUP_OK=1"; return 0
    fi
    if ! tv=$(bench_truth "$sample"); then
        echo "SKIP $dsid: $sample 의 $BENCH_TRUTH_VER germline truth set 없음"; return 0
    fi
    truth_vcf=${tv%%$'\t'*}; truth_bed=${tv#*$'\t'}
    if ! p1_vcf_done "$sample" "$dataset"; then
        echo "SKIP $dsid: VCF 미완 — 30_verify_outputs.sh 확인"; return 0
    fi
    base="$RUN_BASE/$sample/PacBio/$dataset"; id="$sample.$dataset.$REF_NAME"
    for c in $CALLERS; do
        if bench_done "$sample" "$dataset" "$c" && [ "${FORCE:-0}" != 1 ]; then continue; fi
        [ -s "$base/03_VCF/$c/$id.$c.vcf.gz" ] || { echo "  ! $dsid: $c VCF 없음, 건너뜀"; continue; }
        todo="$todo $c"
    done
    if [ -z "$todo" ]; then
        echo "SKIP $dsid: 평가 완료 (재실행은 FORCE=1)"; return 0
    fi
    if p1_job_alive "$KEY.$dsid"; then
        echo "SKIP $dsid: 이미 큐/실행 중"; return 0
    fi

    local launch="$INFRA/launch/$KEY.$dsid"
    mkdir -p "$base/$BENCH_SUB" "$launch"
    local job="$INFRA/jobs/$KEY.$dsid.sh" simg strat_arg="" thr_line
    simg=$(p1_img_path "$HAPPY_IMG")
    # 기본 실행은 슬롯 = 스레드. 층화 실행은 스레드를 슬롯보다 적게 고정한다 — hap.py 메모리가
    # 스레드에 비례하고(env.sh), 층화 BED 가 스레드(프로세스)마다 따로 올라갈 것으로 보여 계수가 더 커진다(미실측).
    # 슬롯은 노드당 동시 실행 수를 막는 용도로만 쓴다 (61_benchmark_sv.sh 의 BENCH_SV_THREADS 와 같은 구조).
    if [ "$STRAT" = 1 ]; then
        thr_line="THREADS=$BENCH_STRAT_THREADS"
    else
        thr_line='THREADS="${NSLOTS:-'"$SLOTS"'}"'
    fi
    # 층화 TSV 는 잡마다 사본을 둔다. 큐에서 기다리는 동안 누가 BENCH_STRAT_SET 을 바꿔
    # 다시 제출해도 이미 들어간 잡은 제출 시점의 목록으로 돈다.
    if [ "$STRAT" = 1 ]; then
        cp "$STRAT_TSV" "$launch/strata.tsv" || { echo "FAIL $dsid: 층화 TSV 복사 실패"; return 1; }
        strat_arg=" --stratification $launch/strata.tsv"   # 앞 공백 포함: 비면 b1 잡이 한 글자도 안 바뀐다
    fi

    # 쓰기가 실패하면(디스크 참, 권한) 예전 잡 스크립트가 남아 엉뚱한 걸 제출하게 된다.
    # 호출부의 `|| rc=1` 때문에 이 함수 안에서는 errexit가 꺼져 있으니 직접 본다.
    if ! cat > "$job" <<EOF
#!/bin/bash
#\$ -N $JOBP.$dsid
#\$ -q $SGE_Q_ARG
#\$ -pe $SGE_PE $SLOTS
#\$ -S /bin/bash
#\$ -V
#\$ -j y
#\$ -o $INFRA/logs/$KEY.$dsid.\$JOB_ID.log
#\$ -l h_vmem=$VMEM
#\$ -l h='$SGE_HOSTS'
#\$ -wd $launch
set -euo pipefail
source "$PHASE1/env.sh"

$thr_line
TMP="$launch/tmp"
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
            -f "$truth_bed"$strat_arg \\
            -r "$REF_FASTA" \\
            -o "$base/$BENCH_SUB/$id.\$c" \\
            --threads "\$THREADS" \\
            --scratch-prefix "\$TMP" \\
            --logfile "$base/$BENCH_SUB/$id.\$c.hap.py.log"
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
    echo "$jid" > "$INFRA/jobs/$KEY.$dsid.jobid" \
        || { echo "FAIL $dsid: jobid=$jid 로 제출됐으나 기록 실패 — $INFRA/jobs/$KEY.$dsid.jobid"; return 1; }
    echo "OK  $dsid: jobid=$jid callers:$todo truth=$(basename "$truth_vcf")"
}

# 같은 dsid가 두 번 들어오면 같은 출력 경로에 잡 둘이 동시에 쓴다.
# p1_job_alive는 preflight 때 뜬 qstat 스냅샷을 보므로 방금 넣은 잡을 못 본다 — 입력에서 잘라낸다.
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

# summary.csv 를 한 장으로 모은다. hap.py 는 Type(SNP/INDEL) x Filter(ALL/PASS) 로 행을 낸다.
# PASS 행이 실제 성능이다 (RefCall 이 빠진 값).
collect() {
    local out="${1:-$PHASE1/phase1_bench_summary.tsv}" dsid r sample dataset id base c f
    {
        printf 'dsid\tsample\tdataset\tcaller\ttype\tfilter\ttruth_total\ttp\tfn\tfp\trecall\tprecision\tf1\n'
        for dsid in $(p1_dsids); do
            r=$(p1_row "$dsid"); sample=$(p1_col "$r" 2); dataset=$(p1_col "$r" 3)
            base="$RUN_BASE/$sample/PacBio/$dataset"; id="$sample.$dataset.$REF_NAME"
            for c in $CALLERS; do
                f="$base/$BENCH_SUB/$id.$c.summary.csv"
                [ -s "$f" ] || continue
                awk -F, -v d="$dsid" -v s="$sample" -v ds="$dataset" -v cl="$c" '
                    NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
                    {
                      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                        d, s, ds, cl, $h["Type"], $h["Filter"],
                        $h["TRUTH.TOTAL"], $h["TRUTH.TP"], $h["TRUTH.FN"], $h["QUERY.FP"],
                        $h["METRIC.Recall"], $h["METRIC.Precision"], $h["METRIC.F1_Score"]
                    }' "$f"
            done
        done
    } > "$out"
    echo "-> $out ($(($(wc -l < "$out") - 1)) rows)"
    echo
    echo "PASS 행만 보기:"
    echo "  awk -F'\\t' 'NR==1 || \$6==\"PASS\"' $out | column -t -s\$'\\t' | head -30"
}

# STRAT=1 결과를 한 장으로 모은다. extended.csv 에서 Subtype=* · Genotype=* 행만 쓴다
# (그 둘을 더 쪼갠 행은 합계가 아니라 부분이다). 열은 헤더 이름으로 찾는다 — hap.py 판마다
# 열 순서가 다를 수 있다.
#
# 대조: Subset=* 행은 층화와 무관한 전체 점수라 기본 실행(05_BENCH/happy)의 summary.csv 와
# TP·FN·FP 가 **같아야 한다**. 다르면 두 실행의 입력(VCF·truth·BED·엔진)이 어긋난 것이고,
# 그 상태의 구간 점수는 기본 점수와 나란히 놓을 수 없다. 불일치는 경고로 모아 끝에 보인다.
collect_strat() {
    local out="${1:-$PHASE1/phase1_bench_strat_summary.tsv}" dsid r sample dataset id base c f b1 n_bad=0 n_chk=0
    {
        printf 'dsid\tsample\tdataset\tcaller\ttype\tsubset\tfilter\ttruth_total\ttp\tfn\tquery_total\tfp\trecall\tprecision\tf1\tsubset_size\tsubset_conf_size\n'
        for dsid in $(p1_dsids); do
            r=$(p1_row "$dsid"); sample=$(p1_col "$r" 2); dataset=$(p1_col "$r" 3)
            base="$RUN_BASE/$sample/PacBio/$dataset"; id="$sample.$dataset.$REF_NAME"
            for c in $CALLERS; do
                f="$base/$BENCH_SUB/$id.$c.extended.csv"
                [ -s "$f" ] || continue
                awk -F, -v d="$dsid" -v s="$sample" -v ds="$dataset" -v cl="$c" '
                    function g(k) { return (k in h) ? $h[k] : "NA" }
                    NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
                    g("Subtype")=="*" && g("Genotype")=="*" {
                      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                        d, s, ds, cl, g("Type"), g("Subset"), g("Filter"),
                        g("TRUTH.TOTAL"), g("TRUTH.TP"), g("TRUTH.FN"), g("QUERY.TOTAL"), g("QUERY.FP"),
                        g("METRIC.Recall"), g("METRIC.Precision"), g("METRIC.F1_Score"),
                        g("Subset.Size"), g("Subset.IS_CONF.Size")
                    }' "$f"
            done
        done
    } > "$out"
    echo "-> $out ($(($(wc -l < "$out") - 1)) rows)"

    # 기본 실행과 대조 (Subset=* 의 TP/FN/FP)
    for dsid in $(p1_dsids); do
        r=$(p1_row "$dsid"); sample=$(p1_col "$r" 2); dataset=$(p1_col "$r" 3)
        base="$RUN_BASE/$sample/PacBio/$dataset"; id="$sample.$dataset.$REF_NAME"
        for c in $CALLERS; do
            b1="$base/05_BENCH/happy/$id.$c.summary.csv"
            [ -s "$b1" ] && [ -s "$base/$BENCH_SUB/$id.$c.extended.csv" ] || continue
            n_chk=$((n_chk + 1))
            # 두 파일의 구분자가 달라(탭/쉼표) 키는 FS 가 아니라 고정 문자 "|" 로 잇는다.
            if ! awk -F'\t' -v d="$dsid" -v cl="$c" '
                    FNR==NR { if ($1==d && $4==cl && $6=="*") k[$5 "|" $7]=$9 "|" $10 "|" $12; next }
                    FNR==1  { for (i=1;i<=NF;i++) h[$i]=i; next }
                    { key=$h["Type"] "|" $h["Filter"]; v=$h["TRUTH.TP"] "|" $h["TRUTH.FN"] "|" $h["QUERY.FP"]
                      n++; if (!(key in k) || k[key]!=v) bad=1 }
                    END { exit (bad || n==0) }' "$out" FS=, "$b1"; then
                echo "  ! 불일치: $dsid / $c — Subset=* 가 기본 실행 summary.csv 와 다르다"
                n_bad=$((n_bad + 1))
            fi
        done
    done
    echo "기본 실행과 대조: $n_chk 건 중 불일치 $n_bad 건"
    echo
    echo "보기 (PASS, 한 런):"
    echo "  awk -F'\\t' 'NR==1 || (\$7==\"PASS\" && \$1==\"<dsid>\")' $out | column -t -s\$'\\t'"
}

case "${1:-}" in
    --list)    list_all ;;
    --collect)
        shift
        if [ "$STRAT" = 1 ]; then collect_strat "${1:-}"; else collect "${1:-}"; fi ;;
    --ready)
        preflight
        # shellcheck disable=SC2046
        submit_many $(p1_dsids_primary) ;;
    "") echo "사용법: $0 --list | --ready | --collect [out.tsv] | <dsid> [dsid ...]"; exit 1 ;;
    *)  preflight
        submit_many "$@" ;;
esac
