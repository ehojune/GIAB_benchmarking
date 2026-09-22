# phase1 PacBio HiFi 정확도 평가 첫 실측 (2026-09-22)

조회용 문서다. 판단과 다음 할 일은 [STATUS.md](../STATUS.md), 경위는 [decisions.md](../decisions.md).

`60_benchmark.sh --ready`로 던진 19잡, **전부 exit 0**. GIAB v4.2.1 germline truth 대비 hap.py 0.3.12,
caller 2종(DeepVariant 1.10.0 / Clair3 v1.2.0) × 19런 = 평가 38건. 원본 표는 `phase1_bench_summary.tsv`
(152행 = 38 × SNP/INDEL × ALL/PASS). 아래는 전부 **PASS 행**이다.

잡 155355~155373, wall 3371~5008초(56~83분), maxvmem 48.40~48.82 GB (`BENCH_SLOTS=16`).

## 결론 세 줄

1. **SNP는 전 런·전 caller가 사실상 동일하다** — F1 0.99844~0.99941 (38건, 평균 0.99902). 기기 세대도
   caller도 유의한 차이를 못 만든다. PacBio HiFi에서 SNP는 이미 포화됐다고 보면 된다.
2. **INDEL이 갈리는 축은 기기 세대다.** Sequel I가 유독 나쁘다 (아래).
3. **Revio에서만 Clair3가 DeepVariant에 진다** — INDEL F1 −0.006~−0.017. Sequel II 12런에서는
   두 caller가 사실상 동률(−0.002~+0.001)이다.

## 전체 표 (PASS)

instr은 `inputs_manifest.tsv`의 movie ID로 판정한다 (m84=Revio, m64=Sequel II, m54=Sequel I).
`-` 셋은 파일명에 movie ID가 없어 판정 불가 — 경로의 `PBmixSequel<NNN>`은 세대 표시가 아니다.

| dsid | instr | INDEL DV | INDEL CL | DV−CL | SNP DV | SNP CL |
|---|---|---|---|---|---|---|
| HG006.PacBio_CCS_15kb_20kb_chemistry2 | - | 0.9967 | 0.9974 | -0.0008 | 0.9993 | 0.9991 |
| HG007.PacBio_CCS_15kb_20kb_chemistry2 | - | 0.9935 | 0.9936 | -0.0001 | 0.9992 | 0.9992 |
| HG002.PacBio_HiFi-Revio_20231031 | Revio | 0.9913 | 0.9747 | +0.0166 | 0.9992 | 0.9990 |
| HG003.PacBio_HiFi-Revio_20231031 | Revio | 0.9916 | 0.9785 | +0.0131 | 0.9991 | 0.9990 |
| HG004.PacBio_HiFi-Revio_20231031 | Revio | 0.9920 | 0.9862 | +0.0058 | 0.9991 | 0.9987 |
| HG002.PacBio_CCS_10kb | SequelI | 0.9646 | 0.9640 | +0.0007 | 0.9989 | 0.9988 |
| HG002.PacBio_CCS_15kb | SequelI | 0.9282 | 0.9130 | +0.0152 | 0.9988 | 0.9988 |
| HG001.HudsonAlpha_PacBio_CCS | SequelII | 0.9762 | 0.9752 | +0.0010 | 0.9991 | 0.9991 |
| HG001.PacBio_SequelII_CCS_11kb | SequelII | 0.9930 | 0.9939 | -0.0009 | 0.9994 | 0.9992 |
| HG002.PacBio_CCS_15kb_20kb_chemistry2 | SequelII | 0.9973 | 0.9980 | -0.0007 | 0.9993 | 0.9993 |
| HG002.PacBio_SequelII_CCS_11kb | SequelII | 0.9932 | 0.9951 | -0.0020 | 0.9992 | 0.9990 |
| HG003.PacBio_CCS_Google_15kb | SequelII | 0.9855 | 0.9843 | +0.0011 | 0.9987 | 0.9986 |
| HG003.PacBio_CCS_HudsonAlpha_14kb_15kb_19kb | SequelII | 0.9950 | 0.9959 | -0.0009 | 0.9992 | 0.9991 |
| HG004.PacBio_CCS_Google_15kb | SequelII | 0.9860 | 0.9866 | -0.0005 | 0.9986 | 0.9986 |
| HG004.PacBio_CCS_HudsonAlpha_15kb_21kb | SequelII | 0.9933 | 0.9949 | -0.0016 | 0.9992 | 0.9991 |
| HG005.HudsonAlpha_PacBio_CCS | SequelII | 0.9963 | 0.9955 | +0.0008 | 0.9993 | 0.9992 |
| HG005.PacBio_SequelII_CCS_11kb | SequelII | 0.9968 | 0.9969 | -0.0000 | 0.9992 | 0.9991 |
| HG006.PacBio_HiFi_Google | SequelII | 0.9921 | 0.9930 | -0.0009 | 0.9992 | 0.9989 |
| HG007.PacBio_HiFi_Google | SequelII | 0.9747 | 0.9749 | -0.0002 | 0.9985 | 0.9984 |

