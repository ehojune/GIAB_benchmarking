#!/usr/bin/env python3
"""master_catalog.tsv -> README.md 의 master table 블록을 재생성한다.

README.md 안의 <!-- MASTER-TABLE:BEGIN --> ... <!-- MASTER-TABLE:END --> 사이만 교체한다.
나머지 본문은 손대지 않는다.

    python catalog/build_readme.py
"""
import csv
import os
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TSV = os.path.join(HERE, 'master_catalog.tsv')
README = os.path.join(ROOT, 'README.md')
BEGIN = '<!-- MASTER-TABLE:BEGIN -->'
END = '<!-- MASTER-TABLE:END -->'

CAT_LABEL = {
    'pacbio_hifi': 'PacBio HiFi',
    'pacbio_clr': 'PacBio CLR',
    'ont': 'Oxford Nanopore',
    'illumina_wgs': 'Illumina WGS',
    'bgi_mgi': 'BGI / MGI',
    'exome': 'Exome',
    'linked_reads': 'Linked reads (10X, stLFR)',
    'complete_genomics': 'Complete Genomics',
    'other': '기타 기술 (BioNano, Hi-C, AVITI, UG100, Strand-seq 등)',
    'release_truthsets': 'Release — truth set / stratification / reference',
    'rnaseq_all': 'RNA-seq',
    'trio_analysis': 'Trio-level analysis',
}
CAT_ORDER = list(CAT_LABEL)

STEPS = [
    ('aligned', 'align_tool', '정렬'),
    ('phased', 'phase_tool', '페이징'),
    ('variant_called', 'variant_tool', '변이'),
    ('meth_called', 'meth_tool', '메틸'),
    ('somatic_called', 'somatic_tool', 'somatic'),
    ('assembled', 'assembly_tool', '어셈블리'),
]


def truthy(v):
    return str(v).strip().upper() == 'TRUE'


def na(v):
    return str(v).strip() in ('-', '')


def cell(done, tool, by):
    """단계 셀: 완료 여부 + 툴 + 수행 주체."""
    d = str(done).strip()
    if d in ('-', ''):
        return '–'
    if d.upper() == 'N/A':
        return 'N/A'
    if d.upper() != 'TRUE':
        return '✗'
    t = esc(tool)
    b = str(by).strip()
    label = '✓'
    if t and t not in ('N/A', '-'):
        label += f' {t}'
    elif t == 'N/A':
        label += ' N/A'
    if b == 'me':
        label += ' *(나)*'
    return label


def idx_cell(row):
    p = str(row.get('index_present', '')).strip().upper()
    if p in ('-', ''):
        return '–'
    if p == 'TRUE':
        return '✓'
    n = str(row.get('index_unindexed_n', '')).strip()
    by = str(row.get('index_by', '')).strip()
    # PARTIAL = GIAB가 일부만 인덱싱함, FALSE = 전부 없음
    out = '△' if p == 'PARTIAL' else '✗'
    if n and n not in ('0', '-'):
        out += f' {n}개'
    if by == 'me':
        out += ' *(나)*'
    return out


def reads_cell(row):
    if truthy(row.get('reads_present')):
        f = esc(row.get('reads_format', ''))
        return f'✓ {f}' if f else '✓'
    if str(row.get('reads_present', '')).strip().upper() == 'N/A':
        return 'N/A'
    if str(row.get('reads_present', '')).strip() == '-':
        return '–'
    return '✗'


def esc(s):
    return str(s).replace('|', r'\|').replace('\n', ' ').strip()


def short_label(label, sample):
    """dataset 라벨에서 sample 컬럼과 겹치는 앞머리를 떼어낸다."""
    lab = esc(label)
    s = esc(sample)
    for pre in (s + ' ', s + '_', s + '-'):
        if s and lab.startswith(pre):
            return lab[len(pre):] or lab
    return lab


def main():
    if not os.path.exists(TSV):
        sys.exit(f'없음: {TSV}')
    with open(TSV, encoding='utf-8', newline='') as f:
        rows = list(csv.DictReader(f, delimiter='\t'))
    if not rows:
        sys.exit('master_catalog.tsv 가 비어 있음')

    out = []
    total_files = sum(int(r['files'] or 0) for r in rows)
    total_gib = sum(float(r['size_gib'] or 0) for r in rows)

    # ---- 요약 -----------------------------------------------------------
    out.append('### 요약\n')
    out.append(f'전체 **{len(rows)}개 데이터셋 / {total_files:,} files / '
               f'{total_gib / 1024:.1f} TiB**. 단계별 도달 데이터셋 수:\n')
    hdr = ['category', '데이터셋', 'GiB'] + [lbl for _, _, lbl in STEPS] + ['GIAB 처리물 보유']
    out.append('| ' + ' | '.join(hdr) + ' |')
    out.append('|' + '---|' * len(hdr))
    for cat in CAT_ORDER:
        sub = [r for r in rows if r['category'] == cat]
        if not sub:
            continue
        cnt = [sum(1 for r in sub if truthy(r[k])) for k, _, _ in STEPS]
        gp = sum(1 for r in sub if truthy(r.get('giab_processed')))
        out.append('| ' + ' | '.join(
            [CAT_LABEL[cat], str(len(sub)), f'{sum(float(r["size_gib"] or 0) for r in sub):,.0f}']
            + [str(c) for c in cnt] + [str(gp)]) + ' |')
    out.append('')

    # ---- 카테고리별 상세 -------------------------------------------------
    cols = ['데이터셋', '샘플', '플랫폼', 'GiB', '리드', 'index'] \
        + [lbl for _, _, lbl in STEPS] + ['출처', '다음 할 일']
    for cat in CAT_ORDER:
        sub = [r for r in rows if r['category'] == cat]
        if not sub:
            continue
        n_gib = sum(float(r['size_gib'] or 0) for r in sub)
        out.append(f'<details>')
        out.append(f'<summary><b>{CAT_LABEL[cat]}</b> — '
                   f'{len(sub)} datasets, {n_gib:,.0f} GiB</summary>\n')
        out.append('| ' + ' | '.join(cols) + ' |')
        out.append('|' + '---|' * len(cols))
        for r in sorted(sub, key=lambda x: (x['sample'], x['dataset'])):
            src = str(r.get('tool_source', '')).strip()
            if src.startswith('giab_doc:'):
                src = '문서'
            elif src == 'filename':
                src = '파일명'
            elif not src or src == 'N/A':
                src = 'N/A'
            line = [
                short_label(r['dataset'], r['sample']),
                esc(r['sample']),
                esc(r['platform']),
                f'{float(r["size_gib"] or 0):,.0f}',
                reads_cell(r),
                idx_cell(r),
            ]
            for done, tool, _ in STEPS:
                by = tool.replace('_tool', '_by')
                line.append(cell(r.get(done), r.get(tool), r.get(by)))
            line += [src, esc(r.get('next_step', ''))]
            out.append('| ' + ' | '.join(line) + ' |')
        out.append('\n</details>\n')

    block = BEGIN + '\n' + '\n'.join(out) + '\n' + END

    text = open(README, encoding='utf-8').read()
    if BEGIN not in text or END not in text:
        sys.exit(f'README.md 에 {BEGIN} / {END} 마커가 없음')
    pre = text.split(BEGIN)[0]
    post = text.split(END, 1)[1]
    open(README, 'w', encoding='utf-8', newline='\n').write(pre + block + post)
    print(f'README.md 갱신: {len(rows)} datasets, {len(block):,} chars in table block')


if __name__ == '__main__':
    main()
