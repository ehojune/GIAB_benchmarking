# GIAB 현황

2026-09-28 03:04 KST 확인. **공개 4잡은 진행 중. Illumina Manta 3건은 마지막 재시도도 실패해 반복을 중단했다.** [비교 16건](reports/2026-09-27-shortread-sixteen.md) · [이번 근거](reference/2026-09-28-0303-status-evidence.json).

| 작업 | 현재 상태 | 다음 행동 |
|---|---|---|
| 업체 기본 run·QC | gd1~4 기본 run exit 0·DONE Success. Verify 오류 **11/11건 복구**, QC 24/24 checksum·결과 링크 확인 | 완료 상태 유지 |
| HG002/3/4 비교 | **16건 완료**: 4회사×3 + 공개 4. 기존 hap.py/v4.2.1 조건 | 공개 후속 결과가 준비되면 승인 범위에서 비교 |
| 공개 기본 run | **155526–155528, 156690 r**. 00:03 대비 CPU 증가·활성 Mark 로그 12개 모두 증가. HiSeq HG003 stage 2→4 | 현재 잡 유지, 종료·산출물·최소 QC 확인 |
| Illumina-250PE QC | HG002 Verify 156823 exit 0, 00:05 반영. 기존 HG003/HG004 포함 3/3 확인 | Verify 추가 재시도 없음 |
| Illumina Manta | **2차 156827–156829도 exit 1·후보 SV 생성 SIGSEGV**. 각 2/2회 소진 | 동일 명령 추가 제출 중단. 원인은 미확정 |
| 다운로드·PacBio·ONT | 기본 정리 완료. BioSkryb 476개 수령·제공 MD5 검증, 카탈로그·Excel 반영 유지 | 업체 롱리드 수령 대기 |
| HG008 somatic | **13쌍 QC·채점 완료**. 29잡 exit 0·QC 해시 불변·summary 28개 | 결과 보존, 범용 bioinfo 개발은 별도 |

Illumina 세트는 아직 SV gap이며 `__DONE__=Error`다. 옛 error_list의 HG002 Verify 오류는 이번 복구로 해소됐지만 원래 기록을 지우지 않았다. [최종 재시도 결과](runs/2026-09-28-0303-heartbeat.md).

Codex가 단독 총괄하며 3시간마다 점검·보고한다. Claude 5세션은 현재 registry에 없고 저장 기록에 새 실행이 없다. 원자료·정상 결과·실패 근거를 보존하며 자료 보유 변화가 없어 Excel은 다시 쓰지 않았다. [범위](SCOPE.md) · [남은 일](backlog.md).
