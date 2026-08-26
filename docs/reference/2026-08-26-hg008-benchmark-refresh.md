# HG008 benchmark 확인 — 2026-08-26

조회용 근거다. 현재 권고만 README와 `next_step`에 반영한다.

| 구분 | 현행판 | 공식 근거 | 평가 권고 |
|---|---|---|---|
| somatic SNV/INDEL | draft V0.3 (2026-04-25) | https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data_somatic/HG008/Liss_lab/analysis/NIST_HG008-T_somatic-smvar_DraftBenchmark_V0.3-20260425/README.md | aardvark; rtg vcfeval·hap.py도 검증됨 |
| somatic SV/CNV | draft V0.5 (2026-03-18) | https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data_somatic/HG008/Liss_lab/analysis/NIST_HG008-T_somatic-stvar-CNV_DraftBenchmark_V0.5-20260318/README.md | SV는 Truvari v5.0+; CNV best practice는 미정 |
| HG009 | benchmark 미공개 | https://www.nist.gov/programs-projects/cancer-genome-bottle | passage·clone·GIAB WDL 교차검증, truth 성능으로 보고하지 않음 |

V0.5 SV는 batch 0823p23이면 clonal+subclonal BED, 다른 passage면 clonal BED를 쓴다.
