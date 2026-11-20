# 정하지 않은 것 (Open Issues)

결정을 기다리는 일을 이 문서 한 곳에서 관리합니다. 다른 문서는 내용을 되풀이하지 않고 `open-issue.md` OI-<번호>로 가리킵니다.

## 관리 규칙

- **더하기:** 정하지 않은 일이 생기면 다음 번호(`OI-<n>`)로 "열린 것" 끝에 더합니다. 번호는 다시 쓰지 않습니다.
- **항목에 적을 것:** 기록한 날, 지금 어떻게 되어 있는지, 정할 것, 아는 선택지, 근거(문서·코드·PR).
- **정하면:** 그 항목에 결정, 날짜, 반영한 PR을 적고 "닫힌 것"으로 옮깁니다. 지우지 않습니다. 이 항목을 가리키던 다른 문서도 같은 변경에서 고칩니다.
- **정하지 않기로 하면:** 그 이유와 날짜를 적고 "닫힌 것"으로 옮깁니다.

## 열린 것

### OI-1. USB 설치기가 NEMESIS 패키지를 보면 설치를 거절할지

- 기록: 2026-11-20
- 지금: NEMESIS 패키지를 막지 않습니다. 설치 경로마다 결과가 다릅니다. [`design.md`](design.md) "다른 패키지·모드와 함께 쓸 때".
  - USB 설치기(`usb/troubleShooter`): Korea Projection이 HMG-API에 넣은 `wireless-carplay-aa`를 누가 넣었는지 가리지 않고 설치 전에 지우고 적용합니다. 그래서 NEMESIS 쪽 설치는 무선 모드 없이 서비스만 남는 반쪽 상태가 됩니다. 그 뒤 NEMESIS의 hostapd가 돌면 처음 자동 설정을 다음 부팅으로 미루고, 상태는 `otherwifi`입니다.
  - adb 등으로 `engine install`: `wireless-carplay-aa`가 남아 무선 기능을 적용하지 않습니다(상태 `oldmod`).
  - NEMESIS의 hostapd가 실제로 도는지는 차에서만 확인할 수 있습니다.
- 안: `usb/troubleShooter`가 `/data/nemesis/apps/korea.projection`이나 `wireless.projection`이 있으면 아무것도 바꾸지 않고 "NEMESIS에서 먼저 지워 주세요"로 끝냅니다.
- 근거: 이 안은 일부러 뺀 것을 되살리는 결정입니다. 원본의 "NEMESIS판·wireless.projection과의 충돌 확인"은 이 포크에서 뺐고(`NOTICE.md` "뺀 것"), `tests/mod-test.sh`의 "NEMESIS·다른 차·제보 흔적 없음(모드·USB·빌드 스크립트)" 시험은 `usb/troubleShooter`에 `nemesis`·`korea.projection`·`wireless.projection`이 있으면 실패합니다.
- 정할 것: 거절할지, 안내만 하고 설치할지, 지금처럼 둘지. 바꾸면 위 시험(예외를 둘지), `tests/mod-test.sh`의 USB 설치기 시험, `NOTICE.md`, README의 설치 안내도 함께 고칩니다.

### OI-2. HMG-API rc.5 이후 판을 지원할지(최소 판, 시험·빌드 판)

- 기록: 2026-11-20
- 지금: `mod/mod.json`의 `hmgapi`는 `>=1.1.0-rc.4` 그대로입니다. 시험·빌드에 쓰는 HMG-API는 rc.7입니다.
  - 2026-11-20: HMG-API가 rc.4·rc.5 릴리스를 지웠습니다. 남은 것은 rc.7과 1.0.2입니다. 그래서 `v2.0.0-beta.2`가 릴리스 USB 묶음에 넣을 rc.4 파일을 받지 못하고 멈췄습니다([`release.md`](release.md) "HMG-API가 릴리스를 지우면").
  - 그래서 배포 워크플로의 시험·빌드와 함께 넣는 HMG-API를 rc.7로 옮겼습니다(아래 첫 갈래).
  - rc.7 소스로도 `tests/mod-test.sh`가 모두 통과했습니다. 빌드와 HMG-API 엔진 시험까지 돌았습니다. rc.5·rc.6은 시험하지 않았습니다.
  - HMG-API USB 설치기(`install/usb/troubleShooter`)와 스틱을 만드는 `tools/mkinstallers.sh`는 rc.4와 rc.7이 같습니다.
