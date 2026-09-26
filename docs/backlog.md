# 남은 일과 보류한 일

[SCOPE](SCOPE.md)가 완료 기준이다. Codex 한 담당이 비교 시점·실행을 관리한다.

| 순서 | 남은 일 | 완료 표시 |
|---|---|---|
| 1 | **VerifyBamID 156799–156805** 종료·exit 0·VERIFIED.json 검증 후 해당 QC만 반영 | gd3 HG002 1건 복구 완료, fastp 12샘플 보고서 복원 완료. 원자료·정상 결과·원래 실패 로그 보존 |
| 2 | **gd1·gd2 비교 156806–156811** 종료·summary 확인. gd4·공개 기본 4잡 계속 확인 | 기존 비교 7건 완료. gd4 종료·최소 QC 뒤 비교 3건과 실패 QC 복구. Illumina 기존 gap 유지, 추가 20 set 일괄 제출 금지 |
| 3 | BioSkryb×UG100 수령·크기·제공 MD5 검증 마무리 | 현재 83.11% 수령. 완료 뒤 카탈로그·Excel 갱신 |
| 4 | 업체 롱리드 수령 뒤 기존 pipeline/QC/truth 비교 | 현재 **수령 대기**. GIAB 자료와 업체 자료를 구분 |

## 보류 — 자동으로 다시 시작하지 않음

- 추가 truth/구간·원인 연구, caller·도구 비교, 동일 원본 중복 run, 전체 구조 통일.
- 반복 PR 리뷰, 새 Claude 위임·타이머·상시 polling, 신규 release 전수 추적, 자동 HARVEST/Yuan PR.
- somatic 13쌍·29잡은 QC·채점까지 완료했으므로 같은 배치를 재제출하지 않는다. bioinfo-agent 범용 개발은 별도이며 기본 GIAB 완료 조건이 아니다.

현재 결과는 [STATUS](STATUS.md), 기존 #8·#9·#10 설계는 [이전 백로그](reference/2026-09-25-backlog-before-scope-reset.md)에 있다.
