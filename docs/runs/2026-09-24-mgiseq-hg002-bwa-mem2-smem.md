# 2026-09-24 — MGISEQ HG002: bwa-mem2 SMEM 버퍼 초과를 입력 순서로 피한다

phase3 1차 MGISEQ2000-PCRfree set의 HG002만 정렬 BAM이 33% 잘려 있었다(09-21 발견). 파이프라인이 bwa 실패를 삼켜 `Finished`로 넘겼기
때문이다. 결론부터: **원인은 bwa-mem2 2.2.1의 SMEM 버퍼 한도**, 해법은 **리드를 하나도 버리지 않고 입력 순서만 바꿔** 밀집 구역을 흩는 것.
모든 잡은 nbb2 `octopus-2-10`, 결과 dir은 `/BiO/scratch/ehojune/GIAB_benchmark/repairs/`.

## 잡과 결과

| 잡 | 무엇 | 결과 |
|---|---|---|
| (09-21 원본 파이프라인) | fastp → bwa-mem2 → 정렬 | SAM 948,868,188번째 줄에서 끊김, 파이프라인은 `Finished` |
| 155525 | Codex 복구 스크립트 `mgi_hg002_recheck.sh --rebuild` | exit 1, samtools "Parse error" — bwa가 쓰다 죽은 결과 |
| 156584 | 같은 스크립트 재시도 | **bwa-mem2 SIGSEGV(139)**. 처리 리드 946,145,492 — 155525와 **한 리드도 안 틀리게 같다** |
| 156641 | `05_bwa_crash_bisect.sh` | 죽은 청크(333,582쌍)만으로 재현. avx512bw·avx2·sse42 **셋 다** 죽음. 651쌍 창까지 좁혀지고 반쪽은 안 죽음 |
| 156645 | 05 2단계(블록 빼기) | 앞 528쌍 어느 블록을 빼도 안 죽음 — 한 리드가 아니라 배치 구성 문제. (이상 리드 "0건"은 awk 오류로 검사가 안 돈 것 — 정정됨) |
| 156644 | `06_bwa_tail_check.sh` 창 제외 | 651쌍을 빼도 첫 배치에서 또 죽음 → 리드 빼기는 해법 아님 |
| 156646 | `07_bwa_reorder_check.sh` L04→L03 | 죽음(134) — 단언문이 원인을 밝힘: `num_smem: 1623546`, `Assertion 'num_smem < *wsize_mem' failed` |
| (로그인 노드) | 창 651쌍 반복도 훑기 | **150 bp 전부 T인 리드**가 창에 있고 같은 청크 대조 창 둘엔 0 |
| 156647 | `interleave_shards.py` K=4 | 병합 입력(L03+L04)을 4구간 교차로 다시 씀, 84분, exit 0 |
| 156648 | `08_rebuild_sorted_bam.sh` | fastp before 1,451,463,284 → after 1,428,410,152(원래와 **같다**). **bwa-mem2 끝까지 통과**: 2,141 청크 · 1,428,410,152 리드, primary 1,428,410,152 = fastp 출력(07:22). bwa 30스레드 약 2시간. 정렬 중(07:22~) → `VALIDATED.txt` |

## 원인

bwa-mem2는 스레드 배치마다 SMEM 버퍼(`wsize_mem`)를 배치의 **총 염기 수**로 잡는다. 게놈 곳곳의 poly-A/T 구간과 맞는 poly-T 리드는
염기 수보다 훨씬 많은 SMEM을 만들고, 그런 리드가 몰린 배치는 버퍼를 넘친다. 단언이 켜진 경로에선 abort(134), 아니면 조용히 넘쳐
segfault(139). 배치 경계(`-K 100000000`, 염기 수 기준)와 스레드 배치가 결정적이라 같은 입력은 매번 같은 곳에서 죽고, 리드 몇 쌍을
빼거나 레인 순서만 바꾸면 배치가 조금 달라질 뿐 밀집 구역은 그대로라 또 죽는다. 최신 master도 같은 검사를 두고 넘치면
`Error [bug]: num_smem ... more than allocated space`로 멈춘다(재할당 안 함) — 빌드를 바꿔도 안 풀린다.
fastp `--trim_poly_g`는 poly-T를 안 건드린다.

## 해법과 검증

병합 입력을 연속 4구간으로 나눠 한 레코드씩 돌아가며 내보내면 밀집 구역의 리드가 배치마다 1/4로 흩어진다. 리드 손실 0, R1/R2 같은
순서. 검증은 파이프라인과 같은 fastp·bwa-mem2 인자로 끝까지 돌리고 primary 리드 수를 fastp 출력과 대조했다.

## 사용자가 할 일 (둘 중 하나)

- **(a) 권장 — 정렬 BAM 교체 후 set 재개.** 파이프라인 입력은 그대로 두고, 검증된 BAM을 `tmp/04.sort`에 넣는다(옛 것은 옆에 보관):
  ```bash
  S=GIAB-publicData-MGISEQ2000-PCRfree-HG002; R=/BiO/scratch/ehojune/GIAB_benchmark/repairs/mgi-hg002-shard4-rebuild
  bash ~/GIAB_benchmarking/phase3_shortread_wgs/scripts/09_swap_sorted_bam.sh $R/VALIDATED.txt /BiO/scratch/dyl/kbb/G000/GIAB-publicData-MGISEQ2000-PCRfree $S          # 계획
  APPLY=1 bash ~/GIAB_benchmarking/phase3_shortread_wgs/scripts/09_swap_sorted_bam.sh $R/VALIDATED.txt /BiO/scratch/dyl/kbb/G000/GIAB-publicData-MGISEQ2000-PCRfree $S
  ```
  그 뒤 MGISEQ set을 1차 다른 set과 같은 Java 17 래퍼로 다시 돌린다(HG003/4는 markdup부터, HG002는 교체한 정렬 BAM부터).
- (b) 파이프라인 입력 자체를 4구간 순서(`repairs/mgi-hg002-shard4/in_{1,2}.fastq.gz`)로 바꾸고 HG002를 처음부터 다시 돌린다 — 같은
  도구·인자라 결정적으로 통과하지만, 03의 병합 크기 검사와 어긋나(재압축으로 크기가 다르다) 03을 다시 돌리면 L03+L04로 되돌리려 한다.
  (a)가 간단하다.

**다른 MGI/BGI 샘플도 같은 일이 생길 수 있다**(2차의 BGISEQ500·MGISEQ·NIST-BGIseq 등). 파이프라인이 bwa 실패를 삼키므로 set이
끝나면 [server-and-infra.md](../reference/server-and-infra.md)의 정렬 BAM 완전성 검사(1단계 idxstats)를 꼭 돌릴 것 — 그 명령은
`GIAB-publicData-*` 전부를 본다. 잘렸으면 이 문서의 순서를 그 샘플에 그대로 쓴다: 파이프라인 입력을 `interleave_shards.py`로 교차
(레코드 수 = fastp before_filtering ÷ 2) → `08_rebuild_sorted_bam.sh` → `09_swap_sorted_bam.sh`. 156647이 쓴 잡 스크립트는 서버
`repairs/mgi-hg002-shard4.job.sh`(R1·R2를 동시에 `interleave_shards.py ... 725731642 4 | pigz -p 8`, 32슬롯).
