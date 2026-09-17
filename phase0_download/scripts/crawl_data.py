#!/usr/bin/env python3
"""GIAB FTP data/·data_somatic/·data_RNAseq/ 라이브 크롤 → 샘플별 manifest 갱신 (release/는 crawl_release.py).

current.tree가 2025-02-27 이후 갱신되지 않아 새 데이터가 manifest에서 빠질 수 있다(release/에서 실증, 2026-09-16).
파일이 7만 개라 전부 HEAD하지 않는다. Apache 인덱스의 수정일·크기를 읽어
  (a) manifest에 없는 새 파일, (b) 수정일이 CUTOFF(2026-08-13, 마지막 HEAD 검증일) 이후인 파일,
  (c) 인덱스 근사 크기가 manifest 크기와 어긋나는 파일, (d) manifest에는 있는데 인덱스에 안 보이는 파일(dotfile·삭제)
만 HEAD로 정확한 바이트를 받는다.
기존 항목이 FTP와 어긋나면(크기 다름·404) S3 미러를 HEAD해 교차 확인한다. download.sh가 S3를 먼저 쓰고 manifest 크기는
S3 기준으로 검증된 것이므로, S3가 manifest와 맞으면 그대로 둔다(FTP 사본만 다른 파일 7천여 개, FTP에서만 사라진 파일 2천여 개 — 2026-09-16).

`manifests/declined_by_decision.tsv`에 적힌 경로는 건너뛴다 — 받지 않기로 결정한 데이터다(2026-09-17). 이 가드가 없으면
manifest에서 지운 파일이 다음 크롤에 다시 들어온다.

새 파일은 catalog/master_catalog.tsv의 giab_path(가장 긴 접두 일치)로 sample/category를 정해
manifests/<SAMPLE>/<category>.tsv (rnaseq_all·trio_analysis는 각자 파일)에 넣는다.
어느 giab_path에도 안 맞는 새 파일은 manifest에 넣지 않고 manifests/data_unrouted_new.tsv에 적는다
— 새 데이터셋이므로 카탈로그 행을 먼저 만들어야 한다.

  python phase0_download/scripts/crawl_data.py                 # 세 루트 전부
  python phase0_download/scripts/crawl_data.py --dry-run       # manifest는 건드리지 않고 보고서만 (logs/crawl_cache/)
  ROOT=data_somatic/HG009 python phase0_download/scripts/crawl_data.py   # 일부만 (콤마로 여러 개)
  --fresh  캐시 무시. 캐시(logs/crawl_cache/)가 있으면 목록 단계를 건너뛰고 이어서 한다.
  --route-all  새 디렉토리도 카탈로그 접두만으로 라우팅. 새 디렉토리의 카탈로그 행을 만든 뒤 캐시로 재실행할 때만.

산출: 바뀐 manifest들(경로 정렬), manifests/data_stale_ftp_removed.tsv(FTP에서 사라진 항목, append),
      manifests/data_unrouted_new.tsv(라우팅 실패 신규), docs/reference/data_crawl_<date>.md(보고서, 덮어쓰지 않음)
"""
import concurrent.futures as cf
import csv
import datetime
import glob
import html
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/"
S3 = "https://giab.s3.amazonaws.com/"  # download.sh가 먼저 쓰는 미러. FTP와 양방향으로 어긋난다(2026-09-16 실측: HiSeq300x FASTQ는 FTP 사본이 15% 작고, Strand-Seq EMBL 등 2,173 파일은 FTP에서만 사라짐)
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
PROJ = os.path.dirname(REPO)
MANI = os.path.join(REPO, "manifests")
CATALOG = os.path.join(PROJ, "catalog", "master_catalog.tsv")
STALE = os.path.join(MANI, "data_stale_ftp_removed.tsv")
UNROUTED = os.path.join(MANI, "data_unrouted_new.tsv")
# 받지 않기로 결정한 파일 목록(경로/바이트/그룹). 여기 있는 경로는 manifest에 넣지도, 신규로 보고하지도 않는다.
# 이 가드가 없으면 manifest에서 지운 파일을 다음 크롤이 "기존 디렉토리의 신규 파일"로 되돌려 넣는다.
DECLINED = os.path.join(MANI, "declined_by_decision.tsv")
ALLOWED = ("data/", "data_somatic/", "data_RNAseq/")
ROOTS = [r.strip().strip("/") + "/" for r in os.environ.get("ROOT", "data,data_somatic,data_RNAseq").split(",")]
for _r in ROOTS:
    if not any(_r == a or _r.startswith(a) for a in ALLOWED):
        sys.exit(f"ROOT={_r} 는 data/·data_somatic/·data_RNAseq/ 밖이다. release/는 crawl_release.py를 쓴다.")
