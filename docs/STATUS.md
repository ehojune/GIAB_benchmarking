# 진행 현황 — 지금 돌고 있는 것과 다음 손

읽고 지나가는 문서가 아니라 **매번 갱신하는 표**다. 잡이 끝나거나 결정이 바뀌면 여기부터 고친다. 근거·경위는 [decisions.md](decisions.md), 결과 수치는 `docs/reference/`.
`docs/runs/`가 아니라 여기 두는 이유(한 번 쓰고 남기는 실행 기록이 아니라 계속 덮어쓰는 현황판)는 decisions.md 2026-09-21 항목에 있다.

갱신: 2026-09-22 (phase1 hap.py 19잡 완료 반영)

## 한눈에 보기 (nbb2 로그인 노드)

```bash
qstat | awk 'NR>2{n[$3" "$5]++} END{for(k in n) print n[k], k}' | sort -k2; echo; cd /BiO/scratch/dyl/kbb/G000 && for d in GIAB-publicData-*/; do printf '%-45s DONE=%-8s err=%s\n' "${d%/}" "$(grep -o 'Success\|Error' $d/__DONE__ 2>/dev/null | head -1)" "$(cat $d/error_list.txt 2>/dev/null | tr '\n' ' ' | cut -c1-60)"; done; echo; ls /BiO/scratch/ehojune/GIAB_benchmark/repairs/mgi-hg002.*/VALIDATED.txt 2>/dev/null || echo "MGISEQ HG002 rebuild: 아직"
```

## 작업 흐름

| # | 작업 | 상태 (2026-09-22) | 잡 | 끝나면 | 막힌 것 / 의존 |
|---|---|---|---|---|---|
| 1 | **phase3 WGRS 재개** — markdup Java 8→17 (BGISEQ500, Element-AVITI, Hiseq-300x, Illumina-250PE, Novaseq6000, NovaseqX) | **qw** 6잡 | 155519~155524 `regermline_java17_*`, 60 slots, `octopus-2-10\|11` 지정 | 세트별 `__DONE__` Success·`error_list.txt` 없음 확인 → #7 | 지정 호스트가 비어야 시작. 오래 qw면 `qstat -j 155519 \| grep -i "cannot run\|reason"` |
| 2 | **MGISEQ HG002 BAM 재생성** (정렬 BAM 33% 누락) | **qw** | 155525 `mgi_HG002_rebuild`, 10 slots, Codex 스크립트 `repairs/mgi_hg002_recheck.sh --rebuild` | `repairs/mgi-hg002.*/VALIDATED.txt` 확인 → `tmp/04.sort/…HG002_sort.bam`(+.bai) 교체(옛것 보관) → #3 | `rawcheck.log` FAIL이면 원본 GIAB 파일 문제 — 별도 판단 |
| 3 | **MGISEQ 세트 재개** (HG002 새 BAM + HG003/4 markdup) | 대기 | — | #1과 같은 Java 17 래퍼로 재제출 | #2 |
| 4 | **phase2 ONT HG002 R10.4.1** (PR #17, ONT open data 플로우셀 1개) | **running** 13:36~ | 155279 `p2.HG002.O…`, shepherd-1-8, 30 slots | `30_verify_outputs.sh` → `35_review_qc.py` → `60_benchmark.sh`/`61_benchmark_sv.sh` (R10·DeepVariant 첫 채점) | — |
| 5 | **phase1 PacBio HiFi hap.py 평가** (`b1.*`, HG001~HG007) | **완료** — 19/19 exit 0 | 155355~155373, 16 slots, 56~83분, maxvmem 48.4~48.8 GB | 수치·판정: [2026-09-22-pacbio-hifi-benchmark-first-results.md](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md) | — |
| 5b | **phase1 PacBio SV 평가** (`s1.*`, Truvari, HG002 5런) | 미제출 | `61_benchmark_sv.sh --ready`, 22 slots | Sequel I / Sequel II / Revio 세 세대 SV 비교 | 브랜치 머지 후 |
| 6 | phase3 Hiseq-subsampled-30x | **완료** (Success) | — | #7에 포함 | — |
| 7 | **phase3 평가 설계** — 업체 4곳(gd1~4) + 공개 raw 22 샘플의 VCF를 v4.2.1(+HG002 CMRG·v5.0q)로 hap.py | 미착수 | — | 결과 디렉토리 구조 받으면 phase1·2 `60_benchmark.sh` 모양으로 스크립트 | #1·#3 완료 |

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

- 2026-09-22 — phase1 hap.py 19잡 완료(전부 exit 0). **SNP는 전 런 0.9984~0.9994로 포화, INDEL은 기기 세대가 가른다** — Sequel I 2런이 0.928·0.965로 나머지(0.975~0.997)와 확연히 갈리고, DeepVariant가 기기별 모델 없이 같은 격차를 내므로 caller 모델 탓이 아니다. **Revio에서만 Clair3가 DeepVariant에 INDEL −0.006~−0.017로 진다**(모델은 `hifi_revio` 제대로 받았다). 같은 날 노드 집합이 octopus 2 + shepherd 2로 바뀌어 큐/노드 해석을 `qstat -f` 대조 방식으로 교체.

- 2026-09-21 — 문서 생성. phase3 첫 실행이 markdup에서 전부 죽음(GATK 4.6.1.0 vs Java 8). Codex 앱 세션 "Fix server Java version for GATK"가 원인·래퍼·MGISEQ HG002 BAM 누락을 찾음. 20 샘플 BAM은 온전(idxstats 대조).
