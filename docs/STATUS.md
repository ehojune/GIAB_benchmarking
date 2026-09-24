# GIAB 현황

2026-09-25 범위 조정. 완료 기준은 [SCOPE](SCOPE.md). 담당자의 01:18 회신·사용자 확인에 숏리드 01:36 보고를 반영했다. 실시간 큐가 아니다.

| 작업 | 현재 상태 | 다음 한 번의 행동 |
|---|---|---|
| 업체 숏리드 + 공개 HG002/3/4 비교 | **업체 기본분석 완료**(사용자 확인). gd1·3·4와 NovaSeq 공개군 비교 13잡 **156705–156717** 제출: 90초 후 4실행·9대기. 첫 13잡의 환경설정 오류를 수정한 재제출이며 점수는 아직 없음. 조회한 gd2 경로는 gd4 입력을 가리킴 | 완료 후 qacct·`ALL DONE`·summary로 점수 수집. gd2는 올바른 기존 결과·원자료 대응 확인 전 N/A. 원본 재분석 없이 경로부터 확인 |
| GIAB 숏리드 미완료 기본 run | **155526–155529, 156690 유지**. MGISEQ HG002 복구 BAM 교체·quickcheck 완료, 이전 BAM 보관. 2차 20 set·53샘플은 준비됨, 미제출 | 기존 잡 완료 시 `__DONE__`·`error_list.txt`·BAM 수 확인. 이후 고정 명세의 필요한 기본 run만 이어감 |
| GIAB PacBio·ONT | 담당자 보고상 PacBio verify **49/49**, 소변이 19런·SV 5런. ONT HG002/3/4 기본 run·QC·채점 완료 | 기존 결과를 비교표에 연결. **업체 롱리드는 수령 대기**(사용자 확인); 받으면 기존 파이프라인 적용 |
| 다운로드 | 담당자는 phase0 확보 100%와 MD5 잡 **156685 완료**를 보고. 후속 결과는 **draft PR #69**, 검토·머지 보류. `NOREF` **3,752개**는 checksum 검증 성공이 아님 | 확보율과 checksum 판정을 구분해 고정 명세의 gap만 기록. `NOREF`를 검증 성공으로 쓰지 않음 |
| 범용 bioinfo 개발 / GIAB somatic | 범용 개발은 별도로 계속 허용. GIAB somatic 통합·pilot·전장 확장은 보류. 짧은 채점 잡 **156691**은 이미 제출됨, 이 표에서 완료 여부 미확인 | 새 GIAB 후속 잡 없음. bioinfo 결과는 GIAB 완료 조건과 분리 |

숏리드 최소 비교 외 PacBio·ONT·다운로드 GIAB 후속 CLI는 중지하고 작업 트리를 보존했다. ONT poller 둘은 담당자 확인상 이미 종료했고, 제출한 156687–156689는 exit 0이다. PR #67은 이미 merge, **#68·#69는 draft로 전환해 보류**한다. 자동 리뷰나 재개 명령이 아니다.

근거: [숏리드 입력·truth](../phase3_shortread_wgs/README.md), [PacBio 기존 결과](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md), [ONT 기존 결과](reference/2026-09-22-ont-r10-benchmark.md), [PR #69](https://github.com/ehojune/GIAB_benchmarking/pull/69).

남은 일은 [backlog](backlog.md). 이전 현황·전체 이력은 [조정 전 스냅샷](reference/2026-09-25-status-before-scope-reset.md), 서버 명령은 [조회용 자료](reference/server-and-infra.md)에 보존했다.
