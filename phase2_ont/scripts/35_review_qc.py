#!/usr/bin/env python3
"""phase2(ONT) QC 산출물을 읽어 실행 단위별 지표를 뽑고 이상치를 표시한다.

30_verify_outputs.sh는 VCF·BAM의 존재만 본다. 파일이 있어도 커버리지가 반토막이거나
변이 수가 두 배거나 위상이 거의 안 잡힌 런은 그대로 통과한다. 이 스크립트가 그 틈을 메운다.
phase1의 35_review_qc.py와 같은 구조이고, ONT에서 달라지는 부분만 아래에 적었다.

읽는 것 (전부 파이프라인이 이미 만든 것, 새로 계산하지 않음):
  04_QC/mosdepth/<id>.mosdepth.summary.txt         genome-wide 평균 커버리지
  04_QC/samtools/<id>.stats.txt                    매핑률, error rate, 평균 리드 길이
  04_QC/bcftools_stats/<id>.<caller>.*.txt         caller별 SNP/INDEL/ts-tv/레코드 수
  03_VCF/phased_longphase/<id>.whatshap_stats.txt  위상 비율, block N50
  <RUN_BASE>/multiqc/<dsid>/multiqc_report.html    MultiQC 리포트 존재 여부

사용:
  python phase2_ont/scripts/35_review_qc.py                      # 전체
  python phase2_ont/scripts/35_review_qc.py HG005.UCSC_Ultralong_OxfordNanopore_Promethion
  python phase2_ont/scripts/35_review_qc.py --tsv qc_review_ont.tsv   # 공유용 요약 저장
  python phase2_ont/scripts/35_review_qc.py --pass-counts         # PASS만 다시 세어 변이 수까지 판정
  python phase2_ont/scripts/35_review_qc.py --calibrate           # 케미스트리별 실측 분포 (임계값 조정용)
  python phase2_ont/scripts/35_review_qc.py --check-meth          # uBAM 진입 런의 MM/ML 태그 보존 확인

── ONT가 phase1과 다른 점 ─────────────────────────────────────────────────
1. **임계값을 케미스트리로 나눈다.** R9.4.1(guppy)의 리드 오류율은 R10.4.1 sup(dorado)의
   5배 수준이다. phase1의 단일 err_max=0.02를 그대로 쓰면 R9 런 12개가 전부 오탐으로 찍힌다.
   phase1이 정상/종양으로 위상 하한을 나눈 것과 같은 종류의 적응이다.
2. **DeepVariant는 R10.4.1 런에만 있다** (1.10.0의 ONT 모델은 ONT_R104뿐). R9 런의 DV 칸은
   '없음'이 아니라 '해당 없음'이므로 `.`으로 찍고 caller 일치 판정에서도 뺀다.
   판정 근거는 run_table.tsv의 dv_model 열이다 (20_status.sh의 ACDSPH 규칙과 같은 축).
3. **커버리지는 데이터셋마다 설계상 크게 다르다** (rel1 6x ~ HG008T-p2 100x). 낮은 하한만 두고
   실제 값을 보여준다. rel1·rel2처럼 원래 낮은 것은 dup 게이트로 기본 제출에서 빠져 있다.
4. **R9의 indel 수는 신뢰도가 낮다** — homopolymer 오류 때문에 R9 ONT의 indel 정확도는
   SNV보다 크게 떨어진다. R9의 indel 상한을 R10보다 훨씬 느슨하게 뒀다.
5. **매핑률은 리드 개수가 아니라 염기 기준으로 판정한다.** ONT 릴리스에 섞인 짧은 fail 리드가
   리드 개수 기준 매핑률을 39%까지 끌어내리는데 정렬 자체는 정상이다 (근거는 TH 주석의 실측).
6. **위상 block N50 하한이 HiFi보다 높다.** ONT 장리드(UL은 100 kb+)는 블록이 훨씬 길게 잡힌다.
7. **MM/ML 태그 보존 확인**(--check-meth). uBAM 진입 경로의 존재 이유가 메틸 태그 보존인데
   지금까지 그걸 검증하는 곳이 없었다. minimap2의 -y가 빠지는 회귀가 조용히 지나가면
   그 경로의 의미가 사라지므로 여기서 실제 BAM을 표본으로 확인한다.

주의 1 (phase1과 동일): 파이프라인의 04_QC/bcftools_stats 는 PASS 필터 없이 돌아서
SNP/INDEL/ts-tv 가 RefCall 포함 raw 카운트다. 기본 실행은 그 값을 ~표시로 보여주기만 하고
판정하지 않는다. 변이 수로 판정하려면 --pass-counts (bcftools 필요, 런당 수십 초).

주의 2: 임계값은 2026-08-27 첫 완주 13런으로 한 번 조정했다 (error rate, 매핑률 지표 교체).
**염기 매핑률 하한과 변이 수 대역은 아직 잠정값이다** — `--calibrate` 로 분포를 다시 보고 조일 것.

exit 1 = 완료된 런인데 QC 파일이 없음(파이프라인 QC 스테이지 실패). WARN만이면 exit 0.
"""
import argparse
import csv
import os
import re
import statistics
import subprocess
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
PHASE2 = HERE.parent
RUN_TABLE = PHASE2 / "run_table.tsv"
NF_CONFIG = PHASE2 / "pipeline" / "ont-wgs" / "nextflow.config"

