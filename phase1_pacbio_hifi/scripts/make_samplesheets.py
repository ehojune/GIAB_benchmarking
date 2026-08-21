#!/usr/bin/env python3
"""phase0 manifests -> phase1 samplesheets.

정책 (2026-08-21): 각 GIAB 데이터셋을 가장 raw한 형태부터 처리한다.
우선순위 fastq > HiFi uBAM > aligned BAM. GIAB이 만든 정렬/콜링 산출물은 무시(삭제 안 함).

산출물 (phase1_pacbio_hifi/ 아래):
  samplesheets/<dsid>.csv   실행 단위(run)별 파이프라인 입력. dsid = <sample>.<dataset>
  run_table.tsv             실행 단위 목록 + clair3 모델 + 중복 표시 (스크립트들이 읽음)
  inputs_manifest.tsv       실행 단위별 필요 파일 + 바이트 (다운로드 완료 검증용)

재실행: python phase1_pacbio_hifi/scripts/make_samplesheets.py [--data-root /BiO/scratch/ehojune/GIAB_benchmark]
결과는 결정론적이므로 git diff로 변경을 확인할 수 있다.
"""
import argparse
import csv
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent          # phase1_pacbio_hifi/scripts
PHASE1 = HERE.parent                            # phase1_pacbio_hifi
REPO = PHASE1.parent                            # repo root
MANIFESTS = REPO / "phase0_download" / "manifests"

MOVIE_RE = re.compile(r"m\d+[A-Z]?_\d+_\d+")

A_HG002 = "data/AshkenazimTrio/HG002_NA24385_son"
A_HG003 = "data/AshkenazimTrio/HG003_NA24149_father"
A_HG004 = "data/AshkenazimTrio/HG004_NA24143_mother"
C_HG005 = "data/ChineseTrio/HG005_NA24631_son"
C_HG006 = "data/ChineseTrio/HG006_NA24694-huCA017E_father"
C_HG007 = "data/ChineseTrio/HG007_NA24695-hu38168_mother"
S_HG009 = "data_somatic/HG009/NIST"


def hg009(name, ds_dir, n):
    """HG009 demux uBAM 선택 규칙. name: BCM_Revio_HG009... 디렉토리의 시료명."""
    return dict(
        manifest="HG009", sample=name, dataset=ds_dir, entry="hifi_bam",
        clair3="hifi_revio", expect=n,
        pattern=rf"^data_somatic/HG009/NIST/{ds_dir}/.*/BCM_Revio_{name}_\d+/m\d+_\d+_\d+_s\d\.demux\.bc\d+--bc\d+\.bam$",
    )


