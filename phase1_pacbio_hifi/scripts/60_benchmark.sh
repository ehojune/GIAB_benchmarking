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
#
# 왜 raw VCF 를 넣는가: hap.py 는 FILTER 를 자체 처리해 summary.csv 에 ALL 행과 PASS 행을
# 둘 다 낸다. 파이프라인의 03_VCF/<caller>/*.vcf.gz 는 RefCall 을 포함하지만(PASS 필터 없음)
# 그대로 넣고 PASS 행을 읽으면 된다. SNV/INDEL 분리본을 넣으면 hap.py 자체 분류와 어긋나므로
# 쓰지 않는다.
#
# 대상: v4.2.1 truth set 이 있는 HG001~HG007 만. HG008-*/HG009* 는 germline truth 가 없어
# 자동으로 빠진다 (somatic draft benchmark 는 아직 매니페스트에 없다 — README 참고).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"
PHASE1="$P1_DIR"
REPO="$(cd "$PHASE1/.." && pwd)"
CALLERS="${CALLERS:-deepvariant clair3}"
BENCH_SUB="05_BENCH/happy"

# 캐시된 singularity 이미지 경로. 01_prepare_login_node.sh 와 같은 파일명 규약.
img_path() { echo "$NXF_SINGULARITY_CACHEDIR/$(echo "$1" | sed 's#[/:]#-#g').img"; }

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
    [ -s "$REF_FASTA" ] || { echo "ERROR: 레퍼런스 없음 ($REF_FASTA) — 01_prepare_login_node.sh 먼저"; exit 1; }
    [ -s "$REF_FASTA.fai" ] || { echo "ERROR: $REF_FASTA.fai 없음 — hap.py 가 요구한다"; exit 1; }
    local i; i=$(img_path "$HAPPY_IMG")
    [ -s "$i" ] || { echo "ERROR: hap.py 이미지 없음 ($i) — 01_prepare_login_node.sh 재실행"; exit 1; }
    mkdir -p "$INFRA/jobs" "$INFRA/logs" "$INFRA/launch"
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
    if p1_job_alive "bench.$dsid"; then
        echo "SKIP $dsid: 이미 큐/실행 중"; return 0
    fi

    mkdir -p "$base/$BENCH_SUB" "$INFRA/launch/bench.$dsid"
    local job="$INFRA/jobs/bench.$dsid.sh" simg
    simg=$(img_path "$HAPPY_IMG")

    cat > "$job" <<EOF
#!/bin/bash
#\$ -N b1.$dsid
#\$ -q $SGE_QUEUE
#\$ -pe $SGE_PE $BENCH_SLOTS
#\$ -S /bin/bash
#\$ -V
#\$ -j y
#\$ -o $INFRA/logs/bench.$dsid.\$JOB_ID.log
#\$ -l h_vmem=$BENCH_VMEM
#\$ -l h='$SGE_HOSTS'
#\$ -wd $INFRA/launch/bench.$dsid
set -euo pipefail
source "$REPO/phase1_pacbio_hifi/env.sh"

THREADS="\${NSLOTS:-$BENCH_SLOTS}"
TMP="$INFRA/launch/bench.$dsid/tmp"
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
            --logfile "$base/$BENCH_SUB/$id.\$c.hap.py.log"
done
echo "ALL DONE $dsid"
EOF
    chmod +x "$job"

    if [ "${DRY:-0}" = 1 ]; then
        echo "DRY $dsid: $job 생성만 함 (callers:$todo)"; return 0
    fi
    local out jid
    out=$(qsub "$job" < /dev/null)
    jid=$(echo "$out" | grep -oE '[0-9]+' | head -1)
    echo "$jid" > "$INFRA/jobs/bench.$dsid.jobid"
    echo "OK  $dsid: jobid=$jid callers:$todo truth=$(basename "$truth_vcf")"
}

# summary.csv 를 한 장으로 모은다. hap.py 는 Type(SNP/INDEL) x Filter(ALL/PASS) 로 행을 낸다.
# PASS 행이 실제 성능이다 (RefCall 이 빠진 값).
collect() {
    local out="${1:-$REPO/phase1_bench_summary.tsv}" dsid r sample dataset id base c f
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

case "${1:-}" in
    --list)    list_all ;;
    --collect) shift; collect "${1:-}" ;;
    --ready)
        preflight
        for d in $(p1_dsids_primary); do submit_one "$d" || true; done ;;
    "") echo "사용법: $0 --list | --ready | --collect [out.tsv] | <dsid> [dsid ...]"; exit 1 ;;
    *)  preflight
        for d in "$@"; do submit_one "$d" || true; done ;;
esac
