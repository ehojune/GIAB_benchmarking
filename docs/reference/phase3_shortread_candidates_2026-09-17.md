# phase3 숏리드 후보 전수와 근거 (2026-09-17, 조회용)

업체(gd001~004) 산출물 ↔ GIAB raw 비교의 arm B를 고르기 위해 HG002/3/4 숏리드 DNA raw FASTQ를 전부 훑은 기록. 결론은
[docs/decisions.md](../decisions.md) 2026-09-17 항목, 실행 목록은 [phase3_shortread_wgs/](../../phase3_shortread_wgs/).

## 1. GIAB FTP 안 (카탈로그·매니페스트 실측)

`giab.s3.amazonaws.com` 디렉토리 목록(2026-09-17)으로 HG002/3/4의 숏리드 WGS FASTQ 디렉토리가 아래 8종뿐임을 재확인했다.
S3 미러에는 FTP에 있는 `Element_AVITI_20240920`가 없다(미러 불일치, 알려진 문제).

| 데이터셋 | 샘플 | 장비 / 리드 | 라이브러리 | 깊이 | GiB | GIAB 처리물 | 판정 |
|---|---|---|---|---|---|---|---|
| NIST_HiSeq_*_Homogeneity | 2/3/4 | HiSeq 2500 Rapid v1, 2x148 | TruSeq PCR-free, 550 bp, 12 lib(6 vial×2) | 300x (lib A~D ≈12x, F/L ≈50x) | 774/787/907 | novoalign BAM, BaseSpace BWA VCF | 유지 — 깊이 상한 실험 |
| NIST_Illumina_2x250bps | 2/3/4 | HiSeq 2500 Rapid v2, 2x250 | TruSeq PCR-free, ~350 bp (DISCOVAR용) | ~40-50x | 163/144/161 | novoalign BAM | 후순위 — 리드 길이 |
| Illumina_PCRfree_downsampled | 2 (3/4는 HPRC) | HiSeq 2500, 2x148 | 위 300x의 서브샘플 | ~30x | 83 (+87/83) | 없음 | **채택** |
| BGISEQ500 | 2/3/4 | BGISEQ-500, **PE100**(헤더 실측) | PCR-free | 추정 ~80x | 208/217/210 | 없음 | 후순위 — 리드 길이 |
| MGISEQ/PCR-free | 2/3/4 | MGISEQ-2000, 2x150(헤더 실측) | PCR-free | 추정 ~73/67/127x | 186/178/354 | 없음 | 조건부 — 업체에 MGI가 있으면 |
| NIST_BGIseq_2x150bp_100x | 2 | DNBSEQ V350, 2x150 | 미문서 | 100x(문서) / 추정 111x | 324 | bwa→GATK BAM | 조건부(HG002만) |
| Element_AVITI_20240920 | 2/3/4 | AVITI Cloudbreak UltraQ, 2x150 | PCR-free, Std 350-400 bp + Lng ~1300 bp, DNA=NIST RM 8392 | Std ~80x + Lng 32-38x | 236/231/251 | BWA-MEM BAM | 후순위 — 플랫폼 다양성 |
| Element_AVITI_20231018 | 2 | AVITI R&D 시약, 2x150 | Std + Lng | 81x + 55x | 269 | BWA-MEM BAM ×3 ref | 제외 — 20240920로 대체 |

제외(라이브러리 특수): 6kb mate-pair, Moleculo, 10X Chromium, stLFR, Hi-C, Strand-seq, Dovetail, 엑솜(BAM only), Complete Genomics, SOLiD.

깊이 추정법: 각 read-1 파일 앞 4 MB를 range 요청으로 받아 bases/압축바이트 비를 구하고 파일 크기에 곱했다. 문서상 100x인 NIST_BGIseq에서 111x가 나와 오차 ±15% 수준.

## 2. GIAB FTP 밖

| 출처 | 내용 | 접근 | 비고 |
|---|---|---|---|
| Google `gs://brain-genomics-public/research/sequencing/fastq/novaseq/wgs_pcr_free/{20x,30x,40x,50x}/` | HG001~HG007, NA12891/2 NovaSeq 6000 PCR-free 2x151 | HTTPS 익명, md5Hash | **30x 트리오 채택**. 헤더 `A00744:46:HV3C3DSXX:2`, 샘플별 듀얼 인덱스 |
| 같은 버킷 `hiseqx/wgs_pcr_free|wgs_pcr_plus/{20x,30x,40x}/` | HG002/3/4 HiSeq X 2x150 PCR-free·**PCR-plus** | HTTPS 익명 | 업체가 PCR-plus면 대조군 후보 |
| 같은 버킷 `novaseqx/` | HG002만: NovaSeq 6000 10~60x(같은 런 HV3C3DSXX), NovaSeq X 10~40x + 전체(SRR37356338 재배포, 헤더 `pi1-04:533:22JTGYLT4`, 2x150) | HTTPS 익명, md5 | **업체 화학(XLEAP-SBS) 맞춘 HG002 대조군 후보**. 30x: R1 22,344,558,277 B md5 c9a66aaa3b932ead2c4750726a475a32 / R2 22,168,774,900 B md5 1d2ca0d3803ed2dcbf574710119eaef8. 전체: R1 32,312,362,334 B 72ef3765…, R2 32,058,778,610 B 254ca0dc… |
| ENA PRJNA1427896 (Weill Cornell, 2026-03) | HG002만: NovaSeq X 25B 3런(SRR37356337/8/9, 각 129~133 Gb ≈ 42x, 2x150) + UG100 5런 | ENA FTP | 트리오 아님. 업체 플랫폼(NovaSeq X/X Plus)과 같은 계열 |
| HPRC `s3://human-pangenomics/working/HPRC_PLUS/HG002/raw_data/Illumina/parents/HG00{3,4}/` | HG003/4 HiSeq30x_subsampled (GIAB README가 가리킴). `child/`에는 HG002 HiSeq30x + NovaSeq 30x 사본 | HTTPS 익명, ETag 멀티파트 | **채택**. 헤더 `HISEQ1:30:HA0L6ADXX`, `HISEQ1:46:HA5R5ADXX` = 300x 플로우셀 |
| 같은 버킷 `NHGRI_UCSC_panel/HG002/hpp_HG002_NA24385_son_v1/` | 위와 같은 파일의 다른 경로 | | 구 경로 `HG002/hpp_HG002_NA24385_son_v1/ILMN/`(GIAB README 링크)는 비어 있다 |