# 실행 단위(run) 정의. 한 run = 한 samplesheet = 한 SGE 잡 = (sample, dataset) 한 쌍.
# pattern은 manifest 상대경로 전체에 대한 정규식. expect와 어긋나면 생성이 실패한다(안전장치).
RUNS = [
    # --- HG001 ---
    dict(manifest="HG001", sample="HG001", dataset="HudsonAlpha_PacBio_CCS", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         pattern=r"^data/NA12878/HudsonAlpha_PacBio_CCS/.*/m\d+_\d+_\d+\.fastq\.gz$"),
    dict(manifest="SRA", sample="HG001", dataset="PacBio_SequelII_CCS_11kb", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         note="리드가 GIAB FTP에 없어 SRA PRJNA540705에서 받음 (11kb 4셀 + 9kb 2셀)"),
    dict(manifest="HG001", sample="HG001", dataset="PacBio_CCS_15kb_20kb_chemistry2", entry="hifi_bam",
         clair3="hifi_sequel2", expect=6,
         pattern=r"^data/NA12878/PacBio_CCS_15kb_20kb_chemistry2/uBAMs/m\d+_\d+_\d+\.hifi_reads\.bam$",
         dup_of="HG001.HudsonAlpha_PacBio_CCS",
         note="HudsonAlpha와 동일 movie 6개의 uBAM 형태 (5mC/kinetics 보존용 원본)"),
    # --- HG002 ---
    dict(manifest="HG002", sample="HG002", dataset="PacBio_CCS_10kb", entry="hifi_fastq",
         clair3="hifi", expect=39,
         pattern=rf"^{A_HG002}/PacBio_CCS_10kb/m\d+_\d+_\d+\.Q20\.fastq$"),
    dict(manifest="HG002", sample="HG002", dataset="PacBio_CCS_15kb", entry="hifi_fastq",
         clair3="hifi", expect=39,
         pattern=rf"^{A_HG002}/PacBio_CCS_15kb/m\d+_\d+_\d+\.Q20\.fastq$"),
    dict(manifest="HG002", sample="HG002", dataset="PacBio_HiFi-Revio_20231031", entry="hifi_bam",
         clair3="hifi_revio", expect=2,
         pattern=rf"^{A_HG002}/PacBio_HiFi-Revio_20231031/HG002_PacBio-Revio_m\d+_\d+_\d+_s\d\.hifi_reads\.bam$"),
    dict(manifest="HG002", sample="HG002", dataset="PacBio_SequelII_CCS_11kb", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         pattern=rf"^{A_HG002}/PacBio_SequelII_CCS_11kb/reads/m\d+_\d+_\d+\.fastq\.gz$"),
    dict(manifest="HG002", sample="HG002", dataset="PacBio_CCS_15kb_20kb_chemistry2", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         pattern=rf"^{A_HG002}/PacBio_CCS_15kb_20kb_chemistry2/reads/m\d+_\d+_\d+\.fastq\.gz$"),
    # --- HG003 ---
    dict(manifest="HG003", sample="HG003", dataset="PacBio_CCS_Google_15kb", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=3,
         pattern=rf"^{A_HG003}/PacBio_CCS_Google_15kb/m\d+[A-Z]?_\d+_\d+\.fastq\.gz$",
         note="m54262U 1개는 Sequel I movie — 다수(m64017 2개) 기준 모델 선택"),
    dict(manifest="HG003", sample="HG003", dataset="PacBio_CCS_HudsonAlpha_14kb_15kb_19kb", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         pattern=rf"^{A_HG003}/PacBio_CCS_HudsonAlpha_14kb_15kb_19kb/.*/m\d+_\d+_\d+\.fastq\.gz$",
         note="셀당 fastq 2벌(런ID명/movie명, 동일 데이터) 중 movie명만 사용"),
    dict(manifest="HG003", sample="HG003", dataset="PacBio_HiFi-Revio_20231031", entry="hifi_bam",
         clair3="hifi_revio", expect=2,
         pattern=rf"^{A_HG003}/PacBio_HiFi-Revio_20231031/HG003_PacBio-Revio_m\d+_\d+_\d+_s\d\.hifi_reads\.bam$"),
    dict(manifest="HG003", sample="HG003", dataset="PacBio_CCS_15kb_20kb_chemistry2", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         pattern=rf"^{A_HG003}/PacBio_CCS_15kb_20kb_chemistry2/reads/.*\.fastq\.gz$",
         dup_of="HG003.PacBio_CCS_HudsonAlpha_14kb_15kb_19kb",
         note="HudsonAlpha와 동일 6개 movie (fastq는 런ID명, uBAMs/는 movie명)"),
    # --- HG004 ---
    dict(manifest="HG004", sample="HG004", dataset="PacBio_CCS_Google_15kb", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=3,
         pattern=rf"^{A_HG004}/PacBio_CCS_Google_15kb/m\d+_\d+_\d+\.fastq\.gz$"),
    dict(manifest="HG004", sample="HG004", dataset="PacBio_CCS_HudsonAlpha_15kb_21kb", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         pattern=rf"^{A_HG004}/PacBio_CCS_HudsonAlpha_15kb_21kb/.*/m\d+_\d+_\d+\.fastq\.gz$",
         note="셀당 fastq 2벌 중 movie명만 사용"),
    dict(manifest="HG004", sample="HG004", dataset="PacBio_HiFi-Revio_20231031", entry="hifi_bam",
         clair3="hifi_revio", expect=2,
         pattern=rf"^{A_HG004}/PacBio_HiFi-Revio_20231031/HG004_PacBio-Revio_m\d+_\d+_\d+_s\d\.hifi_reads\.bam$"),
    dict(manifest="HG004", sample="HG004", dataset="PacBio_CCS_15kb_20kb_chemistry2", entry="hifi_bam",
         clair3="hifi_sequel2", expect=6,
         pattern=rf"^{A_HG004}/PacBio_CCS_15kb_20kb_chemistry2/uBAMs/m\d+_\d+_\d+\.hifi_reads\.bam$",
         dup_of="HG004.PacBio_CCS_HudsonAlpha_15kb_21kb",
         note="HudsonAlpha와 동일 movie 6개의 uBAM 형태"),
    # --- HG005 ---
    dict(manifest="HG005", sample="HG005", dataset="HudsonAlpha_PacBio_CCS", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=7,
         pattern=rf"^{C_HG005}/HudsonAlpha_PacBio_CCS/.*/m\d+_\d+_\d+\.fastq\.gz$"),
    dict(manifest="SRA", sample="HG005", dataset="PacBio_SequelII_CCS_11kb", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         note="리드가 GIAB FTP에 없어 SRA PRJNA540706에서 받음 (11kb 4셀 + 9kb 2셀)"),
    dict(manifest="HG005", sample="HG005", dataset="PacBio_CCS_15kb_20kb_chemistry2", entry="hifi_bam",
         clair3="hifi_sequel2", expect=7,
         pattern=rf"^{C_HG005}/PacBio_CCS_15kb_20kb_chemistry2/uBAMs/m\d+_\d+_\d+\.hifi_reads\.bam$",
         dup_of="HG005.HudsonAlpha_PacBio_CCS",
         note="HudsonAlpha와 동일 movie 7개의 uBAM 형태"),
    # --- HG006 / HG007 ---
    dict(manifest="HG006", sample="HG006", dataset="PacBio_HiFi_Google", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=3,
         pattern=rf"^{C_HG006}/PacBio_HiFi_Google/HG006_m\d+_\d+_\d+\.fastq\.gz$"),
    dict(manifest="HG006", sample="HG006", dataset="PacBio_CCS_15kb_20kb_chemistry2", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         pattern=rf"^{C_HG006}/PacBio_CCS_15kb_20kb_chemistry2/reads/.*\.fastq\.gz$",
         note="같은 데이터셋의 uBAMs/는 동일 셀의 uBAM 형태라 제외 (fastq 우선 정책)"),
    dict(manifest="HG007", sample="HG007", dataset="PacBio_HiFi_Google", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=3,
         pattern=rf"^{C_HG007}/PacBio_HiFi_Google/HG007_m\d+_\d+_\d+\.fastq\.gz$"),
    dict(manifest="HG007", sample="HG007", dataset="PacBio_CCS_15kb_20kb_chemistry2", entry="hifi_fastq",
         clair3="hifi_sequel2", expect=6,
         pattern=rf"^{C_HG007}/PacBio_CCS_15kb_20kb_chemistry2/reads/.*\.fastq\.gz$",
         note="같은 데이터셋의 uBAMs/는 동일 셀의 uBAM 형태라 제외 (fastq 우선 정책)"),
    # --- HG008 (somatic: tumor/normal 별도 sample) ---
    dict(manifest="HG008", sample="HG008-T", dataset="BCM_Revio_20240313", entry="hifi_bam",
         clair3="hifi_revio", expect=2,
         pattern=r"^data_somatic/HG008/Liss_lab/BCM_Revio_20240313/HG008-T_ubams/m\d+_\d+_\d+_s\d\.hifi_reads\.bam$"),
    dict(manifest="HG008", sample="HG008-N-D", dataset="BCM_Revio_20240313", entry="hifi_bam",
         clair3="hifi_revio", expect=2,
         pattern=r"^data_somatic/HG008/Liss_lab/BCM_Revio_20240313/HG008-N-D_ubams/m\d+_\d+_\d+_s\d\.hifi_reads\.bam$"),
    dict(manifest="HG008", sample="HG008-T", dataset="PacBio_Revio_20240125", entry="hifi_bam",
         clair3="hifi_revio", expect=2,
         pattern=r"^data_somatic/HG008/Liss_lab/PacBio_Revio_20240125/HG008-T_PacBio-Revio_m\d+_\d+_\d+_s\d\.hifi_reads\.bc2005\.bam$"),
    dict(manifest="HG008", sample="HG008-N-P", dataset="PacBio_Revio_20240125", entry="hifi_bam",
         clair3="hifi_revio", expect=1,
         pattern=r"^data_somatic/HG008/Liss_lab/PacBio_Revio_20240125/HG008-N-P_PacBio-Revio_m\d+_\d+_\d+_s\d\.hifi_reads\.bc2006\.bam$"),
    # --- HG009 (passage/clone 별도 sample) ---
    hg009("HG009N-WT-p25", "HG009-N_bulk", 1),
    hg009("HG009N-WT-p4", "HG009-N_bulk", 2),
    hg009("HG009N-LVTert-p23", "HG009-N_bulk", 1),
    hg009("HG009T-p16", "HG009-T_bulk", 2),
    hg009("HG009T-p42", "HG009-T_bulk", 1),
    hg009("HG009T-1C3", "HG009-T_clones", 1),
    hg009("HG009T-1D5", "HG009-T_clones", 1),
    hg009("HG009T-3C4", "HG009-T_clones", 1),
    hg009("HG009T-3C9", "HG009-T_clones", 1),
    hg009("HG009T-3F2", "HG009-T_clones", 1),
    hg009("HG009T-4G9", "HG009-T_clones", 1),
]

