#!/usr/bin/env python3
"""phase0 manifests -> 2차 파이프라인 입력 samplesheets + more_run_table.tsv (로컬에서 실행, 결정론적).

2026-09-23 사용자 지시 "GIAB 의 모든 숏리드 데이터는 국통바빅 파이프라인으로 돌아야 한다"에 따라, 1차(HG002/3/4 22 샘플,
make_samplesheets.py + 03_make_pipeline_dirs.py)에 없던 표준 short-read WGS를 전부 넣는다.

    python phase3_shortread_wgs/scripts/make_more_samplesheets.py            # samplesheets/<dsid>.csv + more_run_table.tsv
    DATA_ROOT=/other/root python .../make_more_samplesheets.py                # 절대경로 접두 변경

산출물은 1차와 같은 형식이다(sample,dataset,unit,fastq_1,fastq_2,bytes). 03_make_pipeline_dirs.py가 more_run_table.tsv의
set/label 열을 읽어 디렉토리를 만든다 — 이 표에 있는 dsid는 DIRNAME(1차 규칙) 대신 여기 적힌 set 디렉토리로 간다.

**새 샘플은 1차 set 디렉토리에 절대 넣지 않는다.** 1차 8세트는 파이프라인이 이미 돌았거나(Success/Error) 돌고 있다.
같은 dataset이라도 코호트 접미(-NA12878 / -ChineseTrio)를 붙인 새 set으로 보낸다. 03은 파이프라인 흔적(__DONE__, tmp/, .snakemake/)이
있는 set에 새 샘플 dir을 만들려고 하면 멈춘다.

tier:
  germline — NIST v4.2.1 정답셋이 있는 HG001~HG007. 국통바빅 결과를 바로 채점할 수 있다
  somatic  — HG008/HG009. germline 정답셋이 없어 국통바빅 결과는 QC·정렬까지만 쓰고, 채점은 nf-core somatic 경로(backlog #9) 몫
뺀 것(이유는 EXCLUDED): mate-pair·Moleculo·10X·stLFR·Hi-C·Strand-seq·엑솜, BGISEQ500 PE50(fastp length_required 70에 전부 걸림),
HG008 Element 20240118(README가 superseded R&D 화학이라고 적음), MissionBio Tapestri(표적 단일세포), superseded-2022.
"""
import csv, os, re, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE); REPO = os.path.dirname(ROOT)
MANIFESTS = os.path.join(REPO, "phase0_download", "manifests")
DATA_ROOT = os.environ.get("DATA_ROOT", "/BiO/scratch/ehojune/GIAB_benchmark")
GIB = 1024 ** 3

# 성별: HG001~007은 GIAB 문서. HG008은 BCM README "Donor Biological Sex: female". HG009는 README에 없어 phase1 HiFi BAM의
# idxstats로 쟀다(2026-09-23, chrX/chr1 깊이비 0.97~1.03, chrY/chr1 0.07~0.08 — 남성 대조 HG002 0.38/1.12). 둘 다 female.
SEX = {"HG001": "female", "HG002": "male", "HG003": "male", "HG004": "female", "HG005": "male", "HG006": "male",
       "HG007": "female", "HG008": "female", "HG009": "female"}
TRUTH = {
    "HG001": "release/NA12878_HG001/NISTv4.2.1/GRCh38/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
    "HG002": "release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
    "HG005": "release/ChineseTrio/HG005_NA24631_son/NISTv4.2.1/GRCh38/HG005_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
    "HG006": "release/ChineseTrio/HG006_NA24694_father/NISTv4.2.1/GRCh38/HG006_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
    "HG007": "release/ChineseTrio/HG007_NA24695_mother/NISTv4.2.1/GRCh38/HG007_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
}

A2 = "data/AshkenazimTrio/HG002_NA24385_son"
C5 = "data/ChineseTrio/HG005_NA24631_son"
C6 = "data/ChineseTrio/HG006_NA24694-huCA017E_father"
C7 = "data/ChineseTrio/HG007_NA24695-hu38168_mother"
H1 = "data/NA12878"
L8 = "data_somatic/HG008/Liss_lab"
N8 = "data_somatic/HG008/NIST"
N9 = "data_somatic/HG009/NIST"
FQ = r"\.(fastq|fq)\.gz$"


