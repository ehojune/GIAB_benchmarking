# 2026-09-23 — phase3 입력 트리 전수 점검 + MGISEQ HG002 재생성 실패 진단

phase3 숏리드 세션 인수 직후 두 가지를 했다: (1) 파이프라인 입력 규약 준수 여부를 서버에서 직접
재확인, (2) STATUS.md에 "running"으로 남아 있던 MGISEQ HG002 재생성 잡(155525)의 실제 상태를
`qacct`로 확인하고 실패 원인을 좁혔다. 전부 hiware-cluster 스킬(HIWARE 터널, 읽기 전용 기본)로
nbb2에서 직접 실행했다. `docs/decisions.md` 2026-09-23 항목(들)의 결론이 여기 근거한다.

## 1. 입력 트리 명명 규약 감사

`/BiO/scratch/dyl/kbb/G000/GIAB-publicData-*/outcome/*/` 아래 각 샘플 디렉토리가
`<sample>_1.fastq.gz`/`<sample>_2.fastq.gz` 정확히 1개씩(파일 이름 전체가 그거여야 함 — mate
접미만 맞고 그 앞에 밑줄이 섞인 `sample_bad_1.fastq.gz` 같은 이름을 놓치지 않도록 접미 매치가
아니라 전체 이름 일치로 검사), mate 접미 외 밑줄 없음을 만족하는지 확인.

```bash
cd /BiO/scratch/dyl/kbb/G000
for d in GIAB-publicData-*/outcome/*/; do
  d="${d%/}"
  sample=$(basename "$d")
  ok=1
  case "$sample" in *_*) ok=0 ;; esac
  for mate in 1 2; do
    files=$(ls "$d"/*_${mate}.fastq.gz 2>/dev/null)
    n=$(echo -n "$files" | grep -c . || true)
    [ "$n" = "1" ] || ok=0
    [ "$n" = "1" ] && [ "$(basename "$files")" != "${sample}_${mate}.fastq.gz" ] && ok=0
  done
  extra=$(ls "$d" 2>/dev/null | grep -vE "^(concat\.sh|concat\.log|concat_R1\.list|concat_R2\.list|${sample}_1\.fastq\.gz|${sample}_2\.fastq\.gz)$" | tr '\n' ',')
  printf '%-75s ok=%s extra=[%s]\n' "$d" "$ok" "$extra"
done
```

**결과 (2026-09-23 16:20 KST 재실행, 전문):**

