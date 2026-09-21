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
    local src=$1 stem name dir tmp bt
    # stem/name/dir 을 위의 local 줄에서 같이 잡으면 안 된다 — local은 빌트인이라 인자를 전부 먼저
    # 확장한 뒤 대입한다. 그 시점엔 src가 아직 없어서 경로가 뭉개진다(set -u면 에러까지).
    stem="$(basename "${src%.vcf.gz}").noast"
    name="$stem.vcf.gz"
    # VCF와 인덱스를 **디렉토리 하나에** 담고 그 디렉토리를 통째로 rename해 공개한다.
    # 파일 둘을 따로 옮기면 두 세션이 엇갈렸을 때 A의 VCF에 B의 인덱스가 붙을 수 있다 —
    # bcftools가 헤더에 실행 명령(임시 경로 포함)을 적으므로 같은 입력이어도 바이트가 다르고,
    # 그러면 인덱스 오프셋이 어긋나 조용히 엉뚱한 레코드를 읽는다. 디렉토리 rename은 원자적이다.
    dir="$TRUTH_CACHE/$stem.d"
    if [ -s "$dir/$name" ] && [ -s "$dir/$name.tbi" ]; then echo "$dir/$name"; return 0; fi
    # DRY는 아무것도 만들지 않는다 — 잡 스크립트가 가리킬 경로만 알려준다.
    if [ "${DRY:-0}" = 1 ]; then
        echo "  (DRY) truth 캐시 미생성 — 실제 실행 때 만든다: $dir/$name" >&2
        echo "$dir/$name"; return 0
    fi
    bt="$(p2_img_path "$(p2_container_uris | grep '/bcftools:')")"
    [ -s "$bt" ] || { echo "ERROR: bcftools 컨테이너가 없다 ($bt) — 01_prepare_login_node.sh 먼저" >&2; return 1; }
    mkdir -p "$TRUTH_CACHE"
    echo "  ALT=* 를 걸러 truth 캐시 생성 (1회): $stem.d/" >&2
    tmp="$TRUTH_CACHE/.build.$stem.$$"
    rm -rf "$tmp"; mkdir -p "$tmp" || { echo "ERROR: 작업 디렉토리 생성 실패 — $tmp" >&2; return 1; }
    singularity exec -B "$GIAB_ROOT:$GIAB_ROOT" -B "$INFRA:$INFRA" "$bt" \
        bcftools view -e 'ALT="*"' -Oz -o "$tmp/$name" "$src" >&2 \
        || { rm -rf "$tmp"; echo "ERROR: bcftools view 실패 — $src" >&2; return 1; }
    singularity exec -B "$INFRA:$INFRA" "$bt" tabix -f -p vcf "$tmp/$name" >&2 \
        || { rm -rf "$tmp"; echo "ERROR: tabix 실패 — $tmp/$name" >&2; return 1; }
    if ! mv -T "$tmp" "$dir" 2>/dev/null; then
        # 경쟁에서 졌다 — 상대가 이미 완성본을 놓았어야 한다. 아니면 진짜 실패다.
        rm -rf "$tmp"
        [ -s "$dir/$name" ] && [ -s "$dir/$name.tbi" ] \
            || { echo "ERROR: truth 캐시 공개 실패 — $dir" >&2; return 1; }
    fi
    echo "$dir/$name"
}

sv_call_vcf() {  # sample dataset -> Sniffles VCF 경로 (존재 여부는 호출부에서)
    echo "$RUN_BASE/$1/ONT/$2/03_VCF/SV_sniffles/$1.$2.$REF_NAME.sniffles.vcf.gz"
}

# sample dataset -> 0 if 평가가 "끝까지" 갔을 때.
# 잡은 임시 디렉토리에서 돌고 전부 성공해야 $BENCH_SV_SUB 로 옮기므로, 이 디렉토리가 있다는 것
# 자체가 완주 신호다. refine을 켰으면 refine 산출까지 있어야 완료로 본다 — bench만 끝나고
# refine에서 죽은 결과를 완료로 세면 다음 제출이 조용히 건너뛴다.
bench_sv_done() {
    local d="$RUN_BASE/$1/ONT/$2/$BENCH_SV_SUB"
    [ -s "$d/summary.json" ] || return 1
    if [ "${BENCH_SV_REFINE:-1}" = 1 ]; then
        [ -s "$d/refine.variant_summary.json" ] || return 1
    fi
    return 0
}

