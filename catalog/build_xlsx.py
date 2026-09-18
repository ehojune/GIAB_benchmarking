#!/usr/bin/env python3
"""master_catalog.tsv -> GIAB_HG_Catalog.xlsx 의 'Master Catalog' 시트를 재생성한다.

다른 4시트(Overview, Samples, Platform Matrix, Access & Links)는 건드리지 않되,
Overview·Master Catalog의 버전/집계 문구만 --version 으로 갱신한다.

    python catalog/build_xlsx.py --version 0916 --date 2026-09-16 [--note "..."]
"""
import argparse, csv, os, sys
from copy import copy
import openpyxl

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
TSV = os.path.join(HERE, 'master_catalog.tsv'); XLSX = os.path.join(ROOT, 'GIAB_HG_Catalog.xlsx')
HEADER_ROW = 4  # row1 제목, row2 원본/집계, row3 빈줄, row4 헤더, row5~ 데이터

ap = argparse.ArgumentParser(); ap.add_argument('--version', required=True); ap.add_argument('--date', required=True)
ap.add_argument('--note', default='', help='Overview 마지막 줄(※)에 덧붙일 한 문장'); ap.add_argument('--out', default=XLSX)
ap.add_argument('--matrix-note', default='', help="'Platform Matrix' 비고에 추가할 한 줄('· '로 시작). 같은 문장이 이미 있으면 건너뜀")
ap.add_argument('--crawl-date', default='2026-09-16', help='FTP 라이브 크롤을 돌린 날짜. 카탈로그 버전 날짜(--date)와 다르다')
ap.add_argument('--link', nargs=2, metavar=('LABEL', 'URL'), action='append', default=[], help="'Access & Links' 끝에 추가할 행. 같은 URL이 있으면 건너뜀")
a = ap.parse_args()

rows = list(csv.DictReader(open(TSV, encoding='utf-8', newline=''), delimiter='\t'))
cols = list(rows[0].keys())
n_files = sum(int(r['files'] or 0) for r in rows); tib = sum(float(r['size_gib'] or 0) for r in rows) / 1024

wb = openpyxl.load_workbook(XLSX); ws = wb['Master Catalog']
hdr_cells = [ws.cell(HEADER_ROW, c + 1) for c in range(len(cols))]
assert [c.value for c in hdr_cells] == cols, f'헤더 불일치: xlsx {[c.value for c in hdr_cells][:5]} vs tsv {cols[:5]}'
hdr_style = [(copy(c.font), copy(c.fill), copy(c.alignment), copy(c.border)) for c in hdr_cells]
sample = ws.cell(HEADER_ROW + 1, 1); data_style = (copy(sample.font), copy(sample.alignment), copy(sample.border))
old_n = ws.max_row - HEADER_ROW
ws.delete_rows(HEADER_ROW + 1, max(old_n, 1))
for i, r in enumerate(rows):
    for j, k in enumerate(cols):
        v = r.get(k, '')
        if k in ('files',) and v not in ('', None):
            try: v = int(v)
            except ValueError: pass
        elif k == 'size_gib' and v not in ('', None):
            try: v = float(v)
            except ValueError: pass
        c = ws.cell(HEADER_ROW + 1 + i, j + 1, v if v != '' else None)
        c.font, c.alignment, c.border = (copy(x) for x in data_style)
last_row = HEADER_ROW + len(rows)
last_col = openpyxl.utils.get_column_letter(len(cols))
for tbl in ws.tables.values():  # 표(MasterCatalogTable) 범위를 새 행 수에 맞춘다 — 안 맞추면 추가 행이 표 정렬/필터에서 빠진다
    tbl.ref = f'A{HEADER_ROW}:{last_col}{last_row}'
if ws.auto_filter.ref:
    ws.auto_filter.ref = f'A{HEADER_ROW}:{last_col}{last_row}'
ws['A1'] = f'GIAB Master Catalog — v{a.version}'
ws['A2'] = f'원본: catalog/master_catalog.tsv · {len(rows)} datasets · {n_files:,} files · {tib:.1f} TiB · 플랫폼·리드·tool·next_step을 원문 그대로 보존'

ov = wb['Overview']
for row in ov.iter_rows(min_row=1, max_row=ov.max_row):
    c = row[0]; v = str(c.value or '')
    if v.startswith('카탈로그 버전'):
        c.value = (f'카탈로그 버전 {a.version} ({a.date}) · 기존 파일 목록 검증 2026-08-13 '
                   f'+ FTP 라이브 크롤 {a.crawl_date} (release·data) · 출처: NIST GIAB / master_catalog.tsv')
    elif v.startswith("· 'Master Catalog'"):
        c.value = f"· 'Master Catalog' : 최신 {len(rows)}개 데이터셋의 {len(cols)}개 원본 필드와 처리 현황"
    elif v.startswith('※'):
        c.value = f'※ {len(rows)} datasets / {n_files:,} files / {tib:.1f} TiB. ' + (a.note or v.split('. ', 1)[-1])
if a.matrix_note:
    pm = wb['Platform Matrix']
    existing = {str(pm.cell(r, 1).value or '') for r in range(1, pm.max_row + 1)}
    if a.matrix_note not in existing:
        r = pm.max_row + 1
        pm.cell(r, 1, a.matrix_note)
        src = pm.cell(r - 1, 1); c = pm.cell(r, 1)
        c.font, c.alignment = copy(src.font), copy(src.alignment)
for label, url in a.link:
    al = wb['Access & Links']
    urls = {str(al.cell(r, 2).value or '') for r in range(1, al.max_row + 1)}
    if url not in urls:
        r = al.max_row + 1
        al.cell(r, 1, label); al.cell(r, 2, url)
        for col in (1, 2):
            src = al.cell(r - 1, col); c = al.cell(r, col)
            c.font, c.alignment = copy(src.font), copy(src.alignment)
wb.save(a.out)
print(f'{a.out}: Master Catalog {len(rows)} rows (was {old_n}), {n_files:,} files, {tib:.1f} TiB, v{a.version}')
