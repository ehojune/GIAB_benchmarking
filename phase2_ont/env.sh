# phase2(ONT) 공통 환경. 모든 phase2 스크립트와 SGE 잡이 source 한다. nbb2 값이 바뀌면 여기만 고친다.
# phase1_pacbio_hifi/env.sh와 같은 구조다 (다른 점: 산출 경로의 플랫폼 디렉토리, Clair3 모델 디렉토리).
# shellcheck shell=bash

# 개인/사이트 오버라이드: 같은 폴더에 env.local.sh를 만들면 (git 미추적) 먼저 읽는다.
# env.local.sh 안에서도 ${VAR:-값} 꼴을 쓸 것 — 그래야 `SGE_SLOTS=60 bash 10_submit.sh ...`
# 같은 1회성 지정이 파일 값을 이긴다 (이 파일이 먼저 읽히므로 무조건 export하면 덮어써진다).
_P2_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$_P2_DIR/env.local.sh" ] && . "$_P2_DIR/env.local.sh"

# ---- 경로 ----
export GIAB_ROOT="${GIAB_ROOT:-/BiO/scratch/ehojune/GIAB_benchmark}"   # phase0 다운로드 루트
export RUN_BASE="${RUN_BASE:-$GIAB_ROOT/processed_data_ehojune}"       # 산출물: <sample>/ONT/<dataset>/
export INFRA="${INFRA:-$RUN_BASE/_infra}"                              # phase1과 공유 (컨테이너·레퍼런스·work·로그)

# ---- Nextflow / Java / apptainer (phase1과 동일. kobic-nextflow-env 기준) ----
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
export TRF_BED="${TRF_BED:-$INFRA/reference/human_GRCh38_no_alt_analysis_set.trf.bed}"   # sniffles --tandem-repeats (phase1이 받아둔 것과 동일 파일)
export GIAB_HTTP_BASE="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab"

# Clair3 모델. 컨테이너에 없는 모델을 여기에 내려받아 마운트한다 (01_prepare_login_node.sh).
# hkubal/clair3:v1.2.0 이미지에 들어 있는 것: r941_prom_sup_g5014, r1041_e82_400bps_{sup,hac}_v410,
# r1041_e82_400bps_{sup,hac}_v500, hifi*, ilmn. 우리가 쓰는 r941_prom_hac_g360+g422와
# r1041_e82_400bps_sup_v420/v430은 **이미지에 없다** — 그래서 이 디렉토리가 필요하다.
export CLAIR3_MODEL_DIR="${CLAIR3_MODEL_DIR:-$INFRA/reference/clair3_models}"

# ---- SGE ----
# 노드 실측(2026-08-21): shepherd-1-7/8/9 각 64코어 / 251.1 GB. h_vmem은 consumable=NO —
# 스케줄러가 메모리를 예약하지 않으므로 노드당 잡 수는 슬롯으로만 통제된다.
# octopus.q는 2026-08-22 기준 사용 불가 — shepherd 3대가 전부다.
# ONT 기본값은 노드당 2잡(30x2=60슬롯, 110x2=220 GB). 프리셋은 env.local.sh.example.
export SGE_QUEUE="${SGE_QUEUE:-shepherd.q}"
export SGE_PE="${SGE_PE:-pe_slots}"
export SGE_SLOTS="${SGE_SLOTS:-30}"
export SGE_VMEM="${SGE_VMEM:-115G}"                        # 잡별 상한(넘으면 kill). 예약 아님
export SGE_HOSTS="${SGE_HOSTS:-(shepherd-1-7|shepherd-1-8|shepherd-1-9)}"

# 잡 안에서 Nextflow local executor가 동시에 잡을 수 있는 자원 상한 (kobic.config가 읽음).
# NF_LOCAL_CPUS는 잡 스크립트가 NSLOTS로 덮는다. SGE_VMEM보다 작게 둬서 오버헤드를 남긴다.
export NF_LOCAL_MEM_GB="${NF_LOCAL_MEM_GB:-110}"