def run(set_, label, dataset, pattern, expect, platform, read_len, note="", tier=None, existing=False):
    hg = label.split("-")[0]
    return dict(set=set_, label=label, hg=hg, dataset=dataset, dsid=f"{label}.{dataset}", pattern=pattern, expect=expect,
                platform=platform, read_len=read_len, note=note, existing=existing,
                tier=tier or ("somatic" if hg in ("HG008", "HG009") else "germline"))


def nist8(label, rel, n):   # HG008 NIST 트리(BCM NovaSeq X) — 벌크 passage·클론
    return run("HG008-NovaseqX-" + ("clones" if "clones" in rel else "bulk"), label, "BCM_NovaSeqX",
               rf"^{N8}/{rel}/[^/]+{FQ}", n, "Illumina NovaSeq X 2x151 PCR-free (BCM)", "151")


def nist9(label, rel, n, note=""):   # HG009 NIST 트리(BCM NovaSeq X 25B, 20260413 한 배치)
    return run("HG009-NovaseqX-" + ("clones" if "clones" in rel else "bulk"), label, "BCM_NovaSeqX",
               rf"^{N9}/{rel}/[^/]+{FQ}", n, "Illumina NovaSeq X 25B PCR-free KAPA HyperPrep (BCM)", "151",
               note or "카탈로그는 2x125 로 적었으나 리드 헤더 실측(2026-09-23)은 151")