## Sequel I INDEL이 나쁜 건 caller 모델 탓이 아니다

| 세대 | n | INDEL F1 (DV) 평균 | 범위 |
|---|---|---|---|
| Sequel I | 2 | 0.9464 | 0.9282 ~ 0.9646 |
| Sequel II | 12 | 0.9899 | 0.9747 ~ 0.9973 |
| Revio | 3 | 0.9916 | 0.9913 ~ 0.9920 |
| 판정불가 | 2 | 0.9951 | 0.9935 ~ 0.9967 |

Sequel I 두 런은 Clair3 모델이 범용 `hifi`다(Sequel II 런은 `hifi_sequel2`, Revio 런은 `hifi_revio`).
그래서 "모델이 안 맞아서 나쁜 것 아니냐"가 자연스러운 의심인데, **DeepVariant가 그 의심을 배제한다** —
DeepVariant는 기기별 모델이 없어 19런 전부 같은 PACBIO 모델로 돌았는데도 같은 크기의 격차를 낸다
(0.9282·0.9646 대 나머지 0.9747~0.9973). 즉 데이터 쪽 차이다.

`HG002.PacBio_CCS_15kb`가 전체 최저(DV 0.9282 / CL 0.9130)이고 FP가 DV 49,962·CL 64,273으로
다른 런의 10~20배다. recall도 0.9458/0.9394로 같이 낮다 — 한쪽으로 치우친 게 아니라 양쪽이 나쁘다.

## Revio에서 Clair3가 지는 것은 모델 오배정이 아니다

| dsid | Clair3 모델 | INDEL DV | INDEL CL | 차 |
|---|---|---|---|---|
| HG002.PacBio_HiFi-Revio_20231031 | hifi_revio | 0.9913 | 0.9747 | +0.0166 |
| HG003.PacBio_HiFi-Revio_20231031 | hifi_revio | 0.9916 | 0.9785 | +0.0131 |
| HG004.PacBio_HiFi-Revio_20231031 | hifi_revio | 0.9920 | 0.9862 | +0.0058 |

세 런 다 `hifi_revio`를 제대로 받았다(`run_table.tsv` 6열). 그런데도 Clair3만 INDEL이 내려간다.
같은 caller가 Sequel II 12런에서는 DeepVariant와 동률이므로, **Clair3 v1.2.0의 `hifi_revio` 모델이
Revio INDEL에서 약하다**는 쪽이 남는 해석이다. DeepVariant는 Revio 3런에서 0.9913~0.9920으로
전 세대 통틀어 가장 촘촘하다.

**열린 질문**: 이게 모델 학습 데이터 문제인지, Revio 특유의 오류 프로파일인지는 이 데이터로 못 가른다.
HG008/HG009 Revio 런(germline truth 없음)이 많아 표본을 늘릴 방법도 지금은 없다.

## 실무 판정

