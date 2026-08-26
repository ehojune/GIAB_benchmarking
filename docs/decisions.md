# 결정 기록

## 2026-08-26 — 처리표 원문 전체 표시와 현재 평가 기준

- 이전의 “tool만 전체 표시, 다른 축약 유지” 결정을 폐기했다.
- 플랫폼·리드 포맷·모든 tool·`next_step`은 자수 제한 없이 TSV 원문 전체를 표시한다.
- 상태 필드는 `TRUE/FALSE/N/A/-`만 허용한다. 편집 메모가 섞인 7건은 실제 상태로 복구했다.
- HG008은 somatic small variant V0.3과 SV/CNV V0.5를 현행 기준으로 삼고, HG009는 공식 benchmark가 아직 없다고 적는다.
- 근거는 [reference/2026-08-26-hg008-benchmark-refresh.md](reference/2026-08-26-hg008-benchmark-refresh.md)에 뒀다.
- 엑셀 파일명과 내부 버전 `0826`은 유지하고 `Master Catalog`를 최신 TSV와 맞춘다.

## 2026-08-23 — Yuan 최소 준수 retrofit

- 기존 활성 구조와 `HARVEST.md`는 그대로 두고 MVR 파일과 Journal만 추가했다.
- 전체 템플릿 스탬프와 README 재구성은 현재 작업을 흔들 수 있어 하지 않았다.
- GIAB 원본 데이터는 이 기계의 D:·E:에서 확인되지 않았다. NBB 실행 경로는 문서에 있으나 실제 보관 위치는 재실행 전에 확인한다.
