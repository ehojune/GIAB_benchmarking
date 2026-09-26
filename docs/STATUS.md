# GIAB 현황

2026-09-26 15:53–16:13 KST 확인. **gd3 주요 산출물 검사 통과, 오염 QC 3건은 gap. gd3·공개 비교 7건 실행 중.** 나머지 기본 7잡은 CPU·로그가 증가했다. [검증·제출 기록](runs/2026-09-26-gd3-qc-and-comparison.md). 완료 기준은 [SCOPE](SCOPE.md).

| 작업 | 현재 상태 | 다음 한 번의 행동 |
|---|---|---|
| 업체 gd1~4 재분석 | gd3 **156762 종료**, 265/265·qacct 0·Success지만 verifybamID **KOR-101/103·HG002 실패**. 6샘플 CRAM/gVCF·리드 수 검사 통과, 평균 깊이 29.24–30.87×. gd1/2/4 **156760/156761/156763 `r`**, 80/225/99 of 265 rule(시간 완료율 아님). 세 회사 verifybamID 오류 5건 | 진행 잡 유지. 종료 뒤 실제 산출물 QC 확인. gd3 QC 복구 dry-run은 원자료부터 253작업을 요구해 **실행하지 않음**. 실패 표를 성공으로 쓰지 않음 |
| 업체 + 공개 HG002/3/4 비교 | **156787–156793 `r`**: gd3 HG002/3/4 + 공개 NovaSeq6000 trio·NovaSeqX HG002. 기존 hap.py/v4.2.1. gd3 genotyping은 chr2까지 진행, 공개 4개 hap.py 로그 증가 | Codex 단일 담당. 종료코드·ALL DONE·SNP/INDEL summary 확인. **gd3 HG002는 오염 QC 미완료를 붙여 해석**. gd1/2/4 비교 9건은 기본 run·QC 대기. 옛 업체 캐시 미사용, PacBio 중복 제출 보류 |
| GIAB 숏리드 기본 run | **155526–155528, 156690 `r`**, 활성 Mark 로그 12개 모두 증가. 추가 20 set·53샘플 미제출 | 현재 잡 유지, 종료·산출물·간단 QC 확인. 일괄 추가 제출하지 않음 |
| Illumina-250PE 재시도 | **156786 exit 1·Error 유지**. Manta HG002/3/4 SV gap, HG002 verifybamID QC gap. HG004 verifybamID 성공. HG003 gather·변이 집계는 계산 후 기존 링크 충돌 | 추가 재시도 없음. SNP/INDEL 최소 QC 통과, **세트 전체 완료는 아님**. [판정·검증](runs/2026-09-26-illumina-regermline-retry.md#종료-결과와-판정-09391000) |
| GIAB PacBio·ONT | 담당 보고상 PacBio verify 49/49, 소변이 19런·SV 5런. ONT HG002/3/4 기본 run·QC·채점 완료 | 기존 결과를 비교표에 연결. **업체 롱리드는 수령 대기** |
| 다운로드 | BioSkryb×UG100 **1.951/5.221TB(37.37%)**, 직전보다 +1.169TB. 크기 일치 95·부분 6·미수령 375개, wget 6개 모두 증가. 기존 유효 MD5 마커 50/제공 238개 | 전체 수령 뒤 크기·제공 MD5 확인, 카탈로그 반영. 기존 목록 81,302개와 역사적 FAIL·NOREF 보존. [이번 근거](reference/2026-09-26-1553-status-evidence.json) |
| GIAB somatic / bioinfo 개발 | **HG008 13쌍 전장·채점·QC 완료 유지**. 156747–156779 중 해당 29잡 qacct 0, VCF QC 13/13, summary 28개. QC 표 해시 불변 | 추가 실행 없이 닫음. matched 2쌍은 precision·recall, borrowed 11쌍은 recall만 해석. [결과·한계](runs/2026-09-25-somatic-wgs.md). 범용 bioinfo 개발은 별도 |

공통 백업은 `/BiO/scratch/dyl/kbb/G000/backup/20260925-company-reset`, 재구성 기록은 `G000/.company-reset-20260925.json`. 원자료·샘플 정본·서버 엑셀을 유지했다. 카탈로그·Excel은 비교 점수와 다운로드 완료가 없어 직전 반영분 유지(최근 442행 × 51열 대조 차이 0).

가벼운 정리 3건은 완료했다. PacBio 요약 PR #74와 BioSkryb 수령 PR #75는 main 반영. [ONT 비교](https://github.com/ehojune/GIAB_benchmarking/blob/6a18594/docs/reference/2026-09-25-ont-guppy324-vs-345-same-flowcell.md)·[MD5 후속 대조](https://github.com/ehojune/GIAB_benchmarking/blob/5b2c18b/docs/runs/2026-09-25-md5-verification-followup.md)는 담당 브랜치에 있으며 **PR #68·#69 병합·반복 리뷰 보류**다.

**Codex가 단독으로 4시간 점검·보고와 승인된 후속 작업을 맡는다.** Claude 네 담당은 idle, 임시 총괄 종료 유지. 새 Claude 실행·중복 자동화 없음. 다음 점검은 약 19:52 KST. 남은 일은 [backlog](backlog.md), 과거 이력은 [조회용 자료](reference/README.md)에 있다.