- **PacBio HiFi 소변이 caller는 DeepVariant를 기본으로 둔다.** Sequel II에서는 차이가 없고
  Revio에서는 확실히 낫다. Clair3는 교차 확인용으로 유지한다(두 caller 합의는 여전히 쓸모 있다).
- **Sequel I 런(HG002 CCS_10kb·CCS_15kb)은 INDEL 비교에 넣지 않는다.** 넣으려면 세대를 명시해야 한다.
- **SNP 비교에는 19런을 다 써도 된다.**

## SV (Truvari 5.4.0 vs v5.0q)

HG002 5런, `--pick ac --passonly -r 2000 -C 5000` + refine. 전 런 exit 0.
truth `base cnt` 는 28,123 으로 같다. **refine 후 값으로 판정하고 bench 는 폭을 보는 용도다.**

| dsid | instr | comp cnt | TP-base | FP | FN | precision | recall | **F1** | refine 이득 |
|---|---|---|---|---|---|---|---|---|---|
| HiFi-Revio_20231031 | Revio | 20,636 | 22,147 | 1,980 | 5,976 | 0.9041 | 0.7875 | **0.8418** | +0.0543 |
| CCS_15kb_20kb_chemistry2 | Sequel II | 20,720 | 21,938 | 2,052 | 6,185 | 0.9010 | 0.7801 | **0.8362** | +0.0526 |
| CCS_15kb | **Sequel I** | 20,588 | 21,776 | 2,015 | 6,347 | 0.9021 | 0.7743 | **0.8333** | +0.0519 |
| SequelII_CCS_11kb | Sequel II | 20,608 | 21,558 | 2,084 | 6,565 | 0.8989 | 0.7666 | **0.8275** | +0.0499 |
| CCS_10kb | **Sequel I** | 20,500 | 21,282 | 2,117 | 6,841 | 0.8967 | 0.7567 | **0.8208** | +0.0489 |

### SV에는 세대 단조성이 없다 — 소변이와 다르다

**Sequel I 두 런이 Sequel II 두 런을 사이에 두고 갈라진다.** `CCS_15kb`(Sequel I)가 3위로
`SequelII_CCS_11kb`(Sequel II)보다 위다. 소변이 INDEL 에서는 세대가 깨끗하게 갈렸던 것과 다르다.

전체 폭도 2.1점(0.8208~0.8418)으로 좁다. **이 데이터로는 "Revio 가 SV 에서 낫다"까지만 말할 수
있고, Sequel I ↔ Sequel II 를 SV 로 가르지는 못한다.**

### 소변이 순위와 SV 순위가 뒤집힌다

| dsid | INDEL F1 (DV) | 5런 중 | SV F1 | 5런 중 |
|---|---|---|---|---|
| CCS_15kb_20kb_chemistry2 | 0.9973 | 1 | 0.8362 | 2 |
| SequelII_CCS_11kb | 0.9932 | 2 | 0.8275 | 4 |
| HiFi-Revio_20231031 | 0.9913 | 3 | 0.8418 | 1 |
| CCS_10kb | 0.9646 | 4 | 0.8208 | 5 |
| **CCS_15kb** | **0.9282** | **5** | **0.8333** | **3** |

`CCS_15kb` 는 소변이 INDEL 에서 **19런 전체 최하위**(FP 49,962 — 다른 런의 10~20배)인데
SV 에서는 5런 중 3위다. **두 지표가 같은 방향으로 움직이지 않는다.**

가설(미검증): Sequel I 에서 인서트를 15 kb 로 늘리면 분자당 CCS pass 수가 줄어 consensus 정확도가
떨어지고(→ INDEL 오류 증가), 대신 리드가 길어 SV 를 더 잘 걸친다(→ SV recall 증가). 같은 Sequel I
인 `CCS_10kb` 가 INDEL 은 낫고 SV 는 못한 것이 이 방향과 맞는다. **확인하려면 런별 CCS pass 수
분포(`np` 태그)를 봐야 하는데 아직 안 봤다.**

