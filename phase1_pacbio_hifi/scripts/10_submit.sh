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
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
PHASE1="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$PHASE1/.." && pwd)"
RT="$PHASE1/run_table.tsv"
IM="$PHASE1/inputs_manifest.tsv"

row() { awk -F'\t' -v d="$1" '$1==d {print; exit}' "$RT"; }
col() { echo "$1" | cut -f"$2"; }   # run_table: 1 dsid 2 sample 3 dataset 4 entry 5 units 6 clair3 7 gib 8 dup_of 9 note

inputs_missing() {  # dsid -> "missing/total" (0/N이면 준비 완료; 크기까지 manifest와 일치해야 함)
    local tot=0 miss=0 f rel sz
    while IFS=$'\t' read -r _ rel sz; do
        tot=$((tot + 1))
        f="$GIAB_ROOT/$rel"
        if [ ! -f "$f" ] || [ "$(stat -c%s "$f" 2>/dev/null || echo -1)" != "$sz" ]; then
            miss=$((miss + 1))
        fi
    done < <(awk -F'\t' -v d="$1" '$1==d' "$IM")
    echo "$miss/$tot"
}

vcf_done() {  # dsid sample dataset -> 0 if DV+Clair3+pbsv VCF 존재
    local base="$RUN_BASE/$2/PacBio/$3" id="$2.$3.$REF_NAME"
    [ -s "$base/03_VCF/deepvariant/$id.deepvariant.vcf.gz" ] &&
    [ -s "$base/03_VCF/clair3/$id.clair3.vcf.gz" ] &&
    [ -s "$base/03_VCF/SV_pbsv/$id.pbsv.vcf.gz" ]
}

job_alive() {  # dsid -> 0 if 큐/실행 중
    local idf="$INFRA/jobs/$1.jobid" jid
    [ -f "$idf" ] || return 1
    jid=$(cat "$idf")
    qstat -u "$USER" 2>/dev/null | awk 'NR>2 {print $1}' | grep -qx "$jid"
}

list_all() {
    printf '%-46s %-11s %-8s %-5s %s\n' dsid input job vcf dup_of
    local dsid r sample dataset dup m j v
    for dsid in $(awk -F'\t' 'NR>1 {print $1}' "$RT"); do
        r=$(row "$dsid")
        sample=$(col "$r" 2); dataset=$(col "$r" 3); dup=$(col "$r" 8)
        m=$(inputs_missing "$dsid")
        case "$m" in 0/*) m=ready ;; *) m="miss $m" ;; esac
        j=-; job_alive "$dsid" && j="q/r"
        v=-; vcf_done "$dsid" "$sample" "$dataset" && v=OK
        printf '%-46s %-11s %-8s %-5s %s\n' "$dsid" "$m" "$j" "$v" "$dup"
    done
}

preflight() {
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
    r=$(row "$dsid")
    [ -n "$r" ] || { echo "SKIP $dsid: run_table.tsv에 없음"; return 1; }
    sample=$(col "$r" 2); dataset=$(col "$r" 3); entry=$(col "$r" 4); model=$(col "$r" 6); dup=$(col "$r" 8)

    if [ -n "$dup" ] && [ "${DUP_OK:-0}" != 1 ]; then
        echo "SKIP $dsid: $dup 와 동일 movie 세트 (중복 계산). 그래도 돌리려면 DUP_OK=1"; return 0
    fi
    local m; m=$(inputs_missing "$dsid")
    case "$m" in 0/*) : ;; *) echo "SKIP $dsid: 입력 미완 ($m missing) — 다운로드 완료 후 재시도"; return 0 ;; esac
    if vcf_done "$dsid" "$sample" "$dataset" && [ "${FORCE:-0}" != 1 ]; then
        echo "SKIP $dsid: VCF 3종 이미 존재 (재제출은 FORCE=1)"; return 0
    fi
    if job_alive "$dsid"; then
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
        mapfile -t dsids < <(awk -F'\t' 'NR>1 && $8=="" {print $1}' "$RT")
        for d in "${dsids[@]}"; do submit_one "$d" || true; done ;;
    "") echo "사용법: $0 --list | --ready | <dsid> [dsid ...]  (dsid는 run_table.tsv 1열)"; exit 1 ;;
    *)  preflight
        for d in "$@"; do submit_one "$d" || true; done ;;
esac
