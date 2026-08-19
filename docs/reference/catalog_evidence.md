# 카탈로그 분류 근거 (조회용)

[master_catalog.tsv](../../catalog/master_catalog.tsv)의 각 값이 어떻게 정해졌는지, 그리고
검증 단계에서 무엇이 잡혔는지 기록. 읽을 필요는 없고 특정 값을 의심할 때 찾아보는 문서다.

## 방법

| 값의 종류 | 근거 | 검증 |
|---|---|---|
| 파일 개수, 바이트, index 존재, 파일 종류 | `phase0_download/manifests/` 76,595행 스크립트 집계 | 330개 prefix가 전체를 덮고 미매칭 0건임을 재계산 |
| 처리 단계 (정렬/페이징/변이/메틸/somatic/어셈블리) | 파일명·디렉토리명 토큰 | 카테고리별 독립 검증 에이전트가 파일 존재로 대조 |
| 툴 이름·버전 | GIAB 공식 README 514개 본문 | 인용 검증 에이전트가 원문에서 문장·버전 재확인 |
| 장비/화학 | PacBio movie 접두어(m84/m64/m54/m14·m15), 시퀀서 모델명, 공식 문서 | 동일 |

공식 문서는 `https://s3.amazonaws.com/giab/<path>`와 NCBI FTP에서 직접 수집했다 (514개 전부, 3.9 MB).
파일명에도 없고 문서에도 없는 툴은 `N/A`로 남겼다. 상식 추론으로 채우지 않았다.

## 1차 분류 검증 (카테고리별)

| 버킷 | 분류한 데이터셋 | 검증에서 수정 | 검증이 찾아낸 누락 |
|---|---|---|---|
| pacbio | 36 | 2 | 2 |
| ont | 18 | 5 | 0 |
| illumina_wgs | 28 | 11 | 0 |
| short_targeted | 27 | 2 | 0 |
| linked_cg | 27 | 5 | 5 |
| other | 107 | 11 | 0 |
| release_rna_trio | 87 | 20 | 0 |
| **합계** | **330** | **56** | **7** |

### 검증에서 잡힌 주요 오류

**pacbio**

- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb_20kb_chemistry2` — tools: `["pbmm2", "duplomap"]` → `["pbmm2", "duplomap", "RTG"]`
  - 근거: data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb_20kb_chemistry2/GRCh37/HG002.SequelII.merged_15kb_20kb.pbmm2.hs37d5.haplotag.RTG.10x.trio.bam — 'RTG'가 '.'로 구분된 토큰으로 존재. 같은 근거
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_CCS_15kb_20kb_chemistry2` — tools: `["pbmm2", "deepvariant", "gatk", "RTG"]` → `["pbmm2", "deepvariant", "gatk", "RTG", "ccs"]`
  - 근거: data/AshkenazimTrio/HG003_NA24149_father/PacBio_CCS_15kb_20kb_chemistry2/reads/PBmixSequel729_1_A01_PBTH_30hours_19kbV2PD_70pM_HumanHG003.ccs_report.txt (총 6개) — 'ccs'가 '.'와 '_' 경계

**ont**