- 할 일: 최소 판을 어떻게 할지 정합니다. 시판 판(1.1.0)이 나오면 그 판으로 다시 시험합니다.
- 정할 것: 최소 판을 rc.7로 올릴지, rc.4로 둘지. 차에서 rc.7을 확인한 뒤 정하는 것이 좋습니다.
- 정하면 함께 바꿀 곳:
  - **시험·빌드에 쓰는 HMG-API를 다른 판으로 옮기면**(2026-11-20에 rc.4에서 rc.7로 옮김. HMG-API가 그 판의 릴리스를 지웠을 때도 이 갈래입니다): 배포 워크플로는 HMG-API를 커밋으로 고정해 시험·빌드합니다. `.github/workflows/release.yml`의 `HMGAPI_COMMIT`(태그가 가리키는 커밋 SHA)과 그 주석, 단계 이름 두 곳("HMG-API 소스 (v<판>)"), `docs/release.md`의 판·커밋 표기를 바꿉니다. 릴리스 USB 묶음에 함께 넣는 HMG-API도 같은 판으로 바꿉니다: `HMGAPI_USB_URL`·`HMGAPI_USB_SHA256`(같은 판의 `hmgapi-<판>-usb.zip`. 판이 `HMGAPI_COMMIT`과 다르면 `build` job이 멈춥니다)과 `README.md` "필요한 것"의 함께 든 HMG-API 판과 그 판이 처음 든 릴리스, `docs/design.md` 맨 위의 확인한 엔진 판. 그 판의 소스로 `tests/mod-test.sh`를 먼저 통과시킵니다.
  - **최소 판을 올리면:** 위 갈래를 먼저 하거나 함께 합니다. 릴리스 USB 묶음의 HMG-API가 새 최소 판을 채우지 못하면 `build` job이 멈춥니다(USB 설치기가 낮은 HMG-API를 그것으로 올리기 때문입니다). HMG-API 엔진은 설치할 때 `mod.json` `hmgapi`를 자기 판과 비교해, 더 높은 판을 요구하는 모드는 거절합니다(HMG-API `Packages.java`). 그래서 시험·빌드에 쓰는 HMG-API가 rc.4인 채로 최소 판만 올리면 `tests/mod-test.sh`의 엔진 설치 시험과 배포 워크플로의 PC 시험이 실패합니다. 바꿀 곳은 `git grep -n '1\.1\.0-rc\.4'`로 찾은 것 중 **최소 판을 뜻하는 곳**입니다.
    - 모드: `mod/mod.json` `hmgapi`, `mod/svc/hotspot.sh` `HMG_MIN`
    - 상태 화면 앱: `app/java/io/github/jayparklab/nx4kor/Report.java` `MIN_HMGAPI`(차주에게 "… 이상 필요"를 보이는 값). 앱을 바꾸므로 `app/AndroidManifest.xml`의 판 번호도 올려야 하고, 그래서 `release/`에서 할 일입니다(`docs/git-flow.md` 규칙 4).
    - 시험: `tests/mod-test.sh`는 `mod.json`과 `HMG_MIN`을 서로 비교하지 않고 각각을 `1.1.0-rc.4` 글자 그대로와 비교합니다. 그 두 곳과 `oldhmgapi` 판정 시험, `tests/ReportTest.java`에서 최소 판을 기대하는 값을 함께 고칩니다.
    - 문서: `README.md`(맨 위와 "필요한 것"), `usb/README.txt`, `docs/design.md`(모드 구성 표의 `hmgapi`)
  - **바꾸지 않는 곳**(최소 판이 아니라 시험한 판이나 시험 입력값): `wireless/README.md`의 "HMG-API 1.1.0-rc.4에 … 있습니다(2026-11-19 확인)"는 다른 판으로 다시 시험했을 때 고칩니다. `tests/ReportTest.java`의 `Report.older` 비교 입력값과 `tests/emu/scen.sh`의 HMG-API 판은 그대로 둡니다.
  - **알아 둘 점:** rc.4 → rc.5처럼 `-rc.N`만 올리면 상태 화면은 낮은 판을 막지 못합니다. `hotspot.sh` `ver_lt`와 앱 `Report.older`는 major.minor.patch 숫자만 비교하고 `-태그`는 무시합니다(`ReportTest`: `older("1.1.0-rc.3", "1.1.0-rc.4") == 0`). 그래서 rc.4를 쓰는 차도 `oldhmgapi`로 나오지 않고, 막는 것은 HMG-API 엔진의 설치 거절뿐입니다.

