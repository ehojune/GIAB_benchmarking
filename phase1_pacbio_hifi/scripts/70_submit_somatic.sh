#!/bin/bash
# HG008 PacBio tumor-normal somatic SNV/INDEL — DeepSomatic 1.10.0 (CPU) 전장 실행.
#
#   bash phase1_pacbio_hifi/scripts/70_submit_somatic.sh --list              쌍별 입력 BAM·산출·잡 상태
#   bash phase1_pacbio_hifi/scripts/70_submit_somatic.sh --prepare           (로그인 노드) DeepSomatic 이미지 사전 다운로드
#   bash phase1_pacbio_hifi/scripts/70_submit_somatic.sh <pair_id> [...]     제출
#   bash phase1_pacbio_hifi/scripts/70_submit_somatic.sh --qc [out.tsv]      끝난 쌍의 간단 QC (로그인 노드, 쌍당 1~2분)
#
# 환경 변수: DRY=1   잡 스크립트만 만든다
#            FORCE=1 VCF 가 이미 있어도 제출 (-resume 이라 끝난 단계는 다시 안 돈다)
#            HOLD=<jobid[,jobid]>  그 잡들이 끝난 뒤에 시작 (qsub -hold_jid). 동시 실행 수를 묶는 데 쓴다
#
# 파이프라인은 bioinfo-agent 후보 구현을 **따로** vendor 한 사본이다(pipeline/pacbio-hifi-wgs-somatic,
# VENDORED.md). germline 사본(pipeline/pacbio-hifi-wgs)은 그대로 둔다 — 곧 들어올 업체 롱리드를 공개 비교군과
# 같은 판으로 돌려야 해서다. 이 스크립트는 --somatic_input 만 준다(--input 없음): 정렬·germline 콜은 안 돌고
# CHECK_BAM → DEEPSOMATIC → SNV/INDEL 분리 → bcftools stats → MultiQC 만 돈다. 기존 정렬 BAM 을 그대로 쓴다.
#
# 쌍 목록은 somatic_pairs.tsv. normal_relation=borrowed 인 쌍은 다른 센터·배치의 normal 을 빌려 쓴 것이고,
# truth_scope=recall_only 는 precision 을 해석하지 않는다는 뜻이다(62_benchmark_somatic.sh 머리말).
#
# 산출: $RUN_BASE/<tumor_sample>/PacBio/somatic.<pair_id>/03_VCF/deepsomatic/<tumor_sample>.somatic.<pair_id>.$REF_NAME.deepsomatic.vcf.gz
# 우선순위: 잡은 qsub -p $SOMATIC_PRIO(기본 -100)로 낸다 — 같은 사용자의 HG002/3/4·업체 비교 잡이 먼저 뜬다.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

PAIRS="$P1_DIR/somatic_pairs.tsv"
PIPE="$P1_DIR/pipeline/pacbio-hifi-wgs-somatic"
DS_URI="$(grep -oE "container_deepsomatic *= *'[^']+'" "$PIPE/nextflow.config" | cut -d"'" -f2)"
DS_IMG="$(p1_img_path "$DS_URI")"
SGE_Q_ARG="$SGE_QUEUE"

pair_row() { awk -F'\t' -v p="$1" 'NR>1 && $1==p {print; exit}' "$PAIRS"; }
pair_ids() { awk -F'\t' 'NR>1 && NF {print $1}' "$PAIRS"; }
bam_of() {   # dsid -> 정렬 BAM 경로 (파이프라인 germline 산출)
    local r s d
    r=$(p1_row "$1"); [ -n "$r" ] || return 1
    s=$(p1_col "$r" 2); d=$(p1_col "$r" 3)
    echo "$RUN_BASE/$s/PacBio/$d/02_alignedBAM/$s.$d.$REF_NAME.bam"
}
sample_of() { p1_col "$(p1_row "$1")" 2; }
vcf_of() {   # pair_id -> DeepSomatic VCF 경로
    local r t; r=$(pair_row "$1"); t=$(sample_of "$(echo "$r" | cut -f2)")
    echo "$RUN_BASE/$t/PacBio/somatic.$1/03_VCF/deepsomatic/$t.somatic.$1.$REF_NAME.deepsomatic.vcf.gz"
}

