# ONT 처리 에이전트 인계 프롬프트

phase1(PacBio HiFi)을 끝낸 방식 그대로 ONT를 처리할 에이전트에게 주는 지시문.
아래 전문을 그대로 전달하면 된다. 사실 확인이 필요한 부분은 "직접 확인할 것"으로 표시했다.

---

## 지시문 (여기부터 복사)

GIAB ONT 데이터를 raw 리드부터 정렬·변이 호출해 VCF까지 뽑는 `phase2_ont/`를 만들어라.
저장소는 https://github.com/ehojune/GIAB_benchmarking (nbb2 서버 `~/GIAB_benchmarking`).
**이미 끝난 `phase1_pacbio_hifi/`가 그대로 템플릿이다. 먼저 읽고 구조·명명·스크립트 번호 체계를 따라라.**

### 목표

- 실행 단위(=한 SGE 잡)마다 aligned BAM + SNV/INDEL VCF + SV VCF + phased VCF + QC
- 산출 위치: `/BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune/<sample>/ONT/<dataset>/`
  (phase1이 `<sample>/PacBio/<dataset>/`를 쓰므로 플랫폼 디렉토리만 다르다)
- 처리 현황을 `catalog/master_catalog.tsv`에 기록하고 루트 README 표를 재생성하는 스크립트
  (phase1의 `scripts/50_update_catalog.py`를 그대로 본떠라 — 카탈로그 행 하나는 소속 실행 단위가
  **전부** 검증됐을 때만 기록한다)

### 정책 (phase1과 동일, 2026-08-21 확정)

- 각 데이터셋을 **가장 raw한 형태부터** 다시 처리한다. GIAB이 만든 정렬/변이 산출물은 참고만 하고
  무시한다(지우지는 말 것).
- 진입 우선순위: **fastq > unaligned BAM(uBAM) > aligned BAM**. **POD5/fast5에서 basecalling은 하지 않는다**
  (비용 과다). fast5/pod5만 있는 데이터셋은 그 사실을 기록하고 건너뛰거나 정렬 BAM에서 시작한다.
- GIAB FTP에 리드가 없으면 SRA/ENA 등 외부에서 찾아 받는다. phase1의 `scripts/02_fetch_sra_reads.sh`와
  `sra_manifest.tsv`가 그 패턴이다(크기+md5+리드통계 검증 포함).

### 데이터 현황 — 반드시 직접 확인할 것

`catalog/master_catalog.tsv`에서 `category == ont`인 18행이 대상이다(총 12.7 TB).
`phase0_download/manifests/<SAMPLE>/ont.tsv`가 실제 파일 목록·바이트다. 아래는 내가 훑어본 요점이며
**그대로 믿지 말고 매니페스트로 재확인해라**:

| 묶음 | 상태 |
|---|---|
| HG002 ONT-UL 5종 (rel1 2018-05-18, rel2 2018-08-10, Guppy 2.3.4 / 3.2.4 / 3.4.5) | **같은 플로우셀을 재베이스콜한 것일 가능성이 매우 높다.** 각 44~937 GiB. 전부 돌리면 낭비 |
| UCSC ONT-UL PromethION (HG002~HG007) | 샘플당 fastq.gz 3개. HG005/6/7은 R9.4.1 + Guppy 4.2.2 명시 |
| HG008 (5개 데이터셋) | R10.4.1 + dorado. **unaligned BAM에 MM/ML 메틸 태그 있음**. HG008T-p2는 uBAM 1090개 |
| HG001 ONT-UL | **리드 없음** — GRCh37/38 BAM 2개뿐. 원본은 nanopore-wgs-consortium AWS 버킷(rel6). SRA가 아니다 |
| HG002 Cornell 2D (5.7 GiB) | 구형 2D 케미스트리 + fast5. 처리 가치 낮음 — 제외 판단 후 근거를 기록 |

**중복 판정이 이번 작업의 최대 리스크다.** phase1에서도 4쌍이 같은 movie였고, 매니페스트의 movie ID를
대조해 실측으로 확인한 뒤 `dup_of` 열로 표시하고 기본 제출에서 뺐다(`run_table.tsv` 참고).
ONT는 movie ID가 없으니 다른 근거가 필요하다 — 각 README, `sequencing_summary.txt.gz`의 run_id/flowcell,
리드 수와 총 염기수, 필요하면 리드 이름 샘플 비교. **추측하지 말고 근거를 남겨라.**

### ONT 특유의 판단 지점 (PacBio와 다른 부분)

1. **케미스트리별 콜러 모델이 다르고, 틀려도 조용히 돌아간다.** phase1에서 Clair3 모델
   (hifi_revio / hifi_sequel2 / hifi)을 데이터셋별로 지정한 것과 같은 문제다.
   R9.4.1(Guppy)과 R10.4.1(dorado)은 모델이 완전히 다르다. 각 데이터셋의 케미스트리·베이스콜러·모델
   (fast/hac/sup)을 README와 파일명에서 확정하고 `run_table.tsv`에 열로 남겨라.
   컨테이너 안에 그 모델이 실제로 있는지도 확인할 것(phase1에서 Clair3 v2.x가 HiFi 모델을 전부 뺀 전례).
2. **SV 콜러를 바꿔야 한다.** pbsv는 PacBio 전용이다. ONT는 Sniffles2가 표준(cuteSV도 후보).
3. **DeepVariant ONT 모델을 확인할 것.** R10.4.1용 모델이 있는 버전과 없는 버전이 갈린다. 없으면
   Clair3 단독으로 가고 그 판단을 기록해라.
