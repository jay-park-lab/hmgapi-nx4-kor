# NX4 KOR 설계

NX4 KOR는 투싼 NX4(가솔린 `NX4`, 하이브리드 `NX4HEV`, 한국 내비 260902) 전용 HMG-API 모드 하나입니다. Korea Projection(StopDragon)의 핫스팟 서비스·상태 화면과, Korea Projection이 HMG-API에 따로 넣던 한국 차 빌드 무선 모드(`wireless-carplay-aa` 2.4.5)를 합쳤습니다.

> ⚠️ 차에서 아직 확인하지 않았습니다. PC 시험(`tests/mod-test.sh`)과 HMG-API 1.1.0-rc.4와 1.1.0-rc.7 엔진(PC)에서만 확인했습니다(배포 워크플로는 rc.7로 시험·빌드). 아래 "차에서 확인할 것"을 먼저 봐 주세요.

## 모드 구성 (`mod/`)

| `mod.json` 항목 | 하는 일 |
|---|---|
| `system` | `NX4`·`NX4HEV`, `KOR`, `260902`에만 설치됩니다 |
| `hmgapi` | `>=1.1.0-rc.4` |
| `conflicts` | `wireless-carplay-aa`(따로 설치하는 무선 모드)와 함께 돌지 않습니다. 같은 훅을 겁니다 |
| `services` | `ap`(`svc/ap.sh`, root, Android가 켜진 뒤 시작, 다시 시작), `launch`(`svc/launch.sh`, root, 앱이 부를 때만) |
| `apps`, `provides.launcher` | 상태 화면 앱(`app/NX4KOR.apk`)과 앱 메뉴 타일 |
| `hooks`, `parts`, `feature_flags` | 무선 카플레이·안드로이드 오토 훅(`hooks.jar`, 진입 `hmgapi.mods.wireless.Wireless`, 지점 36개, 네이티브 레시피 5개). 2.4.5와 같습니다 |
| `patches.json`, `files/`, `settings.json` | 순정 핫스팟 권한 줄 주석, 무선 카플레이 속성, AAC 라이브러리, 차주 설정 10개 |

| 파일 | 하는 일 |
|---|---|
| `svc/env.sh` | 위치(`NX4_APP` 모드 폴더, `NX4_ROOT=/data/nx4-kor`, `BK`, `APLOG`) |
| `svc/ap.sh` | 처음 한 번 `scripts/post.sh`, 그다음 `svc/hotspot.sh`(출력은 `/data/nx4-kor/logs/ap.log`) |
| `svc/hotspot.sh` | 핫스팟(hostapd·dnsmasq, Wi-Fi 잠금, 순정 AP 비켜 주기)과 자동 설정(`fix_perms` → `setup_hmgapi`) |
| `svc/launch.sh` → `bin/status.sh` | 상태 파일(`/data/local/tmp/nx4-kor-status.txt`)과 재부팅 요청 감시자 |
| `bin/uninstall.sh` → `scripts/preun.sh` | 지우기·업데이트 전 정리 |

## 자동 설정 (`setup_hmgapi`)

서비스가 부팅 뒤 120초(HMG-API 부팅 단계와 겹치지 않게)에 한 번 돕니다. 진행은 상태 화면에 막대로 보입니다.

1. 이 모드의 차가 아니면 끝(아무것도 바꾸지 않음).
2. 따로 설치된 `wireless-carplay-aa`가 있으면 적용하지 않고 HMG-API 앱에서 지우라고 안내합니다(USB 설치기는 설치 전에 지움).
3. **map:** HMG-API에 NX4 map이 없습니다. 처음에는 `hmgapid engine map-car --write`로 이 차의 파일에서 map을 만들고(`/data/hmgapi/state/local-map.json`, HMG-API를 업데이트해도 남음) `verify-map`으로 확인합니다. 확인에 실패하면 만든 map을 지우고(`map-car --forget`) 다시 만들지 않습니다(`$BK/automap.bad`, 모드를 지웠다 다시 설치하면 다시 시도). HMG-API에 이 차 map이 이미 있으면 그것을 확인만 합니다.
4. **적용:** `engine plan`에 이 모드의 변경이 있으면 Wi-Fi 칩을 확인한 뒤(한 번도 켜지 않은 칩은 한 번 깨움) `engine apply`를 합니다. 계획에 다른 모드의 변경이 섞여 있으면 적용하지 않고 HMG-API 앱에서 적용하라고 안내합니다. 적용하면 "재부팅 필요"가 되고 상태 화면의 [지금 재부팅]이 그 일을 합니다.
5. 새 판으로 업데이트했는데 적용할 것이 없으면(훅 코드만 바뀜) 재부팅만 안내합니다.

