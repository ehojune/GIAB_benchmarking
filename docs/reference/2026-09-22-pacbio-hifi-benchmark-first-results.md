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

## 재현

```bash
bash phase1_pacbio_hifi/scripts/60_benchmark.sh --collect
awk -F'\t' 'NR==1 || $6=="PASS"' phase1_pacbio_hifi/phase1_bench_summary.tsv | column -t -s$'\t'
bash phase1_pacbio_hifi/scripts/61_benchmark_sv.sh --list   # 세대 라벨 확인
```
