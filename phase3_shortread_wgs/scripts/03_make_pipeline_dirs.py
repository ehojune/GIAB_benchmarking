#!/usr/bin/env python3
"""phase3 samplesheets -> 파이프라인 입력 디렉토리 (nbb2에서 실행).

    cd <파이프라인 작업 디렉토리>            # 예: G000-gd1-20260819 옆
    python <repo>/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py            # 링크 생성 + HiSeq300x concat.sh 작성
    python .../03_make_pipeline_dirs.py --dry-run                                  # 만들 것만 출력
    python .../03_make_pipeline_dirs.py --run-concat                               # HiSeq300x 병합(cat)까지 바로 실행 — 수 시간, nohup/qsub 권장
    python .../03_make_pipeline_dirs.py --only Hiseq_subsampled_30x --only NovaseqX_30x
    python .../03_make_pipeline_dirs.py --hard                                     # ln (하드링크; 같은 파일시스템일 때만)
    python .../03_make_pipeline_dirs.py --prefix GIAB_publicdata                   # 접두 변경 (기본 GIAB_publicData, 2026-09-18 사용자 확정)

만드는 구조 (기존 업체 디렉토리 G000-gd?-*/outcome/<sample>/<sample>_1.fastq.gz 와 같은 모양):

    <dest>/<prefix>_<dataset>/outcome/<prefix>_<dataset>_<HG00?>/<prefix>_<dataset>_<HG00?>[_<unit>]_1.fastq.gz  -> 원본 FASTQ
                                                                                    ..._2.fastq.gz

샘플당 R1/R2가 한 쌍이면 unit 없이 `<sample>_1/2.fastq.gz`. 여러 쌍(2x250 34쌍, MGISEQ·BGISEQ·AVITI 2쌍)이면
samplesheet의 unit(플로우셀.레인.라이브러리 / StdInsert 등, '.'→'-')을 끼워 이름을 유일하게 한다.
HiSeq300x(샘플당 935~1,024쌍, 774~907 GiB)는 링크가 아니라 **cat으로 한 쌍으로 병합**한다(2026-09-18 사용자 결정): 샘플 dir에
concat_R1.list / concat_R2.list(같은 순서)와 concat.sh를 쓰고, `--run-concat`이면 바로 실행한다. gzip은 이어붙여도 유효한 멀티멤버다.
병합하면 플로우셀·레인 read group 구분은 FASTQ 파일 단위에서는 사라진다(리드 이름에는 남는다).
원본은 samplesheets/<dsid>.csv 의 절대경로 그대로다(DATA_ROOT=/BiO/scratch/ehojune/GIAB_benchmark). 재실행은 멱등이다 —
같은 대상을 가리키는 링크는 건너뛰고, 다른 대상을 가리키면 에러로 멈춘다. concat.sh도 출력 크기가 맞으면 건너뛴다.
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
CONCAT = {"HiSeq300x"}   # 링크 대신 cat 병합

CONCAT_SH = r"""#!/bin/bash
# {name}: HiSeq300x FASTQ {n}쌍을 R1/R2 각각 하나로 cat 병합한다 (03_make_pipeline_dirs.py 생성, 2026-09-18 결정).
# 순서는 concat_R1.list / concat_R2.list 가 같다(unit, 경로 순). gzip 멀티멤버라 이어붙여도 유효하다.
# 재실행 안전: 출력 크기가 입력 합과 같으면 건너뛴다. 실행: nohup bash concat.sh > concat.log 2>&1 &   (또는 qsub)
set -euo pipefail
cd "$(dirname "$0")"
for m in 1 2; do
    out="{name}_${{m}}.fastq.gz"; list="concat_R${{m}}.list"
    want=$(xargs -d '\n' stat -c%s < "$list" | awk '{{s+=$1}} END{{print s}}')
    if [ -f "$out" ] && [ "$(stat -c%s "$out")" = "$want" ]; then echo "SKIP $out (크기 일치 $want)"; continue; fi
    echo "CAT  $(wc -l < "$list") files -> $out ($(awk -v b="$want" 'BEGIN{{printf "%.1f", b/1073741824}}') GiB) $(date '+%F %T')"
    xargs -d '\n' cat < "$list" > "$out.part"
    got=$(stat -c%s "$out.part")
    [ "$got" = "$want" ] || {{ echo "ERROR: 크기 불일치 $out (got=$got want=$want)"; exit 1; }}
    mv "$out.part" "$out"; echo "OK   $out $(date '+%F %T')"
