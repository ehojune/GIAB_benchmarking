# GIAB 현황

2026-09-25. 완료 기준은 [SCOPE](SCOPE.md). gd2는 07:30 관리자 검증 완료, 기본 큐는 07:31 조회, bioinfo는 02:48 완료 보고 기준이다.

| 작업 | 현재 상태 | 다음 한 번의 행동 |
|---|---|---|
| 업체 숏리드 + 공개 HG002/3/4 비교 | 채점 **0/13**. Singularity 경로와 임시 디렉터리 설정을 수정한 `1543c79` 보고. 환경 확인 잡 **156733**은 failed 0/exit 0/PREFLIGHT_OK. gd1·3 비교 6행은 Coriell ID 근거로 교정 | `PREFLIGHT_OK` 후 미완료 비교 재개. gd2는 아래 준비부터 진행 |
| gd2 입력 교정 | **준비 완료**. 156732 중지, 옛 결과는 백업. 원래 gd2에 jslink 링크 12개, 정본 1–3 KOR·4–6 HG로 엑셀 10칸 교정·검증 | 새 germline 미제출, 사용자 검토 후 제출. gd1·3 엑셀 순서 및 gd4 입력 링크도 사용자 표와 달라 별도 확인 필요 |
| GIAB 숏리드 미완료 기본 run | **155526–155529, 156690 유지**. MGISEQ HG002 복구 BAM 교체·quickcheck 완료, 이전 BAM 보관. 2차 20 set·53샘플은 준비됨, 미제출 | 기존 잡 완료 시 `__DONE__`·`error_list.txt`·BAM 수 확인. 이후 고정 명세의 필요한 기본 run만 이어감 |
| GIAB PacBio·ONT | 담당자 보고상 PacBio verify **49/49**, 소변이 19런·SV 5런. ONT HG002/3/4 기본 run·QC·채점 완료 | 기존 결과를 비교표에 연결. **업체 롱리드는 수령 대기**(사용자 확인); 받으면 기존 파이프라인 적용 |
| 다운로드 | 담당자는 phase0 확보 100%와 MD5 잡 **156685 완료**를 보고. 후속 결과는 **draft PR #69**, 검토·머지 보류. `NOREF` **3,752개**는 checksum 검증 성공이 아님 | 확보율과 checksum 판정을 구분해 고정 명세의 gap만 기록. `NOREF`를 검증 성공으로 쓰지 않음 |
| 범용 bioinfo 개발 / GIAB somatic | bioinfo `f2de95e`: CPU 구현·stub·4 Mb 실행 검증 완료 보고. 전장 검증은 미완. **전장 진행은 사용자 승인**, Desktop PacBio에 직접 시작 지시 예정. 기존 채점 시험 **156691**은 이 표에서 완료 미확인 | PacBio가 bioinfo와 인계·범위를 맞춰 실행. 관리자의 정리 지시로 먼저 전장 제출하지 않음 |

승인된 정리 3건은 06:55 담당 보고상 commit·push 완료: PacBio `e43ca77`, ONT `6a18594`, 다운로드 `5b2c18b`. 각각의 작업 브랜치 결과이며 main 반영과 구분한다. 새 대규모 계산은 없었다. ONT poller 둘은 종료됐다. PR #67은 이미 merge, **#68·#69는 merge 보류**이며 반복 리뷰는 하지 않는다.

근거: [숏리드 입력·truth](../phase3_shortread_wgs/README.md), [PacBio 기존 결과](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md), [ONT 기존 결과](reference/2026-09-22-ont-r10-benchmark.md), [PR #69](https://github.com/ehojune/GIAB_benchmarking/pull/69).

남은 일은 [backlog](backlog.md). 이전 현황·전체 이력은 [조정 전 스냅샷](reference/2026-09-25-status-before-scope-reset.md), 서버 명령은 [조회용 자료](reference/server-and-infra.md)에 보존했다.
