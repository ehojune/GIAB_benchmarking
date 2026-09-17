#!/bin/bash
# 구조변이(SV) 정확도 평가. GIAB HG002 SV truth set 대비 Truvari.
# 소변이(SNV/INDEL)는 60_benchmark.sh(hap.py)가 한다. 이쪽은 03_VCF/SV_sniffles/ 를 본다.
#
#   scripts/61_benchmark_sv.sh --list             대상/상태 훑기
#   scripts/61_benchmark_sv.sh --ready            SV VCF 완료 + truth set 있는 것 전부 제출
#   scripts/61_benchmark_sv.sh <dsid> [dsid ...]  지정 제출
#   scripts/61_benchmark_sv.sh --collect [out]    끝난 결과를 한 TSV로 모음
#
# 환경 변수: DRY=1                qsub 하지 않고 잡 스크립트만 생성
#            FORCE=1              결과가 이미 있어도 재제출
#            DUP_OK=1             dup_of 표시분도 제출
#            BENCH_SV_REFINE=0    truvari --refine 끄기 (기본 1)
#            BENCH_SV_ALIGN=mafft refine 정렬기 고정 (기본은 truvari 기본값 poa)
#
# ── 대상이 HG002 두 런뿐인 이유 ───────────────────────────────────────────
# GRCh38 germline SV truth를 가진 GIAB 샘플은 HG002 하나다 (release_truthsets.tsv 실측).
#   HG002_GRCh38_v5.0q_stvar      전장. T2T-Q100 유래. **이걸 쓴다**
#   HG002_GRCh38_CMRG_SV_v1.00    의학적 중요 유전자 한정(38 KB). 보조용, 여기선 안 쓴다
#   HG002_SVs_Tier1_v0.6          **GRCh37 전용** — 우리 런은 전부 GRCh38라 못 쓴다
# HG001·HG003~HG007에는 SV truth가 아예 없다. HG008 draft benchmark는 somatic-stvar/CNV라
# 단일 샘플 germline SV 평가에 못 쓴다 — 60_benchmark.sh가 소변이에서 부딪힌 것과 같은 벽이다.
# 그래서 dup_of가 빈 HG002 런 둘(guppy-V3.4.5, UCSC_Ultralong_..._Promethion)이 전부다.
# 둘 다 R9.4.1이라 이 단계로는 **R10 SV 성능을 알 수 없다.**
#
# ── Truvari 파라미터 근거 ─────────────────────────────────────────────────
# GIAB v5.0q README(NIST_HG002_v5.0q_variant-benchmarksets_README.md)가 지정한 명령 그대로다:
#   truvari bench -b <truth> -c <call> -o <out> -f <ref> --includebed <bed> \
#                 --pick ac --passonly -r 2000 -C 5000 --refine
# truvari 5.4.0 기본값과 다른 건 둘뿐이다 — -r 2000(기본 500), -C 5000(기본 1000).
# **-C는 chunksize지 sizemin이 아니다.** 나머지는 기본값을 그대로 둔다:
# sizemin 50 / sizefilt 30 / sizemax 50,000 / pctseq 0.70 / pctsize 0.70 / bnddist 100.
# README가 -d(--dup-to-ins)를 지정하지 않는 이유는 --refine 이 그 표현 차이를 흡수하기 때문이다.
# 끄고 돌릴 거면 BENCH_SV_ARGS="-d" 를 같이 주는 편이 낫다 (Sniffles는 <DUP>을 낸다).
#
# --refine 은 phab로 복잡영역의 표현을 정규화한다. 끄면 탠덤반복 구간의 Sniffles 콜이
# 표현 차이만으로 FP가 되어 수치가 실제보다 나쁘게 나온다. 대신 두 가지를 감수한다.
#   (1) 기본 정렬기 poa는 **머신 간 비결정적**이다(truvari 문서). 재현이 필요하면 BENCH_SV_ALIGN=mafft.
#   (2) refine이 변이 표현을 바꿔 어느 콜이 TP/FP였는지 되짚기 어려워진다(README 경고).
# 그래서 --collect 는 refine 전(summary.json)과 후(refine.variant_summary.json)를 **둘 다** 낸다.
# 얼마나 움직였는지가 보여야 수치를 믿을지 판단할 수 있다.
#
# README가 "ALT=* 는 오분류되니 미리 걸러라"고 해서 truth를 한 번 걸러 $INFRA에 캐시한다.
# 잡마다 만들면 동시 실행이 같은 파일을 덮어쓰므로 preflight(로그인 노드)에서 만든다.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"
PHASE2="$P2_DIR"
BENCH_SV_SUB="05_BENCH/truvari"
TRUTH_CACHE="$INFRA/reference/sv_truth"

