# 진행 현황 — 지금 돌고 있는 것과 다음 손

읽고 지나가는 문서가 아니라 **매번 갱신하는 표**다. 잡이 끝나거나 결정이 바뀌면 여기부터 고친다. 근거·경위는 [decisions.md](decisions.md), 결과 수치는 `docs/reference/`.

갱신: 2026-09-21 15:30 (nbb2 qstat 기준)

## 한눈에 보기 (nbb2 로그인 노드)

```bash
qstat | awk 'NR>2{n[$3" "$5]++} END{for(k in n) print n[k], k}' | sort -k2; echo; cd /BiO/scratch/dyl/kbb/G000 && for d in GIAB-publicData-*/; do printf '%-45s DONE=%-8s err=%s\n' "${d%/}" "$(grep -o 'Success\|Error' $d/__DONE__ 2>/dev/null | head -1)" "$(cat $d/error_list.txt 2>/dev/null | tr '\n' ' ' | cut -c1-60)"; done; echo; ls /BiO/scratch/ehojune/GIAB_benchmark/repairs/mgi-hg002.*/VALIDATED.txt 2>/dev/null || echo "MGISEQ HG002 rebuild: 아직"
```

## 작업 흐름

| # | 작업 | 상태 (2026-09-21 15:30) | 잡 | 끝나면 | 막힌 것 / 의존 |
|---|---|---|---|---|---|
| 1 | **phase3 WGRS 재개** — markdup Java 8→17 (BGISEQ500, Element-AVITI, Hiseq-300x, Illumina-250PE, Novaseq6000, NovaseqX) | **qw** 6잡 | 155519~155524 `regermline_java17_*`, 60 slots, `octopus-2-10\|11` 지정 | 세트별 `__DONE__` Success·`error_list.txt` 없음 확인 → #7 | 지정 호스트가 비어야 시작. 오래 qw면 `qstat -j 155519 \| grep -i "cannot run\|reason"` |
| 2 | **MGISEQ HG002 BAM 재생성** (정렬 BAM 33% 누락) | **qw** | 155525 `mgi_HG002_rebuild`, 10 slots, Codex 스크립트 `repairs/mgi_hg002_recheck.sh --rebuild` | `repairs/mgi-hg002.*/VALIDATED.txt` 확인 → `tmp/04.sort/…HG002_sort.bam`(+.bai) 교체(옛것 보관) → #3 | `rawcheck.log` FAIL이면 원본 GIAB 파일 문제 — 별도 판단 |
| 3 | **MGISEQ 세트 재개** (HG002 새 BAM + HG003/4 markdup) | 대기 | — | #1과 같은 Java 17 래퍼로 재제출 | #2 |
| 4 | **phase2 ONT HG002 R10.4.1** (PR #17, ONT open data 플로우셀 1개) | **running** 13:36~ | 155279 `p2.HG002.O…`, shepherd-1-8, 30 slots | `30_verify_outputs.sh` → `35_review_qc.py` → `60_benchmark.sh`/`61_benchmark_sv.sh` (R10·DeepVariant 첫 채점) | — |
| 5 | **phase1 PacBio HiFi hap.py 평가** (`b1.*`, HG002~HG007) | 2 running + 15 qw | 155357~155373 `b1.<sample>.P…`, 16 slots | 결과 표를 `docs/reference/`에 (phase2 첫 실측 문서와 같은 형식) | shepherd 노드 슬롯 |
| 6 | phase3 Hiseq-subsampled-30x | **완료** (Success) | — | #7에 포함 | — |
| 7 | **phase3 평가 설계** — 업체 4곳(gd1~4) + 공개 raw 22 샘플의 VCF를 v4.2.1(+HG002 CMRG·v5.0q)로 hap.py | 미착수 | — | 결과 디렉토리 구조 받으면 phase1·2 `60_benchmark.sh` 모양으로 스크립트 | #1·#3 완료 |

## 자잘한 정리 (급하지 않음)

- `/BiO/scratch/dyl/kbb/G000/GIAB_publicData_Hiseq_subsampled_30x` — 옛 이름, 손으로 바꾼 트리와 중복. 링크 2쌍뿐. 지워도 됨.
- `sample_information_nbb2.filled.xlsx`(로컬) — GIAB 22행 채운 사본. 원본 반영은 사용자.
- decisions.md에 "nbb2 GATK 4.6은 Java 17 필요, 잡 안에서 JAVA_HOME/PATH 지정" 한 줄 — #1 성공 확인 후.
- 파이프라인이 bwa 실패를 삼키고 `Finished`로 넘긴 경로(Codex 확인) — 공용 파이프라인이라 우리가 안 고침. 재개 전 BAM 리드 수 대조가 방어책(아래 명령).

## 자주 쓰는 확인 명령

BAM이 fastp 리드 수 이상인지 (정렬 누락 스크리닝, 즉시 끝남):

```bash
cd /BiO/scratch/dyl/kbb/G000 && for j in GIAB-publicData-*/tmp/02.trimmed/*_fastp.json; do s=$(basename "$j" _fastp.json); d=${j%%/tmp/*}; exp=$(python -c "import json;print(json.load(open('$j'))['summary']['after_filtering']['total_reads'])"); got=$(/home/ehojune/program/samtools-1.24/samtools idxstats "$d/tmp/04.sort/${s}_sort.bam" 2>/dev/null | awk '{s+=$3+$4} END{print s+0}'); printf '%-50s fastp=%s bam=%s %s\n' "$s" "$exp" "$got" "$([ "$got" -ge "$exp" ] && echo OK || echo SHORT)"; done
```

(`bam=0`은 세트가 Success로 끝나 tmp가 정리된 경우다 — Hiseq-subsampled-30x가 그렇다.)

## 이력

- 2026-09-21 — 문서 생성. phase3 첫 실행이 markdup에서 전부 죽음(GATK 4.6.1.0 vs Java 8). Codex 앱 세션 "Fix server Java version for GATK"가 원인·래퍼·MGISEQ HG002 BAM 누락을 찾음. 20 샘플 BAM은 온전(idxstats 대조).
