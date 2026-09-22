# 진행 현황 — 지금 돌고 있는 것과 다음 손

읽고 지나가는 문서가 아니라 **매번 갱신하는 표**다. 잡이 끝나거나 결정이 바뀌면 여기부터 고친다. 근거·경위는 [decisions.md](decisions.md), 결과 수치는 `docs/reference/`.
`docs/runs/`가 아니라 여기 두는 이유(한 번 쓰고 남기는 실행 기록이 아니라 계속 덮어쓰는 현황판)는 decisions.md 2026-09-21 항목에 있다.

갱신: 2026-09-22 (phase1 SV 5런 -t 8 재실행 중 · phase2 HG002 R10 완주 확인)

## 한눈에 보기 (nbb2 로그인 노드)

```bash
qstat | awk 'NR>2{n[$3" "$5]++} END{for(k in n) print n[k], k}' | sort -k2; echo; cd /BiO/scratch/dyl/kbb/G000 && for d in GIAB-publicData-*/; do printf '%-45s DONE=%-8s err=%s\n' "${d%/}" "$(grep -o 'Success\|Error' $d/__DONE__ 2>/dev/null | head -1)" "$(cat $d/error_list.txt 2>/dev/null | tr '\n' ' ' | cut -c1-60)"; done; echo; ls /BiO/scratch/ehojune/GIAB_benchmark/repairs/mgi-hg002.*/VALIDATED.txt 2>/dev/null || echo "MGISEQ HG002 rebuild: 아직"
```

## 작업 흐름

