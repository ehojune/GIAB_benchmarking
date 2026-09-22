# Phase 2 — ONT: raw → VCF

GIAB ONT 전 데이터셋을 **각자의 가장 raw한 형태부터** 정렬·변이 호출한다
(fastq > uBAM > aligned BAM 순. POD5/fast5 베이스콜링은 안 한다. GIAB 산출물은 무시하되 지우지 않음 — 2026-08-21 정책).
파이프라인: minimap2 → Clair3 (+DeepVariant) → Sniffles2 → LongPhase 위상/haplotag → QC.
[pipeline/ont-wgs](pipeline/ont-wgs/)는 phase1의 pacbio-hifi-wgs를 본떠 새로 만들었다
([왜 nf-core/nanoseq가 아닌지](../docs/reference/ont_pipeline_choice.md)).

- 실행 단위: **19개** ([run_table.tsv](run_table.tsv)) = 카탈로그 ONT 18행 중 17행을 분해
  (HG008 Northeastern_ONT-std는 N-D/N-P로 분리). 잡 1개 = 실행 단위 1개.
- 진입점: fastq 12 / uBAM 6 / **aligned_bam_realign 1** (HG002 R10 — 아래).
- 이 중 4개는 `dup_of` 표시 — HG002 ONT-UL은 같은 MinION 플로우셀의 베이스콜 릴리스가 5종이다
  (rel1 6x, rel2 16x, guppy 2.3.4 / 3.2.4 / 3.4.5 각 52x). 기본 제출은 최신·최대인 **guppy-V3.4.5** 하나뿐이고
  나머지 4개는 `DUP_OK=1 scripts/10_submit.sh <dsid>` 로만 돈다.
- 카탈로그 1행은 **제외**: HG002 Cornell 2D ([excluded.tsv](excluded.tsv), 이유 포함)
- 입력 합계 3.07 TiB (중복 제외 **2.66 TiB**, 15 runs). 노드 3대 / 노드당 2잡 = 동시 6런.

## HG002 R10.4.1 — 벤치마크 공백을 메우려고 외부에서 들여온 런

**2026-09-19 추가.** 그전까지 truth가 있는 샘플(HG001~HG007)은 전부 R9.4.1이고 R10은 전부
HG008(germline truth 없음)이라, **R10 정확도도 DeepVariant도 한 번도 채점된 적이 없었다.**
GIAB FTP에는 HG002의 R10 ONT가 없다(ONT 디렉토리 셋 전부 R9 시절). 그래서 밖에서 가져온다.

| | |
|---|---|
| 출처 | ONT 공개 데이터 `s3://ont-open-data/giab_2025.01/` (익명 다운로드) |
| 라이선스 | **CC BY-NC 4.0 — 비상업 연구 한정.** 이 제약은 데이터와 함께 따라다닌다 |
| 케미스트리 | R10.4.1, PromethION FLO-PRO114M, SQK-LSK114 (kit14) |
| 베이스콜러 | dorado 0.8.2 sup, `dna_r10.4.1_e8.2_400bps@v5.0.0` |
| 받는 것 | 플로우셀 **PAW70337** 하나, 정렬 BAM 160 GiB (+`.bai`) |

**정렬 BAM으로 받지만 정렬은 우리가 다시 한다** (`aligned_bam_realign`). ONT는 POD5와 정렬 BAM만
배포하고 uBAM·fastq는 내지 않으며 POD5 재베이스콜은 정책상 제외다. 그래서 정렬 BAM에서
`samtools fastq`로 리드를 꺼내 우리 minimap2로 다시 정렬한다.

**남의 정렬 결과를 그대로 믿지 않는다는 원칙 때문이고**, 이 런을 넣은 이유가 R9↔R10 비교인 만큼
나머지 14런과 정렬이 달라지면 비교축에 교란이 박힌다. 파이프라인에 `aligned_bam`(정렬을 그대로 쓰는)
진입도 있지만 **쓰는 런은 없다.**

