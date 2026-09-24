# docs/reference — 조회용

**조회용 보관소다.** 매번 읽지 말고 필요한 근거만 찾는다. 옛 문서의 작업 지시는 현재 [SCOPE](../SCOPE.md)를 덮어쓰지 않는다.

| 문서 | 내용 |
|---|---|
| [조정 전 STATUS](2026-09-25-status-before-scope-reset.md) | 09-25 이전 현황과 전체 이력 보존. 현재 큐가 아님 |
| [조정 전 backlog](2026-09-25-backlog-before-scope-reset.md) | #8·#9·#10 설계와 당시 판단. 재개 목록이 아님 |
| [server-and-infra.md](server-and-infra.md) | nbb2 클러스터의 안 변하는 사실(노드 스펙·GPU 없음), `_infra` 에 미리 받아 둔 실행 자산(레퍼런스·clair3 모델·컨테이너 16개), 매니페스트 밖에서 받은 것, 자주 쓰는 점검 명령 |
| [2026-09-24-phase1-tstv-regions-and-strat.md](2026-09-24-phase1-tstv-regions-and-strat.md) | phase1 ts/tv 구간 분할 19런, 구간별 hap.py(시험 1런 → 18런 추가 예정), QC 재판정 — 거짓 경고 39건의 원인 둘 |
| [catalog_evidence.md](catalog_evidence.md) | master_catalog.tsv의 각 값이 정해진 근거, 검증에서 잡힌 오류, 인용한 GIAB 공식 문서 목록 |
| [2026-08-27-ont-qc-first-pass.md](2026-08-27-ont-qc-first-pass.md) | ONT 첫 완주 13런 QC 실측표 + 임계값 조정 근거. 염기 매핑률 전환, DV RefCall 1.7~3.4배, R9 indel의 베이스콜러 의존 |
| [ont_pipeline_choice.md](ont_pipeline_choice.md) | phase2(ONT)에서 nf-core/nanoseq를 안 쓴 이유, Clair3·DeepVariant 모델 가용성, HG001 리드 출처, 컨테이너 핀 확인 결과 |
| [phase3_shortread_candidates_2026-09-17.md](phase3_shortread_candidates_2026-09-17.md) | HG002/3/4 숏리드 raw FASTQ 전수(GIAB FTP 안·밖), 리드 길이·깊이 실측, 외부 2종 다운로드 전 검증값, Codex·Gemini 자문 기록 |

플랫폼 디렉토리 단위 정확 바이트는 상위 [docs/SIZES.md](../SIZES.md)에 있다.
