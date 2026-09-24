# #7 숏리드 최소 비교 — 회사 gd001~004 vs 공개 NovaSeq 30x (NIST v4.2.1, hap.py)

상태: **2차 제출(13잡), 채점 미수집 (2026-09-25 KST).** 비교가 끝난 것이 아니다.

## 방법 (한 줄씩)
- 입력: 국통바빅 `outcome/<s>/<s>_v1.1.0.g.vcf.gz`. **gVCF뿐이라**(`<NON_REF>` 블록, 확인함) 그대로 채점하지 않는다.
- 잡마다: GATK 4.6.1.0 `GenotypeGVCFs` (같은 파이프라인 GATK, 단일 샘플) → hap.py v0.3.12 (phase1 이미지) vs NIST v4.2.1 `_noinconsistent.bed`.
- ref: GATK bundle `Homo_sapiens_assembly38.fasta` (호출에 쓴 그 ref). truth는 chr1–22.
- HGID는 `sample_information_nbb2.xlsx` Sheet2 (SET_ID·DNA_ID·note)로 대응. 회사 이름은 gd001~004 유지.
- 스크립트 `scripts/11_happy_submit.sh`, manifest `happy_manifest.csv`. 산출 `processed_data_ehojune/phase3_shortread_wgs/07_happy/<label>/`.

## 제출 잡 (2차, 2026-09-25 KST, 16 slots)
1차 156692–156704는 13개 전부 1–4초 만에 exit 1로 끝났다(qacct). `bashrc.txt` 5행이 `LD_LIBRARY_PATH` unset인데 잡이 `set -u`였다. `set -u`를 source 뒤로 옮겨 재제출했다. 1차 로그는 `07_happy/logs/failed-156692-156704/`에 있다(156700–704 로그 5개는 `logs/`에 남아 있다).

| label | job |
|---|---|
| gd001-HG002 / HG003 / HG004 | 156705 / 156706 / 156707 |
| gd003-HG002 / HG003 / HG004 | 156708 / 156709 / 156710 |
| gd004-HG002 / HG003 / HG004 | 156711 / 156712 / 156713 |
| public NovaSeq6000 PCR-free 30x HG002 / HG003 / HG004 | 156714 / 156715 / 156716 |
| public NovaSeqX 30x HG002 | 156717 |
| gd002-HG002~4 | **제출 안 함** (아래) |

제출 90초 뒤 4잡 r(GenotypeGVCFs chr1 진행 확인), 9잡 qw.

## gd002 확인 (2026-09-25): 조회 범위에서 올바른 결과 미확인
- `G000-gd2-20260819/outcome/C00000040{01..06}…_{1,2}.fastq.gz`는 `readlink -f` 결과가 **`data/cginvites/G000-gd4-20260819/HG00x·KOR-10x`**다. gd4 set 링크와 같은 파일이다(inode 동일, 12/12).
- FASTQ 첫 read 이름(`@LH00677:246:23V3NWLT4…`)도 두 set이 같다. mosdepth·flagstat 총량도 같다.
- VCF `#CHROM`, CRAM `@RG SM`는 둘 다 C00000040…(gd4 DNA_ID)다.
- sampleinfo에서 gd2 DNA_ID는 C00000020{01..06}…이다. 이 ID를 쓴 set·링크·결과는 G000 어디에도 없다. `data/cginvites/G000-gd2-20260819/`도 없다.
- 확인한 gd2 set은 **gd4 raw와 결과를 가리킨다**. 이 경로를 gd002 비교에 쓰지 않는다. 회사 숏리드 처리 완료라는 사용자 확인을 유지하되, 다른 위치의 정상 gd002 결과 유무는 이 조회로 단정하지 않는다.
- 필요한 정보: 올바른 gd002 기존 결과와 원자료의 위치·대응. 확인 전에는 gd002를 N/A로 둔다.

## 표 (수집 후 채움)
QC는 국통바빅 `analyze_meta/<s>/` 재사용 (mosdepth 평균 깊이, flagstat mapped%). 없으면 N/A.

| source | label | HGID | 기술 | 파이프라인/ref | 깊이 | mapped% | SNP P/R/F1 | INDEL P/R/F1 | 상태 |
|---|---|---|---|---|---|---|---|---|---|
| gd | gd001-HG002 | HG002 | N/A | biko GATK4.6.1 / GRCh38 bundle | | | | | 제출 |
| gd | gd002-HG002~4 | — | N/A | — | N/A | N/A | N/A | N/A | 정상 결과 경로 미확인 (조회한 set은 gd4 입력) |
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
