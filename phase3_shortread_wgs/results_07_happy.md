# #7 숏리드 최소 비교 — 회사 gd001~004 vs 공개 NovaSeq 30x (NIST v4.2.1, hap.py)

상태: **채점 0/13, 멈춤 (2026-09-25 KST).** hap.py 단계가 세 번 같은 원인(singularity 경로)으로 실패했다. 비교가 끝난 것이 아니다.

## 방법 (한 줄씩)
- 입력: 국통바빅 `outcome/<s>/<s>_v1.1.0.g.vcf.gz`. **gVCF뿐이라**(`<NON_REF>` 블록, 확인함) 그대로 채점하지 않는다.
- 잡마다: GATK 4.6.1.0 `GenotypeGVCFs` (같은 파이프라인 GATK, 단일 샘플) → hap.py v0.3.12 (phase1 이미지) vs NIST v4.2.1 `_noinconsistent.bed`.
- ref: GATK bundle `Homo_sapiens_assembly38.fasta` (호출에 쓴 그 ref). truth는 chr1–22.
- HGID는 `sample_information_nbb2.xlsx` Sheet2 (SET_ID·DNA_ID·note)로 대응. 회사 이름은 gd001~004 유지.
- 스크립트 `scripts/11_happy_submit.sh`, manifest `happy_manifest.csv`. 산출 `processed_data_ehojune/phase3_shortread_wgs/07_happy/<label>/`.

## 잡 이력 (2026-09-25 KST)
| 회차 | job | 결과 | 원인 |
|---|---|---|---|
| 1 | 156692–156704 | 13/13 exit 1, 1–4초 | `bashrc.txt` 5행 unset 변수 + 잡의 `set -u` → source 뒤로 옮김 |
| 2 | 156705–156717 | 13/13 exit 127 | GenotypeGVCFs는 끝남(genotyped.vcf.gz+tbi 13개). hap.py에서 `singularity: command not found` |
| 3 | 156718–156730 | 13/13 즉시 종료 | 잡 안 `command -v singularity` 실패 — 계산 노드 PATH에도 없다 |

- **원인 (확정):** singularity는 `/home/ehojune/anaconda3/envs/nfcore312/bin`(conda env의 apptainer 심링크)에만 있다. phase1 잡은 `env.sh`가 이 경로를 PATH에 넣어서 돌았다. 로그인·계산 노드 기본 PATH엔 없다.
- **수정 (커밋만, 미제출):** `11_happy_submit.sh`가 잡 안에서 그 절대경로를 쓰고 `test -x`로 확인한다.
- **재개 (1명령):** `cd /BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune/phase3_shortread_wgs/07_happy && <repo의 11_happy_submit.sh 복사> && bash 11_happy_submit.sh happy_manifest.csv`. gd004·공개 7개는 genotyped VCF가 있어 hap.py만 돈다. gd001·gd003 6개는 GenotypeGVCFs부터 다시 돈다(아래 샘플 교정).
- 같은 문제가 반복돼 지시대로 여기서 멈췄다.

## gd001·gd003 샘플 대응 교정 (2026-09-25)
sampleinfo는 C…001/002/003 = HG002/3/4, C…004/005/006 = KOR-101/102/103이다. 원자료 링크와 성별 깊이는 반대를 가리킨다.

| set | DNA_ID | sampleinfo | FASTQ 링크 대상 | chrX/chrY 깊이 | 판정 |
|---|---|---|---|---|---|
| gd1 | C…1001 / 1002 / 1003 | HG002 M / HG003 M / HG004 F | macrogen `19375725` / `19261049` / `19510479` | 24.5/16.5 · 46.1/1.45 · 22.0/13.9 → M F M | KOR (KOR-101 M·102 F·103 M와 일치) |
| gd1 | C…1004 / 1005 / 1006 | KOR-101 M / 102 F / 103 M | macrogen `NA24385` / `NA24149` / `NA24143` | 19.8/14.1 · 20.0/14.1 · 40.6/1.34 → M M F | HG002 / HG003 / HG004 |
| gd3 | C…3001 / 3002 / 3003 | HG002 / HG003 / HG004 | theragen `19375725` / `19261049` / `19510479` | M F M | KOR |
| gd3 | C…3004 / 3005 / 3006 | KOR-101 / 102 / 103 | theragen `NA24385` / `NA24149` / `NA24143` | M M F | HG002 / HG003 / HG004 |

