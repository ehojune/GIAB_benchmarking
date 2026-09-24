# v5.0q smvar 층화 채점 — HG002 R10 (2026-09-24)

#43 머지 뒤 로그인 노드 세션 **한 번**에 층 생성 → 제출 → 끝날 때까지 대기 → 수집을 했다(사용자가 자리를 비우며
서버 로그인을 자주 남기지 말라고 해서). 해석은 [reference](../reference/2026-09-24-ont-r10-v5q-stratified.md).

```bash
V5=$GIAB_ROOT/release/AshkenazimTrio/HG002_NA24385_son/v5.0q/HG002_GRCh38_v5.0q_smvar.benchmark.bed
V4=$GIAB_ROOT/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed
python phase2_ont/scripts/64_v5q_strata.py "$V5" "$V4" "$INFRA/reference/v5q_strata"
#   v5.0q 2,739,407,815 bp / v4.2.1 2,542,242,843 bp (염색체 22개)
#   겹침 2,496,207,096 (91.1%) / v5.0q에만 83,105,444 (3.0%) / 다른 염색체 160,095,275 (chrX, chrY)
#   v4.2.1에만 46,035,747 (안 셈)

BENCH_TRUTH_VER=v5.0q BENCH_STRAT_TSV="$INFRA/reference/v5q_strata/strata.tsv" \
  bash phase2_ont/scripts/60_benchmark.sh HG002.ONT-R10_giab2025.01_PAW70337
#   OK jobid=156640 callers: clair3 deepvariant truth=HG002_GRCh38_v5.0q_smvar.vcf.gz
#   대기 54분(큐 포함) -> exit 0, ru_wallclock 2326s(38.8분), maxvmem 25.139GB, shepherd-1-8

BENCH_TRUTH_VER=v5.0q bash phase2_ont/scripts/60_benchmark.sh --collect          # 8 rows
BENCH_TRUTH_VER=v5.0q bash phase2_ont/scripts/60_benchmark.sh --collect-strata   # 24 rows
```

**v5.0q 는 chrY 까지 담는다.** 64 가 "다른 염색체" 로 `chrX, chrY` 를 냈다. 64 를 자체 리뷰할 때 이 층을 따로 떼지
않았다면 160 Mb 가 "v4.2.1 밖" 83 Mb 보다 두 배 크게 섞였을 것이다.

**자원:** 층 3개를 붙인 hap.py 가 층 없는 v4.2.1 채점(50.7분 / 24.6 GB)과 메모리가 거의 같다. 층이 적으면 층화
비용은 무시할 만하다(PacBio 의 25층 층화는 아직 실측 전).

Codex 리뷰는 사용량 한도(2026-09-24 02:48 재개)로 #43 코드 PR 에서 못 받았다. 이 결과 PR 에서도 같다.

## R9 두 런 (같은 날, 로그인 한 번)

```bash
for d in HG002.guppy-V3.4.5 HG002.UCSC_Ultralong_OxfordNanopore_Promethion; do
  BENCH_TRUTH_VER=v5.0q BENCH_STRAT_TSV="$INFRA/reference/v5q_strata/strata.tsv" \
    bash phase2_ont/scripts/60_benchmark.sh "$d"
done
#   156642 (guppy-V3.4.5), 156643 (UCSC) — 대기 23분 뒤 수집
#   156643: exit 0, ru_wallclock 1293s, maxvmem 25.058GB
#   156642: 수집 시점에 qacct 가 비어 있었다(회계 기록 지연). 층 행은 나왔다
BENCH_TRUTH_VER=v5.0q bash phase2_ont/scripts/60_benchmark.sh --collect-strata   # 48 rows (R10 포함)
```

층은 R10 채점 때 만든 `$INFRA/reference/v5q_strata/` 를 그대로 썼다(같은 HG002 BED). 해석은
[reference §6](../reference/2026-09-24-ont-r10-v5q-stratified.md#6-r9-두-런을-같은-층으로--옛-베이스콜러는-어려운-영역에서-더-무너진다).

## V3.2.4 dup 런도 같은 층으로 — 두 번째 감시 스크립트 (00:58)

V3.2.4(156587)가 V3.4.5·UCSC 와 같은 층에 서면 §6 의 어려운 영역 격차를 기기와 베이스콜러로 가를 수 있다.
9/23 에 띄운 `dup_bench_poller.sh` 는 v4.2.1 채점(60·61)만 넣는다. **도는 스크립트는 고치지 않고**(HARVEST:
bash 는 실행하면서 스크립트를 읽는다) 따로 하나 띄웠다:

```
$INFRA/jobs/dup_bench_v5q_poller.sh   PID 2577074, 48시간 뒤 스스로 끝남
$INFRA/logs/dup_bench_v5q_poller.log
```

156587 이 큐에서 빠지면 한 번 넣고 끝난다. 띄울 때 156587 은 3시간째 `MINIMAP2_ALIGN`. 프로세스가 정리돼 있으면 손으로:

```bash
BENCH_TRUTH_VER=v5.0q BENCH_STRAT_TSV="$INFRA/reference/v5q_strata/strata.tsv" DUP_OK=1 bash phase2_ont/scripts/60_benchmark.sh HG002.guppy-V3.2.4_2020-01-22
```
