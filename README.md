# GIAB benchmark data — master catalog

GIAB 9개 샘플(HG001–HG007 germline, HG008·HG009 tumor-normal)의 **전체 데이터 카탈로그와 처리 현황 추적표**.
아래 표가 이 저장소의 중심이다. 어떤 데이터가 어디까지 처리되어 있고, GIAB가 무슨 툴로 했고,
내가 앞으로 무엇을 돌려야 하는지가 한 표에 들어 있다.

| | |
|---|---|
| 데이터 규모 | **330 datasets / 76,595 files / 115.6 TB** (2026-08-13 파일별 HEAD 검증) |
| 다운로드 | [phase0_download/](phase0_download/) — 스크립트, 매니페스트, 속도·용량 계획 |
| 표 원본 | [catalog/master_catalog.tsv](catalog/master_catalog.tsv) — 51개 컬럼. 필드 정의는 [catalog/README.md](catalog/README.md) |
| 정확 바이트 | [docs/SIZES.md](docs/SIZES.md) — 플랫폼 디렉토리 단위 (조회용) |
| 분류 근거 | [docs/reference/catalog_evidence.md](docs/reference/catalog_evidence.md) |

## 표 읽는 법

| 표시 | 뜻 |
|---|---|
| `✓ pbmm2 v1.10.0` | 그 단계 산출물이 있고, GIAB가 그 툴로 만들었음 |
| `✓ N/A` | 산출물은 있지만 GIAB 공식 문서에도 툴이 안 적혀 있음 |
| `✗` | 산출물 없음 → **내가 돌릴 자리** |
| `✓ pbmm2 +2` | 툴이 여럿 (`+2` = 뒤에 2개 더). 전체 목록은 TSV에 |
| `△ 12개` | GIAB가 일부만 처리 (index 컬럼: 12개 파일에 index 없음) |
| `–` | 해당 없음 (reference FASTA에 alignment 같은 경우) |
| `*(나)*` | GIAB가 아니라 내가 처리한 것 |

처리를 돌린 뒤에는 README를 직접 고치지 말고 `catalog/master_catalog.tsv`의 해당 칸을 채운 다음
아래를 실행한다.

```bash
python catalog/build_readme.py
```

<!-- MASTER-TABLE:BEGIN -->
### 요약

전체 **330개 데이터셋 / 76,595 files / 105.1 TiB**. 단계별 도달 데이터셋 수:

| category | 데이터셋 | GiB | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | GIAB 처리물 보유 |
|---|---|---|---|---|---|---|---|---|---|
| PacBio HiFi | 28 | 8,634 | 20 | 20 | 17 | 14 | 4 | 0 | 0 |
| PacBio CLR | 8 | 13,388 | 7 | 3 | 1 | 0 | 0 | 0 | 0 |
| Oxford Nanopore | 18 | 11,854 | 17 | 9 | 1 | 5 | 4 | 2 | 17 |
| Illumina WGS | 28 | 21,689 | 23 | 0 | 8 | 0 | 0 | 0 | 24 |
| BGI / MGI | 14 | 5,302 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| Exome | 11 | 977 | 11 | 0 | 2 | 0 | 0 | 0 | 0 |
| Linked reads (10X, stLFR) | 18 | 5,038 | 13 | 6 | 3 | 0 | 0 | 0 | 13 |
| Complete Genomics | 11 | 14,880 | 9 | 0 | 9 | 0 | 0 | 0 | 10 |
| 기타 기술 (BioNano, Hi-C, AVITI, UG100, Strand-seq 등) | 107 | 18,830 | 36 | 13 | 29 | 3 | 27 | 11 | 0 |
| Release — truth set / stratification / reference | 58 | 285 | 20 | 13 | 47 | 0 | 2 | 8 | 55 |
| RNA-seq | 20 | 6,700 | 9 | 0 | 0 | 0 | 0 | 0 | 11 |
| Trio-level analysis | 9 | 59 | 4 | 1 | 7 | 1 | 0 | 0 | 9 |

