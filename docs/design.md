# NX4 KOR 설계

NX4 KOR는 투싼 NX4(가솔린 `NX4`, 하이브리드 `NX4HEV`, 한국 내비 260902) 전용 HMG-API 모드 하나입니다. Korea Projection(StopDragon)의 핫스팟 서비스·상태 화면과, Korea Projection이 HMG-API에 따로 넣던 한국 차 빌드 무선 모드(`wireless-carplay-aa` 2.4.5)를 합쳤습니다.

> ⚠️ 차에서 아직 확인하지 않았습니다. PC 시험(`tests/mod-test.sh`)과 HMG-API 1.1.0-rc.4 엔진(PC)에서만 확인했습니다. 아래 "차에서 확인할 것"을 먼저 봐 주세요.

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
| NEMESIS로 설치한 Korea Projection(`/data/nemesis/apps/korea.projection`)이나 무선 패키지(`wireless.projection`) | 핫스팟이 둘이 되어 wlan0을 다투고, 둘 다 Wi-Fi 설정 파일을 잠그고 지울 때 각자 되돌립니다. Korea Projection은 무선 모드 `wireless-carplay-aa`를 HMG-API에 따로 넣습니다 | 설치 경로에 따라 다릅니다. **USB 설치기**는 NEMESIS 패키지를 막지 않지만, Korea Projection이 HMG-API에 넣은 `wireless-carplay-aa`는 설치 전에 지웁니다("따로 설치한 `wireless-carplay-aa`" 줄). 그러면 Korea Projection은 무선 모드 없이 NEMESIS 쪽 서비스만 남습니다. **adb 등으로 `engine install`하면** 그 모드가 남아 무선 기능을 적용하지 않습니다(상태 `oldmod`). 어느 경로든 NEMESIS의 hostapd가 돌면 비켜 줍니다("핫스팟을 띄우는 다른 패키지" 줄). **NEMESIS 패키지를 먼저 지워야 합니다.** 설치기가 막을지는 [`open-issue.md`](open-issue.md) OI-1 |
| 따로 설치한 `wireless-carplay-aa` | 같은 훅 지점을 겁니다 | `mod.json` `conflicts`로 함께 켜지지 않습니다. 자동 설정은 적용하지 않고 HMG-API 앱에서 지우라고 안내합니다(상태 `oldmod`). USB 설치기는 누가 넣었든 설치 전에 지우고 적용합니다. 지우고 적용하지 못하면 설치는 계속하고 상태 `oldmod`가 됩니다 |
| 같은 훅 지점에 `replace` 훅을 거는 다른 HMG-API 모드 | HMG-API는 모드를 id 순서(`requires`로 이어진 모드가 먼저, 그다음 id 이름순)로 올리고, 같은 지점에 `replace` 훅을 거는 뒤쪽 모드의 훅을 통째로 끕니다(계획·로그 `hooks <id> won't load: conflict: … both replace <지점>; turn one of them off`). id가 `nx4-kor`보다 앞인 모드와 겹치면 이 모드의 훅과 앱 메뉴 타일이, 뒤인 모드와 겹치면 그 모드가 꺼집니다. 설치한 순서와는 상관없습니다. 다만 앱이 도는 중에 켠 모드는 다음 재시작 전까지 이미 올라간 쪽에 밀립니다 | 막지 못합니다. 처음 자동 설정은 어느 쪽이 꺼지든 계획에 `won't load` 줄이 있어 적용하지 않고 `otherplan`으로 끝나는데, 그 안내(HMG-API 앱에서 적용하고 재부팅)로는 풀리지 않습니다. 이 모드가 꺼지는 쪽이면 상태는 `modhooksoff`이고, 그 문구는 원인을 map으로 적습니다(판정·문구를 고칠지는 [`open-issue.md`](open-issue.md) OI-5). 푸는 법은 HMG-API 앱에서 한쪽 모드를 끄는 것입니다. 이 모드가 `replace`로 거는 지점은 `mod/mod.json` `hooks.points` 36개 중 19개(`framework.context_impl.start_service`, `framework.navigation_cluster.*` 13개, `dipo.*` 5개) |
| HMG-API에 다른 모드의 적용 전 변경이 남아 있음 | `engine plan`에 이 모드 것이 아닌 변경이 섞입니다 | 자동으로 적용하지 않고 HMG-API 앱에서 적용하라고 안내합니다(상태 `otherplan`). 지울 때도 같습니다 |
| 핫스팟을 띄우는 다른 패키지(USB 동글 패키지 등) | wlan0을 다툽니다 | 그 hostapd가 도는 동안 우리 핫스팟을 멈추고 비켜 줍니다. 처음 설정 전이면 자동 설정(무선 기능 적용)도 이번 부팅은 건너뛰고 다음 부팅에 다시 봅니다. 순정(netd)이 띄운 것이 아니고 연결도 없으면 상태 `otherwifi` |
| 일반 Wi-Fi 접속(클라이언트)이 필요한 모드·앱 | Wi-Fi 잠금으로 wpa_supplicant가 뜨지 않아 접속할 수 없습니다 | 잠금은 이 모드를 지울 때 되돌립니다 |

## 차에서 확인할 것

- **HMG-API가 NX4에서 map을 만들고(`map-car --write`) 확인(`verify-map`)을 통과하는지.** 실패하면 무선 기능을 적용하지 않습니다(`/data/local/tmp/nx4-kor/map-car.txt`, `verify-map.txt`).
- **무선 훅 36개 지점이 모두 NX4 map에 있는지.** 하나라도 없으면 HMG-API가 이 모드의 훅을 끄고 앱 메뉴 타일도 없어집니다(HMG-API 로그 `mods: nx4-kor not loaded: …`).
- **네이티브 레시피가 NX4 라이브러리에 맞는지**(`libCarPlayCore.so` 등). 맞지 않는 레시피는 아무것도 쓰지 않습니다.
- **DSP OTA 뒤 재부팅하지 않고 끝내도 되는지.** OTA 화면이 이상하게 남으면 상태 화면의 [지금 재부팅]이나 RESET을 쓰세요.
- **DSP OTA 화면 위로 상태 화면이 열리는지**(`am start`). 안 열리면 재부팅 뒤 같은 USB로 Update OTA를 다시 누릅니다.
- HMG-API 설치기가 NX4의 `app_process`를 아는지(모르면 `HMGAPI/FORCE`).
- 순정 무선 카플레이가 있는 트림에서 순정 카플레이 AP 경로(`stock_ap_mode`)가 그대로 도는지.

정하지 않은 것은 [`open-issue.md`](open-issue.md)에서 관리합니다.
