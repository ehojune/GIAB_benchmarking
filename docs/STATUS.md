# GIAB 현황

2026-09-28 05:09 KST 확인. **HG002 Manta 복구·반영 완료, Illumina 소변이 비교 3건 실행.** [이번 점검](runs/2026-09-28-0500-heartbeat.md). [진단·수정](runs/2026-09-28-manta-stack-diagnosis.md) · [비교 16건](reports/2026-09-27-shortread-sixteen.md).

| 작업 | 현재 상태 | 다음 행동 |
|---|---|---|
| 업체 기본 run·QC | gd1~4 기본 run exit 0·DONE Success. Verify 오류 **11/11건 복구**, QC 24/24 checksum·결과 링크 확인 | 완료 상태 유지 |
| HG002/3/4 비교 | **16건 완료 + Illumina250PE 3건 실행**(156834–156836). 기존 hap.py/v4.2.1 조건 | 종료·채점 확인 후 표·카탈로그·Excel 반영 |
| 공개 기본 run | **155526–155528, 156690 r**. 04:43→05:01 CPU·활성 Mark 로그 12개 모두 증가. MGI HG003 stage 7→11 | 현재 잡 유지, 종료·산출물·최소 QC 확인 |
| Illumina-250PE QC | HG002 Verify 156823 exit 0, 00:05 반영. 기존 HG003/HG004 포함 3/3 확인 | Verify 추가 재시도 없음 |
| Illumina Manta | **HG002 156831 exit 0·QC·결과 반영 완료**. HG003/4 156832/156833 실행 중 | 각 종료·QC 확인 뒤 반영. 실패 시 로그로 수정·재제출 |
| 다운로드·PacBio·ONT | 기본 정리 완료. BioSkryb 476개 수령·제공 MD5 검증, 카탈로그·Excel 반영 유지 | 업체 롱리드 수령 대기 |
| HG008 somatic | **13쌍 QC·채점 완료**. 29잡 exit 0·QC 해시 불변·summary 28개 | 결과 보존, 범용 bioinfo 개발은 별도 |

Illumina SV gap은 HG003/4 두 건이다. `__DONE__=Error`는 과거 실행 기록으로 보존했다. 옛 error_list의 HG002 Verify 오류는 이번 복구로 해소됐지만 원래 기록을 지우지 않았다. [최종 재시도 결과](runs/2026-09-28-0303-heartbeat.md).

Codex가 단독 총괄한다. **오늘 09시 전 30분 점검 → 09시 5장 PPT → 이후 4시간 점검**. [실행 준비](runs/2026-09-28-before0900.md). Claude 5세션은 현재 registry에 없고 저장 기록에 새 실행이 없다. 원자료·정상 결과·실패 근거를 보존하며 자료 보유 변화가 없어 Excel은 다시 쓰지 않았다. [범위](SCOPE.md) · [남은 일](backlog.md).