# 한 항목 = 파이프라인 샘플 하나 = samplesheet 하나. pattern은 manifest 상대경로 전체에 대한 정규식, expect는 파일 수(R1+R2) —
# 어긋나면 생성이 멈춘다. read_len은 2026-09-23 첫 리드 실측(nbb2). set 이름·label은 `_` 금지(파이프라인이 `_`로 자른다).
RUNS = [
    # ---- germline: 1차에 samplesheet는 있었지만 디렉토리를 안 만든 HG002 두 세트 (make_samplesheets.py 소유 시트를 그대로 쓴다)
    run("NIST-BGIseq-100x", "HG002", "NIST_BGIseq_2x150_100x", None, 30, "MGI DNBSEQ 2x150 (V350038332)", "150", existing=True),
    run("Element-AVITI-2023", "HG002", "Element_AVITI_20231018", None, 4, "Element AVITI 2x150 Std+Lng insert", "150", existing=True,
        note="StdInsert 81x + LngInsert 55x — 1차 Element-AVITI(2024)와 같은 규칙으로 한 쌍에 병합(인서트 이봉)"),
    # ---- germline: HG001 (NA12878). 1차 set과 이름이 겹치지 않게 -NA12878
    run("Hiseq-300x-NA12878", "HG001", "HiSeq300x", rf"^{H1}/NIST_NA12878_HG001_HiSeq_300x/.+_R[12]_\d{{3}}{FQ}", 1742,
        "Illumina HiSeq 2500 2x148 (D00360, RM8398)", "148", note="HG002~4 Homogeneity 300x와 같은 설계(플로우셀 × Sample_U* 라이브러리)"),
    run("BGISEQ500-NA12878", "HG001", "BGISEQ500", rf"^{H1}/BGISEQ500/BGISEQ500_PCRfree_NA12878_[^/]+_read_[12]{FQ}", 4,
        "BGISEQ-500 PCR-free PE100", "100"),
    run("BGISEQ500-NA12878", "HG001-stdlib", "BGISEQ500_stdlib", rf"^{H1}/BGISEQ500/standard_library/ERR\d+_[12]{FQ}", 4,
        "BGISEQ-500 standard(PCR) library PE100, ENA 재배포 ERR1799697/8", "100",
        note="같은 디렉토리의 CL100004823(PE50)는 fastp length_required 70에 전부 걸려 뺐다"),
    run("MGISEQ2000-PCRfree-NA12878", "HG001", "MGISEQ2000_PCRfree", rf"^{H1}/MGISEQ/NA12878_[12]/[^/]+_[12]\.fq\.gz$", 8,
        "MGISEQ-2000 PCR-free 2x150", "150", note="라이브러리 2개(NA12878_1, _2) 병합 — 1차 HG004와 같은 처리"),
    run("Element-AVITI-NA12878", "HG001", "Element_AVITI_20240920", rf"^{H1}/Element_AVITI_20240920/[^/]+/[^/]+_R[12]{FQ}", 4,
        "Element AVITI 2x150 Std+Lng insert", "150"),
    # ---- germline: ChineseTrio. 새 dataset(100x, 2x250 300x, NIST-BGIseq)은 접미 없이, 1차와 겹치는 dataset은 -ChineseTrio
    run("NIST-BGIseq-100x", "HG005", "NIST_BGIseq_2x150_100x", rf"^{C5}/NIST_BGIseq_2x150bp_100x/.+{FQ}", 30,
        "MGI DNBSEQ 2x150 (V350038332/V350038580)", "150"),
    run("Hiseq-250PE-300x", "HG005", "HiSeq300x_2x250", rf"^{C5}/HG005_NA24631_son_HiSeq_300x/.+{FQ}", 336,
        "Illumina HiSeq 2500 2x250 (D00360, basespace)", "250", note="1차 Hiseq-300x(2x148)와 리드 길이가 달라 별도 set"),
    run("Hiseq-100x", "HG006", "HiSeq100x", rf"^{C6}/NA24694_Father_HiSeq100x/.+{FQ}", 600, "Illumina HiSeq 2500 2x148", "148"),
    run("Hiseq-100x", "HG007", "HiSeq100x", rf"^{C7}/NA24695_Mother_HiSeq100x/.+{FQ}", 612, "Illumina HiSeq 2500 2x148", "148"),
    run("BGISEQ500-ChineseTrio", "HG005", "BGISEQ500", rf"^{C5}/BGISEQ500/[^/]+_read_[12]{FQ}", 4, "BGISEQ-500 PCR-free PE100", "100"),
    run("BGISEQ500-ChineseTrio", "HG006", "BGISEQ500", rf"^{C6}/BGISEQ500/[^/]+_read_[12]{FQ}", 4, "BGISEQ-500 PCR-free PE100", "100"),
    run("BGISEQ500-ChineseTrio", "HG007", "BGISEQ500", rf"^{C7}/BGISEQ500/[^/]+_read_[12]{FQ}", 4, "BGISEQ-500 PCR-free PE100", "100"),
    run("MGISEQ2000-PCRfree-ChineseTrio", "HG005", "MGISEQ2000_PCRfree", rf"^{C5}/MGISEQ/PCR-free/.+_[12]\.fq\.gz$", 4, "MGISEQ-2000 PCR-free 2x150", "150"),
    run("Element-AVITI-ChineseTrio", "HG005", "Element_AVITI_20240920", rf"^{C5}/Element_AVITI_20240920/[^/]+/[^/]+_R[12]{FQ}", 4,
        "Element AVITI 2x150 Std+Lng insert", "150"),
    # ---- somatic HG008: Liss_lab 배치별 T/N (같은 배치 안에 짝이 있다)
    run("HG008-Illumina-BCM-2024", "HG008-T", "BCM_Illumina_2024", rf"^{L8}/BCM_Illumina-WGS_20240313/HG008-T_fastqs/[^/]+{FQ}", 8,
        "Illumina NovaSeq 6000 2x151 PCR-free (BCM)", "151"),
    run("HG008-Illumina-BCM-2024", "HG008-N-D", "BCM_Illumina_2024", rf"^{L8}/BCM_Illumina-WGS_20240313/HG008-N-D_fastqs/[^/]+{FQ}", 2,
        "Illumina NovaSeq 6000 2x151 PCR-free (BCM)", "151", note="README 본문에 N-P 조직 언급이 있으나 GIAB 디렉토리 이름(N-D)을 따른다"),
    run("HG008-Illumina-NYGC-2023", "HG008-T", "NYGC_Illumina_2023", rf"^{L8}/NYGC_Illumina-WGS_20231023/HG008-T_[^/]+{FQ}", 24,
        "Illumina NovaSeq 6000 2x150 TruSeq UDI (NYGC)", "150"),
    run("HG008-Illumina-NYGC-2023", "HG008-N-D", "NYGC_Illumina_2023", rf"^{L8}/NYGC_Illumina-WGS_20231023/HG008-N-D_[^/]+{FQ}", 24,
        "Illumina NovaSeq 6000 2x150 TruSeq UDI (NYGC)", "150"),
    run("HG008-NovaseqX-bulk", "HG008-N-D", "BCM_NovaSeqX", rf"^{L8}/BCM_ILMN-WGS_20251124/[^/]+{FQ}", 8,
        "Illumina NovaSeq X 2x151 PCR-free (BCM)", "151", note="라이브러리 2개(ILMN-PCR-free-9a/9b, 335190_3/_4) 병합 — 아래 T 벌크·passage와 같은 기종"),
    run("HG008-NovaseqX-bulk", "HG008-T-p2", "BCM_NovaSeqX", rf"^{L8}/other_passages/BCM_ILMN-HG008Tp2_20250521/[^/]+{FQ}", 4,
        "Illumina NovaSeq X 2x151 PCR-free (BCM)", "151"),
    run("HG008-NovaseqX-bulk", "HG008-T-p13", "BCM_NovaSeqX", rf"^{L8}/other_passages/BCM_ILMN-HG008Tp13_20250521/[^/]+{FQ}", 4,
        "Illumina NovaSeq X 2x151 PCR-free (BCM)", "151"),
    nist8("HG008-T-p21", "HG008-T_bulk/20240508p21/BCM_ILMN-HG008Tp21_20250521", 4),
    nist8("HG008-T-p41", "HG008-T_bulk/20240508p41/BCM_ILMN-HG008Tp41_20250521", 4),
    nist8("HG008-T-p100", "HG008-T_bulk/20240508p100/BCM_ILMN-HG008Tp100_20250904", 8),
    nist8("HG008-T-2D6", "HG008-T_clones/20240718p14/2D6/p15plus12/BCM_ILMN_HG8T-2D6-p15plus12_20250904", 6),
    nist8("HG008-T-2E6", "HG008-T_clones/20240718p14/2E6/p15plus11/BCM_ILMN_HG8T-2E6-p15plus11_20250904", 8),
    nist8("HG008-T-3E4", "HG008-T_clones/20240718p14/3E4/p15plus11/BCM_ILMN_HG8T-3E4-p15plus11_20250904", 8),
    nist8("HG008-T-SC6", "HG008-T_clones/20240805p19/SC6/p20plus15/BCM_ILMN_HG8T-SC6-p20plus15_20250904", 8),
    nist8("HG008-T-SC9", "HG008-T_clones/20240805p19/SC9/p20plus13/BCM_ILMN_HG8T-SC9-p20plus13_20250904", 8),
    nist8("HG008-T-SC14", "HG008-T_clones/20240805p19/SC14/p20plus13/BCM_ILMN_HG8T-SC14-p20plus13_20250904", 8),
    nist8("HG008-T-SC24", "HG008-T_clones/20240805p19/SC24/p20plus8/BCM_ILMN_HG8T-SC24-p20plus8_20250904", 8),
    nist8("HG008-T-SC28", "HG008-T_clones/20240805p19/SC28/p20plus7/BCM_ILMN_HG8T-SC28-p20plus7_20250904", 8),
    # Element 20240626: README가 short=POR_*(KOL-0801/0803), long=*_Long(KOL-0806). PDAC3066 = 종양 세포주(HG008-T)
    run("HG008-Element-AVITI-202406", "HG008-T", "Element_AVITI_20240626",
        rf"^{L8}/Element_AVITI_20240626/HG008_(Std|Lng)Insert_Fastqs/(POR_PDAC3066|PDAC3066_Long)_R[12]{FQ}", 4, "Element AVITI UltraQ Std+Lng insert", "150"),
    run("HG008-Element-AVITI-202406", "HG008-N-D", "Element_AVITI_20240626",
        rf"^{L8}/Element_AVITI_20240626/HG008_(Std|Lng)Insert_Fastqs/(POR_NormalDuodenum|ND_Long)_R[12]{FQ}", 4, "Element AVITI UltraQ Std+Lng insert", "150"),
    run("HG008-Element-AVITI-202406", "HG008-N-P", "Element_AVITI_20240626",
        rf"^{L8}/Element_AVITI_20240626/HG008_(Std|Lng)Insert_Fastqs/(POR_NP|NP_Long)_R[12]{FQ}", 4, "Element AVITI UltraQ Std+Lng insert", "150"),
    run("HG008-Element-AVITI-202412", "HG008-T", "Element_AVITI_20241216", rf"^{L8}/Element-AVITI-20241216/HG008-T_fastqs/[^/]+{FQ}", 2,
        "Element AVITI UltraQ", "150"),
    run("HG008-Element-AVITI-202412", "HG008-N-D", "Element_AVITI_20241216", rf"^{L8}/Element-AVITI-20241216/HG008-N-D_fastqs/[^/]+{FQ}", 2,
        "Element AVITI UltraQ", "150"),
    run("HG008-Element-AVITI-202412", "HG008-N-P", "Element_AVITI_20241216", rf"^{L8}/Element-AVITI-20241216/HG008-N-P_fastqs/[^/]+{FQ}", 2,
        "Element AVITI UltraQ", "150"),
    run("HG008-Onso", "HG008-T", "PacBio_Onso_20240415", rf"^{L8}/PacBio_Onso_20240415/HG008-T_R[12]_trimmed{FQ}", 2,
        "PacBio Onso SBB 2x150 (배포처 트리밍, 가변 길이)", "≤150"),
    run("HG008-Onso", "HG008-N-D", "PacBio_Onso_20240415", rf"^{L8}/PacBio_Onso_20240415/HG008-ND_R[12]_trimmed{FQ}", 2,
        "PacBio Onso SBB 2x150 (배포처 트리밍, 가변 길이)", "≤150"),
    # ---- somatic HG009: NIST 트리, 한 배치(BCM 20260413)에 정상 벌크 3 + 종양 벌크 2 + 클론 6
    nist9("HG009-N-WT-p4", "HG009-N_bulk/20250728p4/BCM_NovaSeqX_HG009N-WT-p4_20260413", 8),
    nist9("HG009-N-WT-p25", "HG009-N_bulk/20250728p25/BCM_NovaSeqX_HG009N-WT-p25_20260413", 8),
    nist9("HG009-N-LVTert-p23", "HG009-N_bulk/20250805p23/BCM_NovaSeqX_HG009N-LVTert-p23_20260413", 8),
    nist9("HG009-T-p16", "HG009-T_bulk/20250715p16/BCM_NovaSeqX_HG009T-p16_20260413", 8),
    nist9("HG009-T-p42", "HG009-T_bulk/20250715p42/BCM_NovaSeqX_HG009T-p42_20260413", 8),
    nist9("HG009-T-1C3", "HG009-T_clones/20250918p14/1C3/p15plus7/BCM_NovaSeqX_HG009T-1C3_20260413", 8),
    nist9("HG009-T-1D5", "HG009-T_clones/20250918p14/1D5/p15plus7/BCM_NovaSeqX_HG009T-1D5_20260413", 8),
    nist9("HG009-T-3C4", "HG009-T_clones/20250918p14/3C4/p15plus8/BCM_NovaSeqX_HG009T-3C4_20260413", 2),
    nist9("HG009-T-3C9", "HG009-T_clones/20250918p14/3C9/p15plus7/BCM_NovaSeqX_HG009T-3C9_20260413", 8),
    nist9("HG009-T-3F2", "HG009-T_clones/20250918p14/3F2/p15plus7/BCM_NovaSeqX_HG009T-3F2_20260413", 8),
    nist9("HG009-T-4G9", "HG009-T_clones/20250918p14/4G9/p15plus7/BCM_NovaSeqX_HG009T-4G9_20260413", 8),
]

