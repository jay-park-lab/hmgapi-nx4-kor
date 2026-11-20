# 배포: GitHub Actions와 배포 키

`v<판>`·`v<판>-beta.<n>` 태그를 올리면 [`.github/workflows/release.yml`](../.github/workflows/release.yml)이 서명한 모드 zip과 USB 묶음을 만들어 GitHub 릴리스에 올립니다. 배포 키는 GitHub의 `production` 환경 secret에 두고, 그 환경을 쓰는 job은 관리자가 승인해야 돕니다. 브랜치와 태그 규칙은 [`git-flow.md`](git-flow.md)를 따릅니다.

## 흐름

1. 태그를 올립니다(`git-flow.md`의 릴리스·핫픽스 흐름). `-beta.<n>` 태그는 시험판(prerelease)이 됩니다.
2. `check` job(배포 키 없음, 승인 전)이 돕니다. 하나라도 실패하면 승인을 묻지 않고 끝납니다.
   - 태그의 판이 `mod/mod.json` `version`, `app/AndroidManifest.xml` `versionName`과 같은지 봅니다(`-beta.<n>`은 빼고 비교).
   - 정식 태그의 커밋이 `main`에 있는지, 베타 태그의 커밋이 `release/` 브랜치나 `main`에 있는지 봅니다.
   - 같은 태그의 릴리스가 이미 있는지 봅니다(아래 "같은 태그로 다시 만들지 않습니다").
   - JDK 21(Temurin), HMG-API `v1.1.0-rc.4`(커밋 `31d781b`), mksh를 준비해 `sh tests/mod-test.sh`를 빌드·HMG-API 엔진 시험까지 돌립니다. 시험은 임시 키를 쓰고, 배포 키를 쓰는 job과 다른 러너에서 돕니다.
3. Actions의 release 실행이 `production` 승인을 기다립니다. 실행 화면의 **Review deployments**에서 아래 "승인하기 전에"를 확인하고 승인합니다.
4. `build` job(배포 키 있음, 저장소 읽기만)이 돕니다.
   - JDK 21, Android SDK(`build-tools;37.0.0`, `platforms;android-19`), HMG-API 소스를 준비합니다.
   - 키를 꺼내기 전에 HMG-API USB 묶음을 받아 확인합니다(아래 "HMG-API를 USB 묶음에 함께").
   - 배포 키를 러너 임시 폴더의 파일로 꺼내고(umask 077), `scripts/build-app.sh`, `scripts/build.sh`를 돌립니다.
   - 다음을 봅니다. 하나라도 다르면 멈춥니다.
     - 앱 서명 인증서가 `.github/release/app-cert.sha256`과 같은지
     - 모드가 `.github/release/mod.key.pub`의 UUID로 서명됐는지
     - USB 묶음의 맨 위 설치기가 `usb/troubleShooter`이고, HMG-API 설치기(`NX4/hmgapi/troubleShooter`)와 같은 판의 payload가 함께 들었는지
   - 키 파일을 지우고, 두 zip만 다음 job에 넘깁니다.
5. `publish` job(배포 키 없음, 저장소 쓰기)이 릴리스를 만들어 두 파일을 올립니다. 릴리스 글에는 다음이 들어갑니다.
   - 파일 설명
   - 모드 UUID, 앱 서명 인증서 SHA-256
   - busybox를 넣었는지
   - 함께 넣은 HMG-API 판과 그 대응 소스
   - 소스 커밋
   - 두 파일의 SHA-256
   - 자동 변경 목록

PC에서 `.env.local`의 키로 `sh scripts/build.sh`를 돌려 만드는 길도 그대로 있습니다(`git-flow.md` 규칙 7).

### 같은 태그로 다시 만들지 않습니다

묶음은 같은 커밋·같은 키로 만들어도 매번 다릅니다. HMG-API의 서명(ECDSA)이 만들 때마다 달라 모드 zip이 바뀌고, 그것을 담은 USB 묶음도 바뀝니다. 그래서 같은 태그로 다시 만들면, 이미 받은 사람의 파일이나 릴리스 글의 SHA-256과 맞지 않게 됩니다.

- 릴리스가 이미 있으면 `check`와 `publish`가 멈춥니다. 고쳐야 하면 다음 번호의 태그를 답니다(`v<판>-beta.<n+1>`, 정식이면 `hotfix/`의 다음 판. `git-flow.md` 규칙 6).
- 올리다 실패해 파일이 빠진 릴리스가 남았으면, 그 릴리스를 GitHub에서 지운 뒤(태그는 두고) 실패한 실행을 다시 돌립니다.

