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

---

# vendored: pacbio-hifi-wgs-somatic (2026-09-25)

- 원본: https://github.com/ehojune/bioinfo-agent `pipelines/pacbio-hifi-wgs`, 브랜치 `worktree-pacbio-somatic-cpu`
- 커밋: `f2de95ea8f2fad81ecc18ead798146e95829f06f` (pacbio-hifi-wgs 0.2.0 — run_label + DeepSomatic tumor-normal CPU).
  bioinfo-agent main(`dd9262b`)에는 아직 안 들어간 후보 구현이다.
- 꺼낸 방법: `git archive f2de95e pipelines/pacbio-hifi-wgs` (작업 트리가 아니라 커밋에서). **이 사본은 한 글자도 고치지 않았다.**
- 검증 기록(bioinfo-agent 쪽): `docs/examples/20260925-pacbio-somatic-cpu-validation/handoff.md` — stub 회귀 + 음성 7건,
  실데이터는 HG008-T/N-P chr13:82–86 Mb 한 조각(16코어 1분 46초, peak RSS 17.8 GB). **전장·정확도 검증은 아직 없다.**

**왜 germline 사본(`pacbio-hifi-wgs`)을 교체하지 않고 따로 두나.** 0.2.0 은 48ec4638 이후 5커밋(CLR 진입, .bai 이름 강제,
preset 별 pbmm2 인덱스)을 함께 담는다. 업체 롱리드(수령 대기)는 공개 비교군과 같은 판으로 돌려야 하므로 germline 사본은
그대로 두고, 이 사본은 `scripts/70_submit_somatic.sh` 의 `--somatic_input` 실행에만 쓴다.

| 고정값 | |
|---|---|
| caller | DeepSomatic 1.10.0, `--model_type=PACBIO` (tumor-normal, 이미지 내장 모델 `/opt/models/deepsomatic/pacbio`) |
| 컨테이너 | `google/deepsomatic:1.10.0` (CPU). bioinfo-agent 검증 때 digest `sha256:6cd98c41781cdc1a2916d8029bedef70a57b87d41f933bd4cf259c80f291e27b` |
| reference | `$REF_FASTA` = GCA_000001405.15 GRCh38 no_alt analysis set — germline 정렬에 쓴 것과 같다 |
| 입력 | 기존 pbmm2 정렬 BAM(`02_alignedBAM/`) 그대로. 재정렬 없음 |
| 수정 1건 | DeepSomatic 1.10.0 이 `FORMAT/NAF` 를 `Number=R` 로 선언하고 ALT 당 하나씩 써서 `bcftools norm` 이 죽는다 — 파이프라인이 그 헤더 한 줄만 `Number=A` 로 고친다 |
