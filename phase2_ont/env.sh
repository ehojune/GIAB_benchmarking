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
# hkubal/clair3:v1.2.0 이미지 실측(2026-08-22): r941_prom_{hac_g360+g422,sup_g5014},
# r1041_e82_400bps_{sup,hac}_{v410,v500}, hifi*, ilmn, ont, ont_guppy5.
# 우리가 쓰는 r1041_e82_400bps_sup_v420/v430과 r941_prom_hac_g238은 **없다** — 그래서 이 디렉토리가 필요하다.
export CLAIR3_MODEL_DIR="${CLAIR3_MODEL_DIR:-$INFRA/reference/clair3_models}"

# ---- 정확도 평가 (60_benchmark.sh) ----
# phase1과 같은 이미지·같은 $INFRA 를 쓰므로 phase1이 이미 받아 뒀으면 다시 안 받는다.
export HAPPY_IMG="${HAPPY_IMG:-jmcdani20/hap.py:v0.3.12}"      # GIAB/NIST 문서가 쓰는 이미지
export TRUVARI_IMG="${TRUVARI_IMG:-quay.io/biocontainers/truvari:5.4.0--pyhdfd78af_0}"  # SV용 (61_benchmark_sv.sh)
export BENCH_IMAGES="${BENCH_IMAGES:-$HAPPY_IMG $TRUVARI_IMG}"
# hap.py는 병렬성이 낮아 파이프라인 잡보다 작게 잡는다
export BENCH_SLOTS="${BENCH_SLOTS:-8}"
export BENCH_VMEM="${BENCH_VMEM:-32G}"      # 실측 maxvmem 23.7~24.5 GB (2026-09-18, R9 8런, 8슬롯)
# 메모리는 스레드 수에 비례하는 것으로 보인다 — phase1이 16슬롯에서 48.4~48.8 GB를 썼다
# (2026-09-22, 19런). 슬롯을 올리면 잡당 메모리도 같이 오르니 동시 실행 수를 함께 줄일 것.
export BENCH_TRUTH_VER="${BENCH_TRUTH_VER:-v4.2.1}"   # germline truth set 판 (release/*/NISTv4.2.1/)

# ── SV 정확도 평가 (61_benchmark_sv.sh) ───────────────────────────────────────
# **실측 (2026-09-18, ONT HG002 2런, -t 8)**: maxvmem 67.1 / 73.2 GB, wall 299~395초.
#
# phase1 HiFi 는 같은 -t 8 에서 91.6~136.2 GB 를 썼다(2026-09-22, 5런). 데이터셋이 다르면
# 두 배까지 벌어진다는 뜻이라, ONT 값을 HiFi 에 쓰거나 그 반대로 하면 안 된다.
#
# **메모리는 스레드에 비례하지 않는다.** phase1 에서 같은 데이터셋을 -t 22 -> 8 로 바꿔 보니
# 스레드 64% 감소에 메모리는 29~46%만 줄었다 — 가장 큰 영역 하나의 정렬 행렬이 고정분으로
# 남는 것으로 보인다. 즉 스레드를 낮춰도 최악값은 크게 안 내려가므로, 노드 과점유를 막는
# 실질적 수단은 **동시 실행 수(슬롯)** 다.
#   위 "ONT 실측 67~73 GB" 는 BENCH_SV_THREADS 가 생기기 전, truvari **기본 4스레드** 값이다.
#   2026-09-22 에 R10 런을 현재 기본값(-t 8)으로 돌려 **133.5 GB** 를 봤다 — phase1 이 같은 날
#   -t 8 로 본 91.6~136.2 GB 범위 안이다. 두 phase 가 독립적으로 같은 값을 냈으니 데이터셋
#   차이가 아니라 스레드 설정 차이다.
#   그래서 33슬롯 = **노드당 1잡**. 22슬롯이면 2잡 x 133.5 = 267 GB 로 251 GB 를 넘는다
#   (앞 주석이 "100 GB 를 넘기면 33으로 올릴 것" 이라 적어 둔 그 조건이 실제로 걸렸다).
export BENCH_SV_THREADS="${BENCH_SV_THREADS:-8}"
export BENCH_SV_SLOTS="${BENCH_SV_SLOTS:-33}"
export BENCH_SV_VMEM="${BENCH_SV_VMEM:-80G}"   # ONT 실측 67~73 GB 위. 표시용이고 강제되지 않는다
export BENCH_SV_TRUTH_VER="${BENCH_SV_TRUTH_VER:-v5.0q}"   # release/*/*/v5.0q/<sample>_GRCh38_v5.0q_stvar.*
export BENCH_SV_REFINE="${BENCH_SV_REFINE:-1}"             # GIAB v5.0q README 권장. 0으로 끌 수 있다
export BENCH_SV_ALIGN="${BENCH_SV_ALIGN:-}"                # refine 정렬기. 비우면 truvari 기본값 poa
export BENCH_SV_ARGS="${BENCH_SV_ARGS:-}"                  # truvari bench 추가 인자 (예: -d)
export BENCH_SV_TIMEOUT="${BENCH_SV_TIMEOUT:-4h}"         # 워치독 상한. 멎은 잡이 슬롯을 영원히 물지 않게 (실측 wall 4분대)