**메틸 태그(MM/ML)는 넘기지 않는다.** 역가닥으로 정렬된 리드는 SEQ가 역상보로 저장돼 있고
`samtools fastq`가 그걸 되돌리는데, MM 오프셋이 그 저장 방향에 묶여 있어 그대로 옮기면 메틸 위치가
조용히 어긋날 수 있다(samtools 문서가 이 경우를 다루지 않는다). 이 런의 목적은 변이 정확도이므로
태그를 버려 그 위험을 없앴다 — `35_review_qc.py`의 `MM%`가 `.`로 나오는 게 정상이다.
R10 메틸화가 필요해지면 ONT 원본 BAM(태그가 정상인 상태로 디스크에 있다)을 직접 쓰면 된다.

**플로우셀 하나만 받는 이유**: ONT가 같은 플로우셀에 자체 hap.py 결과를 공개해 뒀다
(`analysis/happy-benchmark/sup/HG002_PAW70337`, SNP F1 .9983 / INDEL F1 .9147). 같은 입력에 대한
외부 대조군이 생겨서, 우리 수치가 크게 벗어나면 우리 쪽 문제라는 신호가 된다. 나머지 PAW71238
(146 GiB)을 더하면 ~90x가 되지만 그 대조는 사라진다.

이 런 하나가 **R10 소변이 · R10 SV · DeepVariant** 셋을 동시에 연다 — HG002가 소변이(v4.2.1)와
SV(v5.0q) truth를 둘 다 가진 유일한 샘플이기 때문이다.

## 중복 판정은 read_id로 한다

phase1은 movie ID로 같은 셀을 잡아냈다. ONT에는 movie ID가 없다. 대신 **read_id(fast5/pod5의 UUID)가
재베이스콜 후에도 같다**는 성질을 쓴다 — 같은 플로우셀의 재베이스콜이면 read_id 집합이 거의 일치하고,
다른 기기·플로우셀이면 교집합이 0이다.

```bash
bash phase2_ont/scripts/03_dup_evidence.sh        # sequencing_summary에서 read_id/run_id 집합 대조
```

현재 `dup_of` 값은 릴리스 구조·커버리지·문서(52x 3종 = 같은 데이터의 재베이스콜)에 근거한 것이고,
**위 스크립트로 실측 확인 전이다.** 숫자가 나오면 `docs/reference/`에 적고, 판정이 바뀌면
`scripts/make_samplesheets.py`의 `dup_of`를 고쳐 run_table을 다시 생성한다.

## 실행 (nbb2 로그인 노드)

```bash
cd ~/GIAB_benchmarking && git pull
cp phase2_ont/env.local.sh{.example,}                      # 잡 크기 프리셋 (안 하면 노드당 2잡 기본값)
bash phase2_ont/scripts/01_prepare_login_node.sh           # 1회: SGE 점검 + 컨테이너 10개 + 레퍼런스 + TRF + Clair3 모델
bash phase2_ont/scripts/02_fetch_external_reads.sh         # 1회: 외부 리드 (HG001 rel6 136 GiB + HG002 R10 BAM 160 GiB)
bash phase2_ont/scripts/03_dup_evidence.sh                 # 중복 판정 근거 (읽기 전용, 오래 걸림)
bash phase2_ont/scripts/04_stub_test.sh                    # 1회: 파이프라인 배선 스모크 테스트 (1분)
bash phase2_ont/scripts/10_submit.sh --ready               # 준비된 것 전부 제출 (dup 제외; --list로 미리보기)
bash phase2_ont/scripts/20_status.sh                       # 진행 대시보드
bash phase2_ont/scripts/30_verify_outputs.sh               # 완료 검증 (파일 존재 여부)
python phase2_ont/scripts/35_review_qc.py                  # QC 지표 리뷰 (이상치 표시)
bash phase2_ont/scripts/36_multiqc_all.sh                  # 전 런을 MultiQC 리포트 하나로
python phase2_ont/scripts/50_update_catalog.py             # 완료분 → 카탈로그+README 표, git diff 보고 커밋
bash phase2_ont/scripts/60_benchmark.sh --list             # 정확도 평가 대상 확인 (truth set 유무)
bash phase2_ont/scripts/60_benchmark.sh --ready            # hap.py 제출 (HG001~HG007 8런)
bash phase2_ont/scripts/60_benchmark.sh --collect          # 결과를 한 TSV로 모음
bash phase2_ont/scripts/61_benchmark_sv.sh --list          # SV 평가 대상 확인 (HG002만 truth가 있다)
bash phase2_ont/scripts/61_benchmark_sv.sh --ready         # truvari 제출 (HG002 2런)
bash phase2_ont/scripts/61_benchmark_sv.sh --collect       # refine 전/후를 한 TSV로 모음
```