# mate 표지. 앞에서부터 처음 맞는 것을 쓴다(순서 중요: _R1_001 이 _1 보다 먼저).
MATE_PATS = [r"_R([12])_(\d{3})\.fastq\.gz$", r"_R([12])_trimmed\.fastq\.gz$", r"_R([12])\.fastq\.gz$", r"\.R([12])\.fastq\.gz$",
             r"_read_([12])\.fq\.gz$", r"_([12])\.fq\.gz$", r"_([12])\.fastq\.gz$"]


def mate_key(rel):
    d, f = os.path.split(rel)
    for i, pat in enumerate(MATE_PATS):
        m = re.search(pat, f)
        if m:
            split = m.group(2) if m.lastindex == 2 else ""
            return (d, f[:m.start()], i, split), int(m.group(1))
    raise ValueError(f"mate 표지를 못 찾음: {rel}")


def load_manifest(sample_dir):
    rows = []
    for fn in sorted(os.listdir(os.path.join(MANIFESTS, sample_dir))):
        if not fn.endswith(".tsv"):
            continue
        for line in open(os.path.join(MANIFESTS, sample_dir, fn), encoding="utf-8"):
            if line.startswith("#") or not line.strip():
                continue
            p = line.rstrip("\n").split("\t")
            rows.append((p[0], int(p[1])))
    return rows


