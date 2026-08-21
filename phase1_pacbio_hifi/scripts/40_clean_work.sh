#!/bin/bash
# 검증 통과한 dsid의 Nextflow work 디렉토리 삭제 (산출물은 publishDir copy라 안전).
# 삭제하면 그 dsid는 -resume 불가 — 완전히 끝난 것만 지울 것.
# 사용법: scripts/40_clean_work.sh <dsid> [dsid ...]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../env.sh"
[ $# -gt 0 ] || { echo "사용법: $0 <dsid> [dsid ...]"; exit 1; }

for dsid in "$@"; do
    if ! "$HERE/30_verify_outputs.sh" "$dsid" >/dev/null 2>&1; then
        echo "SKIP $dsid: 산출물 검증 미통과 — work 유지"
        continue
    fi
    du -sh "$INFRA/work/$dsid" 2>/dev/null || true
    rm -rf "$INFRA/work/$dsid"
    echo "OK  $dsid: work 삭제"
done
