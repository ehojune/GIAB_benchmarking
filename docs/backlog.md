# 남은 일과 보류한 일

[SCOPE](SCOPE.md)가 완료 기준이다. 아래 순서로 필요한 기본 작업을 닫는다. 이미 있는 결과를 더 깊게 설명하려고 새 과제를 만들지 않는다.

| 순서 | 남은 일 | 완료 표시 |
|---|---|---|
| 1 | 재구성한 회사 gd1~4 germline **156760–156763** 완료·간단 QC 확인 후 공개 NovaSeq6000 trio·NovaSeqX HG002와 기존 hap.py/v4.2.1 비교 | 정본 순번 1–3 KOR·4–6 HG, 새 산출물 확인, SNP·INDEL precision/recall/F1 표. 이전 업체 결과·비교 캐시 재사용 금지 |
| 2 | GIAB 기본 잡 5개 유지. HG002 QC 복구 **156781** 결과 확인. HG002/3 Manta는 미해결로 남김 | [QC 복구](runs/2026-09-25-illumina-hg002-verifybamid-retry.md)의 산출물·종료코드·입력 불변 확인 후 반영. [Manta 재시도도 실패](runs/2026-09-25-illumina-hg003-manta-retry.md): 같은 실행 반복 금지. 20 set 일괄 제출 금지 |
| 3 | 가벼운 정리 3건 완료: PacBio 요약, ONT 비교 정리, 다운로드 집계 | [STATUS의 결과 링크](STATUS.md) 참조. 담당 브랜치 완료이며 main 미통합. checksum은 활성 목록/과거분과 `NOREF`를 구분 |
| 4 | 업체 롱리드 수령 뒤 같은 플랫폼의 기존 pipeline/QC/truth 비교 적용 | 현재는 **수령 대기**; GIAB 자료와 업체 자료를 혼동하지 않음 |

## 보류 — 자동으로 다시 시작하지 않음

- 추가 truth/구간·원인 연구, 동일 원본 중복 run, phase 간 구조 통일. somatic은 이미 승인·제출한 범위만 진행.
- 반복 PR 리뷰, 새 에이전트 위임, 기존 Claude 타이머·상시 polling, 신규 release 전수 추적, 자동 HARVEST/Yuan PR.
- PR #68·#69의 merge는 보류. 완료한 정리를 다시 실행하거나 새 리뷰를 반복하지 않음.

**Codex 단일 담당의 4시간 점검·보고와 승인 범위의 후속 작업은 진행한다.** somatic 13쌍은 QC·채점까지 완료했으므로 다시 제출하지 않는다.

bioinfo-agent 범용 개발은 별도 계속 진행한다. 이 개발·검증·vendor 완료를 GIAB 기본 작업의 의존성으로 걸지 않는다.

기존 #8·#9·#10 설계와 상세는 [조정 전 백로그](reference/2026-09-25-backlog-before-scope-reset.md)에 보존했다. 옛 문서의 “QC만은 기각”, “somatic까지 해야 최종”은 09-25 지시로 대체됐다.
