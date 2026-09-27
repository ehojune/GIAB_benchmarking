# 공개 MarkDuplicates 지연: 조회용 근거

2026-09-28 07:13 KST 실측. FASTQ는 샘플당 BGI 208–217GiB, AVITI 231–251GiB, HiSeq 774–907GiB, MGI 178–354GiB(압축 R1+R2)다. 회사 자료는 50–98GiB다. HiSeq 정렬 BAM은 516–599GiB다. 실제 파일 stat이며 파일 수·링크 대상은 로컬 `outputs/raw-input-sizes-20260928.txt`에 보관했다.

공유 Snakemake mark 규칙은 GATK MarkDuplicatesSpark에 Java heap20GiB·`local[10]`을 주고 Spark 임시 block을 `/BiO` Lustre에 놓는다. 로그의 반복 shuffle은 task당 수천~수만 block을 읽는다. 09-28 07:12 대표 BGISEQ·HiSeq 노드 10초 측정에서 host I/O wait 11.24%·16.31%, Java의 D 상태 thread와 낮은 CPU 사용을 봤다. 원인 가설은 **큰 입력과 공용 저장소 입출력 병목**이다. heap/GC가 주원인인지, 정확한 종료 시각은 판정하지 못했다.

계산노드 SSH는 미등록 host key라 우회하지 않았다. SGE 읽기 전용 진단 156839·156840은 exit0; 선행 156837·156838의 Python3.6 API 오류는 분석 실패가 아니다. 원래 분석 4잡은 전진 중이며 유지한다. 추후 조정은 입력·중간 결과를 보존하는 job-local 설정에서만 검토한다. 전체 재제출·공유 pipeline 수정은 이 진단의 결론이 아니다.

서버 근거: `/BiO/scratch/dyl/kbb/UTILS/Tools/in_house_scripts/snakemake_script/germline_pipeline_snakefile.py:513`; 각 세트 `tmp/05.mark/*_mark.log`; `/BiO/scratch/ehojune/GIAB_benchmark/repairs/markdup-readonly-diagnosis-20260928-v2/{bgi,hiseq}.json`. 로컬 전체 확인 기록: `outputs/markdup-bottleneck-evidence-20260928.json`. [GATK 설명](https://gatk.broadinstitute.org/hc/en-us/articles/360036362052-MarkDuplicatesSpark).
