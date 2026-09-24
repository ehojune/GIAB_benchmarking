# 2026-09-25 — md5 전수 검증(잡 156685) 집계와 FAIL 39건 전수 재확인

2026-09-24 10:44에 제출한 SGE 잡 **156685**(`giab_md5_all`, `sge_md5_verify.sh`, 8슬롯)가
2026-09-24 16:37:24에 끝났다(`qacct -j 156685`: failed=0, exit_status=0). 이 문서는 그 결과를
`SUMMARY=1 bash phase0_download/scripts/md5_verify_all.sh all`로 집계하고, FAIL 39건 전부를
라이브 FTP와 대조해 확정한 기록이다.

## 범위 — phase0 본체만, 4경로 합집합이 아니다

`md5_verify_all.sh`가 읽는 MANIFESTS는 `phase0_download/manifests/**`(GIAB FTP/S3 본체 +
release/rnaseq/trio_analysis)뿐이다. 외부 3경로(`phase1_pacbio_hifi/sra_manifest.tsv`,
`phase2_ont/ext_manifest.tsv`, `phase3_shortread_wgs/ext_manifest.tsv`, 합계 28 files)는
이 스크립트가 검사하지 않는다 — 각 phase가 자체 검증(`VERIFY_ONLY=1` 등)을 갖고 있다.
그래서 이번 md5 검증의 모집단은 **81,302**(phase0 본체 매니페스트 고유 키 수)다.
`fetch_all.sh`가 말하는 "81,330 files"(4경로 합집합)와 혼동하지 않는다.

## 판정별 집계 — 활성 매니페스트(81,302) 기준이 정본, 과거분 포함 총계는 참고용

`.md5_results.tsv`는 81,352줄, 고유 키도 81,352개(`sort | uniq -d` = 0줄) — **중복 로그 없음**. 다만 이 중
**50건은 현재 활성 매니페스트에 없는 과거(release 구버전) 키**다. 판정표를 두 기준으로 나눠 정확히 대조했다
(`.md5_results.tsv`를 활성 manifest 키 목록과 조인, 읽기 전용 — 재검증·재다운로드 없음):

| 판정 | **활성 매니페스트만 (81,302)** | 전체 결과(81,352, 과거 50건 포함) | 뜻 |
|---|---:|---:|---|
| PASS | **73,473** | 73,523 | current.tree md5 일치 |
| PASS_SIDECAR | 3,966 | 3,966 | tree에 없고 같은/상위 디렉토리 sidecar와 일치 |
| PASS_SIDECAR_TREE_STALE | 72 | 72 | tree와 다르지만 sidecar와는 일치 — tree가 낡은 것 |
| FAIL_BOTH | 5 | 5 | tree·sidecar 둘 다 불일치 (재확인 완료, 아래) |
| FAIL_TREE_ONLY | 32 | 32 | tree와 다르고 sidecar 없음 (재확인 완료, 아래) |
| FAIL_SIDECAR | 2 | 2 | tree에 없고 sidecar와 불일치 (재확인 완료, 아래) |
| NOREF | 3,752 | 3,752 | 참조 없음 — **검증 완료로 세지 않는다**(PASS 아님) |
| MISS | 0 | 0 | 로컬에 파일 없음(존재·크기 확보 실패) |
| **PASS\*** (체크섬 검증 통과) | **77,511** | 77,561 | 위 세 PASS* 합 |
| **FAIL\*** | **39** | 39 | 위 세 FAIL* 합 — 활성/전체 동일(과거 50건은 전부 PASS였다) |
| 합계 | 81,302 | 81,352 | — |

과거 50건과 활성 81,302건의 차이는 **PASS 칸에서만** 나타난다(73,523 − 73,473 = 50) — 나머지 판정(PASS_SIDECAR*,
FAIL*, NOREF, MISS)은 활성/전체가 완전히 같다. 즉 **과거 50건은 전부 PASS 판정**이었고, FAIL 39건은 전량 활성
매니페스트 안에 있다. 이하 이 문서의 나머지 수치(FAIL 39건 재확인 등)는 활성/전체 구분 없이 동일하다.

### manifest ↔ results 커버리지

- 현재 활성 manifest 고유 키: **81,302**
- manifest에 있는데 결과가 없음(미검사): **0** — 전수 커버 (파일 존재·크기 확보 + 체크섬 검증 모두 완료)
- 결과에는 있는데 현재 manifest에 없음(과거분): **50**
  - 이 50건은 전부 `release_stale_ftp_removed.tsv`와 일치한다(50/50), 전부 PASS 판정. `declined_by_decision.tsv`와의 교집합은 0.
  - 정체불명(둘 다 아닌) 항목: **0건**. 즉 81,352 − 50(과거 release 구버전, 전부 PASS) = 81,302로 현재 활성 manifest와 정확히 맞아떨어진다.

## FAIL 39건 전수 재확인 — 방법과 결과

각 FAIL 키에 대해 `.md5_results.tsv`에 이미 기록된 로컬 md5("actual")를 그대로 두고,
**HEAD로 크기를 먼저 확인한 뒤 GIAB FTP에서 별도 임시 경로로 새로 받아** md5를 다시 계산해
"지금 FTP가 실제로 서비스하는 내용"과 대조했다(`.md5_results.tsv`는 전 과정에서 한 글자도 건드리지 않았다).

