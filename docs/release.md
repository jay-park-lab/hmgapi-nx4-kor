# 배포: GitHub Actions와 배포 키

`v<판>`·`v<판>-beta.<n>` 태그를 올리면 [`.github/workflows/release.yml`](../.github/workflows/release.yml)이 서명한 모드 zip과 USB 묶음을 만들어 GitHub 릴리스에 올립니다. 배포 키는 GitHub의 `production` 환경 secret에 두고, 그 환경을 쓰는 job은 관리자가 승인해야 돕니다. 브랜치와 태그 규칙은 [`git-flow.md`](git-flow.md)를 따릅니다.

## 흐름

1. 태그를 올립니다(`git-flow.md`의 릴리스·핫픽스 흐름). `-beta.<n>` 태그는 시험판(prerelease)이 됩니다.
2. Actions의 release 실행이 `production` 승인을 기다립니다. 실행 화면의 **Review deployments**에서 아래 "승인하기 전에"를 확인하고 승인합니다.
3. `build` job(배포 키 있음, 저장소 읽기만)이 돕니다.
   - 태그의 판이 `mod/mod.json` `version`, `app/AndroidManifest.xml` `versionName`과 같은지 봅니다(`-beta.<n>`은 빼고 비교).
   - 정식 태그의 커밋이 `main`에 있는지, 베타 태그의 커밋이 `release/` 브랜치나 `main`에 있는지 봅니다.
   - JDK 21(Temurin), Android SDK(`build-tools;37.0.0`, `platforms;android-19`), HMG-API `v1.1.0-rc.4`(커밋 `31d781b`), mksh를 준비합니다.
   - `sh tests/mod-test.sh`를 HMG-API 빌드·엔진 시험까지 돌립니다. 이때는 배포 키를 아직 꺼내지 않았고, 시험은 임시 키를 씁니다.
   - 배포 키를 러너 임시 폴더의 파일로 꺼내고(umask 077), `scripts/build-app.sh`, `scripts/build.sh`를 돌립니다.
   - 앱 서명 인증서가 `.github/release/app-cert.sha256`과 같은지, 모드가 `.github/release/mod.key.pub`의 UUID로 서명됐는지 봅니다. 하나라도 다르면 멈춥니다.
   - 키 파일을 지우고, 두 zip만 다음 job에 넘깁니다.
4. `publish` job(배포 키 없음, 저장소 쓰기)이 릴리스를 만들어 두 파일을 올립니다. 릴리스 글에는 파일 설명, 모드 UUID, 앱 서명 인증서 SHA-256, busybox를 넣었는지, 소스 커밋, SHA-256, 자동 변경 목록이 들어갑니다. 같은 태그로 다시 돌리면 이미 있는 릴리스의 파일만 바꿉니다.

PC에서 `.env.local`의 키로 `sh scripts/build.sh`를 돌려 만드는 길도 그대로 있습니다(`git-flow.md` 규칙 7).

## 키와 값

| 이름 | 종류 | 내용 | 로컬 파일 |
|---|---|---|---|
| `NX4_APP_KEYSTORE_B64` | `production` 환경 secret | 상태 화면 앱 키스토어를 base64로 | `.keys/release.keystore` |
| `NX4_APP_KEY_PASS` | `production` 환경 secret | 키스토어 비밀번호 | `.keys/pass` |
| `NX4_MOD_KEY` | `production` 환경 secret | HMG-API 모드 작성자 키(비밀 키) | `.keys/mod.key` |
| `.github/release/mod.key.pub` | 커밋한 파일 | 모드 작성자 공개 키 | `.keys/mod.key.pub` |
| `.github/release/app-cert.sha256` | 커밋한 파일 | 앱 서명 인증서 SHA-256 | (키스토어에서 뽑은 값) |
| `NX4_PKG_ZIP_URL` | 저장소 변수(선택) | busybox를 꺼낼 Korea Projection 패키지 zip 주소 | — |

로컬 키는 저장소 맨 위 `.keys/`(git 제외, `.gitignore`)에 둡니다. `.env.local`의 `NX4_APP_KEYS`는 그 폴더, `NX4_MOD_KEY`는 `.keys/mod.key`를 절대 경로로 가리킵니다.

### 공개 키와 앱 인증서를 커밋하는 까닭

`Signing.publicOf`는 비밀 키 옆의 `mod.key.pub`를 읽습니다. 공개 키는 비밀이 아니고, 배포한 모드의 `META-HMGAPI/manifest.json`에도 그대로 들어 있습니다. 그래서 secret이나 변수가 아니라 저장소에 커밋합니다.

- 모드 UUID(`5464204c-59b9-8212-b3c1-be16955702d7`)는 공개 키에서 나옵니다. 커밋해 두면 그 값이 PR 리뷰를 거쳐야만 바뀝니다. secret을 다른 키로 잘못 바꿔도 서명 확인에서 멈추고, UUID가 다른 모드는 나가지 않습니다. 비밀 키와 공개 키가 짝이 아니면 HMG-API `mkmodpkg.sh`의 서명 확인에서도 멈춥니다.
- 앱 인증서 SHA-256도 같은 까닭으로 커밋합니다. Android는 같은 키로 서명한 앱만 업데이트로 받습니다. `build-app.sh`는 키가 없으면 새 키를 만들어 버리므로, secret이 비었거나 다른 키스토어이면 워크플로가 멈춥니다.
- 둘 다 secret이나 변수로 두면 쓰기 권한만 있어도 기록 없이 바꿀 수 있어, 확인하는 값으로 쓸 수 없습니다.

