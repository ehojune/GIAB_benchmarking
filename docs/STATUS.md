# 진행 현황 — 지금 돌고 있는 것과 다음 손

읽고 지나가는 문서가 아니라 **매번 갱신하는 표**다. phase1 채점 결과의 해석은
[중간 보고](reports/2026-09-22-phase1-pacbio-benchmark.md) — #8·#9 가 끝나면 그것과 합쳐 최종 보고를 다시 쓴다. 잡이 끝나거나 결정이 바뀌면 여기부터 고친다. 근거·경위는 [decisions.md](decisions.md), 결과 수치는 `docs/reference/`.
`docs/runs/`가 아니라 여기 두는 이유(한 번 쓰고 남기는 실행 기록이 아니라 계속 덮어쓰는 현황판)는 decisions.md 2026-09-21 항목에 있다.

갱신: 2026-09-22 (phase1 SV 5런 -t 8 재실행 중 · phase2 HG002 R10 완주 확인)

## 한눈에 보기 (nbb2 로그인 노드)

```bash
qstat | awk 'NR>2{n[$3" "$5]++} END{for(k in n) print n[k], k}' | sort -k2; echo; cd /BiO/scratch/dyl/kbb/G000 && for d in GIAB-publicData-*/; do printf '%-45s DONE=%-8s err=%s\n' "${d%/}" "$(grep -o 'Success\|Error' $d/__DONE__ 2>/dev/null | head -1)" "$(cat $d/error_list.txt 2>/dev/null | tr '\n' ' ' | cut -c1-60)"; done; echo; ls /BiO/scratch/ehojune/GIAB_benchmark/repairs/mgi-hg002.*/VALIDATED.txt 2>/dev/null || echo "MGISEQ HG002 rebuild: 아직"
```

## 지금 다른 세션이 하는 일 (2026-09-23 갱신)

세 세션이 같은 repo 를 동시에 고친다. 규칙은 [AGENTS.md](../AGENTS.md) 의
"여러 에이전트가 동시에 붙을 때". **이 절은 상태이므로 낡으면 지운다.**

| | 세션 | 상태 |
|---|---|---|
| #29 · #32 | ONT — HG002 R10 채점, ts/tv 구간 분할 | **머지됨** |
| #33 | 다운로드 — 디스크 전수 대조(81,330/81,330 일치) + `fetch_all.sh` (#27 대체) | 열림. **PacBio 에게 묻는 항목 4개** — 아래 답 |
| #31 | PacBio — 조율 규칙(AGENTS.md) | 열림 |

