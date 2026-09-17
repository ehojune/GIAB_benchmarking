#!/usr/bin/env bash
# 리드 헤더 형식으로 FASTQ 한 개의 시퀀싱 플랫폼(Illumina/PacBio/ONT/MGI)을 추정한다.
# 헤더가 모호하면 리드 길이(<1000bp 숏리드, >=1000bp 롱리드)로 폴백한다.
#
# Usage:
#   ./scripts/detect_fastq_platform.sh <fastq[.gz]>

set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <fastq[.gz]>" >&2; exit 1; }
f="$1"
[ -f "$f" ] || { echo "파일 없음: $f" >&2; exit 1; }

reader() { case "$f" in *.gz) zcat "$f" ;; *) cat "$f" ;; esac; }

# 첫 200리드에서 헤더 1줄 + 서열 길이 분포를 한 번에 뽑는다. awk가 200개를 채우고
# 먼저 종료하면 reader가 SIGPIPE로 죽는데, pipefail이 이걸 오류로 보지 않도록 이 파이프에서만 끈다.
stats="$(set +o pipefail; reader | awk '
    NR==1 { hdr=$0 }
    NR%4==2 {
        n++; l=length($0); sum+=l
        if (n==1 || l<min) min=l
        if (l>max) max=l
        if (n==200) exit
    }
    END { printf "%s\t%d\t%d\t%.0f", hdr, (n>0?min:0), (n>0?max:0), (n>0?sum/n:0) }
')"
IFS=$'\t' read -r header min max avg <<<"$stats"
[ -n "$header" ] && [ "${header:0:1}" = "@" ] || { echo "FASTQ 형식이 아님 (첫 줄이 '@'로 시작하지 않음): $f" >&2; exit 1; }

platform="미상"
evidence="헤더 패턴이 알려진 플랫폼과 일치하지 않음"

if [[ "$header" =~ ^@[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12} ]] || [[ "$header" == *" runid="* ]]; then
    platform="Oxford Nanopore (ONT)"
    evidence="헤더가 UUID 리드 ID 또는 runid= 태그 (MinKNOW/Guppy/Dorado 산출물의 특징)"
elif [[ "$header" =~ ^@m[^/[:space:]]*/[0-9]+/(ccs|[0-9]+_[0-9]+) ]]; then
    if [[ "$header" == *"/ccs"* ]]; then platform="PacBio HiFi (CCS)"; else platform="PacBio CLR (subread)"; fi
    evidence="헤더가 PacBio movie/zmw 형식 (m<무비명>/<zmw>/ccs 또는 <subread 범위> — Sequel/Revio 신형과 RS-II 구형 무비명 모두 포함)"
elif [[ "$header" =~ ^@[A-Za-z0-9]+:[0-9]+:[A-Za-z0-9_-]+:[0-9]+:[0-9]+:[0-9]+:[0-9]+([[:space:]]|$) ]]; then
    platform="Illumina (CASAVA 1.8+)"
    evidence="헤더가 <기기>:<런>:<플로우셀>:<레인>:<타일>:<x>:<y> 7필드 형식"
elif [[ "$header" =~ ^@[A-Za-z0-9_.-]+:[0-9]+:[0-9]+:[0-9]+:[0-9]+(#[A-Za-z0-9]+)?/[12]$ ]]; then
    platform="Illumina (구형 CASAVA <1.8)"
    evidence="헤더가 <기기>:<레인>:<타일>:<x>#<인덱스>/<mate> 형식"
elif [[ "$header" =~ ^@[A-Za-z0-9]+L[0-9]+C[0-9]+R[0-9]+ ]]; then
    platform="MGI/BGI (DNBSEQ)"
    evidence="헤더가 <플로우셀>L<레인>C<컬럼>R<로우> 형식"
elif [ "$avg" -ge 1000 ]; then
    platform="미상 (롱리드 추정: PacBio 또는 ONT)"
    evidence="헤더 패턴은 불일치하지만 평균 리드 길이 ${avg}bp가 롱리드 특성"
elif [ "$avg" -gt 0 ]; then
    platform="미상 (숏리드 추정: Illumina 또는 MGI)"
    evidence="헤더 패턴은 불일치하지만 평균 리드 길이 ${avg}bp가 숏리드 특성"
fi

echo "파일       : $f"
echo "헤더 예시  : $header"
echo "리드 길이  : min=$min max=$max avg=$avg (표본 최대 200리드)"
echo "추정 플랫폼: $platform"
echo "근거       : $evidence"