def main():
    for r in RUNS:
        for field in ("set", "label"):
            if "_" in r[field] or "." in r[field]:
                sys.exit(f"ERROR: {field}에 '_' 또는 '.'이 있다: {r[field]}")
    dsids = [r["dsid"] for r in RUNS]
    dup = {d for d in dsids if dsids.count(d) > 1}
    if dup:
        sys.exit(f"ERROR: dsid 중복 {sorted(dup)}")
    names = [(r["set"], r["label"]) for r in RUNS]
    if len(set(names)) != len(names):
        sys.exit("ERROR: 같은 set 안에 같은 label이 둘")

    cache, out_rows, errors = {}, [], []
    for r in RUNS:
        sheet = os.path.join(ROOT, "samplesheets", r["dsid"] + ".csv")
        if r["existing"]:   # make_samplesheets.py 가 만든 시트
            rows = list(csv.DictReader(l for l in open(sheet, encoding="utf-8") if not l.startswith("#")))
            n_files, pairs = 2 * len(rows), len(rows)
            gib = sum(int(x["bytes"]) for x in rows) / GIB
        else:
            mdir = r["hg"] if r["hg"] in os.listdir(MANIFESTS) else None
            if mdir not in cache:
                cache[mdir] = load_manifest(mdir)
            rx = re.compile(r["pattern"])
            files = [(p, b) for p, b in cache[mdir] if rx.search(p)]
            if len(files) != r["expect"]:
                errors.append(f"{r['dsid']}: 파일 {len(files)}개, 기대 {r['expect']} (pattern {r['pattern']})"); continue
            by = defaultdict(dict)
            for p, b in files:
                k, m = mate_key(p)
                if m in by[k]:
                    errors.append(f"{r['dsid']}: mate {m} 중복 {p}")
                by[k][m] = (p, b)
            sheet_rows = []
            # unit = 데이터셋 공통 경로 아래 상대 dir + 파일 접두 + 분할 번호. 플로우셀 dir까지 넣어야 다른 플로우셀의 같은 Sample_* 이름이 안 겹친다
            root = os.path.commonpath([k[0] for k in by]) if len(by) > 1 else next(iter(by))[0]
            for k in sorted(by):
                if set(by[k]) != {1, 2}:
                    errors.append(f"{r['dsid']}: 짝 없음 {k} -> {sorted(by[k])}"); continue
                (p1, b1), (p2, b2) = by[k][1], by[k][2]
                rel = os.path.relpath(k[0], root).replace(os.sep, "/")
                unit = ".".join(x for x in ((rel if rel != "." else ""), k[1], k[3]) if x).replace("/", ".")
                sheet_rows.append([r["label"], r["dataset"], unit, f"{DATA_ROOT}/{p1}", f"{DATA_ROOT}/{p2}", b1 + b2])
            with open(sheet, "w", newline="", encoding="utf-8") as fh:
                fh.write(f"# generated by scripts/make_more_samplesheets.py — data_root={DATA_ROOT}\n")
                w = csv.writer(fh); w.writerow(["sample", "dataset", "unit", "fastq_1", "fastq_2", "bytes"]); w.writerows(sheet_rows)
            units = [x[2] for x in sheet_rows]
            if len(set(units)) != len(units):
                errors.append(f"{r['dsid']}: unit 중복 {len(units) - len(set(units))}건")
            n_files, pairs = len(files), len(sheet_rows)
            gib = sum(x[5] for x in sheet_rows) / GIB
        out_rows.append(dict(dsid=r["dsid"], set=r["set"], label=r["label"], hg=r["hg"], sex=SEX[r["hg"]], tier=r["tier"],
                             platform=r["platform"], read_len=r["read_len"], fastq_files=n_files, fastq_pairs=pairs,
                             size_gib=f"{gib:.1f}", truthset=TRUTH.get(r["hg"], "없음 (germline 정답셋 없음 — somatic 경로)"),
                             note=r["note"]))
    if errors:
        print("ERROR:", *errors, sep="\n  "); sys.exit(1)
    with open(os.path.join(ROOT, "more_run_table.tsv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(out_rows[0]), delimiter="\t"); w.writeheader(); w.writerows(out_rows)
    for tier in ("germline", "somatic"):
        rs = [x for x in out_rows if x["tier"] == tier]
        print(f"{tier}: {len({x['set'] for x in rs})} sets, {len(rs)} samples, {sum(x['fastq_pairs'] for x in rs)} pairs, "
              f"{sum(float(x['size_gib']) for x in rs):.1f} GiB")


if __name__ == "__main__":
    main()
