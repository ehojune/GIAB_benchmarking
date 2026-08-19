#!/usr/bin/env bash
# 로그인 노드 자원 + 다운로드 현황 스냅샷. 아무 때나 실행해도 안전 (읽기 전용).
#   bash scripts/status.sh
#
# Env: DEST=/BiO/scratch/ehojune/GIAB_benchmark  IFACE= (비우면 자동 감지)

set -u
DEST="${DEST:-/BiO/scratch/ehojune/GIAB_benchmark}"

echo "=== $(hostname) / $(date '+%F %T') ==="
echo

# CPU
cores=$(nproc)
read -r l1 l5 l15 _ < /proc/loadavg
echo "CPU   : ${cores} cores, load ${l1} (1m) / ${l5} (5m) / ${l15} (15m)"
awk -v l="$l1" -v c="$cores" 'BEGIN{printf "        load/core = %.2f  (1.0 근처면 포화)\n", l/c}'

# 메모리
free -h | awk 'NR==2{printf "MEM   : %s total, %s used, %s available\n", $2, $3, $7}'

# 스토리지
echo "DISK  :"
df -h "$DEST" 2>/dev/null | tail -1 | awk '{printf "        %s  %s/%s used (%s), avail %s\n", $6, $3, $2, $5, $4}'

# 네트워크: 3초 샘플링으로 실제 수신 속도 측정
IFACE="${IFACE:-$(ip route 2>/dev/null | awk '/default/{print $5; exit}')}"
if [ -n "${IFACE:-}" ] && [ -r "/sys/class/net/$IFACE/statistics/rx_bytes" ]; then
    rx0=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes")
    tx0=$(cat "/sys/class/net/$IFACE/statistics/tx_bytes")
    sleep 3
    rx1=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes")
    tx1=$(cat "/sys/class/net/$IFACE/statistics/tx_bytes")
    echo "NET   : $IFACE rx $(( (rx1-rx0)/3000000 )) MB/s, tx $(( (tx1-tx0)/3000000 )) MB/s (3초 평균)"
else
    echo "NET   : 인터페이스 감지 실패 (IFACE=eth0 식으로 지정)"
fi

# 내 다운로드 프로세스
echo
n_aws=$(pgrep -u "$USER" -fc 'aws s3 cp' 2>/dev/null || true); n_aws=${n_aws:-0}
n_wget=$(pgrep -u "$USER" -fc 'wget .*giab' 2>/dev/null || true); n_wget=${n_wget:-0}
n_runner=$(pgrep -u "$USER" -fc 'run_priority.sh' 2>/dev/null || true); n_runner=${n_runner:-0}
echo "DOWNLOADS: run_priority=$n_runner, aws=$n_aws, wget=$n_wget (동시 파일 수 = aws+wget)"

echo
echo "JOBS 조정 방법 (받은 파일은 자동 스킵되므로 안전):"
echo "  bash scripts/stop_downloads.sh                                        # 중단"
echo "  JOBS=4 nohup bash scripts/run_priority.sh > logs/run_priority.log 2>&1 &   # 원하는 JOBS로 재시작"
