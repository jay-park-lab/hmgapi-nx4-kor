# NX4 KOR

투싼 NX4 한국 내비(260902) 전용 HMG-API 모드. 사용 안내는 `README.md`에 있습니다.

## 문서 위치

| 경로 | 내용 |
|---|---|
| `README.md` | 설치·상태 확인·삭제 안내, 저장소 구성, 만들기와 시험 |
| `docs/design.md` | 설계(모드 구성, 자동 설정, 상태 화면, 재부팅 요청)와 차에서 확인할 것 |
| `docs/troubleshooting.md` | 차에서 설치하다 문제가 생길 때(설치기·상태 화면 문구별 할 일, 부팅 보호, 되돌리기, 남길 기록) |
| `docs/emulator-test.md` | 에뮬레이터에서 상태 화면 앱 시험(SDK·AVD 준비, 시나리오, [지금 재부팅] 흐름, 이 시험이 보지 않는 것) |
| `docs/git-flow.md` | 브랜치 전략(Git Flow) 규칙, 흐름(작업마다 워크트리), 강제 장치 |
| GitHub 이슈(`gh issue list`) | 정하지 않은 것(라벨 `결정 필요`), 차에서 확인할 일(`차 확인`), 릴리스 일(`릴리스`). 결정을 기다리는 일과 이후 할 일은 모두 여기 |
| `docs/release.md` | 태그로 도는 배포 워크플로(`.github/workflows/release.yml`), 배포 키 secret, `production` 환경, 키 백업, 유출 위험 |
| `wireless/README.md` | 합친 무선 모드(한국 차 빌드 2.4.5)의 출처, 공식 판과의 비교 |
| `usb/README.txt` | USB 설치기 안내 |
| `NOTICE.md` | 바탕 프로젝트와 라이선스 고지 |

- 설계·시험 문서는 `docs/`에 둡니다. 새로 만들면 위 표와 `README.md`의 "만들기와 시험" 표에 함께 적습니다.
- 동작을 바꾸면 같은 변경에서 해당 문서도 고칩니다.
- 정하지 않은 일(사용자의 결정을 기다리는 안, 지원할지 정하지 않은 판 등)과 이후 할 일은 GitHub 이슈로 관리합니다(`gh issue create --label "결정 필요"` 등). 저장소 문서에는 따로 목록을 두지 않고 이슈 링크(`[#번호](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/번호)`)로 가리킵니다. 이슈에는 지금 상태, 정할 것, 아는 선택지, 근거(문서·코드·PR)를 적습니다. 정해지면 결정·날짜·반영한 PR을 이슈에 적고 닫습니다. 정하지 않기로 하면 그 이유를 적고 닫습니다. 예전 `docs/open-issue.md`의 OI-1~10은 #13~#22로 옮겼습니다.
- 해야 할 것이 정해진 확인 목록(예: `docs/design.md` "차에서 확인할 것")은 그 문서에 그대로 둡니다. 확인 결과는 `차 확인` 이슈(#23)에 적고, 결과로 무엇을 할지 정해야 하면 `결정 필요` 이슈를 엽니다.

## 스킬

| 스킬 | 하는 일 |
|---|---|
| `pr-review-cycle` (`.claude/skills/pr-review-cycle/`) | Git Flow 규칙대로 커밋·푸시 → PR → 리뷰 서브에이전트 리뷰 → 수정·답글·재리뷰 반복 → merge commit 으로 합치기·태그 → 브랜치 정리 |

## 브랜치 (Git Flow, 반드시 지킴)

[`docs/git-flow.md`](docs/git-flow.md)의 규칙을 따릅니다. 특히:

- **작업은 워크트리를 따로 만들어 시작합니다**([`docs/git-flow.md`](docs/git-flow.md) 규칙 11, "워크트리").
  - 파일을 고치는 일을 시작할 때 메인 체크아웃에서 브랜치를 바꾸지 않습니다.
  - `git fetch origin`, `git worktree add --no-track -b feature/<주제> .claude/worktrees/<주제> origin/develop` 순서로 워크트리를 만듭니다. 그다음 `EnterWorktree`의 `path`로 들어가 그 안에서 고칩니다. `EnterWorktree`의 `name`으로 만들지 않습니다(`main`에서 규칙에 맞지 않는 브랜치를 만듦).
  - 메인 체크아웃은 `develop`에 두고 고치지 않습니다. 읽기만 하는 일은 메인 체크아웃에서 해도 됩니다.
  - 메인 체크아웃에 내가 하지 않은 커밋하지 않은 변경이 있으면 다른 작업의 것이니 건드리지 않습니다.
  - 이미 있는 브랜치(열린 PR의 리뷰 반영 등)를 고칠 때도 메인 체크아웃에서 `git switch` 하지 않고 그 브랜치의 워크트리에서 고칩니다. 없으면 만듭니다. 그 워크트리가 내가 만들었거나 지금 쓰던 것이 아니면 다른 세션이 쓰고 있을 수 있으니 들어가기 전에 사용자에게 묻습니다(`docs/git-flow.md` "워크트리").
  - 데스크톱 앱이 처음부터 워크트리로 연 세션이면 그 안에서 `git fetch origin`, `git switch --no-track -c feature/<주제> origin/develop` 순서로 작업 브랜치를 만듭니다.
- `main`·`develop`에 직접 커밋·푸시하지 않습니다. PR의 `--base`는 `feature/` → `develop`, `release/`·`hotfix/` → `main`과 `develop`입니다.
- 판 번호(`mod/mod.json` `version`, `app/AndroidManifest.xml` `versionName`·`versionCode`)는 `release/`·`hotfix/`에서만 바꿉니다.
- 커밋·푸시·PR·태그는 사용자가 시킬 때만 합니다.
- 로컬 `develop`·`main`·`release/*`를 `git fetch origin <브랜치>:<브랜치>`로 옮기지 않습니다(다른 트리에 열린 브랜치면 그 트리가 어긋남). 메인 체크아웃의 `develop`은 메인 체크아웃에서 `git pull --ff-only`로 맞춥니다.

## 저장소 밖 경로

- Android SDK, 서명 키, HMG-API 소스 같은 PC 경로는 코드와 문서에 기본값으로 적지 않습니다.
- PC 스크립트는 `scripts/local-env.sh`(`nx4_env`, `nx4_need`)로 저장소 맨 위 `.env.local`(git 제외)에서 읽고, 값이 없으면 멈춥니다. 명령 앞에 준 값이 `.env.local`보다 앞섭니다.
- 새 경로 변수는 `.env.example`에 설명과 함께 더합니다.
- 워크트리에는 `.env.local`이 없습니다. 메인 체크아웃의 것을 명령 앞에 `NX4_ENV_FILE=<메인 체크아웃>/.env.local`로 가리킵니다. 주지 않으면 빌드 스크립트는 멈추고 `tests/mod-test.sh`는 빌드·HMG-API 엔진 시험을 건너뜁니다.
- `tests/mod-test.sh`는 `.env.local`에서 `HMGAPI_SRC`만 읽고, 시험이 부르는 스크립트는 `.env.local`을 읽지 않게 합니다(`NX4_ENV_FILE=`).
