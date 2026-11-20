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

## 흐름

명령은 한 줄씩 차례로 칩니다. PR은 `gh`로 만들며 `--base`를 늘 적습니다(GitHub 기본 브랜치는 사용자가 보는 `main`이므로 빠뜨리면 `main`으로 갑니다).

Claude로 PR을 올리고 리뷰·합치기까지 할 때는 `pr-review-cycle` 스킬(`.claude/skills/pr-review-cycle/`)이 이 규칙대로 진행합니다.

**쌓인 PR은 아래 것부터 합칩니다.** 아직 합치지 않은 브랜치 위에 만든 PR(예: #3이 #1의 `feature/dev-setup` 위)을 먼저 합치면, 아래 PR의 커밋이 위 PR의 merge commit에 딸려 들어가고 아래 PR은 merge commit 없이 "합쳐짐"으로 닫힙니다(2026-11-20, #1). 내용은 빠지지 않지만 이력에서 아래 PR 단위가 보이지 않습니다.

### 기능 (`feature/`)

```sh
git switch develop
git pull --ff-only
git switch -c feature/<주제>
# 고치고 커밋
git push -u origin feature/<주제>
gh pr create --base develop --head feature/<주제>
```

합친 뒤:

```sh
git switch develop
git pull --ff-only
git branch -d feature/<주제>
```

### 릴리스 (`release/`)

```sh
git switch develop
git pull --ff-only
git switch -c release/<판>
# mod/mod.json version, app/AndroidManifest.xml versionName·versionCode를 올리고 커밋
git push -u origin release/<판>
```

차에서 확인할 묶음이 필요하면:

```sh
git tag -a v<판>-beta.<n> -m "NX4 KOR <판> beta <n>"
git push origin v<판>-beta.<n>
# Actions의 release 실행을 승인하면 시험판 릴리스에 묶음이 올라갑니다(release.md)
```

확인이 끝나면 `main`에 합치고 태그를 답니다.

```sh
gh pr create --base main --head release/<판>
# 합친 뒤
git switch main
git pull --ff-only
git tag -a v<판> -m "NX4 KOR <판>"
git push origin v<판>
# Actions의 release 실행을 승인하면 릴리스에 묶음이 올라갑니다(release.md)
gh pr create --base develop --head release/<판>
```

`develop`에도 합친 뒤 `release/<판>`을 지웁니다.

### 핫픽스 (`hotfix/`)

```sh
git switch main
git pull --ff-only
git switch -c hotfix/<판>
# 고치고, 판 번호(셋째 자리)를 올리고 커밋
git push -u origin hotfix/<판>
gh pr create --base main --head hotfix/<판>
# 합친 뒤 main에 v<판> 태그(릴리스와 같음)
gh pr create --base develop --head hotfix/<판>
```

## 강제 장치

| 장치 | 막는 것 | 상태 |
|---|---|---|
| `CLAUDE.md`의 브랜치 규칙 | Claude가 `main`·`develop`에서 작업, 이름이 틀린 브랜치, `feature/`에서 판 번호 바꾸기 | 적용됨 |
| GitHub 브랜치 보호(`main`, `develop`) | 직접 푸시, PR 없이 합치기, 강제 푸시, 브랜치 삭제(관리자 포함) | 아직 걸려 있지 않음(2026-11-20 확인). 클래식 브랜치 보호는 없습니다. 브랜치 ruleset `main-protetion`(`main`: 삭제·강제 푸시 금지)과 `develop`(삭제·강제 푸시 금지·PR 필수)은 만들어져 있지만 꺼져 있고, 둘 다 사용자 예외가 있습니다. 무엇으로 걸지는 [`open-issue.md`](open-issue.md) OI-4, 클래식 보호는 아래 "처음 한 번" 3 |
| GitHub 저장소 설정 | squash·rebase 합치기, 합친 브랜치 남기기 | 합친 브랜치 자동 삭제는 켜짐. squash·rebase 합치기는 아직 허용됨(2026-11-20 확인). 아래 "처음 한 번" 2 |
| release 워크플로의 확인([`release.md`](release.md)) | 태그와 판 번호가 다른 묶음, `main`에 없는 정식 태그, 이미 낸 릴리스 다시 만들기, 커밋하지 않은 수정, `mod-test.sh` 실패, 다른 키로 서명한 앱·모드 | `develop`에 있음(#4, 2026-11-20). `v*` 태그를 아직 달지 않아 GitHub에서 한 번도 돌지 않았습니다 |
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

브랜치 보호와 저장소 설정은 GitHub 쪽에 남으므로, 바꾸면 이 표의 "상태"도 고칩니다. 2·3을 적용할지는 [`open-issue.md`](open-issue.md) OI-4에서 관리합니다.
