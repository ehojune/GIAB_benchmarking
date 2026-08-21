#!/usr/bin/env python3
"""완료된 phase1 run을 catalog/master_catalog.tsv에 반영하고 README 표를 재생성한다.

동작:
- run_table.tsv의 실행 단위별로 산출물(BAM·VCF·index) 존재를 검증
- 카탈로그 행(=GIAB 데이터셋 디렉토리) 하나는 소속 실행 단위가 **전부** 완료됐을 때만 기록
  (HG008 행=T+N 2개, HG009 행=passage/클론 여러 개가 한 행에 속함)
- 완료 행의 정렬/페이징/변이 칸을 me 값으로 채운다. GIAB가 이미 TRUE인 칸도 덮어쓴다 —
  2026-08-21 정책이 "GIAB 처리 무시하고 raw부터 전부 재실행"이고, GIAB 산출물 내역은
  giab_processed 열과 notes에 남아 있어서 정보 손실이 없다.
  (aligned_bam 진입 행은 내가 정렬한 게 아니므로 정렬 칸은 GIAB 그대로 둔다)
- 마지막에 catalog/build_readme.py를 돌려 README.md 표를 재생성

사용 (nbb2, repo 루트 어디서든):
  python phase1_pacbio_hifi/scripts/50_update_catalog.py [--run-base ...] [--dry-run]
끝나면 git diff로 확인하고 커밋한다. 재실행해도 같은 값이라 안전하다(멱등).
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

# LANG=C 환경(SGE 잡 등)에서 한글 출력이 UnicodeEncodeError로 죽지 않게
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
PHASE1 = HERE.parent
REPO = PHASE1.parent
CATALOG = REPO / "catalog" / "master_catalog.tsv"
NF_CONFIG = PHASE1 / "pipeline" / "pacbio-hifi-wgs" / "nextflow.config"
SCRIPT_REF = "phase1_pacbio_hifi/scripts/10_submit.sh"


def tool_versions():
    """vendored nextflow.config의 컨테이너 핀에서 버전 추출 (버전의 단일 출처)."""
    text = NF_CONFIG.read_text(encoding="utf-8")
    v = {}
    for name, uri in re.findall(r"container_(\w+)\s*=\s*'([^']+)'", text):
        tag = uri.rsplit(":", 1)[1].split("--")[0]
        v[name] = tag
    return v


def read_tsv(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    return [ln.split("\t") for ln in lines]


def load_runs():
    rows = read_tsv(PHASE1 / "run_table.tsv")
    hdr = rows[0]
    return [dict(zip(hdr, r)) for r in rows[1:]]


def verified(run, run_base, ref_name):
    """30_verify_outputs.sh와 같은 기준: 핵심 산출물 존재 + 비어있지 않음."""
    sample, dataset, entry = run["sample"], run["dataset"], run["entry_type"]
    base = Path(run_base) / sample / "PacBio" / dataset
    rid = f"{sample}.{dataset}.{ref_name}"
    need = [
        f"03_VCF/deepvariant/{rid}.deepvariant.vcf.gz",
        f"03_VCF/deepvariant/{rid}.deepvariant.vcf.gz.tbi",
        f"03_VCF/clair3/{rid}.clair3.vcf.gz",
        f"03_VCF/clair3/{rid}.clair3.vcf.gz.tbi",
        f"03_VCF/SV_pbsv/{rid}.pbsv.vcf.gz",
        f"03_VCF/SV_pbsv/{rid}.pbsv.vcf.gz.tbi",
        f"03_VCF/phased_whatshap/{rid}.deepvariant.phased.vcf.gz",
        f"03_VCF/phased_whatshap/{rid}.deepvariant.phased.vcf.gz.tbi",
        f"03_VCF/SNV_deepvariant/{rid}.deepvariant.snv.vcf.gz",
        f"03_VCF/INDEL_deepvariant/{rid}.deepvariant.indel.vcf.gz",
        f"03_VCF/SNV_clair3/{rid}.clair3.snv.vcf.gz",
        f"03_VCF/INDEL_clair3/{rid}.clair3.indel.vcf.gz",
    ]
    if entry != "aligned_bam":
        need += [f"02_alignedBAM/{rid}.bam", f"02_alignedBAM/{rid}.bam.bai"]
    return all((base / f).exists() and (base / f).stat().st_size > 0 for f in need)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-base", default="/BiO/scratch/ehojune/GIAB_benchmark/processed_data_ehojune")
    ap.add_argument("--ref-name", default="GRCh38")
    ap.add_argument("--dry-run", action="store_true", help="TSV/README 수정 없이 판정만 출력")
    args = ap.parse_args()

    ver = tool_versions()
    align_tool = f"pbmm2 v{ver['pbmm2']}"
    phase_tool = f"WhatsHap v{ver['whatshap']} (DeepVariant VCF phase+haplotag)"
    var_tool = f"DeepVariant v{ver['deepvariant']} + Clair3 {ver['clair3']} + pbsv v{ver['pbsv']}"

    runs = load_runs()
    # 카탈로그 행 key = (HG샘플, GIAB 디렉토리 basename). run sample 은 HG009T-1C3 처럼 파생형.
    groups = {}
    for r in runs:
        hg = re.match(r"HG\d{3}", r["sample"]).group(0)
        groups.setdefault((hg, r["dataset"]), []).append(r)

    rows = read_tsv(CATALOG)
    hdr = rows[0]
    ix = {c: i for i, c in enumerate(hdr)}

    def set_cell(row, colname, value, changes):
        i = ix[colname]
        if row[i] != value:
            changes.append(f"{colname}: {row[i] or '(빈칸)'} -> {value}")
            row[i] = value

    updated, pending, missing_rows = [], [], []
    for row in rows[1:]:
        if row[ix["category"]] != "pacbio_hifi":
            continue
        key = (row[ix["sample"]], row[ix["giab_path"]].rstrip("/").rsplit("/", 1)[-1])
        ds_runs = groups.get(key)
        if not ds_runs:
            missing_rows.append(f"{key[0]} {key[1]}")
            continue
        done = [verified(r, args.run_base, args.ref_name) for r in ds_runs]
        label = f"{key[0]}/{key[1]} ({sum(done)}/{len(done)} run 완료)"
        if not all(done):
            pending.append(label)
            continue

        samples = sorted({r["sample"] for r in ds_runs})
        mid = f"{args.run_base}/{samples[0] if len(samples) == 1 else '*'}/PacBio/{key[1]}"
        changes = []
        if any(r["entry_type"] != "aligned_bam" for r in ds_runs):
            set_cell(row, "aligned", "TRUE", changes)
            set_cell(row, "align_tool", align_tool, changes)
            set_cell(row, "align_ref", "GRCh38 (GCA_000001405.15 no_alt_analysis_set)", changes)
            set_cell(row, "align_by", "me", changes)
            set_cell(row, "align_local_path", f"{mid}/02_alignedBAM", changes)
            set_cell(row, "align_script", SCRIPT_REF, changes)
        set_cell(row, "phased", "TRUE", changes)
        set_cell(row, "phase_tool", phase_tool, changes)
        set_cell(row, "phase_by", "me", changes)
        set_cell(row, "phase_local_path", f"{mid}/03_VCF/phased_whatshap", changes)
        set_cell(row, "phase_script", SCRIPT_REF, changes)
        set_cell(row, "variant_called", "TRUE", changes)
        set_cell(row, "variant_tool", var_tool, changes)
        set_cell(row, "variant_by", "me", changes)
        set_cell(row, "variant_local_path", f"{mid}/03_VCF", changes)
        set_cell(row, "variant_script", SCRIPT_REF, changes)
        if changes:
            updated.append((label, changes))

    for label in pending:
        print(f"대기: {label}")
    for m in missing_rows:
        print(f"경고: run_table에 대응 실행 단위가 없음 — {m}")
    if not updated:
        print("갱신할 완료 행 없음.")
        return
    for label, changes in updated:
        print(f"기록: {label}")
        for c in changes:
            print(f"    {c}")
    if args.dry_run:
        print("(--dry-run: 파일 수정 안 함)")
        return

    with open(CATALOG, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join("\t".join(r) for r in rows) + "\n")
    subprocess.run([sys.executable, str(REPO / "catalog" / "build_readme.py")], check=True)
    print(f"{len(updated)}개 행 갱신 + README 표 재생성 완료. git diff 확인 후 커밋할 것.")
    print("참고: 갱신된 행의 next_step 문구는 자동으로 안 고침 — 낡았으면 직접 수정.")


if __name__ == "__main__":
    main()
