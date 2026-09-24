#!/bin/bash
# gd2 정본 준비 (2026-09-25). germline 제출은 하지 않는다. 로그인 노드에서 사용자가 한 번 돌린다:
#   bash 12_prepare_gd2_jslink.sh          # 계획·검사만 (기본)
#   APPLY=1 bash 12_prepare_gd2_jslink.sh  # 실제로 바꾼다
# 1) 원래 G000-gd2-20260819 (gd4 원자료로 돈 결과) → G000-gd2-20260819-bak-gd4input-20260925 로 rename 보존
# 2) 같은 경로에 outcome/<ID>/<ID>_{1,2}.fastq.gz → data/jslink 원자료 절대경로 링크 12개만 둔 깨끗한 gd2
# 3) sampleinfo Sheet2 의 gd2 6행 SEX/note만 사용자 정본(이미지1: 1–3 KOR-101~103, 4–6 HG002~004)으로 고친다
# 원자료(data/*)·gd4·다른 set 행은 건드리지 않는다.
set -u
G=/BiO/scratch/dyl/kbb/G000; OLD=$G/G000-gd2-20260819; BAK=$G/G000-gd2-20260819-bak-gd4input-20260925
FIX=$G/G000-gd2-20260819-jslink-20260925; D=/BiO/scratch/dyl/kbb/data/jslink
X=$G/sampleinfo/sample_information_nbb2.xlsx
IDS="C000000200100000G0x1 C000000200200000G0x1 C000000200300000G0x1 C000000200400000G0x1 C000000200500000G0x1 C000000200600000G0x1"
die() { echo "ABORT: $*" >&2; exit 1; }

echo "== 검사"
[ -d "$OLD" ] && [ ! -L "$OLD" ] && [ "$(realpath -e "$OLD")" = "$OLD" ] || die "$OLD 이 실제 디렉터리가 아니다"
[ "$(dirname "$(realpath -e "$OLD")")" = "$G" ] || die "상위가 $G 가 아니다"
[ -e "$BAK" ] && die "$BAK 이 이미 있다"
for j in $(qstat -u '*' 2>/dev/null | awk 'NR>2{print $1}'); do
  c=$(qstat -j "$j" 2>/dev/null | awk '/^cwd:/{print $2}')
  case "$c" in "$OLD"|"$OLD"/*) die "job $j 이 $OLD 에서 돈다";; esac
done
for id in $IDS; do
  r1=$(ls "$D"/${id}_S*_L005_R1_001.fastq.gz 2>/dev/null); r2=$(ls "$D"/${id}_S*_L005_R2_001.fastq.gz 2>/dev/null)
  [ "$(echo $r1 | wc -w)" = 1 ] && [ "$(echo $r2 | wc -w)" = 1 ] && [ -s "$r1" ] && [ -s "$r2" ] || die "$id mate가 하나씩이 아니다"
  echo "  $id  $(stat -c '%i %s' "$r1") $(basename "$r1") | $(stat -c '%i %s' "$r2") $(basename "$r2")"
done
echo "  옛 gd2 항목 수: $(find "$OLD" -xdev | wc -l)"
if [ "${APPLY:-0}" != 1 ]; then echo "DRY-RUN — 실제로 바꾸려면 APPLY=1"; exit 0; fi

echo "== 1) 옛 gd2 보존"
mv -T -n "$OLD" "$BAK" && [ ! -e "$OLD" ] && [ -d "$BAK" ] || die "rename 실패"
printf 'backup_at=%s\nfrom=%s\nreason=12 mate 링크가 data/cginvites/G000-gd4-20260819(gd4 원자료, 같은 inode)를 가리켰다. 사용자 요청으로 원래 경로를 비우고 jslink로 다시 준비.\n' \
  "$(date '+%F %T')" "$OLD" > "$BAK/BACKUP_NOTE.txt"
echo "  $BAK 항목 수: $(find "$BAK" -xdev | wc -l)"

echo "== 2) 깨끗한 gd2"
mkdir "$OLD" "$OLD/outcome"
for id in $IDS; do
  mkdir "$OLD/outcome/$id"
  ln -s "$(ls "$D"/${id}_S*_L005_R1_001.fastq.gz)" "$OLD/outcome/$id/${id}_1.fastq.gz"
  ln -s "$(ls "$D"/${id}_S*_L005_R2_001.fastq.gz)" "$OLD/outcome/$id/${id}_2.fastq.gz"
done
bad=0
for f in "$OLD"/outcome/*/*_[12].fastq.gz; do
  t=$(readlink -f "$f"); b=$(basename "$f"); id=${b%_*}; m=${b##*_}; m=${m%%.*}
  case "$t" in "$D"/${id}_S*_L005_R${m}_001.fastq.gz) ;; *) echo "  BAD $b -> $t"; bad=1;; esac
  [ -s "$t" ] || { echo "  DANGLING $b"; bad=1; }
