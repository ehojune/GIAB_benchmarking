# Phase 3 — 숏리드 WGS (HG002·HG003·HG004)

대상: 원시 FASTQ가 있는 표준 short-read WGS만. mate-pair·Moleculo·10X·stLFR·Hi-C·Strand-seq·엑솜(BAM only)·
Complete Genomics·SOLiD는 제외 (이유: 일반 germline 파이프라인에 그대로 넣을 수 없음).
파이프라인은 사용자가 지정·실행한다.

- [inputs_manifest.tsv](inputs_manifest.tsv) — 파이프라인 입력 FASTQ 전부. `dsid / relpath / bytes`. **6,178 files / 5.55 TiB**
- [all_files.tsv](all_files.tsv) — 같은 플랫폼 디렉토리의 모든 파일(GIAB BAM·VCF·md5 포함). `dsid / ftype / relpath / bytes`. 6,890 files
- [run_table.tsv](run_table.tsv) — 실행 단위 18개. `units` = read group 수 (플로우셀.레인.라이브러리)
- [samplesheets/<dsid>.csv](samplesheets/) — R1/R2 짝 맞춘 범용 시트 `sample,dataset,unit,fastq_1,fastq_2,bytes`. 재생성: `python scripts/make_samplesheets.py` (`DATA_ROOT=` 로 경로 변경)
- 로컬 절대경로 = `/BiO/scratch/ehojune/GIAB_benchmark/` + `relpath` (nbb2, phase0 DEST)
- 출처: `phase0_download/manifests/` 실측. 다운로드는 2026-08-30 verify.sh all 100%로 확인됨.

## 실행 단위 후보 18개

| dsid | FASTQ | GiB | 비고 |
|---|---|---|---|
| HG002/3/4.HiSeq300x | 1870 / 2010 / 2048 | 774 / 787 / 907 | 2x148, 플로우셀 12/13/12개 × 12 라이브러리(균질성 시험 바이알 ?A1~?L2) × 2레인 × R1/R2 × 분할. 합 300x, 플로우셀당 ~25x. **전량 사용** |
| HG002/3/4.Illumina_2x250 | 68 / 36 / 70 | 163 / 144 / 161 | 플로우셀 1개 ~40-50x, `reads/D?_S1_L00?_R?_00?.fastq.gz` |
| HG002/3/4.BGISEQ500 | 4 / 4 / 4 | 208 / 217 / 210 | PCR-free, L01·L02 |
| HG002/3/4.MGISEQ2000_PCRfree | 4 / 4 / 8 | 186 / 178 / 354 | HG004는 라이브러리 2개(NA24143_1, _2) |
| HG002/3/4.Element_AVITI_20240920 | 4 / 4 / 4 | 236 / 231 / 251 | StdInsert ~80x + LngInsert 32-38x, 라이브러리 2개 |
| HG002.Illumina_PCRfree_30x | 2 | 83 | HiSeq 30x 서브샘플 |
| HG002.NIST_BGIseq_2x150_100x | 30 | 324 | L01-L03 × 바코드 606-610 |
| HG002.Element_AVITI_20231018 | 4 | 269 | StdInsert 81x + LngInsert 55x |

nbb2에서 실존 확인:

```bash
cd /BiO/scratch/ehojune/GIAB_benchmark && awk -F'\t' 'NR>1{print $2}' <repo>/phase3_shortread_wgs/inputs_manifest.tsv | xargs -I{} sh -c 'test -f "{}" || echo MISSING {}'
```

## 정답셋 (small variant)

| 샘플 | 벤치마크 | 경로 (`release/AshkenazimTrio/<sample>/`) |
|---|---|---|
| HG002·3·4 | NIST v4.2.1 (= `latest/`) GRCh37·GRCh38 | `NISTv4.2.1/GRCh3?/HG00?_GRCh3?_1_22_v4.2.1_benchmark.vcf.gz` + `_benchmark_noinconsistent.bed` |
| HG002 | CMRG v1.00 (의학 유전자 273개) | `CMRG_v1.00/GRCh3?/` |
| HG002 | **v5.0q** (2026-03, Q100 v1.1 어셈블리 기반, GIAB "draft") | `v5.0q/HG002_GRCh38_v5.0q_smvar.vcf.gz` + `_smvar.benchmark.bed` (stvar = SV). manifest에 2026-09-16 추가, **다운로드 전** |
| HG002 | T2T-Q100 draft smvar (defrabb v0.012/v0.015, 2023-11/2024-02, v5.0q의 전신) | `data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.01?-*/GRCh3?_HG002-T2TQ100-V1.0_smvar.vcf.gz` + `.benchmark.bed` |

stratification: `release/genome-stratifications/v3.6/GRCh3?@all/` (2026-09-16 manifest 추가, 다운로드 전. v5.0q README가 v3.6을 지정; 받기 전까지는 v3.5). 참조: `release/references/GRCh38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fasta.gz`, `release/references/GRCh37/hs37d5.fa.gz`.
