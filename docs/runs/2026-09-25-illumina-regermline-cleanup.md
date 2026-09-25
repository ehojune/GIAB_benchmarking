# Illumina 실패 중간산물 정리 후 regermline

2026-09-25 21:51 제출. 사용자 지시로 **156782**를 한 번 등록했다. **현재 `hqw`이며 정리·재분석은 아직 시작하지 않았다.** 기존 `155529`가 종료돼야 실행된다.

- 대상: `/BiO/scratch/dyl/kbb/G000/GIAB-publicData-Illumina-250PE`.
- 기존 잡은 76/118 rule 진행 중이다. 공유 Snakefile의 시작 코드가 세트 `.tmp`를 지우므로 동시에 실행하지 않는다. 시작 시에도 동일 세트의 다른 잡과 이전 잡의 종료 회계를 확인한다.
- 실패한 `tmp/17.Manta/<sample>`만 백업으로 옮겨 실행 경로를 비운다. 현재 HG002/3 두 폴더에는 최종 VCF가 없다. HG004는 실행 시 실패가 확인된 경우에만 같은 조건을 적용한다. 성공 결과는 유지한다.
- HG002 verifybamID의 실패한 표·로그도 보존 후 원 경로에서 비워 재계산한다. 독립 재시도156781은 exit139이며 성공으로 간주하지 않는다. 새 종류의 오류나 부분 최종 산출물이 발견되면 정리 전에 중단한다.
- 원자료, BQSR BAM/index, 다른 완료 결과는 유지한다. 이동 전후 BAM 크기·mtime·inode를 대조하고 기존 `error_list.txt`·`__DONE__`를 백업한다.
- Java17 환경에서 기존 `/BiO/scratch/dyl/kbb/zz.code/regermline.sh`를 그대로 실행한다. `--rerun-incomplete --rerun-triggers mtime --keep-going`, SGE60슬롯·기존300G 설정이다. 공유 pipeline 수정은 없다.

보존·실행 기록: `/BiO/scratch/dyl/kbb/G000/backup/20260925-illumina-regermline`.
`job.sh`, `cleanup.py`, `preflight.json`, `submission-result.json`을 준비했다. 실행 시 `preserved/`, `cleanup-complete.json`, `native-regermline-started.txt`, `runner.exitcode`가 생긴다.

다음 점검: qstat/qacct156782, 정리 기록, 이번 실행의 `__DONE__`·`error_list.txt`, Manta 최종 VCF·필터 결과·outcome 링크와 HG002 QC를 함께 확인한다. 큐 등록이나 잡 exit0만으로 완료 처리하지 않는다.