- `data_somatic/HG008/Liss_lab/other_passages/BCM_ONT-std_HG008T-p2_20260313` — platform: `PromethION (MinKNOW 런 디렉토리 위치 1C/1D, PBI 플로우셀 2장)` → `ONT (기기·케미스트리 미표기; 런 디렉토리 20260202_1137_1C_PBI63802_5301c73c / 2026020`
  - 근거: 이 prefix 아래 1097개 파일 전체에 Promethion/prom/minion/R10/R1041/dorado/guppy/5mC 토큰이 0건. ONT 카테고리 전체의 'Promethion' 토큰 89건은 모두 data/*/UCSC_Ultralong_OxfordNanopore_Promethion/ 디렉토리(HG002 
- `data/AshkenazimTrio/HG002_NA24385_son/CORNELL_Oxford_Nanopore` — platform: `MinION 2D 케미스트리 (파일명 oxford_PC_...ch#_file#_strand.fast5)` → `ONT 2D 케미스트리 (기기명 미표기; 파일명 토큰은 2D뿐, fast5 채널 ch1~ch510)`
  - 근거: ONT 카테고리 전체에서 'minion' 토큰은 5건이고 전부 HG001 파일(data/NA12878/Ultralong_OxfordNanopore/NA12878-minion-ul_GRCh37.bam 등). CORNELL prefix 아래 2915파일에는 minion/MinION 토큰 0건. 근거로 든 파일명 data/As
- `data_somatic/HG008/Liss_lab/other_passages/BCM_ONT-std_HG008T-p2_20260313` — stages / deepest_stage: `["reads","align"] / align (notes: ".ht.cram은 haplotagged로 읽히지만 근거가 2글자` → `stages에 phase 추가(deepest_stage=phase). 또는 ht를 근거 부족으로 본다면 combined_201`
  - 근거: 토큰 분해(/ . _ -) 결과 'ht'는 독립 토큰 2건 — data_somatic/HG008/Liss_lab/other_passages/BCM_ONT-std_HG008T-p2_20260313/HG008T-p2_ONT-std_100X_GRCh38-GIABv3.ht.cram 와 .ht.cram.crai. 반면 phase로
- `data_somatic/HG008/Liss_lab/UCSC_ONT_20231003` — platform: `ONT R10.4.1 standard (PromethION 급, 기기명 미표기)` → `ONT R10.4.1 standard (기기명 미표기)`
  - 근거: 'PromethION 급'은 파일명 근거가 없음. 이 prefix의 11파일에 prom/Promethion 토큰 0건 — data_somatic/HG008/Liss_lab/UCSC_ONT_20231003/HG008-T_UCSC_20230905_ONT-std-R10.4.1_1_dorado_v0.3.4_sup4.2.0_5mC
- `data_somatic/HG008/Liss_lab/Northeastern-ONT-UL-20241216` — notes: `UCSC ONT-UL과 같은 종양 샘플의 재-basecall(dorado 0.8.1) 릴리스` → `HG008-T ONT-UL의 별도 릴리스(런 ID 11_12_2024). 같은 데이터의 재-basecall인지는 파일명으로 알`
  - 근거: unaligned BAM 런 ID가 서로 다름 — data_somatic/HG008/Liss_lab/Northeastern-ONT-UL-20241216/11_12_2024_R1041_HG008_3066.dorado_0.8.1_sup.5mC_5hmC.bam 대 data_somatic/HG008/Liss_lab/UCSC_ON

**illumina_wgs**

- `data/AshkenazimTrio/HG002_NA24385_son/NIST_HiSeq_HG002_Homogeneity-10953946` — contents: `HG002Run01/Run02 두 개 BaseSpace 재시퀀싱 결과(BAM+vcf+genome.vcf.gz+CNV.vcf+S` → `Run01은 SV.vcf 포함, Run02는 SV.vcf 없음. Run02 세트 = BAM+vcf+genome.vcf.gz+C`
  - 근거: data/AshkenazimTrio/HG002_NA24385_son/NIST_HiSeq_HG002_Homogeneity-10953946/HG002Run01-11419412/HG002run1_S1.SV.vcf 는 존재하나 HG002Run02-11611685/ 아래에는 .SV.vcf 파일이 없음. 두 디렉토리 diff 결과 
- `data/NA12878/NIST_NA12878_HG001_HiSeq_300x` — contents: `novoalign BAM 4개(2 레퍼런스)` → `novoalign BAM 2개(레퍼런스 2종 각 1개). 나머지 2개는 .bam.bai 인덱스`
  - 근거: data/NA12878/NIST_NA12878_HG001_HiSeq_300x/NHGRI_Illumina300X_novoalign_bams/ 아래 .bam은 HG001.GRCh38_full_plus_hs38d1_analysis_set_minus_alts.300x.bam, HG001.hs37d5.300x.bam 2개뿐이고 나
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_HiSeq_HG002_Homogeneity-10953946` — contents: `novoalign BAM 12개` → `novoalign BAM 6개(레퍼런스 2종 x 300x / 300x_chr20 / 60x.1). 나머지 6개는 .bam.ba`
  - 근거: NHGRI_Illumina300X_AJtrio_novoalign_bams/ 아래 .bam = HG002.GRCh38.300x.bam, HG002.GRCh38.300x_chr20.bam, HG002.GRCh38.60x.1.bam, HG002.hs37d5.300x.bam, HG002.hs37d5.300x_chr20.bam, 
- `data/AshkenazimTrio/HG003_NA24149_father/NIST_HiSeq_HG003_Homogeneity-12389378` — contents: `novoalign BAM 8개` → `novoalign BAM 4개(레퍼런스 2종 x 300x / 60x.1). chr20 서브셋은 HG003에 없음`
  - 근거: NHGRI_Illumina300X_AJtrio_novoalign_bams/HG003.GRCh38.300x.bam, HG003.GRCh38.60x.1.bam, HG003.hs37d5.300x.bam, HG003.hs37d5.60x.1.bam 이 전부이고 나머지 4개는 .bam.bai
- `data/AshkenazimTrio/HG004_NA24143_mother/NIST_HiSeq_HG004_Homogeneity-14572558` — contents: `novoalign BAM 8개` → `novoalign BAM 4개(레퍼런스 2종 x 300x / 60x.1)`
  - 근거: NHGRI_Illumina300X_AJtrio_novoalign_bams/HG004.GRCh38.300x.bam, HG004.GRCh38.60x.1.bam, HG004.hs37d5.300x.bam, HG004.hs37d5.60x.1.bam + .bai 4개
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps` — contents: `novoalign_bams/에 BAM 4개(2 레퍼런스)` → `novoalign BAM 2개(GRCh38, hs37d5) + .bam.bai 2개`
  - 근거: data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/novoalign_bams/HG002.GRCh38.2x250.bam, HG002.hs37d5.2x250.bam
- `data/AshkenazimTrio/HG003_NA24149_father/NIST_Illumina_2x250bps` — contents: `novoalign_bams/에 BAM 4개(2 레퍼런스)` → `novoalign BAM 2개(GRCh38, hs37d5) + .bam.bai 2개`
  - 근거: data/AshkenazimTrio/HG003_NA24149_father/NIST_Illumina_2x250bps/novoalign_bams/HG003.GRCh38.2x250.bam, HG003.hs37d5.2x250.bam
- `data/AshkenazimTrio/HG004_NA24143_mother/NIST_Illumina_2x250bps` — contents: `novoalign_bams/에 BAM 4개` → `novoalign BAM 2개(GRCh38, hs37d5) + .bam.bai 2개`
  - 근거: data/AshkenazimTrio/HG004_NA24143_mother/NIST_Illumina_2x250bps/novoalign_bams/HG004.GRCh38.2x250.bam, HG004.hs37d5.2x250.bam
- `data/ChineseTrio/HG005_NA24631_son/HG005_NA24631_son_HiSeq_300x` — contents: `novoalign BAM 4개` → `novoalign BAM 2개(GRCh38_full_plus_hs38d1_analysis_set_minus_alts 300x,`
  - 근거: NHGRI_Illumina300X_Chinesetrio_novoalign_bams/HG005.GRCh38_full_plus_hs38d1_analysis_set_minus_alts.300x.bam, HG005.hs37d5.300x.bam + .bai 2개 + README = 5파일
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/NA24694_Father_HiSeq100x` — contents: `NHGRI_Illumina100X_Chinesetrio_novoalign_bams에 BAM 4개` → `novoalign BAM 2개(GRCh38_full_plus_hs38d1_analysis_set_minus_alts 100x,`
  - 근거: NHGRI_Illumina100X_Chinesetrio_novoalign_bams/HG006.GRCh38_full_plus_hs38d1_analysis_set_minus_alts.100x.bam, HG006.hs37d5.100x.bam + .bai 2개 + README = 5파일
- … 외 1건

**short_targeted**

- `data/NA12878/BGISEQ500` — platform: `BGISEQ500 (PCR-free 2x100, standard_library는 PE50/PE100)` → `BGISEQ500 (PCR-free, standard_library에 PE50/PE100 표기)`
  - 근거: data/NA12878/BGISEQ500/BGISEQ500_PCRfree_NA12878_CL100076243_L01_read_1.fq.gz — 파일명에 리드 길이 표기가 전혀 없음. 248개 basename을 '.', '_', '-' 경계로 전수 집계했더니 '2x100' 토큰은 0건이고 2x150(8건, NIST_BGIs
- `data/NA12878/BGISEQ500` — contents: `... + md5·readme 5개. 총 19파일` → `... + md5·readme 4개. 총 19파일`
  - 근거: standard_library에서 리드/BAM이 아닌 파일은 md5.txt, md5_bam.txt, md5_pe50.txt, readme.txt 4개뿐(data/NA12878/BGISEQ500/standard_library/md5.txt, md5_bam.txt, md5_pe50.txt, readme.txt). 적어놓은 부

**linked_cg**

- `data/NA12878/CompleteGenomics_normal_RMDNA` — stages: `["reads", "align"]` → `["raw", "align"] — deepest_stage "align"은 그대로. 동일 수정이 CG 네이티브 7행 전체에 적`
  - 근거: data/NA12878/CompleteGenomics_normal_RMDNA/GS000025639-ASM/EXP/GS02256-DNA_A01/MAP/GS69437-FS3-L08/reads_GS69437-FS3-L08_001.tsv.bz2 (FASTQ/BAM/FASTA 아닌 CG 네이티브 리드) + 같은 prefix의 da
- `data/NA12878/10XGenomics` — platform: `10X Chromium` → `10X Genomics (Chromium 미표기) — 또는 규칙 6대로 '미표기'. 같은 문제가 4행에 적용: data/NA1`
  - 근거: data/NA12878/10XGenomics/NA12878_phased_possorted_bam.bam, data/NA12878/10XGenomics/10XGenomics_sizeselected/README_NISTStanford_10XSizeSelected_NA12878.txt, data/AshkenazimTrio/HG
- `data/NA12878/CompleteGenomics_normal/BAM` — tools: `["teramap", "CGI"]` → `["teramap"] — CGI는 Complete Genomics Inc. 벤더 표기로 platform 필드('Complete`
  - 근거: data/NA12878/CompleteGenomics_normal/BAM/NA12878.chrom1.CGI.teramap.CEU.high_coverage.20120417.bam
- `data/AshkenazimTrio/HG002_NA24385_son/CompleteGenomics_normal_RMDNA` — notes: `chr1~22·X·Y·M 25개 BAM으로 HG001과 달리 chrY 포함` → `HG001 RMDNA도 정렬 BAM에 chrY가 있어 두 샘플의 매핑 BAM 염색체 집합은 chr1~22·X·Y·M 25개로 `
  - 근거: data/NA12878/CompleteGenomics_normal_RMDNA/BAM/mapping_sorted_chrY_mapHeader3.bam (HG001 chrY 존재) / data/NA12878/CompleteGenomics_normal_RMDNA/BAM/mapping_sorted_chr1_corrected_map
- `data/NA12878/CompleteGenomics_normal/BAM` — contents: `chrom1~22, chromX, chromM 24개에 대해 — 48파일` → `chrom1~22, chromX, chromMT 24개에 대해 — 48파일. 미토콘드리아 토큰이 chromM이 아니라 chro`
  - 근거: data/NA12878/CompleteGenomics_normal/BAM/NA12878.chromMT.CGI.teramap.CEU.high_coverage.20120417.bam

**other**

- `data/AshkenazimTrio/HG002_NA24385_son/BioNano` — coverage_check / prefix: `3216 files total, 3216 covered, 0 uncovered, 0 overlapping` → `경로 컴포넌트 매칭에서는 0 overlapping이 맞지만, 단순 문자열 startswith로 계산하면 265개 파일이 두 p`
  - 근거: data/AshkenazimTrio/HG003_NA24149_father/BioNano_DLE/BNG_HG003.README.txt 는 prefix 'data/AshkenazimTrio/HG003_NA24149_father/BioNano' 로도 startswith 매칭됨 (HG004 동일, HG002는 BioNano_DL
- `data_somatic/HG008/Liss_lab/analysis/Verkko_assemblies_05162024` — tools: `["Verkko", "herro"]` → `["Verkko", "herro", "bwa"] — bwa가 파일명에 밑줄/점 경계 토큰으로 8회 등장. 에이전트의 전역 어휘`
  - 근거: data_somatic/HG008/Liss_lab/analysis/Verkko_assemblies_05162024/HG008T/HG008T_verkko_v2.2/8-hicPipeline/index_bwa.sh (동일 디렉토리에 transform_bwa.sh, mergeBWA.sh, scaffold_mergeBWA.sh 및
- `data_somatic/HG008/Liss_lab/Bioskryb_ResolveDNA_20230914` — deepest_stage: `derived` → `reads — 이 결과에서 'derived'가 deepest_stage인 나머지 14개 행은 모두 stages가 [derive`
  - 근거: data_somatic/HG008/Liss_lab/Bioskryb_ResolveDNA_20230914/HG008-T_Bioskryb_120cells_QC1X_fastqs.tar.gz (reads) + .../091423_Bioskryb_Final_Report.pdf (derived) vs data_somatic/HG008
- `data_somatic/HG008/Liss_lab/analysis/BCM_Revio_20240313` — stages: `["phase","variant","meth","somatic","derived"]` → `align 추가. 파일명에 'aligned'가 명시된 레퍼런스 정렬 BAM이 3개 레퍼런스마다 normal/tumor 2개씩 `
  - 근거: data_somatic/HG008/Liss_lab/analysis/BCM_Revio_20240313/pacbio-wgs-wdl_somatic_20240601/GRCh38-GIABv3/HG008.normal.aligned.hiphase.bam
- `data/NA12878/analysis/PacBio_CCS_15kb_20kb_chemistry2_042021` — stages: `["phase","variant","derived"]` → `align 추가. haplotagged BAM은 레퍼런스(GRCh38, hs37d5)에 정렬된 BAM이므로 align도 성립.`
  - 근거: data/NA12878/analysis/PacBio_CCS_15kb_20kb_chemistry2_042021/HG001.GRCh38.haplotagged.bam
- `data_somatic/HG008/Liss_lab/other_passages` — contents: `5mC/5hmC/combined bedMethyl 8개+tbi` → `bedMethyl 6개(+tbi 6개). 5mC/5hmC/combined 각각 normal·tumor 1개씩`
  - 근거: analysis/GRCh38/BCM_ONT-std_HG008T-p2_20260313/HG008-T_vs_HG008-N-P/methylation/ 하위 *.bedmethyl.gz 는 HG008T-p2.5hmC.normal / 5hmC.tumor / 5mC.normal / 5mC.tumor / combined.normal /
- `data_somatic/HG008/Liss_lab/analysis/NIH_HiFi_Severus-SV_20240308` — contents: `severus 플롯 HTML 33개` → `34개 (all_SVs/plots 24개 + somatic_SVs/plots 10개). 또한 breakpoints_double`
  - 근거: data_somatic/HG008/Liss_lab/analysis/NIH_HiFi_Severus-SV_20240308/all_SVs/plots/severus_31.html ~ somatic_SVs/plots/severus_9.html (경로에 '/plots/severus_' 포함 파일 34개), .../breakpoint
- `data/NA12878/analysis/CompleteGenomics_RMDNA_11272014` — contents: `REF coverageRefScore chr별 33` → `24 (chr1~chr22, chrM, chrX). EVIDENCE는 correlation 1 + evidenceDnbs 24`
  - 근거: data/NA12878/analysis/CompleteGenomics_RMDNA_11272014/ASM/REF/ 하위 coverageRefScore-*.tsv.bz2 는 24개 (chr1..chr22, chrM, chrX)
- `data/AshkenazimTrio/HG003_NA24149_father/BioNano_DLE` — contents / notes: `alignmolvref contig별 xmap/q/r 약 100개 … 반복 약 40 contig` → `contig 24개, alignmolvref_contig* 파일 72개(+merge 2개). HG004 BioNano_DLE도`
  - 근거: data/AshkenazimTrio/HG003_NA24149_father/BioNano_DLE/HG003_pipeline_results/contigs/alignmolvref/merge/alignmolvref_contig{N}.xmap|_q.cmap|_r.cmap — 파일 72개, 서로 다른 contig 번호 24개
- `data_somatic/HG008/Liss_lab/analysis/BCM_Revio_20240313` — contents: `3개 레퍼런스별 … DMR TSV 7종` → `DMR TSV 7종은 CHM13v2.0과 GRCh38-GIABv3에만 있고 GRCh37에는 없음. GRCh37 하위에는 hip`
  - 근거: data_somatic/HG008/Liss_lab/analysis/BCM_Revio_20240313/pacbio-wgs-wdl_somatic_20240601/GRCh37/ 하위 12개 파일에 HG008_dmr_annotation_summary.tsv.gz / HG008_hg38_genes_*_dmrs.tsv.gz 가 없음
- … 외 1건

**release_rna_trio**

- `release/genome-stratifications/v3.0` — tools: `TRGT 포함 (v3.0~v3.5 6개 행 전부)` → `TRGT 삭제. 매니페스트 전체에서 trgt 문자열이 나오는 파일은 ComplexVar_in_TRgt100 계열 8건뿐이고 이`
  - 근거: release/genome-stratifications/v3.0/GRCh37/GenomeSpecific/GRCh37_HG002_hifiasmv0.11_ComplexVar_in_TRgt100.bed.gz (토큰 경계 매칭 0건, 부분 문자열만 2건)
- `data/AshkenazimTrio/analysis/PacBio_HiFi-Revio_20231031` — stages: `[variant, phase, derived]` → `phase 삭제 → [variant, derived]. 이 prefix 아래 BAM/CRAM은 0건이다. stage 어휘가 p`
  - 근거: data/AshkenazimTrio/analysis/PacBio_HiFi-Revio_20231031/pacbio-wgs-wdl_germline_20231031/HG002.GRCh38.deepvariant.phased.vcf.gz — 95개 파일 중 .bam/.cram 0건
- `release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1` — stages: `[benchmark, variant, phase]` → `phase 삭제. BAM 0건이다. 같은 문제가 release/NA12878_HG001/NISTv4.2.1, release/N`
  - 근거: release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/SupplementaryFiles/HG002_NA24385_GRCh38_1_22_v4.2_benchmark_phased_StrandSeq_whatshap.vcf.gz — prefix 아래 실데이터 49건 중 .bam 
- `release/AshkenazimTrio/HG003_NA24149_father/NISTv3.2.2` — platform: `Illumina + CG + Ion + SOLiD 통합` → `Illumina + CG + Ion (SOLiD 삭제). 콜셋 이름이 IllFB-IllGATKHC-CG-Ion이고 이 pref`
  - 근거: release/AshkenazimTrio/HG003_NA24149_father/NISTv3.2.2/HG003_GIAB_highconf_IllFB-IllGATKHC-CG-Ion_CHROM1-22_v3.2.2_highconf.bed
- `release/AshkenazimTrio/HG004_NA24143_mother/NISTv3.2.2` — platform: `Illumina + CG + Ion + SOLiD 통합` → `Illumina + CG + Ion (SOLiD 삭제). solid 문자열 0건`
  - 근거: release/AshkenazimTrio/HG004_NA24143_mother/NISTv3.2.2/HG004_GIAB_highconf_IllFB-IllGATKHC-CG-Ion_CHROM1-22_v3.2.2_highconf.bed
- `release/AshkenazimTrio/HG003_NA24149_father/NISTv3.3` — platform: `CG + Illumina + Ion + SOLiD + 10X 통합` → `CG + Illumina + Ion + 10X (SOLiD 삭제). 콜셋 이름이 CG-IllFB-IllGATKHC-Ion-10`
  - 근거: release/AshkenazimTrio/HG003_NA24149_father/NISTv3.3/HG003_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-10X_CHROM1-22_v3.3_highconf.bed
- `release/AshkenazimTrio/HG004_NA24143_mother/NISTv3.3` — platform: `CG + Illumina + Ion + SOLiD + 10X 통합` → `CG + Illumina + Ion + 10X (SOLiD 삭제)`
  - 근거: release/AshkenazimTrio/HG004_NA24143_mother/NISTv3.3/HG004_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-10X_CHROM1-22_v3.3_highconf.bed
- `release/ChineseTrio/HG005_NA24631_son/NISTv3.3` — platform: `CG + Illumina + Ion + SOLiD + 10X 통합` → `CG + Illumina + Ion + SOLiD (10X 삭제). 콜셋 이름이 CG-IllFB-IllGATKHC-Ion-SO`
  - 근거: release/ChineseTrio/HG005_NA24631_son/NISTv3.3/HG005_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-SOLID_CHROM1-22_v3.3_highconf.bed
- `release/AshkenazimTrio/HG002_NA24385_son/NISTv3.3` — refs: `[]` → `[GRCh37] 또는 [hg19]. HG001 NISTv3.3에는 같은 hg19_self_chain 파일을 근거로 GRCh37`
  - 근거: release/AshkenazimTrio/HG002_NA24385_son/NISTv3.3/supplementaryFiles/hg19_self_chain_split_withalts_gt10k.bed.gz (HG003/HG004/HG005 NISTv3.3에도 동일 경로 존재)
- `release/AshkenazimTrio/HG003_NA24149_father/NISTv3.3.2` — coverage: `"" (빈 값)` → `300x. Ilmn150bp300X 토큰이 입력 BED/VCF에 반복 등장한다. HG002 NISTv3.3.2와 HG005 N`
  - 근거: release/AshkenazimTrio/HG003_NA24149_father/NISTv3.3.2/GRCh37/supplementaryFiles/inputvcfsandbeds/HG003_GRCh37_CHROM1-22_novoalign_Ilmn150bp300X_GATKHC_gvcf_callable.bed
- … 외 10건

### 커버리지 판정

- **pacbio**: 3020 files total, 3020 covered, 0 uncovered, 0 overlapping — 주장과 정확히 일치. 직접 재계산: manifests/HG00{1..9}/pacbio_hifi.tsv(9개) + pacbio_clr.tsv(7개) 합 3020행, 중복 경로 0건, prefix 36개 중 접두어 포함 관계(a가 b/ 로 시작) 0건, 한 파일이 두 prefix에 걸린 경우 0건, 파일 0개인 prefix 0건. prefix별 실측 파일 수: HG002 MtSinai_NIST 598, HG003 MtSinai_NIST 420, HG004 MtSinai_NIST 406, HG009-T_clones 330, HG005 MtSinai_PacBio 149, HG009-N_bulk 121, HG
- **ont**: 4274 files total, 4274 covered, 0 uncovered, 0 overlapping — 주장과 정확히 일치. 재계산 방법: manifests/HG001~HG008/ont.tsv 의 1열 4274줄(HG001 6, HG002 3004, HG003 16, HG004 16, HG005 14, HG006 14, HG007 14, HG008 1190; HG009에는 ont.tsv 없음)을 18개 prefix에 대해 완전일치 또는 prefix+'/' 시작으로 매칭. 두 개 이상 prefix에 걸린 파일 0건, prefix 간 포함관계 0건. prefix별 실측 파일수: 6 / 2915 / 10 / 26 / 15 / 12 / 11 / 15 / 16 / 16 / 14 / 14 / 14 / 11 / 1
- **illumina_wgs**: 53493 files total, 53493 covered, 0 uncovered, 0 overlapping — 주장과 일치. 독립 재계산: manifests/HG001..HG008/illumina_wgs.tsv 8개 파일(1841+11380+11511+8486+6594+6778+6791+112)=53493줄, 28개 prefix에 대해 f==p 또는 f.startswith(p+'/') 판정 시 모든 파일이 매치 수 정확히 1. prefix 쌍 간 접두 포함 관계 0건, 파일 0개인 prefix 0건. manifests/HG009에는 illumina_wgs.tsv가 없어(pacbio_hifi.tsv만) 합계에서 빠진 것이 맞음. prefix별 실측 파일수: HG001 300x 1841 / HG002 Mole
- **short_targeted**: 직접 재계산 결과 주장과 완전히 일치. bgi_mgi: 155 files total, 155 covered, 0 uncovered, 0 overlapping (16 prefixes). exome: 93 files total, 93 covered, 0 uncovered, 0 overlapping (11 prefixes). COMBINED: 248 files total, 248 covered, 0 uncovered, 0 overlapping (27 prefixes). 한 파일이 두 prefix에 걸리는 경우 0건, prefix가 다른 prefix의 경로 접두어가 되는 쌍 0건, 매니페스트 내 중복 경로 0건. 파일별 prefix 매칭 개수도 주장과 자릿수까지 동일 — bgi_mgi 19/8/5/5/3/38/4/
- **linked_cg**: 5231 files total, 5231 covered, 0 uncovered, 0 overlapping (linked_reads 344/344, complete_genomics 4887/4887). 독립 스크립트로 재계산했고 주장이 그대로 재현된다. naive startswith와 component-aware(p==pf or p.startswith(pf+'/')) 두 방식에서 결과가 동일하다. nested prefix pair 0건, multi-covered 0건, 매니페스트 내 중복 경로 0건. 원본 라인 수도 일치: linked_reads 108+75+72+72+7+5+5=344, complete_genomics 656+607+603+589+1208+611+613=4887. prefix별 실측(comp
- **other**: 직접 재계산: 3216 files total, 3216 covered, 0 uncovered, 0 overlapping (경로 컴포넌트 매칭 기준: p == prefix 또는 p.startswith(prefix + '/')). prefix 107개 모두 unique이고 파일 0개짜리 prefix도 없음. HG001 398 + HG002 630 + HG003 258 + HG004 272 + HG005 143 + HG006 50 + HG007 72 + HG008 1393 = 3216, 중복 경로 없음. 단서: '0 overlapping'은 컴포넌트 매칭에서만 성립. 단순 문자열 startswith로 집계하면 data/{Ashkenazim}/HG00{2,3,4}/BioNano 가 BioNano_DLE 를 삼켜 2
- **release_rna_trio**: 직접 재계산 결과 커버리지 주장은 정확하다. 매칭 규칙 path == prefix or path.startswith(prefix + '/')로 독립 스크립트를 두 번 돌렸고 두 번 다 같은 값이 나왔다. release_truthsets.tsv: 6464 files total, 6464 covered, 0 uncovered, 0 overlapping (58 prefixes). rnaseq_all.tsv: 324 files total, 324 covered, 0 uncovered, 0 overlapping (20 prefixes). trio_analysis.tsv: 325 files total, 325 covered, 0 uncovered, 0 overlapping (9 prefixes). 합계: 7113 fi

## 2차 출처(툴·버전) 검증

| 버킷 | 조사 행 | 읽은 문서 | 잘못된 인용 | 놓친 출처 | 미해결(N/A) |
|---|---|---|---|---|---|
| pacbio | 36 | 70 | 2 | 3 | 7 |
| ont | 18 | 25 | 2 | 2 | 0 |
| illumina_wgs | 28 | 35 | 2 | 2 | 7 |
| short_targeted | 25 | 11 | 2 | 0 | 6 |
| linked_cg | 29 | 27 | 6 | 0 | 8 |
| other_germline | 52 | 57 | 6 | 7 | 9 |
| other_somatic | 55 | 58 | 3 | 8 | 11 |
| release | 58 | 33 | 13 | 6 | 2 |
| rna_trio | 29 | 24 | 3 | 1 | 2 |
| **합계** | | | **39** | **29** | **52** |

### 잘못된 인용 유형별

| 유형 | 건수 | 뜻 |
|---|---|---|
| overreach | 19 | 파일이 없는데 단계를 TRUE로 표시 |
| not_in_doc | 13 | 인용한 문서 본문에 그 툴이 없음 |
| wrong_dataset | 3 | 형제 디렉토리 문서를 잘못 끌어옴 |
| version_wrong | 2 | 버전 숫자가 문서와 다름 |
| should_be_NA | 2 | 근거 없이 채운 값 |

### 수정 내역

**pacbio**

- `data/NA12878/NA12878_PacBio_MtSinai` — variant_tool (overreach): `PBHoney (blasr 1.3.1/1.3.2) → custom pipeline (blasr 1.3.1/1` → `PBHoney (blasr 1.3.1) | custom pipeline (blasr 1.3.1/1.3.2) `
  - 근거: README.txt의 NS 비트벡터 정의가 caller-매퍼 조합 7개를 열거하는데 PBHoney는 blasr1.3.1과만 짝지어짐: '1. PBHoney/rawReads/blasr1.3.1', '3. PBHoney+ECReads+blasr1.3.1'. blasr 1.3.2는 custom 계열에만 등장: '6. custom+ECReads+blasr1.3.2
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_SequelII_CCS_11kb` — platform_refined (wrong_dataset): `sageELF ~9kb/~11kb` → `sageELF ~11kb`
  - 근거: 인용된 HG002 문서 2개 모두 '~11kb' 단독 표기: PacBio_SequelII_CCS_11kb/README.txt와 HG002_GRCh38/README.txt의 'Size selection was performed, targeting a narrow size band ~11kb using the sageELF DNA size-selection s

**ont**

- `data_somatic/HG008/Liss_lab/Northeastern_ONT-std_20240422` — tool_source (not_in_doc): `somatic_tool의 'ClairS + Severus (epi2me wf-somatic-variation` → `툴 값은 유지하되 tool_source에 giab_doc:data_somatic/HG008/Liss_lab/`
  - 근거: 번들 514문서 grep: 'modkit'은 p2 분석 README(HG008-T_vs_HG008-N-P_ONT.md) 단 한 문서에만, 'wf-somatic-variation'은 p2 데이터 README와 p2 분석 README 두 문서에만 존재. 'ClairS'는 HKU HiFi/Illumina README와 p2 분석 README에만 있고 README
- `data/AshkenazimTrio/HG002_NA24385_son/CORNELL_Oxford_Nanopore` — next_step (not_in_doc): `fast5 2912개로 R9 legacy 모델 재베이스콜 후 minimap2 정렬` → `포어 버전 언급을 빼고 '2D fast5 2912개로 재베이스콜(포어/케미스트리 버전은 문서 미기재, fas`
  - 근거: README 전문이 3문장뿐: 'minION nanopore sequencing device', 베이스콜은 'Metrichor 2.26 module, 2D Basecaling', 'HG002.fasta contains all 2D reads concatenated'. R9/R7 등 포어 세대 문자열이 없음. 매니페스트 파일명도 oxford_PC_HG02.3

**illumina_wgs**

- `data/AshkenazimTrio/HG002_NA24385_son/NIST_Stanford_Illumina_6kb_matepair` — align_ref (wrong_dataset): `hg19 (UCSC). bams/GRCh38/의 BAM은 decoy 포함 no-alt GRCh38 (HG00` → `hg19 (문서 미기재 빌드; 'from ucsc' 표현은 HG002 README에 없음). bams/GRC`
  - 근거: 인용된 data/AshkenazimTrio/HG002_NA24385_son/NIST_Stanford_Illumina_6kb_matepair/README.NIST_Stanford_Illumina_6kb_matepair 본문 전체에 'ucsc'와 'GRCh38' 문자열이 0회 등장(grep 확인). 해당 문장은 "Reads were then mapped to 
- `data/AshkenazimTrio/HG003_NA24149_father/NIST_Stanford_Moleculo` — platform_refined (not_in_doc): `Illumina HiSeq 2500 high output (v4), 2x125 bp PE; TruSeq Sy` → `값 자체는 정확하지만 tool_source에 data/AshkenazimTrio/HG002_NA24385_s`
  - 근거: 이 행의 tool_source는 basespace_bams/readme.txt 1개뿐인데, 그 문서 전문은 4문장(파일명 규칙 007/008, bwa-mem 정렬)이고 기종·리드길이·라이브러리 킷 언급이 전혀 없음. HiSeq 2500 high output (v4) 2x125bp와 TruSeq Synthetic Long-Read DNA Library Pre

**short_targeted**

- `data/AshkenazimTrio/HG002_NA24385_son/MGISEQ/PCR-free` — notes (overreach): `"같은 MGISEQ 상위에 stLFR 서브디렉토리가 따로 있고 그쪽엔 readme.txt가 있으나 stLFR` → `MGISEQ/stLFR/ 에는 readme가 없음. stLFR readme는 별개 최상위 디렉토리 data/`
  - 근거: manifests/HG002/bgi_mgi.tsv 의 MGISEQ/stLFR 항목은 split_read_1.fq.gz, split_read_2.fq.gz, Md5.in 3개뿐(readme 없음). getdoc.py list stLFR → 7개 문서 전부 data/<trio>/<sample>/stLFR/readme.txt 경로. 해당 readme 본문: "T
- `data/NA12878/Nebraska_NA12878_HG001_TruSeq_Exome` — align_ref (overreach): `"hg19/GRCh37 (동봉 TruSeq_exome_targeted_regions.hg19.bed 기준)"` → `N/A (BAM @SQ/@PG 확인 필요). 동봉 BED가 hg19라는 사실만 별도로 적는 편이 정확.`
  - 근거: 이 프리픽스에 문서 0개 (getdoc grep: Nebraska 0건, bcbio 0건, hg001-7001 0건, TruSeq_exome_targeted 0건). BAM 파일명 NIST-hg001-7001-ready.bam / NIST-hg001-7001-b-ready.bam 에 레퍼런스 토큰 없음. 근거는 형제 파일 TruSeq_exome_target

**linked_cg**

- `data/NA12878/CompleteGenomics_normal_RMDNA` — align_tool (version_wrong): `CG Standard Pipeline 2.5.0 → cgatools map2sam v1.8.0 / evide` → `CG Standard Pipeline 2.5 → cgatools map2sam v1.8.0 / evidenc`
  - 근거: 인용 근거로 든 data/NA12878/CompleteGenomics_normal_RMDNA/GS000025639-ASM/EXP/README.2.5.0.txt(2636자) 본문 전문을 읽고 grep -E '2\.5|Standard Pipeline|pipeline|version' 로 확인 — 본문 히트는 'system versions', 'conversion
- `data/ChineseTrio/HG005_NA24631_son/CompleteGenomics_normal_RMDNA` — variant_tool (not_in_doc): `cgatools (CG Standard Pipeline 2.5)` → `CG Standard Pipeline 2.5 (cgatools 삭제). 변이콜 툴 근거를 엄격히 보면 N/A`
  - 근거: 인용 문서 data/ChineseTrio/HG005_NA24631_son/CompleteGenomics_normal_RMDNA/README.txt(2812자)의 cgatools 언급은 3건이고 전부 BAM 변환용이다(evidence2sam, map2sam, docs/1.8.0 user guide). 1행 분석 디렉토리명은 'CompleteGenomics_H
- `data/NA12878/CompleteGenomics_normal/BAM` — tool_source (variant_tool의 junctions2events) (not_in_doc): `variant_tool 'CG Standard Pipeline 2.5 → cgatools junctions2` → `tool_source: giab_doc:data/NA12878/CompleteGenomics_normal/R`
  - 근거: getdoc.py grep 'junctions2events' → 514개 문서 전체에서 2건뿐이고 둘 다 분석 디렉토리 문서다(data/NA12878/analysis/CompleteGenomics_PublicGenomes_10152011/README.txt:18, data/NA12878/analysis/CompleteGenomics_RMDNA_1127201
- `data/NA12878/CompleteGenomics_normal_RMDNA` — tool_source (variant_tool의 junctions2events) (not_in_doc): `variant_tool 'CG Standard Pipeline 2.5 → cgatools junctions2` → `tool_source: giab_doc:data/NA12878/CompleteGenomics_normal_R`
  - 근거: CompleteGenomics_normal_RMDNA/README.txt(2779자) 전문에 junctions2events 없음(cgatools 언급 3건 모두 evidence2sam·map2sam·user guide). 문자열은 data/NA12878/analysis/CompleteGenomics_RMDNA_11272014/README.txt:18에만 있
- `data/NA12878/CompleteGenomics_normal/CGI_PublicGenomeData` — tool_source (should_be_NA): `giab_doc:data/NA12878/CompleteGenomics_normal/README.txt` → `N/A (모든 *_tool이 N/A이므로 tool_source도 N/A. evidence의 실제 인용 문서는`
  - 근거: 상위 README 전문을 읽었다 — 설명 대상은 LIB/MAP 하위와 evidenceDnbs*/_mapping_sorted_header BAM 뿐이고 ASM EVIDENCE/REF tar(이 prefix의 내용물)를 한 번도 언급하지 않는다. 게다가 매니페스트 HG001/complete_genomics.tsv 기준 CompleteGenomics_normal
