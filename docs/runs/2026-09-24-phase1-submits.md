# 2026-09-24 새벽 — phase1 제출 기록

서버 `~/GIAB_benchmarking` 에서. 로그인은 확인·제출을 묶어 03:00 · 03:17 · 03:40 세 번.

| 시각 | jobid | 무엇 | 명령 (요지) |
|---|---|---|---|
| 03:01 | 156649~156666 | 구간별 hap.py 나머지 18런 (시험 156590 이 48.8 GB·60분 → 3잡/노드 21슬롯으로 넣고 곧바로 `qalter -pe pe_slots 16`) | `STRAT=1 BENCH_STRAT_SLOTS=21 60_benchmark.sh --ready` |
| 03:17 | 156667 · 156668 | HG008T-p21 · p41 파이프라인 (PR #53 등록분) | `10_submit.sh HG008T-p21.HG008-T_bulk HG008T-p41.HG008-T_bulk` |
| 03:17 | — | 카탈로그 NIST 9행 갱신 — 서버 별도 worktree 에서 돌려 브랜치 push → PR #54 | `50_update_catalog.py` (python3, openpyxl 3.1.5) |
| 03:40 | 156669~156673 | HG002 5런 v5.0q 층화 채점 (PR #55) | `BENCH_TRUTH_VER=v5.0q BENCH_STRAT_TSV=$INFRA/reference/v5q_strata/strata.tsv 60_benchmark.sh --ready` |

- 층 파일은 ONT 세션이 09-23 23:26 에 만든 것(`64_v5q_strata.py`) 그대로다.
- 서버 conda env(`nfcore312`) python 에는 openpyxl 이 없다. 카탈로그 갱신은 시스템 `python3`(3.14.6)로 돌렸다.
- 쓰고 버린 서버 worktree 두 개(`~/giab_wt_cat`, `~/giab_wt_cat2`)와 로컬 브랜치는 지웠다.

## 이후 (같은 날)

| 시각 | jobid | 무엇 | 결과 |
|---|---|---|---|
| 03:55 | (qalter) | p21·p41 `-p -100`, v5.0q 5잡 `-pe pe_slots 4` (스레드=NSLOTS 라 안전) | 5잡이 숏리드 잡 옆 노드별 빈 4슬롯에서 바로 떴다 |
| 06:51 | 156674~156684 | 대기 층화 11잡을 qdel 후 `BENCH_STRAT_THREADS=4 BENCH_STRAT_SLOTS=4` 로 재제출 (16스레드 고정이라 qalter 로는 못 줄인다) | 45~80분 · 14.1~14.6 GB, 전부 exit 0 |
| 15:47 | 156686 | p21·p41 뒤 verify + QC + MultiQC (`qsub_task.sh -w 156667,156668`) | 22:0x exit 0, verify 49/49 |
| 22:10 | — | 카탈로그 UMD 2행 — 서버 worktree 에서 갱신 → 브랜치 push → #63 | 엑셀 바뀐 행 = 2 |

p21 156667: 5.7h · 54.3 GB. p41 156668: 5.2h · 51.7 GB. 둘 다 shepherd-1-8.

