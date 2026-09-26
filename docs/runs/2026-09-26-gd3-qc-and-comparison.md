# gd3 QC 판정과 기존 truth 비교 시작

2026-09-26 15:53–16:13 KST, `nbbcluster2/ehojune`. 실행 담당 Codex. [기계 판독 근거](../reference/2026-09-26-1553-status-evidence.json).

| 확인 | 결과·판단 |
|---|---|
| gd3 기본 잡 156762 | 14:21:31 종료, qacct failed/exit 0·265/265·Success·error_list 없음. **전체 QC 성공은 아님** |
| 주요 산출물 | 6샘플 CRAM quickcheck, gVCF 샘플 ID·인덱스·BGZF 끝 표식 정상. fastp 처리 후 리드 수와 BAM primary 수 6/6 일치. 평균 깊이 29.24–30.87×. SV·CNV 결과 존재 |
| 누락된 오염 QC | KOR-101·KOR-103·HG002의 VerifyBamID가 표 생성 후 segfault. master 로그에 실패, 성공 checksum·QC 링크 없음. 부분 표 수치를 완료된 QC로 사용하지 않음 |
| 복구 판단 | native regermline과 같은 설정으로 해당 QC 강제 dry-run: **253작업**, 정리된 중간 BAM 때문에 fastp·정렬·변이 호출까지 재계산. **실제 재실행·실패 파일 이동·삭제 없음**. 비용을 늘리지 않고 3건을 gap으로 보존 |
| 비교 허용 범위 | 새 gd3 변이 산출물의 최소 QC는 통과해 승인된 HG002/3/4 비교 진행. HG002는 오염 QC 미완료를 결과표에 명시. 오염이 없다는 결론은 내리지 않음 |

기존 `07_happy/11_happy_submit.sh`로 16:07:36에 한 번 제출했다. GATK 4.6.1.0 genotyping → hap.py 0.3.12 / GIAB v4.2.1 / GRCh38 chr1–22, 기존 no-inconsistent 영역을 사용한다.

| 입력 | 잡 |
|---|---|
| 새 gd3 HG002 / HG003 / HG004 | 156787 / 156788 / 156789 |
| 공개 NovaSeq6000-30x HG002 / HG003 / HG004 | 156790 / 156791 / 156792 |
| 공개 NovaSeqX-30x HG002 | 156793 |

gd3 옛 캐시는 백업에만 있고 새 gVCF부터 genotyping한다. 공개 4개는 기존 genotyped VCF의 샘플·reference·버전·입력 시간·인덱스를 확인해 재사용한다. 직전 Singularity 경로 오류는 수정본과 성공한 preflight 156733을 확인했다. 16:13 점검에서 gd3 genotyping은 chr2, 공개 4개 hap.py 로그도 증가했다. 아직 점수는 없다.

서버 기준 경로는 `/BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune/phase3_shortread_wgs/07_happy`. 제출 명세 `ready_gd3_public_20260926.csv`, 상태·잡 번호 `submission_gd3_public_20260926.json`, 중복 방지 마커 `submission_gd3_public_20260926.attempt`. **제출 스크립트를 다시 실행하지 않는다.** 다음 점검에서 qacct·ALL DONE·summary를 함께 검증한다. gd1/2/4의 나머지 비교 9건은 기본 run 종료·최소 QC 뒤 진행한다.

**후속 정정:** 사용자가 회사별 기본 잡 종료 후 일반 `regermline`, 같은 단계 재실패 시 실패 중간 디렉토리 정리 후 `regermline`을 지시했다. 위 253작업은 `--forcerun`을 추가한 dry-run이므로 일반 재개 범위와 동일시하지 않는다. gd3 비교 종료 뒤 이 순서로 재개한다.