실무적으로: **런을 하나의 "품질" 축으로 줄 세우면 안 된다.** 소변이용으로 고를 때와 SV용으로
고를 때의 답이 다르다.

### refine 이득이 플랫폼을 가로질러 일정하다

+0.0489 ~ +0.0543 (5런). phase2 ONT 실측이 +4.8~5.1점이었다. 서로 다른 플랫폼·caller·데이터에서
같은 폭이 나오는 것은 이 이득이 **표현 정규화**라는 설명과 맞는다 — 콜 품질이 아니라 truth 와
call 의 표기 차이를 걷어내는 값이라면 데이터가 달라도 비슷해야 한다.

`--refine` 을 끄면 F1 이 0.77~0.79 로 내려간다. 켜는 게 맞고, GIAB v5.0q README 도 그렇게 지정한다.

### recall 이 약점이다

precision 은 0.897~0.904 로 고른데 recall 이 0.757~0.788 이다. pbsv 가 truth 28,123 개 중
21,282~22,147 개를 찾고 **5,976~6,841 개를 놓친다.** 잘못 부르는 게 아니라 못 찾는 것이다.

> recall 의 분자는 `TP-base`(정답 중 맞힌 수)이고 precision 의 분모는 `comp cnt`(우리가 부른 수)다.
> 둘을 섞으면 안 된다 — 초판에서 "약 20,600개를 찾는다"고 쓴 것이 `comp cnt` 를 잘못 쓴 것이었다
> (2026-09-22 PR #22 Codex 지적).
>
> `TP-base`(22,147)가 `TP-comp`(18,656)보다 큰 것도 여기서 온다. SV 매칭은 1:1이 아니어서
> 정답 여러 건이 우리 콜 한 건에 붙을 수 있다 — pbsv 가 truth 가 쪼개 적은 것을 합쳐 부른다는 뜻이다.

v5.0q 가 T2T-Q100 유래라 분절중복·위성 영역 SV 를 Tier1 v0.6 보다 훨씬 많이 담고 있어서 정렬 기반
caller 의 recall 이 구조적으로 낮게 나오는 것으로 **추정**한다 — 확인 안 했다. Tier1 시절 감각
(F1 0.95+)과 직접 비교하면 안 된다.

`gt_concordance` 는 bench 단계에서 0.816~0.822 다. refine 행에는 NA 로 나온다 —
truvari 가 `refine.variant_summary.json` 에 그 키를 안 낸다.

### ENOMEM 1건 — 스레드 설정 문제였다

`HG002.PacBio_CCS_15kb`(잡 156033)가 refine 중에 죽었다:

```
[SIMDMalloc] posix_memalign fail!
Size: 68719476736, Error: ENOMEM
```

68,719,476,736 = 정확히 64 GiB 한 방. `-t`를 `NSLOTS`(=22)로 넘기고 있었고, refine의 정렬기
abPOA는 스레드마다 정렬 행렬을 따로 잡아 **메모리가 스레드 수에 비례**한다. 실측이 그대로다 —
phase2가 `-t 8`에서 67~73 GB, phase1이 `-t 22`에서 177~192 GB.

22슬롯이면 64코어 노드에 2잡이 올라가는데 잡당 ~190 GB라 합계 380 GB로 251 GB를 넘는다.
로그 타임스탬프상 156032와 156033이 14:07:11~12에 둘 다 "Building haplotypes/Harmonizing"에
있었다 — 그 겹침에서 두 번째가 64 GiB를 못 잡았다. 나머지 3런은 시차를 두고 돌아 살아남았다.

**슬롯으로 동시 실행 수를 줄이려 한 것이 역효과였다.** 슬롯을 올리면 `-t`가 같이 올라
잡당 메모리가 커져서 노드 총량이 안 줄어든다. `BENCH_SV_THREADS`(기본 8)로 스레드를 고정하고
슬롯은 패킹에만 쓰도록 분리했다.

### 그런데 스레드를 줄여도 메모리가 비례해서 줄지는 않았다

`-t 8` 재실행의 maxvmem 을 같은 데이터셋끼리 짝지으면:

| dsid | `-t 22` | `-t 8` | 변화 |
|---|---|---|---|
| HiFi-Revio_20231031 | 192.6 GB | 136.2 GB | −29% |
| SequelII_CCS_11kb | 177.3 GB | 96.5 GB | −46% |
| CCS_15kb_20kb_chemistry2 | 188.1 GB | 121.0 GB | −36% |
| CCS_10kb | (미측정) | 91.6 GB | |
| CCS_15kb | (두 번 다 ENOMEM) | 99.5 GB | |

**스레드를 64% 줄였는데 메모리는 29~46%만 줄었다.** `base + k·threads` 로 풀면 base 가 50~104 GB 로
큰데, 이건 **가장 큰 영역 하나의 작업 공간**으로 보인다 — 스레드를 줄여도 그 한 방은 그대로다.
ENOMEM 때 실패한 할당이 정확히 64 GiB 한 방이었던 것과 맞아떨어진다.

초판에서 "메모리가 스레드에 비례한다"고 적은 것은 **phase2 ONT(`-t 8`)와 phase1 HiFi(`-t 22`)를
비교한 것이라 데이터셋 차이가 섞여 있었다.** 위 표가 같은 입력으로 스레드만 바꾼 대조다.

실질적 결론: **제어 수단은 스레드가 아니라 동시 실행 수다.** `BENCH_SV_SLOTS` 를 33으로 올려
노드당 1잡으로 두었다 — 22슬롯(2잡)이면 최악 136+121 = 257 GB 로 251 GB 를 넘는다. 2026-09-22
재실행이 살아남은 것은 피크가 안 겹쳤기 때문이지 안전해서가 아니다. 5런을 순차로 돌려도 20분이다.

데이터셋 차이도 크다 — 같은 `-t 8` 에서 ONT 67~73 GB 대 HiFi 91.6~136.2 GB 다. 한쪽 실측을
다른 쪽에 그대로 쓰면 안 된다.

죽은 잡은 `set -e`로 끝나지 않고 SGE에서 계속 `r` 상태로 22슬롯을 붙잡고 있었다(abPOA가
malloc 실패를 찍고도 abort하지 않은 것으로 보인다). `qdel`로 정리했다. **같은 일이 두 번 났고**
(156033, 156038 — 둘 다 이 데이터셋), 판별 지문은 `qstat -j` 의 `cpu=` 가 멈추고 `vmem` 이
`maxvmem` 보다 한참 낮은 것이다(3.2G 대 149G). `qacct` 에는 기록조차 없다 — 종료하지 않았으니까.
스레드 원인과 별개로 `BENCH_SV_TIMEOUT`(기본 4h) 워치독을 넣어 멎은 잡이 슬롯을 영원히 물지
않게 했다.

**`CCS_15kb`가 소변이에서도 최악이었다**(INDEL F1 0.9282, FP 49,962 — 다른 런의 10~20배).
SV에서도 두 번 다 이 런만 죽었다. 다만 `-t 8` 로는 99.5 GB 로 무사히 끝났고, 그 값이 5런 중
중간이다 — **이 데이터가 유별나게 무거운 것은 아니었다.** 22슬롯 2잡 환경에서 하필 이 런이
겹침의 두 번째였을 가능성이 크다(1차·2차 모두 제출 순서상 두 번째였다). 소변이 쪽 이상값과
이어지는 원인인지는 이 데이터로는 못 가른다.

## 재현

```bash
bash phase1_pacbio_hifi/scripts/60_benchmark.sh --collect
awk -F'\t' 'NR==1 || $6=="PASS"' phase1_pacbio_hifi/phase1_bench_summary.tsv | column -t -s$'\t'
bash phase1_pacbio_hifi/scripts/61_benchmark_sv.sh --list
bash phase1_pacbio_hifi/scripts/61_benchmark_sv.sh --collect
```
