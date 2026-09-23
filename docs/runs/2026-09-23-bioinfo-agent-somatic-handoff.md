# 2026-09-23 — bioinfo-agent 위임: PacBio somatic 경로

#9(HG008-T somatic 평가) 방법 B(somatic caller 추가)를 bioinfo-agent 쪽에서 만들기로 했다
(사용자 결정 2026-09-22, 조건: 다른 데이터와 같은 처리도 그대로 하고, repo 정합성을 먼저 맞출 것).
아래 블록을 bioinfo-agent 세션(`D:\bioinfo-agent`)에 그대로 붙인다. 이 세션(GIAB PacBio)이 받는 것은
bioinfo-agent 커밋 해시 하나이고, GIAB 쪽 재-vendor 와 채점 스크립트는 이 세션이 한다.

---

```text
TASK: pipelines/pacbio-hifi-wgs 에 tumor-normal somatic 경로를 추가한다. 먼저 GIAB_benchmarking 에
vendor 된 사본과 diff 0 으로 맞추고(0단계), 그 위에 somatic 을 얹는다(1단계). GIAB_benchmarking 은
네가 만든 커밋을 고정(pin)해서 다시 vendor 한다 — submodule·원격 참조는 안 쓴다(서버 계산 노드에
네트워크가 없다).

담당·보안: 이 리포는 public 이다. 사이트 고유 정보(/BiO/scratch 경로, 노드 이름, 사용자명, 큐 이름)를
커밋하지 않는다. SGE·KOBIC 설정은 GIAB 쪽 phase1_pacbio_hifi/conf/kobic.config 에 있고 거기 남는다.
GIAB_benchmarking 리포는 건드리지 않는다 — 커밋 해시만 보고한다.

입력:
- 이 리포: D:\bioinfo-agent\pipelines\pacbio-hifi-wgs (HEAD 쪽 최신 변경 54313cb, 2026-08-21)
- vendor 사본: C:\Users\admin\Desktop\GIAB_benchmarking\phase1_pacbio_hifi\pipeline\pacbio-hifi-wgs
  (기준 48ec4638 + run_label 3곳 — 같은 폴더 위 VENDORED.md 에 목록이 있다)
  이 경로를 못 읽으면(다른 Windows 계정) github.com/ehojune/GIAB_benchmarking main 의 같은 경로.
- 사이트 설정 참고(읽기만): GIAB_benchmarking\phase1_pacbio_hifi\conf\kobic.config, env.sh

0단계 — 정합성 (somatic 전에 끝낸다)
- 두 사본의 차이는 한 방향씩 하나다.
  GIAB 에만 있음: run_label (여러 런이 --outdir 하나를 같이 쓸 때 pipeline_info·multiqc 충돌 방지).
  bioinfo-agent 에만 있음: 48ec4638 이후 5커밋 — CLR 진입(clr_subreads, CLR_WARNING),
  .bai basename 강제, preset 별 pbmm2 인덱스, 문서 2건.
- run_label 은 사이트 고유가 아니라 일반 기능이다. 기본값('run')에서 기존 산출 경로가 바뀌지 않게
  bioinfo-agent 에 넣는다.
- 완료조건: GIAB 사본을 네 커밋으로 교체했다고 가정하고 `diff -r` 하면 차이가 0 이어야 한다
  (VENDORED.md 는 GIAB 쪽 파일이라 제외).

1단계 — somatic (SNV/INDEL 먼저, SV 는 그 다음)
- 진입: 이미 GRCh38 로 정렬된 tumor/normal BAM 쌍. 재정렬하지 않는다 — GIAB 쪽에 47런 BAM 이 있다.
  samplesheet 에 쌍을 표현하는 방식은 네가 정하되, 기존 4진입(+CLR)과 섞여도 검증이 깨지지 않게.
- caller: DeepSomatic (PacBio 모델). **GPU 없음이 전제다** — 서버에 GPU 가 없다(qhost -F gpu 무응답).
  CPU 경로로 짠다. 판·모델명(tumor-normal / tumor-only PacBio 모델 유무 포함)은 공식 문서로 확인하고
  추측하지 않는다.
- 컨테이너는 nextflow.config 에 `container_<이름> = '<uri>'` 꼴로 둔다. GIAB 의 사전 다운로드 스크립트가
  이 패턴을 grep 해서 로그인 노드에서 미리 받는다 — 다른 꼴이면 계산 노드에서 pull 하다 죽는다.
  모델 가중치가 이미지 밖에 있으면 같은 방식으로 미리 받을 수 있게 경로 param 을 둔다.
- 자원: GIAB 는 SGE 잡 하나 안에서 local executor 로 돈다(노드 64코어, 251 GB 또는 1 TB).
  기존 process 들이 쓰는 자원 상한 방식을 그대로 따른다.
- SV(Severus 등)는 SNV/INDEL 이 끝난 뒤 별도 PR. 필요한 입력(haplotag BAM, phased VCF)이 기존 산출에
  있는지 먼저 확인한다.
- 테스트: 로컬(WSL2+Docker)에서 전장은 안 돌린다. GIAB 공개 HG008 정렬 BAM 을 samtools 로 한 구간만
  (예: chr22 수 Mb) 받아 tumor/normal 쌍을 만들고 1회 통과시킨다. -stub 통과도 함께.
  기록은 docs/examples/<날짜>-.../ 에 이 리포 관례대로.
- 시간 추정을 남긴다: 테스트 구간의 wall·CPU 를 전장·심도(tumor 48~60X, normal ~30X)로 환산한
  값. **쌍 11개 전부를 CPU 로 돌리는 데 2주를 넘기면** 그 사실을 보고한다(사용자가 외부 H100
  서버를 따로 요청해야 하는 조건이다).

GIAB 쪽 사실 (설계에 쓸 것, 이 세션이 서버에서 확인함)
- 쓸 수 있는 쌍:
  HG008-T.BCM_Revio_20240313   ↔ HG008-N-D.BCM_Revio_20240313   (이름상 같은 센터·같은 날짜 — 1순위)
  HG008-T.PacBio_Revio_20240125 ↔ HG008-N-P.PacBio_Revio_20240125
  NIST HG008T-p100(bulk, passage 100) + 클론 8개(2D6·2E6·3E4·SC6·SC9·SC14·SC24·SC28)
    — 정상 짝이 없다. 같은 BCM Revio 인 HG008-N-D 를 빌려 쓴다.
- truth: NIST HG008-T somatic smvar DraftBenchmark V0.3-20260425. 권장 VCF 는
  `*_tumorvariants.vcf.gz`, BED 는 `*_all.bed` 또는 `*_nogermlineinterference.bed`(BED 는 같이 온 zip
  안에 있다). README 권장 비교 도구는 aardvark, rtg vcfeval·hap.py 도 시험됨. VAF 5~10% 미만은
  걸러서 비교하라고 한다. SV 는 stvar-CNV V0.5-20260318.
- truth 는 **0823p23 배치 bulk 의 truncal 변이만** 담는다. 그래서 클론·p100 은 truncal recall 만
  해석할 수 있고 precision 은 못 한다(클론 고유 변이·장기 계대 변이가 FP 로 잡힌다). 채점은 GIAB 쪽
  몫이지만, caller 출력에 VAF 가 남아야 이 구분을 할 수 있다.

상한: 0단계 + 1단계(SNV/INDEL)까지. SV 는 착수만 하고 PR 을 나눈다. 전장 실행 금지.

산출(보고 5줄): 결론 / 바뀐 것(PR·커밋 해시) / 실행한 것(테스트 명령) / 미해결 / 근거(경로).
GIAB PacBio 세션이 받을 것은 "vendor 할 커밋 해시 + 새 samplesheet 꼴 + 컨테이너 URI 목록 +
시간 추정" 넷이다.
```

---

## 받은 뒤 GIAB 쪽에서 할 일 (PacBio 세션)

1. `phase1_pacbio_hifi/pipeline/` 재-vendor, `VENDORED.md` 커밋 해시 갱신. 완료된 47런은 다시 돌리지
   않는다(`-resume` 캐시가 바뀌어도 산출물은 그대로다).
2. `01_prepare_login_node.sh` 로 새 컨테이너 사전 다운로드.
3. 쌍 표 + 제출 스크립트, `62_benchmark_somatic.sh`(가칭) — truth 경로·VAF 필터·BED 선택.