# sample -> "truth_vcf<TAB>truth_bed". 없으면 1을 낸다.
# 디렉토리 깊이가 샘플마다 다르므로 60_benchmark.sh의 bench_truth와 같은 2단 글롭을 쓴다.
# v5.0q는 release/AshkenazimTrio/HG002_NA24385_son/v5.0q/ 에 있다(latest/ 에도 같은 파일이
# 있지만 판을 고정해야 결과를 비교할 수 있어 버전 디렉토리를 본다).
sv_truth() {
    local s=$1 ver="$BENCH_SV_TRUTH_VER" d vcf bed
    for d in "$GIAB_ROOT"/release/*/*/"$ver" "$GIAB_ROOT"/release/*/"$ver"; do
        [ -d "$d" ] || continue
        vcf="$d/${s}_${REF_NAME}_${ver}_stvar.vcf.gz"
        bed="$d/${s}_${REF_NAME}_${ver}_stvar.benchmark.bed"
        # tbi가 없으면 truvari가 한참 뒤에 죽는다 — 여기서 걸러낸다.
        [ -s "$vcf" ] && [ -s "$vcf.tbi" ] && [ -s "$bed" ] || continue
        printf '%s\t%s\n' "$vcf" "$bed"
        return 0
    done
    return 1
}

# ALT=* 를 걸러낸 truth 경로를 낸다. 없으면 만든다 (로그인 노드, bcftools 컨테이너).
sv_truth_filtered() {
    local src=$1 dst bt
    # dst를 위의 local 줄에서 같이 잡으면 안 된다 — local은 빌트인이라 인자를 전부 먼저 확장한 뒤
    # 대입한다. 그 시점엔 src가 아직 없어서 경로가 ".noast.vcf.gz"로 뭉개진다(set -u면 에러까지).
    dst="$TRUTH_CACHE/$(basename "${src%.vcf.gz}").noast.vcf.gz"
    if [ -s "$dst" ] && [ -s "$dst.tbi" ]; then echo "$dst"; return 0; fi
    # DRY는 아무것도 만들지 않는다 — 잡 스크립트가 가리킬 경로만 알려준다.
    if [ "${DRY:-0}" = 1 ]; then
        echo "  (DRY) truth 캐시 미생성 — 실제 실행 때 만든다: $dst" >&2
        echo "$dst"; return 0
    fi
    bt="$(p2_img_path "$(p2_container_uris | grep '/bcftools:')")"
    [ -s "$bt" ] || { echo "ERROR: bcftools 컨테이너가 없다 ($bt) — 01_prepare_login_node.sh 먼저" >&2; return 1; }
    mkdir -p "$TRUTH_CACHE"
    echo "  ALT=* 를 걸러 truth 캐시 생성 (1회): $(basename "$dst")" >&2
    # 중간에 죽어도 반쪽짜리가 캐시로 남지 않게 임시 이름으로 만들고 마지막에 옮긴다.
    singularity exec -B "$GIAB_ROOT:$GIAB_ROOT" -B "$INFRA:$INFRA" "$bt" \
        bcftools view -e 'ALT="*"' -Oz -o "$dst.tmp" "$src" >&2 \
        || { rm -f "$dst.tmp"; echo "ERROR: bcftools view 실패 — $src" >&2; return 1; }
    singularity exec -B "$INFRA:$INFRA" "$bt" tabix -f -p vcf "$dst.tmp" >&2 \
        || { rm -f "$dst.tmp" "$dst.tmp.tbi"; echo "ERROR: tabix 실패 — $dst.tmp" >&2; return 1; }
    mv "$dst.tmp.tbi" "$dst.tbi" && mv "$dst.tmp" "$dst"
    echo "$dst"
}

sv_call_vcf() {  # sample dataset -> Sniffles VCF 경로 (존재 여부는 호출부에서)
    echo "$RUN_BASE/$1/ONT/$2/03_VCF/SV_sniffles/$1.$2.$REF_NAME.sniffles.vcf.gz"
}

bench_sv_done() {  # sample dataset -> 0 if summary.json 존재
    [ -s "$RUN_BASE/$1/ONT/$2/$BENCH_SV_SUB/summary.json" ]
}

# 같은 dsid가 두 번 들어오면 같은 출력 경로에 잡 둘이 동시에 쓴다.
# p2_job_alive는 preflight 때 뜬 qstat 스냅샷을 보므로 방금 넣은 잡을 못 본다 — 입력에서 잘라낸다.
dedup_dsids() { awk 'NF && !seen[$0]++'; }

list_all() {
    printf '%-46s %-5s %-7s %-7s %-8s %s\n' dsid chem sv_vcf truth truvari dup_of
    local dsid r sample dataset dup chem t v b
    for dsid in $(p2_dsids); do
        r=$(p2_row "$dsid"); sample=$(p2_col "$r" 2); dataset=$(p2_col "$r" 3)
        dup=$(p2_col "$r" 12)
        case "$(p2_col "$r" 7)" in *R10*) chem=R10 ;; *) chem=R9 ;; esac
        v=-; [ -s "$(sv_call_vcf "$sample" "$dataset")" ] && v=OK
        t=none; sv_truth "$sample" >/dev/null 2>&1 && t="$BENCH_SV_TRUTH_VER"
        b=-; bench_sv_done "$sample" "$dataset" && b=done
        printf '%-46s %-5s %-7s %-7s %-8s %s\n' "$dsid" "$chem" "$v" "$t" "$b" "$dup"
    done
    echo
    echo "truth=none 은 그 샘플에 GRCh38 germline SV truth set이 없다는 뜻이다."
    echo "GIAB에서 그걸 가진 샘플은 HG002 하나뿐 — HG002_SVs_Tier1_v0.6은 GRCh37 전용이라 못 쓴다."
}

preflight() {
    p2_qstat_refresh
    [ -s "$REF_FASTA" ] || { echo "ERROR: 레퍼런스 없음 ($REF_FASTA) — 01_prepare_login_node.sh 먼저"; exit 1; }
    # truvari도 hap.py와 같이 레퍼런스 옆의 .fai를 요구한다(-f 로 심볼릭 ALT를 푼다).
    # 60_benchmark.sh가 이미 만들었으면 그대로 쓴다.
    if [ ! -s "$REF_FASTA.fai" ]; then
        local st refdir
        st="$(p2_img_path "$(p2_container_uris | grep '/samtools:')")"
        refdir="$(dirname "$REF_FASTA")"
        [ -s "$st" ] || { echo "ERROR: $REF_FASTA.fai 없고 samtools 컨테이너도 없다 — 01_prepare_login_node.sh 먼저"; exit 1; }
        echo "  $REF_FASTA.fai 생성 (1회)"
        singularity exec -B "$refdir:$refdir" "$st" samtools faidx "$REF_FASTA" \
            || { echo "ERROR: samtools faidx 실패 — $REF_FASTA 확인"; exit 1; }
    fi
    local i; i=$(p2_img_path "$TRUVARI_IMG")
    [ -s "$i" ] || { echo "ERROR: truvari 이미지 없음 ($i) — 01_prepare_login_node.sh 재실행"; exit 1; }
    mkdir -p "$INFRA/jobs" "$INFRA/logs" "$INFRA/launch"
}

submit_one() {
    local dsid=$1 r sample dataset dup tv truth_vcf truth_bed call base out job simg refine_arg
    r=$(p2_row "$dsid")
    [ -n "$r" ] || { echo "SKIP $dsid: run_table.tsv에 없음"; return 1; }
    sample=$(p2_col "$r" 2); dataset=$(p2_col "$r" 3); dup=$(p2_col "$r" 12)

    if [ -n "$dup" ] && [ "${DUP_OK:-0}" != 1 ]; then
        echo "SKIP $dsid: $dup 와 같은 플로우셀의 재베이스콜. 그래도 돌리려면 DUP_OK=1"; return 0
    fi
    if ! tv=$(sv_truth "$sample"); then
        echo "SKIP $dsid: $sample 의 $BENCH_SV_TRUTH_VER SV truth set 없음"; return 0
    fi
    truth_vcf=${tv%%$'\t'*}; truth_bed=${tv#*$'\t'}
    call=$(sv_call_vcf "$sample" "$dataset")
    [ -s "$call" ] || { echo "SKIP $dsid: Sniffles VCF 없음 — 30_verify_outputs.sh 확인"; return 0; }
    # truvari는 comp VCF의 tabix 인덱스를 요구한다. 파이프라인이 같이 내지만 확인하고 넘어간다.
    [ -s "$call.tbi" ] || { echo "SKIP $dsid: $call.tbi 없음"; return 0; }
    if bench_sv_done "$sample" "$dataset" && [ "${FORCE:-0}" != 1 ]; then
        echo "SKIP $dsid: 평가 완료 (재실행은 FORCE=1)"; return 0
    fi
    if p2_job_alive "svbench.$dsid"; then
        echo "SKIP $dsid: 이미 큐/실행 중"; return 0
    fi
    # ALT=* 를 걸러낸 판을 만든다(캐시). 로그인 노드에서 하므로 잡끼리 경합하지 않는다.
    local truth_use
    truth_use=$(sv_truth_filtered "$truth_vcf") || { echo "FAIL $dsid: truth 전처리 실패"; return 1; }

    base="$RUN_BASE/$sample/ONT/$dataset"; out="$base/$BENCH_SV_SUB"
    mkdir -p "$base/05_BENCH" "$INFRA/launch/svbench.$dsid"
    job="$INFRA/jobs/svbench.$dsid.sh"
    simg=$(p2_img_path "$TRUVARI_IMG")
    refine_arg=""
    if [ "${BENCH_SV_REFINE:-1}" = 1 ]; then
        refine_arg="--refine"
        [ -n "${BENCH_SV_ALIGN:-}" ] && refine_arg="$refine_arg --align $BENCH_SV_ALIGN"
    fi

    cat > "$job" <<EOF
#!/bin/bash
#\$ -N s2.$dsid
#\$ -q $SGE_QUEUE
#\$ -pe $SGE_PE $BENCH_SV_SLOTS
#\$ -S /bin/bash
#\$ -V
#\$ -j y
#\$ -o $INFRA/logs/svbench.$dsid.\$JOB_ID.log
#\$ -l h_vmem=$BENCH_SV_VMEM
#\$ -l h='$SGE_HOSTS'
#\$ -wd $INFRA/launch/svbench.$dsid
set -euo pipefail
source "$PHASE2/env.sh"

export TMPDIR="$INFRA/launch/svbench.$dsid/tmp"
mkdir -p "\$TMPDIR"

# truvari bench 는 출력 디렉토리가 이미 있으면 거부한다. 재실행(FORCE=1)을 위해 비우고 시작한다.
rm -rf "$out"

echo "== truvari bench : $sample.$dataset =="
echo "   truth = $truth_use"
echo "   call  = $call"
singularity exec \\
    -B "$GIAB_ROOT:$GIAB_ROOT" \\
    -B "$RUN_BASE:$RUN_BASE" \\
    -B "$INFRA:$INFRA" \\
    "$simg" \\
    truvari bench \\
        -b "$truth_use" \\
        -c "$call" \\
        -o "$out" \\
        -f "$REF_FASTA" \\
        --includebed "$truth_bed" \\
        --pick ac \\
        --passonly \\
        -r 2000 \\
        -C 5000 \\
        $refine_arg ${BENCH_SV_ARGS:-}

echo "ALL DONE $dsid"
EOF
    chmod +x "$job"

    if [ "${DRY:-0}" = 1 ]; then
        echo "DRY $dsid: $job 생성만 함 (refine:${BENCH_SV_REFINE:-1})"; return 0
    fi
    # 호출부가 실패를 모아 처리하므로 errexit에 기대지 않고 qsub 결과를 직접 본다.
    local qout jid
    if ! qout=$(qsub "$job" < /dev/null 2>&1); then   # stderr 까지 잡아야 FAIL 메시지가 쓸모 있다
        echo "FAIL $dsid: qsub 거부 — $qout"; return 1
    fi
    jid=$(echo "$qout" | grep -oE '[0-9]+' | head -1)
    [ -n "$jid" ] || { echo "FAIL $dsid: qsub 출력에서 jobid를 못 읽었다 — $qout"; return 1; }
    echo "$jid" > "$INFRA/jobs/svbench.$dsid.jobid"
    echo "OK  $dsid: jobid=$jid truth=$(basename "$truth_vcf") refine=${BENCH_SV_REFINE:-1}"
}

# 여러 dsid를 제출하고, 하나라도 실패하면 non-zero로 끝낸다.
# 개별 실패로 루프를 멈추지는 않는다 — 나머지는 넣어 두는 편이 낫다.
submit_many() {
    local d rc=0
    for d in $(printf '%s\n' "$@" | dedup_dsids); do
        submit_one "$d" || rc=1
    done
    return $rc
}

# summary.json(refine 전)과 refine.variant_summary.json(refine 후)을 한 TSV로 모은다.
# 둘 다 내는 이유: refine이 수치를 얼마나 움직였는지 보여야 그 값을 믿을지 판단할 수 있다.
collect() {
    local out="${1:-$PHASE2/phase2_bench_sv_summary.tsv}" py
    py="${PYTHON:-$(command -v python3 || command -v python || true)}"
    [ -n "$py" ] || { echo "ERROR: python이 없다. PYTHON=<경로> 로 지정할 것"; exit 1; }

    local rows=""
    local dsid r sample dataset chem bc base
    for dsid in $(p2_dsids); do
        r=$(p2_row "$dsid"); sample=$(p2_col "$r" 2); dataset=$(p2_col "$r" 3)
        case "$(p2_col "$r" 7)" in *R10*) chem=R10 ;; *) chem=R9 ;; esac
        bc=$(p2_col "$r" 8)
        base="$RUN_BASE/$sample/ONT/$dataset/$BENCH_SV_SUB"
        [ -d "$base" ] || continue
        rows="$rows$dsid\t$sample\t$dataset\t$chem\t$bc\t$base\n"
    done

    # %b 로 넘겨야 데이터 안의 % 가 포맷으로 해석되지 않는다 (basecaller 열은 자유 텍스트다).
    printf '%b' "$rows" | "$py" -c '
import json, os, sys

cols = ["dsid","sample","dataset","chem","basecaller","stage",
        "base_cnt","comp_cnt","tp_base","fp","fn","precision","recall","f1","gt_concordance"]
out = [ "\t".join(cols) ]

def num(v):
    if v is None: return "NA"
    if isinstance(v, float): return "%.6f" % v
    return str(v)

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line: continue
    dsid, sample, dataset, chem, bc, base = line.split("\t")
    for stage, fname in (("bench", "summary.json"),
                         ("refine", "refine.variant_summary.json")):
        p = os.path.join(base, fname)
        if not os.path.exists(p): continue
        try:
            with open(p) as fh: d = json.load(fh)
        except (ValueError, OSError) as e:
            sys.stderr.write("!! %s %s: %s\n" % (dsid, fname, e))
            continue
        out.append("\t".join([dsid, sample, dataset, chem, bc, stage] +
            [num(d.get(k)) for k in ("base cnt","comp cnt","TP-base","FP","FN",
                                     "precision","recall","f1","gt_concordance")]))

sys.stdout.write("\n".join(out) + "\n")
sys.stderr.write("rows: %d\n" % (len(out) - 1))
' > "$out"

    echo "-> $out ($(($(wc -l < "$out") - 1)) rows)"
    echo
    echo "  column -t -s\$'\\t' $out"
    echo
    echo "stage 열: bench = refine 전, refine = refine 후. 둘의 차이가 크면 복잡영역 표현 차이가"
    echo "그만큼 컸다는 뜻이다. 판정은 refine 행으로 하고 bench 행은 그 폭을 보는 용도다."
}

case "${1:-}" in
    --list)    list_all ;;
    --collect) shift; collect "${1:-}" ;;
    --ready)
        preflight
        # shellcheck disable=SC2046
        submit_many $(p2_dsids_primary) ;;
    "") echo "사용법: $0 --list | --ready | --collect [out.tsv] | <dsid> [dsid ...]"; exit 1 ;;
    *)  preflight
        submit_many "$@" ;;
esac