# ── 임계값 ────────────────────────────────────────────────────────────────
# ONT 13런 실측 (2026-08-27, 첫 완주분 + --pass-counts) 으로 조정했다.
# 전체 수치와 해석은 docs/reference/2026-08-27-ont-qc-first-pass.md.
#
# **리드 개수 기준 매핑률은 ONT에서 파이프라인 건강도 지표가 못 된다.** R9 8런의 rd% 가
# 39.1~89.3 으로 벌어졌지만 정렬 실패가 아니었다 — 미매핑 리드의 평균 길이가 매핑된 리드의
# 1/7~1/12 이다 (HG004: 매핑 19,676bp vs 미매핑 1,599bp = 12.3배). 짧은 fail/adapter 리드가
# 개수만 채우고 염기는 기여하지 않는다. 같은 런들의 염기 매핑률은 90.6~95.2% 로 정상이고
# SNP 수·ts/tv·위상률도 rd% 와 무관하게 일정하다.
#   예외: HG001(rel6)은 미매핑/매핑 길이비가 1.0 이다 — 짧은 리드가 아니라 2016~17년 R9.4
#   구형 베이스콜의 진짜 미매핑이고, 그래서 염기 매핑률도 최저(83.3%)다. 버그는 아니다.
# 그래서 판정은 **염기 기준(bases mapped (cigar) / total length)** 으로 하고, 리드 개수 기준은
# 표시만 하며 트립와이어로만 쓴다. 미매핑 리드 평균 길이(unmap_len)를 같이 찍어 원인을 보여준다.
#
# ts/tv 는 전 런이 이상치(~2.0~2.1)보다 낮다 (R9 1.86~1.97, R10 1.65~1.73). 코호트 전체가
# 같이 낮으므로 **개별 런 게이트로는 쓸 수 없다** — 하한을 코호트 밖을 잡는 값으로 느슨하게 두고,
# 절대 수준의 문제(FP 과다)는 truth set 대비 hap.py 로 따로 판정한다 (phase2에는 아직 없음).
TH = {
    # 케미스트리와 무관
    "cov_min": 8.0,           # ONT는 데이터셋별 설계 심도가 6x~100x로 벌어진다. 하한만 둔다
    "readmap_tripwire": 30.0, # 리드 개수 기준. 이 밑이면 짧은 리드로도 설명이 안 된다
    "snp_lo": 3_500_000, "snp_hi": 5_200_000,   # 실측 PASS 4.05~4.76M
    "tstv_lo": 1.60, "tstv_hi": 2.30,  # 실측 1.65~1.97. 코호트 전체가 이상치보다 낮아
                                       # 게이트는 코호트 밖만 잡는다 (위 주석 참고)
    "sv_lo": 15_000, "sv_hi": 40_000,  # 실측 Sniffles2 21.6~24.6k (13런이 좁게 모였다)
    "caller_ratio_min": 0.8,  # R10에서만 (DV↔C3 둘 다 있을 때)
    # 위상 — LongPhase. ONT 장리드는 블록이 길다
    "phased_min": 70.0,
    "phased_min_tumor": 55.0,   # 종양은 LOH·aneuploidy로 het 자체가 줄어 위상 대상이 줄어든다
    "n50_min": 300_000,         # 실측 526kb~87Mb. HiFi(20kb)와 자릿수가 다르다
    "meth_min_pct": 50.0,       # uBAM 진입 런의 표본 리드 중 MM 태그 보유 비율
}
# 케미스트리별로 갈리는 것: 리드 오류율과 그 파생 지표
TH_CHEM = {
    "R9": {
        "basemap_min": 80.0,   # 실측 83.3~95.2 (최저는 HG001 rel6 구형 베이스콜)
        "err_max": 0.15,       # 실측 0.0896~0.1360
        "readlen_min": 1_000,
        # 실측 PASS 544k~1969k. **베이스콜러 버전이 지배한다** — guppy 4.2.2는 544~551k인데
        # guppy 3.2.x는 1751~1969k로 3.5배다 (homopolymer indel FP). 정상 범위가 원래 넓으니
        # 상한을 느슨하게 두고, 어느 런의 indel을 신뢰할지는 베이스콜러로 판단한다.
        "indel_lo": 400_000, "indel_hi": 2_200_000,
    },
    "R10": {
        "basemap_min": 96.0,   # 실측 98.2~99.8 (dorado sup은 거의 전부 정렬된다)
        "err_max": 0.06,       # 실측 0.0328~0.0531. 0.05는 UL 런(avg_len 52.9kb)을 오탐으로
                               # 잡았다 — 리드가 길수록 error rate가 조금 올라간다
        "readlen_min": 1_000,
        "indel_lo": 500_000, "indel_hi": 1_100_000,   # 실측 PASS 644~838k
    },
}
TUMOR_PAT = ("HG008-T", "HG008T")   # HG008-N-D / HG008-N-P 는 정상이다


