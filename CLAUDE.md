# NX4 KOR

투싼 NX4 한국 내비(260902) 전용 HMG-API 모드. 사용 안내는 `README.md`에 있습니다.

- 앱 이름: 지금까지 '상태 화면 앱'이라 부르던 `io.github.jayparklab.nx4kor`는 '관리 앱'이라고 부릅니다(2026-11-25 사용자 결정. 상태만 보는 앱이 아니라 [지금 재부팅], 진단 기록 확인 창, 앞으로 동글 켜기 등도 하기 때문).
- **구조(2026-11-23 결정. 2.1.0은 2026-11-25 태그만 있고 릴리스 묶음 없음, 2.1.1 정식 2026-11-26):** "HMG-API + 공식 무선 모드(고치지 않음) + 이 저장소의 NX4 추가분(USB 설치기, 관리 앱, 한국 카플레이 길안내 훅, 2.2.0에서 동글)"입니다.
  - **다른 프로젝트(공식 무선 모드, HMG-API, Korea Projection)에 기여하는 길은 선택지에 넣지 않습니다**(2026-11-25 사용자 결정). 고침과 한국 맞춤은 이 저장소의 모드에 넣습니다. 공식 모드와 같은 훅 지점은 `change`·`observe`로만 겁니다(`replace`로 겹치면 공식 모드가 꺼짐, #17).
  - 한국 카플레이 길안내([#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67)): KP·HMG-Seogaemo의 보정을 `hooks/`로 가져와 공식 모드 옆 DiPO에서 돌립니다(`docs/design.md` "한국 카플레이 길안내").
  - 근거와 역할 표는 [#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38)과 `docs/design.md` "2.1.0 구조"에 있습니다. 2.1.0의 할 일 [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45)와 첫 차 확인 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)은 닫았습니다.
  - 다음 판 2.2.0(마일스톤 2.2.0)은 USB Wi-Fi 동글([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48))과 관리 앱 동글 켜기([#60](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/60))입니다. 우리 모드에 넣을 다른 한국 맞춤과 남은 차 확인은 [#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64)에 있습니다.
  - 모드(`mod/`)와 관리 앱 판정은 2.1.0 구조로 바꿨습니다(한국 포크 무선 모드 2.4.5와 `svc/hotspot.sh`를 빼고 관리 앱·`launch` 서비스·`svc/lib.sh`만 남김). USB 설치기(`usb/troubleShooter`, `scripts/build.sh`)도 2.1.0 구조로 바꿨습니다(HMG-API 쪽 일, 공식 무선 모드 설치, 옛 2.0.x 되돌리기, map·적용, PR #52). 2.0.x는 정식 없이 끝냅니다.
  - 2.0.x의 마지막 `release/2.0.4`(`v2.0.4-beta.1`)는 `main`에 합치지 않고 지웠습니다.
- 관리 앱은 지금 UI를 그대로 둡니다(사용자 결정).

## 문서 위치

| 경로 | 내용 |
|---|---|
| `README.md` | 설치·상태 확인·삭제 안내, 저장소 구성, 만들기와 시험 |
| `docs/design.md` | 2.1.0 구조, 모드 구성, 관리 앱(판정 차례·재부팅 요청), 설치기, 다른 패키지·모드와 함께 쓸 때, 차에서 확인할 것 |
| `docs/flow.md` | 2.1.0 처리 흐름 그림(mermaid): 누가 무엇을 하나, USB 설치·업데이트, 재부팅 뒤 무선 연결, 관리 앱, 지우기. `design.md`의 요약 |
| `docs/troubleshooting.md` | 차에서 설치하다 문제가 생길 때(설치기·관리 앱 문구별 할 일, 부팅 보호, 되돌리기, 남길 기록) |
| `docs/emulator-test.md` | 에뮬레이터에서 관리 앱 테스트(SDK·AVD 준비, 시나리오, [지금 재부팅] 흐름, 이 테스트가 보지 않는 것) |
| `docs/git-flow.md` | 브랜치 전략(Git Flow) 규칙, 흐름(작업마다 워크트리), 강제 장치 |
| `drivers/README.md` | USB Wi-Fi 동글 드라이버(#48): 순정 HAL 자리(`bcmdhd`)에 맞추는 방법, 보호 패치, 커널 준비(kernel.org 3.18.24 뼈대 + 현대모비스 GPL 공개 내비 커널 소스 + 차 설정에 맞춘 defconfig), 커널 소스 자산(릴리스 `src-mobis-avnt5w-r9`, `--src-asset`), Docker 빌드(`scripts/build-driver.sh`, CI `.github/workflows/drivers.yml`), 바깥 자료와 출처·라이선스(GPL-2.0). 차에 넣을 `.ko`는 CI(리눅스 x86) 것만(맥 에뮬레이션 빌드는 확인용) |
| GitHub 이슈(`gh issue list`) | 정하지 않은 것(라벨 `결정 필요`), 차에서 확인할 일(`차 확인`), 릴리스 일(`릴리스`). 결정을 기다리는 일과 이후 할 일은 모두 여기 |
| `docs/release.md` | 태그로 도는 배포 워크플로(`.github/workflows/release.yml`), 배포 키 secret, `production` 환경, 키 백업, 유출 위험 |
| `usb/README.txt` | USB 설치기 안내 |
| `NOTICE.md` | 바탕 프로젝트와 라이선스 고지 |

- 설계·시험 문서는 `docs/`에 둡니다. 새로 만들면 위 표와 `README.md`의 "만들기와 시험" 표에 함께 적습니다.
- 동작을 바꾸면 같은 변경에서 해당 문서도 고칩니다.
- 정하지 않은 일(사용자의 결정을 기다리는 안, 지원할지 정하지 않은 판 등)과 이후 할 일은 GitHub 이슈로 관리합니다(`gh issue create --label "결정 필요"` 등). 저장소 문서에는 따로 목록을 두지 않고 이슈 링크(`[#번호](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/번호)`)로 가리킵니다. 이슈에는 지금 상태, 정할 것, 아는 선택지, 근거(문서·코드·PR)를 적습니다. 정해지면 결정·날짜·반영한 PR을 이슈에 적고 닫습니다. 정하지 않기로 하면 그 이유를 적고 닫습니다. 예전 `docs/open-issue.md`의 OI-1~10은 #13~#22로 옮겼습니다.
- 해야 할 것이 정해진 확인 목록(예: `docs/design.md` "차에서 확인할 것")은 그 문서에 그대로 둡니다. 확인 결과는 그 항목을 맡은 이슈(무선·동글은 #48, 그 밖은 #64, 새 항목이면 `차 확인` 라벨로 새 이슈)에 적고, 결과로 무엇을 할지 정해야 하면 `결정 필요` 이슈를 엽니다.

## 스킬

| 스킬 | 하는 일 |
|---|---|
| `pr-review-cycle` (`.claude/skills/pr-review-cycle/`) | Git Flow 규칙대로 커밋·푸시 → PR → 리뷰 서브에이전트 리뷰 → 수정·답글·재리뷰 반복 → merge commit 으로 합치기·태그 → 브랜치 정리 |

## 브랜치 (Git Flow, 반드시 지킴)

[`docs/git-flow.md`](docs/git-flow.md)의 규칙을 따릅니다. 특히:

- **작업은 워크트리를 따로 만들어 시작합니다**([`docs/git-flow.md`](docs/git-flow.md) 규칙 11, "워크트리").
  - 파일을 고치는 일을 시작할 때 메인 체크아웃에서 브랜치를 바꾸지 않습니다.
  - `git fetch origin`, `git worktree add --no-track -b feature/<주제> .claude/worktrees/<주제> origin/develop` 순서로 워크트리를 만듭니다. 그다음 `EnterWorktree`의 `path`로 들어가 그 안에서 고칩니다. `EnterWorktree`의 `name`으로 만들지 않습니다(`main`에서 규칙에 맞지 않는 브랜치를 만듦).
  - **새 작업 브랜치(와 그 워크트리)는 늘 `origin/develop`에서 시작합니다**(`feature/`·`release/` 모두, [`docs/git-flow.md`](docs/git-flow.md) 규칙 12).
    - 새 작업의 예외는 배포한 `main`을 고치는 `hotfix/`(`origin/main`)뿐입니다. `main`의 README 안내만 넣는 `hotfix/main-readme`도 `origin/main`에서 시작합니다(판 번호·태그 없이 `main`에만 합침, 규칙 13).
    - 이미 있는 브랜치를 이어서 고칠 때(열린 PR의 리뷰 반영 등)는 새 작업이 아니므로 그 브랜치에서 워크트리를 엽니다(아래 줄).
    - `release/<판>`에서 시작하는 `feature/`는 만들지 않습니다. 고침은 develop에 합치고, 그 고침이 든 묶음이 필요하면 `release/<판>`에 `origin/develop`을 합친 뒤 판을 다음 베타(`<판>-beta.<n+1>`)로 올립니다([`docs/git-flow.md`](docs/git-flow.md) 규칙 4·12).
  - 메인 체크아웃은 `develop`에 두고 고치지 않습니다. 읽기만 하는 일은 메인 체크아웃에서 해도 됩니다.
  - 메인 체크아웃에 내가 하지 않은 커밋하지 않은 변경이 있으면 다른 작업의 것이니 건드리지 않습니다.
  - 이미 있는 브랜치(열린 PR의 리뷰 반영 등)를 고칠 때도 메인 체크아웃에서 `git switch` 하지 않고 그 브랜치의 워크트리에서 고칩니다. 없으면 만듭니다. 그 워크트리가 내가 만들었거나 지금 쓰던 것이 아니면 다른 세션이 쓰고 있을 수 있으니 들어가기 전에 사용자에게 묻습니다(`docs/git-flow.md` "워크트리").
  - 데스크톱 앱이 처음부터 워크트리로 연 세션이면 그 안에서 `git fetch origin`, `git switch --no-track -c feature/<주제> origin/develop` 순서로 작업 브랜치를 만듭니다. 앱은 워크트리를 GitHub 기본 브랜치(`main`)에서 만들지만, 작업은 이렇게 `origin/develop`에서 시작합니다.
- `main`·`develop`에 직접 커밋·푸시하지 않습니다. PR의 `--base`는 `feature/` → `develop`, `release/`·`hotfix/` → `main`과 `develop`입니다.
- 판 번호(`mod/mod.json` `version`, `app/AndroidManifest.xml` `versionName`·`versionCode`)는 `release/`·`hotfix/`에서만 바꿉니다. 베타는 판에도 꼬리를 붙이고(`2.0.4-beta.2`, 태그 `v2.0.4-beta.2`, 2.0.4-beta.1부터), 정식으로 낼 때 떼어 냅니다. `versionCode`는 지금까지 낸 묶음(`v2.*` 태그) 중 가장 큰 값보다 1 크게 합니다(`develop`의 값은 뒤처져 있음, [`docs/git-flow.md`](docs/git-flow.md) 규칙 4).
- 커밋·푸시·PR·태그는 사용자가 시킬 때만 합니다.
- 로컬 `develop`·`main`·`release/*`를 `git fetch origin <브랜치>:<브랜치>`로 옮기지 않습니다(다른 트리에 열린 브랜치면 그 트리가 어긋남). 메인 체크아웃의 `develop`은 메인 체크아웃에서 `git pull --ff-only`로 맞춥니다.

## 저장소 밖 경로

- Android SDK, 서명 키, HMG-API 소스 같은 PC 경로는 코드와 문서에 기본값으로 적지 않습니다.
- PC 스크립트는 `scripts/local-env.sh`(`nx4_env`, `nx4_need`)로 저장소 맨 위 `.env.local`(git 제외)에서 읽고, 값이 없으면 멈춥니다. 명령 앞에 준 값이 `.env.local`보다 앞섭니다.
- 새 경로 변수는 `.env.example`에 설명과 함께 더합니다.
- 워크트리에는 `.env.local`이 없습니다. 메인 체크아웃의 것을 명령 앞에 `NX4_ENV_FILE=<메인 체크아웃>/.env.local`로 가리킵니다. 주지 않으면 빌드 스크립트는 멈추고 `tests/mod-test.sh`는 빌드·HMG-API 엔진 시험을 건너뜁니다.
- `tests/mod-test.sh`는 `.env.local`에서 `HMGAPI_SRC`·`ANDROID_HOME`만 읽고(`ANDROID_HOME`은 `hooks.jar`를 진짜로 만들 때), 시험이 부르는 스크립트는 `.env.local`을 읽지 않게 합니다(`NX4_ENV_FILE=`).
