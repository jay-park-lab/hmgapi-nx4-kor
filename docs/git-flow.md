# 브랜치 전략: Git Flow

이 저장소는 Git Flow를 따릅니다. 아래 "규칙"은 권장이 아니라 **반드시 지킬 것**이며, 사람과 Claude 모두에게 같습니다. 규칙을 어긴 커밋·PR은 합치지 않습니다.

## 브랜치

| 브랜치 | 만드는 곳 | 합치는 곳 | 쓰임 |
|---|---|---|---|
| `main` | (처음부터 있음) | — | 배포한 판만. 합칠 때마다 `v<판>` 태그 |
| `develop` | `main` (처음 한 번) | — | 다음 판을 모으는 곳 |
| `feature/<주제>` | `develop` | `develop` | 기능, 고침, 문서, 시험 등 모든 일반 작업 |
| `release/<판>` | `develop` | `main`, `develop` | 판 번호 올리기, 차에서 확인, 배포 직전 고침만 |
| `hotfix/<판>` | `main` | `main`, `develop` (진행 중인 `release/`가 있으면 거기에도) | 배포한 판의 급한 고침 |

## 규칙

1. **`main`과 `develop`에 직접 커밋하거나 푸시하지 않습니다.** 모든 변경은 위 작업 브랜치에서 PR로 합칩니다.
2. **브랜치 이름**은 `feature/`, `release/`, `hotfix/` 중 하나로 시작하고, 뒤는 영어 소문자·숫자·하이픈만 씁니다. 판은 `X.Y.Z`입니다.
   - 예: `feature/env-local`, `feature/emulator-test`, `release/2.1.0`, `hotfix/2.0.1`
3. **브랜치마다 만드는 곳과 합치는 곳은 위 표를 따릅니다.** `feature/`를 `main`에 바로 합치거나, `release/`를 `main`에만 합치고 `develop`에 빠뜨리지 않습니다.
4. **판 번호는 `release/`와 `hotfix/` 브랜치에서만 바꿉니다.** `feature/`에서는 바꾸지 않습니다. 바꿀 곳은 세 군데이고 함께 바꿉니다.
   - `mod/mod.json`의 `version`
   - `app/AndroidManifest.xml`의 `versionName` (`mod.json`과 같은 값)
   - `app/AndroidManifest.xml`의 `versionCode` (1 올림. 내려가면 차가 앱 업데이트를 받지 않습니다)
5. **PR은 merge commit으로 합칩니다.** squash와 rebase 합치기는 쓰지 않습니다. 작업 브랜치 단위의 이력이 `main`·`develop`에 그대로 남아야 합니다.
6. **태그**
   - `release/`·`hotfix/`를 `main`에 합치면, 그 merge commit에 주석 태그 `v<판>`을 답니다(예: `v2.1.0`).
   - 차에서 확인하려고 배포 전에 묶음을 만들 때는 `release/` 브랜치에 `v<판>-beta.<n>` 태그를 답니다(예: `v2.1.0-beta.1`).
   - 태그는 지우거나 옮기지 않습니다. 틀렸으면 다음 번호로 새로 답니다.
7. **배포 묶음**(`scripts/build.sh`의 결과)은 태그(`v<판>` 또는 `v<판>-beta.<n>`)를 단 커밋에서, 배포용 키로만 만듭니다. 태그를 올리면 GitHub Actions가 `production` 환경의 키로 만들어 릴리스에 올립니다([`release.md`](release.md)). PC에서 만들 때는 `.env.local`이 가리키는 배포용 키(저장소 밖)를 씁니다. 같은 태그로 다시 만들어 이미 낸 파일을 바꾸지 않습니다(서명이 만들 때마다 달라 SHA-256이 바뀝니다). 커밋하지 않은 수정이 있으면 만들지 않습니다(USB `README.txt`에 "커밋하지 않은 수정 포함"이 찍힙니다).
8. **합치기 전에 확인합니다.**
   - 모든 PR: `sh tests/mod-test.sh`가 "모두 통과", 바뀐 동작에 맞게 문서(`README.md`, `docs/`)를 고침
   - `release/`·`hotfix/`: `.env.local`에 `HMGAPI_SRC`를 두어 빌드·HMG-API 엔진 시험까지 통과, `docs/design.md`의 "차에서 확인할 것" 중 해당 항목 확인
   - 상태 화면 앱을 바꾼 PR: [`docs/emulator-test.md`](emulator-test.md)의 시나리오와 [지금 재부팅] 흐름