값 확인:

```sh
java -cp <HMGAPI_SRC>/out/engine-host hmgapi.engine.Signing uuid .github/release/mod.key.pub
keytool -list -v -keystore .keys/release.keystore -storepass:file .keys/pass -alias nx4kor | grep SHA256:
```

### secret 넣기 (처음 한 번, 키를 바꿀 때)

저장소 맨 위에서, 아래 "production 환경"을 먼저 만든 뒤에 칩니다. 반드시 `--env production`을 붙여 **환경 secret**으로 넣습니다(저장소 secret으로 넣지 않습니다. 까닭은 아래 "위험").

```sh
base64 -i .keys/release.keystore | gh secret set NX4_APP_KEYSTORE_B64 --env production
```

```sh
gh secret set NX4_APP_KEY_PASS --env production < .keys/pass
```

```sh
gh secret set NX4_MOD_KEY --env production < .keys/mod.key
```

```sh
gh secret list --env production
```

- `base64 -i`는 macOS 꼴입니다(한 줄로 냅니다). 리눅스에서는 `base64 -w0 .keys/release.keystore`.
- secret은 읽어 올 수 없으므로, 제대로 넣었는지는 다음 베타 태그 실행의 "앱 서명 인증서 확인", "모드 서명 확인" step으로 봅니다.

### busybox (선택)

`scripts/build.sh`는 `NX4_PKG_ZIP`이 없으면 busybox를 넣지 않습니다(내비의 `/system/bin/busybox`를 씁니다). 지금 PC 빌드도 넣지 않습니다. CI에서 넣으려면 저장소 변수에 Korea Projection 릴리스의 패키지 zip 주소를 둡니다.

```sh
gh variable set NX4_PKG_ZIP_URL --body https://github.com/StopDragon/korea-projection/releases/download/v1.7.4/korea.projection-1.7.4.zip
```

