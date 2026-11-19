# NEMESIS 없이 설치하기 (HMG-API 모드판, 투싼 NX4 전용)

Korea Projection은 NEMESIS 패키지로 배포됩니다. 이 폴더는 **같은 스크립트를 HMG-API 모드로 감싸서** NEMESIS가 없는 내비에 설치하는 방법입니다. 지금은 **투싼 NX4(가솔린 `NX4`, 하이브리드 `NX4HEV`, 한국 내비 260902)** 만 받습니다.

> ⚠️ 차에서 아직 확인하지 않았습니다. PC 시험(`tests/standalone-test.sh`)과 HMG-API 엔진(PC)에서만 확인했습니다. 아래 "차에서 확인할 것"을 먼저 봐 주세요.

## 무엇이 NEMESIS를 대신하나

NEMESIS판 스크립트(`nemesis-pkg/korea.projection`)는 그대로 쓰고, NEMESIS가 하던 일만 HMG-API(1.0.2 이상)의 모드 기능으로 바꿨습니다.

| NEMESIS가 하던 일 | 여기서는 |
|---|---|
| 설치 (`NEMESIS.data` USB 핸들러, Package Store) | Engineering Mode → DSP → Update OTA로 도는 USB 설치기(`usb/troubleShooter`)가 `hmgapid engine install` |
| 서비스 `ap` (`svc/hotspot.sh`, root, 다시 시작) | `mod.json` `services` → hmgapid가 Android가 켜진 뒤 root로 띄우고 다시 띄움 (`standalone/ap.sh`) |
| postinstall (`scripts/post.sh`) | 서비스 `ap`의 첫 시작에 한 번 (`$BK/post.done`) |
| preuninstall (`scripts/preun.sh`) | `standalone/uninstall.sh` (USB `UNINSTALL` 또는 adb) |
| Launch (`bin/status.sh` → 상태 화면) | 상태 화면 앱이 열릴 때 `hmgapid service-start launch` → `standalone/launch.sh`가 `bin/status.sh` |
| 상태 화면 앱 설치·삭제 | `mod.json` `apps` (HMG-API가 서명 우회로 설치, 모드를 지우면 함께 지움) |
| NEMESIS Manager의 목록·Launch 버튼 | HMG-API 훅이 켜지면 앱 메뉴 타일(`provides.launcher`). 그 전에는 같은 USB로 Update OTA를 다시 누르면 상태 화면만 열림 |
| `/data/nemesis/apps`, `backup`, `logs` | 모드 폴더 `/data/hmgapi/mods/korea-projection`, `/data/korea-projection/backup`, `/data/korea-projection/logs/ap.log` |
| `nemesis remount` | 원래부터 `hmgapid remount`로 넘어감 (`sys_remount`) |
| 설치 차종 제한 (`os`, `models`) | `mod.json` `system`: `NX4`·`NX4HEV`, `KOR`, `260902` |

NEMESIS판 스크립트에서 바꾼 곳은 환경 변수가 있을 때만 다르게 도는 몇 줄입니다(없으면 NEMESIS판과 같음).

- `svc/hotspot.sh`: `KP_APP_BY_HMGAPI=1`이면 `install_app`·`remove_app`이 아무것도 하지 않음(앱은 HMG-API가 맡음)
- `scripts/post.sh`, `scripts/preun.sh`: `BK`·`KP_APP`를 받으면 그 위치로. `preun.sh`는 `KP_UPDATE=1`이면 업데이트 갈래로 끝남
- `bin/status.sh`: `KP_APLOG`가 있으면 그 기록 위치
- NEMESIS 버전 로직은 NEMESIS판에서도 걷어냈습니다: `nemesis version` 수집, "NEMESIS를 1.16 이상으로" 판정(`oldnemesis`), 상태 파일 `nemesis=`, 리포트·상태표·QR의 NEMESIS 칸(`bin/status.sh`, 앱 `Report`)
- 앱 `StatusActivity`: 열릴 때 `hmgapid service-start launch`를 부르고, 상태 파일이 새로 쓰이면 다시 그림. NEMESIS판에서는 hmgapid가 거절하므로(모드 앱이 아님) 아무것도 하지 않음

## 설치 (NX4)

준비: 빈 USB(FAT32, 32GB 이하), 차를 세운 상태.

1. **HMG-API 설치(NEMESIS 필요 없음).** HMG-API 릴리스의 `hmgapi-<버전>-usb.zip`을 USB 맨 위에 풀고 Engineering Mode → USB Copy → DSP → Update OTA. 재부팅까지 기다립니다.
   - `HMGAPI/install.log`에 `app_process md5 … isn't a known stock build`가 있으면 HMG-API가 이 차의 `app_process`를 모르는 것입니다(지금 아는 것은 EV6 미국 260507 하나). 그때는 `HMGAPI/FORCE` 빈 파일을 만들고 다시 합니다(자기 책임).
2. **Korea Projection 설치.** `korea-projection-<버전>-standalone-usb.zip`을 다른 USB(또는 지운 USB) 맨 위에 풀고 Update OTA.
   - 묶음을 `HMGAPI_USB_ZIP`과 함께 만들었으면 1·2를 한 USB로 합니다: 첫 번째 Update OTA가 HMG-API를 설치하고 재부팅, 두 번째가 Korea Projection을 설치합니다.
