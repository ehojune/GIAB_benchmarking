# catalog — master table의 원본

`master_catalog.tsv`가 유일한 원본이다. 루트 [README.md](../README.md)의 master table은 여기서 생성된다.

```bash
python catalog/build_readme.py      # master_catalog.tsv -> README.md 표 재생성
```

내가 처리를 돌리면 **README.md를 직접 고치지 말고** `master_catalog.tsv`의 해당 셀을 채운 뒤 위 명령을 다시 돌린다.

## 값 규칙

| 값 | 뜻 |
|---|---|
| `TRUE` | 그 단계 산출물이 존재 |
| `FALSE` | 없음 → 내가 돌려야 하는 자리 |
| 빈 칸 | 내가 아직 안 채운 자리 (`FALSE`인 단계의 `*_by` / `*_path` / `*_script`) |
| `N/A` | GIAB 공식 문서까지 찾아봤지만 확인 불가 |
| `-` | 해당 없음 (예: 원시 데이터에 phasing 컬럼) |

`*_by` 컬럼은 `GIAB` / `me` / `N/A` 중 하나. GIAB가 만든 산출물과 내가 만든 산출물을 같은 행에서 구분하는 용도다.

## 컬럼

**식별 (8)** — `sample` `category` `dataset` `giab_path` `platform` `coverage` `files` `size_gib`

**리드 (2)** — `reads_present` `reads_format`
: 원본 리드를 확보했는지. `reads_format`은 uBAM / FASTQ / bax.h5 / POD5 / subreads.bam 등.
  `FALSE`면 재정렬·재호출이 불가능하다는 뜻이라 중요하다.
  GIAB FTP가 아니라 SRA/ENA에서 받아온 경우도 `TRUE`로 두되, 출처와 로컬 경로를 `reads_format`에 적는다
  (HG001·HG005 SequelII 11kb가 그런 경우 — PRJNA540705/540706).

**index (6)** — `index_present` `index_types` `index_unindexed_n` `index_by` `index_local_path` `index_script`
: `index_present`는 BAM/VCF에 대응하는 `.bai`/`.pbi`/`.tbi`가 GIAB에 함께 있는지.
  `index_unindexed_n`은 index 없는 데이터 파일 개수 (매니페스트에서 실측).
  내가 `samtools index`나 `pbindex`를 돌리면 `index_by=me`, `index_script`에 스크립트 경로를 적는다.

**처리 단계 (각 5~6)**

| 단계 | 컬럼 |
|---|---|
| 정렬 | `aligned` `align_tool` `align_ref` `align_by` `align_local_path` `align_script` |
| 페이징 | `phased` `phase_tool` `phase_by` `phase_local_path` `phase_script` |
| germline 변이 | `variant_called` `variant_tool` `variant_by` `variant_local_path` `variant_script` |
| 메틸화 | `meth_called` `meth_tool` `meth_by` `meth_local_path` `meth_script` |
| somatic | `somatic_called` `somatic_tool` `somatic_by` `somatic_local_path` `somatic_script` |
| 어셈블리 | `assembled` `assembly_tool` `assembly_by` `assembly_local_path` `assembly_script` |

**출처 (4)** — `giab_processed` `tool_source` `next_step` `notes`
: `tool_source`는 툴 이름을 어디서 확인했는지. `filename`(파일명에 툴 표기) /
  `giab_doc:<GIAB README 경로>`(공식 문서에서 확인) / `N/A`(양쪽 다 없음).
  `next_step`은 내가 이 데이터로 다음에 할 일.

## 처음 어떻게 채웠나

초기값은 매니페스트 집계(결정론적)와 GIAB 공식 README 514개 본문 조사로 만들었다.
이후로는 이 TSV를 손으로 관리한다 — 내가 처리를 돌릴 때마다 해당 칸을 채우고
`build_readme.py`를 다시 돌리면 된다.

## 외부 유래 행 (GIAB FTP 밖에서 받은 데이터)

`giab_path`가 `external/`로 시작하는 행은 GIAB 경로가 아니라 **로컬 relpath**(`/BiO/scratch/ehojune/GIAB_benchmark/` + giab_path)다.
2026-09-17에 phase3 업체 비교용으로 받은 숏리드 6행(Google NovaSeq 6000/X, HPRC HiSeq 30x)이 여기 해당한다.

- `files`/`size_gib`의 원본은 그 phase의 외부 매니페스트(`phase3_shortread_wgs/ext_manifest.tsv`)다. 바뀌면 여기도 손으로 맞춘다.
- 크롤러는 이 행을 건드리지 않는다. `crawl_data.py`는 FTP 경로를 giab_path 접두로 라우팅하므로 `external/`은 매치되지 않고,
  `catalog_new_dirs.py`는 phase0 manifest에 그 경로의 파일이 하나도 없는 행의 files/size를 재계산하지 않는다.
- 같은 디렉토리에 여러 샘플이 섞여 있으면(Google 트리오) giab_path에 파일 접두까지 붙여 행을 유일하게 한다 — giab_path는 행의 키다.
- `giab_processed`는 FALSE, `tool_source`는 GIAB 문서가 그 데이터를 설명할 때만 `giab_doc:`(HPRC 사본이 그 경우), 아니면 `N/A`.
- phase1(HG001·HG005 SequelII 11kb, ENA)·phase2(HG001 rel6) 외부 리드는 GIAB 디렉토리가 따로 있어 기존 행의 `reads_format`에 출처를 적는 방식이다. 그 관례는 그대로다.

## 새 디렉토리가 FTP에 생기면

`phase0_download/scripts/crawl_data.py`가 카탈로그 행이 없는 새 디렉토리의 파일을 `manifests/data_unrouted_new.tsv`에 모은다.
받지 않기로 한 경로(`manifests/declined_by_decision.tsv`)는 여기서도 제외되어 카탈로그 행이 생기지 않는다.
`phase0_download/scripts/catalog_new_dirs.py`가 그 목록에서 플랫폼 디렉토리 단위로 행을 만든다(플랫폼 이름 패턴 → category,
README가 있으면 `tool_source`에 경로). 만든 뒤 `crawl_data.py --route-all`로 manifest에 넣고 `build_readme.py`·`build_xlsx.py`를 다시 돌린다.
2026-09-16에 HG008·HG009 행 102개를 이렇게 만들었다. 패턴에 없는 새 플랫폼은 `catalog_new_dirs.py`의 PATTERNS에 추가한다.

## 근거

- 파일 개수·바이트·index 존재 여부는 `phase0_download/manifests/`에서 스크립트로 실측한 값이다. 추정치가 아니다.
- 툴 이름은 (1) 파일명에 나타난 토큰, (2) GIAB 공식 README 514개의 본문에서만 가져왔다.
  "Illumina니까 BWA를 썼을 것" 같은 추측은 넣지 않았고, 그런 칸은 `N/A`다.
- 분류 근거 상세는 [docs/reference/catalog_evidence.md](../docs/reference/catalog_evidence.md).
