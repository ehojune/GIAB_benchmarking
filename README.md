# GIAB benchmark data download

GIAB 샘플(HG001–HG007 germline + HG008 tumor-normal) 원시 데이터 + truth set 다운로드용 스크립트.
파일 목록과 크기는 2026-08-13에 공식 미러 `s3://giab`에서 직접 조회한 값 (NCBI FTP와 동일 내용, 총 71,767개 파일).
샘플·플랫폼 개요는 `GIAB_HG_Catalog.xlsx` (전종범 박사님 정리본) 참고.

## Quick start (nbb2 로그인 노드)

계산 노드(shepherd-1-9)는 외부 egress가 없어(2026-08-13 netcheck로 확인) 다운로드는 로그인 노드에서 돌린다.
로그인 노드 실측: s3 단일 스트림 57 MB/s (wget 17 MB/s).

```bash
git clone https://github.com/ehojune/GIAB_benchmarking.git && cd GIAB_benchmarking
mkdir -p logs
screen -S giab                                                    # 이후 명령은 screen 안에서
JOBS=12 bash scripts/run_priority.sh 2>&1 | tee logs/run_priority.log   # release → hifi → ont → clr → 나머지 순차
# 나오기: Ctrl-A d / 다시 붙기: screen -r giab / 카테고리별 로그: logs/<category>.log
./scripts/verify.sh all                                           # 진행률/크기 검증 (screen 밖에서)
```

- 노드 자원·다운로드 현황: `bash scripts/status.sh` / 중단: `bash scripts/stop_downloads.sh` 후 원하는 `JOBS=`로 재시작
- 일부만 받으려면: `CATEGORIES="release pacbio_hifi ont" nohup bash scripts/run_priority.sh ... &`
- 단발 실행: `TOOL=s3 JOBS=8 ./scripts/download.sh pacbio_hifi HG002`
- aws는 PATH에 없으면 `/BiO/home/program/awscli/bin/aws`를 자동 사용 (`AWS_BIN=경로`로 변경)
- `scripts/sge_download.sh`는 계산 노드에 egress가 생기면(프록시 등) 쓸 수 있는 SGE 제출용, 현재는 사용 불가

- 기본 다운로드 위치: `/BiO/scratch/ehojune/GIAB_benchmark` (변경: `DEST=... ./scripts/download.sh ...`)
- GIAB 원본 디렉토리 구조 그대로 저장됨 (`data/AshkenazimTrio/HG002_.../PacBio_CCS_15kb/...`)
- 크기가 일치하는 기존 파일은 건너뛰므로 중단 후 재실행 안전. 샘플 지정 가능: `./scripts/download.sh ont HG002 HG005`
- 이미 wget으로 받아둔 HiFi 파일은 위 경로 구조로 옮겨두면 자동 스킵됨

## 용량 및 예상 시간

환산: 17 MB/s ≈ **1 GiB/분 ≈ 1.4 TB/일** (단일 스트림 기준).

| category | TB | days @17MB/s |
|---|---|---|
| pacbio_hifi | 7.6 | 5.2 |
| ont | 11.8 | 8.0 |
| pacbio_clr | 14.4 | 9.8 |
| illumina_wgs | 22.3 | 15.2 |
| bgi_mgi | 6.2 | 4.2 |
| linked_reads (10X, stLFR) | 4.9 | 3.4 |
| exome | 1.1 | 0.7 |
| complete_genomics | 16.0 | 10.9 |
| other (BioNano, Strand-seq, HiC, AVITI, UG100 등) | 16.9 | 11.5 |
| release (truth set, stratifications, references) | 0.3 | 0.2 |
| rnaseq (MAS-seq, ONT directRNA; HG002/4/5만) | 0.4 | 0.3 |
| **전체** | **101.7** | **69.3** |

샘플 × 카테고리 (GiB):

