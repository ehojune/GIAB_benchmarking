#!/bin/bash
# 03_make_pipeline_dirs.py 로컬 검증 — 가짜 FASTQ·가짜 qsub/qstat로 링크·병합·가드·lock·qsub 중복 방지·lanes·덮어쓰기 가드를 본다.
# 리눅스(WSL 포함) + python3 이면 된다(openpyxl 불필요; sampleinfo는 따로). 서버·실데이터를 건드리지 않는다: /tmp/p3test 만 쓴다.
#   bash phase3_shortread_wgs/scripts/test_03_make_pipeline_dirs.sh      # 끝줄 '결과: PASS n / FAIL 0'
set -u
R=$(cd "$(dirname "$0")/.." && pwd)
S=$R/scripts/03_make_pipeline_dirs.py
T=/tmp/p3test; rm -rf $T; mkdir -p $T/sheets $T/data $T/bin
pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }; ng(){ echo "FAIL $1"; fail=$((fail+1)); }
for f in $R/samplesheets/*.csv; do sed "s#/BiO/scratch/ehojune/GIAB_benchmark#$T/data#g" "$f" > $T/sheets/$(basename "$f"); done
# 선택한 샘플의 원본만 가짜로 만든다 (리드 1개짜리 gzip, 파일마다 내용이 달라 병합 순서를 검증할 수 있게 리드 이름에 파일명)
python3 - "$T" <<'PY'
import csv, gzip, os, sys
T = sys.argv[1]
want = ["HG006.HiSeq100x", "HG007.HiSeq100x", "HG001.BGISEQ500", "HG001-stdlib.BGISEQ500_stdlib", "HG008-T.PacBio_Onso_20240415",
        "HG008-N-D.PacBio_Onso_20240415", "HG002.NIST_BGIseq_2x150_100x", "HG005.NIST_BGIseq_2x150_100x", "HG001.Element_AVITI_20240920"]
for d in want:
    for r in csv.DictReader(l for l in open(f"{T}/sheets/{d}.csv") if not l.startswith("#")):
        for k in ("fastq_1", "fastq_2"):
            os.makedirs(os.path.dirname(r[k]), exist_ok=True)
            with gzip.open(r[k], "wt") as g: g.write(f"@{os.path.basename(r[k])}\nACGT\n+\nIIII\n")
PY
cat > $T/bin/qsub <<'Q'
#!/bin/bash
n=$(( $(cat /tmp/p3test/qsub.n 2>/dev/null || echo 900000) + 1 )); echo $n > /tmp/p3test/qsub.n; echo "$*" >> /tmp/p3test/qsub.log
echo "Your job $n (\"x\") has been submitted"
Q
cat > $T/bin/qstat <<'Q'
#!/bin/bash
[ "$1" = "-j" ] && grep -qx "$2" /tmp/p3test/alive 2>/dev/null && { echo "job_number: $2"; exit 0; }; exit 1
Q
chmod +x $T/bin/*; touch $T/alive
export PATH=$T/bin:$PATH
run(){ python3 $S --sheets $T/sheets --more-table $R/more_run_table.tsv "$@"; }
SEL="--only Hiseq-100x --only BGISEQ500-NA12878 --only HG008-Onso --only NIST-BGIseq-100x --only Element-AVITI-NA12878"

echo "== T1 dry-run 전체"; D=$T/d1; mkdir -p $D
out=$(run --dest $D --dry-run 2>&1); rc=$?
[ $rc = 0 ] && echo "$out" | grep -q "병합 " && ok "T1 dry-run rc=0" || { ng "T1 rc=$rc"; echo "$out" | tail -5; }
echo "$out" | grep -c "CONCAT\|LINK" | xargs echo "   계획 줄 수:"
[ -z "$(ls -A $D)" ] && ok "T1 dry-run은 아무것도 안 만든다" || ng "T1 dry-run이 뭔가 만들었다"

echo "== T2 링크 + 병합 실행"; D=$T/d2; mkdir -p $D
out=$(run --dest $D $SEL --run-concat --jobs 4 2>&1); rc=$?
[ $rc = 0 ] && ok "T2 rc=0" || { ng "T2 rc=$rc"; echo "$out" | tail -8; }
L=$D/GIAB-publicData-HG008-Onso/outcome/GIAB-publicData-HG008-Onso-HG008-T/GIAB-publicData-HG008-Onso-HG008-T_1.fastq.gz
[ -L "$L" ] && [ "$(readlink "$L")" = "$T/data/data_somatic/HG008/Liss_lab/PacBio_Onso_20240415/HG008-T_R1_trimmed.fastq.gz" ] && ok "T2 1쌍은 원본 링크" || ng "T2 링크 $(readlink "$L")"
C=$D/GIAB-publicData-Hiseq-100x/outcome/GIAB-publicData-Hiseq-100x-HG006
n1=$(zcat $C/GIAB-publicData-Hiseq-100x-HG006_1.fastq.gz | grep -c '^@'); n2=$(zcat $C/GIAB-publicData-Hiseq-100x-HG006_2.fastq.gz | grep -c '^@')
[ "$n1" = 300 ] && [ "$n2" = 300 ] && ok "T2 HG006 300쌍 병합 (R1 $n1, R2 $n2)" || ng "T2 병합 리드 수 $n1/$n2"
# R1/R2 순서가 짝으로 맞는가: i번째 R1 리드 이름에서 R1->R2 로 바꾸면 i번째 R2와 같아야
paste <(zcat $C/*_1.fastq.gz | awk 'NR%4==1' | sed 's/_R1_/_R2_/') <(zcat $C/*_2.fastq.gz | awk 'NR%4==1') | awk '$1!=$2{b++} END{exit b>0}' && ok "T2 R1/R2 순서 짝 일치" || ng "T2 R1/R2 순서 어긋남"
[ ! -e $C/.concat.lock ] && ok "T2 lock 해제됨" || ng "T2 lock 남음"
ls -d $D/GIAB-publicData-* | sed "s#$D/##" | tr '\n' ' '; echo
bad=$(find $D -name '*_*' | grep -vE '_[12]\.fastq\.gz$|concat_R[12]\.list$' | head -3); [ -z "$bad" ] && ok "T2 mate 접미 외 밑줄 없음" || ng "T2 밑줄: $bad"
out=$(run --dest $D $SEL --run-concat 2>&1); echo "$out" | grep -q "병합 0 샘플\|완료 .*/" && ok "T2 재실행 멱등 (SKIP)" || { ng "T2 재실행"; echo "$out" | tail -3; }

