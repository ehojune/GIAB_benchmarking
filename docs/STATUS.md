# GIAB 현황

2026-09-26 19:50–20:00 KST 확인. **gd2·gd3는 DONE=Success이나 VerifyBamID 각 3건 실패. 일반 regermline은 253작업을 다시 시작해 중지했고, 제거된 fastp 보고서만 복원 중이다.** [근거·조치](runs/2026-09-26-gd23-regermline-and-DONE.md).

| 작업 | 현재 상태 | 다음 한 번의 행동 |
|---|---|---|
| 업체 gd1~4 재분석 | gd2 156761·gd3 156762는 exit 0·Success지만 VerifyBamID 각 3건 실패. gd1/4 **156760/156763 실행**, 186/147 of 265 rule(시간 비율 아님), 각각 VerifyBamID 오류 2건 | 일반 regermline **156794/156795는 fastp부터 253작업이라 중지**. CRAM/gVCF·원자료 변경 없음. 제거된 fastp JSON/HTML 12샘플분만 **156796/156797 복원 중**. 완료 검증 후 오류 단계 재개 범위 판단 |
| 업체 + 공개 HG002/3/4 비교 | **156787–156793 모두 완료**: gd3 HG002/3/4 + 공개 NovaSeq6000 trio·NovaSeqX HG002. qacct 0·ALL DONE·7 summary 직접 확인 | 기존 hap.py/v4.2.1 결과 회수 완료, [수치 근거](reference/2026-09-26-gd23-DONE-and-retry.json). **gd3 HG002 오염 QC 미완료 표시 유지**. 나머지 회사 비교 9건 대기. 옛 업체 캐시 미사용 |
| GIAB 숏리드 기본 run | **155526–155528, 156690 `r`**, 활성 Mark 로그 12개 모두 증가. 추가 20 set·53샘플 미제출 | 현재 잡 유지, 종료·산출물·간단 QC 확인. 일괄 추가 제출하지 않음 |
| Illumina-250PE 재시도 | **156786 exit 1·Error 유지**. Manta HG002/3/4 SV gap, HG002 verifybamID QC gap. HG004 verifybamID 성공. HG003 gather·변이 집계는 계산 후 기존 링크 충돌 | 추가 재시도 없음. SNP/INDEL 최소 QC 통과, **세트 전체 완료는 아님**. [판정·검증](runs/2026-09-26-illumina-regermline-retry.md#종료-결과와-판정-09391000) |
| GIAB PacBio·ONT | 담당 보고상 PacBio verify 49/49, 소변이 19런·SV 5런. ONT HG002/3/4 기본 run·QC·채점 완료 | 기존 결과를 비교표에 연결. **업체 롱리드는 수령 대기** |
| 다운로드 | 15:54 확인 BioSkryb×UG100 **1.951/5.221TB(37.37%)**, 직전보다 +1.169TB. 크기 일치 95·부분 6·미수령 375개, wget 6개 모두 증가. 기존 유효 MD5 마커 50/제공 238개 | 전체 수령 뒤 크기·제공 MD5 확인, 카탈로그 반영. 기존 목록 81,302개와 역사적 FAIL·NOREF 보존. [이번 근거](reference/2026-09-26-1553-status-evidence.json) |
| GIAB somatic / bioinfo 개발 | **HG008 13쌍 전장·채점·QC 완료 유지**. 156747–156779 중 해당 29잡 qacct 0, VCF QC 13/13, summary 28개. QC 표 해시 불변 | 추가 실행 없이 닫음. matched 2쌍은 precision·recall, borrowed 11쌍은 recall만 해석. [결과·한계](runs/2026-09-25-somatic-wgs.md). 범용 bioinfo 개발은 별도 |

공통 백업은 `/BiO/scratch/dyl/kbb/G000/backup/20260925-company-reset`, 재구성 기록은 `G000/.company-reset-20260925.json`. 원자료·샘플 정본·서버 엑셀을 유지했다. 카탈로그·Excel은 비교 점수와 다운로드 완료가 없어 직전 반영분 유지(최근 442행 × 51열 대조 차이 0).

가벼운 정리 3건은 완료했다. PacBio 요약 PR #74와 BioSkryb 수령 PR #75는 main 반영. [ONT 비교](https://github.com/ehojune/GIAB_benchmarking/blob/6a18594/docs/reference/2026-09-25-ont-guppy324-vs-345-same-flowcell.md)·[MD5 후속 대조](https://github.com/ehojune/GIAB_benchmarking/blob/5b2c18b/docs/runs/2026-09-25-md5-verification-followup.md)는 담당 브랜치에 있으며 **PR #68·#69 병합·반복 리뷰 보류**다.

**Codex가 단독으로 4시간 점검·보고와 승인된 후속 작업을 맡는다.** 현재 Claude 네 담당·임시 총괄은 idle. 새 Claude 실행·중복 자동화 없음. 남은 일은 [backlog](backlog.md), 과거 이력은 [조회용 자료](reference/README.md)에 있다.
