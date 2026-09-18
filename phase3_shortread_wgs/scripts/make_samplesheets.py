#!/usr/bin/env python3
"""inputs_manifest.tsv (+ ext_manifest.tsv, kind=reads) -> samplesheets/<dsid>.csv (R1/R2 paired, read-group unit) + run_table.tsv.
Pipeline-agnostic: sample,dataset,unit,fastq_1,fastq_2,bytes. unit = flowcell.lane[.library] = one read group."""
import csv, os, re, sys
from collections import defaultdict
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
DATA_ROOT = os.environ.get("DATA_ROOT", "/BiO/scratch/ehojune/GIAB_benchmark")
GIB = 1024**3

# documented coverage (catalog/master_catalog.tsv, GIAB README). N/A = GIAB 문서에 없음
COVERAGE = {"HiSeq300x": "300x (2x148, 플로우셀당 ~25x)", "Illumina_2x250": "~40-50x", "BGISEQ500": "N/A",
            "MGISEQ2000_PCRfree": "N/A", "Element_AVITI_20240920": "Std ~80x + Lng 32-38x",
            "Illumina_PCRfree_30x": "~30x", "NIST_BGIseq_2x150_100x": "100x", "Element_AVITI_20231018": "Std 81x + Lng 55x",
            "NovaSeq_PCRfree_30x": "~30x (Google 배포 명칭)", "NovaSeqX_30x": "~30x (Google 배포 명칭; 원 런 SRR37356338 ≈42x)"}
PLATFORM = {"HiSeq300x": "Illumina HiSeq 2500 rapid, 2x148", "Illumina_2x250": "Illumina 2x250", "BGISEQ500": "BGISEQ-500 PCR-free",
            "MGISEQ2000_PCRfree": "MGISEQ-2000 PCR-free", "Element_AVITI_20240920": "Element AVITI 2x150", "Illumina_PCRfree_30x": "Illumina HiSeq 2500 PCR-free 2x148 (300x 서브샘플)",
            "NIST_BGIseq_2x150_100x": "MGI DNBSEQ 2x150", "Element_AVITI_20231018": "Element AVITI 2x150",
            "NovaSeq_PCRfree_30x": "Illumina NovaSeq 6000 PCR-free 2x151", "NovaSeqX_30x": "Illumina NovaSeq X 25B TruSeq PCR-free 2x150 (SRA 재배포 헤더)"}

def mate_key(path):
    """return (pair_key, mate) where pair_key identifies R1/R2 pair, mate in {1,2}"""
    f = os.path.basename(path)
    for pat in (r"_R([12])_(\d+)\.fastq\.gz$", r"_R([12])\.fastq\.gz$", r"\.R([12])\.fastq\.gz$", r"_read_([12])\.fq\.gz$", r"_([12])\.fq\.gz$"):  # .R1.fastq.gz = Google 명명
        m = re.search(pat, f)
        if m:
            return os.path.dirname(path) + "/" + f[:m.start()] + "|" + pat + (m.group(2) if m.lastindex == 2 else ""), int(m.group(1))
    raise ValueError(f"cannot find mate in {path}")

def unit_of(dataset, path):
    p = path.split("/"); f = p[-1]
    if dataset == "HiSeq300x":            # .../HG002_HiSeq300x_fastq/<flowcell>/Project_*/Sample_2A1/2A1_CGATGT_L001_R1_001.fastq.gz
        fc = p[5].split("_")[-1]; lane = re.search(r"_(L\d{3})_", f).group(1); smp = p[7].replace("Sample_", "")
        return f"{fc}.{lane}.{smp}"
    if dataset == "Illumina_2x250":       # reads/D1_S1_L001_R1_001.fastq.gz — HG003/4는 라이브러리(S1/S2, S1/S3)가 둘이라 D?_S? 까지 unit에 넣는다
        m = re.search(r"^(D\d+_S\d+)_(L\d{3})_", f); return f"{m.group(1)}.{m.group(2)}"
    if dataset in ("BGISEQ500", "MGISEQ2000_PCRfree"):   # ..._CL100076190_L01_read_1.fq.gz / ..._V100002807_L03_1.fq.gz
        m = re.search(r"_([A-Z]+\d+)_(L\d{2})_", f); lib = p[5] if dataset.startswith("MGISEQ") else ""
        return f"{m.group(1)}.{m.group(2)}" + (f".{lib}" if lib else "")
    if dataset == "NIST_BGIseq_2x150_100x":   # 211109_M024_V350038332_L01_HUMuarfR092940-606_1.fq.gz
        m = re.search(r"_(V\d+)_(L\d{2})_.*-(\d{3})_[12]\.fq\.gz$", f); return f"{m.group(1)}.{m.group(2)}.bc{m.group(3)}"
    if dataset.startswith("Element_AVITI"):
        return "LngInsert" if re.search(r"Lng|long-insert", path) else "StdInsert"
    if dataset == "Illumina_PCRfree_30x":
        return "subsampled30x"
    if dataset == "NovaSeq_PCRfree_30x":      # 경로에 플로우셀 없음. 헤더 표본은 A00744:46:HV3C3DSXX:2 한 레인이었지만 전체를 보지는 않았다
        return "novaseq30x"
    if dataset == "NovaSeqX_30x":             # 헤더 표본 pi1-04:533:22JTGYLT4:1 — 한 런, 레인 전체는 안 봤다
        return "novaseqx30x"
    raise ValueError(dataset)

