#!/usr/bin/env bash
# 리드 헤더 형식으로 FASTQ 한 개의 시퀀싱 플랫폼(Illumina/PacBio/ONT/MGI)을 추정한다.
# Illumina면 기기ID 접두어로 구체 기종(MiSeq/HiSeq.../NovaSeq 6000/NovaSeq X 등)도 붙인다.
# 헤더가 모호하면 리드 길이(<1000bp 숏리드, >=1000bp 롱리드)로 폴백한다.
# 표본(첫 200리드) 이후의 gzip 손상은 못 잡는다 — 전체 파일 무결성 검증은 이 스크립트의
# 몫이 아니다 (md5_verify_all.sh / verify.sh 또는 `gzip -t`를 쓸 것).
#
# Usage:
#   ./scripts/detect_fastq_platform.sh <fastq[.gz]>

set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <fastq[.gz]>" >&2; exit 1; }
f="$1"
[ -f "$f" ] || { echo "파일 없음: $f" >&2; exit 1; }

reader() { case "$f" in *.gz) zcat "$f" ;; *) cat "$f" ;; esac; }

# 첫 200리드에서 헤더 1줄 + 서열 길이 분포를 한 번에 뽑는다. awk가 200개를 채우고 먼저
# 종료하면 reader가 SIGPIPE(141)로 죽는데 이건 정상 종료라 무시한다. 그 외 reader 실패
# (손상된 gzip 등)는 PIPESTATUS로 따로 잡아서 부분 데이터로 조용히 성공 처리하지 않는다.
statsfile="$(mktemp)"
trap 'rm -f "$statsfile"' EXIT
set +o pipefail   # PIPESTATUS로 reader 실패를 직접 가릴 것이므로 파이프라인 자체의 집계 실패는 안 봄
reader | awk '
    NR==1 { hdr=$0 }
    NR%4==2 {
        n++; l=length($0); sum+=l
        if (n==1 || l<min) min=l
        if (l>max) max=l
        if (n==200) exit
    }
    END { printf "%s\t%d\t%d\t%.0f\n", hdr, (n>0?min:0), (n>0?max:0), (n>0?sum/n:0) }
' > "$statsfile"
reader_rc=${PIPESTATUS[0]}
set -o pipefail
[ "$reader_rc" = 0 ] || [ "$reader_rc" = 141 ] || { echo "읽기 실패 (exit $reader_rc, 손상되었거나 잘린 파일일 수 있음): $f" >&2; exit 1; }
IFS=$'\t' read -r header min max avg < "$statsfile"
[ -n "$header" ] && [ "${header:0:1}" = "@" ] || { echo "FASTQ 형식이 아님 (첫 줄이 '@'로 시작하지 않음): $f" >&2; exit 1; }

platform="미상"
evidence="헤더 패턴이 알려진 플랫폼과 일치하지 않음"

if [[ "$header" =~ ^@[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12} ]] || [[ "$header" == *" runid="* ]]; then
    platform="Oxford Nanopore (ONT)"
    evidence="헤더가 UUID 리드 ID 또는 runid= 태그 (MinKNOW/Guppy/Dorado 산출물의 특징)"
elif [[ "$header" =~ ^@m[^/[:space:]]*/[0-9]+/(ccs|[0-9]+_[0-9]+) ]]; then
    if [[ "$header" == *"/ccs"* ]]; then platform="PacBio HiFi (CCS)"; else platform="PacBio CLR (subread)"; fi
    evidence="헤더가 PacBio movie/zmw 형식 (m<무비명>/<zmw>/ccs 또는 <subread 범위> — Sequel/Revio 신형과 RS-II 구형 무비명 모두 포함)"
elif [[ "$header" =~ ^@[^:[:space:]]+:[0-9]+:[^:[:space:]]+:[0-9]+:[0-9]+:[0-9]+:[0-9]+([[:space:]]|$) ]]; then
    platform="Illumina (CASAVA 1.8+)"
    evidence="헤더가 <기기>:<런>:<플로우셀>:<레인>:<타일>:<x>:<y> 7필드 형식"
    is_illumina=1
elif [[ "$header" =~ ^@[^:[:space:]]+:[0-9]+:[0-9]+:[0-9]+:[0-9]+(#[A-Za-z0-9]+)?/[12]$ ]]; then
    platform="Illumina (구형 CASAVA <1.8)"
    evidence="헤더가 <기기>:<레인>:<타일>:<x>#<인덱스>/<mate> 형식"
    is_illumina=1
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

# Illumina로 판정됐으면 기기ID 접두어로 구체 기종까지 추정한다. 일루미나 공식 문서가 아니라
# 커뮤니티가 역추적한 비공식 관례라 접두어가 없거나 낯설면 조용히 건너뛴다(오탐보다 미상이 낫다).
if [ "${is_illumina:-0}" = 1 ]; then
    instrument="${header#@}"; instrument="${instrument%%:*}"
    model=""
    case "$instrument" in
        HWI-M*|M[0-9][0-9][0-9][0-9]*)  model="MiSeq" ;;
        HWUSI*)                         model="Genome Analyzer IIx" ;;
        HWI-C*|C[0-9][0-9][0-9][0-9]*)  model="HiSeq 1500" ;;
        HWI-D*|D[0-9][0-9][0-9][0-9]*)  model="HiSeq 2500" ;;
        J[0-9][0-9][0-9][0-9]*)         model="HiSeq 3000" ;;
        K[0-9][0-9][0-9][0-9]*)         model="HiSeq 3000/4000" ;;
        E[0-9][0-9][0-9][0-9]*)         model="HiSeq X" ;;
        NB[0-9]*|NS[0-9]*)              model="NextSeq 500/550" ;;
        MN[0-9]*)                       model="MiniSeq" ;;
        VH[0-9]*)                       model="NextSeq 1000/2000" ;;
        LH[0-9]*)                       model="NovaSeq X/X Plus" ;;
        A[0-9]*)                        model="NovaSeq 6000" ;;
    esac
    if [ -n "$model" ]; then
        platform="Illumina $model ${platform#Illumina }"
        evidence="$evidence; 기기ID(${instrument}) 접두어로 기종 추정 — 비공식 관례라 100% 보장은 아님"
    fi
fi

echo "파일       : $f"
echo "헤더 예시  : $header"
echo "리드 길이  : min=$min max=$max avg=$avg (표본 최대 200리드)"
echo "추정 플랫폼: $platform"
echo "근거       : $evidence"