# 같은 dsid가 두 번 들어오면 같은 출력 경로에 잡 둘이 동시에 쓴다.
# p2_job_alive는 preflight 때 뜬 qstat 스냅샷을 보므로 방금 넣은 잡을 못 본다 — 입력에서 잘라낸다.
dedup_dsids() { awk 'NF && !seen[$0]++'; }

# 잡 번호가 아직 큐에 있나 (preflight에서 뜬 스냅샷 기준). lib.sh의 p2_job_state 는 dsid로 찾지만
# 여기서는 디렉토리 이름에 박힌 번호로 직접 봐야 한다.
p2_sge_queued() { echo "${P2_QSTAT:-}" | awk -v j="$1" 'NR>2 && $1==j {f=1} END {exit !f}'; }

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
    # refine은 bench의 --refine 대신 별도 단계로 돌린다. bench의 --refine 은 내부에서
    # refine_main([outdir]) 을 **인자 없이** 부르므로(truvari 5.4.0 bench.py:803) --align·--threads 를
    # 넘길 방법이 없고, bench 파서에는 --align 자체가 없어서 붙이면 argparse 에러로 죽는다.
    # 두 단계로 나눈 결과는 --refine 과 동일하다 (기본 align=poa). threads만 슬롯 수로 올린다.
    # 분기는 잡 스크립트 **안**에 넣는다 — 생성 쪽에서 ${var:+...} 로 여러 줄을 끼워 넣으면
    # 확장 과정에서 따옴표가 벗겨져 echo 인자의 괄호가 노출된다(실측).
    local do_refine="${BENCH_SV_REFINE:-1}" align="${BENCH_SV_ALIGN:-poa}"

    # 쓰기가 실패하면(디스크 참, 권한) 예전 잡 스크립트가 남아 엉뚱한 걸 제출하게 된다.
    # 호출부의 `|| rc=1` 때문에 이 함수 안에서는 errexit가 꺼져 있으니 직접 본다.
    if ! cat > "$job" <<EOF
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

# truvari bench 는 출력 디렉토리가 이미 있으면 거부한다. 그렇다고 기존 결과를 **미리** 지우면,
# 몇 시간짜리 잡이 죽거나 다른 잡이 같은 dsid로 들어왔을 때 멀쩡한 결과만 날린다.
# 그래서 잡별 임시 디렉토리에서 돌고, 전부 성공한 뒤에만 제자리로 옮긴다.
# 이러면 중간에 죽은 실행이 반쪽 summary.json 을 남기지 않아 "완료"로 오판되지도 않는다.
WORK="$out.inprogress.\$JOB_ID"
rm -rf "\$WORK"
# 실패하면 작업 디렉토리를 치운다. 안 그러면 재시도마다 JOB_ID가 바뀌어 쓰레기가 쌓인다.
# SIGKILL이면 trap이 안 돌므로, 제출 쪽에서도 죽은 잡의 잔여물을 한 번 훑어 지운다.
trap '[ -d "\$WORK" ] && rm -rf "\$WORK"' EXIT

run_truvari() {
    singularity exec \\
        -B "$GIAB_ROOT:$GIAB_ROOT" \\
        -B "$RUN_BASE:$RUN_BASE" \\
        -B "$INFRA:$INFRA" \\
        "$simg" "\$@"
}

echo "== truvari bench : $sample.$dataset =="
echo "   truth = $truth_use"
echo "   call  = $call"
run_truvari truvari bench \\
        -b "$truth_use" \\
        -c "$call" \\
        -o "\$WORK" \\
        -f "$REF_FASTA" \\
        --includebed "$truth_bed" \\
        --pick ac \\
        --passonly \\
        -r 2000 \\
        -C 5000 ${BENCH_SV_ARGS:-}

if [ "$do_refine" = 1 ]; then
    echo "== truvari refine (align=$align) =="
    run_truvari truvari refine \\
        -f "$REF_FASTA" \\
        -a "$align" \\
        -t "\${NSLOTS:-$BENCH_SV_SLOTS}" \\
        "\$WORK"
fi

# 여기까지 왔으면 전 단계가 성공했다 (set -e). 이제 공개한다.
# 옛 결과를 먼저 지우지 않는다 — 새 것을 놓기 전에 지웠다가 mv가 실패하면 둘 다 잃는다.
# 옆으로 치워 두고, 새 것이 자리를 잡은 뒤에 지운다.
PREV=""
if [ -e "$out" ]; then
    PREV="$out.prev.\$JOB_ID"
    rm -rf "\$PREV"
    mv -T "$out" "\$PREV"
