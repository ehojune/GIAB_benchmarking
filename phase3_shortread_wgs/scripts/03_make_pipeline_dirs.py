#!/usr/bin/env python3
"""phase3 samplesheets -> 파이프라인 입력 디렉토리 (nbb2에서 실행).

    cd <파이프라인 작업 디렉토리>            # 예: G000-gd1-20260819 옆
    python <repo>/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py            # 심볼릭 링크 생성
    python .../03_make_pipeline_dirs.py --dry-run                                  # 만들 것만 출력
    python .../03_make_pipeline_dirs.py --prefix GIAB_publicData                   # 접두 변경
    python .../03_make_pipeline_dirs.py --only Hiseq_subsampled_30x --only NovaseqX_30x
    python .../03_make_pipeline_dirs.py --hard                                     # ln (하드링크; 같은 파일시스템일 때만)

만드는 구조 (기존 업체 디렉토리 G000-gd?-*/outcome/<sample>/<sample>_1.fastq.gz 와 같은 모양):

    <dest>/<prefix>_<dataset>/outcome/<prefix>_<dataset>_<HG00?>/<prefix>_<dataset>_<HG00?>[_<unit>]_1.fastq.gz  -> 원본 FASTQ
                                                                                    ..._2.fastq.gz

샘플당 R1/R2가 한 쌍이면 unit 없이 `<sample>_1/2.fastq.gz`. 여러 쌍(HiSeq300x 935쌍, 2x250 34쌍, MGISEQ·BGISEQ·AVITI 2쌍)이면
samplesheet의 unit(플로우셀.레인.라이브러리 / StdInsert 등, '.'→'-')을 끼워 이름을 유일하게 한다.
원본은 samplesheets/<dsid>.csv 의 절대경로 그대로다(DATA_ROOT=/BiO/scratch/ehojune/GIAB_benchmark). 재실행은 멱등이다 —
같은 대상을 가리키는 링크는 건너뛰고, 다른 대상을 가리키면 에러로 멈춘다.
"""
import argparse, csv, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
SHEETS = os.path.join(ROOT, "samplesheets")

# samplesheet dataset -> 디렉토리 이름 뒷부분 (2026-09-18 사용자 지정). 여기 없는 dataset(NIST_BGIseq_2x150_100x, Element_AVITI_20231018)은 만들지 않는다.
DIRNAME = {
    "NovaSeq_PCRfree_30x":    "Novaseq6000-PCRfree_30x",
    "NovaSeqX_30x":           "NovaseqX_30x",
    "Illumina_PCRfree_30x":   "Hiseq_subsampled_30x",
    "HiSeq300x":              "Hiseq_300x",
    "Illumina_2x250":         "Illumina_250PE",
    "MGISEQ2000_PCRfree":     "MGISEQ2000-PCRfree",
    "BGISEQ500":              "BGISEQ500",
    "Element_AVITI_20240920": "Element_AVITI",
}

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument("--dest", default=".", help="디렉토리를 만들 위치 (기본: 현재 디렉토리)")
ap.add_argument("--prefix", default="GIAB_publicdata", help="디렉토리·샘플 이름 접두 (기본 GIAB_publicdata)")
ap.add_argument("--only", action="append", default=[], help="이 데이터셋 디렉토리 이름(뒷부분)만. 반복 가능")
ap.add_argument("--hard", action="store_true", help="심볼릭 링크 대신 하드링크(ln). 원본과 같은 파일시스템이어야 한다")
ap.add_argument("--dry-run", action="store_true", help="만들지 않고 계획만 출력")
ap.add_argument("--sheets", default=SHEETS, help=argparse.SUPPRESS)   # 테스트용: samplesheet 디렉토리 바꿔치기
a = ap.parse_args()
SHEETS = a.sheets

def read_sheet(path):
    rows = [l for l in open(path, encoding="utf-8") if not l.startswith("#")]
    return list(csv.DictReader(rows))

plan = []      # (link_path, target)
missing = []
for fn in sorted(os.listdir(SHEETS)):
    if not fn.endswith(".csv"):
        continue
    sample, dataset = fn[:-4].split(".", 1)
    if dataset not in DIRNAME:
        continue
    dname = f"{a.prefix}_{DIRNAME[dataset]}"
    if a.only and DIRNAME[dataset] not in a.only and dname not in a.only:
        continue
    rows = read_sheet(os.path.join(SHEETS, fn))
    sdir = os.path.join(a.dest, dname, "outcome", f"{dname}_{sample}")
    single = len(rows) == 1
    for r in rows:
        unit = "" if single else "_" + r["unit"].replace(".", "-")
        for mate in ("1", "2"):
            src = r[f"fastq_{mate}"]
            link = os.path.join(sdir, f"{dname}_{sample}{unit}_{mate}.fastq.gz")
            plan.append((link, src))
            if not a.dry_run and not os.path.exists(src):
                missing.append(src)

if missing:
    print(f"ERROR: 원본 FASTQ {len(missing)}개가 없다 (DATA_ROOT 확인). 처음 5개:", *missing[:5], sep="\n  ")
    sys.exit(1)

made = skipped = 0
by_dir = defaultdict(int)
for link, src in plan:
    by_dir[os.path.dirname(link)] += 1
    if a.dry_run:
        continue
    os.makedirs(os.path.dirname(link), exist_ok=True)
    if os.path.lexists(link):
        cur = os.readlink(link) if os.path.islink(link) else (link if a.hard and os.path.samefile(link, src) else None)
        if cur == src or (a.hard and cur == link):
            skipped += 1; continue
        sys.exit(f"ERROR: 이미 있는데 다른 대상을 가리킨다: {link} -> {cur if cur else '(하드링크/일반 파일, 원본과 다름)'} (원한 것: {src})")
    if a.hard:
        os.link(src, link)
    else:
        os.symlink(src, link)
    made += 1

print(f"{'DRY-RUN ' if a.dry_run else ''}{len(plan)} links planned, {made} made, {skipped} already present, "
      f"{len(by_dir)} sample dirs, {len({os.path.dirname(os.path.dirname(d)) for d in by_dir})} dataset dirs under {os.path.abspath(a.dest)}")
for d in sorted(by_dir):
    print(f"  {os.path.relpath(d, a.dest)}  ({by_dir[d]} files)")