- `data/NA12878/CompleteGenomics_normal/README.txt` — notes (overreach): `BAM/ 과 CGI_PublicGenomeData/ 두 하위를 설명하는 상위 README` → `BAM/ 하위(evidenceDnbs*, *_mapping_sorted_header)만 설명하고 CGI_Pu`
  - 근거: README.txt(2773자) 전문 확인: 항목은 변이콜 결과 위치, LIB·MAP 하위 설명 PDF 링크, 'BAM files are provided in order to provide evidence of variants called', evidenceDnbs* 설명, *_mapping_sorted_header.bam 설명 5개뿐. ASM/EVIDEN

**other_germline**

- `data/NA12878/MtSinai_BioNano` — platform_refined (not_in_doc): `Bionano 광학맵, Nt.BspQI nickase (장비 모델 미표기) — align_ref에도 'hg1` → `Bionano 광학맵 (nickase·장비 모델 문서 미기재) / align_ref: hg19 (in-sil`
  - 근거: 인용 문서 data/NA12878/MtSinai_BioNano/README.txt 전문(725자)에는 nickase 이름이 전혀 없음. 해당 줄은 'EXP_REFINEFINAL1_r.cmap: a representation of an in-silico digested public reference hg19'뿐이다. 'Nt.BspQI motifs' 문구는 형
