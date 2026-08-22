# ont-wgs

ONT 사람 WGS germline 파이프라인. 플러그인 0개, nf-core 템플릿 없음, 컨테이너는 전부 `params.container_*`.

```
fastq | uBAM | aligned BAM
  └─ minimap2 -x map-ont ─ merge ─ CHECK_BAM
       ├─ Clair3            (모델을 데이터셋마다 지정)
       ├─ DeepVariant       (ONT_R104 = R10.4.1 전용, R9에서는 --skip_deepvariant)
       ├─ Sniffles2         (--tandem-repeats 권장)
       ├─ LongPhase         phase (+SV 동시 위상) → haplotag
       └─ QC                mosdepth / samtools / bcftools / whatshap stats → MultiQC
```

산출: `<outdir>/<sample>/ONT/<dataset>/{02_alignedBAM,03_VCF,04_QC}`

## 샘플시트

```csv
sample,dataset,input_type,file,index,unit
HG002,guppy-V3.4.5,fastq,/data/HG002_ONT-UL.fastq.gz,,
HG008T-p2,BCM_ONT-std_HG008T-p2_20260313,ubam,/data/run1C/PBI63802_pass_0.bam,,20260202_1137_1C
```

| 열 | 설명 |
|---|---|
| `input_type` | `fastq` / `ubam` / `aligned_bam` |
| `index` | `aligned_bam`의 `.bai` (다른 타입에서는 비워야 한다) |
| `unit` | 정렬 단위 이름. 비우면 파일명에서 만든다. **같은 unit을 가진 `ubam` 행 여러 개는 정렬 전에 `samtools cat`으로 합친다** — 플로우셀 하나가 uBAM 500개로 쪼개져 오는 경우용 |

상대경로는 **샘플시트가 있는 디렉토리** 기준으로 푼다. `(sample,dataset)`가 같은 행들은 정렬 후 하나의 BAM으로 병합된다.

## 파라미터 (전체는 nextflow.config)

| 파라미터 | 기본값 | 비고 |
|---|---|---|
| `--clair3_model` | `r1041_e82_400bps_sup_v500` | **틀려도 조용히 돌아간다.** 케미스트리·베이스콜러별로 지정할 것 |
| `--clair3_model_dir` | – | 컨테이너에 없는 모델을 담은 디렉토리. 주면 여기서 먼저 찾는다 |
| `--skip_deepvariant` | false | R9.4.1 데이터에서는 반드시 켠다 |
| `--sniffles_tandem_repeats` | – | TRF bed (pbsv 배포본과 동일 파일) |
| `--phase_vcf` / `--phase_sv` | `clair3` / true | 위상 대상 소변이 VCF / Sniffles VCF 동시 위상 |
| `--minimap2_sort_mem` | `2G` | `samtools sort -m`(스레드당). 정렬 메모리는 스레드 수 × 이 값 |

### Clair3 모델은 이미지에 다 없다

`hkubal/clair3:v1.2.0` 이미지에 **있는** 것: `r941_prom_sup_g5014`, `r1041_e82_400bps_{sup,hac}_v410`,
`r1041_e82_400bps_{sup,hac}_v500`, `hifi*`, `ilmn`.
**없는** 것: `r941_prom_hac_g360+g422`(Guppy 3.6/4.2.2 hac), `r1041_e82_400bps_sup_v420`, `_v430`.
GIAB ONT 데이터는 대부분 후자를 쓴다 — 그래서 `../../scripts/01_prepare_login_node.sh`가 이 모델들을
`$CLAIR3_MODEL_DIR`에 내려받고, 잡이 `--clair3_model_dir`로 마운트한다.
모델이 없으면 CLAIR3가 시작 단계에서 두 디렉토리 목록을 찍고 죽는다 (조용히 넘어가지 않는다).

## pacbio-hifi-wgs와 다르게 만든 부분

| 항목 | 이유 |
|---|---|
| pbmm2 → minimap2 `-x map-ont` | pbmm2는 PacBio 전용 |
| pbsv → Sniffles2 | pbsv는 PacBio 전용. ONT 표준은 Sniffles2 |
| WhatsHap phase → LongPhase | `whatshap phase`는 단일 스레드다. ONT 50~100x에서 런타임을 지배한다. 위상 QC 지표는 계속 `whatshap stats`로 뽑는다 |
| uBAM 진입에서 `samtools fastq -T MM,ML,MN \| minimap2 -y` | 메틸 태그를 살린다. `-y`는 **uBAM 진입에만** 붙는다 — Guppy fastq의 헤더 코멘트(`runid=... ch=...`)는 SAM aux 형식이 아니라 그대로 옮기면 BAM이 깨진다 |
| `unit` 열 + `samtools cat` | uBAM 1090개짜리 데이터셋(HG008T-p2)에서 정렬 태스크를 1090개가 아니라 2개로 만든다 |

uBAM 진입에서 원본 `@RG`(dorado 모델 문자열)는 fastq를 거치며 사라진다. 파이프라인이
`ID:<unit> SM:<sample> PL:ONT`로 새로 붙이고, 베이스콜러·모델은 `../../run_table.tsv`에 남긴다.

## 스모크 테스트

컨테이너·데이터 없이 채널 배선만 본다 (빈 파일 + `-stub`):

```bash
nextflow run pipeline/ont-wgs -profile test -stub --outdir /tmp/ont_stub
```
