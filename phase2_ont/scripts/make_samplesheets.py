#!/usr/bin/env python3
"""phase0 manifests -> phase2(ONT) samplesheets.

정책 (2026-08-21, phase1과 동일): 각 GIAB 데이터셋을 가장 raw한 형태부터 처리한다.
우선순위 fastq > uBAM > aligned BAM. POD5/fast5 베이스콜링은 하지 않는다.
GIAB이 만든 정렬/콜링 산출물은 무시(삭제 안 함).

산출물 (phase2_ont/ 아래):
  samplesheets/<dsid>.csv   실행 단위(run)별 파이프라인 입력. dsid = <sample>.<dataset>
  run_table.tsv             실행 단위 목록 + 케미스트리/베이스콜러/콜러 모델 + 중복 표시
  inputs_manifest.tsv       실행 단위별 필요 파일 + 바이트 (다운로드 완료 검증용)
  excluded.tsv              돌리지 않기로 한 카탈로그 행 + 이유

재실행: python phase2_ont/scripts/make_samplesheets.py [--data-root /BiO/scratch/ehojune/GIAB_benchmark]
결과는 결정론적이므로 git diff로 변경을 확인할 수 있다.
"""
import argparse
import csv
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent          # phase2_ont/scripts
PHASE2 = HERE.parent                            # phase2_ont
REPO = PHASE2.parent                            # repo root
MANIFESTS = REPO / "phase0_download" / "manifests"

A_HG002 = "data/AshkenazimTrio/HG002_NA24385_son"
A_HG003 = "data/AshkenazimTrio/HG003_NA24149_father"
A_HG004 = "data/AshkenazimTrio/HG004_NA24143_mother"
C_HG005 = "data/ChineseTrio/HG005_NA24631_son"
C_HG006 = "data/ChineseTrio/HG006_NA24694-huCA017E_father"
C_HG007 = "data/ChineseTrio/HG007_NA24695-hu38168_mother"
L_HG008 = "data_somatic/HG008/Liss_lab"
UL_HG002 = f"{A_HG002}/Ultralong_OxfordNanopore"

# Clair3 모델. hkubal/clair3:v1.2.0 이미지에 없는 것은 01_prepare_login_node.sh가 내려받는다.
M_R9_G4 = "r941_prom_hac_g360+g422"        # R9.4.1, Guppy 3.6.0/4.2.2 hac 로 학습 (이미지에 있음 — 실측)
M_R9_G2 = "r941_prom_hac_g238"             # R9.4.1, Guppy 2.3.8 (이미지에 없음. HKU 아카이브 안쪽 이름은 ont_guppy2). albacore 데이터의 대체품
M_R10_420 = "r1041_e82_400bps_sup_v420"    # dorado sup@v4.2.0 (이미지에 없음 -> 01_prepare가 받는다)
M_R10_430 = "r1041_e82_400bps_sup_v430"    # dorado sup@v4.3.0 (이미지에 없음)
M_R10_500 = "r1041_e82_400bps_sup_v500"    # dorado sup@v5.0.0 (이미지에 있음)
DV_R10 = "ONT_R104"                        # DeepVariant 1.10.0의 유일한 ONT 모델 (R10.4.1 전용)
DV_NONE = "-"                              # R9.4.1 = DeepVariant 모델 없음 -> --skip_deepvariant