| sample | pacbio_hifi | ont | pacbio_clr | illumina_wgs | bgi_mgi | linked_reads | exome | complete_genomics | other | TOTAL | days@17MB/s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| HG001 | 386 | 329 | 211 | 2,003 | 1,014 | 1,542 | 123 | 2,087 | 333 | 8,029 | 5.9 |
| HG002 | 1,643 | 3,242 | 4,502 | 3,179 | 1,726 | 659 | 225 | 1,805 | 2,208 | 19,191 | 14.0 |
| HG003 | 1,170 | 896 | 2,686 | 3,141 | 395 | 572 | 199 | 1,854 | 98 | 11,009 | 8.0 |
| HG004 | 1,023 | 917 | 2,549 | 3,487 | 564 | 529 | 214 | 1,747 | 99 | 11,129 | 8.1 |
| HG005 | 611 | 527 | 1,731 | 3,299 | 1,655 | 429 | 216 | 3,660 | 923 | 13,051 | 9.5 |
| HG006 | 442 | 470 | 861 | 1,244 | 192 | 422 | - | 1,859 | 6 | 5,497 | 4.0 |
| HG007 | 424 | 382 | 849 | 1,271 | 209 | 431 | - | 1,867 | 8 | 5,441 | 4.0 |
| HG008 (T + N-D + N-P) | 1,394 | 4,238 | - | 3,111 | - | - | - | - | 12,031 | 20,774 | 15.2 |

- HG008의 other(12.0 TiB)에는 Element AVITI(4.9 TiB), Ultima UG100(1.9 TiB), PacBio Onso(1.2 TiB), analysis(1.7 TiB), superseded 2022 데이터(1.8 TiB)가 포함됨. superseded는 제외해도 무방
- HG008은 T/N-D/N-P 세 물리 샘플이 같은 디렉토리에 섞여 있어 파일명으로 구분됨 (`HG008-T_*`, `HG008-N-D_*`, `HG008-N-P_*`)

플랫폼 디렉토리 단위 상세 용량은 [docs/SIZES.md](docs/SIZES.md) (조회용) 참고.

## 속도: wget보다 빠르게 받는 법

| 방법 | 예상 효과 | 비고 |
|---|---|---|
| `TOOL=s3` (aws cli) | 파일당 병렬 multipart, 보통 수 배 | **권장.** 공식 미러 `s3://giab`, `--no-sign-request`라 계정 불필요 |
| `JOBS=4` (파일 단위 병렬) | 단일 스트림 한계 우회, 2–4배 | wget/aria2/s3 모두에 적용 가능 |
| `TOOL=aria2` | 파일당 4커넥션 | aws cli가 없을 때 차선 |
| aspera (ascp) | 불확실 | NCBI가 aspera 지원을 축소 중이라 동작 보장 없음. S3 경로가 확실함 |

즉, 지금 17 MB/s면 우선 `TOOL=s3 JOBS=4`를 시험해보고 (`aws --version` 확인, 없으면 conda/pip로 awscli 설치), 실측 후 JOBS를 조절하면 됨. 예:

```bash
TOOL=s3 JOBS=4 ./scripts/download.sh pacbio_hifi
```

## 구조

- `manifests/<SAMPLE>/<category>.tsv` — `상대경로<TAB>bytes`. 이 목록이 다운로드 대상의 전부
- `manifests/release_truthsets.tsv` — truth set VCF/BED, stratification, reference (전체 버전 포함)
- `manifests/rnaseq_all.tsv` — `data_RNAseq/` 전체 (324 files, 6.5 TiB). HG002·HG004·HG005만 존재. `./scripts/download.sh rnaseq`로 다운로드. `all`에는 포함되지 않음

### S3 미러 누락 주의 (2026-08-13 확인)

S3 미러는 FTP보다 불완전하다. FTP `current.tree`(86,392 files)와 S3 실시간 목록(87,527 objects)을 대조한 결과:

| 누락 데이터 | 용량 | 대응 |
|---|---|---|
| RNA-seq Illumina(UNC·Google), Iso-Seq, Baylor HiFi RNA | 6.3 TiB | FTP만 가능 |
| Element AVITI 2024-09 (HG001·HG003~HG005) | 2.1 TiB | FTP만 가능 |
| HG001 PacBio CCS haplotagged BAM 등 | 0.4 TiB | FTP만 가능 |

`TOOL=s3`에서 S3에 없는 파일은 자동으로 FTP(wget)로 대체 다운로드된다 (`download.sh`의 fallback).
- `scripts/download.sh` / `scripts/verify.sh` — 위 사용법 참고. `MISSING=1 ./scripts/verify.sh ...`로 미완료 파일 나열
