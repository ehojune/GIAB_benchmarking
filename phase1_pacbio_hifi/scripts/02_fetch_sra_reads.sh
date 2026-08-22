#!/bin/bash
# HG001·HG005 PacBio SequelII CCS 리드를 ENA에서 받는다 (로그인 노드).
# 이 두 데이터셋만 GIAB FTP에 리드가 없고 SRA/ENA(PRJNA540705/540706)에만 있다.
#
#   scripts/02_fetch_sra_reads.sh              전부 (12 cell, 135 GiB)
#   scripts/02_fetch_sra_reads.sh HG001        샘플 지정
#   JOBS=4 scripts/02_fetch_sra_reads.sh       병렬 (기본 3)
#   VERIFY_ONLY=1 scripts/02_fetch_sra_reads.sh   받지 않고 현재 상태만 점검
#
# 대상·크기·md5·리드통계는 sra_manifest.tsv가 전부 (ENA filereport에서 생성).
# wget -c 라서 중단 후 재실행하면 이어받는다. https가 막힌 망에서는 ftp://로 자동 대체.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
MAN="$HERE/../sra_manifest.tsv"
JOBS="${JOBS:-3}"
LOG="$INFRA/logs/sra_fetch.log"
mkdir -p "$INFRA/logs"

# 리드 정합성 검사.
# ENA가 리드 이름을 '@SRR9001770.1' 로 바꿔 배포하므로 PacBio 원래 이름(<movie>/<zmw>/ccs)이
# 남아 있지 않다 -> 이름으로 CCS 여부를 판정할 수 없다. 대신 앞부분을 샘플링해
# 평균 리드 길이를 manifest 값과 대조한다. CCS 여부의 근거는 아래 3개:
#   (1) ENA library_name = 'HG001-CCS-11kb-m64011_190326_191011'
#   (2) cell당 1.3-1.8M reads / 평균 ~10 kb = Sequel II HiFi 수율
#       (진짜 subreads면 같은 cell에서 리드 수가 수천만 개 단위여야 한다)
#   (3) 여기서 재는 실측 평균 길이
# 길이가 크게 어긋나면 진입 타입 가정이 깨진 것이므로 그냥 쓰지 말 것.
check_reads() {
    local f=$1 want=$2 got names
    got=$( { zcat "$f" 2>/dev/null || true; } \
           | awk 'NR%4==2 {n++; t+=length($0)} n>=20000 {exit} END {if(n) printf "%d", t/n}' )
    if [ -z "$got" ]; then
        echo "  ERROR: 리드를 읽지 못함 (gzip 손상?): $f"; return 1
    fi
    # 20% 이상 벗어나면 실패
    if [ "$got" -lt $((want * 8 / 10)) ] || [ "$got" -gt $((want * 12 / 10)) ]; then
        echo "  ERROR: 평균 리드 길이 ${got}bp, manifest는 ${want}bp — 다른 데이터이거나 subreads일 수 있다: $f"
        return 1
    fi
    names=$( { zcat "$f" 2>/dev/null || true; } | head -1 )
    case "$names" in
        */[0-9]*_[0-9]*) echo "  WARN: 리드 이름이 subread 구간 형태다 ($names) — 진입 타입 확인 필요" ;;
    esac
    return 0
}

fetch_one() {
    local relpath=$1 bytes=$2 md5=$3 ena_path=$4 srr=$5 mean_len=$6
    local out="$GIAB_ROOT/$relpath"
    mkdir -p "$(dirname "$out")"
    local have=-1
    [ -f "$out" ] && have=$(stat -c%s "$out" 2>/dev/null || echo -1)

    if [ "$have" != "$bytes" ]; then
        if [ "${VERIFY_ONLY:-0}" = 1 ]; then
            echo "MISS $relpath (have=$have want=$bytes)"; return 1
        fi
        echo "GET  $srr -> $relpath"
        # ENA는 SRR 이름으로 서비스하고 우리는 movie 이름으로 저장한다
        # (파일명이 파이프라인의 unit = BAM의 RG ID가 되므로 movie 쪽이 유용하다).
        # 망에 따라 https가 막힌 경우가 있어 ftp://로 재시도.
        if ! wget -q -c -O "$out" "https://ftp.sra.ebi.ac.uk/$ena_path"; then
            # nbb2에서 실측: ftp.sra.ebi.ac.uk 는 https가 TCP 단계에서 막힌다. 정상 경로다.
            echo "  note: https 차단됨 -> ftp:// 로 전환 (실패 아님): $srr"
            if ! wget -q -c -O "$out" "ftp://ftp.sra.ebi.ac.uk/$ena_path"; then
                echo "  ERROR: 두 경로 모두 실패 — $ena_path"; return 1
            fi
        fi
        have=$(stat -c%s "$out" 2>/dev/null || echo -1)
        if [ "$have" != "$bytes" ]; then
            echo "  ERROR: 크기 불일치 $relpath (got=$have want=$bytes) — 재실행하면 이어받음"; return 1
        fi
    fi

    if [ ! -f "$out.md5ok" ]; then
        echo "MD5  $relpath"
        local got
        got=$(md5sum "$out" | cut -d' ' -f1)
        if [ "$got" != "$md5" ]; then
            echo "  ERROR: md5 불일치 $relpath (got=$got want=$md5) — 파일 지우고 재실행할 것"; return 1
        fi
        touch "$out.md5ok"
    fi
    check_reads "$out" "$mean_len" || return 1
    echo "OK   $relpath"
}
export -f fetch_one check_reads
export GIAB_ROOT VERIFY_ONLY

rows=$(awk -F'\t' 'NR>1' "$MAN")
if [ $# -gt 0 ]; then
    pat=$(printf '%s|' "$@" | sed 's/|$//')
    rows=$(echo "$rows" | grep -E "^($pat)\." || true)
    [ -n "$rows" ] || { echo "해당 샘플의 항목이 없음: $*"; exit 1; }
fi

n=$(echo "$rows" | grep -c .)
tot=$(echo "$rows" | awk -F'\t' '{s+=$6} END {printf "%.1f", s/1024/1024/1024}')
echo "대상 $n cell / $tot GiB -> $GIAB_ROOT/sra/  (JOBS=$JOBS, 로그 $LOG)"

# 필드 순서: relpath bytes md5 ena_path srr mean_len (한 줄에 하나씩 -> xargs -n 6)
# 판정은 pipefail에 맡긴다 (PIPESTATUS 인덱스는 파이프 단계가 늘면 조용히 어긋난다).
if echo "$rows" | awk -F'\t' '{print $5"\t"$6"\t"$7"\t"$8"\t"$2"\t"$11}' \
     | tr '\t' '\n' | xargs -P "$JOBS" -n 6 bash -c 'fetch_one "$@"' _ 2>&1 \
     | tee -a "$LOG"
then rc=0; else rc=1; fi

echo
if [ "$rc" = 0 ]; then
    echo "전부 완료. 다음: scripts/10_submit.sh HG001.PacBio_SequelII_CCS_11kb HG005.PacBio_SequelII_CCS_11kb"
else
    echo "일부 실패 (위 ERROR 확인). 재실행하면 이어받는다."
fi
exit "$rc"