def chem_of(chemistry):
    """run_table.tsv의 chemistry 문자열 -> 'R9' | 'R10'."""
    return "R10" if "R10" in chemistry else "R9"


def is_tumor(sample):
    return any(sample.startswith(p) for p in TUMOR_PAT)


def num(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def read_mosdepth(p):
    """mosdepth.summary.txt의 total 행 mean."""
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
        "maximum length": "max_len",
        "error rate": "err_rate",
        "average quality": "avg_qual",
        "total length": "total_bases",
        # CIGAR의 M/I 기준으로 실제 정렬된 염기. "bases mapped"(=매핑된 리드의 전체 길이,
        # soft-clip 포함)보다 엄격해서 파이프라인 건강도 지표로 이쪽을 쓴다.
        "bases mapped (cigar)": "bases_mapped",
    }
    for line in p.read_text(errors="ignore").splitlines():
        if not line.startswith("SN\t"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        key = parts[1].rstrip(":").strip()
        if key in want:
            out[want[key]] = num(parts[2].split()[0]) if parts[2].strip() else None
    if out.get("n_reads") and out.get("n_mapped") is not None:
        out["mapped_pct"] = 100.0 * out["n_mapped"] / out["n_reads"]
    if out.get("total_bases") and out.get("bases_mapped") is not None:
        out["basemap_pct"] = 100.0 * out["bases_mapped"] / out["total_bases"]
    # 미매핑 리드의 평균 길이. rd% 가 낮을 때 그게 "짧은 fail 리드" 때문인지
    # "진짜 정렬 실패" 때문인지 가르는 지표다 (위 TH 주석의 실측 참고).
    n_un = (out.get("n_reads") or 0) - (out.get("n_mapped") or 0)
    b_un = (out.get("total_bases") or 0) - (out.get("bases_mapped") or 0)
    if n_un > 0 and b_un > 0:
        out["unmap_len"] = b_un / n_un
        if out.get("avg_len"):
            out["unmap_ratio"] = out["avg_len"] / out["unmap_len"]
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
                k, v = f[2].rstrip(":").strip(), num(f[3])
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

    het, ph = col("heterozygous_variants"), col("phased")
    out["het"], out["phased"] = het, ph
    out["blocks"], out["n50"] = col("blocks"), col("block_n50")
    if het and ph is not None and het > 0:
        out["phased_pct"] = 100.0 * ph / het
    return out


def pass_counts(vcf):
    """VCF에서 PASS 레코드만 세어 SNV/INDEL/ts-tv를 돌려준다.

    파이프라인의 04_QC/bcftools_stats는 RefCall 포함 raw 카운트라 진짜 변이 수를 알려면
    다시 세야 한다. bcftools가 필요하고 VCF 1개에 수십 초 걸리므로 --pass-counts로만 켠다.
    """
    if not vcf.is_file():
        return {}
    try:
        r = subprocess.run(["bcftools", "stats", "-f", "PASS", str(vcf)],
                           capture_output=True, text=True, timeout=3600)
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"  ! bcftools 실행 실패 ({e.__class__.__name__}): {vcf.name}", file=sys.stderr)
        return {}
    if r.returncode != 0:
        last = r.stderr.strip().splitlines()[-1] if r.stderr.strip() else ""
        print(f"  ! bcftools stats 실패 rc={r.returncode}: {vcf.name}\n    {last}", file=sys.stderr)
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


