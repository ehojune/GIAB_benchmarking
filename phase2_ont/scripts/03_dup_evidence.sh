#!/bin/bash
# 중복(재베이스콜) 판정 근거를 실측으로 모은다. 로그인 노드에서 돌린다. 읽기 전용.
#
#   scripts/03_dup_evidence.sh            전부
#   scripts/03_dup_evidence.sh HG002      HG002 UL 릴리스 5종 비교만
#   scripts/03_dup_evidence.sh HG001      GIAB BAM vs rel6 대조만
#   OUT=<경로> scripts/03_dup_evidence.sh 결과 저장 위치 (기본 $INFRA/logs/dup_evidence)
#
# ── 왜 이 방식인가 ─────────────────────────────────────────────────────────
# PacBio는 movie ID로 같은 셀을 판정했다(phase1). ONT에는 movie ID가 없다.
# 대신 **read_id(=fast5/pod5의 UUID)가 재베이스콜 후에도 같다**는 성질을 쓴다.
# 같은 플로우셀을 다시 베이스콜한 릴리스라면 read_id 집합이 (거의) 같고,
# 다른 기기·플로우셀이면 교집합이 0이다. 이게 ONT에서 movie ID를 대신하는 증거다.
#
# read_id는 sequencing_summary.txt.gz에 전부 들어 있다 (fastq 전체를 훑지 않아도 된다).
# rel1/rel2처럼 summary가 없는 릴리스는 fastq 앞부분에서 read_id를 뽑아 상대 집합에 넣어 본다.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

# 로그인 노드에 samtools가 PATH로 없을 수 있다 (2026-08-23 nbb2 실측: command not found).
# 이미 캐시해 둔 samtools 컨테이너로 대신 돌린다 — 나머지 스크립트가 samtools를 전부
# Nextflow 컨테이너 안에서만 쓰는 것과 같은 원칙.
SAMTOOLS_IMG="$(p2_img_path "$(p2_container_uris | grep '/samtools:')")"
[ -s "$SAMTOOLS_IMG" ] || { echo "ERROR: samtools 컨테이너가 없다 ($SAMTOOLS_IMG) — 01_prepare_login_node.sh 먼저"; exit 1; }
st() { singularity exec --bind "$GIAB_ROOT" "$SAMTOOLS_IMG" samtools "$@"; }

OUT="${OUT:-$INFRA/logs/dup_evidence}"
SAMPLE_N="${SAMPLE_N:-200000}"      # summary 없는 릴리스에서 뽑아 볼 리드 수
mkdir -p "$OUT"
G="$GIAB_ROOT"
UL="$G/data/AshkenazimTrio/HG002_NA24385_son/Ultralong_OxfordNanopore"
UCSC2="$G/data/AshkenazimTrio/HG002_NA24385_son/UCSC_Ultralong_OxfordNanopore_Promethion"

have() { [ -s "$1" ] || { echo "  없음(다운로드 미완?): $1"; return 1; }; }

# sequencing_summary.txt.gz -> read_id 정렬 목록 + run_id 집계
summary_ids() {   # <label> <summary.txt.gz>
    local label=$1 f=$2
    have "$f" || return 1
    if [ ! -s "$OUT/$label.readids.gz" ]; then
        echo "  read_id 추출: $label"
        zcat "$f" | awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) h[$i]=i; next}
                                {print $h["read_id"]}' | LC_ALL=C sort -u | gzip > "$OUT/$label.readids.gz"
        zcat "$f" | awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) h[$i]=i; next}
                                {c[$h["run_id"]]++} END{for(k in c) print c[k]"\t"k}' \
            | sort -rn > "$OUT/$label.runids.txt"
    fi
    printf '  %-28s reads=%s  run_id=%s개\n' "$label" \
        "$(zcat "$OUT/$label.readids.gz" | wc -l)" "$(wc -l < "$OUT/$label.runids.txt")"
}

# fastq -> 앞부분 read_id 표본 (summary가 없는 릴리스용)
fastq_ids() {     # <label> <fastq.gz>
    local label=$1 f=$2
    have "$f" || return 1
    if [ ! -s "$OUT/$label.readids.gz" ]; then
        echo "  read_id 표본 추출($SAMPLE_N): $label"
        # awk가 먼저 exit하면 앞단이 SIGPIPE(141)로 죽는다. pipefail + set -e 조합에서
        # 그대로 두면 스크립트가 여기서 끝나므로 감싸 준다 (phase1 02_fetch_sra_reads.sh와 같은 이유).
        { zcat "$f" 2>/dev/null || true; } \
            | awk -v n="$SAMPLE_N" 'NR%4==1 {sub(/^@/,""); print $1; c++; if(c>=n) exit}' \
            | LC_ALL=C sort -u | gzip > "$OUT/$label.readids.gz"
    fi
    printf '  %-28s 표본 read_id=%s\n' "$label" "$(zcat "$OUT/$label.readids.gz" | wc -l)"
}