done
n=$(ls "$OLD"/outcome/*/*.fastq.gz | wc -l); other=$(find "$OLD" -mindepth 1 -not -path "$OLD/outcome*" | wc -l)
echo "  링크 $n개, outcome 밖 항목 $other개, 이상 $bad"
[ "$n" = 12 ] && [ "$other" = 0 ] && [ "$bad" = 0 ] || die "새 gd2 검증 실패 (옛 것은 $BAK 에 있다)"
[ -d "$FIX" ] && printf 'DO NOT RUN — 준비 이력으로 보존. job 156732 qdel(2026-09-25, exit 137). 정본 gd2는 %s.\n' "$OLD" > "$FIX/DO_NOT_RUN.txt"

echo "== 3) sampleinfo gd2 6행"
python3 - "$X" <<'PY'
import openpyxl, os, shutil, sys, time
x = sys.argv[1]
want = {'C000000200100000G0x1': ('male', 'KOR-101'), 'C000000200200000G0x1': ('female', 'KOR-102'),
        'C000000200300000G0x1': ('male', 'KOR-103'), 'C000000200400000G0x1': ('male', 'HG002'),
        'C000000200500000G0x1': ('male', 'HG003'), 'C000000200600000G0x1': ('female', 'HG004')}
lock = x + '.lock'; os.mkdir(lock)          # 03_make_pipeline_dirs.py와 같은 lock
try:
    wb = openpyxl.load_workbook(x); ws = wb['Sheet2']
    assert [c.value for c in ws[1]] == ['SET_ID', 'DNA_ID', 'SEX', 'note'], 'header'
    assert not ws.tables and not any(isinstance(c.value, str) and c.value.startswith('=') for r in ws.iter_rows() for c in r), 'table/formula'
    before = [[c.value for c in r] for r in ws.iter_rows()]
    rows = {r[1].value: i for i, r in enumerate(ws.iter_rows(min_row=2), 2) if r[1].value in want}
    assert len(rows) == 6 and all(ws.cell(i, 1).value == 'G000-gd2-20260819' for i in rows.values()), rows
    change = [(k, ws.cell(i, 3).value, ws.cell(i, 4).value) for k, i in rows.items() if (ws.cell(i, 3).value, ws.cell(i, 4).value) != want[k]]
    for c in change: print('  change', c, '->', want[c[0]])
    if not change: print('  수정 불필요 — 저장 안 함'); sys.exit(0)
    bak = f"{x}.bak-{time.strftime('%Y%m%d-%H%M%S')}-gd2fix"; shutil.copy2(x, bak); print('  backup', bak)
    for k, i in rows.items(): ws.cell(i, 3).value, ws.cell(i, 4).value = want[k]
    tmp = x[:-5] + f'.tmp-{os.getpid()}.xlsx'; wb.save(tmp)
    after = [[c.value for c in r] for r in openpyxl.load_workbook(tmp)['Sheet2'].iter_rows()]
    assert len(after) == len(before)
    diff = {(ri, ci) for ri, (a, b) in enumerate(zip(before, after)) for ci, (u, v) in enumerate(zip(a, b)) if u != v}
    assert diff <= {(i - 1, c) for i in rows.values() for c in (2, 3)}, 'gd2 SEX/note 밖이 바뀌었다'
    ids = [r[1] for r in after[1:] if r[1]]; assert len(ids) == len(set(ids)), 'dup DNA_ID'
    shutil.copymode(x, tmp); os.replace(tmp, x); print(f'  저장: 바뀐 칸 {len(diff)}, 행 {len(after)}')
finally:
    shutil.rmtree(lock, ignore_errors=True)
for r in openpyxl.load_workbook(x, read_only=True)['Sheet2'].iter_rows(values_only=True):
    if r[0] == 'G000-gd2-20260819': print('  ', r)
PY
echo "완료. 제출은 사용자: source /BiO/scratch/dyl/kbb/bashrc.txt; cd $OLD; germline $OLD"