# 실행 단위(run) 정의. 한 run = 한 samplesheet = 한 SGE 잡 = (sample, dataset) 한 쌍.
# pattern은 manifest 상대경로 전체에 대한 정규식. expect와 어긋나면 생성이 실패한다(안전장치).
# dataset은 반드시 카탈로그 giab_path의 basename이어야 한다 — 50_update_catalog.py가 그 값으로 행을 찾는다.
RUNS = [
    # --- HG001: GIAB FTP에 리드가 없다. 외부(nanopore-wgs-consortium)에서 rel6 fastq를 받는다 ---
    dict(manifest="EXT", sample="HG001", dataset="Ultralong_OxfordNanopore", entry="fastq",
         chemistry="R9.4", basecaller="guppy (rel6, 2019-06 재배포)",
         clair3=M_R9_G4, dv=DV_NONE, expect=1,
         note="GIAB FTP에는 GRCh37/38 BAM만 있다. 리드는 nanopore-wgs-consortium AWS "
              "s3://nanopore-human-wgs/rel6 (=Jain et al. 2018 프로젝트, GIAB과 별개 컨소시엄). "
              "rel6 전체 53 플로우셀 132.9 Gbp(~43x) 중 Ultra 킷은 12셀 19.3 Gbp뿐 — "
              "GIAB BAM이 실제로 무엇을 담았는지는 03_dup_evidence.sh가 헤더로 대조한다"),

    # --- HG002 ONT-UL: 같은 MinION 플로우셀의 베이스콜 릴리스 5종 ---
    dict(manifest="HG002", sample="HG002", dataset="guppy-V3.4.5", entry="fastq",
         chemistry="R9.4.1 (MinION FLO-MIN106, SQK-RAD003/004)", basecaller="guppy 3.4.5",
         clair3=M_R9_G4, dv=DV_NONE, expect=1,
         pattern=rf"^{UL_HG002}/guppy-V3\.4\.5/HG002_ONT-UL_GIAB_20200204\.fastq\.gz$",
         note="UL 릴리스 5종 중 가장 최신 베이스콜(52x)이고 오라벨 플로우셀이 없다. 기본 제출은 이것만. "
              "MinION 데이터에 PromethION 모델을 쓴다 — Clair3에 MinION R9 모델이 없다"),
    dict(manifest="HG002", sample="HG002", dataset="guppy-V3.2.4_2020-01-22", entry="fastq",
         chemistry="R9.4.1 (MinION FLO-MIN106)", basecaller="guppy 3.2.4",
         clair3=M_R9_G4, dv=DV_NONE, expect=1,
         pattern=rf"^{UL_HG002}/guppy-V3\.2\.4_2020-01-22/HG002_ONT-UL_GIAB_20200122\.fastq\.gz$",
         dup_of="HG002.guppy-V3.4.5",
         note="guppy-V3.4.5와 같은 플로우셀을 3.2.4로 베이스콜한 것 (읽기 자체는 다르다)"),
    dict(manifest="HG002", sample="HG002", dataset="guppy-V2.3.4_2019-06-26", entry="fastq",
         chemistry="R9.4.1 (MinION FLO-MIN106)", basecaller="guppy 2.3.4",
         clair3=M_R9_G2, dv=DV_NONE, expect=1,
         pattern=rf"^{UL_HG002}/guppy-V2\.3\.4_2019-06-26/ultra-long-ont\.fastq\.gz$",
         dup_of="HG002.guppy-V3.4.5",
         note="같은 플로우셀의 2.3.4 베이스콜. **HG001 오라벨 플로우셀 3개(FAH71622/FAH86841/FAH87405)가 "
              "섞여 있다** — 돌릴 거면 mis-labeled-sample_read-ids.txt.gz로 먼저 걸러야 한다"),
    dict(manifest="HG002", sample="HG002", dataset="combined_2018-08-10", entry="fastq",
         chemistry="R9.4.1 (MinION FLO-MIN106)", basecaller="albacore (버전 미기재)",
         clair3=M_R9_G2, dv=DV_NONE, expect=1,
         pattern=rf"^{UL_HG002}/combined_2018-08-10/combined_2018-08-10\.fastq\.gz$",
         dup_of="HG002.guppy-V3.4.5",
         note="rel2(16x) 부분 릴리스. albacore 베이스콜에 맞는 Clair3 모델이 없어 g238로 대체한다. "
              "같은 디렉토리의 raw fast5 tar 10개(751 GiB)는 베이스콜링 제외 정책에 따라 안 쓴다"),
    dict(manifest="HG002", sample="HG002", dataset="combined_2018-05-18", entry="fastq",
         chemistry="R9.4.1 (MinION FLO-MIN106)", basecaller="albacore (문서가 버전 미확정이라 밝힘)",
         clair3=M_R9_G2, dv=DV_NONE, expect=1,
         pattern=rf"^{UL_HG002}/combined_2018-05-18/combined_2018-05-18\.fastq\.gz$",
         dup_of="HG002.guppy-V3.4.5",
         note="rel1(6x) 최초 릴리스. 커버리지가 낮아 변이 호출용으로는 의미가 적다"),

    # --- UCSC PromethION UL (HG002~HG007). MinION UL과는 다른 기기·플로우셀이다 ---
    dict(manifest="HG002", sample="HG002", dataset="UCSC_Ultralong_OxfordNanopore_Promethion",
         entry="fastq", chemistry="R9.4.1 (PromethION FLO-PRO002, SQK-LSK109)",
         basecaller="guppy 3.2.4/3.2.5 (문서 안에서 표기 불일치)",
         clair3=M_R9_G4, dv=DV_NONE, expect=3,
         pattern=rf"^{A_HG002}/UCSC_Ultralong_OxfordNanopore_Promethion/GM24385_\d\.fastq\.gz$",
         note="MinION UL 릴리스들과 다른 데이터다 (기기·플로우셀 다름). 03_dup_evidence.sh가 read_id 교집합으로 확인"),
    dict(manifest="HG003", sample="HG003", dataset="UCSC_Ultralong_OxfordNanopore_Promethion",
         entry="fastq", chemistry="R9.4.1 (PromethION FLO-PRO002, SQK-LSK109)", basecaller="guppy 3.2.x",
         clair3=M_R9_G4, dv=DV_NONE, expect=3,
         pattern=rf"^{A_HG003}/UCSC_Ultralong_OxfordNanopore_Promethion/GM24149_\d\.fastq\.gz$"),
    dict(manifest="HG004", sample="HG004", dataset="UCSC_Ultralong_OxfordNanopore_Promethion",
         entry="fastq", chemistry="R9.4.1 (PromethION FLO-PRO002, SQK-LSK109)", basecaller="guppy 3.2.x",
         clair3=M_R9_G4, dv=DV_NONE, expect=3,
         pattern=rf"^{A_HG004}/UCSC_Ultralong_OxfordNanopore_Promethion/GM24143_\d\.fastq\.gz$"),
    dict(manifest="HG005", sample="HG005", dataset="UCSC_Ultralong_OxfordNanopore_Promethion",
         entry="fastq", chemistry="R9.4.1 (PromethION, dna_r9.4.1_450bps_flipflop)", basecaller="guppy 4.2.2",
         clair3=M_R9_G4, dv=DV_NONE, expect=3,
         pattern=rf"^{C_HG005}/UCSC_Ultralong_OxfordNanopore_Promethion/01_09_20_R941_GM24631_\d_Guppy_4\.2\.2_prom\.fastq\.gz$",
         note="Clair3 r941_prom_hac_g360+g422가 Guppy 4.2.2 데이터로 학습된 모델이라 여기선 정확히 맞는다"),
    dict(manifest="HG006", sample="HG006", dataset="UCSC_Ultralong_OxfordNanopore_Promethion",
         entry="fastq", chemistry="R9.4.1 (PromethION, dna_r9.4.1_450bps_flipflop)", basecaller="guppy 4.2.2",
         clair3=M_R9_G4, dv=DV_NONE, expect=3,
         pattern=rf"^{C_HG006}/UCSC_Ultralong_OxfordNanopore_Promethion/01_09_20_R941_GM24694_\d_Guppy_4\.2\.2_prom\.fastq\.gz$"),
    dict(manifest="HG007", sample="HG007", dataset="UCSC_Ultralong_OxfordNanopore_Promethion",
         entry="fastq", chemistry="R9.4.1 (PromethION, dna_r9.4.1_450bps_flipflop)", basecaller="guppy 4.2.2",
         clair3=M_R9_G4, dv=DV_NONE, expect=3,
         pattern=rf"^{C_HG007}/UCSC_Ultralong_OxfordNanopore_Promethion/01_09_20_R941_GM24695_\d_Guppy_4\.2\.2_prom\.fastq\.gz$"),

    # --- HG008 (somatic. tumor/normal-duodenum/normal-pancreas를 별도 sample로 나눈다 = phase1과 같은 규칙) ---
    dict(manifest="HG008", sample="HG008-N-D", dataset="Northeastern_ONT-std_20240422", entry="ubam",
         chemistry="R10.4.1 (PromethION FLO-PRO114M, SQK-LSK114)", basecaller="dorado 0.5.3 (5mC_5hmC)",
         clair3=M_R10_430, dv=DV_R10, expect=4,
         pattern=rf"^{L_HG008}/Northeastern_ONT-std_20240422/HG008-N-D_ubams/.*\.bam$",
         note="93~94x. 같은 디렉토리의 longer_than_25kb/50kb fastq는 GIAB이 길이로 걸러 만든 파생물이라 안 쓴다. "
              "clair3 모델은 dorado 0.5.3의 기본 sup(v4.3.0) 가정 — 서버의 README_NE_ONT-std.md로 확정할 것"),
    dict(manifest="HG008", sample="HG008-N-P", dataset="Northeastern_ONT-std_20240422", entry="ubam",
         chemistry="R10.4.1 (PromethION FLO-PRO114M, SQK-LSK114)", basecaller="dorado 0.5.3 (5mC_5hmC)",
         clair3=M_R10_430, dv=DV_R10, expect=3,
         pattern=rf"^{L_HG008}/Northeastern_ONT-std_20240422/HG008-N-P_ubams/.*\.bam$",
         note="40~41x. HG008 소마틱 분석의 정상 대조로 반복 사용되는 데이터"),
    dict(manifest="HG008", sample="HG008-T", dataset="Northeastern-ONT-UL-20241216", entry="ubam",
         chemistry="R10.4.1 UL (PromethION, SQK-ULK114, E8.2.1 모터)", basecaller="dorado 0.8.1 sup (5mC_5hmC)",
         clair3=M_R10_500, dv=DV_R10, expect=1,
         pattern=rf"^{L_HG008}/Northeastern-ONT-UL-20241216/11_12_2024_R1041_HG008_3066\.dorado_0\.8\.1_sup\.5mC_5hmC\.bam$",
         note="dorado 0.8.1의 기본 sup은 v5.0.0이라 그 모델을 쓴다 (이미지에 있는 유일한 최신 모델)"),
    dict(manifest="HG008", sample="HG008-T", dataset="UCSC_ONT-UL_20231207", entry="ubam",
         chemistry="R10.4.1 UL (PromethION 48, FLO-PRO114M, SQK-ULK114)", basecaller="dorado 0.4.3 sup@v4.2.0 (5mCG_5hmCG)",
         clair3=M_R10_420, dv=DV_R10, expect=3,
         pattern=rf"^{L_HG008}/UCSC_ONT-UL_20231207/HG008-T_UCSC_20231031_ONT-UL-R10\.4\.1_\d_dorado-v0\.4\.3_sup4\.2\.0-5mCG-5hmCG\.bam$",
         note="파일명에 베이스콜 모델(sup4.2.0)이 박혀 있어 Clair3 모델이 확정적이다. 54x, N50 ~127kb"),
    dict(manifest="HG008", sample="HG008-T", dataset="UCSC_ONT_20231003", entry="ubam",
         chemistry="R10.4.1 (PromethION 48, FLO-PRO114M, SQK-LSK114-XL)", basecaller="dorado 0.3.4 sup@v4.2.0 (5mCG-5hmC)",
         clair3=M_R10_420, dv=DV_R10, expect=1,
         pattern=rf"^{L_HG008}/UCSC_ONT_20231003/HG008-T_UCSC_20230905_ONT-std-R10\.4\.1_1_dorado_v0\.3\.4_sup4\.2\.0_5mCG-5hmC\.bam$",
         note="63x"),
    dict(manifest="HG008", sample="HG008T-p2", dataset="BCM_ONT-std_HG008T-p2_20260313", entry="ubam",
         chemistry="R10.4.1 (PromethION, Ligation Kit V14)", basecaller="dorado sup@v4.3.0 (MinKNOW)",
         clair3=M_R10_430, dv=DV_R10, expect=1090, unit_from="parent",
         pattern=rf"^{L_HG008}/other_passages/BCM_ONT-std_HG008T-p2_20260313/\d+_\d+_\d[CD]_[A-Z]+\d+_[0-9a-f]+/.*\.bam$",
         note="pass uBAM 1090개 = 플로우셀 2개. unit을 런 디렉토리로 묶어 samtools cat으로 2개로 합친 뒤 정렬한다. "
              "GIAB 자신은 ClairS를 --override_basecaller_cfg sup@v4.2.0으로 돌렸지만 문서상 베이스콜 모델은 v4.3.0이다"),
]

