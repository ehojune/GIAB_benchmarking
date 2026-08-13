# GIAB benchmark data download

GIAB 7개 샘플(HG001–HG007) 원시 데이터 + truth set 다운로드용 스크립트.
파일 목록과 크기는 2026-08-13에 공식 미러 `s3://giab`에서 직접 조회한 값 (NCBI FTP와 동일 내용, 총 70,206개 파일).

## Quick start (nbb2)

```bash
git clone <REPO_URL> && cd GIAB_benchmarking
./scripts/download.sh release                    # truth set + stratifications (241 GiB, 먼저)
./scripts/download.sh pacbio_hifi                # 우선순위 1
./scripts/download.sh ont                        # 우선순위 2
./scripts/download.sh pacbio_clr                 # 우선순위 3
./scripts/verify.sh all                          # 진행률/크기 검증
```

- 기본 다운로드 위치: `/BiO/scratch/ehojune/GIAB_benchmark` (변경: `DEST=... ./scripts/download.sh ...`)
- GIAB 원본 디렉토리 구조 그대로 저장됨 (`data/AshkenazimTrio/HG002_.../PacBio_CCS_15kb/...`)
- 크기가 일치하는 기존 파일은 건너뛰므로 중단 후 재실행 안전. 샘플 지정 가능: `./scripts/download.sh ont HG002 HG005`
- 이미 wget으로 받아둔 HiFi 파일은 위 경로 구조로 옮겨두면 자동 스킵됨

## 용량 및 예상 시간

환산: 17 MB/s ≈ **1 GiB/분 ≈ 1.4 TB/일** (단일 스트림 기준).

| category | TB | days @17MB/s |
|---|---|---|
| pacbio_hifi | 6.1 | 4.2 |
| ont | 7.3 | 4.9 |
| pacbio_clr | 14.4 | 9.8 |
| illumina_wgs | 18.9 | 12.9 |
| bgi_mgi | 6.2 | 4.2 |
| linked_reads (10X, stLFR) | 4.9 | 3.4 |
| exome | 1.1 | 0.7 |
| complete_genomics | 16.0 | 10.9 |
| other (BioNano, Strand-seq, HiC, SOLiD 등) | 4.0 | 2.7 |
| release (truth set, stratifications, references) | 0.3 | 0.2 |
| **전체** | **79.0** | **53.8** |

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
- `scripts/download.sh` / `scripts/verify.sh` — 위 사용법 참고. `MISSING=1 ./scripts/verify.sh ...`로 미완료 파일 나열