overlap() {       # <a> <b>
    local a=$1 b=$2 na nb ni
    [ -s "$OUT/$a.readids.gz" ] && [ -s "$OUT/$b.readids.gz" ] || { echo "  (건너뜀: $a 또는 $b 없음)"; return 0; }
    na=$(zcat "$OUT/$a.readids.gz" | wc -l)
    nb=$(zcat "$OUT/$b.readids.gz" | wc -l)
    ni=$(LC_ALL=C comm -12 <(zcat "$OUT/$a.readids.gz") <(zcat "$OUT/$b.readids.gz") | wc -l)
    awk -v a="$a" -v b="$b" -v na="$na" -v nb="$nb" -v ni="$ni" 'BEGIN{
        printf "  %-26s x %-26s 교집합 %d  (%.1f%% of %s, %.1f%% of %s)\n",
               a, b, ni, (na?100*ni/na:0), a, (nb?100*ni/nb:0), b }'
}

run_hg002() {
    echo "== HG002 ONT-UL: 릴리스 5종 + UCSC PromethION =="
    summary_ids g345   "$UL/guppy-V3.4.5/HG002_ONT-UL_GIAB_20200204.sequencing_summary.txt.gz"        || true
    summary_ids g324   "$UL/guppy-V3.2.4_2020-01-22/HG002_ONT-UL_GIAB_20200122.sequencing_summary.txt.gz" || true
    summary_ids g234   "$UL/guppy-V2.3.4_2019-06-26/ultra-long-ont.sequencing_summary.txt.gz"          || true
    fastq_ids   rel1   "$UL/combined_2018-05-18/combined_2018-05-18.fastq.gz"                          || true
    fastq_ids   rel2   "$UL/combined_2018-08-10/combined_2018-08-10.fastq.gz"                          || true
    for i in 1 2 3; do
        summary_ids "ucsc2_$i" "$UCSC2/GM24385_$i.sequencing_summary.txt.gz" || true
    done
    echo
    echo "  -- read_id 교집합 (같은 플로우셀을 다시 베이스콜했으면 ~100%) --"
    overlap g345 g324
    overlap g345 g234
    overlap rel1 g345
    overlap rel2 g345
    echo "  -- 다른 기기(PromethION)와의 교집합 (0에 가까워야 정상) --"
    overlap g345 ucsc2_1
    echo
    echo "  -- run_id(플로우셀) 집합 차이: g234에만 있는 것 = HG001 오라벨 후보 --"
    if [ -s "$OUT/g234.runids.txt" ] && [ -s "$OUT/g345.runids.txt" ]; then
        LC_ALL=C comm -23 <(cut -f2 "$OUT/g234.runids.txt" | sort) <(cut -f2 "$OUT/g345.runids.txt" | sort) \
            | sed 's/^/    only-in-g234: /'
        echo "    (GIAB의 mis-labeled-sample_run-ids.txt 와 대조할 것:"
        echo "     $UL/guppy-V2.3.4_2019-06-26/mis-labeled-sample_run-ids.txt )"
        [ -s "$UL/guppy-V2.3.4_2019-06-26/mis-labeled-sample_run-ids.txt" ] && \
            sed 's/^/    GIAB 목록: /' "$UL/guppy-V2.3.4_2019-06-26/mis-labeled-sample_run-ids.txt"
    fi
}

run_hg001() {
    echo "== HG001: GIAB 정렬 BAM vs 외부 rel6 리드 =="
    local bam="$G/data/NA12878/Ultralong_OxfordNanopore/NA12878-minion-ul_GRCh38.bam"
    local relfq="$G/ext/nanopore-wgs-consortium/rel6/rel_6.fastq.gz"
    local relsum="$G/ext/nanopore-wgs-consortium/rel6/rel_6_sequencing_summary.txt.gz"
    if have "$bam"; then
        echo "  -- BAM 헤더의 @RG / @PG (무엇을 정렬한 것인지) --"
        st view -H "$bam" | grep -E '^@(RG|PG)' | head -20 | sed 's/^/    /'
        echo "  -- 리드 수 (idxstats 합계) --"
        st idxstats "$bam" | awk '{m+=$3; u+=$4} END{printf "    mapped=%d unmapped=%d 합계=%d\n", m, u, m+u}'
        echo "  -- BAM 앞부분 read_id 표본 --"
        { st view "$bam" 2>/dev/null || true; } | awk -v n=50000 '{print $1; c++; if(c>=n) exit}' \
            | LC_ALL=C sort -u | gzip > "$OUT/hg001_bam.readids.gz"
        printf '    표본 %s개\n' "$(zcat "$OUT/hg001_bam.readids.gz" | wc -l)"
    fi
    if [ -s "$relsum" ]; then
        summary_ids rel6 "$relsum" || true
        echo "  -- rel6 read_id 총수와 BAM 리드 수를 비교하면 BAM이 rel6 전체인지 부분인지 알 수 있다 --"
        overlap hg001_bam rel6
    elif [ -s "$relfq" ]; then
        fastq_ids rel6_fq "$relfq" || true
        overlap hg001_bam rel6_fq
    else
        echo "  rel6 파일이 아직 없다 — 02_fetch_external_reads.sh 먼저"
    fi
}

if [ $# -eq 0 ]; then
    run_hg002; echo; run_hg001
else
    for t in "$@"; do
        case "$t" in
            HG002) run_hg002 ;;
            HG001) run_hg001 ;;
            *) echo "알 수 없는 대상: $t (HG001 | HG002)" ;;
        esac
        echo
    done
fi

echo "근거 파일: $OUT"
echo "판정을 확정하면 docs/reference/ont_dup_judgement.md 에 숫자를 옮겨 적고,"
echo "필요하면 scripts/make_samplesheets.py의 dup_of 를 고쳐 run_table.tsv를 다시 생성할 것."
