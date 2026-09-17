# Phase 3 — 숏리드 WGS (HG002·HG003·HG004)

대상: 원시 FASTQ가 있는 표준 short-read WGS만. mate-pair·Moleculo·10X·stLFR·Hi-C·Strand-seq·엑솜(BAM only)·
Complete Genomics·SOLiD는 제외 (이유: 일반 germline 파이프라인에 그대로 넣을 수 없음).
GIAB FTP 밖의 30x 트리오 2종(NovaSeq PCR-free, HiSeq 30x 서브샘플)과 HG002 NovaSeq X 30x를 2026-09-17에 추가했다 — 업체 산출물과 조건을 맞춘 비교 arm.
파이프라인은 사용자가 지정·실행한다.

- [inputs_manifest.tsv](inputs_manifest.tsv) — GIAB FTP에서 받은 파이프라인 입력 FASTQ 전부. `dsid / relpath / bytes`. **6,178 files / 5.55 TiB**
- [ext_manifest.tsv](ext_manifest.tsv) — GIAB FTP 밖에서 받는 입력 FASTQ. `dsid / relpath / bytes / url / md5 / kind / note`. **12 files / 359 GiB**. 카탈로그(`catalog/master_catalog.tsv`)에도 `external/` 행 6개로 들어가 있다. 받기: `bash scripts/02_fetch_external_reads.sh` (로그인 노드, `VERIFY_ONLY=1`로 점검만). **2026-09-17 12/12 OK** (크기·md5·리드 길이·플랫폼; 로그 `external/phase3_ext_fetch.log`)
- [all_files.tsv](all_files.tsv) — 같은 플랫폼 디렉토리의 모든 파일(GIAB BAM·VCF·md5 포함). `dsid / ftype / relpath / bytes`. 6,890 files
- [run_table.tsv](run_table.tsv) — 실행 단위 24개 (GIAB 18 + 외부 6). `units` = read group 수 (플로우셀.레인.라이브러리)
- [samplesheets/<dsid>.csv](samplesheets/) — R1/R2 짝 맞춘 범용 시트 `sample,dataset,unit,fastq_1,fastq_2,bytes`. 재생성: `python scripts/make_samplesheets.py` (`DATA_ROOT=` 로 경로 변경; ext_manifest도 함께 읽는다)
- 로컬 절대경로 = `/BiO/scratch/ehojune/GIAB_benchmark/` + `relpath` (nbb2, phase0 DEST). 외부 리드는 그 아래 `external/<출처>/`
- 출처: `phase0_download/manifests/` 실측. GIAB분 다운로드는 2026-08-30 verify.sh all 100%, 외부분은 2026-09-17 `02_fetch_external_reads.sh` 12/12 OK로 확인됨. 24 실행 단위 전부 nbb2에 실존.

## 실행 단위 24개

업체 비교(gd001~004 산출물 ↔ GIAB raw, 같은 파이프라인)의 기준 arm은 **30x 트리오 2종**이다. 300x 전량은 깊이 상한 실험으로 남긴다
(역할 재정의 2026-09-17, [docs/decisions.md](../docs/decisions.md)). 권고 순서: NovaSeq 30x → HiSeq 30x → 300x → AVITI StdInsert.
업체 4곳은 모두 **Illumina NovaSeq X / X Plus**다(2026-09-17, 업체 FASTQ 기기ID `LH00xxx`). 공개 NovaSeq X **트리오**는 없어(GCS `novaseqx/`·ENA PRJNA1427896 모두 HG002만)
NovaSeq 6000 30x를 트리오 기준으로 쓴다 — 같은 Illumina 2x151 PCR-free 30x지만 화학은 SBS vs XLEAP-SBS로 다르다. 화학까지 맞춘 HG002 단일 대조군으로
`HG002.NovaSeqX_30x`(Google `novaseqx/`, Weill Cornell NovaSeq X 25B TruSeq PCR-free)를 추가했다. MGISEQ2000은 업체에 MGI가 없으므로 후순위로 내렸다.

| dsid | FASTQ | GiB | 비고 |
|---|---|---|---|
| **HG002/3/4.NovaSeq_PCRfree_30x** | 2 / 2 / 2 | 49 / 49 / 49 | **외부(Google GCS)**. NovaSeq 6000 PCR-free 2x151 ~30x, 세 샘플 같은 런(A00744:46 HV3C3DSXX L2). 업체 산출물과 장비·리드 길이·깊이가 맞는 유일한 공개 트리오. **업체 비교 기준 arm** |
| **HG002.NovaSeqX_30x** | 2 | 41 | **외부(Google GCS)**. NovaSeq X 25B, TruSeq PCR-free, 2x150, ~30x(원 런 SRR37356338 ≈42x의 서브샘플). 업체와 같은 화학(XLEAP-SBS)의 유일한 공개 데이터 — HG002만 |
| **HG002/3/4.Illumina_PCRfree_30x** | 2 / 2 / 2 | 83 / 87 / 83 | HiSeq 2500 2x148 TruSeq PCR-free, 300x와 같은 라이브러리의 ~30x 서브샘플(GIAB 제작). HG002는 GIAB FTP, **HG003/4는 외부(HPRC S3)** — GIAB README가 가리키는 사본. 300x↔30x 깊이 효과를 같은 라이브러리에서 잰다 |
| HG002/3/4.HiSeq300x | 1870 / 2010 / 2048 | 774 / 787 / 907 | 2x148, 플로우셀 12/13/12개 × 12 라이브러리(균질성 시험 바이알 ?A1~?L2) × 2레인 × R1/R2 × 분할. 합 300x, 플로우셀당 ~25x. **전량 사용** |
| HG002/3/4.Illumina_2x250 | 68 / 36 / 70 | 163 / 144 / 161 | 플로우셀 1개 ~40-50x, `reads/D?_S1_L00?_R?_00?.fastq.gz` |
| HG002/3/4.BGISEQ500 | 4 / 4 / 4 | 208 / 217 / 210 | PCR-free, L01·L02. **PE100**(리드 헤더 실측) — 업체 2x150과 안 맞아 후순위 |
| HG002/3/4.MGISEQ2000_PCRfree | 4 / 4 / 8 | 186 / 178 / 354 | 2x150. HG004는 라이브러리 2개(NA24143_1, _2). 깊이 미문서 — 압축비 추정 ~73x / 67x / 127x (2026-09-17, ±15%) |
| HG002/3/4.Element_AVITI_20240920 | 4 / 4 / 4 | 236 / 231 / 251 | StdInsert ~80x + LngInsert 32-38x, 라이브러리 2개 |
| HG002.NIST_BGIseq_2x150_100x | 30 | 324 | L01-L03 × 바코드 606-610 |
| HG002.Element_AVITI_20231018 | 4 | 269 | StdInsert 81x + LngInsert 55x |

