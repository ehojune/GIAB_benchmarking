# HG002 R10.4.1 완주와 채점 (2026-09-22)

PR #17·#18 로 편입·정정한 `HG002.ONT-R10_giab2025.01_PAW70337` 을 raw→VCF→채점까지 한 번에
통과시켰다. 수치와 해석은 [reference/2026-09-22-ont-r10-benchmark.md](../reference/2026-09-22-ont-r10-benchmark.md).

## 실행 기록

```bash
# 1) 파이프라인 — 잡 155279 (앞서 잘못된 entry 로 나간 155216·155268 은 qdel)
bash phase2_ont/scripts/10_submit.sh HG002.ONT-R10_giab2025.01_PAW70337
#    exit 0, ru_wallclock 58791s(16h20m), maxvmem 66.204GB, 30슬롯, shepherd-1-8

# 2) 산출물 검증
bash phase2_ont/scripts/30_verify_outputs.sh HG002.ONT-R10_giab2025.01_PAW70337
#    OK 1/1 — DeepVariant 산출물 포함 전부 존재

# 3) QC 리뷰  ※ bcftools 때문에 한 번 죽었다 (아래)
source phase2_ont/env.sh
PATH=/home/ehojune/program/bcftools-1.24:$PATH \
  python phase2_ont/scripts/35_review_qc.py --pass-counts --check-meth \
  HG002.ONT-R10_giab2025.01_PAW70337
#    cov 49 / base% 99.7 / err 0.0334 / len 18414 / C3_SNP 4.56M / DV_SNP 4.48M
#    INDEL 886k / ts/tv 1.77 / SV 26k / phase% 78 / N50 1281kb / MM% '.'
#    -> "모든 완료 런이 기준 안에 있음"

# 4) 배선 스모크 (새 판 첫 실행)
bash phase2_ont/scripts/04_stub_test.sh
#    5 row(s), 2 group(s), 4 unit(s) / stub 2회 / 진입 타입 3종 전부 통과

# 5) 소변이 채점 — 잡 156047
bash phase2_ont/scripts/60_benchmark.sh --list
bash phase2_ont/scripts/60_benchmark.sh --ready
#    OK ... jobid=156047 callers: clair3 deepvariant
#    exit 0, 3042s(50.7분), maxvmem 24.638GB, 8슬롯
bash phase2_ont/scripts/60_benchmark.sh --collect     # 40 rows

# 6) SV 채점 — 잡 156053
bash phase2_ont/scripts/61_benchmark_sv.sh --ready
#    OK ... jobid=156053 truth=HG002_GRCh38_v5.0q_stvar.vcf.gz refine=1
#    exit 0, 272s(4.5분), maxvmem 133.490GB, 22슬롯, shepherd-1-8
bash phase2_ont/scripts/61_benchmark_sv.sh --collect   # 6 rows

# 7) ts/tv 구간 분할 직접 측정 (로그인 노드, 10건 x 3구간)
TSV=tstv_regions.tsv bash phase2_ont/scripts/62_tstv_regions.sh
#    9런 x caller = 10건 전부 `안 + 밖 = 전체` 대조 통과
#    HG008 6런은 v4.2.1 benchmark BED 가 없어 SKIP (설계대로)
#    구간 안 2.0972~2.1400 / 구간 밖 1.0916~1.4839
```

## 스모크 테스트가 무엇을 덮었나

실전 완주가 stub 보다 강한 증거라 `aligned_bam_realign` 은 이미 증명된 상태였다. stub 이 덮은 것은
**실전이 안 건드리는 두 군데**다.

1. **`aligned_bam` 패스스루 분기** — 쓰는 런이 하나도 없어 아무도 밟아 보지 않은 코드다.
   `test_prealigned` 프로파일이 이것만 태운다. 2/2 실행에 `MINIMAP2_INDEX` 가 안 뜬 것이
   "모든 행이 `aligned_bam` 이면 인덱스를 건너뛴다" 분기가 실제로 탔다는 증거다 — 섞인 시트에서는
   이 조건이 영영 거짓이라 프로파일을 따로 둔 이유가 그것이었다.
2. **재그룹 키에 `type` 을 추가한 변경**(PR #18) — 키에서 type 이 유실되면 `ont_realign` 이
   `ubam` 으로 뭉개져 `MINIMAP2_ALIGN (tiny.realign)` 태스크가 아예 안 생긴다. 생겼고,
   `02_alignedBAM/TEST.ont_realign.test.bam` 이 나왔고, 패스스루 쪽은 그 파일이 **없다**.

`5 row(s)` 가 새 판의 표식이다(옛 판은 4). 큐/노드 게이트(`p2_require_sge_targets`)도 이날 처음
실물에서 돌아 `octopus.q@octopus-2-8/9 + shepherd.q@shepherd-1-8/9` 네 인스턴스를 골랐다.

## 사고 — `--pass-counts` 가 스크립트째로 죽었다

```
PermissionError: [Errno 13] Permission denied: 'bcftools'
```

겹친 것이 둘이다. ① 이 repo 의 다른 모든 자리는 도구를 컨테이너로 부르는데(로그인 노드 PATH 에
samtools 도 bcftools 도 없다) `--pass-counts` 만 맨 이름을 불렀다. 같은 파일의 `--check-meth` 는
제대로 하고 있었으니 고칠 때 형제 자리를 안 훑은 자국이다. ② `except (FileNotFoundError, ...)` 는
`PermissionError` 를 못 잡는다 — 형제이지 상속 관계가 아니다. 런 하나 건너뛰고 끝날 일이
스크립트 전체를 죽였다.

당장은 위 실행 기록의 `PATH=...` 로 넘겼고, `bcftools_cmd()`(`$BCFTOOLS` → 컨테이너 → PATH)와
`except OSError` 로 양쪽 phase 를 고쳤다. 판단 근거는 [decisions.md](../decisions.md) 같은 날 항목.

## 파생 — SV 슬롯을 올렸다

truvari 가 **133.5 GB** 를 썼다. env.sh 에 적힌 "ONT 실측 67~73 GB" 는 `BENCH_SV_THREADS` 가
생기기 전 **4스레드** 값이고 현재 기본은 8이다. 22슬롯(노드당 2잡)이면 267 GB 로 251 GB 노드를
넘기므로 33(1잡)으로 올렸다. 같은 주석이 "100 GB 를 넘기 시작하면 33으로 올릴 것" 이라 조건을
미리 적어 뒀고, 그게 걸린 것이다.

## 남은 것

- ~~`62_tstv_regions.sh` 실행~~ — **끝났다(위 7번).** 2026-09-18 의 "구간 안 = 2.1" 가정이
  실측 2.0972~2.1400 으로 확인됐고, HG005 구간 밖 추정 1.33 은 실측 **1.3064**(오차 1.8%)였다.
  R10 도 1.1454 로 닫혔다. 대신 열린 질문이 하나 생겼다 — 구간 밖에서 DeepVariant 와 Clair3 의
  순 차이가 ts/tv 2.18 이라, DV 가 구간 밖에서 버리는 쪽이 FP 가 아닐 수 있다(reference §5).
- HG001·HG003~HG007 의 R10 을 같은 버킷에서 편입 (보류 중)
- HG008 6런은 germline truth 가 없어 구조적으로 hap.py·Truvari 대상이 아니다 — somatic 평가 설계가 따로 필요하다