| # | 작업 | 상태 (2026-09-22) | 잡 | 끝나면 | 막힌 것 / 의존 |
|---|---|---|---|---|---|
| 1 | **phase3 WGRS 재개** — markdup Java 8→17 (BGISEQ500, Element-AVITI, Hiseq-300x, Illumina-250PE, Novaseq6000, NovaseqX) | **running** 4잡 (09-21 16:36~) | 155526~155529 `regermline`, 60 slots, octopus-2-8/9/11 + shepherd-1-9 | 세트별 `__DONE__` Success·`error_list.txt` 없음 확인 → #7 | 지정 호스트가 비어야 시작. 오래 qw면 `qstat -j 155519 \| grep -i "cannot run\|reason"` |
| 2 | **MGISEQ HG002 BAM 재생성** (정렬 BAM 33% 누락) | **running** (09-22 07:53~) | 155525 `mgi_HG002_rebuild`, 10 slots, octopus-2-10, Codex 스크립트 `repairs/mgi_hg002_recheck.sh --rebuild` | `repairs/mgi-hg002.*/VALIDATED.txt` 확인 → `tmp/04.sort/…HG002_sort.bam`(+.bai) 교체(옛것 보관) → #3 | `rawcheck.log` FAIL이면 원본 GIAB 파일 문제 — 별도 판단 |
| 3 | **MGISEQ 세트 재개** (HG002 새 BAM + HG003/4 markdup) | 대기 | — | #1과 같은 Java 17 래퍼로 재제출 | #2 |
| 4 | **phase2 ONT HG002 R10.4.1** (PR #17, ONT open data 플로우셀 1개) | **완주** — qacct exit_status 0 | 155279, shepherd-1-8, 30 slots, **16h20m(58,791s) / maxvmem 66.2 GB**. `30_verify_outputs.sh` OK 1/1 | `35_review_qc.py` → `60_benchmark.sh`/`61_benchmark_sv.sh` (R10·DeepVariant 첫 채점). 채점까지 끝나면 `docs/runs/` 기록 + `docs/reference/` 수치 | 없음 |
| 5 | **phase1 PacBio HiFi hap.py 평가** (`b1.*`, HG001~HG007) | **완료** — 19/19 exit 0 | 155355~155373, 16 slots, 56~83분, maxvmem 48.4~48.8 GB | 수치·판정: [2026-09-22-pacbio-hifi-benchmark-first-results.md](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md) | — |
| 5b | **phase1 PacBio SV 평가** (`s1.*`, Truvari vs v5.0q, HG002 5런) | **재실행 중** 14:50~ — `-t 22` 4런 결과는 나왔으나 조건을 맞추려 5런 전량 `FORCE=1` 재제출 | 156037~156041, 22 slots / `-t 8`. 옛 결과: Revio .8418 > SeqII .8362/.8275 > SeqI .8208 | `--collect` → 참고 문서의 SV 표 갱신 | shepherd-1-8 만 비어 있어 동시 2잡. 5런 ≈ 15분 |
| 6 | phase3 Hiseq-subsampled-30x | **완료** (Success) | — | #7에 포함 | — |
| 7 | **phase3 평가 설계** — 업체 4곳(gd1~4) + 공개 raw 22 샘플의 VCF를 v4.2.1(+HG002 CMRG·v5.0q)로 hap.py | 미착수 | — | 결과 디렉토리 구조 받으면 phase1·2 `60_benchmark.sh` 모양으로 스크립트 | #1·#3 완료 |
| 8 | **phase1 HG008 9런 등록** — uBAM → BAM → VCF. 다운로드는 끝났는데 `run_table.tsv`에 없다 | **미착수** | — | `run_table.tsv` 38 → 47 실행단위, `make_samplesheets.py` → `10_submit.sh --ready` | 없음. 노드 여유가 나면 바로 |
| 9 | **HG008-T somatic 평가 설계** — germline truth가 없는 HG008/HG009를 채점할 유일한 길 | **미착수** | — | smvar V0.3-20260425 / stvar-CNV V0.5-20260318 기준 `62_benchmark_somatic.sh` (가칭) | #8 (평가할 VCF가 먼저 있어야) |
| 10 | **phase1↔phase2 표준화 잔여** — 아래 "표준화 백로그" | 부분 완료 | — | phase3까지 같은 모양으로 | 급하지 않음 |

## #8 상세 — phase1 HG008 9런 (미등록)

다운로드는 2026-08-30에 끝났고 디스크에 있다. **진입 타입은 fastq가 아니라 uBAM이다** (Revio가
기기에서 CCS를 끝내 보낸다). 이미 돌린 HG009 클론과 디렉토리 구조·파일명 규약이 같다.

| 실행 단위 | GiB | 비고 |
|---|---|---|
| HG008T-p100 (bulk 20240508p100) | 95 | |
| HG008T-2D6 / 2E6 / 3E4 (20240718p14 클론) | 86 / 109 / 134 | 2E6은 SMRT cell 2개 → uBAM 2개 |
| HG008T-SC14 / SC24 / SC28 / SC6 / SC9 (20240805p19 클론) | 129 / 97 / 114 / 116 / 123 | |

합계 **1,001 GiB / 리드 파일 19개**. 각 디렉토리에 GIAB 정렬본(`*_GRCh38-GIABv3.bam`)이 같이
들어 있는데 **그건 입력이 아니다** — 우리는 demux uBAM(`m84*.demux.bc*.bam`)만 쓴다.

커버리지가 48~60X라 런당 10~15시간 예상(phase1 30x 실측 6~7시간 기준). 파이프라인 잡은 30슬롯이라
노드당 2런이다.

**germline truth가 없어 `60_benchmark.sh`·`61_benchmark_sv.sh`가 자동으로 건너뛴다.** 채점은 #9가
만들어져야 가능하다 — 그전까지는 QC(`35_review_qc.py`)까지만 본다.

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

- 2026-09-22 — **phase2 HG002 R10.4.1 완주 확인**(155279, exit_status 0, 58,791s = 16h20m, maxvmem 66.2 GB / 30슬롯, shepherd-1-8). `30_verify_outputs.sh` OK 1/1 — dv 산출물 포함 전부 있다. `aligned_bam_realign` 진입이 실전에서 처음 증명됐고, 이 런 하나가 R10 소변이·R10 SV·DeepVariant 채점 셋을 동시에 연다. 이어서 `35_review_qc.py --pass-counts` 가 `PermissionError: 'bcftools'` 로 죽어 도구 해석을 고쳤다(decisions 2026-09-22).
- 2026-09-22 14:50 — phase1 SV 5런을 `-t 8` 로 전량 재제출(156037~156041). 앞선 `-t 22` 4런 결과는 유효하지만 죽은 1런과 조건을 맞추려 통일했다. **SV 수치 서술 정정**: "truth 28,123 중 ~20,600개를 찾는다"는 `comp cnt`(우리가 부른 수)를 recall 분자로 잘못 쓴 것이었다 — 실제로 찾은 건 `TP-base` 21,282~22,147개다(PR #22 Codex 지적). 추적 안 되던 항목 #8(HG008 9런 등록)·#9(somatic 평가 설계)·#10(표준화 백로그)을 표에 올렸다.
- 2026-09-22 저녁 — phase1 SV 첫 실측. **recall이 문제다** — precision 0.90 고른데 recall 0.757~0.788, pbsv가 truth 28,123개 중 21,282~22,147개를 찾고 5,976~6,841개를 놓친다(v5.0q가 T2T-Q100 유래라 어려운 영역을 많이 담은 탓으로 추정, 미확인). 세대 순서는 소변이와 같은 방향(Revio > Sequel II > Sequel I). **`-t`를 NSLOTS에 묶어 둔 것이 ENOMEM을 만들었다** — abPOA 메모리가 스레드에 비례해서 22슬롯 2잡이 겹치자 380 GB를 요구했다. `BENCH_SV_THREADS`로 분리.
- 2026-09-22 — phase1 hap.py 19잡 완료(전부 exit 0). **SNP는 전 런 0.9984~0.9994로 포화, INDEL은 기기 세대가 가른다** — Sequel I 2런이 0.928·0.965로 나머지(0.975~0.997)와 확연히 갈리고, DeepVariant가 기기별 모델 없이 같은 격차를 내므로 caller 모델 탓이 아니다. **Revio에서만 Clair3가 DeepVariant에 INDEL −0.006~−0.017로 진다**(모델은 `hifi_revio` 제대로 받았다). 같은 날 노드 집합이 octopus 2 + shepherd 2로 바뀌어 큐/노드 해석을 `qstat -f` 대조 방식으로 교체.

- 2026-09-21 — 문서 생성. phase3 첫 실행이 markdup에서 전부 죽음(GATK 4.6.1.0 vs Java 8). Codex 앱 세션 "Fix server Java version for GATK"가 원인·래퍼·MGISEQ HG002 BAM 누락을 찾음. 20 샘플 BAM은 온전(idxstats 대조).