DRY = "--dry-run" in sys.argv
FRESH = "--fresh" in sys.argv
# --route-all: 부모 디렉토리 조건을 끄고 카탈로그 접두만으로 라우팅한다.
# 새 디렉토리마다 카탈로그 행(정확한 giab_path)을 만든 **뒤에** 캐시로 재실행할 때만 쓴다.
ROUTE_ALL = "--route-all" in sys.argv
CUTOFF = os.environ.get("CUTOFF", "2026-08-13")  # 이 날 이후 수정된 파일은 HEAD로 다시 잰다
UA = {"User-Agent": "giab-crawl/1.0"}
LIST_THREADS, HEAD_THREADS, TRIES = 4, 4, 8  # NCBI는 동시 요청이 많으면 503
RETRY_CODES = (429, 500, 502, 503, 504)
CACHE = os.environ.get("CRAWL_CACHE", os.path.join(PROJ, "logs", "crawl_cache"))
ROOT_KEY = re.sub(r"[^A-Za-z0-9]+", "_", ",".join(ROOTS)).strip("_")
FILES_CACHE = os.path.join(CACHE, f"data_files.{ROOT_KEY}.tsv")
SIZES_CACHE = os.path.join(CACHE, "data_sizes.tsv")
S3_CACHE = os.path.join(CACHE, "data_s3_sizes.tsv")
GIB = 1024 ** 3
# <a href="name">name</a>   2026-03-02 10:32  588K
ROW = re.compile(r'<a href="([^"]+)">[^<]*</a>\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s+(\S+)')
UNIT = {"K": 1024, "M": 1024 ** 2, "G": 1024 ** 3, "T": 1024 ** 4}


def _sleep(i):
    time.sleep(min(60, 3 * 2 ** i))


def get(url, tries=TRIES):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=90) as r:
                return r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code in RETRY_CODES and i < tries - 1:
                _sleep(i)
                continue
            raise
        except (urllib.error.URLError, TimeoutError, OSError):
            if i == tries - 1:
                raise
            _sleep(i)


def head_size(path, tries=TRIES):
    """bytes, None(404), -1(크기를 못 받음)"""
    url = BASE + urllib.parse.quote(path)
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, method="HEAD", headers=UA), timeout=90) as r:
                cl = r.headers.get("Content-Length")
            if cl is not None:
                return int(cl)
            with urllib.request.urlopen(urllib.request.Request(url, headers=dict(UA, Range="bytes=0-0")), timeout=90) as r:
                cr = r.headers.get("Content-Range", "")
            total = cr.rsplit("/", 1)[-1]
            if total.isdigit():
                return int(total)
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r:
                body = r.read(200 * 1024 * 1024 + 1)
            if len(body) <= 200 * 1024 * 1024:
                return len(body)
            return -1
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if e.code in RETRY_CODES and i < tries - 1:
                _sleep(i)
                continue
            # 403 등: 인덱스에는 있는데 받을 수 없는 파일(NCBI가 .log 등을 막는다, 2026-09-16 실측). 크기 미확인으로 두고 계속.
            print(f"  HTTP {e.code}: {path}", file=sys.stderr, flush=True)
            return -1
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            if i == tries - 1:
                print(f"  network error: {path}: {e}", file=sys.stderr, flush=True)
                return -1
            _sleep(i)


def s3_size(path, tries=4):
    """S3 미러의 바이트. None = 없음(404/403), -1 = 확인 실패"""
    url = S3 + urllib.parse.quote(path)
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, method="HEAD", headers=UA), timeout=60) as r:
                cl = r.headers.get("Content-Length")
            return int(cl) if cl is not None else -1
        except urllib.error.HTTPError as e:
            if e.code in (403, 404):
                return None
            if e.code in RETRY_CODES and i < tries - 1:
                _sleep(i)
                continue
            return -1
        except (urllib.error.URLError, TimeoutError, OSError):
            if i == tries - 1:
                return -1
            _sleep(i)


