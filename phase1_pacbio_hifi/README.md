# Phase 1 — PacBio HiFi: raw → VCF

GIAB PacBio HiFi 전 데이터셋을 **각자의 가장 raw한 형태부터** 정렬·변이 호출한다
(fastq > HiFi uBAM > aligned BAM 순. GIAB이 만든 처리 산출물은 무시하되 지우지 않음 — 2026-08-21 정책).
파이프라인: pbmm2 → DeepVariant + Clair3 → WhatsHap phase/haplotag → pbsv → QC.
[pipeline/pacbio-hifi-wgs](pipeline/pacbio-hifi-wgs/)는 bioinfo-agent에서 vendoring ([차이](pipeline/VENDORED.md)).

- 실행 단위: **38개** ([run_table.tsv](run_table.tsv)) = 카탈로그 HiFi 28행을 (sample, dataset)로 분해
  (HG008 T/N 분리, HG009 passage·클론 11개 분리). 잡 1개 = 실행 단위 1개.
- 진입점: fastq 17 / HiFi uBAM 21. **aligned BAM 진입은 없다** — HG001·HG005 SequelII 11kb도
  SRA에서 리드를 받아 fastq부터 돈다 (아래 SRA 항목).
- 이 중 4개는 `dup_of` 표시 — HG001·HG003·HG004·HG005의 chemistry2는 HudsonAlpha와 **movie가 동일**
  (형태만 fastq/uBAM). 기본 제출에서 빠지며, 돌릴 필요도 없다 (VCF가 필요하면 primary 결과를 복사).
- 산출: `/BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune/<sample>/PacBio/<dataset>/{02_alignedBAM,03_VCF,04_QC}`
- 입력 합계 3.13 TiB (중복 제외 2.73 TiB, 34 runs). 노드 3개 / 노드당 2잡이면 동시 6런, run당 1–3일 → 수 주.

## 실행 (nbb2 로그인 노드)

```bash
cd ~/GIAB_benchmarking && git pull    # 서버의 클론 위치 기준
cp phase1_pacbio_hifi/env.local.sh{.example,}              # 잡 크기 프리셋 선택 (안 하면 노드당 3잡 기본값)
bash phase1_pacbio_hifi/scripts/01_prepare_login_node.sh   # 1회: SGE 점검 + 컨테이너 11개 + 레퍼런스 + TRF bed
bash phase1_pacbio_hifi/scripts/02_fetch_sra_reads.sh      # 1회: HG001·HG005 리드 (SRA, 135 GiB)
bash phase1_pacbio_hifi/scripts/10_submit.sh --ready       # 준비된 것 전부 제출 (dup 제외; --list로 미리보기)
bash phase1_pacbio_hifi/scripts/20_status.sh               # 진행 대시보드 (입력/잡 상태/단계별 산출물)
bash phase1_pacbio_hifi/scripts/30_verify_outputs.sh       # 완료 검증 (dsid 인자 주면 그것만)
python phase1_pacbio_hifi/scripts/50_update_catalog.py     # 완료분 → 카탈로그+README 표 반영, git diff 보고 커밋
```

- 특정 것만: `10_submit.sh HG002.PacBio_CCS_15kb ...` / 로그: `tail -f $INFRA/logs/<dsid>.<jobid>.log`
- 잡이 죽으면 **같은 dsid로 재제출하면 -resume** 으로 이어서 돈다 (완료분 재계산 없음).
- 끝난 run의 중간 파일 정리: `scripts/40_clean_work.sh <dsid>` (verify 통과분만 지움).
- 다운로드가 진행 중이어도 된다 — `--ready`는 manifest와 크기까지 일치하는 실행 단위만 집는다.
  나중에 `--ready`를 다시 돌리면 새로 준비된 것들이 제출된다 (완료/실행 중인 것은 자동 스킵).

## 설정 (전부 [env.sh](env.sh))

| 항목 | 기본값 | 비고 |
|---|---|---|
| 큐/노드 | shepherd.q, shepherd-1-7/8/9 고정 | 계산 노드는 외부망 없음 → `NXF_OFFLINE`, 사전 캐시 |
| 잡 크기 | 21슬롯 / h_vmem 78G / Nextflow 70G = **노드당 3잡** | 노드는 64코어·251 GB. `h_vmem`은 consumable=NO라 **메모리가 예약되지 않는다** — 노드당 잡 수를 통제하는 건 슬롯뿐이므로 (노드당 잡 수)×`NF_LOCAL_MEM_GB` < 251을 지켜야 한다. 프리셋은 [env.local.sh.example](env.local.sh.example) |
| Nextflow | 24.10.5 + conda `nfcore312` (JDK17) | 잡 안에서 local executor로 완주 (SGE 자식 잡 없음) |
| 레퍼런스 | GRCh38_no_alt_analysis_set (release에서 복사) | 산출 파일명 라벨 `REF_NAME=GRCh38` |

- clair3 모델은 run_table의 값(m54→`hifi`, m64→`hifi_sequel2`, m84→`hifi_revio`)이 자동 적용된다.
- 샘플시트 재생성(경로 바꿀 때만): `python scripts/make_samplesheets.py --data-root <GIAB 루트>`
- gVCF가 필요해지면 `GVCF=1 FORCE=1 10_submit.sh <dsid>` 재제출 (-resume이라 DeepVariant만 다시 돈다).

## SRA 리드 (HG001·HG005 SequelII 11kb)

이 두 데이터셋만 GIAB FTP에 리드가 없다. GIAB는 정렬된 BAM만 올렸고 리드는 SRA에 있다
(HG001 PRJNA540705 / HG005 PRJNA540706). raw부터 돌리는 정책이라 SRA에서 직접 받는다.

- 대상: 샘플당 6 cell (11kb 4 + 9kb 2), 합계 **135 GiB**. 목록·크기·md5는 [sra_manifest.tsv](sra_manifest.tsv)
  (ENA filereport에서 생성). ENA HTTPS + `wget -c`라 중단 후 재실행하면 이어받는다.
- 저장 위치는 GIAB 미러와 섞이지 않게 `$GIAB_ROOT/sra/<PRJNA>/<sample>/<movie>.fastq.gz`.
  SRR 대신 movie ID로 저장하는 이유는 파일명이 파이프라인의 unit(=RG ID)이 되기 때문이다.
- **ENA 파일명이 `_subreads.fastq.gz`지만 CCS 리드다**: library_name이 `HG001-CCS-11kb-m64011...`이고
  cell당 ~1.5M reads / 평균 10 kb로 HiFi 수율이다. 다운로드 스크립트가 첫 리드 이름으로 최종 확인한다
  (CCS는 `<movie>/<zmw>/ccs`, subread는 `<movie>/<zmw>/<start>_<end>`). 여기서 걸리면 그냥 쓰지 말 것 —
  진짜 subreads면 samplesheet 진입 타입을 `subreads`로 바꿔 CCS 단계를 태워야 한다.
- GIAB의 정렬 BAM으로 되돌리려면 `make_samplesheets.py`의 해당 RUNS 항목을 `aligned_bam`으로 바꾸면 된다
  (git 이력에 이전 정의가 있다).
