#!/usr/bin/env python3
"""FASTQ.gz 한 개를 연속 구간 K개로 나눠 한 레코드씩 돌아가며 내보낸다(리드는 하나도 버리지 않는다).

2026-09-24 MGISEQ HG002: bwa-mem2 2.2.1이 L04 안 한 구역에서 `num_smem < *wsize_mem` 단언으로 죽는다. SMEM 버퍼가 배치의 총 염기 수로
잡히는데 반복이 심한 리드가 몰린 배치는 염기 수보다 SMEM이 많아진다(master도 같은 검사로 멈춘다). 입력 순서만 바꿔 그 구역을
K개 배치로 흩으면 배치당 밀도가 1/K이 된다. 정렬 뒤 결과에 리드 순서는 상관없다.

    python interleave_shards.py <in.fastq.gz> <레코드 수> <K> | pigz -p 8 > out.fastq.gz

R1과 R2에 같은 레코드 수·K를 주면 같은 순서가 나와 짝이 유지된다. 레코드 수는 fastp before_filtering total_reads / 2 (mate 하나 기준).
구간 j의 시작까지는 pigz -dc | tail 로 건너뛴다(구간마다 압축 해제 프로세스 하나). 끝에서 레코드 수가 안 맞으면 exit 1.
"""
import subprocess, sys

src, n, k = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
pigz = sys.argv[4] if len(sys.argv) > 4 else "pigz"
size = -(-n // k)   # 올림
starts = [j * size for j in range(k)]
procs = []
for j, s in enumerate(starts):
    # tail -n +L 은 L번째 줄부터 — 레코드 s(0-based)는 4*s+1번째 줄
    cmd = f"{pigz} -dc '{src}' | tail -n +{4 * s + 1}"
    procs.append(subprocess.Popen(["bash", "-c", cmd], stdout=subprocess.PIPE, bufsize=1 << 20))
out = sys.stdout.buffer
left = [min(size, n - s) for s in starts]   # 구간마다 내보낼 레코드 수
done = 0
while any(left):
    for j in range(k):
        if not left[j]:
            continue
        rec = [procs[j].stdout.readline() for _ in range(4)]
        if not rec[3] or not rec[0].startswith(b"@") or not rec[2].startswith(b"+"):
            sys.exit(f"ERROR: 구간 {j}의 {size - left[j]}번째 레코드가 깨졌거나 모자라다")
        out.write(b"".join(rec)); left[j] -= 1; done += 1
for p in procs:
    p.stdout.close(); p.kill(); p.wait()
out.flush()
if done != n:
    sys.exit(f"ERROR: 내보낸 레코드 {done} != {n}")
sys.stderr.write(f"interleave_shards: {src} 레코드 {done}, K={k}, 구간 크기 {size}\n")
