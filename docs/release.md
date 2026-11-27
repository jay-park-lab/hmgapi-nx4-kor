# 배포: GitHub Actions와 배포 키

`v<판>`·`v<판>-beta.<n>` 태그를 올리면 [`.github/workflows/release.yml`](../.github/workflows/release.yml)이 서명한 모드 zip과 USB 묶음을 만들어 GitHub 릴리스에 올립니다. 배포 키는 GitHub의 `production` 환경 secret에 두고, 그 환경을 쓰는 job은 관리자가 승인해야 돕니다. 브랜치와 태그 규칙은 [`git-flow.md`](git-flow.md)를 따릅니다.

## 흐름

1. 태그를 올립니다(`git-flow.md`의 릴리스·핫픽스 흐름). `-beta.<n>` 태그는 시험판(prerelease)이 됩니다.
2. `check` job(배포 키 없음, 승인 전)이 돕니다. 하나라도 실패하면 승인을 묻지 않고 끝납니다.
   - 태그의 판(`v`를 뗀 것)이 `mod/mod.json` `version`, `app/AndroidManifest.xml` `versionName`과 같은지 봅니다. 베타는 `-beta.<n>`까지 같아야 합니다(`v2.0.4-beta.2` ↔ `2.0.4-beta.2`, `git-flow.md` 규칙 4). 숫자에 앞자리 0이 있는 태그(`v2.0.4-beta.02`)는 받지 않습니다. 2.0.3-beta.1까지는 꼬리를 빼고 비교했습니다.
   - 정식 태그의 커밋이 `main`에 있는지, 베타 태그의 커밋이 `release/` 브랜치나 `main`에 있는지 봅니다.
   - 같은 태그의 릴리스가 이미 있는지 봅니다(아래 "같은 태그로 다시 만들지 않습니다").
   - JDK 21(Temurin), HMG-API `v1.1.0-rc.10`(커밋 `daa0837`), mksh를 준비해 `sh tests/mod-test.sh`를 빌드·HMG-API 엔진 시험까지 돌립니다. 시험은 임시 키를 쓰고, 배포 키를 쓰는 job과 다른 러너에서 돕니다.
     - `ANDROID_HOME`은 비웁니다. 러너 이미지에 미리 있는 SDK(판을 고정하지 않음)로 `hooks.jar`를 만들지 않으려는 것입니다. 그래서 이 job의 빌드 시험은 자리만 채운 `hooks.jar`로 보고, `hooks.jar`를 진짜로 만드는 시험(`scripts/build-hooks.sh`, 덱스 클래스 확인)은 건너뜁니다(`skip hooks.jar 빌드`). 진짜 `hooks.jar`는 4의 `build` job이 고정한 SDK로 만듭니다. PC에서는 `.env.local`의 `ANDROID_HOME`으로 그 시험까지 돕니다.
     - mksh는 러너의 apt로 설치합니다. apt가 멈출 때가 있어(v2.1.0-beta.1 첫 실행이 20분 멈춰 취소됨) 저장소에서 받는 명령(목록 갱신, 내려받기)마다 90초까지만 기다리고, 모두 3번까지 시도합니다. 설치 자체는 끊지 않습니다. 실패하면 어느 명령이 왜 실패했는지 경고로 남습니다. 그래도 이 단계가 실패하면 러너의 apt 저장소 쪽 문제일 수 있으니 실행을 다시 돌립니다(Actions의 **Re-run jobs**, 또는 `gh run rerun <실행 id>`). 릴리스가 아직 올라가지 않았으므로 같은 태그로 다시 돌려도 됩니다.
