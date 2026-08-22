# HARVEST — Yuan 수확 후보

프로젝트가 일단락되면 심사해서 `D:\Yuan` (github.com/ehojune/Yuan)에 PR한다. 규약 정본은 Yuan `AGENTS.md`.

| 후보 | 종류 | 왜 |
|---|---|---|
| ONT 중복(재베이스콜) 판정: read_id 집합 대조 | lesson | PacBio movie ID의 ONT 대응물. read_id(fast5/pod5 UUID)는 재베이스콜해도 안 바뀌고 sequencing_summary에 전부 있어 fastq를 훑지 않아도 된다. `phase2_ont/scripts/03_dup_evidence.sh` |
| Clair3/DeepVariant 모델 가용성 확인 절차 | lesson | "컨테이너에 모델이 있다"를 가정하면 조용히 틀린 모델로 돈다. 이미지 `/opt/models` 목록 ↔ 필요 모델 대조 후 HKU/Rerio에서 받아 마운트. `phase2_ont/scripts/01_prepare_login_node.sh`, `docs/reference/ont_pipeline_choice.md` |
| Nextflow 기본 셸에 pipefail 없음 | incident-note | `samtools fastq \| minimap2 \| samtools sort`는 앞단이 죽어도 성공으로 보인다. `process.shell = ['/bin/bash','-euo','pipefail']` |
| minimap2 `-y` + Guppy fastq 코멘트 | incident-note | `-y`는 uBAM에서 옮긴 태그를 살리는 옵션인데, Guppy fastq의 `runid=... ch=...` 코멘트에 쓰면 SAM aux 형식이 아니라 BAM이 깨진다 |
| `ont-wgs` 파이프라인 (minimap2/Clair3/Sniffles2/LongPhase) | nextflow-pipeline | 첫 실행 검증 후 판단. 검증 전에는 올리지 않는다 |
| SGE 잡 1개 + Nextflow local executor 패턴 | lesson | 노드 수 제한이 있고 계산 노드에 외부망이 없는 클러스터의 정석. phase1/phase2가 같은 형태를 두 번 썼다 |
