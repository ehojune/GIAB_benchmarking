# 서버·자산·확인 명령 — 조회용

nbb2 클러스터의 안 변하는 사실, `_infra` 에 미리 받아 둔 실행 자산, 자주 쓰는 점검 명령.
**현황이 아니다** — 지금 무엇이 돌고 있는지는 [STATUS.md](../STATUS.md).
값이 바뀌면(노드 교체, 이미지 갱신) 여기를 고치고 STATUS 이력에 한 줄 남긴다.

## 클러스터 사실 (2026-09-22 직접 확인)

세 세션이 다 알아야 하는 것이라 여기 둔다.

| | |
|---|---|
| **GPU 없음** | `qhost -F gpu` 가 리소스 행을 하나도 안 낸다. 어느 노드도 `gpu` complex 를 광고하지 않는다. DeepSomatic 등은 CPU 경로로 설계해야 한다 |
| **octopus 노드는 1 TB RAM** | `octopus-2-*` 1007.1 GB / `shepherd-1-*` 251.1 GB. 지금까지의 슬롯 계산은 전부 251 GB 기준이라 **octopus 에서는 과하게 보수적**이다. 노드별로 다르게 잡을 여지가 있다 |
| 전 노드 64코어 | octopus-2-1~2-11, shepherd-1-1~1-14 (큐 인스턴스 25개). **그중 우리에게 허용된 집합은 따로 물어야 한다** — SGE ACL 이 아니라 사람끼리의 약속이다 |

## 매니페스트 밖에서 받은 것 (2026-09-22~23 전수 확인)

"우리가 외부에서 무엇을 받았나" 를 물을 때 보는 자리다. 디스크 전수 대조 기록은
[runs/2026-09-22-disk-vs-manifest-reconciliation.md](../runs/2026-09-22-disk-vs-manifest-reconciliation.md).

| 세션 | 외부 다운로드 | 확인 |
|---|---|---|
| phase1 PacBio | ENA 12 fastq (HG001·HG005 SequelII 11kb) — 전부 `sra_manifest.tsv` 안 | **그 밖에 받은 것 없다.** SRA toolkit·PacBio 공개 버킷을 쓴 적 없다 |
| phase2 ONT | HG001 rel6 fastq+summary, HG002 R10 `calls.sorted.bam`+`.bai` — 전부 `ext_manifest.tsv` 안 | **그 밖에 받은 것 없다.** PAW71238·POD5·ONT happy-benchmark 파일 전부 안 받았다(`find` 확인). 대조군 수치는 ONT 공개 문서에서 읽은 것이지 파일이 아니다 |
| phase3 숏리드 | Google brain-genomics-public(GCS) 8 files, HPRC S3 4 files — `ext_manifest.tsv` | `external/google_novaseq_pcrfree_30x/md5.txt` 438 B 가 매니페스트 밖 유일한 파일 (미결: `kind=evidence` 로 넣을지) |

**새 데이터를 들일 때의 순서**: 그 phase 의 매니페스트에 먼저 → `02_fetch_*` 로 받기 →
카탈로그 행 → 디스크 대조 재실행해 0 차이 확인. 순서가 바뀌면 "받았는데 목록에 없는" 데이터가 생긴다.
phase0 매니페스트 밖 입력을 쓸 계획은 지금 세 세션 다 없다.

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
| `clair3_models/` 3개 | **195 MB** (78+78+39) | HKU `bio8.cs.hku.hk/clair3/clair3_models/` 우선, 실패 시 Rerio `cdn.oxfordnanoportal.com/software/analysis/models/clair3/`. `r1041_e82_400bps_sup_v420` 78 MB · `…_v430` 78 MB · `r941_prom_hac_g238` 39 MB — 컨테이너 `/opt/models` 에 없는 것만 받는다 | **phase2** `01_prepare` |
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