list_all() {
    printf '%-6s %-40s %-36s %-9s %-5s %-4s %s\n' pair tumor normal relation bams vcf job
    local p r t n tb nb ok v
    p1_qstat_refresh
    for p in $(pair_ids); do
        r=$(pair_row "$p"); t=$(echo "$r" | cut -f2); n=$(echo "$r" | cut -f3)
        tb=$(bam_of "$t" || true); nb=$(bam_of "$n" || true)
        ok=OK
        for b in "$tb" "$nb"; do [ -s "$b" ] && [ -s "$b.bai" ] || ok=MISS; done
        v=-; [ -s "$(vcf_of "$p")" ] && v=OK
        printf '%-6s %-40s %-36s %-9s %-5s %-4s %s\n' "$p" "$t" "$n" "$(echo "$r" | cut -f5)" "$ok" "$v" "$(p1_job_state "som.$p")"
    done
}

prepare() {
    command -v singularity >/dev/null || { echo "ERROR: singularity 가 PATH 에 없다"; exit 1; }
    mkdir -p "$NXF_SINGULARITY_CACHEDIR"
    if [ -s "$DS_IMG" ]; then echo "cached: $DS_IMG"; return 0; fi
    echo "pull: docker://$DS_URI -> $DS_IMG"
    singularity pull --name "$DS_IMG" "docker://$DS_URI"
    ls -la "$DS_IMG"
}

preflight() {
    p1_qstat_refresh
    p1_require_sge_targets || exit 1
    SGE_Q_ARG="$(p1_sge_queue_arg)"
    [ -s "$REF_FASTA" ] && [ -s "$REF_FASTA.fai" ] || { echo "ERROR: 레퍼런스/.fai 없음 ($REF_FASTA)"; exit 1; }
    [ -s "$DS_IMG" ] || { echo "ERROR: DeepSomatic 이미지 없음 ($DS_IMG) — 로그인 노드에서 --prepare 먼저 (계산 노드는 외부망이 없다)"; exit 1; }
    [ -s "$PIPE/main.nf" ] || { echo "ERROR: somatic 파이프라인 사본 없음 ($PIPE)"; exit 1; }
    mkdir -p "$INFRA/jobs" "$INFRA/logs" "$INFRA/launch"
}

submit_one() {
    local p=$1 r t n tb nb ts ns key launch job csv
    r=$(pair_row "$p"); [ -n "$r" ] || { echo "SKIP $p: somatic_pairs.tsv 에 없음"; return 1; }
    t=$(echo "$r" | cut -f2); n=$(echo "$r" | cut -f3)
    tb=$(bam_of "$t") || { echo "FAIL $p: run_table 에 tumor $t 없음"; return 1; }
    nb=$(bam_of "$n") || { echo "FAIL $p: run_table 에 normal $n 없음"; return 1; }
    for b in "$tb" "$nb"; do
        [ -s "$b" ] && [ -s "$b.bai" ] || { echo "FAIL $p: BAM 또는 .bai 없음 — $b"; return 1; }
    done
    ts=$(sample_of "$t"); ns=$(sample_of "$n")
    if [ -s "$(vcf_of "$p")" ] && [ "${FORCE:-0}" != 1 ]; then echo "SKIP $p: VCF 있음 (재실행은 FORCE=1)"; return 0; fi
    key="som.$p"
    if p1_job_alive "$key"; then echo "SKIP $p: 이미 큐/실행 중"; return 0; fi

    launch="$INFRA/launch/$key"; job="$INFRA/jobs/$key.sh"; csv="$launch/pair.csv"
    mkdir -p "$launch" || { echo "FAIL $p: $launch 를 못 만들었다"; return 1; }
    # 잡이 큐에서 기다리는 동안 표가 바뀌어도 제출 시점 쌍으로 돈다 — CSV 는 잡마다 따로 둔다
    if ! printf 'pair_id,tumor_sample,tumor_bam,tumor_index,normal_sample,normal_bam,normal_index\nsomatic.%s,%s,%s,%s.bai,%s,%s,%s.bai\n' \
            "$p" "$ts" "$tb" "$tb" "$ns" "$nb" "$nb" > "$csv"; then
        echo "FAIL $p: $csv 를 못 썼다"; return 1
    fi
    if ! cat > "$job" <<EOF
#!/bin/bash
#\$ -N s1.$p
#\$ -q $SGE_Q_ARG
#\$ -pe $SGE_PE $SOMATIC_SLOTS
#\$ -S /bin/bash
#\$ -V
#\$ -j y
#\$ -o $INFRA/logs/$key.\$JOB_ID.log
#\$ -l h_vmem=$SOMATIC_VMEM
#\$ -l h='$SGE_HOSTS'
#\$ -wd $launch
set -euo pipefail
source "$P1_DIR/env.sh"
export NXF_OFFLINE=true
export NF_LOCAL_CPUS="\${NSLOTS:-$SOMATIC_SLOTS}"
export NF_LOCAL_MEM_GB="$SOMATIC_MEM_GB"
echo "== \$(date '+%F %T') \$(hostname) pair=$p tumor=$t normal=$n slots=\${NSLOTS:-?}"
cat "$csv"

nextflow run "$PIPE" \\
    -profile singularity \\
    -c "$P1_DIR/conf/kobic.config" \\
    -c "$P1_DIR/conf/somatic.config" \\
    -work-dir "$INFRA/work/$key" \\
    -resume -ansi-log false \\
    --somatic_input "$csv" \\
    --fasta "$REF_FASTA" \\
    --ref_name "$REF_NAME" \\
    --outdir "$RUN_BASE" \\
    --run_label "$key"
echo "== DONE \$(date '+%F %T')"
EOF
    then
        echo "FAIL $p: 잡 스크립트를 못 썼다 — $job"; return 1
    fi
    chmod +x "$job" || { echo "FAIL $p: chmod 실패"; return 1; }
    if [ "${DRY:-0}" = 1 ]; then echo "DRY $p: $job"; return 0; fi

    local args=(-p "$SOMATIC_PRIO") out jid
    [ -n "${HOLD:-}" ] && args+=(-hold_jid "$HOLD")
    if ! out=$(qsub "${args[@]}" "$job" < /dev/null 2>&1); then echo "FAIL $p: qsub 거부 — $out"; return 1; fi
    jid=$(echo "$out" | grep -oE '[0-9]+' | head -1)
    [ -n "$jid" ] || { echo "FAIL $p: qsub 출력에서 jobid 를 못 읽었다 — $out"; return 1; }
    echo "$jid" > "$INFRA/jobs/$key.jobid" || { echo "FAIL $p: jobid=$jid 로 제출됐으나 기록 실패"; return 1; }
    echo "OK  $p: jobid=$jid tumor=$ts normal=$ns${HOLD:+ hold=$HOLD}"
}

