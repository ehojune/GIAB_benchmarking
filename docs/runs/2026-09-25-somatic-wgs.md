# 2026-09-25 — HG008 PacBio somatic SNV/INDEL 전장 실행 (DeepSomatic CPU)

사용자 지시(09-25): 준비된 HG008 PacBio tumor-normal 후보 쌍의 SNV/INDEL 전장 분석을 CPU 로 진행한다.
역할 — bioinfo-agent 는 범용 코드 수정·검증, 이 세션(GIAB PacBio, Desktop)은 GIAB 입력·버전 반영·서버 제출·결과 수집.
전장 실행 담당은 이 세션 하나다. somatic SV/CNV, HG009, 추가 caller·모델 비교는 범위 밖이다.

## 고정한 경로 하나

| | |
|---|---|
| 코드 | bioinfo-agent `pipelines/pacbio-hifi-wgs` **`f2de95e`** (브랜치 `worktree-pacbio-somatic-cpu`, 0.2.0) → GIAB `phase1_pacbio_hifi/pipeline/pacbio-hifi-wgs-somatic/` (`git archive`, 무수정, [VENDORED.md](../../phase1_pacbio_hifi/pipeline/VENDORED.md)). germline 사본은 그대로다 |
| caller·모델 | DeepSomatic 1.10.0 `--model_type=PACBIO` tumor-normal (이미지 내장 모델). tumor-only 는 파이프라인이 거부한다 |
| 컨테이너 | `google/deepsomatic:1.10.0` CPU → `$INFRA/containers/google-deepsomatic-1.10.0.img` (3.96 GB, 서버에 09-25 01:08 이미 캐시). 계산 노드 외부망·GPU 불필요 |
| reference | `$REF_FASTA` = GCA_000001405.15 GRCh38 no_alt analysis set (germline 정렬과 같다) |
| 입력 | 기존 pbmm2 정렬 BAM `02_alignedBAM/<sample>.<dataset>.GRCh38.bam` — 재정렬·새 자료 없음 |
| 제출 | GIAB `3d5cabf` 의 [`70_submit_somatic.sh`](../../phase1_pacbio_hifi/scripts/70_submit_somatic.sh) `<pair_id>` → SGE 잡 1개 = 쌍 1개, `nextflow run pacbio-hifi-wgs-somatic --somatic_input <pair.csv> --fasta $REF_FASTA --outdir $RUN_BASE --run_label som.<pair>` |
| 산출 | `$RUN_BASE/<tumor_sample>/PacBio/somatic.<pair_id>/03_VCF/deepsomatic/<tumor_sample>.somatic.<pair_id>.GRCh38.deepsomatic.vcf.gz` (+ SNV/INDEL 분리, visual report) |
| 채점 | [`62_benchmark_somatic.sh`](../../phase1_pacbio_hifi/scripts/62_benchmark_somatic.sh) — aardvark v1.0.0, truth smvar V0.3 `tumorvariants`, BED `nogermlineinterference`(기본)·`all`, query PASS + VAF ≥ 0.05, GT 0/1 통일 |

bioinfo-agent 쪽 검증(`docs/examples/20260925-pacbio-somatic-cpu-validation/handoff.md`): stub 회귀 + 음성 7건,
실데이터 HG008-T/N-P chr13:82–86 Mb 한 조각(16코어 1분 46초, peak RSS 17.8 GB, PASS 54 중 47 이 truth 와 일치).
**전장·정확도 검증은 아니다.** 4 Mb 외삽(쌍당 ~100 CPU-h)은 일정으로 쓰지 않는다.

## 후보 13쌍 검토 (서버 확인 09-25 07:30)

입력 BAM 15개 전부 파일·`.bai`·`samtools quickcheck` 통과. `@RG SM` 은 dsid 의 sample 과 같고, `@SQ` 195개 중
chr1~22·X·Y·M 25개의 이름·길이가 `$REF_FASTA.fai` 와 일치한다(md5 `75afe0a7`). 심도는 2026-09-24 QC.

| pair | tumor (심도) | normal (심도) | 관계 | tumor 배치 | truth 해석 |
|---|---|---|---|---|---|
| **T-BCM** | HG008-T BCM Revio 2024-03-13 (72x) | HG008-N-D 십이지장 정상조직, 같은 센터·날짜 (68x) | **matched** | 0823p23 = truth 배치 | recall·precision |
| **T-PB** | HG008-T PacBio Revio 2024-01-25 (79x) | HG008-N-P 췌장 정상조직, 같은 센터·날짜 (35x) | **matched** | 0823p23 | recall·precision (normal 이 얕다) |
| p21 · p41 | UMD Revio bulk (29x · 29x) | N-D 차용 | borrowed | 20240508 p21 · p41 | recall 만 |
| p100 | BCM Revio SPRQ bulk (32x) | N-D 차용 | borrowed | 20240508 p100 | recall 만 (장기 계대) |
| 2D6 · 2E6 · 3E4 | BCM Revio 클론 (31x · 38x · 47x) | N-D 차용 | borrowed | 20240718 p14 | recall 만 |
| SC6 · SC9 · SC14 · SC24 · SC28 | BCM Revio 클론 (42 · 44 · 44 · 32 · 40x) | N-D 차용 | borrowed | 20240805 p19 | recall 만 |