### OI-3. 무선 모드를 공식 v2.2.0-rc.5 위로 옮길지

- 기록: 2026-11-19
- 지금: 한국 포크 `wireless-carplay-aa` 2.4.5를 이 모드에 그대로 합쳐 씁니다. 공식 rc.5는 한국 차를 받지 않고 한국 포크 기능이 없어 그대로 쓸 수 없습니다.
- 선택지:
  1. 2.4.5를 유지합니다.
  2. 코드를 고치지 않고 rc.5의 `carplay-core-frames-ef49c09b.recipe`와 `libleafiaaac.so`만 차에서 시험합니다.
  3. 한국 포크의 변경을 rc.5 위로 옮겨 다시 빌드합니다(rc.5의 BT 유지, 재연결 같은 수정을 얻습니다).
- 근거: [`wireless/README.md`](../wireless/README.md) "공식 무선 모드 v2.2.0-rc.5와 비교".

### OI-4. GitHub 브랜치 보호와 합치기 방법 설정을 적용할지

- 기록: 2026-11-20
- 지금(2026-11-20 확인):
  - `develop`은 만들었고, 합친 브랜치 자동 삭제는 켜져 있습니다. squash·rebase 합치기는 허용되어 있습니다.
  - `main`·`develop`에 걸린 보호는 없습니다. 클래식 브랜치 보호(`branches/*/protection`)는 없고, 브랜치 ruleset 두 개가 만들어져 있지만 꺼져 있습니다(`enforcement: disabled`, 둘 다 사용자 예외).
    - `main-protetion`: 대상 기본 브랜치·`main`, 삭제·강제 푸시 금지
    - `develop`: 대상 `develop`, 삭제·강제 푸시 금지·PR 필수
  - 태그 쪽은 걸려 있습니다: `production` 환경, 태그 ruleset `release tags: create`·`release tags: immutable`(#4, [`release.md`](release.md)).
  - [`git-flow.md`](git-flow.md) "강제 장치".
- 정할 것:
  - 브랜치 보호를 무엇으로 걸지: 꺼 둔 ruleset 두 개를 켤지(필요하면 `main-protetion`에도 PR 필수를 더함), 클래식 보호(`git-flow.md` "처음 한 번" 3)로 할지. 둘을 함께 두면 규칙이 겹치므로 한쪽으로 정합니다.
  - 관리자(사용자 예외)도 막을지. 막으면 관리자도 PR로만 합칠 수 있습니다.
  - 합치기 방법(`git-flow.md` "처음 한 번" 2): squash·rebase를 끌지.

### OI-5. 다른 모드와 `replace` 훅이 겹칠 때의 판정과 안내를 고칠지

- 기록: 2026-11-20 (PR #5 리뷰 지적 2)
- 지금: 같은 지점에 `replace` 훅을 거는 다른 HMG-API 모드가 있으면, 계획(`engine plan`)에 `hooks <id> won't load: conflict: …` 줄이 생깁니다. `mod/svc/hotspot.sh`의 `plan_only_mod`는 어느 모드의 그 줄이든 "다른 변경"으로 보므로 문제가 둘 생깁니다.
  - 처음 자동 설정은 어느 쪽이 꺼지든 적용하지 않고 `otherplan`("HMG-API 앱에서 변경 사항을 적용하고 재부팅")으로 끝납니다. 다른 모드가 꺼지는 쪽이라 이 모드는 문제없을 때도 그렇습니다. 그 안내로는 풀리지 않습니다.
  - 이 모드가 꺼지는 쪽이면 상태는 `modhooksoff`입니다. 그 문구(`mod/bin/status.sh`)는 원인을 "이 차의 map에 없는 지점"으로 적습니다.
  - [`design.md`](design.md) "다른 패키지·모드와 함께 쓸 때".
- 안: 계획의 `conflict:` 이유를 따로 가려 "다른 모드(<id>)와 같은 훅을 씁니다. HMG-API 앱에서 한쪽을 꺼 주세요" 같은 판정과 문구를 둡니다. 다른 모드만 꺼지는 경우에는 이 모드의 자동 설정을 막지 않을지도 함께 정합니다.
- 정할 것: 고칠지, 고친다면 위 두 경우를 어떻게 다룰지. 바꾸면 `tests/mod-test.sh`의 자동 설정·상태 판정 시험도 더합니다.

## 닫힌 것

아직 없습니다.