핫스팟은 무선 기능이 적용된 뒤(`persist.sys.iap2.wifi=t`)에만 켭니다. 순정 무선 카플레이가 있는 트림은 순정 카플레이 AP를 그대로 씁니다.

## 상태 화면

- 앱이 열릴 때 `hmgapid service-start launch`를 부르고(hmgapid는 이 모드의 앱일 때만 받음), 상태 파일이 새로 쓰이면 다시 그립니다.
- 판정(`verdict`·`verdict_lv`·`verdict_msg`)은 `bin/status.sh`의 `st_verdict` 한 곳에서 정하고 앱은 그대로 보입니다.
- [지금 재부팅]은 앱 개인 폴더의 `reboot.req`를 `status.sh --watch`(화면을 연 뒤 10분)가 받습니다. 설치 중, 설치 마무리 중, `/system`을 바꾸는 작업 중, HMG-API 부팅 보호에 걸릴 때는 거절합니다.
- 앱 메뉴 타일(`provides.launcher`)은 HMG-API가 이 모드의 훅을 올릴 때 함께 등록됩니다. 훅 지점이 이 차의 map에 하나라도 없으면 HMG-API가 모드의 훅을 통째로 끄고 타일도 없어집니다(앱·서비스는 그대로). 그때는 같은 USB로 Update OTA를 다시 누르면 상태 화면이 열립니다.

## 설치·업데이트·지우기 (`usb/troubleShooter`)

Engineering Mode → USB Copy → DSP → Update OTA가 `ota_package.tar`의 `troubleShooter`를 root로 돌립니다(HMG-API USB 설치기와 같은 길).

- HMG-API가 없으면 같은 스틱의 HMG-API 설치기(`NX4/hmgapi/troubleShooter`)로 넘기거나 멈춥니다.
- HMG-API가 있지만 이 모드의 최소 판(`mod.json` `hmgapi`의 `>=…`)보다 낮으면(`installed.txt`의 `version`) 엔진이 설치를 거절합니다. 그래서 아래 무선 모드 지우기 **전에** 봅니다.
  - 같은 스틱의 HMG-API 설치기가 그 판 이상(`HMGAPI/install/payload/VERSION`)이면 그것으로 넘깁니다. HMG-API 설치기는 설치된 HMG-API도 업데이트하고 재부팅하며, 그 뒤 Update OTA를 한 번 더 누릅니다.
  - 아니면 아무것도 바꾸지 않고 "HMG-API <최소 판> 이상으로 먼저 올려 주세요"로 멈춥니다.
  - 판 비교는 HMG-API `Version`과 같은 규칙(semver, `-rc.N`까지)입니다. 최소 판에 꼬리가 없으면 그 판의 rc도 채웁니다(`meetsHmgapi`). 판을 읽지 못하거나 비교할 수 없는 꼬리면 기록만 하고 지나갑니다(엔진이 설치할 때 다시 봄).
