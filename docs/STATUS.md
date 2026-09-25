# GIAB 현황

2026-09-25 15:46–16:05 관리자 서버 확인. 완료 기준은 [SCOPE](SCOPE.md). 아래는 해당 시각의 상태이며 실시간 표시가 아니다. 카탈로그 TSV·Excel **442행 × 51열 대조 차이 0**; 실행 중인 잡은 카탈로그의 완료 표시와 구분한다.

| 작업 | 현재 상태 | 다음 한 번의 행동 |
|---|---|---|
| 업체 gd1~4 germline 재분석 | **156760–156763 모두 `r`**. 로그 step: gd1/2/3 **30/265**, gd4 **24/265**. step 수는 작업 시간·분석 완료율이 아님 | 현재 run의 `__DONE__`·`error_list.txt`·BAM/VCF·간단 QC 확인 후 비교. 중복 재시작하지 않음 |
| 업체 + 공개 HG002/3/4 비교 | 이전 업체 결과·비교 캐시는 역사자료로 보관. 교정한 run은 아직 미완료이며 **새 비교 잡은 제출하지 않음** | 교정 run 완료 후 완료된 공개 NovaSeq군과 이미 승인된 hap.py/v4.2.1 단순 비교. 옛 캐시 재사용 금지 |
| GIAB 숏리드 미완료 기본 run | **155526–155529, 156690 모두 `r`**. Mark 로그 14개 모두 오전보다 전진. Illumina HG003 Manta 오류(-11)는 입력 검증 후 Codex가 **156780 `r`**로 별도 폴더에서 1회 재시도 | [복구 결과](runs/2026-09-25-illumina-hg003-manta-retry.md) 검증 후 반영. 기존 9잡·공유 pipeline·원출력·error_list 유지. 준비된 20 set·53샘플은 미제출 |
| GIAB PacBio·ONT | 담당자 보고상 PacBio verify **49/49**, 소변이 19런·SV 5런. ONT HG002/3/4 기본 run·QC·채점 완료 | 기존 결과를 비교표에 연결. **업체 롱리드는 수령 대기**(사용자 확인); 받으면 기존 파이프라인 적용 |
| 다운로드 | 담당 보고: 활성 목록 **81,302개 = PASS 77,511 + 당시 FAIL 39 + NOREF 3,752**, MISS 0. 39건 후속 대조에서 실제 시퀀싱 파일 손상은 보고되지 않음. **draft PR #69**, merge 보류 | 후속 보고를 참고하되 역사적 FAIL 기록은 보존. `NOREF`를 checksum 검증 성공으로 쓰지 않음 |
| 범용 bioinfo 개발 / GIAB somatic | **HG008 13쌍 전장·채점·QC 완료**. caller **156747–156759**, 채점·QC **156764–156779** 전부 qacct `failed=0`, `exit_status=0` 직접 확인. 서버 QC **13/13 VCF OK**, 채점 summary **28개**. vendor `f2de95e`·DeepSomatic 1.10.0 CPU | 이번 배치는 추가 실행 없이 닫음. matched 2쌍은 precision·recall, borrowed 11쌍은 recall만 해석. [결과·QC·한계](runs/2026-09-25-somatic-wgs.md) |

공통 백업: `/BiO/scratch/dyl/kbb/G000/backup/20260925-company-reset`. 실행 기록: 서버 `G000/.company-reset-20260925.json`. 백업 링크·엑셀 교정 상세는 [decisions](decisions.md) 끝에 남겼다.

승인된 정리 3건은 담당 브랜치에 완료됐으며 **main 미통합**: [PacBio 요약](https://github.com/ehojune/GIAB_benchmarking/blob/e43ca77/docs/reports/2026-09-22-phase1-pacbio-benchmark.md), [ONT 동일 flowcell 비교](https://github.com/ehojune/GIAB_benchmarking/blob/6a18594/docs/reference/2026-09-25-ont-guppy324-vs-345-same-flowcell.md), [MD5 후속 대조](https://github.com/ehojune/GIAB_benchmarking/blob/5b2c18b/docs/runs/2026-09-25-md5-verification-followup.md). ONT 차이를 basecaller 버전 하나의 효과로 단정하지 않는다. ONT poller는 종료됐고 **draft PR #68·#69 merge와 반복 리뷰는 보류**다.

근거: [숏리드 입력·truth](../phase3_shortread_wgs/README.md), [PacBio 기존 결과](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md), [ONT 기존 결과](reference/2026-09-22-ont-r10-benchmark.md), [PR #69](https://github.com/ehojune/GIAB_benchmarking/pull/69).

Codex의 **4시간 간격 점검·보고는 활성화**했다. 승인 범위의 완료 확인·QC·후속 작업만 진행하고 기존 Claude 타이머는 재개하지 않는다.

남은 일은 [backlog](backlog.md). 이전 현황·전체 이력은 [조정 전 스냅샷](reference/2026-09-25-status-before-scope-reset.md), 서버 명령은 [조회용 자료](reference/server-and-infra.md)에 보존했다.
