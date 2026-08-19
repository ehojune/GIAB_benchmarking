#!/usr/bin/env bash
# 이 repo가 띄운 내 다운로드 프로세스만 중단 (내 계정 + 패턴 매칭, 다른 작업엔 영향 없음).
# 받다 만 파일은 크기가 안 맞아 다음 실행 때 다시 받으므로 데이터 손실 없음.

set -u
for pat in 'run_priority.sh' 'scripts/download.sh' 'aws s3 cp --no-sign-request s3://giab' 'wget .*ReferenceSamples/giab'; do
    pids=$(pgrep -u "$USER" -f "$pat" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo "kill: $pat -> $pids"
        kill $pids 2>/dev/null
    fi
done
sleep 2
left=$(pgrep -u "$USER" -fc 'aws s3 cp --no-sign-request s3://giab' 2>/dev/null || echo 0)
echo "남은 다운로드 프로세스: $left (0이 아니면 한 번 더 실행)"
