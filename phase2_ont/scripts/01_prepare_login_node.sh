#!/bin/bash
# 로그인 노드 1회 준비 (재실행 안전): 디렉토리, SGE 점검, 컨테이너 10개, 레퍼런스 FASTA,
# sniffles TRF bed, **Clair3 모델**. 계산 노드는 외부 네트워크가 없으므로 제출 전에 반드시 실행.
#
#   bash phase2_ont/scripts/01_prepare_login_node.sh
#   SKIP_PULL=1 ... 컨테이너 pull은 건너뛰고 나머지만 (phase1이 이미 받아 둔 것 재사용 확인)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
source "$HERE/lib.sh"
PIPE="$HERE/../pipeline/ont-wgs"

mkdir -p "$INFRA"/{containers,reference,tmp,work,launch,jobs,logs} "$CLAIR3_MODEL_DIR" "$RUN_BASE"

echo "== [0/5] SGE 설정 확인 =="
# 파이프라인은 잡 1개 안에서 local executor로 도므로 슬롯이 한 노드에 모여야 한다.
# allocation_rule이 $pe_slots(또는 고정수)가 아니면 슬롯이 여러 노드로 쪼개지고,
# 그 경우 잡은 한 노드 코어만 쓰면서 다른 노드 슬롯을 점유만 한다.
rule=$(qconf -sp "$SGE_PE" 2>/dev/null | awk '$1=="allocation_rule" {print $2}')
case "$rule" in
    '$pe_slots') echo "  PE $SGE_PE: allocation_rule=$rule (단일 노드 보장, 정상)" ;;
    '') echo "  WARN: PE '$SGE_PE'를 조회 못함 — qconf -spl 로 이름 확인" ;;
    *) echo "  WARN: PE $SGE_PE allocation_rule=$rule — 슬롯이 여러 노드로 갈릴 수 있다." ;;
esac
cons=$(qconf -sc 2>/dev/null | awk '$1=="h_vmem" {print $6}')
[ "$cons" = NO ] && echo "  h_vmem consumable=NO → 메모리는 예약되지 않음. 노드당 잡 수는 슬롯으로 통제"
echo "  큐/노드: $SGE_QUEUE $SGE_HOSTS  (octopus.q는 사용 불가)"
echo "  현재 잡 크기: ${SGE_SLOTS}슬롯 / h_vmem ${SGE_VMEM} / Nextflow 메모리 상한 ${NF_LOCAL_MEM_GB}G"
qhost 2>/dev/null | awk 'NR<=2 || /shepherd-1-[789]/' || true

echo "== [1/5] Nextflow $NXF_VER =="
command -v nextflow >/dev/null || { echo "ERROR: nextflow가 PATH에 없음 — $CONDA_ENV/bin 확인"; exit 1; }
nextflow -version | grep -m1 version || true

echo "== [2/5] Singularity 이미지 ($NXF_SINGULARITY_CACHEDIR) =="
command -v singularity >/dev/null || { echo "ERROR: singularity가 PATH에 없음"; exit 1; }
fail=0
for uri in $(p2_container_uris); do
    img="$(p2_img_path "$uri")"
    if [ -s "$img" ]; then echo "  cached: $(basename "$img")"; continue; fi
    if [ "${SKIP_PULL:-0}" = 1 ]; then echo "  MISSING (SKIP_PULL): $uri"; fail=1; continue; fi
    echo "  pull:   $uri"
    singularity pull --name "$img" "docker://$uri" || { echo "  FAIL:   $uri"; fail=1; }
done
[ "$fail" = 0 ] || { echo "ERROR: 일부 이미지 없음 — 재실행하면 이어서 받는다"; exit 1; }

echo "== [3/5] 레퍼런스 FASTA ($REF_FASTA) =="
# phase1과 같은 파일을 공유한다 ($INFRA는 phase1/phase2 공용)
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

echo "== [4/5] TRF bed (sniffles --tandem-repeats, 권장) =="
if [ ! -s "$TRF_BED" ]; then
    # sniffles 배포본과 pbsv 배포본의 파일이 동일하다 (2026-08-22 확인: 둘 다 7,594,623 바이트).
    # phase1이 이미 받아 뒀으면 그걸 그대로 쓴다.
    wget -q -O "$TRF_BED.part" "https://raw.githubusercontent.com/fritzsedlazeck/Sniffles/master/annotations/human_GRCh38_no_alt_analysis_set.trf.bed" \
        && mv "$TRF_BED.part" "$TRF_BED" \
        || echo "  WARN: 다운로드 실패 — sniffles는 bed 없이도 동작(정확도만 손해), 나중에 재시도 가능"
