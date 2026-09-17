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
| ONT 매핑 건강도는 리드 개수가 아니라 염기 기준 | lesson | ONT 릴리스에 섞인 짧은 fail 리드가 reads-mapped%를 39%까지 끌어내리는데 정렬은 정상이다. 미매핑/매핑 리드 평균 길이비로 가른다 (실측 7~12배). 근거: `docs/reference/2026-08-27-ont-qc-first-pass.md` |
| DeepVariant raw 카운트는 RefCall로 1.7~3.4배 부풀어 있다 | lesson | PASS만 세면 Clair3와 3~7% 일치. caller 일치 판정을 raw로 하면 전건 오탐. phase1·phase2에서 각각 확인 |
| R9 ONT indel 정확도는 베이스콜러 버전이 지배한다 | lesson | guppy 3.2.x 1.75~1.97M vs 4.2.2 544~551k (3.5배). R9 indel 분석은 4.2.2+ 데이터셋만 |
| `crawl_release.py` — GIAB FTP 디렉토리 인덱스 재귀 크롤 + 파일별 HEAD → manifest diff | script | `current.tree`가 2025-02-27 이후 갱신되지 않아(2026-09-16 확인) 새 벤치마크(HG002 v5.0q 등)가 manifest에서 통째로 빠졌다. 인덱스 크기는 반올림이라 HEAD가 필수. NCBI는 동시 12+16 스레드에서 503 — 3+4 스레드·지수 백오프로 통과 |
| GIAB `latest/`는 심링크가 아니라 복사본이고 내용이 바뀐다 | lesson | HG002 latest/가 2026-05-27 v4.2.1→v5.0q로 교체됐다. 로컬 미러에는 두 버전이 공존하므로 평가는 버전 디렉토리를 직접 지정한다 |
| GIAB FTP와 S3 미러는 양방향으로 어긋난다 | lesson | HiSeq300x FASTQ 7천여 개는 FTP 사본이 S3보다 15% 작고(재압축), Strand-Seq EMBL·PacBio MtSinai 등 2,173 파일은 FTP에서만 사라졌다(S3에는 있음). manifest 크기는 다운로드 소스(S3) 기준이라 FTP만 보고 갱신하면 verify 전부 불일치·재다운로드가 난다. 크롤러는 FTP 불일치를 S3 HEAD로 교차 확인한다 (`crawl_data.py`, 2026-09-16) |
| GIAB `data/` 인덱스 기반 선별 HEAD 크롤 | script | 파일 7만 개를 전부 HEAD하지 않고 인덱스의 수정일·근사 크기로 신규/변경 후보만 고른다. 2026-08-13 manifest는 S3 목록 기반이라 FTP에만 있던 HG008 NIST 트리·Verkko·HG009 신규 등 15,605 파일(19.7 TiB)이 빠져 있었다 (`crawl_data.py`) |
| 카탈로그 파생 필드는 파일명 토큰으로 추정할 때 GIAB 용어를 조심 | lesson | `smvar`/`stvar`는 GIAB germline 벤치마크의 small/structural variant이지 somatic이 아니다. `phased` 단어는 purple 등 somatic 산출물 파일명에도 나온다. 인덱스 유무는 "어떤 인덱스라도 있음"이 아니라 BAM/CRAM/VCF 각각의 사이드카 짝으로 세야 PARTIAL이 잡힌다 (Codex 리뷰 지적, `catalog_new_dirs.py`) |
| 안 받기로 한 데이터는 manifest에서 지우는 것만으로 남지 않는다 | lesson | 크롤러에 exclusion 목록이 없으면 카탈로그 행이 살아 있는 한 다음 크롤이 "기존 디렉토리의 신규 파일"로 되돌려 넣는다. 목록 파일(`declined_by_decision.tsv`) + 크롤러 가드 + 카탈로그 생성기 필터 세 곳에 남겨야 결정이 유지된다 (2026-09-17) |
| GIAB S3 미러는 2024년 이후 somatic 신규 데이터를 거의 안 받는다 | lesson | HG008 NIST 트리·HG009 신규·Verkko를 표본 96건 조사해 S3 200 응답은 1건, 용량 상위 25건은 0건. `TOOL=s3`이어도 전부 FTP fallback이라 83 MB/s 실측치로 일정을 잡으면 크게 틀린다. 미러 가용성은 다운로드 계획 전에 표본으로 확인할 것 |
| 같은 데이터가 GIAB FTP에 다른 이름으로 두 번 올라와 있을 수 있다 | incident-note | `superseded-2022-data/BCM_Illumina_WGS_20220816/`와 `BCM_ILMN-somatic-analysis_20220816/`는 파일명·크기가 26건 모두 동일하다. 크롤이 새 이름을 신규로 잡아 1.63 TiB를 다시 받을 뻔했다. 대용량 신규 디렉토리는 형제 디렉토리와 파일명+크기를 대조해볼 것 |
| FASTQ 헤더로 시퀀싱 플랫폼 추정 (`detect_fastq_platform.sh`) | script | 리드 이름 규약만으로 판별 — Illumina 7필드 콜론, PacBio movie/zmw(`mNNNNN_YYMMDD_HHMMSS/zmw/ccs`), ONT UUID·`runid=`, MGI `LxCxRx`. 헤더 불일치 시 리드 길이(<1000bp 숏리드/≥1000bp 롱리드)로 폴백. GIAB 특정 로직이 없어 다른 프로젝트에도 그대로 재사용 가능 |