| 재확인 결과 | 건수 | 조치 |
|---|---:|---|
| `LOCAL_OK_REF_STALE` — 새로 받은 내용이 로컬과 바이트 동일 | 34 | 없음. tree/자기참조 sidecar가 낡았을 뿐 실제 손상이 아니다 |
| `SWAPPED_OK` — 새로 받은 내용이 로컬과 다름(GIAB가 실제로 갱신) | 5 | 로컬 원본을 `<path>.bak-20260925`로 보존 후 새 내용으로 교체, 최종 md5가 새로 받은 내용과 일치함을 재확인 |
| `FETCH_FAILED` / `SWAP_VERIFY_FAILED` | 0 | — |

`LOCAL_OK_REF_STALE` 34건에는 `data/AshkenazimTrio/HG003.../hs37d5/HG003.hs37d5.consensusalignments.bam.bai`
(실제 인덱스 데이터, 23.6 MB, 완전 일치)와 `release/*/latest/*/.DS_Store` 4건(mac 메타 파일, `latest/`가
가변임은 이미 알려진 사실 — Yuan `data.giab-latest-dir-is-mutable`), 나머지는 전부 README·checksums.md5
자기참조 파일이다. **39건 중 실제 시퀀싱/정렬 데이터는 `.bai` 1건뿐이었고 그것도 문제가 없었다.**

### 교체된 5건 (전부 텍스트 README, 시퀀싱 데이터 아님)

| 파일 | 이전 바이트 | 새 바이트 | 백업 |
|---|---:|---:|---|
| `data/AshkenazimTrio/HG002_NA24385_son/Element_AVITI_20231018/README_Element.md` | 12,518 | 12,516 | `.bak-20260925` |
| `data/AshkenazimTrio/HG002_NA24385_son/NIST_Stanford_Illumina_6kb_matepair/README.NIST_Stanford_Illumina_6kb_matepair` | 4,696 | 4,758 | `.bak-20260925` |
| `data/ChineseTrio/HG005_NA24631_son/HudsonAlpha_PacBio_CCS/README_PacBio-CCS_HudsonAlpha_HG005.md` | 7,754 | 7,920 | `.bak-20260925` |
| `data/NA12878/Garvan_NA12878_HG001_HiSeq_Exome/Garvan_NA12878_HG001_HiSeq_Exome.README` | 1,376 | 1,089 | `.bak-20260925` |
| `data/NA12878/ion_exome/README.txt` | 1,259 | 799 | `.bak-20260925` |

이 5건은 매니페스트에 기록된 바이트 수도 갱신했다(아래) — 안 하면 다음 `verify.sh`/`download.sh`가
허위 크기 불일치를 낸다.

## 매니페스트·생성 문서 갱신

- `phase0_download/manifests/HG001/exome.tsv`(2줄), `HG002/other.tsv`, `HG002/illumina_wgs.tsv`,
  `HG005/pacbio_hifi.tsv` — 위 5개 키의 바이트를 교체 후 실측값으로 수정.
- `docs/SIZES.md` — `python phase0_download/scripts/build_sizes.py`로 재생성(플랫폼 행 5개 + 합계 줄,
  총 −521 bytes, GiB 반올림에는 영향 없음).
- `catalog/master_catalog.tsv` → `README.md`는 `build_readme.py` 재실행 결과 **diff 0**(카탈로그는
  플랫폼 디렉토리 단위 GiB 반올림이라 521바이트 델타로는 안 움직인다) — 재생성 불필요, 멱등 확인만 했다.

## 문서 수치 불일치 2건도 처리 (backlog.md)

PacBio 세션이 2026-09-23에 남긴 다운로드 세션 몫 "문서 수치 불일치" 2건은 이미 PR #37(2026-09-23)에서
고쳐져 있었다 — README.md 607행과 phase0_download/README.md 5행 모두 "FTP 본체 81,302"와
"4경로 전체 81,330/81,316"을 구분해 적은 문장이 들어가 있다. backlog.md 규약("끝나면 이 절을 지우고
STATUS 이력에 한 줄")대로 해당 절을 지웠다.

## 결론

phase0 본체(GIAB FTP/S3 — 활성 manifest 81,302 files, 외부 28 files는 각 phase 자체 검증 대상이라 이 수치 밖) 중
**파일 존재·크기는 81,302/81,302 전수 확보**됐고, 그중 **체크섬까지 검증 통과(PASS*)한 것은 77,511**이다.
미참조(NOREF) 3,752는 크기만 확보됐을 뿐 체크섬 검증은 아직이라 PASS로 세지 않는다.
FAIL 39건은 전수 재확인을 마쳤고 **실제 데이터 손상은 0건**이었다 — 5건은 GIAB 쪽 README 갱신을
반영해 교체(원본 보존), 34건은 참조(tree/sidecar)가 낡았을 뿐 로컬 파일이 이미 옳았다.
같은 전수 잡은 재제출하지 않았다(잡 156685 결과를 그대로 사용).

## 남은 것 — NOREF 3,752건

이번 재실행에서 처리 대상이 아니었다(요청 범위 밖). 참조(tree 항목도 sidecar도)가 아예 없는 파일이라
현재는 크기 일치로만 검증된 상태다. 성격 파악(신규 크롤 파일 비중, 확장자 분포 등)과 처리 방침은
필요해지면 별도로 진행한다.
