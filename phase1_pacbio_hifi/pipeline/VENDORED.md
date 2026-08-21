# vendored: pacbio-hifi-wgs

- 원본: https://github.com/ehojune/bioinfo-agent `pipelines/pacbio-hifi-wgs`
- 커밋: `48ec4638c6312120f89c754e80a0e940aa4df766` (2026-08-20, hap.py 검증 포함)
- 로컬 원본: `D:\bioinfo-agent\pipelines\pacbio-hifi-wgs` (검증 기록: `docs/examples/20260820-pacbio-hifi-wgs-validation/`)

## 원본과의 차이 (이 저장소에서만 적용)

여러 데이터셋이 하나의 `--outdir`(`processed_data_ehojune/`)를 동시에 쓰므로 충돌 방지용 `run_label` 파라미터 추가:

1. `nextflow.config` params에 `run_label = 'run'` 추가
2. `pipeline_info/` 리포트 파일명에 `${params.run_label}-` 접두사
3. MULTIQC publishDir → `multiqc/${params.run_label}/`

파이프라인 로직(정렬·콜링)은 원본 그대로다. 원본이 업데이트되면 위 3개 변경만 다시 얹으면 된다.
