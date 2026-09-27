# 남은 일과 보류한 일

[SCOPE](SCOPE.md)가 완료 기준이다. Codex 한 담당이 시점·실행을 관리한다.

| 순서 | 남은 일 | 완료 기준 |
|---|---|---|
| 1 | gd4 비교 156815–156817, QC 복구 156818–156820 회수 | 비교 3건 exit 0·summary 확인. QC 3건은 exit 0·검증 후 QC 파일만 반영 |
| 2 | 공개 기본 4잡 확인 | 종료·산출물·최소 QC. 회사 기본 run은 모두 종료 |
| 3 | 업체 롱리드 수령 뒤 기존 pipeline/QC/truth 비교 | 현재 수령 대기 |

**QC gap:** gd3 KOR-101은 1스레드에서도 SIGSEGV. 추가 반복 없이 오류 근거·기존 결과를 보존한다. HG002/3/4 비교와 별개다. Illumina 기존 gap도 유지한다.

완료: 비교 13건, gd1~3 QC 복구 7건, BioSkryb×UG100 수령·검증·카탈로그 반영, fastp 보고서 복원, somatic 13쌍 QC·채점.

보류: 새 연구·caller/도구 비교·추가 truth/구간 분석·전체 구조 통일, 추가 20 set 일괄 제출, 반복 리뷰·새 Claude 위임·중복 타이머·신규 release 전수 추적·자동 HARVEST/Yuan PR. 범용 bioinfo 개발은 별도다.
