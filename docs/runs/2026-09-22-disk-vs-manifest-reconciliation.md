# 2026-09-22 — 서버 디스크 ↔ 매니페스트 4종 전수 대조

세 세션(PacBio·ONT·다운로드)이 각자 받은 것을 한 목록으로 맞추기 위해, nbb2 `/BiO/scratch/ehojune/GIAB_benchmark`
전체를 실측해 repo의 다운로드 목록과 파일 단위로 대조했다. **추정이 아니라 디스크가 기준이다.**

## 방법

로그인 노드에서 읽기 전용으로 한 번에 돌렸다 (HIWARE 터널, 결과만 회수).

- 대상: `find . -type f -printf '%P\t%s'` — `processed_data_ehojune/`(산출물 135,061 files), `repairs/`(재생성물 17), `logs/` 제외
- 기준 목록 = 네 매니페스트의 합집합
  - `phase0_download/manifests/HG00*/*.tsv` + `release_truthsets.tsv` + `rnaseq_all.tsv` + `trio_analysis.tsv` (GIAB FTP/S3)
  - `phase1_pacbio_hifi/sra_manifest.tsv` (ENA, `relpath`/`bytes`)
  - `phase2_ont/ext_manifest.tsv`, `phase3_shortread_wgs/ext_manifest.tsv` (`relpath`/`bytes`)
- 참고 목록: `declined_by_decision.tsv`(받지 않기로 함), `release_stale_ftp_removed.tsv`(FTP에서 삭제됨)
- 판정: 경로가 같고 바이트가 같으면 `ok`. 매니페스트에 없는 파일은 `EXTRA`, 매니페스트에 있는데 디스크에 없으면 `MISSING`.

## 결과

| 판정 | 파일 | 용량 | 뜻 |
|---|---|---|---|
| **ok** | **81,330 / 81,330** | 114.3 TiB | 네 경로의 매니페스트 전부가 디스크에 크기까지 일치 |
| mismatch | 0 | — | 크기가 다른 파일 없음 |
| missing | 0 | — | 매니페스트에 있는데 없는 파일 없음 (`MISSING 1`은 awk가 두 번째 ext_manifest 헤더 `relpath/bytes`를 키로 넣은 가짜) |
| stale_on_disk | 52 | 8.36 GiB | FTP에서 사라졐지만 디스크에는 남아 있음 — 아래 |
| declined_on_disk | 0 | — | 받지 않기로 한 것은 하나도 받지 않았음 |
| extra | 19 | 0.37 GiB | 매니페스트 밖 파일. **전부 비데이터** — 아래 |

경로별로 보면: `data/` 66,600 · `data_somatic/` 6,389 · `data_RNAseq/` 324 · `release/` 8,041(= 7,989 활성 + 52 stale) · `sra/` 24(= 12 fastq + 12 `.md5ok`) · `ext/` 6(= 4 + 2 `.md5ok`) · `external/` 14(= 12 fastq + `md5.txt` + 로그).

### stale_on_disk 52 (8.36 GiB)

`release_stale_ftp_removed.tsv`의 52건과 정확히 같은 집합이다. 2026-08에 받은 뒤 2026-09-16 크롤에서 FTP에 없음이 확인돼 활성 매니페스트에서 뺐다.

- 51건: `release/AshkenazimTrio/HG002_NA24385_son/latest/` — GIAB가 `latest/` 디렉토리를 재구성하면서 옛 경로가 사라졌다. 내용은 v4.2.1 벤치마크 파일이라 현재 `NISTv4.2.1/` 경로의 것과 중복일 가능성이 높지만 **바이트 대조는 하지 않았다**.
- 1건: `release/references/GRCh38/README_GIAB_Mapping_References.md.txt`

**처리 방침(이 PR): 지우지 않고 보유 목록에 남긴다.** 다시 받을 수 없는 파일이라 지우면 복구가 안 되고, 8 GiB는 부담이 아니다.
활성 매니페스트(= `fetch_all.sh`가 받는 목록)에는 넣지 않는다 — 원격에 없는 것을 받으려 하면 전건 실패로 찍힌다.

### extra 19 (0.37 GiB) — 전부 우리 도구가 만든 것

| 파일 | 크기 | 누가 만들었나 |
|---|---|---|
| `.current.tree` | 20.8 MB | `md5_verify_all.sh`/`md5_spotcheck.sh`가 받은 GIAB md5 목록 |
| `.md5_results.tsv` | 13.6 MB | `md5_verify_all.sh` 누적 결과 |
| `.download_failed.log` | 102 KB | `download.sh` 실패 로그 |
| `external/phase3_ext_fetch.log` | 360 MB | phase3 `02_fetch_external_reads.sh` 로그 (`exec > >(tee -a)` 누적) |
| `external/google_novaseq_pcrfree_30x/md5.txt` | 438 B | Google 배포 md5 목록 — phase3 스크립트가 검증용으로 받음. **매니페스트 밖의 유일한 "받은" 파일** |
| `sra/**/*.md5ok` 12개, `ext/**/*.md5ok` 2개 | 0~57 B | phase1·2 fetch 스크립트의 md5 통과 마커 |

시퀀싱 데이터는 하나도 없다. 즉 **매니페스트 밖에 받아둔 데이터는 없다.**

## 서버 repo 상태 (같은 시각)

`~/GIAB_benchmarking`는 main `4c7778f`(origin보다 1커밋 뒤). 미추적 파일 5개 — 다른 세션 산출물이라 여기서 판단하지 않는다:
`phase1_bench_summary.tsv`, `phase1_pacbio_hifi/env.local.sh.bak`, `phase1_pacbio_hifi/phase1_bench_sv_summary.tsv`,
`phase2_ont/phase2_bench_summary.tsv`, `phase2_ont/phase2_bench_sv_summary.tsv`.

## 재현

로그인 노드에서 (읽기 전용, 수 분):

```bash
cd ~/GIAB_benchmarking/phase0_download/manifests && ( cat HG00*/*.tsv release_truthsets.tsv rnaseq_all.tsv trio_analysis.tsv | awk -F'\t' '{print "M\t"$1"\t"$2}'; awk -F'\t' 'NR>1{print "M\t"$5"\t"$6}' ../../phase1_pacbio_hifi/sra_manifest.tsv; for f in ../../phase2_ont/ext_manifest.tsv ../../phase3_shortread_wgs/ext_manifest.tsv; do awk -F'\t' 'NR>1{print "M\t"$2"\t"$3}' "$f"; done; awk -F'\t' '!/^#/{print "S\t"$1"\t"$2}' release_stale_ftp_removed.tsv; cd /BiO/scratch/ehojune/GIAB_benchmark && find . \( -path ./processed_data_ehojune -o -path ./repairs -o -path ./logs \) -prune -o -type f -printf 'F\t%P\t%s\n' ) | awk -F'\t' '$1=="M"{m[$2]=$3;next} $1=="S"{s[$2]=1;next} {seen[$2]=1; if($2 in m){if(m[$2]==$3)ok++; else print "MISMATCH\t"$2} else if($2 in s) st++; else print "EXTRA\t"$2"\t"$3} END{for(k in m) if(!(k in seen)) print "MISSING\t"k; print "ok="ok" stale="st}'
```

(위 명령은 헤더 처리를 고쳐 `MISSING` 가짜 1건이 나오지 않는다.)
