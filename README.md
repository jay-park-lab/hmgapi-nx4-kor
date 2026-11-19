이 저장소는 [StopDragon/korea-projection](https://github.com/StopDragon/korea-projection)의 포크입니다. 원본과 다른 점은 다음과 같습니다.

- **NEMESIS 없이 설치합니다(투싼 NX4 전용).** 원본의 NEMESIS 패키지 스크립트를 그대로 HMG-API 모드로 감싸, HMG-API(1.0.2 이상)만 있으면 Engineering Mode의 USB 설치(DSP Update OTA)로 설치·업데이트·삭제합니다.
- **NEMESIS 버전 판정을 뺐습니다.** 상태 화면·리포트·QR이 NEMESIS 버전을 보지 않습니다.
- **HMG-API를 먼저 지웠어도** USB `UNINSTALL`로 이 패키지가 바꾼 Wi-Fi 설정을 되돌립니다.
- **차에서 아직 확인하지 않았습니다**(PC 시험만). 릴리스 묶음은 없어 직접 만듭니다([만들기와 시험](#만들기와-시험)).

> ⚠️ 차량 소프트웨어를 바꾸는 일입니다. 모든 책임은 설치하신 차주 본인에게 있습니다.

## 무엇을 하나

한국 현대·기아 내비(Gen5W 헤드유닛)는 Wi-Fi 칩을 켜지 않아 무선 카플레이와 무선 안드로이드 오토를 쓸 수 없습니다. Korea Projection은 부팅할 때 순정 `hostapd`와 `dnsmasq`로 카플레이용 핫스팟을 켜고, HMG-API 무선 모드(한국 차 빌드)와 그 차의 HMG-API 지도를 자동으로 넣어 폰이 무선으로 붙게 합니다.

이 포크에서는 NEMESIS가 하던 일을 HMG-API의 모드 기능이 대신합니다.

| NEMESIS가 하던 일 | 이 포크에서는 |
|---|---|
| 설치(USB 핸들러, Package Store) | USB 설치기(`standalone/usb/troubleShooter`)를 Engineering Mode → DSP → Update OTA로 돌림 |
| 부팅 서비스(`svc/hotspot.sh`, root, 다시 시작) | HMG-API 모드 서비스 `ap` |
| Launch 버튼(상태 화면) | 앱 메뉴 타일. 화면이 열릴 때 HMG-API 서비스 `launch`가 상태를 새로 씀 |
| 상태 화면 앱 설치·삭제 | HMG-API 모드 `apps` |
| 설치·삭제 스크립트 | 서비스 첫 시작 때 `scripts/post.sh`, 삭제 때 `standalone/uninstall.sh` → `scripts/preun.sh` |

자세한 내용은 [`standalone/README.md`](standalone/README.md)에 있습니다.

## 대상 차

**투싼 NX4**: 가솔린(`NX4`)과 하이브리드(`NX4HEV`), 한국 내비 소프트웨어 260902(`NX4….KOR.….260902`)만 받습니다. 다른 차와 다른 소프트웨어에는 HMG-API가 설치하지 않습니다.

- 원본(NEMESIS판)에서는 두 차 모두 무선 연결이 확인됐습니다([#125](https://github.com/StopDragon/korea-projection/issues/125), [#126](https://github.com/StopDragon/korea-projection/issues/126)). 가솔린은 내비에 무선 카플레이용 순정 핫스팟이 있어 그것을 씁니다.
- NX4 지도는 HMG-API에도 이 패키지에도 없습니다. 처음 설치할 때 HMG-API가 그 차의 파일로 지도를 만들고 확인합니다.

## 필요한 것

- **HMG-API** 1.0.2 이상. USB로 설치하며 NEMESIS는 필요 없습니다.
- **이 포크로 만든 USB 묶음** `korea-projection-버전-standalone-usb.zip`([만들기와 시험](#만들기와-시험)).
- FAT32로 포맷한 USB(32GB 이하 권장).

나머지는 Korea Projection이 알아서 갖춥니다.
- **HMG-API 무선 모드(한국 차 빌드):** HMG-API 앱에는 `Korea Projection: Wireless CarPlay + Android Auto`로 보입니다. HMG-API 공식 모드에 한국 차를 더한 판입니다. 없으면 설치하고, 예전 판이면 새 판으로 바꿉니다. 차주가 일부러 지우거나 꺼 둔 것은 다시 넣지 않습니다.
- **NX4 지도:** HMG-API가 그 차의 파일로 만들고(`engine map-car --write`), 차에서 확인(`verify-map`)한 뒤에만 무선 모드를 넣습니다.

## 설치

1. **HMG-API 설치:** HMG-API [릴리스](https://github.com/Open-HMG/HMG-API/releases)의 `hmgapi-버전-usb.zip`을 USB 맨 위에 풀고 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다. 재부팅될 때까지 기다립니다.
   - USB의 `HMGAPI/install.log`에 `isn't a known stock build`가 있으면 HMG-API 설치기가 이 차의 `app_process`를 모르는 것입니다(설치기가 아는 것은 EV6 미국 260507 하나). 그때는 `HMGAPI/FORCE` 빈 파일을 만들고 다시 합니다(자기 책임).
2. **Korea Projection 설치:** `korea-projection-버전-standalone-usb.zip`을 USB 맨 위에 풀고 다시 Update OTA를 누릅니다.
   ```
   USB
   ├─ ota_package.tar
   ├─ README.txt
   └─ KoreaProjection
       └─ install (korea-projection.zip, payload)
   ```
   - 묶음을 HMG-API USB 묶음과 함께 만들었으면(`HMGAPI_USB_ZIP`) 같은 USB로 두 번 하면 됩니다. 첫 번째에 HMG-API를 설치하고 재부팅, 두 번째에 Korea Projection을 설치합니다.
3. 상태 화면이 열리고 설정 진행이 보입니다. OTA 화면의 오류 684는 정상입니다. 지도를 만들고 확인하는 동안 **3~5분 동안 끄지 마세요.**
4. "무선 카플레이 설정을 마쳤습니다"가 나오면 **[지금 재부팅]**을 누릅니다(또는 RESET 버튼). 시동만 끄면 내비가 꺼지지 않을 수 있습니다.
5. 폰에서 무선 카플레이(또는 무선 안드로이드 오토)를 연결합니다.

- **업데이트:** 새 판 USB로 같은 방법으로 합니다. 같은 판을 다시 설치하려면 `KoreaProjection/REINSTALL` 빈 파일을 만듭니다.
- NEMESIS판 Korea Projection(`korea.projection` 패키지)과 함께 쓰지 않습니다. 둘 다 있으면 이 판은 아무것도 하지 않고, 설치기도 설치하지 않습니다.
- USB를 꽂아 둔 채로 두면 유선 안드로이드 오토가 시작되어 무선이 붙지 않을 수 있습니다. 끝나면 빼 주세요.

## 상태 확인

- **앱 메뉴의 Korea Projection 타일**을 누릅니다. 타일은 HMG-API 훅이 켜진 뒤(지도 확인 뒤 재부팅)에 생깁니다.
- 그 전에는 설치 USB로 Update OTA를 다시 누르면 다시 설치하지 않고 **상태 화면만 엽니다.**
- 화면이 열릴 때 상태를 새로 씁니다. 화면 안내에 "Launch를 다시 누르면"이라고 나오면 "화면을 다시 열면"으로 읽으세요.

상태 화면에서 볼 수 있는 것:
- 맨 위 한 줄 판정(초록: 준비됨·연결됨, 노랑: 확인 필요, 빨강: 문제)과 요약 3줄(설치 / 무선 Wi-Fi / 폰 연결). 자세한 상태표는 "자세히(제보용)" 아래에 있습니다.
- 노란 알림 줄: 설치 중 안내, 아이폰이 차 Wi-Fi에 오지 않거나 카플레이가 시작되지 않을 때의 안내.
- **[지금 재부팅]**: 차를 세운 상태에서만 누르세요. 켜진 지 3분이 안 됐으면 막힙니다. 재부팅을 짧게 여러 번 하면 HMG-API가 무선 기능을 끄므로 3분 넘게 켜 두세요.
- **[제보 파일 만들기]**: USB를 꽂고 누르면 USB의 `KoreaProjection-report` 폴더에 `1-report.md`, `2-car-report.json`(HMG-API Car Report), `3-log.txt`가 생깁니다. 비밀번호·SSID·폰 이름·MAC·IP·전화번호·위치는 가립니다. 디버그 로그를 켰으면 `KoreaProjection-private` 폴더가 따로 생기는데, 운행 기록이라 남에게 보내지 마세요.
- 화면의 QR은 원본 저장소의 차량 제보 양식을 엽니다.

## 알아 두실 점

- 설치 뒤 약 5분 동안 재부팅하지 마세요.
- 핫스팟이 켜져 있는 동안에는 내비가 휴대폰 핫스팟(일반 Wi-Fi)에 붙을 수 없습니다. Wi-Fi 칩 하나가 핫스팟 역할을 하기 때문입니다.
- 내비의 일반 Wi-Fi 접속 기능을 잠급니다. Wi-Fi 설정 파일(`/data/misc/wifi/wpa_supplicant.conf`)의 소유자를 root로 바꿉니다. 그러지 않으면 내비의 Wi-Fi 서비스가 30초마다 Wi-Fi를 다시 시작해 핫스팟이 끊깁니다. 한국 내비에는 일반 Wi-Fi 메뉴가 없어 보통은 영향이 없고, 지우면 원래대로 되돌립니다.
- 차 설정에서 ADB TCP가 켜져 있으면 HMG-API가 경고를 띄웁니다. 이 패키지는 `192.168.43.x` 대역을 써서 영향이 없었습니다.
- **계기판·HUD 길안내의 한계:** 폰의 지도 앱이 보내 주는 정보(다음 회전의 종류·방향·남은 거리·도로 이름)까지만 나와서 순정 내비와 똑같지 않습니다. 지하차도·고가차도 구분, 일부 갈림길·회전교차로 모양, 방면 표시는 다르거나 나오지 않을 수 있고, 지도 앱마다 보내는 정보가 다릅니다.
- **지도가 생기기 전(훅이 꺼진 동안)에는 HMG-API가 순정 OTA 업데이트를 막지 못합니다.** 펌웨어가 업데이트되면 HMG-API의 시스템 파일이 지워지니, 그때는 HMG-API부터 다시 설치합니다.

## 삭제

설치 USB의 `KoreaProjection` 폴더에 빈 파일 `UNINSTALL`을 만들고 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다. 다음을 되돌린 뒤 재부팅합니다.
- 이 패키지가 켠 핫스팟과 DHCP를 멈춥니다.
- 이 패키지가 설치한 HMG-API 무선 모드를 지우고 적용합니다. 차주가 직접 넣은 모드와 지도는 남깁니다.
- 잠갔던 Wi-Fi 설정 파일의 소유자·권한, 순정 핫스팟 저장값, 무선 권한 파일을 원래대로 되돌립니다. 설치 전에 Wi-Fi가 꺼져 있던 차는 다시 끕니다.
- HMG-API에서 이 모드를 지웁니다. 상태 화면 앱도 함께 지워집니다. 작업 폴더와 백업(`/data/korea-projection`)을 지웁니다.

주의할 점:
- **HMG-API 앱에서 모드만 지우거나 HMG-API를 먼저 지우면** Wi-Fi 설정 파일 잠금·순정 핫스팟 저장값·권한 파일이 그대로 남습니다. HMG-API 삭제는 HMG-API를 통해 바꾼 것만 되돌리기 때문입니다. 그때도 USB `UNINSTALL`을 하면 됩니다. HMG-API가 없어도 남은 모드 폴더나 USB의 사본으로 되돌리고, 남은 모드 폴더와 상태 화면 앱도 지웁니다.
- 둘 다 지울 때는 **Korea Projection을 먼저, HMG-API를 나중에** 지우세요.
- HMG-API 일반 삭제(`HMGAPI/UNINSTALL`)는 모드 파일·설정을 남기고 모드 앱을 꺼 두기만 합니다. 모두 지우려면 `HMGAPI/UNINSTALL-PURGE`를 씁니다.
- 삭제할 때 Wi-Fi를 껐다 켜지 않습니다. 껐다 켜면 Wi-Fi·블루투스 모듈이 다시 시작되어 블루투스 카플레이가 재부팅 전까지 되지 않습니다(원본에서 니로로 확인). 재부팅하면 일반 Wi-Fi가 원래대로 돌아옵니다.

## 만들기와 시험

| 위치 | 내용 |
|---|---|
| `standalone/` | HMG-API 모드판: `mod.json`, 서비스 래퍼(`ap.sh`·`launch.sh`·`uninstall.sh`·`env.sh`), USB 설치기 |
| `nemesis-pkg/korea.projection/` | 원본 패키지 스크립트(핫스팟 서비스·상태·설치·삭제). 그대로 쓰고, 환경 변수가 있을 때만 다르게 돕니다 |
| `nemesis-pkg/app-src/` | 상태 화면 앱. 화면이 열릴 때 `hmgapid service-start launch`를 부르도록 고쳤습니다 |
| `hmgapi-mod/` | 함께 넣는 HMG-API 무선 모드(한국 차 빌드)의 대응 소스 |
| `scripts/build-standalone.sh` | 서명한 모드 zip과 USB 묶음을 만듦 |
| `tests/` | PC 시험 |

**만들기**
```sh
# 1. 상태 화면 앱(Android SDK build-tools와 android-19 필요)
sh scripts/build-app.sh

# 2. 모드 작성자 키(처음 한 번, 저장소 밖에 보관. 업데이트도 같은 키로 서명해야 HMG-API가 받습니다)
cd <HMG-API 소스>
mkdir -p out/engine-host
javac --release 8 -d out/engine-host core/runtime/java/hmgapi/engine/*.java
java -cp out/engine-host hmgapi.engine.Signing keygen ~/.local/share/korea-projection/keys/mod.key

# 3. 묶음(결과: out/standalone/korea-projection-버전.zip, korea-projection-버전-standalone-usb.zip)
HMGAPI_SRC=<HMG-API 소스> KP_MOD_KEY=~/.local/share/korea-projection/keys/mod.key \
  KP_PKG_ZIP=<원본 릴리스의 korea.projection.zip, busybox용> HMGAPI_USB_ZIP=<hmgapi-버전-usb.zip, 선택> \
  sh scripts/build-standalone.sh
```

**PC 시험**
- `sh tests/standalone-test.sh`: 서비스 래퍼, USB 설치기, 지우기(HMG-API를 먼저 지운 경우 포함). `HMGAPI_SRC`에 HMG-API 소스를 주면 빌드와 HMG-API 엔진(PC) 설치, 차종 제한(NX4.KOR 260902만)까지 봅니다.
- `sh tests/stub-test.sh`: 원본 패키지 스크립트 시험. 공개 저장소에 없는 파일을 보는 시험 등 36개는 원본에서도 실패합니다(이 포크에서 늘거나 줄지 않음).

**차에서 확인할 것**은 [`standalone/README.md`](standalone/README.md#차에서-확인할-것)에 있습니다(재부팅 없이 끝내는 DSP OTA, OTA 화면 위로 상태 화면 열기, NX4 지도 만들기·확인 등).

## 라이선스

[GNU AGPL-3.0](LICENSE). 원본, HMG-API와 같은 라이선스입니다. 제조사 파일은 넣지 않습니다.

- 함께 넣는 HMG-API 무선 모드(한국 차 빌드)의 대응 소스와 다시 만드는 방법은 [`hmgapi-mod/`](hmgapi-mod/README.md)에 있습니다.
- 다른 프로젝트에서 가져온 부분과 원저작권은 [`NOTICE.md`](NOTICE.md)에 있습니다.
- 패키지에 함께 넣는 `bin/busybox`는 별개 프로그램이며 **GPL-2.0**입니다. 출처와 대응 소스는 [`NOTICE.md`](NOTICE.md#busybox-gpl-20)에 있습니다.

## 바탕이 된 프로젝트

- [Korea Projection](https://github.com/StopDragon/korea-projection) — StopDragon (원본)
- [HMG-API](https://github.com/Open-HMG/HMG-API) — VysseCodes
- [NEMESIS](https://github.com/xwtk/hmg_nemesis) — xwtk
