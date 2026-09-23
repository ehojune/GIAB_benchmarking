# 백로그 — 아직 안 한 일의 상세

[STATUS.md](STATUS.md) 작업 흐름 표의 **#8·#9·#10 행이 가리키는 상세**다.
상태(지금 어디까지 왔는지)는 그 표가 정본이고, 여기는 "왜 그 일이 필요하고 무엇을 정해야
하는가"를 적는다. 일이 끝나면 이 절을 지우고 STATUS 이력에 결과를 한 줄 남긴다.

## #8 상세 — phase1 HG008-T 9 실행단위 (2026-09-22 등록 완료)

`make_samplesheets.py` 의 RUNS 스펙에서 **HG008 의 NIST 트리가 통째로 빠져 있었다.** 다운로드는
2026-08-30 에 끝나 있었다. HG008 은 Liss_lab 4건만, HG009 는 NIST 11건이 다 등록돼 있었는데
HG008 NIST 만 없었다 — 의도적 제외가 아니라 누락이다. 생성기를 고쳐 재생성했다(손으로 넣으면
다음 재생성 때 사라진다).

**진입 타입은 fastq 가 아니라 uBAM 이다.** Revio 가 기기에서 CCS 를 끝내 보낸다.

| 실행 단위 | uBAM | GiB |
|---|---|---|
| HG008T-p100 (bulk, 20240508p100) | 1 | 49.9 |
| HG008T-2D6 / 2E6 / 3E4 (20240718p14 클론) | 1 / **2** / 1 | 46.1 / 57.5 / 69.9 |
| HG008T-SC6 / SC9 / SC14 / SC24 / SC28 (20240805p19 클론) | 1 each | 61.5 / 64.8 / 67.2 / 50.8 / 60.2 |

**합계 10 uBAM / 528.1 GiB.** 2E6 만 SMRT cell 이 2개다.

> 이전에 "1,001 GiB" 로 적었던 것은 **디렉토리 총량**이다. 절반이 GIAB 이 만든 정렬본
> (`*_PacBio-HiFi-Revio_<N>X_GRCh38-GIABv3.bam`)이고 **그건 입력이 아니다** — 우리는 uBAM 부터
> 다시 정렬한다. 패턴이 demux uBAM 만 잡으므로 정렬본은 자동으로 빠진다.

커버리지가 48~60X 라 런당 10~15시간 예상(phase1 30x 실측 6~7시간 기준). 파이프라인 잡은
30슬롯이라 노드당 2런이다.

**germline truth 가 없어 `60_benchmark.sh`·`61_benchmark_sv.sh` 가 자동으로 건너뛴다.**
채점은 #9 가 서야 가능하고, 그전까지는 QC(`35_review_qc.py`)까지만 본다.

## #9 상세 — somatic 평가에서 먼저 정해야 할 것

**germline caller 출력을 somatic truth 에 그냥 대면 안 된다.** 우리 파이프라인이 HG008-T 에서
내는 것은 DeepVariant/Clair3 의 **전체 변이**(germline + somatic)인데, GIAB somatic 벤치마크는
**종양 특이 변이만** 담는다. 그대로 비교하면 germline 변이가 전부 FP 가 되어 precision 이 무너진다.

갈 수 있는 길 셋:

| | 방법 | 문제 |
|---|---|---|
| A | tumor − normal 뺄셈 | 거칠다. somatic 은 subclonal(저 VAF)이 많은데 germline caller 가 그걸 잘 못 부른다 |
| B | somatic caller 추가 (DeepSomatic 등, PacBio 지원) | 파이프라인 확장이 필요하다. 가장 정공법 |
| C | 채점 포기, somatic 구간을 QC·커버리지 확인에만 사용 | 안전하지만 얻는 게 적다 |

**매칭 정상(normal)이 또 하나의 걸림돌이다.** 매니페스트 실측으로 NIST 트리에는 tumor 만 있고
정상은 Liss_lab 쪽뿐이다(HG008-N-D, HG008-N-P). 즉 NIST 클론 9건의 짝을 맞추려면 **다른 랩·다른
준비의 정상**을 써야 해서, 랩 차이가 somatic 판정에 섞인다.

