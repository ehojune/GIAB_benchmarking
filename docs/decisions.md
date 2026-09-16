# 결정 기록

## 2026-08-26 — 처리표 원문 전체 표시와 현재 평가 기준

- 이전의 “tool만 전체 표시, 다른 축약 유지” 결정을 폐기했다.
- 플랫폼·리드 포맷·모든 tool·`next_step`은 자수 제한 없이 TSV 원문 전체를 표시한다.
- 상태 필드는 `TRUE/FALSE/N/A/-`만 허용한다. 편집 메모가 섞인 7건은 실제 상태로 복구했다.
- HG008은 somatic small variant V0.3과 SV/CNV V0.5를 현행 기준으로 삼고, HG009는 공식 benchmark가 아직 없다고 적는다.
- 근거는 [reference/2026-08-26-hg008-benchmark-refresh.md](reference/2026-08-26-hg008-benchmark-refresh.md)에 뒀다.
- 엑셀 파일명과 내부 버전 `0826`은 유지하고 `Master Catalog`를 최신 TSV와 맞춘다.

## 2026-08-23 — Yuan 최소 준수 retrofit

- 기존 활성 구조와 `HARVEST.md`는 그대로 두고 MVR 파일과 Journal만 추가했다.
- 전체 템플릿 스탬프와 README 재구성은 현재 작업을 흔들 수 있어 하지 않았다.
- GIAB 원본 데이터는 이 기계의 D:·E:에서 확인되지 않았다. NBB 실행 경로는 문서에 있으나 실제 보관 위치는 재실행 전에 확인한다.

## 2026-09-09 — phase3 숏리드 WGS 대상 확정

- HG002·3·4의 숏리드 DNA 중 **원시 FASTQ가 있는 표준 WGS 8종(18 실행 단위)** 만 phase3 대상으로 한다.
  mate-pair·Moleculo·10X·stLFR·Hi-C·Strand-seq·Dovetail은 라이브러리가 특수해 일반 germline 파이프라인에 맞지 않고,
  엑솜은 BAM만 있고, CG·SOLiD는 포맷이 다르다.
- 경로 목록은 nbb2 접속 없이 `phase0_download/manifests/`에서 생성했다. verify.sh all 100%(2026-08-30)를 실존 근거로 삼는다.
- 파이프라인 선택·실행은 사용자가 한다. 이 repo는 입력 목록과 정답셋 경로만 제공한다.
- HiSeq 300x는 **전량 사용**한다(사용자 결정). 플로우셀당 ~25x라 서브셋을 고르는 것보다 read group으로 전부 넣고 파이프라인에서 병합하는 편이 단순하다.
  samplesheet의 unit(플로우셀.레인.라이브러리)이 read group 단위다 — `make_samplesheets.py`가 R1/R2 짝과 unit 일치를 assert로 검증한다.

## 2026-09-16 — release/ manifest를 FTP 라이브 크롤로 재구성

- GIAB `current.tree`가 2025-02-27 이후 갱신되지 않아 2026-08-13 manifest에 HG002 v5.0q(2025-12~2026-07)와
  stratifications v3.6이 없었다. `release/`는 `scripts/crawl_release.py`로 FTP 인덱스를 직접 크롤해 맞춘다(파일별 HEAD, 3+4 스레드).
- manifest는 FTP를 그대로 따른다: 추가 1,577 files(41.4 GiB — v5.0q 52 + 그 latest/ 복사본 52 + stratifications v3.6 1,471 + mosaic VCF 2), 제거 52(HG002 latest/의 v4.2.1 51 + references README.md.txt). 순증 +1,525 files.
  제거분은 `manifests/release_stale_ftp_removed.tsv`에 남긴다. 로컬 파일은 지우지 않는다.
- Apache 인덱스가 숨기는 dotfile 394건은 HEAD로 실존을 확인해 유지했다. 첫 실행에서 이를 "사라짐"으로 오판해 446건을 뺐다가 되돌렸다.
- HG002 `latest/`는 v5.0q 복사본이 되었다. 로컬에는 두 판이 공존하므로 평가는 버전 디렉토리를 직접 지정한다.
- 평가 기본은 v4.2.1 유지. v5.0q는 GIAB가 draft라 명시했으므로 HG002 보조 평가용. stratification은 v3.6으로 통일(v5.0q README 지정).
- 보고서 `docs/reference/release_crawl_2026-09-16.md`는 `--baseline`(2fe9c2b의 manifest)으로 재생성했다 — 같은 날 재실행이 덮어써 8건짜리로 바뀌어 있었다(Codex 리뷰 지적). 이후 dry-run은 docs/에 쓰지 않고, 실행 보고서는 `_2`, `_3`로 보존한다.
- 카탈로그에 v5.0q·v3.6 행을 추가했다(334 datasets). 엑셀 `Master Catalog`는 `catalog/build_xlsx.py`로 TSV에서 재생성한다(v0916).
- 스크립트는 `release/` 전용으로 잠갔다(Codex 리뷰 지적: data/ ROOT가 release manifest에 써질 수 있었다). `data/` 계열은 샘플별 manifest라 별도 도구가 필요하다.

## 2026-09-16 — data/ 트리도 FTP 라이브 크롤로 재대조

