# ONT 파이프라인·모델 선택 근거 (조회용)

phase2_ont를 만들 때 확인한 외부 사실. 전부 2026-08-22에 직접 조회했다.

## nf-core/nanoseq를 안 쓴 이유

사용자가 우선 검토를 요청했고, 확인 결과 요건을 못 채운다.

| 확인 항목 | 결과 |
|---|---|
| 최신 릴리스 | **3.1.0 (2023-03-10)** — 3년 5개월 전. `GET /repos/nf-core/nanoseq/releases` |
| 유지보수 방향 | `dev` 브랜치 최신 머지가 PR #321 "update to Template 3.2.1 and all nf-core/modules; **add dorado + ToulligQC; remove DNA functionalities**" (2025-05-27). 즉 다음 버전은 RNA 전용이고 **DNA 변이 호출이 상류에서 제거된다** |
| germline SNV 콜러 | medaka / DeepVariant / pepper_margin_deepvariant. **Clair3 없음** — R10.4.1 ONT의 사실상 표준을 못 쓴다 |
| SV 콜러 | Sniffles / cuteSV (요건 충족) |
| 오프라인 실행 | nf-core 템플릿은 nf-schema(nf-validation) 플러그인을 받아야 한다. 계산 노드에 외부망이 없는 nbb2에서 phase1이 "플러그인 0개"를 고른 이유와 같은 문제 |

→ `phase1_pacbio_hifi/pipeline/pacbio-hifi-wgs`를 본떠 `phase2_ont/pipeline/ont-wgs`를 만들었다.

## Clair3 모델: 이미지에 없는 게 대부분이다

`hkubal/clair3:v1.2.0` README의 모델 표(2026-08-22 열람) 기준.

| 모델 | 용도 | 도커 이미지 포함 |
|---|---|---|
| `r941_prom_sup_g5014` | R9.4.1, Guppy5 sup | 있음 |
| `r941_prom_hac_g360+g422` | R9.4.1, **Guppy 3.6.0/4.2.2 hac** | **없음** |
| `r941_prom_hac_g238` | R9.4.1, Guppy 2.3.8 | **없음** |
| `r1041_e82_400bps_sup_v410` / `hac_v410` | R10.4.1 4kHz, dorado v4.1.0 | 있음 |
| `r1041_e82_400bps_sup_v500` / `hac_v500` | R10.4.1 5kHz, dorado v5.0.0 | 있음 |
| `r1041_e82_400bps_sup_v420`, `_v430` | R10.4.1, dorado v4.2.0 / v4.3.0 | **없음** |

GIAB ONT 데이터가 필요로 하는 것은 대부분 "없음" 쪽이다 (R9는 Guppy 3~4, HG008은 dorado sup@v4.2/v4.3).
phase1에서 Clair3 v2.x가 HiFi 모델을 전부 뺀 것과 같은 종류의 함정이다.

다운로드 출처 (`scripts/01_prepare_login_node.sh`가 이 순서로 시도):

1. HKU: `https://www.bio8.cs.hku.hk/clair3/clair3_models/<model>.tar.gz`
   — 디렉토리 목록에 `r941_prom_hac_g360+g422`, `_g238`, `r1041_e82_400bps_sup_v420` 등이 있다.
   URL에서 `+`는 `%2B`로 인코딩해야 한다. http는 301이고 https로 받아야 한다.
2. ONT Rerio: `https://cdn.oxfordnanoportal.com/software/analysis/models/clair3/<model>.tar.gz`
   — `nanoporetech/rerio` repo의 `clair3_models/<model>_model` 파일이 이 URL 한 줄을 담고 있다.
   `sup_v420`, `sup_v430`, `sup_v500`, `hac_v600` 등 버전별 정확 매칭이 여기 있다.

## DeepVariant의 ONT 모델은 하나뿐

`google/deepvariant:1.10.0` (레지스트리 최신 태그). `scripts/run_deepvariant.py`의
`--model_type` enum은 `[WGS, WES, PACBIO, ONT_R104, HYBRID_PACBIO_ILLUMINA]`이고
`MODEL_TYPE_MAP`에서 `ONT_R104 -> /opt/models/ont_r104`다. **R9.4.1용 모델은 없다** —
그래서 R9 데이터셋은 Clair3 단독으로 돌린다 (`run_table.tsv`의 `dv_model` 열이 `-`).

## HG001 리드의 출처

GIAB `data/NA12878/Ultralong_OxfordNanopore`에는 GRCh37/38 BAM 2개(각 164 GiB)만 있고 리드가 없다.
GIAB README가 "rel6 based called reads"라고 밝히는데, 그 rel6는 GIAB가 아니라
**nanopore-wgs-consortium**(Jain et al. 2018, *Nanopore sequencing and assembly of a human genome
with ultra-long reads*)의 공개 데이터다.

- 전체 fastq: `https://s3.amazonaws.com/nanopore-human-wgs/rel6/rel_6.fastq.gz`
  — **146,155,473,652 바이트** (HEAD로 확인). ETag가 멀티파트(`-8712`)라 md5로 못 쓴다.
- sequencing summary: `.../rel_6_sequencing_summary.txt.gz` — 1,182,107,904 바이트.
- `Genome.md` 표 집계: rel6 = 53 플로우셀 / 132.9 Gbp / **~43x**. 이 중 `Kit=Ultra` 행은
  12 플로우셀 / 19.3 Gbp / **6.2x**뿐이다.
- 즉 파일명이 `minion-ul`인데 GIAB BAM이 rel6 전체인지 Ultra 12셀인지는 문서로 확정할 수 없다.
  `scripts/03_dup_evidence.sh HG001`이 BAM 헤더(@RG/@PG) + 리드 수 + read_id 표본으로 대조한다.
- rel7(`rel_7.fastq.gz`, 116,979,102,692 바이트)도 있지만 GIAB가 rel6이라고 적었으므로 rel6을 쓴다.

## 그 밖의 확인 사항

| 항목 | 확인 결과 |
|---|---|
| minimap2+samtools 컨테이너 | nf-core `minimap2/align` 모듈이 쓰는 `community.wave.seqera.io/library/minimap2_samtools:b09096fc890429ce` = minimap2 2.30 + samtools 1.23.1 (모듈 `environment.yml`). 정렬이 `samtools fastq \| minimap2 \| samtools sort` 파이프라 한 이미지에 둘 다 필요하다 |
| Sniffles2 / LongPhase | quay.io biocontainers 최신: `sniffles 2.8.0--pyhdfd78af_1`, `longphase 2.0.2--h4e109e1_0` |
| TRF bed | sniffles repo와 pbsv repo의 `human_GRCh38_no_alt_analysis_set.trf.bed`가 **같은 파일**이다 (둘 다 7,594,623 바이트) → phase1이 받아 둔 것을 그대로 쓴다 |
| 위상 도구 | LongPhase는 멀티스레드이고 `--sv-file`로 SV까지 같이 위상한다. `whatshap phase`는 단일 스레드라 ONT 50~100x에서 런타임을 지배한다 → 위상은 LongPhase, 지표만 `whatshap stats` |
| minimap2 `-y` | uBAM 진입에서만 붙인다. Guppy/dorado fastq의 헤더 코멘트(`runid=... ch=... start_time=...`)는 SAM aux(TAG:TYPE:VALUE) 형식이 아니라, `-y`로 그대로 옮기면 BAM이 깨진다 |