echo "== T3 파이프라인이 손댄 새 set에 새 샘플 → 멈춤"; D=$T/d3; mkdir -p $D/GIAB-publicData-Element-AVITI-NA12878; touch $D/GIAB-publicData-Element-AVITI-NA12878/__DONE__
out=$(run --dest $D --only Element-AVITI-NA12878 2>&1); rc=$?
[ $rc = 1 ] && echo "$out" | grep -q "이미 돌았거나" && [ ! -d $D/GIAB-publicData-Element-AVITI-NA12878/outcome ] && ok "T3 intrusion 거부, 아무것도 안 만듦" || { ng "T3 rc=$rc"; echo "$out" | tail -3; }
out=$(run --dest $D --only Element-AVITI-NA12878 --dry-run 2>&1); [ $? = 1 ] && ok "T3 dry-run에서도 알림" || ng "T3 dry-run 통과해버림"

echo "== T4 1차 set: 샘플 dir 있으면 통과, 없으면 거부"; D=$T/d4; B=$D/GIAB-publicData-BGISEQ500; mkdir -p $B/tmp
for h in HG002 HG003 HG004; do mkdir -p $B/outcome/GIAB-publicData-BGISEQ500-$h; touch $B/outcome/GIAB-publicData-BGISEQ500-$h/concat.sh; done
run --dest $D --only BGISEQ500 --dry-run >/dev/null 2>&1 && ok "T4 기존 샘플 재실행 허용" || ng "T4 기존 샘플을 막음"
rm $B/outcome/GIAB-publicData-BGISEQ500-HG004/concat.sh   # 빈 dir만 남김 — 이미 만든 샘플로 치면 안 된다
run --dest $D --only BGISEQ500 --dry-run >/dev/null 2>&1; [ $? = 1 ] && ok "T4 1차 set에 빠진 샘플 새로 만들기는 거부" || ng "T4 빈 dir이 가드를 우회"

echo "== T5 lock"; C=$T/d2/GIAB-publicData-Hiseq-100x/outcome/GIAB-publicData-Hiseq-100x-HG007
mkdir $C/.concat.lock; echo "fakehost pid=1" > $C/.concat.lock/owner
bash $C/concat.sh >/dev/null 2>&1; [ $? = 3 ] && ok "T5 lock이면 concat.sh exit 3" || ng "T5 lock 무시"
rm $C/GIAB-publicData-Hiseq-100x-HG007_1.fastq.gz
out=$(run --dest $T/d2 --only Hiseq-100x --qsub 2>&1); echo "$out" | grep -q "SKIP GIAB-publicData-Hiseq-100x-HG007: .concat.lock" && ok "T5 --qsub이 lock 샘플 건너뜀" || { ng "T5"; echo "$out" | tail -3; }
rm -r $C/.concat.lock

