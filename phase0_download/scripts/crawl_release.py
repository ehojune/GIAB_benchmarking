#!/usr/bin/env python3
"""GIAB FTP release/ 라이브 크롤 → manifests/release_truthsets.tsv 갱신.

current.tree는 2025-02-27 이후 갱신되지 않아(2026-09-16 확인) 쓰지 않는다. Apache 디렉토리 인덱스를 재귀로 읽고,
파일마다 HEAD로 정확한 바이트를 받는다(인덱스의 크기는 40M처럼 반올림이라 download.sh의 크기 비교에 못 쓴다).

  python phase0_download/scripts/crawl_release.py            # 크롤 + 대조 + manifest 갱신 + 보고서
  python phase0_download/scripts/crawl_release.py --dry-run  # manifest는 건드리지 않고 보고서만
  python phase0_download/scripts/crawl_release.py --fresh    # 캐시(logs/crawl_cache/) 무시하고 다시 크롤. 캐시가 있으면 이어서 한다
  python phase0_download/scripts/crawl_release.py --baseline <manifest.tsv>  # 대조 기준을 현재 manifest 대신 이 파일로 (보고서 재생성용)
  ROOT=release/AshkenazimTrio/HG002_NA24385_son/v5.0q python ... # release/ 아래 일부만 (여러 개는 콤마)

release/ 전용이다. data/·data_somatic/·data_RNAseq/는 샘플별 manifest(manifests/<SAMPLE>/<category>.tsv)로 나뉘어
있어 이 스크립트가 다루지 않는다 — release/ 밖 ROOT는 거부한다.

산출: manifests/release_truthsets.tsv (FTP 기준으로 재작성, 경로 정렬),
      manifests/release_stale_ftp_removed.tsv (FTP에서 사라진 옛 항목, 기록용 append, 중복 없음),
      docs/reference/release_crawl_<date>.md (추가/삭제/크기변경 목록. 같은 날 두 번째 실행은 _2, _3… 로 보존)
      --dry-run 보고서는 docs/가 아니라 logs/crawl_cache/ 에 쓴다.
"""
import concurrent.futures as cf
import datetime
import html
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
PROJ = os.path.dirname(REPO)
MANIFEST = os.path.join(REPO, "manifests", "release_truthsets.tsv")
STALE = os.path.join(REPO, "manifests", "release_stale_ftp_removed.tsv")
ROOTS = [r.strip().strip("/") + "/" for r in os.environ.get("ROOT", "release").split(",")]
for _r in ROOTS:
    if _r != "release/" and not _r.startswith("release/"):
        sys.exit(f"ROOT={_r} 는 release/ 밖이다. 이 스크립트는 release_truthsets.tsv 전용 — data/ 계열은 샘플별 manifest라 다루지 않는다.")
DRY = "--dry-run" in sys.argv
FRESH = "--fresh" in sys.argv
BASELINE = sys.argv[sys.argv.index("--baseline") + 1] if "--baseline" in sys.argv else None
HREF = re.compile(r'href="([^"]+)"')
UA = {"User-Agent": "giab-crawl/1.0"}
LIST_THREADS, HEAD_THREADS, TRIES = 3, 4, 8  # NCBI는 동시 요청이 많으면 503을 준다 (2026-09-16 실측: 12+16 스레드에서 503)
RETRY_CODES = (429, 500, 502, 503, 504)
CACHE = os.environ.get("CRAWL_CACHE", os.path.join(PROJ, "logs", "crawl_cache"))
# 목록 캐시는 ROOT 범위별로 따로 둔다(부분 크롤 캐시를 전체 크롤에 재사용하면 범위 밖 파일이 통째로 빠진다).
# 크기 캐시는 경로별 사실이라 공유하되, 읽을 때 ROOT 범위 안의 경로만 쓴다.
ROOT_KEY = re.sub(r"[^A-Za-z0-9]+", "_", ",".join(ROOTS)).strip("_")
FILES_CACHE, SIZES_CACHE = os.path.join(CACHE, f"files.{ROOT_KEY}.txt"), os.path.join(CACHE, "sizes.tsv")


def in_scope(p):
    return any(p.startswith(r) for r in ROOTS)