- truth 는 0823p23 배치 bulk 의 **truncal 변이만** 담는다. 클론·다른 계대의 고유 변이는 truth 밖이라 FP 로 잡히지만
  **오류가 아니다** — `recall_only` 쌍의 precision 은 읽지 않는다.
- 차용 normal 은 다른 준비·배치다(p21·p41 은 센터도 다르다). 두 matched 쌍과 같은 조건이 아니다.
- T-BCM 과 T-PB 의 tumor 는 SM 이 둘 다 `HG008-T` 다. 쌍마다 별도 실행·별도 산출 폴더(`somatic.<pair>`)라 충돌은 없다.

## 제출

**최종 제출 (07:42, 사용자: "휴일이라 노드를 한정하지 말고 제출해도 된다")** — 13쌍 동시, 쌍마다 노드 1대:

| jobid | pair | 노드 | jobid | pair | 노드 |
|---|---|---|---|---|---|
| 156747 | T-BCM | octopus-2-2 | 156754 | 3E4 | octopus-2-3 |
| 156748 | T-PB | octopus-2-1 | 156755 | SC6 | octopus-2-4 |
| 156749 | p21 | shepherd-1-4 | 156756 | SC9 | shepherd-1-3 |
| 156750 | p41 | octopus-2-5 | 156757 | SC14 | shepherd-1-14 |
| 156751 | p100 | shepherd-1-11 | 156758 | SC24 | shepherd-1-5 |
| 156752 | 2D6 | shepherd-1-10 | 156759 | SC28 | shepherd-1-2 |
| 156753 | 2E6 | shepherd-1-1 | | | |

```bash
SGE_HOSTS='(octopus-2-*|shepherd-1-*)' SOMATIC_SLOTS=60 SOMATIC_MEM_GB=230 SOMATIC_VMEM=240G   bash phase1_pacbio_hifi/scripts/70_submit_somatic.sh T-BCM T-PB p21 p41 p100 2D6 2E6 3E4 SC6 SC9 SC14 SC24 SC28
```

