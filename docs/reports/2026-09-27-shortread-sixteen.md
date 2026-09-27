# 숏리드 비교 — 완료 16건

2026-09-27 20:55 KST 확인. **회사 4곳의 HG002/3/4 12건과 공개 비교군 4건을 채점했다.** 새 정본 국통바빅 gVCF → GATK 4.6.1.0 GenotypeGVCFs → hap.py 0.3.12. GIAB v4.2.1 GRCh38 chr1–22/no-inconsistent 조건이며 옛 회사 캐시를 쓰지 않았다.

| 자료 | SNP F1 | INDEL F1 |
|---|---:|---:|
| gd1 HG002 | 0.975518 | 0.981310 |
| gd1 HG003 | 0.978034 | 0.981176 |
| gd1 HG004 | 0.977489 | 0.982701 |
| gd2 HG002 | 0.976560 | 0.983065 |
| gd2 HG003 | 0.977404 | 0.984749 |
| gd2 HG004 | 0.977339 | 0.983987 |
| gd3 HG002 | 0.976556 | 0.974389 |
| gd3 HG003 | 0.976670 | 0.976105 |
| gd3 HG004 | 0.976358 | 0.974597 |
| gd4 HG002 | 0.977329 | 0.980025 |
| gd4 HG003 | 0.977773 | 0.981318 |
| gd4 HG004 | 0.977769 | 0.978837 |
| 공개 NovaSeq6000 30x HG002 | 0.980786 | 0.980077 |
| 공개 NovaSeq6000 30x HG003 | 0.980786 | 0.980185 |
| 공개 NovaSeq6000 30x HG004 | 0.980805 | 0.980090 |
| 공개 NovaSeqX 30x HG002 | 0.978631 | 0.979057 |

회사 HG002/3/4의 VerifyBamID QC는 모두 정상 종료 결과를 확보했다. 회사에서 남은 QC 오류는 비교 대상 밖 KOR-101(gd3)·KOR-102(gd4)다. 회사 기본 run 24샘플은 종료했지만 QC까지 24/24 성공한 것은 아니다.

공개 BGISEQ500·Element-AVITI·Hiseq-300x·MGISEQ2000-PCRfree는 아직 실행 중이다. 이 표는 현재 완료된 비교이며 F1 차이만으로 회사 품질 순위나 원인을 단정하지 않는다.

gd4 3건은 SGE exit 0·ALL DONE·SNP/INDEL PASS 행·truth TP+FN·입력 파일 불변을 확인했다. [gd4 precision/recall/F1·설정·해시](../reference/2026-09-27-gd4-happy.json) · [gd1/2 6건](../reference/2026-09-27-gd12-happy.json) · [기존 7건](../reference/2026-09-26-gd23-DONE-and-retry.json).
