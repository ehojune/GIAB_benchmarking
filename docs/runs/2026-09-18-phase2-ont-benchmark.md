# phase2 ONT 정확도 평가 첫 실행 (2026-09-18)

`60_benchmark.sh`(hap.py)와 `61_benchmark_sv.sh`(Truvari)를 nbb2에서 처음 실제로 돌렸다.
그때까지는 샌드박스 검증만 있었다. 10잡 전부 exit 0.

수치와 해석: [docs/reference/2026-09-18-ont-benchmark-first-results.md](../reference/2026-09-18-ont-benchmark-first-results.md).

## 실행

```bash
bash phase2_ont/scripts/01_prepare_login_node.sh     # hap.py·truvari 이미지를 여기서 처음 받았다
bash phase2_ont/scripts/60_benchmark.sh --ready      # 8잡 (HG001~HG007, Clair3)
bash phase2_ont/scripts/61_benchmark_sv.sh --ready   # 2잡 (HG002)
bash phase2_ont/scripts/60_benchmark.sh --collect
bash phase2_ont/scripts/61_benchmark_sv.sh --collect
```

잡 153682~153691, 전부 shepherd-1-9. hap.py 39~44분 / maxvmem 23.7~24.5 GB,
truvari+refine 5~6.6분 / maxvmem 67~73 GB.

## 걸린 것 하나

`--ready` 첫 시도가 `ERROR: truvari 이미지 없음`으로 멈췄다. `01_prepare_login_node.sh`가
`BENCH_IMAGES`(hap.py·truvari)를 받기 시작한 것은 PR #6부터인데, 마지막으로 그 스크립트를 돌린 게
그 전이었다. 재실행하면 이미 있는 것은 `cached:`로 건너뛰고 없는 둘만 받는다.

→ **벤치마크 단계를 처음 쓰는 클론에서는 `01_prepare_login_node.sh`를 먼저 다시 돌려야 한다.**
`60`·`61`의 preflight가 이미 이미지 없음을 명확히 잡아내므로 별도 가드는 넣지 않았다.

같은 실행에서 `01_prepare`가 `r941_prom_hac_g238` 모델 디렉토리를 자동 복구했다(이전 실행이 남긴
반쯤 풀린 디렉토리). 그 모델은 gate된 dup 런만 쓰므로 실제 실행에는 영향이 없었다.

## 이 실행이 바꾼 것

- **ts/tv 열린 질문(2026-08-27)이 R9에서 닫혔다.** FP가 벤치마크 구간 밖에 몰려 있다는 게 확인됐다.
- **indel 격차 수치가 갱신됐다.** 개수 기준 3.5배 → FP 기준 42배.
- **`h_vmem`이 강제 종료 한도가 아니라는 것이 확인됐다.** 32G 선언 잡이 73 GB를 쓰고 exit 0.
  `env.sh`의 주석을 고치고 `BENCH_SV_VMEM`을 실측에 맞춰 80G로 올렸다.
- **`--refine`을 켠 판단이 실측으로 뒷받침됐다** (F1 +4.8~5.1점, 비용 5분).

## 같은 날 — 파이프라인 14/14 완료

HG008T-p2가 끝나 `35_review_qc.py --pass-counts --check-meth`를 14런 전부에 돌렸다
(완료 14 / 대기 0 / dup-skip 4). **HG008T-p2가 전 코호트 최고 성적이다** — 염기 매핑률 99.5%,
리드 오류율 .0237, 커버리지 77x. dorado sup v4.3.0 + R10.4.1의 상한을 보여준다.

경고는 **`N50미산출` 2건**뿐이고 다른 항목은 없다. 둘 다 R10이고 둘 다 std 라이브러리다
(`HG008-T.UCSC_ONT_20231003`, `HG008T-p2.BCM_ONT-std`). 위상 자체는 정상이다(73%, 75%).
phase1에서도 같은 현상을 봤고 그때도 지표 미산출로 처리했다 — whatshap stats 출력에서 block N50
칸이 비는 경우가 있다. **1건일 때는 예외로 넘겼지만 2건이 되었으니 다음에는 whatshap 출력 원문을
한 번 봐야 한다**(`04_QC/.../phased_whatshap/*.tsv`). 값이 실제로 없는 것인지 파서가 못 읽는 것인지
아직 구분하지 않았다.

R10의 위상 block N50은 전반적으로 R9보다 훨씬 짧다(526~2,072 kb vs 6,671~86,994 kb).
HG008 R10 런이 std 위주라 리드가 짧은 것이 주된 이유로 보인다 — 케미스트리 자체의 성질은 아니다.

## 다음

- R10·DeepVariant는 truth가 없어 이 경로로는 못 연다. GIAB FTP에 HG002 R10 ONT는 없다 —
  열려면 외부 수급이 필요하다. 공개 후보 조사는 2026-09-18 별도로 착수했다.
- `N50미산출` 2건의 원인 구분 (whatshap 출력 원문 확인)