def approx_bytes(s):
    """'588K' → 602112, '40M' → 41943040, '-' → None"""
    if not s or s == "-":
        return None
    m = re.fullmatch(r"([\d.]+)([KMGT]?)", s)
    if not m:
        return None
    return int(float(m.group(1)) * UNIT.get(m.group(2), 1))


def listdir(d):
    """d = 'data/x/' → (files[(path, mtime, sizestr)], subdirs)"""
    page = get(BASE + urllib.parse.quote(d))
    files, dirs = [], []
    for h, mtime, size in ROW.findall(page):
        h = html.unescape(h)
        if h.startswith(("?", "/", "http://", "https://")) or h == "../":
            continue
        name = urllib.parse.unquote(h)
        if name.endswith("/"):
            dirs.append(d + name)
        else:
            files.append((d + name, mtime, size))
    return files, dirs


def in_scope(p):
    return any(p.startswith(r) for r in ROOTS)


def load_declined():
    """받지 않기로 한 경로 집합. 파일이 없으면 빈 집합."""
    out = set()
    if os.path.exists(DECLINED):
        for l in open(DECLINED, encoding="utf-8"):
            if l.strip() and not l.startswith("#"):
                out.add(l.split("\t")[0])
    return out


def load_manifests():
    """path → (bytes, manifest file)"""
    out = {}
    for f in glob.glob(os.path.join(MANI, "HG*", "*.tsv")) + [os.path.join(MANI, "rnaseq_all.tsv"), os.path.join(MANI, "trio_analysis.tsv")]:
        for line in open(f, encoding="utf-8"):
            if line.strip():
                p, b = line.rstrip("\n").split("\t")[:2]
                out[p] = (int(b) if b else None, f)
    return out


def load_routes():
    """catalog giab_path → (sample, category), 긴 접두 우선"""
    rows = list(csv.DictReader(open(CATALOG, encoding="utf-8", newline=""), delimiter="\t"))
    routes = [(r["giab_path"].rstrip("/"), r["sample"], r["category"]) for r in rows if r["category"] != "release_truthsets"]
    return sorted(routes, key=lambda x: -len(x[0]))


def manifest_for(sample, cat):
    if cat in ("rnaseq_all", "trio_analysis"):
        return os.path.join(MANI, cat + ".tsv")
    return os.path.join(MANI, sample, cat + ".tsv")


def route(path, routes, dirs_of):
    """(manifest, sample, category, routed?)

    카탈로그 giab_path의 가장 긴 접두로 후보 manifest를 고르되, **새 파일의 부모 디렉토리에 이미 그 manifest의
    파일이 있을 때만** 라우팅한다(기존 런 디렉토리에 파일이 추가된 경우). 부모 디렉토리가 통째로 새것이면
    새 플랫폼/런이므로 routed=False — 카탈로그 행을 만들고 category를 정한 뒤 넣어야 한다.
    (HG009처럼 카탈로그 접두가 `HG009-T_bulk` 수준으로 거칠면 접두만으로는 NovaSeq X·RNA-seq·Hi-C가 전부
    pacbio_hifi로 들어간다 — 2026-09-16 실측.)"""
    for prefix, sample, cat in routes:
        if path == prefix or path.startswith(prefix + "/"):
            f = manifest_for(sample, cat)
            routed = ROUTE_ALL or os.path.dirname(path) in dirs_of.get(f, ())
            return f, sample, cat, routed
    return None, None, None, False


def group(paths, depth=4):
    g = {}
    for p in paths:
        g.setdefault("/".join(p.split("/")[:depth]), []).append(p)
    return g


