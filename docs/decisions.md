# 결정 기록

## 2026-09-22 — 다운로드 진입점을 하나로, 외부 데이터는 "대응 GIAB 디렉토리 유무"로 가른다

- **취득 경로 4개를 `phase0_download/scripts/fetch_all.sh` 하나로 묶는다.** GIAB FTP/S3(phase0) · ENA(phase1) ·
  ONT 공개 데이터(phase2) · Google/HPRC(phase3)가 각각 다른 스크립트였고, 실제로 PR #17이 데이터를 들여왔는데
  카탈로그·README·Excel 반영이 빠지는 일이 일어났다. 진입점이 하나면 "무엇을 받는지"의 목록도 한 곳에 남는다.
  기존 스크립트는 그대로 두고 부르기만 한다 — 각 phase의 검증 규약(`VERIFY_ONLY=1`)이 이미 통일돼 있어 가능했다.
- **HG002 R10.4.1은 기존 행의 `reads_format`이 아니라 `ext/` 외부 유래 행으로 넣는다.** 가르는 기준은
  "대응하는 GIAB 디렉토리가 있는가" 하나다. HG001 rel6·HG001/HG005 SequelII는 GIAB 디렉토리가 있어 기존 행에 출처만
  적었지만(집계 미포함), HG002 R10은 GIAB FTP에 아예 없다(ONT 디렉토리 셋 전부 R9 시절). 자체 행이 없으면
  어느 표에도 나타나지 않아 "받았는데 목록에 없는" 데이터가 된다. 이 기준을 [catalog/README.md](../catalog/README.md)에 표로 적었다.
  결과: 441 → 442 datasets / 81,314 → 81,316 files / 114.1 → 114.3 TiB.
- **CC BY-NC 4.0 데이터가 카탈로그에 처음 섞였다.** 비상업 연구 한정이라는 제약은 데이터와 함께 따라다니므로
  해당 행 `notes`와 README 외부 리드 항목 양쪽에 적었다. 앞으로 라이선스가 다른 데이터를 들일 때도 같게 한다.
- **`download.sh`가 '대상 아님' 목록을 이름만으로 받는 구멍을 막았다.** `declined_by_decision`(받지 않기로 한 10.7 TiB)과
  `release_stale_ftp_removed`(FTP에서 삭제됨)는 파일명 분기에 걸려 `./download.sh declined_by_decision`이 성립했고,
  둘 다 3열이라 크기 비교가 전건 실패해 10.7 TiB를 받고도 전부 MISMATCH로 찍힐 수 있었다. 이름을 거부하도록 했다.

## 2026-09-23 — fetch_all.sh의 완료 판정은 퍼센트가 아니라 파일 수이고, 검증 로그는 격리한다

- `verify.sh`의 `(100.0%)`는 바이트 기준 소수 1자리다. 0바이트 파일이 빠져도, 0.05% 미만이 빠져도 100.0%로 찍힌다. 진입점의 완료 판정은 `TOTAL` 줄의 `done == total`(파일 수) + 검증기 rc 0으로 한다.
- `run_priority.sh`가 카테고리마다 `TOTAL`을 찍으므로 사후 검증 출력을 같은 로그에 붙이면 마지막 카테고리의 TOTAL을 전체로 오판한다. 검증은 `phase0.verify.log`로 격리하고 그 파일만 읽는다.
- 다운로드 뒤 검증 범위는 무조건 `all`. `PHASE0_VERIFY_CAT`은 `VERIFY_ONLY=1` 스모크 전용이다.
- 근거·스모크: [runs/2026-09-23-fetch-all-completion-policy.md](runs/2026-09-23-fetch-all-completion-policy.md). Codex 리뷰 #37 1·2라운드 지적을 그대로 받아들인 결정이다.

## 2026-09-22 — 다운로드 목록의 기준은 서버 디스크 실측이고, FTP에서 사라진 파일은 지우지 않는다

- **"무엇을 받았나"의 정본은 매니페스트가 아니라 디스크다.** 세 세션이 각자 받은 것을 한 목록으로 맞출 때, 매니페스트를 서로 믿는 대신 nbb2 `/BiO/scratch/ehojune/GIAB_benchmark`를 전수 실측해 네 매니페스트 합집합과 파일·바이트 단위로 대조했다. 결과 81,330/81,330 일치, 매니페스트 밖 데이터 0 — 즉 지금은 매니페스트 = 디스크다. 앞으로 새 데이터를 들일 때는 그 phase의 매니페스트(`sra_manifest.tsv`/`ext_manifest.tsv`)에 먼저 넣고 받는다. 기록: [runs/2026-09-22-disk-vs-manifest-reconciliation.md](runs/2026-09-22-disk-vs-manifest-reconciliation.md).
- **FTP에서 삭제된 release 구버전 52건(8.4 GiB)은 지우지 않고 `release_stale_ftp_removed.tsv`에 남긴다.** 다시 받을 수 없어 지우면 복구 불가이고, `latest/` 재구성 전 v4.2.1 파일이라 현재 경로와 중복일 가능성이 높지만 바이트 대조는 안 했다. 활성 매니페스트(`fetch_all.sh` 대상)에는 넣지 않는다 — 원격에 없는 것을 받으려 하면 전건 실패로 찍힌다. 지울지는 사용자 결정.
- `processed_data_ehojune/`(135,061 files)와 `repairs/`(17)는 산출물·재생성물이라 다운로드 목록 대상이 아니다. 단 `_infra/`에 01_prepare가 받아둔 레퍼런스·모델·컨테이너가 있다 — 그 목록은 각 phase 세션이 안다.

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

## 2026-09-17 — 발견했으나 받지 않기로 한 데이터 3건

2026-09-16 크롤이 찾은 것 중 셋은 받지 않는다(사용자 결정). 2026-09-16 항목의 "superseded-2022 raw와 Verkko 작업 디렉토리는
기존 관례대로 manifest에 포함했다"와 "legacy 분석을 받을지는 사용자 결정"을 이 항목이 대체한다.

| 그룹 | 파일 | TiB | 판단 근거 |
|---|---|---|---|
| legacy-trio-analysis | 8,228 | 7.78 | 2014~2020 trio 레벨 분석 107 디렉토리. 카탈로그 행이 없고 현재 작업과 무관 |
| hg008-superseded-2022-raw | 26 | 1.63 | GIAB이 superseded로 표시. **이미 받은 `BCM_ILMN-somatic-analysis_20220816/`와 파일명·크기가 전부 동일한 중복**이라 받아도 얻는 게 없다(워크플로 검증에서 확인) |
| hg008-verkko-workdirs | 4,169 | 1.28 | Verkko 작업 디렉토리 중간 산출물. 어셈블리 결과 353 files / 197.5 GiB는 그대로 보유 |

- **기록은 세 곳에 남긴다.** manifest에서 지우기만 하면 다음 크롤이 "기존 디렉토리의 신규 파일"로 되돌려 넣는다.
  (1) `manifests/declined_by_decision.tsv` — 경로·바이트·그룹 12,423행. (2) `crawl_data.py`가 이 목록을 읽어 신규에서 제외.
  (3) `catalog_new_dirs.py`의 PATTERNS 비고와 unrouted 필터.
- 제거 범위는 **크롤이 추가한 것만**이다. 2026-08-30에 이미 받은 파일(커밋 62acb11 기준)은 한 건도 manifest에서 빠지지 않았다(실측 확인).
  `optional_trio_analysis_legacy.tsv`와 `data_unrouted_new.tsv`는 declined 목록에 흡수돼 삭제했다.
- 카탈로그에서 `superseded-2022-data/BCM_Illumina_WGS_20220816` 행은 파일이 0이 되어 지웠다(435 datasets).
  같은 26 files / 1666 GiB를 주장하던 `BCM_ILMN-somatic-analysis_20220816` 행과의 이중 계수도 이걸로 해소됐다.
- **S3 미러에 신규 데이터가 사실상 없다**(표본 96건 중 1건, 용량 상위 25건은 0건). `TOOL=s3`이어도 FTP fallback으로 받으므로
  83 MB/s 기준 추정은 쓰면 안 된다. 실제 내려받을 양은 4,759 files / 8.67 TiB다
  (2fe9c2b 대비 파일 단위 대조. 8,954는 제외 결정을 반영하기 전 수치였다 — 2026-09-17 정정).

## 2026-09-17 — detect_fastq_platform.sh 판단 근거

- 판정은 헤더 패턴(Illumina 콜론 필드 수, PacBio movie/zmw, ONT UUID·`runid=`, MGI `LxCxRx`)을 1순위로 쓰고,
  리드 길이는 헤더가 안 걸릴 때만 쓰는 폴백으로 뒀다. 헤더 규약이 리드 길이보다 훨씬 구체적이라 오탐이 적다.
- 롱리드/숏리드 컷오프는 1000bp로 뒀다. PacBio/ONT(수천~수만bp)와 Illumina/MGI(<300bp)가 갈리는 지점 어디든
  안전해서 고른 값이지, 그 자체로 실측 근거가 있는 임계값은 아니다 — 조정이 필요하면 여기부터 볼 것.
- `phase0_download/scripts/`에 뒀다. 새 top-level `scripts/`를 만드는 대신, 원본 fastq를 검증하는 기존
  스크립트(verify.sh, md5_verify_all.sh)와 같은 성격으로 판단했다.
- PacBio 정규식은 애초에 Sequel/Revio 신형 무비명(`mNNNNN_YYMMDD_HHMMSS`)만 받았는데, Codex 리뷰 1회차 P2로
  RS-II 구형 무비명(`m<날짜>_<시각>_<기기>_c<셀바코드>_s<세트>_p<파트>`)이 빠진다는 지적을 받아 `m<무비명>/<zmw>/(ccs|범위)`
  형태로 느슨하게 바꿨다. 세 필드를 각각 검증하는 대신 마지막 `/zmw/ccs-or-range` 접미사에만 기댄다.
- 이 항목 자체가 Codex 리뷰 1회차 P1 지적(판단 기록 누락)으로 사후 추가됐다. 원 커밋(`5938d71`)에는 없었다.
- Codex 리뷰 2회차 P2 2건: Illumina 신형 헤더의 기기명이 `[A-Za-z0-9]+`라 하이픈 포함 실기기명(`HWI-ST911` 등 HiSeq 세대)을
  못 받았다 — PacBio 때와 같은 교훈으로, 필드 내용을 하드코딩하지 말고 `[^:[:space:]]+`처럼 구분자만 강제하는 쪽으로 양쪽
  Illumina 분기를 통일했다. 또 SIGPIPE 억제용 파이프페일 처리가 손상된 gzip 등 **진짜** reader 오류까지 삼켜서 부분
  데이터로 조용히 exit 0을 내고 있었다 — `PIPESTATUS`로 reader 자체의 종료코드를 따로 확인해 0/141(정상 SIGPIPE)이
  아니면 실패로 보고하게 바꿨다.
- 이 과정에서 직접 만든 회귀도 하나 있었다: awk `printf`에 개행이 없어 `read`가 EOF에서 개행 없이 끝나는 줄을 읽으면
  필드는 다 채우고도 자기 자신은 1을 리턴한다 — `set -e`가 그 자리에서 스크립트를 죽였다(테스트로 잡음, 커밋 전에 수정).
  그리고 `pipefail` 켜진 상태에서 파이프라인 실패를 `|| true`로 넘기면 `PIPESTATUS`가 `|| true`의 `true` 하나짜리로
  덮어써져 정작 보려던 reader 종료코드가 사라진다(bash 5.3 확인) — `|| true` 대신 그 구간만 `pipefail`을 껐다 켰다.
- Codex 리뷰 3회차 P2(표본 200리드 *이후*의 gzip 손상은 조기종료 SIGPIPE와 구분 안 됨): 지적은 맞지만 고치지 않기로
  했다. 잡으려면 파일 전체를 다 읽어야 하는데, 그러면 "대용량 파일 앞부분만 빠르게 보고 판별한다"는 이 스크립트의
  존재 이유가 없어진다. 전체 무결성은 이미 있는 전담 도구(`md5_verify_all.sh`, `verify.sh`)의 몫으로 남기고,
  한계는 스크립트 상단 주석에 명시하는 선에서 끝냈다.
- (병합 후 후속) Illumina로 판정되면 기기ID 접두어(예: `LH00`)로 구체 기종(NovaSeq X/X Plus 등)까지 추정하는 걸 추가했다.
  실사용 중 사용자가 서버에서 4개 파일을 돌려 전부 `LH00xxx` 기기ID를 봤고, "더 분석 가능한가" 물어서 붙였다.
  이 접두어-기종 표는 **일루미나 공식 문서가 아니라 커뮤니티가 역추적한 비공식 관례**다 — 웹 검색으로 `LH00`→NovaSeq
  X/X Plus는 확인했지만(ASeq Newsletter 등), 표 전체를 하나의 공식 출처로 검증하지는 못했다. 그래서 접두어가 없거나
  표에 없으면 조용히 generic `Illumina (...)`로 남기고 모델을 지어내지 않는다 — 오탐보다 미상이 낫다는 원칙.

## 2026-09-17 — phase3에 외부 숏리드 30x 트리오 2종 추가 (업체 비교 arm)

- 목적 재확인: gd001~004 업체가 만든 HG002/3/4 데이터를 자체 WGRS 파이프라인으로 돌린 결과(A)를, 같은 파이프라인으로 돌린 GIAB 공개 raw(B)와
  GIAB 정답셋(C)에 대조한다. joint calling은 이번 범위 밖.
- 기존 18 실행 단위에는 업체 산출물(NovaSeq/DNBSEQ 2x150, ~30x, 1 라이브러리)과 조건이 맞는 것이 없었다 — 300x·12 라이브러리, 2x250, PE100,
  AVITI 80x. GIAB FTP의 HG002/3/4 숏리드 WGS 디렉토리는 S3 목록으로 재확인했고 18개가 전부다.
- 추가 (사용자 결정, 둘 다 받는다):
  (1) `HG00{2,3,4}.NovaSeq_PCRfree_30x` — Google brain-genomics-public(GCS). NovaSeq 6000 PCR-free 2x151, 세 샘플이 같은 런(A00744:46 HV3C3DSXX L2), md5 공개, 147 GiB.
  (2) `HG00{3,4}.Illumina_PCRfree_30x` — HPRC S3. GIAB FTP `Illumina_PCRfree_downsampled`에는 HG002만 있고 그 README가 HPRC 링크를 가리킨다.
  300x와 같은 TruSeq PCR-free 라이브러리에서 뽑은 2x148 ~30x, 170 GiB. 기존 HG002 행과 같은 dataset 이름을 쓴다.
