# GIAB 현황

2026-09-27 00:28 KST 후속 잡 확인, 기본·다운로드는 00:16 확인. **fastp 12샘플 보고서 복원 완료, Verify 단독 1건 성공·반영, 나머지 7건 재시도와 회사 비교 6건 실행.** [이번 조치](runs/2026-09-27-verify-recovery-and-company-comparison.md) · [근거](reference/2026-09-27-0030-status-evidence.json).

| 작업 | 현재 상태 | 다음 한 번의 행동 |
|---|---|---|
| 업체 gd1~4 재분석 | gd1도 23:17 종료: **gd1/2/3 exit 0·Success·변이 최소 QC 확인**. gd4 156763은 186/265 rule, 진행 중이며 Verify 오류 3건 | fastp 12샘플 복원 검증 완료. gd3 HG002 Verify 복구·정본 반영. **나머지 7건 156799–156805 실행**. 종료 후 검사 결과만 반영; 전체 regermline 반복 안 함 |
| 업체 + 공개 HG002/3/4 비교 | 기존 **7건 완료**. **gd1·gd2 trio 6건 156806–156811 실행**, 새 gVCF로 GenotypeGVCFs 시작. 옛 업체 캐시 미사용 | QC 재시도와 별도로 비교 계산 진행; QC 미완료 샘플은 결과 확정 때 재확인. gd3 HG002 QC gap 해소. [첫 점수표](reports/2026-09-26-shortread-first-seven.md). gd4 비교 3건 대기 |
| GIAB 숏리드 기본 run | **155526–155528, 156690 `r`**, 활성 Mark 로그 12개 모두 증가. 추가 20 set·53샘플 미제출 | 현재 잡 유지, 종료·산출물·간단 QC 확인. 일괄 추가 제출하지 않음 |
| Illumina-250PE 재시도 | **156786 exit 1·Error 유지**. Manta HG002/3/4 SV gap, HG002 verifybamID QC gap. HG004 verifybamID 성공. HG003 gather·변이 집계는 계산 후 기존 링크 충돌 | 추가 재시도 없음. SNP/INDEL 최소 QC 통과, **세트 전체 완료는 아님**. [판정·검증](runs/2026-09-26-illumina-regermline-retry.md#종료-결과와-판정-09391000) |
| GIAB PacBio·ONT | 담당 보고상 PacBio verify 49/49, 소변이 19런·SV 5런. ONT HG002/3/4 기본 run·QC·채점 완료 | 기존 결과를 비교표에 연결. **업체 롱리드는 수령 대기** |
| 다운로드 | BioSkryb×UG100 **4.339/5.221TB(83.11%)**, 직전보다 +1.143TB. 크기 일치 199·부분 6·미수령 271개, wget 6개 모두 증가. 기존 유효 MD5 마커 102/제공 238개 | 수령 완료 뒤 크기·제공 MD5 검증, 카탈로그·Excel 반영. 아직 다운로드 완료 아님 |
| GIAB somatic / bioinfo 개발 | **HG008 13쌍 전장·채점·QC 완료 유지**. 156747–156779 중 해당 29잡 qacct 0, VCF QC 13/13, summary 28개. QC 표 해시 불변 | 추가 실행 없이 닫음. matched 2쌍은 precision·recall, borrowed 11쌍은 recall만 해석. [결과·한계](runs/2026-09-25-somatic-wgs.md). 범용 bioinfo 개발은 별도 |

공통 백업은 `/BiO/scratch/dyl/kbb/G000/backup/20260925-company-reset`. 재구성 기록은 `G000/.company-reset-20260925.json`. 원자료·샘플 정본·서버 엑셀 유지. 카탈로그·Excel은 자료 보유/처리 상태를 유지하며 비교 점수는 위 별도 보고서에 둔다. 다운로드 완료로 미리 표시하지 않는다.

가벼운 정리 3건은 완료했다. PacBio 요약 PR #74, BioSkryb 수령 PR #75, [MD5 후속 대조](runs/2026-09-25-md5-verification-followup.md) PR #69는 main 반영(#69는 09-26 사용자 승인). [ONT 비교](https://github.com/ehojune/GIAB_benchmarking/blob/6a18594/docs/reference/2026-09-25-ont-guppy324-vs-345-same-flowcell.md)는 담당 브랜치에만 있다. PR #68(Java 17 제출 래퍼)도 09-26 사용자 승인으로 main 반영.

**Codex가 단독으로 4시간 점검·보고와 승인된 후속 작업을 맡는다.** 현재 Claude 네 담당·임시 총괄은 idle. 새 Claude 실행·중복 자동화 없음. 남은 일은 [backlog](backlog.md), 과거 이력은 [조회용 자료](reference/README.md)에 있다.
