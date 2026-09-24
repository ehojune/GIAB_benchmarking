# #7 숏리드 최소 비교 — 현재 인계

2026-09-25 07:49:38 KST 제출 직후 기준. 회사 4개 set을 정본 표로 다시 준비하고 기존 `germline`으로 제출했다. **새 회사 QC·truth 채점 결과는 아직 없다. 기본 run을 중복 제출하지 않는다.**

| 회사 | set | job | 당시 상태 |
|---|---|---|---|
| gd001 | G000-gd1-20260819 | 156760 | r |
| gd002 | G000-gd2-20260819 | 156761 | r |
| gd003 | G000-gd3-20260819 | 156762 | qw |
| gd004 | G000-gd4-20260819 | 156763 | qw |

24샘플·48개 원자료 링크를 검증했고 4개 set의 dry-run이 통과했다. Java 17 환경을 지정했으며 공용 국통바빅 코드는 바꾸지 않았다. 07:53경 gd1·gd2는 각각 6/265 steps, 성별 로그는 6샘플(male 4·female 2·unknown 0)이었고 error_list는 없었다. gd3·gd4는 대기 중이다. 이는 초기 진행 기록이며 완료 판정이 아니다.

## 입력·성별 정본

네 회사 모두 DNA_ID의 샘플 순번을 아래처럼 맞췄다. 서버 sampleinfo Sheet2의 `DNA_ID`·`SEX`·`note`도 같은 대응이다.

| 순번 | 실제 샘플 | 성별 |
|---|---|---|
| 001 / 002 / 003 | KOR-101 / KOR-102 / KOR-103 | male / female / male |
| 004 / 005 / 006 | HG002 / HG003 / HG004 | male / male / female |

gd2는 `data/jslink` 원자료다. `happy_manifest.csv`의 회사 12행은 모두 각 회사의 004–006을 가리킨다. 이번에 gd2·gd4의 6행을 교정했으며 gd1·gd3와 공개 자료 4행은 유지했다. KOR 12샘플은 기본 run·간단 QC만 수행하며 GIAB truth 채점 대상이 아니다.

## 기존 결과 보존·재사용 금지

- 서버 백업: `/BiO/scratch/dyl/kbb/G000/backup/20260925-company-reset/`. 이전 회사 4개 set, gd2 이력 디렉터리 2개, 변경 전 Excel을 보존했다. 백업 내부의 절대경로 링크 376개도 백업 대상을 가리키도록 고치고 검증했다.
- 옛 회사 coverage·mapped% 표는 백업한 이전 run의 이력이다. 현재 정본 입력·성별로 얻은 값처럼 인용하지 않는다.
- 07:55:41 KST에 기존 회사 채점 디렉터리 9개(gd001·gd003·gd004 × HG002/3/4)를 같은 파일시스템의 `backup/20260925-company-reset/hap_py_before_reset/`로 옮기고 원래 경로가 비었음을 확인했다. 원본 manifest·`retirement.json`·`DO_NOT_REUSE.txt`를 함께 보관했다. 공개 4개 디렉터리의 device/inode는 유지됐고 새 비교 잡은 제출하지 않았다.
- **이전 회사 genotyped VCF·hap.py 결과는 재사용하지 않는다.** 새 기본 run의 gVCF에서 GenotypeGVCFs부터 새로 만든다. 새 manifest만 덮어쓴 채 이전 `07_happy/<label>` 캐시를 남기는 방식은 금지한다.
- 이전 gd2 준비·수동 제출 명령은 현행 절차에서 제외했다. 이미 제출한 네 잡을 다시 시작하지 않는다.

## 담당자가 이어갈 최소 작업

1. 각 새 set의 `__DONE__`에 `Message : Success`가 있는지와 `error_list.txt`를 함께 확인한다. 큐에서 사라졌거나 exit 0인 것만으로 완료 처리하지 않는다.
2. 정본 표 ↔ 실제 원자료 링크 ↔ 산출물 sample ID를 대조한다. BAM/CRAM·gVCF의 존재와 읽기 가능 여부, BAM primary read 수, coverage·mapping을 확인해 새 QC 표를 만든다.
3. 위 조건을 통과한 새 회사 HG002/3/4와 manifest의 공개 4개 비교군만, 이미 승인된 최소 truth 비교로 진행한다. gVCF를 그대로 채점하지 않고 GATK 4.6.1.0 `GenotypeGVCFs` 후 hap.py v0.3.12를 사용한다. 호출에 쓴 GRCh38 reference와 NIST v4.2.1의 chr1–22 `_noinconsistent.bed`를 동일하게 적용한다.
4. SNP·INDEL precision/recall/F1과 간단 QC를 짧은 표로 정리한다. 현재 인계 작업에서는 채점 잡을 제출하지 않았다. 추가 비교군·caller·구간별 실험은 늘리지 않는다.

도구는 `scripts/11_happy_submit.sh`, 입력 목록은 `happy_manifest.csv`다. 이전 hap.py 환경 점검 156733의 `PREFLIGHT_OK`는 보존하되 새 회사 결과의 성공 근거로 쓰지 않는다. 공개 기본 run과 그 밖의 자료 확보·QC는 기존 담당 범위로 유지한다.

지난 실패·교정 과정과 옛 QC 값은 [변경 전 보고서](../docs/reference/2026-09-25-shortread-happy-before-company-reset.md)에 보존했다. 조회용 이력이며 현재 상태나 실행 지시가 아니다.