else
    echo "  있음"
fi

echo "== [5/5] Clair3 모델 =="
# 여기가 ONT의 함정이다. hkubal/clair3:v1.2.0 이미지에는 우리가 쓸 모델이 절반도 없다.
# run_table.tsv가 요구하는 모델을 이미지 목록과 대조해서, 없는 것만 내려받는다.
clair3_img="$(p2_img_path "$(p2_container_uris | grep clair3)")"
in_image="$(singularity exec "$clair3_img" ls /opt/models 2>/dev/null || true)"
echo "  이미지 안 /opt/models:"
echo "$in_image" | sed 's/^/    /'
HKU="https://www.bio8.cs.hku.hk/clair3/clair3_models"
RERIO="https://cdn.oxfordnanoportal.com/software/analysis/models/clair3"
need_fail=0
for m in $(p2_clair3_models); do
    [ "$m" = - ] && continue
    if echo "$in_image" | grep -qx "$m"; then echo "  이미지에 있음: $m"; continue; fi
    if [ -d "$CLAIR3_MODEL_DIR/$m" ]; then echo "  받아둠:        $m"; continue; fi
    # 모델 이름의 '+'는 URL에서 %2B로 인코딩해야 한다 (r941_prom_hac_g360+g422)
    enc="${m//+/%2B}"
    echo "  다운로드:      $m"
    ok=0
    dest="$CLAIR3_MODEL_DIR/$m"
    for url in "$HKU/$enc.tar.gz" "$RERIO/$m.tar.gz"; do
        if wget -q -O "$INFRA/tmp/$m.tar.gz" "$url"; then
            mkdir -p "$dest"
            tar -xzf "$INFRA/tmp/$m.tar.gz" -C "$dest"
            # 아카이브 안쪽 디렉토리 이름은 모델 이름과 다를 수 있다
            # (실측: r941_prom_hac_g238.tar.gz -> ont_guppy2/). pileup.index가 있는 곳을 찾아 끌어올린다.
            if [ ! -f "$dest/pileup.index" ]; then
                inner=$(find "$dest" -name pileup.index -printf '%h\n' 2>/dev/null | head -1)
                if [ -n "$inner" ] && [ "$inner" != "$dest" ]; then
                    mv "$inner"/* "$dest"/
                    find "$dest" -mindepth 1 -type d -empty -delete
                fi
            fi
            rm -f "$INFRA/tmp/$m.tar.gz"
            ok=1; break
        fi
    done
    if [ "$ok" = 1 ] && [ -f "$dest/pileup.index" ]; then
        echo "    OK ($(du -sh "$dest" | cut -f1))"
    else
        # 기본 제출(dup_of 없는 런)이 쓰는 모델만 치명적이다. gate된 재베이스콜 런에만 필요한
        # 모델은 경고로 넘긴다 — 그것 때문에 14개 기본 런을 막을 이유가 없다.
        if p2_clair3_models_primary | grep -qx "$m"; then
            echo "    FAIL: $m — HKU/Rerio 양쪽 실패. 이 모델은 기본 제출 런이 쓴다"
            need_fail=1
        else
            echo "    WARN: $m — 받지 못했다. DUP_OK=1로 돌릴 런에만 필요하니 기본 제출은 진행 가능"
        fi
    fi
done
[ "$need_fail" = 0 ] || { echo "ERROR: 기본 제출 런이 쓸 Clair3 모델이 빠졌다. 이 상태로 제출하면 그 런이 CLAIR3에서 죽는다"; exit 1; }

echo
echo "준비 완료. 다음:"
echo "  bash $HERE/02_fetch_external_reads.sh      # HG001 rel6 리드 (외부, 136 GiB)"
echo "  nextflow run $PIPE -profile test -stub --outdir $INFRA/tmp/stub   # 배선 스모크 테스트"
echo "  bash $HERE/10_submit.sh --list"