def samtools_img():
    """캐시된 samtools 컨테이너 경로. 로그인 노드에 samtools가 PATH로 없다 (03_dup_evidence.sh와 같은 이유)."""
    cachedir = os.environ.get("NXF_SINGULARITY_CACHEDIR")
    if not cachedir:
        infra = os.environ.get("INFRA")
        if not infra:
            return None
        cachedir = f"{infra}/containers"
    m = re.search(r"container_samtools\s*=\s*'([^']+)'", NF_CONFIG.read_text(encoding="utf-8"))
    if not m:
        return None
    img = Path(cachedir) / (re.sub(r"[/:]", "-", m.group(1)) + ".img")
    return img if img.is_file() else None


def meth_tag_pct(bam, img, n=200):
    """정렬 BAM 앞부분 n개 리드 중 MM 태그를 가진 비율(%).

    uBAM 진입 경로의 목적이 5mC/5hmC(MM/ML) 보존이다. minimap2의 -y가 빠지거나
    samtools fastq의 -T가 빠지면 조용히 태그만 사라지므로 실제 레코드를 표본으로 본다.
    """
    if not bam.is_file() or img is None:
        return None
    root = os.environ.get("GIAB_ROOT", "/BiO/scratch")
    cmd = ["singularity", "exec", "--bind", root, str(img),
           "samtools", "view", str(bam)]
    try:
        # awk가 먼저 끝나면 앞단이 SIGPIPE로 죽는다 -> 파이프를 파이썬에서 끊고 rc는 무시한다
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        seen = tagged = 0
        for line in p.stdout:
            seen += 1
            if "MM:Z:" in line:
                tagged += 1
            if seen >= n:
                break
        p.stdout.close()
        p.terminate()
        p.wait(timeout=30)
    except Exception as e:
        print(f"  ! MM 태그 확인 실패 ({e.__class__.__name__}): {bam.name}", file=sys.stderr)
        return None
    return 100.0 * tagged / seen if seen else None