```
GIAB-publicData-BGISEQ500/outcome/GIAB-publicData-BGISEQ500-HG002           ok=1 extra=[]
GIAB-publicData-BGISEQ500/outcome/GIAB-publicData-BGISEQ500-HG003           ok=1 extra=[]
GIAB-publicData-BGISEQ500/outcome/GIAB-publicData-BGISEQ500-HG004           ok=1 extra=[]
GIAB-publicData-Element-AVITI/outcome/GIAB-publicData-Element-AVITI-HG002   ok=1 extra=[]
GIAB-publicData-Element-AVITI/outcome/GIAB-publicData-Element-AVITI-HG003   ok=1 extra=[]
GIAB-publicData-Element-AVITI/outcome/GIAB-publicData-Element-AVITI-HG004   ok=1 extra=[]
GIAB-publicData-Hiseq-300x/outcome/GIAB-publicData-Hiseq-300x-HG002         ok=1 extra=[]
GIAB-publicData-Hiseq-300x/outcome/GIAB-publicData-Hiseq-300x-HG003         ok=1 extra=[]
GIAB-publicData-Hiseq-300x/outcome/GIAB-publicData-Hiseq-300x-HG004         ok=1 extra=[]
GIAB-publicData-Hiseq-subsampled-30x/outcome/GIAB-publicData-Hiseq-subsampled-30x-HG002 ok=1 extra=[GIAB-publicData-Hiseq-subsampled-30x-HG002_canvas.CNV_filtered.vcf,GIAB-publicData-Hiseq-subsampled-30x-HG002.diploidSV.conInv_filtered.vcf,GIAB-publicData-Hiseq-subsampled-30x-HG002_v1.1.0.cram,GIAB-publicData-Hiseq-subsampled-30x-HG002_v1.1.0.cram.crai,GIAB-publicData-Hiseq-subsampled-30x-HG002_v1.1.0.g.vcf.gz,GIAB-publicData-Hiseq-subsampled-30x-HG002_v1.1.0.g.vcf.gz.tbi,]
GIAB-publicData-Hiseq-subsampled-30x/outcome/GIAB-publicData-Hiseq-subsampled-30x-HG003 ok=1 extra=[GIAB-publicData-Hiseq-subsampled-30x-HG003_canvas.CNV_filtered.vcf,GIAB-publicData-Hiseq-subsampled-30x-HG003.diploidSV.conInv_filtered.vcf,GIAB-publicData-Hiseq-subsampled-30x-HG003_v1.1.0.cram,GIAB-publicData-Hiseq-subsampled-30x-HG003_v1.1.0.cram.crai,GIAB-publicData-Hiseq-subsampled-30x-HG003_v1.1.0.g.vcf.gz,GIAB-publicData-Hiseq-subsampled-30x-HG003_v1.1.0.g.vcf.gz.tbi,]
GIAB-publicData-Hiseq-subsampled-30x/outcome/GIAB-publicData-Hiseq-subsampled-30x-HG004 ok=1 extra=[GIAB-publicData-Hiseq-subsampled-30x-HG004_canvas.CNV_filtered.vcf,GIAB-publicData-Hiseq-subsampled-30x-HG004.diploidSV.conInv_filtered.vcf,GIAB-publicData-Hiseq-subsampled-30x-HG004_v1.1.0.cram,GIAB-publicData-Hiseq-subsampled-30x-HG004_v1.1.0.cram.crai,GIAB-publicData-Hiseq-subsampled-30x-HG004_v1.1.0.g.vcf.gz,GIAB-publicData-Hiseq-subsampled-30x-HG004_v1.1.0.g.vcf.gz.tbi,]
GIAB-publicData-Illumina-250PE/outcome/GIAB-publicData-Illumina-250PE-HG002 ok=1 extra=[]
GIAB-publicData-Illumina-250PE/outcome/GIAB-publicData-Illumina-250PE-HG003 ok=1 extra=[]
GIAB-publicData-Illumina-250PE/outcome/GIAB-publicData-Illumina-250PE-HG004 ok=1 extra=[]
GIAB-publicData-MGISEQ2000-PCRfree/outcome/GIAB-publicData-MGISEQ2000-PCRfree-HG002 ok=1 extra=[]
GIAB-publicData-MGISEQ2000-PCRfree/outcome/GIAB-publicData-MGISEQ2000-PCRfree-HG003 ok=1 extra=[]
GIAB-publicData-MGISEQ2000-PCRfree/outcome/GIAB-publicData-MGISEQ2000-PCRfree-HG004 ok=1 extra=[]
GIAB-publicData-Novaseq6000-PCRfree-30x/outcome/GIAB-publicData-Novaseq6000-PCRfree-30x-HG002 ok=1 extra=[GIAB-publicData-Novaseq6000-PCRfree-30x-HG002_canvas.CNV_filtered.vcf,GIAB-publicData-Novaseq6000-PCRfree-30x-HG002.diploidSV.conInv_filtered.vcf,GIAB-publicData-Novaseq6000-PCRfree-30x-HG002_v1.1.0.cram,GIAB-publicData-Novaseq6000-PCRfree-30x-HG002_v1.1.0.cram.crai,GIAB-publicData-Novaseq6000-PCRfree-30x-HG002_v1.1.0.g.vcf.gz,GIAB-publicData-Novaseq6000-PCRfree-30x-HG002_v1.1.0.g.vcf.gz.tbi,]
GIAB-publicData-Novaseq6000-PCRfree-30x/outcome/GIAB-publicData-Novaseq6000-PCRfree-30x-HG003 ok=1 extra=[GIAB-publicData-Novaseq6000-PCRfree-30x-HG003_canvas.CNV_filtered.vcf,GIAB-publicData-Novaseq6000-PCRfree-30x-HG003.diploidSV.conInv_filtered.vcf,GIAB-publicData-Novaseq6000-PCRfree-30x-HG003_v1.1.0.cram,GIAB-publicData-Novaseq6000-PCRfree-30x-HG003_v1.1.0.cram.crai,GIAB-publicData-Novaseq6000-PCRfree-30x-HG003_v1.1.0.g.vcf.gz,GIAB-publicData-Novaseq6000-PCRfree-30x-HG003_v1.1.0.g.vcf.gz.tbi,]
GIAB-publicData-Novaseq6000-PCRfree-30x/outcome/GIAB-publicData-Novaseq6000-PCRfree-30x-HG004 ok=1 extra=[GIAB-publicData-Novaseq6000-PCRfree-30x-HG004_canvas.CNV_filtered.vcf,GIAB-publicData-Novaseq6000-PCRfree-30x-HG004.diploidSV.conInv_filtered.vcf,GIAB-publicData-Novaseq6000-PCRfree-30x-HG004_v1.1.0.cram,GIAB-publicData-Novaseq6000-PCRfree-30x-HG004_v1.1.0.cram.crai,GIAB-publicData-Novaseq6000-PCRfree-30x-HG004_v1.1.0.g.vcf.gz,GIAB-publicData-Novaseq6000-PCRfree-30x-HG004_v1.1.0.g.vcf.gz.tbi,]
GIAB-publicData-NovaseqX-30x/outcome/GIAB-publicData-NovaseqX-30x-HG002     ok=1 extra=[GIAB-publicData-NovaseqX-30x-HG002_canvas.CNV_filtered.vcf,GIAB-publicData-NovaseqX-30x-HG002.diploidSV.conInv_filtered.vcf,GIAB-publicData-NovaseqX-30x-HG002_v1.1.0.cram,GIAB-publicData-NovaseqX-30x-HG002_v1.1.0.cram.crai,GIAB-publicData-NovaseqX-30x-HG002_v1.1.0.g.vcf.gz,GIAB-publicData-NovaseqX-30x-HG002_v1.1.0.g.vcf.gz.tbi,]
```