4. **HG008 uBAM의 MM/ML 태그.** fastq로 바꾸면 메틸 정보가 사라진다. uBAM으로 진입하고 minimap2에
   태그 보존 옵션을 주면 거의 공짜로 살릴 수 있다. 메틸 콜링(modkit) 자체는 범위 밖이지만
   **태그를 버리는 선택은 명시적으로 기록해라.**
5. **ONT는 리드 길이 분포가 극단적이다**(UL은 100 kb+). 정렬 메모리·시간이 HiFi와 다르게 튄다.
   첫 1~2런의 실측(`qacct -j <jobid>`의 maxvmem/ru_wallclock)을 보고 자원을 조정해라.

### 파이프라인 선택

사용자가 nf-core/nanoseq를 우선 검토하길 원한다. **다만 그대로 쓸 수 있다고 가정하지 말고 직접 확인해라** —
유지보수 상태, germline SNV 콜링 지원 여부(Clair3 유무), SV 콜링 유무, 오프라인 실행 가능성.
요건을 못 채우면 `phase1_pacbio_hifi/pipeline/pacbio-hifi-wgs/`를 본떠 독립 DSL2 파이프라인을 만들어라
(플러그인 0개, 컨테이너는 전부 `params.container_*`로 노출, `-resume` 동작, stub 블록 포함).
대략의 형태: minimap2 `-x map-ont` → Clair3(+가능하면 DeepVariant) → Sniffles2 → WhatsHap 위상 →
mosdepth/samtools/bcftools stats → MultiQC.

### 실행 환경 (KOBIC nbb2) — 여기서 틀리면 전부 막힌다

- **계산 노드에 외부 네트워크가 없다.** 컨테이너·레퍼런스·입력을 로그인 노드에서 미리 받아두고
  잡은 `NXF_OFFLINE=true`로 돌린다. phase1의 `scripts/01_prepare_login_node.sh`가 그 역할이다.
- Nextflow는 `NXF_VER=24.10.5`, conda env `nfcore312`(JDK 17), `JAVA_HOME`은 경로 하드코딩
  (`$CONDA_PREFIX`를 쓰면 SGE 잡에서 base로 덮여 깨진다). `GODEBUG=netdns=cgo`가 있어야
  `singularity pull`이 된다. 전부 `phase1_pacbio_hifi/env.sh`에 정리돼 있으니 그대로 재사용해라.
- **잡 1개 안에서 Nextflow local executor로 완주시킨다** (SGE executor로 자식 잡을 뿌리지 않는다).
- 큐: `shepherd.q`의 shepherd-1-7/8/9(각 64코어·251 GB) **세 대가 전부다.**
  octopus.q는 더 이상 쓸 수 없다 (2026-08-22).
- `h_vmem`은 **consumable=NO**다. SGE가 메모리를 예약하지 않으므로 노드당 잡 수는 슬롯으로만 통제된다.
  (노드당 잡 수) × (잡당 메모리) < 노드 RAM 을 직접 지켜야 한다.
- phase1 실측 참고: 30슬롯 잡으로 ~30x HiFi WGS가 6~7시간, 피크 43~54 GB.

### phase1에서 얻은 교훈 — 같은 실수를 반복하지 마라

- **다운로드 완료 판정에 크기만 쓰면 안 된다.** `aws s3 cp`는 `.part` 없이 최종 파일명에 멀티파트로 쓴다.
  뒤쪽 파트가 먼저 도착하면 크기는 최종값인데 중간이 빈 구멍이다. phase1은 크기 + mtime 안정화(기본 10분)를
  같이 본다(`scripts/lib.sh`의 `p1_inputs_state`).
- 여러 데이터셋이 하나의 `--outdir`를 공유하므로 `run_label` 같은 네임스페이스가 없으면 MultiQC와
  `pipeline_info/` 리포트가 서로 덮어쓴다.
- 샘플시트는 손으로 쓰지 말고 매니페스트에서 생성하되 **개수·크기 assertion을 넣어라**
  (`scripts/make_samplesheets.py`). 조용히 파일이 빠지는 사고를 막는다.
- 자원 설정은 git 미추적 `env.local.sh`로 오버라이드하게 만들어라(`${VAR:-값}` 형태 유지).
- **repo 루트에서 nextflow를 돌리지 마라.** `.nextflow/cache`(LevelDB)가 커밋되는 사고가 있었다.
  `.gitignore`에 이미 들어가 있다.

### 진행 방식

1. 조사 → ONT 실행 단위 목록(`run_table.tsv`)과 중복 판정 근거를 먼저 확정하고 사용자에게 확인받아라.
   여기서 잘못 세면 수 TB와 수 일을 날린다.
2. 그다음 파이프라인 선택 근거, 샘플시트 생성, 스크립트(준비/제출/상태/검증/정리/카탈로그 갱신) 순으로.
3. 커밋은 PR 없이 main에 직접 push한다(사용자 선호).
4. 문서는 짧게. 사용자의 전역 규칙이다 — 근거·상세는 `docs/reference/`로 빼고 본문은 표와 짧은 불릿으로.

### 하지 말 것

- POD5/fast5 basecalling
- 추측으로 카탈로그 채우기 (근거 없는 칸은 `N/A`, 판정 불가는 그대로 두고 이유를 notes에)
- 이미 돌아가는 phase1 잡·산출물 건드리기
- 사용자 확인 없이 수 TB짜리 다운로드나 대량 제출 시작하기

## 지시문 끝
