# 2026-09-23 — md5 전수 검증 중간 상태와 방법 수정

## 지금까지 (2026-09-09 결과 파일 기준, 서버 실측)

`$GIAB_ROOT/.md5_results.tsv` (13.6 MB, 마지막 갱신 2026-09-09 16:33):

| 판정 | 파일 |
|---|---|
| PASS | 73,485 |
| FAIL | 110 |
| NOREF | 3,000 |
| 미검사 | 4,759 (8.67 TiB) — 2026-09-16 크롤로 추가된 파일. 결과 파일이 그 전 것이다 |

FAIL 110의 구성: 문서·텍스트 75 (README, checksums.md5, .tsv, .gv), 인덱스 12 (.bai 등), 데이터 12 (BAM·fastq.gz), 기타 11.
데이터 12개는 HG008 Northeastern ONT-std BAM 8, HG008 UCSC ONT-UL BAM 2, HG002 SequelII haplotag BAM 1, HG006 CCS fastq 1.

## 왜 FAIL이 나오나 — current.tree가 낡았다

참조로 쓴 `current.tree`는 **FTP 원본 자체가 2025-02-28 이후 갱신되지 않았다**(파일 자기 항목의 날짜는 2024-03-25, 크기 20,758,013 바이트가 2026-08과 2026-09-23에 동일). 반면 매니페스트 크기는 2026-09 라이브 HEAD 값이고 디스크 크기는 그것과 전부 일치한다(2026-09-22 전수 대조). 즉 FAIL 파일은 **GIAB가 tree 갱신 뒤 바꾼 파일**일 가능성이 높다 — README·checksums.md5 같은 문서가 75건인 것이 그 신호다. 다만 tree만으로는 stale인지 손상인지 가릴 수 없다.

## 방법 수정 (이 PR)

`md5_verify_all.sh`:

1. **sidecar 인식 확대** — 기존 패턴(md5.in, MD5, md5sum.txt, *.md5, *_md5sum, *.md5sums)이 매니페스트 실측의 주류를 놓쳤다: `checksums.md5` 132개(HG008 NIST 트리), `md5sum` 59, `md5sum.chk` 4, `*md5sum*.txt` 등. 이 때문에 2026-09-16 추가분 대부분이 NOREF로 빠질 판이었다.
2. **tree 불일치 → sidecar 2차 판정** — tree와 다르면 같은 디렉토리 sidecar와 다시 비교한다. sidecar가 맞으면 `PASS_SIDECAR_TREE_STALE`(tree가 낡은 것), 둘 다 틀리면 `FAIL_BOTH`(손상 의심), sidecar가 없으면 `FAIL_TREE_ONLY`(판정 불가)로 갈라 적는다.
3. 참조가 하나도 없는 파일은 읽지 않는다(NOREF) — 107 TiB에서 불필요한 읽기를 줄인다.

`sge_md5_verify.sh`: 로그인 노드가 아니라 SGE 잡으로 돌린다(8 슬롯 = md5 8 병렬). 계산 노드는 외부망이 없어 current.tree는 제출 전에 로그인 노드가 받아둔다.

## 재실행 준비 (서버, 2026-09-23)

- `.md5_results.tsv` → `.md5_results.tsv.bak-20260909` 백업, FAIL 110 목록 → `.md5_fail_20260909.txt`
- 결과 파일에서 FAIL·NOREF 행을 지워 재검사 대상에 넣었다 (PASS 73,485만 유지)
- 잡 156589(옛 스크립트)로 먼저 제출했다가 sidecar 누락을 확인해 **취소하고, 이 PR 머지 후 새 스크립트로 재제출**. 잡 ID는 STATUS 이력에.

재검사 대상 = 4,759(신규) + 110(FAIL) + 3,000(NOREF) ≈ 7,870 files. 결과가 나오면 이 문서의 후속 기록에 판정별 수치를 적는다.
