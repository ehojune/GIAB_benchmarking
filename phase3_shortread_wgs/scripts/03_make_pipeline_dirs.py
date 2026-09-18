#!/usr/bin/env python3
"""phase3 samplesheets -> 파이프라인 입력 디렉토리, 샘플당 FASTQ 한 쌍 (nbb2에서 실행).

    cd <파이프라인 작업 디렉토리>            # 예: G000-gd1-20260819 옆
    python <repo>/phase3_shortread_wgs/scripts/03_make_pipeline_dirs.py --dry-run      # 계획만
    python .../03_make_pipeline_dirs.py --prune                                        # 1쌍짜리는 링크, 여러 쌍은 concat.sh 작성 (옛 링크 정리)
    python .../03_make_pipeline_dirs.py --prune --run-concat --jobs 4                  # + 병합을 여기서 4개씩 병렬로 전부 실행하고 기다린다 (nohup 권장)
    python .../03_make_pipeline_dirs.py --prune --qsub                                 # + 병합을 샘플별 SGE 잡으로 제출 (shepherd.q)
    python .../03_make_pipeline_dirs.py --only Hiseq_300x --only Illumina_250PE        # 일부 데이터셋만
    python .../03_make_pipeline_dirs.py --prefix GIAB_publicdata                       # 접두 변경 (기본 GIAB_publicData, 2026-09-18 사용자 확정)

만드는 구조 (업체 디렉토리 G000-gd?-*/outcome/<sample>/<sample>_1.fastq.gz 와 같은 모양, **샘플당 R1/R2 한 쌍**):

    <dest>/<prefix>_<dataset>/outcome/<prefix>_<dataset>_<HG00?>/<prefix>_<dataset>_<HG00?>_1.fastq.gz
                                                                                  ..._2.fastq.gz

- 샘플에 쌍이 하나면(NovaSeq 6000/X, HiSeq 30x 서브샘플) 원본으로의 심볼릭 링크(`--hard`면 하드링크).
- 쌍이 여럿이면(HiSeq300x 935~1,024쌍, 2x250 18~35쌍, MGISEQ·BGISEQ·AVITI 2~4쌍) **cat으로 한 쌍에 병합**한다(2026-09-18 사용자 결정 "각각 알아서").
  샘플 dir에 concat_R1.list / concat_R2.list(같은 순서: unit, 경로)와 concat.sh를 쓴다. gzip은 멀티멤버라 이어붙여도 유효하다.
  concat.sh는 출력 크기 = 입력 합을 확인하고, 이미 맞으면 SKIP한다(재실행 안전). 병합 파일은 실사본이다(HiSeq300x 3샘플만 2.4 TiB).
  AVITI는 StdInsert(~400 bp)와 LngInsert(~1300 bp) 라이브러리가 한 파일로 합쳐진다 — 인서트 분포가 이봉이 된다는 점을 파이프라인 해석에 남길 것.
- 원본은 samplesheets/<dsid>.csv 의 절대경로 그대로다(DATA_ROOT=/BiO/scratch/ehojune/GIAB_benchmark).
- 멱등: 같은 대상을 가리키는 링크는 건너뛰고, 다른 대상을 가리키면 멈춘다. `--prune`은 관리하는 샘플 dir 안의 계획에 없는 심볼릭 링크만 지운다
  (병합 결과·일반 파일은 안 건드림). 이름 규칙이 바뀐 뒤 재실행할 때 쓴다.
"""
import argparse, csv, os, re, subprocess, sys, time
from collections import Counter, defaultdict

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

CONCAT_SH = r"""#!/bin/bash
# {name}: FASTQ {n}쌍을 R1/R2 각각 하나로 cat 병합한다 (03_make_pipeline_dirs.py 생성, 2026-09-18 결정).
# 순서는 concat_R1.list / concat_R2.list 가 같다(unit, 경로 순). gzip 멀티멤버라 이어붙여도 유효하다.
# 재실행 안전: 출력 크기가 입력 합과 같으면 건너뛴다. 단독 실행: nohup bash concat.sh > concat.log 2>&1 &
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
echo "첫 리드 이름(짝이어야 함):"; zcat "{name}_1.fastq.gz" | head -1; zcat "{name}_2.fastq.gz" | head -1
echo "DONE {name} $(date '+%F %T')"
"""