def one(run, run_base, ref, want_pass=False, want_meth=False, img=None):
    """dsid 하나의 지표 + 상태."""
    dsid, sample, dataset = run["dsid"], run["sample"], run["dataset"]
    entry, dup = run["entry_type"], run.get("dup_of", "")
    dv_model, chem = run.get("dv_model", "-"), chem_of(run.get("chemistry", ""))
    base = run_base / sample / "ONT" / dataset
    rid = f"{sample}.{dataset}.{ref}"
    qc = base / "04_QC"
    row = {"dsid": dsid, "sample": sample, "dataset": dataset, "entry": entry,
           "chem": chem, "dv_model": dv_model, "dup_of": dup or "",
           "status": "", "flags": []}

    # 파이프라인 본산출물이 있는지. Clair3는 전 런 공통이고 Sniffles2는 SV 쪽 대표다
    core = [base / f"03_VCF/clair3/{rid}.clair3.vcf.gz",
            base / f"03_VCF/SV_sniffles/{rid}.sniffles.vcf.gz"]
    if not all(f.is_file() and f.stat().st_size > 0 for f in core):
        row["status"] = "dup-skip" if dup else "pending"
        return row
    row["status"] = "done"

    row["cov"] = read_mosdepth(qc / "mosdepth" / f"{rid}.mosdepth.summary.txt")
    row.update(read_samtools(qc / "samtools" / f"{rid}.stats.txt"))

    for caller, pre in (("clair3", "c3"), ("deepvariant", "dv"), ("sniffles", "sv")):
        st = read_bcftools(qc / "bcftools_stats" / f"{rid}.{caller}.bcftools_stats.txt")
        for k, v in st.items():
            row[f"{pre}_{k}"] = v

    row.update({f"wh_{k}": v for k, v in
                read_whatshap(base / "03_VCF" / "phased_longphase"
                              / f"{rid}.whatshap_stats.txt").items()})

    mq = run_base / "multiqc" / dsid / "multiqc_report.html"
    row["multiqc"] = "ok" if (mq.is_file() and mq.stat().st_size > 1) else "MISSING"

    if want_pass:
        callers = [("clair3", "c3")] + ([("deepvariant", "dv")] if dv_model != "-" else [])
        for caller, pre in callers:
            for k, v in pass_counts(base / f"03_VCF/{caller}" / f"{rid}.{caller}.vcf.gz").items():
                row[f"{pre}_pass_{k}"] = v

    if want_meth and entry == "ubam":
        row["meth_pct"] = meth_tag_pct(base / "02_alignedBAM" / f"{rid}.bam", img)

    # ---- 판정 ----------------------------------------------------------
    F = row["flags"]
    tumor = is_tumor(sample)
    T = TH_CHEM[chem]

    # (1) FILTER와 무관하게 유효한 지표
    if row.get("cov") is None:
        F.append("QC:mosdepth없음")
    elif row["cov"] < TH["cov_min"]:
        F.append(f"저커버리지({row['cov']:.0f}x)")

    if row.get("mapped_pct") is None:
        F.append("QC:samtools없음")
    else:
        # 판정은 염기 기준으로 한다. 리드 개수 기준은 ONT에서 짧은 fail 리드에 끌려다닌다
        # (위 TH 주석의 실측 참고) — 정말 깨진 경우만 트립와이어로 잡는다.
        bp = row.get("basemap_pct")
        if bp is None:
            F.append("QC:염기매핑률없음")
        elif bp < T["basemap_min"]:
            F.append(f"염기매핑률{bp:.1f}%({chem}기준{T['basemap_min']:.0f})")
        if row["mapped_pct"] < TH["readmap_tripwire"]:
            F.append(f"리드매핑률{row['mapped_pct']:.1f}%(트립와이어{TH['readmap_tripwire']:.0f})")
        if row.get("err_rate") and row["err_rate"] > T["err_max"]:
            F.append(f"error_rate{row['err_rate']:.3f}({chem}기준{T['err_max']})")
        if row.get("avg_len") and row["avg_len"] < T["readlen_min"]:
            F.append(f"리드길이{row['avg_len']:.0f}bp")

    if row.get("c3_snp") is None:
        F.append("QC:bcftools없음")
    # R10인데 DeepVariant 통계가 없으면 스테이지가 빠진 것이다
    if dv_model != "-" and row.get("dv_snp") is None:
        F.append("QC:DV통계없음")

    # (2) 변이 수·ts/tv·caller 일치 — PASS를 실제로 셌을 때만 판정 (raw는 RefCall 포함)
    snp = row.get("c3_pass_snp")
    indel, tstv = row.get("c3_pass_indel"), row.get("c3_pass_tstv")
    if snp is not None and not tumor:
        if not (TH["snp_lo"] <= snp <= TH["snp_hi"]):
            F.append(f"PASS_SNP{snp/1e6:.2f}M")
        if indel and not (T["indel_lo"] <= indel <= T["indel_hi"]):
            F.append(f"PASS_INDEL{indel/1e3:.0f}k({chem}기준)")
        if tstv and not (TH["tstv_lo"] <= tstv <= TH["tstv_hi"]):
            F.append(f"PASS_ts/tv{tstv:.2f}")
    dvsnp = row.get("dv_pass_snp")
    if snp and dvsnp:   # R10에서만 둘 다 있다
        hi, lo = max(snp, dvsnp), min(snp, dvsnp)
        if hi > 0 and lo / hi < TH["caller_ratio_min"]:
            F.append(f"caller불일치(PASS C3 {snp/1e6:.2f}M vs DV {dvsnp/1e6:.2f}M)")
    if row.get("sv_records") and not tumor and \
            not (TH["sv_lo"] <= row["sv_records"] <= TH["sv_hi"]):
        F.append(f"SV{row['sv_records']/1e3:.0f}k")

    # (3) 위상
    if row.get("wh_phased_pct") is None:
        F.append("QC:whatshap없음")
    else:
        lim = TH["phased_min_tumor"] if tumor else TH["phased_min"]
        if row["wh_phased_pct"] < lim:
            F.append(f"위상{row['wh_phased_pct']:.0f}%")
        n50 = row.get("wh_n50")
        if n50 == 0:
            row["wh_n50"] = None
            F.append("N50미산출")
        elif n50 and n50 < TH["n50_min"]:
            F.append(f"blockN50 {n50/1e3:.0f}kb")

    # (4) 메틸 태그 (uBAM 진입 런만)
    if row.get("meth_pct") is not None and row["meth_pct"] < TH["meth_min_pct"]:
        F.append(f"MM태그{row['meth_pct']:.0f}% — uBAM 진입인데 메틸 태그가 유실됐다")

    if row["multiqc"] == "MISSING":
        F.append("MultiQC없음")
    return row


