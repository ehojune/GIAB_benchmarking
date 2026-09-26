# 남은 일과 보류한 일

[SCOPE](SCOPE.md)가 완료 기준이다. Codex 한 담당이 비교 시점·실행을 관리한다.

| 순서 | 남은 일 | 완료 표시 |
|---|---|---|
| 1 | **fastp 복원 156796/156797** 종료·RESTORED.json·12샘플 리드 수 검증. **Verify 단독 156798** exit 0·VERIFIED.json 확인 후 나머지 5샘플 적용 | CRAM/gVCF·원자료 보존. pilot 실패 시 로그를 남기고 전체 재실행으로 우회하지 않음. [실행·검증 기준](runs/2026-09-26-verify-only-pilot.md) |
| 2 | gd1/4·공개 기본 4잡 유지. gd2를 포함한 나머지 회사 비교 9건은 복구·최소 QC 뒤 진행 | 기존 비교 7건 qacct·ALL DONE·summary 완료 확인. gd3 HG002 QC gap 명시. Illumina 156786의 기존 gap 유지, 추가 20 set 일괄 제출 금지 |
| 3 | BioSkryb×UG100 수령·크기·제공 MD5 검증 마무리 | 현재 61.23% 수령. 완료 뒤 카탈로그·Excel 갱신. 가벼운 정리 3건은 완료 유지; **PR #68·#69 미통합·병합 보류** |
| 4 | 업체 롱리드 수령 뒤 기존 pipeline/QC/truth 비교 | 현재 **수령 대기**. GIAB 자료와 업체 자료를 구분 |

## 보류 — 자동으로 다시 시작하지 않음

- 추가 truth/구간·원인 연구, caller·도구 비교, 동일 원본 중복 run, 전체 구조 통일.
- 반복 PR 리뷰, 새 Claude 위임·타이머·상시 polling, 신규 release 전수 추적, 자동 HARVEST/Yuan PR.
- somatic 13쌍·29잡은 QC·채점까지 완료했으므로 같은 배치를 재제출하지 않는다. bioinfo-agent 범용 개발은 별도이며 기본 GIAB 완료 조건이 아니다.

현재 결과는 [STATUS](STATUS.md), 기존 #8·#9·#10 설계는 [이전 백로그](reference/2026-09-25-backlog-before-scope-reset.md)에 있다.
