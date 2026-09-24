# #7 숏리드 최소 비교 — 회사 gd001~004 vs 공개 NovaSeq 30x (NIST v4.2.1, hap.py)

상태: **채점 0/13, gd2 입력·엑셀 준비 완료(2026-09-25 07:30 KST).** preflight 156733은 exit 0/PREFLIGHT_OK. 비교 13잡은 아직 재제출하지 않았다. gd2 교정 잡 156732는 중지했고 원래 set은 사용자 검토·제출 대기다.

## 방법 (한 줄씩)
- 입력: 국통바빅 `outcome/<s>/<s>_v1.1.0.g.vcf.gz`. **gVCF뿐이라**(`<NON_REF>` 블록, 확인함) 그대로 채점하지 않는다.
- 잡마다: GATK 4.6.1.0 `GenotypeGVCFs` (같은 파이프라인 GATK, 단일 샘플) → hap.py v0.3.12 (phase1 이미지) vs NIST v4.2.1 `_noinconsistent.bed`.
- ref: GATK bundle `Homo_sapiens_assembly38.fasta` (호출에 쓴 그 ref). truth는 chr1–22.
- HGID는 사용자 정본 표와 실제 원자료를 대조한다. 서버 sampleinfo의 기존 note만으로 대응시키지 않는다. 회사 이름은 gd001~004 유지.
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
- 같은 문제가 반복돼 멈췄다가 사용자 지시(09-25)로 preflight 후 재개하기로 했다.
- preflight 1 (1 slot, 4G): singularity는 찾았으나 SIF를 sandbox로 풀다 `unsquashfs: Out of memory in cache_get`. phase1 env.sh의 `APPTAINER_TMPDIR`도 빠져 있었다 → 잡에 추가.
- preflight 2 = **job 156733** (16 slot, 56G): 07:21:34 종료, failed 0/exit 0/`PREFLIGHT_OK` 확인. 로그 `07_happy/logs/preflight2.156733.log`.
- **재개 조건:** 그 로그에 `PREFLIGHT_OK`가 있으면 `cd …/07_happy && bash 11_happy_submit.sh happy_manifest.csv` (서버 사본은 최신). 없으면 로그의 오류를 먼저 본다.

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

## gd002 교정 전 입력 대조와 정본 준비 (2026-09-25)
| 비교 | 판정 | 근거 |
|---|---|---|
| gd2 outcome ↔ gd4 outcome | **같은 파일** (내용 동일) | 12/12 mate가 같은 device·inode·크기로 `data/cginvites/G000-gd4-20260819/{HG002…KOR-103}_{1,2}.fastq.gz`에 닿는다. hash 불필요 |
| jslink ↔ gd2 outcome | **다른 read set** | 12/12 inode·크기 다름(jslink C…2001 R1 32.78 GB vs 43.65 GB). 첫 read flowcell/lane `LH00842:226:25333MLT4:5` vs `LH00677:246:23V3NWLT4:1`, index도 다름. 업체 Summary read 수(C…2001 4.11억/mate)와 gd2 flagstat(primary 10.05억 = gd4 HG002)도 다름 |
| jslink ↔ gd4 | **다른 read set** | 위와 같음(gd2 outcome = gd4) |

- 판정 범위: 파일 전체 hash는 하지 않았다. "다름"은 크기·inode·flowcell·read 수 차이로 충분하다. "같음"은 같은 inode라 확정이다.
- 교정 전 gd2 결과(VCF·CRAM SM = C…40xx)는 **gd4 원자료로 만든 것**이다. 아래 백업 경로로 옮겼고 비교에 쓰지 않는다. 위 대조표는 교정 전 결과 기준이다.
- jslink 원자료 = gd2 회사 자료(사용자 확인). DNA_ID C…2001–2006이 sampleinfo gd2 행, 업체 Summary(`20260729_KRIBB_Josoobok_WGS_1_Summary.txt`, lane 5, S67–S72)와 일치한다. mate는 R1→`_1`, R2→`_2`이고 첫 read 이름이 R1/R2 쌍으로 맞는다.

**사용자 정본 대응 (이미지1, 2026-09-25)** — 네 회사 모두 순번 1–3 = KOR-101~103 (19375725·19261049·19510479), 4–6 = HG002~004 (NA24385·NA24149·NA24143). 서버 sampleinfo(1–3 = HG, 4–6 = KOR)와 반대다.

