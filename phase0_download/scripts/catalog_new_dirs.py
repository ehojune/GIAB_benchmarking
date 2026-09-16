#!/usr/bin/env python3
"""crawl_data.py가 남긴 manifests/data_unrouted_new.tsv(새 디렉토리의 신규 파일)를 카탈로그 행으로 만든다.

  python phase0_download/scripts/catalog_new_dirs.py            # 카탈로그 행 추가 + optional manifest 작성 + 요약
  python phase0_download/scripts/catalog_new_dirs.py --dry-run  # 요약만

규칙
- 플랫폼 디렉토리 = 경로에서 알려진 플랫폼 이름 패턴(BCM_ILMN, BCM_Revio, Dovetail, analysis …)이 처음 나오는 구성요소까지.
  그 디렉토리가 이미 카탈로그 giab_path면 기존 행에 붙인다(files/size 갱신). 아니면 새 행을 만든다.
- category는 디렉토리 이름 패턴으로 정한다(아래 PATTERNS). HG008 관례: analysis·Hi-C·단일세포·핵형·superseded = other.
- data/<trio>/analysis/<dir> (2014~2020 trio 레벨 분석, 카탈로그에 없던 것)는 카탈로그 행을 만들지 않고
  manifests/optional_trio_analysis_legacy.tsv 에만 적는다. `download.sh optional_trio_analysis_legacy` 로만 받는다.
  예외: NIST_HG002_DraftBenchmark_defrabb* 는 기존 defrabb 행들과 같은 trio_analysis 행으로 만든다.
- 행을 만든 뒤 `crawl_data.py --route-all` 을 캐시로 다시 돌리면 파일이 manifest에 들어간다.
"""
import csv
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
PROJ = os.path.dirname(REPO)
MANI = os.path.join(REPO, "manifests")
CATALOG = os.path.join(PROJ, "catalog", "master_catalog.tsv")
UNROUTED = os.path.join(MANI, "data_unrouted_new.tsv")
LEGACY = os.path.join(MANI, "optional_trio_analysis_legacy.tsv")
DRY = "--dry-run" in sys.argv
GIB = 1024 ** 3
TODAY = "2026-09-16"

