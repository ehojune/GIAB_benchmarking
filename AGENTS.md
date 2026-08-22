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