GIB = 1024 ** 3


def _sleep(i):
    time.sleep(min(60, 3 * 2 ** i))


def get(url, tries=TRIES):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
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
            with urllib.request.urlopen(urllib.request.Request(url, method="HEAD", headers=UA), timeout=60) as r:
                cl = r.headers.get("Content-Length")
            if cl is not None:
                return int(cl)
            rng = dict(UA, Range="bytes=0-0")
            with urllib.request.urlopen(urllib.request.Request(url, headers=rng), timeout=60) as r:
                cr = r.headers.get("Content-Range", "")  # bytes 0-0/TOTAL
            total = cr.rsplit("/", 1)[-1]
            if total.isdigit():
                return int(total)
            # Content-Length도 Content-Range도 없음(빈 파일 등) → 본문을 직접 읽어 잰다 (200 MiB 상한)
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r:
                body = r.read(200 * 1024 * 1024 + 1)
            if len(body) <= 200 * 1024 * 1024:
                return len(body)
            print(f"  no size: {path}", file=sys.stderr, flush=True)
            return -1
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if e.code in RETRY_CODES and i < tries - 1:
                _sleep(i)
                continue
            raise RuntimeError(f"{path}: HTTP {e.code}") from e
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            if i == tries - 1:
                raise RuntimeError(f"{path}: {e}") from e
            _sleep(i)


def listdir(d):
    """d = 'release/x/y/' → (files, subdirs) as full relative paths"""
    page = get(BASE + urllib.parse.quote(d))
    files, dirs = [], []
    for h in HREF.findall(page):
        h = html.unescape(h)
        if h.startswith(("?", "/", "http://", "https://")) or h == "../":
            continue
        name = urllib.parse.unquote(h)
        (dirs if name.endswith("/") else files).append(d + name)
    return files, dirs


def baseline_label():
    """보고서에 적는 대조 기준. repo 밖 파일이면 이름만 (임시 경로는 재현에 쓸모가 없다)."""
    if not BASELINE:
        return "manifests/release_truthsets.tsv (실행 전)"
    rel = os.path.relpath(os.path.abspath(BASELINE), PROJ)
    return os.path.basename(BASELINE) if rel.startswith("..") else rel.replace(os.sep, "/")


def group(paths):
    """디렉토리(샘플/버전) 단위 집계 키"""
    g = {}
    for p in paths:
        parts = p.split("/")
        key = "/".join(parts[:4]) if parts[1] in ("AshkenazimTrio", "ChineseTrio") else "/".join(parts[:3])
        g.setdefault(key, []).append(p)
    return g