- NA24385·NA24149·NA24143은 HG002·HG003·HG004의 Coriell ID다. 성별 패턴도 맞는다.
- manifest의 gd001·gd003 HG002/3/4를 C…004/005/006으로 바꿨다. 2회차에서 C…001–003으로 만든 genotyped VCF 6개는 지우지 않고 `07_happy/_superseded_wrong_sample/`로 옮겼다.
- **정본 sampleinfo(G000/sampleinfo/*.xlsx) 교정은 사용자·관리자 몫이다.** gd4(cginvites `HG002_1.fastq.gz` 등)는 파일명과 sampleinfo가 맞는다.
- hap.py가 돌면 recall로 교정이 맞는지 한 번 더 확인된다(잘못된 샘플이면 크게 낮게 나온다).

## gd002 (2026-09-25)
- 확정: `G000-gd2-20260819`의 12 mate 링크는 `data/cginvites/G000-gd4-20260819/`를 가리킨다. VCF `#CHROM`, CRAM `@RG SM`는 C00000040…(gd4 ID)다.
- **후보 (근거 있음):** `/BiO/scratch/dyl/kbb/data/jslink/`에 `C00000020{01..06}00000G0x1_S6{7..9}/S7{0..2}_L005_R{1,2}_001.fastq.gz` 12개가 있다. 정본 sampleinfo의 gd2 DNA_ID와 정확히 같다. `20260729_KRIBB_Josoobok_WGS_1_Summary.txt`에 같은 6 Sample_ID(lane 5, 샘플당 4.1–4.9억 read)가 있다.
- 조회한 경로(G000 set 목록, `G000/*/outcome/C0000002*`, `G000/*/analyze_meta/C0000002*`, `data/*/`)에서 이 FASTQ로 만든 VCF·CRAM은 없다. 그래서 채점할 gd2 결과가 없다. gd2 원자료는 jslink에 있다.
- 파일명에 HG ID가 없어서 HG002/3/4 대응은 sampleinfo(C…2001/2002/2003 = HG002/3/4)에만 기댄다. gd1·gd3에서 sampleinfo 순서가 틀렸으니 처리 후 성별로 확인해야 한다.
- 다음 필요 정보: jslink FASTQ를 국통바빅으로 돌린 set이 G000 밖에 따로 있는지(사용자 확인). 없으면 gd2는 기본 run이 필요하다(사용자 결정, 이 턴에 실행 안 함).

## 표 (채점 미수집)
QC는 국통바빅 `analyze_meta/<s>/` (mosdepth 평균 깊이, flagstat mapped%).

| source | label | DNA_ID | 기술 | 깊이 | mapped% | SNP P/R/F1 | INDEL P/R/F1 | 상태 |
|---|---|---|---|---|---|---|---|---|
| gd | gd001-HG002 / 3 / 4 | C…1004 / 1005 / 1006 | N/A | 35.84 / 36.59 / 39.72 | 99.99 / 99.99 / 99.98 | — | — | 대기(singularity) |
| gd | gd002-HG002~4 | C…2001–2003 | N/A | N/A | N/A | N/A | N/A | 처리된 결과 없음, raw는 jslink |
| gd | gd003-HG002 / 3 / 4 | C…3004 / 3005 / 3006 | N/A | 29.89 / 30.87 / 30.17 | 99.99 / 99.98 / 99.99 | — | — | 대기 |
| gd | gd004-HG002 / 3 / 4 | C…4001 / 4002 / 4003 | N/A | 39.86 / 45.98 / 34.73 | 99.97 / 99.98 / 99.98 | — | — | 대기 |
| public | NovaSeq6000 PCR-free 30x HG002 / 3 / 4 | — | NovaSeq6000 | 29.53 / 29.58 / 29.80 | 99.92 / 99.87 / 99.93 | — | — | 대기 |
| public | NovaSeqX 30x HG002 | — | NovaSeqX | 25.70 | 100.00 | — | — | 대기 |

KOR(truth 없음, QC만): gd1 C…1001–1003 44.06/44.38/40.06x · gd3 C…3001–3003 30.82/29.24/30.24x · gd4 C…4004–4006 44.61/32.71/32.14x. mapped 전부 99.97–99.99%.
회사 롱리드: **수령 대기**.

## GIAB 기본 run (2026-09-25 KST 조회)
| 구분 | set | 상태 |
|---|---|---|
| 완료 | Novaseq6000-PCRfree-30x, NovaseqX-30x, Hiseq-subsampled-30x | `__DONE__` Success |
| 도는 중 (1차) | BGISEQ500 155526 · Element-AVITI 155527 · Hiseq-300x 155528 · Illumina-250PE 155529 · MGISEQ2000-PCRfree 156690 | r, lock 있음, gVCF 0 |
| 준비만 (2차 20 set/53 샘플) | BGISEQ500-ChineseTrio … NIST-BGIseq-100x (`more_run_table.tsv`) | dir·링크만, lock 0, gVCF 0, **제출 안 함(보류)** |

기본 run 다음 순서 (사용자 승인 후): ① 1차 5 set 완료 확인 ② 2차 중 HG001~HG007 germline set부터 `10_submit_java17.sh`로 제출 ③ HG008/HG009 set(somatic 쪽 소유 결정 후). Hiseq-subsampled-30x는 완료된 공개 비교군이라 #7 표에 넣을 수 있다(3잡, 미제출).

## 수집 (재개 뒤 한 번)
```bash
cd /BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune/phase3_shortread_wgs/07_happy
for d in */; do l=${d%/}; f=$l/$l.summary.csv; [ -s $f ] || { echo "$l 미완"; continue; }
  awk -F, -v l=$l 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next} $2=="PASS"{print l,$1,"P="$h["METRIC.Precision"],"R="$h["METRIC.Recall"],"F1="$h["METRIC.F1_Score"]}' $f; done
```
