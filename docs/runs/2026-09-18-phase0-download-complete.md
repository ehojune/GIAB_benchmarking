# 2026-09-18 — phase0 다운로드 전량 완료 (2026-09 크롤 반영본)

2026-09-16 FTP 라이브 크롤로 늘어난 목록을 nbb2에서 전부 받았다. `verify.sh`가 카테고리마다 100.0%를 찍었고,
카테고리 합계가 manifest 합계와 파일 수·바이트까지 정확히 같다.

- 실행: `TOOL=s3 JOBS=8 bash phase0_download/scripts/run_priority.sh`, 로그인 노드, screen
- 기간: 2026-09-17 09:18:35 → 2026-09-18 14:07:21 (**28시간 49분**)
- 결과: **81,302 / 81,302 files, 116,509.5 / 116,509.5 GiB (113.78 TiB = 125.1 TB), 100.0%**
- 신규분: 4,759 files / 8.67 TiB → 평균 **92 MB/s**
- 로그: `logs/run_priority_20260917.log` (카테고리별 상세는 `phase0_download/logs/<category>.log`)

## 카테고리별

| category | files | GiB | 소요 | 신규분 |
|---|---|---|---|---|
| release | 7,989 | 318.2 | 2초 | 1,577 files / 41.4 GiB |
| trio_analysis | 415 | 72.8 | 1분 50초 | 90 files / 13.7 GiB |
| pacbio_hifi | 1,366 | 9,635.7 | 3시간 6분 | 83 files / 1,001 GiB (HG008) |
| ont | 4,277 | 11,872.4 | 18분 | 3 files / 18.2 GiB (HG008 HERRO) |
| pacbio_clr | 1,737 | 13,388.2 | 1초 | 0 |
| rnaseq | 447 | 6,941.3 | 41분 | 123 files / 241.7 GiB (HG008·HG009) |
| illumina_wgs | 53,752 | 27,755.3 | 18시간 53분 | 259 files / 6,066 GiB |
| bgi_mgi | 155 | 5,755.5 | 1초 | 0 |
| linked_reads | 344 | 4,584.9 | 2초 | 0 |
| exome | 93 | 976.9 | 1초 | 0 |
| complete_genomics | 4,887 | 14,880.4 | 16초 | 0 |
| other | 5,840 | 20,327.9 | 5시간 15분 | 2,624 files / 1,495 GiB |
| **합계** | **81,302** | **116,509.5** | **28시간 49분** | **4,759 files / 8.67 TiB** |

`illumina_wgs` DONE(08:18:59)과 `bgi_mgi` START(08:49:05) 사이 30분은 53,752 파일에 대한 `verify.sh`다.

## 속도 예측이 틀렸다

이 실행 직전에 "S3 미러에 신규 데이터가 없으니(표본 96건 중 1건만 200) FTP fallback 속도로 계산해야 하고,
하루가 아니라 며칠을 잡아라"라고 적었다. 실측은 **평균 92 MB/s**로, 2026-08-13에 잰 S3 83 MB/s보다 오히려 빨랐다.
카테고리별로도 85~106 MB/s에서 벗어나지 않았다(pacbio_hifi 92, illumina_wgs 96, rnaseq 106, other 85).

요약 로그만으로는 S3와 FTP의 비율을 가를 수 없다. 실제 경로가 궁금하면 `phase0_download/logs/<category>.log`에서
`S3 miss → FTP fallback` 줄을 세면 된다. 어느 쪽이든 **JOBS=8에서 하루 남짓이면 8.67 TiB가 들어온다**가 실측이다.
미러 가용성 표본으로 소요 시간을 추정하지 말 것 — 표본은 경로를 알려주지 실효 대역폭을 알려주지 않는다.

## 검증

| 확인 | 결과 |
|---|---|
| 카테고리 12개 verify.sh | 전부 100.0% |
| 카테고리 합계 vs manifest 합계 | 81,302 files / 116,509.5 GiB 양쪽 일치 (차 0) |
| 받지 않기로 한 3건 | manifest에 없음 → 받지 않았다 (12,423 files / 10.69 TiB) |

`declined_by_decision.tsv`의 12,423건은 이번 실행 대상이 아니었다. 나중에 받기로 바꾸면
[phase0_download/README.md](../../phase0_download/README.md)의 "받지 않기로 한 데이터" 절에 있는 복원 명령을 쓴다.
