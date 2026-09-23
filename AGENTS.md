# Project agent contract

이 repo는 [Yuan](https://github.com/ehojune/Yuan)의 templates/project에서 찍어낸 프로젝트다.
Yuan의 AGENTS.md가 상위 규약이다.

## 시작할 때 (Retrieve)

- Yuan `JOURNAL.md`에서 비슷한 작업을 한 적 있는지 먼저 본다. 있으면 그 저장소부터 연다.
- 그다음 `catalog/assets.yaml`에서 쓸 자산을 찾는다. 새로 짜는 건 그 뒤다.
- 사용한 자산은 `yuan.lock.yaml`에 pin한다 (Yuan 커밋 + asset id).

## 작업 중

- 판단과 이유는 `docs/decisions.md`에 그때그때 적는다. 한 결정에 몇 줄이면 충분하다.
- 재사용 가치가 보이는 코드나 교훈은 `HARVEST.md`에 즉시 한 줄 적립한다. 나중에 발굴하지 않는다.
- 실행 기록(plan/cmd/handoff)은 `docs/runs/`에 남긴다.
- 굵직한 진행·전환은 README 끝 `## Journal`에 날짜 + 한 줄로 남긴다. 세션이 끝나기 전에.
- 템플릿 구조에서 벗어나면 이유를 decisions.md에 한 줄 남긴다.

## 끝날 때 (Harvest)

- HARVEST.md를 심사해 Yuan에 PR을 올린다. 자산과 catalog 항목은 같은 커밋으로.
- Yuan `JOURNAL.md`에 이 프로젝트 항목이 없으면 추가한다 — 저장소·커밋·결론·다시 할 때, 짧게.
- 교훈 분류: 누구에게나 유용한 도메인 교훈 → bioinfo-agent(공개), 개인적·사적인 것 → Yuan,
  이 기계에서만 참인 사실 → host.env/sync.md.

## 여러 에이전트가 동시에 붙을 때

2026-09-22 기준 세 세션이 같은 repo를 동시에 고치고 있다(PacBio / ONT / 다운로드).
그날 실제로 STATUS.md 충돌이 났고, ONT 세션이 phase1 스크립트를 고치고 있었다.

**시작할 때 한 번 본다.** 남이 지금 무엇을 건드리는지 모르면 같은 파일을 두 번 고친다.

```bash
git fetch --prune origin && gh pr list --state open
git branch -r --sort=-committerdate | head -10     # PR 없는 작업 브랜치도 있다
```

### 소유 구분

| 경로 | 주인 |
|---|---|
| `phase0_download/`, `catalog/`, `manifests/` | 다운로드 세션 |
| `phase1_pacbio_hifi/` | PacBio 세션 |
| `phase2_ont/` | ONT 세션 |
| `phase3_shortread_wgs/` | 숏리드 세션 |
| `docs/`, `README.md`, `HARVEST.md`, `AGENTS.md` | **공용** |

**주인이 아닌 경로를 고쳐야 하면 PR 본문에 그 사실과 이유를 쓴다.** 금지가 아니다 —
phase1·phase2 스크립트는 일부러 같은 모양이라 한쪽 교훈이 다른 쪽에 바로 적용되는 일이 잦다.
다만 상대가 모르고 지나가면 다음 PR에서 충돌하거나 조용히 덮어쓴다.

### 충돌이 잦은 파일

| 파일 | 규칙 |
|---|---|
| `docs/STATUS.md` | `## 이력`은 **맨 위에 한 줄 추가만**. 작업 흐름 표는 **자기 행만** 고친다. 표 구조를 바꿔야 하면 그 PR 하나만 그것을 한다 |
| `docs/decisions.md` | **append only.** 남의 항목을 고치지 않는다. 남의 판단을 뒤집을 때는 새 항목에 "정정" 으로 쓴다 |
| `HARVEST.md` | 표 끝에 행 추가. 남의 행을 고칠 때는 그 사실을 PR 본문에 쓴다 |
| `README.md ## Journal` | 맨 위에 한 줄 추가만 |
| `phase{1,2}/env.local.sh.example` | 두 phase가 거의 같은 문구를 공유한다. **한쪽만 고치면 갈라진다 — 양쪽을 같이 고친다** |
| `phase{1,2}/scripts/35_review_qc.py` | 위와 같다 |

### PR 전에

```bash
git fetch -q origin && git merge-tree $(git merge-base origin/main HEAD) origin/main HEAD | grep -c 'changed in both'
```

0이 아니면 `git merge origin/main` 으로 먼저 풀고 올린다. 리뷰어(사람·봇)가 충돌부터 보게 하지 않는다.

### 남의 실측을 덮어쓰기 전에

`env.sh` 주석의 실측값(maxvmem, wall, 슬롯 계산)은 **다른 세션이 실제로 잰 것**이다.
내 실측이 다르면 지우지 말고 **둘 다 남기고 조건을 밝힌다** — 플랫폼·데이터셋·스레드가 다르면
값이 달라지는 게 정상이고, 하나로 뭉개면 다음 사람이 잘못된 용량 계산을 한다.
실제로 2026-09-22 에 "ONT 67~73 GB vs HiFi 91~136 GB, **데이터셋**이 두 배를 가른다" 고 적었다.
ONT 세션이 같은 날 재 보니 그 67~73 은 `BENCH_SV_THREADS` 가 생기기 전 truvari **기본 4스레드**
값이었고, `-t 8` 로 맞춰 돌린 R10 은 133.5 GB 로 HiFi 대역 안이었다. **데이터셋 차이가 아니라
스레드 설정 차이였다.** 실측을 비교할 때는 값만 보지 말고 **어떤 설정에서 잰 것인지**를 같이 적을 것.