**8개 세트 22개 샘플 디렉토리 전부 `ok=1`.** 세트별 샘플 수: BGISEQ500(3) ·
Element-AVITI(3) · Hiseq-300x(3) · Hiseq-subsampled-30x(3) · Illumina-250PE(3) ·
MGISEQ2000-PCRfree(3) · Novaseq6000-PCRfree-30x(3) · NovaseqX-30x(1, HG002만) = 22. 완료 세트
(Hiseq-subsampled-30x·Novaseq6000·NovaseqX)의 `extra` 는 그 세트가 낸 산출물(CRAM·gvcf·CNV vcf
등)이고 전부 같은 이름 규칙을 따른다. 나머지 5세트는 입력 fastq 2개 + concat 부산물뿐.

검사 스크립트는 Codex 리뷰로 두 번 고쳤다(사실 관계는 처음부터 끝까지 22/22 통과로 안 바뀜):
접미 매치만 보던 것(`grep -vE '_[12]\.fastq\.gz$'`)을 파일 이름 전체 일치로, 그다음 디렉토리
이름 자체에 밑줄이 섞인 경우(`sample_bad`)를 놓치던 것을 `case "$sample" in *_*)` 로 막았다.

옛 이름(밑줄) 잔존 확인:

```bash
cd /BiO/scratch/dyl/kbb/G000 && ls -d GIAB_publicData_* 2>/dev/null || echo "no legacy underscore-named dirs"
# → GIAB_publicData_Hiseq_subsampled_30x  (링크 6개뿐, 03_make_pipeline_dirs.py가 만든 정식 트리와 중복)
```

사용자 승인 후 `rm -rf`로 삭제(아래 3절).

## 2. MGISEQ HG002 재생성 잡(155525) — STATUS와 실제 상태 불일치

STATUS.md는 "running (09-22 07:53~)"으로 남아 있었다. `qacct`로 확인:

```
$ qacct -j 155525
jobname      mgi_HG002_rebuild
qsub_time    Mon Sep 21 15:28:12 2026
start_time   Tue Sep 22 07:53:59 2026
end_time     Tue Sep 22 15:59:55 2026
granted_pe   pe_slots
slots        10
failed       0
exit_status  1
maxvmem      21.081GB
category     -q octopus.q,shepherd.q -l h_vmem=60G,hostname=(octopus-2-10|octopus-2-11) -pe pe_slots 10
```

**8시간 6분 실행 후 exit 1로 이미 끝나 있었다.** `failed=0`이라 SGE가 강제 종료한 게 아니라
스크립트 자신이 에러를 감지하고 종료했다. `df -h /BiO`는 30% 사용(1.7P 여유)이라 디스크 문제는
아니다. **이 잡 자신의 OOM은 아니지만 노드 전체의 메모리 압박은 배제 못 한다** — `maxvmem
21.081GB`는 요청 60G에 크게 못 미치지만, nbb2의 `h_vmem`은 예약도 상한도 아니다(consumable=NO,
HARVEST.md "SGE h_vmem은 예약도 상한도 아닐 수 있다" 항목). 같은 노드(octopus-2-10)의 **다른
잡이** 물리 메모리를 눌러 커널 OOM killer가 bwa-mem2를 죽였을 가능성이 남아 있고, 그 경우 정확히
지금 본 증상(`bwa.stderr`가 에러 없이 중간에서 끊기고, samtools view가 이어서 파싱 에러)이
나온다. dmesg/노드 로그는 이 세션에서 접근하지 않았다 — 확인 전까지 OOM을 배제하지 않는다.

`repairs/mgi-hg002.IMeaDNit/view.stderr` (samtools view, `-bS -h` 로 bwa-mem2 SAM 스트림을 받는 쪽):

```
[W::sam_read1_sam] Parse error at line 948884480
samtools view: error reading file "-"
```

`repairs/mgi-hg002.IMeaDNit/bwa.stderr` 마지막 부분 — **에러 메시지 없이 그냥 멈춘다**:

