#!/usr/bin/env bash
# 우선순위 순서대로 전 카테고리를 순차 다운로드 (SGE 불가 시 로그인/전송 노드용).
#   nohup bash scripts/run_priority.sh > logs/run_priority.log 2>&1 &
#   tail -f logs/run_priority.log
#
# Env: TOOL=s3 JOBS=8 DEST=... (download.sh로 전달)
#      CATEGORIES="release pacbio_hifi ont" 처럼 지정하면 그 순서만 실행

set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TOOL="${TOOL:-s3}" JOBS="${JOBS:-8}"
CATEGORIES="${CATEGORIES:-release trio_analysis pacbio_hifi ont pacbio_clr rnaseq illumina_wgs bgi_mgi linked_reads exome complete_genomics other}"
mkdir -p "$REPO_DIR/logs"

for cat in $CATEGORIES; do
    echo "[$(date '+%F %T')] START $cat (TOOL=$TOOL JOBS=$JOBS)"
    "$REPO_DIR/scripts/download.sh" "$cat" > "$REPO_DIR/logs/$cat.log" 2>&1
    echo "[$(date '+%F %T')] DONE  $cat"
    "$REPO_DIR/scripts/verify.sh" "$cat" | tail -1
done
echo "[$(date '+%F %T')] ALL DONE"