rows = list(csv.DictReader(open(os.path.join(ROOT, "inputs_manifest.tsv"), encoding="utf-8"), delimiter="\t"))
# 외부 유래 리드 (GIAB FTP 밖; phase0 manifest에 없다). 받는 법은 scripts/02_fetch_external_reads.sh
EXT = os.path.join(ROOT, "ext_manifest.tsv"); n_ext = 0
if os.path.exists(EXT):
    for r in csv.DictReader(open(EXT, encoding="utf-8"), delimiter="\t"):
        if r["kind"] != "reads": continue
        rows.append({"dsid": r["dsid"], "relpath": r["relpath"], "bytes": r["bytes"]}); n_ext += 1
by_ds = defaultdict(list)
for r in rows: by_ds[r["dsid"]].append(r)

run_table = []
for dsid in sorted(by_ds):
    sample, dataset = dsid.split(".", 1)
    pairs = defaultdict(dict)
    for r in by_ds[dsid]:
        k, mate = mate_key(r["relpath"]); pairs[k][mate] = r
    out = []
    for k, m in sorted(pairs.items(), key=lambda kv: kv[1][1]["relpath"] if 1 in kv[1] else ""):
        assert set(m) == {1, 2}, f"{dsid}: unpaired {k} -> {list(m)}"
        u = unit_of(dataset, m[1]["relpath"]); u2 = unit_of(dataset, m[2]["relpath"]); assert u == u2, (dsid, u, u2, m[1]["relpath"], m[2]["relpath"])
        out.append((sample, dataset, u, f"{DATA_ROOT}/{m[1]['relpath']}", f"{DATA_ROOT}/{m[2]['relpath']}", int(m[1]["bytes"]) + int(m[2]["bytes"])))
    with open(os.path.join(ROOT, "samplesheets", dsid + ".csv"), "w", newline="", encoding="utf-8") as fh:
        fh.write(f"# generated by scripts/make_samplesheets.py — data_root={DATA_ROOT}\n")
        w = csv.writer(fh); w.writerow(["sample", "dataset", "unit", "fastq_1", "fastq_2", "bytes"]); w.writerows(out)
    units = sorted({o[2] for o in out}); fcs = sorted({u.split(".")[0] for u in units})
    gib = sum(o[5] for o in out) / GIB
    note = ""
    if dataset == "HiSeq300x":
        note = f"플로우셀 {len(fcs)}개 × 2레인 × Sample_* 라이브러리; unit = 플로우셀.레인.라이브러리 = read group. 전량 사용(2026-09-09 결정)"
        if sample == "HG003": note += ". 0030_AHA0L6ADXX는 1.2 GiB(≈0.5x, 실패 런으로 보임)이지만 포함"
    elif dataset == "MGISEQ2000_PCRfree" and sample == "HG004": note = "라이브러리 2개(NA24143_1, NA24143_2)"
    elif dataset.startswith("Element_AVITI"): note = "StdInsert·LngInsert 라이브러리 2개 — 병합 여부는 파이프라인에서 결정"
    elif dataset == "NovaSeq_PCRfree_30x": note = "외부(Google brain-genomics-public GCS) — ext_manifest.tsv. 세 샘플이 같은 런 A00744:46 HV3C3DSXX L2의 다른 인덱스(2026-09-17 리드 헤더 표본). 업체 비교용 30x arm(2026-09-17 결정)"
    elif dataset == "NovaSeqX_30x": note = "외부(Google GCS novaseqx/) — ext_manifest.tsv. 업체 화학(NovaSeq X, XLEAP-SBS) 매칭 HG002 단일 대조군(2026-09-17 결정). 원 데이터 Weill Cornell PRJNA1427896 SRR37356338; 리드 이름이 SRA 형식이라 detect_fastq_platform.sh는 미상(숏리드)으로 찍는다"
    elif dataset == "Illumina_PCRfree_30x" and sample != "HG002": note = "외부(HPRC S3 human-pangenomics) — ext_manifest.tsv. GIAB FTP에는 HG002만 있고 README가 이 사본을 가리킴. 300x와 같은 TruSeq PCR-free 라이브러리의 서브샘플"
    run_table.append(dict(dsid=dsid, sample=sample, dataset=dataset, entry_type="fastq_pe", platform=PLATFORM[dataset],
                          units=len(units), fastq_pairs=len(out), size_gib=f"{gib:.1f}", coverage_doc=COVERAGE[dataset],
                          truthset=f"release/AshkenazimTrio/{sample}_*/NISTv4.2.1/GRCh38/{sample}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz + _benchmark_noinconsistent.bed",
                          note=note))
with open(os.path.join(ROOT, "run_table.tsv"), "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=list(run_table[0]), delimiter="\t"); w.writeheader(); w.writerows(run_table)
print(f"{len(run_table)} runs, {sum(r['fastq_pairs'] for r in run_table)} pairs, {sum(float(r['size_gib']) for r in run_table):.1f} GiB (ext files: {n_ext})")