- 워크플로는 그 zip의 `bin/busybox`가 [`NOTICE.md`](../NOTICE.md#busybox-gpl-20)에 적은 SHA-256과 같을 때만 씁니다. 라이선스 안내(`bin/busybox-LICENSE.txt`)가 없으면 `build.sh`가 멈춥니다.
- 위 주소의 zip 안을 이 문서를 쓰며 열어 보지는 않았습니다. 처음에는 베타 태그로 확인합니다.
- HMG-API USB 묶음(`HMGAPI_USB_ZIP`)은 CI에서 넣지 않습니다. USB 묶음에는 NX4 KOR만 들어가므로, HMG-API가 없는 차에는 HMG-API를 먼저 설치해야 합니다.

## production 환경 (처음 한 번, 저장소 관리자)

워크플로가 처음 돌기 전에 만듭니다. 없는 환경을 job이 쓰면 GitHub이 보호 규칙 없이 만들어 버립니다.

1. 내 GitHub 사용자 id:

   ```sh
   gh api users/parkjoos --jq .id
   ```

2. 환경 만들기: 필수 리뷰어, 정해 둔 태그에서만 배포:

   ```sh
   gh api -X PUT repos/jay-park-lab/hmgapi-nx4-kor/environments/production --input - <<'EOF'
   {"reviewers": [{"type": "User", "id": <위의 id>}], "prevent_self_review": false, "deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}
   EOF
   ```

3. 배포할 수 있는 ref를 `v*` 태그로 한정:

   ```sh
   gh api -X POST repos/jay-park-lab/hmgapi-nx4-kor/environments/production/deployment-branch-policies -f name='v*' -f type=tag
   ```

- 관리자 혼자면 `prevent_self_review`는 `false`여야 스스로 승인할 수 있습니다. 쓰기 권한자가 늘면 다른 리뷰어를 더하고 `true`로 바꿉니다.
- 화면에서는 Settings > Environments > production. "Required reviewers", "Deployment branches and tags: Selected branches and tags"에 태그 규칙 `v*`가 보여야 합니다.

### `v*` 태그 보호 (처음 한 번, 저장소 관리자)

관리자만 `v*` 태그를 만들고, 누구도 옮기거나 지우지 못하게 합니다(`git-flow.md` 규칙 6). 관리자는 bypass로 만들 수 있습니다.

```sh
gh api -X POST repos/jay-park-lab/hmgapi-nx4-kor/rulesets --input - <<'EOF'
{"name": "release tags", "target": "tag", "enforcement": "active", "conditions": {"ref_name": {"include": ["refs/tags/v*"], "exclude": []}}, "rules": [{"type": "creation"}, {"type": "update"}, {"type": "deletion"}], "bypass_actors": [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]}
EOF
```

`actor_id` 5는 저장소 Admin 역할입니다. 만든 뒤 Settings > Rules > Rulesets > release tags의 Bypass list에 "Repository admin"이 보이는지 확인합니다.

## 키 백업

GitHub secret은 넣기만 되고 읽어 올 수 없습니다. 백업이 아닙니다. 저장소나 조직이 지워지거나, 계정을 잃거나, secret을 덮어쓰면 되찾을 길이 없습니다. `.keys/`도 git에 들어가지 않으므로 푸시나 워크트리로 남지 않습니다.

- `.keys/`의 네 파일(`release.keystore`, `pass`, `mod.key`, `mod.key.pub`)을 오프라인에 두 곳 이상 백업합니다. 예: 암호화한 USB, 비밀번호 관리자의 보안 메모나 첨부. 비밀번호(`pass`)는 키스토어와 같은 곳에만 두지 않습니다.
- 잃으면:
  - 앱 키를 잃으면 차가 상태 화면 앱 업데이트를 받지 않습니다. 사용자가 앱을 지우고 다시 설치해야 합니다.
  - 모드 키를 잃으면 HMG-API가 업데이트를 받지 않습니다. 모드를 지우고 다시 설치해야 하고, 새 키라서 UUID도 바뀝니다.
- 백업을 바꾸면(키 교체) secret, `.github/release/`의 두 값, 이 문서의 UUID를 함께 바꿉니다.

## 위험: 쓰기 권한자의 secret 유출

GitHub은 로그에서 secret 값을 가리지만, `build` job에서 도는 코드는 secret과 키 파일을 그대로 읽을 수 있습니다. base64로 바꾸거나 밖으로 보내면 가림도 소용없습니다. 그래서 **그 job에서 코드를 돌릴 수 있는 사람은 키를 가져갈 수 있다**고 보고 막습니다.

| 길 | 막는 것 |
|---|---|
| 아무 브랜치에 워크플로를 새로 올려 저장소 secret을 읽음 | 키를 저장소 secret이 아니라 **환경 secret**으로만 둡니다. 환경 secret은 `production`을 쓰고 그 규칙을 통과한 job만 받습니다 |
| 다른 브랜치나 PR의 워크플로가 `environment: production`을 씀 | 환경의 배포 ref를 `v*` 태그로 한정, 필수 리뷰어 승인 |
| 쓰기 권한자가 `release.yml`이나 job이 부르는 스크립트(`scripts/`, `tests/`)를 바꾼 커밋에 `v*` 태그를 닮 | 태그 ruleset(관리자만 `v*` 태그), 필수 리뷰어. 태그 push로 도는 워크플로는 **태그의 커밋에 있는 `release.yml`**입니다 |
| 포크의 PR | 포크 PR에는 secret이 가지 않습니다. 이 저장소는 `pull_request_target`을 쓰지 않습니다 |
| job이 받아 돌리는 남의 코드(액션, HMG-API) | 액션과 HMG-API를 커밋 SHA로 고정합니다. busybox zip은 돌리지 않고, 파일의 SHA-256을 확인합니다 |
| 키를 가진 job의 토큰으로 저장소를 바꿈 | `build`의 토큰은 읽기만, 쓰기 토큰은 키가 없는 `publish`에만 둡니다 |

### 승인하기 전에

승인은 "이 커밋의 코드에 배포 키를 맡긴다"는 뜻입니다.

- 태그가 기대한 커밋인지 봅니다. 정식 태그는 `main`의 merge commit, 베타 태그는 `release/<판>`의 끝입니다.
- 지난 릴리스 태그 이후 `.github/`, `scripts/`, `tests/`, HMG-API 고정 커밋(`HMGAPI_COMMIT`)이 바뀌었으면, 그 변경이 리뷰를 거쳐 합친 것인지 봅니다.

  ```sh
  git diff --stat <지난 태그> <이번 태그> -- .github scripts tests
  ```

- 모르는 태그나 내가 달지 않은 태그면 승인하지 않고 실행을 취소합니다.

### 남는 위험

- 관리자(태그를 만들고 승인할 수 있는 사람)는 키를 가져갈 수 있습니다. 관리자와 쓰기 권한자는 최소로 둡니다.
- 키가 샜다고 의심되면 secret을 바로 지우고(`gh secret delete <이름> --env production`) 원인을 찾습니다. 키를 바꾸면 위 "잃으면"처럼 사용자가 다시 설치해야 하므로, 막는 쪽이 중요합니다.

## 바꿀 때

- HMG-API 판을 올리면 `release.yml`의 `HMGAPI_COMMIT`(태그가 가리키는 커밋 SHA)과 주석, 이 문서, `mod/mod.json` `hmgapi`를 함께 바꿉니다.
- 액션을 올릴 때도 태그가 아니라 커밋 SHA로 적고, 뒤에 판을 주석으로 남깁니다.
- 러너는 `ubuntu-24.04`로 고정했습니다. Android SDK는 빈 폴더에 정한 판만 받으므로 러너 이미지가 바뀌어도 같은 도구로 만듭니다.
