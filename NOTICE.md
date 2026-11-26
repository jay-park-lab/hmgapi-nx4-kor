# 고지 (NOTICE)

NX4 KOR는 GNU AGPL-3.0입니다(`LICENSE`). 아래는 다른 프로젝트에서 가져오거나 바탕으로 삼은 부분과 그 원저작권, 그리고 이 저장소에서 바꾼 것입니다.

## 이 저장소의 변경 (jay-park-lab/hmgapi-nx4-kor, parkjoos, 2026-11-19부터, AGPL-3.0)

이 저장소(https://github.com/jay-park-lab/hmgapi-nx4-kor)는 Korea Projection(StopDragon, https://github.com/StopDragon/korea-projection, AGPL-3.0)을 2026-11-19부터 고친 판입니다. 원본은 커밋 `e5221e0`(Korea Projection 1.7.4 뒤)입니다. 라이선스는 원본과 같은 AGPL-3.0이며, 바꾼 내용의 자세한 기록은 이 저장소의 git 기록에 있습니다.

- **HMG-API 모드 하나로 바꿨습니다(2026-11-19).**
  - NEMESIS 패키지(`NEMESIS.data`, NEMESIS 서비스·Launch·설치·삭제)를 HMG-API 모드 `nx4-kor`(`mod/mod.json`)로 바꿨습니다.
    - 서비스는 `svc/launch.sh`로, 삭제는 `bin/uninstall.sh`로 옮겼습니다. 위치는 `svc/env.sh`에서 정합니다.
    - USB 설치기 `usb/troubleShooter`와 빌드 `scripts/build.sh`를 새로 넣었습니다.
  - 2.0.x(2026-11-19~23)에는 따로 설치하던 한국 차 빌드 무선 모드 `wireless-carplay-aa` 2.4.5(`hooks.jar`, 레시피, `libleafiaaac.so`, 설정)를 이 모드에 합치고, 원본의 핫스팟 서비스(`svc/hotspot.sh`)로 HMG-API map을 만들고 적용했습니다.
- **2.1.0 구조로 줄였습니다(2026-11-23).** 무선 카플레이·안드로이드 오토는 HMG-API와 HMG-API 공식 무선 모드(고치지 않고 따로 설치)에 맡기고, `nx4-kor`에는 관리 앱과 그 서비스만 남겼습니다.
  - 뺀 것: 합쳤던 무선 모드 2.4.5 전부(`hooks.jar`, `recipes/`, `files/libleafiaaac.so`, `patches.json`, `settings.json`, `mod.json`의 `parts`·`feature_flags`·`hooks`, 저장소의 `wireless/`), 서비스 `ap`(`svc/ap.sh`, `scripts/post.sh`, `svc/hotspot.sh`의 순정 `hostapd`·`dnsmasq` 핫스팟·Wi-Fi 설정 잠금·칩 깨우기·자동 설정).
  - `svc/hotspot.sh`는 관리 앱이 쓰는 함수만 남겨 `svc/lib.sh`로 바꿨습니다(원본에서 온 softap.conf 읽기, 카플레이 연결 수 세기 등).
  - `bin/status.sh`의 판정과 상태 파일 키, `scripts/preun.sh`·`bin/uninstall.sh`, 관리 앱의 자세히 표를 새 구조에 맞췄습니다.
- **뺀 것:**
  - NEMESIS 관련: NEMESIS 버전 판정, NEMESIS판·wireless.projection과의 충돌 확인, NEMESIS 문구
    - 2026-11-24에 USB 설치기에 확인 하나를 새로 넣었습니다([#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13)). NEMESIS의 Korea Projection 패키지(`/data/nemesis/apps/korea.projection`)가 있으면 설치·업데이트하지 않고 멈춥니다. 원본의 충돌 확인을 되살린 것이 아니고, 그 패키지만 봅니다(`wireless.projection` 등 다른 NEMESIS 패키지는 막지 않음).
    - 2026-11-26에 NEMESIS 자체(`/system/xbin/nemesis`)가 있으면 설치·업데이트하지 않고 멈추는 확인을 더했습니다([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)). 이것도 원본의 판정을 되살린 것이 아니고, HMG-API가 NEMESIS를 알아보는 기준을 따랐습니다.
  - 다른 차: 차 목록, 차별 map, 패치 세트, 니로 featurexml 되돌리기
  - 제보 기능: 관리 앱의 제보 파일 만들기·QR, `bin/carreport.sh`, 리포트, USB 진단·로그 꺼내기
  - 그 밖: 이슈 자동 분류 워크플로·이슈 양식, 후원 링크, NEMESIS용 문서·빌드(`docs/install-guide.md`, `docs/car-report-guide.md`, `scripts/build-usb.sh`)
- **이름을 바꾼 것:** 원본과 섞이지 않게
  - HMG-API 모드 id `nx4-kor`(앱 목록 이름 "NX4 KOR: Tucson NX4 (Korea)"), USB 폴더 `NX4/`, 결과 파일 `hmgapi-nx4-kor-<판>.zip`·`-usb.zip`
  - 차 안 위치: 기록 `/data/nx4-kor`, 작업 폴더 `/data/local/tmp/nx4-kor`, 상태 파일 `/data/local/tmp/nx4-kor-*.txt`
  - 관리 앱:
    - 이름 "NX4 KOR"(원본 "Korea Projection"), 안드로이드 패키지 `io.github.jayparklab.nx4kor`(원본 `korea.projection.app`)
    - 소스 `app/`, APK `NX4KOR.apk`, 서명 키는 저장소 밖(`.env.local`의 `NX4_APP_KEYS`, `scripts/build-app.sh`)
    - 화면이 열릴 때 `hmgapid service-start launch`를 부르고, 상태 파일이 새로 쓰이면 다시 그립니다
- **시험:** `tests/mod-test.sh`를 새로 넣었고 `tests/ReportTest.java`는 남은 기능에 맞췄습니다. 원본의 `tests/stub-test.sh`는 뺐습니다.
- **문서:** `README.md`, `docs/design.md`, `usb/README.txt`
- **한국 카플레이 길안내(2026-11-25, [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67)):** `nx4-kor`에 `hooks.jar`(소스 `hooks/src`, 빌드 `scripts/build-hooks.sh`)와 `settings.json`(`kor_tbt`, `kor_tbt_log`)을 다시 넣었습니다. 공식 무선 모드 옆 DiPO 안에서 카플레이 길안내를 따로 받아 Korea Projection의 보정으로 계기판·HUD에 보냅니다. 가져온 코드는 아래 "Korea Projection의 카플레이 길안내 보정", 이 저장소가 새로 쓴 것은 `Nx4KorHooks.java`, `KorTbt.java`(리스너·다시 보내기·다시 요청 배선은 공식 모드와 KP의 `Dipo.java`를 따름, 계기판 호출 덮어쓰기는 새로 씀), `TbtGate.java`(덮어쓰기·비켜 주기·남의 멈춤 미루기·중복 호출 줄이기 판단), `ClusterOut.java`(공식 모드가 실어 간 같은 값의 계기판 호출을 건너뜀, 2026-11-26 #77), `PhoneBarOut.java`(KP와 같은 꼴, 아무것도 보내지 않음), 테스트 `tests/tools/HookPlanCheck.java`·`TbtGateTest.java`와 `tests/fixtures/`입니다.
- **2.1.0 USB 설치기(2026-11-23):** `usb/troubleShooter`가 HMG-API 쪽 일을 모두 맡습니다. 공식 무선 모드 설치(`--any-car`), 옛 2.0.x 되돌리기, 이 차의 map 만들기·확인, 계획 확인 뒤 적용입니다. `scripts/build.sh`는 공식 무선 모드 zip을 USB 묶음에 그대로 넣고(`scripts/fetch-wireless.sh`, 아래 "공식 무선 모드"), 옛 2.0.x의 되돌리기 스크립트를 이 저장소의 태그 `v2.0.4-beta.1`에서 그대로 꺼내 `NX4/legacy-2.0/`에 넣습니다.

## HMG-API (VysseCodes, AGPL-3.0)

- https://github.com/Open-HMG/HMG-API (예전 주소 `VysseCodes/HMG-API`)
- 이 저장소(소스)에는 HMG-API의 코드가 들어 있지 않습니다. `hooks.jar`는 HMG-API의 런타임 소스에 대고 컴파일만 하고(`scripts/build-hooks.sh`, `HMGAPI_SRC`), 그 클래스는 넣지 않습니다(차에서는 HMG-API가 올림). 공식 무선 모드에서 온 것은 아래 "Korea Projection의 카플레이 길안내 보정"에 적은 것뿐입니다. 릴리스 USB 묶음에는 HMG-API와 공식 무선 모드를 고치지 않고 함께 넣습니다(HMG-API는 `HMGAPI-SOURCE.txt`, 무선 모드는 아래 "공식 무선 모드").
  - 2.0.x에 합쳤던 무선 모드 2.4.5(Korea Projection이 HMG-API 무선 모드를 한국 차용으로 고친 판, 포크 `StopDragon/HMG-API`의 `korea-build` 브랜치)는 2.1.0에서 통째로 뺐습니다. 그 판의 묶음과 대응 소스 안내는 2.0.x 베타 태그(`v2.0.4-beta.1` 등)의 `wireless/README.md`에 있습니다. 그중 카플레이 길안내 보정만 2026-11-25에 그 브랜치의 새 커밋에서 다시 가져왔습니다(아래).
- `scripts/build.sh`는 HMG-API의 `tools/mkmodpkg.sh`로 모드를 서명합니다. USB 설치기 `usb/troubleShooter`는 HMG-API USB 설치기와 같은 방식(DSP Update OTA)을 씁니다.

## Korea Projection의 카플레이 길안내 보정 (StopDragon, HMG-Seogaemo, VysseCodes, AGPL-3.0)

`hooks/`(한국 카플레이 길안내, [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67))에 가져온 코드입니다. 모두 GNU AGPL-3.0(이 저장소와 같음)이고, 파일마다 머리말에 출처와 이 저장소가 바꾼 것을 적었습니다.

| 이 저장소의 파일 | 가져온 곳 | 바꾼 것 |
|---|---|---|
| `hooks/src/io/github/jayparklab/nx4kor/hook/dipo/CpTurnsFit.java` | Korea Projection(StopDragon) `StopDragon/HMG-API` 브랜치 `korea-build` 커밋 `ebca56f3824a2234e48b336abda927d7a635e243`(무선 모드 2.4.10, Korea Projection 1.8.1. 2026-11-25에는 `6258357`에서 가져왔고 2026-11-26에 다시 가져옴), `mods/wireless-carplay-aa/src/hmgapi/mods/wireless/dipo/CpTurnsFit.java`. 그 바탕은 공식 무선 모드의 `CpTurns.java`(VysseCodes)이고, 일부(대체 아이콘, 각도 띠, 다시 보내기, 차선 그림 `LaneGlyphs` 등)는 HMG-Seogaemo(seogaemo, https://github.com/seogaemo/hmg-seogaemo, 커밋 `26eeb97e`)에서 왔습니다(파일 머리말의 KP 줄) | 패키지, 로그(`Dipo.log` → `KorTbt.log`), `CpTurns.exactIcon`·`CpTurns.distStrState` → `CpIcons`, 고르는 곳 `make()`를 뺌, 진단 줄 한도 `DIAG_LOGS_MAX`를 1200에서 300으로(2026-11-26), 계기판을 `ClusterOut`으로 보냄(공식 모드가 실어 간 같은 값은 다시 보내지 않음)·`diagTurn`·`logManeuver`는 한도를 먼저 봄·HUD 목록 줄은 `kor_tbt_log`일 때만 300줄까지(2026-11-26, #77), 일반 도로 곧 회전 거리 `D_GENERAL` 350 m → 600 m(2026-11-26, 사용자 결정) |
| `hooks/src/.../hook/dipo/CpTbt.java` | 같은 커밋의 `CpTbt.java` | 패키지 |
| `hooks/src/.../hook/dipo/CpIcons.java` | 같은 커밋의 `CpTurns.java`의 `exactIcon`(순정 한국 DiPO 표, 공식 모드 `icon()` 바탕)과 `distStrState`(표시 거리 문자열 상태, 기록용) | 그 두 함수만 따로 둠 |
| `hooks/src/.../hook/dipo/PhoneBarOut.java` | 커밋 `6258357`의 `PhoneBarOut.java`의 꼴(`ebca56f`에서도 같음) | 아무것도 보내지 않음(받는 쪽 `TrapBar`를 가져오지 않음) |
| `hooks/stubs/com/tcc/iap2/*.java` 4개 | 공식 무선 모드(VysseCodes) `Open-HMG/hmgapi-wireless-cp-aa` 태그 `v2.2.0-rc.9`의 `wireless-carplay-aa/stubs/com/tcc/iap2/` | 그대로(컴파일할 때만 쓰고 `hooks.jar`에는 넣지 않음) |
| `tests/fixtures/wireless-carplay-aa-2.2.0-rc.9-hooks.json` | 같은 태그의 `wireless-carplay-aa/mod.json`에서 `id`·`version`·`hooks.points`만 | 그 셋만 남김 |

- 저작자: Korea Projection(StopDragon), HMG-Seogaemo(seogaemo), 공식 무선 모드와 HMG-API(VysseCodes). 원저작권은 각 저작자에게 있습니다.
- 대응 소스: 이 저장소의 태그(릴리스마다), 그리고 위 커밋·태그.

## 공식 무선 모드 wireless-carplay-aa (VysseCodes, AGPL-3.0)

- https://github.com/Open-HMG/hmgapi-wireless-cp-aa
- 2.1.0부터 USB 묶음에 HMG-API의 공식 무선 모드(Wireless CarPlay + Android Auto)를 **고치지 않고** 그대로 넣습니다(`NX4/wireless/wireless-carplay-aa.zip`, 그 zip에서 꺼낸 `NX4/wireless/mod.json`).
  - USB 설치기(`usb/troubleShooter`)가 투싼 NX4에 HMG-API의 "Install anyway"(`hmgapid engine install --any-car`)로 설치합니다. NX4가 공식 모드의 차 목록에 없기 때문입니다.
- 파일: 릴리스 `v2.2.0-rc.9`의 `wireless-carplay-aa-2.2.0-rc.9.zip`(HMG-API 모드 zip, 작성자 서명 포함, 102,012바이트)
  - 공식 모드 zip SHA-256 `1df29d9223357d60604e433c54ff4877753f7b35cdf77373eea9d2a99534ccb9`
  - 이 저장소의 빌드는 이 파일을 그 릴리스에서 직접 받습니다(`scripts/fetch-wireless.sh`). SHA-256이 위 값과 같을 때만 넣고, 풀거나 고치지 않습니다.
  - USB 맨 위 `WIRELESS-SOURCE.txt`에 넣은 판과 SHA-256, 대응 소스 위치를 적습니다.
- 라이선스: GNU AGPL-3.0(이 저장소와 같음)
- 대응 소스: https://github.com/Open-HMG/hmgapi-wireless-cp-aa/tree/v2.2.0-rc.9

## USB Wi-Fi 동글 드라이버 (`drivers/`, GPL-2.0)

- 2.2.0에서 USB Wi-Fi 동글을 지원하려고 넣었습니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)). 이 폴더는 저장소의 다른 부분(AGPL-3.0)과 달리 **GNU GPL 2.0**입니다(전문 `drivers/COPYING`). 리눅스 커널 모듈인 드라이버가 GPL-2.0이기 때문입니다.
  - `drivers/` 밖의 `scripts/build-driver.sh`(이 폴더를 Docker로 돌리는 PC 스크립트)와 `.github/workflows/drivers.yml`은 저장소와 같은 AGPL-3.0입니다.
- 드라이버 원본: RTL88x2BU, https://github.com/cilynx/rtl88x2bu (Realtek, GPL-2.0), 커밋 `fc158d1f71b9e5dfcd1fccaf4d28725b65086e3b`. 저장소에는 넣지 않고 빌드할 때 받습니다.
- 드라이버 원본: RTL8831BU, https://github.com/hyeondg/rtl8831bu (Realtek 드라이버 v1.19.10), 커밋 `fed914c8931f3a768afe087dea9998965816f37e`. 저장소에 LICENSE 파일은 없고 소스 머리말이 Realtek의 GPL-2.0입니다. 저장소에는 넣지 않고 빌드할 때 받습니다.
- 내비 커널 소스: 현대모비스가 GPL에 따라 공개한 AVNT STD G50 WIDE(R9) 오픈소스(https://www.mobis.com/kr/tech/rnd.do#open)의 커널 폴더 `AVNT5W_TCC803XKK_kernel/`(Linux Kernel, GPL-2.0, 저작권 Hyundai Mobis·Telechips 등). 드라이버를 내비 커널과 같은 트리로 빌드하는 데 씁니다.
  - 원본 묶음은 sha256 `e7533517e65fb0af24a989ea4a7877cffcb29bed02a21c99b9277b1668c3bb20`입니다. 그 커널 폴더를 고치지 않고 묶어 이 저장소의 릴리스 `src-mobis-avnt5w-r9`에 모비스 고지 원본(`OSB_202606110414354220.zip`)과 함께 올려 두고, 빌드는 그것을 받습니다(`drivers/README.md` "커널 소스 자산"). 저장소에는 넣지 않습니다.
  - 그 안의 툴체인 묶음 `toolchain/arm-eabi-4.7.tar.gz`(GCC 4.7, GPL)로 컴파일합니다.
- 커널 뼈대: kernel.org `linux-3.18.24`(GPL-2.0). 모비스 커널 폴더에 없는 맨 위 `Makefile`·`scripts/` 등을 채웁니다. 빌드할 때 받습니다.
- 이 저장소가 쓴 것: 보호 패치 `drivers/rtl88x2bu/0001-nx4-protect.diff`·`drivers/rtl8831bu/0001-nx4-protect.diff`, 순정 HAL에 맞추는 패치 `drivers/rtl88x2bu/0002-nx4-hal.diff`·`drivers/rtl8831bu/0002-nx4-hal.diff`, 빌드 맞춤 `drivers/rtl8831bu/0003-nx4-build.diff`, `drivers/kernel/prepare.sh`·`Dockerfile`·`inputs.sh`·`lib.sh`·`config-sum.sh`·`build-in-container.sh`(GPL-2.0), `scripts/build-driver.sh`(AGPL-3.0). 자세한 것은 `drivers/README.md`.

## BusyBox (GPL-2.0)

- https://busybox.net
- 모드에 `bin/busybox`가 들어 있습니다(Korea Projection 1.7.0부터 들어 있던 것과 같은 파일).
  - busybox가 없는 내비에서도 이 모드의 스크립트(관리 앱이 부르는 스크립트)를 돌리려고 함께 넣었습니다. 내비에 `/system/bin/busybox`가 있으면 그것을 쓰고, 이 파일은 쓰지 않습니다.
- BusyBox는 NX4 KOR와 따로 동작하는 프로그램이고, AGPL-3.0이 아니라 **GNU GPL 2.0**으로 배포됩니다. 이 파일은 고치지 않았습니다.
- 파일: BusyBox v1.36.1, Alpine Linux 3.20 `busybox-static-1.36.1-r31` 패키지의 `/bin/busybox.static`(ARMv7 정적 링크, 877,900바이트)
  - SHA-256 `3d31efecd4d09625a5d04597ad857f3475d35e6d63a3365912a7edd4c60770a5`
  - 이 저장소의 빌드는 이 파일을 Alpine 저장소에서 직접 받습니다(`scripts/fetch-busybox.sh`: `dl-cdn.alpinelinux.org`의 v3.20 main armv7 패키지에서 이 파일만 꺼냄). 받은 패키지 파일과 꺼낸 파일의 SHA-256이 각각 아래·위 값과 같을 때만 넣습니다.
  - 패키지 파일 `busybox-static-1.36.1-r31.apk`(armv7)의 apk SHA-256 `be29041c1584a296c8fa3bbc4488c233ad23936dcbd45abceb90c09e0aa9aadb`
  - Korea Projection에 들어 있던 것도 Alpine 서명을 확인하는 `apk add busybox-static`(Docker `alpine:3.20`, linux/arm/v7)으로 받은 같은 파일입니다.
- 대응 소스
  - BusyBox 1.36.1: https://busybox.net/downloads/busybox-1.36.1.tar.bz2
  - Alpine 빌드 설정·패치(`APKBUILD`, 설정 파일, 패치): https://gitlab.alpinelinux.org/alpine/aports/-/tree/3.20-stable/main/busybox
- 라이선스 원문: https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
- 소스를 받기 어려우면 이 저장소의 이슈로 알려 주세요. 위 소스를 직접 보내 드립니다.
