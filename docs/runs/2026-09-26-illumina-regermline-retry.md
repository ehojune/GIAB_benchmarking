# Illumina-250PE: 155529 Error 종료 → 정리잡 156782 6초 실패 → 정리 후 native regermline 156786

2026-09-26 08:37–09:05 KST, 총괄(Claude, Codex 장애로 09-26 인계). 사용자 09-25 21:44 지시(실패 Manta 중간 폴더를 비우고 `regermline` 1회 재개)와 09-26 지시(오류 뒤 재시도는 `regermline`)의 첫 실제 실행이다.

## 155529 종료 (05:05)

qacct: start 09-21 17:26:29, end 09-26 05:05:56, `failed 0`, `exit_status 1`, maxvmem 206.7 GB, octopus-2-11. Snakemake `114 of 118 steps (97%) done` 후 종료. `__DONE__` = `Message : Error`, `error_list.txt` 5건:

| 시각 | 샘플 | 단계 | 증상 |
|---|---|---|---|
| 09-25 07:53 | HG003 | manta | `generateCandidateSV_0000` taskExitCode −11 (signal 11), `--threads 10` |
| 09-25 18:51 | HG002 | verifybamID | 표(.selfSM/.Ancestry)를 쓴 뒤 segfault. FREEMIX 9.6e-05 |
| 09-25 18:55 | HG002 | manta | 위와 같음 |
| 09-26 03:05 | HG004 | manta | 위와 같음 |
| 09-26 03:18 | HG004 | verifybamID | 위와 같음. FREEMIX 1.16e-04 |

HG003 verifybamID는 정상 완료(`.selfSM.sha256sum` + `analyze_meta` 링크 있음). 3샘플 모두 CRAM·crai·g.vcf.gz·tbi·Canvas 링크가 `outcome/`에 있다. Manta 최종 VCF는 셋 다 없다.

파이프라인 rule의 `try/except`가 예외를 삼키므로 verifybamID처럼 출력이 먼저 써지고 죽은 단계는 Snakemake가 완료로 본다 — 출력을 옮기지 않으면 `regermline`이 재계산하지 않고, `onstart`가 `error_list.txt`를 지워 실패 근거만 사라진다. Manta는 runDir이 남아 있으면 configManta가 거부한다. 그래서 두 종류 모두 실패 산출물을 백업으로 옮겨야 재개가 성립한다.

## 156782 (Codex 정리잡) — 6초 만에 exit 1, 이동 0건

qacct: start 09-26 05:05:59, end 05:06:05, `exit_status 1`. `cluster.log`:

```
  File ".../20260925-illumina-regermline/cleanup.py", line 33, in <module>
    assert all(s in SAMPLES and (step=='manta' or (step=='verifybamID' and s==SAMPLES[0])) for s,step in entries),'New error needs inspection'
AssertionError: New error needs inspection
```

검사문이 Manta는 3샘플, verifybamID는 HG002만 허용했다. HG004가 같은 두 단계에서 같은 방식으로 실패하자 "새 오류"로 판정해 멈췄다. `preserved/`·`cleanup-started.json`·`native-regermline-started.txt` 없음 — 아무것도 옮기지 않았고 regermline도 시작하지 않았다.

## 정리 (09:03, 로그인 노드)

`/BiO/scratch/dyl/kbb/G000/backup/20260926-illumina-regermline/cleanup2.py` (sha256 `6f488ef3…`, 서버 사본 확인). 09-25판과 같은 보수적 구조이고 바꾼 것은 둘: verifybamID 실패를 샘플별로 처리(sha256sum·analyze_meta 링크가 없는 샘플만), 선행 잡 155529·156782 둘 다 qacct 종료 확인. 서버 dry-run(rc 0) 뒤 독립 검증 3갈래(Snakemake 의미·데이터 보존·지시 준수)를 거쳤다. 지적된 결함 하나 — 스트리밍 셸에서는 `test -f`가 뒤 명령을 막지 못한다 — 는 제출 줄을 `&&` 체인으로 묶고 마커 파일·같은 세트 잡 0건 검사를 넣어 고쳤다.

`--apply` 결과: 19건 rename(같은 파일시스템, 삭제 없음), `cleanup-complete.json` 기록.

