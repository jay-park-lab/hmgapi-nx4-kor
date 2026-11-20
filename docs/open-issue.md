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

### OI-2. HMG-API 1.1.0-rc.5를 지원할지

- 기록: 2026-11-20
- 지금: HMG-API 1.1.0-rc.4에서만 확인했습니다(`tests/mod-test.sh`의 빌드·HMG-API 엔진 시험). `mod/mod.json`의 `hmgapi`가 `>=1.1.0-rc.4`라 rc.5에도 설치됩니다. rc.5 태그가 나온 것만 확인했고 시험은 하지 않았습니다.
- 할 일: rc.5 소스를 `HMGAPI_SRC`로 주고 `tests/mod-test.sh`를 돌립니다.
- 정할 것: rc.5를 지원 판으로 적을지, 최소 판을 올릴지, 그대로 둘지.
- 정하면 함께 바꿀 곳:
  - **시험·빌드에 쓰는 HMG-API를 rc.5로 옮기면:** 배포 워크플로도 HMG-API rc.4를 커밋으로 고정해 시험·빌드합니다. `.github/workflows/release.yml`의 `HMGAPI_COMMIT`(태그가 가리키는 커밋 SHA)과 그 주석, 단계 이름 두 곳("HMG-API 소스 (v1.1.0-rc.4)"), `docs/release.md`의 판·커밋 표기를 바꿉니다. 릴리스 USB 묶음에 함께 넣는 HMG-API도 같은 판으로 바꿉니다: `HMGAPI_USB_URL`·`HMGAPI_USB_SHA256`(같은 판의 `hmgapi-<판>-usb.zip`. 판이 `HMGAPI_COMMIT`과 다르면 `build` job이 멈춥니다)과 `README.md` "필요한 것"의 함께 든 HMG-API 판.
  - **최소 판을 올리면:** 위 갈래를 먼저 하거나 함께 합니다. 릴리스 USB 묶음의 HMG-API가 새 최소 판을 채우지 못하면 `build` job이 멈춥니다(USB 설치기가 낮은 HMG-API를 그것으로 올리기 때문입니다). HMG-API 엔진은 설치할 때 `mod.json` `hmgapi`를 자기 판과 비교해, 더 높은 판을 요구하는 모드는 거절합니다(HMG-API `Packages.java`). 그래서 시험·빌드에 쓰는 HMG-API가 rc.4인 채로 최소 판만 올리면 `tests/mod-test.sh`의 엔진 설치 시험과 배포 워크플로의 PC 시험이 실패합니다. 바꿀 곳은 `git grep -n '1\.1\.0-rc\.4'`로 찾은 것 중 **최소 판을 뜻하는 곳**입니다.
    - 모드: `mod/mod.json` `hmgapi`, `mod/svc/hotspot.sh` `HMG_MIN`
    - 상태 화면 앱: `app/java/io/github/jayparklab/nx4kor/Report.java` `MIN_HMGAPI`(차주에게 "… 이상 필요"를 보이는 값). 앱을 바꾸므로 `app/AndroidManifest.xml`의 판 번호도 올려야 하고, 그래서 `release/`에서 할 일입니다(`docs/git-flow.md` 규칙 4).
    - 시험: `tests/mod-test.sh`는 `mod.json`과 `HMG_MIN`을 서로 비교하지 않고 각각을 `1.1.0-rc.4` 글자 그대로와 비교합니다. 그 두 곳과 `oldhmgapi` 판정 시험, `tests/ReportTest.java`에서 최소 판을 기대하는 값을 함께 고칩니다.
    - 문서: `README.md`(맨 위와 "필요한 것"), `usb/README.txt`, `docs/design.md`(모드 구성 표의 `hmgapi`)
  - **바꾸지 않는 곳**(최소 판이 아니라 시험한 판이나 시험 입력값): `docs/design.md` 맨 위의 "1.1.0-rc.4 엔진에서만 확인"과 `wireless/README.md`의 "HMG-API 1.1.0-rc.4에 … 있습니다(2026-11-19 확인)"는 다른 판으로 다시 시험했을 때 고칩니다. `tests/ReportTest.java`의 `Report.older` 비교 입력값과 `tests/emu/scen.sh`의 HMG-API 판은 그대로 둡니다.
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

