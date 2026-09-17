# Phase 0 — 데이터 다운로드

GIAB 원시 데이터 + truth set을 nbb2로 받는 단계. 대상 목록은 `manifests/`가 전부다.
**총 81,302 files / 125.1 TB** (2026-08-13 S3 목록 + `current.tree` 기반 HEAD 검증 → 2026-09-16 FTP `release/`·`data/` 라이브 크롤로 재대조. 아래 [release/ 갱신](#release-갱신-2026-09-16), [data/ 갱신](#data-갱신-2026-09-16)). 2026-09-17에 받지 않기로 한 3건(12,423 files / 10.7 TiB)은 미포함 — [manifests/declined_by_decision.tsv](manifests/declined_by_decision.tsv).

데이터셋별 처리 현황은 저장소 루트 [README.md](../README.md)의 master table 참고.

## Quick start (nbb2 로그인 노드)

계산 노드(shepherd-1-9)는 외부 egress가 없다(2026-08-13 netcheck 확인). 다운로드는 로그인 노드에서 돌린다.
로그인 노드 실측: s3 단일 스트림 57 MB/s, wget 17 MB/s.

```bash
git clone https://github.com/ehojune/GIAB_benchmarking.git && cd GIAB_benchmarking
mkdir -p logs
screen -S giab
JOBS=12 bash phase0_download/scripts/run_priority.sh 2>&1 | tee logs/run_priority.log
```

`run_priority.sh`는 release → pacbio_hifi → ont → pacbio_clr → 나머지 순으로 받는다.
screen 나오기 `Ctrl-A d`, 다시 붙기 `screen -r giab`.

로그 위치가 두 곳으로 갈린다. 전체 진행은 위 `tee`가 쓰는 저장소 루트 `logs/run_priority.log`,
카테고리별 상세는 스크립트가 쓰는 `phase0_download/logs/<category>.log`
(`run_priority.sh`가 `REPO_DIR/logs`에 쓰고, `REPO_DIR`이 이 폴더다).

```bash
./phase0_download/scripts/verify.sh all
```

- 노드 자원·진행 현황: `bash phase0_download/scripts/status.sh`
- 중단: `bash phase0_download/scripts/stop_downloads.sh` 후 원하는 `JOBS=`로 재시작
- 일부만: `CATEGORIES="release pacbio_hifi ont" nohup bash phase0_download/scripts/run_priority.sh ... &`
- 단발 실행: `TOOL=s3 JOBS=8 ./phase0_download/scripts/download.sh pacbio_hifi HG002`
- 샘플 지정: `./phase0_download/scripts/download.sh ont HG002 HG005`
- 미완료 파일 나열: `MISSING=1 ./phase0_download/scripts/verify.sh pacbio_hifi`
- aws가 PATH에 없으면 `/BiO/home/program/awscli/bin/aws`를 자동 사용 (`AWS_BIN=경로`로 변경)
- `scripts/sge_download.sh`는 계산 노드에 egress가 생기면 쓸 SGE 제출용. 현재는 사용 불가

기본 저장 위치는 `/BiO/scratch/ehojune/GIAB_benchmark` (변경: `DEST=...`). GIAB 원본 디렉토리 구조를 그대로 유지한다
(`data/AshkenazimTrio/HG002_.../PacBio_CCS_15kb/...`). 크기가 일치하는 기존 파일은 건너뛰므로 중단 후 재실행이 안전하다.
이미 wget으로 받아둔 파일은 같은 경로 구조로 옮겨두면 자동 스킵된다.

## 용량 및 예상 시간

실측 **s3 83 MB/s ≈ 7.2 TB/일** (JOBS=12, 2026-08-13). wget 단일 스트림은 17 MB/s ≈ 1.4 TB/일.

| category | TB | days @83MB/s |
|---|---|---|
| pacbio_hifi (HG009 포함) | 10.3 | 1.4 |
| ont | 12.7 | 1.8 |
| pacbio_clr | 14.4 | 2.0 |
| rnaseq (HG002/4/5 data_RNAseq + HG008/HG009 RNA-seq) | 7.5 | 1.0 |
| illumina_wgs | 29.8 | 4.2 |
| bgi_mgi | 6.2 | 0.9 |
| linked_reads (10X, stLFR) | 4.9 | 0.7 |
| exome | 1.0 | 0.1 |
| complete_genomics | 16.0 | 2.2 |
| other (BioNano, Strand-seq, HiC, AVITI, UG100, 단일세포, somatic 분석 등) | 21.8 | 3.0 |
| release (truth set, stratifications, references) | 0.3 | 0.0 |
| trio_analysis (HG002 T2T-Q100 draft benchmark 등) | 0.1 | 0.0 |
| **전체** | **125.1** | **17.4** |

샘플 × 카테고리 (GiB):

| sample | pacbio_hifi | ont | pacbio_clr | illumina_wgs | bgi_mgi | linked_reads | exome | complete_genomics | other | TOTAL | days@83MB/s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| HG001 | 386 | 329 | 211 | 2,003 | 1,014 | 1,542 | 123 | 2,087 | 1,138 | 8,833 | 1.3 |
| HG002 | 1,643 | 3,242 | 4,502 | 3,179 | 1,726 | 659 | 225 | 1,805 | 3,022 | 20,005 | 3.0 |
| HG003 | 1,170 | 896 | 2,686 | 3,141 | 395 | 572 | 199 | 1,854 | 515 | 11,426 | 1.7 |
| HG004 | 1,023 | 917 | 2,549 | 3,487 | 564 | 529 | 214 | 1,747 | 555 | 11,585 | 1.7 |
| HG005 | 611 | 527 | 1,731 | 3,299 | 1,655 | 429 | 216 | 3,660 | 1,342 | 13,470 | 2.0 |
| HG006 | 442 | 470 | 861 | 1,244 | 192 | 422 | - | 1,859 | 6 | 5,497 | 0.8 |
| HG007 | 424 | 382 | 849 | 1,271 | 209 | 431 | - | 1,867 | 8 | 5,441 | 0.8 |
| HG008 (T + N-D + N-P) | 2,396 | 5,109 | - | 6,660 | - | - | - | - | 13,330 | 27,496 | 4.1 |
| HG009 (T + N) | 1,542 | - | - | 3,471 | - | - | - | - | 412 | 5,424 | 0.8 |

- HG008 other(13,330 GiB = 13.0 TiB) 구성: Element AVITI 4.9, Ultima UG100 1.9, PacBio Onso 1.2, analysis 2.1(Verkko는 어셈블리 결과 0.19만), superseded 2022 데이터 1.73, NIST 트리 단일세포·Hi-C·somatic 분석 1.0, Dovetail LinkPrep 0.2 TiB. 2026-09-17 결정으로 Verkko 작업 디렉토리 1.28과 superseded raw 1.63 TiB는 빠져 있다
- HG008은 T/N-D/N-P, HG009는 T(bulk p16·p42 + 클론 6종)/N(WT-p4·p25, LVTert-p23)이 파일명으로 구분됨
- HG009는 PacBio HiFi Revio(1.5 TiB) + 2026-09 크롤로 추가된 BCM NovaSeq X 125x WGS(3.4 TiB)·LinkPrep Hi-C·RNA-seq·핵형·sarek somatic 분석 (950 files / 5.3 TiB)

플랫폼 디렉토리 단위 정확 바이트는 [docs/SIZES.md](../docs/SIZES.md) 참고 (조회용).

## 속도: wget보다 빠르게 받는 법

| 방법 | 예상 효과 | 비고 |
|---|---|---|
| `TOOL=s3` (aws cli) | 파일당 병렬 multipart, 보통 수 배 | **권장.** 공식 미러 `s3://giab`, `--no-sign-request`라 계정 불필요 |
| `JOBS=4` (파일 단위 병렬) | 단일 스트림 한계 우회, 2–4배 | wget/aria2/s3 모두 적용 |
| `TOOL=aria2` | 파일당 4커넥션 | aws cli가 없을 때 차선 |
| aspera (ascp) | 불확실 | NCBI가 aspera 지원을 축소 중. S3 경로가 확실함 |

```bash
TOOL=s3 JOBS=4 ./phase0_download/scripts/download.sh pacbio_hifi
```

## manifests 구조

- `manifests/<SAMPLE>/<category>.tsv` — `상대경로<TAB>bytes`. 다운로드 대상의 전부 (HG001~HG009)
- `manifests/release_truthsets.tsv` — truth set VCF/BED, stratification, reference (전체 버전 포함). **FTP `release/` 라이브 크롤로 유지** (`scripts/crawl_release.py`, 2026-09-16 기준 7,989 files / 318.2 GiB)
- `manifests/release_stale_ftp_removed.tsv` — FTP에서 사라져 manifest에서 뺀 항목(경로, 바이트, 확인일). 로컬에는 남아 있음
- `manifests/declined_by_decision.tsv` — **발견했지만 받지 않기로 한 데이터**(경로, 바이트, 그룹). 2026-09-17 결정, 12,423 files / 10.69 TiB.
  어떤 manifest에도 없고 `crawl_data.py`가 이 목록을 읽어 다시 넣지 않는다. 3열이라 `download.sh`에 직접 먹이면 안 된다 — 마음이 바뀌면 아래 '받지 않기로 한 데이터' 참고
- `manifests/data_unrouted_new.tsv` — data/ 크롤이 카탈로그 행 없이 만난 신규 파일. 처리하면 사라진다(현재 없음). `catalog_new_dirs.py` → `crawl_data.py --route-all` 로 manifest에 넣는다
- `manifests/rnaseq_all.tsv` — `data_RNAseq/` 전체 (HG002·HG004·HG005) + 2026-09-16 추가된 HG008·HG009 RNA-seq(`data_somatic/` 하위, UMD·BCM). `all`에는 미포함, run_priority에는 포함
- `manifests/trio_analysis.tsv` — trio 레벨 analysis (HG002 T2T-Q100 draft benchmark defrabb 등, 325 files / 59 GiB). `all`에는 미포함, run_priority에는 포함

헤더 없음. 1열이 GIAB 상대경로, 2열이 바이트.

### S3 미러 누락 주의 (2026-08-13 확인)

S3 미러는 FTP보다 불완전하다. (2026-09-16 추가: 반대 방향도 있다 — FTP에서 사라졌지만 S3에는 남은 파일 2,173건, FTP 사본만 재압축돼 크기가 다른 Illumina FASTQ 7,122건. 상세는 [data/ 갱신](#data-갱신-2026-09-16).) FTP `current.tree` + 신규 디렉토리 라이브 크롤과 S3 실시간 목록을 대조한 결과
아래는 **FTP에만 존재**한다 (전부 파일별 HEAD로 실존·크기 검증 후 manifest 반영).

| 누락 데이터 | 용량 |
|---|---|
| RNA-seq Illumina(UNC·Google), Iso-Seq, Baylor HiFi RNA | 6.3 TiB |
| HG009 전체 (PacBio HiFi Revio, 2026-07 신규) | 1.5 TiB |
| HG008 확장: other_passages(p2·p13 ILMN/ONT), N-D ILMN WGS 2025-11, N-P Dovetail LinkPrep | 2.0 TiB |
| Element AVITI 2024-09 (HG001·HG003~HG005) + HG002B Phase Genomics Hi-C | 2.5 TiB |
| HG001 PacBio CCS haplotagged BAM, trio analysis, release 구버전 등 | 0.5 TiB |

`TOOL=s3`에서 S3에 없는 파일은 자동으로 FTP(wget)로 대체된다 (`download.sh` fallback).
manifest 자체가 FTP 검증 기준이므로 중단 후 재실행하면 누락분까지 전부 받아진다.

## release/ 갱신 (2026-09-16)

GIAB `current.tree`는 **2025-02-27 이후 갱신되지 않는다**(Last-Modified 확인). 그래서 2026-08-13 manifest에는
그 뒤 올라온 벤치마크가 통째로 빠져 있었다. `release/`는 이제 FTP 디렉토리 인덱스를 직접 크롤해 맞춘다.

```bash
python phase0_download/scripts/crawl_release.py            # 크롤 → manifest 재작성 → docs/reference/release_crawl_<날짜>.md (같은 날 재실행은 _2, _3…)
python phase0_download/scripts/crawl_release.py --dry-run  # 보고서만, logs/crawl_cache/ 에 쓴다
```

파일별 HEAD로 정확한 바이트를 받는다(인덱스 크기는 반올림). 동시성은 3+4 스레드 — 더 올리면 NCBI가 503을 준다.
Apache 인덱스가 숨기는 dotfile(`.DS_Store`, `._*` 394건)은 옛 manifest 항목을 HEAD로 확인해 유지한다.
`logs/crawl_cache/`에 목록·크기를 캐시하므로 중단 후 재실행은 이어서 한다(`--fresh`로 무시).

2026-09-16 대조 결과 — 기준은 2026-08-13 manifest(커밋 `2fe9c2b`, 6,464 files / 285.2 GiB), 현재 FTP 7,989 files / 318.2 GiB ([상세](../docs/reference/release_crawl_2026-09-16.md)):

| 변화 | 파일 | GiB | 내용 |
|---|---|---|---|
| 추가 | 1,577 | 41.4 | HG002 **v5.0q**(Q100 v1.1 어셈블리 기반 smvar+stvar, 52 files 9.4 GiB) + 그 `latest/` 복사본(52 files 9.4 GiB) · **stratifications v3.6**(1,471 files 22.5 GiB) · mosaic_v1.10에 MosaicSNVv1.1 VCF 2건 |
| 제거 | 52 | 8.4 | HG002 `latest/`의 v4.2.1 파일 51건(latest가 2026-05-27 v5.0q로 교체됨) + `references/GRCh38/README_GIAB_Mapping_References.md.txt` |
| 크기 변경 | 8 | - | README·checksum·regions-md5s 류 문서 파일만 |

받기: 로그인 노드에서 `TOOL=s3 JOBS=4 bash phase0_download/scripts/download.sh release` — 기존 파일은 크기 일치로 건너뛰고 새 1,577건(41.4 GiB)만 받는다.
S3 미러에 없는 파일은 FTP로 자동 대체된다. 로컬 HG002 `latest/`에는 v4.2.1과 v5.0q가 공존하므로 평가는 `NISTv4.2.1/`·`v5.0q/`를 직접 지정한다.

이 스크립트는 `release/` 전용이다(release/ 밖 `ROOT`는 거부). `data/`·`data_somatic/`·`data_RNAseq/`는 샘플별 manifest로 나뉘어 있어 별도 도구가 필요하고, 이번에 크롤하지 않았다.

## data/ 갱신 (2026-09-16)

`data/`·`data_somatic/`·`data_RNAseq/`도 FTP 인덱스를 직접 크롤해 맞춘다. 파일이 8만 개라 전부 HEAD하지 않고,
인덱스의 수정일·근사 크기로 신규/변경 후보만 골라 HEAD한다(`scripts/crawl_data.py`).

```bash
python phase0_download/scripts/crawl_data.py --dry-run     # 보고서만 (logs/crawl_cache/)
python phase0_download/scripts/crawl_data.py               # 기존 디렉토리의 신규 파일은 manifest에 바로 넣고, 새 디렉토리는 data_unrouted_new.tsv에
python phase0_download/scripts/catalog_new_dirs.py         # 새 디렉토리마다 카탈로그 행 생성(플랫폼 이름 패턴 → category). 기존 행의 files/size도 실측으로 재계산
python phase0_download/scripts/crawl_data.py --route-all   # 캐시로 재실행 → 새 행의 파일을 manifest에 반영
```

2026-09-16 결과 ([발견](../docs/reference/data_crawl_2026-09-16.md) · [반영](../docs/reference/data_crawl_2026-09-16_2.md)):

| 변화 | 파일 | TiB | 내용 |
|---|---|---|---|
| 기존 디렉토리에 추가 | 273 | 0.12 | HG008 Liss_lab analysis 하위(HKU ClairS 0.4.1, Hartwig OncoAnalyser, Lancet2 등), BGISEQ QC 리포트 |
| 새 디렉토리 → 카탈로그 행 102개 | 7,104 | 11.4 | HG008 NIST 트리(T_bulk p21/p41/p100/p103 + 클론 8종: BCM NovaSeq X WGS·Revio SPRQ·somatic 분석·ResolveOME·Tapestri·10x Multiome·Hi-C·RNA-seq·핵형), HG009 신규(NovaSeq X 125x WGS·LinkPrep Hi-C·RNA-seq·핵형·sarek 분석), HG008 Verkko 작업 디렉토리 1.28, superseded 2022 raw 1.63, HG002 defrabb v0.011·v0.020 |
| 그중 받지 않기로 한 것 (2026-09-17) | 12,423 | 10.69 | 아래 '받지 않기로 한 데이터' 절. 카탈로그·manifest에서 빠졌다 |
| FTP에서만 사라짐 — S3에 있어 유지 | 2,173 | 12.3 | PacBio_MtSinai_NIST·PacBio_CLR·SOLiD·Strand-Seq EMBL·BioNano DLE·HiC_UCSC·CG normal 등. 이미 로컬에 있음 |
| FTP 사본 크기만 다름 — 유지 | 7,122 | - | Illumina HiSeq 300x/2x250/mate-pair FASTQ. FTP 사본이 S3보다 ~14% 작음(재압축). manifest는 S3 기준 |
| 양쪽 미러에서 사라짐 | 0 | 0 | |

**FTP와 S3 미러는 양방향으로 어긋난다.** download.sh는 S3를 먼저 쓰고 manifest 크기는 S3 기준으로 검증된 것이므로,
크롤러는 FTP와 어긋난 기존 항목을 S3에 HEAD해 S3가 manifest와 맞으면 그대로 둔다. FTP만 보고 갱신했다면 7,122 파일이
전부 크기 불일치로 재다운로드됐을 것이다.

2026-08-13 목록이 이렇게 많이 빠진 이유: 그 목록은 S3 실시간 목록이 주였고, HG008 NIST 트리·Verkko·HG009 신규처럼
FTP에만 있는 것은 `current.tree`(2025-02 정지) 에 없어 보이지 않았다. 신규 게시(2026-08-13 이후 수정)는 713 파일뿐이고
나머지는 그 전부터 FTP에 있었다.

받기: `TOOL=s3 JOBS=8 bash phase0_download/scripts/run_priority.sh` 를 다시 돌리면 신규분만 받는다(기존은 크기 일치로 스킵).
제외 결정 반영 후 실제 내려받을 양은 **4,759 files / 8.67 TiB** (release 1,577 files / 41.4 GiB + data 3,182 files / 8.63 TiB).
2026-08-30 완료 시점(커밋 `2fe9c2b`, 76,595 files / 105.11 TiB)과 현재 manifest(81,302 files / 113.78 TiB)를 파일 단위로 대조한 값이다.
크기가 바뀌어 다시 받는 파일은 8건(문서류, 44 KB), manifest에서 빠졌지만 디스크에 남는 파일은 52건이다.

**S3 미러에 신규 데이터가 없다** (2026-09-17 표본 96건 중 1건만 200, 용량 상위 25건은 0건).
`TOOL=s3`이어도 거의 전부 `S3 miss → FTP fallback` 으로 wget을 타므로 실측 83 MB/s가 아니라 FTP 속도로 계산해야 한다.
JOBS를 8~12로 두고 하루 단위가 아니라 며칠을 잡는 편이 맞다. 로그에서 `S3 miss` 줄 수로 확인할 수 있다.

## 받지 않기로 한 데이터 (2026-09-17)

2026-09-16 크롤이 찾았지만 사용자가 받지 않기로 결정한 3건이다. 목록은 [manifests/declined_by_decision.tsv](manifests/declined_by_decision.tsv)
(경로·바이트·그룹). 어떤 manifest에도 없고 `crawl_data.py`가 이 목록을 읽어 다시 넣지 않는다.

| 그룹 | 파일 | TiB | 왜 안 받나 |
|---|---|---|---|
| `legacy-trio-analysis` | 8,228 | 7.78 | `data/*/analysis/` 2014~2020 trio 레벨 분석 107 디렉토리(10X LongRanger/Supernova 어셈블리 5.4, DISCOVAR 0.8, CG 콜셋 등). 카탈로그 행이 없고 현재 작업과 무관 |
| `hg008-superseded-2022-raw` | 26 | 1.63 | `superseded-2022-data/BCM_Illumina_WGS_20220816/`. GIAB이 superseded로 표시했고, **이미 받은 `BCM_ILMN-somatic-analysis_20220816/`와 파일명·크기가 전부 같은 중복**이다 |
| `hg008-verkko-workdirs` | 4,169 | 1.28 | Verkko 2.2/2.2.1 작업 디렉토리의 중간 산출물(.sh/.red/.range 등). 어셈블리 결과 353 files / 197.5 GiB는 그대로 보유 |
| **합계** | **12,423** | **10.69** | |

마음이 바뀌면 그룹을 2열 manifest로 뽑아 이름으로 받는다:

```bash
awk -F'	' '$3=="legacy-trio-analysis"{print $1"	"$2}' phase0_download/manifests/declined_by_decision.tsv   > phase0_download/manifests/legacy_trio_analysis.tsv
TOOL=s3 JOBS=8 bash phase0_download/scripts/download.sh legacy_trio_analysis
```

## 경로 변경 이력

2026-08-19에 `scripts/`와 `manifests/`가 이 폴더로 들어왔다. 스크립트는 `REPO_DIR="$(dirname $0)/.."`로
자기 위치를 잡으므로 내부 경로 수정은 없었다.

### 다운로드 도중에 pull 할 때

`run_priority.sh`는 카테고리마다 `"$REPO_DIR/scripts/download.sh"`를 **경로로 호출**한다.
옛 경로로 띄운 실행 중에 pull하면 그 경로가 사라지는데, `set -uo pipefail`에 `-e`가 없어서
**루프가 죽지 않고 남은 카테고리를 조용히 건너뛰고 `ALL DONE`을 찍는다.** 셋 중 하나를 택한다.

1. **지금 pull 안 하기** — 다운로드에 새 구조가 필요 없다. 끝난 뒤 pull. 손실 0.
2. **심링크로 옛 경로 살리기** — 손실 0, pull 가능. 한 줄로 실행해 틈을 없앤다.
   ```bash
   git pull && ln -sfn phase0_download/scripts scripts && ln -sfn phase0_download/manifests manifests
   ```
   다운로드가 끝나면 `rm scripts manifests`로 심링크만 지운다.
3. **멈추고 재시작** — `stop_downloads.sh` → `git pull` → 새 경로로 재시작.
   `TOOL=s3`은 `aws s3 cp`가 `.part` 없이 최종 파일명에 직접 쓰므로 **이어받기가 안 된다.**
   전송 중이던 `JOBS`개 파일은 처음부터 다시 받는다 (완료된 파일은 크기 일치로 건너뜀).
   PacBio HiFi처럼 파일이 40–120 GiB인 카테고리면 재전송이 수백 GiB가 될 수 있으니
   `tail -3 logs/run_priority.log`로 어느 카테고리인지 먼저 확인할 것.

`stop_downloads.sh`의 패턴 `'scripts/download.sh'`는 새 경로
`phase0_download/scripts/download.sh`에도 포함되므로 이동 후에도 그대로 작동한다.