- `data/NA12878/MtSinai_BioNano` — reads_format (wrong_dataset): `all.bnx (이미지 처리·>150kb 필터 후 원시 분자)` → `all.bnx (BioNano 80x raw molecule file)`
  - 근거: MtSinai README.txt는 'all.bnx: BioNano 80x raw molecule file'로만 기술. '이미지 처리 후 >150kb 필터'는 AJ/중국인 트리오 BioNano README의 문장('all.bnx is the raw data after image processing and filtering for molecules >150k
- `data/AshkenazimTrio/HG002_NA24385_son/HiC_downsampled` — reads_format (overreach): `fastq.gz R1/R2 (HiC_1 S1~S3 triplicate, HiC_2 2x150 및 NovaSe` → `fastq.gz 8개: HiC_1 3반복(HG002.HiC_1_1/2/3 R1·R2) + HiC_2 Nova`
  - 근거: 매니페스트(manifests/HG002)의 HiC_downsampled 항목은 fastq 8개뿐이며 HiC_2 2x150 파일이 없다. README 자체도 'As of Jan 22 2020, only one dataset is available'라고 적어 미업로드 상태를 시사한다. facts.tsv n_fastq=8과 일치.
- `data/NA12878/analysis/Leicester_HipSTR_GangSTR_05182022` — notes (overreach): `이 디렉토리 VCF에는 NA12878 외에 HG002~HG007도 포함된 멀티샘플 파일이 있음` → `HipSTR VCF 2개(NA12878_Chinese_trio_100x/30x)가 HG005·HG006·HG`
  - 근거: 매니페스트상 이 prefix 파일은 GangSTR/NA12878_{100x,30x}.vcf.gz(+tbi), HipSTR/NA12878_Chinese_trio_{100x,30x}.vcf.gz(+tbi), README 3개, NA12878-md5s.txt 뿐. HipSTR/README.md 표: 'HG005,HG006,HG007,NA12878  NA12878
- `data/NA12878/analysis/IonTorrent_TVC_06302015` — align_ref (not_in_doc): `hg19` → `N/A (또는 '같은 bam'이라는 문서 진술을 근거로 형제 문서 IonTorrent_TVC_04302015`
  - 근거: 인용 문서 README.IonTorrent_TVC_06302015 전문에는 레퍼런스 언급이 없다(내용은 'Alignment: tmap -J 25 --end-repair 15 --do-repeat-clip --context / Variant calling: TVC4.4 + new high confidence region (AmpliseqExome.201411
- `data/NA12878/analysis/Illumina_PlatinumGenomes_NA12877_NA12878_09162015` — align_tool (overreach): `bwa (파일명 토큰 bwa_*, 버전 미기재); Isaac / Isaac2 (자체 정렬 포함)` → `bwa (파일명 토큰 bwa_*, 버전 미기재). isaac/isaac2는 콜셋 파일명 토큰일 뿐, 정렬 수`
  - 근거: 이 prefix의 README는 226자로 'This is a mirror of the data that are available on http://www.illumina.com/platinumgenomes'만 기술. 파일명은 individual_callsets/isaac.vcf.gz(v6.0), isaac2.vcf.gz(v7.0)로 콜셋 파일이며, 문서 

**other_somatic**

- `data_somatic/HG008/Liss_lab/analysis/Harvard_Cheng_hifiasm-assemblies_20240509` — platform_refined / notes / next_step (not_in_doc): `"PacBio Revio HiFi(UCSC/BCM 2종)" 및 "UCSC HiFi(sub0)와 BCM HiF` → `sub0 = PacBio가 생성한 Revio HiFi, sub1 = BCM이 생성한 Revio HiFi. U`
  - 근거: README_hifiasm_20240509.md: 커맨드 블록 헤더가 "using PacBio generated Revio data" (HG008.tumor.sub0.asm, 입력 HG008-T_PacBio-Revio_m84039_240113_032943_s4/m84039_240114_012401_s1.hifi_reads.bc2005.fq.gz) 와 "us
- `data_somatic/HG008/Liss_lab/superseded-2022-data/BCM_ILMN-somatic-analysis_20220816` — coverage_refined (not_in_doc): `"NIST 재정렬 기준 normal ~150x / tumor ~180~191x"` → `인용 문서(README_BCM.md)에 있는 값은 NIST 재정렬 기준 HG008-T mean autosom`
  - 근거: getdoc.py grep "180x" 결과 전체 514개 문서 중 유일한 매칭이 superseded-2022-data/analysis/NIST-Year1_BCM-ILMN-WGS_2022/README_NIST-year1-analysis.md:125-126(파일명 HG008-T_Illumina_180x_GRCh38_sorted.bam)과 :187("Cover
- `data_somatic/HG008/NIST/HG008-T_clones` — notes (overreach): `"클론마다 33-35개 염색체 집단과 65-71개 집단(전게놈 배가)이 공존한다고 기록돼 있어"` → `두 집단 공존은 2D6과 3E4에만 해당한다. SC14는 20개 metaphase spread 전부가 65-`
  - 근거: README_KaryoLogic_20241028.md: "**HG008-T clone SC14** / 20 metaphase spreads counted and analyzed / 65-71 chromosomes with multiple rearrangements (20 metaphase spreads)" — 33-35 집단 항목이 SC14에는 없다. 2D

**release**

- `release/NA12878_HG001/NISTv4.2.1` — variant_tool (not_in_doc): `"... MrCaNaVaR(Illumina 중복 제외), mosdepth 계열 커버리지 이상치 제외" — t` → `mosdepth 삭제. 커버리지 이상치 제외는 툴 미기재로 두고 MrCaNaVaR만 남길 것 (MrCaNaV`
  - 근거: getdoc grep "mosdepth" → release 문서 중 유일한 히트가 release/AshkenazimTrio/HG002_NA24385_son/NISTv4.1/README_v4.1.txt:15 (형제 데이터셋 문서). HG001/HG002/HG005/HG006/HG007의 어떤 README_v4.2.1.txt에도 mosdepth 문자열이 없고,
- `release/AshkenazimTrio/HG002_NA24385_son/NISTv3.2` — evidence (not_in_doc): `README_NISTv3.2.txt 인용으로 'AJ Trio는 "the union of >10 submitt` → `이 문장은 삭제. v3.2 README의 해당 대목은 "These were SVs derived from m`
  - 근거: getdoc grep "union of >10 submitted SV callsets" → 히트 문서는 HG003/HG004 NISTv3.2.2, 모든 NISTv3.3, NISTv3.3.2, NISTv4.1, NISTv4.2.1. HG002_NA24385_son/NISTv3.2/README_NISTv3.2.txt와 NA12878_HG001/NISTv3.2/
- `release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1` — variant_tool (overreach): `"... trio 멘델 분석으로 위반 영역 제외; pbsv SV 영역 제외" — HG002 콜셋 설명에 pb` → `pbsv 제외는 HG002에서 빼고 HG003/HG004 행에만 남길 것. HG002는 v0.6 SV 콜셋 `
  - 근거: getdoc grep "pbsv" → HG002 NISTv4.2.1/README_v4.2.1.txt 안의 유일한 pbsv 문장은 13행 "2. We exclude pbsv calls and 50bp flanking sequence from HG003 and HG004, because the Tier 1 and Tier 2 SVs did not exclude
- `release/NA12878_HG001/NISTv2.19` — notes (version_wrong): `"배포 VCF 파일명은 여전히 VQSRv2.18 계열이라 파일명만 보면 버전 오인 가능"` → `배포 VCF는 VQSRv2.19 표기다. 오인 소지는 반대 방향 — README 본문이 구버전 v2.18 파`
  - 근거: manifests/release_truthsets.tsv: release/NA12878_HG001/NISTv2.19/NISTIntegratedCalls_14datasets_131103_allcall_UGHapMerge_HetHomVarPASS_VQSRv2.19_2mindatasets_5minYesNoRatio_all_...vcf.gz 와 union13...
- `release/ChineseTrio/HG006_NA24694_father/NISTv3.3.2` — evidence (overreach): `sentieonHC 근거로 "For new GRCh38 analyses of Illumina and 10X ` → `이 문장은 AJ trio와 Chinese son만 포괄한다. HG006 근거는 파일명 토큰(HG006_1-2`
  - 근거: getdoc grep 결과 해당 문장은 HG006 자체 문서(NISTv3.3.2/GRCh37/README_NIST_v3.3.2.txt:21)에 있으나 대상이 "AJ trio and Chinese son"으로 한정된다. 문서 item 6은 Han Chinese trio의 parents에 대해서는 위상이 아니라 멘델 오류 50bp 제외만 언급한다. 더구나 HG
- `release/NA12878_HG001/NISTv3.3.2` — evidence (overreach): `phase_tool 근거로 README_NISTv3.3.2.txt의 "Use RTG vcfeval tools` → `같은 문서의 HG001 관련 문장으로 교체할 것: item 7 "For HG001, 99.0% of benc`
  - 근거: 22행 원문 전체는 "6. Use RTG vcfeval tools to harmonize representation of complex variants in AJ trio prior to performing Mendelian inheritance analysis and phasing. Apply trio phasing to HG002 high confide
- `release/NA12878_HG001/NISTv2.15` — align_ref (should_be_NA): `align_ref = "GRCh37"` → `빈 값 또는 N/A. (v2.17 이후 README에는 GRCh37 언급이 있으나 v2.15 문서에는 없다)`
  - 근거: README.NIST.v2.15.txt 전문(1962자, 매니페스트 크기 1971과 일치)에 GRCh37/hg19/b37 문자열이 없다(getdoc grep 히트 0). 이 prefix 4개 파일명(NIST_IntegratedCalls_12datasets_130517_HetHomVarPASS_VQSRv2.15.vcf.gz, union12callable...
- `release/NA12878_HG001/NISTv3.3.2` — notes (overreach): `"TSVC(Ion Torrent Variant Caller)는 매니페스트 전체에서 이 prefix에만 나온다` → `release/ 안에서는 이 prefix에만 나온다로 한정할 것`
  - 근거: 매니페스트 전체 경로 76595건 대조: data/NA12878/analysis/IonTorrent_TVC_04302015/TSVC_variants.vcf, .../TSVC_variants_NISTv2.19ashotspot.vcf, data/NA12878/analysis/IonTorrent_TVC_06302015/TSVC_variants_defaultlow
- `release/references` — index_note (overreach): `"resources 하위 BED/VCF는 모두 bgzip + tabix(.tbi)"` → `VCF 언급 삭제. resources 하위는 BED(.bed.gz)와 md5/README뿐이다`
  - 근거: facts.tsv: release/references n_vcf=0. 매니페스트에서 release/references 하위 .vcf 파일 grep 결과 0건. 실제 구성은 hg19/hg38 계열 *.bed.gz 29건, FASTA 7건, self_chain BAM 2건, 문서 6건.
- `release/NA12878_HG001/NISTv3.2` — aligned (overreach): `aligned=TRUE, align_by=GIAB (align_tool novoalign/tmap/Lifes` → `"-" (이 prefix에는 리드도 BAM도 없다). 정렬 툴 정보는 align_tool 문자열에 남겨두면 `
  - 근거: facts.tsv: release/NA12878_HG001/NISTv3.2 n_bam=0, n_fastq=0 (파일 12건 = bed 4, vcf 3, index 2, checksum 2, doc 1). 행 자신의 notes도 "BAM은 이 prefix에 없다"고 적고 있어 aligned=TRUE와 모순이며, 같은 상황인 v4.2.1 행은 aligned="
- `release/AshkenazimTrio/HG002_NA24385_son/NISTv3.2.2` — aligned (overreach): `aligned=TRUE, align_by=GIAB` → `"-"`
  - 근거: facts.tsv: n_bam=0, n_fastq=0 (파일 10건). 행 notes에 "BAM은 이 prefix에 없음"이라고 명시돼 있다.
- `release/ChineseTrio/HG006_NA24694_father/NISTv3.3.2` — aligned (overreach): `aligned=TRUE, align_by=GIAB` → `"-"`
  - 근거: facts.tsv: n_bam=0, n_fastq=0 (파일 64건, 전부 vcf/bed/index/doc). 매니페스트 확인 결과 GRCh37·GRCh38 모두 입력 VCF와 callable BED만 있고 정렬 산출물은 없다.
- … 외 1건

**rna_trio**

- `data/AshkenazimTrio/analysis/NIST_BGIseq_2x150bp_100x_07192023` — variant_called (overreach): `variant_called=TRUE / variant_tool="GATK HaplotypeCaller v4.` → `이 prefix에 VCF가 한 건도 없으므로 variant_called는 "-"(해당 없음)가 맞다. 툴 인`
  - 근거: manifests/trio_analysis.tsv에서 이 prefix는 파일 3건뿐: README_NIST_BGISeq_100x_HG002_analysis.md(5759B), hg19_BGI_F21FTSUSAT0769_HUMuarfR_report_en.pdf, hg38_...pdf. facts.tsv n_bam=0 n_vcf=0 gib=0.0. README
- `data/ChineseTrio/analysis/NIST_BGIseq_2x150bp_100x_07192023` — variant_called (overreach): `variant_called=TRUE / variant_tool="GATK HaplotypeCaller v4.` → `HG002 쪽과 동일 — VCF 부재이므로 "-". GATK HaplotypeCaller v4.1.4.1 인`
  - 근거: manifests/trio_analysis.tsv: README_NIST_BGISeq_100x_HG005_analysis.md(5779B) + hg19/hg38 BGI 리포트 PDF 2건(HG002 디렉토리와 바이트 수까지 동일: 1007111 / 1007295). facts상 n_vcf=0. README 48-55행의 HG005 snp·indel vcf.
- `data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.015-20240215` — notes (not_in_doc): `v0.012 대비 차이는 제외 규칙(segdup·satellite 40kb 병합)뿐이고 툴·버전은 동일` → `인용 README의 Changelog는 변경 5건을 명시한다 — (1) 소변이·SV 공용 단일 VCF 제공,`
  - 근거: v0.015 README 8-12행 Changelog 5개 항목 원문 확인. 대조로 v0.012 README에는 Changelog 절 자체가 없고 3행 제목 직후 GENERAL INFORMATION으로 이어짐 — 즉 5개 항목이 모두 v0.015에서 새로 선언된 차이다. (같은 행의 reads_format '통합 VCF'는 항목 (1)을 반영하고 있어 no

### 문서까지 확인했지만 툴 불명 (N/A로 남긴 것)

**pacbio** (7건)

- `data/ChineseTrio/HG005_NA24631_son/PacBio_CCS_15kb_20kb_chemistry2`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/PacBio_CCS_15kb_20kb_chemistry2`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/PacBio_CCS_15kb_20kb_chemistry2`
- `data/AshkenazimTrio/HG004_NA24143_mother/PacBio_CCS_15kb_20kb_chemistry2`
- `data/NA12878/PacBio_CCS_15kb_20kb_chemistry2`
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_MtSinai_NIST`
- `data/AshkenazimTrio/HG004_NA24143_mother/PacBio_MtSinai_NIST`

**illumina_wgs** (7건)

- `data/AshkenazimTrio/HG002_NA24385_son/Illumina_PCRfree_downsampled`
- `data/AshkenazimTrio/HG003_NA24149_father/NIST_Illumina_2x250bps`
- `data/AshkenazimTrio/HG004_NA24143_mother/NIST_Illumina_2x250bps`
- `data/AshkenazimTrio/HG004_NA24143_mother/NIST_Stanford_Moleculo`
- `data/ChineseTrio/HG005_NA24631_son/NIST_Stanford_Moleculo`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/NIST_Stanford_Moleculo`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/NIST_Stanford_Moleculo`

**short_targeted** (6건)

- `data/NA12878/BGISEQ500`
- `data/NA12878/Nebraska_NA12878_HG001_TruSeq_Exome`
- `data/AshkenazimTrio/HG002_NA24385_son/OsloUniversityHospital_Exome`
- `data/AshkenazimTrio/HG003_NA24149_father/OsloUniversityHospital_Exome`
- `data/AshkenazimTrio/HG004_NA24143_mother/OsloUniversityHospital_Exome`
- `data/ChineseTrio/HG005_NA24631_son/OsloUniversityHospital_Exome`

**linked_cg** (8건)

- `data/NA12878/CompleteGenomics_normal/BAM`
- `data/NA12878/stLFR`
- `data/AshkenazimTrio/HG002_NA24385_son/stLFR`
- `data/AshkenazimTrio/HG003_NA24149_father/stLFR`
- `data/AshkenazimTrio/HG004_NA24143_mother/stLFR`
- `data/ChineseTrio/HG005_NA24631_son/stLFR`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/stLFR`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/stLFR`

**other_germline** (9건)

- `data/NA12878/analysis/GARVAN_snps_indels_12172013`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_SOLiD5500W`
- `data/ChineseTrio/HG005_NA24631_son/NIST_SOLiD5500W`
- `data/NA12878/MtSinai_BioNano`
- `data/AshkenazimTrio/HG002_NA24385_son/BioNano`
- `data/AshkenazimTrio/HG003_NA24149_father/BioNano`
- `data/AshkenazimTrio/HG004_NA24143_mother/BioNano`
- `data/ChineseTrio/HG005_NA24631_son/BioNano`
- `data/NA12878/analysis/JasonChin_Peregrine_PacBioCCS_assembly_05072019`

**other_somatic** (11건)

- `data_somatic/HG008/Liss_lab/Arima_HiC-ILMN_20240112`
- `data_somatic/HG008/Liss_lab/Bioskryb_ResolveDNA_20230914`
- `data_somatic/HG008/Liss_lab/analysis/BCM_Revio_20240313`
- `data_somatic/HG008/Liss_lab/analysis/NIH_HiFi-HiC_Wakhan-CNA_20240424`
- `data_somatic/HG008/Liss_lab/analysis/NIH_HiFi_Wakhan-CNA_20240308`
- `data_somatic/HG008/Liss_lab/analysis/NIH_HiFi_mm2_mapping`
- `data_somatic/HG008/Liss_lab/analysis/NYGC-somatic-pipeline_20240412`
- `data_somatic/HG008/Liss_lab/analysis/PacBio_Revio_20240125`
- `data_somatic/HG008/Liss_lab/analysis/Ultima_DeepVariant-somatic-SNV-INDEL_20240822`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/PhaseGenomics_HiC_20220629`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/BCM_Illumina_WGS_20220816`

**release** (2건)

- `release/AshkenazimTrio/HG002_NA24385_son/TandemRepeats_v1.0`
- `release/references`

**rna_trio** (2건)

- `data/AshkenazimTrio/analysis/ncbi_chrXY_var_03302023/ILMN`
- `data/AshkenazimTrio/analysis/ncbi_chrXY_var_03302023/PacBio_HiFi`

### 인용한 GIAB 공식 문서

319개 문서를 근거로 사용했다.

<details><summary>전체 목록</summary>

- `data/AshkenazimTrio/HG002_NA24385_son/10XGenomics/README_10Xgenomes.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/BioNano/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/BioNano/bionano_readme`
- `data/AshkenazimTrio/HG002_NA24385_son/BioNano_DLE/README.data_link`
- `data/AshkenazimTrio/HG002_NA24385_son/CORNELL_Oxford_Nanopore/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/CompleteGenomics_normal_RMDNA/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/Dovetail_ChicagoLibraties/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/Element_AVITI_20231018/README_Element.md`
- `data/AshkenazimTrio/HG002_NA24385_son/Element_AVITI_20240920/README_Element_20240920.md`
- `data/AshkenazimTrio/HG002_NA24385_son/HG002B-PhaseGenomics-20241031/README_20241031.md`
- `data/AshkenazimTrio/HG002_NA24385_son/HiC_downsampled/README`
- `data/AshkenazimTrio/HG002_NA24385_son/Illumina_PCRfree_downsampled/README`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_BGIseq_2x150bp_100x/README_NIST_BGISeq_100x_HG002_data.md`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_HiSeq_HG002_Homogeneity-10953946/NHGRI_Illumina300X_AJtrio_novoalign_bams/README_NHGRI_Novoalign_bams`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_HiSeq_HG002_Homogeneity-10953946/README_NIST_Illumina_pairedend_HG002.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/README_NIST_Illumina_pairedend_2x250_HG002.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/novoalign_bams/README_update_feb2019`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_SOLiD5500W/README.NIST_SOLID5500W.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_Stanford_Illumina_6kb_matepair/README.NIST_Stanford_Illumina_6kb_matepair`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_Stanford_Moleculo/README.NIST_Stanford_Moleculo`
- `data/AshkenazimTrio/HG002_NA24385_son/NIST_Stanford_Moleculo/basespace_bams/readme.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_10kb/GRCh38_no_alt_analysis/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_10kb/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_10kb/README_PacBio_CCS_10kb_HG002.md`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_10kb/alignment/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb/GRCh38_no_alt_analysis/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb/alignment/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb_20kb_chemistry2/GRCh37/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb_20kb_chemistry2/GRCh38/README.giab_uploadedbams_UCSD_duplomap`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb_20kb_chemistry2/GRCh38/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb_20kb_chemistry2/GRCh38/README_PacBio_CCS_15kb_20kb_HG002.md`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CCS_15kb_20kb_chemistry2/reads/HG002_PacBioCCS_15kb_20kb_README.md`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CLR/PacBio_CLR_HG002_README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_CLR/WUSTL_PacBio_CLR.README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_HiFi-Revio_20231031/README_HG002-PacBio-Revio.md`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_MtSinai_NIST/Baylor_NGMLR_bam_GRCh37/README`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_MtSinai_NIST/PacBio_fasta/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_MtSinai_NIST/PacBio_minimap2_bam/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_MtSinai_NIST/hdf5/pacbio_README`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_SequelII_CCS_11kb/HG002_GRCh38/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/PacBio_SequelII_CCS_11kb/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/Strand-Seq_BCCRC/README`
- `data/AshkenazimTrio/HG002_NA24385_son/Strand-Seq_BCCRC/README_UPDATE`
- `data/AshkenazimTrio/HG002_NA24385_son/Strand-Seq_EMBL/HG002_StrandSeq_README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/UCSC_Ultralong_OxfordNanopore_Promethion/README_ONT-UL_UCSC_HG002.md`
- `data/AshkenazimTrio/HG002_NA24385_son/Ultralong_OxfordNanopore/combined_2018-05-18/README_2018-05-17`
- `data/AshkenazimTrio/HG002_NA24385_son/Ultralong_OxfordNanopore/combined_2018-08-10/HG002_ONTrel2_16x_RG_HP10xtrioRTG.cram_filename_change_01292020.README`
- `data/AshkenazimTrio/HG002_NA24385_son/Ultralong_OxfordNanopore/combined_2018-08-10/README_2018-08-10`
- `data/AshkenazimTrio/HG002_NA24385_son/Ultralong_OxfordNanopore/guppy-V2.3.4_2019-06-26/README.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/Ultralong_OxfordNanopore/guppy-V3.2.4_2020-01-22/README`
- `data/AshkenazimTrio/HG002_NA24385_son/Ultralong_OxfordNanopore/guppy-V3.4.5/README_ONT-UL_GIAB_HG002.md`
- `data/AshkenazimTrio/HG002_NA24385_son/ion_exome/README_Ion_GIAB_20150508.txt`
- `data/AshkenazimTrio/HG002_NA24385_son/stLFR/readme.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/10XGenomics/README_10Xgenomes.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/BioNano/README.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/BioNano/bionano_readme`
- `data/AshkenazimTrio/HG003_NA24149_father/BioNano_DLE/BNG_HG003.README.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/CompleteGenomics_normal_RMDNA/README.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/Dovetail_ChicagoLibraties/README.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/Element_AVITI_20240920/README_Element_20240920.md`
- `data/AshkenazimTrio/HG003_NA24149_father/HiC_UCSC/HG003_HiC_README.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/NIST_HiSeq_HG003_Homogeneity-12389378/NHGRI_Illumina300X_AJtrio_novoalign_bams/README_NHGRI_Novoalign_bams`
- `data/AshkenazimTrio/HG003_NA24149_father/NIST_HiSeq_HG003_Homogeneity-12389378/README_NIST_Illumina_pairedend_HG003.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/NIST_Illumina_2x250bps/README_NIST_Illumina_pairedend_2x250_HG003.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/NIST_Illumina_2x250bps/novoalign_bams/README`
- `data/AshkenazimTrio/HG003_NA24149_father/NIST_Stanford_Illumina_6kb_matepair/README.NIST_Stanford_Illumina_6kb_matepair`
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_CCS_15kb_20kb_chemistry2/CHM13v2.0/GIAB_5mC_CpG/README.txt_02022023`
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_CCS_15kb_20kb_chemistry2/GRCh38/README_HG003_GRCh38.md`
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_CCS_15kb_20kb_chemistry2/reads/README_PacBio-CCS_HudsonAlpha_HG003.md`
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_CCS_Google_15kb/Readme.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_HiFi-Revio_20231031/README_HG003-PacBio-Revio.md`
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_MtSinai_NIST/CSHL_bwamem_bam_GRCh37/README.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_MtSinai_NIST/PacBio_fasta/README.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/PacBio_MtSinai_NIST/PacBio_minimap2_bam/README.txt`
- `data/AshkenazimTrio/HG003_NA24149_father/Strand-Seq_BCCRC/README`
- `data/AshkenazimTrio/HG003_NA24149_father/UCSC_Ultralong_OxfordNanopore_Promethion/README_ONT-UL_UCSC_HG003.md`
- `data/AshkenazimTrio/HG003_NA24149_father/stLFR/readme.txt`
- `data/AshkenazimTrio/HG004_NA24143_mother/10XGenomics/README_10Xgenomes.txt`
- `data/AshkenazimTrio/HG004_NA24143_mother/BioNano_DLE/BNG_HG004.README.txt`
- `data/AshkenazimTrio/HG004_NA24143_mother/CompleteGenomics_normal_RMDNA/README.txt`
- `data/AshkenazimTrio/HG004_NA24143_mother/Element_AVITI_20240920/README_Element_20240920.md`
- `data/AshkenazimTrio/HG004_NA24143_mother/HiC_UCSC/HG004_HiC_README.txt`
- `data/AshkenazimTrio/HG004_NA24143_mother/NIST_HiSeq_HG004_Homogeneity-14572558/NHGRI_Illumina300X_AJtrio_novoalign_bams/README_NHGRI_Novoalign_bams`
- `data/AshkenazimTrio/HG004_NA24143_mother/NIST_HiSeq_HG004_Homogeneity-14572558/README_NIST_Illumina_pairedend_HG004.txt`
- `data/AshkenazimTrio/HG004_NA24143_mother/NIST_Illumina_2x250bps/README_NIST_Illumina_pairedend_2x250_HG004.txt`
- `data/AshkenazimTrio/HG004_NA24143_mother/NIST_Illumina_2x250bps/novoalign_bams/README`
- `data/AshkenazimTrio/HG004_NA24143_mother/NIST_Stanford_Illumina_6kb_matepair/README.NIST_Stanford_Illumina_6kb_matepair`
- `data/AshkenazimTrio/HG004_NA24143_mother/PacBio_CCS_15kb_20kb_chemistry2/GRCh38/README_HG004_GRCh38.md`
- `data/AshkenazimTrio/HG004_NA24143_mother/PacBio_CCS_Google_15kb/Readme.txt`
- `data/AshkenazimTrio/HG004_NA24143_mother/PacBio_CCS_HudsonAlpha_15kb_21kb/README_PacBio-CCS_HudsonAlpha_HG004.md`
- `data/AshkenazimTrio/HG004_NA24143_mother/PacBio_HiFi-Revio_20231031/README_HG004-PacBio-Revio.md`
- `data/AshkenazimTrio/HG004_NA24143_mother/Strand-Seq_BCCRC/README`
- `data/AshkenazimTrio/HG004_NA24143_mother/UCSC_Ultralong_OxfordNanopore_Promethion/README_ONT-UL_UCSC_HG004.md`
- `data/AshkenazimTrio/HG004_NA24143_mother/stLFR/readme.txt`
- `data/AshkenazimTrio/analysis/NIST_BGIseq_2x150bp_100x_07192023/README_NIST_BGISeq_100x_HG002_analysis.md`
- `data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.012-20231107/README.md`
- `data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.015-20240215/README.md`
- `data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.018-20240716/NIST_HG002_DraftBenchmark_defrabbV0.018-20240716_README_update.md`
- `data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.019-20241113/NIST_HG002_DraftBenchmark_defrabbV0.019-20241113_README.md`
- `data/AshkenazimTrio/analysis/PacBio_HiFi-Revio_20231031/pacbio-wgs-wdl_germline_20231031/README_PacBio_Revio_analysis.md`
- `data/ChineseTrio/HG005_NA24631_son/BioNano/README.txt`
- `data/ChineseTrio/HG005_NA24631_son/CompleteGenomics_normal_RMDNA/README.txt`
- `data/ChineseTrio/HG005_NA24631_son/CompleteGenomics_normal_cellsDNA/README.txt`
- `data/ChineseTrio/HG005_NA24631_son/Element_AVITI_20240920/README_Element_20240920.md`
- `data/ChineseTrio/HG005_NA24631_son/HG005_NA24631_son_HiSeq_300x/NHGRI_Illumina300X_Chinesetrio_novoalign_bams/README`
- `data/ChineseTrio/HG005_NA24631_son/HG005_NA24631_son_HiSeq_300x/README_NIST_Illumina_pairedend_HG005.txt`
- `data/ChineseTrio/HG005_NA24631_son/HG005_NA24631_son_HiSeq_300x/basespace_45x_bams_vcfs_PerFlowCell/README`
- `data/ChineseTrio/HG005_NA24631_son/HudsonAlpha_PacBio_CCS/README_PacBio-CCS_HudsonAlpha_HG005.md`
- `data/ChineseTrio/HG005_NA24631_son/MtSinai_PacBio/HG005.README`
- `data/ChineseTrio/HG005_NA24631_son/MtSinai_PacBio/PacBio_fasta/README.txt`
- `data/ChineseTrio/HG005_NA24631_son/MtSinai_PacBio/PacBio_minimap2_bam/README.txt`
- `data/ChineseTrio/HG005_NA24631_son/NIST_BGIseq_2x150bp_100x/README_NIST_BGISeq_100x_HG005_data.md`
- `data/ChineseTrio/HG005_NA24631_son/NIST_SOLiD5500W/README.NIST_SOLID5500W.txt`
- `data/ChineseTrio/HG005_NA24631_son/NIST_Stanford_Illumina_6kb_matepair/README.NIST_Stanford_Illumina_6kb_matepair`
- `data/ChineseTrio/HG005_NA24631_son/PacBio_SequelII_CCS_11kb/README.txt`
- `data/ChineseTrio/HG005_NA24631_son/Strand-Seq_BCCRC/README`
- `data/ChineseTrio/HG005_NA24631_son/UCSC_Ultralong_OxfordNanopore_Promethion/README_ONT-UL_UCSC_HG005.md`
- `data/ChineseTrio/HG005_NA24631_son/stLFR/readme.txt`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/CompleteGenomics_normal_cellsDNA/README.txt`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/NA24694_Father_HiSeq100x/NHGRI_Illumina100X_Chinesetrio_novoalign_bams/README`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/NA24694_Father_HiSeq100x/README_NIST_Illumina_pairedend_NA24694.txt`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/NIST_Stanford_Illumina_6kb_matepair/README.NIST_Stanford_Illumina_6kb_matepair`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/PacBio_CCS_15kb_20kb_chemistry2/reads/README_PacBio-CCS_HudsonAlpha_HG006.md`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/PacBio_HiFi_Google/README_PacBio-CCS_Google_HG006.md`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/PacBio_MtSinai/HG006.README`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/PacBio_MtSinai/PacBio_fasta/README.txt`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/PacBio_MtSinai/raw_data/HG006.README`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/Strand-Seq_BCCRC/README`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/UCSC_Ultralong_OxfordNanopore_Promethion/README_ONT-UL_UCSC_HG006.md`
- `data/ChineseTrio/HG006_NA24694-huCA017E_father/stLFR/readme.txt`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/CompleteGenomics_normal_cellsDNA/README.txt`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/NA24695_Mother_HiSeq100x/NHGRI_Illumina100X_Chinesetrio_novoalign_bams/README`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/NA24695_Mother_HiSeq100x/README_NIST_Illumina_pairedend_NA24695.txt`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/NIST_Stanford_Illumina_6kb_matepair/README.NIST_Stanford_Illumina_6kb_matepair`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/PacBio_CCS_15kb_20kb_chemistry2/reads/README_PacBio-CCS_HudsonAlpha_HG007.md`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/PacBio_HiFi_Google/README_PacBio-CCS_Google_HG007.md`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/PacBio_MtSinai/HG007.README`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/Strand-Seq_BCCRC/README`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/UCSC_Ultralong_OxfordNanopore_Promethion/README_ONT-UL_UCSC_HG007.md`
- `data/ChineseTrio/HG007_NA24695-hu38168_mother/stLFR/readme.txt`
- `data/ChineseTrio/analysis/NIST_BGIseq_2x150bp_100x_07192023/README_NIST_BGISeq_100x_HG005_analysis.md`
- `data/NA12878/10XGenomics/10XGenomics_sizeselected/README_NISTStanford_10XSizeSelected_NA12878.txt`
- `data/NA12878/10XGenomics/README_10Xgenomes.txt`
- `data/NA12878/10Xgenomics_ChromiumGenome_LongRanger2.0_06202016/README`
- `data/NA12878/10Xgenomics_ChromiumGenome_LongRanger2.1_09302016/README`
- `data/NA12878/BGISEQ500/standard_library/readme.txt`
- `data/NA12878/CompleteGenomics_normal/README.txt`
- `data/NA12878/CompleteGenomics_normal_RMDNA/GS000025639-ASM/EXP/README.2.5.0.txt`
- `data/NA12878/CompleteGenomics_normal_RMDNA/README.txt`
- `data/NA12878/Element_AVITI_20240920/README_Element_20240920.md`
- `data/NA12878/Garvan_NA12878_HG001_HiSeq_Exome/Garvan_NA12878_HG001_HiSeq_Exome.README`
- `data/NA12878/HudsonAlpha_PacBio_CCS/README_PacBio-CCS_HudsonAlpha_HG001.md`
- `data/NA12878/MtSinai_BioNano/README.txt`
- `data/NA12878/NA12878_PacBio_MtSinai/README.txt`
- `data/NA12878/NIST_NA12878_HG001_HiSeq_300x/NHGRI_Illumina300X_novoalign_bams/README`
- `data/NA12878/NIST_NA12878_HG001_HiSeq_300x/README_NIST_Illumina_pairedend_NA12878.txt`
- `data/NA12878/NIST_NA12878_HG001_SOLID5500W/README_NIST_NA12878_HG001_SOLID5500W.txt`
- `data/NA12878/PacBio_SequelII_CCS_11kb/HG001_GRCh38/README.txt`
- `data/NA12878/PacBio_SequelII_CCS_11kb/README.txt`
- `data/NA12878/Ultralong_OxfordNanopore/NA12878-minion-ul-README.txt`
- `data/NA12878/analysis/10XGenomics_calls_08142015/README_10Xgenomes.txt`
- `data/NA12878/analysis/BilkentUni_IlluminaHiSeq_TARDIS_mrCaNaVar_01102020/README_HG001_010920`
- `data/NA12878/analysis/BilkentUni_IlluminaHiSeq_TARDIS_mrCaNaVar_01102020/README_HG001_TARDIS_012120`
- `data/NA12878/analysis/CLCBIO_Illumina300X_callsets_10012015/README.txt`
- `data/NA12878/analysis/CompleteGenomics_PublicGenomes_10152011/README.txt`
- `data/NA12878/analysis/CompleteGenomics_RMDNA_11272014/README.txt`
- `data/NA12878/analysis/CompleteGenomics_newLFR_CGAtools_06122015/README.txt`
- `data/NA12878/analysis/GIAB_integration/README.GIAB.v0.2.txt`
- `data/NA12878/analysis/INOVA_CytoSNP_850K_FinalReport_12082013/README`
- `data/NA12878/analysis/Illumina_PlatinumGenomes_NA12877_NA12878_09162015/README`
- `data/NA12878/analysis/IonTorrent_TVC_04302015/README.txt`
- `data/NA12878/analysis/IonTorrent_TVC_06302015/README.IonTorrent_TVC_06302015`
- `data/NA12878/analysis/Leicester_HipSTR_GangSTR_05182022/GangSTR/README.md`
- `data/NA12878/analysis/Leicester_HipSTR_GangSTR_05182022/HipSTR/README.md`
- `data/NA12878/analysis/Leicester_HipSTR_GangSTR_05182022/README.md`
- `data/NA12878/analysis/MPG_WhatsHap_phasing_07202017/README_WhatsHap`
- `data/NA12878/analysis/NIST_union_callsets_06172013/README.NIST.v2.18.txt`
- `data/NA12878/analysis/PacBio_CCS_15kb_20kb_chemistry2_042021/README.md`
- `data/NA12878/analysis/PacBio_pbsv_05212019/README.txt`
- `data/NA12878/analysis/RTG_Illumina_Segregation_Phasing_05122016/README.txt`
- `data/NA12878/analysis/RTG_small_variants_01132014/README.txt`
- `data/NA12878/ion_exome/README.txt`
- `data/NA12878/stLFR/readme.txt`
- `data_RNAseq/AshkenazimTrio/HG002_NA24385_son/Baylor_PacBio/README_RNAseq_Baylor_HG002_PacBio.md`
- `data_RNAseq/AshkenazimTrio/HG002_NA24385_son/Google_Illumina/README_RNAseq_Google_HG002-Ill.md`
- `data_RNAseq/AshkenazimTrio/HG002_NA24385_son/Google_PacBio/README_RNAseq_Google_HG002-PacBio.md`
- `data_RNAseq/AshkenazimTrio/HG002_NA24385_son/Mason_ONT-directRNA/README_Mason_ONT_HG002_data.md`
- `data_RNAseq/AshkenazimTrio/HG002_NA24385_son/PacBio_Pacbio-MASseq/README_NIST_PacBio-MASseq.md`
- `data_RNAseq/AshkenazimTrio/HG002_NA24385_son/UNC_Illumina/README_RNAseq_UNC_HG002_Ill.md`
- `data_RNAseq/AshkenazimTrio/HG004_NA24143_mother/Baylor_PacBio/README_RNAseq_Baylor_HG004_PacBio.md`
- `data_RNAseq/AshkenazimTrio/HG004_NA24143_mother/Google_Illumina/README_RNAseq_Google_HG004-Ill.md`
- `data_RNAseq/AshkenazimTrio/HG004_NA24143_mother/Google_PacBio/README_RNAseq_Google_HG004-PacBio.md`
- `data_RNAseq/AshkenazimTrio/HG004_NA24143_mother/Mason_ONT-directRNA/README_Mason_ONT_HG004_data.md`
- `data_RNAseq/AshkenazimTrio/HG004_NA24143_mother/UNC_Illumina/README_RNAseq_UNC_HG004_Ill.md`
- `data_RNAseq/ChineseTrio/HG005_NA24631_son/Baylor_PacBio/README_RNAseq_Baylor_HG005_PacBio.md`
- `data_RNAseq/ChineseTrio/HG005_NA24631_son/Google_Illumina/README_RNAseq_Google_HG005-Ill.md`
- `data_RNAseq/ChineseTrio/HG005_NA24631_son/Google_PacBio/README_RNAseq_Google_HG005-PacBio.md`
- `data_RNAseq/ChineseTrio/HG005_NA24631_son/Mason_ONT-directRNA/README_Mason_ONT_HG005_data.md`
- `data_RNAseq/ChineseTrio/HG005_NA24631_son/UNC_Illumina/README_RNAseq_UNC_HG005_Ill.md`
- `data_somatic/HG008/Liss_lab/Arima_HiC-ILMN_20240112/README_Arima.md`
- `data_somatic/HG008/Liss_lab/BCM_ILMN-WGS_20251124/README.md`
- `data_somatic/HG008/Liss_lab/BCM_Illumina-WGS_20240313/README_BCM_ILMN.md`
- `data_somatic/HG008/Liss_lab/BCM_Revio_20240313/README_BCM_Revio.md`
- `data_somatic/HG008/Liss_lab/Bionano_OpticalMapping_20231019/README_Bionano.md`
- `data_somatic/HG008/Liss_lab/Bioskryb_ResolveDNA_20230914/README_Bioskryb.md`
- `data_somatic/HG008/Liss_lab/Dovetail_LinkPrep-ILMN_HG8NP_20250625/README_20250625.md`
- `data_somatic/HG008/Liss_lab/Element-AVITI-20241216/README_Element_20241216.md`
- `data_somatic/HG008/Liss_lab/Element_AVITI_20240118/README_Element_20240118.md`
- `data_somatic/HG008/Liss_lab/Element_AVITI_20240626/README_Element_20240626.md`
- `data_somatic/HG008/Liss_lab/HG008-T_bioskryb-libraries-UG100/README_Bioskryb-Ultima.md`
- `data_somatic/HG008/Liss_lab/NYGC_Illumina-WGS_20231023/README_NYGC.md`
- `data_somatic/HG008/Liss_lab/Northeastern-ONT-UL-20241216/Northeastern-ONT-UL-20241216.md`
- `data_somatic/HG008/Liss_lab/Northeastern_ONT-std_20240422/README_NE_ONT-std.md`
- `data_somatic/HG008/Liss_lab/PacBio_Onso_20240415/README_PacBio_Onso.md`
- `data_somatic/HG008/Liss_lab/PacBio_Revio_20240125/README_PacBio-Revio.md`
- `data_somatic/HG008/Liss_lab/README`
- `data_somatic/HG008/Liss_lab/UCSC_ONT-UL_20231207/README_UCSC_ONT-UL.md`
- `data_somatic/HG008/Liss_lab/UCSC_ONT_20231003/README_UCSC_ONT-std.md`
- `data_somatic/HG008/Liss_lab/Ultima-ppmSeq-UG100-20241028/README_ppmSeq_20241028.md`
- `data_somatic/HG008/Liss_lab/Ultima_UG100-WGS_20240530/README_Ultima.md`
- `data_somatic/HG008/Liss_lab/analysis/BCM_HiFi_ONT_Sniffles-v2.2_02282024/BCM_Sniffles_README.md`
- `data_somatic/HG008/Liss_lab/analysis/BCM_Revio_20240313/pacbio-wgs-wdl_somatic_20240601/README_BCM_Revio_analysis.md`
- `data_somatic/HG008/Liss_lab/analysis/Bionano_OpticalMapping-analysis_20231019/README_Bionano.md`
- `data_somatic/HG008/Liss_lab/analysis/Bioskryb_ResolveDNA-analysis_20230914/README_Bioskryb.md`
- `data_somatic/HG008/Liss_lab/analysis/DRAGEN-v4.2.4_ILMN-WGS_20240312/README_DRAGEN_20240312.md`
- `data_somatic/HG008/Liss_lab/analysis/HG008_ancestry_analysis/README_HG008_ancestry_analysis.md`
- `data_somatic/HG008/Liss_lab/analysis/HKU_HiFi_ClairS_v0.1.7-SNV-INDEL_20240326/README_HKU_ClairS.md`
- `data_somatic/HG008/Liss_lab/analysis/Harvard_Cheng_hifiasm-assemblies_20240317/README_hifiasm.md`
- `data_somatic/HG008/Liss_lab/analysis/Harvard_Cheng_hifiasm-assemblies_20240509/README_hifiasm_20240509.md`
- `data_somatic/HG008/Liss_lab/analysis/NCBI_Element_WGS_Somatic_SVs_GRIDSS2_20240430/README_Element_gridss2_ncbi_20240430`
- `data_somatic/HG008/Liss_lab/analysis/NCBI_Illumina_WGS_BCM_Somatic_SVs_GRIDSS2_Passage23_20240510/README_Illumina_Passage23_gridss2_ncbi_20240510`
- `data_somatic/HG008/Liss_lab/analysis/NIH-NCI_minda-ensemble_20240710/README_minda_20240710.md`
- `data_somatic/HG008/Liss_lab/analysis/NIH_HiFi-HiC_Wakhan-CNA_20240424/README_NIH_Wakhan-HIFi-HiC.md`
- `data_somatic/HG008/Liss_lab/analysis/NIH_HiFi_Severus-SV_20240308/README_NIH_Severus.md`
- `data_somatic/HG008/Liss_lab/analysis/NIH_HiFi_Wakhan-CNA_20240308/README_NIH_Wakhan.md`
- `data_somatic/HG008/Liss_lab/analysis/NIH_HiFi_mm2_mapping/README_NIH_HiFi-mm2.md`
- `data_somatic/HG008/Liss_lab/analysis/NIST_HG008-T_somatic-stvar_DraftBenchmark_V0.1-20241219/README.md`
- `data_somatic/HG008/Liss_lab/analysis/NIST_HG008-T_somatic-stvar_DraftBenchmark_V0.2-20250110/README.md`
- `data_somatic/HG008/Liss_lab/analysis/NIST_HG008-T_somatic-stvar_DraftBenchmark_V0.3-20250220/README.md`
- `data_somatic/HG008/Liss_lab/analysis/NYGC-somatic-pipeline_20240412/README_NYGC.md`
- `data_somatic/HG008/Liss_lab/analysis/PacBio_Revio_20240125/pacbio-wgs-wdl_germline_20240206/README_PacBio_Revio_analysis.md`
- `data_somatic/HG008/Liss_lab/analysis/UCSC_HiFi_DeepSomatic-SNV-INDEL_20240308/README_UCSC_DeepSomatic.md`
- `data_somatic/HG008/Liss_lab/analysis/Ultima_DeepVariant-somatic-SNV-INDEL_20240822/README_Ultima_DeepVariant-somatic.md`
- `data_somatic/HG008/Liss_lab/analysis/Verkko_assemblies_05162024/HG008N_hifi_plus_hic_verkko_v2.0/README`
- `data_somatic/HG008/Liss_lab/analysis/Verkko_assemblies_05162024/HG008T/HG008T_verkko_v2.0/README`
- `data_somatic/HG008/Liss_lab/other_passages/BCM_ILMN-HG008Tp13_20250521/README_p13_20250521.md`
- `data_somatic/HG008/Liss_lab/other_passages/BCM_ILMN-HG008Tp2_20250521/README_p2_20250521.md`
- `data_somatic/HG008/Liss_lab/other_passages/BCM_ONT-std_HG008T-p2_20260313/README_BCM-ONT-std_HG008T-p2_20260313.md`
- `data_somatic/HG008/Liss_lab/other_passages/analysis/GRCh38/BCM_ONT-std_HG008T-p2_20260313/HG008-T_vs_HG008-N-P/README_HG008-T_vs_HG008-N-P_ONT.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/BCM_ILMN-somatic-analysis_20220816/README_BCM.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/KaryoLogic_20220309/README_KaryoLogic.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/PhaseGenomics_HiC_20220629/README_PhaseGenomics.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/BCM_Illumina_WGS_20220816/Manta_results/readme.txt`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/BCM_Illumina_WGS_20220816/README_BCM.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/DRAGEN-v4.2.4_ILMN-WGS_20230914/README_DRAGEN.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/DRAGEN-v4.2.4_ILMN-WGS_20230914/annotations/README_DRAGEN_annotations.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/HKU_ILMN_ClairS_v0.1.7-SNV-INDEL_20240326/README_HKU_ClairS.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/NCBI_Illumina_WGS_Somatic_SVs_GRIDSS2_20240430/README_Illumina_gridss2_ncbi_20240430`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/NIST-Year1_BCM-ILMN-WGS_2022/README_NIST-year1-analysis.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/PhaseGenomics_HiC_20220629/README_PhaseGenomics-analysis.md`
- `data_somatic/HG008/Liss_lab/superseded-2022-data/analysis/UCSC_ILMN_DeepSomatic-SNV-INDEL_20240308/README_UCSC_DeepSomatic.md`
- `data_somatic/HG008/NIST/HG008-T_bulk/20240508p18/KaryoLogic_20240612/README_KaryoLogic.md`
- `data_somatic/HG008/NIST/HG008-T_bulk/20240508p21/KromaTiD-dGH_20241029/README_KromaTiD_20241029.md`
- `data_somatic/HG008/NIST/HG008-T_bulk/20240508p21/UMD-Revio-HG008Tp21-20241011/README_UMD-Revio-HG008Tp21andp41.md`
- `data_somatic/HG008/NIST/HG008-T_bulk/20240508p41/UMD-Revio-HG008Tp41-20241011/README_UMD-Revio-HG008Tp21andp41.md`
- `data_somatic/HG008/NIST/HG008-T_bulk/20240508p53/KromaTiD-dGH_20241029/README`
- `data_somatic/HG008/NIST/HG008-T_clones/20240508p19/SC14/p20plus11/KaryoLogic_20241028/README_KaryoLogic_20241028.md`
- `data_somatic/HG008/NIST/README`
- `data_somatic/HG008/README_HG008.md`
- `data_somatic/HG009/NIST/HG009-N_bulk/20250728p25/BCM_Revio_HG009N-WT-p25_20260313/README_BCM_Revio_HG009N-WT-p25_20260313.md`
- `data_somatic/HG009/NIST/HG009-N_bulk/20250728p25/analysis/GRCh38/BCM_Revio_HG009N-WT-p25_20260313/HG009-N-WT-p25_vs_HG009-N-WT-p4/README_HG009-N-WT-p25_vs_HG009-N-WT-p4.md`
- `data_somatic/HG009/NIST/HG009-N_bulk/20250728p4/BCM_Revio_HG009N-WT-p4_20260313/README_BCM_Revio_HG009N-WT-p4_20260313.md`
- `data_somatic/HG009/NIST/HG009-N_bulk/20250805p23/BCM_Revio_HG009N-LVTert-p23_20260313/README_BCM_Revio_HG009N-LVTert-p23_20260313.md`
- `data_somatic/HG009/NIST/HG009-T_bulk/20250715p16/BCM_Revio_HG009T-p16_20260313/README_BCM_Revio_HG009T-p16_20260313.md`
- `data_somatic/HG009/NIST/HG009-T_bulk/20250715p42/BCM_Revio_HG009T-p42_20260313/README_BCM_Revio_HG009T-p42_20260313.md`
- `data_somatic/HG009/NIST/HG009-T_clones/20250918p14/1C3/p15plus7/BCM_Revio_HG009T-1C3_20260313/README_BCM_Revio_HG009T-1C3_20260313.md`
- `data_somatic/HG009/NIST/HG009-T_clones/20250918p14/1C3/p15plus7/analysis/GRCh38/BCM_Revio_HG009T-1C3_20260313/HG009-T-1C3_vs_HG009-N-WT-p4/README_HG009-T-1C3_vs_HG009-N-WT-p4.md`
- `data_somatic/HG009/NIST/HG009-T_clones/20250918p14/1D5/p15plus7/BCM_Revio_HG009T-1D5_20260313/README_BCM_Revio_HG009T-1D5_20260313.md`
- `data_somatic/HG009/NIST/HG009-T_clones/20250918p14/3C4/p15plus8/BCM_Revio_HG009T-3C4_20260313/README_BCM_Revio_HG009T-3C4_20260313.md`
- `data_somatic/HG009/NIST/HG009-T_clones/20250918p14/3C9/p15plus7/BCM_Revio_HG009T-3C9_20260313/README_BCM_Revio_HG009T-3C9_20260313.md`
- `data_somatic/HG009/NIST/HG009-T_clones/20250918p14/3F2/p15plus7/BCM_Revio_HG009T-3F2_20260313/README_BCM_Revio_HG009T-3F2_20260313.md`
- `data_somatic/HG009/NIST/HG009-T_clones/20250918p14/4G9/p15plus7/BCM_Revio_HG009T-4G9_20260313/README_BCM_Revio_HG009T-4G9_20260313.md`
- `release/AshkenazimTrio/HG002_NA24385_son/CMRG_v1.00/README_GIAB_medical_gene_benchmark.md`
- `release/AshkenazimTrio/HG002_NA24385_son/NIST_SV_v0.6/GIAB_Evaluations/SVRefine_v0.6_TruvariReports_NFH/README.txt`
- `release/AshkenazimTrio/HG002_NA24385_son/NIST_SV_v0.6/GIAB_Evaluations/SpiralBGA_v0.6_TruvariBench/README.txt`
- `release/AshkenazimTrio/HG002_NA24385_son/NIST_SV_v0.6/README_SV_v0.6.txt`
- `release/AshkenazimTrio/HG002_NA24385_son/NISTv3.2.1/README_NISTv3.2.1.txt`
- `release/AshkenazimTrio/HG002_NA24385_son/NISTv3.3.2/README_NISTv3.3.2.txt`
- `release/AshkenazimTrio/HG002_NA24385_son/NISTv4.1/README_v4.1.txt`
- `release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/README_v4.2.1.txt`
- `release/AshkenazimTrio/HG002_NA24385_son/TandemRepeats_v1.0/GRCh38/README.md`
- `release/AshkenazimTrio/HG002_NA24385_son/chrXY_v1.0/GRCh38/SmallVariant/README_chrXY-smVar_Benchmark.md`
- `release/AshkenazimTrio/HG002_NA24385_son/chrXY_v1.0/GRCh38/SmallVariant/README_chrXY-smVar_Benchmark.md (chrXY 콜셋 문서 탐색 중 확인 — ncbi_chrXY_var_03302023을 다루지 않아 근거로 쓰지 않음)`
- `release/AshkenazimTrio/HG002_NA24385_son/mosaic_v1.00/GRCh38/SNV/README.md`
- `release/AshkenazimTrio/HG002_NA24385_son/mosaic_v1.10/GRCh38/SNV/README.md`
- `release/NA12878_HG001/GIABPedigreev0.2/README.GIAB.v0.2.txt`
- `release/NA12878_HG001/NISTv2.15/README.NIST.v2.15.txt`
- `release/NA12878_HG001/NISTv2.17/README.NIST.v2.17.txt`
- `release/NA12878_HG001/NISTv2.18/README.NIST.v2.18.txt`
- `release/NA12878_HG001/NISTv2.19/README.NIST.v2.19.txt`
- `release/NA12878_HG001/NISTv3.2.1/README_NISTv3.2.1.txt`
- `release/NA12878_HG001/NISTv3.2/README_NISTv3.2.txt`
- `release/NA12878_HG001/NISTv3.3.1/GRCh37/README_NISTv3.3.1.txt`
- `release/genome-stratifications/v2.0/GRCh37/GenomeSpecific/v2.0-GRCh37-GenomeSpecific-README.txt`
- `release/genome-stratifications/v2.0/v2.0-stratification-BEDs-README.txt`
- `release/genome-stratifications/v3.0/GIAB-v3.0-stratifications-README.md`
- `release/genome-stratifications/v3.0/GRCh37/GenomeSpecific/GRCh37-GenomeSpecific-README.md`
- `release/genome-stratifications/v3.0/GRCh38/GenomeSpecific/GRCh38-GenomeSpecific-README.md`
- `release/genome-stratifications/v3.1/GRCh37/GenomeSpecific/GRCh37-GenomeSpecific-README.md`
- `release/genome-stratifications/v3.1/README.md`
- `release/genome-stratifications/v3.2/README.md`
- `release/genome-stratifications/v3.5/GRCh37@all/GenomeSpecific/GRCh37_GenomeSpecific_README.md`
- `release/genome-stratifications/v3.5/GRCh38@all/LowComplexity/GRCh38_LowComplexity_README.md`
- `release/genome-stratifications/v3.5/GRCh38@all/Mappability/GRCh38_Mappability_README.md`
- `release/genome-stratifications/v3.5/HG002.mat@all/Diploid/HG002.mat_Diploid_README.md`
- `release/genome-stratifications/v3.5/README.md`
- `release/references/GRCh37/resources/hg19.README_annotation.md`
- `release/references/README_GIAB_Mapping_References.md`

</details>

