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