echo "== T6 qsub 중복 제출 방지"; D=$T/d6; mkdir -p $D; : > $T/qsub.log
run --dest $D --only Hiseq-100x --qsub >/dev/null 2>&1
[ "$(wc -l < $T/qsub.log)" = 2 ] && ok "T6 2 샘플 제출" || ng "T6 제출 $(wc -l < $T/qsub.log)"
cat $D/GIAB-publicData-Hiseq-100x/outcome/*/concat.jobid > $T/alive
run --dest $D --only Hiseq-100x --qsub 2>&1 | grep -c "아직 큐에" | xargs -I{} sh -c '[ {} = 2 ] && echo "PASS T6 큐에 있으면 재제출 안 함" || echo "FAIL T6 재제출함"'
: > $T/alive; run --dest $D --only Hiseq-100x --qsub >/dev/null 2>&1
[ "$(wc -l < $T/qsub.log)" = 4 ] && ok "T6 잡이 사라지면 다시 제출" || ng "T6 $(wc -l < $T/qsub.log)"
grep -q "h='(octopus" $D/GIAB-publicData-Hiseq-100x/outcome/GIAB-publicData-Hiseq-100x-HG006/concat.qsub.sh && ok "T6 qsub 스크립트에 호스트 제한" || ng "T6 호스트"

echo "== T7 --lanes 1: 큰 샘플부터, 둘째 잡이 첫째를 hold"; D=$T/d7; mkdir -p $D; : > $T/qsub.log; : > $T/alive
run --dest $D --only Hiseq-100x --qsub --lanes 1 >/dev/null 2>&1
first=$(sed -n 1p $T/qsub.log); second=$(sed -n 2p $T/qsub.log)
echo "$first" | grep -q "Hiseq-100x-HG007" && ok "T7 큰 샘플(HG007, 306쌍) 먼저" || ng "T7 순서: $first"
j1=$(cat $D/GIAB-publicData-Hiseq-100x/outcome/GIAB-publicData-Hiseq-100x-HG007/concat.jobid)
echo "$second" | grep -q -- "-hold_jid $j1 " && ok "T7 둘째가 -hold_jid $j1" || ng "T7 hold: $second"
: > $T/qsub.log; D=$T/d8; mkdir -p $D; run --dest $D --only Hiseq-100x --qsub >/dev/null 2>&1
grep -q hold_jid $T/qsub.log && ng "T7 lanes=0 인데 hold" || ok "T7 lanes=0 이면 hold 없음"
echo "== T8 --lanes 재실행: 살아 있는 잡이 줄을 차지"; D=$T/d9; mkdir -p $D; : > $T/qsub.log; : > $T/alive
run --dest $D --only Hiseq-100x --qsub --lanes 1 >/dev/null 2>&1
O=$D/GIAB-publicData-Hiseq-100x/outcome; j7=$(cat $O/GIAB-publicData-Hiseq-100x-HG007/concat.jobid); echo $j7 > $T/alive; rm $O/GIAB-publicData-Hiseq-100x-HG006/concat.jobid; : > $T/qsub.log
run --dest $D --only Hiseq-100x --qsub --lanes 1 >/dev/null 2>&1
grep -q -- "-hold_jid $j7 .*HG006" $T/qsub.log && ok "T8 새 잡이 살아 있는 잡($j7)을 hold" || ng "T8: $(cat $T/qsub.log)"
echo "== T9 concat.sh 덮어쓰기 가드"; D=$T/d10; mkdir -p $D; run --dest $D --only Hiseq-100x >/dev/null 2>&1
C=$D/GIAB-publicData-Hiseq-100x/outcome/GIAB-publicData-Hiseq-100x-HG006; m0=$(stat -c %Y $C/concat.sh); sleep 1
run --dest $D --only Hiseq-100x >/dev/null 2>&1; [ "$(stat -c %Y $C/concat.sh)" = "$m0" ] && ok "T9 내용 같으면 안 건드림" || ng "T9 같은 내용인데 다시 씀"
echo "# edited" >> $C/concat.sh; mkdir $C/.concat.lock; run --dest $D --only Hiseq-100x >/dev/null 2>&1
grep -q "# edited" $C/concat.sh && ok "T9 lock 중이면 그대로" || ng "T9 lock 중에 덮어씀"
rm -r $C/.concat.lock; run --dest $D --only Hiseq-100x >/dev/null 2>&1
grep -q "# edited" $C/concat.sh && ng "T9 lock 없고 내용 다른데 안 고침" || ok "T9 lock 없으면 새 내용으로"
echo "== T10 가장 큰 잡 제출이 실패했고 다음 둘이 살아 있을 때 --lanes 2 재시도"; D=$T/d11; mkdir -p $D; : > $T/qsub.log; : > $T/alive
run --dest $D --only Hiseq-100x --only BGISEQ500-NA12878 --qsub --lanes 2 >/dev/null 2>&1
O=$D; big=$(ls -d $O/*/outcome/*/ | while read d; do echo "$(du -sb $d | cut -f1) $d"; done | sort -rn | head -1 | cut -d' ' -f2)
rm -f $big/concat.jobid; for f in $(ls $O/*/outcome/*/concat.jobid); do cat $f >> $T/alive; done; : > $T/qsub.log
run --dest $D --only Hiseq-100x --only BGISEQ500-NA12878 --qsub --lanes 2 >/dev/null 2>&1
grep -q -- "-hold_jid" $T/qsub.log && ok "T10 재시도한 큰 잡도 hold를 받는다" || ng "T10 hold 없이 제출: $(cat $T/qsub.log)"
echo; echo "결과: PASS $pass / FAIL $fail (T6의 재제출 검사 1건은 위에 따로 찍힌다)"; [ "$fail" = 0 ]
