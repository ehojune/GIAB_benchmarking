# phase1 공용 헬퍼. 10_submit.sh / 20_status.sh 가 source 한다. env.sh 를 먼저 읽은 상태를 전제.
# shellcheck shell=bash

P1_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
P1_RT="$P1_DIR/run_table.tsv"
P1_IM="$P1_DIR/inputs_manifest.tsv"

# 다운로드가 끝난 것으로 인정하기까지 파일이 조용해야 하는 시간(분).
# 왜 필요한가: phase0의 기본 경로인 `aws s3 cp`는 .part 없이 최종 파일명에 바로 쓰고,
# 대용량은 멀티파트로 오프셋에 나눠 쓴다. 그래서 뒤쪽 파트가 먼저 도착하면
# **겉보기 크기는 최종 크기인데 중간이 빈 구멍인** 상태가 생긴다 — 크기만 보면 완료로 오판한다.
# 쓰기가 있을 때마다 mtime이 갱신되므로, 크기가 맞고 + N분간 조용하면 완료로 본다.
# (wget/aria2 경로는 .part -> mv 라서 애초에 안전하다.)
P1_READY_AGE_MIN="${READY_AGE_MIN:-10}"

p1_row() { awk -F'\t' -v d="$1" '$1==d {print; exit}' "$P1_RT"; }
p1_col() { echo "$1" | cut -f"$2"; }   # 1 dsid 2 sample 3 dataset 4 entry 5 units 6 clair3 7 gib 8 dup_of 9 note

p1_dsids() { awk -F'\t' 'NR>1 {print $1}' "$P1_RT"; }
p1_dsids_primary() { awk -F'\t' 'NR>1 && $8=="" {print $1}' "$P1_RT"; }

# dsid -> "ready" | "settling k/n" | "miss k/n"
p1_inputs_state() {
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
        if [ $(( (now - mt) / 60 )) -lt "$P1_READY_AGE_MIN" ]; then
            settle=$((settle + 1))
        fi
    done < <(awk -F'\t' -v d="$1" '$1==d' "$P1_IM")
    if [ "$miss" -gt 0 ]; then echo "miss $miss/$tot"
    elif [ "$settle" -gt 0 ]; then echo "settling $settle/$tot"
    else echo ready; fi
}

# sample dataset -> 0 if DeepVariant+Clair3+pbsv VCF 존재
p1_vcf_done() {
    local base="$RUN_BASE/$1/PacBio/$2" id="$1.$2.$REF_NAME"
    [ -s "$base/03_VCF/deepvariant/$id.deepvariant.vcf.gz" ] &&
    [ -s "$base/03_VCF/clair3/$id.clair3.vcf.gz" ] &&
    [ -s "$base/03_VCF/SV_pbsv/$id.pbsv.vcf.gz" ]
}

p1_qstat_refresh() { P1_QSTAT="$(qstat -u "${USER:-$(whoami)}" 2>/dev/null || true)"; }

# dsid -> qstat state (r/qw/Eqw...) 또는 '-'
p1_job_state() {
    local idf="$INFRA/jobs/$1.jobid" jid st
    [ -f "$idf" ] || { echo -; return; }
    jid=$(cat "$idf")
    st=$(echo "${P1_QSTAT:-}" | awk -v j="$jid" 'NR>2 && $1==j {print $5; exit}')
    echo "${st:--}"
}

p1_job_alive() { [ "$(p1_job_state "$1")" != - ]; }