# (정규식, category, platform 설명, 처리 요약(align/variant 등), 비고) — README에서 확인한 것만 구체적으로 적는다
PATTERNS = [
    (r"BCM_NovaSeqX", "illumina_wgs", "Illumina NovaSeq X 25B, 2x125 PCR-free(KAPA HyperPrep)", "bwa-mem2 (nf-core/sarek) → GRCh38-GIABv3 BAM(dup 미표시); fastp 전처리",
     "README: BCM HGSC. mean autosomal ~125x(N-WT-p4 기준). FASTQ 8(4레인) + BAM + MultiQC"),
    (r"BCM_ILMN", "illumina_wgs", "Illumina NovaSeq X, 2x150 PCR-free", "DRAGEN → GRCh38 CRAM",
     "README: BCM HGSC. p21 ~103x. FASTQ 4 + CRAM(+crai)"),
    (r"BCM_Revio", "pacbio_hifi", "PacBio Revio SPRQ", "pbmm2 v1.17.0 → GRCh38-GIABv3, HiPhase v1.5.0 위상; uBAM(.demux.bam+.pbi) 동봉",
     "README: BCM HGSC. p100 기준 mean autosome 32x / median diploid 51x, N50 18.4 kb"),
    (r"MGH-Bioskryb_resolveOME", "other", "Bioskryb ResolveOME 단일세포 WGS+cDNA, Illumina NovaSeq 6000 2x100", "Basejumper(bj-expression 1.8.7, PARABRICKS germline fq2bam); 세포당 ~0.7x",
     "README: MGH. QC 통과 59 세포쌍(88 중). FASTQ+BAM 세포별"),
    (r"MissionBio_Tapestri", "other", "Mission Bio Tapestri 단일세포 DNA(CNV 500 amplicon + HG008-T 특이 223 amplicon), NovaSeq X 10B", "Tapestri DNA pipeline(BWA), Mosaic v3.7; ~3,700 cells/run × 2",
     "README: Mission Bio. FASTQ + h5 + BAM/VCF"),
    (r"JHU_SingleCell_10X", "other", "10x Chromium Multiome ATAC+GEX, Illumina NovaSeq X 10B", "Cell Ranger ARC 2.0.2 → GRCh38 (BAM, h5, fragments, peaks)",
     "README: JHU. 8,483 nuclei"),
    (r"Dovetail_HiC-LinkPrep|Dovetail_HiC", "other", "Dovetail LinkPrep Hi-C(v2.0 kit), Illumina NovaSeq X Plus 2x150", "BWA-MEM2 v2.2.1 → GRCh38 BAM, pairtools",
     "README: Dovetail(Cantata Bio). 라이브러리 4개. HG008-T p21 55.3x"),
    (r"PhaseGenomics_HiC", "other", "Phase Genomics Proximo Hi-C v4.5(CytoTerra), Illumina NovaSeq X 2x150", "BWA-MEM → BAM; hic_qc.py; bcl2fastq 2.20",
     "README: Phase Genomics. 단일 라이브러리(~250k cells)"),
    (r"UMD_RNA-?seq", "rnaseq_all", "Illumina NovaSeq 6000 2x150, total RNA(rRNA depletion, unstranded), NEBNext UltraExpress", "정렬 없음(FASTQ trimmed/untrimmed + stats)",
     "README: UMD Maryland Genomics. 패시지당 2 라이브러리, 런 2회 합산 ~50M read pairs"),
    (r"BCM_RNAseq", "rnaseq_all", "Illumina NovaSeq X 25B 2x151, Watchmaker total RNA(rRNA/globin depletion)", "STAR v2.7.3a → GRCh38_ERCC_RSEM BAM(MarkDuplicates), samtools 1.21",
     "README: BCM HGSC. 플로우셀 2개 합산 ~161M reads"),
    (r"[Kk]aryo[Ll]ogic", "other", "KaryoLogic G-band 핵형(시퀀싱 아님)", "-",
     "README+PDF 리포트. 20 metaphase. HG008-T p14: 58-64개 염색체 hypotriploid, 다중 재배열"),
    (r"HERR0-corr", "ont", "ONT std(Northeastern) HERRO 보정 리드", "HERRO 보정(dorado) — 세부는 README 확인 필요",
     "Northeastern_ONT-std_20240422 하위 2025-02 추가분"),
    (r"Hartwig_Oncoanalyzer", "other", "Illumina WGS 분석(Hartwig OncoAnalyser)", "OncoAnalyser 결과(입력 BCM/NYGC ILMN)", "README 미확인"),
    (r"HKU_(ONT|HiFi)_ClairS", "other", "ClairS v0.4.1 somatic SNV/INDEL", "ClairS v0.4.1", "README 미확인"),
    (r"NYGC_ILMN_Lancet2", "other", "Lancet2 somatic 콜셋(NYGC ILMN)", "Lancet2", "README 미확인"),
    (r"Ultima-ppmSeq-SNV", "other", "Ultima ppmSeq somatic SNV 분석", "-", "README 미확인"),
    (r"NIST_HG008-T_somatic", "other", "NIST HG008-T somatic draft benchmark", "NIST somatic benchmark 산출물", "README 미확인"),
    (r"Verkko", "other", "Verkko 어셈블리(HG008-T v2.2.1 HERRO 보정, HG008-N v2.2)", "Verkko 2.2/2.2.1 작업 디렉토리 전체(.sh/.red/.range 중간 산출물 포함)", "중간 산출물이 대부분. README_HG8N-verkko.md 참고"),
    (r"^analysis$", "other", "somatic 분석 결과(GRCh38)", "HiFi: HiFi Somatic WDL v0.9.4(DeepSomatic 1.9.0, Severus 1.6.0, CNVkit 0.9.10, PURPLE 4.0, VEP 112) · ILMN: nf-core/sarek 3.8.1 T/N(FreeBayes, Strelka2, Manta, indexcov)",
     "패시지/클론별 analysis 디렉토리. HG009는 기존 pacbio_hifi 행(2026-08) 분석 파일과 나뉘어 들어간다"),
    (r"NIST_HG002_DraftBenchmark_defrabb", "trio_analysis", "미표기(어셈블리 기반 draft benchmark)", "DeFrABB(dipcall) draft benchmark", "v5.0q의 전신(defrabb v0.020, 2025-01-17)"),
    (r"superseded-2022-data", "other", "Illumina WGS 2022(superseded)", "정렬 BAM/CRAM + FASTQ", "GIAB이 superseded로 표시. 받지 않아도 무방"),
]
PLATFORM_HINT = re.compile("|".join(f"(?:{p})" for p, *_ in PATTERNS))


