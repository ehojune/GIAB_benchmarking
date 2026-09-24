# GIAB 현황

2026-09-25. 완료 기준은 [SCOPE](SCOPE.md). 회사 재구성은 07:45:39, 실제 제출은 07:49:38 관리자 기록 기준이다. 아래 큐 상태는 제출 후 확인값이며 실시간 표시가 아니다.

| 작업 | 현재 상태 | 다음 한 번의 행동 |
|---|---|---|
| 업체 gd1~4 germline 재분석 | **24샘플·48 raw 링크·엑셀 24행 검증**, 네 dry-run 통과, Java 17. 실제 제출: gd1 **156760 r**, gd2 **156761 r**, gd3 **156762 qw**, gd4 **156763 qw** | 분석 완료까지 기다린 뒤 `__DONE__`·`error_list.txt`·BAM/VCF·간단 QC 확인 |
| 업체 + 공개 HG002/3/4 비교 | 이전 업체 결과·비교 캐시는 역사자료로 보관. 교정한 run은 아직 미완료이며 **새 비교 잡은 제출하지 않음** | 교정 run 완료 후 완료된 공개 NovaSeq군과 이미 승인된 hap.py/v4.2.1 단순 비교. 옛 캐시 재사용 금지 |
| GIAB 숏리드 미완료 기본 run | **155526–155529, 156690 유지**. MGISEQ HG002 복구 BAM 교체·quickcheck 완료, 이전 BAM 보관. 2차 20 set·53샘플은 준비됨, 미제출 | 기존 잡 완료 시 `__DONE__`·`error_list.txt`·BAM 수 확인. 이후 고정 명세의 필요한 기본 run만 이어감 |
| GIAB PacBio·ONT | 담당자 보고상 PacBio verify **49/49**, 소변이 19런·SV 5런. ONT HG002/3/4 기본 run·QC·채점 완료 | 기존 결과를 비교표에 연결. **업체 롱리드는 수령 대기**(사용자 확인); 받으면 기존 파이프라인 적용 |
| 다운로드 | 담당자는 phase0 확보 100%와 MD5 잡 **156685 완료**를 보고. 후속 결과는 **draft PR #69**, 검토·머지 보류. `NOREF` **3,752개**는 checksum 검증 성공이 아님 | 확보율과 checksum 판정을 구분해 고정 명세의 gap만 기록. `NOREF`를 검증 성공으로 쓰지 않음 |
| 범용 bioinfo 개발 / GIAB somatic | bioinfo `f2de95e`(DeepSomatic 1.10.0 PACBIO tumor-normal, CPU)를 GIAB 에 별도 사본으로 고정 vendor(#70, germline 사본 불변). **HG008 13쌍 전장 실행 중** — 156747–156759, 쌍마다 노드 1대·60슬롯(휴일 지시로 노드 제한 해제), 07:44 전부 `r`·60 shard 확인. 채점 경로는 156691(공개 UCSC 콜셋)로 검증됨. bioinfo 쪽 PR ehojune/bioinfo-agent#57 은 Codex 리뷰 중 | 잡 종료 시 qacct·VCF·`70_submit_somatic.sh --qc` → 쌍별 `62_benchmark_somatic.sh` → 채점표. 기록: [runs/2026-09-25-somatic-wgs.md](runs/2026-09-25-somatic-wgs.md) |

공통 백업: `/BiO/scratch/dyl/kbb/G000/backup/20260925-company-reset`. 실행 기록: 서버 `G000/.company-reset-20260925.json`. 백업 링크·엑셀 교정 상세는 [decisions](decisions.md) 끝에 남겼다.

승인된 정리 3건은 06:55 담당 보고상 commit·push 완료: PacBio `e43ca77`, ONT `6a18594`, 다운로드 `5b2c18b`. 각각의 작업 브랜치 결과이며 main 반영과 구분한다. 새 대규모 계산은 없었다. ONT poller 둘은 종료됐다. PR #67은 이미 merge, **#68·#69는 merge 보류**이며 반복 리뷰는 하지 않는다.

근거: [숏리드 입력·truth](../phase3_shortread_wgs/README.md), [PacBio 기존 결과](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md), [ONT 기존 결과](reference/2026-09-22-ont-r10-benchmark.md), [PR #69](https://github.com/ehojune/GIAB_benchmarking/pull/69).

남은 일은 [backlog](backlog.md). 이전 현황·전체 이력은 [조정 전 스냅샷](reference/2026-09-25-status-before-scope-reset.md), 서버 명령은 [조회용 자료](reference/server-and-infra.md)에 보존했다.
