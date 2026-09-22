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
# 기본 제출(dup_of 없는) 런이 쓰는 모델만. 이게 빠지면 치명적이고, 나머지는 경고로 족하다.
p2_clair3_models_primary() { awk -F'\t' 'NR>1 && $12=="" {print $9}' "$P2_RT" | sort -u; }

# ── 큐/노드 해석 ──────────────────────────────────────────────────────────────
# 쓸 수 있는 노드 집합은 **고정이 아니다.** 다른 연구자와 나눠 쓰는 자원이라 그때그때 바뀌고,
# 2026-09-22에는 큐가 둘로 갈렸다 (shepherd.q + octopus.q). 그래서 이름을 박아 두지 않고
# SGE_QUEUE(콤마 목록) x SGE_HOSTS(정규식)를 **실제 큐 인스턴스와 대조해서** 쓴다.
#
# 왜 대조가 필요한가: 큐에 없는 노드를 -l h= 로 지정하면 qsub은 받아들이고 잡은 qw로 남는다.
# 영원히. 에러도 안 난다. 반대로 -q 에 없는 큐 이름을 넣으면 그 순간 잡 전체가 거부된다.
# 둘 다 제출하고 한참 뒤에야 알게 되는 실패라, 로그인 노드에서 미리 걸러낸다.
#
# **이 대조가 답해 주지 않는 것**: 우리가 그 노드를 써도 되는지. qstat -f 는 클러스터의 전 큐
# 인스턴스를 보여준다 — 2026-09-22 실측으로 octopus-2-1~2-11 + shepherd-1-1~1-14 스물다섯 개다.
# 그중 우리에게 허용된 건 넷뿐이고, 그 제한은 SGE 설정이 아니라 **사람끼리의 약속**이라
# 스크립트가 알 길이 없다. 즉 이 게이트는 오타·옛 이름을 잡는 장치지 권한 검사가 아니다.
# 허용 목록은 사용자에게 물어서 SGE_HOSTS 에 적는 수밖에 없다.

# SGE_QUEUE x SGE_HOSTS 와 실제로 겹치는 큐 인스턴스(queue@host) 목록.
p2_sge_targets() {
    local qre="^(${SGE_QUEUE//,/|})@"
    qstat -f 2>/dev/null | awk -v q="$qre" -v h="$SGE_HOSTS" '
        $1 ~ /@/ && $1 ~ q { split($1, a, "@"); if (a[2] ~ h) print $1 }' | sort -u
}

# 잡 스크립트의 -q 에 넣을 값. 실재하는 큐만 남긴다 — SGE_QUEUE에 옛 이름이 섞여 있어도
# 그 때문에 잡 전체가 거부되지 않는다. qstat을 못 읽으면 SGE_QUEUE를 그대로 쓴다.
p2_sge_queue_arg() {
    local q; q=$(p2_sge_targets | cut -d@ -f1 | sort -u | paste -sd, -)
    echo "${q:-$SGE_QUEUE}"
}

# 제출 전 게이트. 겹치는 인스턴스가 없으면 무엇을 고를 수 있는지 보여주고 실패한다.
p2_require_sge_targets() {
    local t; t=$(p2_sge_targets)
    if [ -z "$t" ]; then
        echo "ERROR: SGE_QUEUE='$SGE_QUEUE' 와 SGE_HOSTS='$SGE_HOSTS' 에 겹치는 큐 인스턴스가 없다."
        echo "       이대로 제출하면 잡이 영원히 qw 로 남는다. 아래에서 골라 env.local.sh 에 적을 것:"
        qstat -f 2>/dev/null | awk '$1 ~ /@/ {print "         " $1}' | sort -u
        return 1
    fi
    echo "  대상: $(echo "$t" | tr '\n' ' ')"
}