- **`nextflow` 를 직접 부르지 말 것.** 서버 기본은 26.x이고 strict config 파서가 `def` 선언을 거부한다.
  env.sh가 24.10.5를 고정하니 스크립트(또는 `source env.sh`)를 거쳐야 한다.
- 특정 것만: `10_submit.sh HG002.guppy-V3.4.5 ...` / 로그: `tail -f $INFRA/logs/<dsid>.<jobid>.log`
- 잡이 죽으면 **같은 dsid로 재제출하면 -resume** 으로 이어서 돈다.
- 끝난 run의 중간 파일 정리: `scripts/40_clean_work.sh <dsid>`. ONT는 이게 phase1보다 중요하다 —
  HG008T-p2는 uBAM 1090개를 플로우셀 2개로 합치는 중간 파일이 300 GiB 넘게 work에 남는다.
- 다운로드가 진행 중이어도 그냥 제출하면 된다. `--ready`는 입력이 (1) manifest와 크기가 같고
  (2) 최근 10분간 쓰이지 않은 실행 단위만 집는다 (`READY_AGE_MIN=N`으로 조정).
  이유는 phase1 README의 `aws s3 cp` 멀티파트 설명과 같다.

## 설정 (전부 [env.sh](env.sh))

| 항목 | 기본값 | 비고 |
|---|---|---|
| 큐/노드 | `$SGE_QUEUE` x `$SGE_HOSTS` (env.sh) | **노드 집합은 고정이 아니다** — 2026-09-22 기준 octopus-2-8/2-9 + shepherd-1-8/1-9 네 대, 큐 둘. 계산 노드는 외부망 없음 → `NXF_OFFLINE`, 사전 캐시 |
| 잡 크기 | 30슬롯 / h_vmem 115G / Nextflow 110G = **노드당 2잡** | 노드는 64코어·251 GB. `h_vmem`은 consumable=NO라 메모리가 예약되지 않는다 — (노드당 잡 수)×`NF_LOCAL_MEM_GB` < 251을 직접 지켜야 한다. 프리셋은 [env.local.sh.example](env.local.sh.example) |
| Nextflow | 24.10.5 + conda `nfcore312` (JDK17) | 잡 안에서 local executor로 완주 (SGE 자식 잡 없음) |
| 레퍼런스 | GRCh38_no_alt_analysis_set | phase1과 `$INFRA`를 공유하므로 이미 있으면 다시 안 받는다 |
| Clair3 모델 | `$INFRA/reference/clair3_models` | **이미지에 없는 모델 3개를 여기 받아 마운트한다** (아래) |

## 케미스트리별 콜러 모델 (틀려도 조용히 돌아간다)

| 데이터셋 | 케미스트리 / 베이스콜러 | Clair3 | DeepVariant |
|---|---|---|---|
| HG001 rel6 | R9.4 / guppy | `r941_prom_hac_g360+g422` ¹ | 없음 |
| HG002 UL 5종 | R9.4.1 MinION / guppy 2.3.4~3.4.5, albacore | `r941_prom_hac_g360+g422`, 구버전은 `r941_prom_hac_g238` ² | 없음 |
| HG002~004 UCSC prom | R9.4.1 PromethION / guppy 3.2.x | `r941_prom_hac_g360+g422` | 없음 |
| HG005~007 UCSC prom | R9.4.1 PromethION / guppy 4.2.2 | `r941_prom_hac_g360+g422` ³ | 없음 |
| HG008 UCSC std/UL | R10.4.1 / dorado sup@v4.2.0 | `r1041_e82_400bps_sup_v420` | `ONT_R104` |
| HG008 NE std, BCM p2 | R10.4.1 / dorado sup@v4.3.0 | `r1041_e82_400bps_sup_v430` | `ONT_R104` |
| HG008 NE UL | R10.4.1 / dorado 0.8.1 sup(v5.0.0) | `r1041_e82_400bps_sup_v500` | `ONT_R104` |

