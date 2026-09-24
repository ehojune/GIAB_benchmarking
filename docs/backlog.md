# 남은 일과 보류한 일

[SCOPE](SCOPE.md)가 완료 기준이다. 아래 순서로 필요한 기본 작업을 닫는다. 이미 있는 결과를 더 깊게 설명하려고 새 과제를 만들지 않는다.

| 순서 | 남은 일 | 완료 표시 |
|---|---|---|
| 1 | 회사 gd1~4 숏리드와 완료된 공개 NovaSeq6000 trio·NovaSeqX HG002의 VCF/조건 확인 → 기존 hap.py/v4.2.1 비교 | 샘플별 SNP·INDEL precision/recall/F1와 간단 QC 표 |
| 2 | 유지한 GIAB 기본 잡 완료 확인. 고정 카탈로그에서 미처리 기본 run만 식별 | 산출물·완료 로그·QC 또는 `gap` 사유. 추가 20 set을 무조건 한꺼번에 제출하지 않음 |
| 3 | 다운로드 목록과 기존 checksum 결과의 잔여 표시 정리 | `PASS`/실패/`NOREF` 구분. 실제 필요한 입력의 실패만 복구 |
| 4 | 업체 롱리드 수령 뒤 같은 플랫폼의 기존 pipeline/QC/truth 비교 적용 | 현재는 **수령 대기**; GIAB 자료와 업체 자료를 혼동하지 않음 |

## 보류 — 자동으로 다시 시작하지 않음

- GIAB HG008/HG009 somatic 통합·pilot·전장 배치, 추가 truth/구간 연구, 동일 원본 중복 run, phase 간 구조 통일.
- 반복 PR 리뷰, 새 에이전트 위임, 상시 감시, 신규 release 전수 추적, 자동 HARVEST/Yuan PR.
- PR #68·#69는 draft로 보류하고 미커밋 ONT 해석 문서는 보존. 다음 실행의 필수 조건으로 만들지 않음.

bioinfo-agent 범용 개발은 별도 계속 진행한다. 이 개발·검증·vendor 완료를 GIAB 기본 작업의 의존성으로 걸지 않는다.

기존 #8·#9·#10 설계와 상세는 [조정 전 백로그](reference/2026-09-25-backlog-before-scope-reset.md)에 보존했다. 옛 문서의 “QC만은 기각”, “somatic까지 해야 최종”은 09-25 지시로 대체됐다.