- 300x 전량 실행(2026-09-09)은 유지하되 역할을 바꾼다: 업체 비교의 기준이 아니라 깊이 상한(포화) 실험. 업체 비교는 30x arm으로 한다.
- 권고 순서: NovaSeq 30x → HiSeq 30x → (업체 중 MGI가 있으면) MGISEQ2000 PCR-free(2x150, 압축비 추정 ~70x/67x/127x) → 300x → AVITI StdInsert.
  2x250(리드 길이)·BGISEQ500(PE100, 헤더 실측)·AVITI 20231018(R&D 시약, HG002만)은 후순위.
- 검증은 간략하게 한다(사용자 결정, 비용): HEAD 크기, 앞 256 KB 표본의 리드 길이·장비·플로우셀. md5는 Google만 있다(HPRC ETag는 멀티파트).
  다운로드 뒤 `scripts/02_fetch_external_reads.sh`가 크기(+md5)·앞 20k 리드 평균 길이(140~160 bp)를 본다.
- 자문: Codex gpt-5.6-sol과 Gemini 3.1 Pro에 같은 질문을 독립적으로 물었다. 둘 다 NovaSeq 30x 트리오 1순위. Gemini는 300x를 빼라 했고
  Codex는 별도 포화·read group 실험으로 남기라 했다 — 후자를 택했다. Fable 워크플로(추가 후보 탐색·비판)는 비용 때문에 사용자 지시로 중단, 결과 없음.
  기록: `docs/reference/phase3_shortread_candidates_2026-09-17.md`.
- 카탈로그(master_catalog.tsv)에는 넣지 않는다. 카탈로그는 GIAB FTP 인벤토리이고 크롤러가 giab_path로 라우팅한다. 외부 리드는 phase1·phase2처럼 phase 매니페스트에만 둔다.
- (같은 날 추가) 업체 4곳의 플랫폼이 **Illumina NovaSeq X / X Plus**로 확인됐다(사용자 전달; 서버의 업체 FASTQ 4건이 기기ID `LH00xxx`, `detect_fastq_platform.sh`).
  공개 데이터에 NovaSeq X **트리오**는 없다 — GCS `novaseqx/`도 ENA PRJNA1427896(Weill Cornell, NovaSeq X 25B/10B + UG100)도 HG002만. 그래서 트리오 기준 arm은
  NovaSeq 6000 PCR-free 30x로 유지한다. 같은 Illumina 2x151 PCR-free 30x지만 화학이 다르다(SBS vs XLEAP-SBS)는 점은 비교 해석에 적어야 한다.
  화학까지 맞춘 HG002 단일 대조군으로 Google `novaseqx/HG002.novaseqX.30x`(22.3+22.2 GB, md5 c9a66aaa…/1d2ca0d3…)를 **추가했다**(사용자 결정, 같은 날). dsid `HG002.NovaSeqX_30x`,
  로컬 `external/google_novaseqx_hg002_30x/`. 원 데이터는 Weill Cornell PRJNA1427896 SRR37356338 — ENA SRX32270094 design에 "NovaSeq X 25B, 2x151bp, v1.3, TruSeq DNA PCR-Free, 64-plex"라고 적혀 있다.
  리드 이름이 SRA 형식(`@SRR37356338.N pi1-04:...`)이라 `detect_fastq_platform.sh`가 Illumina 규칙에 못 걸려 "미상(숏리드)"을 낸다 — 그래서 fetch 스크립트의 플랫폼 판정은
  PacBio/ONT/MGI로 **양성 판정될 때만 실패**하고 미상은 경고로 낮췄다. 실행 단위 24.
  MGISEQ2000 조건부 항목은 업체에 MGI가 없으므로 후순위로 내렸다.
- (같은 날 추가) 외부 리드 저장 경로를 `ext/<버킷 경로>`에서 `external/<출처>/`로 바꿨다. 사용자가 이미 `external/google_novaseq_pcrfree_30x/`로 수동 wget 중이어서 매니페스트를 그쪽에 맞췄다.
  `02_fetch_external_reads.sh`는 같은 경로를 보므로 받은 파일은 다시 받지 않고 md5·리드 길이·플랫폼만 확인한다. HPRC 4건은 `external/hprc_hiseq30x_subsampled/HG00{3,4}/`로 받는다.
