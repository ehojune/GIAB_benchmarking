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

# 컨테이너 이미지 캐시 경로 (Nextflow 규약: 프로토콜 제거 후 [/:] -> '-' + .img)
p1_img_path() { echo "$NXF_SINGULARITY_CACHEDIR/$(echo "$1" | sed 's#[/:]#-#g').img"; }

# 파이프라인이 쓰는 컨테이너 URI 목록. BENCH_IMAGES(env.sh)는 파이프라인이 안 쓰므로 여기 없다 —
# 미리 받아야 하는 쪽(01_prepare)에서 따로 합친다.
# 2026-09-21까지 이 파싱이 4개 스크립트에 각자 인라인으로 박혀 있었고, 그중 하나가 편집 잔재로
# 깨져서 BENCH_IMAGES를 통째로 놓쳤다. 한 곳에서만 고칠 수 있게 함수로 뺀다.
p1_container_uris() {
    grep -oE "container_[a-z0-9_]+ *= *'[^']+'" "$P1_DIR/pipeline/pacbio-hifi-wgs/nextflow.config" \
        | cut -d"'" -f2 | sort -u
}

# dsid -> 기기 세대 (Revio | SequelII | SequelI | RSII | mixed:... | -)
# 근거는 inputs_manifest.tsv 파일명의 **movie ID**다: m84=Revio, m64=Sequel II, m54=Sequel I,
# m14/m15=RS II. dataset 이름으로 때려잡으면 안 된다 — HG002.PacBio_CCS_10kb/15kb 는 이름에
# 세대 표시가 없는데 실제로는 m54(Sequel I)라, 이름 기반 판정은 이 둘을 Sequel II로 잘못 묶는다
# (2026-09-22 Codex 리뷰 지적). 61_benchmark_sv.sh 가 내세우는 세대 비교축이 바로 이 둘을 포함한다.
# 경로에 PBmixSequel<NNN> 이 있어도 그건 PacBio의 혼합 런 명명일 뿐 세대 표시가 아니다
# (HG001.HudsonAlpha_PacBio_CCS 는 PBmixSequel846 디렉토리 안에 m64 movie가 들어 있다).
# movie ID가 아예 없는 런(HG003/6/7 chemistry2 셋)은 '-'로 둔다 — 추측하지 않는다.
p1_instr_of() {
    local p
    p=$(awk -F'\t' -v d="$1" '$1==d {print $2}' "$P1_IM" \
        | grep -oE 'm[0-9]{5}_[0-9]{6}' | cut -c1-3 | sort -u | paste -sd, -)
    case "$p" in
        m84)         echo Revio ;;
        m64)         echo SequelII ;;
        m54)         echo SequelI ;;
        m14|m15|m14,m15) echo RSII ;;
        '')          echo - ;;
        *)           echo "mixed:$p" ;;
    esac
}

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
p1_sge_targets() {
    local qre="^(${SGE_QUEUE//,/|})@"
    qstat -f 2>/dev/null | awk -v q="$qre" -v h="$SGE_HOSTS" '
        $1 ~ /@/ && $1 ~ q { split($1, a, "@"); if (a[2] ~ h) print $1 }' | sort -u
}

# 잡 스크립트의 -q 에 넣을 값. 실재하는 큐만 남긴다 — SGE_QUEUE에 옛 이름이 섞여 있어도
# 그 때문에 잡 전체가 거부되지 않는다. qstat을 못 읽으면 SGE_QUEUE를 그대로 쓴다.
p1_sge_queue_arg() {
    local q; q=$(p1_sge_targets | cut -d@ -f1 | sort -u | paste -sd, -)
    echo "${q:-$SGE_QUEUE}"
}

# 제출 전 게이트. 겹치는 인스턴스가 없으면 무엇을 고를 수 있는지 보여주고 실패한다.
p1_require_sge_targets() {
    local t; t=$(p1_sge_targets)
    if [ -z "$t" ]; then
        echo "ERROR: SGE_QUEUE='$SGE_QUEUE' 와 SGE_HOSTS='$SGE_HOSTS' 에 겹치는 큐 인스턴스가 없다."
        echo "       이대로 제출하면 잡이 영원히 qw 로 남는다. 아래에서 골라 env.local.sh 에 적을 것:"
        qstat -f 2>/dev/null | awk '$1 ~ /@/ {print "         " $1}' | sort -u
        return 1
    fi
    echo "  대상: $(echo "$t" | tr '\n' ' ')"
}