3. Actions의 release 실행이 `production` 승인을 기다립니다. 실행 화면의 **Review deployments**에서 아래 "승인하기 전에"를 확인하고 승인합니다.
4. `build` job(배포 키 있음, 저장소 읽기만)이 돕니다.
   - JDK 21, Android SDK(`build-tools;37.0.0`, `platforms;android-19`), HMG-API 소스를 준비합니다.
   - 키를 꺼내기 전에 공식 무선 모드(아래 "공식 무선 모드를 USB 묶음에 함께"), HMG-API USB 묶음(아래 "HMG-API를 USB 묶음에 함께")과 busybox(아래 "busybox")를 받아 확인합니다.
   - USB Wi-Fi 동글 드라이버 둘을 `scripts/build-driver.sh`(Docker, 리눅스 x86)로 이 커밋에서 빌드하고, `build.sh`에 `NX4_DRIVERS`로 줍니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48), [`drivers/README.md`](../drivers/README.md)). drivers 워크플로와 같은 방법이라 같은 커밋이면 같은 md5가 나옵니다. 이 단계 때문에 `build` job의 시간 제한은 45분입니다.
   - 배포 키를 러너 임시 폴더의 파일로 꺼내고(umask 077), `scripts/build-app.sh`, `scripts/build.sh`를 돌립니다. `build.sh`는 같은 SDK(`ANDROID_HOME`)로 `scripts/build-hooks.sh`를 불러 `hooks.jar`(한국 카플레이 길안내, [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67))를 만들어 넣습니다.
   - 다음을 봅니다. 하나라도 다르면 멈춥니다.
     - 앱 서명 인증서가 `.github/release/app-cert.sha256`과 같은지
     - 모드가 `.github/release/mod.key.pub`의 UUID로 서명됐는지
     - USB 묶음의 맨 위 설치기가 `usb/troubleShooter`이고, HMG-API 설치기(`NX4/hmgapi/troubleShooter`)와 같은 판의 payload가 함께 들었으며, `HMGAPI/updates`는 없는지
     - busybox와 그 라이선스 안내가 모드(`bin/`)와 USB 맨 위(`BUSYBOX-LICENSE.txt`)에 들었는지
     - 공식 무선 모드 zip(`NX4/wireless/wireless-carplay-aa.zip`)이 `NOTICE.md`의 SHA-256과 같고, 그 `mod.json`과 `WIRELESS-SOURCE.txt`가 들었는지
     - 옛 2.0.x 되돌리기 스크립트(`NX4/legacy-2.0/`)가 들었는지. `build.sh`가 태그 `v2.0.4-beta.1`에서 꺼내므로 `build` job도 저장소를 태그까지 받습니다(`fetch-depth: 0`)
     - 묶음의 nx4-kor(`payload/mod.json`)가 공식 무선 모드와 충돌을 선언하지 않는지(옛 2.0.x 꼴이면 2.1.0 설치기가 멈춤). 그래서 nx4-kor 2.1.0(PR #50)이 합쳐지기 전의 커밋으로는 릴리스를 낼 수 없습니다
     - 묶음의 nx4-kor에 `mod.json`이 선언한 `hooks.jar`가 있고 비지 않았는지(없으면 HMG-API가 이 모드의 훅을 올리지 못함)
     - 동글 드라이버 대응 소스 묶음(`scripts/driver-source.sh`)에 `SOURCE.txt`가 들었는지
     - 묶음의 nx4-kor에 동글 드라이버 둘(`drivers/<드라이버>/bcmdhd.ko`)이 빌드한 그대로 들었고, 받는 USB ID 목록(`drivers/usb-ids.txt`), GPL-2.0 전문(`drivers/COPYING`)과 대응 소스 안내(`drivers/SOURCE.txt`)가 있는지. 두 `.ko`의 md5는 실행 요약에 남깁니다
   - 키 파일을 지우고, 두 zip과 동글 드라이버 대응 소스 묶음(`hmgapi-nx4-kor-<판>-driver-source.tar.gz`)을 다음 job에 넘깁니다.
5. `publish` job(배포 키 없음, 저장소 쓰기)이 릴리스를 만들어 세 파일을 올립니다(두 zip과 동글 드라이버 대응 소스 묶음, GPL-2.0). 릴리스 글에는 다음이 들어갑니다.
   - 파일 설명
   - 모드 UUID, 앱 서명 인증서 SHA-256
   - 넣은 busybox(BusyBox 1.36.1, Alpine `busybox-static-1.36.1-r31`)
   - 필요한 HMG-API 최소 판, 함께 넣은 HMG-API 판과 그 대응 소스(커밋)
   - 함께 넣은 공식 무선 모드 판과 그 대응 소스(태그)
   - 소스 커밋
   - 세 파일의 SHA-256
   - 자동 변경 목록

PC에서 `.env.local`의 키로 `sh scripts/build.sh`를 돌려 만드는 길도 그대로 있습니다(`git-flow.md` 규칙 7).

### 모드가 아닌 릴리스(`src-*`)

동글 드라이버 빌드가 받는 커널 소스 자산은 `v*`가 아닌 태그의 릴리스로 올립니다(지금은 `src-mobis-avnt5w-r9`, [`drivers/README.md`](../drivers/README.md) "커널 소스 자산"). 이 워크플로는 돌지 않고, 시험판·최신 아님으로 두어 "Latest" 릴리스를 가리지 않습니다.

- 모드 릴리스의 자동 변경 목록(`--generate-notes`)은 바로 앞 릴리스부터 셉니다. `src-*` 릴리스 뒤 첫 모드 릴리스(특히 베타)는 그 범위가 `src-*` 태그부터일 수 있으니, 올린 뒤 변경 목록을 보고 모자라면 릴리스 글을 고칩니다.

### 같은 태그로 다시 만들지 않습니다

묶음은 같은 커밋·같은 키로 만들어도 매번 다릅니다. HMG-API의 서명(ECDSA)이 만들 때마다 달라 모드 zip이 바뀌고, 그것을 담은 USB 묶음도 바뀝니다. 그래서 같은 태그로 다시 만들면, 이미 받은 사람의 파일이나 릴리스 글의 SHA-256과 맞지 않게 됩니다.

- 릴리스가 이미 있으면 `check`와 `publish`가 멈춥니다. 고쳐야 하면 `develop`에서 고친 뒤 `release/<판>`에 `develop`을 합치고(`develop`에 다음 판의 작업이 있으면 그 PR만 체리픽, `git-flow.md` 규칙 12) 판을 다음 베타로 올려 `v<판>-beta.<n+1>`을 답니다(`git-flow.md` 규칙 4·12. 예: `v2.0.4-beta.1` 다음이 `v2.0.4-beta.2`). 정식이면 `hotfix/`의 다음 판입니다.
- 올리다 실패해 파일이 빠진 릴리스가 남았으면, 그 릴리스를 GitHub에서 지운 뒤(태그는 두고) 실패한 실행을 다시 돌립니다.

## 키와 값

| 이름 | 종류 | 내용 | 로컬 파일 |
|---|---|---|---|
| `NX4_APP_KEYSTORE_B64` | `production` 환경 secret | 관리 앱 키스토어를 base64로 | `<NX4_APP_KEYS>/release.keystore` |
| `NX4_APP_KEY_PASS` | `production` 환경 secret | 키스토어 비밀번호 | `<NX4_APP_KEYS>/pass` |
| `NX4_MOD_KEY` | `production` 환경 secret | HMG-API 모드 작성자 키(비밀 키) | `<NX4_MOD_KEY>` |
| `.github/release/mod.key.pub` | 커밋한 파일 | 모드 작성자 공개 키 | `<NX4_MOD_KEY>.pub` |
| `.github/release/app-cert.sha256` | 커밋한 파일 | 앱 서명 인증서 SHA-256 | (키스토어에서 뽑은 값) |
| `NX4_BUSYBOX_URL` | 저장소 변수(선택) | busybox 패키지 미러 주소(https, 같은 파일이어야 함. 비우면 Alpine CDN. 아래 "busybox") | `.env.local`의 같은 이름(선택) |

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

### busybox

모드의 스크립트는 busybox로 돕니다. NX4 내비에 `/system/bin/busybox`가 없으면 모드에 함께 넣은 것만 쓸 수 있으므로, 묶음에는 늘 busybox를 넣습니다(내비에 있으면 그것을 먼저 씁니다).

- `scripts/fetch-busybox.sh`가 Alpine Linux 저장소에서 `busybox-static-1.36.1-r31`(armv7) 패키지를 받아 `/bin/busybox.static`만 꺼냅니다. 원본 Korea Projection 릴리스를 거치지 않습니다.
- [`NOTICE.md`](../NOTICE.md#busybox-gpl-20)에 적은 SHA-256 두 개로 확인합니다. 받은 패키지 파일(apk SHA-256)은 풀기 전에, 꺼낸 busybox는 두기 전에 봅니다. 하나라도 다르면 멈춥니다. 받은 것은 실행하지 않습니다.
- 라이선스 안내(`bin/busybox-LICENSE.txt`, USB 맨 위 `BUSYBOX-LICENSE.txt`)도 이 스크립트가 씁니다. 이미 받아 둔 폴더에서도 안내는 매번 다시 씁니다.
- 워크플로는 키를 꺼내기 전에 받고, 만든 USB 묶음에 busybox와 안내가 들었는지 확인합니다.
- PC 빌드(`scripts/build.sh`)는 `NX4_BUSYBOX`를 주지 않으면 먼저 `mod/bin/busybox`(git 제외 파일)를 씁니다. 그 파일은 SHA-256을 확인하지 않으므로, 예전에 둔 것이 있으면 지우고 만듭니다. 없으면 같은 스크립트로 받아 `out/busybox`에 둡니다(curl·인터넷 필요). 인터넷 없이 만들 때는 받아 둔 파일을 `NX4_BUSYBOX`로 가리킵니다. `NX4_BUSYBOX=none`이면 넣지 않습니다(배포용으로 쓰지 않습니다).
- Alpine 3.20은 지원이 끝난 판이라 이 패키지가 더 바뀌지 않을 것으로 봅니다. 저장소에서 내려가 받지 못하면 빌드가 멈춥니다. 그때는 같은 파일을 둔 미러 주소를 씁니다(SHA-256이 같아야 합니다).
  - CI: 저장소 변수 `gh variable set NX4_BUSYBOX_URL --body <https 주소>`. 워크플로의 busybox 단계가 읽습니다. 비워 두면 Alpine CDN입니다.
  - PC: `.env.local`(또는 명령 앞)에 `NX4_BUSYBOX_URL=<https 주소>`.

### HMG-API를 USB 묶음에 함께

릴리스의 USB 묶음에는 HMG-API USB 묶음이 함께 들어갑니다. 그래서 HMG-API가 없는 차도 USB 하나로 설치합니다.

- **차에서:** NX4 KOR 설치기(`usb/troubleShooter`)가 HMG-API를 먼저 봅니다([`design.md`](design.md) "설치·업데이트·지우기").
  - HMG-API가 없거나 최소 판(설치기의 `HMG_MIN`과 스틱의 두 모드 `mod.json` `hmgapi` 중 가장 높은 것)보다 낮으면, 첫 Update OTA에서 HMG-API 설치기(`NX4/hmgapi/troubleShooter`)를 대신 돌립니다. HMG-API가 설치(또는 업데이트)되고 재부팅되면 같은 USB로 한 번 더 누릅니다.
  - 낮은 판일 때는 아무것도 바꾸기 전에 넘기므로, 설치가 거절되어 옛 판만 지워지는 일이 없습니다.
  - 최소 판 이상이면 한 번에 공식 무선 모드와 NX4 KOR를 설치합니다.
- **HMG-API 앱으로 모드를 넣는 길을 쓰지 않는 까닭:** HMG-API 문서의 방법(USB `HMGAPI/updates/`에 모드 zip, 앱의 "Check USB updates")은 HMG-API 앱을 열어야 합니다. 그런데 HMG-API에 NX4 map이 없어 처음에는 앱 타일이 생기지 않습니다(NEMESIS나 adb가 있어야 엽니다).
- **어떻게 넣나:** 워크플로 맨 위 `HMGAPI_USB_URL`(HMG-API 릴리스의 `hmgapi-<판>-usb.zip`)을 받습니다. 다음 둘이 맞을 때만 `HMGAPI_USB_ZIP`으로 `scripts/build.sh`에 넘깁니다.
  - 파일의 SHA-256이 `HMGAPI_USB_SHA256`과 같은지
  - 그 안의 `HMGAPI/install/payload/VERSION`이 `HMGAPI_COMMIT` 소스의 판(`Engine.java`의 `HMGAPI_VERSION`)과 같은지
  - 그 판이 설치기의 최소 판(`HMG_MIN`)과 두 모드(`mod/mod.json`, 공식 무선 모드)의 `hmgapi`를 모두 채우는지(비교는 `usb/troubleShooter`의 `vlt`·`hmg_meets`를 그대로 씁니다). 못 채우면 설치기가 낮은 HMG-API를 올릴 수 없습니다. 릴리스 글의 최소 판은 그중 가장 높은 것입니다
- **싣지 않는 것:** HMG-API 스틱의 `HMGAPI/updates/`(HMG-API 앱용 업데이트와 공식 모드 묶음: `wireless-carplay-aa`, `adb`, `nemesis-shortcut`)와 `NEMESIS.data`는 `build.sh`가 뺍니다. HMG-API 설치기는 `HMGAPI/install`만 씁니다. 공식 무선 모드는 아래 "공식 무선 모드를 USB 묶음에 함께"대로 고정한 판을 따로 넣습니다. 서명 확인 step이 `HMGAPI/updates`가 없는지도 봅니다.
- **배포 키를 가진 job이 받는 까닭:** `build.sh`가 USB 묶음을 만들 때 넣어야 해서 `build` job에서 받습니다. 키를 꺼내기 전에 받고, 그 안의 것은 실행하지 않습니다. 풀어서 USB 묶음에 옮겨 담기만 합니다.
- **라이선스:** HMG-API(AGPL-3.0)에서 설치에 쓰는 것만 고치지 않고 함께 배포합니다. `build.sh`가 USB 맨 위 `HMGAPI-SOURCE.txt`에 판, 대응 소스(태그), 뺀 것을 적습니다. 릴리스 글에는 대응 소스를 `HMGAPI_COMMIT`(커밋)으로 적습니다. 태그는 옮겨질 수 있기 때문입니다.
- **PC 빌드:** `.env.local`의 `HMGAPI_USB_ZIP`이 없으면 NX4 KOR만 넣습니다.
- **어느 HMG-API 판을 쓰나(2026-11-20 결정, [#22](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/22)):** 시험·빌드(`HMGAPI_COMMIT`)와 USB 묶음(`HMGAPI_USB_URL`·`HMGAPI_USB_SHA256`)에 쓰는 HMG-API 판의 규칙입니다.
  - HMG-API 1.1.0 정식판이 나오기 전까지는 그때 나와 있는 가장 새 시험판(`1.1.0-rc.N`)을 따라갑니다.
  - 1.1.0 정식판이 나온 뒤에는 정식 릴리스(GitHub에서 Pre-release가 아닌 판, 판 번호에 `-rc`·`-beta` 같은 꼬리가 없는 판)만 씁니다.
  - HMG-API 파일의 사본을 이 저장소에 두지 않습니다. 늘 HMG-API 릴리스 주소에서 받고 SHA-256으로 확인합니다.
  - 그래서 1.1.0 전에 쓰던 시험판이 지워지면 아래 "HMG-API가 릴리스를 지우면"대로 그때 가장 새 시험판으로 옮깁니다. 지금까지 HMG-API가 지운 것은 시험판(rc.4, rc.5)뿐이고, 정식판 1.0.2는 남아 있습니다.
- **HMG-API가 릴리스를 지우면:** HMG-API는 새 시험판을 내면서 예전 시험판 릴리스를 지웁니다. 2026-11-20에 rc.4 릴리스가 지워져, `v2.0.0-beta.2` 실행이 "HMG-API USB 묶음" step의 다운로드(404)에서 멈췄습니다. 키를 꺼내기 전이라 키는 쓰이지 않았고, 릴리스도 만들지 않았습니다.
  - 고치려면 그때 있는 판으로 `HMGAPI_COMMIT`, `HMGAPI_USB_URL`, `HMGAPI_USB_SHA256`을 함께 옮깁니다. 바꿀 곳 목록은 [#14](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/14)에 있습니다.
  - 이 고침도 `develop`에서 시작한 `feature/`로 `develop`에 합칩니다(`git-flow.md` 규칙 12). 그 소스로 `tests/mod-test.sh`를 통과시킨 뒤, `release/<판>`에 `develop`을 합치고(다음 판의 작업이 있으면 그 PR만 체리픽, 규칙 12) 판을 다음 베타로 올려 `v<판>-beta.<n+1>`을 답니다. `release/`에서 직접 고치지는 않습니다.
  - 같은 태그는 다시 쓸 수 없습니다. 태그 push로 도는 워크플로는 그 태그 커밋의 `release.yml`을 쓰기 때문입니다.
  - 받을 수 있는지는 태그를 달기 전에 `curl -sSI -o /dev/null -w '%{http_code}\n' <HMGAPI_USB_URL>`로 봅니다. 200이나 302면 됩니다.
  - 정식판 직전에 지워지면 차에서 확인하지 않은 판으로 옮겨야 합니다. 그래도 사본은 두지 않기로 했습니다(위 "어느 HMG-API 판을 쓰나").

### 공식 무선 모드를 USB 묶음에 함께

2.1.0부터 USB 묶음에 HMG-API의 공식 무선 모드 `wireless-carplay-aa`([Open-HMG/hmgapi-wireless-cp-aa](https://github.com/Open-HMG/hmgapi-wireless-cp-aa))를 고치지 않고 넣습니다. NX4 KOR 설치기가 NX4에 `--any-car`로 설치합니다([`design.md`](design.md) "설치·업데이트·지우기").

- **어떻게 넣나:** `build` job의 "공식 무선 모드" step이 `scripts/fetch-wireless.sh`로 그 릴리스의 `wireless-carplay-aa-<판>.zip`을 받아 `NX4_WIRELESS_ZIP`으로 `scripts/build.sh`에 넘깁니다. 키를 꺼내기 전에 받고, 풀거나 실행하지 않습니다(`build.sh`가 `mod.json`만 꺼냅니다).
- **고정:** 판은 `scripts/fetch-wireless.sh`의 `WV`, SHA-256은 `NOTICE.md` "공식 무선 모드"의 "공식 모드 zip SHA-256"에 둡니다. 받은 파일이 그 값과 다르면 멈춥니다. 서명 확인 step은 USB 묶음 안의 zip도 그 값과 같은지 봅니다.
- **판을 바꿀 때:** `fetch-wireless.sh`의 `WV`, `NOTICE.md`의 판·파일 이름·크기·SHA-256·대응 소스 줄을 함께 바꿉니다(`tests/mod-test.sh`가 둘이 같은지 봅니다). SHA-256은 공식 릴리스의 `SHA256SUMS`나 GitHub이 기록한 파일 digest에서 읽고, 받은 파일로 `shasum -a 256`을 돌려 같은지도 봅니다. 새 판이 더 높은 HMG-API를 요구하면(`mod.json` `hmgapi`) 위 HMG-API 고정값도 함께 옮깁니다("HMG-API USB 묶음" step이 확인).
- **라이선스:** AGPL-3.0. `build.sh`가 USB 맨 위 `WIRELESS-SOURCE.txt`에 판, SHA-256, 대응 소스(태그)를 적고, 릴리스 글에도 적습니다.
- **PC 빌드:** `.env.local`의 `NX4_WIRELESS_ZIP`이 없으면 공식 릴리스에서 받아 `out/wireless`에 둡니다. 주면 그 파일을 SHA-256 확인 없이 씁니다(인터넷 없이 만들 때).

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
  - 앱 키를 잃으면 차가 관리 앱 업데이트를 받지 않습니다. 사용자가 앱을 지우고 다시 설치해야 합니다.
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
| job이 받아 돌리는 남의 코드(액션, HMG-API) | 액션과 HMG-API 소스를 커밋 SHA로 고정합니다. busybox 패키지와 HMG-API USB 묶음은 돌리지 않고, 받은 파일의 SHA-256을 먼저 확인한 뒤 풉니다(busybox는 꺼낸 파일도 한 번 더). 둘 다 키를 꺼내기 전에 받습니다 |
| 키를 가진 job의 토큰으로 저장소를 바꿈 | `build`의 토큰은 읽기만 합니다. 쓰기 토큰은 키가 없는 `publish`에만 둡니다 |

### 승인하기 전에

승인은 "이 커밋의 코드에 배포 키를 맡긴다"는 뜻입니다.

- `check` job이 통과했는지 봅니다. 승인 요청은 `check`가 통과한 태그에만 뜹니다.
- 태그가 기대한 커밋인지 봅니다. 정식 태그는 `main`의 merge commit, 베타 태그는 `release/<판>`의 끝입니다.
- 지난 릴리스 태그 이후 `build` job에서 도는 코드가 바뀌었으면, 그 변경이 리뷰를 거쳐 합친 것인지 봅니다. 대상은 `.github/`, `scripts/`, `mod/build.sh`(있으면 안 됨), HMG-API 고정값(`HMGAPI_COMMIT`, `HMGAPI_USB_URL`, `HMGAPI_USB_SHA256`), 공식 무선 모드 고정값(`scripts/fetch-wireless.sh`의 `WV`, `NOTICE.md`의 "공식 모드 zip SHA-256")입니다.

  ```sh
  git diff --stat <지난 태그> <이번 태그> -- .github scripts mod/build.sh
  ```

- 모르는 태그나 내가 달지 않은 태그면 승인하지 않고 실행을 취소합니다.

### 남는 위험

- 관리자(태그를 만들고 승인할 수 있는 사람)는 키를 가져갈 수 있습니다. 관리자와 쓰기 권한자는 최소로 둡니다.
- 키가 샜다고 의심되면 secret을 바로 지우고(`gh secret delete <이름> --env production`) 원인을 찾습니다. 키를 바꾸면 위 "잃으면"처럼 사용자가 다시 설치해야 하므로, 막는 쪽이 중요합니다.

## 바꿀 때

- HMG-API 판을 올리면 다음을 함께 바꿉니다. 어느 판으로 올릴지는 "HMG-API를 USB 묶음에 함께"의 "어느 HMG-API 판을 쓰나"를 따릅니다(1.1.0 정식판 뒤에는 정식 릴리스만).
  - `release.yml`의 `HMGAPI_COMMIT`(태그가 가리키는 커밋 SHA)과 주석
  - `release.yml`의 `HMGAPI_USB_URL`, `HMGAPI_USB_SHA256`(같은 판의 `hmgapi-<판>-usb.zip`)
  - 이 문서
  - `mod/mod.json` `hmgapi`
  - 최소 판까지 올리면 `usb/troubleShooter` `HMG_MIN`, `mod/svc/lib.sh` `HMG_MIN`, 관리 앱 `Report.MIN_HMGAPI`, 이를 보는 테스트(`tests/mod-test.sh`, `tests/ReportTest.java`), 에뮬레이터 시나리오(`tests/emu/scen.sh`)와 문서의 판 언급도 함께 바꿉니다. 2.1.1에서 rc.10으로 올린 까닭(NEMESIS 1.17, [Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397))은 [`design.md`](design.md) "2.1.0 모드 구성"의 `hmgapi`
  - 2.1.1은 처음에 rc.9로 고정했는데, PR #70 리뷰 중(2026-11-25) HMG-API가 rc.10을 내며 rc.9 릴리스를 지워 주소가 404가 됐습니다. 태그를 달기 직전에 아래 `curl` 확인을 꼭 돌립니다.
- `HMGAPI_USB_SHA256`은 HMG-API 릴리스의 `SHA256SUMS`나 GitHub이 기록한 파일 digest에서 읽습니다. 받은 파일로 `shasum -a 256`을 돌려 같은지도 봅니다.

  ```sh
  gh release view v<판> --repo Open-HMG/HMG-API --json assets --jq '.assets[] | select(.name | endswith("-usb.zip")) | .digest | ltrimstr("sha256:")'
  ```
- 액션을 올릴 때도 태그가 아니라 커밋 SHA로 적고, 뒤에 판을 주석으로 남깁니다.
- 러너는 `ubuntu-24.04`로 고정했습니다. Android SDK는 빈 폴더에 정한 판만 받으므로 러너 이미지가 바뀌어도 같은 도구로 만듭니다.
