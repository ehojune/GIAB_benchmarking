# Illumina-250PE HG003 Manta 단일 복구

2026-09-25 16:05 KST. 담당은 Codex 총괄 한 명이다. **156780 실행 중이며 아직 복구 완료가 아니다.**

- 원래 잡 `155529`의 HG003 Manta `GenerateSVCandidates`가 07:53에 signal 11로 종료했다. workflow exit 1과 `error_list.txt` 1건을 확인했다. 원인은 아직 확정하지 않았다.
- 입력 BQSR는 06:55에 exit 0. 70,610,086,661-byte BAM·인덱스가 있고 samtools 1.20 `quickcheck` exit 0, 헤더 SM도 HG003으로 일치했다.
- 기존 Manta 1.6.0·동일 BAM·동일 GRCh38 reference로 별도 폴더에서 한 번 실행한다. 병렬도만 10→1로 낮췄다. SGE 1슬롯·32G·최대 4시간, workflow 자체 제한 3시간이다.
- 16:04:01 제출, 16:04:14 `shepherd-1-1`에서 시작. 16:04:51 초기 작업 진행·새 오류 로그 0-byte 확인.
- 원자료, 원래 Manta 폴더, `error_list.txt`, 공유 pipeline과 실행 중인 9개 master는 변경하지 않았다. 실패 로그는 복구 폴더에 복사했다.

서버 복구 폴더:
`/BiO/scratch/ehojune/GIAB_benchmark/repairs/manta-Illumina250PE-HG003-20260925`

명령·검증 근거는 폴더의 `job.sh`, `preflight.json`, `submission-result.json`, `cluster.log`에 있다. 입력은 `/BiO/scratch/dyl/kbb/G000/GIAB-publicData-Illumina-250PE/tmp/09.bqsr/GIAB-publicData-Illumina-250PE-HG003_v1.1.0.bam`이다.

다음 점검은 qacct·`isolated_attempt.exitcode`·`run/workflow.exitcode.txt`·`RESULT.txt`·VCF/인덱스·bcftools stats·입력 전후 stat을 함께 확인한다. 성공해도 기존 분석에 자동 덮어쓰지 않는다. 원래 master와 쓰기 충돌이 없을 때 후처리 산출물·링크·실패 기록을 보존하며 반영하고 완료 판정을 다시 확인한다. 같은 오류가 반복되면 추가 재시도 없이 미해결 항목으로 남긴다.
