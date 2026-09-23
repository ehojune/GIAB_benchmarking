# Phase 3 — 숏리드 WGS (1차 HG002·HG003·HG004, 2차 HG001·HG005~HG009)

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
| **HG002/3/4.NovaSeq_PCRfree_30x** | 2 / 2 / 2 | 49 / 49 / 49 | **외부(Google GCS)**. NovaSeq 6000 PCR-free 2x151 ~30x, 세 샘플 같은 런(A00744:46 HV3C3DSXX L2). 업체 산출물과 Illumina·2x151·PCR-free·30x는 맞지만 **화학은 다르다**(SBS vs 업체 NovaSeq X의 XLEAP-SBS). 공개 데이터 중 조건이 가장 가까운 트리오라 **업체 비교 트리오 arm**; 화학 매칭은 아래 HG002.NovaSeqX_30x |
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

## 파이프라인 입력 디렉토리 (2026-09-18)

업체 디렉토리(`G000-gd?-*/outcome/<sample>/<sample>_1.fastq.gz`)와 같은 모양, **샘플당 FASTQ 한 쌍**으로 공개 데이터를 모은다. nbb2에서 파이프라인 작업 디렉토리로 가서:

```bash
python <repo>/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py --dry-run                      # 계획만
nohup python <repo>/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py --prune --run-concat --jobs 4 > make_dirs.log 2>&1 &   # 링크 + 병합 전부, 4개씩 병렬
python <repo>/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py --prune --qsub                 # 대신 병합을 샘플별 SGE 잡으로
```

| 디렉토리 | dataset | 샘플 dir (`outcome/` 아래) | 파일 |
|---|---|---|---|
| `GIAB-publicData-Novaseq6000-PCRfree-30x` | NovaSeq_PCRfree_30x | `…-HG002` `…-HG003` `…-HG004` | 샘플당 `<sample>_1/2.fastq.gz` 1쌍 (링크) |
| `GIAB-publicData-NovaseqX-30x` | NovaSeqX_30x | `…-HG002` | 1쌍 (링크) |
| `GIAB-publicData-Hiseq-subsampled-30x` | Illumina_PCRfree_30x | HG002/3/4 | 1쌍 (링크) |
| `GIAB-publicData-Hiseq-300x` | HiSeq300x | HG002/3/4 | **cat 병합** 935/1005/1024쌍 → 1쌍 (774/787/907 GiB 실사본) |
| `GIAB-publicData-Illumina-250PE` | Illumina_2x250 | HG002/3/4 | **cat 병합** 34/18/35쌍 → 1쌍 (163/144/161 GiB; 레인당 분할 파일, HG003/4는 라이브러리 2개 포함) |
| `GIAB-publicData-MGISEQ2000-PCRfree` | MGISEQ2000_PCRfree | HG002/3/4 | **cat 병합** 2/2/4쌍 → 1쌍 (HG004는 라이브러리 2개 포함) |
| `GIAB-publicData-BGISEQ500` | BGISEQ500 | HG002/3/4 | **cat 병합** 2쌍(레인 2) → 1쌍 |
| `GIAB-publicData-Element-AVITI` | Element_AVITI_20240920 | HG002/3/4 | **cat 병합** StdInsert + LngInsert → 1쌍 (인서트 ~400 bp와 ~1300 bp가 한 파일에 섞임 — 해석 주의) |

이름은 2026-09-18 사용자 지정, 구분자는 2026-09-19에 전부 `-`로(파이프라인이 `_`로 샘플명을 자른다; `_`는 mate 접미 `_1/_2.fastq.gz`에만). 접두 `GIAB-publicData`(`--prefix`로 변경 가능, `_` 금지).
2026-09-18에 `_` 이름으로 만들어 둔 트리는 `scripts/04_rename_underscore_to_hyphen.sh <dest> [제외 dir]`로 바꾼다(기본 dry-run, `APPLY=1`로 적용, 이미 있는 이름은 SKIP). 샘플당 쌍이 하나면 링크, 둘 이상이면 cat 병합(사용자 결정 "각각 알아서"): 샘플 dir의
`concat_R1.list`/`concat_R2.list`(같은 순서)를 `concat.sh`가 이어붙이고 출력 크기 = 입력 합을 확인한다(gzip 멀티멤버, 이미 맞으면 SKIP). 병합 파일은 실사본이라 약 3.6 TiB가 추가로 든다.
`--run-concat --jobs N`은 로그인 노드에서 N개씩 병렬로 전부 돌리고 끝까지 기다린다(nohup 권장), `--qsub`은 샘플별 SGE 잡(shepherd.q, phase2와 같은 호스트 제한)으로 제출한다.
NIST_BGIseq_2x150_100x·Element_AVITI_20231018은 1차 DIRNAME에 없어 2차(아래)에서 새 set으로 만든다. 재실행은 멱등이고, 같은 이름이 다른 원본을 가리키면 멈춘다. `--prune`은 계획에 없는 옛 심볼릭 링크만 지운다(일반 파일·병합 결과는 안 건드림). 원본은 samplesheets의 절대경로 그대로다.