- (같은 날 추가) `02_fetch_external_reads.sh` 마지막 단계에 main에 merge된 `phase0_download/scripts/detect_fastq_platform.sh`(PR #7/#9)를 붙였다. 헤더로 Illumina·기종을 찍고 Illumina가 아니면 실패.
- (같은 날, 번복) 위의 "카탈로그에는 넣지 않는다"를 사용자 요청으로 뒤집었다 — 엑셀·README 표에 새 다운로드 내역이 보여야 한다.
  외부 6행(HG002/3/4 NovaSeq 6000 30x, HG002 NovaSeq X 30x, HG003/4 HiSeq 30x 서브샘플)을 `illumina_wgs`로 추가했다(441 datasets / 81,314 files).
  `giab_path`는 GIAB 경로가 아니라 **로컬 relpath(`external/...`)** 이고, 같은 디렉토리에 세 샘플이 섞인 Google 트리오는 파일 접두(`.../HG002.novaseq.pcr-free.30x`)까지 붙여 행을 유일하게 했다.
  크롤러에 안전한 이유: `crawl_data.py`는 FTP 경로를 giab_path 접두로 라우팅하므로 `external/`은 절대 매치되지 않고, `catalog_new_dirs.py`의 files/size 재계산은 phase0 manifest에 그 경로의 파일이 하나도 없으면(`has_any`) 행을 건드리지 않는다.
  files/size의 원본은 `phase3_shortread_wgs/ext_manifest.tsv`다. 규칙은 `catalog/README.md` "외부 유래 행"에 적었다. phase1(ENA)·phase2(rel6) 외부 리드는 기존 GIAB 행에 붙어 있어 그대로 둔다.
- (PR #12 Codex 리뷰, 사용자 지시로 상한 10라운드) built-in review 1회 "regression 없음" → adversarial 3회. 지적 3건 전부 반영:
  ① NovaSeq 6000 트리오를 "장비 매칭"이라 쓴 next_step·phase3 README 행·fetch 스크립트 주석 → "Illumina·2x151·PCR-free·30x는 맞지만 화학(SBS vs XLEAP-SBS)은 다름, 화학 매칭은 HG002.NovaSeqX_30x"로 정정.
  ② README 외부 리드 행의 "규모 집계 미포함"이 상단 441행 집계와 모순 → PacBio·ONT 외부분만 미포함, phase3 외부 6행은 포함으로 명시.
  ③ `02_fetch_external_reads.sh`가 DSID 오타·빈 매니페스트에서 0건 검사 후 exit 0 → 매니페스트 없음/0건 선택 시 exit 1.
  4라운드 approve("No material findings"). 남은 한계(Codex도 인정): HPRC 4건은 md5가 없어 크기·리드 길이·플랫폼 검증까지만.

## 2026-09-18 — phase3 파이프라인 입력 디렉토리 이름과 링크 구조

- 사용자 지정 이름 8개(`GIAB_publicdata_<dataset>`; Novaseq6000-PCRfree_30x, NovaseqX_30x, Hiseq_subsampled_30x, Hiseq_300x, Illumina_250PE,
  MGISEQ2000-PCRfree, BGISEQ500, Element_AVITI). 업체 디렉토리 `G000-gd?-*/outcome/<sample>/<sample>_1.fastq.gz`와 같은 모양으로
  `<dir>/outcome/<dir>_<HG00?>/` 아래에 원본 FASTQ 링크를 둔다. `scripts/03_make_pipeline_dirs.py`가 samplesheets에서 만든다.
- 접두 대소문자: 사용자가 첫 항목은 `GIAB_publicData`, 나머지는 `GIAB_publicdata`로 적었다. 처음엔 다수인 `GIAB_publicdata`를 기본으로 두었으나
  같은 날 사용자가 **`GIAB_publicData`로 통일**하라고 해 기본값을 바꿨다(`--prefix`로 변경 가능).
- HiSeq300x는 링크 대신 **cat 병합**(사용자 결정, 같은 날): 샘플당 935~1,024쌍을 R1/R2 각 하나로 이어붙여 `<sample>_1/2.fastq.gz`를 만든다.
  gzip은 멀티멤버라 유효하고, R1/R2 리스트를 같은 순서(unit, 경로)로 써서 짝이 어긋나지 않게 했다. 출력 크기 = 입력 합으로 검증, 크기 맞으면 SKIP.
  2.4 TiB 실사본이 생기고 플로우셀·레인 read group은 FASTQ 파일 단위에서는 사라진다(리드 이름에는 남음). 실행은 nohup/qsub으로 사용자가.
- 첫 실제 실행(nbb2, 같은 날)에서 링크 3개 데이터셋만 만들고 멈췄다: 2x250의 samplesheet unit이 레인(`L001`)뿐이라 레인당 분할 파일(_001~_017)과
  HG003/4의 라이브러리 2개(D2_S1/D2_S2, D3_S1/D3_S3)가 같은 링크 이름으로 겹쳤고, 스크립트가 "다른 대상을 가리킨다"로 정지했다.
  고친 것: (1) `make_samplesheets.py`의 2x250 unit을 `D?_S?.L00?`로(run_table units HG002 2, HG003 4, HG004 4), (2) `03_make_pipeline_dirs.py`는 unit이
  반복되면 원본 분할 번호를 덧붙이고, 만들기 전에 링크 이름 유일성을 검사해 겹치면 아무것도 만들지 않고 멈춘다, (3) `--prune`으로 계획에 없는 옛 심볼릭 링크를 지운다.
  교훈: "unit = read group"과 "파일 쌍"은 다르다 — 분할 FASTQ가 있으면 read group 하나에 쌍이 여럿이다. 이름 유일성은 가정하지 말고 검사한다.
- (같은 날, 확장) 사용자: "결국 병합을 해야 되는데 일일이 하기보다 한번에 각각 알아서". 파이프라인 입력은 업체와 같이 **샘플당 한 쌍**이어야 하므로
  HiSeq300x뿐 아니라 쌍이 둘 이상인 모든 샘플(2x250 18~35쌍, MGISEQ 2~4, BGISEQ 2, AVITI Std+Lng 2)을 cat 병합한다. 1쌍짜리(NovaSeq 6000/X, HiSeq 30x)만 링크.
  실행은 `--run-concat --jobs N`(로그인 노드, 병렬 N, 끝까지 기다림) 또는 `--qsub`(샘플별 SGE 잡, shepherd.q, phase2와 같은 호스트 제한). 완료된 샘플(크기 일치)은 건너뛴다.
  AVITI는 인서트 ~400 bp와 ~1300 bp 라이브러리가 한 파일에 섞인다 — 파이프라인 해석에 남길 것. 앞 항목의 unit 기반 링크 이름 규칙은 이걸로 사실상 쓰이지 않게 됐지만
  1쌍 판정·유일성 검사는 남겼다.
- 첫 병합 실행(nbb2, 같은 날)에서 샘플마다 rc=141로 FAIL 집계. 원인은 concat.sh 끝의 `zcat | head -1`(첫 리드 확인) — head가 먼저 끝나 zcat이 SIGPIPE,
  `set -eo pipefail`이 그 자리에서 스크립트를 죽였다. 병합(cat·크기 검증·mv)은 그 앞에서 이미 끝나 파일은 정상. `( zcat || true ) | head -1`로 고쳤고
  러너는 마지막에 "완료 N/15(출력 크기 = 입력 합)"를 따로 센다. 같은 날 다른 에이전트가 HARVEST에 적어 둔 pipefail 함정과 같은 뿌리다.

## 2026-09-21 — phase3 WGRS 첫 실행 실패: Java 17, MGISEQ HG002 BAM 재생성, 현황판

- **GATK 4.6.1.0 MarkDuplicatesSpark는 Java 17이 필요한데 nbb2 잡은 Java 8을 잡았다**(class file 61 vs 52). 7세트 19건 `mark` 전부 이 원인.
  공용 biko 파이프라인(`/BiO/scratch/dyl/kbb/zz.code/`)은 건드리지 않고, **qsub 잡 안에서 `JAVA_HOME=/BiO/scratch/dyl/apps/miniconda3/lib/jvm`(Java 17.0.18, 서버에 이미 있음)과 PATH를 지정한 뒤 `regermline.sh`를 부른다.**
  GATK 실행기는 PATH의 `java`를 쓰므로 둘 다 필요. 근거·래퍼는 Codex 앱 세션 "Fix server Java version for GATK"(2026-09-21). phase1·2에서 nf-core에 JDK 17을 고정했던 것과 같은 환경 문제.
  **검증 대기** — 잡 155519~155524가 Success로 끝나면 여기와 STATUS.md를 "검증됨"으로.
- **MGISEQ2000 HG002는 정렬 BAM이 33% 잘려 있었다.** bwa-mem2 출력 SAM 948,868,188번째 줄에서 samtools가 `SEQ and QUAL are of different length`로 멈췄는데
  파이프라인이 예외를 삼켜 `Finished`로 넘겼다(BAM 정렬 수 948,864,819 = 에러 줄 − 헤더 3,369줄). 끊긴 위치는 리드 기준 66%로 내 L03+L04 cat 병합 경계(50%)가 아니고,
  같은 플로우셀의 HG003은 정상이라 병합은 원인이 아니다. 원본 레코드 결함인지 bwa-mem2 출력 문제인지는 미확정. Codex 스크립트(`repairs/mgi_hg002_recheck.sh --rebuild`: 원본 검사 → fastp → bwa → 리드 수 대조 → sort)로
  별도 디렉토리에 재생성한 뒤 교체한다. 다른 20 샘플은 `idxstats`로 fastp 리드 수 이상임을 확인했다(primary만 세는 확정 검사는 STATUS.md).
- **현황판 `docs/STATUS.md`를 `docs/`에 둔다** — 템플릿의 `docs/runs/`(한 번 쓰고 남기는 plan/cmd/handoff)와 성격이 다르다. 동시에 5갈래(phase3 재개, BAM 재생성, phase2 R10, phase1 hap.py, 평가 설계)가 돌아
  사용자가 "같이 트래킹 잘 하자"고 해서 만든, 계속 덮어쓰는 문서다. 이력은 문서 끝 `## 이력`에 append. 템플릿 이탈 기록은 이 줄.

## 2026-09-19 — 파이프라인 입력 이름의 `_`를 `-`로

- 사용자 결정: 디렉토리·샘플 dir·파일 이름의 `_`는 mate 접미(`_1.fastq.gz`/`_2.fastq.gz`)만 남기고 전부 `-`로. 파이프라인이 `_`로 샘플명을 자르기 때문
  (사용자가 HiSeq 30x 서브샘플 트리를 손으로 `GIAB-publicData-Hiseq-subsampled-30x`로 바꿔 돌려 보고 확인). 병합은 2026-09-18에 15/15 끝난 상태였다.
- `03_make_pipeline_dirs.py`: 접두 기본 `GIAB-publicData`, DIRNAME 값·구분자 전부 `-`, 접두에 `_`가 있으면 거부. 완료 판정은 파일 크기라 이름을 바꿔도 병합을 다시 하지 않는다.
- 이미 만든 트리는 `04_rename_underscore_to_hyphen.sh`로 깊은 것부터 mv(파일 → 샘플 dir → 데이터셋 dir). 심볼릭 링크는 이름만 바뀌고 대상은 그대로.
  손으로 바꾼 트리와 겹치면 SKIP. 업체 디렉토리(G000-*)는 패턴이 달라 대상이 아니다. 샘플 dir 안의 concat.sh/list/log는 안 건드리고, 03을 다시 돌리면 새 이름으로 다시 쓴다.
- 링크는 심볼릭 링크가 기본(원본이 어느 파일시스템에 있든 동작). `--hard`는 같은 파일시스템일 때만.
- 샘플당 여러 쌍(HiSeq300x 최대 1,024쌍)은 `<sample>_<unit>_1/2.fastq.gz`로 이름을 유일하게 한다. 원본 파일명은 플로우셀이 다르면 겹친다
  (`2A1_CGATGT_L001_R1_001.fastq.gz`가 12개 플로우셀에 있다). 파이프라인이 샘플 dir 안의 여러 쌍을 병합하는지는 사용자가 확인.
- 링크는 데이터 복제가 아니라서 원본(`/BiO/scratch/ehojune/GIAB_benchmark/…`)을 옮기면 깨진다. 원본 위치를 바꾸면 스크립트를 다시 돌린다(멱등).

## 2026-09-17 — phase2(ONT)에 hap.py 정확도 평가 단계

phase2(ONT)에 hap.py 정확도 평가 단계를 붙였다(`phase2_ont/scripts/60_benchmark.sh`). phase1의 60을 본떴고
ONT 차이는 두 가지다. (1) **caller를 런마다 `dv_model` 열로 정한다** — R9.4.1에는 DeepVariant ONT 모델이 없어 Clair3 단독으로
돌기 때문이다. 전역 `CALLERS` 기본값을 쓰면 R9 런에서 없는 VCF를 찾다 실패한다. (2) `--collect` 출력에 `chem`·`basecaller` 열을
넣었다 — ONT indel 성능이 베이스콜러 버전으로 3.5배 갈리므로(2026-08-27 실측) 그 축 없이는 표를 읽을 수 없다.

- **평가 대상은 HG001~HG007 8런뿐이고 전부 Clair3 단독이다.** germline truth(v4.2.1)가 있는 샘플이 phase2에서는 전부 R9이고,
  DeepVariant가 도는 R10 6런은 전부 HG008이다. HG008 draft benchmark는 매니페스트에 들어와 있지만 `somatic-stvar`/`CNV`라
  단일 샘플 germline VCF 평가에 쓸 수 없다. 즉 **phase2에서 DeepVariant는 벤치마크되지 않는다.** 스크립트가 `dv_model`로
  자동 판정하므로 나중에 germline truth가 생기면 코드 수정 없이 포함된다.
- 그래서 2026-08-27에 남긴 ts/tv 열린 질문은 이 단계로 R9 8런까지만 답이 나온다. R10의 더 낮은 ts/tv(1.65~1.73)는 미해결이다.
  > **2026-09-22 후속: 위 두 줄은 모두 뒤집혔다.** HG002 R10 런을 들여와(2026-09-19, PR #17) truth 있는 R10 이 생겼고,
  > DeepVariant 가 처음 채점됐다(코드 수정 없이 `dv_model` 자동 판정 그대로). ts/tv 도 `62_tstv_regions.sh` 로 직접 재
  > R9·R10 양쪽에서 닫혔다. 이 항목은 그 시점의 판단으로 남겨 둔다 —
  > [2026-09-22-ont-r10-benchmark.md](reference/2026-09-22-ont-r10-benchmark.md).
- 벤치마크 이미지·자원 변수는 phase1과 같은 값으로 `phase2_ont/env.sh`에 뒀다. `$INFRA`를 공유하므로 phase1이 받아 둔
  hap.py 이미지를 그대로 쓴다.

## 2026-09-17 — phase2(ONT)에 Truvari SV 정확도 평가 단계

`61_benchmark_sv.sh`. Sniffles2 콜을 GIAB HG002 SV truth set 대비 Truvari로 채점한다. 소변이(60_benchmark.sh)와
분리한 이유는 도구·truth·대상 샘플·산출 형식이 전부 다르기 때문이다 — 한 스크립트에 넣으면 분기가 두 배가 된다.

- **truth를 `HG002_GRCh38_v5.0q_stvar`로 골랐다.** 매니페스트에서 GRCh38 germline SV truth를 가진 GIAB 샘플은
  HG002 하나다. 후보가 셋이었다.
  | 후보 | 판단 |
  |---|---|
  | `HG002_GRCh38_v5.0q_stvar` | **채택.** 전장, T2T-Q100 유래, `.benchmark.bed` 동봉 |
  | `HG002_GRCh38_CMRG_SV_v1.00` | 의학적 중요 유전자 한정(38 KB). 전장 성능 지표로는 못 씀 |
  | `HG002_SVs_Tier1_v0.6` | **GRCh37 전용.** 가장 널리 인용되지만 GRCh38 판이 없어 우리 런에 못 쓴다 |
  `latest/`에도 같은 파일이 있지만 버전 디렉토리(`v5.0q/`)를 본다 — 판이 바뀌면 수치가 바뀌는데
  `latest`를 보면 그 변화가 조용히 섞인다.
- **평가 대상은 HG002 2런(guppy-V3.4.5, UCSC_Ultralong_..._Promethion)이고 둘 다 R9.4.1이다.**
  60_benchmark.sh가 소변이에서 부딪힌 벽과 같다 — truth가 있는 샘플과 R10 런이 겹치지 않는다.
  **R10의 SV 성능은 이 단계로도 알 수 없다.** HG008 draft benchmark는 somatic-stvar/CNV라 germline 평가에 못 쓴다.
  > **2026-09-22 후속: 알 수 있게 됐다.** HG002 R10 런이 같은 truth(v5.0q)·같은 파라미터로 3번째 행이 됐다.
  > R10 이 R9 를 refine F1 +0.031 로 이기고 그 이득이 거의 전부 recall(+0.048)이다. HG008 은 여전히 해당 없음.
- **파라미터는 GIAB v5.0q README 지정값을 그대로 쓴다**(`--pick ac --passonly -r 2000 -C 5000 --refine`).
  자체 판단으로 고르지 않은 이유는 SV 매칭 파라미터가 결과를 크게 흔들어서, 근거를 댈 수 있는 값이
  "발행처가 지정한 값"뿐이기 때문이다. truvari 5.4.0 기본값과 다른 건 `-r`(500→2000)과 `-C`(1000→5000)뿐이다.
  **`-C`는 chunksize지 sizemin이 아니다** — 소스(`truvari/bench.py`, `variant_params.py`)로 확인했다.
  README가 `-d/--dup-to-ins`를 지정하지 않는 건 `--refine`이 그 표현 차이를 흡수하기 때문으로 읽었다.
  refine을 끄고 돌릴 거면 `BENCH_SV_ARGS="-d"`를 같이 줘야 한다(Sniffles는 `<DUP>`을 낸다).
- **refine을 기본으로 켰다.** 끄면 탠덤반복 구간의 Sniffles 콜이 표현 차이만으로 FP가 되어 수치가 실제보다
  나쁘게 나온다. 대신 기본 정렬기 poa가 **머신 간 비결정적**이라(truvari 문서) 재현이 필요하면
  `BENCH_SV_ALIGN=mafft`로 고정한다. `--collect`가 refine 전(`summary.json`)과 후
  (`refine.variant_summary.json`)를 `stage` 열로 **둘 다** 내보내는 건 이 때문이다 — 수치가 얼마나
  움직였는지 보이지 않으면 refine 값을 믿을 근거가 없다.
- truth의 `ALT=*`는 README가 "오분류되니 미리 걸러라"고 해서 `bcftools view -e 'ALT="*"'`로 한 번 걸러
  `$INFRA/reference/sv_truth/`에 캐시한다. 잡 안에서 만들면 동시 실행이 같은 파일을 덮어쓰므로
  로그인 노드(preflight/submit)에서 만들고, 중간에 죽어도 반쪽이 캐시로 남지 않게 임시 이름으로 쓴 뒤 옮긴다.
- mafft은 bioconda truvari 패키지의 런타임 의존성이라 핀한 이미지
  (`quay.io/biocontainers/truvari:5.4.0--pyhdfd78af_0`, quay.io에 실재 확인)에 들어 있다. 따로 받을 게 없다.

### 같은 PR에서 60_benchmark.sh의 Codex 지적 2건 반영

PR #6이 merge된 뒤 돌린 adversarial 리뷰가 3건을 냈다. 같은 파일을 건드리는 이 PR에서 두 건을 고쳤다.

- **중복 제출이 가드를 지나간다**(반영). `p2_job_alive`는 preflight 때 뜬 qstat 스냅샷을 보므로 방금 넣은 잡을
  못 본다 — 같은 dsid를 한 줄에 두 번 주면 같은 출력 경로에 잡 둘이 동시에 쓴다. 입력 dsid를 dedup해 막았다.
  `--ready`는 run_table의 1열(고유 키)을 읽어 원래 영향이 없었다.
- **qsub이 거부돼도 exit 0**(반영). 디스패치 루프의 `|| true`가 개별 실패를 삼켜 스크립트 전체는 성공으로
  끝났다. 실패를 모아 non-zero로 끝내되 루프는 멈추지 않게 `submit_many()`로 바꿨다.
- **노드당 메모리 초과 가능성**(기각). 8슬롯 잡 8개가 한 노드에 들어가면 명목 32G×8 = 256G > 251.1G라는
  지적. Codex 스스로 "관측된 OOM이 아니라 용량 추론"이라고 단 항목이고, **사용자가 8슬롯/32G는 안전하다고
  판정**해 그대로 둔다. 근거가 생기면 `BENCH_SLOTS`/`BENCH_SV_SLOTS`만 올리면 된다.

### PR #11 Codex adversarial 리뷰 1회차 — 5건 전부 반영

- **`--align` 은 `bench` 의 인자가 아니다**(high 상당, 실제 버그였다). `BENCH_SV_ALIGN=mafft`를 문서에 적어
  놓고 `truvari bench ... --refine --align mafft` 를 만들고 있었는데, 5.4.0 `bench.py` 파서에 `--align` 이
  없어 argparse 에러로 죽는다. 게다가 `--refine` 은 내부에서 `refine_main([args.output])` 을 **인자 없이**
  부르므로(bench.py:803) refine 쪽 옵션을 넘길 통로 자체가 없다. → refine을 `bench` 뒤의 **별도 단계**로
  분리했다. 기본값으로 돌리면 `--refine` 과 결과가 같고, `-a`/`-t` 를 우리가 정할 수 있다(threads는 4 → 슬롯 수).
- **실행 전에 기존 결과를 지우던 것**(반영). `truvari bench` 는 출력 디렉토리가 있으면 거부해서 잡 시작부에
  `rm -rf "$out"` 을 뒀는데, 그러면 몇 시간짜리 잡이 죽거나 같은 dsid가 두 번 들어왔을 때 멀쩡한 결과만
  날린다. 잡별 임시 디렉토리(`truvari.inprogress.$JOB_ID`)에서 돌고 전 단계 성공 후에만 제자리로 옮긴다.
  **부수 효과가 더 크다** — 중간에 죽은 실행이 반쪽 `summary.json` 을 남기지 않으므로 다음 제출이
  그걸 완료로 오판하지 않는다(리뷰의 별도 지적 1건이 같이 해소됐다).
- **완료 판정이 `summary.json` 하나였던 것**(반영). refine을 켰으면 `refine.variant_summary.json` 까지
  있어야 완료로 본다. bench만 끝나고 refine에서 죽은 결과를 완료로 세면 다음 제출이 조용히 건너뛴다.
- **truth 캐시 공개가 안전하지 않던 것**(반영). 임시 파일명에 PID를 넣어 두 세션이 서로의 `.tmp` 를
  자르지 못하게 했고, 두 번의 `mv` 실패를 삼키고 성공을 반환하던 것을 고쳤다. `.tbi` 를 먼저 옮기는
  순서는 유지한다 — 캐시 판정이 vcf.gz + .tbi 를 둘 다 보므로 그래야 "둘 다 있다"가 "완성됐다"가 된다.
- **잡 스크립트·jobid 쓰기 실패를 안 보던 것**(반영, 60·61 양쪽). 호출부의 `|| rc=1` 이 함수 안 errexit를
  끄기 때문에 쓰기가 실패해도 그대로 진행해 **예전 잡 스크립트를 제출**할 수 있었다. 둘 다 확인한다.
  jobid 기록 실패는 잡이 이미 들어간 뒤라 실패로 보고하되 잡 번호를 반드시 출력한다(사람이 qdel 해야 한다).

이 라운드에서 내가 만든 회귀도 하나 있었다: 잡 본문의 refine 블록을 `${refine_cmd:+...}` 로 끼워 넣었더니
확장 과정의 quote removal로 `echo "== ... (align=poa) =="` 의 따옴표가 벗겨져 괄호가 노출됐다 — 생성된
잡이 문법 에러로 죽는다. 분기를 잡 스크립트 **안**의 `if` 로 옮겨 해결했다(생성된 잡에 `bash -n` 을 돌려 잡음).

### PR #11 Codex 리뷰 2회차 — 3건 반영

1회차가 남긴 동시성·정리 문제다. Codex가 같은 라운드에서 **truvari 5.4.0이 우리가 넘기는 플래그를 받고
`bench`가 `refine`이 요구하는 `candidate.refine.bed`를 만든다는 것**을 소스로 확인해 줬다 — 1회차의 구조 변경이 맞았다.

- **truth 캐시의 VCF와 인덱스가 엇갈릴 수 있었다**(반영). 파일 둘을 각각 `mv` 하면 두 세션이 A인덱스→B인덱스→
  B본체→A본체 순으로 엇갈려 A의 VCF에 B의 인덱스가 붙은 채 공개될 수 있다. bcftools가 헤더에 실행 명령
  (임시 경로 포함)을 적으므로 같은 입력이어도 바이트가 달라 인덱스 오프셋이 어긋난다 — 죽지 않고 **조용히
  엉뚱한 레코드를 읽는** 종류라 더 나쁘다. VCF+인덱스를 디렉토리 하나에 담고 그 **디렉토리를 통째로 rename**
  하도록 바꿨다. 디렉토리 rename은 원자적이라 읽는 쪽은 옛 쌍이나 새 쌍만 보고 섞인 걸 볼 수 없다.
  경쟁에서 지면(mv 실패) 상대의 완성본을 쓴다 — 락이 필요 없다.
- **결과 공개가 옛 결과를 먼저 지우고 있었다**(반영). `rm -rf $out` 뒤 `mv` 사이에서 죽으면 둘 다 잃는다.
  옛 것을 `.prev.$JOB_ID` 로 옆에 치워 두고, 새 것이 자리를 잡은 뒤에 지운다. 실패하면 옛 것을 되돌린다.
  그리고 **`mv -T` 를 쓴다** — 목적지가 디렉토리로 존재하면 그냥 `mv` 는 그 **안으로** 옮겨 놓고 성공을 내서,
  결과가 한 단계 중첩된 채 "ALL DONE"이 찍힌다. `-T` 는 그 경우 실패한다.
- **죽은 잡의 작업 디렉토리가 쌓이던 것**(반영). `WORK` 이름에 `$JOB_ID`가 들어가 재시도마다 새 이름이 생긴다.
  잡에 EXIT trap을 달아 실패 시 치우고, SIGKILL이면 trap이 못 도므로 제출 쪽에서도 한 번 훑는다 —
  살아 있는 잡이 없음을 이미 확인한 지점이라 남은 `inprogress`/`prev` 는 전부 죽은 잡의 잔여물이다.

여기서도 내가 만든 회귀가 둘 있었고 둘 다 테스트로 잡았다. (1) `[ -n "$PREV" ] && rm -rf "$PREV"` 를
마지막 명령으로 두면 PREV가 빌 때 test가 1을 내고 `set -e` 가 스크립트를 죽인다 — `if` 로 바꿨다.
(2) 주석에 넣은 백틱이 **unquoted heredoc 안에서는 생성 시점에 명령 치환으로 실행된다.** 주석이어도 그렇다.

검증은 생성된 잡을 **실제로 실행해서** 했다(truvari를 흉내내는 mock): 정상 완주 / refine 실패 시 이전 결과
보존 + 잔여물 0 / 잔여 디렉토리 청소 / 재공개 시 중첩 없음, 그리고 tabix 실패 시 반쪽 캐시가 남지 않는 것까지.

### PR #11 Codex 리뷰 3회차 — 한도 소진으로 중단, 남긴 실마리 1건은 반영

Codex가 3회차 도중 사용 한도로 멈췄다("You've hit your usage limit", 재설정 2026-09-17 20:36).
구조화된 결과는 못 받았지만 끊기기 직전 한 줄을 남겼다 — "The stale-directory sweep runs before the
`DRY` check." **확인해 보니 맞았다.** 그 지적과, 그 자리에서 같이 보인 것 둘을 내가 마저 고쳤다.

- **DRY=1이 파괴적이었다**(반영). 잔여물 청소가 DRY 조기 반환보다 **앞에** 있어서, 미리보기 모드가
  `rm -rf` 를 돌리고 있었다. DRY 반환 뒤로 옮겼다.
- **살아 있는 잡의 작업 디렉토리를 지울 수 있었다**(반영). 청소 근거가 "dsid 단위 `p2_job_alive` 를
  통과했으니 이 dsid로 사는 잡이 없다"였는데, **jobid 파일 기록이 실패한 잡**은 살아 있어도 alive 판정을
  못 받는다(그 실패 경로는 이번 PR에서 우리가 새로 만든 것이다). 그러면 그 잡이 지금 쓰고 있는
  `inprogress` 를 지워 몇 시간짜리 작업을 날린다. 디렉토리 이름 끝의 **잡 번호를 qstat 스냅샷에서 직접
  확인**하도록 바꿨다(`p2_sge_queued`). 큐에 있으면 건너뛰고 그 사실을 출력한다.
- 공개 실패 시 롤백의 `[ -n "$PREV" ] && mv -T ...` 를 `if` 로 바꿨다. 지금은 바로 뒤가 `exit 1` 이라
  동작이 같지만, 뒤에 무언가 추가되면 `set -e` 가 그 자리에서 잘라먹는다.

Codex가 물었던 나머지는 확인 결과 문제가 없었다. nullglob이 꺼져 있어 매치가 없으면 패턴이 그대로
오는데 `[ -d "$stale" ] || continue` 가 걸러낸다. EXIT trap은 성공 경로에서 `trap - EXIT` 로 풀고,
실패 경로에서 trap의 test가 1을 내도 스크립트 종료 코드는 유지된다(생성된 잡을 실제로 돌려 확인:
첫 실행·재실행 exit 0, refine 실패 exit 1, 세 경로 모두 잔여물 0). truth 캐시는 `$tmp` 를 다 만든 뒤
디렉토리를 rename하므로 목적지가 불완전한 상태로 보이는 창이 없다(같은 파일시스템이라 rename은 원자적).

3회차가 온전히 끝나지 않았으므로 **이 PR은 2.5라운드 검토를 받은 셈이다.** 남은 위험은 동시 실행
시나리오이고, 실사용은 로그인 노드에서 사람이 한 번에 하나씩 돌리는 형태다.

## 2026-09-18 — phase0 다운로드 완료, 속도 예측은 틀렸다

- 2026-09 크롤 반영본을 전부 받았다. 12개 카테고리 100.0%, 81,302/81,302 files · 116,509.5 GiB.
  카테고리 합계가 manifest 합계와 파일 수·바이트까지 같다. 기록은 `docs/runs/2026-09-18-phase0-download-complete.md`.
- **S3 미러 가용성으로 소요 시간을 추정한 것이 틀렸다.** 신규 데이터가 S3에 거의 없으니(표본 96건 중 1건)
  FTP fallback 속도로 "며칠"을 잡으라고 적었는데, 실측은 28시간 49분 · 평균 92 MB/s로 S3 실측치(83 MB/s)보다 빨랐다.
  표본은 어느 경로로 받는지를 알려줄 뿐 실효 대역폭을 알려주지 않는다. 앞으로 소요 시간은 표본이 아니라 실측 대역폭으로 잡는다.
- 받지 않기로 한 3건(12,423 files / 10.69 TiB)은 manifest에 없어 이번 실행 대상이 아니었다. 결정이 그대로 지켜졌다.

## 2026-09-18 — phase2 ONT 정확도 평가 첫 실측과 그 결과 바뀐 것

10잡(hap.py 8 + Truvari 2) 전부 exit 0. 수치는
[docs/reference/2026-09-18-ont-benchmark-first-results.md](reference/2026-09-18-ont-benchmark-first-results.md),
실행 기록은 [docs/runs/2026-09-18-phase2-ont-benchmark.md](runs/2026-09-18-phase2-ont-benchmark.md).

- **2026-08-27의 ts/tv 열린 질문을 R9에서 닫았다.** 벤치마크 구간 안의 SNP precision이 0.990~0.997이라
  구간 안에는 FP가 거의 없다. 낮은 genome-wide ts/tv는 구간 밖(반복서열 등) 콜에서 온다 —
  HG005 기준 구간 밖 약 0.99M이 ts/tv ≈ 1.33이면 전체 1.88이 설명된다. 콜러·파이프라인 문제가 아니다.
  (2026-09-21 정정: 처음 1.15로 적었는데 **가중치를 전체 SNV 수로 잡은 오류**였다. ts/tv의 분모는
  Tv이므로 Tv로 가중하거나 카운트를 복원해 빼야 한다 — 전체 Ti 2.787M·Tv 1.483M에서 구간 안
  Ti 2.220M·Tv 1.057M을 빼면 구간 밖이 Ti 0.567M·Tv 0.425M = 1.33이다. 결론 방향은 같다.)
  R10(HG008 6런)은 truth가 없어 같은 방법을 못 쓴다.
- **indel 격차 수치를 갱신했다.** 2026-08-27에 PASS indel 개수로 "guppy 3.2.x가 4.2.2보다 3.5배"라고
  적었는데, truth 대비로 보니 그 여분이 거의 전부 FP였다 — **FP 기준 42배**다. 그리고 precision(6.3배
  개선)과 recall(1.8배)이 다르게 움직여 guppy 4.2.2조차 indel recall은 .68~.75다.
  "R9 indel은 4.2.2에서만 신뢰할 만하다"는 결론은 유지되지만 그 4.2.2에도 단서가 붙는다.
- **`--refine`을 기본으로 켠 판단이 실측으로 뒷받침됐다.** F1을 4.8~5.1점 올리고 비용은 5분이다.
  설계 시점의 유일한 미지수였던 poa 런타임 걱정이 기우였으므로, 재현이 필요하면 결정적 정렬
  (`BENCH_SV_ALIGN=mafft`)로 바꿔도 감당할 만하다.
- **`h_vmem`이 강제 종료 한도가 아니다.** 32G로 선언한 truvari 잡이 maxvmem 73 GB를 쓰고도 exit 0으로
  끝났다. `consumable=NO`(예약 안 함)는 알고 있었지만 상한으로도 동작하지 않는다는 건 처음 확인했다.
  `env.sh`의 "잡별 상한(넘으면 kill)" 주석을 고치고, 값은 실측에 맞춰 뒀다(`BENCH_SV_VMEM` 32G→80G,
  `BENCH_VMEM`은 실측 23.7~24.5 GB라 32G 유지). **값이 강제력이 없어도 실측과 맞춰 둔다** — 안 맞으면
  다음 사람이 노드 용량을 잘못 계산한다. Codex가 PR #11에서 낸 메모리 지적이 SV 쪽에서는 근거를 얻은 셈이다.
- 벤치마크 커버리지의 한계를 명시해 뒀다: 14 primary 런 중 소변이 8 / SV 2만 평가 가능하고, R10 6런과
  DeepVariant는 **구조적으로** 평가할 수 없다(truth가 있는 샘플과 겹치지 않는다). GIAB FTP에 HG002
  R10 ONT는 없다(매니페스트 확인). 열려면 외부 수급이 필요하고 후보 조사는 아직 안 했다.

## 2026-09-19 — phase2에 HG002 R10.4.1을 외부에서 들여온다 (벤치마크 공백 메우기)

2026-09-18 실측으로 드러난 구조적 공백: truth가 있는 샘플(HG001~HG007)은 phase2에서 전부 R9.4.1이고
R10은 전부 HG008(germline truth 없음)이라 **R10 정확도도 DeepVariant도 한 번도 채점된 적이 없다.**
GIAB FTP에 HG002의 R10 ONT는 없다(매니페스트 확인: ONT 디렉토리 셋 전부 R9 시절). 공개 데이터를
찾아 ONT 자체 배포본을 쓰기로 했다.

- **출처: `s3://ont-open-data/giab_2025.01/`** (ONT 공개 데이터, 익명 다운로드). 직접 확인했다 —
  익명 S3 ListBucket으로 HG001~HG007 7샘플이 전부 있고, EPI2ME 공지가 SQK-LSK114 / Dorado v0.8.2 /
  `dna_r10.4.1_e8.2_400bps@v5.0.0` / 샘플당 플로우셀 2개 × ~140 Gbase를 확인해 준다.
- **라이선스는 CC BY-NC 4.0 = 비상업 연구 한정.** 사용자가 이 프로젝트는 상업 목적이 아니라고
  확인해 진행한다(2026-09-19). 제약 자체는 ext_manifest·README·이 기록 세 곳에 남겨 데이터와 함께
  따라다니게 했다.
- **HG002만 먼저 받는다**(사용자 결정). HG002가 소변이(v4.2.1)와 SV(v5.0q) truth를 둘 다 가진 유일한
  샘플이라 **R10 소변이 · R10 SV · DeepVariant 셋을 한 런으로 연다.** HG001·HG003~HG007은 소변이
  truth만 있고 나중에 천천히 붙인다.
- **플로우셀 PAW70337 하나만 받는다(160 GiB).** 둘을 받으면 ~90x가 되지만, ONT가 **플로우셀 단위로**
  자체 hap.py 결과를 공개해 뒀기 때문에(`analysis/happy-benchmark/sup/HG002_PAW70337`,
  SNP F1 .9983 / INDEL F1 .9147) 하나만 받아야 같은 입력에 대한 외부 대조군이 생긴다. 우리 수치가
  거기서 크게 벗어나면 우리 쪽 문제라는 신호가 된다.
- **진입은 aligned BAM이다 — phase2에서 유일하다.** ONT는 POD5와 정렬 BAM만 배포하고 uBAM·fastq를
  내지 않는다. POD5 재베이스콜은 정책상 제외이므로 `fastq > uBAM > aligned BAM` 순서에서 쓸 수 있는
  가장 raw한 형태가 정렬 BAM이다. 파이프라인은 원래 `aligned_bam` 진입을 지원하고 `.bai`도 함께
  배포되므로 배선 변경이 없다. **대가: 정렬이 우리 것이 아니라서(ONT도 minimap2) R9↔R10 비교에
  정렬이 교란으로 남는다.** 재정렬하면 이 교란은 없어지지만 ~300 GiB 전환 + 90x 재정렬 비용이 들고
  ONT 대조군과의 비교축도 흐려진다 — 교란을 기록하는 쪽을 택했다.
- **ONT가 이미 자체 벤치마크를 냈다는 점을 값어치 판단에 반영했다.** 우리가 새로 알아내는 것은
  "R10 절대 정확도"가 아니라 **"우리 파이프라인으로 R9↔R10을 한 잣대로 비교한 결과"**다.
  그게 이 프로젝트의 목적이므로 중복이 아니다.

### 같이 고친 것

- `ext_manifest.tsv`에 **md5 열**을 추가했다. 160 GiB를 크기만으로 믿을 수 없다. ONT가 md5sums.txt를
  공개하므로 값이 있다(기존 2행은 출처가 공개 안 해 `-`). 한 번 통과하면 `<파일>.md5ok`에 **검증한
  값을 적어** 다시 계산하지 않는다 — 존재만 보면 기대 md5가 바뀌었을 때 낡은 스탬프가 통과시킨다.
- `02_fetch_external_reads.sh`의 탭 파싱을 고쳤다. `IFS=$'\t' read`는 탭이 IFS 공백류라 빈 칸에서
  필드가 밀린다(phase3에서 이미 당한 것). awk가 0x1F로 바꿔 넘기게 했다. BAM은 리드 길이로 검증할 수
  없으므로 `samtools quickcheck` + 헤더의 베이스콜 모델이 R10인지로 본다.
- **`35_review_qc.py`의 `N50미산출` 판정이 틀렸다.** whatshap의 `block_n50`은 사실 **NG50**이고
  (유전체 길이 기준), 블록 span 합이 유전체의 절반에 못 미치면 **정의상 0**을 낸다. 미산출이 아니라
  "위상 블록이 절반도 못 덮는다"는 진짜 측정값이다. 50% 지점에서 절벽처럼 떨어져 0과 정상값 사이에
  중간이 없다(HG008-N-D 9048블록/526kb는 간신히 위, HG008T-p2 10577블록/0은 아래). 라벨을 고쳤다.

### PR #17 Codex adversarial 리뷰 1회차 — 5건 전부 반영

Codex가 매니페스트 소비자를 전수 추적해 확인해 준 것: phase3는 자기 매니페스트를 읽으므로 md5 열
추가로 인한 열 밀림이 없고, `aligned_bam` + 빈 unit 조합을 main.nf가 받으며, NG50 재라벨이
whatshap 2.8 소스와 일치한다.

- **`.bai`가 준비 상태 판정에서 빠져 있었다**(반영). 샘플시트는 인덱스를 명시적으로 가리키는데
  inputs_manifest에는 BAM만 있었다. `KIND=reads`로만 받으면 BAM만 있고 .bai가 없는 상태가 실제로
  생기는데, `p2_inputs_state`가 그걸 ready로 보고 잡을 넣고, 잡은 main.nf의 인덱스 검사에서 죽는다.
  `load_ext()`가 인덱스도 돌려주게 해 inputs_manifest에 넣었다.
- **VERIFY_ONLY가 검증을 건너뛰고 있었다**(반영). 이건 **내가 이 PR에서 만든 회귀다** — 크기가 맞으면
  일찍 continue 하게 해서, 원래 하던 md5·내용 검사를 통과 없이 지나쳤다. 크기만 맞는 손상 파일이
  점검을 통과한다. 조기 continue를 걷어냈다(크기만 보고 싶으면 `SKIP_MD5=1`을 같이 준다).
- **md5 스탬프가 파일 정체성에 묶여 있지 않았다**(반영). 기대 md5만 적어 두면 **같은 크기로 파일이
  바뀌었을 때** 낡은 스탬프가 통과시킨다. `기대md5 크기 mtime` 셋을 적어 비교하고, 재다운로드 직전에
  스탬프를 먼저 지운다.
- **BAM 검증 실패를 성공으로 취급하던 경로 둘**(반영). samtools 컨테이너가 없으면 "생략"하고 성공을
  냈고, `samtools view -H`가 죽어도 `|| true` 때문에 "모델 정보 없음"으로 흘러 OK가 찍혔다. 둘 다
  실패로 바꾸고, 이미지 경로는 하드코딩 대신 `p2_img_path`/`p2_container_uris`로 끌어온다
  (03_dup_evidence.sh와 같은 방식 — 컨테이너 판을 올릴 때 여기만 어긋나지 않게).
- **전처리(awk) 실패가 성공으로 보였다**(반영). 프로세스 치환 안이라 종료 코드가 rc로도 pipefail로도
  안 올라온다 — 매니페스트가 깨지면 "0건 처리 후 완료"가 찍힌다. 읽은 행 수를 세어 기대 건수와
  비교하고, 매니페스트를 읽을 수 없거나 비어 있으면 시작 전에 죽는다.

## 2026-09-21 — 스모크 테스트가 진입 타입 셋 중 둘만 덮고 있었다

HG002 R10 런을 제출하기 직전에 확인해 보니 **`aligned_bam` 진입은 phase2에서 한 번도 실행된 적이
없었다.** 파이프라인은 세 타입(`fastq`/`ubam`/`aligned_bam`)을 지원하는데 `04_stub_test.sh`의 시트는
앞의 둘만 태운다. phase1은 타입 이름 자체가 다르므로(`hifi_bam`) 그쪽 경험도 넘어오지 않는다.

`aligned_bam` 단독은 분기가 두 군데 갈린다 — 모든 행이 `aligned_bam`이면 `MINIMAP2_INDEX`를 아예
건너뛰고, unit 1개 + 인덱스 제공이면 `FINALIZE_BAM`도 건너뛰는 passthrough다. **섞인 시트로는 두 분기
모두 못 탄다.** 그래서 시트·프로파일을 따로 뒀다(`test_prealigned`)고 `04_stub_test.sh`가 stub를 두 번
돌린다. 1분짜리라 비용은 없다.

- passthrough에서는 **`02_alignedBAM/<id>.bam`이 재발행되지 않는 것이 정상이다** — 원본 BAM을 그대로
  쓴다. 스모크 테스트가 그 부재를 **명시적으로 확인한다**(생기면 실패). `30_verify_outputs.sh`는
  원래부터 같은 전제로 짜여 있었다(43행).
- `35_review_qc.py`의 메틸 검사는 `entry == "ubam"` 게이트라 이 런은 `MM%`가 `.`로 나온다. 맞는
  동작이다 — BAM을 손대지 않고 통과시키므로 우리 파이프라인이 태그를 깨뜨릴 여지가 없다.

## 2026-09-21 — HG002 R10을 ONT 정렬 그대로 쓰지 않고 **재정렬**한다 (설계 정정)

PR #17에서 이 런을 `aligned_bam` 진입으로 넣었다. **잘못된 선택이었다.** 사용자가 파이프라인 설계
당시 준 원칙이 "fastq가 있으면 fastq부터 시작하고, **GIAB의 run 결과물(aligned bam 포함)을 믿기보다
우리가 한 결과물을 믿는다**"였다. `aligned_bam` 진입이 코드에만 있고 쓰는 런이 하나도 없던 이유가
그것인데, 나는 그걸 "쓸 수 있는 가장 raw한 형태"로만 읽고 넘어갔다.

**그리고 이 런을 넣은 이유가 R9↔R10 비교다.** 나머지 14런은 우리 정렬이고 이 하나만 ONT 정렬이면
비교축에 정렬이 교란으로 박힌다. PR #17에서 그걸 "기록해 둔다"로 처리했는데, 원칙상 받아들이면 안 되는
종류의 교란이었다.

- 진입 타입 `aligned_bam_realign`을 새로 만들었다. 정렬 BAM에서 `samtools fastq`로 리드를 꺼내
  **우리 minimap2로 다시 정렬한다.** uBAM 진입과 같은 경로를 타므로 프로세스 추가는 없다.
  `aligned_bam`(정렬을 그대로 쓰는)은 코드에 남겨 두되 쓰는 런은 계속 없다.
- 재그룹에서 `type`이 `'ubam'`으로 하드코딩돼 있어 진입 타입이 유실됐다 — 그룹 키에 넣어 살렸다.
  안 고쳤으면 realign 런이 uBAM으로 취급돼 아래 태그 문제를 그대로 맞았을 것이다.
- **메틸 태그(MM/ML)는 넘기지 않는다.** 역가닥으로 정렬된 리드는 SEQ가 역상보로 저장돼 있고
  `samtools fastq`가 그걸 되돌리는데, MM 오프셋이 저장 방향에 묶여 있어 그대로 옮기면 메틸 위치가
  조용히 어긋날 수 있다. samtools 문서(`fastq`·`reset`)가 이 경우를 다루지 않아 확인이 안 됐다.
  **이 런의 목적은 변이 정확도이므로 태그를 버려 조용히 틀리는 쪽을 없앴다.** 대가는 R10 메틸화를
  이 런에서 못 보는 것인데, 그건 ONT 원본 BAM(태그가 정상인 상태로 디스크에 있다)을 직접 쓰면 된다 —
  메틸화 분석에는 ONT 정렬을 써도 무방하다.
- 비용: `samtools fastq` 추출 + ~45x ONT 재정렬. 몇 시간 늘어나지만 비교축의 교란을 없애는 값이다.

### 스모크 테스트도 같이 고쳤다

제출 직전에 확인해 보니 **`aligned_bam` 계열 진입은 phase2에서 한 번도 실행된 적이 없었다.**
`04_stub_test.sh` 시트가 fastq·uBAM 둘만 태운다. phase1은 타입 이름이 달라(`hifi_bam`) 경험이
넘어오지도 않는다. 지금은 `test` 시트에 `aligned_bam_realign` 행을, `test_prealigned` 프로파일에
`aligned_bam` 단독 시트를 둬서 셋을 다 덮는다. 단독 시트가 따로 필요한 이유는 "모든 행이
`aligned_bam`이면 `MINIMAP2_INDEX`를 건너뛴다" 같은 조건이 섞인 시트에서는 영영 거짓이기 때문이다.

## 2026-09-22 — 큐/노드를 이름으로 박지 않고 qstat과 대조해서 쓴다

쓸 수 있는 노드가 또 바뀌었다. 2026-08-22엔 `shepherd.q`의 shepherd-1-7/8/9 셋이었는데
2026-09-22 기준으로 **octopus-2-8, octopus-2-9, shepherd-1-8, shepherd-1-9 넷**이고
**큐가 둘로 갈렸다**(octopus.q가 다시 살아났다). 전 노드 64코어 / 251 GB로 스펙은 같다.

한 달 사이 두 번 바뀐 값을 코드와 문서 열 곳에 박아 두고 있었다. 그래서 값을 고치는 대신
**틀린 값이 조용히 통과하지 못하게** 만들었다.

- 큐에 없는 노드를 `-l h=`로 지정하면 qsub은 받아들이고 **잡은 영원히 `qw`로 남는다.**
  에러도, 로그도 없다. 반대로 `-q`에 없는 큐 이름을 넣으면 그 순간 잡 전체가 거부된다.
  둘 다 한참 뒤에야 알게 되는 실패다.
- `lib.sh`에 `*_sge_targets`(SGE_QUEUE x SGE_HOSTS ∩ `qstat -f`)를 두고,
  `*_require_sge_targets`가 겹치는 인스턴스가 없으면 **제출 전에** 막으면서 실제 고를 수 있는
  목록을 찍는다. `*_sge_queue_arg`는 실재하는 큐만 남겨 `-q`를 만든다 — SGE_QUEUE에 옛 이름이
  섞여 있어도 그것 때문에 잡이 거부되지 않는다.
- 이제 노드가 바뀌면 `env.local.sh`의 두 줄(`SGE_QUEUE`, `SGE_HOSTS`)만 고치면 되고,
  안 고치면 제출이 막힌다. `01_prepare_login_node.sh`가 현재 대상 인스턴스를 찍어 준다.
- `SGE_QUEUE`는 이제 콤마 목록을 받는다(`shepherd.q,octopus.q`).

검증은 합성 픽스처로 네 가지를 돌려서 했다: 4노드 2큐 정상, shepherd만 지정 시 `-q`에서
octopus.q 탈락, 없는 노드 지정 시 차단 + exit 1, 없는 큐 이름이 섞여도 유효한 것만 남음.

## 2026-09-22 — phase1에 Truvari SV 평가 단계 (phase2 61_benchmark_sv.sh 이식)

phase2의 `61_benchmark_sv.sh`를 phase1로 옮겼다. 파라미터·truth 캐시 전략·결과 공개 방식은
그대로고(GIAB v5.0q README 지정 명령, ALT=* 선제거, 임시 디렉토리 → 원자적 rename),
입력만 Sniffles → **pbsv**(`03_VCF/SV_pbsv/`)로 바뀐다. truth 캐시는 `$INFRA/reference/sv_truth`를
phase2와 **공유**한다 — 같은 truth를 같은 필터로 거른 것이라 두 벌 만들 이유가 없다.

**phase1 쪽이 phase2보다 답이 많이 나온다.** GRCh38 germline SV truth를 가진 GIAB 샘플은
HG002 하나뿐인데, phase2의 HG002 런은 둘 다 R9.4.1이라 화학종 비교가 안 됐다. phase1의 HG002
런은 다섯이고 dup_of가 전부 비어 있으며 **기기 세대가 셋으로 갈린다** —
Sequel I 둘(m54) + Sequel II 둘(m64) + Revio 하나(m84). 같은 truth·같은 파라미터로
**세 세대의 SV 성능을 직접 비교**할 수 있다. `--list`/`--collect`의 `instr` 열이 그 축이다.

### 같이 통일한 것 (phase2 → phase1)

- `60_benchmark.sh`: `.fai` 자동 생성(hap.py가 요구하는데 만드는 곳이 없었다 — 파이프라인의
  SAMTOOLS_FAIDX는 Nextflow work 안에만 만든다), 잡 스크립트 쓰기 실패 감지,
  qsub stderr 포착 + jobid 검증, `submit_many()`/`dedup_dsids()`.
- `10_submit.sh`(**양쪽 phase 다**): 위와 같은 qsub 하드닝. 여기는 phase2에도 없었다 —
  실패하면 빈 jobid 파일을 쓰고 `OK`를 찍는다(큐에는 아무것도 안 들어갔는데).
- `env.sh`: `BENCH_SV_*` 6개 변수, h_vmem이 상한도 아니라는 2026-09-18 실측 주석.
- `env.local.sh.example`(양쪽): 벤치마크 잡 크기 프리셋 절. 실측 maxvmem(hap.py 24.5 GB,
  truvari 73 GB) 기준으로 파이프라인 잡과 노드를 나눠 쓸 때의 슬롯 계산을 적었다.

### 같은 커밋 Codex 리뷰 — 3건 전부 반영

초판(85a9fbb)을 밀고 나서 받은 리뷰다. 세 건 다 실제 결함이었고 셋 다 고쳤다.

- **[P1] `10_submit.sh`에 리터럴 `
`** (양쪽 phase). `echo "$jid" > ... 
 || {...}` 가 줄
  연속이 아니라 escaped `n` 이라 jobid 파일에 `900123 n` 이 들어간다(실증). `p1_job_state` 가
  qstat 번호와 `==` 비교하므로 **중복 제출 가드가 그 dsid에 영영 무력**해진다 — 같은 work·출력
  디렉토리에 파이프라인 둘이 붙을 수 있었다. `bash -n` 은 통과한다.
  Codex는 "제대로 된 백슬래시+개행으로 바꾸라"고 했지만 **백슬래시를 아예 없앴다**(`if ! ...; then`).
  같은 사고가 2026-08-27에도 있었고 원인이 같다 — Bash 툴 heredoc의 이스케이프 뭉갬. 재발 가능한
  형태를 남기지 않는 쪽을 골랐다.
- **[P1] `BENCH_SV_SLOTS=8` 이 노드를 터뜨린다.** phase2에서 그대로 가져온 값인데, truvari는
  실측 maxvmem 67~73 GB다. 8슬롯이면 64코어 노드에 8잡이 올라가 최대 584 GB — 251 GB를 크게
  넘는다. h_vmem은 예약도 상한도 아니라 아무도 안 막는다. phase2는 `--ready` 대상이 HG002 2런뿐이라
  우연히 안전했고, phase1은 5런이라 실제로 터질 수 있었다. **22로 올렸다**(노드당 2잡 = 146 GB).
  양쪽 phase 다 고쳤다 — phase2도 대상이 늘면 같은 문제다.
- **[P2] 기기 세대 라벨이 틀렸다.** `instr_of()` 를 dataset 이름으로 때려잡았는데,
  `HG002.PacBio_CCS_10kb`/`_15kb` 는 이름에 세대 표시가 없고 **실제로는 m54(Sequel I)** 다.
  초판은 이 둘을 Sequel II로 묶어, **이 스크립트가 내세우는 비교축 자체를 조용히 망가뜨렸다.**
  `lib.sh`의 `p1_instr_of` 로 옮겨 `inputs_manifest.tsv` 의 movie ID로 판정한다
  (m84=Revio, m64=Sequel II, m54=Sequel I, m14/m15=RS II). 38런 분포: Revio 18 / Sequel II 15 /
  Sequel I 2 / 판정불가 3. 판정불가 셋(HG003·6·7 chemistry2)은 파일명에 movie ID가 없어 `-`로
  둔다 — 경로의 `PBmixSequel<NNN>` 은 세대 표시가 아니라 혼합 런 명명이라 근거가 못 된다
  (HG001.HudsonAlpha_PacBio_CCS 는 PBmixSequel846 디렉토리 안에 m64 movie가 들어 있다).
  **셋 다 HG002가 아니라 SV 평가 대상이 아니므로 추측하지 않는다.**

## 2026-09-22 — phase1 hap.py 첫 실측으로 바뀐 것

19런 × 2 caller = 38건, 전부 exit 0. 수치는
[reference/2026-09-22-pacbio-hifi-benchmark-first-results.md](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md).
결정만 여기 적는다.

- **PacBio HiFi 소변이의 기본 caller는 DeepVariant다.** Sequel II 12런에서 두 caller는 동률
  (INDEL F1 차 −0.002~+0.001)인데 Revio 3런에서만 Clair3가 −0.006~−0.017로 진다. 모델 오배정이
  아니다 — 세 런 다 `hifi_revio`를 제대로 받았다. Clair3는 버리지 않고 교차 확인용으로 둔다.
- **Sequel I 런(HG002 CCS_10kb·CCS_15kb)은 INDEL 비교에서 세대를 명시하지 않으면 쓰지 않는다.**
  INDEL F1 0.9282·0.9646으로 나머지(0.9747~0.9973)와 확연히 갈린다. caller 모델 탓이라는 의심은
  DeepVariant가 배제한다 — 기기별 모델이 없어 19런을 같은 PACBIO 모델로 돌았는데도 같은 격차다.
- **SNP는 더 파지 않는다.** 38건 전부 0.99844~0.99941(평균 0.99902)이라 기기·caller 어느 축으로도
  신호가 없다. 앞으로 PacBio 비교는 INDEL과 SV로 한다.
- `BENCH_SLOTS` 기본값을 8 → **16**으로. 실측 maxvmem이 16슬롯에서 48.4~48.8 GB였다(phase2가 8슬롯
  24 GB). **메모리가 스레드 수에 비례**하는 것으로 보여 노드 총량은 어느 쪽이든 ~192 GB로 수렴한다.
  실제로 완주한 조합을 기본값으로 둔다. `BENCH_VMEM`도 32G → 56G (표시용이지만 실측과 맞춘다).

### 큐/노드 게이트의 한계 — 처음 주장은 과했다

같은 날 `*_require_sge_targets`를 넣으면서 "노드가 바뀌면 스크립트가 막아 준다"고 적었는데,
**허용 여부는 못 본다.** 실측하니 `qstat -f`에 octopus-2-1~2-11 + shepherd-1-1~1-14, 큐 인스턴스가
**스물다섯 개** 다 뜬다. 그중 우리 몫이 넷이라는 건 SGE ACL이 아니라 사람끼리의 약속이라
스크립트가 알 길이 없다.

게이트가 실제로 막는 건 **존재하지 않는** 큐·노드다(오타, 폐기된 이름). 그것도 값어치는 있다 —
그 경우 잡이 에러 없이 `qw`로 영원히 남기 때문이다. 하지만 허용 목록은 여전히 사용자에게 물어서
`SGE_HOSTS`에 적는 수밖에 없다. 주석·문서를 그렇게 고쳤다.

## 2026-09-22 (저녁) — truvari refine 의 스레드를 슬롯에서 떼어낸다

phase1 SV 첫 실행에서 5런 중 1런이 ENOMEM 으로 죽었다. 원인은 내가 같은 날 아침에 넣은
`-t "${NSLOTS:-$BENCH_SV_SLOTS}"` 다.

**추론이 반대로 갔다.** "truvari 가 무거우니 슬롯을 올려 노드당 동시 실행 수를 줄이자"고 22슬롯으로
잡았는데, `-t` 를 슬롯에 묶어 뒀으므로 슬롯을 올리는 순간 **잡당 메모리도 같이 올라갔다.**
refine 의 정렬기 abPOA 는 스레드마다 정렬 행렬을 따로 잡는다. 실측이 정확히 그 비례다:

| | 스레드 | maxvmem |
|---|---|---|
| phase2 ONT (2026-09-18) | 8 | 67~73 GB |
| phase1 HiFi (2026-09-22) | 22 | 177~192 GB |

2.75배 스레드에 2.6배 메모리. 그래서 22슬롯 = 노드당 2잡 = **380 GB** 로, 146 GB 를 의도했던
계산이 정반대 결과를 냈다. 로그 타임스탬프상 156032·156033 이 같은 초에 haplotype 을 만들고
있었고 두 번째가 64 GiB 한 방(`posix_memalign fail! Size: 68719476736`)을 못 잡았다.

**결정**: `BENCH_SV_THREADS`(기본 8)를 새로 두고 `refine -t` 는 그것만 본다. `BENCH_SV_SLOTS` 는
노드 패킹 전용이다. 두 축이 분리되어야 "동시 실행 수를 줄인다"가 실제로 메모리를 줄인다.
양쪽 phase 다 고쳤다 — phase2 는 8슬롯이라 안 겪었을 뿐 코드는 같았고, 내가 아침에 phase2 의
`BENCH_SV_SLOTS` 도 22로 올려 놔서 다음 실행에서 똑같이 터질 참이었다.

**교훈**: 자원 축이 둘(슬롯=패킹, 스레드=잡당 메모리)인데 하나로 묶어 두면 한쪽을 조정할 방법이
없어진다. 묶기 전에 그 둘이 독립적으로 움직여야 하는지부터 본다.

### 죽은 잡이 슬롯을 계속 붙잡았다

abPOA 가 malloc 실패를 찍고도 abort 하지 않아, 잡이 SGE 에서 `r` 상태로 22슬롯을 계속 점유했다
(`set -e` 가 볼 종료 코드가 안 나온 것이다). `qdel` 로 정리했다. 잡 스크립트에 워치독을 넣을지는
보류한다 — 원인을 없앴고, 워치독은 정상 장기 실행과 구분이 어렵다.

## 2026-09-22 — QC 리뷰 스크립트의 외부 도구 해석을 한 곳으로 모은다

`35_review_qc.py --pass-counts` 가 `PermissionError: [Errno 13] ... 'bcftools'` 로 죽었다.
두 가지가 겹쳐 있었다.

**1. 도구를 찾는 방식이 이 자리만 달랐다.** 이 repo 의 다른 모든 자리 — `61_benchmark_sv.sh`,
`03_dup_evidence.sh`, `60_benchmark.sh` 의 faidx, 같은 파일의 `--check-meth` — 는 전부
컨테이너를 거친다. **로그인 노드 PATH 에 samtools 도 bcftools 도 없기 때문이다.**
`--pass-counts` 만 `["bcftools", "stats", ...]` 로 맨 이름을 불렀다. 같은 파일 안에서
`--check-meth` 는 제대로 하고 있었으니, 고칠 때 형제 자리를 안 훑은 전형적인 자국이다.

**2. 예외 핸들러가 좁았다.** `except (FileNotFoundError, subprocess.TimeoutExpired)` 였는데
실제로 온 것은 `PermissionError` 다. 둘은 형제이지 상속 관계가 아니라서 그대로 새어나가
스크립트가 통째로 죽었다 — 런 하나 건너뛰고 끝날 일이었다. `except OSError` 로 바꿨다
(errno 13 permission, 2 not-found, 8 exec-format, 20 not-a-directory 가 전부 OSError 다).

**정한 것:** `tool_img(name)` 과 `bcftools_cmd()` 를 양쪽 phase 에 둔다. 찾는 순서는

1. `$BCFTOOLS` — 직접 지정 (예: `/home/ehojune/program/bcftools-1.24/bcftools`)
2. 캐시된 컨테이너 — `nextflow.config` 의 `container_bcftools` 를 그대로 읽는다
3. PATH

**2번이 기본인 이유가 편의가 아니다.** 파이프라인이 실제로 쓴 판과 같은 것이 보장된다.
판이 다르면 `bcftools stats` 의 변이 수·ts/tv 가 미묘하게 갈리고, 그 차이는 데이터 차이로
보이지 도구 차이로 안 보인다. 자기 빌드를 쓰고 싶으면 1번으로 명시하게 했다.

`tool_img()` 는 **env.sh 를 source 하지 않아도** 동작한다. 유도식은 `main()` 의 `default_base`
와 같다(`RUN_BASE` -> `GIAB_ROOT/processed_data_ehojune` -> `/_infra/containers`). python 스크립트는
보통 `python scripts/35_review_qc.py` 로 바로 부르는데, 그때 `--check-meth` 가 "컨테이너를 못
찾았다"로 조용히 건너뛰고 있었다 — 같은 사고의 다른 얼굴이다.

검증: 양쪽 phase 에 3경로 + 캐싱 + PermissionError 흡수 6항목, 12/12 통과.

양쪽 `env.local.sh.example` 에 `$BCFTOOLS` 예시를 적었고, `.gitignore` 에 `__pycache__/` 를
추가했다 (`py_compile` 로 문법 검사하면 생긴다).

## 2026-09-22 — ONT R10 의 기본 caller 를 DeepVariant 로 둔다

HG002 R10 런에서 같은 BAM·같은 truth 로 두 caller 를 채점했다. **DeepVariant 가 SNP·INDEL 의
recall·precision 네 칸 전부에서 이긴다** — INDEL F1 0.9378 vs 0.9134, FP 38,198 → 25,608(−33%),
FN 52,697 → 39,652(−25%). SNP 는 둘 다 포화라 차이가 작다(+0.0009).

phase1 PacBio 에서 같은 날 나온 결론과 방향이 같다(거기서는 Revio 에서만 Clair3 가 INDEL
−0.006~−0.017 로 졌다). 플랫폼 둘이 독립적으로 같은 방향을 가리키므로 caller 선택을 바꾼다.

**Clair3 를 빼지는 않는다.** 교차 확인용으로 유지한다 — 두 caller 의 변이 수 비(`caller_ratio_min`)
가 QC 게이트 중 하나이고, R9 런은 DeepVariant ONT 모델 자체가 없어 Clair3 단독이라 비교축이 필요하다.

이건 **판정 기준의 변경이지 파이프라인 변경이 아니다.** 파이프라인은 R10 런에서 이미 둘 다 돌고
있다. 바뀌는 것은 "어느 쪽 수치를 대표값으로 보고하는가"다.

## 2026-09-22 — truvari 메모리 서술 정정과 phase2 SV 슬롯 22 → 33

R10 SV 잡(156053)이 `-t 8` 에서 **maxvmem 133.5 GB** 를 썼다. env.sh 에는 "ONT 실측 67~73 GB" 로
적혀 있었다.

**옛 값이 틀린 게 아니라 조건이 달랐다.** 67~73 GB 는 `BENCH_SV_THREADS` 가 생기기 전 측정이라
truvari 기본 **4스레드** 였고, 지금 기본은 8이다. phase1 이 같은 날 `-t 8` 로 본 91.6~136.2 GB
대역 안에 133.5 가 정확히 들어간다.

→ **"truvari 메모리는 데이터셋이 두 배를 가른다"는 서술을 철회한다.** ONT(4스레드)와 HiFi(8스레드)를
비교한 것이라 스레드 차이가 데이터셋 차이로 보였다. 같은 스레드에서는 두 데이터셋이 같은 대역이다.
(스레드를 낮춰도 메모리가 비례해서 안 내려간다는 phase1 의 관찰은 그대로 유효하다 — 별개 사실이다.)

→ `BENCH_SV_SLOTS` 22 → **33(노드당 1잡)**. 22 면 2잡 x 133.5 = 267 GB 로 251 GB 노드를 넘는다.
같은 주석이 "100 GB 를 넘기 시작하면 phase1 처럼 33으로 올릴 것" 이라 조건을 미리 적어 뒀고 그게
걸렸다. 이번엔 대상이 1런뿐이라 터지지 않았을 뿐이다.

**교훈은 값이 아니라 형식이다.** 실측값을 적을 때 **측정 조건(여기서는 스레드 수)을 같이 적지
않으면 나중에 다른 조건의 값과 비교돼 엉뚱한 결론이 선다.** 이번엔 그 결론이 "데이터셋이 메모리를
가른다"였고, 노드 과점유 계산의 근거가 될 뻔했다.

## 2026-09-22 — ts/tv 구간 분할을 가정 대신 직접 센다 (62_tstv_regions.sh)

2026-09-18 에 구간 밖 ts/tv 를 **빼기로 추정**했다(R9/HG005 1.33). 그 추정은 "구간 안 ts/tv = 2.1"
가정에 기대고, 가정을 2.0 으로 바꾸면 R10 답이 1.13 → 1.28 로 움직인다. 결론("FP 가 구간 밖에
몰려 있다")은 어느 가정에서도 서지만 **숫자를 문서에 적으려면 재야 한다.**

`62_tstv_regions.sh` 를 만들었다. benchmark BED 로 갈라 `bcftools stats` 를 세 번(안 `-R`, 밖
`-T ^`, 전체) 돌리고 ts·tv **카운트**를 그대로 쓴다.

**전체를 따로 세는 것이 이 스크립트의 핵심이다.** `안 + 밖 = 전체` 가 안 맞으면 죽는다 —
bcftools 가 `-T ^file` 의 여집합을 기대대로 다루지 않거나 BED 가 엉뚱하면 조용히 틀린 값이
나오는데, 그게 정확히 2026-09-21 ts/tv 사고(틀린 값이 문서 5곳에 퍼진 뒤 외부 리뷰로 잡힘)의
재발 경로다. 1/3 의 추가 비용은 그 보험값이다.

비(比)는 절대 평균하지 않고 카운트만 더한다. 스크립트 주석과 출력 말미에 그렇게 적어 뒀다.

## 2026-09-22 — ts/tv 구간 분할 직접 측정: 가정이 맞았고, 질문이 하나 새로 생겼다

[`62_tstv_regions.sh`](../phase2_ont/scripts/62_tstv_regions.sh) 를 10건(9런 x caller)에 돌렸다.
전부 `안 + 밖 = 전체` 대조를 통과했다.

**확인된 것 셋.**

1. **"구간 안 = 2.1" 가정이 사실이었다.** 실측 2.0972~2.1400, 열 건이 좁게 모인다. 2026-09-18 에
   그 가정 위에 세운 추정들이 전부 근거를 얻는다.
2. **HG005 구간 밖 추정 1.33 → 실측 1.3064** (오차 1.8%). 2026-09-21 에 1.15 에서 1.33 으로 고친
   그 값이다. R10 추정 1.13 도 실측 1.1454 로 맞았다.
3. **2026-08-27 의 열린 질문이 R9·R10 양쪽에서 닫혔다.** 구간 안은 germline 기대치와 같고 구간
   밖만 1.09~1.48 이다. 낮은 genome-wide ts/tv 는 콜러·파이프라인 문제가 아니다.

**추정을 직접 측정으로 바꾼 값어치가 무엇이었나.** 숫자는 거의 안 바뀌었다(1.33 → 1.3064).
값어치는 다른 데 있다 — ① 가정이 사실인지 확인됐고, ② 측정하니 **추정으로는 안 보이던 게 둘
보였다**. 아래 둘은 빼기 산수로는 나올 수 없는 것들이다.

**새 관찰 1 — 베이스콜러가 좋을수록 구간 밖 ts/tv 가 낮다.** R10 dorado 1.1454 < guppy 4.2.2
1.296~1.331 < guppy 3.2.x 1.277~1.484. 방향이 직관과 반대인데, 구간 밖 SNV 수를 같이 보면 맞는다 —
R10 이 1.20M 으로 제일 많다. **좋은 베이스콜러가 어려운 영역까지 더 부르고 그 한계 콜이 FP 비중이
높다.** 구간 안 정확도가 오른 것과 모순이 아니다. 평가 구간이 그 영역을 애초에 빼 놓았기 때문이다.

**새 관찰 2 (미확인) — DeepVariant 가 구간 밖에서 무엇을 버리는가.** 구간 **안**에서 두 caller 는
사실상 같다(SNV 3,366,766 vs 3,366,883, ts/tv 2.0974 vs 2.0972). 차이는 전부 구간 밖이다:
SNV −86,129, ts −60,401, tv −27,753. **순차분의 ts/tv 가 2.18** — germline 신호에 가깝다.

단정하지 않는다. 이건 두 caller 의 **순 차이**이지 "DV 가 버린 집합"이 아니다(콜 집합이 같지 않다).
확인하려면 두 VCF 를 구간 밖에서 교차시켜 실제 차집합을 봐야 한다.

**그래도 기록해 두는 이유:** 같은 날 내린 "ONT R10 기본 caller 를 DeepVariant 로" 결정은
**벤치마크 구간 안에서만 검증된 것**이다. hap.py 는 구간 밖을 아예 안 본다. 구간 밖까지 쓰는
용도(반복영역 변이 탐색 등)로 넘어갈 때는 이 결정을 다시 봐야 한다. 결정을 바꾸지는 않는다 —
지금 우리 판정 기준이 truth 기반이고 truth 는 구간 안에만 있기 때문이다.

## 2026-09-23 — 카탈로그가 외부 유래 런을 영영 못 보던 구멍 (EXT_ALIAS)

세 세션 정렬(PR #33) 중 ONT 몫을 반영하다 찾았다.

`50_update_catalog.py` 는 카탈로그 행을 `(sample, giab_path 의 basename)` 으로 run_table 과 잇는다.
GIAB FTP 에서 받은 행은 디렉토리 이름이 곧 dataset 이라 이게 성립한다. 그런데 **외부에서 들여온
행은 둘이 다르다** — 경로는 배포처 구조(`ext/ont-open-data/giab_2025.01/HG002/PAW70337`)를 따르고
dataset 은 우리 명명 규칙(`ONT-R10_giab2025.01_PAW70337`)을 따르기 때문이다.

그래서 HG002 R10 행은 `경고: run_table에 대응 실행 단위가 없음` 으로만 뜨고 **채점이 끝나도 영영
기록되지 않는 상태**였다. 경고가 한 줄 났을 뿐이라 아무도 안 봤다. 파이프라인·채점이 다 끝난
런인데 카탈로그에는 `variant_called=FALSE` 로 남아 있었다.

**고친 방식:** 자동 매칭(끝부분 일치 등)은 엉뚱한 행을 물 수 있어 쓰지 않고, `EXT_ALIAS` 로
명시적으로 이었다. 같은 뿌리의 두 번째 버그도 같이 고쳤다 — 산출물 경로를 카탈로그 basename 으로
만들고 있어서(`{run_base}/{sample}/ONT/{key[1]}`), 별칭으로 이어도 **존재하지 않는 경로**를 적었다.
run_table 의 dataset 을 쓰도록 바꿨다.

**교훈은 "경고를 세는 자리가 없었다"는 것이다.** 이 스크립트는 경고를 출력하고 계속 돈다.
정상(HG008 HERR0 처럼 run_table 에 없는 행)과 비정상(위 경우)이 같은 줄로 나와 구분이 안 된다.
phase3 가 같은 구조로 외부 데이터를 더 들이므로 phase1 에도 같은 구멍이 있다 — phase1 은 아직
외부 유래 행이 카탈로그에 없어서 드러나지 않았을 뿐이다.

## 2026-09-23 — 카탈로그 next_step 을 "다음 할 일"에서 "한 것 + 남은 것"으로

PacBio 세션이 phase1 에서 먼저 한 전환을 phase2 에도 적용했다. 채점이 끝났는데 문구가
"다음: …평가" 로 남아 있으면 **방금 채운 칸과 모순**된다.

- HG002: 소변이·SV 둘 다 공식 truth 가 있어 **남은 평가가 없다**
- HG001·HG003~HG007: 소변이는 끝났고, SV 는 **공식 germline SV benchmark 가 없어 정확도를 말할 수
  없다**(GRCh38 stvar truth 는 HG002 뿐). Sniffles2 콜셋은 내되 성능으로 보고하지 않는다 —
  PacBio 가 phase1 에서 "교차 콜러 일치도와 수동 검토로 평가" 를 지운 것과 같은 판단이다
  (하지 않았고 할 계획도 없는 방법을 계획으로 적어 두지 않는다)
- HG008 4행: 그대로 둔다. somatic 평가는 실제로 안 끝났다

## 2026-09-23 — STATUS.md 를 현황판으로 되돌리고 셋으로 나눈다

사용자 지적: "STATUS 가 데이터 다운로드와 처리의 현재 상황을 한 번에 보는 곳이었으면 하는데,
지금은 PR 얘기나 이전 기록이 같이 있다."

재 보니 **249줄 중 현황은 29줄(12%)** 이었다. 나머지는 레퍼런스(클러스터 사실·`_infra` 자산·
점검 명령 61줄), 백로그(#9·표준화 53줄), 끝난 인계장(세션 조율 54줄), 완료된 작업의 상세(#8 27줄).

**가른 기준은 "에이전트용이냐"가 아니다.** 그걸로 가르면 `_infra` 자산·클러스터 사실·확인 명령이
어디로 갈지 애매해진다 — 에이전트용이 아니라 사람용 레퍼런스인데도 현황판에 있을 이유는 없다.
기준은 **다음 주에 거짓이 되는가**로 잡았다.

| 수명 | 어디 |
|---|---|
| 다음 주에 거짓이 된다 | `STATUS.md` — 잡 ID, 지금 도는 것, 다음 손 |
| 안 변한다 | `reference/server-and-infra.md` — 노드 스펙, `_infra` 자산, 점검 명령 |
| 끝나기 전엔 안 변한다 | `backlog.md` — #8·#9·#10 상세, 문서 수치 불일치 |
| 이미 지났다 | `STATUS.md ## 이력`(맨 아래), `README ## Journal`, `runs/` |

**지운 것 둘.** "지금 다른 세션이 하는 일"(PR 상태표)과 "세션별 남은 최신화"는 2026-09-23 기준
전부 해소됐다. 끝난 인계장을 남겨 두면 다음 사람이 **할 일로 읽는다.** 규칙은 AGENTS.md 가,
경위는 이력과 PR 이 이미 갖고 있어 유실이 없다. 다만 그 안에 섞여 있던 **미해결 2건**
(다운로드 세션의 README 수치 불일치)은 backlog 로 옮겼다 — 조용히 사라질 뻔했다.

**백로그를 `reference/` 에 넣지 않은 이유.** `docs/reference/README.md` 가 자기 범위를
"특정 값의 근거를 의심할 때만 찾아보는 곳" 으로 못박고 있다. 백로그는 값의 근거가 아니라
앞으로 할 일이라 거기 넣으면 찾을 사람이 안 본다. 상시 문서가 하나 늘지만 성격이 분명하다.

**이력은 맨 아래에 전부 남긴다**(사용자 결정). 잡 ID·실측 같은 세밀한 것은 README Journal 에
넣기엔 굵고, "지금 돌던 잡이 왜 끝났나" 를 현황판에서 바로 볼 수 있는 값어치가 있다.
대신 맨 아래에 둬서 "지금" 을 보러 온 사람이 과거를 먼저 지나가지 않게 했다.

## 2026-09-23 — [숏리드 세션] MGISEQ HG002 재생성 잡(155525)이 이미 실패해 있었다

STATUS.md 는 "running (09-22 07:53~)" 으로 남아 있었지만 `qacct -j 155525` 로 보니 실제로는
09-22 15:59:55 에 `exit_status=1` 로 끝나 있었다(약 8시간 6분 실행, `failed=0` — SGE 가 죽인 게
아니라 스크립트 자신이 에러를 감지하고 종료했다). 아무도 23시간 넘게 들여다보지 않은 상태였다.

`repairs/mgi-hg002.IMeaDNit/` 산출물로 원인을 좁혔다. `bwa.stderr` 는 끝까지 정상적으로 read를
처리하고 있었고, `view.stderr` 에 `[W::sam_read1_sam] Parse error at line 948884480` /
`samtools view: error reading file "-"` 가 있다 — bwa-mem2 가 samtools view 로 넘기는 SAM 스트림이
특정 줄에서 깨졌다. 디스크는 `/BiO` 30% 사용(1.7P 여유)이라 공간 문제가 아니다. `qstat -j`의
`h_vmem=300G`는 다른 잡(155526, regermline)의 값을 잘못 옮겨 적은 것이었다 — 155525 자신의
요청은 `h_vmem=60G`고 `maxvmem 21.081GB`라 그 잡 자신의 OOM은 아니다. **다만 nbb2의 `h_vmem`은
예약도 상한도 아니라서(HARVEST.md "SGE h_vmem은 예약도 상한도 아닐 수 있다") 같은 노드의 다른
잡이 물리 메모리를 눌러 커널이 bwa-mem2를 죽였을 가능성은 배제하지 않는다** — `failed=0`은 SGE
자신의 추적 기준으로 안 죽였다는 뜻일 뿐 노드 차원의 OOM killer와는 별개다. 원본
`rawcheck.log`/`trimmedcheck.log` 는 raw·trimmed FASTQ 양쪽 다 PASS 를 찍었으니 입력 FASTQ
자체는 온전하다. `aligned.bam.partial` 149GB 가 남아 있다.

**재시도 전에 파싱 에러가 재현되는지부터 봐야 한다** — 재현 안 되면 우연한 스트림 손상으로 보고
그냥 재제출, 재현되면 bwa-mem2 버전/스레드 설정을 의심해야 한다. 국통바빅 파이프라인이든 이
복구 스크립트든 실행·재제출은 사용자(또는 서버에서 직접 작업하는 Codex 세션) 몫이라 여기서
qsub 는 하지 않았다 — 읽기 전용 진단만 하고 STATUS #2 행을 "실패"로 정정한다.

## 2026-09-23 — [숏리드 세션] MGISEQ HG002 재생성 재시도: 실패 지점이 두 번 다 거의 같다

사용자 확인: 국통바빅(BIKO) 본 파이프라인 실행만 사용자 전용이고, `repairs/mgi_hg002_recheck.sh`
같은 복구/유틸리티 스크립트의 qsub 는 에이전트가 해도 된다. 이에 따라 155525 와 동일한 자원
요청으로 재제출했다(잡 156584, `-q octopus.q,shepherd.q -l h_vmem=60G,hostname=(octopus-2-10|
octopus-2-11) -pe pe_slots 10`, `qacct -j 155525` 의 `category` 필드에서 그대로 가져옴).

재시도 전에 **1차 실패가 우연이 아닐 수 있다는 신호**를 찾았다. 2026-09-21 원본 파이프라인 실패는
SAM 948,868,188번째 줄(헤더 3,369줄 제외 정렬 레코드 948,864,819개, 전체 리드 1,451,463,284개
중 약 65.4% 지점)에서 `SEQ and QUAL are of different length` 로 죽었다. 2026-09-22 복구 스크립트
1차 시도(155525)는 SAM 948,884,480번째 줄에서 `samtools view: error reading file "-"` (파싱 에러)
로 죽었다 — **레코드 수로 16,292개, 비율로 0.0017% 밖에 차이가 안 난다.** 스크립트도 다르고
날짜도 다른 두 번의 독립된 실행이 스트림의 거의 같은 지점에서 깨졌다는 것은, 무작위 스트림 손상보다
**그 근방 리드 자체(또는 bwa-mem2 가 그 리드를 처리하는 방식)에 문제가 있을 가능성**을 가리킨다.

**156584 가 다시 비슷한 지점에서 죽으면 blind retry를 멈춰야 한다.** 그때는 SAM 줄 번호를 2로
나눠 페어 위치를 계산하지 않는다 — bwa-mem2가 secondary·supplementary를 낼 수 있어 그 계산은
±수백만 페어까지 틀어질 수 있다(근거·수치는 [docs/runs/2026-09-23-phase3-input-audit-and-mgiseq-repair.md](runs/2026-09-23-phase3-input-audit-and-mgiseq-repair.md)).
대신 끊기기 직전의 마지막 완전한 QNAME을 partial BAM/SAM에서 회수해 그 이름 그대로
`R1/R2.trimmed.fastq.gz`에서 grep 한다. 성공하면 이 우려는 기우였던 것으로 정리한다.

## 2026-09-23 — [숏리드 세션] 위 두 항목의 원 명령/출력을 docs/runs/에 남긴다

Codex 리뷰 지적(PR #36): 입력 트리 감사와 MGISEQ 실패 진단이 `qacct`·클러스터 stderr·디렉토리
스캔 같은 휘발성 서버 상태에 근거하는데 원 명령/출력을 남긴 곳이 없었다 — AGENTS.md 규약상
이런 실행 기록은 `docs/runs/`에 남겨야 재현·검증이 가능하다. 맞는 지적이라 추가했다:
[docs/runs/2026-09-23-phase3-input-audit-and-mgiseq-repair.md](runs/2026-09-23-phase3-input-audit-and-mgiseq-repair.md).

같은 리뷰에서 재시도(156584) 전에 실패 지점부터 조사해야 하지 않냐는 지적도 왔다. 이미 사용자
승인으로 재제출한 뒤였는데, 그 김에 `bwa.stderr`를 다시 봤다 — **에러 메시지가 하나도 없이
`task: 1418, 1. Calling kt_for - worker_bwt` 에서 파일이 그냥 끝난다.** 정상 종료도 에러 출력도
없이 멎었다는 건 bwa-mem2 프로세스 자체가 (samtools 쪽 파싱 에러의 원인이 아니라 결과로) 죽었을
가능성을 가리킨다. 156584가 같은 자원·같은 청크 크기(`-K 100000000`)로 도는 이상 결정적 버그면
비슷한 지점에서 또 죽을 것이고, 그게 가장 싼 재현성 검사다 — 그때 가서 해당 구간 리드를
직접 뽑는다(87~91GB gzip이라 그 지점까지 순차 압축 해제에만 10~20분 걸려 미리 할 이유가 없다).

## 2026-09-23 — [PacBio 세션] #9 somatic 은 bioinfo-agent 위에 짓고 고정 vendor 한다

- **방법 B(somatic caller 추가)** 는 사용자 결정(2026-09-22)이다. 조건 둘 — 다른 데이터와 같은
  처리는 그대로 하고, repo 정합성을 먼저 맞출 것 — 과 "가능하면 bioinfo-agent 위에" 라는 요청이 있었다.
- **bioinfo-agent 에 짓는다.** 두 사본은 process 24/25 가 같고 차이는 한 방향씩 하나다(GIAB 의 `run_label`,
  bioinfo-agent 의 CLR 진입 등 5커밋). 여기서 somatic 을 따로 키우면 갈라진 사본이 셋이 된다.
  자문 둘(gpt-5.6-sol, gemini-3.8-flash-high, 서로 못 보게)이 같은 결론이었다 — bioinfo-agent 에 넣고
  고정 커밋을 vendor, 0단계로 sync. gpt-6-astra 는 한도로 못 물었다.
- **submodule·원격 참조는 안 쓴다.** 계산 노드에 네트워크가 없고, 파이프라인 사본이 바뀌면 47런의
  `-resume` 캐시 해석이 달라진다. 커밋 해시를 `VENDORED.md` 에 적고 사본을 통째로 교체한다.
- **실행은 이 세션이 하지 않고 위임한다** (사용자 지시). 프롬프트는 [runs/2026-09-23-bioinfo-agent-somatic-handoff.md](runs/2026-09-23-bioinfo-agent-somatic-handoff.md).

## 2026-09-23 — [PacBio 세션] 구간별 hap.py 는 GIAB 층화 188개 중 25개만 쓴다

- 중간 보고서의 열린 질문 둘(Sequel I INDEL 격차 원인, Revio 에서 Clair3 가 지는 위치)은 BED 전체
  한 덩어리 점수로는 답이 안 나온다. 그래서 `60_benchmark.sh STRAT=1` 을 만들었다.
- **전부(188) 대신 25개.** 절반(90)이 샘플별 GenomeSpecific 이라 HG002 런이 HG001~HG007 의 구간까지
  세게 된다. 층화 수만큼 hap.py 메모리·시간이 늘고, 그 계수는 아직 실측이 없다. 질문에 필요한 것 —
  호모폴리머 길이 구간, 반복·저매핑·segdup, 쉬운 영역(notin*), MHC·KIR·VDJ, 코딩, chrX nonPAR — 만 골랐다.
  4~6bp 호모폴리머는 뺐다: 구간 수가 가장 많은데 HiFi 가 약한 길이가 아니다. `BENCH_STRAT_SET=all` 로 전부 돌릴 수 있다.
- **판은 v3.6** — 디스크에 있는 최신(v2.0~v3.6 보유). 판을 바꾸면 `BENCH_STRAT_VER` 한 줄이다.
- **기본 결과를 덮지 않는다** — `05_BENCH/happy_strat/` 에 따로 두고, `Subset=*` 행이 기본 실행과
  TP/FN/FP 까지 같은지 `--collect` 가 대조한다. 같지 않으면 두 실행의 입력이 어긋난 것이다.

## 2026-09-23 — [숏리드 세션] phase3 2차 입력: 나머지 숏리드 WGS 전부를 새 set으로

사용자 지시: "GIAB 의 모든 숏리드 데이터는 국통바빅 파이프라인으로 돌아야 한다." 1차(HG002/3/4 22 샘플) 밖의 표준 short-read WGS를
phase0 manifest에서 전수로 골라 **53 샘플 / 20 set**을 만든다(`make_more_samplesheets.py` → `more_run_table.tsv`). 판단 여섯.

1. **새 샘플은 1차 set에 넣지 않는다.** 1차 8 set은 파이프라인이 끝났거나(Success·Error) 돌고 있다(155526~9). 같은 BGISEQ500이라도
   HG001·ChineseTrio를 `GIAB-publicData-BGISEQ500`에 넣으면 끝난 set의 의미가 바뀌고, 다음 재실행이 섞인다. 그래서 1차에 같은
   dataset set이 있으면 코호트 접미(`-NA12878` / `-ChineseTrio`)를 붙인 새 set, 새 dataset이면 접미 없이, HG008/HG009는
   `HG00x-<기종/배치>`. 03에는 가드를 넣었다 — 파이프라인 흔적(`__DONE__`·`error_list.txt`·`tmp/`·`.snakemake/`·`analyze_meta/`)이
   있는 set에 **없던 샘플 dir**을 만들려 하면 아무것도 만들지 않고 멈춘다(dry-run에서도). 이미 있는 샘플의 재실행은 통과.
2. **tier 둘.** germline = NIST v4.2.1 정답셋이 있는 HG001~HG007(11 set, 16 샘플, 5.0 TiB) — 국통바빅 결과를 바로 채점한다.
   somatic = HG008/HG009(9 set, 37 샘플, 7.3 TiB) — germline 정답셋이 없어 국통바빅은 QC·정렬까지, 채점은 #9(nf-core somatic) 몫.
   그래도 "모든 숏리드"라는 지시대로 만든다. 같은 배치 안에 T/N 짝이 있어(BCM-2024·NYGC-2023·Element 두 배치·Onso·HG009 BCM)
   somatic 파이프라인의 입력으로도 그대로 쓸 수 있다 — PacBio 쪽 NIST 클론에 짝 정상이 없던 것(backlog #9)과 다르다.
3. **뺀 것과 이유.** BGISEQ500 standard_library의 PE50(CL100004823): 국통바빅 fastp가 `--length_required 70`이라 리드가 전부 걸린다
   (같은 디렉토리 PE100 ERR1799697/8은 `HG001-stdlib`로 넣었다). HG008 Element 20240118: README가 in-development R&D 화학이고
   이후 데이터가 대체한다고 적었다. MissionBio Tapestri(표적 단일세포), superseded-2022-data, MGISEQ/stLFR는 WGS가 아니거나 대체됐다.
   mate-pair·Moleculo·10X·Hi-C·Dovetail·Strand-seq·엑솜은 1차와 같은 이유.
4. **HG009 성별은 측정했다.** README에 없고 저장소 어디에도 없었다. 파이프라인 sampleinfo에 SEX가 필요해서, 이미 있는 phase1 HiFi
   BAM(HG009N-WT-p25, HG009T-p16)에 `samtools idxstats`만 돌렸다(로그인 노드, 인덱스만 읽음): chrX/chr1 깊이비 0.97·1.03,
   chrY/chr1 0.08·0.07 → female. 같은 방법으로 HG008T-p100 1.01/0.07(README "female"과 일치), 남성 대조 HG002 0.38/1.12.
5. **병합을 lock으로 한 번에 하나만.** 03 `--qsub`을 두 번 돌리면 같은 샘플에 잡이 둘 뜬다. 두 cat이 같은 `.part`에 `>`로 쓰면 최종
   크기는 입력 합과 같은데 내용이 섞일 수 있고, concat.sh의 크기 검증이 그걸 **통과시킨다**. `mkdir .concat.lock`(Lustre에서 원자적,
   flock은 마운트 옵션에 따라 안 된다)으로 막고, `--qsub`은 lock이 있거나 `concat.jobid`의 잡이 qstat에 남아 있으면 다시 내지 않는다.
6. **sampleinfo 행은 03이 덧붙인다(`--sampleinfo`).** "돌아와서 바로 돌리면 되게"가 요구라, 파이프라인이 읽는 `G000/sampleinfo/
   sample_information_nbb2.xlsx`에 없는 DNA_ID만 추가한다. 먼저 `.bak-<시각>`으로 복사하고, 같은 DNA_ID가 다른 SET_ID·SEX로 있으면
   쓰지 않고 멈춘다. note 열은 1차처럼 HG 번호, somatic은 label(예: HG008-T-p100).

검증: WSL에서 가짜 FASTQ·가짜 qsub/qstat로 18건(링크 대상, 300쌍 병합의 R1/R2 순서, 멱등 재실행, 가드 두 경우, lock, qsub 중복 방지),
Windows에서 실제 sampleinfo 사본으로 3건(추가·백업, 재실행 0건, 충돌 시 파일 불변). manifest 패턴 53개가 전부 기대 파일 수와 일치했다
(HG005 MGISEQ는 stLFR까지 잡는 패턴이라 기대 수 불일치로 한 번 걸렸고 `PCR-free/`로 좁혔다).

**리뷰 (PR #41).** GitHub Codex 봇과 로컬 Codex CLI 둘 다 사용 한도에 걸려(로컬은 "try again at Sep 24th, 2026 2:48 AM") 리뷰를
못 받았다. 재시도하지 않고 Gemini(`gemini-3.8-flash-high`, agyq)에 독립 리뷰를 맡겼다 — Codex 리뷰가 아니다. 지적 10건 중 받은 것:
sampleinfo 쓰기를 링크·concat.sh 생성 **뒤로** 옮김(중간에 멈추면 반쪽 샘플 행이 남는다 — 옮기고 나서 Windows 테스트에서 concat.sh를
인코딩 없이 쓰던 버그가 드러나 전부 `encoding="utf-8"`로 고침), `--lanes` 재실행 때 살아 있는 잡도 줄을 차지하게(안 그러면 새 잡이
hold 없이 떠 상한이 깨진다), xlsx는 마지막으로 값이 있는 행 다음에 직접 쓰고 Excel 표가 있으면 멈춤, 머리행 대소문자 무시, 빈 샘플
dir(입력 없음)은 "이미 만든 샘플"로 치지 않음(가드 우회 방지), unit에 플로우셀 dir까지(정렬 키지만 HiSeq에서 711건 겹쳤다).
안 받은 것과 이유: 죽은 잡의 lock 자동 제거(qstat 일시 실패와 구분이 안 돼 산 병합을 깰 수 있다 — 대신 주인 잡이 큐에 없으면 지우는
명령을 안내), qstat 일시 실패 시 중복 제출(lock이 두 번째 cat을 exit 3으로 막는다), jobid 덮어쓰기(같은 이유로 무해),
파이프라인 잡이 qw일 때 마커가 없어 가드가 안 걸림(아직 시작 전이면 새 샘플이 그 실행에 들어가는 것뿐이다).
Codex가 풀리면(09-24 02:48 이후) 이 브랜치의 diff로 한 번 더 돌려 후속 PR로 처리한다.