### OI-6. HMG-API rc.6부터 바뀐 부팅 보호에 상태 판정과 [지금 재부팅] 거절을 맞출지

- 기록: 2026-11-20
- 지금: `mod/bin/status.sh`는 HMG-API 1.1.0-rc.4의 부팅 보호 규칙을 전제로 합니다.
  - rc.4: zygote가 120초를 못 버틴 시작이 재부팅을 넘어 3번 이어지면(`/data/hmgapi/hook/starts` ≥ 3) 그 시작의 훅을 끕니다.
  - rc.6부터(HMG-API 커밋 `6247107` "Boot guard: quick restarts aren't crashes", `core/zygote/zygote.c`): 한 커널 부팅 안에서 3번(훅이 시스템을 죽여 같은 부팅에서 zygote가 다시 뜨는 경우), 또는 재부팅을 넘어 6번 이어질 때만 끕니다. 부팅마다의 횟수는 새 파일 `hook/boot`(`<boot_id> <횟수>`)에 둡니다. 커널 로그 줄은 `hooks off (boot guard, starts=N, this boot M)`, `hooks on, start N (this boot M)`으로 바뀌었습니다.
  - 그래서 HMG-API가 rc.6 이상인 차에서는 우리 쪽이 지나치거나 틀립니다.
    - [지금 재부팅] 거절(`status.sh` `rb_result guard`): `starts`가 2·3이면 거절하고, 앱은 "3분 안에 재부팅을 반복하면 HMG-API가 무선 기능을 끕니다"(`Report.RB_GUARD`)를 보입니다. rc.6 이상에서는 6번까지 괜찮으므로 필요 없는 거절이고 문구도 맞지 않습니다.
    - `bootguard` 판정의 대비 갈래: 이번 부팅 커널 로그에 zygote 줄이 없을 때 `starts` ≥ 4면 부팅 보호로 봅니다. rc.6 이상에서는 `starts`가 4·5여도 훅이 켜져 있을 수 있습니다. 커널 로그 줄로 보는 기본 갈래(`hooks off (boot guard` 글자)는 rc.6 이후에도 맞습니다.
  - 배포 워크플로가 릴리스 USB에 함께 넣는 HMG-API를 rc.7로 옮기면(OI-2, #11) 새로 설치하는 차는 rc.7이 됩니다.
- 안:
  1. 설치된 HMG-API 판(`installed.txt`)을 보고 규칙을 고릅니다(rc.6 미만은 지금처럼, 이상은 새 규칙).
  2. `hook/boot`가 있으면 rc.6 이후로 보고 그 파일의 이번 부팅 횟수와 `starts`(6 기준)로 판단합니다.
  3. 지금처럼 둡니다(거절이 지나칠 뿐 위험하지는 않음).
- 정할 것: 어느 안으로 할지. 바꾸면 `mod/bin/status.sh`(거절과 `bootguard` 판정), 앱 `Report.RB_GUARD` 문구(앱 판 번호 → `release/`), `tests/mod-test.sh`의 부팅 보호 시험, `tests/ReportTest.java`를 함께 고칩니다. OI-2(최소 판)와 함께 정하는 것이 좋습니다.

### OI-7. HMG-API "집 Wi-Fi"가 켜져 있으면 상태 화면에서 알릴지

- 기록: 2026-11-20
- 지금: HMG-API 1.1.0-rc.5부터 있는 "집 Wi-Fi"는 켜면 주차했을 때 프로젝션 핫스팟을 끄고 차의 Wi-Fi 클라이언트를 켜며, Android Wi-Fi 설정(`wpa_supplicant.conf`)을 다시 씁니다. 이 모드의 핫스팟과 Wi-Fi 잠금과 부딪힐 것으로 봅니다(시험하지 않음). 문서로만 "켜지 않습니다"라고 안내합니다([`design.md`](design.md) "다른 패키지·모드와 함께 쓸 때", README "알아 두실 점", #11). 상태 화면은 이것을 모릅니다.
- 안: `mod/bin/status.sh`가 집 Wi-Fi 스위치를 읽어(HMG-API rc.7 `engine/HomeWifi.java`: `/data/hmgapi/settings/allow/home_wifi` 파일, 또는 `hmgapi.json`의 `"home_wifi": true`) 켜져 있으면 판정(예: `homewifi`)과 "HMG-API 앱에서 집 Wi-Fi를 꺼 주세요" 안내를 냅니다.
- 정할 것: 안내만 할지(다른 판정 아래), 앞쪽 판정으로 둘지, 그대로 문서로만 둘지. 바꾸면 `tests/mod-test.sh`의 판정 시험과 앱 문구(앱 판 번호 → `release/`)도 함께 고칩니다.

### OI-8. HMG-API의 프로젝션 AP 보정이 순정 AP 경로와 부딪히면 어떻게 할지

- 기록: 2026-11-20
- 지금: HMG-API 1.1.0-rc.5부터 한국 260902 현대·기아 빌드에서 무선 프로젝션 AP(apMode 2)를 폰에 알린 이름·비밀번호로 띄우게 고칩니다(HMG-API `hook/ProjectionAp.java`). 관련 훅 지점 5개가 NX4 map에 모두 있을 때만 돕니다. 이 모드는 순정 무선 카플레이가 있는 트림에서 순정 AP를 그대로 쓰는 경로(`stock_ap_mode`)가 있어, 둘이 함께 돌 때 어떻게 되는지 모릅니다. 확인할 일은 [`design.md`](design.md) "차에서 확인할 것"에 있습니다(#11).
- 정할 것: 차에서 부딪히는 것이 보이면 무엇을 할지. 예: 그 트림에서는 HMG-API 보정에 맡기고 `stock_ap_mode`를 보정에 맞춤, 또는 보정을 끄는 방법을 찾아 안내. 부딪히지 않으면 확인 결과를 적고 닫습니다.

### OI-9. HMG-API 차 이벤트(주차·시동 끔·깨어남)를 쓸지

- 기록: 2026-11-20
- 지금: 쓰지 않습니다. HMG-API 1.1.0-rc.5부터 모드가 `mod.json`에 `"car_events"`로 원하는 이벤트를 적으면, HMG-API가 `hmgapi.intent.action.CAR_EVENT` 방송(보낸이는 `DEVICE_POWER` 권한이 있는 HMG-API)으로 알려 줍니다: `parked`(주차하고 운전자가 떠남), `unparked`, `shutdown`(몇 초 뒤 꺼짐), `wake`(QuickBoot에서 깨어남). 모드의 훅 코드뿐 아니라 모드의 앱도 이 방송을 받으므로(HMG-API rc.7 `hook/CarEvents.java`), `hooks.jar`를 다시 빌드하지 않고 상태 화면 앱만으로도 받을 수 있습니다.
- 쓸 곳 후보: `shutdown` 때 핫스팟·DHCP를 정리하고 기록을 마무리, `parked` 때 핫스팟을 꺼 폰이 차를 떠난 뒤 붙어 있지 않게, `wake` 때 핫스팟을 다시 확인. 앱이 받아 root 서비스에 알리는 길(지금 `reboot.req` 같은 파일)이 필요합니다.
- 정할 것: 쓸지, 쓴다면 어느 이벤트에 무엇을 할지. 최소 판을 rc.5 이상으로 올려야 하므로 OI-2와 묶이고, 앱을 바꾸므로 `release/`에서 할 일입니다. 무선 모드를 rc.8로 옮기면(OI-3 선택지 3) 그쪽의 `park` 기능과 겹치는지도 봅니다.

## 닫힌 것

아직 없습니다.