**ONT 세션이 정정해 준 것**(#29): main 에 "truvari 는 ONT 67~73 GB / HiFi 91.6~136.2 GB,
데이터셋이 두 배를 가른다" 고 적었던 것은 틀렸다. 그 ONT 값은 `BENCH_SV_THREADS` 가 생기기 전
**기본 4스레드** 값이었고, `-t 8` 로 맞춰 재니 R10 이 133.5 GB 로 HiFi 대역 안이었다.
**데이터셋 차이가 아니라 스레드 설정 차이다.** PacBio 세션은 동의한다.

### #33 의 PacBio 질문에 대한 답 (2026-09-23)

1. **sra_manifest 밖에 받은 것 없다.** phase1 의 외부 다운로드는 `02_fetch_sra_reads.sh` 가
   ENA 에서 받는 12 fastq 뿐이고 전부 `sra_manifest.tsv` 에 있다. 다른 출처(SRA toolkit,
   PacBio 공개 버킷)를 쓴 적 없다.
2. **`_infra/` 자산 목록은 아래 "공유 `_infra` 자산" 절.** ONT 와 같은 디렉토리를 쓰므로
   중복은 한 번만 적었다.
3. **미추적 파일 처리** — `phase1_bench_summary.tsv`(repo 루트)는 **옛 경로**다. 지금 스크립트는
   `phase1_pacbio_hifi/` 밑에 쓴다. 루트 것은 삭제, phase 디렉토리의 둘은 **gitignore**
   (재생성 가능한 산출물이고 `--collect` 한 번이면 나온다). `env.local.sh.bak` 도 gitignore.
4. **phase0 매니페스트 밖 입력 계획은 지금 없다.** #8 의 HG008-T 10 파일은 전부 phase0 안이다.
   생기면 `sra_manifest.tsv` 에 먼저 등록하고 받겠다.

## 공유 `_infra` 자산 (phase1·phase2 공용, 2026-09-23 확인)

`$RUN_BASE/_infra` = `/BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune/_infra`.
**산출물이 아니라 실행에 필요한 자산**이라 매니페스트 대조 대상이 아니었다. 계산 노드에
외부망이 없어 전부 로그인 노드에서 미리 받아 둔 것들이다(`01_prepare_login_node.sh`).

### `reference/` — 3.2 GB

| 파일 | 크기 | 출처 | 받은 곳 |
|---|---|---|---|
| `GCA_000001405.15_GRCh38_no_alt_analysis_set.fasta` | 3,144,230,986 | phase0 `release/references/GRCh38/` 사본을 압축 해제. 없으면 GIAB FTP 직접 | phase1 `01_prepare` |
| `…fasta.fai` | 7,804 | `samtools faidx` 로 생성 (hap.py·truvari 가 요구) | phase1 `60_benchmark` |
| `human_GRCh38_no_alt_analysis_set.trf.bed` | 7,594,623 | `raw.githubusercontent.com/PacificBiosciences/pbsv/master/annotations/` | phase1 `01_prepare` |
| `clair3_models/` 3개 | — | HKU/Rerio. `r1041_e82_400bps_sup_v420`, `…_v430`, `r941_prom_hac_g238` — 컨테이너에 없는 것들 | **phase2** `01_prepare` |
| `sv_truth/HG002_GRCh38_v5.0q_stvar.noast.{vcf.gz,tbi}` | — | 파생물. phase0 truth 에서 `ALT="*"` 제거 (v5.0q README 지시) | phase1 `61_benchmark_sv`, phase2 와 공유 |

### `containers/` — 4.9 GB, 이미지 16개

| | |
|---|---|
| 공용 | `bcftools 1.24` 84 MB · `samtools 1.24` 44 MB · `mosdepth 0.3.14` 44 MB · `multiqc 1.35` 383 MB |
| 변이 호출 | `deepvariant 1.10.0` 1,879 MB · `clair3 v1.2.0` 1,413 MB |
| phase1 전용 | `pbmm2 26.2.0` · `pbsv 2.11.0` · `pbccs 6.4.0` · `pbtk 3.5.0` (합 41 MB) · `whatshap 2.8` 152 MB |
| phase2 전용 | `minimap2_samtools`(seqera wave) 140 MB · `sniffles 2.8.0` 134 MB · `longphase 2.0.2` 29 MB |
| 벤치마크 | `hap.py v0.3.12` 447 MB · `truvari 5.4.0` 141 MB |

전부 `docker://` 에서 `singularity pull` 로 받았다. URI 는 각 phase 의 `nextflow.config`
`container_*` 와 `env.sh` 의 `BENCH_IMAGES` 가 정본이고, 파일명은 Nextflow 규약
(프로토콜 제거 후 `[/:]` → `-`, `.img`)이라 URI 에서 기계적으로 나온다.

**받은 데이터가 아니라 실행 자산**이다. 지우면 `01_prepare_login_node.sh` 한 번으로 복구된다
(로그인 노드에서, 외부망 필요).

## 클러스터 사실 (2026-09-22 직접 확인)

세 세션이 다 알아야 하는 것이라 여기 둔다.

| | |
|---|---|
| **GPU 없음** | `qhost -F gpu` 가 리소스 행을 하나도 안 낸다. 어느 노드도 `gpu` complex 를 광고하지 않는다. DeepSomatic 등은 CPU 경로로 설계해야 한다 |
| **octopus 노드는 1 TB RAM** | `octopus-2-*` 1007.1 GB / `shepherd-1-*` 251.1 GB. 지금까지의 슬롯 계산은 전부 251 GB 기준이라 **octopus 에서는 과하게 보수적**이다. 노드별로 다르게 잡을 여지가 있다 |
| 전 노드 64코어 | octopus-2-1~2-11, shepherd-1-1~1-14 (큐 인스턴스 25개). **그중 우리에게 허용된 집합은 따로 물어야 한다** — SGE ACL 이 아니라 사람끼리의 약속이다 |

## 작업 흐름

| # | 작업 | 상태 (2026-09-22) | 잡 | 끝나면 | 막힌 것 / 의존 |
|---|---|---|---|---|---|
| 1 | **phase3 WGRS 재개** — markdup Java 8→17 (BGISEQ500, Element-AVITI, Hiseq-300x, Illumina-250PE, Novaseq6000, NovaseqX) | **running** 4잡 (09-21 16:36~) | 155526~155529 `regermline`, 60 slots, octopus-2-8/9/11 + shepherd-1-9 | 세트별 `__DONE__` Success·`error_list.txt` 없음 확인 → #7 | 지정 호스트가 비어야 시작. 오래 qw면 `qstat -j 155519 \| grep -i "cannot run\|reason"` |
| 2 | **MGISEQ HG002 BAM 재생성** (정렬 BAM 33% 누락) | **running** (09-22 07:53~) | 155525 `mgi_HG002_rebuild`, 10 slots, octopus-2-10, Codex 스크립트 `repairs/mgi_hg002_recheck.sh --rebuild` | `repairs/mgi-hg002.*/VALIDATED.txt` 확인 → `tmp/04.sort/…HG002_sort.bam`(+.bai) 교체(옛것 보관) → #3 | `rawcheck.log` FAIL이면 원본 GIAB 파일 문제 — 별도 판단 |
| 3 | **MGISEQ 세트 재개** (HG002 새 BAM + HG003/4 markdup) | 대기 | — | #1과 같은 Java 17 래퍼로 재제출 | #2 |
| 4 | **phase2 ONT HG002 R10.4.1** (PR #17, ONT open data 플로우셀 1개) | **완료** — 파이프라인·채점 전부 | 155279, shepherd-1-8, 30 slots, **16h20m(58,791s) / maxvmem 66.2 GB**. `30_verify_outputs.sh` OK 1/1 | **채점까지 완료** — hap.py 156047(50.7분) + Truvari 156053(4.5분) 둘 다 exit 0. 수치: [2026-09-22-ont-r10-benchmark.md](reference/2026-09-22-ont-r10-benchmark.md) | 없음 |
| 5 | **phase1 PacBio HiFi hap.py 평가** (`b1.*`, HG001~HG007) | **완료** — 19/19 exit 0 | 155355~155373, 16 slots, 56~83분, maxvmem 48.4~48.8 GB | 수치·판정: [2026-09-22-pacbio-hifi-benchmark-first-results.md](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md) | — |
| 5b | **phase1 PacBio SV 평가** (`s1.*`, Truvari vs v5.0q, HG002 5런) | **완료** — refine F1 .8208~.8418. **세대 단조성 없음**(SeqI 이 SeqII 를 가른다), recall 이 약점(.757~.788) | 156048~156052, `-t 8`, exit 0 | 수치·판정: [2026-09-22-pacbio-hifi-benchmark-first-results.md](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md) | — |
| 6 | phase3 Hiseq-subsampled-30x | **완료** (Success) | — | #7에 포함 | — |
| 7 | **phase3 평가 설계** — 업체 4곳(gd1~4) + 공개 raw 22 샘플의 VCF를 v4.2.1(+HG002 CMRG·v5.0q)로 hap.py | 미착수 | — | 결과 디렉토리 구조 받으면 phase1·2 `60_benchmark.sh` 모양으로 스크립트 | #1·#3 완료 |
| 8 | **phase1 HG008-T 9 실행단위** — uBAM → BAM → VCF | **제출됨** 2026-09-22 17:23 — 2건 r / 7건 qw | 156064~156072, 30 slots. 허용 4노드 중 셋이 `regermline` 60슬롯에 잡혀 shepherd-1-8 만 빈다 | `30_verify_outputs.sh` → `35_review_qc.py`. 채점은 #9 가 서야 가능 | 런당 10~15시간 예상, 9건이면 2~3일 |
| 9 | **HG008-T somatic 평가 설계** — germline truth가 없는 HG008/HG009를 채점할 유일한 길 | **미착수** | — | smvar V0.3-20260425 / stvar-CNV V0.5-20260318 기준 `62_benchmark_somatic.sh` (가칭) | #8 (평가할 VCF가 먼저 있어야) |
| 10 | **phase1↔phase2 표준화 잔여** — 아래 "표준화 백로그" | 부분 완료 | — | phase3까지 같은 모양으로 | 급하지 않음 |

## #8 상세 — phase1 HG008-T 9 실행단위 (2026-09-22 등록 완료)

`make_samplesheets.py` 의 RUNS 스펙에서 **HG008 의 NIST 트리가 통째로 빠져 있었다.** 다운로드는
2026-08-30 에 끝나 있었다. HG008 은 Liss_lab 4건만, HG009 는 NIST 11건이 다 등록돼 있었는데
HG008 NIST 만 없었다 — 의도적 제외가 아니라 누락이다. 생성기를 고쳐 재생성했다(손으로 넣으면
다음 재생성 때 사라진다).

**진입 타입은 fastq 가 아니라 uBAM 이다.** Revio 가 기기에서 CCS 를 끝내 보낸다.

| 실행 단위 | uBAM | GiB |
|---|---|---|
| HG008T-p100 (bulk, 20240508p100) | 1 | 49.9 |
| HG008T-2D6 / 2E6 / 3E4 (20240718p14 클론) | 1 / **2** / 1 | 46.1 / 57.5 / 69.9 |
| HG008T-SC6 / SC9 / SC14 / SC24 / SC28 (20240805p19 클론) | 1 each | 61.5 / 64.8 / 67.2 / 50.8 / 60.2 |

**합계 10 uBAM / 528.1 GiB.** 2E6 만 SMRT cell 이 2개다.

> 이전에 "1,001 GiB" 로 적었던 것은 **디렉토리 총량**이다. 절반이 GIAB 이 만든 정렬본
> (`*_PacBio-HiFi-Revio_<N>X_GRCh38-GIABv3.bam`)이고 **그건 입력이 아니다** — 우리는 uBAM 부터
> 다시 정렬한다. 패턴이 demux uBAM 만 잡으므로 정렬본은 자동으로 빠진다.

커버리지가 48~60X 라 런당 10~15시간 예상(phase1 30x 실측 6~7시간 기준). 파이프라인 잡은
30슬롯이라 노드당 2런이다.

**germline truth 가 없어 `60_benchmark.sh`·`61_benchmark_sv.sh` 가 자동으로 건너뛴다.**
채점은 #9 가 서야 가능하고, 그전까지는 QC(`35_review_qc.py`)까지만 본다.

## #9 상세 — somatic 평가에서 먼저 정해야 할 것

**germline caller 출력을 somatic truth 에 그냥 대면 안 된다.** 우리 파이프라인이 HG008-T 에서
내는 것은 DeepVariant/Clair3 의 **전체 변이**(germline + somatic)인데, GIAB somatic 벤치마크는
**종양 특이 변이만** 담는다. 그대로 비교하면 germline 변이가 전부 FP 가 되어 precision 이 무너진다.

갈 수 있는 길 셋:

| | 방법 | 문제 |
|---|---|---|
| A | tumor − normal 뺄셈 | 거칠다. somatic 은 subclonal(저 VAF)이 많은데 germline caller 가 그걸 잘 못 부른다 |
| B | somatic caller 추가 (DeepSomatic 등, PacBio 지원) | 파이프라인 확장이 필요하다. 가장 정공법 |
| C | 채점 포기, somatic 구간을 QC·커버리지 확인에만 사용 | 안전하지만 얻는 게 적다 |

**매칭 정상(normal)이 또 하나의 걸림돌이다.** 매니페스트 실측으로 NIST 트리에는 tumor 만 있고
정상은 Liss_lab 쪽뿐이다(HG008-N-D, HG008-N-P). 즉 NIST 클론 9건의 짝을 맞추려면 **다른 랩·다른
준비의 정상**을 써야 해서, 랩 차이가 somatic 판정에 섞인다.

이 셋 중 무엇으로 갈지는 사용자 결정이 필요하다 — #8 산출물이 나오기 전에도 정할 수 있다.

## 표준화 백로그 (#10)

phase2를 기준으로 phase1을 맞추는 작업의 잔여분. 급하지 않지만 남겨 둔다.

| 항목 | 상태 |
|---|---|
| `lib.sh` 공용 헬퍼(`*_img_path`, `*_container_uris`, `*_sge_*`) | **완료** (2026-09-22) |
| `60_benchmark.sh` 하드닝(.fai 자동생성, qsub 검증, `submit_many`) | **완료** |
| `10_submit.sh` qsub 하드닝 (양쪽 phase) | **완료** |
| `61_benchmark_sv.sh` phase1 이식 | **완료** |
| `env.local.sh.example` 벤치마크 프리셋 (양쪽) | **완료** |
| `30_verify_outputs.sh`·`20_status.sh`에 haplotagged BAM + mosdepth/samtools 점검 추가 | 미착수 |
| `35_review_qc.py`에 `--calibrate`, `basemap_pct`(CIGAR 기반 매핑률), `--check-meth` | 미착수 |
| `50_update_catalog.py`의 `excluded.tsv` 기구 | 미착수 |
| `run_table.tsv`에 `files` 열 | 미착수 |
| phase3를 phase1·2와 같은 `env.sh`/`lib.sh`/번호 스크립트 구조로 | 미착수 |

## 자잘한 정리 (급하지 않음)

- `/BiO/scratch/dyl/kbb/G000/GIAB_publicData_Hiseq_subsampled_30x` — 옛 이름, 손으로 바꾼 트리와 중복. 링크 2쌍뿐. 지워도 됨.
- `sample_information_nbb2.filled.xlsx`(로컬) — GIAB 22행 채운 사본. 원본 반영은 사용자.
- Java 17 결정은 decisions.md 2026-09-21 항목에 적었다(검증 대기 표시). #1 성공 확인 후 "검증됨"으로 바꾼다.
- 파이프라인이 bwa 실패를 삼키고 `Finished`로 넘긴 경로(Codex 확인) — 공용 파이프라인이라 우리가 안 고침. 재개 전 BAM 리드 수 대조가 방어책(아래 명령).

## 자주 쓰는 확인 명령

정렬 BAM 완전성 검사는 두 단계다.

**1단계 — 빠른 스크리닝** (인덱스만 읽어 즉시 끝남). `idxstats`는 secondary/supplementary까지 세므로 작은 누락(≲0.4%)은 가릴 수 있다. 잘린 파일(MGISEQ HG002처럼 수십 %)만 잡는 용도다. samtools 실패(파일 없음 포함)는 idxstats의 종료 코드로 잡아 `NOBAM`으로 따로 표시한다 — 파이프 뒤에 두면 awk 종료 코드에 가려진다.

```bash
cd /BiO/scratch/dyl/kbb/G000 && SAM=/home/ehojune/program/samtools-1.24/samtools; for j in GIAB-publicData-*/tmp/02.trimmed/*_fastp.json; do s=$(basename "$j" _fastp.json); d=${j%%/tmp/*}; exp=$(python -c "import json;print(json.load(open('$j'))['summary']['after_filtering']['total_reads'])"); if ! out=$($SAM idxstats "$d/tmp/04.sort/${s}_sort.bam" 2>/dev/null); then printf '%-50s fastp=%s NOBAM\n' "$s" "$exp"; continue; fi; got=$(printf '%s\n' "$out" | awk '{s+=$3+$4} END{print s+0}'); printf '%-50s fastp=%s idxstats=%s %s\n' "$s" "$exp" "$got" "$([ "$got" -ge "$exp" ] && echo OK || echo SHORT)"; done
```

**2단계 — 확정** (primary만 세므로 정확하지만 BAM 전체를 읽는다. 샘플당 수 분~수십 분, SGE 잡으로). `fastp after_filtering total_reads`와 정확히 같아야 한다.

```bash
cd /BiO/scratch/dyl/kbb/G000 && SAM=/home/ehojune/program/samtools-1.24/samtools; for j in GIAB-publicData-*/tmp/02.trimmed/*_fastp.json; do s=$(basename "$j" _fastp.json); d=${j%%/tmp/*}; exp=$(python -c "import json;print(json.load(open('$j'))['summary']['after_filtering']['total_reads'])"); got=$($SAM view -c -F 0x900 -@ 4 "$d/tmp/04.sort/${s}_sort.bam") || { printf '%-50s FAIL(samtools)\n' "$s"; continue; }; printf '%-50s fastp=%s primary=%s %s\n' "$s" "$exp" "$got" "$([ "$got" -eq "$exp" ] && echo OK || echo MISMATCH)"; done
```

(1단계에서 `NOBAM`은 세트가 Success로 끝나 tmp가 정리된 경우다 — Hiseq-subsampled-30x가 그렇다. 2026-09-21 1단계 결과: 20 OK, MGISEQ HG002 SHORT. 2단계는 아직 안 돌렸다.)

## 이력

- 2026-09-22 밤 — **ts/tv 구간 분할을 직접 쟀다**(`62_tstv_regions.sh`, 10건 전부 `안+밖=전체` 통과). **2026-08-27 의 열린 질문이 R9·R10 양쪽에서 닫혔다** — 구간 안이 전 런 2.0972~2.1400 으로 germline 기대치 그대로고 구간 밖만 1.09~1.48 이다. 2026-09-18 의 추정(HG005 1.33)은 실측 **1.3064**(오차 1.8%)로 확인됐고 "구간 안 = 2.1" 가정도 사실이었다. 새 관찰 둘: 베이스콜러가 좋을수록 구간 밖 ts/tv 가 오히려 **낮다**(어려운 영역까지 더 부른다), 그리고 구간 밖에서 DV↔C3 순 차이의 ts/tv 가 2.18 이라 **DV 가 구간 밖에서 버리는 쪽이 FP 가 아닐 수 있다**(미확인, reference §5).
- 2026-09-22 밤 — **phase2 HG002 R10 채점 전량 완료**(hap.py 156047 + Truvari 156053, 둘 다 exit 0). **ONT 가 같은 플로우셀에 공개한 hap.py 결과와 SNP F1 −0.0001 / INDEL F1 −0.0013 로 일치** — 우리가 ONT 정렬을 버리고 재정렬했는데도 그렇다. **DeepVariant 가 네 칸 전부에서 Clair3 를 이긴다**(INDEL F1 +0.024, FP −33%). SV 는 R10 이 R9 를 F1 +0.031 로 이기는데 그 이득이 거의 전부 recall(+0.048)이다. truvari 가 133.5 GB 를 써서 `BENCH_SV_SLOTS` 를 22→33 으로 올렸다 — env.sh 의 옛 "67~73 GB" 는 4스레드 값이었다. 수치: [2026-09-22-ont-r10-benchmark.md](reference/2026-09-22-ont-r10-benchmark.md)
- 2026-09-22 17:30 — #8 제출(156064~156072). **GPU 는 없다**(`qhost -F gpu` 무응답) — somatic 은 CPU 경로로 설계해야 한다. **octopus 노드가 1 TB RAM** 인 것을 처음 확인했다(shepherd 251 GB) — 지금까지의 슬롯 계산이 전부 251 GB 기준이라 octopus 에서는 과하게 보수적이다. 세 세션이 동시에 repo 를 고치고 있어 AGENTS.md 에 조율 규칙을 넣었다(소유 구분, 충돌 잦은 파일, PR 전 merge-tree 확인, 남의 실측을 덮어쓰지 않기).
- 2026-09-22 밤 — SV 5런 최종 수치 확정. **"세대 순서가 소변이와 같다"는 앞선 보고를 정정한다** — `CCS_15kb`(Sequel I)가 F1 .8333 으로 `SequelII_CCS_11kb`(.8275)보다 위라 Sequel I 두 런이 Sequel II 를 사이에 두고 갈라진다. **소변이 순위와도 뒤집힌다**: `CCS_15kb` 는 INDEL 19런 중 최하위(F1 .9282)인데 SV 는 5런 중 3위다. 런을 하나의 품질 축으로 줄 세우면 안 된다. refine 이득은 +4.9~5.4점으로 phase2 ONT(+4.8~5.1)와 거의 같다 — 표현 정규화라는 설명과 맞는다. phase1 벤치마킹은 **채점 가능한 전량 완료**(소변이 19런, SV 5런). 남은 것은 #8·#9.
- 2026-09-22 저녁 — SV 5런 `-t 8` 로 전량 완주(maxvmem 91.6~136.2 GB). **"메모리가 스레드에 비례한다"는 앞선 판단을 정정한다** — 같은 데이터로 `-t 22 -> 8` 하니 스레드 64% 감소에 메모리는 29~46%만 줄었다. 가장 큰 영역 하나의 작업 공간이 고정분으로 남는 것으로 보인다. 초판의 비례 주장은 ONT(-t 8)와 HiFi(-t 22)를 비교한 것이라 데이터셋 차이가 섞여 있었다. **제어 수단은 스레드가 아니라 동시 실행 수** — `BENCH_SV_SLOTS` 를 33(노드당 1잡)으로 올렸다. 22슬롯이면 최악 257 GB 로 251 GB 초과다.
- 2026-09-22 — **phase2 HG002 R10.4.1 완주 확인**(155279, exit_status 0, 58,791s = 16h20m, maxvmem 66.2 GB / 30슬롯, shepherd-1-8). `30_verify_outputs.sh` OK 1/1 — dv 산출물 포함 전부 있다. `aligned_bam_realign` 진입이 실전에서 처음 증명됐고, 이 런 하나가 R10 소변이·R10 SV·DeepVariant 채점 셋을 동시에 연다. 이어서 `35_review_qc.py --pass-counts` 가 `PermissionError: 'bcftools'` 로 죽어 도구 해석을 고쳤다(decisions 2026-09-22).
- 2026-09-22 14:50 — phase1 SV 5런을 `-t 8` 로 전량 재제출(156037~156041). 앞선 `-t 22` 4런 결과는 유효하지만 죽은 1런과 조건을 맞추려 통일했다. **SV 수치 서술 정정**: "truth 28,123 중 ~20,600개를 찾는다"는 `comp cnt`(우리가 부른 수)를 recall 분자로 잘못 쓴 것이었다 — 실제로 찾은 건 `TP-base` 21,282~22,147개다(PR #22 Codex 지적). 추적 안 되던 항목 #8(HG008 9런 등록)·#9(somatic 평가 설계)·#10(표준화 백로그)을 표에 올렸다.
- 2026-09-22 저녁 — phase1 SV 첫 실측. **recall이 문제다** — precision 0.90 고른데 recall 0.757~0.788, pbsv가 truth 28,123개 중 21,282~22,147개를 찾고 5,976~6,841개를 놓친다(v5.0q가 T2T-Q100 유래라 어려운 영역을 많이 담은 탓으로 추정, 미확인). **`-t`를 NSLOTS에 묶어 둔 것이 ENOMEM을 만들었다** — abPOA 메모리가 스레드에 비례해서 22슬롯 2잡이 겹치자 380 GB를 요구했다. `BENCH_SV_THREADS`로 분리.
- 2026-09-22 — phase1 hap.py 19잡 완료(전부 exit 0). **SNP는 전 런 0.9984~0.9994로 포화, INDEL은 기기 세대가 가른다** — Sequel I 2런이 0.928·0.965로 나머지(0.975~0.997)와 확연히 갈리고, DeepVariant가 기기별 모델 없이 같은 격차를 내므로 caller 모델 탓이 아니다. **Revio에서만 Clair3가 DeepVariant에 INDEL −0.006~−0.017로 진다**(모델은 `hifi_revio` 제대로 받았다). 같은 날 노드 집합이 octopus 2 + shepherd 2로 바뀌어 큐/노드 해석을 `qstat -f` 대조 방식으로 교체.

- 2026-09-21 — 문서 생성. phase3 첫 실행이 markdup에서 전부 죽음(GATK 4.6.1.0 vs Java 8). Codex 앱 세션 "Fix server Java version for GATK"가 원인·래퍼·MGISEQ HG002 BAM 누락을 찾음. 20 샘플 BAM은 온전(idxstats 대조).
