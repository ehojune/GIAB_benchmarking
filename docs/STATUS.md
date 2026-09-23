# 진행 현황 — 지금 돌고 있는 것과 다음 손

**지금 무엇이 돌고 무엇이 막혀 있는지만 적는다.** 다음 주에 거짓이 될 것만 여기 있고,
안 변하는 것·이미 끝난 것은 아래로 나가 있다.

| 찾는 것 | 어디 |
|---|---|
| 잡이 왜 그 크기인지, 노드 스펙, `_infra` 에 뭐가 있는지, 확인 명령 | [reference/server-and-infra.md](reference/server-and-infra.md) |
| 아직 안 한 일의 상세 (#8·#9·#10) | [backlog.md](backlog.md) |
| 왜 그렇게 정했는지 | [decisions.md](decisions.md) |
| 결과 수치 | `reference/` 의 날짜별 문서. phase1 채점 해석은 [중간 보고](reports/2026-09-22-phase1-pacbio-benchmark.md) |
| 한 번 하고 남기는 실행 기록 | `runs/` |
| 여러 세션이 동시에 붙을 때의 규칙 | [AGENTS.md](../AGENTS.md) |

잡이 끝나거나 결정이 바뀌면 **여기부터** 고친다. 고친 내용은 맨 아래 `## 이력` 에 한 줄.

갱신: 2026-09-23 밤 (PacBio 세션)

## 한눈에 보기 (nbb2 로그인 노드)

```bash
qstat | awk 'NR>2{n[$3" "$5]++} END{for(k in n) print n[k], k}' | sort -k2; echo; cd /BiO/scratch/dyl/kbb/G000 && for d in GIAB-publicData-*/; do printf '%-45s DONE=%-8s err=%s\n' "${d%/}" "$(grep -o 'Success\|Error' $d/__DONE__ 2>/dev/null | head -1)" "$(cat $d/error_list.txt 2>/dev/null | tr '\n' ' ' | cut -c1-60)"; done; echo; ls /BiO/scratch/ehojune/GIAB_benchmark/repairs/mgi-hg002.*/VALIDATED.txt 2>/dev/null || echo "MGISEQ HG002 rebuild: 아직"
```

## 작업 흐름

| # | 작업 | 상태 (2026-09-23) | 잡 | 끝나면 | 막힌 것 / 의존 |
|---|---|---|---|---|---|
| 1 | **phase3 WGRS 재개** — markdup Java 8→17 (BGISEQ500, Element-AVITI, Hiseq-300x, Illumina-250PE, Novaseq6000, NovaseqX) | **2/6 Success**(Novaseq6000·NovaseqX, 09-22 새벽), **4/6 running**(BGISEQ500·Element-AVITI·Hiseq-300x·Illumina-250PE — `__DONE__`는 재개 전 옛 Error라 무시, `qstat -j`로 CPU 계속 증가 확인함) | 155526~155529 `regermline`, 60 slots, octopus-2-8/9/11 + shepherd-1-9 (09-21 16:36~, 09-23 기준 약 47h) | 세트별 `__DONE__` Success·`error_list.txt` 없음 확인 → #7 | 지정 호스트가 비어야 시작. 오래 qw면 `qstat -j 155519 \| grep -i "cannot run\|reason"` |
| 2 | **MGISEQ HG002 BAM 재생성** (정렬 BAM 33% 누락) | **qw** (사용자 승인으로 재제출, 09-23 15:29) | 156584 `mgi_HG002_rebuild`, `-q octopus.q,shepherd.q -l h_vmem=60G,hostname=(octopus-2-10\|octopus-2-11) -pe pe_slots 10`(155525와 동일 자원) | `repairs/mgi-hg002.*/VALIDATED.txt` 확인 → BAM 교체 → #3 | **1차 실패(155525)가 우연이 아닐 수 있다** — SAM 스트림 처리량 약 65.4% 지점에서 끊겼는데, 이 위치가 2026-09-21 원본 파이프라인 실패 지점과 레코드 수 기준 0.002%밖에 안 다르다(근거: [decisions.md](decisions.md) 2026-09-23, 원 명령/출력은 [runs/2026-09-23-phase3-input-audit-and-mgiseq-repair.md](runs/2026-09-23-phase3-input-audit-and-mgiseq-repair.md)). 이번에도 비슷한 지점에서 죽으면 blind retry 대신 그 구간 리드를 직접 봐야 한다 |
| 3 | **MGISEQ 세트 재개** (HG002 새 BAM + HG003/4 markdup) | 대기 | — | #1과 같은 Java 17 래퍼로 재제출 | #2 |
| 4 | **phase2 ONT HG002 R10.4.1** (PR #17, ONT open data 플로우셀 1개) | **완료** — 파이프라인·채점 전부 | 155279, shepherd-1-8, 30 slots, **16h20m(58,791s) / maxvmem 66.2 GB**. `30_verify_outputs.sh` OK 1/1 | **채점까지 완료** — hap.py 156047(50.7분) + Truvari 156053(4.5분) 둘 다 exit 0. 수치: [2026-09-22-ont-r10-benchmark.md](reference/2026-09-22-ont-r10-benchmark.md) | 없음 |
| 5 | **phase1 PacBio HiFi hap.py 평가** (`b1.*`, HG001~HG007) | **완료** — 19/19 exit 0 | 155355~155373, 16 slots, 56~83분, maxvmem 48.4~48.8 GB | 수치·판정: [2026-09-22-pacbio-hifi-benchmark-first-results.md](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md) | — |
| 5b | **phase1 PacBio SV 평가** (`s1.*`, Truvari vs v5.0q, HG002 5런) | **완료** — refine F1 .8208~.8418. **세대 단조성 없음**(SeqI 이 SeqII 를 가른다), recall 이 약점(.757~.788) | 156048~156052, `-t 8`, exit 0 | 수치·판정: [2026-09-22-pacbio-hifi-benchmark-first-results.md](reference/2026-09-22-pacbio-hifi-benchmark-first-results.md) | — |
| 5c | **phase1 구간별 hap.py** (`STRAT=1`, GIAB strat v3.6 에서 25구간, HG001~HG007 19런) — 중간 보고서의 열린 질문 둘(Sequel I INDEL 격차 원인, Revio Clair3 열세 위치)용 | **시험 1잡 qw** (HG002 Revio, 09-23 22:05) | 156590 `b2.*`, 32 slots / 16 threads. shepherd-1-8 이 SC28 + ONT 156587 로 60/64 라 SC28 뒤에 뜬다 | 시험 잡 maxvmem 보고 슬롯 정한 뒤 나머지 18런 → `STRAT=1 --collect` (Subset=* 가 기본 실행과 같은지 대조) | — |
| 6 | phase3 Hiseq-subsampled-30x | **완료** (Success) | — | #7에 포함 | — |
| 7 | **phase3 평가 설계** — 업체 4곳(gd1~4) + 공개 raw 22 샘플의 VCF를 v4.2.1(+HG002 CMRG·v5.0q)로 hap.py | 미착수 | — | 결과 디렉토리 구조 받으면 phase1·2 `60_benchmark.sh` 모양으로 스크립트 | #1·#3 완료 |
| 8 | **phase1 HG008-T 9 실행단위** — uBAM → BAM → VCF ([상세](backlog.md#8-상세--phase1-hg008-t-9-실행단위-2026-09-22-등록-완료)) | **8/9 완료** (전부 exit 0, wall 4.9~7.0h, maxvmem 49.4~58.3 GB). SC28 1건 실행 중(09-23 16:57~) | 156064~156072, 30 slots, 전부 shepherd-1-8 한 노드에서 2건씩 순차. 허용 4노드 중 셋은 숏리드 `regermline` 60슬롯이 잡고 있다 | 8건 `30_verify_outputs.sh` OK. SC28 뒤 QC 잡 156592(`qsub_task.sh`, hold)가 9건 verify + 전 런 `35_review_qc.py --pass-counts` + MultiQC 를 돈다. 같은 날 ts/tv 구간 분할 19런도 156591 로 제출. 채점은 #9 | 예상(10~15h)보다 빨랐다 |
| 9 | **HG008-T somatic 평가** — germline truth가 없는 HG008/HG009를 채점할 유일한 길 ([상세](backlog.md#9-상세--somatic-평가-방법-b-결정-2026-09-22)) | **방법 B 결정**(somatic caller 추가). 구현은 bioinfo-agent 쪽에 위임 — 프롬프트 [runs/2026-09-23-bioinfo-agent-somatic-handoff.md](runs/2026-09-23-bioinfo-agent-somatic-handoff.md) | — | 받은 커밋을 재-vendor → 쌍 11개 제출 → smvar V0.3 기준 `62_benchmark_somatic.sh`(가칭) | bioinfo-agent 커밋 해시. CPU 로 2주를 넘기면 외부 H100 요청 |
| 10 | **phase1↔phase2 표준화 잔여** — phase2 에 있고 phase1 에 없는 것 7개 ([상세](backlog.md#표준화-백로그-10)) | 부분 완료 — 09-23 `62_tstv_regions.sh` phase1 이식. 거꾸로 phase1 에만 있는 것 2개가 생겼다(`STRAT=1`, `qsub_task.sh`) | — | phase3까지 같은 모양으로 | 급하지 않음 |

## 자잘한 정리 (급하지 않음)

- `sample_information_nbb2.filled.xlsx`(로컬) — GIAB 22행 채운 사본. 원본 반영은 사용자.
- Java 17 결정은 decisions.md 2026-09-21 항목에 적었다(검증 대기 표시). #1 성공 확인 후 "검증됨"으로 바꾼다.
- 파이프라인이 bwa 실패를 삼키고 `Finished`로 넘긴 경로(Codex 확인) — 공용 파이프라인이라 우리가 안 고침. 재개 전 BAM 리드 수 대조가 방어책(아래 명령).

## 이력

- 2026-09-23 밤 — [PacBio 세션] #8 8/9 완료(exit 0, 4.9~7.0h — 예상 10~15h 의 절반). #9 는 방법 B 로 정해 bioinfo-agent 위임 프롬프트를 남겼다. 서버에서 확인한 설계 사실 셋: **HG008 matched pair 가 이미 둘 있다**(BCM↔BCM, PacBio↔PacBio — NIST 클론은 짝이 없어 BCM 정상을 빌린다), smvar V0.3 truth 는 **0823p23 배치의 truncal 변이만** 담아 클론·p100 은 recall 만 해석된다, README 권장 비교 도구는 aardvark. phase1 에 구간별 hap.py(`STRAT=1`)·ts/tv 구간 분할·`qsub_task.sh` 추가(PR #38).
- 2026-09-23 — [숏리드 세션] 사용자 승인으로 MGISEQ HG002 재생성 재제출(155525 실패 → 156584, 동일 자원). 국통바빅 본 파이프라인만 사용자 전용 실행이고 이런 복구 스크립트 qsub는 에이전트가 해도 된다고 확인받음. 옛 이름 중복 디렉토리(`GIAB_publicData_Hiseq_subsampled_30x`, 링크뿐)도 삭제.
- 2026-09-23 — [숏리드 세션] 사용자가 이 세션을 phase3 전담으로 지정, 파이프라인 입력 트리를 전수 재점검했다. **8개 세트 22개 샘플 디렉토리 전부 규약 준수**(NovaseqX-30x 는 HG002 뿐, 나머지 7세트는 트리오 — 3×7+1=22, #7 행의 "22 샘플"과 일치) — `_1`/`_2.fastq.gz` 정확히 1개씩, mate 접미 외 밑줄 0건, 완료 세트(Hiseq-subsampled-30x·Novaseq6000·NovaseqX)의 산출물(CRAM·gvcf 등)도 같은 이름 규칙을 따른다. 점검 중 **STATUS 의 실수를 하나 찾았다** — #2(MGISEQ HG002 BAM 재생성, 155525)가 "running" 으로 남아 있었지만 실제로는 09-22 15:59 에 exit 1 로 이미 끝나 있었다(원인: [decisions.md](decisions.md) 참고, samtools view 파싱 에러). 표 #1·#2·#3 행 정정. 옛 이름 디렉토리 `GIAB_publicData_Hiseq_subsampled_30x` 는 여전히 남아 있음을 재확인(삭제는 사용자 승인 대기).
- 2026-09-23 — **STATUS 를 현황판으로 되돌렸다.** 249줄 중 현황이 29줄(12%)이었고 나머지는 레퍼런스·백로그·끝난 인계장이었다. 가른 기준은 "에이전트용이냐"가 아니라 **다음 주에 거짓이 되는가**다 — 안 변하는 것(노드 스펙·`_infra` 자산·점검 명령)은 [reference/server-and-infra.md](reference/server-and-infra.md), 아직 안 한 일(#8·#9·#10 상세 + 다운로드 세션의 문서 수치 불일치 2건)은 [backlog.md](backlog.md) 로 옮겼다. 세션 조율 절 둘("지금 다른 세션이 하는 일"·"세션별 남은 최신화")은 **전부 해소돼 지웠다** — 규칙은 AGENTS.md 가, 내용은 이력과 PR 이 이미 갖고 있다. 이력은 사용자 요청대로 **맨 아래에 전부** 남겼다(14항목 그대로). STATUS 60줄.
- 2026-09-23 — [ONT 세션] 세 세션 정렬(#33)에 ONT 몫 반영. **카탈로그가 외부 유래 런을 영영 못 보던 구멍을 찾았다** — 행 key 가 `(sample, giab_path basename)` 인데 ext 행은 경로(배포처 구조)와 dataset(우리 명명)이 달라 HG002 R10 이 채점 완료 후에도 `variant_called=FALSE` 로 남아 있었다. 경고 한 줄로만 났다. `EXT_ALIAS` + 산출물 경로를 dataset 기준으로 고쳐 **10행 갱신**(germline 8 + HG008T-p2 + PAW70337). next_step 을 "한 것 + 남은 것" 으로 전환. phase2 README 의 소변이·SV·자원 실측 절을 R10 포함해 다시 썼고, 서버 미추적 결과 파일 7개를 gitignore 했다. PAW70337 행의 coverage 를 추정 ~45x 에서 **실측 49x** 로, notes 에 BAM 헤더 실측(정렬 PG 없음 · @RG basecall 모델 · GRCh38 195 contig)을 넣었다.
- 2026-09-23 — repo 전반 최신화 훑기. **엑셀이 25행만큼 뒤처져 있었다** — `50_update_catalog.py` 가 `build_readme.py` 만 돌리고 `build_xlsx.py` 는 안 돌렸다. 양쪽 phase 에 추가하고, `build_xlsx.py` 의 `--version`/`--date` 를 선택으로 바꿨다(처리 상태 갱신이 카탈로그 판번호를 올릴 이유가 없는데 required 라 부를 수 없었다). **표준화 백로그의 방향이 뒤집힌 것도 발견** — "phase2 기준으로 phase1 을 맞춘다" 였는데 phase1 이 따라가는 동안 phase2 가 더 나가서, 지금은 phase2 에 있고 phase1 에 없는 것이 8개다. 표를 phase 별 3열로 바꿔 코드 확인 결과를 그대로 적었다. 세션별 남은 최신화 목록도 절로 뒀다.
- 2026-09-23 — phase1 문서 최신화. 채점이 끝났는데 문서가 "앞으로 할 일" 상태였고 **사실 오류가 둘** 있었다: 카탈로그 note 가 HG002 에 "SV benchmark v0.6 으로 Truvari 평가"(v0.6 은 **GRCh37 전용**이라 못 쓴다 — 실제로 쓴 것은 v5.0q), HG001·HG003~007 에 "교차 콜러 일치도와 수동 검토로 평가"(하지 않았고 할 계획도 없다). `50_update_catalog.py` 문구를 고쳐 25행 재생성. phase1 README 에 SV 절 신설(있던 "SV 와 somatic 은 아직 못 한다" 가 낡았다), 채점 대상 23런 -> 19런, BENCH_SLOTS 8/32G -> 16/56G. **ONT 세션 할 일**: `phase2_ont/scripts/50_update_catalog.py` 의 같은 v0.6 오류를 고쳤으니(문구만) 재실행해 ONT 8행에 반영할 것.
- 2026-09-22 — [다운로드 세션] **서버 디스크 전수 대조 완료**: 매니페스트 4종 합집합 81,330 files 전부 디스크에 크기 일치(mismatch 0·missing 0), 매니페스트 밖 데이터 0, FTP 삭제 release 구버전 52건 8.4 GiB 보유. 세션 정지 상태에서 컨텍스트 정렬용 PR(#27 대체)을 올림 — PacBio·ONT 세션에 확인 요청 4건은 그 PR 본문. 서버 repo(`~/GIAB_benchmarking`)는 main 4c7778f + 미추적 결과 파일 5개.
- 2026-09-22 밤 — **ts/tv 구간 분할을 직접 쟀다**(`62_tstv_regions.sh`, 10건 전부 `안+밖=전체` 통과). **2026-08-27 의 열린 질문이 R9·R10 양쪽에서 닫혔다** — 구간 안이 전 런 2.0972~2.1400 으로 germline 기대치 그대로고 구간 밖만 1.09~1.48 이다. 2026-09-18 의 추정(HG005 1.33)은 실측 **1.3064**(오차 1.8%)로 확인됐고 "구간 안 = 2.1" 가정도 사실이었다. 새 관찰 둘: 베이스콜러가 좋을수록 구간 밖 ts/tv 가 오히려 **낮다**(어려운 영역까지 더 부른다), 그리고 구간 밖에서 DV↔C3 순 차이의 ts/tv 가 2.18 이라 **DV 가 구간 밖에서 버리는 쪽이 FP 가 아닐 수 있다**(미확인, reference §5).
- 2026-09-22 밤 — **phase2 HG002 R10 채점 전량 완료**(hap.py 156047 + Truvari 156053, 둘 다 exit 0). **ONT 가 같은 플로우셀에 공개한 hap.py 결과와 SNP F1 −0.0001 / INDEL F1 −0.0013 로 일치** — 우리가 ONT 정렬을 버리고 재정렬했는데도 그렇다. **DeepVariant 가 네 칸 전부에서 Clair3 를 이긴다**(INDEL F1 +0.024, FP −33%). SV 는 R10 이 R9 를 F1 +0.031 로 이기는데 그 이득이 거의 전부 recall(+0.048)이다. truvari 가 133.5 GB 를 써서 `BENCH_SV_SLOTS` 를 22→33 으로 올렸다 — env.sh 의 옛 "67~73 GB" 는 4스레드 값이었다. 수치: [2026-09-22-ont-r10-benchmark.md](reference/2026-09-22-ont-r10-benchmark.md)
- 2026-09-22 17:30 — #8 제출(156064~156072). **GPU 는 없다**(`qhost -F gpu` 무응답) — somatic 은 CPU 경로로 설계해야 한다. **octopus 노드가 1 TB RAM** 인 것을 처음 확인했다(shepherd 251 GB) — 지금까지의 슬롯 계산이 전부 251 GB 기준이라 octopus 에서는 과하게 보수적이다. 세 세션이 동시에 repo 를 고치고 있어 AGENTS.md 에 조율 규칙을 넣었다(소유 구분, 충돌 잦은 파일, PR 전 merge-tree 확인, 남의 실측을 덮어쓰지 않기).
- 2026-09-22 밤 — SV 5런 최종 수치 확정. **"세대 순서가 소변이와 같다"는 앞선 보고를 정정한다** — `CCS_15kb`(Sequel I)가 F1 .8333 으로 `SequelII_CCS_11kb`(.8275)보다 위라 Sequel I 두 런이 Sequel II 를 사이에 두고 갈라진다. **소변이 순위와도 뒤집힌다**: `CCS_15kb` 는 INDEL 19런 중 최하위(F1 .9282)인데 SV 는 5런 중 3위다. 런을 하나의 품질 축으로 줄 세우면 안 된다. refine 이득은 +4.9~5.4점으로 phase2 ONT(+4.8~5.1)와 거의 같다 — 표현 정규화라는 설명과 맞는다. phase1 벤치마킹은 **채점 가능한 전량 완료**(소변이 19런, SV 5런). 남은 것은 #8·#9.
- 2026-09-22 저녁 — SV 5런 `-t 8` 로 전량 완주(maxvmem 91.6~136.2 GB). **"메모리가 스레드에 비례한다"는 앞선 판단을 정정한다** — 같은 데이터로 `-t 22 -> 8` 하니 스레드 64% 감소에 메모리는 29~46%만 줄었다. 가장 큰 영역 하나의 작업 공간이 고정분으로 남는 것으로 보인다. 초판의 비례 주장은 ONT(-t 8)와 HiFi(-t 22)를 비교한 것이라 데이터셋 차이가 섞여 있었다. **제어 수단은 스레드가 아니라 동시 실행 수** — `BENCH_SV_SLOTS` 를 33(노드당 1잡)으로 올렸다. 22슬롯이면 최악 257 GB 로 251 GB 초과다.
- 2026-09-22 — **phase2 HG002 R10.4.1 완주 확인**(155279, exit_status 0, 58,791s = 16h20m, maxvmem 66.2 GB / 30슬롯, shepherd-1-8). `30_verify_outputs.sh` OK 1/1 — dv 산출물 포함 전부 있다. `aligned_bam_realign` 진입이 실전에서 처음 증명됐고, 이 런 하나가 R10 소변이·R10 SV·DeepVariant 채점 셋을 동시에 연다. 이어서 `35_review_qc.py --pass-counts` 가 `PermissionError: 'bcftools'` 로 죽어 도구 해석을 고쳤다(decisions 2026-09-22).
- 2026-09-22 14:50 — phase1 SV 5런을 `-t 8` 로 전량 재제출(156037~156041). 앞선 `-t 22` 4런 결과는 유효하지만 죽은 1런과 조건을 맞추려 통일했다. **SV 수치 서술 정정**: "truth 28,123 중 ~20,600개를 찾는다"는 `comp cnt`(우리가 부른 수)를 recall 분자로 잘못 쓴 것이었다 — 실제로 찾은 건 `TP-base` 21,282~22,147개다(PR #22 Codex 지적). 추적 안 되던 항목 #8(HG008 9런 등록)·#9(somatic 평가 설계)·#10(표준화 백로그)을 표에 올렸다.
- 2026-09-22 저녁 — phase1 SV 첫 실측. **recall이 문제다** — precision 0.90 고른데 recall 0.757~0.788, pbsv가 truth 28,123개 중 21,282~22,147개를 찾고 5,976~6,841개를 놓친다(v5.0q가 T2T-Q100 유래라 어려운 영역을 많이 담은 탓으로 추정, 미확인). **`-t`를 NSLOTS에 묶어 둔 것이 ENOMEM을 만들었다** — abPOA 메모리가 스레드에 비례해서 22슬롯 2잡이 겹치자 380 GB를 요구했다. `BENCH_SV_THREADS`로 분리.
- 2026-09-22 — phase1 hap.py 19잡 완료(전부 exit 0). **SNP는 전 런 0.9984~0.9994로 포화, INDEL은 기기 세대가 가른다** — Sequel I 2런이 0.928·0.965로 나머지(0.975~0.997)와 확연히 갈리고, DeepVariant가 기기별 모델 없이 같은 격차를 내므로 caller 모델 탓이 아니다. **Revio에서만 Clair3가 DeepVariant에 INDEL −0.006~−0.017로 진다**(모델은 `hifi_revio` 제대로 받았다). 같은 날 노드 집합이 octopus 2 + shepherd 2로 바뀌어 큐/노드 해석을 `qstat -f` 대조 방식으로 교체.

- 2026-09-21 — 문서 생성. phase3 첫 실행이 markdup에서 전부 죽음(GATK 4.6.1.0 vs Java 8). Codex 앱 세션 "Fix server Java version for GATK"가 원인·래퍼·MGISEQ HG002 BAM 누락을 찾음. 20 샘플 BAM은 온전(idxstats 대조).