def platform_dir(path):
    """플랫폼 디렉토리 경로와 매칭 패턴을 돌려준다. 없으면 (None, None).

    - defrabb draft benchmark: data/<trio>/analysis/<dir> 단위 (trio_analysis)
    - Liss_lab/analysis/<name>, superseded-2022-data/<name>: 그 <name> 단위 (HG008 카탈로그 관례). <name>이 PATTERNS에
      맞으면 그 패턴, 아니면 일반 분석(^analysis$ 패턴)으로 분류
    - NIST 트리(HG008/HG009): 경로에서 처음 나오는 플랫폼 패턴 구성요소까지. <passage>/analysis 는 그 자체가 단위
    """
    parts = path.split("/")
    if len(parts) > 3 and parts[0] == "data" and parts[2] == "analysis" and "NIST_HG002_DraftBenchmark_defrabb" in parts[3]:
        return "/".join(parts[:4]), r"NIST_HG002_DraftBenchmark_defrabb"
    for i, comp in enumerate(parts[:-1]):
        if comp in ("analysis", "superseded-2022-data") and i + 1 < len(parts) - 1 and parts[i - 1] == "Liss_lab":
            name = parts[i + 1]
            for pat, *_ in PATTERNS:
                if pat not in (r"^analysis$", r"superseded-2022-data") and re.search(pat, name):
                    return "/".join(parts[:i + 2]), pat
            return "/".join(parts[:i + 2]), r"^analysis$" if comp == "analysis" else r"superseded-2022-data"
        if comp == "superseded-2022-data" and i + 1 < len(parts) - 1:
            return "/".join(parts[:i + 2]), r"superseded-2022-data"
        for pat, *_ in PATTERNS:
            if pat in (r"superseded-2022-data",):
                continue
            if re.search(pat, comp):
                return "/".join(parts[:i + 1]), pat
    return None, None


def sample_of(path):
    m = re.search(r"data_somatic/(HG00[89])", path)
    if m:
        return m.group(1)
    m = re.search(r"/(HG00[1-7])_", path)
    if m:
        return m.group(1)
    if "AshkenazimTrio/analysis" in path:
        return "HG002" if "HG002" in path else "공용"
    if "ChineseTrio/analysis" in path:
        return "HG005" if "HG005" in path else "공용"
    return "공용"


AUTO_MARK = "FTP data/ 라이브 크롤로 발견"   # 이 스크립트가 만든 행의 표식(notes). 재실행 때 파생 필드를 다시 계산한다
REF_TOKENS = [("GRCh38-GIABv3", r"GRCh38[-_]GIABv3"), ("GRCh38_ERCC_RSEM", r"GRCh38_ERCC_RSEM"), ("CHM13v2.0", r"CHM13v2\.0|CHM13"),
              ("GRCh37", r"GRCh37|hs37d5|\bhg19\b"), ("GRCh38", r"GRCh38|\bhg38\b")]
