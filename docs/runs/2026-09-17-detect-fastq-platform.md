# 2026-09-17 — detect_fastq_platform.sh

- 목적: 시퀀싱 플랫폼(Illumina/PacBio HiFi·CLR/ONT/MGI)을 FASTQ 헤더로 추정, 안 걸리면 리드 길이로 폴백.
- 사전 확인: Yuan `JOURNAL.md`/`catalog/assets.yaml`에 판별기 자산 없음(`pacbio.pbmm2`는 정렬 프리셋이라 다른 물건) → 신규 작성.
- 테스트(스크래치패드 합성 fastq, repo에 파일로 남기지 않음): Illumina 신형(7필드 콜론)/구형(CASAVA<1.8, 4필드+#index/mate),
  PacBio HiFi(ccs)/CLR(subread), ONT(UUID·`runid=`), MGI(`LxCxRx`) 8개 헤더 패턴 + gzip + 파일없음/빈파일/비-fastq 에러 케이스 +
  300리드 파일로 200리드 조기종료 시 SIGPIPE·pipefail 상호작용(plain+gzip 둘 다 정상 종료 확인).
- 발견 1: 구형 Illumina 정규식에 필드(y좌표) 누락 — 최초 커밋 전에 수정.
- 발견 2 (Codex 리뷰 1회차 P2): 구형 PacBio RS-II 무비명 접미사(`_<기기>_c<셀바코드>_s<세트>_p<파트>`) 미인식 —
  `m<무비명>/<zmw>/(ccs|범위)` 접미사만 보는 정규식으로 완화해 반영, 신형/구형 fixture 둘 다 재검증 통과.
- Codex 리뷰 1회차: P1 1(이 기록·`docs/decisions.md` 누락) · P2 1(위 발견 2). 둘 다 반영 후 재검토 요청.
- Codex 리뷰 2회차 P2 2건 반영: (1) Illumina 신형 헤더 기기명이 하이픈 포함 실기기명(`HWI-ST911` 등)을 못 받음 —
  두 Illumina 분기 모두 기기명 필드를 `[^:[:space:]]+`로 완화. (2) SIGPIPE 억제(`|| true`)가 손상된 gzip 등 진짜 reader
  오류까지 삼켜 부분 데이터로 exit 0 — `PIPESTATUS[0]`로 reader 종료코드를 따로 확인(0/141만 정상)하게 변경.
- 이 수정 과정에서 자체 회귀 2건 발견·수정(재검증 통과): awk `printf`에 개행 누락으로 `read`가 EOF에서 실패 리턴(`set -e`가
  즉시 스크립트 종료), `pipefail` 켜진 채 `|| true`를 쓰면 `PIPESTATUS`가 `true` 하나짜리로 덮어써짐(bash 5.3.15 확인) —
  둘 다 `|| true` 대신 해당 구간만 `pipefail`을 껐다 켜는 방식으로 해결.
- 재검증: 기존 fixture 전체(11개 헤더 패턴 + gzip + 300리드 SIGPIPE) 회귀 없음 확인 + 신규 fixture(하이픈 기기명, 잘린 gzip)
  추가해 통과. 잘린 gzip은 이제 "읽기 실패" exit 1로 정확히 보고됨(이전엔 부분 데이터로 조용히 exit 0).
- Codex 리뷰 3회차: P2 1(표본 200리드 이후의 gzip 손상은 여전히 못 잡음) · P1 0. 사용자 지시(P1 없으면 병합)에 따라
  코드는 고치지 않고 스크립트 상단에 이 한계를 명시하는 주석만 추가, main에 병합(PR #7, `6fbacc2`).

## 후속: Illumina 기기 모델 매핑 (같은 날, PR 머지 후)

- 사용자가 서버(nbbcluster2)에서 실제 4개 파일(G000-gd4/HG002·3·4, theragen, macrogen, jslink)에 돌려 전부 정상
  동작 확인(실행 비트 그대로 살아있음, `git pull`만으로 사용 가능 확인) — 4개 다 기기ID가 `LH00xxx`로 동일.
- "더 분석 가능한가" 질문에 웹 검색(WebSearch)으로 확인: `LH00` 접두어 = NovaSeq X/X Plus. 10x Genomics의
  `tenkit/illumina_instrument.py`(구형 기종 매핑 코드)와 ASeq Newsletter(LH00587/LH00584 예시)를 근거로 삼음.
  이 매핑은 일루미나 공식 문서가 아니라 커뮤니티 역추적 관례라는 점을 답변에 명시.
- 사용자 승인 후 기기ID 접두어→기종 매핑 12개(MiSeq/GA IIx/HiSeq 1500·2500·3000·3000-4000·X/NextSeq 500-550·
  1000-2000/MiniSeq/NovaSeq 6000/NovaSeq X-X Plus) 추가. 미등록 접두어는 조용히 generic으로 남김(모델 지어내지 않음).
- 테스트: 실제 4개 헤더 재현 + 12개 기종 대표 헤더 + 매핑 없는 접두어 2개(하이픈 포함 실제 HiSeq명, 임의 미등록명)
  + 기존 회귀 세트(PacBio/ONT/MGI/미상 폴백, 300리드 SIGPIPE, 손상 gzip, 에러 케이스) 전체 재확인.
- 구현 중 자체 버그 1건 발견·수정: `platform` 문자열에 괄호를 이중으로 씌워 `((CASAVA 1.8+))`가 나옴 — 이미
  괄호 포함된 문자열에 또 괄호를 감쌈. 테스트로 잡고 커밋 전에 수정.
