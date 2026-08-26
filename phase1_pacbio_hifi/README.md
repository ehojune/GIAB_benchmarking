# Phase 1 — PacBio HiFi: raw → VCF

GIAB PacBio HiFi 전 데이터셋을 **각자의 가장 raw한 형태부터** 정렬·변이 호출한다
(fastq > HiFi uBAM > aligned BAM 순. GIAB이 만든 처리 산출물은 무시하되 지우지 않음 — 2026-08-21 정책).
파이프라인: pbmm2 → DeepVariant + Clair3 → WhatsHap phase/haplotag → pbsv → QC.
[pipeline/pacbio-hifi-wgs](pipeline/pacbio-hifi-wgs/)는 bioinfo-agent에서 vendoring ([차이](pipeline/VENDORED.md)).

```mermaid
flowchart TD
    SUB["subreads 진입<br/>phase1 0 런"]
    HB["HiFi uBAM 진입<br/>phase1 21 런"]
    HF["HiFi fastq 진입<br/>phase1 17 런"]
    AB["aligned BAM 진입<br/>phase1 0 런"]

    SUB -->|"pbccs 6.4.0<br/>8 chunk + pbmerge"| CCS["HiFi uBAM<br/>01_HIFI/"]
    CCS --> PM
    HB --> PM["pbmm2 26.2.0<br/>--preset CCS"]
    HF --> PM
    PM --> FIN["samtools merge / index<br/>02_alignedBAM/"]
    AB --> FIN
    FIN --> CHK{"CHECK_BAM<br/>레퍼런스 contig 대조<br/>mapped 0 이면 중단"}

    CHK --> DV["DeepVariant 1.10.0<br/>PACBIO<br/>03_VCF/deepvariant/"]
    CHK --> C3["Clair3 v1.2.0<br/>hifi / hifi_sequel2 / hifi_revio<br/>03_VCF/clair3/"]
    CHK --> PS["pbsv 2.11.0<br/>discover + call<br/>03_VCF/SV_pbsv/"]

    DV --> WP["WhatsHap 2.8 phase<br/>03_VCF/phased_whatshap/"]
    WP --> WH["WhatsHap haplotag<br/>02_alignedBAM/haplotagged/"]

    DV --> SP["bcftools norm -m -any + view<br/>03_VCF/SNV_* · INDEL_*"]
    C3 --> SP

    CHK --> QC["mosdepth 0.3.14<br/>samtools stats"]
    DV --> VS["bcftools stats"]
    C3 --> VS
    PS --> VS
    WP --> WS["whatshap stats<br/>위상 블록 지표"]
    QC --> MQ["MultiQC 1.35<br/>multiqc/dsid/"]
    VS --> MQ
    WS --> MQ
```

ONT 쪽 같은 그림은 [phase2_ont/pipeline/ont-wgs/README.md](../phase2_ont/pipeline/ont-wgs/README.md).
차이는 정렬(pbmm2→minimap2), SV(pbsv→Sniffles2), 위상(WhatsHap→LongPhase), 그리고 R9.4.1에서 DeepVariant가 빠지는 것이다.

- 실행 단위: **38개** ([run_table.tsv](run_table.tsv)) = 카탈로그 HiFi 28행을 (sample, dataset)로 분해
  (HG008 T/N 분리, HG009 passage·클론 11개 분리). 잡 1개 = 실행 단위 1개.
- 진입점: fastq 17 / HiFi uBAM 21. **aligned BAM 진입은 없다** — HG001·HG005 SequelII 11kb도
  SRA에서 리드를 받아 fastq부터 돈다 (아래 SRA 항목).
- 이 중 4개는 `dup_of` 표시 — HG001·HG003·HG004·HG005의 chemistry2는 HudsonAlpha와 **movie가 동일**
  (형태만 fastq/uBAM). 기본 제출에서 빠진다. 다만 카탈로그상 별개 데이터셋이라 "전부 VCF까지" 정책을
  문자 그대로 채우려면 돌려야 하고, 실측 기준 4개(406 GiB) 동시 실행에 6~7시간이면 끝난다:
  `DUP_OK=1 scripts/10_submit.sh <dsid>` (돌리지 않으면 `50_update_catalog.py`가 그 4행을 계속 "대기"로 보고).
- 산출: `/BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune/<sample>/PacBio/<dataset>/{02_alignedBAM,03_VCF,04_QC}`
- 입력 합계 3.13 TiB (중복 제외 2.73 TiB, 34 runs). 노드 3개 / 노드당 2잡 = 동시 6런.

**실측 (2026-08-21, 30슬롯 잡, 첫 4런 완주)**