def main():
    os.makedirs(CACHE, exist_ok=True)
    t0 = time.time()
    if os.path.exists(FILES_CACHE) and not FRESH:
        entries = [tuple(l.rstrip("\n").split("\t")) for l in open(FILES_CACHE, encoding="utf-8") if l.strip()]
        entries = [e for e in entries if in_scope(e[0])]
        print(f"crawl: {len(entries)} files from cache {FILES_CACHE} (--fresh 로 다시 크롤)", file=sys.stderr)
    else:
        todo, entries, ndirs = list(ROOTS), [], 0
        with cf.ThreadPoolExecutor(LIST_THREADS) as ex:
            while todo:
                batch, todo = todo, []
                for fs, ds in ex.map(listdir, batch):
                    entries += fs
                    todo += ds
                    ndirs += 1
                print(f"  dirs listed {ndirs}, files {len(entries)}, queue {len(todo)}, {time.time() - t0:.0f}s", file=sys.stderr, flush=True)
        entries = sorted(set(entries))
        with open(FILES_CACHE, "w", encoding="utf-8", newline="\n") as fh:
            for e in entries:
                fh.write("\t".join(e) + "\n")
        print(f"crawl: {ndirs} dirs, {len(entries)} files in {time.time() - t0:.0f}s", file=sys.stderr)

    listed = {p: (mtime, size) for p, mtime, size in entries}
    mani = load_manifests()
    in_scope_old = {p: v for p, v in mani.items() if in_scope(p)}
    routes = load_routes()
    dirs_of = {}  # manifest → 그 manifest의 파일이 들어 있는 디렉토리 집합
    for p, (_, f) in mani.items():
        dirs_of.setdefault(f, set()).add(os.path.dirname(p))

    # HEAD 대상 선정 — 받지 않기로 한 경로는 신규로 치지 않는다(재추가 방지)
    declined = load_declined()
    declined_seen = sum(1 for p in listed if p in declined)
    new_paths = [p for p in listed if p not in in_scope_old and p not in declined]
    modified = [p for p, (mt, sz) in listed.items() if p in in_scope_old and mt[:10] > CUTOFF]
    approx_off = []
    for p, (mt, sz) in listed.items():
        if p in in_scope_old and p not in modified:
            a, have = approx_bytes(sz), in_scope_old[p][0]
            if a is not None and have is not None and abs(a - have) > max(2048, 0.15 * a):
                approx_off.append(p)
    unlisted = [p for p in in_scope_old if p not in listed]
    to_head = sorted(set(new_paths) | set(modified) | set(approx_off) | set(unlisted))
    print(f"HEAD targets: new {len(new_paths)}, modified-since-{CUTOFF} {len(modified)}, approx-size-off {len(approx_off)}, "
          f"unlisted-old {len(unlisted)} → {len(to_head)}", file=sys.stderr)

    sizes = {}
    if os.path.exists(SIZES_CACHE) and not FRESH:
        for l in open(SIZES_CACHE, encoding="utf-8"):
            if l.strip():
                p, b = l.rstrip("\n").split("\t")
                if in_scope(p) and b != "-1":
                    sizes[p] = None if b == "404" else int(b)
    elif FRESH:
        # --fresh: 크기 캐시와 S3 캐시를 모두 버린다. S3 캐시를 남기면 이번 조회가 실패했을 때
        # 다음 실행이 옛 결과를 읽고 재시도를 건너뛴다(append 모드라 실패는 기록되지 않는다).
        for f in (SIZES_CACHE, S3_CACHE):
            if os.path.exists(f):
                os.remove(f)
    pending = [p for p in to_head if p not in sizes]
    t1 = time.time()
    with cf.ThreadPoolExecutor(HEAD_THREADS) as ex, open(SIZES_CACHE, "a", encoding="utf-8", newline="\n") as cache:
        for n, (p, s) in enumerate(zip(pending, ex.map(head_size, pending)), 1):
            sizes[p] = s
            if s != -1:
                cache.write(f"{p}\t{'404' if s is None else s}\n")
                cache.flush()
            if n % 200 == 0:
                print(f"  HEAD {n}/{len(pending)} {time.time() - t1:.0f}s", file=sys.stderr, flush=True)
    print(f"HEAD: {len(pending)} lookups in {time.time() - t1:.0f}s", file=sys.stderr)

    added, changed, removed, hidden, nosize, unrouted = {}, {}, {}, [], [], {}
    for p in new_paths:
        s = sizes.get(p)
        if s is None or s == -1:
            (nosize if s == -1 else []).append(p)
            continue
        f, sample, cat, ok = route(p, routes, dirs_of)
        if ok:
            added[p] = (s, f)
        else:
            unrouted[p] = (s, f"{sample}/{cat}" if f else "(카탈로그 접두 없음)")
    # 기존 항목의 FTP 불일치 후보: 크기 다름(ftp_diff) 또는 FTP 404(ftp_gone). 결론은 S3 교차 확인 뒤에 낸다.
    ftp_diff, ftp_gone = {}, {}
    for p in set(modified + approx_off + unlisted):
        s = sizes.get(p)
        if s is None:
            ftp_gone[p] = in_scope_old[p]
        elif s == -1:
            nosize.append(p)
        else:
            if p in unlisted:
                hidden.append(p)
            if s != in_scope_old[p][0]:
                ftp_diff[p] = s
    # S3 교차 확인 (download.sh는 S3를 먼저 쓴다): S3가 manifest와 맞으면 그대로 둔다
    s3 = {}
    if os.path.exists(S3_CACHE) and not FRESH:
        for l in open(S3_CACHE, encoding="utf-8"):
            if l.strip():
                p, b = l.rstrip("\n").split("\t")
                if b != "-1":
                    s3[p] = None if b == "404" else int(b)
    s3_pending = [p for p in list(ftp_diff) + list(ftp_gone) if p not in s3]
    t2 = time.time()
    with cf.ThreadPoolExecutor(HEAD_THREADS) as ex, open(S3_CACHE, "a", encoding="utf-8", newline="\n") as cache:
        for n, (p, b) in enumerate(zip(s3_pending, ex.map(s3_size, s3_pending)), 1):
            s3[p] = b
            if b != -1:
                cache.write(f"{p}\t{'404' if b is None else b}\n")
                cache.flush()
            if n % 500 == 0:
                print(f"  S3 HEAD {n}/{len(s3_pending)} {time.time() - t2:.0f}s", file=sys.stderr, flush=True)
    print(f"S3 cross-check: {len(s3_pending)} lookups in {time.time() - t2:.0f}s "
          f"(ftp_diff {len(ftp_diff)}, ftp_gone {len(ftp_gone)})", file=sys.stderr)
    mirror_diff, s3_only, s3_unverified = {}, {}, []
    for p, s in ftp_diff.items():
        have = in_scope_old[p][0]
        b = s3.get(p, -1)
        if b == have:
            mirror_diff[p] = (have, s)  # S3 = manifest, FTP만 다름 → 유지
        elif b == -1:
            s3_unverified.append(p)  # S3 확인 실패(타임아웃 등): 검증된 크기를 건드리지 않는다. 다음 실행에서 재확인
        elif b is None:
            changed[p] = (have, s, in_scope_old[p][1])  # S3에 없음이 확인됨 → FTP 크기가 유일한 진실
        else:
            changed[p] = (have, b, in_scope_old[p][1])  # S3도 바뀜 → S3 크기(다운로드 소스) 적용
    for p, (have, f) in ftp_gone.items():
        b = s3.get(p, -1)
        if b is None:
            removed[p] = (have, f)  # 양쪽 다 없음이 확인됨
        elif b == -1:
            s3_unverified.append(p)  # 확인 실패 → 유지
        else:
            s3_only[p] = have
            if b != have:
                changed[p] = (have, b, f)
    gib = lambda b: b / GIB

    date = datetime.date.today().isoformat()
    rep = [f"# data/ 크롤 대조 {date}", "",
           f"FTP 라이브 인덱스 재귀 크롤(수정일·근사 크기 파싱) + 선별 HEAD. 도구: `phase0_download/scripts/crawl_data.py`. "
           f"ROOT: {', '.join(ROOTS)} · CUTOFF {CUTOFF}" + (" · **dry-run**" if DRY else ""), "",
           "| 항목 | 파일 | GiB |", "|---|---|---|",
           f"| FTP 현재(인덱스) | {len(listed)} | - |",
           f"| manifest(이전, 범위 안) | {len(in_scope_old)} | {gib(sum(v[0] or 0 for v in in_scope_old.values())):.2f} |",
           f"| HEAD 조회 | {len(to_head)} | - |",
           f"| 추가(라우팅 성공) | {len(added)} | {gib(sum(v[0] for v in added.values())):.2f} |",
           f"| 추가 후보 — 새 디렉토리(카탈로그 행 필요, manifest 미반영) | {len(unrouted)} | {gib(sum(v[0] for v in unrouted.values())):.2f} |",
           f"| FTP·S3 양쪽에서 사라짐(manifest에서 제거) | {len(removed)} | {gib(sum(v[0] or 0 for v in removed.values())):.2f} |",
           f"| FTP에서만 사라짐 — S3에 있음(유지) | {len(s3_only)} | {gib(sum(s3_only.values())):.2f} |",
           f"| 미러 간 크기 불일치 — S3=manifest, FTP만 다름(유지) | {len(mirror_diff)} | - |",
           f"| S3 확인 실패 — 판단 보류(유지, 다음 실행에서 재확인) | {len(s3_unverified)} | - |",
           f"| 인덱스에 숨겨진 파일(HEAD로 존재 확인해 유지) | {len(hidden)} | - |",
           f"| 크기 변경(적용) | {len(changed)} | - |",
           f"| 크기 못 받음(변경 없음 처리) | {len(nosize)} | - |",
           f"| 받지 않기로 결정(declined_by_decision.tsv, 신규에서 제외) | {declined_seen} | - |", ""]
    if added:
        rep += ["## 추가 (디렉토리 단위 → manifest)", "", "| 디렉토리 | 파일 | GiB | manifest |", "|---|---|---|---|"]
        for k, ps in sorted(group(added).items()):
            fs = sorted({os.path.relpath(added[p][1], MANI).replace(os.sep, "/") for p in ps})
            rep.append(f"| `{k}` | {len(ps)} | {gib(sum(added[p][0] for p in ps)):.2f} | {', '.join(fs)} |")
        rep += ["", "<details><summary>파일 목록</summary>", ""] + [f"- `{p}` {added[p][0]:,}" for p in sorted(added)] + ["", "</details>", ""]
    if unrouted:
        rep += ["## 새 디렉토리의 신규 파일 (새 데이터셋 — 카탈로그 행을 만들고 category를 정한 뒤 manifest에 넣을 것)", "",
                "| 디렉토리(부모) | 파일 | GiB | 가장 가까운 카탈로그 접두의 sample/category |", "|---|---|---|---|"]
        bydir = {}
        for p in unrouted:
            bydir.setdefault(os.path.dirname(p), []).append(p)
        for k, ps in sorted(bydir.items()):
            sug = sorted({unrouted[p][1] for p in ps})
            rep.append(f"| `{k}` | {len(ps)} | {gib(sum(unrouted[p][0] for p in ps)):.2f} | {', '.join(sug)} |")
        rep += ["", "<details><summary>파일 목록</summary>", ""] + [f"- `{p}` {unrouted[p][0]:,}" for p in sorted(unrouted)] + ["", "</details>", ""]
    if removed:
        rep += ["## FTP에서 사라짐", "", "| 디렉토리 | 파일 |", "|---|---|"]
        for k, ps in sorted(group(removed).items()):
            rep.append(f"| `{k}` | {len(ps)} |")
        rep += ["", "<details><summary>파일 목록</summary>", ""] + [f"- `{p}`" for p in sorted(removed)] + ["", "</details>", ""]
    if changed:
        rep += ["## 크기 변경 적용 (manifest → 소스)", ""] + [f"- `{p}` {a:,} → {b:,}" for p, (a, b, _) in sorted(changed.items())] + [""]
    if s3_only:
        rep += ["## FTP에서만 사라진 파일 — S3에 있어 유지 (디렉토리 단위)", "", "| 디렉토리 | 파일 | GiB |", "|---|---|---|"]
        for k, ps in sorted(group(s3_only).items()):
            rep.append(f"| `{k}` | {len(ps)} | {gib(sum(s3_only[p] for p in ps)):.2f} |")
        rep += [""]
    if mirror_diff:
        rep += ["## 미러 간 크기 불일치 — S3=manifest, FTP 사본만 다름 (디렉토리 단위, 유지)", "", "| 디렉토리 | 파일 | FTP/S3 크기 비(중앙값) |", "|---|---|---|"]
        for k, ps in sorted(group(mirror_diff).items()):
            ratios = sorted(mirror_diff[p][1] / mirror_diff[p][0] for p in ps if mirror_diff[p][0])
            med = ratios[len(ratios) // 2] if ratios else 0
            rep.append(f"| `{k}` | {len(ps)} | {med:.3f} |")
        rep += [""]
    if hidden:
        rep += [f"## 인덱스에 숨겨진 파일 {len(hidden)}건 (유지)", "", "<details><summary>파일 목록</summary>", ""] + [f"- `{p}`" for p in hidden] + ["", "</details>", ""]
    if nosize:
        rep += ["## 크기를 못 받은 파일 (다음 실행에서 재시도)", ""] + [f"- `{p}`" for p in sorted(nosize)] + [""]
    if DRY:
        rp = os.path.join(CACHE, f"data_crawl_{datetime.datetime.now():%Y%m%d-%H%M%S}.dry.md")
    else:
        os.makedirs(os.path.join(PROJ, "docs", "reference"), exist_ok=True)
        rp = os.path.join(PROJ, "docs", "reference", f"data_crawl_{date}.md")
        k = 2
        while os.path.exists(rp):
            rp = os.path.join(PROJ, "docs", "reference", f"data_crawl_{date}_{k}.md")
            k += 1
    with open(rp, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(rep))
    print(f"report: {rp}", file=sys.stderr)
    print(f"added {len(added)} ({gib(sum(v[0] for v in added.values())):.2f} GiB), "
          f"new-dir candidates {len(unrouted)} ({gib(sum(v[0] for v in unrouted.values())):.2f} GiB), removed {len(removed)}, "
          f"s3-only kept {len(s3_only)}, mirror-diff kept {len(mirror_diff)}, s3-unverified kept {len(s3_unverified)}, "
          f"changed {len(changed)}, hidden {len(hidden)}, nosize {len(nosize)}, declined {declined_seen}")

    if DRY:
        return
    # manifest 갱신: 파일별로 다시 쓴다(경로 정렬). 범위 밖 항목은 그대로.
    touched = {}
    for p, (s, f) in added.items():
        touched.setdefault(f, {})[p] = s
    for p, (a, b, f) in changed.items():
        touched.setdefault(f, {})[p] = b
    for p, (b, f) in removed.items():
        touched.setdefault(f, {})[p] = None  # None = 제거
    for f, upd in touched.items():
        cur = {}
        if os.path.exists(f):
            for line in open(f, encoding="utf-8"):
                if line.strip():
                    p, b = line.rstrip("\n").split("\t")[:2]
                    cur[p] = int(b) if b else None
        for p, s in upd.items():
            if s is None:
                cur.pop(p, None)
            else:
                cur[p] = s
        os.makedirs(os.path.dirname(f), exist_ok=True)
        with open(f, "w", encoding="utf-8", newline="\n") as fh:
            for p in sorted(cur):
                fh.write(f"{p}\t{cur[p]}\n")
        print(f"  manifest {os.path.relpath(f, MANI)}: {len(cur)} lines (+{sum(1 for s in upd.values() if s is not None and p not in in_scope_old)} / ~{len(upd)})", file=sys.stderr)
    if removed:
        already = {l.split("\t")[0] for l in open(STALE, encoding="utf-8") if l.strip()} if os.path.exists(STALE) else set()
        with open(STALE, "a", encoding="utf-8", newline="\n") as fh:
            for p in sorted(removed):
                if p not in already:
                    fh.write(f"{p}\t{removed[p][0]}\t{date}\n")
    # 라우팅 실패 목록은 현재 상태로 유지한다: 이번 ROOT 범위 안은 이번 결과로 바꾸고, 범위 밖 기존 항목은 그대로 둔다
    # (부분 크롤이 다른 루트의 대기 항목을 지우지 않도록). 결과가 비면 파일을 지운다.
    keep = []
    if os.path.exists(UNROUTED):
        for l in open(UNROUTED, encoding="utf-8"):
            if l.strip() and not l.startswith("#") and not in_scope(l.split("\t")[0]):
                keep.append(l.rstrip("\n"))
    lines = keep + [f"{p}\t{unrouted[p][0]}\t{listed[p][0]}\t{unrouted[p][1]}\t{date}" for p in sorted(unrouted)]
    if lines:
        with open(UNROUTED, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("# path\tbytes\tftp_mtime\tnearest catalog sample/category\tcrawl date — 새 디렉토리의 신규 파일. catalog_new_dirs.py로 행을 만든 뒤 crawl_data.py --route-all\n")
            fh.write("\n".join(sorted(lines)) + "\n")
    elif os.path.exists(UNROUTED):
        os.remove(UNROUTED)
    print(f"manifests touched: {len(touched)}; stale logged: {len(removed)}; unrouted logged: {len(unrouted)}", file=sys.stderr)


if __name__ == "__main__":
    main()
