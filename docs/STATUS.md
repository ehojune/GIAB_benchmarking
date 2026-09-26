# GIAB 현황

2026-09-27 04:17 KST 기본 잡 확인, 후속 QC는 아래 근거 시각 기준. **회사·공개 비교 13건 완료, BioSkryb×UG100 수령·검증 완료.** [점수표](reports/2026-09-27-shortread-thirteen.md) · [이번 근거](reference/2026-09-27-0404-status-evidence.json).

| 작업 | 현재 상태 | 다음 한 번의 행동 |
|---|---|---|
| 업체 기본 run | gd1/2/3 exit 0·Success·변이 최소 QC 확인. **gd4 156763 실행, 186→190/265 rule**, Mark 완료 23/24, 남은 로그 증가 | gd4 종료 후 산출물·최소 QC 확인, 비교 3건과 실패 QC 처리 |
| VerifyBamID 복구 | 단독 7건 중 **4건 성공·정본 반영**, 3건은 SIGSEGV 재발. 이후 gd2 HG002 1스레드 재시도도 성공·반영해 누적 6건 복구. 원자료·CRAM·변이·실패 로그 보존 | **gd2/gd3 KOR-101 156813/156814**: 성공한 1스레드 방식으로 재시도 실행. 종료 후 QC만 검증·반영 |
| HG002/3/4 비교 | **gd1/2/3 9건 + 공개 4건 = 13건 완료**. 새 6잡 156806–156811 모두 qacct 0·ALL DONE·summary 검증 | gd2 HG002 QC gap 해소. gd4 비교 3건 대기. 회사 순위·원인은 단정하지 않음 |
| 공개 숏리드 기본 run | **155526–155528, 156690 r**, CPU 증가·활성 Mark 로그 12개 모두 증가 | 현재 잡 유지, 종료·산출물·간단 QC 확인. 추가 20 set·53샘플 일괄 제출하지 않음 |
| Illumina-250PE | 156786 exit 1·Error. Manta HG002/3/4 SV gap, HG002 Verify QC gap, HG003 기존 링크 충돌 유지 | 추가 실행 없음. SNP/INDEL 최소 QC 통과지만 세트 전체 완료 아님. [기록](runs/2026-09-26-illumina-regermline-retry.md) |
| 다운로드 | **BioSkryb×UG100 476/476 파일, 5.22 TB 수령**. 크기 전부 일치, 제공 MD5 238개 직접 재계산 일치. 나머지 238개는 MD5 참조 없음 | 카탈로그 1행·README·Excel 반영. 수령 작업 닫음. [검증](runs/2026-09-27-bioskryb-download-complete.md) |
| PacBio·ONT / somatic | 기본 정리 완료 유지. HG008 somatic **13쌍 QC·채점 완료**, 해당 29잡 exit 0·QC 해시 불변·summary 28개 | 기존 결과 보존. **업체 롱리드는 수령 대기**. 범용 bioinfo 개발은 별도 |

fastp 보고서 12샘플 복원은 검증 완료. 회사 정본·서버 엑셀·원자료와 공통 백업 `G000/backup/20260925-company-reset`은 유지한다. 전체 regermline을 반복하지 않는다. 비교 점수는 위 보고서에, 자료 보유 상태는 카탈로그·Excel에 둔다.

Codex가 4시간 점검·후속 실행을 맡는다. Claude 네 담당·임시 총괄은 idle이며 새 위임·타이머 없음. PR #68/#69/#78은 09-26 별도 담당이 사용자 승인으로 병합한 상태; 이번 점검에서 PR 병합·리뷰 요청 없음. [범위](SCOPE.md) · [남은 일](backlog.md).
