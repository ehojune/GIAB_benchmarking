# 2026-09-23 — fetch_all.sh 완료 판정 정책과 스모크 결과 (#37)

`fetch_all.sh`는 네 취득 경로를 묶는 진입점이라, 하위 스크립트가 실패를 삼켜도 여기서 잡아야 한다.
`run_priority.sh`/`download.sh`는 개별 파일 실패를 rc로 올리지 않고(의도된 설계 — 한 파일 때문에 12 TiB 다운로드를 멈추지 않는다),
`verify.sh`도 미완료여도 rc 0이다. 그래서 진입점이 직접 판정한다. Codex 리뷰 2라운드(#37)에서 정해진 규칙:

| 규칙 | 이유 |
|---|---|
| phase0 완료 = 검증기 rc 0 **AND** 검증 로그 `TOTAL` 줄의 `done == total` (파일 수) | 퍼센트는 바이트 기준 소수 1자리라 0.05% 미만 결손(0바이트 파일 포함)이 `100.0%`로 찍힌다 |
| 다운로드 뒤 검증은 **항상 `all`** | `PHASE0_VERIFY_CAT`으로 좁힌 부분 검증이 통과해도 나머지 카테고리는 모른다. 그 변수는 `VERIFY_ONLY=1` 스모크 전용 |
| 검증 출력은 `phase0.verify.log`에 **격리** | `run_priority.sh`도 카테고리마다 `TOTAL`을 찍는다. 같은 파일의 마지막 `TOTAL`을 집으면 "마지막 카테고리만 완료"를 전체 완료로 오판한다 |
| 로그는 실행마다 새로 쓴다; phase0이 이번 실행에 없으면 phase0 로그를 읽지 않는다 | 옛 진행률이 이번 판정에 섞이지 않게 |
| `STAGES` 오타·스크립트 부재는 `FAIL(unknown)`/`FAIL(missing)` | `SKIP`으로 성공 집계되면 그 출처가 통째로 빠진다 |

## 스모크 (데이터 없는 개발 머신, `GIAB_ROOT=/tmp/giab_nonexistent`)

| # | 명령 | 기대 | 결과 |
|---|---|---|---|
| S1 | `VERIFY_ONLY=1 PHASE0_VERIFY_CAT=trio_analysis fetch_all.sh` | rc 1, phase0 행 `FAIL(incomplete)`, `phase0.verify.log` 생성 | 통과 |
| S2 | `phase0.log`에 가짜 `TOTAL 415/415 (100.0%)`를 심고 검증만 실행 | 검증 로그만 보므로 여전히 `FAIL(incomplete)`, rc 1 | 통과 |
| S3 | `STAGES="phaes2"` | `FAIL(unknown)`, rc 1 | 통과 |
| S4 | `STAGES=phase3` | phase0 문구 0줄 | 통과 |
| U | `phase0_complete` 단위: `76595/76595`→complete, `81301/81302`→INCOMPLETE, TOTAL 없음→INCOMPLETE | — | 통과 |

서버에서의 실제 다운로드 모드 실행은 데이터가 이미 100%라 `run_priority.sh`가 전건 스킵 → `verify.sh all` → `done==total`로 OK가 나와야 한다. 다음 실행 때 이 문서에 결과를 덧붙인다.
