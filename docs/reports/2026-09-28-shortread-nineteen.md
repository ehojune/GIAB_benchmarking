# 숏리드 비교 — 완료 19건

2026-09-28 06:07 KST 검증. **4회사 HG002/3/4 12건과 공개 비교군 7건을 채점했다.** 정본 국통바빅 gVCF → GATK 4.6.1.0 GenotypeGVCFs → hap.py 0.3.12. GIAB v4.2.1 GRCh38 chr1–22/no-inconsistent 조건이다.

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
| 공개 Illumina250PE HG002 | 0.981207 | 0.971749 |
| 공개 Illumina250PE HG003 | 0.980931 | 0.967494 |
| 공개 Illumina250PE HG004 | 0.981327 | 0.969275 |

회사 QC 24/24, Illumina Verify·Manta 각 3/3 복구 완료. 새 Illumina 채점은 156834–156836 exit 0·ALL DONE·SNP/INDEL PASS·truth TP+FN·입력 보존·인덱스 조회를 확인했다. 이전 16건 점수는 바뀌지 않았다.

공개 BGISEQ500·Element-AVITI·Hiseq-300x·MGISEQ2000-PCRfree는 기본 분석 중이다. F1 차이만으로 회사 품질 순위나 원인을 단정하지 않는다.

[새 3건의 precision/recall·설정·해시](../reference/2026-09-28-0600-status-evidence.json) · [이전 16건](2026-09-27-shortread-sixteen.md) · [카탈로그 정리](../reference/2026-09-28-public-shortread-catalog.json).
