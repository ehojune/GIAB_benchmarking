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

# ── 구간별(층화) hap.py (STRAT=1 60_benchmark.sh) ─────────────────────────────
# GIAB genome-stratifications 판. release/genome-stratifications/<판>/GRCh38@all/ 구조(v3.5+)를 전제한다.
export BENCH_STRAT_VER="${BENCH_STRAT_VER:-v3.6}"
# 고른 구간. GIAB 목록(188개)의 절반이 샘플별 GenomeSpecific 이라 남의 샘플 구간까지 세게 되고,
# 층화 수만큼 메모리·시간이 는다. 물을 질문에 맞춰 골랐다 — 호모폴리머 길이 구간(Sequel I INDEL 격차),
# 반복·저매핑·segdup(Revio Clair3 vs DeepVariant 가 어디서 갈리나), 쉬운 영역(notin*), 코딩 영역.
# 4~6bp 호모폴리머는 뺐다 — 구간 수가 가장 많은 파일인데 HiFi 가 약한 길이가 아니다.
# 전부 돌리려면 BENCH_STRAT_SET=all.
export BENCH_STRAT_SET="${BENCH_STRAT_SET:-alldifficultregions notinalldifficultregions alllowmapandsegdupregions AllHomopolymers_ge7bp_imperfectge11bp_slop5 notinAllHomopolymers_ge7bp_imperfectge11bp_slop5 SimpleRepeat_homopolymer_7to11_slop5 SimpleRepeat_homopolymer_ge12_slop5 SimpleRepeat_homopolymer_ge21_slop5 AllTandemRepeatsandHomopolymers_slop5 notinAllTandemRepeatsandHomopolymers_slop5 AllTandemRepeats_le50bp_slop5 AllTandemRepeats_51to200bp_slop5 AllTandemRepeats_201to10000bp_slop5 SimpleRepeat_diTR_10to49_slop5 satellites_slop5 lowmappabilityall notinlowmappabilityall segdups notinsegdups MHC KIR VDJ gclt25orgt65_slop50 refseq_cds chrX_nonPAR}"
# **실측 전 값이다.** 기본 hap.py 가 스레드당 ~3 GB(16스레드 48.8 GB)라 16스레드면 층화 전 ~49 GB.
# 32슬롯 = 노드당 2잡이라 층화 부담이 스레드당 4.8 GB 까지 늘어도 251 GB 안이다. 첫 잡의
# maxvmem 을 보고 고칠 것.
export BENCH_STRAT_THREADS="${BENCH_STRAT_THREADS:-16}"
export BENCH_STRAT_SLOTS="${BENCH_STRAT_SLOTS:-32}"
export BENCH_STRAT_VMEM="${BENCH_STRAT_VMEM:-120G}"   # 표시용이고 강제되지 않는다

# ── somatic 채점 (62_benchmark_somatic.sh) ───────────────────────────────────
# NIST HG008-T smvar DraftBenchmark V0.3. BED 셋은 원래 zip 안에만 있어 풀어 둔 것을 쓴다.
export SOMATIC_TRUTH_DIR="${SOMATIC_TRUTH_DIR:-$GIAB_ROOT/data_somatic/HG008/Liss_lab/analysis/NIST_HG008-T_somatic-smvar_DraftBenchmark_V0.3-20260425}"
export SOMATIC_MIN_VAF="${SOMATIC_MIN_VAF:-0.05}"     # truth README: VAF 5~10% 미만은 걸러서 비교
export SOMATIC_BENCH_DIR="${SOMATIC_BENCH_DIR:-$RUN_BASE/_somatic_bench}"
export AARDVARK="${AARDVARK:-$INFRA/tools/aardvark-v1.0.0/aardvark}"   # PacBio 공식 릴리스 정적 바이너리 (README 권장 도구)