| 옮긴 것 | 위치 |
|---|---|
| Manta runDir·`_manta.err`·`manta.benchmark` × HG002/3/4 | `preserved/Manta-<샘플>{,.err,.benchmark}` |
| verifybamID `.selfSM`·`.Ancestry`·`.err`·`.log`·benchmark × HG002/HG004 | `preserved/Verify-<샘플>…` |
| `error_list.txt`·`__DONE__` 사본, qacct 155529·156782 원문 | `preserved/`, `predecessor-qacct-*.txt` |

유지: HG003 verifybamID 5개, BQSR BAM/bai 6개(크기·mtime·inode 이동 전후 동일: HG002 77,460,504,813 B / HG003 70,610,086,661 B / HG004 76,856,089,641 B), gVCF·CRAM·Canvas·outcome/analyze_meta 링크 전부.

## 제출 (09:04:27)

```bash
source /BiO/scratch/dyl/kbb/bashrc.txt
export JAVA_HOME=/BiO/scratch/dyl/apps/miniconda3/lib/jvm; export PATH="$JAVA_HOME/bin:$PATH"   # 회사 잡 156760–63과 같은 Java 17 전달(-V)
cd "$G" && test -f "$R/cleanup-complete.json" && test ! -e "$R/native-regermline-started.txt" \
  && [ "$(qstat -xml -u ehojune | grep -c Illumina-250PE)" = 0 ] \
  && qsub -e "$G/log" -o "$G/log" -N "regermline_$(basename "$G")" /BiO/scratch/dyl/kbb/zz.code/regermline.sh "$G"   # = bashrc.txt의 regermline alias 본문 그대로
```

→ **156786 `regermline_GIAB-publicData-Illumina-250PE`**, 60슬롯 shepherd.q, 09:04:27 `qw`. 마커 `native-regermline-started.txt`.

제출 직전 실제 Snakefile로 `snakemake -n` (onstart는 dry-run에서 안 돈다): **manta 3 · verifybamID 2 · all 1 · haplo_interval 12 = 18잡**. haplo_interval 12건은 `sampleinfo/sample_information_nbb2.xlsx`가 09-25 07:45(회사 교정)에 바뀌어 그보다 오래된 HaplotypeCaller 구간 출력이 `--rerun-triggers mtime`에 걸린 것이다. GIAB 행의 성별은 그때 바뀌지 않았으므로 결과는 같아야 하고, 이것은 `regermline`의 고정 옵션이라 156782가 돌았어도 같았다.

## 기대와 판정 기준

Manta signal 11은 3샘플 + 단독 재시도(156780, 1스레드)까지 4/4, verifybamID segfault도 3회 + 단독(156781)이라 **또 실패할 가능성이 높다.** 그래도 사용자가 지시한 단일 재시도이고 비용은 노드 1대 수 시간이다.

- 성공: `__DONE__` `Message : Success`, `error_list.txt` 없음, Manta `conInv_filtered.vcf` 3개 + outcome 링크, verifybamID `.selfSM.sha256sum` HG002/HG004.
- 다시 실패: **재시도하지 않는다.** 이 세트의 SV(Manta)와 HG002/HG004 오염 QC(verifybamID)를 `gap`으로 기록하고, 이미 있는 gVCF·CRAM으로 SNP/INDEL 비교를 진행한다(CRAM `samtools quickcheck`, gVCF `tabix -l`, BAM primary 리드 수 확인 후). 원인 연구·새 caller는 범위 밖.
- 큐 등록·exit 0만으로 완료 처리하지 않는다. qacct 156786, 새 `error_list.txt`, `preserved/`와 원 경로 대조.

## 그 밖에 확인한 것

- 로그인 노드에서 다운로드 담당의 BioSkryb×UG100 `fetch_external.sh`(PR #75, 08:58 merge)가 wget 6개로 돌고 있다. 4시간 점검에 포함한다.
- 공개 4세트(155526/27/28, 156690)는 여전히 markdup 단계, 회사 gd1~4는 30·38·32·30/265. 오류 기록 없음.
- HIWARE 게이트웨이로 파일을 올릴 때 한 번에 보내는 입력은 3 KB 이내로 나눠야 한다(긴 base64 한 줄은 유실됐다). gzip+base64 700자 청크, 호출당 3청크로 성공.
