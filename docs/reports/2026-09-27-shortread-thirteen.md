# 숏리드 비교 — 완료 13건

> 과거 04시 스냅샷. 최신 표는 [완료 16건](2026-09-27-shortread-sixteen.md)이다.

2026-09-27 04:17 KST. gd1·gd2 6건이 추가로 정상 종료했다. 새 입력의 국통바빅 gVCF → GATK 4.6.1.0 GenotypeGVCFs → hap.py 0.3.12, GIAB v4.2.1 GRCh38 chr1–22/no-inconsistent 영역. 옛 회사 캐시는 쓰지 않았다.

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
| 공개 NovaSeq6000 30x HG002 | 0.980786 | 0.980077 |
| 공개 NovaSeq6000 30x HG003 | 0.980786 | 0.980185 |
| 공개 NovaSeq6000 30x HG004 | 0.980805 | 0.980090 |
| 공개 NovaSeqX 30x HG002 | 0.978631 | 0.979057 |

**아직 최종 회사 순위표는 아니다.** gd4 3건은 기본 run 종료를 기다린다. gd2 HG002 VerifyBamID도 1스레드 재시도 후 정상 종료해 QC에 반영했다. F1 차이의 원인이나 회사 품질 순위를 단정하지 않는다.

새 6건 모두 SGE exit 0·ALL DONE·summary의 SNP/INDEL PASS 행을 확인했다. [새 6건 precision·recall·F1와 경로·해시](../reference/2026-09-27-gd12-happy.json) · [기존 7건 근거](../reference/2026-09-26-gd23-DONE-and-retry.json).
