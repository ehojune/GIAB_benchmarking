# Illumina-250PE HG002 verifybamID 한정 복구

2026-09-25 19:59 KST. Codex가 **156781**을 한 번 제출했다. 완료 여부는 다음 점검에서 확인한다.

- 원 실행은 18:51 `VerifyBamID`가 표를 쓴 뒤 segmentation fault로 종료했다. `.selfSM`과 `.Ancestry`는 있으나 정상 종료 기록·checksum·QC 링크가 없어 성공으로 처리하지 않았다. 원 `error_list.txt`는 보존한다.
- 입력 BQSR exit 0, samtools quickcheck 0, HG002 SM·BAM/index 존재 확인. 기존 도구·BAM·reference·SVD를 그대로 쓰고 스레드만 4→1로 줄였다. 원인은 아직 확정하지 못했다.
- 별도 폴더 `/BiO/scratch/ehojune/GIAB_benchmark/repairs/verifybamID-Illumina250PE-HG002-20260925`에 원 로그·표를 복사했다. SGE 1슬롯·8G·최대 1시간, 도구 제한 45분. `submission-attempt.json`으로 중복 제출을 막는다.
- 기존 9개 master·원 결과·공유 pipeline에는 쓰지 않는다. 성공해도 종료코드, sample ID, 유효한 SNP/read 수·FREEMIX, 입력 전후 stat, SHA256을 확인한 후 반영한다. 실패하면 반복 재시도하지 않는다.

다음 확인: qstat/qacct `156781`, `isolated_attempt.exitcode`, `RESULT.txt`, `validation.json`, `SHA256SUMS`, `input.before.stat`/`input.after.stat`. 원 master와 쓰기 충돌이 없을 때 결과를 연결하며, 전체 세트 완료와 구분한다.