¹ MinION/R9.4 데이터에 PromethION 모델을 쓴다 — Clair3에 MinION R9 모델이 없다.
² albacore 베이스콜에 맞는 모델은 아예 없어 Guppy2 모델로 대체한다 (기본 제출 대상 아님).
³ 이 모델이 Guppy 4.2.2 데이터로 학습된 것이라 HG005~007에는 정확히 맞는다.

- **DeepVariant 1.10.0의 ONT 모델은 `ONT_R104` 하나뿐이고 R10.4.1 전용이다.** R9.4.1 런은
  `--skip_deepvariant`로 돌고(제출 스크립트가 `dv_model` 열을 보고 자동으로 붙인다) Clair3 단독이다.
- `hkubal/clair3:v1.2.0` 이미지에 **없는** 모델은 `sup_v420`, `sup_v430`, `_g238` 셋이다
  (2026-08-22 nbb2 실측. `r941_prom_hac_g360+g422`는 Clair3 README 표와 달리 이미지에 있다).
  `01_prepare_login_node.sh`가 이미지 목록과 대조해 없는 것만 HKU/Rerio에서 받고, 제출 시점에도 다시 확인한다.
  `_g238`은 gate된 dup 런만 쓰므로 못 받아도 경고로 넘어간다.

## QC 보는 순서

`30_verify_outputs.sh`는 **파일이 있는지**만 본다. 커버리지가 반토막이거나 위상이 거의 안 잡힌 런도
파일만 있으면 통과하므로 그 틈은 [35_review_qc.py](scripts/35_review_qc.py)가 메운다.

```bash
python phase2_ont/scripts/35_review_qc.py                   # 지표 표 + 이상치
python phase2_ont/scripts/35_review_qc.py --pass-counts     # 변이 수까지 판정 (bcftools, 런당 수십 초)
python phase2_ont/scripts/35_review_qc.py --calibrate       # 케미스트리별 실측 분포 (임계값 조정용)
python phase2_ont/scripts/35_review_qc.py --check-meth      # uBAM 런의 MM/ML 태그 보존 확인
bash   phase2_ont/scripts/36_multiqc_all.sh                 # 전 런 → MultiQC 리포트 1개
```

| 판정 축 | phase1과 다른 점 |
|---|---|
| 임계값 | **R9.4.1 / R10.4.1로 나눈다.** R9의 리드 오류율은 R10 sup의 5배 수준이라 phase1의 단일 `err_max=0.02`를 쓰면 R9 12개가 전부 오탐이 된다 (매핑률·error rate·indel 상한이 갈린다) |
| DeepVariant | R10 런에만 있으니 R9의 DV 칸은 `.`(해당 없음)으로 찍고 caller 일치 판정에서 뺀다 |
| 커버리지 | 설계상 6x~100x로 벌어져 하한만 본다 |
| 위상 block N50 | ONT 장리드는 블록이 길어 하한을 HiFi(20kb)보다 높게(50kb) 뒀다 |
| MM/ML 태그 | uBAM 진입 경로의 존재 이유가 메틸 태그 보존인데 검증하는 곳이 없었다 — `--check-meth`가 정렬 BAM을 표본으로 확인한다 |

**변이 수는 `--pass-counts` 없이는 판정하지 않는다.** 파이프라인의 `bcftools_stats`가 PASS 필터 없이
돌아서 RefCall이 섞인 raw 카운트이기 때문이다 (phase1에서 확인된 것과 같은 함정). 기본 실행은 그 값에
`~`를 붙여 보여주기만 한다.

**임계값은 2026-08-27 첫 완주 13런으로 조정했다** (전체 수치·해석은
[docs/reference/2026-08-27-ont-qc-first-pass.md](../docs/reference/2026-08-27-ont-qc-first-pass.md)).
그 실측에서 확정된 것:

- 판정 지표를 리드 개수 → **염기 매핑률**로 옮겼다. R9의 `rd%`가 39~89%로 벌어진 게 정렬 실패가
  아니라 짧은 fail 리드 탓임을 미매핑 리드 평균 길이로 확인했다 (매핑 리드의 1/7~1/12).
- DeepVariant raw 카운트는 RefCall로 **1.7~3.4배** 부풀어 있고, PASS만 세면 Clair3와 3~7%
  안에서 일치한다. caller 일치 판정을 `--pass-counts`에 묶어 둔 게 맞았다.
