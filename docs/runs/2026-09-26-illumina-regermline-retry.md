# Illumina-250PE: 정리·regermline 156786 종료, 실패 항목만 gap

2026-09-26 10:00 KST 갱신. Claude가 08:37–09:05 정리·제출했고, 사용자 지시로 복귀한 Codex가 종료·산출물을 확인했다. 원본 Claude 총괄 세션 통지·인계·프로세스 중지를 마쳤다. **156786은 exit 1, 세트 전체 Error이며 추가 재시도하지 않는다.**

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

→ **156786 `regermline_GIAB-publicData-Illumina-250PE`**, 60슬롯 shepherd.q, 09:04:27 제출·09:04:29 시작·09:39:49 종료. 마커 `native-regermline-started.txt`.

제출 직전 실제 Snakefile로 `snakemake -n` (onstart는 dry-run에서 안 돈다): **manta 3 · verifybamID 2 · all 1 · haplo_interval 12 = 18잡**. haplo_interval 12건은 `sampleinfo/sample_information_nbb2.xlsx`가 09-25 07:45(회사 교정)에 바뀌어 그보다 오래된 HaplotypeCaller 구간 출력이 `--rerun-triggers mtime`에 걸린 것이다. GIAB 행의 성별은 그때 바뀌지 않았으므로 결과는 같아야 하고, 이것은 `regermline`의 고정 옵션이라 156782가 돌았어도 같았다.

## 종료 결과와 판정 (09:39–10:00)

qacct `failed=0 / exit_status=1`(35분 20초), `__DONE__=Message : Error`. 새 `error_list.txt` 6건을 산출물과 대조했다.

| 단계 | 최종 판정 |
|---|---|
| Manta HG002/3/4 | 재시도에도 실패. **SV gap**, 추가 재시도 없음 |
| verifybamID HG002 | 표는 있지만 성공 status·checksum·결과 링크 없음. **오염 QC gap** |
| verifybamID HG004 | **성공**. 09:18:20 결과·checksum·링크, `Success!`·status 0. HG003의 기존 성공 결과도 유지 |
| HG003 haplo_gather·count_variants | **계산 성공, 기존 링크 생성 충돌**. 코드가 계산→checksum 뒤 `ln -s`를 실행해 `File exists`를 기록. 기존 링크는 올바른 실파일을 가리키므로 수정·재계산 불필요 |

10:00 최소 QC: HG002/3/4 gVCF 샘플명 일치·tabix 25 contig·정상 BGZF EOF, CRAM `samtools quickcheck` 3/3 통과. HG003 gVCF(2,124,718,754 B)·tbi·변이 집계는 재계산 SHA256이 새 sidecar와 **3/3 일치**했고 chrM 인덱스 조회도 성공했다. outcome의 gVCF·tbi 및 analyze_meta의 집계 링크는 각각 해당 실파일을 정확히 가리킨다. HG003 CRAM·crai·Canvas도 유지됐다.

**SNP/INDEL 산출물 사용 가능성과 세트 전체 성공은 별개다.** HG003 gVCF는 이번에 다시 생성됐으며 예전 파일과 바이트 동일성까지 확인한 것은 아니다. 정상 결과와 error_list를 보존한다. 회사 run 완료·QC 전 비교는 보류하고 기존 비교 범위를 유지한다. Illumina 추가 재시도·원인 연구·새 caller는 시작하지 않는다.

## 그 밖에 확인한 것

- 09:56 BioSkryb×UG100 `fetch_external.sh`(PR #75 main 반영)는 wget 6개로 수령 중. 수령 완료 아님.
- 09:56 공개 4잡(155526–155528, 156690)과 회사 4잡(156760–156763)은 모두 `r`. Codex의 단일 4시간 점검을 유지한다.
- HIWARE 게이트웨이로 파일을 올릴 때 한 번에 보내는 입력은 3 KB 이내로 나눠야 한다(긴 base64 한 줄은 유실됐다). gzip+base64 700자 청크, 호출당 3청크로 성공.