def pick_v(row, key):
    """PASS 카운트가 있으면 그것을, 없으면 raw를 쓴다."""
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


def calibrate(done):
    """케미스트리별 실측 분포. TH를 실측으로 고칠 때 쓴다."""
    metrics = [("cov", "평균 depth", 1), ("basemap_pct", "염기 매핑률%", 1),
               ("mapped_pct", "리드 매핑률%", 1), ("unmap_len", "미매핑 평균길이bp", 0),
               ("unmap_ratio", "매핑/미매핑 길이비", 1),
               ("err_rate", "error rate", 4), ("avg_len", "평균 리드길이bp", 0),
               ("c3_snp", "C3 SNP(raw)", 0), ("c3_indel", "C3 INDEL(raw)", 0),
               ("c3_tstv", "C3 ts/tv(raw)", 2), ("sv_records", "SV 레코드", 0),
               ("wh_phased_pct", "위상%", 1), ("wh_n50", "block N50", 0)]
    print("\n=== 케미스트리별 실측 분포 (임계값 조정 근거) ===")
    for chem in ("R9", "R10"):
        grp = [r for r in done if r["chem"] == chem]
        if not grp:
            continue
        print(f"\n-- {chem} ({len(grp)} run) --")
        print(f"   {'지표':22s} {'min':>12s} {'median':>12s} {'max':>12s}")
        for key, label, nd in metrics:
            vals = [r[key] for r in grp if r.get(key) is not None]
            if not vals:
                print(f"   {label:22s} {'(값 없음)':>12s}")
                continue
            print(f"   {label:22s} {min(vals):12.{nd}f} "
                  f"{statistics.median(vals):12.{nd}f} {max(vals):12.{nd}f}")
    print("\n종양(HG008-T*)은 위상·변이 수가 정상과 다르게 나오는 게 정상이다 — 섞어서 보지 말 것.")


