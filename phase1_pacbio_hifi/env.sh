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
# **h_vmem은 강제 종료 한도도 아니다**(2026-09-18 phase2 실측): 32G로 선언한 truvari 잡이
# maxvmem 73 GB를 쓰고도 exit 0으로 끝났다. 즉 이 값은 문서일 뿐이고, 넘겨도 아무 일도 없다.
# 그래도 실측에 맞춰 둔다 — 안 맞으면 다음 사람이 노드 용량을 잘못 계산한다.
# 기본값은 노드당 3잡(21x3=63슬롯, 70x3=210 GB) 기준. 프리셋 변경은 env.local.sh.example.
#
# **쓸 수 있는 노드 집합은 고정이 아니다.** 다른 연구자와 나눠 쓰는 자원이라 그때그때 바뀐다.
#   2026-08-22: shepherd-1-7/8/9 (shepherd.q) 셋. octopus.q 사용 불가
#   2026-09-22: octopus-2-8, octopus-2-9, shepherd-1-8, shepherd-1-9 넷 — **큐가 둘로 갈렸다**
# 그래서 SGE_QUEUE는 콤마 목록을 받고, 실제 제출에는 lib.sh의 p1_sge_queue_arg 가
# qstat -f 와 대조해 **실재하는 큐만** 골라 쓴다. 겹치는 인스턴스가 없으면 제출 자체를 막는다
# (p1_require_sge_targets) — 안 그러면 잡이 조용히 qw로 영원히 남는다.
# 지금 쓸 수 있는 집합을 보려면: qstat -f | awk '$1 ~ /@/ {print $1}' | sort -u
export SGE_QUEUE="${SGE_QUEUE:-shepherd.q,octopus.q}"
export SGE_PE="${SGE_PE:-pe_slots}"
export SGE_SLOTS="${SGE_SLOTS:-21}"
export SGE_VMEM="${SGE_VMEM:-78G}"                         # 표시용. 예약도 상한도 아니다 (위 주석)
export SGE_HOSTS="${SGE_HOSTS:-(octopus-2-8|octopus-2-9|shepherd-1-8|shepherd-1-9)}"

# 잡 안에서 Nextflow local executor가 동시에 잡을 수 있는 자원 상한 (kobic.config가 읽음).
# NF_LOCAL_CPUS는 잡 스크립트가 NSLOTS로 덮는다. SGE_VMEM보다 작게 둬서 오버헤드를 남긴다.
export NF_LOCAL_MEM_GB="${NF_LOCAL_MEM_GB:-70}"

# ── 벤치마킹 (60_benchmark.sh) ────────────────────────────────────────────────
# 파이프라인이 쓰지 않는 이미지라 nextflow.config 가 아니라 여기에 둔다.
# 01_prepare_login_node.sh 가 이 목록도 함께 미리 받는다 (계산 노드는 외부망이 없다).
# hap.py 는 GIAB/NIST 문서가 쓰는 이미지를 그대로 쓴다 (biocontainers 에는 없다).
export HAPPY_IMG="${HAPPY_IMG:-jmcdani20/hap.py:v0.3.12}"
export TRUVARI_IMG="${TRUVARI_IMG:-quay.io/biocontainers/truvari:5.4.0--pyhdfd78af_0}"  # SV용 (61_benchmark_sv.sh)
export BENCH_IMAGES="${BENCH_IMAGES:-$HAPPY_IMG $TRUVARI_IMG}"
# **실측 (2026-09-22, phase1 19런 전부 exit 0)**: BENCH_SLOTS=16 에서 maxvmem 48.40~48.82 GB,
# wall 3371~5008초(56~83분). 16슬롯이면 64코어 노드에 동시 4잡 = 194/251 GB — 이 조합이
# 실제로 완주한 값이라 그대로 기본값으로 둔다.
#
# 슬롯을 바꿀 때 주의: hap.py 메모리는 **스레드 수에 비례**하는 것으로 보인다.
# phase2가 8슬롯에서 23.7~24.5 GB, phase1이 16슬롯에서 48.4~48.8 GB — 슬롯 2배에 메모리 2배다.
# 그래서 노드 총 사용량은 슬롯 선택과 무관하게 ~192 GB로 비슷하게 수렴한다(측정점 둘뿐이라
# 가설이다). 슬롯을 올리면 잡당 빨라지는 대신 동시 실행 수가 줄고, 총량은 그대로다.
export BENCH_SLOTS="${BENCH_SLOTS:-16}"
export BENCH_VMEM="${BENCH_VMEM:-56G}"      # 실측 48.8 GB 위. 표시용이고 강제되지 않는다
export BENCH_TRUTH_VER="${BENCH_TRUTH_VER:-v4.2.1}"   # germline truth set 판 (release/*/NISTv4.2.1/)

# ── SV 정확도 평가 (61_benchmark_sv.sh) ───────────────────────────────────────
# **실측 (2026-09-22, phase1 HG002 5런)**: -t 22 에서 maxvmem 177~192 GB, wall 228~262초.
# 2026-09-18 phase2 ONT 값(-t 8 에서 67~73 GB)의 2.6배다. 스레드가 2.75배였다.
#
# refine 의 정렬기 abPOA 는 **스레드마다 정렬 행렬을 따로 잡는다.** 그래서 -t 를 NSLOTS 에
# 묶어 두면 "슬롯을 올려 동시 실행 수를 줄인다"가 통하지 않는다 — 잡당 메모리가 같이 올라
# 노드 총량이 그대로다. 실제로 22슬롯 2잡이 한 노드에 겹쳐 abPOA 가 64 GiB 한 방을 못 잡고
# ENOMEM 으로 죽었다(HG002.PacBio_CCS_15kb, 잡 156033). 나머지 4런은 시차를 두고 돌아 살았다.
#
# 그래서 **스레드와 슬롯을 분리한다**:
#   BENCH_SV_THREADS = truvari refine -t. 메모리를 정하는 값. 8이면 ~73 GB.
#   BENCH_SV_SLOTS   = 노드 패킹만. 22면 노드당 2잡 = ~146 GB.
# truvari refine 의 기본 스레드는 4라(5.4.0 refine.py) 8이면 기본보다 빠르면서 메모리는 잡힌다.
export BENCH_SV_THREADS="${BENCH_SV_THREADS:-8}"
export BENCH_SV_SLOTS="${BENCH_SV_SLOTS:-22}"
export BENCH_SV_VMEM="${BENCH_SV_VMEM:-80G}"   # -t 8 기준 실측 67~73 GB 위. 표시용이고 강제되지 않는다
export BENCH_SV_TRUTH_VER="${BENCH_SV_TRUTH_VER:-v5.0q}"   # release/*/*/v5.0q/<sample>_GRCh38_v5.0q_stvar.*
export BENCH_SV_REFINE="${BENCH_SV_REFINE:-1}"             # GIAB v5.0q README 권장. 0으로 끌 수 있다
export BENCH_SV_ALIGN="${BENCH_SV_ALIGN:-}"                # refine 정렬기. 비우면 truvari 기본값 poa
export BENCH_SV_ARGS="${BENCH_SV_ARGS:-}"                  # truvari bench 추가 인자 (예: -d)
