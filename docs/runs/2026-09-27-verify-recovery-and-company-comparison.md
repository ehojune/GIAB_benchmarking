# 실패 QC 복구와 회사 비교 후속

2026-09-27 00:13–00:29 KST. 실행 담당은 Codex다.

- **완료:** fastp 보고서 12샘플 복원. 156796/156797 exit 0·RESTORED.json, 정본 JSON/HTML 해시와 BAM primary 수 대조 통과. 기존 CRAM·변이 결과 보존.
- **복구 성공:** gd3 HG002 VerifyBamID 156798 exit 0. BAM 복원·리드 수·read group·결과표 확인 후 00:23 정본 표·checksum·QC 링크 반영. FREEMIX 8.33497e-06. 원래 실패 파일은 별도 보존.
- **재시도:** gd1 HG002/HG004 = 156799/156800, gd2 KOR-101/HG002/HG004 = 156801–156803, gd3 KOR-101/KOR-103 = 156804/156805. 같은 도구·참조·4스레드 설정, 샘플당 8슬롯·16GB·4시간. 현재 CRAM→임시 BAM 변환 중. 성공 전 정본 QC를 바꾸지 않는다.
- **비교 제출:** gd1 HG002/3/4 = 156806–156808, gd2 HG002/3/4 = 156809–156811. 12샘플 CRAM quickcheck·gVCF 샘플/인덱스/EOF·fastp/BAM 리드 수 검사 통과, DRY READY 6/6 뒤 기존 hap.py/v4.2.1 스크립트로 제출했다. 새 gVCF를 사용하며 QC 재시도 중인 샘플은 결과 확정 때 재확인한다.

서버 기록:
- `G000/backup/20260926-verify-only-pilot/PROMOTED.json` — 1건 반영 근거.
- `G000/backup/20260927-verify-only/` — `batch.py`, `jobs.json`, 샘플별 `VERIFIED.json` 또는 `FAILED.json`. 성공은 도구·SGE exit 0과 출력 검증을 함께 요구한다.
- `07_happy/submission_gd12_20260927.json`·`.attempt` — 비교 제출 기록. **어느 제출 스크립트도 다시 실행하지 않는다.**

기본 gd1은 23:17 exit 0·Success, Verify 원래 실패 2건을 위 복구로 처리한다. gd4·공개 4잡은 CPU·로그 증가. 완료 표시만으로 단계 오류를 무시하지 않는다. [이번 근거](../reference/2026-09-27-0030-status-evidence.json).
