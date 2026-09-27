# 재부팅 후 점검 — 2026-09-27 20:55 KST

| 구분 | 확인·조치 |
|---|---|
| 완료 | 회사 24샘플 기본 run 종료. gd4 비교 156815–156817 회수로 **16건 비교 완료** |
| 이번 복구 | gd4 HG002(156819)·HG004(156820) 정상 종료·파일 해시·48개 보호 경로 불변 확인. 20:51 QC 파일·checksum·analyze_meta 링크 반영, 기존 실패 파일 백업 |
| 남은 QC | 회사 Verify 실패 11건 중 9건 복구. gd3 KOR-101·gd4 KOR-102는 1스레드에서도 −11. 정본 QC 22/24 검증 |
| 실행 | 공개 155526–155528·156690. CPU·Mark 로그 12개 모두 증가, PC 재부팅 영향 없음 |
| 기존 오류 | Illumina Manta 3건의 workflow.error.log.txt에서 taskExitCode −11 재확인. HG002 Verify도 1스레드 재시도 156781에서 139. 같은 명령 추가 제출 없음 |
| 완료 유지·대기 | 다운로드·PacBio·ONT 기본 정리, HG008 somatic 13쌍 완료. 업체 롱리드 수령 대기 |

현재 사용자가 직접 풀어야 할 접속·승인 문제는 없다. 재부팅 뒤 HIWARE 포트가 바뀌었으며 호스트 확인 후 nbbcluster2로 접속했다. 회사 전체 regermline은 재제출하지 않았다.

[16건 비교표](../reports/2026-09-27-shortread-sixteen.md) · [종료코드·QC 반영·현재 큐·오류 경로](../reference/2026-09-27-reboot-status-evidence.json).

QC 반영 근거: `/BiO/scratch/dyl/kbb/G000/backup/20260927-gd4-verify-only/{C000000400400000G0x1,C000000400600000G0x1}/PROMOTED.json`. 남은 회사 실패는 같은 backup의 `C000000400200000G0x1/FAILED.json` 및 `backup/20260927-verify-one-thread/C000000300100000G0x1/FAILED.json`이다. 프로그램 실패이며 오염 양성 판정이 아니다.