```
[0000] Calling mem_process_seqs.., task: 1418
[0000] 1. Calling kt_for - worker_bwt
```
(이게 파일의 마지막 줄이다. task 1418의 완료 로그도, 에러도 없다 — 정상 종료·크래시 어느 쪽
로그도 안 남기고 파이프가 끊겼다는 뜻이라 bwa-mem2 프로세스 자체가 죽었을 가능성을 가리킨다.)

`rawcheck.log`/`trimmedcheck.log`는 raw·trimmed 양쪽 다 PASS — 입력 FASTQ 자체는 gzip
EOF/CRC·4줄 레코드·SEQ/QUAL 길이·mate 이름 전부 정상.

### 우연이 아닐 수 있다는 신호

2026-09-21 원본 파이프라인 실패(decisions.md 2026-09-21)는 SAM 948,868,188번째 줄에서
`SEQ and QUAL are of different length`로 죽었다(정렬 레코드 948,864,819개, 전체 리드
1,451,463,284개 중 약 65.4%). 이번 155525는 SAM 948,884,480번째 줄에서 죽었다.
**두 값의 차이는 16,292줄, 비율로 0.0017%다.** 스크립트도 다르고(원본 kbb 파이프라인 vs
복구 스크립트) 날짜도 다른 두 독립 실행이 스트림의 거의 같은 지점에서 깨졌다 — bwa-mem2의
청크 처리가 입력 순서·크기(`-K 100000000`)에 대해 결정적이라는 점과 맞물려, 무작위 손상보다
**그 부근의 특정 리드(또는 그 리드를 bwa-mem2가 처리하는 방식)에 재현 가능한 문제가 있을
가능성**을 가리킨다.

## 3. 조치

- `GIAB_publicData_Hiseq_subsampled_30x` 삭제(사용자 승인, 링크 6개뿐 확인 후):
  `rm -rf /BiO/scratch/dyl/kbb/G000/GIAB_publicData_Hiseq_subsampled_30x`
- MGISEQ HG002 재생성 재제출(사용자 승인 — "국통바빅 본 파이프라인 실행만" 금지, 복구
  스크립트 qsub는 에이전트가 해도 된다고 확인받음). 155525와 동일 자원(`qacct`의 `category`
  필드에서 그대로 가져옴):

```bash
cd /BiO/scratch/ehojune/GIAB_benchmark/repairs
qsub -N mgi_HG002_rebuild -q octopus.q,shepherd.q \
  -l h_vmem=60G,hostname="(octopus-2-10|octopus-2-11)" -pe pe_slots 10 \
  -j y -o /BiO/scratch/ehojune/GIAB_benchmark/repairs/log/ \
  -wd /BiO/scratch/ehojune/GIAB_benchmark/repairs \
  mgi_hg002_recheck.sh --rebuild
# → Your job 156584 ("mgi_HG002_rebuild") has been submitted
```

**재시도 자체를 재현성 검사로 쓴다.** 같은 자원·같은 청크 크기라 결정적 버그라면 156584도
비슷한 지점에서 죽을 것이다. 그러면 blind retry를 멈추고 리드를 직접 봐야 하는데, **SAM 줄
번호를 2로 나눠 FASTQ 페어 위치를 추정하면 안 된다** — bwa-mem2는 기본 설정에서도 secondary·
supplementary 정렬을 낼 수 있어 SAM 레코드 수가 입력 리드 수보다 많을 수 있다(같은 종류의
과다 계수가 `docs/reference/server-and-infra.md`의 idxstats 단계에도 있고 ≲0.4% 로 적혀 있는데,
714,205,076 페어 기준 0.4%면 ±280만 페어 — 애초에 제안했던 8만 페어 폭의 탐색 구간을 통째로
벗어난다). 대신 **끊기기 직전의 마지막 완전한 QNAME을 partial BAM/SAM 쪽에서 회수해서**, 그
QNAME 그대로 `R1/R2.trimmed.fastq.gz`에서 grep 하는 쪽이 안전하다 — 위치를 계산할 필요가
없어진다. 156584가 성공하면 두 실패는 우연히 가까운 자리였던 것으로 정리한다.

## 근거

- `qacct -j 155525` 전문, `stat -c '%y %n'`으로 확인한 `__DONE__`/`error_list.txt` mtime (재개
  전 옛 파일임을 확인 — 09-21 16:36 잡 시작보다 이전)
- `repairs/mgi-hg002.IMeaDNit/{view,bwa}.stderr`, `{raw,trimmed}check.log`
- 위 입력 트리 감사 스크립트 원문과 전체 출력(터미널 스크롤백, 파일로 남기지 않음 — 재현 명령은
  1절에 그대로 있다)
