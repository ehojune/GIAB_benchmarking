# GIAB 현황

2026-09-26 09:56–10:00 서버 직접 확인. **Codex 총괄 복귀**, Claude 인계·총괄 프로세스 중지 완료. 회사·공개 **8잡 실행 중**, Illumina 재시도는 Error 종료. 완료 기준은 [SCOPE](SCOPE.md). 카탈로그는 somatic 13행·BioSkryb 수령 결정을 반영했고 최근 TSV·Excel **442행 × 51열 대조 차이 0**.

| 작업 | 현재 상태 | 다음 한 번의 행동 |
|---|---|---|
| 업체 gd1~4 germline 재분석 | **156760–156763 모두 `r`**, 분석 완료 아님 | 현재 run의 `__DONE__`·`error_list.txt`·BAM/VCF·간단 QC 확인 후 비교. 중복 재시작하지 않음 |
| 업체 + 공개 HG002/3/4 비교 | 회사 12개·공개 4개 비교는 기본 run·QC 대기. PacBio의 같은 비교도 보류, 새 비교 잡 미제출 | **Codex가 시점·단일 실행 담당 관리**. 회사 run 완료·QC 후 기존 hap.py/v4.2.1 비교(브랜치 `claude/phase3-07-happy`의 `11_happy_submit.sh`)와 PacBio·ONT 기존 결과 요약. 옛 캐시 재사용 금지 |
| GIAB 숏리드 기본 run | **155526–155528, 156690 `r`**. 추가 20 set·53샘플은 미제출 | 현재 잡 유지, 완료·간단 QC 확인. 일괄 추가 제출하지 않음 |
| Illumina-250PE 재시도 | **156786은 09:39 exit 1, `__DONE__=Error`**. Manta HG002/3/4는 SV gap, HG002 verifybamID는 QC gap. **HG004 verifybamID 성공**. HG003 gather·변이 집계는 계산 성공 후 기존 링크 충돌 | 추가 재시도 없음. HG002/3/4 SNP/INDEL 산출물 최소 QC 통과, **세트 전체 완료는 아님**. 정상 결과·실패 근거 보존. [판정·검증](runs/2026-09-26-illumina-regermline-retry.md#종료-결과와-판정-09391000) |
| GIAB PacBio·ONT | 담당자 보고상 PacBio verify **49/49**, 소변이 19런·SV 5런. ONT HG002/3/4 기본 run·QC·채점 완료 | 기존 결과를 비교표에 연결. **업체 롱리드는 수령 대기**(사용자 확인); 받으면 기존 파이프라인 적용 |
| 다운로드 | 담당 보고: 활성 목록 **81,302개 = PASS 77,511 + 당시 FAIL 39 + NOREF 3,752**, MISS 0. 39건 후속 대조에서 실제 시퀀싱 파일 손상은 보고되지 않음. **BioSkryb×UG100 476개 / 4.75 TiB(5.22 TB) 수령 진행**, 09:56 wget 6개 확인. 수령 코드·명세는 **PR #75 main 반영**, stale 52건 보유 확정 | 수령 뒤 크기·제공 MD5(238개) 전건 검증 → `reads_present=TRUE` → 디스크 대조. 현재는 수령 완료 아님. 역사적 FAIL과 `NOREF`를 검증 성공으로 바꾸지 않음. MD5 정리 **draft PR #69 merge 보류** |
| 범용 bioinfo 개발 / GIAB somatic | **HG008 13쌍 전장·채점·QC 완료**. caller **156747–156759**, 채점·QC **156764–156779** 전부 qacct `failed=0`, `exit_status=0` 직접 확인. 서버 QC **13/13 VCF OK**, 채점 summary **28개**. vendor `f2de95e`·DeepSomatic 1.10.0 CPU | 이번 배치는 추가 실행 없이 닫음. matched 2쌍은 precision·recall, borrowed 11쌍은 recall만 해석. [결과·QC·한계](runs/2026-09-25-somatic-wgs.md) |

공통 백업: `/BiO/scratch/dyl/kbb/G000/backup/20260925-company-reset`. 실행 기록: 서버 `G000/.company-reset-20260925.json`. 백업 링크·엑셀 교정 상세는 [decisions](decisions.md) 끝에 남겼다.

승인된 정리 3건 중 PacBio 요약은 PR #74로 main에 들어갔고([보고서](reports/2026-09-22-phase1-pacbio-benchmark.md)), 나머지 둘은 담당 브랜치에 완료됐으며 **main 미통합**: [ONT 동일 flowcell 비교](https://github.com/ehojune/GIAB_benchmarking/blob/6a18594/docs/reference/2026-09-25-ont-guppy324-vs-345-same-flowcell.md), [MD5 후속 대조](https://github.com/ehojune/GIAB_benchmarking/blob/5b2c18b/docs/runs/2026-09-25-md5-verification-followup.md). ONT 차이를 basecaller 버전 하나의 효과로 단정하지 않는다. ONT poller는 종료됐고 **draft PR #68·#69 merge와 반복 리뷰는 보류**다.

근거: [숏리드 입력·truth](../phase3_shortread_wgs/README.md), [PacBio 기존 결과](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md), [ONT 기존 결과](reference/2026-09-22-ont-r10-benchmark.md), [PR #69](https://github.com/ehojune/GIAB_benchmarking/pull/69).

**Codex가 단독으로 4시간 점검·보고와 승인된 후속 작업을 맡는다.** Claude 총괄의 중복 점검은 종료했다. 회사 run 완료·QC 전 비교는 계속 보류한다.

남은 일은 [backlog](backlog.md). 이전 현황·전체 이력은 [조정 전 스냅샷](reference/2026-09-25-status-before-scope-reset.md), 서버 명령은 [조회용 자료](reference/server-and-infra.md)에 보존했다.