# uBAM 형태와 fastq 형태가 같은 movie 세트인지 실측으로 확인하는 쌍 (dup_of 근거 검증)
DUP_MOVIE_CHECKS = [
    ("HG001", r"/PacBio_CCS_15kb_20kb_chemistry2/uBAMs/.*\.bam$", r"/HudsonAlpha_PacBio_CCS/.*\.fastq\.gz$"),
    ("HG003", r"/PacBio_CCS_15kb_20kb_chemistry2/uBAMs/.*\.bam$", r"/PacBio_CCS_HudsonAlpha_14kb_15kb_19kb/.*/m\d+_\d+_\d+\.fastq\.gz$"),
    ("HG004", r"/PacBio_CCS_15kb_20kb_chemistry2/uBAMs/.*\.bam$", r"/PacBio_CCS_HudsonAlpha_15kb_21kb/.*/m\d+_\d+_\d+\.fastq\.gz$"),
    ("HG005", r"/PacBio_CCS_15kb_20kb_chemistry2/uBAMs/.*\.bam$", r"/HudsonAlpha_PacBio_CCS/.*\.fastq\.gz$"),
]


def load_manifest(name):
    rows = {}
    with open(MANIFESTS / name / "pacbio_hifi.tsv", newline="", encoding="utf-8") as fh:
        for line in fh:
            relpath, size = line.rstrip("\n").split("\t")
            rows[relpath] = int(size)
    return rows


