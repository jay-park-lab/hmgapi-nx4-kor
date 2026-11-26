# 브랜치 전략: Git Flow

이 저장소는 Git Flow를 따릅니다. 아래 "규칙"은 권장이 아니라 **반드시 지킬 것**이며, 사람과 Claude 모두에게 같습니다. 규칙을 어긴 커밋·PR은 합치지 않습니다.

## 브랜치

| 브랜치 | 만드는 곳 | 합치는 곳 | 쓰임 |
|---|---|---|---|
| `main` | (처음부터 있음) | — | 배포한 판만. 합칠 때마다 `v<판>` 태그 |
| `develop` | `main` (처음 한 번) | — | 다음 판을 모으는 곳 |
| `feature/<주제>` | `develop` | `develop` | 기능, 고침, 문서, 시험 등 모든 일반 작업 |
| `release/<판>` | `develop` | `main`, `develop` | 판 번호 올리기, 차에서 확인만. 고침은 `develop`에서(규칙 12) |
| `hotfix/<판>` | `main` | `main`, `develop` (진행 중인 `release/`에는 넣지 않음. 필요하면 `develop`을 그 `release/`에 합쳐 다음 베타를 냄, 규칙 12) | 배포한 판의 급한 고침 |

## 규칙

1. **`main`과 `develop`에 직접 커밋하거나 푸시하지 않습니다.** 모든 변경은 위 작업 브랜치에서 PR로 합칩니다.
2. **브랜치 이름**은 `feature/`, `release/`, `hotfix/` 중 하나로 시작하고, 뒤는 영어 소문자·숫자·하이픈만 씁니다. 판은 `X.Y.Z`입니다.
   - 예: `feature/env-local`, `feature/emulator-test`, `release/2.1.0`, `hotfix/2.0.1`
   - 예외: `main`의 README 안내만 바꾸는 `hotfix/main-readme`(규칙 13)