# ---- SGE ----
# 노드 실측(2026-08-21): 노드당 64코어 / 251.1 GB (전 노드 동일 스펙). h_vmem은 consumable=NO —
# 스케줄러가 메모리를 예약하지 않으므로 노드당 잡 수는 슬롯으로만 통제된다.
# **h_vmem은 강제 종료 한도도 아니다**(2026-09-18 실측): 32G로 선언한 truvari 잡이 maxvmem 73 GB를
# 쓰고도 exit 0으로 끝났다. 즉 이 값은 문서일 뿐이고, 넘겨도 아무 일도 일어나지 않는다.
# 그래도 실측에 맞춰 둔다 — 안 맞으면 다음 사람이 노드 용량을 잘못 계산한다.
# ONT 기본값은 노드당 2잡(30x2=60슬롯, 110x2=220 GB). 프리셋은 env.local.sh.example.
#
# **쓸 수 있는 노드 집합은 고정이 아니다.** 다른 연구자와 나눠 쓰는 자원이라 그때그때 바뀐다.
#   2026-08-22: shepherd-1-7/8/9 (shepherd.q) 셋. octopus.q 사용 불가
#   2026-09-22: octopus-2-8, octopus-2-9, shepherd-1-8, shepherd-1-9 넷 — **큐가 둘로 갈렸다**
# 그래서 SGE_QUEUE는 콤마 목록을 받고, 실제 제출에는 lib.sh의 p2_sge_queue_arg 가
# qstat -f 와 대조해 **실재하는 큐만** 골라 쓴다. 겹치는 인스턴스가 없으면 제출 자체를 막는다
# (p2_require_sge_targets) — 안 그러면 잡이 조용히 qw로 영원히 남는다.
# 지금 쓸 수 있는 집합을 보려면: qstat -f | awk '$1 ~ /@/ {print $1}' | sort -u
export SGE_QUEUE="${SGE_QUEUE:-shepherd.q,octopus.q}"
export SGE_PE="${SGE_PE:-pe_slots}"
export SGE_SLOTS="${SGE_SLOTS:-30}"
export SGE_VMEM="${SGE_VMEM:-115G}"                        # 표시용. 예약도 상한도 아니다 (위 주석)
export SGE_HOSTS="${SGE_HOSTS:-(octopus-2-8|octopus-2-9|shepherd-1-8|shepherd-1-9)}"

# 잡 안에서 Nextflow local executor가 동시에 잡을 수 있는 자원 상한 (kobic.config가 읽음).
# NF_LOCAL_CPUS는 잡 스크립트가 NSLOTS로 덮는다. SGE_VMEM보다 작게 둬서 오버헤드를 남긴다.
export NF_LOCAL_MEM_GB="${NF_LOCAL_MEM_GB:-110}"
