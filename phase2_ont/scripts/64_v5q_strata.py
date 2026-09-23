#!/usr/bin/env python3
"""v5.0q smvar 구간을 v4.2.1 구간과 대어 **겹침 / v5.0q 에만** 두 층으로 나눈다 (로그인 노드, 1초).

    python phase2_ont/scripts/64_v5q_strata.py <v5.0q.bed> <v4.2.1.bed> <출력 디렉토리>

산출: <출력>/v5q_and_v421.bed, <출력>/v5q_not_v421.bed, <출력>/strata.tsv(hap.py --stratification 용)

**왜 필요한가.** 63_caller_diff_regions.sh 는 "v4.2.1 구간 밖" 콜의 ts/tv 만 봤고, truth 가 없어
그 콜이 진짜인지 FP 인지는 가르지 못했다. v5.0q smvar(T2T-Q100 유래)는 v4.2.1 이 빼놓은 어려운
영역 상당 부분까지 truth 가 있다. 그 **v5.0q 에만 있는 구간**에서 두 caller 의 FN·FP 를 직접 세면
"DV 가 v4.2.1 밖에서 진짜 변이를 버리는가" 에 답이 나온다.

**v5.0q 전체 결과에서 v4.2.1 결과를 빼면 안 된다.** 두 truth 는 겹치는 구간에서도 서로 다르다
(T2T 기반 재호출이라 같은 자리의 유전형·표현이 다를 수 있다). 그래서 차이는 "v4.2.1 밖의 성능" 이
아니라 두 truth 의 차이와 뒤섞인다 — 2026-09-23 "순 차이 2.18" 과 같은 함정이다. 그래서 hap.py
--stratification 으로 **한 번의 채점 안에서** 구간을 갈라 센다. 겹침 층은 대조용이다 — 거기 성능이
v4.2.1 채점과 크게 다르면 두 truth 의 차이가 크다는 신호다.

BED 는 0-based half-open 으로 다룬다. 입력을 염색체별로 정렬·병합한 뒤 쓸어 가며 교집합·차집합을 낸다.
"""
import sys
from collections import defaultdict
from pathlib import Path

# LANG=C 환경(SGE 잡 등)에서 한글 출력이 UnicodeEncodeError 로 죽지 않게 (50_update_catalog.py 와 같다)
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass


def read_bed(path):
    """-> ({염색체: 병합된 구간}, [입력에 처음 나온 순서의 염색체])"""
    iv = defaultdict(list)
    order = []
    with open(path) as f:
        for line in f:
            if not line.strip() or line.startswith(("#", "track", "browser")):
                continue
            c, s, e = line.split("\t")[:3]
            s, e = int(s), int(e)
            if c not in iv:
                order.append(c)
            if e > s:
                iv[c].append((s, e))
    return {c: merge(v) for c, v in iv.items()}, order


def merge(v):
    v = sorted(v)
    out = []
    for s, e in v:
        if out and s <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], e))
        else:
            out.append((s, e))
    return out


def intersect(a, b):
    i = j = 0
    out = []
    while i < len(a) and j < len(b):
        s, e = max(a[i][0], b[j][0]), min(a[i][1], b[j][1])
        if s < e:
            out.append((s, e))
        if a[i][1] < b[j][1]:
            i += 1
        else:
            j += 1
    return out


def subtract(a, b):
    out = []
    j = 0
    for s, e in a:
        cur = s
        while j < len(b) and b[j][1] <= cur:
            j += 1
        k = j
        while k < len(b) and b[k][0] < e:
            if b[k][0] > cur:
                out.append((cur, b[k][0]))
            cur = max(cur, b[k][1])
            if cur >= e:
                break
            k += 1
        if cur < e:
            out.append((cur, e))
    return out


def bp(d):
    return sum(e - s for v in d.values() for s, e in v)


def write_bed(d, path, order):
    with open(path, "w") as f:
        for c in order:
            for s, e in d.get(c, []):
                f.write(f"{c}\t{s}\t{e}\n")


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    (v5, order), (v4, _), out = read_bed(sys.argv[1]), read_bed(sys.argv[2]), Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    # 출력은 v5.0q 입력의 염색체 순서를 그대로 따른다(GIAB 가 참조 순서로 낸다). 다시 정렬하지 않는다.

    # **v4.2.1 이 아예 안 덮는 염색체는 따로 뺀다.** v4.2.1 은 파일명대로 chr1~22 만 덮는다. v5.0q 가
    # chrX 를 담으면 그 전체가 "v4.2.1 밖" 에 들어가는데, 그건 v4.2.1 이 어렵다고 뺀 영역이 아니라
    # 애초에 대상이 아니었던 염색체다(HG002 는 남성이라 chrX 는 반접합이기도 하다). 한 층에 섞으면
    # "어려운 영역에서 caller 가 무엇을 버리나" 를 읽을 수 없다.
    covered = set(v4)
    both, only, other = {}, {}, {}
    for c in order:
        if c in covered:
            both[c] = intersect(v5[c], v4[c])
            only[c] = subtract(v5[c], v4[c])
        else:
            other[c] = v5[c]

    # 쪼갠 세 층을 합치면 v5.0q 전체와 같아야 한다 — 안 맞으면 구간 연산이 틀린 것이다.
    if bp(both) + bp(only) + bp(other) != bp(v5):
        sys.exit(f"ERROR: 겹침 {bp(both)} + v5.0q에만 {bp(only)} + 다른 염색체 {bp(other)} != v5.0q {bp(v5)}")

    strata = [("v5q_and_v421", both), ("v5q_not_v421", only), ("v5q_other_chrom", other)]
    with open(out / "strata.tsv", "w") as f:
        for name, d in strata:
            if bp(d) == 0:            # 빈 BED 를 hap.py 에 넘기지 않는다
                continue
            write_bed(d, out / f"{name}.bed", order)
            f.write(f"{name}\t{(out / f'{name}.bed').resolve()}\n")

    print(f"v5.0q        {bp(v5):>14,} bp")
    print(f"v4.2.1       {bp(v4):>14,} bp  (염색체 {len(covered)}개)")
    print(f"  겹침       {bp(both):>14,} bp  ({100 * bp(both) / bp(v5):.1f}% of v5.0q)")
    print(f"  v5.0q에만  {bp(only):>14,} bp  ({100 * bp(only) / bp(v5):.1f}% of v5.0q)  <- v4.2.1 이 덮는 염색체 안의 '밖'")
    print(f"  다른 염색체 {bp(other):>13,} bp  ({', '.join(other) or '없음'}) — v4.2.1 이 아예 안 덮는 곳")
    print(f"  v4.2.1에만 {bp({c: subtract(v4[c], v5.get(c, [])) for c in v4}):>14,} bp  (v5.0q 가 뺀 구간 — 여기선 안 센다)")
    print(f"-> {out}/strata.tsv")


if __name__ == "__main__":
    main()
