#!/usr/bin/env python3
"""phase1 QC 산출물을 읽어 실행 단위별 지표를 뽑고 이상치를 표시한다.

30_verify_outputs.sh는 VCF·BAM의 존재만 본다. 파일이 있어도 커버리지가 반토막이거나
변이 수가 두 배거나 위상이 거의 안 잡힌 런은 그대로 통과한다. 이 스크립트가 그 틈을 메운다.

읽는 것 (전부 파이프라인이 이미 만든 것, 새로 계산하지 않음):
  04_QC/mosdepth/<id>.mosdepth.summary.txt      genome-wide 평균 커버리지
  04_QC/samtools/<id>.stats.txt                 매핑률, error rate, 평균 리드 길이
  04_QC/bcftools_stats/<id>.<caller>.*.txt      caller별 SNP/INDEL/ts-tv/레코드 수
  03_VCF/phased_whatshap/<id>.whatshap_stats.txt  위상 비율, block N50
  <RUN_BASE>/multiqc/<dsid>/multiqc_report.html  MultiQC 리포트 존재 여부

사용:
  python phase1_pacbio_hifi/scripts/35_review_qc.py                 # 전체
  python phase1_pacbio_hifi/scripts/35_review_qc.py HG002.PacBio_CCS_10kb
  python phase1_pacbio_hifi/scripts/35_review_qc.py --tsv qc_review.tsv   # 공유용 요약 저장
  python phase1_pacbio_hifi/scripts/35_review_qc.py --pass-counts     # PASS만 다시 세어 변이 수까지 판정

주의: 파이프라인의 04_QC/bcftools_stats 는 PASS 필터 없이 돌아서 SNP/INDEL/ts-tv 가
RefCall 포함 raw 카운트다. 기본 실행은 그 값을 ~표시로 보여주기만 하고 판정하지 않는다.
변이 수로 판정하려면 --pass-counts (bcftools 필요, 런당 수십 초).

exit 1 = 완료된 런인데 QC 파일이 없음(파이프라인 QC 스테이지 실패). WARN만이면 exit 0.
"""
import argparse
import csv
import os
import subprocess
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
PHASE1 = HERE.parent
RUN_TABLE = PHASE1 / "run_table.tsv"

# ── 파이프라인의 bcftools stats 는 PASS 필터 없이 돈다 ────────────────────────
# BCFTOOLS_STATS 가 받는 것은 raw caller VCF (main.nf: ch_dv_vcf / ch_clair3_vcf / ch_pbsv_vcf).
# DeepVariant 는 FILTER=RefCall 레코드를, Clair3 는 merge_output.vcf.gz 의 RefCall 을 그대로 담는다
# (--no_ref_calls 미사용). 그래서 04_QC/bcftools_stats 의 SNP/INDEL/ts-tv 는 **후보 레코드 수**이고
# 진짜 변이 수가 아니다. 실측 확인: dv_snp+dv_indel = 9.766M ≈ dv_records 9.754M (모든 레코드가 집계됨),
# 정상군에서 cov↔dv_snp 상관 r=+0.711 (진짜 germline 이면 20x 이상에서 커버리지와 무관해야 한다).
#
# 따라서 변이 수·ts/tv·caller 일치는 **--pass-counts 로 PASS 만 다시 셀 때만** 판정한다.
# 기본 실행은 필터와 무관하게 유효한 지표(커버리지·매핑률·error rate·리드길이·MultiQC)만 판정한다.
TH = {
    # 항상 유효 (FILTER 무관)
    "cov_min": 15.0,          # 이하면 변이 호출 품질이 떨어짐
    "mapped_min": 95.0,       # HiFi→GRCh38은 보통 99% 이상
    "err_max": 0.02,          # samtools error rate = mismatches/bases_mapped, 참변이 포함
    "readlen_min": 5000,      # HiFi인데 이보다 짧으면 subreads가 섞인 것일 수 있음
    # PASS 기준으로만 의미 있음 (--pass-counts 필요)
    "snp_lo": 2_500_000, "snp_hi": 5_500_000,
    "indel_lo": 300_000, "indel_hi": 1_500_000,
    "tstv_lo": 1.8, "tstv_hi": 2.3,
    "caller_ratio_min": 0.8,  # DV↔C3 SNV 수 비가 이보다 벌어지면 한쪽이 잘못 돈 것
    "sv_lo": 5_000, "sv_hi": 60_000,
    # 위상 — germline / tumor 를 나눈다. 종양은 LOH·aneuploidy로 het 자체가 줄어
    # 위상 대상이 줄기 때문에 낮은 값이 정상이다 (실측 정상 76.9% vs 종양 66.8%, het 비 0.712).
    "phased_min": 70.0,
    "phased_min_tumor": 55.0,
    "n50_min": 20_000,
}
# 종양 실행 단위: HG008-T / HG009T-* (HG008-N-*, HG009N-* 는 정상이다)
TUMOR_PAT = ("HG008-T", "HG009T")


