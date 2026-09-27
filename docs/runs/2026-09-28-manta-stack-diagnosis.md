# Manta 충돌 진단과 스택 설정 수정

2026-09-28 04:29 KST. **HG002 수정 검증 156831 실행 중이며 아직 복구 완료는 아니다.**

- GDB 156830에서 `searchRepeats()` 재귀 호출과 스택 경계 부근 SIGSEGV를 확인했다. 원자료·정상 결과의 크기·mtime·inode는 그대로다. 디버거 exit 0은 분석 성공을 뜻하지 않는다.
- 실제 SGE 잡은 스택 제한이 unlimited였지만 작업 스레드에는 **2MiB**만 배정됐다. 실행 전 제한을 유한한 **64MiB**로 지정한 뒤 실제 스레드 스택도 64MiB로 늘었음을 확인했다. **재귀 중 스택 부족이 유력하며 전체 실행으로 검증 중**이다.
- Manta 1.6.0·입력·reference·필터·10스레드는 유지했다. HG002만 별도 폴더에서 native Manta→변환·필터→VCF/QC를 실행한다. 성공·qacct·입력 보존 검증 뒤 HG003/4에 같은 수정을 적용한다.
- 사용자 정정에 따라 동일 명령 반복만 제한한다. 로그에 근거한 진단·수정·검증은 계속하며 3시간 점검 지침도 고쳤다.

[실측 근거](../reference/2026-09-28-manta-stack-evidence.json) · [Manta 재귀 함수](https://github.com/Illumina/manta/blob/v1.6.0/src/c%2B%2B/lib/assembly/IterativeAssembler.cpp#L509-L574) · [Linux 스레드 스택 규칙](https://man7.org/linux/man-pages/man3/pthread_create.3.html)
