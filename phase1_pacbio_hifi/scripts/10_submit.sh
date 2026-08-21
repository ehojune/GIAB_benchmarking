#!/bin/bash
# SGE 제출 (로그인 노드에서 실행). 실행 단위(dsid)당 잡 1개 — 잡 안에서 Nextflow가 local executor로 완주.
#
#   scripts/10_submit.sh --list              실행 단위 + 준비/완료 상태
#   scripts/10_submit.sh <dsid> [dsid ...]   지정 제출
#   scripts/10_submit.sh --ready             입력이 다 받아진 것 전부 제출 (dup_of 표시분 제외)
#
# 환경 변수: DUP_OK=1  중복 데이터셋(dup_of 표시)도 제출 허용
#            FORCE=1   VCF가 이미 다 있어도 재제출 (-resume라 캐시는 재사용)
#            GVCF=1    DeepVariant gVCF도 출력 (--gvcf)
#            DRY=1     qsub 하지 않고 잡 스크립트만 생성
#            READY_AGE_MIN=N  다운로드 안정화 대기 분 (기본 10, lib.sh 설명 참고)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"
PHASE1="$P1_DIR"
REPO="$(cd "$PHASE1/.." && pwd)"

list_all() {
    printf '%-46s %-13s %-5s %-5s %s\n' dsid input job vcf dup_of
    local dsid r sample dataset dup m j v
    p1_qstat_refresh
    for dsid in $(p1_dsids); do
        r=$(p1_row "$dsid")
        sample=$(p1_col "$r" 2); dataset=$(p1_col "$r" 3); dup=$(p1_col "$r" 8)
        m=$(p1_inputs_state "$dsid")
        j=$(p1_job_state "$dsid")
        v=-; p1_vcf_done "$sample" "$dataset" && v=OK
        printf '%-46s %-13s %-5s %-5s %s\n' "$dsid" "$m" "$j" "$v" "$dup"
    done
}

preflight() {
    p1_qstat_refresh
    [ -s "$REF_FASTA" ] || { echo "ERROR: 레퍼런스 없음 ($REF_FASTA) — scripts/01_prepare_login_node.sh 먼저"; exit 1; }
    local uris missing=0 img
    uris=$(grep -oE "container_[a-z0-9_]+ *= *'[^']+'" "$PHASE1/pipeline/pacbio-hifi-wgs/nextflow.config" | cut -d"'" -f2 | sort -u)
    for uri in $uris; do
        img="$NXF_SINGULARITY_CACHEDIR/$(echo "$uri" | sed 's#[/:]#-#g').img"
        [ -s "$img" ] || { echo "ERROR: 컨테이너 캐시 없음: $img"; missing=1; }
    done
    [ "$missing" = 0 ] || { echo "scripts/01_prepare_login_node.sh 먼저 실행"; exit 1; }
}

submit_one() {
    local dsid=$1 r sample dataset entry model dup
    r=$(p1_row "$dsid")
    [ -n "$r" ] || { echo "SKIP $dsid: run_table.tsv에 없음"; return 1; }
    sample=$(p1_col "$r" 2); dataset=$(p1_col "$r" 3); entry=$(p1_col "$r" 4)
    model=$(p1_col "$r" 6); dup=$(p1_col "$r" 8)

    if [ -n "$dup" ] && [ "${DUP_OK:-0}" != 1 ]; then
        echo "SKIP $dsid: $dup 와 동일 movie 세트 (중복 계산). 그래도 돌리려면 DUP_OK=1"; return 0
    fi
    local m; m=$(p1_inputs_state "$dsid")
    case "$m" in
        ready) : ;;
        settling*) echo "SKIP $dsid: 다운로드 중일 수 있음 ($m) — 크기는 맞지만 최근에 쓰인 파일이 있다"; return 0 ;;
        *) echo "SKIP $dsid: 입력 미완 ($m) — 다운로드 완료 후 재시도"; return 0 ;;
    esac
    if p1_vcf_done "$sample" "$dataset" && [ "${FORCE:-0}" != 1 ]; then
        echo "SKIP $dsid: VCF 3종 이미 존재 (재제출은 FORCE=1)"; return 0
    fi
    if p1_job_alive "$dsid"; then
        echo "SKIP $dsid: 이미 큐/실행 중 (jobid $(cat "$INFRA/jobs/$dsid.jobid"))"; return 0
    fi

    mkdir -p "$INFRA/launch/$dsid" "$INFRA/jobs" "$INFRA/logs" "$INFRA/work"
    local trf_arg=""
    [ -s "$TRF_BED" ] && trf_arg="--pbsv_tandem_repeats \"$TRF_BED\""
    [ "${GVCF:-0}" = 1 ] && trf_arg="$trf_arg --gvcf"
    local job="$INFRA/jobs/$dsid.sh"

    cat > "$job" <<EOF
#!/bin/bash
#\$ -N p1.$dsid
#\$ -q $SGE_QUEUE
#\$ -pe $SGE_PE $SGE_SLOTS
#\$ -S /bin/bash
#\$ -V
#\$ -j y
#\$ -o $INFRA/logs/$dsid.\$JOB_ID.log
#\$ -l h_vmem=$SGE_VMEM
#\$ -l h='$SGE_HOSTS'
#\$ -wd $INFRA/launch/$dsid
set -euo pipefail
source "$REPO/phase1_pacbio_hifi/env.sh"
export NXF_OFFLINE=true
export NF_LOCAL_CPUS="\${NSLOTS:-$SGE_SLOTS}"
export NF_LOCAL_MEM_GB="$NF_LOCAL_MEM_GB"

nextflow run "$REPO/phase1_pacbio_hifi/pipeline/pacbio-hifi-wgs" \\
    -profile singularity \\
    -c "$REPO/phase1_pacbio_hifi/conf/kobic.config" \\
    -work-dir "$INFRA/work/$dsid" \\
    -resume -ansi-log false \\
    --input "$PHASE1/samplesheets/$dsid.csv" \\
    --fasta "$REF_FASTA" \\
    --ref_name "$REF_NAME" \\
    --outdir "$RUN_BASE" \\
    --run_label "$dsid" \\
    --clair3_model "$model" $trf_arg
EOF
    chmod +x "$job"

    if [ "${DRY:-0}" = 1 ]; then
        echo "DRY $dsid: $job 생성만 함"; return 0
    fi
    local out jid
    out=$(qsub "$job" < /dev/null)
    jid=$(echo "$out" | grep -oE '[0-9]+' | head -1)
    echo "$jid" > "$INFRA/jobs/$dsid.jobid"
    echo "OK  $dsid: jobid=$jid entry=$entry clair3=$model"
}

case "${1:-}" in
    --list) list_all ;;
    --ready)
        preflight
        mapfile -t dsids < <(p1_dsids_primary)
        for d in "${dsids[@]}"; do submit_one "$d" || true; done ;;
    "") echo "사용법: $0 --list | --ready | <dsid> [dsid ...]  (dsid는 run_table.tsv 1열)"; exit 1 ;;
    *)  preflight
        for d in "$@"; do submit_one "$d" || true; done ;;
esac