- 60 슬롯을 실제로 쓰려면 사이트 설정이 필요했다 — 파이프라인이 DEEPSOMATIC 을 `process_high` = 16 CPU 로 선언하고
  `kobic.config` 의 `resourceLimits` 는 줄이기만 한다. `conf/somatic.config`(#71)가 DEEPSOMATIC CPU 를 잡 슬롯에 맞춘다.
  파이프라인 코드는 그대로다.
- 첫 확인(07:44): 13잡 전부 `r`, DeepSomatic `--num_shards=60`, make_examples 진행 중, 로그 오류 0. 시작 직후 vmem 95~108 GB.
- 우선순위 `-p -100` 은 유지했다.

**그 전에 거둔 것.** 07:32 파일럿 T-BCM(156734)을 4슬롯으로, 07:38 나머지 12쌍을 4슬롯·HOLD 4레인(156735~156746)으로
넣었다 — 그때는 허용 4노드가 숏리드 `regermline` 으로 차 노드마다 4슬롯만 비었다. 휴일 지시를 받고 07:41 에 13잡을 모두
qdel 하고 위처럼 다시 냈다. 계산 손실은 파일럿 약 10분(4코어)뿐이고 CHECK_BAM 은 `-resume` 으로 재사용됐다.

## 156691 결과 — 채점 경로가 선다 (공개 콜셋, 새 caller 실행이 아니다)

`UCSC-DS160-HiFi-TPB` (GIAB 배포 `0201_HG008_HiFi_DeepSomatic_v1.6.0_model354_somaticOnly.vcf.gz`), BED `all`:

| | truth | TP | FN | FP | recall | precision | F1 |
|---|---:|---:|---:|---:|---:|---:|---:|
| SNV | 9,454 | 8,962 | 492 | 607 | 0.948 | 0.937 | 0.942 |
| INDEL | 8,752 | 1,792 | 6,960 | 154 | 0.205 | 0.921 | 0.335 |

우리 DeepSomatic 1.10.0 결과를 놓을 기준값이다. INDEL recall 이 낮은 이유는 이번 범위에서 파지 않는다.
산출: `$RUN_BASE/_somatic_bench/UCSC-DS160-HiFi-TPB/{all,nogermlineinterference}/summary.tsv`.

## 결과 (11:05 전부 종료, 11:08 채점·QC 수집)

13쌍 모두 exit 0. 실패·제외 없음. 채점 잡 156764–156776, QC·수집 156777(p21 재채점 156778·재수집 156779).

**실행** — 쌍마다 노드 1대, `--num_shards=60`:

| pair | 노드 | wall | maxvmem | pair | 노드 | wall | maxvmem |
|---|---|---:|---:|---|---|---:|---:|
| T-BCM | octopus-2-2 | 2.53 h | 258 GB | 3E4 | octopus-2-3 | 2.65 h | 236 GB |
| T-PB | octopus-2-1 | 2.40 h | 246 GB | SC6 | octopus-2-4 | 2.60 h | 228 GB |
| p21 | shepherd-1-4 | 3.40 h | 206 GB | SC9 | shepherd-1-3 | 2.70 h | 223 GB |
| p41 | octopus-2-5 | 3.20 h | 202 GB | SC14 | shepherd-1-14 | 2.94 h | 215 GB |
| p100 | shepherd-1-11 | 3.09 h | 204 GB | SC24 | shepherd-1-5 | 3.18 h | 200 GB |
| 2D6 | shepherd-1-10 | 2.91 h | 205 GB | SC28 | shepherd-1-2 | 3.13 h | 213 GB |
| 2E6 | shepherd-1-1 | 2.93 h | 204 GB | | | | |

- maxvmem 은 가상메모리다. 60샤드에서 200~258 GB — shepherd 노드 실메모리(251 GB)에 가깝다. 다시 돌릴 때 shepherd 에서는
  샤드를 줄인다(예: 40).
- p21 채점(11:04:29 시작)은 잡 종료(11:05:01)보다 먼저 들어갔다. VCF 는 11:03:41 에 이미 완성돼 있었고, 다시 채점한
  결과(156778)가 첫 결과와 byte 단위로 같다.

**간단 QC** (`70_submit_somatic.sh --qc`, PASS 기준):

| pair | PASS | SNV | INDEL | VAF 중앙값 | GERMLINE | pair | PASS | SNV | INDEL | VAF 중앙값 | GERMLINE |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|
| T-BCM | 13,488 | 11,000 | 2,488 | 0.51 | 1,379,134 | 3E4 | 13,179 | 10,709 | 2,470 | 0.52 | 1,332,369 |
| T-PB | 14,947 | 12,215 | 2,732 | 0.50 | 1,338,812 | SC6 | 13,226 | 10,687 | 2,539 | 0.53 | 1,320,894 |
| p21 | 12,100 | 10,057 | 2,043 | 0.52 | 1,350,495 | SC9 | 12,682 | 10,164 | 2,518 | 0.52 | 1,367,509 |
| p41 | 12,453 | 10,471 | 1,982 | 0.52 | 1,363,987 | SC14 | 13,251 | 10,779 | 2,472 | 0.51 | 1,376,003 |
| p100 | 14,712 | 12,431 | 2,281 | 0.50 | 1,378,335 | SC24 | 12,466 | 10,089 | 2,377 | 0.53 | 1,386,457 |
| 2D6 | 12,319 | 10,005 | 2,314 | 0.53 | 1,374,393 | SC28 | 12,750 | 10,374 | 2,376 | 0.53 | 1,358,802 |
| 2E6 | 12,778 | 10,417 | 2,361 | 0.53 | 1,353,241 | | | | | | |

LowQual 0건. PASS 중 VAF ≥ 0.05 비율은 matched 두 쌍이 98~99%(tumor 72~79x), 나머지는 99.5% 이상.

**채점** (aardvark v1.0.0, truth smvar V0.3 tumorvariants, VAF ≥ 0.05). BED `all` 기준, 괄호는 `nogermlineinterference`:

| pair | 조건 | SNV recall | SNV precision | INDEL recall | INDEL precision | truth 밖 PASS SNV |
|---|---|---:|---:|---:|---:|---:|
| **T-BCM** | matched, normal 68x | 0.950 (0.984) | **0.953** | 0.249 (0.430) | **0.986** | 447 |
| **T-PB** | matched, normal 35x | 0.951 (0.984) | **0.864** | 0.255 (0.437) | **0.917** | 1,418 |
| p21 | borrowed, 센터 다름 | 0.931 (0.966) | — | 0.202 (0.351) | — | 526 |
| p41 | borrowed, 센터 다름 | 0.931 (0.965) | — | 0.199 (0.348) | — | 757 |
| p100 | borrowed, 장기 계대 | 0.931 (0.965) | — | 0.217 (0.378) | — | 2,885 |
| 2D6 | borrowed, 클론 p14 | 0.929 (0.964) | — | 0.226 (0.394) | — | 717 |
| 2E6 | borrowed, 클론 p14 | 0.926 (0.960) | — | 0.231 (0.402) | — | 1,124 |
| 3E4 | borrowed, 클론 p14 | 0.892 (0.923) | — | 0.223 (0.387) | — | 1,491 |
| SC6 | borrowed, 클론 p19 | 0.894 (0.925) | — | 0.236 (0.409) | — | 1,672 |
| SC9 | borrowed, 클론 p19 | 0.934 (0.968) | — | 0.246 (0.426) | — | 700 |
| SC14 | borrowed, 클론 p19 | 0.934 (0.968) | — | 0.239 (0.415) | — | 1,194 |
| SC24 | borrowed, 클론 p19 | 0.932 (0.966) | — | 0.225 (0.393) | — | 759 |
| SC28 | borrowed, 클론 p19 | 0.934 (0.968) | — | 0.230 (0.400) | — | 859 |
| 기준: UCSC DS 1.6.0 공개 콜셋 | | 0.948 (0.981) | 0.937 | 0.205 (0.353) | 0.921 | 607 |

truth 는 SNV 9,454 · INDEL 8,752 (`all`), 9,078 · 4,934 (`nogermlineinterference`).

읽는 법:

- precision 은 matched 두 쌍만 읽는다. `recall_only` 쌍의 "truth 밖 PASS" 는 오류가 아니다 — truth 는 0823p23 bulk 의
  truncal 변이만 담고, 클론·다른 계대의 고유 변이는 truth 에 없다. p100(장기 계대)이 가장 많은 것도 그 방향이다.
- matched 두 쌍의 recall 은 같다(SNV 0.95). precision 차이(0.953 vs 0.864)는 normal 심도 차이(68x vs 35x)와 같은
  방향이지만 원인은 이번 범위에서 확인하지 않았다.
- DS 1.10.0 T-BCM 은 공개 DS 1.6.0 콜셋보다 SNV·INDEL 모두 recall·precision 이 같거나 높다. 입력 쌍이 같다고 확인하지
  않았으므로 버전 차이로만 읽지 않는다. INDEL recall 이
  0.2 대인 것은 공개 콜셋도 같다 — 우리 실행만의 문제가 아니다.
- borrowed 쌍의 SNV recall 은 0.93 이 중심이다. 3E4·SC6 만 0.89 로 낮다(심도는 47x·42x 로 낮지 않다). 원인은 보지 않았다.

산출:

- VCF: `$RUN_BASE/<tumor_sample>/PacBio/somatic.<pair>/03_VCF/deepsomatic/<tumor_sample>.somatic.<pair>.GRCh38.deepsomatic.vcf.gz`
- 채점: `$RUN_BASE/_somatic_bench/DS110-<pair>/{all,nogermlineinterference}/summary.tsv`
- 모음: `$INFRA/adhoc/2026-09-25/phase1_somatic_{qc,summary}.tsv` (28 summary = 13쌍 + UCSC 기준 × BED 2)
- 로그: `$INFRA/logs/som.<pair>.<jobid>.log`, 채점 `task.som.<pair>.<jobid>.log`

이번 배치는 vendor `f2de95e` 로 돌렸다. bioinfo-agent 에서 뒤에 들어간 수정(PR #57: 사용자 모델 경로, 표본표 검증,
실행 조건 분기)은 이 배치에 없다. 결과에는 영향이 없다 — 이 실행은 기본 모델을 쓰고 표본표를 직접 만들었다.

## 다시 돌릴 때

이번 배치는 1·2 까지 끝났다(위 결과). 아래는 다시 돌리거나 쌍을 더할 때의 절차다.

1. 잡이 끝나면: `qacct -j <jobid>`(exit·wall·maxvmem), 로그 `$INFRA/logs/som.<pair>.<jobid>.log`, 산출 VCF,
   `bash phase1_pacbio_hifi/scripts/70_submit_somatic.sh --list` · `--qc`.
2. 채점: 쌍마다 `qsub_task.sh som.<pair> -s 4 -- bash phase1_pacbio_hifi/scripts/62_benchmark_somatic.sh DS110-<pair> <vcf>`,
   모은 뒤 `62_benchmark_somatic.sh --collect`. `recall_only` 쌍의 precision 은 읽지 않는다.
3. 실패하면 같은 명령으로 재제출 — `-resume` 으로 이어서 돈다(`$INFRA/work/som.<pair>`). 코드 문제는 bioinfo-agent 에
   넘기고(범용 코드), 고친 커밋을 다시 vendor 한다 — 이 세션은 파이프라인 코드를 직접 고치지 않는다.
4. shepherd 노드에서는 샤드를 줄인다 — `SOMATIC_SLOTS=40` 등. 60샤드 maxvmem 이 실메모리에 붙는다.
