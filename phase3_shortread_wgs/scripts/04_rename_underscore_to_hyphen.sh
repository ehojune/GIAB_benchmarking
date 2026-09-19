#!/bin/bash
# 2026-09-18에 만든 GIAB_publicData_* 트리의 이름에서 `_`를 `-`로 바꾼다. mate 접미(`_1.fastq.gz`/`_2.fastq.gz`)만 남긴다.
# (2026-09-19 사용자 결정 — 파이프라인이 `_`로 샘플명을 자른다.) 03_make_pipeline_dirs.py는 이제 처음부터 `-` 이름을 만든다.
#
#   bash 04_rename_underscore_to_hyphen.sh <dest> [제외할 디렉토리 이름 ...]        # 계획만 출력 (기본)
#   APPLY=1 bash 04_rename_underscore_to_hyphen.sh <dest> [제외 ...]               # 실제로 mv
#
# 대상: <dest> 바로 아래 `GIAB_publicData_*` 디렉토리(업체 G000-* 등은 이름이 안 맞아 애초에 대상이 아니다).
# 순서: 파일 → 샘플 dir → 데이터셋 dir (깊은 것부터). 심볼릭 링크는 링크 이름만 바뀌고 대상은 그대로다.
# 바꾼 이름이 이미 있으면 그 항목은 건너뛰고 SKIP으로 알린다(이미 손으로 바꾼 트리와 겹치는 경우). 재실행 안전.
# 샘플 dir 안의 concat.sh / concat_R?.list / concat.log 는 이름을 바꾸지 않는다 — 03_make_pipeline_dirs.py를 다시 돌리면
# 새 이름으로 다시 쓰고(SKIP 판정은 파일 크기로 하므로 병합을 다시 하지 않는다), 옛 concat.log는 기록으로 남는다.
set -euo pipefail
dest="${1:?usage: $0 <dest> [exclude-dir ...]}"; shift
excl=("$@")
cd "$dest"

excluded() { local x; for x in "${excl[@]:-}"; do [ "$1" = "$x" ] && return 0; done; return 1; }
newname() {   # 마지막 경로 요소만: mate 접미 분리 → 나머지 `_`→`-` → 접미 복원
    local b=$1 suf=""
    if [[ "$b" =~ (_[12]\.fastq\.gz)$ ]]; then suf="${BASH_REMATCH[1]}"; b="${b%$suf}"; fi
    printf '%s%s' "${b//_/-}" "$suf"
}
n_mv=0; n_skip=0; n_err=0
do_mv() {   # $1 = 현재 경로. 이름이 안 바뀌면 조용히 통과
    local p=$1 d b nb
    d=$(dirname "$p"); b=$(basename "$p"); nb=$(newname "$b")
    [ "$nb" = "$b" ] && return 0
    if [ -e "$d/$nb" ] || [ -L "$d/$nb" ]; then echo "SKIP $p -> $nb (이미 있음)"; n_skip=$((n_skip+1)); return 0; fi
    echo "MV   $p -> $d/$nb"
    if [ "${APPLY:-0}" = 1 ]; then
        mv "$p" "$d/$nb" || { echo "ERROR mv 실패: $p"; n_err=$((n_err+1)); return 0; }
    fi
    n_mv=$((n_mv+1))
}

for ds in GIAB_publicData_*; do
    [ -d "$ds" ] || continue
    if excluded "$ds"; then echo "EXCL $ds"; continue; fi
    if [ -e "$(newname "$ds")" ]; then echo "SKIP $ds 전체 — $(newname "$ds") 가 이미 있다(손으로 바꾼 트리?). 안쪽도 안 건드림. 중복이면 직접 지울 것"; n_skip=$((n_skip+1)); continue; fi
    # 1) 파일 (샘플 dir 안). 옛 이름으로 찾는다
    for f in "$ds"/outcome/*/*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        case "$(basename "$f")" in *.fastq.gz|*.fastq.gz.part) do_mv "$f" ;; esac
    done
    # 2) 샘플 dir
    for sd in "$ds"/outcome/*/; do
        sd="${sd%/}"; [ -d "$sd" ] || continue
        do_mv "$sd"
    done
    # 3) 데이터셋 dir
    do_mv "$ds"
done
echo
if [ "${APPLY:-0}" = 1 ]; then echo "완료: mv $n_mv건, skip $n_skip건, 실패 $n_err건"; else echo "DRY-RUN: mv 예정 $n_mv건, skip $n_skip건 — 실제 적용은 APPLY=1"; fi
echo "다음: python <repo>/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py --prune --run-concat   # 새 이름 기준 재확인(완료된 병합은 건너뜀)"
[ "$n_err" = 0 ]