def main():
    ap = argparse.ArgumentParser(description="phase2(ONT) QC 리뷰")
    ap.add_argument("dsids", nargs="*")
    default_base = os.environ.get("RUN_BASE") or (
        (os.environ.get("GIAB_ROOT") or "/BiO/scratch/ehojune/GIAB_benchmark")
        + "/processed_data_ehojune")
    ap.add_argument("--run-base", default=default_base)
    ap.add_argument("--ref-name", default=os.environ.get("REF_NAME", "GRCh38"))
    ap.add_argument("--tsv", help="요약을 TSV로 저장 (공유용)")
    ap.add_argument("--pass-counts", action="store_true",
                    help="VCF에서 PASS만 다시 세어 변이 수·ts/tv·caller 일치를 판정한다. "
                         "bcftools 필요, 런당 수십 초~수 분. 켜지 않으면 그 판정은 건너뛴다.")
    ap.add_argument("--calibrate", action="store_true",
                    help="케미스트리별 실측 분포를 출력한다 (TH 잠정값을 실측으로 고칠 때)")
    ap.add_argument("--check-meth", action="store_true",
                    help="uBAM 진입 런의 정렬 BAM에서 MM 태그 보존을 표본 확인 (samtools 컨테이너 필요)")
    a = ap.parse_args()

    run_base = Path(a.run_base)
    if not RUN_TABLE.is_file():
        sys.exit(f"없음: {RUN_TABLE}")
    runs = list(csv.DictReader(RUN_TABLE.read_text(encoding="utf-8").splitlines(),
                               delimiter="\t"))
    if a.dsids:
        want = set(a.dsids)
        runs = [r for r in runs if r["dsid"] in want]
        for m in sorted(want - {r["dsid"] for r in runs}):
            print(f"?? {m}: run_table.tsv에 없음")

    img = None
    if a.check_meth:
        img = samtools_img()
        if img is None:
            print("! samtools 컨테이너를 못 찾았다 — env.sh를 source 했는지 확인. "
                  "MM 태그 확인을 건너뛴다.", file=sys.stderr)
    if a.pass_counts:
        print("PASS 카운트 계산 중 (bcftools, 런당 수십 초)...", file=sys.stderr)

    rows = [one(r, run_base, a.ref_name, a.pass_counts, a.check_meth, img) for r in runs]
    done = [r for r in rows if r["status"] == "done"]
    pend = [r for r in rows if r["status"] == "pending"]
    dups = [r for r in rows if r["status"] == "dup-skip"]

    # C3_SNP/DV_SNP/INDEL/ts-tv 는 --pass-counts 없이는 RefCall 포함 raw 값이라
    # 헤더에 ~를 붙여 판정 근거가 아님을 드러낸다.
    tag = "" if a.pass_counts else "~"
    cols = [("dsid", 46, ""), ("chem", 5, ""), ("cov", 6, ".0f"), ("base%", 6, ".1f"),
            ("rd%", 5, ".1f"), ("err", 7, ".4f"), ("len", 7, ".0f"), ("unmapLen", 8, ".0f"),
            (tag + "C3_SNP", 8, ".2f"),
            (tag + "DV_SNP", 8, ".2f"), (tag + "INDEL", 7, ".0f"), (tag + "ts/tv", 6, ".2f"),
            ("SV", 6, ".0f"), ("phase%", 7, ".0f"), ("N50kb", 7, ".0f")]
    if a.check_meth:
        cols.append(("MM%", 5, ".0f"))
    cols.append(("MQC", 8, ""))
    print()
    print("  ".join(h.ljust(w) for h, w, _ in cols))
    print("-" * (sum(w + 2 for _, w, _ in cols)))
    for r in sorted(done, key=lambda x: x["dsid"]):
        dv = pick_v(r, "dv_snp")
        vals = [
            r["dsid"], r["chem"],
            fmt(r.get("cov"), ".0f"), fmt(r.get("basemap_pct"), ".1f"),
            fmt(r.get("mapped_pct"), ".1f"),
            fmt(r.get("err_rate"), ".4f"), fmt(r.get("avg_len"), ".0f"),
            fmt(r.get("unmap_len"), ".0f"),
            fmt(pick_v(r, "c3_snp") / 1e6 if pick_v(r, "c3_snp") else None, ".2f"),
            # R9은 DeepVariant 모델이 없어 안 돌린다 — '없음'(-)과 구분해 '.'으로 찍는다
            ("." if r["dv_model"] == "-" else fmt(dv / 1e6 if dv else None, ".2f")),
            fmt(pick_v(r, "c3_indel") / 1e3 if pick_v(r, "c3_indel") else None, ".0f"),
            fmt(pick_v(r, "c3_tstv"), ".2f"),
            fmt(r.get("sv_records") / 1e3 if r.get("sv_records") else None, ".0f"),
            fmt(r.get("wh_phased_pct"), ".0f"),
            fmt(r.get("wh_n50") / 1e3 if r.get("wh_n50") else None, ".0f"),
        ]
        if a.check_meth:
            vals.append("." if r["entry"] != "ubam" else fmt(r.get("meth_pct"), ".0f"))
        vals.append(r.get("multiqc", "-"))
        print("  ".join(str(v).ljust(w) for v, (_, w, _s) in zip(vals, cols)))

    print("\n단위: cov=평균 depth, C3/DV_SNP=백만, INDEL=천, SV=천, N50kb=위상 block N50")
    print("'.' = 해당 없음 (R9.4.1 런에는 DeepVariant ONT 모델이 없다 / fastq 진입은 MM 태그 없음)")
    print(f"완료 {len(done)} / 대기 {len(pend)} / dup-skip {len(dups)}  (전체 {len(rows)})")
    if not a.pass_counts:
        print("~ 표시 = RefCall 포함 raw 카운트. 변이 수 판정은 --pass-counts 로만.")

    warned = [r for r in done if r["flags"]]
    qc_missing = [r for r in done if any(f.startswith("QC:") or f == "MultiQC없음"
                                        for f in r["flags"])]
    if warned:
        print(f"\n=== 확인 필요 {len(warned)}건 ===")
        for r in sorted(warned, key=lambda x: x["dsid"]):
            print(f"  {r['dsid']}  [{r['chem']}]")
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

    if a.calibrate:
        calibrate(done)

    if a.tsv:
        keys = ["dsid", "sample", "dataset", "entry", "chem", "dv_model", "status",
                "cov", "basemap_pct", "mapped_pct", "err_rate", "avg_len", "max_len",
                "unmap_len", "unmap_ratio", "n_reads", "total_bases", "bases_mapped", "avg_qual",
                "c3_snp", "c3_indel", "c3_tstv", "c3_records",
                "dv_snp", "dv_indel", "dv_tstv", "dv_records",
                "c3_pass_snp", "c3_pass_indel", "c3_pass_tstv",
                "dv_pass_snp", "dv_pass_indel", "dv_pass_tstv",
                "sv_records", "wh_het", "wh_phased", "wh_phased_pct",
                "wh_blocks", "wh_n50", "meth_pct", "multiqc"]
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