## 키와 값

| 이름 | 종류 | 내용 | 로컬 파일 |
|---|---|---|---|
| `NX4_APP_KEYSTORE_B64` | `production` 환경 secret | 상태 화면 앱 키스토어를 base64로 | `<NX4_APP_KEYS>/release.keystore` |
| `NX4_APP_KEY_PASS` | `production` 환경 secret | 키스토어 비밀번호 | `<NX4_APP_KEYS>/pass` |
| `NX4_MOD_KEY` | `production` 환경 secret | HMG-API 모드 작성자 키(비밀 키) | `<NX4_MOD_KEY>` |
| `.github/release/mod.key.pub` | 커밋한 파일 | 모드 작성자 공개 키 | `<NX4_MOD_KEY>.pub` |
| `.github/release/app-cert.sha256` | 커밋한 파일 | 앱 서명 인증서 SHA-256 | (키스토어에서 뽑은 값) |
| `NX4_PKG_ZIP_URL` | 저장소 변수(선택) | busybox를 꺼낼 Korea Projection 패키지 zip 주소 | — |

`<NX4_APP_KEYS>`, `<NX4_MOD_KEY>`는 `.env.local`에 적은 경로입니다. 로컬 키는 저장소 밖에 둡니다(아래 "키 백업").

### 공개 키와 앱 인증서를 커밋하는 까닭

`Signing.publicOf`는 비밀 키 옆의 `mod.key.pub`를 읽습니다. 공개 키는 비밀이 아니고, 배포한 모드의 `META-HMGAPI/manifest.json`에도 그대로 들어 있습니다. 그래서 secret이나 변수가 아니라 저장소에 커밋합니다.

- 모드 UUID(`5464204c-59b9-8212-b3c1-be16955702d7`)는 공개 키에서 나옵니다. 커밋해 두면 그 값이 PR 리뷰를 거쳐야만 바뀝니다.
  - secret을 다른 키로 잘못 바꿔도 서명 확인에서 멈추므로, UUID가 다른 모드는 나가지 않습니다.
  - 비밀 키와 공개 키가 짝이 아니면 HMG-API `mkmodpkg.sh`의 서명 확인에서도 멈춥니다.
- 앱 인증서 SHA-256도 같은 까닭으로 커밋합니다. Android는 같은 키로 서명한 앱만 업데이트로 받습니다. `build-app.sh`는 키가 없으면 새 키를 만들어 버리므로, secret이 비었거나 다른 키스토어이면 워크플로가 멈춥니다.
- 둘 다 secret이나 변수로 두면 쓰기 권한만 있어도 기록 없이 바꿀 수 있습니다. 그러면 확인 기준으로 쓸 수 없습니다.

`app-cert.sha256`은 콜론 없는 소문자 64자 한 줄로 적습니다. `keytool` 꼴(`8B:3E:...`)로 붙여 넣어도 워크플로는 콜론과 대소문자를 지우고 비교합니다. 값 확인:

```sh
java -cp <HMGAPI_SRC>/out/engine-host hmgapi.engine.Signing uuid .github/release/mod.key.pub
```

```sh
<ANDROID_HOME>/build-tools/37.0.0/apksigner verify --print-certs mod/app/NX4KOR.apk
```

`apksigner`의 `certificate SHA-256 digest:` 값이 `app-cert.sha256`과 같아야 합니다(배포용 키로 만든 APK에서).

### secret 넣기 (처음 한 번, 키를 바꿀 때)

저장소 맨 위에서, 아래 "production 환경"을 먼저 만든 뒤에 칩니다. 반드시 `--env production`을 붙여 **환경 secret**으로 넣습니다. 저장소 secret으로 넣지 않습니다(까닭은 아래 "위험").

```sh
base64 -i <NX4_APP_KEYS>/release.keystore | gh secret set NX4_APP_KEYSTORE_B64 --env production
```

```sh
gh secret set NX4_APP_KEY_PASS --env production < <NX4_APP_KEYS>/pass
```

```sh
gh secret set NX4_MOD_KEY --env production < <NX4_MOD_KEY>
```

```sh
gh secret list --env production
```

- `base64 -i`는 macOS 꼴입니다(한 줄로 냅니다). 리눅스에서는 `base64 -w0 <NX4_APP_KEYS>/release.keystore`.
- secret은 읽어 올 수 없습니다. 제대로 넣었는지는 다음 베타 태그 실행의 "앱 서명 인증서 확인", "모드 서명 확인" step으로 봅니다.

