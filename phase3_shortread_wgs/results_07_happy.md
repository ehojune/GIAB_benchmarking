# #7 숏리드 최소 비교 — 회사 gd001~004 vs 공개 NovaSeq 30x (NIST v4.2.1, hap.py)

상태: **제출됨, 채점 미수집 (2026-09-25).** 비교가 끝난 것이 아니다.

## 방법 (한 줄씩)
- 입력: 국통바빅 `outcome/<s>/<s>_v1.1.0.g.vcf.gz`. **gVCF뿐이라**(`<NON_REF>` 블록, 확인함) 그대로 채점하지 않는다.
- 잡마다: GATK 4.6.1.0 `GenotypeGVCFs` (같은 파이프라인 GATK, 단일 샘플) → hap.py v0.3.12 (phase1 이미지) vs NIST v4.2.1 `_noinconsistent.bed`.
- ref: GATK bundle `Homo_sapiens_assembly38.fasta` (호출에 쓴 그 ref). truth는 chr1–22.
- HGID는 `sample_information_nbb2.xlsx` Sheet2 (SET_ID·DNA_ID·note)로 대응. 회사 이름은 gd001~004 유지.
- 스크립트 `scripts/11_happy_submit.sh`, manifest `happy_manifest.csv`. 산출 `processed_data_ehojune/phase3_shortread_wgs/07_happy/<label>/`.

## 제출 잡 (qsub 2026-09-25, 16 slots)
| label | job | 비고 |
|---|---|---|
| gd001-HG002 / HG003 / HG004 | 156692 / 156693 / 156694 | |
| gd002-HG002~4 | — | **미제출**: `outcome/`에 C00000020… 샘플 dir 없음, `tmp/10.haplo`엔 C00000040…(gd4 ID)만 있다. `__DONE__`은 Success. 입력 대응 확인 필요 |
| gd003-HG002 / HG003 / HG004 | 156695 / 156696 / 156697 | |
| gd004-HG002 / HG003 / HG004 | 156698 / 156699 / 156700 | |
| public NovaSeq6000 PCR-free 30x HG002 / HG003 / HG004 | 156701 / 156702 / 156703 | |
| public NovaSeqX 30x HG002 | 156704 | |

## 표 (수집 후 채움)
QC는 국통바빅 `analyze_meta/<s>/` 재사용 (mosdepth 평균 깊이, flagstat mapped%). 없으면 N/A.

| source | label | HGID | 기술 | 파이프라인/ref | 깊이 | mapped% | SNP P/R/F1 | INDEL P/R/F1 | 상태 |
|---|---|---|---|---|---|---|---|---|---|
| gd | gd001-HG002 | HG002 | N/A | biko GATK4.6.1 / GRCh38 bundle | | | | | 제출 |
| gd | gd004-HG002 | HG002 | N/A | 〃 | 39.86 | 99.97 | | | 제출 |
| gd | gd004-HG003 | HG003 | N/A | 〃 | 45.98 | 99.98 | | | 제출 |
| gd | gd004-HG004 | HG004 | N/A | 〃 | 34.73 | 99.98 | | | 제출 |
| public | NovaSeq6000-30x-HG002 | HG002 | NovaSeq6000 PCR-free | 〃 | 29.53 | 99.92 | | | 제출 |
| public | NovaSeq6000-30x-HG003 | HG003 | 〃 | 〃 | 29.58 | 99.87 | | | 제출 |
| public | NovaSeq6000-30x-HG004 | HG004 | 〃 | 〃 | 29.80 | 99.93 | | | 제출 |
| public | NovaSeqX-30x-HG002 | HG002 | NovaSeqX | 〃 | 25.70 | 100.00 | | | 제출 |

gd001·gd003 QC와 KOR-101~103(truth 없음 → QC만)은 수집 때 채운다.
회사 롱리드: **수령 대기** (raw 미도착).

## 수집 (다음 요청 때 한 번)
```bash
cd /BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune/phase3_shortread_wgs/07_happy
for d in */; do l=${d%/}; f=$l/$l.summary.csv; [ -s $f ] || { echo "$l 미완"; continue; }
  awk -F, -v l=$l 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next} $2=="PASS"{print l,$1,"P="$h["METRIC.Precision"],"R="$h["METRIC.Recall"],"F1="$h["METRIC.F1_Score"]}' $f; done
qstat -u ehojune | grep happy7; grep -l "ALL DONE" logs/*.log | wc -l
```
