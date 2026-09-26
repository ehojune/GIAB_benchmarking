# 남은 일과 보류한 일

[SCOPE](SCOPE.md)가 완료 기준이다. Codex 한 담당이 비교 시점·실행을 관리한다.

| 순서 | 남은 일 | 완료 표시 |
|---|---|---|
| 1 | **비교 156787–156793**(gd3 3개·공개 4개) 결과 회수. gd1/2/4 **156760/156761/156763** 종료·최소 QC 뒤 나머지 회사 비교 9건 | qacct·ALL DONE·summary를 함께 확인해 SNP/INDEL precision·recall·F1 표 작성. gd3 HG002 오염 QC gap 명시. 옛 회사 캐시 재사용 금지. [실행 기록](runs/2026-09-26-gd3-qc-and-comparison.md) |
| 2 | 공개 기본 **155526–155528, 156690** 유지, 종료 후 리드 수·산출물·오류 확인 | Illumina **156786 exit 1**의 Manta 3건·HG002 verifybamID는 gap 유지. 회사별 기본 잡 종료 후 일반 regermline, 같은 단계 재실패 시 실패 중간 디렉토리만 정리 후 regermline. gd3는 비교 종료 후 재개. 강제 dry-run 253작업으로 일반 재개를 배제하지 않음. 추가 20 set 일괄 제출 금지 |
| 3 | BioSkryb×UG100 수령·크기·제공 MD5 검증 마무리 | 현재 37.37% 수령. 완료 뒤 카탈로그·Excel 갱신. 가벼운 정리 3건은 완료 유지; **PR #68·#69 미통합·병합 보류** |
| 4 | 업체 롱리드 수령 뒤 기존 pipeline/QC/truth 비교 | 현재 **수령 대기**. GIAB 자료와 업체 자료를 구분 |

## 보류 — 자동으로 다시 시작하지 않음

- 추가 truth/구간·원인 연구, caller·도구 비교, 동일 원본 중복 run, 전체 구조 통일.
- 반복 PR 리뷰, 새 Claude 위임·타이머·상시 polling, 신규 release 전수 추적, 자동 HARVEST/Yuan PR.
- somatic 13쌍·29잡은 QC·채점까지 완료했으므로 같은 배치를 재제출하지 않는다. bioinfo-agent 범용 개발은 별도이며 기본 GIAB 완료 조건이 아니다.

현재 결과는 [STATUS](STATUS.md), 기존 #8·#9·#10 설계는 [이전 백로그](reference/2026-09-25-backlog-before-scope-reset.md)에 있다.
