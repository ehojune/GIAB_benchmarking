# phase2 공용 헬퍼. 10_submit.sh / 20_status.sh 가 source 한다. env.sh 를 먼저 읽은 상태를 전제.
# phase1의 scripts/lib.sh와 같은 구조다 (열 번호와 산출 경로만 ONT용).
# shellcheck shell=bash

P2_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
P2_RT="$P2_DIR/run_table.tsv"
P2_IM="$P2_DIR/inputs_manifest.tsv"

# 다운로드가 끝난 것으로 인정하기까지 파일이 조용해야 하는 시간(분).
# 왜 필요한가: phase0의 기본 경로인 `aws s3 cp`는 .part 없이 최종 파일명에 바로 쓰고,
# 대용량은 멀티파트로 오프셋에 나눠 쓴다. 뒤쪽 파트가 먼저 도착하면
# **겉보기 크기는 최종 크기인데 중간이 빈 구멍인** 상태가 생긴다 — 크기만 보면 완료로 오판한다.
# 쓰기가 있을 때마다 mtime이 갱신되므로, 크기가 맞고 + N분간 조용하면 완료로 본다.
P2_READY_AGE_MIN="${READY_AGE_MIN:-10}"

# run_table.tsv 열: 1 dsid 2 sample 3 dataset 4 entry_type 5 units 6 files
#                   7 chemistry 8 basecaller 9 clair3_model 10 dv_model 11 size_gib 12 dup_of 13 note
p2_row() { awk -F'\t' -v d="$1" '$1==d {print; exit}' "$P2_RT"; }
p2_col() { echo "$1" | cut -f"$2"; }

p2_dsids() { awk -F'\t' 'NR>1 {print $1}' "$P2_RT"; }
p2_dsids_primary() { awk -F'\t' 'NR>1 && $12=="" {print $1}' "$P2_RT"; }

# dsid -> "ready" | "settling k/n" | "miss k/n"
p2_inputs_state() {
    local tot=0 miss=0 settle=0 f rel sz now mt
    now=$(date +%s)
    while IFS=$'\t' read -r _ rel sz; do
        tot=$((tot + 1))
        f="$GIAB_ROOT/$rel"
        if [ ! -f "$f" ] || [ "$(stat -c%s "$f" 2>/dev/null || echo -1)" != "$sz" ]; then
            miss=$((miss + 1))
            continue
        fi
        mt=$(stat -c%Y "$f" 2>/dev/null || echo 0)
        if [ $(( (now - mt) / 60 )) -lt "$P2_READY_AGE_MIN" ]; then
            settle=$((settle + 1))
        fi
    done < <(awk -F'\t' -v d="$1" '$1==d' "$P2_IM")
    if [ "$miss" -gt 0 ]; then echo "miss $miss/$tot"
    elif [ "$settle" -gt 0 ]; then echo "settling $settle/$tot"
    else echo ready; fi
}

# sample dataset dv_model -> 0 if Clair3 + (DeepVariant) + Sniffles VCF 존재
# dv_model이 '-'인 런(R9.4.1)은 DeepVariant를 돌리지 않으므로 검사에서 뺀다.
p2_vcf_done() {
    local base="$RUN_BASE/$1/ONT/$2" id="$1.$2.$REF_NAME" dv="$3"
    [ -s "$base/03_VCF/clair3/$id.clair3.vcf.gz" ] || return 1
    [ -s "$base/03_VCF/SV_sniffles/$id.sniffles.vcf.gz" ] || return 1
    if [ "$dv" != - ]; then
        [ -s "$base/03_VCF/deepvariant/$id.deepvariant.vcf.gz" ] || return 1
    fi
    return 0
}

p2_qstat_refresh() { P2_QSTAT="$(qstat -u "${USER:-$(whoami)}" 2>/dev/null || true)"; }

# dsid -> qstat state (r/qw/Eqw...) 또는 '-'
p2_job_state() {
    local idf="$INFRA/jobs/$1.jobid" jid st
    [ -f "$idf" ] || { echo -; return; }
    jid=$(cat "$idf")
    st=$(echo "${P2_QSTAT:-}" | awk -v j="$jid" 'NR>2 && $1==j {print $5; exit}')
    echo "${st:--}"
}

p2_job_alive() { [ "$(p2_job_state "$1")" != - ]; }

# 컨테이너 이미지 캐시 경로 (Nextflow 규약: 프로토콜 제거 후 [/:] -> '-' + .img)
p2_img_path() { echo "$NXF_SINGULARITY_CACHEDIR/$(echo "$1" | sed 's#[/:]#-#g').img"; }

p2_container_uris() {
    grep -oE "container_[a-z0-9_]+ *= *'[^']+'" "$P2_DIR/pipeline/ont-wgs/nextflow.config" \
        | cut -d"'" -f2 | sort -u
}

# run_table에서 실제로 쓰이는 clair3 모델 목록 (중복 표시된 런 포함 — 나중에 돌릴 수 있으니 다 받아 둔다)
p2_clair3_models() { awk -F'\t' 'NR>1 {print $9}' "$P2_RT" | sort -u; }