9. **강제 푸시(`--force`)는 `main`·`develop`에 하지 않습니다.** 작업 브랜치도 PR을 연 뒤에는 하지 않습니다.
10. **합친 작업 브랜치는 지웁니다.** `release/`·`hotfix/`는 `main`과 `develop` 양쪽에 합친 뒤에 지웁니다.
11. **작업은 작업 브랜치마다 워크트리를 따로 만들어 시작합니다.** 만들고 지우는 법은 아래 "워크트리"에 있습니다.
    - 메인 체크아웃(저장소를 받은 폴더)은 `develop`에 둡니다. 브랜치를 바꾸지 않고, 파일도 고치지 않습니다.
    - 읽기만 하는 일(조사, 질문에 답하기, PR 보기)은 메인 체크아웃에서 해도 됩니다.
    - 까닭: 한 체크아웃에서 브랜치를 바꿔 가며 일하면 여러 세션(사람·Claude)이 같은 파일과 HEAD를 함께 씁니다. 그러면 한쪽의 커밋하지 않은 변경이 다른 쪽의 브랜치로 따라갑니다(2026-11-20: 한 세션이 메인 체크아웃을 `feature/` 브랜치로 바꿔 둔 사이, 다른 작업이 같은 체크아웃에서 `docs/release.md`를 고침).
    - 메인 체크아웃에 내가 하지 않은 커밋하지 않은 변경이 있으면 다른 작업의 것입니다. 건드리지 않습니다.

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
# mod/mod.json version, app/AndroidManifest.xml versionName·versionCode를 올리고 커밋
git push -u origin release/<판>
```

차에서 확인할 묶음이 필요하면 그 워크트리에서:

```sh
git tag -a v<판>-beta.<n> -m "NX4 KOR <판> beta <n>"
git push origin v<판>-beta.<n>
# Actions의 release 실행을 승인하면 시험판 릴리스에 묶음이 올라갑니다(release.md)
```

확인이 끝나면 `main`에 합치고 태그를 답니다. 로컬 `main`으로 바꾸지 않고, 합친 merge commit에 바로 답니다.

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

### 워크트리

규칙 11대로 작업마다 워크트리를 따로 만듭니다. 한 저장소의 브랜치는 한 트리에서만 열 수 있습니다. 메인 체크아웃에는 `develop`이 열려 있으므로 다른 트리에서는 `git switch develop`을 쓸 수 없습니다. 어느 트리에 무엇이 열려 있는지는 `git worktree list`로 봅니다(첫 줄이 메인 체크아웃).

- **폴더:** `.claude/worktrees/<이름>`에 만듭니다(git이 무시하는 폴더). 이름은 `feature/<주제>`면 `<주제>`, `release/<판>`·`hotfix/<판>`이면 `release-<판>`·`hotfix-<판>`입니다.
- **다른 브랜치에서 시작하는 일:** 사용자가 정한 예외로 `release/<판>`에 넣는 `feature/` 브랜치 등이 그렇습니다. 같은 방법으로 만들고 시작점만 `origin/<그 브랜치>`로 바꿉니다.
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
  - `ExitWorktree`는 사용자가 요청할 때만 부르는 도구입니다. 그래서 합칠지 물을 때 "합친 뒤 워크트리에서 나와 워크트리와 브랜치를 지운다"를 함께 묻고, 사용자가 고르면 부릅니다.
- **데스크톱 앱이 워크트리로 연 세션:** 앱이 처음부터 `.claude/worktrees/<이름>`(브랜치 `claude/<이름>`)에서 연 세션은 이미 따로 떨어져 있습니다. 그 안에서 작업 브랜치를 만듭니다. 워크트리 폴더는 앱이 정리합니다.

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
| `CLAUDE.md`의 브랜치 규칙 | Claude가 `main`·`develop`에서 작업, 메인 체크아웃에서 브랜치를 바꿔 작업(규칙 11), 이름이 틀린 브랜치, `feature/`에서 판 번호 바꾸기 | 적용됨 |
| GitHub 브랜치 보호(`main`, `develop`) | 직접 푸시, PR 없이 합치기, 강제 푸시, 브랜치 삭제(관리자 포함) | 아직 걸려 있지 않음(2026-11-20 확인). 클래식 브랜치 보호는 없습니다. 브랜치 ruleset `main-protetion`(`main`: 삭제·강제 푸시 금지)과 `develop`(삭제·강제 푸시 금지·PR 필수)은 만들어져 있지만 꺼져 있고, 둘 다 사용자 예외가 있습니다. 무엇으로 걸지는 [#16](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/16), 클래식 보호는 아래 "처음 한 번" 3 |
| GitHub 저장소 설정 | squash·rebase 합치기, 합친 브랜치 남기기 | 합친 브랜치 자동 삭제는 켜짐. squash·rebase 합치기는 아직 허용됨(2026-11-20 확인). 아래 "처음 한 번" 2 |
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

2. 합치기 방법을 merge commit만 남기고, 합친 브랜치는 자동으로 지우기:

   ```sh
   gh api -X PATCH repos/jay-park-lab/hmgapi-nx4-kor -F allow_merge_commit=true -F allow_squash_merge=false -F allow_rebase_merge=false -F delete_branch_on_merge=true
   ```

3. `main`과 `develop` 보호(관리자도 PR로만 합치게):

   ```sh
   gh api -X PUT repos/jay-park-lab/hmgapi-nx4-kor/branches/main/protection --input - <<'EOF'
   {"required_status_checks": null, "enforce_admins": true, "required_pull_request_reviews": {"required_approving_review_count": 0}, "restrictions": null, "allow_force_pushes": false, "allow_deletions": false}
   EOF
   ```

   `develop`도 같은 명령에서 `branches/main`을 `branches/develop`으로 바꿔 한 번 더 실행합니다.

브랜치 보호와 저장소 설정은 GitHub 쪽에 남으므로, 바꾸면 이 표의 "상태"도 고칩니다. 2·3을 적용할지는 [#16](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/16)에서 정합니다.
