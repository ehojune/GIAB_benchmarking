# 남은 오류 제한 재시도 — 2026-09-27 21:08 KST

사용자가 실패한 명령의 재실행·작은 오류 수정과 같은 명령을 최대 2회 시도하도록 승인했다. **이번 승인 이후 항목별 최대 2회**이며 과거 시도와 구분한다. 기존 점검 `giab-4`는 3시간으로 변경했다.

| 단계·샘플 | 1차 잡 |
|---|---|
| VerifyBamID gd3 KOR-101 | 156821 |
| VerifyBamID gd4 KOR-102 | 156822 |
| VerifyBamID Illumina HG002 | 156823 |
| Manta Illumina HG002 | 156824 |
| Manta Illumina HG003 | 156825 |
| Manta Illumina HG004 | 156826 |

원래 실행파일·BAM·참조를 사용한다. Verify는 원래 4스레드, Manta는 원래 `configManta.py` → `runWorkflow.py -j 10` → inversion 변환·기존 필터다. 새 폴더에 출력하며 회사 BAM은 앞서 검증한 임시 복원본을 재사용한다. 재정렬·전체 regermline은 없다.

입력 여섯 건의 quickcheck·SM을 확인했고 정상 outcome·BAM·인덱스·참조의 stat과 실행파일 해시를 기록했다. 성공은 종료코드·검증 표식·출력 QC를 함께 확인한 뒤 반영한다. 1차 실패가 확정된 항목만 2차 제출하며 실행 중·성공·불확실한 제출은 반복하지 않는다. 21:10 여섯 잡 모두 실행 중이며 Verify 계산·Manta workflow 진입을 확인했다. 아직 복구 완료 판정은 하지 않았다.

서버: `/BiO/scratch/dyl/kbb/G000/backup/20260927-bounded-retries/<항목>/attempt-1/`. `retry.py`는 항목별 두 폴더까지만 허용한다. `job.json`, `stage.json`, `VERIFIED.json`/`FAILED.json`에 진행·결과를 남긴다. [명령·입력·해시·잡 근거](../reference/2026-09-27-bounded-retries.json).
