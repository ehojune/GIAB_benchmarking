# 2026-09-23 — phase3 2차 입력 서버 적용 (nbb2)

PR #41(91c116e) merge 직후, hiware-cluster 스킬로 로그인 한 번에 실행했다. 국통바빅은 돌리지 않았다(사용자 몫).

## 명령

```bash
cd ~/GIAB_benchmarking && git pull --ff-only                       # af88456 → 91c116e
cd /BiO/scratch/dyl/kbb/G000
PY=/home/ehojune/anaconda3/bin/python; S=~/GIAB_benchmarking/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py
ONLY=$(awk -F'\t' 'NR>1{print $2}' ~/GIAB_benchmarking/phase3_shortread_wgs/more_run_table.tsv | sort -u | sed 's/^/--only /' | tr '\n' ' ')   # 2차 20 set만 — 1차 dir은 안 건드린다
H='(octopus-2-8|octopus-2-9|octopus-2-10|octopus-2-11|shepherd-1-8|shepherd-1-9)'
$PY $S $ONLY --dry-run --sampleinfo sampleinfo/sample_information_nbb2.xlsx > ~/p3more.dryrun.log 2>&1
$PY $S $ONLY --qsub --lanes 8 --hosts "$H" --sampleinfo sampleinfo/sample_information_nbb2.xlsx > ~/p3more.apply.log 2>&1
```

호스트는 phase1/2 기본 넷에 octopus-2-10/11을 더했다 — 사용자 자신의 잡(155529 regermline, 156584 재정렬)이 그 둘에서 돌고 있다.

## 출력 (요지, 전문은 서버 `~/p3more.dryrun.log`·`~/p3more.apply.log`)

```
dryrun rc=0
sampleinfo sampleinfo/sample_information_nbb2.xlsx: 이미 있음 0, 추가 53 (dry-run, 안 씀)
DRY-RUN 링크 14개(0 생성, 0 기존, 0 정리) · 병합 46 샘플 · 데이터셋 dir 20개 under /BiO/scratch/dyl/kbb/G000
apply rc=0
sampleinfo sampleinfo/sample_information_nbb2.xlsx: 이미 있음 0, 추가 53
  저장함 (백업 sampleinfo/sample_information_nbb2.xlsx.bak-20260923-224239)
링크 14개(14 생성, 0 기존, 0 정리) · 병합 46 샘플 · 데이터셋 dir 20개 under /BiO/scratch/dyl/kbb/G000
46/46 잡 제출.
```

적용 직후: `GIAB-publicData-*` set 28개(1차 8 + 2차 20), 샘플 dir 75개(22 + 53). qstat: `cat.GIAB-p` 8개 qw(줄 머리) + 38개 hqw(-hold_jid 대기).

## 되돌리기

- sampleinfo: `cp sampleinfo/sample_information_nbb2.xlsx.bak-20260923-224239 sampleinfo/sample_information_nbb2.xlsx`
- 디렉토리: 2차 20 set은 새로 만든 것이라 `rm -r GIAB-publicData-<set>`로 통째로 지우면 된다(원본은 `/BiO/scratch/ehojune/GIAB_benchmark` 밖으로 안 나갔다). 병합 잡은 `qdel`.

## 이후 확인

23:29 (적용 47분 뒤): cat 잡 156594~156639 중 완료 8 · 실행 8 · 대기 30, `ERROR`/`LOCKED` 로그 0.
READY 6 set — `Hiseq-100x`(HG006·HG007 각 ~300 GiB가 45분 안에), `NIST-BGIseq-100x`, `MGISEQ2000-PCRfree-NA12878`,
`HG008-Illumina-BCM-2024`, `HG008-Onso`, `HG008-Element-AVITI-202412`(마지막 셋은 링크·1쌍이 섞여 있다).
확인 명령은 phase3 README 2차 절의 READY 한 줄.
