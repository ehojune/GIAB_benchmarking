# 숏리드 비교 — 첫 7건

2026-09-26 완료된 gd3 3개·공개 4개. 국통바빅 gVCF → GATK 4.6.1.0 GenotypeGVCFs → hap.py 0.3.12, GIAB v4.2.1 GRCh38 chr1–22/no-inconsistent 영역. 모든 잡 qacct exit 0·ALL DONE·summary 확인.

| 자료 | SNP F1 | INDEL F1 |
|---|---:|---:|
| gd3 HG002 | 0.976556 | 0.974389 |
| gd3 HG003 | 0.976670 | 0.976105 |
| gd3 HG004 | 0.976358 | 0.974597 |
| 공개 NovaSeq6000 30x HG002 | 0.980786 | 0.980077 |
| 공개 NovaSeq6000 30x HG003 | 0.980786 | 0.980185 |
| 공개 NovaSeq6000 30x HG004 | 0.980805 | 0.980090 |
| 공개 NovaSeqX 30x HG002 | 0.978631 | 0.979057 |

**해석 범위:** 나머지 3회사 비교는 아직 없다. gd3 HG002는 VerifyBamID 비정상 종료로 오염 QC 미완료이며, 전체 QC 통과로 표시하지 않는다. 이 표만으로 회사 품질 순위나 차이의 원인을 단정하지 않는다.

세부 precision·recall·원본 summary 경로와 해시는 [실행 근거](../reference/2026-09-26-gd23-DONE-and-retry.json)에 있다. gd3는 교정된 새 입력 결과이며 옛 업체 캐시는 사용하지 않았다.