def main():
    os.makedirs(CACHE, exist_ok=True)
    t0 = time.time()
    if os.path.exists(FILES_CACHE) and not FRESH:
        files = [l.rstrip("\n") for l in open(FILES_CACHE, encoding="utf-8") if l.strip() and in_scope(l.rstrip("\n"))]
        print(f"crawl: {len(files)} files from cache {FILES_CACHE} (--fresh 로 다시 크롤)", file=sys.stderr)
    else:
        todo, files, ndirs = list(ROOTS), [], 0
        with cf.ThreadPoolExecutor(LIST_THREADS) as ex:
            while todo:
                batch, todo = todo, []
                for fs, ds in ex.map(listdir, batch):
                    files += fs
                    todo += ds
                    ndirs += 1
                print(f"  dirs listed {ndirs}, files {len(files)}, queue {len(todo)}", file=sys.stderr, flush=True)
        files = sorted(set(files))
        with open(FILES_CACHE, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(files) + "\n")
        print(f"crawl: {ndirs} dirs, {len(files) } files in {time.time() - t0:.0f}s", file=sys.stderr)

    # 대조 기준(old): 현재 manifest, 또는 --baseline 파일. 재작성 대상은 항상 MANIFEST.
    old = {}
    for line in open(BASELINE or MANIFEST, encoding="utf-8"):
        if line.strip():
            p, b = line.rstrip("\n").split("\t")[:2]
            old[p] = int(b) if b else None
    in_scope_old = {p: b for p, b in old.items() if in_scope(p)}

    t0 = time.time()
    sizes = {}
    if os.path.exists(SIZES_CACHE) and not FRESH:
        for l in open(SIZES_CACHE, encoding="utf-8"):
            if l.strip():
                p, b = l.rstrip("\n").split("\t")
                if in_scope(p) and b != "-1":  # 실패(-1)는 캐시로 인정하지 않는다 → 재시도
                    sizes[p] = None if b == "404" else int(b)
        print(f"HEAD: {len(sizes)} sizes from cache (ROOT 범위 안만)", file=sys.stderr)
    elif FRESH and os.path.exists(SIZES_CACHE):
        os.remove(SIZES_CACHE)

    def lookup(paths, cache):
        """HEAD를 돌려 sizes에 넣고, 성공(바이트·404)만 캐시에 쓴다. 실패(-1)는 다음 실행에서 다시 조회된다."""
        for n, (p, s) in enumerate(zip(paths, ex.map(head_size, paths)), 1):
            sizes[p] = s
            if s != -1:
                cache.write(f"{p}\t{'404' if s is None else s}\n")
                cache.flush()
            if n % 500 == 0:
                print(f"  HEAD {n}/{len(paths)} {time.time() - t0:.0f}s", file=sys.stderr, flush=True)

    pending = [p for p in files if p not in sizes]
    with cf.ThreadPoolExecutor(HEAD_THREADS) as ex, open(SIZES_CACHE, "a", encoding="utf-8", newline="\n") as cache:
        lookup(pending, cache)
    print(f"HEAD: {len(pending)} new lookups in {time.time() - t0:.0f}s", file=sys.stderr)

    # 인덱스에 안 보이는 옛 항목 — Apache는 dotfile(.DS_Store, ._*)을 숨긴다. 직접 HEAD해서 있으면 유지, 404만 제거.
    unlisted = [p for p in in_scope_old if p not in sizes]
    with cf.ThreadPoolExecutor(HEAD_THREADS) as ex, open(SIZES_CACHE, "a", encoding="utf-8", newline="\n") as cache:
        lookup(unlisted, cache)
    listed = set(files)
    hidden = sorted(p for p in in_scope_old if p not in listed and sizes.get(p) is not None and sizes[p] >= 0)
    print(f"unlisted old entries: {len(unlisted)} checked; hidden-but-present {len(hidden)}, "
          f"gone {sum(1 for p in unlisted if sizes.get(p) is None)}", file=sys.stderr)
    gone404 = sorted(p for p, s in sizes.items() if s is None and p in listed)
    nosize = sorted(p for p, s in sizes.items() if s == -1)
    sizes = {p: s for p, s in sizes.items() if s is not None and s >= 0}
    # 크기를 못 받은 파일: 존재는 확인된 것이므로 manifest에서 빼지 않는다. 옛 항목이면 이전 크기를 유지하고,
    # 신규 파일이면 크기가 없어 manifest에 넣을 수 없다 — 둘 다 보고서에 남긴다.
    nosize_kept = {p: in_scope_old[p] for p in nosize if p in in_scope_old and in_scope_old[p] is not None}
    nosize_new = [p for p in nosize if p not in nosize_kept]
    sizes.update(nosize_kept)

    added = {p: s for p, s in sizes.items() if p not in in_scope_old}
    removed = {p: b for p, b in in_scope_old.items() if p not in sizes}
    changed = {p: (in_scope_old[p], s) for p, s in sizes.items() if p in in_scope_old and in_scope_old[p] != s}
    gib = lambda b: b / GIB

    date = datetime.date.today().isoformat()
    rep = [f"# release/ 크롤 대조 {date}", "",
           f"FTP `{BASE}release/` 라이브 인덱스 재귀 크롤 + 파일별 HEAD. 도구: `phase0_download/scripts/crawl_release.py`.",
           f"대조 기준: `{baseline_label()}` · ROOT: {', '.join(ROOTS)}"
           + (" · **dry-run**" if DRY else ""), "",
           "| 항목 | 파일 | GiB |", "|---|---|---|",
           f"| FTP 현재 | {len(sizes)} | {gib(sum(sizes.values())):.2f} |",
           f"| manifest(이전) | {len(in_scope_old)} | {gib(sum(b for b in in_scope_old.values() if b)):.2f} |",
           f"| 추가 | {len(added)} | {gib(sum(added.values())):.2f} |",
           f"| FTP에서 사라짐(manifest에서 제거) | {len(removed)} | {gib(sum(b for b in removed.values() if b)):.2f} |",
           f"| 인덱스에 숨겨진 파일(dotfile 등, HEAD로 존재 확인해 유지) | {len(hidden)} | {gib(sum(sizes[p] for p in hidden)):.2f} |",
           f"| 크기 변경 | {len(changed)} | - |", ""]
    if added:
        rep += ["## 추가 (디렉토리 단위)", "", "| 디렉토리 | 파일 | GiB |", "|---|---|---|"]
        for k, ps in sorted(group(added).items()):
            rep.append(f"| `{k}` | {len(ps)} | {gib(sum(added[p] for p in ps)):.2f} |")
        rep += ["", "<details><summary>파일 목록</summary>", ""] + [f"- `{p}` {added[p]:,}" for p in sorted(added)] + ["", "</details>", ""]
    if removed:
        rep += ["## FTP에서 사라짐", "", "| 디렉토리 | 파일 |", "|---|---|"]
        for k, ps in sorted(group(removed).items()):
            rep.append(f"| `{k}` | {len(ps)} |")
        rep += ["", "<details><summary>파일 목록</summary>", ""] + [f"- `{p}`" for p in sorted(removed)] + ["", "</details>", ""]
    if changed:
        rep += ["## 크기 변경 (manifest → FTP)", ""] + [f"- `{p}` {a:,} → {b:,}" for p, (a, b) in sorted(changed.items())] + [""]
    if gone404:
        rep += ["## 인덱스에는 있으나 HEAD 404", ""] + [f"- `{p}`" for p in gone404] + [""]
    if nosize_kept:
        rep += ["## 크기를 못 받은 파일 — 이전 manifest 크기 유지", ""] + [f"- `{p}` {nosize_kept[p]:,}" for p in sorted(nosize_kept)] + [""]
    if nosize_new:
        rep += ["## 크기를 못 받은 신규 파일 (manifest 미반영 — 다음 크롤에서 재시도)", ""] + [f"- `{p}`" for p in nosize_new] + [""]
    if DRY:  # 보고서를 docs/에 남기지 않는다 — 실행 보고서를 덮어쓰면 증거가 사라진다
        rp = os.path.join(CACHE, f"release_crawl_{datetime.datetime.now():%Y%m%d-%H%M%S}.dry.md")
    else:
        os.makedirs(os.path.join(PROJ, "docs", "reference"), exist_ok=True)
        rp = os.path.join(PROJ, "docs", "reference", f"release_crawl_{date}.md")
        k = 2
        while os.path.exists(rp):  # 같은 날 두 번째 실행부터 _2, _3 … (덮어쓰지 않음)
            rp = os.path.join(PROJ, "docs", "reference", f"release_crawl_{date}_{k}.md")
            k += 1
    with open(rp, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(rep))
    print(f"report: {rp}", file=sys.stderr)
    print(f"added {len(added)} ({gib(sum(added.values())):.2f} GiB), removed {len(removed)}, changed {len(changed)}, "
          f"404 {len(gone404)}, nosize kept {len(nosize_kept)} / new {len(nosize_new)}")

    if not DRY:
        new = {p: b for p, b in old.items() if not in_scope(p)}
        new.update({p: s for p, s in sizes.items() if in_scope(p)})
        with open(MANIFEST, "w", encoding="utf-8", newline="\n") as fh:
            for p in sorted(new):
                fh.write(f"{p}\t{new[p]}\n")
        already = set()
        if os.path.exists(STALE):
            already = {l.split("\t")[0] for l in open(STALE, encoding="utf-8") if l.strip()}
        to_log = [p for p in sorted(removed) if p not in already]
        if to_log:
            with open(STALE, "a", encoding="utf-8", newline="\n") as fh:
                for p in to_log:
                    fh.write(f"{p}\t{removed[p]}\t{date}\n")
        print(f"manifest rewritten: {len(new)} lines; stale appended: {len(to_log)} (already logged: {len(removed) - len(to_log)})", file=sys.stderr)


if __name__ == "__main__":
    main()
