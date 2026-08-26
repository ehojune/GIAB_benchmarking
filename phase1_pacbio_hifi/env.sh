# phase1 공통 환경. 모든 phase1 스크립트와 SGE 잡이 source 한다. nbb2 값이 바뀌면 여기만 고친다.
# shellcheck shell=bash

# 개인/사이트 오버라이드: 같은 폴더에 env.local.sh를 만들면 (git 미추적) 먼저 읽는다.
# 템플릿과 노드 실측값 기반 프리셋은 env.local.sh.example 참고.
# env.local.sh 안에서도 ${VAR:-값} 꼴을 쓸 것 — 그래야 `SGE_SLOTS=60 bash 10_submit.sh ...`
# 같은 1회성 지정이 파일 값을 이긴다 (이 파일이 먼저 읽히므로 무조건 export하면 덮어써진다).
_P1_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$_P1_DIR/env.local.sh" ] && . "$_P1_DIR/env.local.sh"

# ---- 경로 ----
export GIAB_ROOT="${GIAB_ROOT:-/BiO/scratch/ehojune/GIAB_benchmark}"   # phase0 다운로드 루트
export RUN_BASE="${RUN_BASE:-$GIAB_ROOT/processed_data_ehojune}"       # 산출물: <sample>/PacBio/<dataset>/
export INFRA="${INFRA:-$RUN_BASE/_infra}"                              # 컨테이너·레퍼런스·work·로그 (산출물 아님)

# ---- Nextflow / Java / apptainer (kobic-nextflow-env 메모 기준, 2026-08-19 검증) ----
export NXF_VER="${NXF_VER:-24.10.5}"                       # 서버 기본 26.x는 구형 config 못 읽음
export CONDA_ENV="${CONDA_ENV:-/home/ehojune/anaconda3/envs/nfcore312}"
export JAVA_HOME="$CONDA_ENV"                              # $CONDA_PREFIX 쓰면 SGE 잡에서 base로 덮임 — 하드코딩
export PATH="$CONDA_ENV/bin:$PATH"
export GODEBUG=netdns=cgo                                  # apptainer pull 의 Go 리졸버 DNS 실패 우회
export NXF_SINGULARITY_CACHEDIR="${NXF_SINGULARITY_CACHEDIR:-$INFRA/containers}"
export APPTAINER_TMPDIR="$INFRA/tmp"
export SINGULARITY_TMPDIR="$INFRA/tmp"

# ---- 레퍼런스 ----
export REF_NAME="${REF_NAME:-GRCh38}"                      # 산출 파일명에 들어가는 라벨
export REF_FASTA="${REF_FASTA:-$INFRA/reference/GCA_000001405.15_GRCh38_no_alt_analysis_set.fasta}"
export TRF_BED="${TRF_BED:-$INFRA/reference/human_GRCh38_no_alt_analysis_set.trf.bed}"
export GIAB_HTTP_BASE="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab"

# ---- SGE (노드 3개 고정은 불변) ----
# 노드 실측(2026-08-21): 64코어 / 251.1 GB. h_vmem은 consumable=NO —
# 스케줄러가 메모리를 예약하지 않으므로 노드당 잡 수는 슬롯으로만 통제된다.
# 기본값은 노드당 3잡(21x3=63슬롯, 70x3=210 GB) 기준. 프리셋 변경은 env.local.sh.example.
export SGE_QUEUE="${SGE_QUEUE:-shepherd.q}"
export SGE_PE="${SGE_PE:-pe_slots}"
export SGE_SLOTS="${SGE_SLOTS:-21}"
export SGE_VMEM="${SGE_VMEM:-78G}"                         # 잡별 상한(넘으면 kill). 예약 아님
export SGE_HOSTS="${SGE_HOSTS:-(shepherd-1-7|shepherd-1-8|shepherd-1-9)}"

# 잡 안에서 Nextflow local executor가 동시에 잡을 수 있는 자원 상한 (kobic.config가 읽음).
# NF_LOCAL_CPUS는 잡 스크립트가 NSLOTS로 덮는다. SGE_VMEM보다 작게 둬서 오버헤드를 남긴다.
export NF_LOCAL_MEM_GB="${NF_LOCAL_MEM_GB:-70}"

# ── 벤치마킹 (60_benchmark.sh) ────────────────────────────────────────────────
# 파이프라인이 쓰지 않는 이미지라 nextflow.config 가 아니라 여기에 둔다.
# 01_prepare_login_node.sh 가 이 목록도 함께 미리 받는다 (계산 노드는 외부망이 없다).
# hap.py 는 GIAB/NIST 문서가 쓰는 이미지를 그대로 쓴다 (biocontainers 에는 없다).
export HAPPY_IMG="${HAPPY_IMG:-jmcdani20/hap.py:v0.3.12}"
export TRUVARI_IMG="${TRUVARI_IMG:-quay.io/biocontainers/truvari:5.4.0--pyhdfd78af_0}"
export BENCH_IMAGES="${BENCH_IMAGES:-$HAPPY_IMG $TRUVARI_IMG}"
# hap.py 는 병렬성이 낮아 파이프라인 잡보다 작게 잡는다
export BENCH_SLOTS="${BENCH_SLOTS:-8}"
export BENCH_VMEM="${BENCH_VMEM:-32G}"
export BENCH_TRUTH_VER="${BENCH_TRUTH_VER:-v4.2.1}"   # germline truth set 판 (release/*/NISTv4.2.1/)