- **R9 indel은 베이스콜러 버전이 지배한다** — guppy 3.2.x 1,751~1,969k vs 4.2.2 544~551k(3.5배).
  R9 indel 분석은 HG005~007(Guppy 4.2.2)에서만 신뢰할 만하다. SNV는 전 런 사용 가능.
  (2026-09-18 truth 대비로 확인: 그 여분이 거의 전부 FP였다. **FP 기준으로는 3.5배가 아니라 42배**이고,
  guppy 4.2.2조차 indel recall은 0.68~0.75다 — precision은 고쳐지지만 R9이 못 부르는 건 남는다.)
- uBAM 진입 5런의 메틸 태그(MM) 보존율 **100%** — `-y` 경로가 의도대로 동작한다.

**ts/tv 열린 질문은 R9에서 답이 나왔다** (2026-09-18, `60_benchmark.sh` 실측). 전 런이 2.0~2.1보다
낮은 게(R9 1.86~1.97, R10 1.65~1.73) FP 과다 신호인 건 맞는데, **그 FP가 벤치마크 구간 밖에 몰려 있다.**
구간 안의 SNP precision은 0.990~0.997이다. HG005 기준 genome-wide 4.27M 중 구간에서 평가된 건
3.28M이고 나머지 약 0.99M이 구간 밖인데, 구간 안을 2.1로 두면 전체 1.88이 되려면 구간 밖이
ts/tv ≈ 1.15여야 한다 — FP가 섞인 값으로 자연스럽다. 콜러나 파이프라인 문제가 아니다.
**R10(HG008 6런)은 truth가 없어 같은 방법을 못 쓴다 — 미해결.**

## 정확도 평가 ([60_benchmark.sh](scripts/60_benchmark.sh))

GIAB truth set 대비 hap.py. phase1의 같은 스크립트와 구조가 같고 ONT 차이만 아래에 적었다.

| | |
|---|---|
| 대상 | **HG001~HG007 8런**. HG008 6런은 germline truth가 없어 자동으로 빠진다 |
| caller | 런마다 `dv_model` 열로 정한다 — R9는 Clair3 단독, R10은 Clair3+DeepVariant |
| 입력 | `03_VCF/<caller>/*.vcf.gz` **원본**. hap.py가 FILTER를 자체 처리해 ALL/PASS 행을 둘 다 내므로 재실행이 필요 없다 |
| 산출 | `<dataset>/05_BENCH/happy/<id>.<caller>.summary.csv` → `--collect`가 `phase2_bench_summary.tsv`로 모은다 |
| 잡 크기 | `BENCH_SLOTS=8` / `BENCH_VMEM=32G` (hap.py는 병렬성이 낮다) |

**phase2에서 DeepVariant는 벤치마크되지 않는다.** DV가 도는 건 R10 6런뿐인데 그게 전부 HG008이고,
HG008에는 germline truth가 없다 — 매니페스트에 있는 HG008 draft benchmark는 `somatic-stvar`/`CNV`라
단일 샘플 germline VCF 평가에 못 쓴다. 스크립트는 `dv_model`을 보고 자동 판정하므로 나중에 HG008
germline truth가 생기면 코드 수정 없이 DV까지 평가된다.

따라서 [열린 질문인 ts/tv](../docs/reference/2026-08-27-ont-qc-first-pass.md)는 이 단계로 **R9 8런까지만**
답이 나온다. R10의 더 낮은 ts/tv(1.65~1.73)는 미해결로 남는다.

### 실측 (2026-09-18, 8런 전부 완료)

| 베이스콜러 | SNP F1 | INDEL F1 | INDEL precision | INDEL FP |
|---|---|---|---|---|
| guppy 3.2.x · rel6 (HG001~HG004) | .986~.989 | .217~.228 | .146~.159 | 1.08~1.27M |
| guppy 3.4.5 (HG002) | .995 | .556 | .560 | 234k |
| guppy 4.2.2 (HG005~007) | .997 | .771~.822 | .896~.915 | 29~35k |

**SNV는 전 런 쓸 만하고(F1 .986~.997) indel은 베이스콜러가 지배한다.** 2026-08-27에 개수로 추정한
3.5배 격차는 truth 대비 **FP 42배**였다. precision은 베이스콜러로 6.3배 좋아지지만 recall은 1.8배에
그쳐 guppy 4.2.2조차 .68~.75다 — R9이 못 부르는 indel은 남는다.
전체 수치·자원 실측: [docs/reference/2026-09-18-ont-benchmark-first-results.md](../docs/reference/2026-09-18-ont-benchmark-first-results.md).