이 셋 중 무엇으로 갈지는 사용자 결정이 필요하다 — #8 산출물이 나오기 전에도 정할 수 있다.

## 표준화 백로그 (#10)

**방향이 한 번 뒤집혔다.** 원래 "phase2 를 기준으로 phase1 을 맞춘다" 였는데, phase1 이 따라가는
동안 phase2 가 더 나갔다. 2026-09-23 코드 직접 확인 결과가 아래다 — **표를 "미착수"로 뭉뚱그려
두었더니 이미 한 것까지 안 한 것으로 보였다.**

| 항목 | phase1 | phase2 | phase3 |
|---|---|---|---|
| `lib.sh` 공용 헬퍼 (`*_img_path`, `*_container_uris`, `*_sge_*`) | ✅ | ✅ | ✗ |
| `60_benchmark.sh` 하드닝 (`.fai` 자동생성, qsub 검증, `submit_many`) | ✅ | ✅ | — |
| `10_submit.sh` qsub 하드닝 | ✅ | ✅ | — |
| `61_benchmark_sv.sh` | ✅ | ✅ | — |
| `env.local.sh.example` 벤치마크 프리셋 | ✅ | ✅ | — |
| `35_review_qc.py --pass-counts` (bcftools 해석 포함) | ✅ | ✅ | — |
| `50_update_catalog.py` 가 엑셀도 재생성 | ✅ | ✅ | — |
| `30_verify_outputs.sh` 에 haplotagged BAM 점검 | ✗ | ✅ | — |
| `30_verify_outputs.sh` 에 mosdepth/QC 점검 | ✗ | ✅ | — |
| `35_review_qc.py --calibrate` | ✗ | ✅ | — |
| `35_review_qc.py basemap_pct` (CIGAR 기반 매핑률) | ✗ | ✅ | — |
| `35_review_qc.py --check-meth` | ✗ | ✅ | — |
| `excluded.tsv` 기구 | ✗ | ✅ | — |
| `run_table.tsv` 의 `files` 열 | ✗ | ✅ | — |
| `62_tstv_regions.sh` (ts/tv 구간 분할) | ✗ | ✅ | — |
| phase1·2 와 같은 `env.sh`/`lib.sh`/번호 스크립트 구조 | — | — | ✗ |

**phase1 이 가져와야 할 것 8개**(phase2 에 있고 phase1 에 없음). 급하지 않지만, 가져올 때는
phase2 판을 그대로 이식하고 달라지는 부분만 주석에 적는다 — 두 phase 스크립트가 같은 모양인 것이
지금까지 여러 번 교훈을 한쪽에서 다른 쪽으로 바로 옮길 수 있게 해 줬다.

`62_tstv_regions.sh` 는 phase1 에도 쓸모가 있다. phase1 의 SNP 는 포화(F1 .9984~.9994)라
ts/tv 로 더 캘 게 없어 보이지만, 구간 안/밖을 갈라 보면 Sequel I 의 INDEL 이 나쁜 이유가
구간 밖 FP 때문인지 확인할 수 있다 — 지금은 미확인으로 남아 있다.

## 문서 수치 불일치 (다운로드 세션 몫, 2026-09-23 확인 시점 미해결)

PacBio 세션이 repo 를 훑어 찾은 것이다. ONT·PacBio 몫은 처리했고 이 둘이 남았다.

| 무엇 | 어디 |
|---|---|
| "현재 **435개 prefix · 81,302파일**" — 카탈로그는 **442 / 81,316** 이다 | `README.md` 605행 |
| phase0 README 의 81,302 / 116,509.5 GiB 는 **FTP/S3 본체만**인 값이라 그 자체로 틀리진 않지만, 81,330(4경로 합집합)과 나란히 있어 읽는 사람이 헷갈린다. 둘을 구분해 적으면 좋겠다 | `phase0_download/README.md` 4·5·26행 |

`README.md` 의 Journal·`docs/runs/` 의 옛 수치는 **건드리지 않는다** — append-only 기록이고
그 시점의 사실로 맞다. 위 둘은 "현재 상태"를 말하는 문장이라 다르다.