- 설치·업데이트: 따로 설치된 `wireless-carplay-aa`를 지우고 적용 → (업데이트면) `bin/uninstall.sh --update` → `hmgapid engine install` → 상태 화면 열기. 재부팅하지 않습니다(첫 설정 3~5분을 끊지 않게).
- 같은 판이면 상태 화면만 엽니다. `NX4/REINSTALL`이면 다시 설치합니다.
- `NX4/UNINSTALL`: `bin/uninstall.sh` → `scripts/preun.sh`(핫스팟 멈춤 → HMG-API에서 이 모드를 빼고 적용 → 무선 권한 파일·Wi-Fi 잠금·순정 AP 저장값 되돌리기 → `$BK` 지우기) → 재부팅. HMG-API를 먼저 지웠어도 남은 모드 폴더나 스틱의 사본으로 되돌립니다. 이때 `/system`은 DSP OTA 프로세스에서 순정 `mount`로 엽니다.

adb가 있으면(HMG-API를 USB로 설치한 뒤에는 hmgapid가 root를 줌):

```sh
adb push hmgapi-nx4-kor-2.0.0.zip /data/local/tmp/
adb shell hmgapid engine install /data/local/tmp/hmgapi-nx4-kor-2.0.0.zip
adb shell am start -n io.github.jayparklab.nx4kor/.StatusActivity
# 지우기
adb shell "hmgapid sh 'sh /data/hmgapi/mods/nx4-kor/bin/uninstall.sh'"
```

## 묶음과 라이선스 파일

`scripts/build.sh`가 HMG-API의 `tools/mkmodpkg.sh`로 서명한 모드 zip과 USB 묶음을 만듭니다. 라이선스 파일도 함께 들어갑니다(남에게 묶음을 줄 때 필요).
- 모드와 USB 맨 위: `LICENSE`(AGPL-3.0), `NOTICE.md`(원저작권과 이 저장소의 변경)
- busybox를 넣으면 그 라이선스 안내(GPL-2.0, 대응 소스 위치): 모드의 `bin/busybox-LICENSE.txt`, USB 맨 위 `BUSYBOX-LICENSE.txt`. 안내가 없으면 묶음을 만들지 않습니다.
- HMG-API USB 묶음을 함께 넣으면 그 판과 소스 위치: USB 맨 위 `HMGAPI-SOURCE.txt`
- USB `README.txt`에 이 묶음을 만든 소스 커밋을 적습니다(커밋하지 않은 수정이 있으면 그렇다고 적음).

## 다른 패키지·모드와 함께 쓸 때

이 모드는 핫스팟(hostapd)으로 wlan0을 쓰고, Wi-Fi 설정 파일을 잠그고(README "알아 두실 점"), 무선 훅 일부를 `replace`로 겁니다. 그래서 같은 자원을 쓰는 것과는 함께 쓸 수 없습니다.