QSUB_SH = """#!/bin/bash
#$ -N cat.{name}
#$ -q {queue}
#$ -S /bin/bash
#$ -j y
#$ -o {sdir}/concat.$JOB_ID.log
#$ -l h_vmem=4G
#$ -l h='{hosts}'
#$ -wd {sdir}
bash {sdir}/concat.sh
"""

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument("--dest", default=".", help="디렉토리를 만들 위치 (기본: 현재 디렉토리)")
ap.add_argument("--prefix", default="GIAB_publicData", help="디렉토리·샘플 이름 접두 (기본 GIAB_publicData)")
ap.add_argument("--only", action="append", default=[], help="이 데이터셋 디렉토리 이름(뒷부분)만. 반복 가능")
ap.add_argument("--hard", action="store_true", help="1쌍짜리를 심볼릭 링크 대신 하드링크로. 원본과 같은 파일시스템이어야 한다")
ap.add_argument("--run-concat", action="store_true", help="concat.sh 전부를 여기서 실행하고 끝날 때까지 기다린다 (--jobs 병렬)")
ap.add_argument("--jobs", type=int, default=3, help="--run-concat 동시 실행 수 (기본 3; 로그인 노드 I/O 고려)")
ap.add_argument("--qsub", action="store_true", help="concat.sh 를 샘플별 SGE 잡으로 제출 (이미 완료된 샘플은 건너뜀)")
ap.add_argument("--queue", default=os.environ.get("SGE_QUEUE", "shepherd.q"))
ap.add_argument("--hosts", default=os.environ.get("SGE_HOSTS", "(shepherd-1-7|shepherd-1-8|shepherd-1-9)"))
ap.add_argument("--prune", action="store_true", help="관리하는 샘플 dir 안에서 계획에 없는 심볼릭 링크를 지운다(일반 파일·병합 결과는 안 건드림)")
ap.add_argument("--dry-run", action="store_true", help="만들지 않고 계획만 출력")
ap.add_argument("--sheets", default=SHEETS, help=argparse.SUPPRESS)   # 테스트용: samplesheet 디렉토리 바꿔치기
a = ap.parse_args()
SHEETS = a.sheets
BASH = os.environ.get("CONCAT_BASH", "bash")   # 테스트용: Windows에서 Git Bash 경로 지정
if a.run_concat and a.qsub:
    sys.exit("--run-concat 과 --qsub 은 하나만")


def read_sheet(path):
    rows = [l for l in open(path, encoding="utf-8") if not l.startswith("#")]
    return list(csv.DictReader(rows))


def concat_done(sdir, name, pairs):
    """출력 두 파일이 있고 크기가 입력 합과 같으면 True (concat.sh의 SKIP 조건과 동일)"""
    for m, idx in (("1", 0), ("2", 1)):
        out = os.path.join(sdir, f"{name}_{m}.fastq.gz")
        if not os.path.isfile(out):
            return False
        try:
            want = sum(os.path.getsize(p[idx]) for p in pairs)
        except OSError:
            return False
        if os.path.getsize(out) != want:
            return False
    return True


plan = []      # (link_path, target)          — 1쌍짜리
concat = []    # (sample_dir, name, [(r1, r2), ...] 고정 순서) — 여러 쌍
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
    name = f"{dname}_{sample}"
    if len(rows) > 1:
        pairs = [(r["fastq_1"], r["fastq_2"]) for r in sorted(rows, key=lambda r: (r["unit"], r["fastq_1"]))]
        concat.append((sdir, name, pairs))
        if not a.dry_run:
            missing += [f for pr in pairs for f in pr if not os.path.exists(f)]
        continue
    r = rows[0]
    for mate in ("1", "2"):
        src = r[f"fastq_{mate}"]
        plan.append((os.path.join(sdir, f"{name}_{mate}.fastq.gz"), src))
        if not a.dry_run and not os.path.exists(src):
            missing.append(src)

dups = [l for l, c in Counter(l for l, _ in plan).items() if c > 1]
if dups:
    print(f"ERROR: 링크 이름이 겹친다 {len(dups)}개. 처음 5개:", *dups[:5], sep="\n  "); sys.exit(1)
if missing:
    print(f"ERROR: 원본 FASTQ {len(missing)}개가 없다 (DATA_ROOT 확인). 처음 5개:", *missing[:5], sep="\n  ")
    sys.exit(1)

