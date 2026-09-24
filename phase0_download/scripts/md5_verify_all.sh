#!/usr/bin/env bash
# 전수 md5 검증. 참조는 current.tree + 같은 디렉토리의 sidecar(md5.in, checksums.md5, *.md5sum …).
# 결과를 $DEST/.md5_results.tsv 에 누적하므로 중단 후 재실행하면 이어서 검사한다.
#
# 판정 (2열):
#   PASS                     tree md5 일치
#   PASS_SIDECAR             tree에 없고 sidecar 일치
#   PASS_SIDECAR_TREE_STALE  tree와 다르지만 sidecar 일치 — GIAB가 tree 갱신 뒤 파일을 바꾼 것. current.tree는
#                            FTP에서도 2025-02-28 이후 갱신되지 않아(2026-09-23 확인) 이 경우가 실제로 있다
#   FAIL_BOTH                tree·sidecar 둘 다 불일치 → 진짜 손상 의심
#   FAIL_TREE_ONLY           tree와 다르고 sidecar 없음 → tree stale인지 손상인지 이 파일만으로는 모른다
#   FAIL_SIDECAR             tree에 없고 sidecar와 불일치
#   NOREF                    참조 없음 (md5 계산 안 함) · MISS 로컬에 파일 없음
#
# Usage:
#   nohup bash scripts/md5_verify_all.sh all > logs/md5_all.log 2>&1 &
#   ./scripts/md5_verify_all.sh pacbio_hifi HG002        # 부분 검증
#   SUMMARY=1 ./scripts/md5_verify_all.sh all            # 검사 없이 현재 집계만 출력
#
# Env: JOBS=8 (동시 md5 수 — 디스크가 병목이므로 8~16 권장), DEST, RESULTS(기본 $DEST/.md5_results.tsv)
#
# 예상 소요: 전체 107.6 TiB, JOBS=8 기준 대략 1~2일 (스토리지 읽기 속도에 좌우)
# FAIL 재처리: awk -F'\t' '$2 ~ /^FAIL/{print $1}' $DEST/.md5_results.tsv 로 목록 확인 →
#   해당 파일 rm 후 download.sh 재실행 → RESULTS에서 그 줄 지우고 본 스크립트 재실행

set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DEST:-/BiO/scratch/ehojune/GIAB_benchmark}"
RESULTS="${RESULTS:-$DEST/.md5_results.tsv}"
JOBS="${JOBS:-8}"
TREE="$DEST/.current.tree"
SUMMARY="${SUMMARY:-0}"

