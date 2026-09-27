# 남은 일과 보류한 일

[SCOPE](SCOPE.md)가 완료 기준이다. Codex 한 담당이 시점·실행을 관리한다.

| 순서 | 남은 일 | 완료 기준 |
|---|---|---|
| 1 | Illumina Manta 2차 156827–156829 회수 | 종료코드·SV 출력 QC 확인. 이번 승인 이후 각 2/2회째이므로 실패해도 재제출 없음 |
| 2 | 공개 기본 4잡 확인 | 종료·산출물·최소 QC 확인 후 필요한 기존 비교 |
| 3 | 업체 롱리드 수령 뒤 기존 pipeline/QC/truth 비교 | 현재 수령 대기 |

**남은 오류:** 공개 Illumina HG002/3/4 Manta. 1차의 `GenerateSVCandidates`가 signal 11로 종료했다. 2차 결과까지 확인한 뒤 원인·다음 판단을 보고한다. Verify 세 건은 성공해 정식 QC에 반영했으며 재실행하지 않는다.

완료: 회사 기본 24샘플·Verify QC 24/24(실패 11건 모두 복구), Illumina Verify 3/3, 비교 16건, BioSkryb 수령·검증·카탈로그 반영, fastp 보고서 복원, somatic 13쌍 QC·채점.

보류: 새 연구·caller/도구 비교·추가 truth/구간 분석·전체 구조 통일, 추가 20 set 일괄 제출, 반복 리뷰·새 Claude 위임·중복 타이머·신규 release 전수 추적·자동 HARVEST/Yuan PR. 범용 bioinfo 개발은 별도다.
