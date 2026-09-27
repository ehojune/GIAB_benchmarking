# GIAB 현황

2026-09-27 21:08 KST 갱신. **회사 기본 run 24샘플 종료, 회사·공개 비교 16건 완료.** [비교표](reports/2026-09-27-shortread-sixteen.md) · [완료 근거](reference/2026-09-27-reboot-status-evidence.json) · [제한 재시도](runs/2026-09-27-bounded-retries.md).

| 작업 | 현재 상태 | 다음 행동 |
|---|---|---|
| 업체 기본 run | gd1~4 모두 exit 0·DONE Success. CRAM·변이 파일·기본 QC 확인 | 정상 결과 보존 |
| VerifyBamID | 오류 11건 중 **9건 복구·반영**. 이번 gd4 HG002/HG004 두 건 반영, 정본 QC 22/24 확인 | 남은 2건과 공개 Illumina HG002 **156821–156823 1차 제출**. 이번 승인 이후 최대 2회, 성공 검증 후 QC 반영 |
| HG002/3/4 비교 | **16건 완료**: 4회사×3 + 공개 4. gd4 156815–156817 모두 exit 0·summary 검증 | 현재 표 마감. 공개 후속 결과가 준비되면 승인 범위 안에서 비교 |
| 공개 기본 run | **155526–155528, 156690 r**. 직전 20:46 점검에서 CPU·활성 Mark 로그 12개 증가 확인 | 현재 잡 유지, 종료·산출물·최소 QC 확인 |
| Illumina-250PE | 156786 exit 1·Error. Manta 3샘플과 HG002 Verify gap. HG003 링크 충돌은 계산 성공 확인 | Manta **156824–156826 1차 제출**. 같은 단계만 별도 폴더에서 최대 2회. 기존 정상 결과 보존 |
| 다운로드 | BioSkryb×UG100 **476/476, 5.22 TB 수령**. 크기 전부 일치, 제공 MD5 238개 일치·참조 없음 238개 | 카탈로그·Excel 반영 완료 유지 |
| PacBio·ONT / somatic | 기본 정리 완료. HG008 somatic **13쌍 QC·채점 완료**, 29잡 exit 0·QC 해시 불변·summary 28개 | 업체 롱리드 수령 대기. 범용 bioinfo 개발은 별도 |

원자료·정본 샘플표·성별·백업·정상 산출물을 보존한다. 비교 점수는 보고서, 자료 보유 상태는 카탈로그·Excel에 둔다. 이번 점검은 보유 자료 변화가 없어 Excel을 다시 쓰지 않았다.

재부팅 후 nbbcluster2/ehojune 접속 정상. Codex가 단독 총괄하며 **3시간마다 점검·보고**한다. 새 위임·중복 잡 없음. 기존 Claude 5세션은 현재 registry에 없고 저장 기록에 새 실행은 없다(실시간 idle 판정 아님). [범위](SCOPE.md) · [남은 일](backlog.md).
