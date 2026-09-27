# GIAB 현황

2026-09-28 06:07 KST 검증. **숏리드 비교 19건 완료, 공개 기본 4잡 실행.** [이번 점검](runs/2026-09-28-0600-heartbeat.md) · [비교표](reports/2026-09-28-shortread-nineteen.md).

| 작업 | 현재 상태 | 다음 행동 |
|---|---|---|
| 업체 기본 run·QC | gd1~4 기본 run exit 0·DONE Success. Verify 오류 **11/11건 복구**, QC 24/24 checksum·결과 링크 확인 | 완료 상태 유지 |
| HG002/3/4 비교 | **19건 완료**: 회사 12건 + 공개 7건. 기존 hap.py/v4.2.1 조건 | 표·공개 7행의 카탈로그·Excel 반영 완료 |
| 공개 기본 run | **155526–155528, 156690 r**. 05:31→06:01 CPU·활성 Mark 로그 12개 모두 증가 | 현재 잡 유지, 종료·산출물·최소 QC 확인 |
| Illumina-250PE QC | HG002 Verify 156823 exit 0, 00:05 반영. 기존 HG003/HG004 포함 3/3 확인 | Verify 추가 재시도 없음 |
| Illumina Manta | **HG002/3/4 156831–156833 exit 0·QC·결과 반영 완료** | 복구 종료, 기존 결과 보존 |
| 다운로드·PacBio·ONT | 기본 정리 완료. BioSkryb 476개 수령·제공 MD5 검증, 카탈로그·Excel 반영 유지 | 업체 롱리드 수령 대기 |
| HG008 somatic | **13쌍 QC·채점 완료**. 29잡 exit 0·QC 해시 불변·summary 28개 | 결과 보존, 범용 bioinfo 개발은 별도 |

Illumina의 Manta 3건·Verify 오류는 복구했다. `__DONE__=Error`와 error_list는 과거 실행 기록으로 보존한다. 기존 링크 충돌과 현재 결과를 구분한 [근거](reference/2026-09-28-0530-status-evidence.json).

Codex가 단독 총괄한다. **오늘 09시 전 30분 점검 → 09시 5장 PPT → 이후 4시간 점검**. [실행 준비](runs/2026-09-28-before0900.md). Claude 5세션은 현재 registry에 없고 저장 기록에 새 실행이 없다. 원자료·정상 결과·실패 근거를 보존했다. 공개 숏리드 7행의 처리 누락 기록과 Excel 현황을 갱신했다. [범위](SCOPE.md) · [남은 일](backlog.md).
