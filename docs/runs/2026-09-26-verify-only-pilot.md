# VerifyBamID만 재시도

2026-09-26 20:16 KST. 사용자 요청에 따라 Codex가 **156798**을 제출했다. gd3 HG002(`C000000300400000G0x1`) 한 샘플이며 현재 CRAM→임시 BAM 변환 중이다. 정렬·변이 호출을 다시 하지 않는다.

- 원래 VerifyBamID 실행 파일, GRCh38 reference, 1000g SVD, `--NumThread 4`를 유지한다. 입력·출력 경로만 별도 복구 폴더로 바꾼다.
- BAM quickcheck·인덱스·read group·기존 flagstat와 모든 리드 수 일치 확인 뒤 실행한다. 성공은 도구 exit 0, 결과표 검사, `VERIFIED.json`, SGE qacct 0을 함께 요구한다.
- 원자료·기존 결과에는 쓰지 않는다. 성공 검증 후 해당 QC 결과를 반영하고 나머지 5샘플에 적용한다. 실패 시 `FAILED.json`·단계별 종료코드를 보존한다.
- 8슬롯·16GB·최대 4시간. 공유 파이프라인 수정·새 도구·추가 연구 없음. 전체 regermline은 반복하지 않는다.

서버 기록: `/BiO/scratch/dyl/kbb/G000/backup/20260926-verify-only-pilot/`의 `pilot.py`, `manifest.json`, `job.json`, `stage.json`. 중복 제출 방지용 `submit-attempt.json`을 지우지 않는다.

fastp 보고서 복원 **156796/156797**은 별도 진행 중이다. [원래 실패 및 전체 재시도 중지 근거](2026-09-26-gd23-regermline-and-DONE.md) · [이번 preflight·실행 증거](../reference/2026-09-26-verify-only-pilot.json).