| 함께 있는 것 | 일어나는 일 | 이 모드가 하는 일 |
|---|---|---|
| NEMESIS로 설치한 Korea Projection(`/data/nemesis/apps/korea.projection`)이나 무선 패키지(`wireless.projection`) | 핫스팟이 둘이 되어 wlan0을 다투고, 둘 다 Wi-Fi 설정 파일을 잠그고 지울 때 각자 되돌립니다. Korea Projection은 무선 모드 `wireless-carplay-aa`를 HMG-API에 따로 넣습니다 | 설치 경로에 따라 다릅니다. **USB 설치기**는 NEMESIS 패키지를 막지 않지만, Korea Projection이 HMG-API에 넣은 `wireless-carplay-aa`는 설치 전에 지웁니다("따로 설치한 `wireless-carplay-aa`" 줄). 그러면 Korea Projection은 무선 모드 없이 NEMESIS 쪽 서비스만 남습니다. **adb 등으로 `engine install`하면** 그 모드가 남아 무선 기능을 적용하지 않습니다(상태 `oldmod`). 어느 경로든 NEMESIS의 hostapd가 돌면 비켜 줍니다("핫스팟을 띄우는 다른 패키지" 줄). **NEMESIS 패키지를 먼저 지워야 합니다.** 설치기가 막을지는 [#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13) |
| 따로 설치한 `wireless-carplay-aa` | 같은 훅 지점을 겁니다 | `mod.json` `conflicts`로 함께 켜지지 않습니다. 자동 설정은 적용하지 않고 HMG-API 앱에서 지우라고 안내합니다(상태 `oldmod`). USB 설치기는 누가 넣었든 설치 전에 지우고(`engine remove`는 모드 폴더를 바로 지움), 계획이 그 모드의 되돌리기뿐이면 적용합니다. 어느 쪽이 안 돼도 설치는 계속합니다. 지우지 못했으면 상태 `oldmod`(HMG-API 앱에서 그 모드를 지우고 적용)이고, 지웠지만 계획에 다른 변경이 있어 적용하지 않았으면 그 모드의 되돌리기(`restore`)가 계획에 남아 상태 `otherplan`(HMG-API 앱에서 적용)입니다 |
| 같은 훅 지점에 `replace` 훅을 거는 다른 HMG-API 모드 | HMG-API는 모드를 id 순서(`requires`로 이어진 모드가 먼저, 그다음 id 이름순)로 올리고, 같은 지점에 `replace` 훅을 거는 뒤쪽 모드의 훅을 통째로 끕니다(계획 `hooks <id> won't load: conflict: … both replace <지점>; turn one of them off`, HMG-API 로그 `mods: <id> not loaded: conflict: …`). id가 `nx4-kor`보다 앞인 모드와 겹치면 이 모드의 훅과 앱 메뉴 타일이, 뒤인 모드와 겹치면 그 모드가 꺼집니다. 설치한 순서와는 상관없습니다. 다만 앱이 도는 중에 켠 모드는 다음 재시작 전까지 이미 올라간 쪽에 밀립니다 | 막지 못합니다. 처음 자동 설정은 어느 쪽이 꺼지든 계획에 `won't load` 줄이 있어 적용하지 않고 `otherplan`으로 끝나는데, 그 안내(HMG-API 앱에서 적용하고 재부팅)로는 풀리지 않습니다. 이 모드가 꺼지는 쪽이면 상태는 `modhooksoff`이고, 그 문구는 원인을 map으로 적습니다(판정·문구를 고칠지는 [#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)). 푸는 법은 HMG-API 앱에서 한쪽 모드를 끄는 것입니다. 이 모드가 `replace`로 거는 지점은 `mod/mod.json` `hooks.points` 36개 중 19개(`framework.context_impl.start_service`, `framework.navigation_cluster.*` 13개, `dipo.*` 5개) |
| HMG-API에 다른 모드의 적용 전 변경이 남아 있음 | `engine plan`에 이 모드 것이 아닌 변경이 섞입니다 | 자동으로 적용하지 않고 HMG-API 앱에서 적용하라고 안내합니다(상태 `otherplan`). 지울 때도 같습니다 |
| 핫스팟을 띄우는 다른 패키지(USB 동글 패키지 등) | wlan0을 다툽니다 | 그 hostapd가 도는 동안 우리 핫스팟을 멈추고 비켜 줍니다. 처음 설정 전이면 자동 설정(무선 기능 적용)도 이번 부팅은 건너뛰고 다음 부팅에 다시 봅니다. 순정(netd)이 띄운 것이 아니고 연결도 없으면 상태 `otherwifi` |
| 일반 Wi-Fi 접속(클라이언트)이 필요한 모드·앱 | Wi-Fi 잠금으로 wpa_supplicant가 뜨지 않아 접속할 수 없습니다 | 잠금은 이 모드를 지울 때 되돌립니다 |
| HMG-API의 "집 Wi-Fi"(HMG-API 1.1.0-rc.5부터, HMG-API 앱 설정 > Home Wi-Fi, 기본 꺼짐) | 켜면 두 가지가 일어납니다(HMG-API rc.7 `engine/HomeWifi.java`). 이 모드는 그 파일을 root로 잠그고 자체 hostapd로 핫스팟을 띄우므로, 잠금이 풀리거나 핫스팟과 클라이언트가 wlan0을 다툴 수 있습니다.<br>• HMG-API 앱에서 집 Wi-Fi 네트워크를 저장하거나 지울 때(`join`·`forget`), Android Wi-Fi 설정(`wpa_supplicant.conf`)을 `wifi:wifi` 소유로 다시 씁니다.<br>• 차를 끈 지 30초 뒤나 주차하면(car events) 프로젝션 핫스팟을 끄고 차의 Wi-Fi 클라이언트를 켜 집 Wi-Fi에 붙습니다. | 막지 못하고, 시험하지 않았습니다. **켜지 않습니다**(README "알아 두실 점"). 상태 화면에서 알릴지는 [#19](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/19) |

## 차에서 확인할 것

- **HMG-API가 NX4에서 map을 만들고(`map-car --write`) 확인(`verify-map`)을 통과하는지.** 실패하면 무선 기능을 적용하지 않습니다(`/data/local/tmp/nx4-kor/map-car.txt`, `verify-map.txt`).
- **무선 훅 36개 지점이 모두 NX4 map에 있는지.** 하나라도 없으면 HMG-API가 이 모드의 훅을 끄고 앱 메뉴 타일도 없어집니다(HMG-API 로그 `mods: nx4-kor not loaded: …`).
- **네이티브 레시피가 NX4 라이브러리에 맞는지**(`libCarPlayCore.so` 등). 맞지 않는 레시피는 아무것도 쓰지 않습니다.
- **DSP OTA 뒤 재부팅하지 않고 끝내도 되는지.** OTA 화면이 이상하게 남으면 상태 화면의 [지금 재부팅]이나 RESET을 쓰세요.
- **DSP OTA 화면 위로 상태 화면이 열리는지**(`am start`). 안 열리면 재부팅 뒤 같은 USB로 Update OTA를 다시 누릅니다.
- HMG-API 설치기가 NX4의 `app_process`를 아는지(모르면 `HMGAPI/FORCE`).
- **HMG-API가 없는 차에서 릴리스 USB 하나로 설치되는지.** 첫 Update OTA에서 NX4 KOR 설치기가 스틱의 HMG-API 설치기(`NX4/hmgapi/troubleShooter`)로 넘겨 HMG-API가 설치되고 재부팅되는지, 두 번째 Update OTA에서 NX4 KOR가 설치되는지(USB의 `HMGAPI/install.log`, `NX4/install.log`).
- **HMG-API가 1.1.0-rc.4보다 낮은 차에서 HMG-API를 먼저 올리는지.** 첫 Update OTA가 따로 설치한 무선 모드(`wireless-carplay-aa`)를 지우지 않고 HMG-API 설치기의 업데이트 갈래로 HMG-API를 올린 뒤 재부팅하는지, 두 번째에 NX4 KOR가 설치되는지. HMG-API 설치기를 `/storage/upgrade`가 아니라 스틱의 `NX4/hmgapi`에서 `exec`로 돌리는 길은 차에서 처음 돕니다. NEMESIS로 설치한 HMG-API라면 NEMESIS 목록의 판도 함께 봅니다.
- 순정 무선 카플레이가 있는 트림에서 순정 카플레이 AP 경로(`stock_ap_mode`)가 그대로 도는지.
  - HMG-API 1.1.0-rc.5부터는 한국 260902 현대·기아 빌드에서, 무선 프로젝션 AP(apMode 2)를 폰에 알린 이름·비밀번호로 띄우게 고칩니다(HMG-API `hook/ProjectionAp.java`).
  - 이 고침은 관련 훅 지점 5개가 NX4 map에 모두 있을 때만 돕니다(`framework.network_management_service.start_access_point`, `framework.wifi_configuration.*` 4개).
  - 이 모드는 순정 AP(netd가 띄운 hostapd) 설정의 `ssid=`로 판정합니다(`hotspot.sh` `stock_ssid`). 카플레이 SSID(softap.conf의 S2)면 `carplay`, 핫스팟 이름(S1)이면 `hotspot`입니다.
  - 판정은 무선 기능이 적용된 뒤에만 합니다(`try_ready`). 그 앞의 두 경우는 판정까지 가지 않습니다.
    - 적용 전: 판정 줄은 없고 `ap.log`에 "대기: 무선 기능이 아직 적용되지 않음(적용된 뒤 핫스팟을 켬)"이 남습니다. 뒤에서 도는 설정(`setup_hmgapi`)의 줄도 함께 남습니다.
    - 처음 설정할 때 순정 AP가 떠 있음(`setup_hmgapi`): map 만들기를 포함한 설정을 건너뜁니다. `ap.log`에 "무선 설정 안 함: 다른 hostapd가 돌고 있음(순정 핫스팟 등) (다음 부팅에 다시 봄)"이 남고, 상태 화면은 순정 핫스팟을 끄고 재부팅하라고 안내합니다.
  - 기대값(적용이 끝난 뒤):
    - HMG-API rc.5 이상이고 이번 부팅에 훅이 켜짐: 순정 AP 이름이 카플레이 SSID(S2)이고, `ap.log`에 "순정 카플레이 AP 사용"이 남아야 합니다. 폰이 그 AP에 붙는지 봅니다.
    - HMG-API rc.4이거나 이번 부팅에 훅이 꺼짐(적용 직후 재부팅 전, 부팅 보호 등): 이 빌드에 그 분기가 없으면 순정 AP가 핫스팟 이름(S1)으로 떠 판정이 `hotspot`입니다. `ap.log`에는 처음이면 "대기: 다른 hostapd가 돌고 있음(순정 핫스팟 등, 판정 hotspot)", 앞선 부팅에 `carplay`를 본 기록(`stockap.seen`)이 있으면 "순정 카플레이 AP를 기다림 … 지금 판정 hotspot"이 남습니다. 그때 폰이 붙는지도 적어 둡니다.
    - 순정 AP가 우리 핫스팟보다 늦게 뜸: 우리 핫스팟을 켠 뒤의 확인(`ap_yield`)이 판정합니다.
      - S2(`carplay`)면 "우리 핫스팟을 켠 뒤 순정 카플레이 AP가 켜짐: 우리 핫스팟을 멈춤…"이 남고, 이어 "순정 카플레이 AP 사용"이 남습니다.
      - S1(`hotspot`)이면 "다른 hostapd가 돌고 있음(순정 핫스팟 등): 우리 핫스팟을 멈추고 기다림"이 남습니다.
  - 이 갈래들은 `tests/mod-test.sh`에 시험이 없습니다. 순정 AP가 언제 뜨는지는 차에서만 확인됩니다.
  - 둘이 부딪히면 어떻게 할지, 순정 AP가 늘 떠 있어 설정이 되지 않으면 어떻게 할지는 [#20](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/20)에서 정합니다.
- **HMG-API rc.5 이상에서 이 모드의 서비스가 그대로 도는지.** rc.5부터 `hmgapid`는 모드 서비스를 실효 그룹 2950(`MOD_GID`, root 서비스는 보조 그룹도 비움)과 `ANDROID_DNS_MODE=local`로 돌립니다. 또 HMG-API 방화벽이 그룹 2950·2951의 `rmnet+` 송신을 막습니다(rc.7 `core/hmgapid/hmgapid.c`, `engine/Network.java`).
  - 이 모드의 `ap` 서비스(root)와 그 자식 hostapd·dnsmasq도 이 환경에서 돕니다.
  - `tests/mod-test.sh`의 엔진 시험은 서비스를 띄우지 않아 이 부분을 덮지 않습니다.
  - 우리 스크립트는 모바일 데이터와 이름 조회를 쓰지 않아 영향이 없을 것으로 봅니다.
  - HMG-API rc.7인 차에서 다음 셋이 되면 이것도 확인한 것으로 봅니다: 우리 핫스팟이 뜨고, 폰이 붙고, 상태 화면이 상태를 읽음.

정하지 않은 것은 [GitHub 이슈](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues?q=is%3Aissue+label%3A%22%EA%B2%B0%EC%A0%95+%ED%95%84%EC%9A%94%22)(라벨 `결정 필요`)에서 관리합니다. 차에서 확인한 결과는 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에 적습니다.