3. 상태 화면이 열리고 설정 진행이 보입니다. NX4에는 HMG-API 지도가 없어서 HMG-API가 이 차의 파일로 지도를 만들고 확인합니다(1~2분). **3~5분 동안 끄지 마세요.** OTA 화면의 오류 684는 정상입니다.
4. "설정을 마쳤습니다"가 나오면 [지금 재부팅]을 누릅니다(또는 RESET 버튼).
5. 재부팅 뒤 무선 카플레이·안드로이드 오토를 연결합니다. HMG-API 훅이 켜졌으면 앱 메뉴에 Korea Projection과 HMG-API 타일이 생깁니다.

adb가 있으면(HMG-API를 USB로 설치한 뒤에는 hmgapid가 root를 줌):

```sh
adb push korea-projection-1.7.4.zip /data/local/tmp/
adb shell hmgapid engine install /data/local/tmp/korea-projection-1.7.4.zip
adb shell am start -n korea.projection.app/.StatusActivity
```

## 지우기

- USB: `KoreaProjection` 폴더에 빈 파일 `UNINSTALL`을 만들고 Update OTA. 서비스를 멈추고 `scripts/preun.sh`로 되돌린 뒤(무선 모드, Wi-Fi 잠금, 순정 AP 저장값, 권한 파일) 모드를 지우고 재부팅합니다.
- adb: `adb shell "hmgapid sh 'sh /data/hmgapi/mods/korea-projection/standalone/uninstall.sh'"` 뒤 재부팅.
- **HMG-API 앱에서 모드만 지우거나 HMG-API를 먼저 지우면 Korea Projection이 직접 바꾼 것은 되돌아가지 않습니다**(Wi-Fi 설정 파일 잠금, 순정 AP 저장값, 권한 파일. HMG-API에는 삭제 전 스크립트가 없고, HMG-API 삭제는 HMG-API를 통해 바꾼 것만 되돌림). 그랬다면 USB `UNINSTALL`을 한 번 하세요.
  - HMG-API가 없어도 됩니다. 남은 모드 폴더(HMG-API 일반 삭제는 `/data/hmgapi/mods`를 남김)가 있으면 그것으로, 없으면 스틱에 든 사본으로 되돌리고, 남은 모드 폴더와 상태 화면 앱(HMG-API 일반 삭제는 꺼 두기만 함)도 지웁니다.
  - 이때는 `/system`을 열어 줄 nemesis·hmgapid가 없으므로 USB 설치기가 DSP OTA 프로세스에서 순정 `mount`로 엽니다(HMG-API 설치기와 같은 방법).
- 둘 다 지울 때 권하는 순서: Korea Projection `UNINSTALL` → HMG-API 삭제.

## 만들기

```sh
# 상태 화면 앱(Android SDK 필요): 화면을 열 때 launch를 부르는 새 앱이어야 한다
sh scripts/build-app.sh

# 모드 작성자 키(처음 한 번, 저장소 밖에 보관)
cd <HMG-API>
mkdir -p out/engine-host
javac --release 8 -d out/engine-host core/runtime/java/hmgapi/engine/*.java
java -cp out/engine-host hmgapi.engine.Signing keygen ~/.local/share/korea-projection/keys/mod.key

# 묶음
HMGAPI_SRC=<HMG-API> KP_MOD_KEY=~/.local/share/korea-projection/keys/mod.key \
  KP_PKG_ZIP=<릴리스의 korea.projection.zip, busybox용> HMGAPI_USB_ZIP=<hmgapi-버전-usb.zip, 선택> \
  sh scripts/build-standalone.sh
```

결과: `out/standalone/korea-projection-<버전>.zip`(모드), `out/standalone/korea-projection-<버전>-standalone-usb.zip`(USB).

시험: `sh tests/standalone-test.sh` (HMG-API 저장소를 `HMGAPI_SRC`로 주면 빌드와 HMG-API 엔진 설치까지 봄).

## 차에서 확인할 것

- **DSP OTA 뒤 재부팅하지 않고 끝내도 되는지.** HMG-API 설치기는 끝에 늘 재부팅합니다. 여기서는 첫 설정(3~5분)을 끊지 않으려고 `/storage/upgrade`만 비우고 재부팅하지 않습니다. OTA 화면이 이상하게 남으면 상태 화면의 [지금 재부팅]이나 RESET을 쓰세요.
- **DSP OTA 화면 위로 상태 화면이 열리는지**(`am start`). 안 열리면 재부팅 뒤 같은 USB로 Update OTA를 다시 누릅니다.
- HMG-API 설치기가 NX4의 `app_process`를 아는지(모르면 `HMGAPI/FORCE`).
- HMG-API가 NX4에서 지도를 만들고(`engine map-car --write`) 확인(`verify-map`)을 통과하는지. 실패하면 훅이 꺼져 무선 모드가 켜지지 않습니다. 상태 화면의 [제보 파일 만들기]로 알려 주세요.
- 상태 화면 안내 문구 몇 곳에 "NEMESIS 재부팅", "NEMESIS Manager에서 Launch"가 그대로 남아 있습니다(동작에는 영향 없음).

## 함께 쓰지 않기

NEMESIS판 `korea.projection`과 이 모드는 같은 Wi-Fi와 작업 폴더를 씁니다. 둘 다 있으면 이 모드는 아무것도 하지 않고, USB 설치기는 설치하지 않습니다. NEMESIS판을 먼저 지우세요.