# 간단 QC: 레코드 수·FILTER 분포·PASS SNV/INDEL·PASS VAF 중앙값·VAF>=SOMATIC_MIN_VAF 수.
# 채점이 아니다 — 채점은 62_benchmark_somatic.sh.
qc() {
    local out="${1:-$P1_DIR/phase1_somatic_qc.tsv}" p v bt_img
    bt_img="$(p1_img_path "$(p1_container_uris | grep '/bcftools:')")"
    {
        printf 'pair_id\ttumor\tnormal\tnormal_relation\ttruth_scope\tvcf\trecords\tPASS\tGERMLINE\tRefCall\tLowQual\tNoCall\tpass_snv\tpass_indel\tpass_vaf_median\tpass_vaf_ge_min\n'
        for p in $(pair_ids); do
            local r; r=$(pair_row "$p"); v=$(vcf_of "$p")
            if [ ! -s "$v" ]; then
                printf '%s\t%s\t%s\t%s\t%s\tMISSING\t\t\t\t\t\t\t\t\t\t\n' "$p" "$(echo "$r" | cut -f2)" "$(echo "$r" | cut -f3)" "$(echo "$r" | cut -f5)" "$(echo "$r" | cut -f6)"
                continue
            fi
            singularity exec -B "$RUN_BASE:$RUN_BASE" "$bt_img" bcftools query -f '%FILTER\t%TYPE\t[%VAF]\n' "$v" \
              | awk -F'\t' -v P="$p" -v T="$(echo "$r" | cut -f2)" -v N="$(echo "$r" | cut -f3)" \
                    -v R="$(echo "$r" | cut -f5)" -v S="$(echo "$r" | cut -f6)" -v min="$SOMATIC_MIN_VAF" '
                  { n++; f[$1]++
                    if ($1=="PASS") { if ($2=="SNP") s++; else if ($2=="INDEL") i++
                                      split($3, a, ","); x=a[1]+0; vs[++k]=x; if (x>=min) g++ } }
                  END { m="NA"
                        if (k) { asort(vs); m = (k%2) ? vs[(k+1)/2] : (vs[k/2]+vs[k/2+1])/2 }
                        printf "%s\t%s\t%s\t%s\t%s\tOK\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%d\n", P,T,N,R,S,
                               n, f["PASS"], f["GERMLINE"], f["RefCall"], f["LowQual"], f["NoCall"], s, i, m, g }'
        done
    } > "$out"
    echo "-> $out"
    column -t -s$'\t' "$out" | cut -c1-220
}

dedup() { awk 'NF && !seen[$0]++'; }

case "${1:-}" in
    --list)    list_all ;;
    --prepare) prepare ;;
    --qc)      shift; qc "${1:-}" ;;
    ""|-h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
    *)
        preflight
        rc=0
        for p in $(printf '%s\n' "$@" | dedup); do submit_one "$p" || rc=1; done
        exit $rc ;;
esac