| 실행 단위 | 커버리지 | 입력 | wallclock | maxvmem |
|---|---|---|---|---|
| HG001.HudsonAlpha_PacBio_CCS | (미기재) | 65.9 GiB | 5h50m | 53.8 GB |
| HG002.PacBio_CCS_10kb | 약 30x | 165.5 GiB | 5h58m | 48.4 GB |
| HG002.PacBio_CCS_15kb | 약 28x | 166.2 GiB | 7h17m | 45.1 GB |
| HG002.PacBio_SequelII_CCS_11kb | 약 32x | 78.4 GiB | 6h46m | 43.1 GB |

커버리지는 카탈로그 값. 넷 다 `exit_status 0`.

- **메모리는 준 110 GB의 절반도 안 썼다** (피크 43~54 GB). 30x 기준이므로 HG008(106~116x)·
  HG009(61~140x)도 한도 안에 들어올 가능성이 높다 — 현재 설정 그대로 두면 된다.
- 시간은 6~7h/런. 커버리지에 비례해 늘어나므로 고심도 런은 12~25h 대로 예상,
  전체 32런 종료까지 **2~4일** 규모 (동시 6런).

## 실행 (nbb2 로그인 노드)

```bash
cd ~/GIAB_benchmarking && git pull    # 서버의 클론 위치 기준
cp phase1_pacbio_hifi/env.local.sh{.example,}              # 잡 크기 프리셋 선택 (안 하면 노드당 3잡 기본값)
bash phase1_pacbio_hifi/scripts/01_prepare_login_node.sh   # 1회: SGE 점검 + 컨테이너 13개(파이프라인 11 + 벤치 2) + 레퍼런스 + TRF bed
bash phase1_pacbio_hifi/scripts/02_fetch_sra_reads.sh      # 1회: HG001·HG005 리드 (SRA, 135 GiB)
bash phase1_pacbio_hifi/scripts/10_submit.sh --ready       # 준비된 것 전부 제출 (dup 제외; --list로 미리보기)
bash phase1_pacbio_hifi/scripts/20_status.sh               # 진행 대시보드 (입력/잡 상태/단계별 산출물)
bash phase1_pacbio_hifi/scripts/30_verify_outputs.sh       # 산출물 존재 검증 (dsid 인자 주면 그것만)
python phase1_pacbio_hifi/scripts/35_review_qc.py          # QC 지표 리뷰 (이상치 표시; --tsv 로 요약 저장)
bash phase1_pacbio_hifi/scripts/36_multiqc_all.sh          # 전 런을 MultiQC 리포트 하나로 병합
python phase1_pacbio_hifi/scripts/50_update_catalog.py     # 완료분 → 카탈로그+README 표 반영, git diff 보고 커밋
bash phase1_pacbio_hifi/scripts/60_benchmark.sh --list     # 정확도 평가 대상 확인 (truth set 유무)
bash phase1_pacbio_hifi/scripts/60_benchmark.sh --ready    # hap.py 제출 (HG001~HG007)
bash phase1_pacbio_hifi/scripts/60_benchmark.sh --collect  # 결과를 한 TSV로 모음
```

- 특정 것만: `10_submit.sh HG002.PacBio_CCS_15kb ...` / 로그: `tail -f $INFRA/logs/<dsid>.<jobid>.log`
- 잡이 죽으면 **같은 dsid로 재제출하면 -resume** 으로 이어서 돈다 (완료분 재계산 없음).
- 끝난 run의 중간 파일 정리: `scripts/40_clean_work.sh <dsid>` (verify 통과분만 지움).
- **30은 파일이 있는지만 본다.** 커버리지가 반토막이거나 변이 수가 두 배거나 위상이 거의 안 잡힌
  런도 통과한다. `35_review_qc.py`가 그 틈을 메운다 — 파이프라인이 이미 만든 QC 파일
  (mosdepth·samtools stats·bcftools stats·whatshap stats·MultiQC)만 읽어서 실행 단위별로
  커버리지·매핑률·error rate·리드길이·SNP/INDEL 수·ts/tv·SV 수·위상 비율·block N50을 표로 뽑고,
  기준을 벗어난 것과 **DeepVariant↔Clair3 불일치(20% 이상)** 를 표시한다. 새로 계산하지 않아 몇 초면 끝난다.
  기준값은 스크립트 맨 위 `TH` dict에서 조정한다. 종양(HG008-T·HG009T-*)은 LOH·배수성 때문에
  변이 수 검사에서 면제하고 위상 하한도 따로 쓴다 (정상 70% / 종양 55%).
  **변이 수·ts/tv·caller 일치는 `--pass-counts`를 붙일 때만 판정한다** — 파이프라인의
  `bcftools stats`가 PASS 필터 없이 돌아 RefCall이 섞인 raw 카운트라서, 그대로 판정하면 전건 오탐이 난다.
  exit 1은 QC 파일 자체가 없을 때만이고(파이프라인 QC 스테이지 실패), 기준 초과는 경고로만 남긴다.
  `50_update_catalog.py`의 완료 판정도 30과 같은 파일 목록이라 QC 내용은 보지 않는다 — 35를 별도로 돌릴 것.
