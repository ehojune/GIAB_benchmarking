# gd2·gd3 DONE와 개별 실패 근거

2026-09-26 19:50–20:00 KST 확인. **둘 다 원래 잡은 exit 0, `__DONE__=Success`, error_list 없음. 그러나 VerifyBamID가 각각 3번 segfault했다. 시료 오염이 확인됐다는 뜻은 아니다.**

| 세트 | 원래 잡 종료 | VerifyBamID 실패 샘플 | 원래 master 로그 행 |
|---|---|---|---|
| gd2 / 156761 | 19:06:10 | KOR-101·HG002·HG004 | 205152·206830·208364 |
| gd3 / 156762 | 14:21:31 | KOR-101·HG002·KOR-103 | 142294·142443·142502 |

서버 원문:

- `/BiO/scratch/dyl/kbb/G000/G000-gd2-20260819/log/germline_G000-gd2-20260819.o156761`
- `/BiO/scratch/dyl/kbb/G000/G000-gd3-20260819/log/germline_G000-gd3-20260819.o156762`

위 행에 `Segmentation fault (core dumped)`와 `VerifyBamID` 명령이 함께 있다. 각 set의 `tmp/13.verifybamID/`에 해당 샘플 `.selfSM`·`.Ancestry`는 있지만 `.selfSM.sha256sum`과 `analyze_meta/<ID>/<ID>.selfSM`은 없다. gd2 실패 ID 순번은 001/004/006, gd3는 001/004/003이다.

파이프라인 `/BiO/scratch/dyl/kbb/UTILS/Tools/in_house_scripts/snakemake_script/germline_pipeline_snakefile.py`의 1099–1103행은 예외를 받아 알림만 남기고 다시 예외를 올리지 않는다. `rule all` 1425–1428행은 결과표 두 파일을 검사하며 성공 checksum은 검사하지 않는다. 따라서 프로그램이 표를 쓴 뒤 죽어도 전체 Success와 공존할 수 있다. 이것이 전체 정렬·변이 결과가 실패했다는 뜻은 아니다.

## 이번 재시도와 현재 조치

19:52:26 사용자 지시대로 **일반 regermline 156794(gd2)·156795(gd3)**를 제출했다. `--forcerun` 없이도 각각 253작업을 잡고 fastp부터 시작해 19:53:40 두 잡만 중지했다(qacct exit 137). 기존 CRAM·gVCF·SV·CNV·원자료의 대상·크기·mtime·inode는 전부 이전과 같다.

재시도 과정에서 fastp JSON/HTML 12샘플분이 제거됐다. 복구 책임은 Codex에 있으며, 같은 fastp 0.23.2와 설정으로 **보고서만 복원하는 156796·156797**을 19:58 제출했다. 20:00 실행 중이다. FASTQ·정렬·변이 결과는 만들지 않는다. 처리 리드 수를 기존 BAM primary 수와 대조한 뒤 누락 보고서만 복원한다. 아직 복원 완료는 아니다.

복구 경로: `/BiO/scratch/dyl/kbb/G000/backup/20260926-gd23-regermline/fastp-reports/{gd2,gd3}/RESTORED.json`. 원래 실패 근거와 제출 기록은 같은 상위 경로의 `ordinary/`에 보존했다. 일반 regermline이 오류 지점만 재개한다고 가정해 반복하거나 실패 폴더를 더 비우지 않는다.

gd1·gd4는 기존 잡 진행 중이다. 앞서 제출한 gd3·공개 비교 7건은 모두 qacct 0·ALL DONE·summary 확인을 마쳤다. gd3 HG002의 오염 QC 미완료 표시는 유지한다.

[상세 근거](../reference/2026-09-26-gd23-DONE-and-retry.json).
