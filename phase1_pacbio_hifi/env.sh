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
# hap.py 는 병렬성이 낮아 파이프라인 잡보다 작게 잡는다
export BENCH_SLOTS="${BENCH_SLOTS:-8}"
export BENCH_VMEM="${BENCH_VMEM:-32G}"      # phase2 실측 maxvmem 23.7~24.5 GB (2026-09-18, R9 8런)
export BENCH_TRUTH_VER="${BENCH_TRUTH_VER:-v4.2.1}"   # germline truth set 판 (release/*/NISTv4.2.1/)

# ── SV 정확도 평가 (61_benchmark_sv.sh) ───────────────────────────────────────
# truvari refine의 기본 스레드는 4다(truvari 5.4.0 refine.py) — 슬롯을 더 줘도 안 쓴다.
# **그래도 슬롯을 크게 잡는다.** h_vmem이 예약도 상한도 아니므로 노드당 동시 실행 수를 통제하는
# 수단이 슬롯밖에 없는데, truvari는 실측 maxvmem 67~73 GB로 무겁다. 8슬롯이면 64코어 노드에
# 8잡(= 최대 584 GB)이 올라가 251 GB를 크게 넘는다 — phase1은 --ready 대상이 HG002 5런이라
# 실제로 한 노드에 다섯이 몰릴 수 있다(2026-09-22 Codex 리뷰 지적).
# 22슬롯 = 노드당 최대 2잡(44/64 슬롯, 146 GB). 노드를 통째로 쓸 수 있으면 21로 낮춰 3잡
# (63/64 슬롯, 219 GB)까지 가능하지만, 다른 잡과 나눠 쓰는 것이 기본이라 2잡으로 둔다.
export BENCH_SV_SLOTS="${BENCH_SV_SLOTS:-22}"
export BENCH_SV_VMEM="${BENCH_SV_VMEM:-80G}"   # phase2 실측 maxvmem 67~73 GB (2026-09-18, refine 포함)
export BENCH_SV_TRUTH_VER="${BENCH_SV_TRUTH_VER:-v5.0q}"   # release/*/*/v5.0q/<sample>_GRCh38_v5.0q_stvar.*
export BENCH_SV_REFINE="${BENCH_SV_REFINE:-1}"             # GIAB v5.0q README 권장. 0으로 끌 수 있다
export BENCH_SV_ALIGN="${BENCH_SV_ALIGN:-}"                # refine 정렬기. 비우면 truvari 기본값 poa
export BENCH_SV_ARGS="${BENCH_SV_ARGS:-}"                  # truvari bench 추가 인자 (예: -d)
