# NX4 KOR

투싼 NX4 한국 내비(260902) 전용 HMG-API 모드. 사용 안내는 `README.md`에 있습니다.

## 문서 위치

| 경로 | 내용 |
|---|---|
| `README.md` | 설치·상태 확인·삭제 안내, 저장소 구성, 만들기와 시험 |
| `docs/design.md` | 설계(모드 구성, 자동 설정, 상태 화면, 재부팅 요청)와 차에서 확인할 것 |
| `docs/emulator-test.md` | 에뮬레이터에서 상태 화면 앱 시험(SDK·AVD 준비, 시나리오, [지금 재부팅] 흐름, 이 시험이 보지 않는 것) |
| `docs/git-flow.md` | 브랜치 전략(Git Flow) 규칙, 흐름, 강제 장치 |
| `docs/open-issue.md` | 정하지 않은 것(OI-번호). 결정을 기다리는 일은 모두 여기 |
| `docs/release.md` | 태그로 도는 배포 워크플로(`.github/workflows/release.yml`), 배포 키 secret, `production` 환경, 키 백업, 유출 위험 |
| `wireless/README.md` | 합친 무선 모드(한국 차 빌드 2.4.5)의 출처, 공식 판과의 비교 |
| `usb/README.txt` | USB 설치기 안내 |
| `NOTICE.md` | 바탕 프로젝트와 라이선스 고지 |

- 설계·시험 문서는 `docs/`에 둡니다. 새로 만들면 위 표와 `README.md`의 "만들기와 시험" 표에 함께 적습니다.
- 동작을 바꾸면 같은 변경에서 해당 문서도 고칩니다.
- 정하지 않은 일(사용자의 결정을 기다리는 안, 지원할지 정하지 않은 판 등)은 `docs/open-issue.md`에만 적고, 다른 문서에서는 OI-번호로 가리킵니다. 정해지면 결정·날짜·PR을 적어 "닫힌 것"으로 옮깁니다(규칙은 그 문서 맨 위).
- 해야 할 것이 정해진 확인 목록(예: `docs/design.md` "차에서 확인할 것")은 정하지 않은 일이 아니므로 그 문서에 그대로 둡니다. 확인 결과로 무엇을 할지 정해야 할 때만 `open-issue.md`에 올립니다.

## 스킬

| 스킬 | 하는 일 |
|---|---|
| `pr-review-cycle` (`.claude/skills/pr-review-cycle/`) | Git Flow 규칙대로 커밋·푸시 → PR → 리뷰 서브에이전트 리뷰 → 수정·답글·재리뷰 반복 → merge commit 으로 합치기·태그 → 브랜치 정리 |

## 브랜치 (Git Flow, 반드시 지킴)

[`docs/git-flow.md`](docs/git-flow.md)의 규칙을 따릅니다. 특히:

- 파일을 고치기 전에 현재 브랜치를 확인합니다. `main`이나 `develop`이면 고치지 말고 먼저 알맞은 작업 브랜치(보통 `develop`에서 만든 `feature/<주제>`)로 옮깁니다. `develop`이 아직 없으면 사용자에게 알리고 어떻게 할지 묻습니다.
- `main`·`develop`에 직접 커밋·푸시하지 않습니다. PR의 `--base`는 `feature/` → `develop`, `release/`·`hotfix/` → `main`과 `develop`입니다.
- 판 번호(`mod/mod.json` `version`, `app/AndroidManifest.xml` `versionName`·`versionCode`)는 `release/`·`hotfix/`에서만 바꿉니다.
- 커밋·푸시·PR·태그는 사용자가 시킬 때만 합니다.

## 저장소 밖 경로

- Android SDK, 서명 키, HMG-API 소스 같은 PC 경로는 코드와 문서에 기본값으로 적지 않습니다.
- PC 스크립트는 `scripts/local-env.sh`(`nx4_env`, `nx4_need`)로 저장소 맨 위 `.env.local`(git 제외)에서 읽고, 값이 없으면 멈춥니다. 명령 앞에 준 값이 `.env.local`보다 앞섭니다.
- 새 경로 변수는 `.env.example`에 설명과 함께 더합니다.
- `tests/mod-test.sh`는 `.env.local`에서 `HMGAPI_SRC`만 읽고, 시험이 부르는 스크립트는 `.env.local`을 읽지 않게 합니다(`NX4_ENV_FILE=`).