fi
# -T 가 중요하다. 그냥 mv 는 목적지가 디렉토리면 **그 안으로** 옮겨 놓고 성공을 내서, 결과가
# 한 단계 중첩된 채 "ALL DONE"이 찍힌다. -T 는 dst 를 이름으로 다뤄 그걸 막는다.
# (다만 -T 는 존재 가드가 아니다 — dst 가 **빈** 디렉토리면 조용히 대체하고 성공한다. 실측 확인.
#  여기서는 위에서 옛 결과를 치운 뒤라 중첩 방지만 필요해서 이걸로 충분하다.)
if ! mv -T "\$WORK" "$out"; then
    echo "ERROR: 결과 공개 실패 — \$WORK 를 $out 로 못 옮겼다"
    if [ -n "\$PREV" ]; then mv -T "\$PREV" "$out"; fi   # 옛 결과를 되돌린다
    exit 1
fi
trap - EXIT
# test-and-rm 을 && 로 이어 마지막 명령으로 쓰면 PREV가 빌 때 test가 1을 내고 set -e 가 잡는다.
if [ -n "\$PREV" ]; then rm -rf "\$PREV"; fi

echo "ALL DONE $dsid"
EOF
    then
        echo "FAIL $dsid: 잡 스크립트를 못 썼다 — $job"; return 1
    fi
    chmod +x "$job" || { echo "FAIL $dsid: chmod 실패 — $job"; return 1; }

    if [ "${DRY:-0}" = 1 ]; then
        echo "DRY $dsid: $job 생성만 함 (refine:${BENCH_SV_REFINE:-1})"; return 0
    fi

    # 죽은 잡이 남긴 작업 디렉토리를 치운다. SIGKILL이면 잡 안의 EXIT trap이 못 돌아 남는다.
    # **DRY 반환 뒤에 둔다** — DRY는 미리보기인데 여기서 rm -rf 를 하면 미리보기가 파괴적이 된다.
    # 판정은 dsid 단위 p2_job_alive 가 아니라 디렉토리 이름 끝의 잡 번호로 한다. jobid 파일
    # 기록이 실패한 잡은 살아 있어도 alive 판정을 못 받아서, 그 잡이 지금 쓰는 디렉토리를 지운다.
    local stale sj
    for stale in "$out".inprogress.* "$out".prev.*; do
        [ -d "$stale" ] || continue          # nullglob이 꺼져 있어 매치가 없으면 패턴이 그대로 온다
        sj="${stale##*.}"
        if [[ "$sj" =~ ^[0-9]+$ ]] && p2_sge_queued "$sj"; then
            echo "  건너뜀: $(basename "$stale") — 잡 $sj 가 아직 큐에 있다"; continue
        fi
        echo "  치움: $(basename "$stale") (죽은 잡의 잔여물)"
        rm -rf "$stale"
    done

    # 호출부가 실패를 모아 처리하므로 errexit에 기대지 않고 qsub 결과를 직접 본다.
    local qout jid
    if ! qout=$(qsub "$job" < /dev/null 2>&1); then   # stderr 까지 잡아야 FAIL 메시지가 쓸모 있다
        echo "FAIL $dsid: qsub 거부 — $qout"; return 1
    fi
    jid=$(echo "$qout" | grep -oE '[0-9]+' | head -1)
    [ -n "$jid" ] || { echo "FAIL $dsid: qsub 출력에서 jobid를 못 읽었다 — $qout"; return 1; }
    # jobid 기록이 실패하면 중복 제출 가드가 그 dsid에 대해 무력해진다 — 잡은 이미 들어갔으므로
    # 실패로 보고하되 잡 번호를 반드시 보여준다(사람이 qdel 할 수 있어야 한다).
    echo "$jid" > "$INFRA/jobs/svbench.$dsid.jobid" \
        || { echo "FAIL $dsid: jobid=$jid 로 제출됐으나 기록 실패 — $INFRA/jobs/svbench.$dsid.jobid"; return 1; }
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
# 실측(2026-09-18): refine이 F1을 4.8~5.1점 올린다 — 켜 두는 게 맞았다.
# refine 행의 gt_concordance는 NA로 나온다. truvari가 refine.variant_summary.json에 그 키를 안 낸다.
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
