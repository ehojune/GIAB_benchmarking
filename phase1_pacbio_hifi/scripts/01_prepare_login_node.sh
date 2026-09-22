#!/bin/bash
# 로그인 노드 1회 준비 (재실행 안전): 디렉토리, Nextflow 배포판 캐시, 컨테이너,
# 레퍼런스 FASTA, pbsv TRF bed. 계산 노드는 외부 네트워크가 없으므로 제출 전에 반드시 실행.
#
# 컨테이너는 파이프라인용(nextflow.config의 container_*)에 벤치마킹용(BENCH_IMAGES, env.sh)을 더한다.
# 벤치마크 단계를 처음 쓰는 클론이면 이 스크립트를 먼저 다시 돌려야 한다 — 이미 있는 건 cached로 넘어간다.
#
# 환경 변수: SKIP_PULL=1  이미지를 받지 않고 없는 것만 보고한다 (레퍼런스 점검만 빠르게 돌릴 때)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"

mkdir -p "$INFRA"/{containers,reference,tmp,work,launch,jobs,logs} "$RUN_BASE"

echo "== [0/4] SGE 설정 확인 =="
# 파이프라인은 잡 1개 안에서 local executor로 도므로 슬롯이 한 노드에 모여야 한다.
# allocation_rule이 $pe_slots(또는 고정수)가 아니면 슬롯이 여러 노드로 쪼개지고,
# 그 경우 잡은 한 노드 코어만 쓰면서 다른 노드 슬롯을 점유만 한다.
rule=$(qconf -sp "$SGE_PE" 2>/dev/null | awk '$1=="allocation_rule" {print $2}')
case "$rule" in
    '$pe_slots') echo "  PE $SGE_PE: allocation_rule=$rule (단일 노드 보장, 정상)" ;;
    '') echo "  WARN: PE '$SGE_PE'를 조회 못함 — qconf -spl 로 이름 확인" ;;
    *) echo "  WARN: PE $SGE_PE allocation_rule=$rule — 슬롯이 여러 노드로 갈릴 수 있다."
       echo "        단일 노드 PE가 따로 있으면 env.local.sh에서 SGE_PE를 그걸로 지정할 것 (qconf -spl)" ;;
esac
cons=$(qconf -sc 2>/dev/null | awk '$1=="h_vmem" {print $6}')
[ "$cons" = NO ] && echo "  h_vmem consumable=NO → 메모리는 예약되지 않음. 노드당 잡 수는 슬롯으로 통제 (env.local.sh.example 참고)"
echo "  현재 잡 크기: ${SGE_SLOTS}슬롯 / h_vmem ${SGE_VMEM} / Nextflow 메모리 상한 ${NF_LOCAL_MEM_GB}G"
# 쓸 수 있는 노드 집합은 그때그때 바뀐다 (2026-09-22에 shepherd 3대 -> octopus 2 + shepherd 2, 큐도 둘).
# 그래서 이름을 박아 두지 않고 SGE_QUEUE x SGE_HOSTS 로 실제 큐 인스턴스를 뽑아 보여준다.
echo "  설정: SGE_QUEUE='$SGE_QUEUE'  SGE_HOSTS='$SGE_HOSTS'"
if ! p1_require_sge_targets; then
    echo "  ^^ 이 상태로는 제출해도 잡이 qw 로 남는다. env.local.sh 에서 위 목록에 맞게 고칠 것."
fi
qhost 2>/dev/null | awk -v h="$SGE_HOSTS" 'NR<=2 || $1 ~ h' || true

echo "== [1/4] Nextflow $NXF_VER 배포판 캐시 =="
command -v nextflow >/dev/null || { echo "ERROR: nextflow가 PATH에 없음 — $CONDA_ENV/bin 확인"; exit 1; }
nextflow -version | grep -m1 version || true

echo "== [2/4] Singularity 이미지 ($NXF_SINGULARITY_CACHEDIR) =="
command -v singularity >/dev/null || { echo "ERROR: singularity가 PATH에 없음 — conda env의 apptainer에 singularity 심링크 필요"; exit 1; }
# 이미지 목록은 lib.sh의 p1_container_uris(파이프라인) + BENCH_IMAGES(벤치마킹, env.sh).
# 캐시 파일명 규약은 p1_img_path가 안다 (Nextflow가 그 이름으로 찾는다).
fail=0
for uri in $( { p1_container_uris; for i in ${BENCH_IMAGES:-}; do echo "$i"; done; } | sed '/^$/d' | sort -u); do
    img="$(p1_img_path "$uri")"
    if [ -s "$img" ]; then echo "  cached: $(basename "$img")"; continue; fi
    if [ "${SKIP_PULL:-0}" = 1 ]; then echo "  MISSING (SKIP_PULL): $uri"; fail=1; continue; fi
    echo "  pull:   $uri"
    singularity pull --name "$img" "docker://$uri" || { echo "  FAIL:   $uri"; fail=1; }
done
[ "$fail" = 0 ] || { echo "ERROR: 일부 이미지 없음 — 재실행하면 이어서 받는다"; exit 1; }

echo "== [3/4] 레퍼런스 FASTA ($REF_FASTA) =="
src_gz="$GIAB_ROOT/release/references/GRCh38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fasta.gz"
if [ ! -s "$REF_FASTA" ]; then
    if [ ! -s "$src_gz" ]; then
        echo "  phase0 release 사본이 없어 FTP에서 직접 받음"
        mkdir -p "$(dirname "$src_gz")"
        wget -q -c -O "$src_gz.part" "$GIAB_HTTP_BASE/release/references/GRCh38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fasta.gz"
        mv "$src_gz.part" "$src_gz"
    fi
    echo "  압축 해제 중 (~3 GB)"
    gzip -dc "$src_gz" > "$REF_FASTA.part" && mv "$REF_FASTA.part" "$REF_FASTA"
else
    echo "  있음"
fi

echo "== [4/4] pbsv TRF bed (선택 사항, 권장) =="
if [ ! -s "$TRF_BED" ]; then
    wget -q -O "$TRF_BED.part" "https://raw.githubusercontent.com/PacificBiosciences/pbsv/master/annotations/human_GRCh38_no_alt_analysis_set.trf.bed" \
        && mv "$TRF_BED.part" "$TRF_BED" \
        || echo "  WARN: 다운로드 실패 — pbsv는 TRF bed 없이도 동작, 나중에 재시도 가능"
else
    echo "  있음"
fi

echo "준비 완료. 다음: scripts/10_submit.sh --list"