<details>
<summary><b>PacBio HiFi</b> — 28 datasets, 8,634 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| HiFi CCS (HudsonAlpha) | HG001 | Sequel II (m64109) | 66 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ를 pbmm2 --preset CCS(HiFi)로 GRCh38-GIABv3에 정렬 후 Deep… |
| HiFi SequelII 11kb | HG001 | Sequel II | 110 | ✗ | ✓ | ✓ pbmm2 align | ✓ WhatsHap 0.17 haplotag | ✓ pbsv v2.2.1 | – | – | ✗ | 문서 | 원본 HiFi 리드가 이 디렉토리에 없어 재정렬은 SRA(PRJNA540705) 다운로드가 선행돼야 함… |
| HiFi chemistry2 | HG001 | Sequel II (m64109) | 210 | ✓ hifi_reads/uBAM | △ 6개 | ✓ pbmm2 v1.1.0 | ✓ N/A | ✓ GATK 4.0.10.1 HaplotypeCaller +1 | ✓ N/A | – | ✗ | 문서 | uBAM(염기수식 태그 포함)을 pbmm2 --preset HIFI로 GRCh38-GIABv3에 재정렬… |
| HiFi CCS 10kb | HG002 | Sequel | 282 | ✓ FASTQ | ✓ | ✓ pbmm2 align +1 | ✓ WhatsHap 0.17 haplotag | ✗ | – | – | ✗ | 문서 | 39개 FASTQ를 병합해 pbmm2 --preset HIFI로 GRCh38-GIABv3 재정렬 → D… |
| HiFi CCS 15kb | HG002 | Sequel | 292 | ✓ FASTQ | ✓ | ✓ pbmm2 align +1 | ✓ WhatsHap 0.17 haplotag | ✗ | – | – | ✗ | 문서 | 39개 FASTQ 병합 후 pbmm2 --preset HIFI로 GRCh38-GIABv3 재정렬 → D… |
| HiFi Revio 20231031 | HG002 | Revio (m84039) | 287 | ✓ hifi_reads/uBAM | △ 2개 | ✓ pbmm2 v1.10.0 | ✓ HiPhase | ✓ DeepVariant +2 | ✓ pb-CpG-tools | – | ✗ | 문서 | uBAM을 그대로 HiFi-human-WGS-WDL(또는 pbmm2 → DeepVariant → HiP… |
| HiFi SequelII 11kb | HG002 | Sequel II | 209 | ✓ FASTQ | ✓ | ✓ pbmm2 align | ✓ WhatsHap 0.17 haplotag | ✗ | – | – | ✗ | 문서 | 6개 FASTQ를 pbmm2 --preset HIFI로 GRCh38-GIABv3 재정렬 → DeepVa… |
| HiFi chemistry2 | HG002 | Sequel II | 573 | ✓ FASTQ | ✓ | ✓ pbmm2 align +1 | ✓ whatshap haplotag, 버전 미기재 | ✓ GATK 4.0.10.1 HaplotypeCaller… +1 | – | – | ✗ | 문서 | 6개 FASTQ를 pbmm2 --preset HIFI로 GRCh38-GIABv3 재정렬 → DeepVa… |
| HiFi CCS (Google) | HG003 | Sequel II | 45 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | 3개 FASTQ를 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 후 DeepVar… |
| HiFi CCS (HudsonAlpha) | HG003 | Sequel II (m64017) | 191 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | 파일명 | 중복 FASTQ 하나만 골라 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 후 변… |
| HiFi Revio 20231031 | HG003 | Revio (m84039) | 276 | ✓ hifi_reads/uBAM | △ 2개 | ✓ pbmm2 v1.10.0 | ✓ HiPhase | ✓ DeepVariant +2 | ✓ pb-CpG-tools | – | ✗ | 문서 | uBAM을 HiFi-human-WGS-WDL(또는 pbmm2 → DeepVariant → HiPhase… |
| HiFi chemistry2 | HG003 | Sequel II (m64017) | 658 | ✓ hifi_reads/uBAM | △ 6개 | ✓ pbmm2 | ✓ whatshap haplotag \| GIAB_5mC… +1 | ✓ DeepVariant v0.9.0 + GATK MAP… | ✓ ccs v6.2.0 +1 | – | ✗ | 문서 | uBAM을 입력으로 ccs/primrose 대신 최신 pbmm2 + DeepVariant + HiPha… |
| HiFi CCS (Google) | HG004 | Sequel II (m64017) | 43 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | 3개 FASTQ를 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 후 DeepVar… |
| HiFi CCS (HudsonAlpha) | HG004 | Sequel II (m64017) | 196 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | 중복 FASTQ 하나만 골라 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 후 변… |
| HiFi Revio 20231031 | HG004 | Revio (m84039) | 208 | ✓ hifi_reads/uBAM | △ 2개 | ✓ pbmm2 v1.10.0 | ✓ HiPhase | ✓ DeepVariant +2 | ✓ pb-CpG-tools | – | ✗ | 문서 | uBAM을 HiFi-human-WGS-WDL 또는 pbmm2 → DeepVariant → HiPhase… |
| HiFi chemistry2 | HG004 | Sequel II (m64017) | 577 | ✓ hifi_reads/uBAM | △ 6개 | ✓ pbmm2 | ✓ whatshap haplotag, 버전 미기재 | ✓ DeepVariant v0.9.0 + GATK MAP… | ✓ N/A | – | ✗ | 문서 | uBAM을 pbmm2 --preset HIFI로 GRCh38-GIABv3 재정렬 → DeepVarian… |
| HiFi CCS (HudsonAlpha) | HG005 | Sequel II (m64109, m64017) | 119 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ를 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 후 DeepVarian… |
| HiFi SequelII 11kb | HG005 | Sequel II | 123 | ✗ | ✓ | ✓ pbmm2 align | ✓ WhatsHap 0.17 haplotag | ✓ pbsv v2.2.1 | – | – | ✗ | 문서 | 이 디렉토리에 리드가 없어 재정렬은 SRA(PRJNA540706) 확보가 선행돼야 함. 당장은 hapl… |
| HiFi chemistry2 | HG005 | Sequel II (m64109, m64017) | 369 | ✓ hifi_reads/uBAM | △ 7개 | ✓ N/A | ✓ N/A | ✓ DeepVariant | ✓ N/A | – | ✗ | 파일명 | uBAM을 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 → DeepVariant… |
| HiFi (Google) | HG006 | Sequel II | 56 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | 3개 FASTQ를 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 후 DeepVar… |
| HiFi chemistry2 | HG006 | Sequel II (m64017, m64109) | 386 | ✓ hifi_reads/uBAM | △ 6개 | ✓ N/A | ✓ N/A | ✓ DeepVariant | ✓ N/A | – | ✗ | 문서 | uBAM을 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 → DeepVariant… |
| HiFi (Google) | HG007 | Sequel II (m64062) | 44 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | 3개 FASTQ를 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 후 DeepVar… |
| HiFi chemistry2 | HG007 | Sequel II (m64017) | 380 | ✓ hifi_reads/uBAM | △ 6개 | ✓ N/A | ✓ N/A | ✓ DeepVariant | ✓ N/A | – | ✗ | 문서 | uBAM을 pbmm2 --preset HIFI로 GRCh38-GIABv3 정렬 → DeepVariant… |
| HiFi Revio (BCM) 20240313 | HG008 | Revio (m84059, m84101) | 757 | ✓ hifi_reads | ✓ | ✓ pbmm2 v1.12.0 | ✓ HiPhase | ✓ Clair3 | ✓ pb-CpG-tools +1 | ✓ Severus — PacBio Somatic Pipe… | ✗ | 문서 | T/N uBAM 쌍을 HiFi-Somatic-WDL(또는 pbmm2 → Clair3 → HiPhase… |
| HiFi Revio 20240125 | HG008 | Revio (m84039) | 637 | ✓ hifi_reads/uBAM | △ 3개 | ✓ pbmm2 v1.10.0 | ✓ HiPhase | ✓ DeepVariant +2 | ✓ pb-CpG-tools | ✗ | ✗ | 문서 | HG008-T와 HG008-N-P(췌장 정상조직) uBAM 쌍으로 소마틱 파이프라인(DeepSomati… |
| N bulk HiFi Revio + somatic | HG009 | Revio (m84059) | 428 | ✓ uBAM/BAM | ✓ | ✓ pbmm2 v1.17.0 | ✓ HiPhase v1.5.0 | ✓ Clair3 | ✓ pb-CpG-tools v2.3.1 +2 | ✓ DeepSomatic v1.9.0 +4 | ✗ | 문서 | HiFi-somatic-WDL v0.9.4를 그대로 재현하려면 demux uBAM + WT-p4를 정상… |
| T bulk HiFi Revio + somatic | HG009 | Revio (m84059, m84113) | 335 | ✓ uBAM/BAM | ✓ | ✓ pbmm2 v1.17.0 | ✓ HiPhase v1.5.0 | ✓ Clair3 | ✓ pb-CpG-tools v2.3.1 +2 | ✓ DeepSomatic v1.9.0 +4 | ✗ | 문서 | HG009-N_bulk/20250728p4(WT-p4)를 정상으로 지정해 HiFi-somatic-WDL… |
| T 단일세포 클론 6종 HiFi Revio + somatic | HG009 | Revio (m84059, m84113) | 779 | ✓ uBAM/BAM | ✓ | ✓ pbmm2 v1.17.0 | ✓ HiPhase v1.5.0 | ✓ Clair3 | ✓ pb-CpG-tools v2.3.1 +2 | ✓ DeepSomatic v1.9.0 +4 | ✗ | 문서 | 단일세포 클론 6종을 WT-p4 정상 대조로 HiFi-somatic-WDL v0.9.4 재현 → 클론… |

</details>

<details>
<summary><b>PacBio CLR</b> — 8 datasets, 13,388 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| PacBio CLR (MtSinai) | HG001 | 미표기 | 211 | ✓ FASTA/bax.h5 | ✓ | ✓ blasr v1.3.2 | ✗ | ✓ PBHoney \| custom pipeline \|… | – | – | ✗ | 문서 | 원시 subread가 없어 베이스콜부터의 재현은 불가. EC FASTA를 GRCh38에 재정렬해 비교하… |
| PacBio CLR (MtSinai/NIST) | HG002 | RS II (m14·m15 movie) | 3,292 | ✓ subreads/fastq | ✓ | ✓ ngmlr v0.2.3 \| pbsv fasta v2… +2 | ✓ whatshap haplotype-partition | ✗ | – | – | ✗ | 문서 | PacBio_fasta의 subreads.fasta.gz를 pbmm2/minimap2로 GRCh38-G… |
| PacBio CLR (WUSTL+PB) | HG002 | Sequel II (m64070, m64043) | 1,210 | ✓ subreads/scraps | ✓ | ✗ | – | ✗ | – | – | ✗ | filename | giab_doc:data/AshkenazimTrio/HG002_NA24385_son/PacBio_CLR/PacBio_CLR_HG002_README.txt | giab_doc:data/AshkenazimTrio/HG002_NA24385_son/PacBio_CLR/WUSTL_PacBio_CLR.README.txt | subreads.bam을 pbmm2 --preset SUBREAD 또는 minimap2 -x map-p… |
| PacBio CLR (MtSinai/NIST) | HG003 | RS II (m14·m15 movie) | 2,686 | ✓ subreads/fasta | △ 1개 | ✓ bwa mem v0.7.12-r1039 \| pbsv… +2 | ✓ N/A | ✗ | – | – | ✗ | 문서 | PacBio_fasta subreads.fasta.gz로 GRCh38-GIABv3 재정렬하거나 mini… |
| PacBio CLR (MtSinai/NIST) | HG004 | RS II (m14·m15 movie) | 2,550 | ✓ subreads/fasta | △ 1개 | ✓ bwa mem v0.7.12-r1039 \| pbsv… +2 | ✓ N/A | ✗ | – | – | ✗ | 문서 | PacBio_fasta subreads.fasta.gz로 GRCh38-GIABv3 재정렬 또는 mini… |
| PacBio CLR (MtSinai) | HG005 | Sequel (m54015, m54016) | 1,731 | ✓ subreads/scraps | ✓ | ✓ pbsv fasta v2.0.0 +2 | ✗ | ✗ | – | – | ✗ | 문서 | raw_data tarball 해제 후 subreads.bam을 pbmm2 --preset SUBREA… |
| PacBio CLR (MtSinai) | HG006 | Sequel (m54015, m54016) | 861 | ✓ subreads/fasta | ✓ | ✓ pbsv fasta v2.0.0 +2 | ✗ | ✗ | – | – | ✗ | 문서 | raw_data tarball 해제 후 subreads.bam을 GRCh38-GIABv3에 재정렬, 또… |
| PacBio CLR (MtSinai) | HG007 | Sequel (m54015, m54016) | 849 | ✓ subreads/fasta | ✓ | ✓ pbsv fasta v2.0.0 +2 | ✗ | ✗ | – | – | ✗ | 문서 | raw_data tarball 해제 후 subreads.bam을 GRCh38-GIABv3에 재정렬, 또… |

</details>

<details>
<summary><b>Oxford Nanopore</b> — 18 datasets, 11,854 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ONT ultralong (MinION UL, GRCh37/38 BAM) | HG001 | MinION ultralong | 329 | ✗ | ✓ | ✓ minimap2 | ✓ whatshap haplotag | ✗ | – | – | ✗ | 문서 | GRCh37/38 haplotag BAM을 ONT 벤치마킹 입력으로 바로 사용. 재정렬은 이 디렉토리에… |
| Cornell ONT 2D (fast5 원시 2912개 + 2D 리드) | HG002 | ONT 2D 케미스트리 | 6 | ✓ fastq/fasta | – | ✗ | – | ✗ | – | – | ✗ | 문서 | 포어 버전 언급을 빼고 '2D fast5 2912개로 재베이스콜(포어/케미스트리 버전은 문서 미기재,… |
| ONT-UL Guppy 2.3.4 (2019-06-26) | HG002 | ONT ultralong | 627 | ✓ fastq | ✓ | ✓ minimap2 | ✓ whatshap haplotag | ✗ | – | – | ✗ | 문서 | 오라벨 3개 플로우셀 리드를 먼저 제외할 것. hs37d5 phased BAM은 그대로 사용 가능하고,… |
| ONT-UL Guppy 3.2.4 (2020-01-22, phased) | HG002 | ONT ultralong | 571 | ✓ fastq | ✓ | ✓ minimap2 | ✓ whatshap haplotag | ✗ | – | – | ✗ | 문서 | GRCh37/38 phased BAM 그대로 사용. 정렬을 다시 하려면 같은 디렉토리의 guppy 3.… |
| ONT-UL Guppy 3.4.5 (align only) | HG002 | ONT ultralong | 545 | ✓ fastq | ✓ | ✓ minimap2 | ✗ | ✗ | – | – | ✗ | 문서 | 최신 guppy(3.4.5) 정렬본이므로 정렬은 그대로 쓰고, 페이징(whatshap haplotag… |
| ONT-UL combined 2018-05-18 (rel1) | HG002 | ONT ultralong | 44 | ✓ fastq | ✓ | ✓ minimap2 | ✗ | ✗ | – | – | ✗ | 문서 | 6x·구버전 베이스콜이라 신규 분석에는 부적합. 같은 리드의 최신 베이스콜인 guppy-V3.4.5 릴… |
| ONT-UL combined 2018-08-10 (rel2, raw fast5 tar 포함) | HG002 | ONT ultralong | 937 | ✓ fastq/fast5 | ✓ | ✓ minimap2 | ✓ whatshap haplotag | ✗ | – | – | ✗ | 문서 | raw_fast5s.1~10.tar로 dorado R9 legacy 재베이스콜 → 재정렬하는 실험이 가… |
| UCSC ONT-UL PromethION (20200508, phased) | HG002 | PromethION ultralong | 511 | ✓ fastq | ✓ | ✓ minimap2 | ✓ whatshap haplotag | ✗ | – | – | ✗ | 문서 | phased BAM 그대로 사용하거나 GM24385_1~3.fastq.gz로 최신 minimap2 재정… |
| UCSC ONT-UL PromethION (20200508) | HG003 | PromethION ultralong | 896 | ✓ fastq | ✓ | ✓ minimap2 | ✗ | ✗ | – | – | ✗ | 문서 | 정렬본은 그대로 사용. 페이징이 필요하면 트리오/10x phased VCF로 whatshap haplo… |
| UCSC ONT-UL PromethION (20200508) | HG004 | PromethION ultralong | 917 | ✓ fastq | ✓ | ✓ minimap2 | ✗ | ✗ | – | – | ✗ | 문서 | 정렬본 그대로 사용. 페이징은 사용자가 whatshap haplotag / longphase로 추가할… |
| UCSC ONT-UL PromethION R9.4.1 Guppy 4.2.2 (phased) | HG005 | PromethION ultralong, R9.… | 527 | ✓ fastq | ✓ | ✓ minimap2 | ✓ whatshap haplotag | ✗ | – | – | ✗ | 문서 | phased BAM 그대로 사용. 재베이스콜/재정렬을 원하면 human-pangenomics S3의 f… |
| UCSC ONT-UL PromethION R9.4.1 Guppy 4.2.2 (phased) | HG006 | PromethION ultralong, R9.… | 470 | ✓ fastq | ✓ | ✓ minimap2 | ✓ whatshap haplotag | ✗ | – | – | ✗ | 문서 | phased BAM 그대로 사용. 재정렬은 fastq.gz 3개로 가능, 재베이스콜은 외부 S3 fas… |
| UCSC ONT-UL PromethION R9.4.1 Guppy 4.2.2 (phased) | HG007 | PromethION ultralong, R9.… | 382 | ✓ fastq | ✓ | ✓ minimap2 | ✓ whatshap haplotag | ✗ | – | – | ✗ | 문서 | phased BAM 그대로 사용. 재정렬은 fastq.gz 3개로 가능 |
| N (십이지장/췌장) Northeastern ONT-std R10.4.1 dorado 0.5.3 | HG008 | ONT R10.4.1 standard | 2,754 | ✓ fastq/BAM | △ 7개 | ✓ minimap2 2.26-r1175 +1 | ✗ | ✗ | ✓ dorado v0.5.3 +1 | ✓ Severus v1.0 +4 | ✓ hifiasm v0.19.9-r616 | 툴 값은 유지하되 tool_source에 giab_doc:data_somatic/HG008/Liss_lab/other_passages/analysis/GRCh38/BCM_ONT-std_HG008T-p2_20260313/HG008-T_vs_HG008-N-P/README_HG008-T_vs_HG008-N-P_ONT.md 를 추가해야 함 | HG008 정상 대조(BAM/gt25kb BAM)로 그대로 사용. 재현하려면 ubam 7개 → mini… |
| T Northeastern ONT-UL R10.4.1 dorado 0.8.1 (54x) | HG008 | ONT R10.4.1 ultralong | 537 | ✓ BAM/pod5 | △ 1개 | ✓ minimap2 2.26-r1175 +1 | ✗ | ✗ | ✓ dorado v0.8.1 | ✗ | ✗ | 문서 | unaligned BAM으로 modkit 파일업(메틸)이나 HG008-N 대비 소마틱 SV/SNV 호출… |
| T UCSC ONT-UL R10.4.1 dorado 0.4.3 (54x, 5mCG-5hmCG) | HG008 | ONT R10.4.1 ultralong | 437 | ✓ BAM/pod5 | △ 3개 | ✓ minimap2 2.26-r1175 +1 | ✗ | ✗ | ✓ dorado v0.4.3 | ✓ Sniffles v2.2 | ✓ hifiasm v0.19.9-r616 +1 | 문서 | GIAB 정렬본으로 SV/소마틱 결과 재현·비교에 사용. 새로 할 일은 modkit 메틸 파일업과 lo… |
| T UCSC ONT-std R10.4.1 dorado 0.3.4 (63x, 5mCG-5hmC) | HG008 | ONT R10.4.1 standard | 510 | ✓ BAM | △ 1개 | ✓ minimap2 2.26-r1175 | ✗ | ✗ | ✓ dorado v0.3.4 | ✓ Sniffles v2.2; Severus v1.0 +4 | ✗ | 문서 | GIAB 정렬본으로 소마틱 SV 앙상블 재현·비교. 추가로 할 일은 modkit 메틸 파일업과 페이징 |
| HG008T-p2 BCM ONT-std 100X (플로우셀 2개, ubam 1090) | HG008 | ONT | 853 | ✓ BAM | △ 1090개 | ✓ minimap2 | ✓ longphase | ✓ Clair3 | ✓ dorado +1 | ✓ ClairS + Severus | ✗ | 문서 | 정렬·haplotag·소마틱·메틸까지 끝난 GIAB 산출물 그대로 사용. 재현하려면 pass ubam… |

</details>

<details>
<summary><b>Illumina WGS</b> — 28 datasets, 21,689 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| NIST HiSeq 300x | HG001 | Illumina HiSeq | 2,003 | ✓ FASTQ | ✓ | ✓ novoalign 3.02.07 +1 | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ 1742개로 자체 정렬(BWA-MEM/DRAGEN 등)+변이 검출을 돌려 novoalign… |
| 6kb mate-pair | HG002 | Illumina 6kb mate-pair | 187 | ✓ FASTQ | △ 1개 | ✓ bwa mem +1 | ✗ | ✗ | – | – | ✗ | 문서 | 물리적 커버리지가 높아 대형 SV/전좌 검출 검증용. FASTQ 4개로 어댑터 제거 후 재정렬해 중복… |
| HiSeq 300x Homogeneity | HG002 | Illumina HiSeq | 2,346 | ✓ FASTQ | △ 5개 | ✓ novoalign 3.02.07 +1 | ✗ | ✓ BaseSpace BWA Whole Genome Se… | – | – | ✗ | 문서 | FASTQ 1870개로 자체 정렬+변이 검출 실행 후 novoalign 300x/60x BAM 및 HG… |
| Illumina 2x250bp | HG002 | Illumina 2x250bp (기종 미표기) | 443 | ✓ FASTQ | ✓ | ✓ novoalign 3.02.07 +1 | ✗ | ✗ | – | – | ✗ | 문서 | 2x250 오버랩 리드로 어셈블리(DISCOVAR 등) 또는 긴 리드 정렬 벤치마크 재현. novoal… |
| Moleculo 합성 롱리드 | HG002 | Illumina Moleculo | 121 | ✓ FASTQ | ✓ | ✓ bwa-mem | ✗ | ✗ | – | – | ✗ | 문서 | 웰별 BAM 병합 후 read-cloud 기반 haplotype/SV 분석. 또는 FASTQ 6144개… |
| PCR-free 30x 서브샘플 FASTQ | HG002 | Illumina HiSeq | 83 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | 30x FASTQ로 정렬~변이 검출 전 과정 실행. 1KG 30x 수준 저커버리지 벤치마크 기준선으로… |
| 6kb mate-pair | HG003 | Illumina 6kb mate-pair | 179 | ✓ FASTQ | △ 1개 | ✓ bwa mem +1 | ✗ | ✗ | – | – | ✗ | 문서 | 대형 SV/전좌 검증용. FASTQ 4개로 어댑터 제거+재정렬해 중복 포함 BAM 확보 |
| HiSeq 300x Homogeneity | HG003 | Illumina HiSeq | 2,348 | ✓ FASTQ | △ 6개 | ✓ novoalign 3.02.07 +1 | ✗ | ✓ BaseSpace BWA Whole Genome Se… | – | – | ✗ | 문서 | FASTQ 2010개로 자체 정렬+변이 검출 실행. AJ trio 삼자 일치성 검증에 HG002/HG0… |
| Illumina 2x250bp | HG003 | Illumina 2x250bp (기종 미표기) | 490 | ✓ FASTQ | △ 3개 | ✓ novoalign 3.02.07 +1 | ✗ | ✓ N/A | – | – | ✗ | 문서 | 2x250 리드로 어셈블리 또는 긴 리드 정렬 벤치마크. novoalign BAM과 자체 정렬 결과 비교 |
| Moleculo 합성 롱리드 | HG003 | Illumina Moleculo | 123 | ✓ FASTQ | ✓ | ✓ bwa-mem | ✗ | ✗ | – | – | ✗ | 문서 | 웰별 BAM 1536개 병합 후 read-cloud 분석. FASTQ 6144개로 재처리도 가능 |
| 6kb mate-pair | HG004 | Illumina 6kb mate-pair | 188 | ✓ FASTQ | △ 1개 | ✓ bwa mem +1 | ✗ | ✗ | – | – | ✗ | 문서 | 대형 SV 검증용. FASTQ로 어댑터 제거+재정렬해 중복 포함 BAM 확보 |
| HiSeq 300x Homogeneity | HG004 | Illumina HiSeq | 2,686 | ✓ FASTQ | △ 6개 | ✓ novoalign 3.02.07 +1 | ✗ | ✓ BaseSpace BWA Whole Genome Se… | – | – | ✗ | 문서 | FASTQ 2048개로 자체 정렬+변이 검출 실행. HG002/HG003과 묶어 AJ trio 멘델 일… |
| Illumina 2x250bp | HG004 | Illumina 2x250bp (기종 미표기) | 542 | ✓ FASTQ | △ 3개 | ✓ novoalign 3.02.07 +1 | ✗ | ✓ N/A | – | – | ✗ | 문서 | 2x250 리드로 어셈블리 또는 긴 리드 정렬 벤치마크. novoalign BAM과 비교 |
| Moleculo 합성 롱리드 | HG004 | Illumina Moleculo | 72 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | N/A | 바코드별 FASTQ 6144개를 웰 단위로 정렬(bwa-mem 등)해야 함. GIAB BAM이 없으니… |
| 6kb mate-pair | HG005 | Illumina 6kb mate-pair | 185 | ✓ FASTQ | △ 1개 | ✓ bwa mem +1 | ✗ | ✗ | – | – | ✗ | 문서 | 대형 SV 검증용. FASTQ로 어댑터 제거+재정렬해 중복 포함 BAM 확보 |
| HiSeq 300x | HG005 | Illumina HiSeq, 2x250bp 리드 | 3,048 | ✓ FASTQ | △ 24개 | ✓ novoalign +1 | ✗ | ✓ Isaac Whole Genome Sequencing… | – | – | ✗ | 문서 | FASTQ 336개로 자체 정렬+변이 검출 실행. novoalign 300x BAM과 Isaac 45x… |
| Moleculo 합성 롱리드 | HG005 | Illumina Moleculo | 67 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | N/A | 바코드별 FASTQ를 웰 단위로 정렬해야 함. GIAB 정렬 산출물이 없어 전 과정을 사용자가 수행 |
| 6kb mate-pair | HG006 | Illumina 6kb mate-pair | 196 | ✓ FASTQ | △ 1개 | ✓ bwa mem +1 | ✗ | ✗ | – | – | ✗ | 문서 | 대형 SV 검증용. FASTQ로 어댑터 제거+재정렬 |
| HiSeq 100x | HG006 | Illumina HiSeq | 981 | ✓ FASTQ | △ 3개 | ✓ novoalign +1 | ✗ | ✓ Isaac Whole Genome Sequencing… | – | – | ✗ | 문서 | FASTQ 600개로 자체 정렬+변이 검출 실행. HG005/HG007과 함께 Chinese trio… |
| Moleculo 합성 롱리드 | HG006 | Illumina Moleculo | 66 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | N/A | 바코드별 FASTQ를 웰 단위로 정렬해야 함. GIAB 산출물 없어 전 과정 사용자 수행 |
| 6kb mate-pair | HG007 | Illumina 6kb mate-pair | 187 | ✓ FASTQ | △ 1개 | ✓ bwa mem +1 | ✗ | ✗ | – | – | ✗ | 문서 | 대형 SV 검증용. FASTQ로 어댑터 제거+재정렬 |
| HiSeq 100x | HG007 | Illumina HiSeq | 1,016 | ✓ FASTQ | △ 3개 | ✓ novoalign +1 | ✗ | ✓ Isaac Whole Genome Sequencing… | – | – | ✗ | 문서 | FASTQ 612개로 자체 정렬+변이 검출 실행. HG005/HG006과 함께 Chinese trio… |
| Moleculo 합성 롱리드 | HG007 | Illumina Moleculo | 68 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | N/A | 바코드별 FASTQ를 웰 단위로 정렬해야 함. GIAB 산출물 없어 전 과정 사용자 수행 |
| BCM ILMN-WGS 2025 (정상) | HG008 | Illumina WGS (기종 미표기) | 560 | ✓ FASTQ | ✓ | ✓ Dragen v4.3.6 germline pipeli… | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ 8개로 자체 정렬+생식세포 변이 검출 실행해 Dragen CRAM과 비교. HG008-T와… |
| BCM Illumina WGS (T/N) | HG008 | Illumina WGS (기종 미표기) | 1,381 | ✓ FASTQ | ✓ | ✓ BWA-MEM 0.7.17-r1188 +2 | ✗ | ✗ | – | ✗ | ✗ | 문서 | T/N FASTQ 쌍으로 somatic 파이프라인(Mutect2/Strelka2/DeepSomatic… |
| NYGC Illumina WGS (T/N) | HG008 | Illumina WGS (기종 미표기) | 1,730 | ✓ FASTQ | ✓ | ✓ BWA-MEM v0.7.15 +4 | ✗ | ✗ | – | ✗ | ✗ | 문서 | T/N FASTQ 48개로 somatic 파이프라인 실행. 정렬 비교는 NYGC BAM, 콜 비교는 a… |
| T passage 13 BCM ILMN | HG008 | Illumina WGS (기종 미표기) | 174 | ✓ FASTQ | ✓ | ✓ Dragen | ✗ | ✗ | – | ✗ | ✗ | 문서 | 계대 2/13 비교로 배양 중 체세포 변이 축적 추적. HG008-N-D 정상 데이터를 짝지어 soma… |
| T passage 2 BCM ILMN | HG008 | Illumina WGS (기종 미표기) | 220 | ✓ FASTQ | ✓ | ✓ Dragen | ✗ | ✗ | – | ✗ | ✗ | 문서 | 계대 2 vs 13 vs 23 비교로 체세포 변이 축적·클론 진화 분석. somatic 콜에는 HG00… |

</details>

<details>
<summary><b>BGI / MGI</b> — 14 datasets, 5,302 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| BGISEQ500 WGS | HG001 | BGISEQ500 | 654 | ✓ fastq | ✗ 2개 | ✓ N/A | ✗ | ✗ | – | – | – | 문서 | PCR-free fq.gz 4개로 정렬→변이 호출을 직접 실행. 기존 PE50/PE100 BAM은 hg… |
| MGISEQ2000 PCR-free WGS | HG001 | MGISEQ2000 | 360 | ✓ fq.gz 8개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 8개(라이브러리 2개 x 레인 2개)를 직접 정렬→변이 호출. 처리 전 단계라 전 구간이 사… |
| BGISEQ500 WGS | HG002 | BGISEQ500 (PCR-free) | 208 | ✓ fq.gz 4개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 4개로 정렬→변이 호출을 직접 실행. GIAB BAM/VCF 없음. |
| MGISEQ2000 PCR-free WGS | HG002 | MGISEQ2000 | 186 | ✓ fq.gz 4개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 4개로 정렬→변이 호출 직접 실행. HG003/HG004와 같은 플로우셀(V100002807… |
| NIST BGISEQ 2x150 100x | HG002 | BGISEQ 2x150bp | 1,104 | ✓ fq.gz 30개 | ✓ | ✓ bwa +1 | ✗ | ✗ | – | – | – | 문서 | GRCh38 BAM으로 바로 변이 호출해 v4.2.1 벤치마크와 비교. 파이프라인을 바꿔 볼 땐 rea… |
| BGISEQ500 WGS | HG003 | BGISEQ500 (PCR-free) | 217 | ✓ fq.gz 4개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 4개로 정렬→변이 호출 직접 실행. 트리오(HG002/003/004) 동시 처리해 멘델 오류… |
| MGISEQ2000 PCR-free WGS | HG003 | MGISEQ2000 | 178 | ✓ fq.gz 4개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 4개로 정렬→변이 호출 직접 실행. HG002와 같은 플로우셀 V100002807. |
| BGISEQ500 WGS | HG004 | BGISEQ500 (PCR-free) | 210 | ✓ fq.gz 4개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 4개로 정렬→변이 호출 직접 실행. |
| MGISEQ2000 PCR-free WGS | HG004 | MGISEQ2000 | 354 | ✓ fq.gz 8개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | 라이브러리 2개를 따로 정렬한 뒤 합칠지 결정하고 변이 호출. 사용자 몫. |
| BGISEQ500 WGS | HG005 | BGISEQ500 (PCR-free) | 212 | ✓ fq.gz 4개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 4개로 정렬→변이 호출 직접 실행. |
| MGISEQ2000 PCR-free WGS | HG005 | MGISEQ2000 | 186 | ✓ fq.gz 4개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 4개로 정렬→변이 호출 직접 실행. |
| NIST BGISEQ 2x150 100x | HG005 | BGISEQ 2x150bp | 1,031 | ✓ fq.gz 30개 | ✓ | ✓ bwa +1 | ✗ | ✗ | – | – | – | 문서 | GRCh38 BAM으로 변이 호출해 HG005 벤치마크와 비교. 파이프라인 교체 실험은 reads/ f… |
| BGISEQ500 WGS | HG006 | BGISEQ500 (PCR-free) | 192 | ✓ fq.gz 4개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 4개로 정렬→변이 호출 직접 실행. HG005 트리오 부모 쪽 상속 검증용. |
| BGISEQ500 WGS | HG007 | BGISEQ500 (PCR-free) | 209 | ✓ fq.gz 4개 | – | ✗ | ✗ | ✗ | – | – | – | N/A | fq.gz 4개로 정렬→변이 호출 직접 실행. |

</details>

<details>
<summary><b>Exome</b> — 11 datasets, 977 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Garvan HiSeq Exome | HG001 | Illumina HiSeq | 39 | ✓ fastq | △ 1개 | ✓ trimgalore +2 | ✗ | ✓ GATK HaplotypeCaller | – | – | – | 문서 | hg19 + bwa backtrack 기반 옛 산출물이라, GRCh38 v4.2.1 벤치마크와 비교하려… |
| Ion Torrent Exome | HG001 | Ion Torrent | 65 | ✓ fastq/BAM | ✓ | ✓ TMap | ✗ | ✗ | – | – | – | 문서 | flow·ZM 태그가 필요한 Ion 데이터라 일반 정렬기로 재처리하지 말고 TVC 계열로 변이 호출.… |
| Nebraska TruSeq Exome | HG001 | 장비 미표기, TruSeq Exome 캡처 | 19 | ✗ | △ 8개 | ✓ N/A | ✗ | ✓ freebayes + gatk + gatk-haplo… +1 | – | – | – | 파일명 | 원시 리드가 없어 재정렬 불가. ready.bam 2개로 변이 재호출만 가능. VCF 8개는 bgzip… |
| Ion Torrent Exome | HG002 | Ion Torrent | 215 | ✗ | ✓ | ✓ Torrent Suite v4.2 | ✗ | ✗ | – | – | – | 문서 | 원시 fastq가 없고 flow 신호 기반이라 재정렬 대신 TVC 계열로 변이 호출. 런 4개를 합칠지… |
| Oslo Exome (KIT-Av5) | HG002 | 장비 미표기 | 10 | ✗ | ✓ | ✓ N/A | ✗ | ✗ | – | – | – | N/A | 원시 리드가 없어 재정렬 불가. 먼저 BAM 헤더(@PG, @SQ)로 정렬 툴과 참조 게놈을 확인하고,… |
| Ion Torrent Exome | HG003 | Ion Torrent | 190 | ✗ | ✓ | ✓ Torrent Suite v4.2 | ✗ | ✗ | – | – | – | 문서 | 원시 fastq 없음 → 재정렬 불가. TVC 계열로 변이 호출해 트리오 엑솜 비교에 사용. |
| Oslo Exome (KIT-Av5) | HG003 | 장비 미표기 | 8 | ✗ | ✓ | ✓ N/A | ✗ | ✗ | – | – | – | N/A | 원시 리드가 없어 재정렬 불가. BAM 헤더로 정렬 툴·참조 확인 후 트리오 엑솜 변이 호출에 사용. |
| Ion Torrent Exome | HG004 | Ion Torrent | 204 | ✗ | ✓ | ✓ Torrent Suite v4.2 | ✗ | ✗ | – | – | – | 문서 | 원시 fastq 없음 → 재정렬 불가. TVC 계열로 변이 호출. |
| Oslo Exome (KIT-Av5) | HG004 | 장비 미표기 | 10 | ✗ | ✓ | ✓ N/A | ✗ | ✗ | – | – | – | N/A | 원시 리드가 없어 재정렬 불가. BAM 헤더로 정렬 툴·참조 확인 후 변이 호출에 사용. |
| Ion Torrent Exome | HG005 | Ion Torrent | 208 | ✗ | ✓ | ✓ Torrent Suite v4.2 | ✗ | ✗ | – | – | – | 문서 | 원시 fastq 없음 → 재정렬 불가. TVC 계열로 변이 호출해 HG005 엑솜 비교에 사용. |
| Oslo Exome (KIT-Av5) | HG005 | 장비 미표기 | 8 | ✗ | ✓ | ✓ N/A | ✗ | ✗ | – | – | – | N/A | 원시 리드가 없어 재정렬 불가. BAM 헤더로 정렬 툴·참조 확인 후 변이 호출에 사용. |

</details>

<details>
<summary><b>Linked reads (10X, stLFR)</b> — 18 datasets, 5,038 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 10X Chromium LongRanger2.0 (GRCh37+GRCh38) | HG001 | 10X Chromium | 490 | ✓ FASTQ | ✓ | ✓ Long Ranger v2.0 | ✓ Long Ranger v2.0 | ✓ Long Ranger v2.0 | – | – | ✗ | 문서 | FASTQ가 있어 원하는 참조·툴로 재정렬·재콜이 가능하고, GRCh37/GRCh38 Long Rang… |
| 10X Chromium LongRanger2.1 (GRCh38+hg19) | HG001 | 10X Chromium | 363 | ✗ | ✓ | ✓ Long Ranger v2.1 | ✓ Long Ranger v2.1 | ✓ Long Ranger v2.1 | – | – | ✗ | 문서 | 정렬·페이징·변이까지 끝난 GIAB 산출물 그대로 사용. 재처리하려면 LongRanger2.0 디렉토리… |
| 10X Chromium phased BAM (기본+size-selected) | HG001 | 10X Genomics | 176 | ✗ | ✓ | ✓ Long Ranger | ✓ Long Ranger | ✗ | – | – | ✗ | 문서 | 정렬·페이징 완료된 BAM이라 그대로 사용. FASTQ가 없어 재정렬은 불가하고, 소변이가 필요하면 이… |
| stLFR L0 (리드+정렬+VCF) | HG001 | stLFR | 514 | ✓ FASTQ | △ 1개 | ✓ N/A | ✗ | ✓ GATK | – | – | ✗ | 문서 | barcode-split FASTQ가 있어 재정렬·재콜이 가능하고, GIAB의 GATK VCF는 bgz… |
| 10X Chromium FASTQ only | HG002 | 10X Chromium | 166 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | N/A | FASTQ만 있는 상태 — barcode-aware 정렬·페이징(Long Ranger 계열 또는 대안… |
| 10X Chromium phased BAM | HG002 | 10X Chromium | 60 | ✗ | ✓ | ✓ Long Ranger | ✓ Long Ranger | ✗ | – | – | ✗ | 문서 | 페이징된 BAM 그대로 사용. FASTQ가 없어 재정렬은 불가하니 재처리는 같은 샘플 10Xgenomi… |
| stLFR (MGISEQ2000) | HG002 | MGISEQ-2000 stLFR | 228 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | N/A | 문서가 없는 원시 FASTQ — 참조(hs37d5 또는 GRCh38)와 정렬 툴을 사용자가 정해 처음부… |
| stLFR (리드+정렬) | HG002 | stLFR | 433 | ✓ FASTQ | ✓ | ✓ N/A | ✗ | ✗ | – | – | ✗ | 문서 | hs37d5 정렬 BAM과 FASTQ가 함께 있으니 변이콜부터 진행하고, 매퍼가 미기재라 재현이 필요하… |
| 10X Chromium FASTQ only | HG003 | 10X Chromium | 81 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | N/A | FASTQ만 있는 상태 — barcode-aware 정렬·페이징을 사용자가 직접 돌려야 한다. |
| 10X Chromium phased BAM | HG003 | 10X Chromium | 62 | ✗ | ✓ | ✓ Long Ranger | ✓ Long Ranger | ✗ | – | – | ✗ | 문서 | 페이징된 BAM 그대로 사용. 재정렬은 같은 샘플 10Xgenomics_ChromiumGenome FA… |
| stLFR (리드+정렬) | HG003 | stLFR | 428 | ✓ FASTQ | ✓ | ✓ N/A | ✗ | ✗ | – | – | ✗ | 문서 | hs37d5 정렬 BAM과 FASTQ가 있으니 변이콜부터 진행. 매퍼 미기재라 재현엔 자체 정렬 필요. |
| 10X Chromium FASTQ only | HG004 | 10X Chromium | 86 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | N/A | FASTQ만 있는 상태 — barcode-aware 정렬·페이징을 사용자가 직접 돌려야 한다. |
| 10X Chromium phased BAM | HG004 | 10X Chromium | 56 | ✗ | ✓ | ✓ Long Ranger | ✓ Long Ranger | ✗ | – | – | ✗ | 문서 | 페이징된 BAM 그대로 사용. 재정렬은 같은 샘플 10Xgenomics_ChromiumGenome FA… |
| stLFR (리드+정렬) | HG004 | stLFR | 387 | ✓ FASTQ | ✓ | ✓ N/A | ✗ | ✗ | – | – | ✗ | 문서 | hs37d5 정렬 BAM과 FASTQ가 있으니 변이콜부터 진행. 매퍼 미기재라 재현엔 자체 정렬 필요. |
| stLFR (MGISEQ2000) | HG005 | MGISEQ-2000 stLFR | 226 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | ✗ | N/A | 문서 없는 원시 FASTQ — 참조와 정렬 툴을 정해 처음부터 돌려야 한다. |
| stLFR (리드+정렬) | HG005 | stLFR | 429 | ✓ FASTQ | ✓ | ✓ N/A | ✗ | ✗ | – | – | ✗ | 문서 | hs37d5 정렬 BAM과 FASTQ가 있으니 변이콜부터 진행. 매퍼 미기재라 재현엔 자체 정렬 필요. |
| stLFR (리드+정렬) | HG006 | stLFR | 422 | ✓ FASTQ | ✓ | ✓ N/A | ✗ | ✗ | – | – | ✗ | 문서 | hs37d5 정렬 BAM과 FASTQ가 있으니 변이콜부터 진행. 매퍼 미기재라 재현엔 자체 정렬 필요. |
| stLFR (리드+정렬) | HG007 | stLFR | 431 | ✓ FASTQ | ✓ | ✓ N/A | ✗ | ✗ | – | – | ✗ | 문서 | hs37d5 정렬 BAM과 FASTQ가 있으니 변이콜부터 진행. 매퍼 미기재라 재현엔 자체 정렬 필요. |

</details>

<details>
<summary><b>Complete Genomics</b> — 11 datasets, 14,880 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CG RMDNA GS000025639 (native ASM + BAM) | HG001 | Complete Genomics | 1,620 | ✓ FASTQ | △ 26개 | ✓ CG Standard Pipeline 2.5 +1 | ✗ | ✓ CG Standard Pipeline 2.5 +1 | – | – | – | 문서 | README가 재정렬·재콜을 금지 — 표준 파이프라인 대상이 아니다. mapping BAM 26개에 s… |
| CG normal 디렉토리 README | HG001 | Complete Genomics | 0 | ✗ | – | – | – | – | – | – | – | 문서 | 처리 대상 아님 — CompleteGenomics_normal 하위 BAM·ASM tar를 해석할 때… |
| CG public genome ASM tarball (EVIDENCE/REF) | HG001 | Complete Genomics | 32 | ✗ | – | – | – | ✗ | – | – | – | N/A (모든 *_tool이 N/A이므로 tool_source도 N/A. evidence의 실제 인용 문서는 data/NA12878/analysis/CompleteGenomics_PublicGenomes_10152011/README.txt) | tar를 풀어 EVIDENCE/REF 텍스트를 조회용으로만 쓴다. CG 네이티브 포맷이라 표준 파이프라… |
| CG teramap BAM (CEU high-coverage) | HG001 | Complete Genomics | 435 | ✗ | ✓ | ✓ cgatools evidence2sam v1.8.0 | ✗ | ✓ CG Standard Pipeline 2.5 +1 | – | – | – | 문서 | README가 '갭 리드 구조 때문에 이 BAM으로 재정렬·재콜하는 것은 부적절'이라고 명시 — 재처리… |
| CG RMDNA GS000037263 (native ASM + BAM) | HG002 | Complete Genomics | 1,805 | ✓ FASTQ | △ 26개 | ✓ CG Standard Pipeline 2.5 +1 | ✗ | ✓ cgatools | – | – | – | 문서 | README가 재정렬·재콜을 금지 — 재처리 대상 아니다. mapping BAM에 samtools in… |
| CG RMDNA GS000037264 (native ASM + BAM) | HG003 | Complete Genomics | 1,854 | ✓ FASTQ | △ 26개 | ✓ CG Standard Pipeline 2.5 +1 | ✗ | ✓ cgatools | – | – | – | 문서 | README가 재정렬·재콜을 금지 — 재처리 대상 아니다. 조회용으로 samtools index만. |
| CG RMDNA GS000037262 (native ASM + BAM) | HG004 | Complete Genomics | 1,747 | ✓ FASTQ | △ 26개 | ✓ CG Standard Pipeline 2.5 +1 | ✗ | ✓ cgatools | – | – | – | 문서 | README가 재정렬·재콜을 금지 — 재처리 대상 아니다. 조회용으로 samtools index만. |
| CG RMDNA GS000037265 (native ASM + BAM) | HG005 | Complete Genomics | 1,796 | ✓ FASTQ | △ 26개 | ✓ CG Standard Pipeline 2.5 +1 | ✗ | ✓ CG Standard Pipeline 2.5. 변이콜… | – | – | – | 문서 | README가 재정렬·재콜을 금지 — 재처리 대상 아니다. 조회용으로 samtools index만. |
| CG cellsDNA GS000037475 (native ASM + BAM) | HG005 | Complete Genomics | 1,865 | ✓ FASTQ | △ 26개 | ✓ CG Standard Pipeline 2.5 +1 | ✗ | ✓ cgatools | – | – | – | 문서 | README가 재정렬·재콜을 금지 — 재처리 대상 아니다. RMDNA 대비 세포주 유래 차이 확인용으로… |
| CG cellsDNA GS000037476 (native ASM + BAM) | HG006 | Complete Genomics | 1,859 | ✓ FASTQ | △ 26개 | ✓ CG Standard Pipeline 2.5 +1 | ✗ | ✓ cgatools | – | – | – | 문서 | README가 재정렬·재콜을 금지 — 재처리 대상 아니다. 조회용으로 samtools index만. |
| CG cellsDNA GS000037477 (native ASM + BAM) | HG007 | Complete Genomics | 1,868 | ✓ FASTQ | △ 26개 | ✓ CG Standard Pipeline 2.5 +1 | ✗ | ✓ cgatools | – | – | – | 문서 | README가 재정렬·재콜을 금지 — 재처리 대상 아니다. 조회용으로 samtools index만. |

</details>

<details>
<summary><b>기타 기술 (BioNano, Hi-C, AVITI, UG100, Strand-seq 등)</b> — 107 datasets, 18,830 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 10X Genomics 콜셋 | HG001 | 10X Genomics 링크드리드 | 0 | ✗ | ✓ | ✗ | ✓ Long Ranger | ✓ Long Ranger — SV 호출 및 SNP/ind… | – | – | ✗ | 문서 | 리드가 없어 재처리 불가. Long Ranger 페이징 결과를 자체 페이징(switch error) 비… |
| CG LFR CGAtools | HG001 | Complete Genomics LFR | 11 | ✗ | ✗ 3개 | ✗ | ✓ N/A | ✓ Complete Genomics LFR standar… | – | – | ✗ | 문서 | 리드 없음. LFR 페이징 콜셋을 자체 페이징 비교용으로 사용. RM DNA가 아니라 Coriell 세… |
| CG Public Genomes | HG001 | Complete Genomics | 1 | ✗ | – | ✗ | – | ✓ Complete Genomics standard pi… +1 | – | – | ✗ | 문서 | tar 해제 후 vcfBeta/masterVar 사용. 리드 없음. CG 기술 비교 및 구 통합 콜셋… |
| CG RM DNA ASM 전체 | HG001 | Complete Genomics | 42 | ✗ | – | ✗ | – | ✓ Complete Genomics standard pi… +1 | – | – | ✗ | 문서 | 리드 없음. vcfBeta/masterVar를 CG 기술 비교 및 SNV/CNV 직교 검증에 사용 |
| CLC bio 콜셋 | HG001 | Illumina(모델 미표기) | 0 | ✗ | ✗ 4개 | ✗ | – | ✓ CLC bio | – | – | ✗ | 파일명 | 리드 없음(입력 FASTQ는 GIAB Illumina 300x 디렉토리). 자체 Illumina 소변이… |
| CytoSNP-850K 어레이 | HG001 | Illumina CytoSNP-850K 어레이 | 0 | – | – | – | – | ✓ Illumina GenomeStudio V2011.1 +1 | – | – | – | 문서 | 시퀀싱 처리 대상이 아님. 자체 genotype 및 CNV 결과를 검증하는 직교 어레이 데이터로 사용 |
| Element AVITI 20240920 | HG001 | Element AVITI | 421 | ✓ fastq | ✓ | ✓ BWA-MEM 0.7.17-r1188 +1 | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ로 자체 정렬·소변이 호출 파이프라인을 돌리고 GIAB BWA-MEM BAM을 정렬 기준선으로… |
| GIAB integration v0.2 | HG001 | 미표기(통합 콜셋) | 1 | ✗ | ✗ 2개 | ✗ | ✗ | ✓ NIST-GIAB v2.19 arbitrated ca… +1 | – | – | – | 문서 | 벤치마크 truth set 용도. 실제 평가에는 release/ 하위 최신 GIAB 버전을 쓰고, 이… |
| Garvan SNP/indel | HG001 | 미표기 | 0 | ✗ | ✗ 1개 | ✗ | – | ✓ N/A | – | – | ✗ | N/A | 리드 없음. 툴 출처가 미확정이라 벤치마크 기준선으로 쓰기 전에 VCF 헤더의 ##GATKCommand… |
| HipSTR/GangSTR STR 콜 | HG001 | 미표기 | 0 | ✗ | ✓ | ✗ | – | ✓ picard +1 | – | – | ✗ | 문서 | 리드 없음. 자체 STR 호출(HipSTR/GangSTR/TRGT) 결과와 비교하는 기준 콜셋으로 사용 |
| Illumina Platinum Genomes | HG001 | Illumina(모델 미표기) | 1 | ✗ | ✓ | ✗ | ✗ | ✓ bwa+FreeBayes +7 | – | – | ✗ | 파일명 | 리드 없음. NA12878 벤치마크 truth set 대안 및 다중 콜러 비교(bwa+GATK/Free… |
| Ion Torrent TVC 04/2015 | HG001 | Ion Torrent Proton | 0 | ✗ | ✗ 2개 | ✗ | – | ✓ Torrent Variant Caller — 버전 미… | – | – | ✗ | 문서 | 리드 없음. AmpliseqExome 타깃 영역 안에서 자체 엑솜 변이 콜셋과 비교(비교 전 vcfal… |
| Ion Torrent TVC 06/2015 | HG001 | Ion Torrent(모델 미표기) | 0 | ✗ | ✗ 2개 | ✗ | – | ✓ tmap +1 | – | – | ✗ | 문서 | 리드 없음. TVC 파라미터 민감도 비교 및 자체 엑솜 콜셋 대조용 |
| MtSinai BioNano | HG001 | Bionano 광학맵(장비 모델 미표기) | 0 | ✓ all.bnx | – | ✓ N/A | – | ✗ | – | – | ✓ N/A | 문서 | Bionano 전용 툴(Solve/RefAligner)이 필요해 표준 NGS 파이프라인으로는 처리 불가… |
| NIST union callsets v2.15~2.18 | HG001 | 미표기(다중 데이터셋 통합) | 5 | ✗ | ✗ 13개 | ✗ | ✗ | ✓ GATK 2.6 UnifiedGenotyper + G… +1 | – | – | – | 문서 | 벤치마크 truth set 용도. 현행 평가는 release/ 하위 최신 버전을 쓰고 이 세트는 과거… |
| PacBio CCS chem2 콜셋 | HG001 | PacBio CCS 15kb/20kb chem… | 384 | ✗ | ✓ | ✓ pbmm2 v1.1.0 | ✓ N/A | ✓ DeepVariant v0.9.0 +2 | ✗ | – | ✗ | 문서 | 원시 HiFi uBAM이 data/NA12878/PacBio_CCS_15kb_20kb_chemistry… |
| PacBio PBHoney SV | HG001 | PacBio(모델 미표기) | 0 | ✗ | – | ✗ | – | ✓ PBHoney 15.8.24 | – | – | ✗ | 파일명 | 리드 없음. PacBio SV 후보(spots/tails)를 자체 SV 콜셋과 대조하는 용도 |
| PacBio pbsv SV | HG001 | PacBio(모델 미표기) | 0 | ✗ | ✓ | ✗ | – | ✓ pbmm2 v1.1.0 +1 | – | – | ✗ | 문서 | 리드 없음. pbsv SV 콜셋을 자체 PacBio SV 호출 결과의 비교 기준으로 사용 |
| Peregrine CCS 어셈블리 | HG001 | PacBio CCS(모델 미표기) | 3 | ✗ | – | – | – | ✗ | – | – | ✓ Peregrine | 파일명 | 자체 어셈블리(hifiasm 등) 결과와 QUAST/asmgene 비교, 또는 dipcall 등 어셈블… |
| RTG segregation phasing | HG001 | Illumina(모델 미표기) | 7 | ✗ | ✓ | ✗ | ✓ RTG Core segregation phasing +2 | ✓ RTG Core population caller | – | – | ✗ | 문서 | 리드 없음(원본은 ENA). SP를 페이징 기준 truth로 삼아 rtg vcfeval/hap.py로… |
| RTG small variants | HG001 | Illumina WGS(모델 미표기) | 19 | ✗ | ✓ | ✗ | ✓ RTG segregation phasing | ✓ rtgVariant v1.0 +3 | – | – | ✗ | 문서 | 리드 없음. 최신 SP는 RTG_Illumina_Segregation_Phasing_05122016을… |
| SOLiD 5500W | HG001 | SOLiD 5500W | 242 | ✗ | ✓ | ✓ LifeScope 2.5.1 | ✗ | ✗ | – | – | ✗ | 문서 | 원시 xsq/FASTQ가 없어 재정렬 불가. 커버리지 6~15x color-space BAM에서 변이… |
| TARDIS/mrCaNaVar SV·CNV | HG001 | Illumina HiSeq | 0 | ✗ | ✓ | ✗ | – | ✓ TARDIS +1 | – | – | ✗ | 문서 | 리드 없음. 자체 Illumina SV/CNV 콜셋과 비교하는 직교 콜셋으로 사용 |
| WhatsHap 페이징 | HG001 | Strand-seq + PacBio | 0 | ✗ | ✓ | ✗ | ✓ WhatsHap v0.14.1 | ✗ | – | – | ✗ | 문서 | 리드 없음. Strand-seq+PacBio 통합 페이징을 자체 페이징 정확도(switch error)… |
| BioNano DLE(링크만) | HG002 | Bionano DLE-1 광학맵 | 0 | ✗ | – | ✗ | – | ✗ | – | – | ✗ | 문서 | GIAB FTP에 실데이터가 없음. 다운로드 대상에서 제외하거나 Dropbox 링크에서 별도 취득 (링… |
| BioNano(구버전 nickase) | HG002 | Bionano 광학맵(장비 모델 미표기) | 1 | ✓ all.bnx | – | ✓ N/A | – | ✗ | – | – | ✓ N/A | 문서 | Bionano 전용 툴(Solve/RefAligner)이 필요해 표준 NGS 파이프라인 처리 불가. S… |
| Dovetail Chicago | HG002 | Dovetail Chicago 라이브러리 | 24 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | Chicago FASTQ는 스캐폴딩(HiRise/SALSA2 등) 입력 전용. 단독 변이 호출에는 부적합 |
| Element AVITI 20231018 | HG002 | Element AVITI | 911 | ✓ fastq | ✓ | ✓ BWA-MEM 0.7.17-r1188 | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ로 자체 정렬·변이 호출 수행. GRCh37/GRCh38/CHM13 BAM 3종이 있어 레퍼런… |
| Element AVITI 20240920 | HG002 | Element AVITI | 428 | ✓ fastq | ✓ | ✓ BWA-MEM 0.7.17-r1188 +1 | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ로 자체 정렬·소변이 호출 후 GIAB BWA-MEM BAM 및 v4.2.1 벤치마크로 평가 |
| Hi-C downsampled | HG002 | Illumina NovaSeq | 213 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | README 권고대로 bwa mem -5SP(HiC_1) / -SP5M(HiC_2)로 직접 정렬한 뒤… |
| SOLiD 5500W | HG002 | SOLiD 5500W | 1,035 | ✓ xsq 24개 | ✓ | ✓ N/A | ✗ | ✗ | – | – | ✗ | N/A | 원시 xsq는 color-space 전용 툴(LifeScope 등)이 필요해 표준 파이프라인 처리 불가… |
| Strand-seq BCCRC | HG002 | Strand-seq(시퀀서 미표기) | 8 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | – | 문서 | 세포별로 정렬(bwa 등) 후 BreakpointR/StrandPhaseR로 페이징·역위 검출. 개별… |
| Strand-seq EMBL | HG002 | Strand-seq(시퀀서 미표기) | 18 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | – | – | 문서 | 세포별 정렬 후 BreakpointR/StrandPhaseR로 페이징에 사용. BCCRC Strand-… |
| HG002B Phase Genomics Hi-C | HG002 | Phase Genomics Hi-C | 386 | ✓ fastq | △ 2개 | ✓ BWA-MEM +1 | ✗ | ✗ | – | – | ✗ | 문서 | Hi-C FASTQ로 스캐폴딩·페이징 입력 구성. HG002B는 별도 배양체이므로 HG002 벤치마크와… |
| BioNano DLE 파이프라인 전체 | HG003 | Bionano DLE-1 광학맵 | 5 | ✓ all.bnx.gz | – | ✓ Bionano Solve 3.2.1 | – | ✓ Bionano Solve 3.2.1 | – | – | ✓ Bionano Solve 3.2.1 | 문서 | Bionano 전용 툴 필요(Solve 3.2.1 다운로드 링크가 README에 있음). 광학맵 SV/… |
| BioNano(구버전 nickase) | HG003 | Bionano 광학맵(장비 모델 미표기) | 1 | ✓ all.bnx | – | ✓ N/A | – | ✗ | – | – | ✓ N/A | 문서 | Bionano 전용 툴 필요. 표준 NGS 파이프라인 대상 아님. SV 검증용 직교 근거로 사용 |
| Dovetail Chicago | HG003 | Dovetail Chicago 라이브러리 | 17 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | Chicago FASTQ는 스캐폴딩 입력 전용. 단독 변이 호출 부적합 |
| Element AVITI 20240920 | HG003 | Element AVITI | 417 | ✓ fastq | ✓ | ✓ BWA-MEM 0.7.17-r1188 +1 | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ로 자체 정렬·소변이 호출. HG002-HG003-HG004 트리오 동시 처리 시 멘델 오류… |
| Hi-C UCSC | HG003 | Hi-C(시퀀서 미표기) | 69 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | Hi-C FASTQ를 bwa mem -5SP 등으로 직접 정렬해 스캐폴딩·페이징 입력으로 사용 |
| Strand-seq BCCRC | HG003 | Strand-seq(시퀀서 미표기) | 6 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | – | 문서 | 세포별 정렬 후 BreakpointR/StrandPhaseR로 페이징·역위 검출에 사용 |
| BioNano DLE 파이프라인 전체 | HG004 | Bionano DLE-1 광학맵 | 6 | ✓ all.bnx.gz | – | ✓ Bionano Solve 3.2.1 | – | ✓ Bionano Solve 3.2.1 | – | – | ✓ Bionano Solve 3.2.1 | 문서 | Bionano 전용 툴 필요. 광학맵 SV/CNV를 시퀀싱 SV 콜셋의 직교 검증 근거로 사용 |
| BioNano(구버전 nickase) | HG004 | Bionano 광학맵(장비 모델 미표기) | 1 | ✓ all.bnx | – | ✓ N/A | – | ✗ | – | – | ✓ N/A | 문서 | Bionano 전용 툴 필요. 표준 NGS 파이프라인 대상 아님. SV 검증용 직교 근거 |
| Dovetail Chicago | HG004 | Dovetail Chicago 라이브러리 | 17 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | Chicago FASTQ는 스캐폴딩 입력 전용. 단독 변이 호출 부적합 |
| Element AVITI 20240920 | HG004 | Element AVITI | 456 | ✓ fastq | ✓ | ✓ BWA-MEM 0.7.17-r1188 +1 | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ로 자체 정렬·소변이 호출. AJ 트리오(HG002-003-004) 동시 처리로 멘델 일관성… |
| Hi-C UCSC | HG004 | Hi-C(시퀀서 미표기) | 67 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | ✗ | 문서 | Hi-C FASTQ를 bwa mem -5SP 등으로 직접 정렬해 스캐폴딩·페이징에 사용 |
| Strand-seq BCCRC | HG004 | Strand-seq(시퀀서 미표기) | 7 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | – | 문서 | 세포별 정렬 후 BreakpointR/StrandPhaseR로 페이징·역위 검출 |
| BioNano | HG005 | Bionano 광학맵(장비 모델 미표기) | 1 | ✓ Molecules.bnx | – | ✓ N/A | – | ✗ | – | – | ✓ N/A | 문서 | Bionano 전용 툴 필요. 표준 NGS 파이프라인 대상 아님. SV 검증용 직교 근거 |
| Element AVITI 20240920 | HG005 | Element AVITI | 419 | ✓ fastq | ✓ | ✓ BWA-MEM 0.7.17-r1188 +1 | ✗ | ✗ | – | – | ✗ | 문서 | FASTQ로 자체 정렬·소변이 호출 후 GIAB BAM 및 HG005 벤치마크로 평가 |
| SOLiD 5500W | HG005 | SOLiD 5500W | 911 | ✓ xsq 24개 | ✓ | ✓ N/A | ✗ | ✗ | – | – | ✗ | N/A | 원시 xsq는 color-space 전용 툴이 필요해 표준 파이프라인 처리 불가. b37 BAM에서 변… |
| Strand-seq BCCRC | HG005 | Strand-seq(시퀀서 미표기) | 11 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | – | 문서 | 세포별 정렬 후 BreakpointR/StrandPhaseR로 페이징. 중국인 트리오 3인(HG005/… |
| Strand-seq BCCRC | HG006 | Strand-seq(시퀀서 미표기) | 6 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | – | 문서 | 세포별 정렬 후 BreakpointR/StrandPhaseR로 페이징. HG005/HG007과 묶어 트… |
| Strand-seq BCCRC | HG007 | Strand-seq(시퀀서 미표기) | 8 | ✓ fastq | – | ✗ | ✗ | ✗ | – | – | – | 문서 | 세포별 정렬 후 BreakpointR/StrandPhaseR로 페이징. HG005/HG006과 묶어 트… |
| Arima Hi-C | HG008 | Arima Hi-C, Illumina 2x150 | 299 | ✓ FASTQ | – | ✗ | ✗ | ✗ | – | ✗ | ✗ | 문서 | Hi-C FASTQ로 직접 정렬/스캐폴딩 수행. hifiasm/Verkko 어셈블리의 --h1/--h2… |
| BCM 2022 Manta/Strelka/xAtlas(대체됨) | HG008 | Illumina WGS(모델 미표기) | 2 | ✗ | △ 5개 | – | – | ✓ Manta +1 | – | ✓ Manta +1 | – | 문서 | superseded이고 툴 버전도 없어 기준선 가치가 낮다. Manta ± candidateIndel… |
| BCM Illumina WGS 2022(대체됨) | HG008 | Illumina WGS(모델 미표기) | 1,666 | ✓ FASTQ | ✓ | ✓ BCM: BWA-MEM +2 | ✗ | ✗ | – | ✗ | – | 문서 | 패세지가 다르므로 2024년 데이터와 직접 합치지 말 것. 패세지 간 somatic 변이 변화를 보려면… |
| BCM Revio somatic WDL | HG008 | PacBio Revio HiFi | 565 | ✗ | ✓ | ✓ N/A | ✓ HiPhase | ✓ Clair3 | ✓ pb-CpG-tools +1 | ✓ DeepSomatic +2 | – | 문서 | GIAB 산출물 그대로 기준선으로 사용. 자체 HiFi somatic 파이프라인 결과와 Severus/… |
| Bionano SV/CNV 분석 | HG008 | Bionano 광학맵(장비 모델 미표기) | 0 | ✗ | ✗ 2개 | – | – | – | – | ✓ Bionano Rare Variant Analysis… +2 | – | 문서 | 직교 기술 SV 근거로 사용. 자체 시퀀싱 기반 SV 콜셋을 이 UniqueSVs와 대조해 5kb 이상… |
| Bionano 광학맵 원시 | HG008 | Bionano 광학맵(장비 모델 미표기) | 3 | ✓ BNX.gz + CMAP | – | ✓ Bionano Access 1.8 +1 | – | ✗ | – | ✗ | ✗ | 문서 | BNX 원자료가 있으니 Bionano Solve로 재분석 가능하지만 Bionano 라이선스 소프트웨어가… |
| DRAGEN v4.2.4 (graph/standard) | HG008 | Illumina WGS(모델 미표기) | 683 | ✗ | ✓ | ✓ DRAGEN 4.2.4 | ✗ | ✗ | – | ✓ DRAGEN 4.2.4 Tumor-Normal WGS… | – | 문서 | GIAB 산출물 그대로 벤치마크 입력 계보 확인용으로 사용. graph vs standard 레퍼런스… |
| DRAGEN v4.2.4 2023(대체됨) | HG008 | Illumina WGS(모델 미표기) | 0 | ✗ | △ 2개 | ✗ | – | – | – | ✓ DRAGEN 4.2.4 Tumor-Normal WGS… +1 | – | 문서 | superseded이므로 신규 비교에는 20240312 DRAGEN 결과를 쓸 것. ANNOVAR 주석… |
| Element AVITI 20240118 | HG008 | Element AVITI | 777 | ✓ FASTQ | ✓ | ✓ BWA-MEM 0.7.17-r1188 +1 | ✗ | ✗ | – | ✗ | ✗ | 문서 | GRCh38-GIABv3 T/N BAM 쌍으로 somatic SNV/INDEL 콜 후 HG008-T 초… |
| Element AVITI 20240626 | HG008 | Element AVITI | 2,284 | ✓ FASTQ | ✓ | ✓ BWA-MEM 0.7.17-r1188 +1 | ✗ | ✗ | – | ✗ | ✗ | 문서 | StdInsert/LngInsert를 나눠서 또는 합쳐서 somatic SV 콜(GRIDSS2, Man… |
| Element AVITI 20241216 | HG008 | Element AVITI | 1,917 | ✓ FASTQ | ✓ | ✓ BWA-MEM 0.7.17-r1188 +1 | ✗ | ✗ | – | ✗ | ✗ | 문서 | FASTQ와 3개 레퍼런스 BAM이 다 있으므로 T/N somatic 콜(예: Mutect2, Stre… |
| Element GRIDSS2 somatic SV | HG008 | Element AVITI | 0 | ✗ | ✗ 3개 | – | – | – | – | ✓ GRIDSS 2.13.2 +2 | – | 문서 | tabix 인덱싱 후 Element 기반 somatic SV 참조로 사용. 자체 GRIDSS2 실행 시… |
| HiFi ClairS SNV/INDEL | HG008 | PacBio HiFi(모델 미표기) | 0 | ✗ | ✓ | – | – | – | – | ✓ ClairS v0.1.7 | – | 문서 | 장독 somatic SNV/INDEL 참조 콜셋으로 사용. 자체 ClairS/DeepSomatic 결과… |
| HiFi DeepSomatic | HG008 | PacBio HiFi(모델 미표기) | 0 | ✗ | ✓ | – | – | – | – | ✓ DeepSomatic v1.6.0 | – | 문서 | HiFi somatic SNV/INDEL 참조 콜셋으로 사용. HKU ClairS v0.1.7 HiFi… |
| HiFi minimap2 정렬 | HG008 | PacBio HiFi Revio | 152 | ✗ | ✓ | ✓ samtools fastq -T MM,ML +2 | ✗ | ✗ | ✗ | ✗ | – | 문서 | pbmm2 정렬본과 이 minimap2 정렬본으로 같은 somatic SV 콜러를 각각 돌려 정렬기 차… |
| Illumina ClairS SNV(대체됨) | HG008 | Illumina WGS(모델 미표기) | 0 | ✗ | ✓ | – | – | – | – | ✓ ClairS v0.1.7 | – | 문서 | superseded 입력(패세지 상이) 때문에 기준선으로는 주의. 같은 ClairS v0.1.7로 Hi… |
| Illumina DeepSomatic(대체됨) | HG008 | Illumina WGS(모델 미표기) | 0 | ✗ | ✓ | – | – | – | – | ✓ DeepSomatic v1.6.0 | – | 문서 | superseded 입력이므로 정답셋으로 쓰지 말 것. 같은 DeepSomatic v1.6.0에서 mo… |
| Illumina GRIDSS2 somatic SV(대체됨) | HG008 | Illumina WGS(모델 미표기) | 0 | ✗ | ✗ 3개 | – | – | – | – | ✓ GRIDSS 2.13.2 +2 | – | 문서 | superseded — 벤치마크 비교에는 Passage23 버전을 쓸 것. 두 콜셋 diff로 패세지… |
| Illumina p23 GRIDSS2 somatic SV | HG008 | Illumina WGS(모델 미표기) | 0 | ✗ | ✗ 3개 | – | – | – | – | ✓ GRIDSS 2.13.2 +2 | – | 문서 | 벤치마크 계보상 가장 중요한 단독 콜셋. tabix 인덱싱 후 자체 단독 somatic SV 콜과 브레… |
| KaryoLogic 핵형 2022(대체됨) | HG008 | 세포유전학 핵형분석(시퀀싱 아님) | 0 | – | – | – | – | – | – | – | – | 문서 | 처리 대상 아님. 대형 CNA/전좌 콜의 타당성 검토용 배경 자료로만 참조하고, 최신 핵형은 NIST/… |
| Liss lab README | HG008 | 해당 없음 | 0 | – | – | – | – | – | – | – | – | 문서 | 처리 대상 아님. Liss_lab 하위 구조를 볼 때 data_somatic/HG008/README_H… |
| NIST README | HG008 | 해당 없음 | 0 | – | – | – | – | – | – | – | – | 문서 | 처리 대상 아님. NIST 하위 구조는 data_somatic/HG008/README_HG008.md… |
| NIST Year1 somatic 콜셋(대체됨) | HG008 | Illumina WGS(모델 미표기) | 0 | ✗ | ✓ | – | – | – | – | ✓ Strelka2 v2.9.10 +2 | – | 문서 | 동봉된 실행 스크립트를 참고해 같은 4개 콜러를 최신 버전으로 재실행하고, 버전 상승분과 패세지 차이를… |
| NYGC somatic 파이프라인 | HG008 | Illumina WGS(모델 미표기) | 2 | ✗ | ✓ | ✗ | – | ✓ GATK HaplotypeCaller | – | ✓ NYGC Somatic Pipeline v7 — St… +1 | – | 문서 | merged/high_confidence/final annotated VCF를 다중콜러 합의 기준선으로… |
| PacBio Onso SBS | HG008 | PacBio Onso | 1,216 | ✓ FASTQ | ✓ | ✓ cutadapt +2 | ✗ | ✗ | – | ✗ | ✗ | 문서 | 저오류 SBS 데이터이므로 GRCh38-GIABv3 T/N BAM으로 somatic SNV 콜을 돌려… |
| PacBio Revio germline WDL | HG008 | PacBio Revio HiFi | 14 | ✗ | ✓ | ✗ | ✓ HiPhase | ✓ DeepVariant +2 | ✓ pb-CpG-tools | ✗ | – | 문서 | HG008-N-P germline 콜을 somatic 필터링의 정상 대조로 사용. 정렬 BAM이 필요하… |
| Severus SV (HiFi) | HG008 | PacBio HiFi(모델 미표기) | 0 | ✗ | △ 2개 | – | ✓ HiPhase v1.3.0 +1 | ✓ Clair3 v1.0.4 | – | ✓ Severus v0.1.3 | – | 문서 | 이 4단계 체인(Clair3→HiPhase→WhatsHap→Severus)을 자체 환경에서 그대로 재현… |
| Sniffles v2.2 HiFi+ONT 병합 SV | HG008 | PacBio HiFi + ONT(모델 미표기) | 0 | ✗ | ✗ 2개 | – | – | ✓ Sniffles v2.2 | – | ✓ Sniffles v2.2 | – | 문서 | tbi가 없으니 tabix로 인덱싱한 뒤 사용. 자체 장독 SV 콜셋과 비교할 참조 콜셋으로 쓰고, s… |
| Ultima DeepVariant somatic | HG008 | Ultima UG100 | 0 | ✗ | ✓ | – | – | – | – | ✓ UG 최적화 somatic DeepVariant +1 | – | 문서 | Ultima 플랫폼 somatic 콜 기준선으로 사용. VAF 필터를 걸 때 표준 AF 대신 VAFR을… |
| Ultima UG100 WGS | HG008 | Ultima UG100 | 1,454 | ✗ | ✓ | ✓ UA — Ultima Analysis Pipeline… | ✗ | ✗ | – | ✗ | ✗ | 문서 | CRAM 그대로 T/N somatic 콜(Ultima 데이터는 flow-based라 UG 전용 모델/파… |
| Ultima ppmSeq UG100 | HG008 | Ultima UG100 ppmSeq | 448 | ✗ | ✓ | ✓ Ultima UG100 on-tool 트리밍/정렬/정… | ✗ | ✗ | – | ✗ | ✗ | 문서 | CRAM만 있고 FASTQ가 없어 완전 재정렬은 CRAM→FASTQ 역변환이 필요. 레퍼런스가 GIAB… |
| Verkko 어셈블리 모음 | HG008 | PacBio HiFi + ONT + Hi-C | 198 | ✗ | ✗ 2개 | ✗ | ✓ verkko 내부 Hi-C 페이징 | ✗ | – | ✗ | ✓ verkko v2.0 +1 | 문서 | HG008T_verkko_v2.2.1_herro_corrected와 HG008N v2.1 하플로타입 F… |
| Wakhan CNA (HiFi) | HG008 | PacBio HiFi(모델 미표기) | 0 | ✗ | ✗ 2개 | – | ✓ Clair3 v1.0.4 | ✓ Clair3 v1.0.4 | – | ✓ Wakhan | – | 문서 | HiFi 기반 somatic CNA 기준선으로 사용. 자체 CNA 콜과 copynumber/LOH BE… |
| Wakhan CNA (HiFi+Hi-C) | HG008 | PacBio HiFi + Hi-C(모델 미표기) | 0 | ✗ | ✗ 1개 | – | ✓ HapCUT2 | – | – | ✓ Wakhan | – | 문서 | NIH_HiFi_Wakhan-CNA_20240308 결과와 copynumber/LOH BED를 직접 d… |
| hifiasm Hi-C 어셈블리 05/2024 | HG008 | PacBio HiFi + Hi-C(모델 미표기) | 11 | ✗ | – | ✗ | – | ✗ | – | ✗ | ✓ hifiasm v0.19.9-r616 | 문서 | tumor sub0/sub1 하플로타입 FASTA를 GRCh38-GIABv3에 직접 정렬(minimap… |
| hifiasm 어셈블리 03/2024 | HG008 | PacBio HiFi(모델 미표기) | 8 | ✗ | ✓ | ✓ minimap2 -ax asm5 -L +1 | – | ✗ | – | ✗ | ✓ hifiasm v0.19.8 | 문서 | tumor/normal 하플로타입 FASTA로 dipcall 기반 어셈블리 변이 콜을 돌려 read-b… |
| minda 앙상블 SV | HG008 | PacBio HiFi + ONT + Illum… | 11 | ✗ | ✗ 12개 | – | – | – | – | ✓ Minda v0.0.2 ensemble — 입력: S… +1 | – | 문서 | caller별 개별 VCF 11개를 기준선으로 확보하고, 자체 SV 콜셋을 Minda에 12번째 입력으… |
| 조상성분 분석 | HG008 | 해당 없음(2차 분석) | 0 | ✗ | – | – | – | – | – | – | – | 문서 | 처리 대상 아님. 샘플 신원/기원 확인용 메타데이터로만 참조. R 스크립트가 함께 있어 필요하면 재현… |
| 최상위 README | HG008 | 해당 없음 | 0 | – | – | – | – | – | – | – | – | 문서 | 처리 대상 아님. HG008 데이터 계획을 세울 때 가장 먼저 읽을 문서. 특히 세포주가 이질적 세포… |
| N-P Dovetail LinkPrep | HG008 | Dovetail LinkPrep, Illumi… | 210 | ✓ FASTQ | ✓ | ✓ BWA-MEM v2.2.1 +1 | ✗ | ✗ | – | ✗ | ✗ | 문서 | 근접결합 리드이므로 일반 WGS 변이 콜에는 쓰지 말고, GRCh38-GIABv3로 재정렬해 정상 게놈… |
| T BioSkryb ResolveDNA 원자료 | HG008 | BioSkryb ResolveDNA 단일세포 | 41 | ✓ FASTQ | – | ✓ N/A | – | ✗ | – | ✗ | ✗ | 문서 | tar를 풀어 셀별 FASTQ로 자체 단일세포 CNV/서브클론 분석 재수행. 심도가 낮아 SNV 콜에는… |
| T BioSkryb x UG100 매니페스트 | HG008 | BioSkryb ResolveDNA + Ult… | 0 | ✗ | – | ✓ Ultima 최적화 BWA-MEM + Ultima S… | – | ✗ | – | ✗ | ✗ | 문서 | 먼저 AWS 매니페스트 TSV를 열어 단일세포 CRAM 위치와 총 용량을 확인하고 다운로드 계획을 세울… |
| T BioSkryb 단일세포 CNV 분석 | HG008 | BioSkryb ResolveDNA 단일세포 | 0 | ✗ | – | – | – | – | – | ✓ BJ-CNV workflow v1.1.4 | – | 문서 | 클론 구조/서브클론 판정 근거로 사용. 자체 벌크 CNV 콜의 서브클론 세그먼트가 단일세포 CNV와 일… |
| T Phase Genomics Hi-C 2022(대체됨) | HG008 | Phase Genomics Hi-C | 97 | ✓ FASTQ | ✓ | ✓ BWA-MEM — Phase Genomics 정렬·Q… | ✗ | ✗ | – | ✗ | – | 문서 | Arima Hi-C와 합쳐 HG008-T 어셈블리 스캐폴딩/페이징 입력으로 재사용. 일반 변이 콜에는… |
| T Phase Genomics 분석 리포트(대체됨) | HG008 | Phase Genomics Hi-C | 0 | ✗ | – | – | – | – | – | ✓ Phase Genomics OncoTerra 분석 플… | – | 문서 | 처리 대상 아님. Hi-C 기반 파생 염색체/전좌 구조에 대한 직교 근거로만 참조하고, 좌표 기반 SV… |
| T p18 KaryoLogic 핵형 | HG008 | 세포유전학 핵형분석(시퀀싱 아님) | 0 | – | – | – | – | – | – | – | – | 문서 | 처리 대상 아님. NIST 배양 계보(p18/p21/p53)에서 핵형이 어떻게 변하는지 확인하는 배경… |
| T p2 ONT somatic + 메틸 | HG008 | ONT standard(모델/케미스트리 미표기) | 4 | ✗ | △ 1개 | ✗ | ✓ epi2me wf-somatic-variation v… | ✓ Clair3 +1 | ✓ modkit +1 | ✓ epi2me wf-somatic-variation v… | – | 문서 | p2(초기 패세지) 대 p23 somatic 콜을 비교해 배양 중 변이 축적 추적. GIABv3 dec… |
| T p21 KromaTiD dGH | HG008 | KromaTiD dGH(시퀀싱 아님) | 0 | – | – | – | – | – | – | ✓ KromaTiD dGH SCREEN 전게놈 assay… | – | 문서 | 처리 대상 아님. 대형 전좌/역위 콜의 방향성·상대 염색체 검증용 직교 근거로 사용. xlsx 이벤트/… |
| T p21 UMD Revio HiFi | HG008 | PacBio Revio HiFi(R84050) | 85 | ✓ hifi_reads/BAM | △ 1개 | ✓ pbmm2 v1.12.0 | ✗ | ✗ | ✗ | ✗ | ✗ | 문서 | unaligned BAM이 있으므로 정렬부터 재현 가능. p21 대 p41 쌍으로 HiFi 기반 패세지… |
| T p53 KromaTiD(문서만) | HG008 | KromaTiD dGH(시퀀싱 아님) | 0 | – | – | – | – | – | – | – | – | 문서 | 처리 대상 아님. p53 dGH 결과가 필요하면 20240508p21/KromaTiD-dGH_20241… |
| T somatic 벤치마크 V0.1 | HG008 | 해당 없음(벤치마크) | 0 | – | ✓ | – | – | – | – | ✓ 수동 큐레이션; bgzip | – | 문서 | 처리 대상 아님. V0.3이 나와 있으므로 신규 평가에는 V0.3을 쓰고, V0.1은 버전 간 변화 추… |
| T somatic 벤치마크 V0.2 | HG008 | 해당 없음(벤치마크) | 7 | – | ✓ | – | – | – | – | ✓ 수동 큐레이션 +1 | – | 문서 | 처리 대상 아님. 동봉된 defrabb 실행 tar와 dipcall 벤치마크 BED는 자체 어셈블리 기… |
| T somatic 벤치마크 V0.3 | HG008 | 해당 없음(벤치마크) | 0 | – | ✓ | – | – | – | – | ✓ 수동 큐레이션 + KromaTiD dGH 근거; 평가… | – | 문서 | 처리 대상 아님 — 자체 somatic SV 콜셋 평가의 정답셋으로 사용. 문서의 truvari ben… |
| T 클론별 핵형 | HG008 | 세포유전학 핵형분석(시퀀싱 아님) | 0 | – | – | – | – | – | – | – | – | 문서 | 처리 대상 아님. 벌크 데이터의 클론성/WGD 해석 근거로 사용. 클론별 시퀀싱 데이터는 이 디렉토리에… |
| UMD-Revio-HG008Tp41-20241011 | HG008 | PacBio Revio | 90 | ✓ hifi_reads/BAM | △ 1개 | ✓ pbmm2 v1.12.0 | ✗ | ✗ | ✗ | ✗ | ✗ | 문서 | unaligned hifi_reads BAM이 있으므로 재정렬부터 전 단계 재현 가능. p41(후기 패… |

</details>

<details>
<summary><b>Release — truth set / stratification / reference</b> — 58 datasets, 285 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| GIAB Pedigree v0.2 | HG001 | 미표기(다중 콜셋 통합) | 0 | ✗ | ✗ 1개 | – | – | ✓ NIST-GIAB v2.19 중재 콜셋 + RTG 위… +1 | – | – | – | 문서 | 베타 버전 truth set. GRCh37 소형변이 벤치마크 비교용으로만 사용하고, 실제 벤치마킹은 v… |
| NIST v2.15 | HG001 | 미표기(12 datasets 통합) | 0 | ✗ | ✗ 1개 | – | – | ✓ GATK UnifiedGenotyper + GATK… | – | – | – | 문서 | 구버전 truth set. 방법 변천 이력 참고용이며 실제 벤치마킹에는 사용하지 말 것 |
| NIST v2.17 | HG001 | 미표기(13 datasets 통합) | 0 | ✗ | ✗ 1개 | – | – | ✓ GATK UnifiedGenotyper v2.6 +… +1 | – | – | – | 문서 | 구버전 truth set. 이력 참고용 |
| NIST v2.18 | HG001 | 미표기(14 datasets 통합) | 0 | ✗ | ✗ 1개 | – | – | ✓ GATK UnifiedGenotyper v2.6 +… +1 | – | – | – | 문서 | 구버전 truth set. 이력 참고용 |
| NIST v2.19 | HG001 | 미표기(14 datasets 통합) | 0 | ✗ | ✗ 1개 | – | – | ✓ GATK UnifiedGenotyper v2.6 +… | – | – | – | 문서 | 구버전 truth set. GIABPedigreev0.2의 입력이므로 계보 확인용으로만 사용 |
| NIST v3.2 | HG001 | Complete Genomics + Illum… | 0 | ✗ | △ 1개 | ✗ | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. v3.3.2 이후 판이 있으니 이력 확인용 |
| NIST v3.2.1 | HG001 | Complete Genomics + Illum… | 0 | ✗ | △ 1개 | ✓ novoalign +2 | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. 이력 참고용 |
| NIST v3.2.2 | HG001 | Illumina + Complete Genom… | 0 | ✗ | ✓ | ✓ novoalign +2 | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. 이력 참고용 |
| NIST v3.3 | HG001 | CG + Illumina + Ion + SOL… | 0 | ✗ | ✓ | ✓ novoalign +2 | – | ✓ GATK HaplotypeCaller + freeba… +4 | – | – | – | 문서 | 구버전 truth set. 반복영역 BED(AllRepeats/SimpleRepeat/self_chai… |
| NIST v3.3.1 | HG001 | CG + Illumina + Ion + 10X… | 1 | ✗ | ✓ | ✓ novoalign +2 | ✓ RTG vcfeval 위상 전이 | ✓ GATK HaplotypeCaller + freeba… +4 | – | – | – | 문서 | 구버전 truth set. HG001 위상 벤치마크가 필요하면 v3.3.2 PGandRTGphasetr… |
| NIST v3.3.2 | HG001 | Illumina | 5 | ✗ | △ 1개 | ✓ novoalign +2 | ✓ RTG vcfeval 위상 전이 — 버전 미기재 | ✓ GATK HaplotypeCaller + freeba… +4 | – | – | – | 문서 | 구버전 truth set. Ion/SOLiD/CG 등 레거시 플랫폼 입력 VCF가 필요할 때만 참조 |
| NIST v4.2.1 | HG001 | PacBio HiFi + 10X Genomics | 7 | ✗ | △ 8개 | – | ✓ trio-hifiasm dipcall VCF에서 위상… | ✓ mosdepth 삭제. 커버리지 이상치 제외는 툴 미… | – | – | ✗ | 문서 | 현행 GRCh37/GRCh38 소형변이 벤치마크. hap.py 또는 rtg vcfeval의 baseli… |
| latest(v4.2.1 미러) | HG001 | PacBio HiFi + 10X Genomics | 7 | ✗ | △ 8개 | – | ✓ trio-hifiasm dipcall VCF에서 위상… | ✓ DeepVariant + GATK4 + 10x Gen… +1 | – | – | ✓ hifiasm v0.11 | 문서 | NISTv4.2.1과 동일 내용이므로 둘 중 하나만 받아 벤치마크 baseline으로 사용 |
| CMRG v1.00 (의학 유전자) | HG002 | 미표기(어셈블리 기반) | 8 | ✗ | ✓ | ✓ dipcall v0.1 | ✓ trio 기반 hifiasm v0.11 하플로타입 분리 +1 | ✓ dipcall v0.1 +1 | – | – | ✓ hifiasm v0.11 | 문서 | 273개 난이도 높은 의학 유전자 구간 벤치마크. v4.2.1이 못 덮는 영역 성능 측정에 사용(SV는… |
| Mosaic SNV v1.00 | HG002 | Illumina 300x, Element AV… | 1 | ✗ | △ 1개 | – | – | ✓ Strelka v2.8.4 +2 | – | ✓ Strelka v2.8.4 — HG002=tumor,… | – | 문서 | 모자이크/저빈도(VAF>5%) SNV 벤치마크. tumor-only 또는 HG003/HG004를 nor… |
| Mosaic SNV v1.10 | HG002 | Element도 유지해야 한다. externa… | 1 | ✗ | △ 1개 | – | – | ✓ Strelka v2.8.4 +2 | – | ✓ Strelka v2.8.4 — HG002=tumor,… | – | 문서 | 모자이크 SNV 벤치마크 최신판. v1.00 대신 이 판을 사용 |
| NIST v3.2 | HG002 | CG + Illumina + Ion + SOL… | 0 | ✗ | ✓ | ✓ novoalign +2 | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. 이력 참고용 |
| NIST v3.2.1 | HG002 | CG + Illumina + Ion + SOL… | 0 | ✗ | ✓ | ✓ novoalign +2 | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. 이력 참고용 |
| NIST v3.2.2 | HG002 | Illumina + CG + Ion + SOL… | 0 | ✗ | ✓ | ✗ | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. 이력 참고용 |
| NIST v3.3 | HG002 | CG + Illumina + Ion + SOL… | 0 | ✗ | ✓ | ✓ novoalign +2 | – | ✓ GATK HaplotypeCaller + freeba… +4 | – | – | – | 문서 | 구버전 truth set. supplementaryFiles의 AllRepeats/SimpleRepea… |
| NIST v3.3.2 | HG002 | Illumina 250x250/150bp/Ma… | 16 | ✗ | △ 1개 | ✓ GenomeWarp — 버전 미기재 | ✓ RTG vcfeval로 복합변이 표현 조정 후 AJ… | ✓ GATK HaplotypeCaller + freeba… +4 | – | – | – | 문서 | 구버전 truth set이지만 trio 위상 VCF와 콜러별 입력 VCF가 필요할 때 참조. 벤치마킹… |
| NIST v4.1 | HG002 | PacBio HiFi + 10X Genomics | 8 | ✗ | △ 9개 | – | – | ✓ DeepVariant + GATK + 10x Geno… | – | – | ✓ PacBio CCS 표적 이배체 어셈블리 + ONT/… | 문서 | draft truth set. v4.2.1로 대체되었으므로 이력 확인용 |
| NIST v4.2.1 | HG002 | PacBio HiFi + 10X Genomics | 8 | ✗ | ✓ | – | ✓ hifiasm v0.11 trio 어셈블리 dipca… +1 | ✓ pbsv 제외는 HG002에서 빼고 HG003/HG0… | – | – | ✓ hifiasm v0.11 | 문서 | 현행 HG002 GRCh37/GRCh38 소형변이 벤치마크. hap.py/rtg vcfeval base… |
| SV benchmark v0.6 + 평가결과 | HG002 | 다중 | 1 | ✗ | △ 122개 | – | – | ✓ 커뮤니티 30+ SV 콜러 union +3 | – | – | – | 문서 | HG002 SV 벤치마크 기준. truvari bench --includebed Tier1 BED로 내… |
| TandemRepeats v1.0 | HG002 | 미표기 | 0 | ✗ | ✓ | – | ✓ 모계/부계 하플로타입별 allele delta 컬럼… | ✓ adotto v0.1 변이 세트의 HG002 subs… | – | – | – | 문서 | 탠덤리피트 벤치마크. truvari bench --sizemin 5 --pick ac + truvari… |
| chrXY smallvar v1.0 | HG002 | 미표기(T2T 어셈블리 기반) | 0 | ✗ | △ 1개 | ✓ dipcall — 버전 미기재 | ✓ T2T 완성 어셈블리의 hap1/hap2 +1 | ✓ dipcall +1 | – | – | ✓ T2T-XY-v2.7 | 문서 | chrX/chrY 소형변이 벤치마크. 성염색체 성능 평가 baseline으로 사용(v4.2.1은 1-2… |
| latest(v4.2.1 미러) | HG002 | PacBio HiFi + 10X Genomics | 8 | ✗ | ✓ | – | ✓ hifiasm v0.11 trio 어셈블리 dipca… +1 | ✓ DeepVariant + GATK4 + 10x Gen… +1 | – | – | ✓ hifiasm v0.11 | 문서 | NISTv4.2.1과 동일 내용이므로 둘 중 하나만 받아 벤치마크 baseline으로 사용 |
| NIST v3.2.2 | HG003 | Illumina + CG + Ion | 0 | ✗ | ✓ | ✓ novoalign +1 | – | ✓ GATK HaplotypeCaller + freeba… +2 | – | – | – | 문서 | 구버전 truth set. 이력 참고용 |
| NIST v3.3 | HG003 | CG + Illumina + Ion + 10X | 0 | ✗ | ✓ | ✓ novoalign +1 | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. supplementaryFiles 반복영역 BED는 계층 분석에 재사용 가능 |
| NIST v3.3.2 | HG003 | Ion AmpliSeq Exome 추가. 콜셋… | 13 | ✗ | ✓ | ✓ novoalign +1 | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. HG002 trio 분석의 부모 콜셋으로만 참조 |
| NIST v4.2.1 | HG003 | PacBio HiFi + 10X Genomics | 7 | ✗ | △ 2개 | – | – | ✓ DeepVariant + GATK4 + 10x Gen… | – | – | – | 문서 | 현행 HG003 소형변이 벤치마크. hap.py/rtg vcfeval baseline 및 trio 멘델… |
| latest(v4.2.1 미러) | HG003 | PacBio HiFi + 10X Genomics | 7 | ✗ | △ 2개 | – | – | ✓ DeepVariant + GATK4 + 10x Gen… | – | – | – | 문서 | NISTv4.2.1과 동일 내용이므로 둘 중 하나만 받아 사용 |
| 루트 macOS 메타데이터 | HG003 | 해당없음 | 0 | ✗ | – | – | – | – | – | – | – | N/A | 다운로드 목록에서 제외 |
| NIST v3.2.2 | HG004 | Illumina + CG + Ion | 0 | ✗ | ✗ 1개 | ✓ novoalign +1 | – | ✓ GATK HaplotypeCaller + freeba… +2 | – | – | – | 문서 | 구버전 truth set. 이력 참고용 |
| NIST v3.3 | HG004 | CG + Illumina + Ion + 10X | 0 | ✗ | ✓ | ✓ novoalign +1 | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. 반복영역 BED만 재사용 가치 있음 |
| NIST v3.3.2 | HG004 | Illumina | 14 | ✗ | △ 1개 | ✓ novoalign +1 | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. HG002 trio 분석의 부모 콜셋으로만 참조 |
| NIST v4.2.1 | HG004 | PacBio HiFi + 10X Genomics | 7 | ✗ | △ 1개 | – | – | ✓ DeepVariant + GATK4 + 10x Gen… | – | – | – | 문서 | 현행 HG004 소형변이 벤치마크. hap.py/rtg vcfeval baseline 및 trio 부모… |
| latest(v4.2.1 미러) | HG004 | PacBio HiFi + 10X Genomics | 7 | ✗ | △ 1개 | – | – | ✓ DeepVariant + GATK4 + 10x Gen… | – | – | – | 문서 | NISTv4.2.1과 동일 내용이므로 둘 중 하나만 받아 사용 |
| 루트 macOS 메타데이터 | HG004 | 해당없음 | 0 | ✗ | – | – | – | – | – | – | – | N/A | 다운로드 목록에서 제외 |
| NIST v3.3 | HG005 | CG + Illumina + Ion + SOL… | 0 | ✗ | ✓ | ✓ novoalign +2 | – | ✓ GATK HaplotypeCaller + freeba… +3 | – | – | – | 문서 | 구버전 truth set. 반복영역 BED만 재사용 가치 있음 |
| NIST v3.3.2 | HG005 | Illumina 250x250/MatePair… | 16 | ✗ | △ 1개 | ✓ novoalign +1 | ✓ RTG vcfeval로 복합변이 표현 조정 후 Han… | ✓ GATK HaplotypeCaller + freeba… +4 | – | – | – | 문서 | 구버전 truth set. Chinese trio 위상 VCF가 필요할 때 참조. 벤치마킹은 v4.2.… |
| NIST v4.2.1 | HG005 | PacBio HiFi + 10X Genomics | 7 | ✗ | △ 7개 | – | ✓ trio-hifiasm dipcall VCF에서 위상… | ✓ DeepVariant + GATK4 + 10x Gen… +1 | – | – | ✓ hifiasm v0.11 | 문서 | 현행 HG005 소형변이 벤치마크. hap.py/rtg vcfeval baseline으로 사용하고 위상… |
| latest(v4.2.1 미러) | HG005 | PacBio HiFi + 10X Genomics | 7 | ✗ | △ 7개 | – | ✓ trio-hifiasm dipcall VCF에서 위상… | ✓ DeepVariant + GATK4 + 10x Gen… +1 | – | – | ✓ hifiasm v0.11 | 문서 | NISTv4.2.1과 동일 내용이므로 둘 중 하나만 받아 사용 |
| 루트 macOS 메타데이터 | HG005 | 해당없음 | 0 | ✗ | – | – | – | – | – | – | – | N/A | 다운로드 목록에서 제외 |
| NIST v3.3.2 | HG006 | Illumina HiSeq 100X + 6Kb… | 14 | ✗ | ✓ | ✗ | – | ✓ freebayes + Sentieon haplotyp… +1 | – | – | – | 문서 | 구버전 truth set. Chinese trio 분석의 부모 콜셋으로만 참조 |
| NIST v4.2.1 | HG006 | PacBio HiFi + 10X Genomics | 6 | ✗ | △ 8개 | – | – | ✓ DeepVariant + GATK4 + 10x Gen… | – | – | – | 문서 | 현행 HG006 소형변이 벤치마크. hap.py/rtg vcfeval baseline 및 Chinese… |
| latest(v4.2.1 미러) | HG006 | PacBio HiFi + 10X Genomics | 6 | ✗ | △ 8개 | – | – | ✓ DeepVariant + GATK4 + 10x Gen… | – | – | – | 문서 | NISTv4.2.1과 동일 내용이므로 둘 중 하나만 받아 사용 |
| NIST v3.3.2 | HG007 | Illumina HiSeq 100X + 6Kb… | 13 | ✗ | ✓ | ✓ novoalign; Complete Genomics… | – | ✓ freebayes + Sentieon haplotyp… +1 | – | – | – | 문서 | 구버전 truth set. Chinese trio 분석의 부모 콜셋으로만 참조 |
| NIST v4.2.1 | HG007 | PacBio HiFi + 10X Genomics | 6 | ✗ | △ 9개 | – | – | ✓ DeepVariant + GATK4 + 10x Gen… | – | – | – | 문서 | 현행 HG007 소형변이 벤치마크. hap.py/rtg vcfeval baseline 및 Chinese… |
| latest(v4.2.1 미러) | HG007 | PacBio HiFi + 10X Genomics | 6 | ✗ | △ 9개 | – | – | ✓ DeepVariant + GATK4 + 10x Gen… | – | – | – | 문서 | NISTv4.2.1과 동일 내용이므로 둘 중 하나만 받아 사용 |
| GIAB mapping references | 공용 | 해당없음(레퍼런스 자원) | 14 | ✗ | ✓ | – | – | – | – | – | – | 문서 | 모든 재처리의 매핑 레퍼런스로 사용. GRCh38은 maskedGRC_exclusions v2를 기본으… |
| Genome stratifications v2.0 | 공용 | 해당없음(참조 주석 트랙) | 2 | ✗ | – | – | – | – | – | – | – | 문서 | hap.py --stratification 용 계층 BED. 벤치마킹 결과를 난이도 구간별로 쪼갤 때… |
| Genome stratifications v3.0 | 공용 | 해당없음(참조 주석 트랙) | 4 | ✗ | – | – | – | – | – | – | – | 문서 | hap.py 계층 BED. v4.2.1 벤치마킹용 tsv(v3.0-GRCh3X-v4.2.1-strati… |
| Genome stratifications v3.1 | 공용 | 해당없음(참조 주석 트랙) | 5 | ✗ | – | – | – | – | – | – | – | 문서 | hap.py 계층 BED. CHM13v2.0 좌표계 벤치마킹이 필요하면 v3.1 이상 사용 |
| Genome stratifications v3.2 | 공용 | 해당없음(참조 주석 트랙) | 7 | ✗ | – | – | – | – | – | – | – | 문서 | hap.py 계층 BED. 카테고리별 생성 근거가 필요하면 같은 파이프라인의 v3.5 카테고리 READ… |
| Genome stratifications v3.3 | 공용 | 해당없음(참조 주석 트랙) | 7 | ✗ | – | – | – | – | – | – | – | 문서 | hap.py 계층 BED. validation/diagnostics.tsv로 계층 커버리지 온전성을 먼… |
| Genome stratifications v3.4 | 공용 | 해당없음(참조 주석 트랙) | 11 | ✗ | – | – | – | – | – | – | – | 문서 | hap.py 계층 BED. 어셈블리 좌표계 벤치마킹이 필요하면 v3.5의 mat/pat 판을 우선 검토 |
| Genome stratifications v3.5 | 공용 | 해당없음(참조 주석 트랙) | 22 | ✗ | – | – | – | – | – | – | – | 문서 | 최신 계층 BED. hap.py --stratification 으로 난이도 구간별 성능 산출에 사용하고… |

</details>

<details>
<summary><b>RNA-seq</b> — 20 datasets, 6,700 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Baylor PacBio Iso-Seq reads | HG002 | PacBio Sequel II/IIe | 20 | ✓ hifi_reads/BAM | ✗ 3개 | ✗ | – | – | – | – | – | 문서 | splice-aware 정렬을 직접 수행해야 함 — GIAB는 이 데이터에 정렬본을 제공하지 않는다 |
| Google Illumina mRNA/lncRNA | HG002 | Illumina (모델 미표기) | 160 | ✓ FASTQ | ✓ | ✓ STAR v2.6.1d +2 | – | – | – | – | – | 문서 | 같은 FASTQ를 자기 RNA 파이프라인으로 재정렬해 GIAB STAR 정렬본과 비교(정렬률·접합부 검… |
| Google PacBio Iso-Seq subreads | HG002 | PacBio Sequel IIe | 2,422 | ✓ subreads/BAM | ✗ 3개 | ✗ | – | – | – | – | – | 문서 | consensus basecalling으로 HiFi 리드를 먼저 만들어야 Iso-Seq 분석 가능. 2… |
| Mason ONT direct RNA | HG002 | ONT direct RNA (기기 미표기) | 28 | ✓ FASTQ | ✓ | ✓ Minimap2 v2.26-r1175 | – | – | – | – | – | 문서 | direct RNA 아이소폼 분석을 GIAB minimap2 정렬본과 나란히 돌려 비교(스파이크인 서열… |
| PacBio MAS-Seq (FLNC/Cluster) | HG002 | PacBio MAS-Seq (기기 미표기) | 171 | ✓ hifi_reads/subreads | ✓ | ✓ skera +3 | – | – | – | – | – | 문서 | FLNC BAM부터 재현 가능 — GIAB mapped BAM과 자기 collapse 결과를 아이소폼… |
| UNC Illumina mRNA/totalRNA | HG002 | Illumina (모델 미표기) | 1,100 | ✓ FASTQ | – | ✗ | – | – | – | – | – | N/A | 정렬·정량 전 과정을 직접 수행. 3반복 설계라 자기 파이프라인의 재현성 평가에 쓰기 좋다 |
| Baylor PacBio Iso-Seq reads | HG004 | PacBio Sequel II/IIe | 6 | ✓ hifi_reads/BAM | ✗ 1개 | ✗ | – | – | – | – | – | 문서 | splice-aware 정렬부터 직접 수행. 문서 파일목록을 신뢰하지 말고 실제 movie 1건만 있음… |
| Google Illumina mRNA/lncRNA | HG004 | Illumina (모델 미표기) | 49 | ✓ FASTQ | ✓ | ✓ STAR v2.6.1d +2 | – | – | – | – | – | 문서 | 같은 FASTQ를 자기 파이프라인으로 재정렬해 GIAB STAR 정렬본과 비교 |
| Google PacBio Iso-Seq subreads | HG004 | PacBio Sequel IIe | 921 | ✓ subreads/BAM | ✗ 1개 | ✗ | – | – | – | – | – | 문서 | consensus basecalling 후 Iso-Seq 분석. 용량 대비 이득 먼저 판단 |
| Mason ONT direct RNA | HG004 | ONT direct RNA (기기 미표기) | 10 | ✓ FASTQ | ✓ | ✓ Minimap2 v2.26-r1175 | – | – | – | – | – | 문서 | GIAB 정렬본과 비교하며 direct RNA 아이소폼 분석(스파이크인 제외 처리 필요) |
| PacBio MAS-Seq (FLNC/Cluster) | HG004 | PacBio MAS-Seq (기기 미표기) | 55 | ✓ BAM | ✓ | ✓ skera +3 | – | – | – | – | – | 문서 | FLNC BAM부터 재현 가능 — analysis 디렉토리의 collapse 결과와 대조 |
| UNC Illumina mRNA/totalRNA | HG004 | Illumina (모델 미표기) | 350 | ✓ FASTQ | – | ✗ | – | – | – | – | – | N/A | 정렬·정량 전 과정을 직접 수행(반복 3회 설계로 재현성 평가 가능) |
| Chinese MAS-Seq collapse/Pigeon | HG005 | PacBio MAS-Seq (기기 미표기) | 7 | ✗ | – | – | – | – | – | – | – | 문서 | Pigeon 분류 결과를 HG005 아이소폼 카탈로그 기준선으로 사용. 재현은 HG005 3-Clust… |
| Baylor PacBio Iso-Seq reads | HG005 | PacBio Sequel II/IIe | 7 | ✓ hifi_reads/BAM | ✗ 1개 | ✗ | – | – | – | – | – | 문서 | splice-aware 정렬부터 직접 수행 |
| Google Illumina mRNA/lncRNA | HG005 | Illumina (모델 미표기) | 53 | ✓ FASTQ | ✓ | ✓ STAR v2.6.1d +2 | – | – | – | – | – | 문서 | 같은 FASTQ를 재정렬해 GIAB STAR 정렬본과 비교 |
| Google PacBio Iso-Seq subreads | HG005 | PacBio Sequel IIe | 875 | ✓ subreads/BAM | ✗ 1개 | ✗ | – | – | – | – | – | 문서 | consensus basecalling 후 Iso-Seq 분석. 용량 대비 이득 먼저 판단 |
| Mason ONT direct RNA | HG005 | ONT direct RNA (기기 미표기) | 3 | ✓ FASTQ | ✓ | ✓ Minimap2 v2.26-r1175 | – | – | – | – | – | 문서 | GIAB 정렬본과 비교하며 direct RNA 아이소폼 분석 |
| PacBio MAS-Seq (FLNC/Cluster) | HG005 | PacBio MAS-Seq (기기 미표기) | 57 | ✓ BAM | ✓ | ✓ skera +3 | – | – | – | – | – | 문서 | FLNC BAM부터 재현 가능 — ChineseTrio/analysis collapse 결과와 대조 |
| UNC Illumina mRNA/totalRNA | HG005 | Illumina (모델 미표기) | 374 | ✓ FASTQ | – | ✗ | – | – | – | – | – | N/A | 정렬·정량 전 과정을 직접 수행 |
| Ashkenazim MAS-Seq collapse/Pigeon | 공용 | PacBio MAS-Seq (기기 미표기) | 30 | ✗ | – | – | – | – | – | – | – | 문서 | Pigeon 분류 결과를 HG002/HG004 아이소폼 기준선으로 사용. 재현은 각 샘플 3-Clust… |

</details>

<details>
<summary><b>Trio-level analysis</b> — 9 datasets, 59 GiB</summary>

| 데이터셋 | 샘플 | 플랫폼 | GiB | 리드 | index | 정렬 | 페이징 | 변이 | 메틸 | somatic | 어셈블리 | 출처 | 다음 할 일 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| BGISEQ 100x 벤더 QC 리포트 | HG002 | BGISEQ 2x150bp | 0 | ✗ | – | ✗ | – | ✗ | – | – | – | 문서 | 벤더 QC 리포트 열람용. 실제 VCF가 필요하면 data/AshkenazimTrio/analysis/… |
| chrXY GATK 콜셋 (Illumina) | HG002 | Illumina (ILMN, 모델 미표기) | 0 | ✗ | ✗ 6개 | ✗ | – | ✓ GATK | – | – | – | 파일명 | chrXY 벤치마크 개발 과정의 참고 콜셋. 문서·파라미터가 불명이라 평가 기준으로 쓰지 말고 비교 참… |
| chrXY GATK 콜셋 (PacBio HiFi) | HG002 | PacBio HiFi (기기 미표기) | 0 | ✗ | ✗ 6개 | ✗ | – | ✓ GATK | – | – | – | 파일명 | 참고용 비교 콜셋으로만 사용. 정식 평가 기준이 필요하면 release 쪽 chrXY v1.0 벤치마크… |
| draft benchmark defrabb v0.012 | HG002 | 미표기(T2T-Q100 어셈블리 기반) | 8 | ✗ | ✓ | ✓ dipcall v0.3 — defrabb v0.012… | – | ✓ dipcall v0.3 +1 | – | – | – | 문서 | 자기 콜셋 평가용 draft 벤치마크(smvar/stvar VCF+BED 쌍). 문서 권고대로 소변이는… |
| draft benchmark defrabb v0.015 | HG002 | 미표기(T2T-Q100 어셈블리 기반) | 7 | ✗ | ✓ | ✓ dipcall v0.3 — defrabb v0.015… | – | ✓ dipcall v0.3 +1 | – | – | – | 문서 | v0.012 대신 이 버전을 벤치마크 기준선으로 사용. SV 비교는 truvari refine(문서 권… |
| draft benchmark defrabb v0.018 | HG002 | 미표기(T2T-Q100 어셈블리 기반) | 9 | ✗ | ✓ | ✓ dipcall v0.3 — defrabb v0.018… | – | ✓ dipcall v0.3 +1 | – | – | – | 문서 | 소변이는 hap.py --engine vcfeval(--gender male), SV는 truvari… |
| draft benchmark defrabb v0.019 | HG002 | 미표기(T2T-Q100 어셈블리 기반) | 10 | ✗ | ✓ | ✓ dipcall v0.3 — defrabb v0.019… | – | ✓ dipcall v0.3 +1 | – | – | – | 문서 | 이 버전을 HG002 draft 벤치마크 기준선으로 확정하고, hap.py --engine vcfeva… |
| BGISEQ 100x 벤더 QC 리포트 | HG005 | BGISEQ 2x150bp | 0 | ✗ | – | ✗ | – | ✗ | – | – | – | 문서 | 벤더 QC 리포트 열람용. VCF가 필요하면 data/ChineseTrio/analysis/NIST_B… |
| Ashkenazim trio Revio WGS WDL 결과 | 공용 | PacBio Revio HiFi | 26 | ✗ | ✓ | ✗ | ✓ HiPhase | ✓ DeepVariant + pbsv +2 | ✓ pb-CpG-tools | – | – | 문서 | GIAB DeepVariant/pbsv/HiPhase 산출물을 그대로 트리오 비교·메틸 분석에 사용.… |

</details>

<!-- MASTER-TABLE:END -->

## 이 표가 만들어진 방식

숫자와 툴 이름을 분리해서, 각각 다른 근거로 채웠다.

**결정론적으로 계산한 것** — 파일 개수, 바이트, index 존재 여부, 파일 종류 분포.
`phase0_download/manifests/`의 76,595행을 스크립트로 집계했다. 330개 데이터셋 prefix가
매니페스트 전체를 빠짐없이, 중복 없이 덮는다 (미매칭 0건).

**GIAB 공식 문서에서 확인한 것** — 툴 이름과 버전, 파이프라인, 처리 주체.
매니페스트에 있는 GIAB README 514개를 S3/FTP에서 전부 받아 본문을 근거로 삼았다.
예를 들어 HG002 Revio의 `align_tool`은 파일명만으로는 알 수 없었고,
공식 README의 다음 문장에서 나왔다.

> Mapping was performed using pbmm2 v1.10.0 ... as part of the PacBio HiFi-human-WGS_WDL (germline) pipeline v1.1.0

**추측하지 않은 것** — "Illumina니까 BWA를 썼을 것" 같은 상식 추론은 넣지 않았다.
파일명에도 없고 공식 문서에도 없으면 `N/A`다. `N/A`는 조사 실패가 아니라 정직한 값이다.

분류와 출처 조사는 각각 독립된 검증 에이전트가 원문 대조로 재확인했다. 검증에서 잡힌
수정 사항과 반증 내역은 [docs/reference/catalog_evidence.md](docs/reference/catalog_evidence.md)에 있다.

## 주의

GIAB는 같은 장비의 원시 데이터와 분석 결과를 **다른 디렉토리에 나눠 둔다.**
예를 들어 HG008 PacBio Revio의 VCF는 `pacbio_hifi` 쪽이 아니라 `other` 쪽
(`data_somatic/HG008/Liss_lab/analysis/`)에 있다. 카테고리 하나만 보면 놓치므로,
데이터를 찾을 때는 카테고리가 아니라 이 표의 `giab_path`로 확인할 것.