## 2차 입력 (2026-09-23) — 나머지 숏리드 전부

사용자 지시 "GIAB의 모든 숏리드 데이터는 국통바빅 파이프라인으로". 1차 22 샘플 밖의 표준 short-read WGS 53 샘플(20 set)을 같은 규약으로 만든다.
생성: `python scripts/make_more_samplesheets.py` → `samplesheets/<dsid>.csv` + [more_run_table.tsv](more_run_table.tsv)(set·label·성별·tier·read 길이 실측).
03이 이 표를 읽어 **새 set dir**에 넣는다 — 1차 set(돌았거나 도는 중)에는 절대 넣지 않고, 넣으려 하면 멈춘다.

```bash
cd /BiO/scratch/dyl/kbb/G000
python ~/GIAB_benchmarking/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py --dry-run --sampleinfo sampleinfo/sample_information_nbb2.xlsx   # 계획 + 추가될 sampleinfo 행
python ~/GIAB_benchmarking/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py --qsub --sampleinfo sampleinfo/sample_information_nbb2.xlsx \
    --hosts '(octopus-2-8|octopus-2-9|octopus-2-10|octopus-2-11|shepherd-1-8|shepherd-1-9)'           # 링크 + 병합 잡(큰 것부터 8줄, -hold_jid) + sampleinfo 행 추가(백업 후)
```

| tier | set dir | 샘플(label) | 쌍 | GiB | 처리 | 기종 |
|---|---|---|---|---|---|---|
| germline | `GIAB-publicData-NIST-BGIseq-100x` | HG002 · HG005 | 15/15 | 635 | cat | MGI DNBSEQ 2x150 |
| germline | `GIAB-publicData-Element-AVITI-2023` | HG002 | 2 | 269 | cat | AVITI Std+Lng |
| germline | `GIAB-publicData-Hiseq-300x-NA12878` | HG001 | 871 | 758 | cat | HiSeq 2500 2x148 |
| germline | `GIAB-publicData-BGISEQ500-NA12878` | HG001 · HG001-stdlib | 2/2 | 310 | cat | BGISEQ-500 PE100 (PCR-free / standard) |
| germline | `GIAB-publicData-MGISEQ2000-PCRfree-NA12878` | HG001 | 4 | 360 | cat | MGISEQ-2000 2x150, 라이브러리 2 |
| germline | `GIAB-publicData-Element-AVITI-NA12878` | HG001 | 2 | 233 | cat | AVITI Std+Lng |
| germline | `GIAB-publicData-Hiseq-250PE-300x` | HG005 | 168 | 857 | cat | HiSeq 2500 **2x250** |
| germline | `GIAB-publicData-Hiseq-100x` | HG006 · HG007 | 300/306 | 595 | cat | HiSeq 2500 2x148 |
| germline | `GIAB-publicData-BGISEQ500-ChineseTrio` | HG005 · HG006 · HG007 | 2/2/2 | 613 | cat | BGISEQ-500 PE100 |
| germline | `GIAB-publicData-MGISEQ2000-PCRfree-ChineseTrio` | HG005 | 2 | 186 | cat | MGISEQ-2000 2x150 |
| germline | `GIAB-publicData-Element-AVITI-ChineseTrio` | HG005 | 2 | 231 | cat | AVITI Std+Lng |
| somatic | `GIAB-publicData-HG008-Illumina-BCM-2024` | HG008-T · HG008-N-D | 4/1 | 466 | cat·링크 | NovaSeq 6000 2x151 |
| somatic | `GIAB-publicData-HG008-Illumina-NYGC-2023` | HG008-T · HG008-N-D | 12/12 | 392 | cat | NovaSeq 6000 2x150 |
| somatic | `GIAB-publicData-HG008-NovaseqX-bulk` | HG008-N-D · T-p2 · T-p13 · T-p21 · T-p41 · T-p100 | 4/2/2/2/2/4 | 1307 | cat | NovaSeq X 2x151 |
| somatic | `GIAB-publicData-HG008-NovaseqX-clones` | HG008-T-2D6 · 2E6 · 3E4 · SC6 · SC9 · SC14 · SC24 · SC28 | 3~4 | 1499 | cat | NovaSeq X 2x151 |
| somatic | `GIAB-publicData-HG008-Element-AVITI-202406` | HG008-T · N-D · N-P | 2/2/2 | 651 | cat | AVITI Std+Lng |
| somatic | `GIAB-publicData-HG008-Element-AVITI-202412` | HG008-T · N-D · N-P | 1/1/1 | 559 | 링크 | AVITI |
| somatic | `GIAB-publicData-HG008-Onso` | HG008-T · N-D | 1/1 | 353 | 링크 | PacBio Onso(배포처 트리밍) |
| somatic | `GIAB-publicData-HG009-NovaseqX-bulk` | HG009-N-WT-p4 · N-WT-p25 · N-LVTert-p23 · T-p16 · T-p42 | 4씩 | 980 | cat | NovaSeq X 25B |
| somatic | `GIAB-publicData-HG009-NovaseqX-clones` | HG009-T-1C3 · 1D5 · 3C4 · 3C9 · 3F2 · 4G9 | 4 (3C4만 1) | 1124 | cat·링크 | NovaSeq X 25B |