## SV 정확도 평가 ([61_benchmark_sv.sh](scripts/61_benchmark_sv.sh))

Sniffles2 콜을 GIAB HG002 SV truth set 대비 Truvari로 채점한다.

| | |
|---|---|
| 대상 | **HG002 2런뿐** — `guppy-V3.4.5`, `UCSC_Ultralong_..._Promethion`. 둘 다 R9.4.1 |
| truth | `HG002_GRCh38_v5.0q_stvar` (T2T-Q100 유래, 전장) |
| 입력 | `03_VCF/SV_sniffles/<id>.sniffles.vcf.gz` |
| 산출 | `<dataset>/05_BENCH/truvari/{summary.json,refine.variant_summary.json}` → `--collect`가 `phase2_bench_sv_summary.tsv` |
| 잡 크기 | `BENCH_SV_SLOTS=8` / `BENCH_SV_VMEM=32G` |

**GRCh38 germline SV truth를 가진 GIAB 샘플은 HG002 하나다.** 자주 인용되는
`HG002_SVs_Tier1_v0.6`은 **GRCh37 전용**이라 GRCh38로 정렬한 우리 런에는 쓸 수 없다.
HG001·HG003~HG007에는 SV truth가 아예 없고, HG008의 draft benchmark는 `somatic-stvar`/`CNV`라
소변이 때와 같은 이유로 못 쓴다. 그래서 **R10의 SV 성능은 이 단계로도 알 수 없다.**

파라미터는 GIAB v5.0q README가 지정한 명령 그대로다 — `--pick ac --passonly -r 2000 -C 5000 --refine`.
truvari 5.4.0 기본값과 다른 건 `-r`(500→2000)과 `-C`(1000→5000) 둘뿐이고, `-C`는 chunksize지
sizemin이 아니다. README가 "ALT=\*는 오분류되니 미리 걸러라"고 해서 truth를 한 번 걸러 `$INFRA`에 캐시한다.

`--refine`은 phab로 복잡영역의 표현을 정규화한다. 끄면 탠덤반복 구간의 Sniffles 콜이 표현 차이만으로
FP가 되어 수치가 실제보다 나쁘게 나온다. 다만 **기본 정렬기 poa는 머신 간 비결정적이다**(truvari 문서) —
재현이 필요하면 `BENCH_SV_ALIGN=mafft`. `--collect`는 refine 전/후를 `stage` 열로 둘 다 내보내므로
refine이 수치를 얼마나 움직였는지 보고 판단하면 된다.

### 실측 (2026-09-18, 2런 전부 완료)

| 런 | stage | precision | recall | F1 |
|---|---|---|---|---|
| HG002.guppy-V3.4.5 | bench → **refine** | .917 → **.939** | .706 → **.774** | .798 → **.849** |
| HG002.UCSC_..._Promethion | bench → **refine** | .891 → **.914** | .690 → **.752** | .778 → **.825** |

**refine이 F1을 4.8~5.1점 올린다 — 기본으로 켠 판단이 실측으로 뒷받침됐다.** 비용은 5분이다
(잡 전체가 5~6.6분, maxvmem 67~73 GB). 설계 시점의 유일한 미지수였던 poa 런타임 걱정은 기우였다.
recall .75가 상한이고 truth 28,123건 중 6,363건을 못 부른다. `refine` 행의 `gt_concordance`는
truvari가 그 키를 안 내서 `NA`다.

## 자원 실측은 아직 없다

phase1은 30슬롯 잡으로 30x HiFi가 6~7시간, 피크 43~54 GB였다. ONT는 리드 길이 분포가 극단적이라
(UL은 100 kb+) 정렬 메모리·시간이 다르게 튄다. **첫 1~2런이 끝나면 `qacct -j <jobid>`의
maxvmem / ru_wallclock을 보고 [env.local.sh.example](env.local.sh.example)의 프리셋을 고를 것.**
현재 값(30슬롯 / 110 GB)은 phase1 실측 + Clair3 문서(50x ONT를 36코어로 ~8시간)에 기댄 추정이다.