done
zcat "{name}_1.fastq.gz" | head -1; zcat "{name}_2.fastq.gz" | head -1   # 첫 리드 이름이 짝인지 눈으로 확인
"""

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument("--dest", default=".", help="디렉토리를 만들 위치 (기본: 현재 디렉토리)")
ap.add_argument("--prefix", default="GIAB_publicData", help="디렉토리·샘플 이름 접두 (기본 GIAB_publicData)")
ap.add_argument("--only", action="append", default=[], help="이 데이터셋 디렉토리 이름(뒷부분)만. 반복 가능")
ap.add_argument("--hard", action="store_true", help="심볼릭 링크 대신 하드링크(ln). 원본과 같은 파일시스템이어야 한다")
ap.add_argument("--run-concat", action="store_true", help="HiSeq300x concat.sh를 여기서 순서대로 실행 (수 시간)")
ap.add_argument("--dry-run", action="store_true", help="만들지 않고 계획만 출력")
ap.add_argument("--sheets", default=SHEETS, help=argparse.SUPPRESS)   # 테스트용: samplesheet 디렉토리 바꿔치기
a = ap.parse_args()
SHEETS = a.sheets


def read_sheet(path):
    rows = [l for l in open(path, encoding="utf-8") if not l.startswith("#")]
    return list(csv.DictReader(rows))


plan = []      # (link_path, target)
concat = []    # (sample_dir, sample_name, [(r1, r2), ...] 고정 순서)
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
    if dataset in CONCAT:
        pairs = [(r["fastq_1"], r["fastq_2"]) for r in sorted(rows, key=lambda r: (r["unit"], r["fastq_1"]))]
        concat.append((sdir, f"{dname}_{sample}", pairs))
        if not a.dry_run:
            missing += [f for pr in pairs for f in pr if not os.path.exists(f)]
        continue
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

for sdir, name, pairs in concat:
    if a.dry_run:
        continue
    os.makedirs(sdir, exist_ok=True)
    with open(os.path.join(sdir, "concat_R1.list"), "w", newline="\n") as f1, \
         open(os.path.join(sdir, "concat_R2.list"), "w", newline="\n") as f2:
        for r1, r2 in pairs:
            f1.write(r1 + "\n"); f2.write(r2 + "\n")
    sh = os.path.join(sdir, "concat.sh")
    with open(sh, "w", newline="\n") as f:
        f.write(CONCAT_SH.format(name=name, n=len(pairs)))
    os.chmod(sh, 0o755)

n_ds = len({os.path.dirname(os.path.dirname(d)) for d in list(by_dir) + [c[0] for c in concat]})
print(f"{'DRY-RUN ' if a.dry_run else ''}{len(plan)} links planned, {made} made, {skipped} already present, "
      f"{len(by_dir)} link sample dirs + {len(concat)} concat sample dirs, {n_ds} dataset dirs under {os.path.abspath(a.dest)}")
for d in sorted(by_dir):
    print(f"  {os.path.relpath(d, a.dest)}  ({by_dir[d]} files)")
for sdir, name, pairs in concat:
    print(f"  {os.path.relpath(sdir, a.dest)}  (cat {len(pairs)} pairs -> {name}_1/2.fastq.gz{'' if a.dry_run else '; concat.sh 작성됨'})")
if concat and not a.dry_run:
    if a.run_concat:
        import subprocess
        for sdir, name, _ in concat:
            print(f"== running {name}/concat.sh"); subprocess.run(["bash", os.path.abspath(os.path.join(sdir, "concat.sh")).replace(os.sep, "/")], check=True)
    else:
        print("HiSeq300x 병합은 아직 안 했다. 샘플 dir마다:  nohup bash <dir>/concat.sh > <dir>/concat.log 2>&1 &   (또는 --run-concat)")