label 앞 `HG008-`는 set 이름에만 줄여 적었다 — 샘플 dir은 전부 `<set>-<label>` 전체다(예: `GIAB-publicData-HG008-NovaseqX-clones-HG008-T-2D6`).
병합 실사본 약 11 TiB(germline 5.0 + somatic 6.0; 1쌍짜리 1.3 TiB는 링크). 성별은 HG008/HG009 모두 female(HG009는 README에 없어 phase1 HiFi BAM idxstats로 측정).

- **이름 규칙**: 1차에 같은 dataset set이 있으면 코호트 접미(`-NA12878` / `-ChineseTrio`), 새 dataset이면 접미 없이, HG008/HG009는 `HG00x-<기종/배치>`
- **somatic tier**는 germline 정답셋이 없어 국통바빅 결과로 채점하지 못한다 — QC·정렬(나중 nf-core somatic의 입력 BAM)까지. 같은 배치 안에 T/N 짝이 있다(BCM-2024, NYGC-2023, Element 두 배치, Onso, HG009 BCM)
- **뺀 것**: mate-pair·Moleculo·10X·stLFR(MGISEQ/stLFR 포함)·Hi-C·Dovetail·Strand-seq·엑솜, BGISEQ500 standard_library의 **PE50**(CL100004823 — fastp `length_required 70`에 전부 걸림), HG008 Element **20240118**(README가 superseded R&D 화학), MissionBio Tapestri(표적 단일세포), superseded-2022-data

## 정답셋 (small variant)

| 샘플 | 벤치마크 | 경로 (`release/AshkenazimTrio/<sample>/`) |
|---|---|---|
| HG002·3·4 | NIST v4.2.1 (= `latest/`) GRCh37·GRCh38 | `NISTv4.2.1/GRCh3?/HG00?_GRCh3?_1_22_v4.2.1_benchmark.vcf.gz` + `_benchmark_noinconsistent.bed` |
| HG002 | CMRG v1.00 (의학 유전자 273개) | `CMRG_v1.00/GRCh3?/` |
| HG002 | **v5.0q** (2026-03, Q100 v1.1 어셈블리 기반, GIAB "draft") | `v5.0q/HG002_GRCh38_v5.0q_smvar.vcf.gz` + `_smvar.benchmark.bed` (stvar = SV). manifest에 2026-09-16 추가, **다운로드 전** |
| HG002 | T2T-Q100 draft smvar (defrabb v0.012/v0.015, 2023-11/2024-02, v5.0q의 전신) | `data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.01?-*/GRCh3?_HG002-T2TQ100-V1.0_smvar.vcf.gz` + `.benchmark.bed` |

stratification: `release/genome-stratifications/v3.6/GRCh3?@all/` (2026-09-16 manifest 추가, 다운로드 전. v5.0q README가 v3.6을 지정; 받기 전까지는 v3.5). 참조: `release/references/GRCh38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fasta.gz`, `release/references/GRCh37/hs37d5.fa.gz`.
