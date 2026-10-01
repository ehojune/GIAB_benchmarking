# 패치노트

이 저장소의 주요 변경 이력입니다. 최신순.

2026-10-01 이전 항목은 README에 적던 진행 기록을 그대로 옮긴 것입니다. 근거 열은 그 항목을 처음 기록한 커밋입니다.

## 2026-10-01

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | **README 진행 기록을 패치노트로 옮겼습니다.** README 상단 배지에서 엽니다 | [#79](https://github.com/ehojune/GIAB_benchmarking/pull/79) |

## 2026-09-28

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| 10:45 | HiSeq Mark 자원 개선 3잡 실행, 기존 master 정지·보존. [근거](../docs/reference/2026-09-28-hiseq-mark-optimization.md). | [`62bf68a`](https://github.com/ehojune/GIAB_benchmarking/commit/62bf68a4320c2c2bc610cffb4be194f4f4bc419f) |
| — | [09시 총괄 보고](../docs/runs/2026-09-28-0900-heartbeat.md): 5장 PPT 완성·4시간 점검 전환. 비교 19건 완료, 공개 기본 4잡·12샘플은 계속 실행. | [`11fca4a`](https://github.com/ehojune/GIAB_benchmarking/commit/11fca4aa161ba71d732f361dc4fe462cd8d1a2f7) |
| — | [07:30 점검](../docs/runs/2026-09-28-0730-heartbeat.md): 공개 기본 4잡은 실행 중. 큰 원본과 공유 디스크 I/O 지연을 확인했고 기존 계산은 유지. | [`b5c10df`](https://github.com/ehojune/GIAB_benchmarking/commit/b5c10df9be1c8cf6c217a8555d45ce7b497187a8) |
| — | [06시 점검](../docs/runs/2026-09-28-0600-heartbeat.md): 숏리드 비교 19건 완료. 공개 7행의 카탈로그·Excel 누락 기록을 반영했고 공개 기본 4잡은 진행 중. | [`4700295`](https://github.com/ehojune/GIAB_benchmarking/commit/470029533d3e69d6d30f50ba072ead15509e8f8e) |
| — | [05:30 점검](../docs/runs/2026-09-28-0530-heartbeat.md): Manta 세 샘플 복구·반영 완료. 공개 기본 4잡과 Illumina 채점 3잡 진행. | [`4c198f2`](https://github.com/ehojune/GIAB_benchmarking/commit/4c198f2f413dfb6e1159bc09faecf5b218f9c294) |
| — | [05시 점검](../docs/runs/2026-09-28-0500-heartbeat.md): HG002 Manta 스택 수정 성공·결과 반영, HG003/4 실행 유지. Illumina250PE 기존 소변이 채점 3건 추가 제출. | [`0be75f0`](https://github.com/ehojune/GIAB_benchmarking/commit/0be75f0d1853e3813023e5f966225db90950607b) |
| — | 사용자 지시로 [Manta HG002/3/4 병렬 실행](../docs/reference/2026-09-28-manta-parallel.json): 156831–156833, 스택 64MiB 수정. 한 샘플 성공 대기 조건을 없앴다. | [`4f74785`](https://github.com/ehojune/GIAB_benchmarking/commit/4f74785c85f2ddeb534bdc2da395fc830a114696) |
| — | [09시 전 집중 점검](../docs/runs/2026-09-28-before0900.md): 30분마다 준비된 승인 후속 잡 확인·제출, 09시 5장 총괄 PPT와 4시간 점검 전환 준비. | [`33ae774`](https://github.com/ehojune/GIAB_benchmarking/commit/33ae774c236e6b805d9d83e08575581081cb535b) |
| 04시 | Manta GDB 진단에서 재귀 스택 부족 단서 확인. HG002에 스택 2→64MiB 수정 검증 156831 시작. 동일 명령 반복 제한과 원인 해결을 구분. [기록](../docs/runs/2026-09-28-manta-stack-diagnosis.md). | [`b5aad2f`](https://github.com/ehojune/GIAB_benchmarking/commit/b5aad2f79641e05ccc017ac24ce87046524cccfc) |
| 03시 | Illumina Manta 3건 최종 재시도도 실패해 각 2/2회로 반복 종료. 공개 4잡·12샘플은 계속 진전. [점검](../docs/runs/2026-09-28-0303-heartbeat.md). | [`42fbec7`](https://github.com/ehojune/GIAB_benchmarking/commit/42fbec71068144d7a455ca0574d4ebc2afaec914) |
| 00시 | Verify 잔여 3건 복구·반영: 회사 24/24, Illumina 3/3 QC 확보. Manta만 마지막 2차 156827–156829 실행. [점검](../docs/runs/2026-09-28-0002-heartbeat.md). | [`198ac2c`](https://github.com/ehojune/GIAB_benchmarking/commit/198ac2c14ea3eb0c39b2a6d530827b5d7686ce45) |

## 2026-09-27

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| 21시 | 사용자 승인으로 남은 Verify·Manta 6건을 단계별 최대 2회 재시도, 1차 156821–156826 제출. 기존 점검은 3시간으로 변경. [기록](../docs/runs/2026-09-27-bounded-retries.md). | [`aaf8a9a`](https://github.com/ehojune/GIAB_benchmarking/commit/aaf8a9a1f8bcb941cef6b398c0cc10d637106942) |
| 20시 | 회사·공개 비교 16건 완료. gd4 QC 두 건 반영으로 정본 QC 22/24, 공개 4잡은 계속 진전. [비교표](../docs/reports/2026-09-27-shortread-sixteen.md) · [점검](../docs/runs/2026-09-27-reboot-status.md). | [`8a88ad7`](https://github.com/ehojune/GIAB_benchmarking/commit/8a88ad73a33b5f31ebe52c96f17b102b4ea1b504) |
| 16시 | gd4 종료·6샘플 최소 QC 확인. 새 정본 비교 3건(156815–156817)과 실패 QC만 3건(156818–156820) 실행. [점검](../docs/runs/2026-09-27-1606-heartbeat.md). | [`78fa9ca`](https://github.com/ehojune/GIAB_benchmarking/commit/78fa9ca1c71db5551a383e7c919567b9e7facaa0) |
| 08시 | gd2 KOR-101 QC 복구·반영으로 누적 7건 완료. gd3 KOR-101 재실패는 gap 보존, gd4 228/265단계. [점검](../docs/runs/2026-09-27-0804-heartbeat.md). | [`21d6440`](https://github.com/ehojune/GIAB_benchmarking/commit/21d6440e1ef6de1f04925c030fd9fbeed06602f5) |
| 04시 | 회사·공개 비교 13건 회수, Verify QC 5건 추가 반영·2건 제한 재시도. BioSkryb×UG100 476개 수령·검증 완료, 카탈로그·Excel 갱신. [현황](../docs/STATUS.md). | [`61e94ab`](https://github.com/ehojune/GIAB_benchmarking/commit/61e94abf54ece2771a653900f5744f73433f2728) |
| — | fastp 보고서 12샘플 복원·Verify 단독 1건 복구 완료. 같은 QC 7건 재시도와 gd1·gd2 비교 6건 제출, 다운로드 83.11%. [기록](../docs/runs/2026-09-27-verify-recovery-and-company-comparison.md) | [`a2e94fd`](https://github.com/ehojune/GIAB_benchmarking/commit/a2e94fd148c8082f49fba406e8161714e405e7bc) |

## 2026-09-26

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | PacBio: 보고서 마무리 판을 main 에 반영(#74, HG003 Google 15kb 세대 혼합 표시). GIAB 전장 실측(germline 19런·SV 5런·somatic 13쌍)을 bioinfo-agent 검증 기록으로 되먹였다(ehojune/bioinfo-agent#58, 0.4.9). 보류하던 #68·#69 는 사용자 승인으로 Codex 리뷰 3회 후 병합. | [`a711865`](https://github.com/ehojune/GIAB_benchmarking/commit/a711865f48d962549b8729abe1d71920a397cdd2) |
| 20:15 | 사용자 요청으로 gd3 HG002의 VerifyBamID만 개별 재시도(156798). 완료 CRAM에서 임시 BAM을 복원하며 정렬·변이는 재계산하지 않는다. [실행 기록](../docs/runs/2026-09-26-verify-only-pilot.md) | [`6710ddb`](https://github.com/ehojune/GIAB_benchmarking/commit/6710ddbde651454b56686764a810007f3a03f8fa) |
| 20:00 | gd3·공개 비교 7건 완료 확인. gd2·gd3 일반 regermline은 253작업을 재계산해 중지했고 제거된 fastp 보고서만 복원 중이다. DONE과 개별 VerifyBamID 실패의 근거를 남겼다. [기록](../docs/runs/2026-09-26-gd23-regermline-and-DONE.md) | [`f09e9fd`](https://github.com/ehojune/GIAB_benchmarking/commit/f09e9fdc93f7a13aeceaa44534227bc5e0b8e69e) |
| 16:07 | Codex 총괄로 gd3·공개 truth 비교 7건(156787–156793) 시작. gd3 주요 산출물·리드 수 검사 통과, 오염 QC 3건은 gap으로 보존하고 원자료 재처리는 하지 않았다. [기록](../docs/runs/2026-09-26-gd3-qc-and-comparison.md) | [`5dd146e`](https://github.com/ehojune/GIAB_benchmarking/commit/5dd146e5725251e24c3923be39f10b409a85197b) |
| 09:05 | Codex 장애로 총괄을 Claude 세션이 인계(사용자 지시). Illumina-250PE 155529가 05:05 Error 종료(Manta 3샘플·verifybamID 2샘플 segfault), 정리잡 156782는 검사문에 걸려 6초 만에 종료. 실패 산출물 19건 보존 후 native `regermline` 156786 제출. 나머지 8잡 진행 중. [기록](../docs/runs/2026-09-26-illumina-regermline-retry.md) | [`0afc603`](https://github.com/ehojune/GIAB_benchmarking/commit/0afc60350322da9291f7674e9671aee7b09f30cb) |
| — | 사용자 결정 둘 반영: stale release 52건 보유 유지, HG008-T BioSkryb×UG100 단일세포 CRAM·VCF 수령. HEAD 실측으로 규모를 476 files / 4.75 TiB(5.22 TB)로 정정(FTP 매니페스트 size_Gb는 GiB, 인덱스 누락). `fetch_external.sh`(범용 URL fetcher) + `fetch_all.sh` phase0ext 단계 + `ext_manifest.tsv`. 카탈로그 행·README·Excel·SIZES 갱신. | [`6176456`](https://github.com/ehojune/GIAB_benchmarking/commit/6176456aad195da71368cca7672420a5302af061) |

## 2026-09-25

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | md5 전수 검증 잡 156685 집계·마감: phase0 본체 81,302 files 중 실질검증(PASS*) 77,511, FAIL 39건 전수를 라이브 FTP와 대조해 실손상 0건 확정(5건은 GIAB README 갱신 반영, 원본은 `.bak-20260925` 보존). 매니페스트 바이트 5줄·`docs/SIZES.md` 재생성. 기록: [docs/runs/2026-09-25-md5-verification-followup.md](../docs/runs/2026-09-25-md5-verification-followup.md). | [`4bf7878`](https://github.com/ehojune/GIAB_benchmarking/commit/4bf78785f2414024eda4026ddb964a1d71add6ff) |
| 23:55 | 기본 9잡 진전·regermline156782 대기 확인. HG002/3/4 비교는 회사 완료·QC 뒤 Codex가 조율한다. PacBio 담당은 새 잡 없이 보류했다. [현황](../docs/STATUS.md) | [`278cd1d`](https://github.com/ehojune/GIAB_benchmarking/commit/278cd1d4cf6004496aabcf06c058b2d0ff47bd58) |
| 21:51 | 사용자 지시에 따라 실패 Manta 중간산물 정리 후 native regermline156782를 대기 제출했다. 기존155529 종료 후 실행한다. [기록](../docs/runs/2026-09-25-illumina-regermline-cleanup.md) | [`6472930`](https://github.com/ehojune/GIAB_benchmarking/commit/64729307bd2ea85ead1560660ea09f569b9430ab) |
| 19:52 | 기본 9잡 진전 확인. Manta HG003 재시도도 실패해 반복 중지, HG002 QC만 156781로 한정 복구. 누락된 somatic 13쌍을 카탈로그에 반영했다. [현황](../docs/STATUS.md) | [`2216cc2`](https://github.com/ehojune/GIAB_benchmarking/commit/2216cc225d864806802ae153c8397cbcb0d262fb) |
| 16:05 | 공개 기본 5잡·회사 4잡 진행, somatic 13쌍 QC·채점 완료 확인. HG003 Manta 오류는 별도 복구 잡 156780으로 재시도하며 Codex 4시간 점검·보고를 시작했다. [현황](../docs/STATUS.md) | [`edb1b9c`](https://github.com/ehojune/GIAB_benchmarking/commit/edb1b9c036c954e4689749537389dc518583f110) |
| — | HG008 PacBio somatic 13쌍 전장(DeepSomatic 1.10.0 CPU) 완료·채점. matched T-BCM SNV recall 0.950·precision 0.953, borrowed 11쌍 SNV recall 0.89~0.93. [기록](../docs/runs/2026-09-25-somatic-wgs.md) | [`c2b833f`](https://github.com/ehojune/GIAB_benchmarking/commit/c2b833fc8e738eac5dd94f8c5b01ff29817c4c81) |
| — | 카탈로그 TSV·Excel 442행 대조 차이 0. 회사 4개 재분석·GIAB 기본 5개·somatic 13쌍 실행은 [STATUS](../docs/STATUS.md)에 분리해 기록했다. | [`fee1711`](https://github.com/ehojune/GIAB_benchmarking/commit/fee1711e7979d3309cec06e8317b202290cd9454) |

## 2026-09-24

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | md5 전수 검증을 SGE 잡 156685로 재제출(sidecar 2차 판정, #40). 다운로드 세션 교훈 11건을 Yuan에 수확(ehojune/Yuan#6) — HARVEST.md 해당 15행에 자산 id 표시. Codex 리뷰 원칙: #37 3라운드·#40 3라운드 반영 후 머지. | [`b1fbff8`](https://github.com/ehojune/GIAB_benchmarking/commit/b1fbff883c13f3e2ae0ec97f4a9c4e25ca4c7c10) |
| — | MGISEQ HG002 정렬 실패의 원인을 찾아 고쳤다: bwa-mem2 2.2.1이 poly-T 150 bp 리드가 몰린 배치에서 SMEM 버퍼를 넘친다(세 실행이 같은 946,145,492 리드에서 죽었다). 리드를 버리지 않고 입력을 4구간 교차로 섞어 끝까지 통과(1,428,410,152 리드, fastp 출력과 일치). 파이프라인이 bwa 실패를 삼키므로 다른 MGI/BGI set도 끝나면 BAM 리드 수 검사를 돌릴 것. [기록](../docs/runs/2026-09-24-mgiseq-hg002-bwa-mem2-smem.md) | [`d773646`](https://github.com/ehojune/GIAB_benchmarking/commit/d7736466b7f7cfdddcc50cacc31d90bdf9435beb) |
| — | [PacBio] #8 9/9 완료. QC 거짓 경고 39건의 원인 둘(ts/tv 하한, 종양 판정 목록)을 고쳤고, 카탈로그 category 가 other 라 빠져 있던 HG008-T bulk p21·p41 을 등록했다(49 실행 단위). 구간별 hap.py 시험: Revio Clair3 의 INDEL 열세는 90% 가 12bp+ 호모폴리머. | [`153e856`](https://github.com/ehojune/GIAB_benchmarking/commit/153e856351acef1ffe458a41c0567d40dea392b2) |
| — | [ONT] HG002 R9 두 런(guppy 3.4.5, 3.2.x)을 R10 과 같은 v5.0q 층으로 채점했다. **옛 베이스콜러일수록 v4.2.1 밖 어려운 영역에서 더 무너진다** — SNP F1 R10 0.895 / 3.4.5 0.857 / 3.2.x 0.802, 겹침 층에선 셋 다 0.987 이상이라 안 보이던 차이다. R9 INDEL 은 겹침 층에서도 0.554 이하. [docs/reference/2026-09-24-ont-r10-v5q-stratified.md](../docs/reference/2026-09-24-ont-r10-v5q-stratified.md) §6 | [`8260906`](https://github.com/ehojune/GIAB_benchmarking/commit/82609067ebed37e4ec536d37fcc8cda25c564392) |
| — | [ONT] **DeepVariant 는 v4.2.1 밖 어려운 영역에서도 Clair3 를 이긴다.** HG002 v5.0q smvar(T2T-Q100) 로 층화 채점해 v4.2.1 이 빼놓은 상염색체 83 Mb 를 truth 로 셌다 — DV 가 FN SNP −17% · INDEL −10%, FP 는 절반 이하다. 9/22 에 "구간 안에서만 검증" 으로 한정해 뒀던 기본 caller 결정이 밖으로 넓어졌다. v5.0q 결과에서 v4.2.1 결과를 빼지 않고 한 채점 안에서 층을 갈랐고(두 truth 차이가 섞이지 않게), 겹침 층이 v4.2.1 채점과 0.001 안에서 맞아 해석이 선다. 남성 샘플의 chrX·Y 는 FN≈FP 대칭이라 유전형 표현 불일치로 보여 따로 뗐다. 같이 적은 것: ONT 공개 층화로 보면 R10 INDEL 오류의 94% 가 9bp 넘는 homopolymer 에 있다. [수치](../docs/reference/2026-09-24-ont-r10-v5q-stratified.md). | [`964ca22`](https://github.com/ehojune/GIAB_benchmarking/commit/964ca22b0b23ea46cd863395804eff05a0817ea4) |

## 2026-09-23

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | md5 전수 검증 재개 준비: 2026-09-09 결과(PASS 73,485 / FAIL 110 / NOREF 3,000)에 2026-09 신규 4,759 files가 빠져 있었고, FAIL의 원인이 낡은 current.tree(FTP 원본 2025-02-28 이후 정지)임을 확인. sidecar 2차 판정과 checksums.md5 등 누락 패턴을 넣어 SGE로 재제출. docs/SIZES.md를 매니페스트 생성기(`build_sizes.py`)로 재생성(HG009·외부 유래 포함). HG008 BioSkryb×UG100 4.4 TiB는 받지 않는 쪽으로 기록(사용자 결정 대기). | [`69b8559`](https://github.com/ehojune/GIAB_benchmarking/commit/69b855984599b6dda6d1f759eafc9a42ecb2b666) |
| — | [ONT] 하루 전 "DV 가 구간 밖에서 진짜 변이를 버린다" 는 의심의 근거였던 **두 caller 의 구간 밖 순차분 ts/tv 2.18 이 빼기의 부산물이었다.** `63_caller_diff_regions.sh` 로 실제 차집합을 세니 Clair3 단독 0.87 · DV 단독 0.67 로 germline 같은 집합이 없었다 — 순 차이는 두 집합의 구성 차이를 재지 원소를 재지 않는다. 다만 이것이 "버리지 않는다" 의 증명은 아니어서, 질문은 v5.0q smvar(T2T-Q100) truth 로 채점해 닫는다. **ONT 외부 대조군은 Clair3 였다** — hap.py 출력에 옮겨진 FILTER 설명 문구가 Clair3 소스와 일치한다. HG002 dup 런은 **V3.2.4 하나만** 돈다: 기기(PromethION vs MinION)와 베이스콜러가 섞인 헤드라인 비교를 가르려는 것이다. 같이 넣은 V2.3.4 는 **HG001 오라벨 플로우셀이 섞여 있어 시작 전 취소했다** — run_table 의 note 를 안 읽고 제출했고 Codex 리뷰가 잡았다. run_id 대조로 이미 채점한 V3.4.5 도 깨끗함을 확인했다. 통합 MultiQC 는 15런으로 갱신. [수치](../docs/reference/2026-09-22-ont-r10-benchmark.md) §1·§5. | [`2a77e91`](https://github.com/ehojune/GIAB_benchmarking/commit/2a77e918b85dd48b2124a790c44b1f1eb45a44ba) |
| — | phase3 2차 입력: 1차 밖 숏리드 WGS 전부(HG001·HG005~HG009 + HG002 잔여) 53 샘플을 20 set으로 배정하는 생성기와, 1차 set에 새 샘플을 못 넣게 하는 가드·병합 lock·sampleinfo 자동 추가를 03에 넣었다. germline 11 set(5.0 TiB) + somatic 9 set(7.3 TiB). [표](../phase3_shortread_wgs/README.md#2차-입력-2026-09-23--나머지-숏리드-전부). | [`91c116e`](https://github.com/ehojune/GIAB_benchmarking/commit/91c116e626da49ab6bd12da64eb7f14894639927) |
| — | `fetch_all.sh` 완료 판정 정책 확정(#37): 파일 수 `done==total` + 검증기 rc 0, 검증 로그 격리, 사후 검증은 항상 all. 기록 [docs/runs/2026-09-23-fetch-all-completion-policy.md](../docs/runs/2026-09-23-fetch-all-completion-policy.md). | [`0db4869`](https://github.com/ehojune/GIAB_benchmarking/commit/0db486925c3320609b8cab183d288bc842444675) |
| — | #33 후속: Codex 리뷰 3건 반영(`fetch_all.sh` — phase0는 다운로드 뒤 verify 합계 100%로만 성공 판정, phase0 미실행 시 옛 로그 무시, 단계 이름 오타·스크립트 부재는 FAIL). PacBio 세션이 짚은 README 수치 2곳을 FTP 본체(435행/81,302)와 4경로 전체(442행/81,330)로 구분해 적었다. | [`0db4869`](https://github.com/ehojune/GIAB_benchmarking/commit/0db486925c3320609b8cab183d288bc842444675) |
| — | [PacBio] #8 HG008-T 9런 중 8런 완료(예상의 절반인 5~7h). #9 는 방법 B 로 정하고 bioinfo-agent 위임 프롬프트를 남겼다 — 서버에서 HG008 matched pair 둘, smvar V0.3 이 truncal 만 담는다는 점(클론은 recall 만 해석)을 확인. phase1 에 구간별 hap.py(`STRAT=1`)·ts/tv 구간 분할·`qsub_task.sh`. | [`22d544f`](https://github.com/ehojune/GIAB_benchmarking/commit/22d544fd8df991c0f3486d3eaecc6be6517cb972) |
| — | 이 세션이 phase3 숏리드 전담으로 지정됨. 파이프라인 입력 22샘플 전수 점검(전부 명명 규약 준수), MGISEQ HG002 재생성 잡이 전날 밤 SAM 파싱 에러로 이미 실패해 있던 것을 발견해 STATUS/decisions 정정. | [`5fe0a17`](https://github.com/ehojune/GIAB_benchmarking/commit/5fe0a17570fae3dcd0aefcae96f579f250ef4be1) |
| — | **문서 구조 전환: `docs/STATUS.md` 를 현황판으로 되돌렸다**(249줄 → 65줄). 249줄 중 현황이 29줄(12%)뿐이었고 나머지는 레퍼런스·백로그·끝난 인계장이었다. 가른 기준은 "에이전트용이냐"가 아니라 **다음 주에 거짓이 되는가** — 안 변하는 것(노드 스펙·`_infra` 자산·점검 명령)은 [docs/reference/server-and-infra.md](../docs/reference/server-and-infra.md), 아직 안 한 일(#8·#9·#10 상세)은 [docs/backlog.md](../docs/backlog.md) 로 나눴다. 세션 조율 절 둘은 전부 해소돼 지웠고(규칙은 AGENTS.md 가 갖고 있다), 그 안에 섞여 있던 미해결 2건은 backlog 로 살렸다. 이력은 맨 아래에 14항목 그대로. `AGENTS.md` 충돌 규칙에 **"STATUS 에 다시 쌓지 않는다"** 를 명시했다. 근거: [decisions.md](../docs/decisions.md) 2026-09-23 항목. | [`24f9557`](https://github.com/ehojune/GIAB_benchmarking/commit/24f9557846598ddf432eb9a6cc95908a77ea62c0) |
| — | 세 세션(다운로드·PacBio·ONT) repo 정렬. ONT 몫: **카탈로그가 외부에서 들여온 런을 구조적으로 못 보던 구멍**을 찾아 고쳤다 — 카탈로그 행 key 가 `(sample, giab_path basename)` 인데 ext 행은 경로가 배포처 구조를, dataset 이 우리 명명 규칙을 따라 서로 다르다. HG002 R10 은 채점까지 끝난 런인데 카탈로그에 `variant_called=FALSE` 로 남아 있었고, 신호는 경고 한 줄뿐이었다. `EXT_ALIAS` 로 잇고 산출물 경로도 dataset 기준으로 바로잡아 **카탈로그 10행 갱신**. next_step 을 "다음 할 일"에서 **"한 것 + 남은 것"**으로 전환했고(PacBio 가 phase1 에서 먼저 한 전환), `phase2_ont/README.md` 의 소변이·SV·자원 실측 절을 R10 포함해 다시 썼다. 서버에 미추적으로 쌓여 있던 결과 파일 7개는 gitignore. | [`d8762e9`](https://github.com/ehojune/GIAB_benchmarking/commit/d8762e98a342aef54c83ee970fc63a04edb6d582) |

## 2026-09-22

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | **서버 디스크 전수 대조**: 네 취득 경로 매니페스트 합집합 81,330 files가 nbb2에 크기까지 전부 있음(mismatch 0, missing 0). 매니페스트 밖에 받아둔 데이터는 없고(EXTRA 19건은 md5 마커·로그·current.tree), FTP에서 삭제된 release 구버전 52건 8.4 GiB는 지우지 않고 보유 목록에 남긴다. 기록: [docs/runs/2026-09-22-disk-vs-manifest-reconciliation.md](../docs/runs/2026-09-22-disk-vs-manifest-reconciliation.md). 세 세션 컨텍스트 정렬을 위해 PR #27을 이 PR로 대체. | [`d8762e9`](https://github.com/ehojune/GIAB_benchmarking/commit/d8762e98a342aef54c83ee970fc63a04edb6d582) |
| — | 다운로드 진입점을 `phase0_download/scripts/fetch_all.sh` 하나로 모았다(FTP·ENA·ONT공개·GCS/S3 4경로). 반영이 빠져 있던 HG002 R10.4.1 ONT(160 GiB, CC BY-NC 4.0)를 `ext/` 행으로 카탈로그·README·Excel(v0922)에 넣어 442 datasets / 81,316 files / 114.3 TiB. `download.sh`가 declined/stale 목록을 이름만으로 받던 구멍도 막았다. 근거: [docs/decisions.md](../docs/decisions.md) 2026-09-22. | [`d8762e9`](https://github.com/ehojune/GIAB_benchmarking/commit/d8762e98a342aef54c83ee970fc63a04edb6d582) |
| — | **ts/tv 열린 질문이 닫혔다.** 2026-08-27 에 "전 런 ts/tv 가 germline 기대치보다 낮다"로 남긴 뒤 2026-09-18 에 가정을 깔고 추정했던 것을, `62_tstv_regions.sh` 로 benchmark BED 에 갈라 **직접 셌다**(10건, 전부 `안+밖=전체` 대조 통과). **구간 안이 2.0972~2.1400 으로 열 건 전부 germline 기대치 그대로고 구간 밖만 1.09~1.48** — 낮은 genome-wide ts/tv 는 콜러나 파이프라인이 아니라 신뢰구간 밖 콜 때문이다. 추정치도 맞았다(HG005 1.33 → 실측 1.3064, 오차 1.8%). 실측이 새로 알려준 것: **베이스콜러가 좋을수록 구간 밖 ts/tv 가 오히려 낮다**(R10 1.15 < guppy 4.2.2 1.30 < 3.2.x 1.48) — 좋은 베이스콜러가 어려운 영역까지 더 부르고 그 한계 콜이 FP 비중이 높다. 그리고 구간 안에서 두 caller 가 사실상 같은데(2.0974 vs 2.0972) 구간 밖 순 차이의 ts/tv 가 2.18 이라, **DeepVariant 가 구간 밖에서 버리는 쪽이 진짜 변이일 가능성**이 열린 질문으로 남았다 — "DV 가 이긴다"는 결론은 벤치마크 구간 안에서만 검증된 것이다. [수치](../docs/reference/2026-09-22-ont-r10-benchmark.md). | [`bb1e1f9`](https://github.com/ehojune/GIAB_benchmarking/commit/bb1e1f90b345e4c462e0009a317f614ddc61cdf1) |
| — | **phase2 HG002 R10.4.1 채점 전량 완료.** 이 런 하나가 R10 소변이·R10 SV·DeepVariant 셋을 동시에 열었다(HG002 가 소변이 v4.2.1 과 SV v5.0q truth 를 둘 다 가진 유일한 샘플). **ONT 가 같은 플로우셀 PAW70337 에 공개한 hap.py 결과와 SNP F1 −0.0001 / INDEL F1 −0.0013 로 일치** — ONT 정렬을 버리고 우리 minimap2 로 재정렬한 결과다. **DeepVariant 가 Clair3 를 네 칸 전부에서 이긴다**(INDEL F1 .9378 vs .9134, FP −33%) — phase1 PacBio 와 같은 방향이라 ONT R10 기본 caller 도 DV 로 둔다. INDEL 은 베이스콜러가 지배한다는 결론이 R10 에서도 유지되고, 이제 네 세대가 한 줄에 선다(guppy 3.2.x F1 .22 → 3.4.5 .56 → 4.2.2 .77~.82 → dorado R10 .91~.94; FP 비율 17배 감소). SV 는 R10 이 F1 +0.031 인데 **이득이 거의 전부 recall**(+0.048, precision 은 +0.006) — R9 도 헛부르진 않았고 놓쳤던 것이다. refine 이득은 케미스트리와 무관하게 +4.8~5.3점. 자원: 파이프라인 16h20m/66.2 GB, hap.py 50.7분/24.6 GB, truvari 4.5분/**133.5 GB**(→ SV 슬롯 22→33). 기록: [docs/runs/2026-09-22-phase2-r10-benchmark.md](../docs/runs/2026-09-22-phase2-r10-benchmark.md), [수치](../docs/reference/2026-09-22-ont-r10-benchmark.md). | [`4c7778f`](https://github.com/ehojune/GIAB_benchmarking/commit/4c7778f3999517788dca0687b90f8157047c6663) |
| — | **phase2 HG002 R10.4.1 완주**(잡 155279, exit 0, 16시간 20분, maxvmem 66.2 GB / 30슬롯, shepherd-1-8). `30_verify_outputs.sh` OK 1/1. `aligned_bam_realign` 진입이 실전에서 처음 증명됐고, **이 런 하나가 R10 소변이·R10 SV·DeepVariant 채점 셋을 동시에 연다** — HG002가 v4.2.1(소변이)과 v5.0q(SV) truth 를 둘 다 가진 유일한 샘플이기 때문이다. 같은 플로우셀에 대한 ONT 자체 hap.py 결과(SNP F1 .9983 / INDEL F1 .9147)가 외부 대조군이 된다. QC·채점은 다음 차례. 곁가지로 `35_review_qc.py --pass-counts` 가 `PermissionError: 'bcftools'` 로 죽던 것을 고쳤다 — 도구를 `$BCFTOOLS` → 컨테이너 → PATH 순으로 찾게 하고, 핸들러를 `except OSError` 로 넓혔다. | [`4c7778f`](https://github.com/ehojune/GIAB_benchmarking/commit/4c7778f3999517788dca0687b90f8157047c6663) |
| — | phase1 PacBio 채점 **전량 완료**(소변이 19런 × 2 caller, SV 5런, 잡 24건 전부 exit 0). 정답셋이 있는 것은 다 했고 남은 15 실행단위(HG008/HG009)는 somatic 평가가 서야 채점된다. 중간 보고: [docs/reports/2026-09-22-phase1-pacbio-benchmark.md](../docs/reports/2026-09-22-phase1-pacbio-benchmark.md). #8(HG008 9런 등록)·#9(somatic 평가 설계)가 끝나면 이 보고와 합쳐 최종 보고를 쓴다. | [`204a817`](https://github.com/ehojune/GIAB_benchmarking/commit/204a81748323d87583ce1d5270b1a11ed5e0be91) |
| — | phase1 SV 첫 실측 완료(Truvari vs v5.0q, HG002 5런 전량). refine F1 .8208~.8418. **precision은 0.90으로 고른데 recall이 0.757~0.788** — pbsv가 truth 28,123개 중 21,282~22,147개를 찾고 5,976~6,841개를 놓친다. **SV에는 세대 단조성이 없다** — Sequel I 두 런이 Sequel II 두 런을 사이에 두고 갈라진다(Revio .8418 > SeqII .8362 > **SeqI .8333** > SeqII .8275 > SeqI .8208). 소변이 INDEL과 순위가 뒤집히기까지 한다 — `CCS_15kb`는 INDEL 19런 중 꼴찌(.9282)인데 SV는 3위다. **런을 하나의 품질 축으로 줄 세우면 안 된다.** refine 이득 +4.9~5.4점은 phase2 ONT(+4.8~5.1)와 거의 같아, 이 이득이 콜 품질이 아니라 표현 정규화라는 설명과 맞는다. [수치](../docs/reference/2026-09-22-pacbio-hifi-benchmark-first-results.md). | [`204a817`](https://github.com/ehojune/GIAB_benchmarking/commit/204a81748323d87583ce1d5270b1a11ed5e0be91) |
| — | phase1 PacBio HiFi 정확도 평가 첫 실측(hap.py 19런 × 2 caller, 38건, 전부 exit 0). **SNP는 F1 0.9984~0.9994로 포화**돼 기기·caller 차이가 없고, **INDEL은 기기 세대가 가른다** — Sequel I 2런이 0.928·0.965로 나머지(0.975~0.997)와 갈린다. DeepVariant가 기기별 모델 없이 같은 격차를 내므로 caller 모델 탓이 아니라 데이터 쪽이다. **Revio에서만 Clair3가 INDEL −0.006~−0.017로 진다**(`hifi_revio` 모델을 제대로 받았는데도). → PacBio 기본 caller는 DeepVariant. [수치](../docs/reference/2026-09-22-pacbio-hifi-benchmark-first-results.md). | [`1ecd16b`](https://github.com/ehojune/GIAB_benchmarking/commit/1ecd16b8c5abc71e0536ce68f538289fbe516dc7) |
| — | 쓸 수 있는 노드가 또 바뀌어(shepherd 3대 → octopus-2-8/2-9 + shepherd-1-8/1-9 넷, **큐 둘**) 이름을 박는 대신 `qstat -f`와 대조해 쓰도록 고쳤다 — 큐 x 노드가 안 겹치면 잡이 에러 없이 `qw`로 영원히 남는 실패를 제출 전에 막는다. 같은 커밋에서 phase1에 Truvari SV 평가(`61_benchmark_sv.sh`)를 phase2에서 이식했다. **phase1 쪽이 답이 많다** — HG002 5런이 Sequel I 2 + Sequel II 2 + Revio 1로 갈려 **세 세대** 비교가 된다(phase2는 둘 다 R9). 양쪽 `10_submit.sh`의 qsub 실패 무시(빈 jobid에 `OK` 출력)도 같이 고쳤다. | [`1ecd16b`](https://github.com/ehojune/GIAB_benchmarking/commit/1ecd16b8c5abc71e0536ce68f538289fbe516dc7) |

## 2026-09-21

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | phase3 WGRS 첫 실행이 markdup에서 전부 죽음(GATK 4.6.1.0 vs Java 8). Java 17 래퍼로 6세트 재제출(잡 155519~24), MGISEQ HG002는 정렬 BAM 33% 누락이라 재생성 잡(155525) 후 재개. 동시에 phase2 R10·phase1 hap.py가 돌아 현황판 `docs/STATUS.md`를 두고 매 세션 갱신하기로. PR #20. | [`b1a3f36`](https://github.com/ehojune/GIAB_benchmarking/commit/b1a3f36a4fe8747ef5b3ca6c85be54e7e2a530fa) |
| — | HG002 R10 런의 진입을 `aligned_bam`(ONT 정렬 그대로)에서 **`aligned_bam_realign`(우리 minimap2로 재정렬)** 으로 정정. "남의 run 결과물보다 우리 결과물을 믿는다"는 설계 원칙과 어긋났고, 이 런의 목적이 R9↔R10 비교라 정렬이 다르면 비교축에 교란이 박힌다. 같이 발견: 스모크 테스트가 진입 타입 셋 중 둘만 덮고 있었고, 채널 재그룹에서 진입 타입이 유실되는 버그가 있었다. 기록: [docs/runs/2026-09-21-phase2-r10-realign.md](../docs/runs/2026-09-21-phase2-r10-realign.md). | [`56df5f5`](https://github.com/ehojune/GIAB_benchmarking/commit/56df5f5ea93fe1fb9c181a6e87d3ae23214ae867) |

## 2026-09-19

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | phase3 파이프라인 입력 22 샘플 dir 준비 완료(nbb2 `/BiO/scratch/dyl/kbb/G000/GIAB-publicData-*/outcome/`): 1쌍짜리 7개는 링크, 15개는 cat 병합(15/15 크기 검증). 이름은 `_`를 mate 접미에만 남기고 `-`로 통일(파이프라인이 `_`로 샘플명을 자름). 사용자가 자체 WGRS 파이프라인 실행 시작. PR #13·#16. | [`31103f1`](https://github.com/ehojune/GIAB_benchmarking/commit/31103f127260cf2caf2cb436e883731be7aae679) |

## 2026-09-18

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | phase2 ONT 파이프라인 **14/14 완료**(HG008T-p2 종료). QC 경고는 `N50미산출` 2건뿐이고 둘 다 R10 std 런이다(위상 자체는 정상 — whatshap 출력 원문 확인이 남았다). HG008T-p2가 전 코호트 최고 성적: 염기 매핑률 99.5%, 오류율 .0237, 77x. | [`efc7e28`](https://github.com/ehojune/GIAB_benchmarking/commit/efc7e287f0f2c963fabd8ccd790169c4cb6f6357) |
| — | phase2 ONT 정확도 평가 첫 실측(hap.py 8런 + Truvari 2런, 10잡 전부 exit 0). **SNV는 전 런 F1 .986~.997로 쓸 만하고, indel은 베이스콜러가 지배한다** — 2026-08-27에 개수로 본 3.5배 격차가 truth 대비로는 FP 42배였고 guppy 4.2.2조차 recall .68~.75다. SV는 HG002 2런에서 refine이 F1을 4.8~5.1점 올렸다. **2026-08-27의 ts/tv 열린 질문은 R9에서 닫혔다**(FP가 벤치마크 구간 밖에 몰려 있다). R10 6런과 DeepVariant는 germline truth가 없어 구조적으로 평가 불가. 기록: [docs/runs/2026-09-18-phase2-ont-benchmark.md](../docs/runs/2026-09-18-phase2-ont-benchmark.md), [수치](../docs/reference/2026-09-18-ont-benchmark-first-results.md). | [`efc7e28`](https://github.com/ehojune/GIAB_benchmarking/commit/efc7e287f0f2c963fabd8ccd790169c4cb6f6357) |
| — | phase0 다운로드 전량 완료. 2026-09 크롤로 늘어난 신규 4,759 files / 8.67 TiB를 받아 `verify.sh` 12개 카테고리 전부 100.0%, 합계 81,302/81,302 files · 116,509.5 GiB. 28시간 49분, 평균 92 MB/s — "S3에 신규가 없으니 며칠 잡으라"던 예측은 틀렸다(S3 실측 83 MB/s보다 빨랐다). 기록: [docs/runs/2026-09-18-phase0-download-complete.md](../docs/runs/2026-09-18-phase0-download-complete.md). | [`19fa74c`](https://github.com/ehojune/GIAB_benchmarking/commit/19fa74c8184d902b5946e84766ef96c9884802af) |

## 2026-09-17

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | phase3 외부 리드 12 files / 359 GiB 다운로드·검증 완료(`02_fetch_external_reads.sh` 12/12 OK, ERROR 0, NovaSeq X 쌍은 SRA 헤더로 플랫폼 미상 경고 2건 — 예상대로). 24 실행 단위 전부 nbb2에 있다. PR #10. | [`0b8d8e6`](https://github.com/ehojune/GIAB_benchmarking/commit/0b8d8e674b9015b0a055dac3dd59a6f5f4493969) |
| — | 업체 4곳이 NovaSeq X/X Plus로 확인돼 phase3에 HG002 NovaSeq X 30x(Google 재배포, Weill Cornell PRJNA1427896, TruSeq PCR-free, 41 GiB)를 화학 매칭 단일 대조군으로 추가. 실행 단위 24. 외부 리드 경로는 실제 다운로드 위치 `external/<출처>/`로 통일. | [`bdbb06e`](https://github.com/ehojune/GIAB_benchmarking/commit/bdbb06efa982d88447dbd82d34d5f4675d69410f) |
| — | phase3에 업체 비교용 30x 트리오 2종을 외부에서 추가: Google NovaSeq 6000 PCR-free 30x(HG002/3/4, 147 GiB)와 HPRC S3의 HiSeq 30x 서브샘플(HG003/4, 170 GiB; GIAB FTP에는 HG002만). 실행 단위 18→23, 300x 전량은 깊이 상한 실험으로 역할 변경. 검증은 HEAD·리드 헤더 표본만(사용자 결정). Codex·Gemini 독립 자문은 둘 다 NovaSeq 30x를 1순위로 꼽았다. | [`bdbb06e`](https://github.com/ehojune/GIAB_benchmarking/commit/bdbb06efa982d88447dbd82d34d5f4675d69410f) |
| — | 2026-09-16 크롤이 찾은 3건을 받지 않기로 확정: legacy trio 분석 8,228 files / 7.78 TiB, HG008 superseded-2022 raw 26 / 1.63 TiB(이미 받은 디렉토리와 동일 내용), Verkko 작업 디렉토리 4,169 / 1.28 TiB. 목록은 `manifests/declined_by_decision.tsv`에 남기고 `crawl_data.py`가 재추가하지 않도록 가드를 넣었다. 카탈로그 435 datasets / 81,302 files. 실제 내려받을 신규분은 4,759 files / 8.67 TiB (2026-08-30 완료 시점 76,595 files 대비). | [`6d8efb5`](https://github.com/ehojune/GIAB_benchmarking/commit/6d8efb532d0db7aa72e854d8aa97e80e904a3ce9) |

## 2026-09-16

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | data/·data_somatic/·data_RNAseq/도 FTP 라이브 크롤(`crawl_data.py`): 2026-08-13 S3 기반 목록에서 빠졌던 HG008 NIST 트리·HG009 신규·Verkko 등 7,377 files / 11.5 TiB를 manifest에 추가(카탈로그 436 datasets), 2014~2020 trio 분석 8,228 files / 7.8 TiB는 `optional_trio_analysis_legacy.tsv`로 분리. FTP·S3 미러가 양방향으로 어긋남을 확인(FTP만 다른 7,122 + FTP에서만 사라진 2,173 → S3 기준 유지). | [`9f590d4`](https://github.com/ehojune/GIAB_benchmarking/commit/9f590d49e2e6480a2a7a6d8428ea697d9032694e) |
| — | release/를 FTP 라이브 크롤로 재대조(`crawl_release.py`): HG002 v5.0q(9.4 GiB, latest/ 복사본 포함 2벌)·stratifications v3.6(22.5 GiB) 등 1,577 files / 41.4 GiB 추가, HG002 latest/ 옛 v4.2.1 51건 제거(순증 +1,525 files). `current.tree`가 2025-02-27 이후 미갱신인 것이 원인. 카탈로그 334 datasets, 엑셀 v0916. | [`3b59434`](https://github.com/ehojune/GIAB_benchmarking/commit/3b59434045af7f4516791b7f6ef6a6a84406a96b) |

## 2026-09-09

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | phase3 시작: HG002·3·4 숏리드 WGS 입력 목록(`phase3_shortread_wgs/inputs_manifest.tsv`, 18 실행 단위 / 6,178 FASTQ / 5.55 TiB)과 small-variant 정답셋 경로 정리. | [`3b59434`](https://github.com/ehojune/GIAB_benchmarking/commit/3b59434045af7f4516791b7f6ef6a6a84406a96b) |

## 2026-08-30

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | phase0 다운로드 전량 완료 확인: verify.sh all 기준 76,595/76,595 files, 107,637 GiB (115.6 TB), 100.0%. HG001–HG009 + release + RNA-seq + trio_analysis 전부. 8/13 시작, 정전 1회 포함 약 2주. | [`9ebc22f`](https://github.com/ehojune/GIAB_benchmarking/commit/9ebc22fb64288443c6c22196e47e264303d1b122) |

## 2026-08-26

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | HG008 최신 benchmark를 반영하고 플랫폼·리드·툴·다음 할 일의 모든 자동 축약을 없앴다. | [`4478de4`](https://github.com/ehojune/GIAB_benchmarking/commit/4478de438e20fea8e115e5d7de7f6254050acffc) |

## 2026-08-23

| 시간 | 주요 변경사항 | 근거 |
|---|---|---|
| — | Yuan 최소 준수 retrofit을 적용했다. 기존 카탈로그·PacBio HiFi·ONT 분석 구조와 HARVEST 후보는 유지했다. | [`897393e`](https://github.com/ehojune/GIAB_benchmarking/commit/897393e43dbd7be0be63d6ec027550a2da173aa3) |
