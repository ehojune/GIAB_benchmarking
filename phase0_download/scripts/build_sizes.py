#!/usr/bin/env python3
"""phase0 manifest + 외부 매니페스트 3종 -> docs/SIZES.md (플랫폼 디렉토리 단위 정확 바이트, 조회용).

    python phase0_download/scripts/build_sizes.py

'플랫폼 디렉토리' = 샘플 루트 바로 아래 디렉토리. HG008/HG009는 <lab>/<platform> 두 단계.
카테고리는 그 파일이 들어 있는 manifest 파일명(= download.sh 카테고리). 외부 유래는 ext_manifest의 dsid.
"""
import csv, os, glob
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
P0 = os.path.dirname(HERE); ROOT = os.path.dirname(P0)
MAN = os.path.join(P0, 'manifests'); OUT = os.path.join(ROOT, 'docs', 'SIZES.md')
GIB = 1024 ** 3
SAMPLE_ROOT = {
    'data/NA12878/': 'HG001',
    'data/AshkenazimTrio/HG002_NA24385_son/': 'HG002',
    'data/AshkenazimTrio/HG003_NA24149_father/': 'HG003',
    'data/AshkenazimTrio/HG004_NA24143_mother/': 'HG004',
    'data/ChineseTrio/HG005_NA24631_son/': 'HG005',
    'data/ChineseTrio/HG006_NA24694-huCA017E_father/': 'HG006',
    'data/ChineseTrio/HG007_NA24695-hu38168_mother/': 'HG007',
    'data_somatic/HG008/': 'HG008',
    'data_somatic/HG009/': 'HG009',
}

def platform_of(key):
    for root, s in SAMPLE_ROOT.items():
        if key.startswith(root):
            rest = key[len(root):].split('/')
            depth = 2 if s in ('HG008', 'HG009') else 1
            return s, '/'.join(rest[:depth]) if len(rest) > depth else '(root)'
    return None, None

agg = defaultdict(lambda: [0, 0])  # (sample, platform, category) -> [files, bytes]
for m in sorted(glob.glob(os.path.join(MAN, 'HG00*', '*.tsv'))):
    cat = os.path.basename(m)[:-4]
    for ln in open(m, encoding='utf-8'):
        p = ln.rstrip('\n').split('\t')
        if len(p) < 2 or not p[1].isdigit(): continue
        s, plat = platform_of(p[0])
        if s is None: continue
        a = agg[(s, plat, cat)]; a[0] += 1; a[1] += int(p[1])
special = defaultdict(lambda: [0, 0])
for name in ('release_truthsets', 'rnaseq_all', 'trio_analysis'):
    for ln in open(os.path.join(MAN, name + '.tsv'), encoding='utf-8'):
        p = ln.rstrip('\n').split('\t')
        if len(p) >= 2 and p[1].isdigit():
            top = '/'.join(p[0].split('/')[:2])
            a = special[(name, top)]; a[0] += 1; a[1] += int(p[1])
ext = defaultdict(lambda: [0, 0])
for label, rel, kcol, bcol in (('ENA (phase1)', 'phase1_pacbio_hifi/sra_manifest.tsv', 'dsid', 'bytes'),
                               ('ONT 공개 (phase2)', 'phase2_ont/ext_manifest.tsv', 'dsid', 'bytes'),
                               ('Google/HPRC (phase3)', 'phase3_shortread_wgs/ext_manifest.tsv', 'dsid', 'bytes')):
    for r in csv.DictReader(open(os.path.join(ROOT, rel), encoding='utf-8', newline=''), delimiter='\t'):
        a = ext[(label, r[kcol])]; a[0] += 1; a[1] += int(r[bcol])

tf = tb = 0
lines = ['# GIAB platform-level sizes (lookup-only reference)', '',
         '생성: `python phase0_download/scripts/build_sizes.py` — 원본은 `phase0_download/manifests/**` + 외부 매니페스트 3종. 바이트는 정확한 합계. 손으로 고치지 말 것.', '',
         '## GIAB FTP/S3 — 샘플 × 플랫폼 디렉토리', '',
         '| sample | platform dir | category | files | bytes | GiB |', '|---|---|---|---|---|---|']
for (s, plat, cat), (n, b) in sorted(agg.items()):
    lines.append(f'| {s} | {plat} | {cat} | {n} | {b} | {b/GIB:,.1f} |'); tf += n; tb += b
lines += ['', '## GIAB FTP — release / RNA-seq / trio analysis', '', '| manifest | top dir | files | bytes | GiB |', '|---|---|---|---|---|']
for (name, top), (n, b) in sorted(special.items()):
    lines.append(f'| {name} | {top} | {n} | {b} | {b/GIB:,.1f} |'); tf += n; tb += b
lines += ['', '## 외부 유래 (GIAB FTP 밖)', '', '| 출처 | dsid | files | bytes | GiB |', '|---|---|---|---|---|']
for (label, d), (n, b) in sorted(ext.items()):
    lines.append(f'| {label} | {d} | {n} | {b} | {b/GIB:,.1f} |'); tf += n; tb += b
lines += ['', f'**합계 {tf:,} files / {tb:,} bytes = {tb/GIB:,.1f} GiB = {tb/1024**4:.2f} TiB = {tb/1e12:.1f} TB** (4경로 전체)', '']
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
print(f'{OUT}: {tf:,} files / {tb/1024**4:.2f} TiB, rows={len(agg)+len(special)+len(ext)}')
