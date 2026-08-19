#!/usr/bin/env bash
# 노드의 외부 연결 진단. 로그인 노드와 계산 노드 양쪽에서 돌려 결과를 비교.
#   bash scripts/netcheck.sh                                   # 로그인 노드
#   qsub -N giab_netcheck -q shepherd.q@shepherd-1-9.kobic -V -j y -o netcheck.log -S /bin/bash scripts/netcheck.sh

set -u
echo "host: $(hostname)"
echo "proxy env: http_proxy=${http_proxy:-none} https_proxy=${https_proxy:-none} no_proxy=${no_proxy:-none}"
echo

check() {
    local label="$1" host="$2" url="$3"
    if getent hosts "$host" >/dev/null 2>&1; then
        echo "DNS  $host : OK ($(getent hosts "$host" | head -1 | awk '{print $1}'))"
    else
        echo "DNS  $host : FAIL"
    fi
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -I "$url" 2>/dev/null)
    echo "HTTPS $label : ${code:-no response} (000=연결 불가)"
}

check "s3 (giab.s3.amazonaws.com)" giab.s3.amazonaws.com "https://giab.s3.amazonaws.com/"
check "NCBI (ftp-trace)" ftp-trace.ncbi.nlm.nih.gov "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/"
echo
echo "해석:"
echo "- 로그인 노드 OK + 계산 노드 FAIL = 계산 노드에 외부 egress 없음."
echo "  클러스터 프록시가 있으면 제출 셸에서 export https_proxy=... 후 qsub -V (job에 전달됨)."
echo "  프록시가 없으면 다운로드는 로그인/전송 노드에서: nohup ./scripts/download.sh ... &"
echo "- 양쪽 다 000이면 방화벽/DNS 문제이니 관리자 문의."