# ── somatic 콜 (70_submit_somatic.sh, DeepSomatic 1.10.0 CPU) ───────────────────
# 전장 실측 전 값이다. 4 Mb 조각(HG008-T 116x / N-P 35x, 16코어) peak RSS 17.8 GB 를 전장·30코어로 옮기는 근거는
# 없으므로 germline 파이프라인 잡과 같은 크기(노드당 2잡)로 시작하고, 파일럿 qacct maxvmem 을 보고 고친다.
export SOMATIC_SLOTS="${SOMATIC_SLOTS:-30}"
export SOMATIC_MEM_GB="${SOMATIC_MEM_GB:-110}"   # Nextflow local executor 상한 (kobic.config)
export SOMATIC_VMEM="${SOMATIC_VMEM:-115G}"      # 표시용. 강제되지 않는다
# 같은 사용자의 HG002/3/4·업체 비교 잡이 먼저 뜨게 낮춘다 (2026-09-25 사용자 지시: 그쪽이 우선)
export SOMATIC_PRIO="${SOMATIC_PRIO:--100}"

# ── SV 정확도 평가 (61_benchmark_sv.sh) ───────────────────────────────────────
# **실측 (2026-09-22, phase1 HG002 5런, -t 8)**: maxvmem 91.6 / 96.5 / 99.5 / 121.0 / 136.2 GB,
# wall 247~257초. 전 런 exit 0.
#
# 같은 데이터셋을 -t 22 로 돌렸을 때와 짝지어 보면 **메모리는 스레드에 비례하지 않는다**:
#   HiFi-Revio     192.6 -> 136.2 GB   (-29%)
#   SequelII_11kb  177.3 ->  96.5 GB   (-46%)
#   chemistry2     188.1 -> 121.0 GB   (-36%)
# 스레드를 64% 줄였는데 메모리는 29~46%만 줄었다. base + k*threads 로 풀면 base 가 50~104 GB 로
# 큰데, 이건 **가장 큰 영역 하나의 정렬 행렬**로 보인다 — 스레드를 줄여도 그 한 방은 그대로다
# (ENOMEM 때 실패한 할당이 정확히 64 GiB 한 방이었던 것과 맞아떨어진다).
# 2026-09-22 초판에서 "스레드에 비례한다"고 적었던 것은 phase2 ONT(-t 8)와 phase1 HiFi(-t 22)를
# 비교한 것이라 데이터셋 차이가 섞여 있었다. 위가 같은 데이터로 스레드만 바꾼 대조다.
#
# **그래서 실질적인 제어 수단은 스레드가 아니라 동시 실행 수(슬롯)다.**
#   33슬롯 = 노드당 1잡. 최악 136 GB / 251 GB — 안전.
#   22슬롯 = 노드당 2잡. 최악 136+121 = 257 GB — 251 GB 초과. 2026-09-22 실행은 피크가
#            안 겹쳐 살아남았을 뿐이다. 5런 순차라도 20분이라 처리량을 아낄 이유가 없다.
export BENCH_SV_THREADS="${BENCH_SV_THREADS:-8}"
export BENCH_SV_SLOTS="${BENCH_SV_SLOTS:-33}"
export BENCH_SV_VMEM="${BENCH_SV_VMEM:-150G}"  # 실측 최대 136.2 GB 위. 표시용이고 강제되지 않는다
export BENCH_SV_TRUTH_VER="${BENCH_SV_TRUTH_VER:-v5.0q}"   # release/*/*/v5.0q/<sample>_GRCh38_v5.0q_stvar.*
export BENCH_SV_REFINE="${BENCH_SV_REFINE:-1}"             # GIAB v5.0q README 권장. 0으로 끌 수 있다
export BENCH_SV_ALIGN="${BENCH_SV_ALIGN:-}"                # refine 정렬기. 비우면 truvari 기본값 poa
export BENCH_SV_ARGS="${BENCH_SV_ARGS:-}"                  # truvari bench 추가 인자 (예: -d)
export BENCH_SV_TIMEOUT="${BENCH_SV_TIMEOUT:-4h}"         # 워치독 상한. 멎은 잡이 슬롯을 영원히 물지 않게 (실측 wall 4분대)
