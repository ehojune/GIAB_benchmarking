# phase1 공통 환경. 모든 phase1 스크립트와 SGE 잡이 source 한다. nbb2 값이 바뀌면 여기만 고친다.
# shellcheck shell=bash

# 개인/사이트 오버라이드: 같은 폴더에 env.local.sh를 만들면 (git 미추적) 먼저 읽는다.
# 아래의 모든 기본값이 ${VAR:-...} 꼴이라, env.local.sh에서 export한 값이 이긴다.
# 예: export SGE_SLOTS=32; export SGE_VMEM=300G; export NF_LOCAL_MEM_GB=280
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

# ---- SGE (kobic-sge-job-constraints 메모 기준; 노드 3개 고정은 불변) ----
export SGE_QUEUE="${SGE_QUEUE:-shepherd.q}"
export SGE_PE="${SGE_PE:-pe_slots}"
export SGE_SLOTS="${SGE_SLOTS:-21}"                        # 잡당 슬롯. 노드 여유 보고 조정 가능
export SGE_VMEM="${SGE_VMEM:-80G}"                         # h_vmem. 사이트가 slot당/잡당 어느 쪽인지에 따라 의미 다름
export SGE_HOSTS="${SGE_HOSTS:-(shepherd-1-7|shepherd-1-8|shepherd-1-9)}"

# 잡 안에서 Nextflow local executor가 동시에 잡을 수 있는 자원 상한 (kobic.config가 읽음).
# NF_LOCAL_CPUS는 잡 스크립트가 NSLOTS로 덮는다. MEM은 h_vmem이 잡당이면 그보다 약간 작게.
export NF_LOCAL_MEM_GB="${NF_LOCAL_MEM_GB:-72}"
