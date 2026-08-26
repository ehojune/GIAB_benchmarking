# Phase 2 — ONT: raw → VCF

GIAB ONT 전 데이터셋을 **각자의 가장 raw한 형태부터** 정렬·변이 호출한다
(fastq > uBAM > aligned BAM 순. POD5/fast5 베이스콜링은 안 한다. GIAB 산출물은 무시하되 지우지 않음 — 2026-08-21 정책).
파이프라인: minimap2 → Clair3 (+DeepVariant) → Sniffles2 → LongPhase 위상/haplotag → QC.
[pipeline/ont-wgs](pipeline/ont-wgs/)는 phase1의 pacbio-hifi-wgs를 본떠 새로 만들었다
([왜 nf-core/nanoseq가 아닌지](../docs/reference/ont_pipeline_choice.md)).

- 실행 단위: **18개** ([run_table.tsv](run_table.tsv)) = 카탈로그 ONT 18행 중 17행을 분해
  (HG008 Northeastern_ONT-std는 N-D/N-P로 분리). 잡 1개 = 실행 단위 1개.
- 진입점: fastq 12 / uBAM 6. **aligned BAM 진입은 없다.**
- 이 중 4개는 `dup_of` 표시 — HG002 ONT-UL은 같은 MinION 플로우셀의 베이스콜 릴리스가 5종이다
  (rel1 6x, rel2 16x, guppy 2.3.4 / 3.2.4 / 3.4.5 각 52x). 기본 제출은 최신·최대인 **guppy-V3.4.5** 하나뿐이고
  나머지 4개는 `DUP_OK=1 scripts/10_submit.sh <dsid>` 로만 돈다.
- 카탈로그 1행은 **제외**: HG002 Cornell 2D ([excluded.tsv](excluded.tsv), 이유 포함)
- 입력 합계 2.92 TiB (중복 제외 **2.50 TiB**, 14 runs). 노드 3대 / 노드당 2잡 = 동시 6런.

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
bash phase2_ont/scripts/02_fetch_external_reads.sh         # 1회: HG001 rel6 리드 (외부 AWS, 136 GiB)
bash phase2_ont/scripts/03_dup_evidence.sh                 # 중복 판정 근거 (읽기 전용, 오래 걸림)
bash phase2_ont/scripts/04_stub_test.sh                    # 1회: 파이프라인 배선 스모크 테스트 (1분)
bash phase2_ont/scripts/10_submit.sh --ready               # 준비된 것 전부 제출 (dup 제외; --list로 미리보기)
bash phase2_ont/scripts/20_status.sh                       # 진행 대시보드
bash phase2_ont/scripts/30_verify_outputs.sh               # 완료 검증 (파일 존재 여부)
python phase2_ont/scripts/35_review_qc.py                  # QC 지표 리뷰 (이상치 표시)
bash phase2_ont/scripts/36_multiqc_all.sh                  # 전 런을 MultiQC 리포트 하나로
python phase2_ont/scripts/50_update_catalog.py             # 완료분 → 카탈로그+README 표, git diff 보고 커밋
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
| 큐/노드 | shepherd.q, shepherd-1-7/8/9 고정 | **octopus.q는 사용 불가**(2026-08-22). 계산 노드는 외부망 없음 → `NXF_OFFLINE`, 사전 캐시 |
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

**임계값은 아직 잠정값이다** — 케미스트리 특성에 기댄 값이고 실측 조정 전이다. 완주분이 모이면
`--calibrate`로 분포를 뽑아 고치고 근거를 주석에 적을 것.

## 자원 실측은 아직 없다

phase1은 30슬롯 잡으로 30x HiFi가 6~7시간, 피크 43~54 GB였다. ONT는 리드 길이 분포가 극단적이라
(UL은 100 kb+) 정렬 메모리·시간이 다르게 튄다. **첫 1~2런이 끝나면 `qacct -j <jobid>`의
maxvmem / ru_wallclock을 보고 [env.local.sh.example](env.local.sh.example)의 프리셋을 고를 것.**
현재 값(30슬롯 / 110 GB)은 phase1 실측 + Clair3 문서(50x ONT를 36코어로 ~8시간)에 기댄 추정이다.
