# HG002 R10 진입 타입 정정과 스모크 테스트 구멍 (2026-09-21)

PR #17로 편입한 HG002 R10 런을 **ONT 정렬 그대로 쓰는 대신 재정렬하도록** 고치고, 그 과정에서
드러난 스모크 테스트의 빈 구멍을 메웠다. 판단 근거는 [docs/decisions.md](../decisions.md)의
같은 날짜 항목.

## 무엇이 잘못됐나

PR #17에서 이 런을 `aligned_bam` 진입으로 넣었다. 사용자가 파이프라인 설계 때 준 원칙이
"fastq가 있으면 fastq부터 시작하고, **GIAB의 run 결과물(aligned bam 포함)을 믿기보다 우리가 한
결과물을 믿는다**"였는데, `aligned_bam` 진입이 코드에만 있고 쓰는 런이 하나도 없던 이유가 그것이다.
"쓸 수 있는 가장 raw한 형태"로만 읽고 넘어갔다.

더 중요한 건 **이 런을 넣은 목적이 R9↔R10 비교**라는 점이다. 나머지 14런은 우리 정렬이므로
이 하나만 ONT 정렬이면 차이가 케미스트리 때문인지 정렬 때문인지 못 가른다. PR #17은 그걸
"교란으로 기록해 둔다"로 처리했는데, 기록으로 넘길 게 아니라 없앴어야 했다.

## 실행 기록

```bash
# 1) 다운로드 (성공) — 160 GiB + .bai, md5 검증 통과
bash phase2_ont/scripts/02_fetch_external_reads.sh

# 2) 제출 — jobid 155216. entry=aligned_bam 으로 나갔다 (원칙 위반, 아래)
bash phase2_ont/scripts/10_submit.sh HG002.ONT-R10_giab2025.01_PAW70337

# 3) 스모크 테스트 (서버, main 기준) — 통과하지만 진입 타입 셋 중 둘만 덮는다
bash phase2_ont/scripts/04_stub_test.sh
#   ont-wgs v0.1.0 | 4 row(s), 1 sample-dataset group(s), 3 unit(s)
#   프로세스 22개 완주, 산출 파일명 13개 전부 OK

# 4) 재제출 — jobid 155268. **여전히 entry=aligned_bam**
bash phase2_ont/scripts/10_submit.sh HG002.ONT-R10_giab2025.01_PAW70337
```

**155216·155268 둘 다 폐기했다(`qdel`).** 4)가 또 옛 진입 타입으로 나간 이유는 수정이 PR 브랜치에만
있고 main에 머지되지 않아 `git pull`이 "Already up to date"였기 때문이다. 3)의 stub도 같은 이유로
옛 판이 돌았다(출력이 `4 row(s)`, 실행 1회 — 새 판은 5행에 실행 2회다).

→ **교훈: 브랜치의 파이프라인 변경을 서버에서 확인하려면 머지가 먼저다.** 제출 로그의
`entry=` 값이 기대와 다르면 코드가 안 왔다는 신호다 — 이번에 그 값이 아니었으면 몇 시간 뒤에나 알았다.

## 고친 것

- 진입 타입 **`aligned_bam_realign`** 추가. 정렬 BAM에서 `samtools fastq`로 리드를 꺼내 우리
  minimap2로 다시 정렬한다. uBAM 진입과 같은 경로라 프로세스 추가는 없다.
- 채널 재그룹에서 `type: 'ubam'`이 리터럴로 박혀 있어 **새 진입 타입이 그 지점에서 유실됐다**.
  그룹 키에 넣어 살렸다. 안 고쳤으면 realign 런이 uBAM으로 취급돼 아래 태그 문제를 그대로 맞았다.
- **MM/ML을 넘기지 않는다.** 역가닥 정렬 리드는 SEQ가 역상보로 저장돼 있고 `samtools fastq`가
  그걸 되돌리는데, MM 오프셋이 저장 방향에 묶여 있어 그대로 옮기면 메틸 위치가 어긋날 수 있다.
  samtools 문서(`fastq`·`reset`)가 이 경우를 다루지 않아 확인이 안 됐다. 목적이 변이 정확도이므로
  태그를 버렸다 — `35_review_qc.py`의 `MM%`가 `.`로 나오는 게 정상이다.
- 스모크 테스트가 진입 타입 셋 중 **둘만** 덮고 있었다. `test` 시트에 `aligned_bam_realign` 행을,
  `test_prealigned` 프로파일에 `aligned_bam` 단독 시트를 둬 셋을 다 덮는다. 단독 시트가 따로 필요한
  이유는 "모든 행이 `aligned_bam`이면 `MINIMAP2_INDEX`를 건너뛴다" 같은 조건이 섞인 시트에서는
  영영 거짓이기 때문이다.

## 검증 상태

| 항목 | 상태 |
|---|---|
| `bash -n` (04_stub_test.sh) | 통과 |
| 생성기 재실행 → 샘플시트 `aligned_bam_realign`, index 비움 | 확인 |
| main.nf 분기 검토 (VALID_TYPES·branch·재그룹·MINIMAP2_ALIGN) | 확인 |
| **Nextflow stub 실행 (새 판)** | **미실행** — 로컬에 nextflow 24.10.5가 없고, 서버는 머지 전이라 옛 판이 돌았다 |
| 실제 런 | 미실행 |

**머지 후 서버에서 `04_stub_test.sh`를 다시 돌려야 확정된다.** 새 판이면 출력이 `5 row(s)`에
stub 실행이 2회(`1/2`, `2/2`)로 나온다.

## 다음

```bash
cd ~/GIAB_benchmarking && git pull && bash phase2_ont/scripts/04_stub_test.sh
bash phase2_ont/scripts/10_submit.sh HG002.ONT-R10_giab2025.01_PAW70337   # entry=aligned_bam_realign 확인할 것
```