# smvar/stvar는 GIAB germline 벤치마크 용어(small/structural variant)라 somatic 토큰에 넣지 않는다
SOMATIC_RE = re.compile(r"somatic|ClairS|DeepSomatic|Strelka|Mutect|Lancet|Severus|Oncoanalyzer|purple|cnvkit|_vs_|ppmSeq|GRIDSS|minda|Wakhan", re.I)
GERMLINE_RE = re.compile(r"germline|dipcall|deepvariant|clair3(?!S)|freebayes|haplotypecaller|benchmark\.vcf|smvar|stvar", re.I)
PHASE_RE = re.compile(r"hiphase|whatshap|longphase|haplotag", re.I)   # 'phased' 단어는 너무 헐거워서(purple 등 파일명) 빼는다


def load_manifest_files():
    out = {}
    for f in glob.glob(os.path.join(MANI, "HG*", "*.tsv")) + [os.path.join(MANI, "rnaseq_all.tsv"), os.path.join(MANI, "trio_analysis.tsv")]:
        if os.path.exists(f):
            for l in open(f, encoding="utf-8"):
                if l.strip() and not l.startswith("#"):
                    p, b = l.rstrip("\n").split("\t")[:2]
                    out[p] = int(b) if b else 0
    return out


def index_status(names):
    """(index_present, index_types, unindexed_n) — 인덱스 대상 파일마다 사이드카가 있는지 본다"""
    s = set(names)
    pairs = [(".bam", (".bam.bai", ".bai", ".bam.pbi")), (".cram", (".cram.crai", ".crai")), (".vcf.gz", (".vcf.gz.tbi", ".vcf.gz.csi"))]  # PacBio uBAM은 .pbi
    targets, indexed, types = 0, 0, set()
    for n in names:
        for ext, sides in pairs:
            if n.endswith(ext):
                targets += 1
                cands = [n + sd[len(ext):] if sd.startswith(ext) else n[: -len(ext)] + sd for sd in sides]
                hit = [c for c in cands if c in s]
                if hit:
                    indexed += 1
                    types.add(os.path.splitext(hit[0])[1])
        if n.endswith(".bam.pbi"):
            types.add(".pbi")
    if targets == 0:
        return "-", ",".join(sorted(types)), ""
    if indexed == targets:
        return "TRUE", ",".join(sorted(types)), "0"
    return ("PARTIAL" if indexed else "FALSE"), ",".join(sorted(types)), str(targets - indexed)


def refs_in(names):
    found = []
    for label, pat in REF_TOKENS:
        if any(re.search(pat, n) for n in names) and label not in found:
            if label == "GRCh38" and "GRCh38-GIABv3" in found:
                continue
            found.append(label)
    return ", ".join(found) if found else "N/A"


