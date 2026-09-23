# 2026-09-23 22:05 — phase1 제출 셋 (PR #38 merge 직후)

서버 `~/GIAB_benchmarking` 을 22d544f 로 pull 한 뒤 한 번의 접속으로 넣었다.
산출 위치: `$INFRA/adhoc/2026-09-23/` (`$INFRA` = `processed_data_ehojune/_infra`).

| jobid | 무엇 | 명령 |
|---|---|---|
| 156590 | 구간별 hap.py **시험 1런** (HG002 Revio) — 층화 메모리 실측용 | `STRAT=1 bash phase1_pacbio_hifi/scripts/60_benchmark.sh HG002.PacBio_HiFi-Revio_20231031` |
| 156591 | ts/tv 구간 분할, germline 19런 | `qsub_task.sh p1tstv -s 2 -- env TSV=$INFRA/adhoc/2026-09-23/phase1_tstv_regions.tsv bash phase1_pacbio_hifi/scripts/62_tstv_regions.sh` |
| 156592 | 156072(SC28) 뒤: 전 런 verify + `35_review_qc.py --pass-counts` + MultiQC | `qsub_task.sh p1qc -s 4 -w 156072 -- bash -c '... 30_verify_outputs.sh > verify_all.txt; 35_review_qc.py --pass-counts --tsv qc_review_phase1.tsv > qc_review_phase1.txt; 36_multiqc_all.sh > multiqc_all.txt'` |

제출 시점 노드: 허용 4대 중 셋(octopus-2-8/2-9, shepherd-1-9)은 숏리드 `regermline` 60슬롯, shepherd-1-8 은
SC28(30) + ONT 156587(30). 156590 은 SC28 이 끝나야 뜬다.

같은 접속에서 확인한 것: smvar V0.3 의 BED 셋은 zip 안에만 있다(`unzip -l`).

다음: 156590 maxvmem 을 보고 `BENCH_STRAT_SLOTS` 를 정해 나머지 18런 제출.
