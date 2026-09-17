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