- **다운로드가 진행 중이어도 그냥 제출하면 된다.** `--ready`는 입력이 (1) manifest와 크기가 같고
  (2) 최근 10분간 쓰이지 않은 실행 단위만 집는다. 나중에 다시 돌리면 새로 준비된 것이 제출된다
  (완료/실행 중인 것은 자동 스킵). 대기 시간은 `READY_AGE_MIN=N`으로 조정.
  - mtime까지 보는 이유: phase0의 기본 경로 `aws s3 cp`는 `.part` 없이 최종 파일명에 바로 쓰고
    대용량은 멀티파트로 오프셋에 나눠 쓴다. 뒤쪽 파트가 먼저 도착하면 **크기는 최종값인데
    중간이 빈 구멍인** 순간이 생겨서, 크기만 보면 완료로 오판한다. (wget 경로는 `.part`→`mv`라 무관)
  - `20_status.sh`의 input 열에서 `settling`이 그 상태다. 다운로드가 끝난 뒤에도 계속 `settling`이면
    그 파일을 실제로 쓰는 중이 아닌지(`ls -l --time-style=full-iso`) 확인할 것.

## 정확도 평가 ([60_benchmark.sh](scripts/60_benchmark.sh))

GIAB truth set 대비 hap.py. germline small variant만 — **HG001~HG007 23런**이 대상이고
HG008·HG009는 germline truth가 없어 자동으로 빠진다.

- 입력은 `03_VCF/<caller>/*.vcf.gz` **원본**이다. hap.py가 FILTER를 자체 처리해
  `summary.csv`에 ALL 행과 PASS 행을 둘 다 내므로, PASS 필터가 없는 파이프라인 산출물을
  그대로 넣고 PASS 행을 읽으면 된다. **재실행이 필요 없다.**
  `SNV_*`/`INDEL_*` 분리본은 넣지 않는다 — hap.py 자체 분류와 어긋난다.
- truth set은 `release/*/NISTv4.2.1/GRCh38/`에서 자동 탐색한다. 경로 깊이와 BED 이름이
  샘플마다 다르다: HG001은 `release/NA12878_HG001/`, HG002~HG007은 `release/<Trio>/<Sample>/`,
  Ashkenazim 트리오(HG002~HG004)의 BED은 `_benchmark_noinconsistent.bed`다.
  truth VCF의 `.tbi`가 없으면 제출 단계에서 걸러낸다.
- 산출: `<dataset>/05_BENCH/happy/<id>.<caller>.summary.csv` 등. `--collect`가 이를 모아
  `phase1_bench_summary.tsv`(dsid × caller × SNP/INDEL × ALL/PASS)로 만든다.
- 잡 크기는 파이프라인보다 작다 (`BENCH_SLOTS=8`, `BENCH_VMEM=32G`) — hap.py는 병렬성이 낮다.
- 컨테이너는 `env.sh`의 `HAPPY_IMG`(`jmcdani20/hap.py:v0.3.12`, GIAB/NIST 문서가 쓰는 이미지)와
  `TRUVARI_IMG`. `nextflow.config`가 아니라 `env.sh`에 둔 이유는 파이프라인이 쓰지 않기 때문이고,
  `01_prepare_login_node.sh`가 `BENCH_IMAGES`도 함께 미리 받는다.

**SV와 somatic은 아직 못 한다.** SV는 Truvari v5.0+ (이미지는 핀해 뒀다). HG008-T somatic은
현행 기준인 smvar V0.3(2026-04-25)·stvar-CNV V0.5(2026-03-18)가 **매니페스트에 없다** —
받아둔 것은 stvar V0.1~V0.3(2025-02)뿐이다. 먼저 phase0 매니페스트에 추가해야 한다.
기준 근거는 [docs/reference/2026-08-26-hg008-benchmark-refresh.md](../docs/reference/2026-08-26-hg008-benchmark-refresh.md).

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
  cell당 1.3~1.8M reads / 평균 ~10 kb로 Sequel II HiFi 수율이다(진짜 subreads면 같은 cell에서
  리드가 수천만 개여야 한다). **ENA는 리드 이름을 `@SRR9001770.1`로 바꿔 배포하므로 이름으로는
  판정할 수 없다** — 다운로드 스크립트가 앞부분을 샘플링해 평균 리드 길이를 manifest 값과 대조한다.
  여기서 걸리면 그냥 쓰지 말 것: 진짜 subreads면 진입 타입을 `subreads`로 바꿔 CCS 단계를 태워야 한다.
- GIAB의 정렬 BAM으로 되돌리려면 `make_samplesheets.py`의 해당 RUNS 항목을 `aligned_bam`으로 바꾸면 된다
  (git 이력에 이전 정의가 있다).
