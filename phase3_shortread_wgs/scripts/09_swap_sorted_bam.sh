#!/bin/bash
# 08이 검증한 정렬 BAM을 파이프라인 set의 tmp/04.sort 자리에 넣는다. 옛 BAM은 지우지 않고 옆에 이름을 바꿔 둔다.
#   bash 09_swap_sorted_bam.sh <VALIDATED.txt> <SET_DIR> <SAMPLE>            # 계획만 (기본)
#   APPLY=1 bash 09_swap_sorted_bam.sh <VALIDATED.txt> <SET_DIR> <SAMPLE>    # 실제로 바꾼다
# 멈추는 경우: VALIDATED.txt가 없거나 NEW_BAM이 SAMPLE과 안 맞음 · 새 BAM/인덱스가 없음 · 그 set에서 Snakemake가 도는 중
# (.snakemake/locks 가 비어 있지 않음) · 옛 BAM이 없음. 바꾼 뒤 set을 다시 돌리는 것(Java 17 래퍼)은 사용자 몫이다.
# 새 BAM은 mv(같은 Lustre라 즉시)로 옮긴다 — 수정 시각이 위 단계 산출물보다 새로워 Snakemake는 정렬 이전 단계를 다시 돌리지 않는다.
set -euo pipefail
V=${1:?VALIDATED.txt}; SET=${2:?SET_DIR}; S=${3:?SAMPLE}
[ -r "$V" ] || { echo "ERROR: $V 없음 — 08이 끝까지 통과하지 않았다" >&2; exit 1; }
NEW=$(sed -n 's/^NEW_BAM=//p' "$V"); N=$(sed -n 's/^VALIDATED_PRIMARY_READS=//p' "$V")
[ "$(basename "$NEW")" = "${S}_sort.bam" ] || { echo "ERROR: NEW_BAM($NEW)이 샘플 $S 와 안 맞는다" >&2; exit 1; }
[ -s "$NEW" ] && [ -s "$NEW.bai" ] || { echo "ERROR: 새 BAM 또는 인덱스가 없다: $NEW(.bai)" >&2; exit 1; }
if [ -d "$SET/.snakemake/locks" ] && [ -n "$(ls -A "$SET/.snakemake/locks" 2>/dev/null)" ]; then
  echo "ERROR: $SET 에서 Snakemake가 도는 중(.snakemake/locks) — 끝난 뒤에 할 것" >&2; exit 1
fi
OLD=$SET/tmp/04.sort/${S}_sort.bam
[ -e "$OLD" ] || { echo "ERROR: 옛 BAM이 없다: $OLD" >&2; exit 1; }
TAG=pre-rebuild-$(date +%Y%m%d)
echo "새 BAM : $NEW  (primary $N, $(du -h "$NEW" | cut -f1))"
echo "옛 BAM : $OLD  ($(du -h "$OLD" | cut -f1)) → ${OLD}.$TAG"
echo "옛 인덱스: $OLD.bai → $OLD.bai.$TAG"
if [ "${APPLY:-0}" != 1 ]; then echo "DRY-RUN — 실제로 바꾸려면 APPLY=1"; exit 0; fi
mv "$OLD" "$OLD.$TAG"; [ -e "$OLD.bai" ] && mv "$OLD.bai" "$OLD.bai.$TAG"
mv "$NEW" "$OLD"; mv "$NEW.bai" "$OLD.bai"
printf 'SWAPPED_AT=%s\nINTO=%s\nOLD_KEPT=%s.%s\n' "$(date '+%F %T')" "$OLD" "$OLD" "$TAG" >> "$V"
echo "바꿨다. 되돌리기: mv $OLD.$TAG $OLD && mv $OLD.bai.$TAG $OLD.bai"