| gd2 ID | 실제 샘플 | R1 / R2 원본 (`data/jslink/`) | 성별 · 근거 |
|---|---|---|---|
| C000000200100000G0x1 | KOR-101 (19375725) | `…_S67_L005_R1_001` / `R2` | male · sampleinfo의 KOR-101 성별(4회사 공통), gd1·gd3 19375725 chrY 깊이 |
| C000000200200000G0x1 | KOR-102 (19261049) | `…_S68_…` | female · 같음 |
| C000000200300000G0x1 | KOR-103 (19510479) | `…_S69_…` | male · 같음 |
| C000000200400000G0x1 | HG002 (NA24385) | `…_S70_…` | male · GIAB son |
| C000000200500000G0x1 | HG003 (NA24149) | `…_S71_…` | male · GIAB father |
| C000000200600000G0x1 | HG004 (NA24143) | `…_S72_…` | female · GIAB mother |

**진행 상태 — 관리자 직접 검증·반영, 07:30 KST**
- 교정 잡 **156732 중지**(exit 137). `G000-gd2-20260819-jslink-20260925`는 이력으로 보존하고 `DO_NOT_RUN.txt` 표시.
- 원래 `G000-gd2-20260819`를 `G000-gd2-20260819-bak-gd4input-20260925`로 보관했다. 원래 경로는 `outcome/<ID>/<ID>_{1,2}.fastq.gz` 링크 12개만으로 다시 구성했다. 전부 jslink의 같은 ID·mate·inode·크기와 일치하며 이전 결과·완료 표시가 없다.
- 서버 sampleinfo Sheet2의 gd2 note 6칸·SEX 4칸 수정. 백업: `sample_information_nbb2.xlsx.bak-20260925-072959-gd2fix`. 101행·서식·대상 밖 셀 유지, worksheet 이외 XLSX 내부 파일은 바이트 동일 검증.
- Claude 일괄 명령은 자동 검사에서 거절됐다. 관리자가 준비본 검증과 최종 반영을 분리하고 별도 승인검사를 거쳐 완료했다. 서버 기록: `G000/.gd2-preparation-complete-20260925.json`.
- **입력·메타데이터 READY, 새 germline 미제출.** 준비 스크립트는 다시 실행하지 않는다.

**사용자 실행 (검토 후)**
```bash
source /BiO/scratch/dyl/kbb/bashrc.txt
export JAVA_HOME=/BiO/scratch/dyl/apps/miniconda3/lib/jvm
export PATH="$JAVA_HOME/bin:$PATH"
cd /BiO/scratch/dyl/kbb/G000/G000-gd2-20260819
germline /BiO/scratch/dyl/kbb/G000/G000-gd2-20260819
```
- `germline`은 bashrc의 alias다(`qsub … germline.sh`). germline.sh 헤더는 `-q shepherd.q`, 60 slot, 300G이고 호스트 제한이 없다.
- bashrc는 `JAVA_HOME=$CONDA_PREFIX`다. 내 로그인 환경에서는 openjdk 17.0.18이었다. 제출 셸에서 `java -version`이 17인지 먼저 본다(GATK 4.6.1 MarkDuplicatesSpark가 17을 요구). 아니면 `10_submit_java17.sh`를 쓴다.

**발견사항 (보고만)**
- gd1·gd3: 링크(C…001–003 → 19xxxx, 004–006 → NA24xxx)는 이미지와 맞는다. sampleinfo note·SEX가 반대다.
- gd4: sampleinfo와 **링크도** 이미지와 반대다. C…4001 → cginvites `HG002_1.fastq.gz`인데, 이미지는 C…4001 = KOR-101이다. hap.py manifest의 gd004 행(C…4001–4003 = HG002–004)은 cginvites 파일명 기준이라 이미지와 다르다. 결과 해석 전에 사용자 확인이 필요하다.

## 표 (채점 미수집)
QC는 국통바빅 `analyze_meta/<s>/` (mosdepth 평균 깊이, flagstat mapped%).

| source | label | DNA_ID | 기술 | 깊이 | mapped% | SNP P/R/F1 | INDEL P/R/F1 | 상태 |
|---|---|---|---|---|---|---|---|---|
| gd | gd001-HG002 / 3 / 4 | C…1004 / 1005 / 1006 | N/A | 35.84 / 36.59 / 39.72 | 99.99 / 99.99 / 99.98 | — | — | 대기(singularity) |
| gd | gd002-HG002~4 | C…2004–2006 (이미지1) | N/A | N/A | N/A | — | — | gd2 입력·엑셀 준비 완료, 사용자 제출 대기 |
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