def load_sra():
    """sra_manifest.tsv -> {dsid: {relpath: bytes}}. phase0 매니페스트에 없는 SRA 유래 리드."""
    by_dsid = {}
    with open(PHASE1 / "sra_manifest.tsv", newline="", encoding="utf-8") as fh:
        hdr = fh.readline().rstrip("\n").split("\t")
        for line in fh:
            r = dict(zip(hdr, line.rstrip("\n").split("\t")))
            by_dsid.setdefault(r["dsid"], {})[r["relpath"]] = int(r["bytes"])
    return by_dsid


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-root", default="/BiO/scratch/ehojune/GIAB_benchmark",
                    help="nbb2에서 GIAB 원본이 놓인 루트 (phase0 다운로드 위치)")
    args = ap.parse_args()

    manifests = {n: load_manifest(n) for n in
                 ["HG001", "HG002", "HG003", "HG004", "HG005", "HG006", "HG007", "HG008", "HG009"]}
    sra = load_sra()

    errors = []
    sra_dsids = {f"{r['sample']}.{r['dataset']}" for r in RUNS if r["manifest"] == "SRA"}
    if set(sra) != sra_dsids:
        errors.append(f"sra_manifest.tsv의 dsid {sorted(set(sra))} != RUNS의 SRA 항목 {sorted(sra_dsids)}")
    for hg, ubam_re, fq_re in DUP_MOVIE_CHECKS:
        paths = manifests[hg]
        ubams = {m.group(0) for p in paths if re.search(ubam_re, p) for m in [MOVIE_RE.search(Path(p).name)] if m}
        fqs = {m.group(0) for p in paths if re.search(fq_re, p) for m in [MOVIE_RE.search(Path(p).name)] if m}
        if ubams != fqs:
            errors.append(f"{hg}: chemistry2 uBAM movie 세트 != HudsonAlpha fastq movie 세트\n"
                          f"  uBAM만: {sorted(ubams - fqs)}\n  fastq만: {sorted(fqs - ubams)}")

    ss_dir = PHASE1 / "samplesheets"
    ss_dir.mkdir(exist_ok=True)
    run_rows, input_rows = [], []
    seen_dsid = set()

    for run in RUNS:
        dsid = f"{run['sample']}.{run['dataset']}"
        assert dsid not in seen_dsid, f"dsid 중복: {dsid}"
        seen_dsid.add(dsid)
        if run["manifest"] == "SRA":
            paths = sra.get(dsid, {})
            picked = sorted(paths)
        else:
            paths = manifests[run["manifest"]]
            rex = re.compile(run["pattern"])
            picked = sorted(p for p in paths if rex.match(p))
        if len(picked) != run["expect"]:
            errors.append(f"{dsid}: 기대 {run['expect']}개, 매칭 {len(picked)}개\n"
                          f"  source={run['manifest']} pattern={run.get('pattern', '-')}\n"
                          f"  matched={picked[:5]}")
            continue

        total = 0
        ss_rows = []
        for p in picked:
            total += paths[p]
            idx = ""
            if run["entry"] == "aligned_bam":
                bai = p + ".bai"
                if bai not in paths:
                    errors.append(f"{dsid}: {bai} 가 manifest에 없음")
                    continue
                idx = f"{args.data_root}/{bai}"
                input_rows.append((dsid, bai, paths[bai]))
                total += paths[bai]
            ss_rows.append((run["sample"], run["dataset"], run["entry"], f"{args.data_root}/{p}", idx))
            input_rows.append((dsid, p, paths[p]))

        with open(ss_dir / f"{dsid}.csv", "w", newline="\n", encoding="utf-8") as fh:
            fh.write(f"# generated by scripts/make_samplesheets.py — data_root={args.data_root}\n")
            fh.write("sample,dataset,input_type,file,index\n")
            for r in ss_rows:
                fh.write(",".join(r) + "\n")

        run_rows.append(dict(
            dsid=dsid, sample=run["sample"], dataset=run["dataset"], entry_type=run["entry"],
            units=len(picked), clair3_model=run["clair3"], size_gib=f"{total / 2**30:.1f}",
            dup_of=run.get("dup_of", ""), note=run.get("note", "")))

    if errors:
        sys.exit("샘플시트 생성 실패:\n\n" + "\n\n".join(errors))

    with open(PHASE1 / "run_table.tsv", "w", newline="\n", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(run_rows[0].keys()), delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(run_rows)

    with open(PHASE1 / "inputs_manifest.tsv", "w", newline="\n", encoding="utf-8") as fh:
        for dsid, relpath, size in input_rows:
            fh.write(f"{dsid}\t{relpath}\t{size}\n")

    n_dup = sum(1 for r in run_rows if r["dup_of"])
    total_gib = sum(float(r["size_gib"]) for r in run_rows)
    uniq_gib = sum(float(r["size_gib"]) for r in run_rows if not r["dup_of"])
    print(f"runs: {len(run_rows)} (중복 표시 {n_dup}개 포함), 입력 {total_gib / 1024:.2f} TiB "
          f"(중복 제외 {uniq_gib / 1024:.2f} TiB), 파일 {len(input_rows)}개")
    print(f"-> {ss_dir}, run_table.tsv, inputs_manifest.tsv")


if __name__ == "__main__":
    main()