3. **브랜치마다 만드는 곳과 합치는 곳은 위 표를 따릅니다.** `feature/`를 `main`에 바로 합치거나, `release/`를 `main`에만 합치고 `develop`에 빠뜨리지 않습니다.
4. **판 번호는 `release/`와 `hotfix/` 브랜치에서만 바꿉니다.** `feature/`에서는 바꾸지 않습니다. 바꿀 곳은 세 군데이고 함께 바꿉니다.
   - `mod/mod.json`의 `version`
   - `app/AndroidManifest.xml`의 `versionName` (`mod.json`과 같은 값)
   - `app/AndroidManifest.xml`의 `versionCode`: 지금까지 낸 묶음(`v2.*` 태그) 중 가장 큰 값보다 1 크게 합니다. `v1.*` 태그는 예전 NEMESIS 묶음입니다. 그때의 앱은 패키지가 달라(`korea.projection.app`, `nemesis-pkg/app-src/`) 이 앱(`io.github.jayparklab.nx4kor`)의 `versionCode`와 상관없고, `app/AndroidManifest.xml`도 없습니다(PR #43 리뷰 7·8). 베타도 같습니다. 내려가면 차가 앱 업데이트를 받지 않습니다(HMG-API가 `pm install -r`로 넣어 낮은 값은 거절됨, 차에는 옛 판 관리 앱이 남음).
     - `develop`의 값은 뒤처져 있습니다. 2.0.3까지의 `release/`를 `develop`에 되돌려 합치지 않아 `develop`은 38인데, 낸 묶음은 `v2.0.3-beta.1`의 41까지입니다(PR #43 리뷰 6). 그래서 `develop`에서 자른 뒤 "1 올림"이 아니라 태그를 봅니다: `git tag --list 'v2.*'`의 태그마다 `git show <태그>:app/AndroidManifest.xml`. `release/2.0.4`의 첫 베타는 42입니다.
   - **베타는 판에도 꼬리를 붙입니다**(2026-11-23 사용자 결정). 차에서 확인하는 동안 `release/<판>`의 판은 `<판>-beta.<n>`(예: `2.0.4-beta.2`)이고, 정식으로 낼 때만 `<판>`(예: `2.0.4`)으로 바꿉니다. 숫자는 앞자리 0 없이 씁니다(`beta.02`가 아니라 `beta.2`, release 워크플로가 확인).
     - 까닭: 파일의 판이 베타와 정식에서 같으면, 고친 베타를 같은 판으로 낼 수 없습니다. USB 설치기는 판이 같으면 "같은 판이 이미 설치됨"으로 건너뛰고(`usb/troubleShooter`), 자동 설정도 새 판을 알아보지 못합니다(`$BK/applied`). 그래서 예전에는 고칠 때마다 판을 올렸습니다(2.0.0 → 2.0.3, 모두 베타).
     - 판의 차례(semver, `2.0.3 < 2.0.4-beta.1 < 2.0.4-beta.2 < 2.0.4-beta.10 < 2.0.4`)를 보는 것은 HMG-API입니다. `engine install`은 설치된 판보다 낮은 판을 `--force` 없이 거절합니다. USB 설치기는 이 모드의 판이 같은지만 봅니다(같으면 건너뜀, `NX4/REINSTALL`이 있으면 다시 설치). 다르면 예전 판을 정리(`uninstall.sh --update`)한 뒤 `engine install`을 부르고, 거절되면 예전 판의 서비스를 다시 띄우고 실패로 끝냅니다.
     - 그래서 정식 `<판>`이 들어간 차에는 같은 판의 베타(`<판>-beta.<n>`)를 넣지 않습니다(HMG-API가 거절).
     - **새 방식은 2.0.4-beta.1부터입니다.** 2.0.3-beta.1까지는 파일의 판에 꼬리가 없었습니다(이미 공개한 `v2.0.3-beta.1`의 판은 `2.0.3`). 2.0.3의 베타를 꼬리 붙여 이어 가면, `v2.0.3-beta.1`을 넣은 차는 `2.0.3-beta.<n>`을 낮은 판이라 받지 못하고, 정식 `2.0.3`은 같은 판이라 건너뜁니다(PR #43 리뷰 2). 그래서 2.0.3은 정식으로 내지 않고 다음 판 2.0.4로 넘어갑니다.
     - 관리 앱(설치 중 제목 "NX4 KOR <판> 설치 중", 확인 줄)은 자기 `versionName`을 그대로 보이므로, 차에서 어느 베타인지 바로 보입니다.
5. **PR은 merge commit으로 합칩니다.** squash와 rebase 합치기는 쓰지 않습니다. 작업 브랜치 단위의 이력이 `main`·`develop`에 그대로 남아야 합니다.
   - 명령은 `gh pr merge <PR> --merge`입니다. `develop` ruleset이 승인 1을 요구해(아래 "강제 장치"), `develop`으로 가는 PR은 `gh pr view <PR> --json mergeStateStatus,reviewDecision`이 `BLOCKED`, `REVIEW_REQUIRED`입니다. 혼자 쓰는 저장소라 자기 PR은 승인할 수 없습니다.
   - 그때는 **사용자가 합치기를 고른 경우에만** `gh pr merge <PR> --merge --admin`으로 사용자 예외를 써서 합칩니다(GitHub 화면에서는 bypass 체크). PR #56을 이렇게 합쳤습니다(2026-11-24). `--admin`을 붙여도 merge commit이고, squash·rebase는 여전히 쓰지 않습니다.
   - `--admin`은 `gh pr view <PR> --json mergeable,mergeStateStatus,reviewDecision`이 `MERGEABLE`·`BLOCKED`·`REVIEW_REQUIRED`이고 막는 것이 승인뿐일 때만 씁니다. 그 밖의 까닭이면 넘기지 않고 그 까닭부터 풉니다(충돌은 `CONFLICTING`·`DIRTY`로 나오고 `--admin`으로도 넘지 못함).
   - `develop` ruleset의 승인 수를 0으로 바꾸면 `--admin`은 필요 없습니다.
6. **태그**
   - `release/`·`hotfix/`를 `main`에 합치면, 그 merge commit에 주석 태그 `v<판>`을 답니다(예: `v2.1.0`).
   - 차에서 확인하려고 배포 전에 묶음을 만들 때는 `release/` 브랜치에 `v<판>-beta.<n>` 태그를 답니다(예: `v2.1.0-beta.1`). 그 커밋의 파일 판은 태그에서 `v`만 뗀 것(`2.1.0-beta.1`)과 같아야 합니다(규칙 4, release 워크플로가 확인).
   - 태그는 지우거나 옮기지 않습니다. 틀렸으면 다음 번호로 새로 답니다.
7. **배포 묶음**(`scripts/build.sh`의 결과)은 태그(`v<판>` 또는 `v<판>-beta.<n>`)를 단 커밋에서, 배포용 키로만 만듭니다. 태그를 올리면 GitHub Actions가 `production` 환경의 키로 만들어 릴리스에 올립니다([`release.md`](release.md)). PC에서 만들 때는 `.env.local`이 가리키는 배포용 키(저장소 밖)를 씁니다. 같은 태그로 다시 만들어 이미 낸 파일을 바꾸지 않습니다(서명이 만들 때마다 달라 SHA-256이 바뀝니다). 커밋하지 않은 수정이 있으면 만들지 않습니다(USB `README.txt`에 "커밋하지 않은 수정 포함"이 찍힙니다).
8. **합치기 전에 확인합니다.**
   - 모든 PR: `sh tests/mod-test.sh`가 "모두 통과", 바뀐 동작에 맞게 문서(`README.md`, `docs/`)를 고침
   - `release/`·`hotfix/`: `.env.local`에 `HMGAPI_SRC`를 두어 빌드·HMG-API 엔진 시험까지 통과, `docs/design.md`의 "차에서 확인할 것" 중 해당 항목 확인
   - 관리 앱을 바꾼 PR: [`docs/emulator-test.md`](emulator-test.md)의 시나리오와 [지금 재부팅] 흐름
9. **강제 푸시(`--force`)는 `main`·`develop`에 하지 않습니다.** 작업 브랜치도 PR을 연 뒤에는 하지 않습니다.
10. **합친 작업 브랜치는 지웁니다.** `release/`·`hotfix/`는 `main`과 `develop` 양쪽에 합친 뒤에 지웁니다.
11. **작업은 작업 브랜치마다 워크트리를 따로 만들어 시작합니다.** 만들고 지우는 법은 아래 "워크트리"에 있습니다.
    - 메인 체크아웃(저장소를 받은 폴더)은 `develop`에 둡니다. 브랜치를 바꾸지 않고, 파일도 고치지 않습니다.
    - 읽기만 하는 일(조사, 질문에 답하기, PR 보기)은 메인 체크아웃에서 해도 됩니다.
    - 까닭: 한 체크아웃에서 브랜치를 바꿔 가며 일하면 여러 세션(사람·Claude)이 같은 파일과 HEAD를 함께 씁니다. 그러면 한쪽의 커밋하지 않은 변경이 다른 쪽의 브랜치로 따라갑니다(2026-11-20: 한 세션이 메인 체크아웃을 `feature/` 브랜치로 바꿔 둔 사이, 다른 작업이 같은 체크아웃에서 `docs/release.md`를 고침).
    - 메인 체크아웃에 내가 하지 않은 커밋하지 않은 변경이 있으면 다른 작업의 것입니다. 건드리지 않습니다.
12. **새 작업 브랜치(와 그 워크트리)는 늘 `origin/develop`에서 시작합니다**(2026-11-23 사용자 결정).
    - `feature/`·`release/` 모두 그렇습니다. 새 작업의 예외는 `hotfix/`뿐입니다. 배포한 `main`을 고치는 브랜치라 `origin/main`에서 시작합니다.
    - 이미 있는 브랜치를 이어서 고치는 것(열린 PR의 리뷰 반영 등)은 새 작업이 아니므로 그 브랜치에서 워크트리를 엽니다(아래 "워크트리"). 리뷰어의 리뷰용 워크트리(head SHA에 `--detach`)도 같습니다.
    - `release/<판>`에서 시작하는 `feature/`(release에 고침을 옮겨 넣던 길, 예: #35)는 만들지 않습니다. `hotfix/`도 진행 중인 `release/`에 합치지 않습니다.
      - 고침은 `develop`에 합칩니다.
      - 그 고침이 든 묶음이 필요하면 판을 올리지 않고 같은 `release/<판>`에 `origin/develop`을 합친(merge commit) 뒤, 판을 다음 베타(`<판>-beta.<n+1>`)로 올리고 `v<판>-beta.<n+1>`을 답니다(규칙 4, 아래 "릴리스"). `develop`에 그 사이 들어온 다른 변경도 함께 들어오므로, 이번 판에 넣고 싶지 않은 것이 있으면 합치기 전에 사용자에게 묻습니다.
      - **`develop`에 다음 판의 작업이 이미 있으면 체리픽합니다**(2026-11-26 사용자 결정. 2.1.2-beta.2 때 `develop`에 2.2.0의 USB Wi-Fi 동글 PR #69가 먼저 들어옴).
        - 이번 판에 넣을 PR도 먼저 평소처럼 `develop`에 합칩니다.
        - 그다음 `origin/develop`을 합치지 않고, 그 PR의 커밋만 `release/<판>`으로 옮깁니다: `git cherry-pick -x <PR이 시작한 커밋>..<PR의 리뷰된 head>`. `-x`가 원래 커밋을 메시지에 남깁니다. PR이 `develop`을 합친 커밋은 옮기지 않습니다(다음 판의 작업이 따라옴).
        - 옮긴 뒤 다음 판의 커밋이 섞이지 않았는지 봅니다(`git merge-base --is-ancestor <다음 판의 합친 커밋> HEAD`가 실패해야 함). 그다음 테스트하고 판을 다음 베타로 올립니다.
        - 정식으로 낸 뒤 `release/<판>`을 `develop`으로 되돌려 합칠 때는 같은 변경이 원래 커밋과 체리픽으로 두 벌 있습니다. 내용이 같아 대개 그대로 합쳐지고, 충돌이 나면 `develop` 쪽을 따릅니다.
      - 예전(2.0.3-beta.1까지)에는 파일의 판에 베타 꼬리가 없어, 고칠 때마다 `develop`에서 `release/`를 다음 판으로 다시 자르고 지난 `release/`를 지웠습니다(`release/2.0.0`의 `v2.0.0-beta.4` 다음이 `release/2.0.1`의 `v2.0.1-beta.1`, … `release/2.0.3`). 지난 `release/`를 지울 때는 끝 커밋에 베타 태그가 있는지 먼저 봅니다(`git tag --points-at origin/release/<판>`). 없으면 지우지 말고 사용자에게 묻습니다.
    - 데스크톱 앱이 `main`에서 만든 워크트리 세션도 작업 브랜치는 `origin/develop`에서 만듭니다.
13. **`main`의 README 안내만 바꾸는 예외**(2026-11-23 사용자 결정). `main`에 정식 판이 아직 없는 동안, 저장소 첫 화면(`main`의 README)에 보일 안내를 넣을 때 씁니다. 그 안내와 어긋나는 README 줄(예: "릴리스 묶음은 없어 직접 만듭니다")도 함께 고칩니다.
    - 같은 내용을 먼저 `feature/`로 `develop`에 합쳐 둡니다.
    - 그다음 `origin/main`에서 `hotfix/main-readme` 브랜치로 시작해 README만 고치고, `main`에만 PR로 합칩니다(merge commit).
    - 판 번호와 태그는 바꾸지 않습니다. `develop`으로 되돌려 합치지 않습니다(내용이 이미 있음).
    - 이 브랜치는 규칙 2(이름의 판), 규칙 3(`develop`에도 합침), 규칙 6(`v<판>` 태그), 규칙 10(양쪽에 합친 뒤 지움), 규칙 12(새 작업은 `develop`에서)의 예외입니다. README 말고 다른 파일은 넣지 않습니다.
    - `main`에 합친 뒤 바로 지웁니다. 다음에 또 쓰면 같은 이름으로 다시 만듭니다.

## 흐름

명령은 한 줄씩 차례로 칩니다. 메인 체크아웃의 맨 위 폴더에서 시작합니다. PR은 `gh`로 만들며 `--base`를 늘 적습니다(GitHub 기본 브랜치는 사용자가 보는 `main`이므로 빠뜨리면 `main`으로 갑니다).

Claude로 PR을 올리고 리뷰·합치기까지 할 때는 `pr-review-cycle` 스킬(`.claude/skills/pr-review-cycle/`)이 이 규칙대로 진행합니다.

**쌓인 PR은 아래 것부터 합칩니다.** 아직 합치지 않은 브랜치 위에 만든 PR(예: #3이 #1의 `feature/dev-setup` 위)을 먼저 합치면, 아래 PR의 커밋이 위 PR의 merge commit에 딸려 들어가고 아래 PR은 merge commit 없이 "합쳐짐"으로 닫힙니다(2026-11-20, #1). 내용은 빠지지 않지만 이력에서 아래 PR 단위가 보이지 않습니다.

### 기능 (`feature/`)

```sh
git fetch origin
git worktree add --no-track -b feature/<주제> .claude/worktrees/<주제> origin/develop
cd .claude/worktrees/<주제>
# 고치고 커밋
git push -u origin feature/<주제>
gh pr create --base develop --head feature/<주제>
```

`--no-track`을 주면 새 브랜치가 `origin/develop`을 따라가지 않습니다. 첫 `git push -u` 뒤에는 자기 원격 브랜치를 따라갑니다.

합친 뒤, 메인 체크아웃에서:

```sh
git pull --ff-only
git worktree remove .claude/worktrees/<주제>
git branch -d feature/<주제>
```

### 릴리스 (`release/`)

```sh
git fetch origin
git worktree add --no-track -b release/<판> .claude/worktrees/release-<판> origin/develop
cd .claude/worktrees/release-<판>
# mod/mod.json version, app/AndroidManifest.xml versionName을 <판>-beta.1로,
# versionCode를 지금까지 낸 묶음(v2.* 태그) 중 가장 큰 값 + 1로(develop 값 + 1이 아님, 규칙 4) 바꾸고 커밋
git push -u origin release/<판>
```

차에서 확인할 묶음은 그 워크트리에서 답니다. 태그의 판은 파일의 판과 같습니다(규칙 4).

```sh
git tag -a v<판>-beta.<n> -m "NX4 KOR <판> beta <n>"
git push origin v<판>-beta.<n>
# Actions의 release 실행을 승인하면 시험판 릴리스에 묶음이 올라갑니다(release.md)
```

차 확인에서 고칠 것이 나오면 그 `release/`에서 고치지 않습니다(규칙 12).
1. `develop`에서 시작한 `feature/`로 고쳐 `develop`에 합칩니다.
2. `release/<판>` 워크트리에서 `git fetch origin`, `git merge origin/develop`으로 고침을 들입니다(merge commit).
   - 그 사이 `hotfix/`가 판을 올려 `develop`에 들어갔으면 판 세 곳(`mod.json` `version`, `versionName`, `versionCode`)이 충돌합니다. 판은 `release/` 쪽의 다음 베타(`<판>-beta.<n+1>`)로, `versionCode`는 낸 묶음 중 가장 큰 값보다 1 크게(규칙 4, 보통 두 쪽 중 큰 값 + 1) 풀고, 3의 판 올리기를 그 merge commit에서 함께 합니다.
3. 판을 `<판>-beta.<n+1>`로, `versionCode`를 낸 묶음 중 가장 큰 값 + 1(보통 지난 베타 + 1)로 바꿔 커밋하고 푸시한 뒤 `v<판>-beta.<n+1>`을 답니다(위와 같은 순서).

확인이 끝나면 판을 `<판>`으로(꼬리를 떼고), `versionCode`를 낸 묶음 중 가장 큰 값 + 1로 바꿔 `release/<판>`에 커밋합니다. 그다음 `main`에 합치고 태그를 답니다. 로컬 `main`으로 바꾸지 않고, 합친 merge commit에 바로 답니다. 정식 묶음은 마지막 베타와 판 문자열·`versionCode`만 다릅니다.

```sh
gh pr create --base main --head release/<판>
# 합친 뒤. <merge commit>은 gh pr view <PR> --json mergeCommit -q .mergeCommit.oid
git fetch origin
git tag -a v<판> -m "NX4 KOR <판>" <merge commit>
git push origin v<판>
# Actions의 release 실행을 승인하면 릴리스에 묶음이 올라갑니다(release.md)
gh pr create --base develop --head release/<판>
```

`develop`에도 합친 뒤, 메인 체크아웃에서 `git pull --ff-only`, `git worktree remove .claude/worktrees/release-<판>`, `git branch -d release/<판>` 순서로 지웁니다.

### 핫픽스 (`hotfix/`)

```sh
git fetch origin
git worktree add --no-track -b hotfix/<판> .claude/worktrees/hotfix-<판> origin/main
cd .claude/worktrees/hotfix-<판>
# 고치고, 판 번호(셋째 자리)를 올리고 커밋
git push -u origin hotfix/<판>
gh pr create --base main --head hotfix/<판>
# 합친 뒤 merge commit에 v<판> 태그(릴리스와 같음)
gh pr create --base develop --head hotfix/<판>
```

지우는 법은 릴리스와 같습니다.

`main`의 README 안내만 넣는 `hotfix/main-readme`는 이 흐름이 아니라 규칙 13을 따릅니다.
- 워크트리 폴더는 `.claude/worktrees/hotfix-main-readme`입니다.
- 판 번호를 올리지 않고 태그도 달지 않습니다.
- `develop` PR을 열지 않고, `main`에 합친 뒤 바로 지웁니다.

### 워크트리

규칙 11대로 작업마다 워크트리를 따로 만듭니다. 한 저장소의 브랜치는 한 트리에서만 열 수 있습니다. 메인 체크아웃에는 `develop`이 열려 있으므로 다른 트리에서는 `git switch develop`을 쓸 수 없습니다. 어느 트리에 무엇이 열려 있는지는 `git worktree list`로 봅니다(첫 줄이 메인 체크아웃).

- **폴더:** `.claude/worktrees/<이름>`에 만듭니다(git이 무시하는 폴더). 이름은 `feature/<주제>`면 `<주제>`, `release/<판>`·`hotfix/<판>`이면 `release-<판>`·`hotfix-<판>`입니다.
- **시작점:** 새 작업은 늘 `origin/develop`입니다(규칙 12). `release/<판>`에 넣는 `feature/` 브랜치는 만들지 않습니다. 새 작업의 예외는 `hotfix/`(`origin/main`)뿐입니다. 이미 있는 브랜치를 이어서 고칠 때는 아래처럼 그 브랜치에서 엽니다.
- **이미 있는 브랜치를 이어서 고칠 때**(열린 PR의 리뷰 반영 등): 메인 체크아웃에서 `git switch`로 그 브랜치를 열지 않습니다.
  - 그 브랜치가 열린 워크트리가 `git worktree list`에 있으면 그 워크트리에서 고칩니다.
    - 그 워크트리를 다른 세션(그 PR을 만든 세션, 데스크톱 앱이 연 폴더 등)이 아직 쓰고 있을 수 있습니다. 내가 만들었거나 지금 쓰던 워크트리가 아니면 들어가기 전에 사용자에게 묻습니다. 두 세션이 한 트리를 함께 쓰면 규칙 11이 막으려는 일이 그대로 일어납니다.
    - 같은 브랜치로 워크트리를 하나 더 만들 수는 없습니다(`is already checked out at …`). 그래서 길은 그 워크트리에 들어가거나 사용자에게 묻는 것뿐입니다.
  - 없으면 `git fetch origin` 뒤 만듭니다.
    - 로컬 브랜치가 있으면 `git worktree add .claude/worktrees/<주제> feature/<주제>`. 원격보다 뒤처졌으면 그 워크트리에서 `git pull --ff-only` 합니다.
    - 로컬 브랜치가 없으면 `git worktree add -b feature/<주제> .claude/worktrees/<주제> origin/feature/<주제>`. 이때는 원격 브랜치를 따라가야 하므로 `--no-track`을 주지 않습니다.
- **Claude 세션:**
  - 메인 체크아웃에서 시작한 세션은 위 `git worktree add`로 만든 뒤 `EnterWorktree`의 `path`로 그 워크트리에 들어가 작업합니다. 이미 있는 워크트리도 같습니다.
  - `EnterWorktree`의 `name`으로 새로 만들지 않습니다. 그 길은 GitHub 기본 브랜치(`main`)에서 규칙 2에 맞지 않는 이름의 브랜치를 만듭니다.
  - 지울 때는 `ExitWorktree`(`keep`)로 메인 체크아웃에 돌아온 뒤 위의 `git worktree remove`를 합니다. `path`로 들어간 워크트리는 `ExitWorktree`가 지우지 않습니다.
  - 사용자에게 물어서 빌려 쓴 다른 세션의 워크트리는 `ExitWorktree`(`keep`)로 나오기만 하고, 워크트리와 로컬 브랜치는 지우지 않습니다. 워크트리가 브랜치를 열고 있어 `git branch -d`도 막힙니다. 남았다고 알리고, 지우려면 사용자에게 묻습니다.
  - `ExitWorktree`는 사용자가 요청할 때만 부르는 도구입니다. 그래서 합칠지 물을 때 "합친 뒤 워크트리에서 나와 워크트리와 브랜치를 지운다"를 함께 묻고, 사용자가 고르면 부릅니다.
- **데스크톱 앱이 워크트리로 연 세션:** 앱이 처음부터 `.claude/worktrees/<이름>`(브랜치 `claude/<이름>`)에서 연 세션은 이미 따로 떨어져 있습니다. 그 안에서 작업 브랜치를 만듭니다. 앱은 그 워크트리를 GitHub 기본 브랜치(`main`)에서 만들지만, 작업 브랜치는 아래처럼 `origin/develop`에서 만듭니다(규칙 12). 워크트리 폴더는 앱이 정리합니다.

  ```sh
  git fetch origin
  git switch --no-track -c feature/<주제> origin/develop
  # 고치고 커밋, 푸시, PR은 위와 같음
  ```

  합친 뒤:

  ```sh
  git fetch origin
  git switch --detach origin/develop
  git branch -d feature/<주제>
  ```

- **지울 때:**
  - 워크트리에 커밋하지 않은 변경이나 git이 모르는 파일이 있으면 `git worktree remove`가 멈춥니다. `--force`로 지우지 말고 무엇이 남았는지 봅니다.
  - git이 무시하는 빌드 결과(`out/`, `mod/app/`)는 워크트리와 함께 지워집니다.
  - 다른 세션의 워크트리(`git worktree list`의 다른 줄)는 지우지 않습니다. 그 안에서 고치는 것은 위 "이미 있는 브랜치를 이어서 고칠 때"대로 사용자에게 물은 뒤에만 합니다.
- **stash:** stash 목록은 모든 트리가 함께 씁니다. 맨 `git stash`·`git stash pop`은 다른 트리가 넣은 것을 꺼낼 수 있습니다.
  - 커밋하지 않은 변경을 다른 트리로 옮길 때는 내 파일만 경로로 넣습니다.
  - 경로를 주지 않으면 그 트리에 있던 다른 작업의 변경(`-u`라 미추적 파일 포함)까지 함께 옮겨집니다. 그러면 규칙 11이 막으려는 일이 그대로 일어납니다(2026-11-20, PR #33 리뷰에서 확인).
  - 순서:
    1. `git stash push -u -m <고유한 이름> -- <내 파일>…`
    2. 옮길 트리에서 `git stash list --format='%H %gd %gs'`로 그 이름의 SHA를 찾아 `git stash apply <SHA>` 합니다.
    3. 옮긴 것을 확인한 뒤, 같은 목록에서 이름으로 지금의 `stash@{n}`을 다시 찾아 `git stash drop stash@{n}` 합니다.
  - `git stash drop`은 SHA를 받지 않습니다(`is not a stash reference`). 그사이 다른 트리가 넣으면 `n`이 바뀌므로 지우기 직전에 다시 찾습니다.
- **로컬 `develop`·`main`·`release/*`를 `git fetch origin <브랜치>:<브랜치>`나 `git update-ref`로 옮기지 않습니다.**
  - 이 PC의 git 2.33은 다른 트리에 열린 브랜치도 막지 않고 옮깁니다. 그러면 그 트리는 HEAD만 새 커밋으로 가고 파일과 인덱스는 예전 그대로 남습니다.
  - 그 트리의 `git status`에는 방금 합친 PR을 되돌리는 스테이징 변경으로 보이고, 그대로 브랜치를 만들어 커밋하면 PR이 되돌려집니다(2026-11-20, #11·#29를 합친 뒤 두 번 일어남, [#25](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/25)).
  - 메인 체크아웃의 로컬 `develop`은 메인 체크아웃에서 `git pull --ff-only`로 맞춥니다.
- **알아보는 법:** `git status`에 하지 않은 스테이징 변경이 있고 `git reflog <브랜치>` 맨 위가 `fetch origin <브랜치>:<브랜치>`이면 이 경우입니다.
- **맞추는 법:**
  - `git diff --cached --stat <reflog에서 바로 앞 커밋>`이 비어 있으면 남은 흔적뿐입니다. 사용자에게 확인한 뒤 `git restore --source=HEAD --staged --worktree -- <파일>`로 맞춥니다.
  - 비어 있지 않으면 그 트리에서 하던 작업이 섞여 있으니 손대지 말고 사용자에게 묻습니다.
- **`.env.local`:** git이 무시하는 파일이라 워크트리에는 없습니다. 시험과 빌드에는 메인 체크아웃의 것을 가리킵니다(`NX4_ENV_FILE=<메인 체크아웃>/.env.local sh tests/mod-test.sh`). 주지 않으면 `mod-test.sh`는 빌드·HMG-API 엔진 시험을 건너뛰고, `scripts/build-app.sh`·`build.sh`는 값이 없다며 멈춥니다.

## 강제 장치

| 장치 | 막는 것 | 상태 |
|---|---|---|
| `CLAUDE.md`의 브랜치 규칙 | Claude가 `main`·`develop`에서 작업, 메인 체크아웃에서 브랜치를 바꿔 작업(규칙 11), `origin/develop`이 아닌 곳에서 작업 시작(규칙 12, `hotfix/` 빼고), 이름이 틀린 브랜치, `feature/`에서 판 번호 바꾸기 | 적용됨 |
| GitHub 브랜치 ruleset 두 개(`develop`, `main-protetion`) | `develop`: 직접 푸시·PR 없이 합치기(PR 필수, 승인 1), 강제 푸시, 브랜치 삭제. `main`: 강제 푸시, 브랜치 삭제. 둘 다 사용자(parkjoos)는 예외(`always`)라 막지 않습니다. Claude도 사용자 계정(`gh`)으로 푸시하므로 같은 예외를 받습니다 | 적용됨(2026-11-24 확인, 사용자가 켬, [#16](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/16)). `develop`은 `refs/heads/develop`, `main-protetion`은 기본 브랜치와 `refs/heads/main`이 대상입니다. 혼자 쓰는 저장소라 자기 PR은 승인할 수 없어 `develop`으로 가는 PR은 `BLOCKED`(`REVIEW_REQUIRED`)입니다. 사용자가 합치기를 고른 경우에만 `gh pr merge <PR> --merge --admin`(사용자 예외, GitHub 화면은 bypass 체크)으로 합칩니다(규칙 5, PR #56 2026-11-24). `--admin`이어도 merge commit이고 squash·rebase는 쓰지 않습니다. 승인 수를 0으로 바꾸면 `--admin`은 필요 없습니다. `main`에는 PR 필수가 없어 `main`에 직접 푸시하지 않는 것은 규칙 1로 지킵니다. 클래식 브랜치 보호는 쓰지 않습니다(ruleset과 규칙이 겹침). 아래 "처음 한 번" 3 |
| GitHub 저장소 설정 | 합친 브랜치 남기기 | 합친 브랜치 자동 삭제는 켜짐(2026-11-24 확인). squash·rebase 합치기는 그대로 허용합니다(2026-11-24 사용자 결정, [#16](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/16)). merge commit만 쓰는 것은 규칙 5와 `pr-review-cycle` 스킬로 지킵니다. 아래 "처음 한 번" 2 |
| release 워크플로의 확인([`release.md`](release.md)) | 태그와 판 번호가 다른 묶음, `main`에 없는 정식 태그, 이미 낸 릴리스 다시 만들기, 커밋하지 않은 수정, `mod-test.sh` 실패, 다른 키로 서명한 앱·모드 | `develop`에 있음(#4, 2026-11-20). `v2.0.0-beta.1`(`release/2.0.0`의 `407ab2f`)에서 처음 돌았고, 태그 확인·PC 시험, 서명한 묶음 만들기(`production` 승인 뒤), GitHub 릴리스가 모두 성공했습니다(실행 `44652653040`, 2026-11-20 확인) |
| GitHub `production` 환경(필수 리뷰어, 배포 ref `v*` 태그) | 승인 없이, 또는 `v*` 태그가 아닌 곳에서 배포 키를 쓰는 job | 적용됨(2026-11-20 확인): 필수 리뷰어 parkjoos(자기 승인 허용), 배포 ref는 `v*` 태그만, secret 세 개 있음. 관리자는 이 보호를 건너뛸 수 있습니다(`can_admins_bypass` 기본값). [`release.md`](release.md) "production 환경" |
| GitHub 태그 ruleset 두 개(`refs/tags/v*`) | 관리자가 아닌 사람의 `v*` 태그 만들기, 관리자를 포함한 누구든 태그 옮기기·지우기 | 적용됨(2026-11-20 확인): `release tags: create`(만들기 막음, 관리자 예외), `release tags: immutable`(옮기기·지우기 막음, 예외 없음). [`release.md`](release.md) "`v*` 태그 보호" |

### 처음 한 번 (저장소 관리자)

1. `develop` 만들기(2026-11-20에 했습니다):

   ```sh
   git switch main
   git pull --ff-only
   git switch -c develop
   git push -u origin develop
   ```

2. 합친 브랜치는 자동으로 지우기(켜져 있음, 2026-11-24 확인). squash·rebase 합치기는 끄지 않습니다(2026-11-24 사용자 결정, [#16](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/16)). merge commit만 쓰는 것은 규칙 5와 `pr-review-cycle` 스킬로 지킵니다.

   ```sh
   gh api -X PATCH repos/jay-park-lab/hmgapi-nx4-kor -F delete_branch_on_merge=true
   ```

3. `main`과 `develop` 보호: 브랜치 ruleset 두 개를 GitHub 저장소 Settings → Rules → Rulesets에서 켭니다(2026-11-24 사용자가 켬, [#16](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/16)).
   - `develop`: 대상 `refs/heads/develop`. 삭제 금지, 강제 푸시 금지, PR 필수(승인 1). 사용자 예외 `always`. 승인 1이라 PR은 `--admin`으로 합칩니다(규칙 5). 승인 수를 0으로 바꾸면 필요 없습니다
   - `main-protetion`: 대상 기본 브랜치와 `refs/heads/main`. 삭제 금지, 강제 푸시 금지. 사용자 예외 `always`
   - 클래식 브랜치 보호(`branches/<브랜치>/protection`)는 쓰지 않습니다. ruleset과 함께 두면 규칙이 겹칩니다.
   - 지금 상태는 이렇게 봅니다(둘 다 `active`여야 함):

     ```sh
     gh api repos/jay-park-lab/hmgapi-nx4-kor/rulesets --jq '.[] | [.name, .target, .enforcement] | @tsv'
     ```

브랜치 보호와 저장소 설정은 GitHub 쪽에 남으므로, 바꾸면 이 표의 "상태"도 고칩니다. 2·3은 [#16](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/16)에서 정했습니다(2026-11-24).
