# caller 차집합 · 통합 MultiQC · dup 런 · 대조군 caller (2026-09-23)

사용자가 "ONT 에 돌려야 할 기초 분석·처리가 있으면 알아서 qsub 으로" 라고 해서 서버 상태부터 봤다.
ONT 는 **아무것도 안 돌고 있었고** 기본 15런은 파이프라인·채점이 다 끝나 있었다.

## 1. caller 차집합

2026-09-22 에 "미확인" 으로 남긴 의심: 구간 밖에서 DV 가 진짜 변이를 버리는가. 근거는 두 caller 의
구간 밖 **순 차이** ts/tv 2.18 이었다. 순 차이는 "DV 가 버린 집합" 이 아니라서 `63_caller_diff_regions.sh`
를 새로 써 차집합을 직접 셌다.

```bash
bash phase2_ont/scripts/63_caller_diff_regions.sh          # 잡 156585, exit 0, 63s, 120 MB
#    교차 대조: Clair3 4,555,317 (62 실측 4,562,462, 0.16%) / DV 4,468,046 (4,476,450, 0.19%)
bash phase2_ont/scripts/63_caller_diff_regions.sh --show
```

**결과: 의심의 근거가 부산물이었다.** 구간 밖 Clair3 단독 0.87, DV 단독 0.67, 공유 1.31. 2.18 은 두 단독
집합의 차(2.16)로 재현된다. **질문 자체는 안 닫혔다** — 이 ts/tv 로 단독 콜을 FP 로 분류할 수 없다.
해석은 [reference §5](../reference/2026-09-22-ont-r10-benchmark.md).

htslib 이 `The index file is older than the data file` 경고를 냈다(Clair3 VCF 의 .tbi). mtime 순서
경고일 뿐이다 — 교차 대조가 62 실측과 0.2% 안에서 맞았다.

## 2. 통합 MultiQC 갱신

`$RUN_BASE/multiqc/_all_ont` 가 **8월 27일 판(13런)** 이었다. `36_multiqc_all.sh` 는 `included_runs.txt` 를
**먼저 비우고** multiqc 를 돈다 — 중간에 죽으면 목록·리포트가 어긋난다. 스크립트는 안 고치고 잡으로 감싸
새 디렉토리에 만든 뒤 교체했다.

```bash
# 잡 156586 — exit 0, 40s, 810 MB  ->  _all_ont (15 runs) / _all_ont.prev.20260923.156586 (옛 판, 보존)
```

## 3. HG002 dup 런

```bash
DUP_OK=1 bash phase2_ont/scripts/10_submit.sh HG002.guppy-V3.2.4_2020-01-22   # 156587, running
DUP_OK=1 bash phase2_ont/scripts/10_submit.sh HG002.guppy-V2.3.4_2019-06-26   # 156588 -> 취소
qdel 156588                                                                    # 시작 전 (qacct 기록 없음)
```

**V2.3.4 를 취소한 이유.** run_table 의 note 에 "HG001 오라벨 플로우셀 3개(FAH71622/FAH86841/FAH87405)가 섞여
있다 — 돌릴 거면 먼저 걸러야 한다" 가 있었다. dataset·entry·모델·크기 열만 보고 note 를 안 읽었다.
PR #39 Codex 리뷰가 잡았다.

**나머지가 깨끗한지 검증** (잡 156593, 2분). GIAB `mis-labeled-sample_run-ids.txt` 의 run_id 26개를 세 릴리스의
sequencing_summary run_id 와 대조:

| 릴리스 | run_id | 오라벨 |
|---|---:|---:|
| V2.3.4 (양성 대조) | 463 | 26 |
| V3.4.5 (이미 채점) | 437 | 0 |
| V3.2.4 (156587) | 437 | 0 |

**채점 이어 붙이기.** `qsub -hold_jid` 사슬은 못 만든다 — `qconf -ss` 가 로그인 노드(`nbbcluster2`)만
submit host 로 낸다. 로그인 노드에 감시 스크립트를 띄웠다:

```
$INFRA/jobs/dup_bench_poller.sh   PID 2550447 (setsid 로 세션에서 떼어 냄 — 세션 종료 뒤에도 살아 있음을 확인)
$INFRA/logs/dup_bench_poller.log
```

30분마다 `qstat -j <jobid>` 한 번. 파이프라인이 큐에서 빠지면 `DUP_OK=1` 로 60·61 을 넣는다. 72시간 뒤
스스로 끝난다. V2.3.4 는 취소됐으니 60·61 이 VCF 가 없어 SKIP 한다(무해). 관리자가 로그인 노드 프로세스를
정리하면 자동 제출이 안 되는데, 그때는 손으로:

```bash
DUP_OK=1 bash phase2_ont/scripts/60_benchmark.sh HG002.guppy-V3.2.4_2020-01-22
DUP_OK=1 bash phase2_ont/scripts/61_benchmark_sv.sh HG002.guppy-V3.2.4_2020-01-22
```

## 4. 외부 대조군 caller 확정

서버 없이 공개 버킷에서. ONT 의 `happy_GIABv4.2.1.summary.csv`(965 B)와 `happy_GIABv4.2.1.vcf.gz` 첫 BGZF 블록
(64 KB, 전체 99 MB)만 받았다. FILTER 설명 문구가 Clair3 `shared/utils.py` 와 일치하고 DeepVariant 와는 다르다.
[reference §1](../reference/2026-09-22-ont-r10-benchmark.md).

## 서버 접속

상태 확인 · 제출 · 감시 스크립트 기동 · V2.3.4 취소와 오라벨 검증으로 로그인 노드 세션을 여러 번 열었다.
사용자가 자리를 비우며 "서버 로그인을 자주 남기지 말라" 고 해서, 마지막 검증은 잡을 제출하고 **같은 세션에서
끝날 때까지 기다려** 한 번으로 끝냈다.