### busybox (선택)

`scripts/build.sh`는 `NX4_PKG_ZIP`이 없으면 busybox를 넣지 않습니다. 그때는 내비의 `/system/bin/busybox`를 씁니다. 지금 PC 빌드도 넣지 않습니다. CI에서 넣으려면 저장소 변수에 Korea Projection 릴리스의 패키지 zip 주소를 둡니다.

```sh
gh variable set NX4_PKG_ZIP_URL --body https://github.com/StopDragon/korea-projection/releases/download/v1.7.4/korea.projection-1.7.4.zip
```

- 워크플로는 그 zip의 `bin/busybox`가 [`NOTICE.md`](../NOTICE.md#busybox-gpl-20)에 적은 SHA-256과 같을 때만 씁니다. 라이선스 안내(`bin/busybox-LICENSE.txt`)가 없으면 `build.sh`가 멈춥니다.
- 위 주소의 zip 안을 이 문서를 쓰며 열어 보지는 않았습니다. 처음에는 베타 태그로 확인합니다.

### HMG-API를 USB 묶음에 함께

릴리스의 USB 묶음에는 HMG-API USB 묶음이 함께 들어갑니다. 그래서 HMG-API가 없는 차도 USB 하나로 설치합니다.

- **차에서:** 첫 Update OTA에서 NX4 KOR 설치기가 HMG-API가 없는 것을 보고 HMG-API 설치기(`NX4/hmgapi/troubleShooter`)를 대신 돌립니다. HMG-API가 설치되고 재부팅되면 같은 USB로 한 번 더 누릅니다. HMG-API가 이미 있으면 한 번에 NX4 KOR를 설치합니다(`usb/troubleShooter`).
- **HMG-API 앱으로 모드를 넣는 길을 쓰지 않는 까닭:** HMG-API 문서의 방법(USB `HMGAPI/updates/`에 모드 zip, 앱의 "Check USB updates")은 HMG-API 앱을 열어야 합니다. 그런데 HMG-API에 NX4 map이 없어 처음에는 앱 타일이 생기지 않습니다(NEMESIS나 adb가 있어야 엽니다).
- **어떻게 넣나:** 워크플로 맨 위 `HMGAPI_USB_URL`(HMG-API 릴리스의 `hmgapi-<판>-usb.zip`)을 받습니다. 다음 둘이 맞을 때만 `HMGAPI_USB_ZIP`으로 `scripts/build.sh`에 넘깁니다.
  - 파일의 SHA-256이 `HMGAPI_USB_SHA256`과 같은지
  - 그 안의 `HMGAPI/install/payload/VERSION`이 `HMGAPI_COMMIT` 소스의 판(`Engine.java`의 `HMGAPI_VERSION`)과 같은지
- **배포 키를 가진 job이 받는 까닭:** `build.sh`가 USB 묶음을 만들 때 넣어야 해서 `build` job에서 받습니다. 키를 꺼내기 전에 받고, 그 안의 것은 실행하지 않습니다. 풀어서 USB 묶음에 옮겨 담기만 합니다.
- **라이선스:** HMG-API(AGPL-3.0)를 고치지 않고 그대로 함께 배포합니다. `build.sh`가 USB 맨 위 `HMGAPI-SOURCE.txt`에 판과 대응 소스(태그)를 적고, 릴리스 글에도 적습니다.
- **PC 빌드:** `.env.local`의 `HMGAPI_USB_ZIP`이 없으면 NX4 KOR만 넣습니다.

## production 환경 (처음 한 번, 저장소 관리자)

워크플로가 처음 돌기 전에 만듭니다. 없는 환경을 job이 쓰면, GitHub이 보호 규칙 없는 환경을 저절로 만듭니다.

1. 내 GitHub 사용자 id:

   ```sh
   gh api users/parkjoos --jq .id
   ```

2. 환경 만들기(필수 리뷰어를 두고, 정해 둔 태그에서만 배포):

   ```sh
   gh api -X PUT repos/jay-park-lab/hmgapi-nx4-kor/environments/production --input - <<'EOF'
   {"reviewers": [{"type": "User", "id": <위의 id>}], "prevent_self_review": false, "deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}
   EOF
   ```

3. 배포할 수 있는 ref를 `v*` 태그로 한정:

   ```sh
   gh api -X POST repos/jay-park-lab/hmgapi-nx4-kor/environments/production/deployment-branch-policies -f name='v*' -f type=tag
   ```

- 관리자 혼자면 `prevent_self_review`가 `false`여야 스스로 승인할 수 있습니다. 쓰기 권한자가 늘면 다른 리뷰어를 더하고 `true`로 바꿉니다.
- 화면에서는 Settings > Environments > production에서 확인합니다. 다음 두 가지가 보여야 합니다.
  - "Required reviewers"
  - "Deployment branches and tags: Selected branches and tags"의 태그 규칙 `v*`

### `v*` 태그 보호 (처음 한 번, 저장소 관리자)

`git-flow.md` 규칙 6에 맞춰 ruleset을 둘 만듭니다. ruleset의 bypass는 그 ruleset의 모든 규칙에 걸리므로, 만들기와 옮기기·지우기를 나눠야 관리자에게도 옮기기·지우기를 막을 수 있습니다.

1. 만들기: 관리자만(Admin bypass).

   ```sh
   gh api -X POST repos/jay-park-lab/hmgapi-nx4-kor/rulesets --input - <<'EOF'
   {"name": "release tags: create", "target": "tag", "enforcement": "active", "conditions": {"ref_name": {"include": ["refs/tags/v*"], "exclude": []}}, "rules": [{"type": "creation"}], "bypass_actors": [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]}
   EOF
   ```

2. 옮기기·지우기: 누구도 못 함(bypass 없음).

   ```sh
   gh api -X POST repos/jay-park-lab/hmgapi-nx4-kor/rulesets --input - <<'EOF'
   {"name": "release tags: immutable", "target": "tag", "enforcement": "active", "conditions": {"ref_name": {"include": ["refs/tags/v*"], "exclude": []}}, "rules": [{"type": "update"}, {"type": "deletion"}], "bypass_actors": []}
   EOF
   ```

- `actor_id` 5는 저장소 Admin 역할입니다. 만든 뒤 Settings > Rules > Rulesets에서 두 ruleset을 확인합니다.
  - "release tags: create": Bypass list에 "Repository admin"
  - "release tags: immutable": Bypass list가 비어 있음
- 태그를 정말 지워야 하면(예: 실수로 단 태그) 관리자가 "release tags: immutable"을 잠시 끄고 지운 뒤 다시 켭니다. 그 일은 PR이나 이슈에 남깁니다.

## 키 백업

로컬 배포 키는 저장소 밖(`.env.local`이 가리키는 곳)에 둡니다. 키를 잃으면 차의 모드·앱을 업데이트할 수 없습니다.

GitHub secret은 넣기만 되고 읽어 올 수 없으므로 백업이 아닙니다. 저장소나 조직이 지워지거나, 계정을 잃거나, secret을 덮어쓰면 되찾을 길이 없습니다.

- 키 폴더의 네 파일(`release.keystore`, `pass`, `mod.key`, `mod.key.pub`)을 오프라인에 두 곳 이상 백업합니다. 예: 암호화한 USB, 비밀번호 관리자의 보안 메모나 첨부. 비밀번호(`pass`)는 키스토어와 같은 곳에만 두지 않습니다.
- 잃으면:
  - 앱 키를 잃으면 차가 상태 화면 앱 업데이트를 받지 않습니다. 사용자가 앱을 지우고 다시 설치해야 합니다.
  - 모드 키를 잃으면 HMG-API가 업데이트를 받지 않습니다. 모드를 지우고 다시 설치해야 하고, 새 키라서 UUID도 바뀝니다.
- 키를 바꾸면 secret, `.github/release/`의 두 값, 이 문서의 UUID를 함께 바꿉니다.

## 위험: 쓰기 권한자의 secret 유출

GitHub은 로그에서 secret 값을 가리지만, `build` job에서 도는 코드는 secret과 키 파일을 그대로 읽을 수 있습니다. base64로 바꾸거나 밖으로 보내면 가림도 소용없습니다. 그래서 **그 job에서 코드를 돌릴 수 있는 사람은 키를 가져갈 수 있다**고 보고 막습니다.

| 길 | 막는 것 |
|---|---|
| 아무 브랜치에 워크플로를 새로 올려 저장소 secret을 읽음 | 키를 저장소 secret이 아니라 **환경 secret**으로만 둡니다. 환경 secret은 `production`을 쓰고 그 규칙을 통과한 job만 받습니다 |
| 다른 브랜치나 PR의 워크플로가 `environment: production`을 씀 | 환경의 배포 ref를 `v*` 태그로 한정합니다. 필수 리뷰어가 승인해야 합니다 |
| 쓰기 권한자가 `release.yml`이나 job이 부르는 스크립트(`scripts/`, HMG-API 고정 커밋)를 바꾼 커밋에 `v*` 태그를 닮 | 태그 ruleset(관리자만 `v*` 태그를 만듦), 필수 리뷰어. 태그 push로 도는 워크플로는 **태그의 커밋에 있는 `release.yml`**입니다 |
| 모드 폴더의 `build.sh`: HMG-API `mkmodpkg.sh`가 서명 키를 받은 채로 실행하고, 패키지에서는 빼서 결과물에 남지 않음 | 이 모드는 그 파일을 쓰지 않습니다. `scripts/build.sh`가 `mod/build.sh`를 보면 만들지 않고 멈춥니다(`check`의 시험 빌드에서도 멈춥니다). 이 확인을 없애는 변경은 `scripts/`에 있으므로 아래 diff에 보입니다 |
| 시험 코드(`tests/`)가 키를 읽음 | 시험은 키가 없는 `check` job에서, 다른 러너로 돕니다. `build` job은 시험을 돌리지 않습니다 |
| 포크의 PR | 포크 PR에는 secret이 가지 않습니다. 이 저장소는 `pull_request_target`을 쓰지 않습니다 |
| job이 받아 돌리는 남의 코드(액션, HMG-API) | 액션과 HMG-API 소스를 커밋 SHA로 고정합니다. busybox zip과 HMG-API USB 묶음은 돌리지 않고, 파일의 SHA-256을 확인합니다. HMG-API USB 묶음은 키를 꺼내기 전에 받습니다 |
| 키를 가진 job의 토큰으로 저장소를 바꿈 | `build`의 토큰은 읽기만 합니다. 쓰기 토큰은 키가 없는 `publish`에만 둡니다 |

### 승인하기 전에

승인은 "이 커밋의 코드에 배포 키를 맡긴다"는 뜻입니다.

- `check` job이 통과했는지 봅니다. 승인 요청은 `check`가 통과한 태그에만 뜹니다.
- 태그가 기대한 커밋인지 봅니다. 정식 태그는 `main`의 merge commit, 베타 태그는 `release/<판>`의 끝입니다.
- 지난 릴리스 태그 이후 `build` job에서 도는 코드가 바뀌었으면, 그 변경이 리뷰를 거쳐 합친 것인지 봅니다. 대상은 `.github/`, `scripts/`, `mod/build.sh`(있으면 안 됨), HMG-API 고정값(`HMGAPI_COMMIT`, `HMGAPI_USB_URL`, `HMGAPI_USB_SHA256`)입니다.

  ```sh
  git diff --stat <지난 태그> <이번 태그> -- .github scripts mod/build.sh
  ```

- 모르는 태그나 내가 달지 않은 태그면 승인하지 않고 실행을 취소합니다.

### 남는 위험

- 관리자(태그를 만들고 승인할 수 있는 사람)는 키를 가져갈 수 있습니다. 관리자와 쓰기 권한자는 최소로 둡니다.
- 키가 샜다고 의심되면 secret을 바로 지우고(`gh secret delete <이름> --env production`) 원인을 찾습니다. 키를 바꾸면 위 "잃으면"처럼 사용자가 다시 설치해야 하므로, 막는 쪽이 중요합니다.

## 바꿀 때

- HMG-API 판을 올리면 다음을 함께 바꿉니다.
  - `release.yml`의 `HMGAPI_COMMIT`(태그가 가리키는 커밋 SHA)과 주석
  - `release.yml`의 `HMGAPI_USB_URL`, `HMGAPI_USB_SHA256`(같은 판의 `hmgapi-<판>-usb.zip`)
  - 이 문서
  - `mod/mod.json` `hmgapi`
- `HMGAPI_USB_SHA256`은 HMG-API 릴리스의 `SHA256SUMS`나 GitHub이 기록한 파일 digest에서 읽습니다. 받은 파일로 `shasum -a 256`을 돌려 같은지도 봅니다.

  ```sh
  gh release view v<판> --repo Open-HMG/HMG-API --json assets --jq '.assets[] | select(.name | endswith("-usb.zip")) | .digest'
  ```
- 액션을 올릴 때도 태그가 아니라 커밋 SHA로 적고, 뒤에 판을 주석으로 남깁니다.
- 러너는 `ubuntu-24.04`로 고정했습니다. Android SDK는 빈 폴더에 정한 판만 받으므로 러너 이미지가 바뀌어도 같은 도구로 만듭니다.
