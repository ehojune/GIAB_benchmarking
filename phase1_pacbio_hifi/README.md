# Phase 1 — PacBio HiFi: raw → VCF

GIAB PacBio HiFi 전 데이터셋을 **각자의 가장 raw한 형태부터** 정렬·변이 호출한다
(fastq > HiFi uBAM > aligned BAM 순. GIAB이 만든 처리 산출물은 무시하되 지우지 않음 — 2026-08-21 정책).
파이프라인: pbmm2 → DeepVariant + Clair3 → WhatsHap phase/haplotag → pbsv → QC.
[pipeline/pacbio-hifi-wgs](pipeline/pacbio-hifi-wgs/)는 bioinfo-agent에서 vendoring ([차이](pipeline/VENDORED.md)).

- 실행 단위: **38개** ([run_table.tsv](run_table.tsv)) = 카탈로그 HiFi 28행을 (sample, dataset)로 분해
  (HG008 T/N 분리, HG009 passage·클론 11개 분리). 잡 1개 = 실행 단위 1개.
- 이 중 4개는 `dup_of` 표시 — HG001·HG003·HG004·HG005의 chemistry2는 HudsonAlpha와 **movie가 동일**
  (형태만 fastq/uBAM). 기본 제출에서 빠지며, 돌릴 필요도 없다 (VCF가 필요하면 primary 결과를 복사).
- 산출: `/BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune/<sample>/PacBio/<dataset>/{02_alignedBAM,03_VCF,04_QC}`
- 입력 합계 3.1 TiB (중복 제외 2.7 TiB, 34 runs). 21코어 잡 기준 run당 대략 1–3일 → 노드 3개로 수 주.

## 실행 (nbb2 로그인 노드)

```bash
cd ~/GIAB_benchmarking && git pull    # 서버의 클론 위치 기준
bash phase1_pacbio_hifi/scripts/01_prepare_login_node.sh   # 1회: 컨테이너 11개 + 레퍼런스 + TRF bed
bash phase1_pacbio_hifi/scripts/10_submit.sh --list        # 준비 상태 확인 (input=ready인 것만 제출됨)
bash phase1_pacbio_hifi/scripts/10_submit.sh --ready       # 준비된 것 전부 제출 (dup 제외)
qstat -u $USER                                             # 잡 상태
bash phase1_pacbio_hifi/scripts/30_verify_outputs.sh       # 완료 검증 (dsid 인자 주면 그것만)
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
| 잡 크기 | `SGE_SLOTS=21`, `SGE_VMEM=80G`, `NF_LOCAL_MEM_GB=72` | nanoseq 검증값. `qhost`로 노드 RAM 확인 후 키우면 빨라짐 (특히 100x+ 데이터: HG008-T 116x, HG009T-p16 140x) |
| Nextflow | 24.10.5 + conda `nfcore312` (JDK17) | 잡 안에서 local executor로 완주 (SGE 자식 잡 없음) |
| 레퍼런스 | GRCh38_no_alt_analysis_set (release에서 복사) | 산출 파일명 라벨 `REF_NAME=GRCh38` |

- clair3 모델은 run_table의 값(m54→`hifi`, m64→`hifi_sequel2`, m84→`hifi_revio`)이 자동 적용된다.
- HG001·HG005 `PacBio_SequelII_CCS_11kb`는 리드가 SRA에만 있어 GIAB **GRCh38 정렬 BAM에서 시작**
  (aligned_bam 진입 — 02_alignedBAM 미발행이 정상). 잡이 CHECK_BAM의 reference mismatch로 죽으면
  그 BAM의 GRCh38 변종이 달라서다: `REF_FASTA=<맞는 fasta> REF_NAME=<라벨> 10_submit.sh <dsid>`로 재제출.
- 샘플시트 재생성(경로 바꿀 때만): `python scripts/make_samplesheets.py --data-root <GIAB 루트>`
- gVCF가 필요해지면 `GVCF=1 FORCE=1 10_submit.sh <dsid>` 재제출 (-resume이라 DeepVariant만 다시 돈다).