업체 플랫폼(2026-09-17 사용자 전달): 4곳 모두 Illumina NovaSeq X / X Plus (업체 FASTQ 기기ID `LH00xxx`). 공개 NovaSeq X 트리오는 위 어디에도 없다.

## 3. 다운로드 전 검증 실측 (2026-09-17)

| 파일 | Content-Length | md5 / ETag | 앞 표본 헤더 | 리드 길이 |
|---|---|---|---|---|
| HG002.novaseq.pcr-free.30x.R1/R2 | 25,664,092,287 / 26,634,286,830 | 53a0e35f… / 387b1cf1… | @A00744:46:HV3C3DSXX:2 … NGCGATAG+NGGCGAAG | 151 |
| HG003.novaseq.pcr-free.30x.R1/R2 | 25,952,362,473 / 27,035,921,150 | 6919a25c… / b5bcc32b… | 인덱스 NGCGATAG+NAATCTTA | 151 |
| HG004.novaseq.pcr-free.30x.R1/R2 | 25,963,733,907 / 26,885,537,878 | 5be03cb2… / 29979889… | 인덱스 NGCGATAG+NAGGACGT | 151 |
| HG003_HiSeq30x_subsampled_R1/R2 | 45,137,067,184 / 48,000,175,473 | ETag …-673 / …-716 (멀티파트) | @HISEQ1:30:HA0L6ADXX:1 … TGACCA | 148 |
| HG004_HiSeq30x_subsampled_R1/R2 | 43,104,576,071 / 46,282,363,431 | ETag …-643 / …-690 (멀티파트) | @HISEQ1:46:HA5R5ADXX:1 … CGATGT | 148 |

md5 전문은 [phase3_shortread_wgs/ext_manifest.tsv](../../phase3_shortread_wgs/ext_manifest.tsv). 사용자 결정으로 검증은 여기까지(비용). 다운로드 후 `02_fetch_external_reads.sh`가 크기·md5·리드 길이를 다시 본다.

## 4. 외부 자문 기록

같은 질문(후보 9종, 목적, 제약)을 두 모델에 독립적으로 물었다. 서로의 답은 보여주지 않았다.

**Codex `gpt-5.6-sol`** (2026-09-17, codex exec, effort high)
- MUST: Google NovaSeq 30x 트리오; HiSeq 30x 서브샘플 트리오(HG003/4 확보). 조건부 MUST: HiSeq X PCR-plus/PCR-free(업체가 PCR-plus면), MGISEQ2000(MGI 업체면, 리드 길이·깊이·PCR 먼저 확인), NIST_BGIseq 100x→30x.
- SHOULD: 300x 전량(포화·read group 실험으로, 기준 arm 아님), AVITI 20240920(Std/Lng 따로), 2x250(리드 길이 민감도). SKIP: BGISEQ500, AVITI 20231018.
- 혼란변수: 1차 비교를 "업체 FASTQ vs NovaSeq PCR-free 30x, 샘플별"로 미리 선언. PCR 여부로 층화. 매핑·오토좀 깊이를 맞춘 비교를 주, 원 깊이는 부. read group·라이브러리 provenance 유지, 중복률·라이브러리 복잡도 보고. A↔B 일치도를 정확도로 취급하지 말고 각각 정답셋에 대조.
- 300x는 스케일·포화·난영역 근거는 주지만 30x 업체 비교엔 기여가 적다. 최선의 프로덕션 대조군은 Google NovaSeq 30x, 최선의 깊이 실험은 300x에서 pair 보존·결정적·라이브러리 비례 서브샘플.
- 간과 가능: 샘플 정체성·오염·FASTQ 무결성·어댑터·달성 깊이 사전 확인, v4.2.1과 CMRG 지표 분리 보고, 공개 데이터가 정답셋 구축에 쓰였는지(독립성) 확인.

**Gemini `gemini-3.1-pro-high`** (2026-09-17, agyq)
- MUST: Google NovaSeq 30x; MGI(NIST_BGIseq 100x→30x, MGISEQ2000). SHOULD: HiSeq 30x 서브샘플. SKIP: 300x(깊이·12 라이브러리가 비교를 왜곡), 2x250, BGISEQ500(PE100), AVITI.
- 300x 전량 실행(09-09)을 취소하라고 권고. 모든 공개 데이터를 업체 목표 깊이(~30x)로 맞춰라. 같은 참조(GRCh38 no-alt)를 A/B에 쓸 것.

**갈린 점과 선택**: 300x를 Gemini는 제외, Codex는 별도 실험으로 유지. 이미 내린 사용자 결정(전량)을 존중하되 역할을 "깊이 상한"으로 바꾸는 Codex 쪽을 택했다.
**둘 다**: NovaSeq 30x 트리오가 1순위, 깊이 매칭이 핵심 혼란변수.

Fable 워크플로(외부 후보 추가 탐색 3 + 검증 + 비판 2)는 탐색 단계에서 사용자 지시로 중단했다(비용). 결과 없음.