[ $# -ge 1 ] || { echo "usage: $0 <category|all|release|rnaseq|trio_analysis> [SAMPLE ...]"; exit 1; }
CAT="$1"; shift
ALL_SAMPLES=(HG001 HG002 HG003 HG004 HG005 HG006 HG007 HG008 HG009)
SAMPLES=("$@"); [ ${#SAMPLES[@]} -gt 0 ] || SAMPLES=("${ALL_SAMPLES[@]}")

MANIFESTS=()
case "$CAT" in
    release)       MANIFESTS+=("$REPO_DIR/manifests/release_truthsets.tsv");;
    rnaseq)        MANIFESTS+=("$REPO_DIR/manifests/rnaseq_all.tsv");;
    trio_analysis) MANIFESTS+=("$REPO_DIR/manifests/trio_analysis.tsv");;
    all)
        for s in "${SAMPLES[@]}"; do
            for m in "$REPO_DIR/manifests/$s"/*.tsv; do [ -e "$m" ] && MANIFESTS+=("$m"); done
        done
        for m in release_truthsets rnaseq_all trio_analysis; do
            [ -e "$REPO_DIR/manifests/$m.tsv" ] && MANIFESTS+=("$REPO_DIR/manifests/$m.tsv")
        done;;
    *)
        for s in "${SAMPLES[@]}"; do
            m="$REPO_DIR/manifests/$s/$CAT.tsv"; [ -e "$m" ] && MANIFESTS+=("$m")
        done;;
esac
[ ${#MANIFESTS[@]} -gt 0 ] || { echo "no manifests matched"; exit 1; }
touch "$RESULTS"

summary() {
    # 헤드라인은 접두로 묶는다 — PASS*(정상) / FAIL*(재처리 대상) / NOREF / MISS. 상태별 상세는 그 아래.
    awk -F'\t' '
        { c[$2]++; if ($2 ~ /^PASS/) p++; else if ($2 ~ /^FAIL/) f++; else if ($2 == "NOREF") n++; else if ($2 == "MISS") m++ }
        END {
            printf "PASS* %d / FAIL* %d / NOREF %d / MISS %d (누적 %d)\n", p, f, n, m, NR
            for (k in c) printf "  %-26s %d\n", k, c[k]
        }' "$RESULTS"
    awk -F'\t' '$2 ~ /^FAIL/{print "  " $2 ":", $1}' "$RESULTS"
}
if [ "$SUMMARY" = "1" ]; then summary; exit 0; fi

if [ ! -s "$TREE" ]; then
    echo "current.tree 다운로드 중 (20 MB)..."
    wget -q -O "$TREE" "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/current.tree" \
        || { echo "current.tree 다운로드 실패"; exit 1; }
fi

WORK=$(mktemp)
trap 'rm -f "$WORK" "$WORK.keys"' EXIT

# 작업 목록: manifest 키 − 이미 검사된 키, tree md5를 미리 붙임 (key \t expect_md5_or_-)
cat "${MANIFESTS[@]}" | cut -f1 | sort -u > "$WORK.keys"
awk -F'\t' -v r="$RESULTS" -v t="$TREE" '
    FILENAME==r  { done[$1]=1; next }
    FILENAME==t  { k=$1; sub(/^ftp\//,"",k); md5[k]=$5; next }
    !($1 in done){ print $1 "\t" (($1 in md5)? md5[$1] : "-") }
' "$RESULTS" "$TREE" "$WORK.keys" > "$WORK"
total_todo=$(wc -l < "$WORK")
echo "[$(date '+%F %T')] 검사 대상 $total_todo files (JOBS=$JOBS, 결과: $RESULTS)"

# 같은 디렉토리의 md5 목록 파일에서 basename에 해당하는 32자리 해시를 찾는다.
# 매니페스트 실측(2026-09-23): checksums.md5 132 · md5sum 59 · md5.in 56 · md5sum.txt 16 · md5sum.chk 4 · *.md5sum 등.
sidecar_md5() {
    # 같은 디렉토리에서는 basename 으로, 상위 디렉토리(최대 4단계, DEST 안)에서는 그 디렉토리 기준 상대경로로 찍는다.
    # HG009 NIST 트리처럼 checksums.md5 가 상위에 하나 있고 파일은 biomarkers/ 같은 하위에 있는 경우가 있다.
    local f="$1" d rel sc v depth=0
    d=$(dirname "$f"); rel=$(basename "$f")
    while [ "$depth" -le 4 ]; do
        for sc in "$d/$rel.md5" "$d/${rel}.md5sum" "$d/${rel}_md5sum" "$d"/*md5* "$d"/*MD5* "$d"/*checksum* "$d"/*CHECKSUM*; do
            [ -f "$sc" ] || continue
            [ "$sc" = "$f" ] && continue
            # 토큰 정확 일치. 지원 형식: "hash  name" / "hash *name" / "hash ./dir/name" / "name hash".
            # 같은 디렉토리(depth 0)에서는 basename 만, 상위에서는 상대경로 전체가 맞아야 한다 — 하위 디렉토리 간 동명 충돌 방지.
            v=$(awk -v want="$rel" -v depth="$depth" '{
                    for (i = 1; i <= NF; i++) {
                        t = $i; if (substr(t, 1, 1) == "*") t = substr(t, 2); sub(/^\.\//, "", t)
                        if (t == want || (depth == 0 && t ~ ("(^|/)" want "$"))) {
                            for (j = 1; j <= NF; j++) if (length($j) == 32 && $j ~ /^[0-9a-f]+$/) { print $j; exit }
                        }
                    }
                }' "$sc" 2>/dev/null)
            [ -n "$v" ] && { printf '%s' "$v"; return 0; }
        done
        [ "$d" = "$DEST" ] || [ "$d" = "/" ] || [ "$d" = "." ] && break
        rel="$(basename "$d")/$rel"; d=$(dirname "$d"); depth=$((depth + 1))
    done
    return 1
}

check_one() {
    local key="$1" expect="$2" f status actual sc
    f="$DEST/$key"
    if [ ! -f "$f" ]; then
        printf '%s\tMISS\t-\n' "$key" >> "$RESULTS"; return
    fi
    sc=$(sidecar_md5 "$f" || true)
    if [ "$expect" = "-" ] && [ -z "$sc" ]; then
        printf '%s\tNOREF\t-\n' "$key" >> "$RESULTS"; return     # 참조가 없으면 읽지 않는다
    fi
    actual=$(md5sum "$f" | awk '{print $1}')
    if [ "$expect" != "-" ] && [ "$actual" = "$expect" ]; then status="PASS"
    elif [ -n "$sc" ] && [ "$actual" = "$sc" ]; then
        if [ "$expect" = "-" ]; then status="PASS_SIDECAR"; else status="PASS_SIDECAR_TREE_STALE"; fi
    elif [ "$expect" != "-" ] && [ -n "$sc" ]; then status="FAIL_BOTH"
    elif [ "$expect" != "-" ]; then status="FAIL_TREE_ONLY"
    else status="FAIL_SIDECAR"
    fi
    printf '%s\t%s\t%s\n' "$key" "$status" "$actual" >> "$RESULTS"
    case "$status" in FAIL*) echo "$status $key (tree=$expect sidecar=${sc:--} got $actual)" >&2;; esac
}
export -f check_one sidecar_md5
export DEST RESULTS

tr '\t' '\n' < "$WORK" | xargs -d'\n' -n2 -P "$JOBS" bash -c 'check_one "$1" "$2"' _

echo "[$(date '+%F %T')] 완료"
summary