def is_tumor(sample):
    return any(sample.startswith(p) for p in TUMOR_PAT)


def num(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def read_mosdepth(p):
    """mosdepth.summary.txt의 total 행 mean을 돌려준다."""
    if not p or not p.is_file():
        return None
    for line in p.read_text(errors="ignore").splitlines():
        f = line.split("\t")
        if len(f) >= 4 and f[0] == "total":
            return num(f[3])
    return None


def read_samtools(p):
    """stats.txt의 SN 섹션에서 필요한 값만."""
    out = {}
    if not p or not p.is_file():
        return out
    want = {
        "raw total sequences": "n_reads",
        "reads mapped": "n_mapped",
        "average length": "avg_len",
        "error rate": "err_rate",
        "average quality": "avg_qual",
    }
    for line in p.read_text(errors="ignore").splitlines():
        if not line.startswith("SN\t"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        key = parts[1].rstrip(":").strip()
        if key in want:
            # "error rate" 은 "3.0e-03\t# mismatches..." 형태
            out[want[key]] = num(parts[2].split()[0]) if parts[2].strip() else None
    if out.get("n_reads") and out.get("n_mapped") is not None:
        out["mapped_pct"] = 100.0 * out["n_mapped"] / out["n_reads"]
    return out


def read_bcftools(p):
    """bcftools stats에서 SNP/INDEL/records/ts-tv."""
    out = {}
    if not p or not p.is_file():
        return out
    for line in p.read_text(errors="ignore").splitlines():
        if line.startswith("SN\t"):
            f = line.split("\t")
            if len(f) >= 4:
                k = f[2].rstrip(":").strip()
                v = num(f[3])
                if k == "number of SNPs":
                    out["snp"] = v
                elif k == "number of indels":
                    out["indel"] = v
                elif k == "number of records":
                    out["records"] = v
                elif k == "number of multiallelic sites":
                    out["multiallelic"] = v
        elif line.startswith("TSTV\t"):
            f = line.split("\t")
            if len(f) >= 5:
                out["tstv"] = num(f[4])
    return out


def read_whatshap(p):
    """whatshap stats --tsv 결과에서 ALL 행. 컬럼은 헤더 이름으로 찾는다."""
    out = {}
    if not p or not p.is_file():
        return out
    rows = list(csv.reader(p.read_text(errors="ignore").splitlines(), delimiter="\t"))
    if not rows:
        return out
    hdr = [h.lstrip("#").strip() for h in rows[0]]
    idx = {h: i for i, h in enumerate(hdr)}
    pick = None
    for r in rows[1:]:
        if len(r) != len(hdr):
            continue
        chrom = r[idx["chromosome"]] if "chromosome" in idx else ""
        if chrom.upper() == "ALL":
            pick = r
            break
        pick = pick or r
    if pick is None:
        return out

    def col(name):
        return num(pick[idx[name]]) if name in idx and idx[name] < len(pick) else None

    het = col("heterozygous_variants")
    ph = col("phased")
    out["het"] = het
    out["phased"] = ph
    out["blocks"] = col("blocks")
    out["n50"] = col("block_n50")
    if het and ph is not None and het > 0:
        out["phased_pct"] = 100.0 * ph / het
    return out


def pass_counts(vcf):
    """VCF 에서 PASS 레코드만 세어 SNV/INDEL/ts-tv 를 돌려준다.

    파이프라인의 04_QC/bcftools_stats 는 RefCall 을 포함한 raw 카운트라
    진짜 변이 수를 알려면 여기서 다시 세야 한다. bcftools 가 필요하고
    VCF 1개에 수십 초 걸리므로 --pass-counts 로만 켠다.
    """
    if not vcf.is_file():
        return {}
    cmd = ["bcftools", "stats", "-f", "PASS", str(vcf)]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"  ! bcftools 실행 실패 ({e.__class__.__name__}): {vcf.name}", file=sys.stderr)
        return {}
    if r.returncode != 0:
        print(f"  ! bcftools stats 실패 rc={r.returncode}: {vcf.name}\n"
              f"    {r.stderr.strip().splitlines()[-1] if r.stderr.strip() else ''}",
              file=sys.stderr)
        return {}
    out = {}
    for line in r.stdout.splitlines():
        if line.startswith("SN\t"):
            f = line.split("\t")
            if len(f) >= 4:
                k, v = f[2].rstrip(":").strip(), num(f[3])
                if k == "number of SNPs":
                    out["snp"] = v
                elif k == "number of indels":
                    out["indel"] = v
                elif k == "number of records":
                    out["records"] = v
        elif line.startswith("TSTV\t"):
            f = line.split("\t")
            if len(f) >= 5:
                out["tstv"] = num(f[4])
    return out


def one(dsid, sample, dataset, entry, dup, run_base, ref, want_pass=False):
    """dsid 하나의 지표 + 상태."""
    base = run_base / sample / "PacBio" / dataset
    rid = f"{sample}.{dataset}.{ref}"
    qc = base / "04_QC"
    row = {"dsid": dsid, "sample": sample, "dataset": dataset,
           "entry": entry, "dup_of": dup or "", "status": "", "flags": []}

    # 파이프라인 본산출물이 있는지 (30_verify_outputs.sh와 같은 대표 파일 2개로 판정)
    core = [base / f"03_VCF/deepvariant/{rid}.deepvariant.vcf.gz",
            base / f"03_VCF/clair3/{rid}.clair3.vcf.gz"]
    done = all(f.is_file() and f.stat().st_size > 0 for f in core)
    if not done:
        row["status"] = "dup-skip" if dup else "pending"
        return row
    row["status"] = "done"

    row["cov"] = read_mosdepth(qc / "mosdepth" / f"{rid}.mosdepth.summary.txt")
    row.update(read_samtools(qc / "samtools" / f"{rid}.stats.txt"))

    for caller in ("deepvariant", "clair3", "pbsv"):
        st = read_bcftools(qc / "bcftools_stats" / f"{rid}.{caller}.bcftools_stats.txt")
        pre = {"deepvariant": "dv", "clair3": "c3", "pbsv": "sv"}[caller]
        for k, v in st.items():
            row[f"{pre}_{k}"] = v

    row.update({f"wh_{k}": v for k, v in
                read_whatshap(base / "03_VCF" / "phased_whatshap"
                              / f"{rid}.whatshap_stats.txt").items()})

    mq = run_base / "multiqc" / dsid / "multiqc_report.html"
    row["multiqc"] = "ok" if (mq.is_file() and mq.stat().st_size > 1) else "MISSING"

    if want_pass:
        for caller in ("deepvariant", "clair3"):
            pc = pass_counts(base / f"03_VCF/{caller}" / f"{rid}.{caller}.vcf.gz")
            pre = {"deepvariant": "dv", "clair3": "c3"}[caller]
            for k, v in pc.items():
                row[f"{pre}_pass_{k}"] = v

    # ---- 판정 ----------------------------------------------------------
    F = row["flags"]
    tumor = is_tumor(sample)

    # (1) FILTER 와 무관하게 유효한 지표 -----------------------------------
    if row.get("cov") is None:
        F.append("QC:mosdepth없음")
    elif row["cov"] < TH["cov_min"]:
        F.append(f"저커버리지({row['cov']:.0f}x)")

    if row.get("mapped_pct") is None:
        F.append("QC:samtools없음")
    else:
        if row["mapped_pct"] < TH["mapped_min"]:
            F.append(f"매핑률{row['mapped_pct']:.1f}%")
        if row.get("err_rate") and row["err_rate"] > TH["err_max"]:
            F.append(f"error_rate{row['err_rate']:.3f}")
        if row.get("avg_len") and row["avg_len"] < TH["readlen_min"]:
            F.append(f"리드길이{row['avg_len']:.0f}bp")

    if row.get("dv_snp") is None:
        F.append("QC:bcftools없음")

    # (2) 변이 수·ts/tv·caller 일치 — PASS 를 실제로 셌을 때만 판정한다.
    #     raw 카운트는 RefCall 포함이라 판정 근거가 못 된다 (위 주석 참고).
    snp, indel, tstv = row.get("dv_pass_snp"), row.get("dv_pass_indel"), row.get("dv_pass_tstv")
    if snp is not None and not tumor:
        if not (TH["snp_lo"] <= snp <= TH["snp_hi"]):
            F.append(f"PASS_SNP{snp/1e6:.2f}M")
        if indel and not (TH["indel_lo"] <= indel <= TH["indel_hi"]):
            F.append(f"PASS_INDEL{indel/1e3:.0f}k")
        if tstv and not (TH["tstv_lo"] <= tstv <= TH["tstv_hi"]):
            F.append(f"PASS_ts/tv{tstv:.2f}")
    c3snp = row.get("c3_pass_snp")
    if snp and c3snp:
        hi, lo = max(snp, c3snp), min(snp, c3snp)
        if hi > 0 and lo / hi < TH["caller_ratio_min"]:
            F.append(f"caller불일치(PASS DV {snp/1e6:.2f}M vs C3 {c3snp/1e6:.2f}M)")
    if row.get("sv_records") and not tumor and \
            not (TH["sv_lo"] <= row["sv_records"] <= TH["sv_hi"]):
        F.append(f"SV{row['sv_records']/1e3:.0f}k")

    # (3) 위상 — 분모(heterozygous_variants)도 unfiltered VCF 기준이라 절대값은 낮게 나온다.
    #     germline/tumor 를 나눈 느슨한 하한만 본다.
    if row.get("wh_phased_pct") is None:
        F.append("QC:whatshap없음")
    else:
        lim = TH["phased_min_tumor"] if tumor else TH["phased_min"]
        if row["wh_phased_pct"] < lim:
            F.append(f"위상{row['wh_phased_pct']:.0f}%")
        n50 = row.get("wh_n50")
        if n50 == 0:
            # whatshap ALL 행에서 N50 이 0 으로 나오는 경우가 있다. 실측상 종양 중
            # 위상률 최하위권에서만 발생 → 지표 미산출로 보고 경고에서 제외한다.
            row["wh_n50"] = None
            F.append("N50미산출")
        elif n50 and n50 < TH["n50_min"]:
            F.append(f"blockN50 {n50/1e3:.0f}kb")

    if row["multiqc"] == "MISSING":
        F.append("MultiQC없음")
    return row


def pick_v(row, key):
    """PASS 카운트가 있으면 그것을, 없으면 raw 를 쓴다."""
    pre, rest = key.split("_", 1)
    return row.get(f"{pre}_pass_{rest}", row.get(key))


def fmt(v, spec=""):
    if v is None or v == "":
        return "-"
    if spec:
        try:
            return format(v, spec)
        except (TypeError, ValueError):
            return str(v)
    return str(v)


def main():
    ap = argparse.ArgumentParser(description="phase1 QC 리뷰")
    ap.add_argument("dsids", nargs="*")
    default_base = os.environ.get("RUN_BASE") or (
        (os.environ.get("GIAB_ROOT") or "/BiO/scratch/ehojune/GIAB_benchmark")
        + "/processed_data_ehojune")
    ap.add_argument("--run-base", default=default_base)
    ap.add_argument("--ref-name", default=os.environ.get("REF_NAME", "GRCh38"))
    ap.add_argument("--tsv", help="요약을 TSV로 저장 (공유용)")
    ap.add_argument("--wide", action="store_true", help="전체 컬럼 콘솔 출력")
    ap.add_argument("--pass-counts", action="store_true",
                    help="VCF에서 PASS만 다시 세어 변이 수·ts/tv·caller 일치를 판정한다. "
                         "bcftools 필요, 런당 수십 초~수 분. 켜지 않으면 그 판정은 건너뛴다.")
    a = ap.parse_args()

    run_base = Path(a.run_base)
    if not RUN_TABLE.is_file():
        sys.exit(f"없음: {RUN_TABLE}")
    runs = list(csv.DictReader(RUN_TABLE.read_text(encoding="utf-8").splitlines(),
                               delimiter="\t"))
    if a.dsids:
        want = set(a.dsids)
        runs = [r for r in runs if r["dsid"] in want]
        missing = want - {r["dsid"] for r in runs}
        for m in sorted(missing):
            print(f"?? {m}: run_table.tsv에 없음")

    if a.pass_counts:
        print("PASS 카운트 계산 중 (bcftools, 런당 수십 초)...", file=sys.stderr)
    rows = [one(r["dsid"], r["sample"], r["dataset"], r["entry_type"],
                r.get("dup_of", ""), run_base, a.ref_name, a.pass_counts)
            for r in runs]

    done = [r for r in rows if r["status"] == "done"]
    pend = [r for r in rows if r["status"] == "pending"]
    dups = [r for r in rows if r["status"] == "dup-skip"]

    # DV_SNP/C3_SNP/INDEL/ts-tv 는 --pass-counts 없이는 RefCall 포함 raw 값이라
    # 헤더에 raw 를 붙여 판정 근거가 아님을 드러낸다.
    tag = "" if a.pass_counts else "~"
    cols = [("dsid", 44, ""), ("cov", 6, ".0f"), ("map%", 6, ".1f"),
            ("err", 7, ".4f"), ("len", 6, ".0f"), (tag + "DV_SNP", 8, ".2f"),
            (tag + "C3_SNP", 8, ".2f"), (tag + "INDEL", 7, ".0f"), (tag + "ts/tv", 6, ".2f"),
            ("SV", 6, ".0f"), ("phase%", 7, ".0f"), ("N50kb", 7, ".0f"), ("MQC", 8, "")]
    print()
    print("  ".join(h.ljust(w) for h, w, _ in cols))
    print("-" * (sum(w + 2 for _, w, _ in cols)))
    for r in sorted(done, key=lambda x: x["dsid"]):
        vals = [
            r["dsid"],
            fmt(r.get("cov"), ".0f"),
            fmt(r.get("mapped_pct"), ".1f"),
            fmt(r.get("err_rate"), ".4f"),
            fmt(r.get("avg_len"), ".0f"),
            fmt(pick_v(r, "dv_snp") / 1e6 if pick_v(r, "dv_snp") else None, ".2f"),
            fmt(pick_v(r, "c3_snp") / 1e6 if pick_v(r, "c3_snp") else None, ".2f"),
            fmt(pick_v(r, "dv_indel") / 1e3 if pick_v(r, "dv_indel") else None, ".0f"),
            fmt(pick_v(r, "dv_tstv"), ".2f"),
            fmt(r.get("sv_records") / 1e3 if r.get("sv_records") else None, ".0f"),
            fmt(r.get("wh_phased_pct"), ".0f"),
            fmt(r.get("wh_n50") / 1e3 if r.get("wh_n50") else None, ".0f"),
            r.get("multiqc", "-"),
        ]
        print("  ".join(str(v).ljust(w) for v, (_, w, _s) in zip(vals, cols)))

    print(f"\n단위: cov=평균 depth, DV/C3_SNP=백만, INDEL=천, SV=천, N50kb=위상 block N50")
    print(f"완료 {len(done)} / 대기 {len(pend)} / dup-skip {len(dups)}  (전체 {len(rows)})")

    warned = [r for r in done if r["flags"]]
    qc_missing = [r for r in done if any(f.startswith("QC:") or f == "MultiQC없음"
                                        for f in r["flags"])]
    if warned:
        print(f"\n=== 확인 필요 {len(warned)}건 ===")
        for r in sorted(warned, key=lambda x: x["dsid"]):
            print(f"  {r['dsid']}")
            print(f"      {' / '.join(r['flags'])}")
    else:
        print("\n모든 완료 런이 기준 안에 있음.")

    if pend:
        print(f"\n=== 대기 {len(pend)}건 (아직 산출물 없음) ===")
        for r in sorted(pend, key=lambda x: x["dsid"]):
            print(f"  {r['dsid']}")
    if dups:
        print(f"\n=== dup-skip {len(dups)}건 (DUP_OK=1 로 돌리면 채워짐) ===")
        for r in sorted(dups, key=lambda x: x["dsid"]):
            print(f"  {r['dsid']}  (dup_of {r['dup_of']})")

    if a.tsv:
        keys = ["dsid", "sample", "dataset", "entry", "status", "cov", "mapped_pct",
                "err_rate", "avg_len", "n_reads", "avg_qual",
                "dv_snp", "dv_indel", "dv_tstv", "dv_records",
                "c3_snp", "c3_indel", "c3_tstv", "c3_records",
                "sv_records", "wh_het", "wh_phased", "wh_phased_pct",
                "wh_blocks", "wh_n50", "multiqc"]
        with open(a.tsv, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh, delimiter="\t")
            w.writerow(keys + ["flags"])
            for r in sorted(rows, key=lambda x: x["dsid"]):
                w.writerow([r.get(k, "") if r.get(k) is not None else ""
                            for k in keys] + [" / ".join(r["flags"])])
        print(f"\n-> {a.tsv} ({len(rows)} rows) — 이 파일만 공유하면 리뷰 가능")

    if qc_missing:
        print(f"\nQC 산출물이 빠진 런 {len(qc_missing)}건 → 파이프라인 QC 스테이지 확인 필요")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