def main():
    if not os.path.exists(UNROUTED):
        sys.exit(f"없음: {UNROUTED} (crawl_data.py를 먼저)")
    items = []
    for l in open(UNROUTED, encoding="utf-8"):
        if l.strip() and not l.startswith("#"):
            p, b, mtime, sug, date = l.rstrip("\n").split("\t")[:5]
            items.append((p, int(b), mtime))
    manifest_files = load_manifest_files()
    rows = list(csv.DictReader(open(CATALOG, encoding="utf-8", newline=""), delimiter="\t"))
    cols = list(rows[0].keys())
    by_path = {r["giab_path"]: r for r in rows}

    legacy, groups, skipped = [], {}, []
    for p, b, mtime in items:
        q = p.split("/")
        if q[0] == "data" and q[2] == "analysis":
            if "NIST_HG002_DraftBenchmark_defrabb" not in p:
                legacy.append((p, b, mtime))
                continue
        d, pat = platform_dir(p)
        if d is None:
            skipped.append(p)
            continue
        groups.setdefault(d, {"pat": pat, "files": []})["files"].append((p, b))

    # 이 스크립트가 이미 만든 행(또는 이전 실행에서 갱신한 행)도 다시 계산 대상에 넣는다 — unrouted가 비어도 파생 필드가 manifest 실측을 따라간다
    for r in rows:
        notes = r.get("notes") or ""
        if (AUTO_MARK in notes or f"{TODAY} data/ 크롤" in notes) and r["giab_path"] not in groups:
            _, pat = platform_dir(r["giab_path"] + "/x")
            if pat:
                groups[r["giab_path"]] = {"pat": pat, "files": []}

    new_rows, updated = [], []
    for d, g in sorted(groups.items()):
        pat = g["pat"]
        _, cat, platform, tools, note = next(x for x in PATTERNS if x[0] == pat)
        # 인벤토리 = manifest에 이미 있는 파일 ∪ 이번 unrouted 파일 (경로 기준 중복 없음). 재실행해도 수가 불지 않는다.
        inv = {p: b for p, b in manifest_files.items() if p == d or p.startswith(d + "/")}
        inv.update(dict(g["files"]))
        n, size = len(inv), sum(inv.values())
        names = [os.path.basename(p) for p in inv]
        has_fastq = any(re.search(r"\.(fastq|fq)\.gz$", x) for x in names)
        has_bam = any(x.endswith((".bam", ".cram")) for x in names)
        vcfs = [x for x in names if x.endswith((".vcf.gz", ".vcf"))]
        idx_present, idx_types, unindexed = index_status(names)
        readme = sorted(p for p in inv if re.search(r"README", os.path.basename(p), re.I) and os.path.dirname(p) == d)
        # VCF 성격: somatic(T/N 비교·somatic 콜러) vs germline. analysis 디렉토리는 somatic이 기본, germline 토큰이 있으면 둘 다
        is_analysis = pat == r"^analysis$" or "/analysis/" in d + "/"
        somatic = bool(vcfs) and pat != r"NIST_HG002_DraftBenchmark_defrabb" and (
            any(SOMATIC_RE.search(x) for x in vcfs) or is_analysis or SOMATIC_RE.search(os.path.basename(d)) is not None)
        germline = any(GERMLINE_RE.search(x) for x in vcfs) or (bool(vcfs) and pat == r"NIST_HG002_DraftBenchmark_defrabb")
        if vcfs and not somatic and not germline:
            germline = True  # 분류 근거 없으면 germline으로(카탈로그 기존 관례)
        phased = any(PHASE_RE.search(x) for x in names)
        phase_tool = ("HiPhase v1.5.0 (BCM Revio README)" if pat == r"BCM_Revio" else "파일명 토큰 기준(hiphase/whatshap/longphase/phased) — 툴 버전은 README 확인") if phased else "-"
        refs = refs_in([p for p in inv if p.endswith((".bam", ".cram", ".vcf.gz", ".vcf"))]) if (has_bam or vcfs) else "-"
        if cat == "rnaseq_all" and has_bam and refs == "N/A":
            refs = "GRCh38_ERCC_RSEM (BCM RNAseq README)"
        derived = dict(
            files=str(n), size_gib=f"{size / GIB:.1f}",
            reads_present="TRUE" if has_fastq or (has_bam and cat in ("pacbio_hifi", "ont")) else "FALSE",
            reads_format=("FASTQ" if has_fastq else "") + (" + BAM/CRAM" if has_bam else "") or "N/A",
            index_present=idx_present, index_types=idx_types, index_unindexed_n=unindexed, index_by="GIAB" if idx_types else "-",
            aligned="TRUE" if has_bam else "-", align_tool=tools if has_bam else "-", align_ref=refs if has_bam else "-", align_by="GIAB" if has_bam else "-",
            phased="TRUE" if phased else "-", phase_tool=phase_tool, phase_by="GIAB" if phased else "-",
            variant_called="TRUE" if germline else "-", variant_tool=(tools if germline else "-"), variant_by="GIAB" if germline else "-",
            somatic_called="TRUE" if somatic else "-", somatic_tool=(tools if somatic else "-"), somatic_by="GIAB" if somatic else "-",
            assembled="TRUE" if pat == r"Verkko" else "-", assembly_tool="Verkko 2.2/2.2.1" if pat == r"Verkko" else "-", assembly_by="GIAB" if pat == r"Verkko" else "-",
            giab_processed="TRUE" if (has_bam or vcfs) else "FALSE",
            tool_source=("giab_doc:" + readme[0]) if readme else "N/A",
        )
        if d in by_path:
            r = by_path[d]
            if AUTO_MARK in (r.get("notes") or ""):   # 이 스크립트가 만든 행 → 파생 필드 전부 재계산
                r.update(derived)
            else:                                     # 사람이 채운 기존 행 → files/size만 인벤토리 기준으로 맞추고 비고는 한 번만
                r["files"], r["size_gib"] = derived["files"], derived["size_gib"]
                if f"{TODAY} data/ 크롤" not in (r.get("notes") or ""):
                    r["notes"] = (r.get("notes") or "") + f" | {TODAY} data/ 크롤: 하위 신규 {len(g['files'])} files 반영, files/size는 manifest 실측으로 재계산"
            updated.append((d, n, size))
            continue
        sample = sample_of(d)
        row = dict.fromkeys(cols, "")
        base = os.path.basename(d)
        parent_hint = ""
        m = re.search(r"(HG00[89]-[TN][^/]*)/(\d{8}p\d+)(?:/([^/]+)/(p\d+plus\d+))?", d)
        if m:
            parent_hint = " ".join(x for x in (m.group(1), m.group(2), m.group(3), m.group(4)) if x)
        row.update(
            sample=sample, category=cat, dataset=f"{sample} {parent_hint} {base}".replace("  ", " ").strip(),
            giab_path=d, platform=platform, coverage="",
            meth_called="-", meth_tool="-", meth_by="-", next_step="",
            notes=f"{TODAY} {AUTO_MARK}(2026-08-13 목록 누락분). {note}" + ("" if readme else " — README 없음/미확인, 필드는 파일명 기준"),
        )
        row.update(derived)
        new_rows.append(row)

    # 요약
    print(f"unrouted items {len(items)}: legacy(trio analysis) {len(legacy)} ({sum(b for _, b, _ in legacy) / GIB:.1f} GiB), "
          f"platform dirs {len(groups)} → new rows {len(new_rows)} ({sum(int(r['files']) for r in new_rows)} files, {sum(float(r['size_gib']) for r in new_rows):.1f} GiB), "
          f"existing rows updated {len(updated)}, unclassified {len(skipped)}")
    from collections import Counter
    print("new rows by sample/category:", dict(Counter((r["sample"], r["category"]) for r in new_rows)))
    for p in skipped[:20]:
        print("  UNCLASSIFIED:", p)
    for d, n, size in updated:
        print(f"  EXISTING ROW +{n} files / {size / GIB:.1f} GiB: {d}")
    if DRY:
        for r in new_rows[:120]:
            print(f"  {r['category']:13s} {r['files']:>5s} {r['size_gib']:>8s}  {r['giab_path']}")
        return

    rows.extend(new_rows)
    with open(CATALOG, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    if legacy:
        already = {l.split("\t")[0] for l in open(LEGACY, encoding="utf-8") if l.strip()} if os.path.exists(LEGACY) else set()
        with open(LEGACY, "a", encoding="utf-8", newline="\n") as fh:
            for p, b, _ in sorted(legacy):
                if p not in already:
                    fh.write(f"{p}\t{b}\n")
    print(f"catalog: {len(rows)} rows; legacy manifest: {LEGACY}")
    print("다음: python phase0_download/scripts/crawl_data.py --route-all   (캐시로 재실행 → manifest 반영)")


if __name__ == "__main__":
    main()
