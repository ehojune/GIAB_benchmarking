# HiSeq MarkDuplicates 실행 개선

2026-09-28 10:45 KST. 사용자 승인으로 HiSeq Mark 단계만 별도 실행했다. 정렬·FASTQ를 다시 계산하지 않는다.

| 항목 | 확인 결과 |
|---|---|
| HG002 / HG003 / HG004 | **157347 / 157348 / 157349 실행 중**, octopus-2-6 / 10 / 11 |
| 기존 HiSeq 155528 | **일시 정지(s)**, 기존 계산·로그 보존 |
| BGI / AVITI / MGI | 155526 / 155527 / 156690 실행 유지 |
| 실행 설정 | 같은 GATK 4.6.1.0·reference·중복 판정, heap 20→256GiB, local 10→16, reducer 4096 |
| 임시 공간 | SSD 1경로 + 공유 scratch 2경로. SSD 여유 100GiB·가용 RAM 30GiB 미만이면 해당 Java 프로세스 그룹 중단 |
| 현재 확인 | MemoryStore 153.4GiB·세 임시경로 적용, 초기 Spark 단계 전진, stderr 빈 파일 |

검증 잡 157343은 exit 0. 500만 리드에서 70.118→42.045초였고 정규화한 모든 리드·중복 플래그·중복 통계 해시가 일치했다. 후행 실행의 캐시 이득이 있을 수 있으며 작은 검증 입력의 배수를 전체 자료에 적용하지 않는다. 전체 실행은 heap 256GiB·reducer 4096·혼합 저장소로 검증 입력과 크기에 맞는 설정이 다르다. 새 완료 시각은 실제 본 실행 추세로 다시 추정한다.

첫 실행 157344–157346은 감시 코드의 Java 하위 프로세스 종료·RSS 집계를 보완하기 위해 초기 sampling 중 취소했다. 실패한 분석의 무근거 재시도가 아니다. v1 코드와 시도 폴더는 보존하고 v2를 별도 배포했다. 기존 sorted BAM 세 파일의 크기·mtime·inode를 고정했으며 원자료·공유 pipeline을 수정하지 않았다.

다음: 세 결과의 qacct exit 0·VERIFIED.json·BAM/index/리드 수·입력 보존을 독립 확인한 뒤에만 기존 master를 종료하고 결과를 연결한다. 후속 Snakemake dry-run에서 Mark/정렬/원자료 처리 재계산이 없음을 확인해 필요한 단계만 제출한다. 그 전에는 기존 155528을 정지 상태로 유지한다. 성공·진행 잡을 재제출하지 않는다.

서버 근거: `/BiO/scratch/ehojune/GIAB_benchmark/repairs/hiseq-mark-optimization-20260928/`의 BENCHMARK_VERIFIED.json, production-submission-v2.json, full-v2/{HG002,HG003,HG004}/PROGRESS.json·mark.log. 로컬 원본은 outputs/hiseq-mark-optimized-status-20260928-1046.txt와 hiseq-mark-production-v2-submission-20260928.txt.