# 돌리지 않기로 한 카탈로그 행. 이유를 남기는 게 목적이다 (50_update_catalog.py가 next_step에 기록).
EXCLUDED = [
    dict(sample="HG002", dataset="CORNELL_Oxford_Nanopore",
         reason="2D 리드가 fastq 96 MB(+fasta 43 MB) = 0.03x 수준이고, 원시 데이터는 fast5 2912개다. "
                "R7 2D 케미스트리는 Clair3/DeepVariant 모델이 아예 없고 fast5 재베이스콜은 정책상 제외. "
                "커버리지만으로도 변이 호출이 불가능하다 (2026-08-22 사용자 확인)"),
]


def load_manifest(name):
    rows = {}
    with open(MANIFESTS / name / "ont.tsv", newline="", encoding="utf-8") as fh:
        for line in fh:
            relpath, size = line.rstrip("\n").split("\t")
            rows[relpath] = int(size)
    return rows


def load_ext():
    """ext_manifest.tsv -> {dsid: {relpath: bytes}}. phase0 매니페스트에 없는 외부 유래 리드."""
    by_dsid = {}
    with open(PHASE2 / "ext_manifest.tsv", newline="", encoding="utf-8") as fh:
        hdr = fh.readline().rstrip("\n").split("\t")
        for line in fh:
            if not line.strip() or line.startswith("#"):
                continue
            r = dict(zip(hdr, line.rstrip("\n").split("\t")))
            if r["kind"] != "reads":      # evidence 행(sequencing summary)은 파이프라인 입력이 아니다
                continue
            by_dsid.setdefault(r["dsid"], {})[r["relpath"]] = int(r["bytes"])
    return by_dsid


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-root", default="/BiO/scratch/ehojune/GIAB_benchmark",
                    help="nbb2에서 GIAB 원본이 놓인 루트 (phase0 다운로드 위치)")
    args = ap.parse_args()

    manifests = {n: load_manifest(n) for n in
                 ["HG001", "HG002", "HG003", "HG004", "HG005", "HG006", "HG007", "HG008"]}
    ext = load_ext()

    errors = []
    ext_dsids = {f"{r['sample']}.{r['dataset']}" for r in RUNS if r["manifest"] == "EXT"}
    if set(ext) != ext_dsids:
        errors.append(f"ext_manifest.tsv의 dsid {sorted(set(ext))} != RUNS의 EXT 항목 {sorted(ext_dsids)}")

    ss_dir = PHASE2 / "samplesheets"
    ss_dir.mkdir(exist_ok=True)
    run_rows, input_rows = [], []
    seen_dsid = set()

    for run in RUNS:
        dsid = f"{run['sample']}.{run['dataset']}"
        assert dsid not in seen_dsid, f"dsid 중복: {dsid}"
        seen_dsid.add(dsid)
        if run["manifest"] == "EXT":
            paths = ext.get(dsid, {})
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
            # unit_from='parent': 파일이 수백 개인 데이터셋을 런 디렉토리 단위로 묶어
            # 정렬 전에 samtools cat으로 합친다 (파이프라인의 unit 열)
            unit = Path(p).parent.name if run.get("unit_from") == "parent" else ""
            ss_rows.append((run["sample"], run["dataset"], run["entry"],
                            f"{args.data_root}/{p}", "", unit))
            input_rows.append((dsid, p, paths[p]))

        with open(ss_dir / f"{dsid}.csv", "w", newline="\n", encoding="utf-8") as fh:
            fh.write(f"# generated by scripts/make_samplesheets.py — data_root={args.data_root}\n")
            fh.write("sample,dataset,input_type,file,index,unit\n")
            for r in ss_rows:
                fh.write(",".join(r) + "\n")

        n_units = len({r[5] for r in ss_rows}) if run.get("unit_from") else len(picked)
        run_rows.append(dict(
            dsid=dsid, sample=run["sample"], dataset=run["dataset"], entry_type=run["entry"],
            units=n_units, files=len(picked), chemistry=run["chemistry"], basecaller=run["basecaller"],
            clair3_model=run["clair3"], dv_model=run["dv"], size_gib=f"{total / 2**30:.1f}",
            dup_of=run.get("dup_of", ""), note=run.get("note", "")))

    if errors:
        sys.exit("샘플시트 생성 실패:\n\n" + "\n\n".join(errors))

    with open(PHASE2 / "run_table.tsv", "w", newline="\n", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(run_rows[0].keys()), delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(run_rows)

    with open(PHASE2 / "inputs_manifest.tsv", "w", newline="\n", encoding="utf-8") as fh:
        for dsid, relpath, size in input_rows:
            fh.write(f"{dsid}\t{relpath}\t{size}\n")

    with open(PHASE2 / "excluded.tsv", "w", newline="\n", encoding="utf-8") as fh:
        fh.write("sample\tdataset\treason\n")
        for e in EXCLUDED:
            fh.write(f"{e['sample']}\t{e['dataset']}\t{e['reason']}\n")

    n_dup = sum(1 for r in run_rows if r["dup_of"])
    total_gib = sum(float(r["size_gib"]) for r in run_rows)
    uniq_gib = sum(float(r["size_gib"]) for r in run_rows if not r["dup_of"])
    print(f"runs: {len(run_rows)} (중복 표시 {n_dup}개 포함), 입력 {total_gib / 1024:.2f} TiB "
          f"(중복 제외 {uniq_gib / 1024:.2f} TiB), 파일 {len(input_rows)}개, 제외 행 {len(EXCLUDED)}개")
    print(f"-> {ss_dir}, run_table.tsv, inputs_manifest.tsv, excluded.tsv")


if __name__ == "__main__":
    main()