- `crawl_data.py`: 인덱스 수정일·근사 크기로 후보를 골라 선별 HEAD(25k/83k). 2026-08-13 목록(S3 기반)에 FTP 전용 데이터가 빠져 있었다:
  HG008 NIST 트리(T_bulk 패시지·클론 8종의 NovaSeq X·Revio SPRQ·somatic 분석·단일세포·Hi-C·RNA-seq), HG009 신규, Verkko 작업 디렉토리 등 7,377 files / 11.5 TiB.
- **manifest는 다운로드 소스(S3) 기준을 지킨다.** FTP와 어긋난 기존 항목은 S3 HEAD로 교차 확인해 S3=manifest면 유지.
  FTP 사본이 14% 작은 Illumina FASTQ 7,122건, FTP에서만 사라진 2,173건(12.3 TiB)이 그 경우다. 첫 실행은 이를 반영해 버렸고 되돌린 뒤 규칙을 넣었다.
- 새 디렉토리는 카탈로그 접두만으로 라우팅하지 않는다(HG009 접두가 거칠어 NovaSeq X·RNA-seq가 pacbio_hifi로 들어갔다). 부모 디렉토리에 기존 파일이 있을 때만 자동,
  아니면 `catalog_new_dirs.py`로 행을 만든 뒤 `--route-all`. 카테고리는 플랫폼 디렉토리 이름 패턴으로 정했고 HG008 관례(analysis·Hi-C·단일세포·핵형·superseded = other)를 따랐다.
  HG008/HG009 RNA-seq는 `rnaseq_all` 카테고리·`rnaseq_all.tsv`에 넣었다(data_RNAseq 밖이지만 같은 성격).
- 2014~2020 trio 레벨 분석 107 디렉토리(8,228 files / 7.8 TiB, 10X LongRanger/Supernova 어셈블리 등)는 카탈로그 행 없이 `optional_trio_analysis_legacy.tsv`로 분리.
  run_priority에 안 들어가고 `download.sh optional_trio_analysis_legacy`로만 받는다. 받을지는 사용자 결정.
- superseded-2022 raw(1.7 TiB)와 Verkko 작업 디렉토리(1.2 TiB)는 기존 관례대로 manifest에 포함했다. 빼려면 manifest에서 지운다.
- NCBI가 `.log`·`.err` 파일에 403을 준다(Verkko, Severus). 인덱스에는 보이지만 받을 수 없어 크기 미확인으로 두고 manifest에 넣지 않는다(74건).
- Codex 리뷰 1회차(P1 1·P2 6) 전부 반영: S3 확인 실패(-1)면 검증된 크기 유지, 기존 행 파일 수는 manifest∪신규 인벤토리로 재계산(중복 가산 제거),
  참조 게놈은 파일명 토큰으로, somatic/germline VCF 구분, 인덱스는 파일별 사이드카 짝으로 PARTIAL 판정, Revio 위상(HiPhase) 반영, 부분 크롤이 다른 루트의 대기 목록을 지우지 않게.
  2회차는 Codex 사용 한도 소진으로 못 돌렸다(2026-09-16). PR 때 다시 돌린다.
- Codex 리뷰 2회차(P2 7건) 반영: 카탈로그 인벤토리를 **배타 배정**(가장 긴 giab_path 접두 하나)으로 바꿔 부모·자식 행 이중 계수 제거
  (HG009 부모 3행 121/112/330 → 29/20/54, 합계 86,063 → 85,479 files). 사람이 채운 단계(`*_by=me` 또는 local_path/script)는 재실행 때 보존.
  somatic 표기가 generic 벤치마크 용어보다 우선(`somatic-stvar`는 germline 아님). tar.gz FASTQ 아카이브를 리드로 인정(ResolveOME 104 GB).
  인덱스 판정은 전체 경로로 짝을 맞추고 BAM의 .csi도 인정. `--fresh`는 S3 캐시도 지운다(실패가 옛 결과로 덮이지 않게).
- Codex 리뷰 3회차(P2 5건) 반영: 비압축 `.vcf`도 미인덱스 대상으로 계수, 기존 디렉토리에 직접 추가된 파일까지 모든 비-release 행을 배타 배정으로 재계수(BGISEQ QC 행 3→12),
  자식이 전부 가져간 부모 행은 0으로(“파일 없음”과 구분), germline/somatic tool을 파이프라인 요약이 아니라 VCF 파일명의 콜러로 귀속(dipcall·Clair3 등),
  legacy manifest는 append가 아니라 병합해 크기 변경을 반영.
- Codex 리뷰 4회차(P2 2건) 반영: 메틸화 산출물(analysis/methylation/*.cpg 등)을 인벤토리에서 감지해 19개 행의 meth_called를 채웠다.
  VCF 분류를 label(명시) > hint(콜러 이름) 2단계로 바꿨다 — `purple.germline.vcf.gz`는 germline, `somatic-stvar`는 somatic.
- 5회차 리뷰는 Codex 사용 한도로 못 돌렸다(재설정 2026-09-17 03:25). 3회에 걸친 지적 14건을 모두 반영한 뒤,
  자체 검증(스크립트 재실행 멱등성, 카탈로그 436행×51열, files 85,497 = manifest 77,508+7,989 일치, giab_path 중복 0,
  라우팅 누락 0, README·엑셀 동기)을 확인하고 merge했다.
