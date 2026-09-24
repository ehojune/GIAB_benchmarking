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

**2026-09-24 추가 — bulk p21·p41 (UMD Revio, 각 29x, uBAM 1개씩 47·50 GB).** 카탈로그에 있었는데
category 가 `other`, phase0 매니페스트도 `HG008/other.tsv` 라 PacBio 목록(`pacbio_hifi.tsv`)만 읽는 생성기가
못 봤다. 파일명에 movie ID 가 없고(`XZOOK_…_1-1-A01.hifi_reads.bam`) `<시료>_ubams/` 하위라 `hg008t()` 규칙과도
다르다. 생성기에 `mcat` 을 두어 분류 파일을 골라 읽게 했다(매니페스트는 다운로드 세션 것이라 안 옮김).
p21 은 somatic truth 배치(0823p23)에 가장 가까운 계대라 #9 에 중요하다 — p21·p41·p100 이 계대 계열이 된다.

**germline truth 가 없어 `60_benchmark.sh`·`61_benchmark_sv.sh` 가 자동으로 건너뛴다.**
채점은 #9 가 서야 가능하고, 그전까지는 QC(`35_review_qc.py`)까지만 본다.

## #9 상세 — somatic 평가: 방법 B 결정 (2026-09-22)

**germline caller 출력을 somatic truth 에 그냥 대면 안 된다.** 우리 파이프라인이 HG008-T 에서
내는 것은 DeepVariant/Clair3 의 **전체 변이**(germline + somatic)인데, GIAB somatic 벤치마크는
**종양 특이 변이만** 담는다. 그대로 비교하면 germline 변이가 전부 FP 가 되어 precision 이 무너진다.

| | 방법 | 판정 |
|---|---|---|
| A | tumor − normal 뺄셈 | 기각 — subclonal(저 VAF) 을 germline caller 가 못 부른다 |
| **B** | **somatic caller 추가** (DeepSomatic 등) | **채택** (사용자 결정). 조건: 다른 데이터와 같은 처리는 그대로 하고, repo 정합성부터 맞춘다 |
| C | 채점 포기, QC 만 | 기각 |

**구현은 bioinfo-agent 위에 얹는다.** 위임 프롬프트: [runs/2026-09-23-bioinfo-agent-somatic-handoff.md](runs/2026-09-23-bioinfo-agent-somatic-handoff.md).
0단계로 vendor 사본과 diff 0 을 맞추고(`run_label` 역병합), 1단계로 somatic SNV/INDEL. 우리는
커밋 해시를 받아 고정 vendor 한다(계산 노드에 네트워크가 없어 submodule·원격 참조는 못 쓴다).
**GPU 가 없다**(`qhost -F gpu` 무응답) — CPU 경로. 쌍 11개를 CPU 로 2주 넘게 걸리면 외부 H100 요청.

### 서버에서 확인한 설계 사실 (2026-09-23)

**matched pair 가 이미 둘 있다.** 앞서 "정상은 Liss_lab 쪽뿐이라 다른 랩의 정상을 써야 한다"고
적었는데, Liss_lab 트리 안에 짝이 이미 있다.

| tumor | normal | 비고 |
|---|---|---|
| HG008-T.BCM_Revio_20240313 | HG008-N-D.BCM_Revio_20240313 | 이름상 같은 센터·같은 날짜 — 1순위 |
| HG008-T.PacBio_Revio_20240125 | HG008-N-P.PacBio_Revio_20240125 | 같은 센터 |
| NIST HG008T-p100 + 클론 8개 | (없음) → HG008-N-D 차용 | NIST 도 BCM Revio 라 센터는 같다. 배치·준비는 다르다 |
| NIST HG008T-p21 · p41 (UMD Revio, 09-24 추가) | (없음) → HG008-N-D 차용 | 센터도 다르다(UMD). p21 이 truth 배치(p23)에 가장 가깝다 |

**truth 가 무엇을 담는지가 채점 해석을 가른다.** smvar DraftBenchmark V0.3-20260425 README:

- **0823p23 배치 bulk 의 truncal/clonal 변이만** 담는다. 클론은 truncal 변이를 공유하므로 recall 은
  해석되지만 클론 고유 변이는 FP 로 잡혀 **precision 은 해석할 수 없다.** p100(100계대)도 같다.
- 권장 VCF `*_tumorvariants.vcf.gz`, BED 는 `_all.bed`(어려운 것 포함) 또는 `_nogermlineinterference.bed`.
  BED 셋은 디렉토리에 풀려 있지 않고 같은 폴더의 zip 안에만 있다(`unzip -l` 확인, all 1.0 MB · nogermlineinterference 1.1 MB · nogermlinewithin50bp 80.8 MB).
- 권장 비교 도구는 **aardvark**(PacBio). rtg vcfeval·hap.py 도 시험됐다고 한다.
- VAF 5~10% 미만은 걸러서 비교하라고 권한다 — caller 출력에 VAF 가 남아야 한다.
- SV/CNV 는 stvar-CNV V0.5-20260318. HG009 는 somatic truth 가 아직 없다.

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
| `62_tstv_regions.sh` (ts/tv 구간 분할) | ✅ (09-23 이식) | ✅ | — |
| `60_benchmark.sh STRAT=1` (구간별 hap.py) | ✅ | ✗ | — |
| `qsub_task.sh` (로그인 노드용 점검을 잡으로) | ✅ | ✗ | — |
| phase1·2 와 같은 `env.sh`/`lib.sh`/번호 스크립트 구조 | — | — | ✗ |

**phase1 이 가져와야 할 것 7개**(phase2 에 있고 phase1 에 없음). 거꾸로 phase1 에만 있는 것 2개는 ONT 세션이 필요할 때 가져간다.
**ONT 세션 몫 둘** (PR #38 Codex 지적, phase1 판은 고쳤다 — `phase2_ont/scripts/62_tstv_regions.sh`):
1. **INDEL 수가 안·밖에 이중으로 세어질 수 있다.** bcftools 기본값이 `-R` 은 레코드 겹침, `-T` 는 POS 라서
   구간 경계에 걸친 결실이 양쪽에 들어간다. SNP·ts/tv 는 영향이 없고(길이 1) 대조도 그 셋만 봐서 통과했다.
   phase1 판처럼 `--regions-overlap pos` / `--targets-overlap pos` + INDEL 합 대조. reference 문서의 INDEL 열을 다시 볼 것.
2. `bt()` 가 `GIAB_ROOT` 만 바인드 — `RUN_BASE` 를 그 밖에 두면 VCF 가 안 보인다. 기본 경로에서는 문제없다. 급하지 않지만, 가져올 때는
phase2 판을 그대로 이식하고 달라지는 부분만 주석에 적는다 — 두 phase 스크립트가 같은 모양인 것이
지금까지 여러 번 교훈을 한쪽에서 다른 쪽으로 바로 옮길 수 있게 해 줬다.

`62_tstv_regions.sh` 를 phase1 에 이식했다(09-23). 앞에 "Sequel I INDEL 이 나쁜 이유가 구간 밖 FP
때문인지 확인할 수 있다"고 적었는데 틀린 기대였다 — ts/tv 는 SNP 지표이고, hap.py 의 FP 는 정의상
구간 **안** 에서만 센다. 그 질문은 구간별 hap.py(`STRAT=1`)가 맡는다. ts/tv 구간 밖 값은 truth 없는
영역의 품질을 ONT 와 나란히 보는 용도다.

