#!/bin/bash
# 로그인 노드 1회 준비 (재실행 안전): 디렉토리, Nextflow 배포판 캐시, 컨테이너 11개,
# 레퍼런스 FASTA, pbsv TRF bed. 계산 노드는 외부 네트워크가 없으므로 제출 전에 반드시 실행.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
PIPE="$HERE/../pipeline/pacbio-hifi-wgs"

mkdir -p "$INFRA"/{containers,reference,tmp,work,launch,jobs,logs} "$RUN_BASE"

echo "== [1/4] Nextflow $NXF_VER 배포판 캐시 =="
command -v nextflow >/dev/null || { echo "ERROR: nextflow가 PATH에 없음 — $CONDA_ENV/bin 확인"; exit 1; }
nextflow -version | grep -m1 version || true

echo "== [2/4] Singularity 이미지 ($NXF_SINGULARITY_CACHEDIR) =="
command -v singularity >/dev/null || { echo "ERROR: singularity가 PATH에 없음 — conda env의 apptainer에 singularity 심링크 필요"; exit 1; }
# 캐시 파일명 규약: 프로토콜 없이 [/:] -> '-' 치환 + .img (Nextflow가 이 이름으로 찾음)
uris=$(grep -oE "container_[a-z0-9_]+ *= *'[^']+'" "$PIPE/nextflow.config" | cut -d"'" -f2 | sort -u)
fail=0
cd "$NXF_SINGULARITY_CACHEDIR"
for uri in $uris; do
    img="$(echo "$uri" | sed 's#[/:]#-#g').img"
    if [ -s "$img" ]; then echo "  cached: $img"; continue; fi
    echo "  pull:   $uri"
    singularity pull --name "$img" "docker://$uri" || { echo "  FAIL:   $uri"; fail=1; }
done
[ "$fail" = 0 ] || { echo "ERROR: 일부 이미지 pull 실패 — 재실행하면 이어서 받는다"; exit 1; }

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