nbb2에서 실존 확인 (GIAB분은 아래, 외부분은 `VERIFY_ONLY=1 bash scripts/02_fetch_external_reads.sh`):

```bash
cd /BiO/scratch/ehojune/GIAB_benchmark && awk -F'\t' 'NR>1{print $2}' <repo>/phase3_shortread_wgs/inputs_manifest.tsv | xargs -I{} sh -c 'test -f "{}" || echo MISSING {}'
```

## 외부 보충 리드 (2026-09-17 추가, 같은 날 다운로드·검증 완료)

| dsid | 출처 | 파일 | 검증(다운로드 전, 2026-09-17) |
|---|---|---|---|
| HG002/3/4.NovaSeq_PCRfree_30x | Google `gs://brain-genomics-public/research/sequencing/fastq/novaseq/wgs_pcr_free/30x/` (HTTPS, 로그인 없음) → 로컬 `external/google_novaseq_pcrfree_30x/` | 6 files / 147 GiB | HEAD 크기 일치, md5 6건(GCS md5Hash), 앞 256 KB 표본에서 2x151·NovaSeq 6000(A00744)·HV3C3DSXX L2 확인 |
| HG002.NovaSeqX_30x | Google `gs://brain-genomics-public/research/sequencing/fastq/novaseqx/HG002.novaseqX.30x.R{1,2}.fastq.gz` → 로컬 `external/google_novaseqx_hg002_30x/` | 2 files / 41 GiB | 크기·md5(GCS), 표본에서 2x150·헤더 `@SRR37356338.N pi1-04:533:22JTGYLT4` 확인. SRA 형식 이름이라 `detect_fastq_platform.sh`는 미상(숏리드)으로 찍는다 — 정상. 라이브러리는 ENA SRX32270094 design(TruSeq DNA PCR-Free) |
| HG003/4.Illumina_PCRfree_30x | HPRC S3 `s3://human-pangenomics/working/HPRC_PLUS/HG002/raw_data/Illumina/parents/HG00{3,4}/` → 로컬 `external/hprc_hiseq30x_subsampled/HG00{3,4}/` | 4 files / 170 GiB | HEAD 크기 일치, 표본에서 2x148·HISEQ1·300x 플로우셀(HA0L6ADXX, HA5R5ADXX) 확인. md5 없음(ETag 멀티파트) → 크기+리드 길이로 검증 |

`02_fetch_external_reads.sh`는 크기·md5(있는 것만)·앞 20k 리드 평균 길이·[detect_fastq_platform.sh](../phase0_download/scripts/detect_fastq_platform.sh) 플랫폼 판정(PacBio/ONT/MGI면 실패, 미상은 경고)을 본다.
같은 버킷에 NovaSeq 20x/40x/50x, HiSeq X PCR-free·PCR-plus 20~40x 트리오, HG002 NovaSeq X 10~40x·전체(≈42x) 시리즈도 있다 — 업체 라이브러리가 PCR-plus로 판명되거나
깊이 적정(titration)이 필요해지면 그때 받는다. 전체 후보 목록·근거·자문 기록: [docs/reference/phase3_shortread_candidates_2026-09-17.md](../docs/reference/phase3_shortread_candidates_2026-09-17.md).

## 정답셋 (small variant)

| 샘플 | 벤치마크 | 경로 (`release/AshkenazimTrio/<sample>/`) |
|---|---|---|
| HG002·3·4 | NIST v4.2.1 (= `latest/`) GRCh37·GRCh38 | `NISTv4.2.1/GRCh3?/HG00?_GRCh3?_1_22_v4.2.1_benchmark.vcf.gz` + `_benchmark_noinconsistent.bed` |
| HG002 | CMRG v1.00 (의학 유전자 273개) | `CMRG_v1.00/GRCh3?/` |
| HG002 | **v5.0q** (2026-03, Q100 v1.1 어셈블리 기반, GIAB "draft") | `v5.0q/HG002_GRCh38_v5.0q_smvar.vcf.gz` + `_smvar.benchmark.bed` (stvar = SV). manifest에 2026-09-16 추가, **다운로드 전** |
| HG002 | T2T-Q100 draft smvar (defrabb v0.012/v0.015, 2023-11/2024-02, v5.0q의 전신) | `data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.01?-*/GRCh3?_HG002-T2TQ100-V1.0_smvar.vcf.gz` + `.benchmark.bed` |

stratification: `release/genome-stratifications/v3.6/GRCh3?@all/` (2026-09-16 manifest 추가, 다운로드 전. v5.0q README가 v3.6을 지정; 받기 전까지는 v3.5). 참조: `release/references/GRCh38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fasta.gz`, `release/references/GRCh37/hs37d5.fa.gz`.