# ---- 1쌍짜리: 링크 ------------------------------------------------------------------
made = skipped = pruned = 0
planned = {os.path.abspath(l) for l, _ in plan}
managed = {os.path.dirname(l) for l, _ in plan} | {c[0] for c in concat}
if a.prune and not a.dry_run:
    for d in managed:
        if not os.path.isdir(d):
            continue
        for fn in os.listdir(d):
            f = os.path.join(d, fn)
            if os.path.islink(f) and os.path.abspath(f) not in planned:
                os.remove(f); pruned += 1; print(f"PRUNE {os.path.relpath(f, a.dest)}")
for link, src in plan:
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

# ---- 여러 쌍: concat.sh 작성 ------------------------------------------------------------
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

n_ds = len({os.path.dirname(os.path.dirname(d)) for d in managed})
print(f"{'DRY-RUN ' if a.dry_run else ''}링크 {len(plan)}개({made} 생성, {skipped} 기존, {pruned} 정리) · 병합 {len(concat)} 샘플 · "
      f"데이터셋 dir {n_ds}개 under {os.path.abspath(a.dest)}")
for d in sorted({os.path.dirname(l) for l, _ in plan}):
    print(f"  LINK   {os.path.relpath(d, a.dest)}")
for sdir, name, pairs in concat:
    gib = sum(os.path.getsize(p) for pr in pairs for p in pr) / 2**30 if not a.dry_run else 0
    state = "" if a.dry_run else (" — 이미 완료" if concat_done(sdir, name, pairs) else f" — {gib:.0f} GiB, concat.sh 작성됨")
    print(f"  CONCAT {os.path.relpath(sdir, a.dest)}  ({len(pairs)} pairs -> {name}_1/2.fastq.gz{state})")

if a.dry_run or not concat:
    sys.exit(0)
todo = [(sdir, name) for sdir, name, pairs in concat if not concat_done(sdir, name, pairs)]

# ---- 병합 실행 -------------------------------------------------------------------------
if a.qsub:
    for sdir, name in todo:
        job = os.path.join(sdir, "concat.qsub.sh")
        with open(job, "w", newline="\n") as f:
            f.write(QSUB_SH.format(name=name, sdir=os.path.abspath(sdir), queue=a.queue, hosts=a.hosts))
        try:
            out = subprocess.run(["qsub", job], capture_output=True, text=True, stdin=subprocess.DEVNULL)
        except FileNotFoundError:
            sys.exit(f"ERROR: qsub 을 찾을 수 없다 (로그인 노드에서 실행할 것). 잡 스크립트는 썼다: {job}")
        print(f"QSUB {name}: {(out.stdout or out.stderr).strip()}")
    print(f"{len(todo)} 잡 제출. 상태: qstat  · 결과: <샘플 dir>/concat.<JOB_ID>.log 마지막 줄이 'DONE'")
elif a.run_concat:
    running = {}   # name -> (Popen, sdir, log)
    failed = []
    todo = list(todo)
    print(f"병합 {len(todo)} 샘플, 동시 {a.jobs}개. 로그: <샘플 dir>/concat.log")
    while todo or running:
        while todo and len(running) < a.jobs:
            sdir, name = todo.pop(0)
            log = open(os.path.join(sdir, "concat.log"), "a")
            pr = subprocess.Popen([BASH, os.path.join(os.path.abspath(sdir), "concat.sh").replace(os.sep, "/")], stdout=log, stderr=subprocess.STDOUT)
            running[name] = (pr, sdir, log)
            print(f"START {name} {time.strftime('%F %T')}", flush=True)
        for name in list(running):
            pr, sdir, log = running[name]
            if pr.poll() is None:
                continue
            log.close(); del running[name]
            print(f"{'OK   ' if pr.returncode == 0 else 'FAIL '}{name} rc={pr.returncode} {time.strftime('%F %T')}", flush=True)
            if pr.returncode != 0:
                failed.append(name)
        time.sleep(5)
    print(f"병합 끝: 실패 {len(failed)}개" + (f" — {', '.join(failed)} (concat.log 확인, 재실행하면 이어서 함)" if failed else ""))
    sys.exit(1 if failed else 0)
else:
    print(f"병합 미실행 {len(todo)} 샘플. 한 번에 전부: --run-concat (--jobs N) 또는 --qsub. 개별: nohup bash <샘플 dir>/concat.sh > <샘플 dir>/concat.log 2>&1 &")
