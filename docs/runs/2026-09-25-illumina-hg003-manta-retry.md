# Illumina-250PE Manta 미해결 기록

2026-09-25 19:52 KST 확인. **HG003 별도 재시도도 실패했다.** 21:44 사용자 지시로 이후에는 실패 중간 폴더를 정리하고 [native regermline156782](2026-09-25-illumina-regermline-cleanup.md)로 재개한다. 기존 master `155529`는 나머지 분석을 진행 중이다.

| 실행 | 확인 결과 |
|---|---|
| HG003 원 실행 | 07:53 `GenerateSVCandidates / generateCandidateSV_0000` signal 11, workflow exit 1 |
| HG003 별도 156780 | 16:04:14 시작, 16:57:46 종료. qacct `failed=0`, **exit_status=1**. 같은 태스크 signal 11, 최종 VCF 없음 |
| HG002 원 실행 | 18:55 같은 태스크 signal 11, workflow exit 1 |

HG003은 동일 Manta 1.6.0·BAM·GRCh38로 병렬도만 10→1로 낮췄다. SGE 1슬롯·32G·4시간, workflow 제한 3시간이었다. 53분 만에 실패했으므로 시간 제한 종료가 아니다. 병렬도 변경으로 해결되지 않았으며 원인은 확정하지 못했다.

입력 BQSR은 exit 0, samtools 1.20 quickcheck도 0이고 SM이 일치한다. BAM 70,610,086,661 bytes와 index의 크기·mtime·inode가 재시도 전과 19:55 확인에서 동일했다. 이를 전체 BAM 내용 검증으로 해석하지 않는다.

근거 폴더: `/BiO/scratch/ehojune/GIAB_benchmark/repairs/manta-Illumina250PE-HG003-20260925`. `preflight.json`, `job.sh`, `submission-result.json`, `isolated_attempt.exitcode`, `ended_at.txt`, `run/workflow.error.log.txt`를 보존했다. 원 출력·오류 기록·공유 pipeline은 그대로다.

두 샘플의 SV 결과는 미완료다. 기존 잡이 끝난 뒤 승인된 native 재개만 수행한다. 새 caller·원인 연구로 확대하지 않는다. 다른 단계가 끝나면 SNP/INDEL 비교 가능 여부를 해당 산출물과 QC로 따로 판단한다.
