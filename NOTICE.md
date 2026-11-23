# 고지 (NOTICE)

NX4 KOR는 GNU AGPL-3.0입니다(`LICENSE`). 아래는 다른 프로젝트에서 가져오거나 바탕으로 삼은 부분과 그 원저작권, 그리고 이 저장소에서 바꾼 것입니다.

## 이 저장소의 변경 (jay-park-lab/hmgapi-nx4-kor, parkjoos, 2026-11-19부터, AGPL-3.0)

이 저장소(https://github.com/jay-park-lab/hmgapi-nx4-kor)는 Korea Projection(StopDragon, https://github.com/StopDragon/korea-projection, AGPL-3.0)을 2026-11-19부터 고친 판입니다. 원본은 커밋 `e5221e0`(Korea Projection 1.7.4 뒤)입니다. 라이선스는 원본과 같은 AGPL-3.0이며, 바꾼 내용의 자세한 기록은 이 저장소의 git 기록에 있습니다.

- **HMG-API 모드 하나로 바꿨습니다(2026-11-19).**
  - NEMESIS 패키지(`NEMESIS.data`, NEMESIS 서비스·Launch·설치·삭제)를 HMG-API 모드 `nx4-kor`(`mod/mod.json`)로 바꿨습니다.
    - 서비스는 `svc/ap.sh`·`svc/launch.sh`로, 삭제는 `bin/uninstall.sh`로 옮겼습니다. 위치는 `svc/env.sh`에서 정합니다.
    - USB 설치기 `usb/troubleShooter`와 빌드 `scripts/build.sh`를 새로 넣었습니다.
  - 따로 설치하던 무선 모드 `wireless-carplay-aa` 2.4.5(한국 차 빌드)를 이 모드에 합쳤습니다.
    - 합친 것: `hooks.jar`, `recipes/`, `files/`, `settings.json`, `patches.json`의 changes, `mod.json`의 `parts`·`feature_flags`·`hooks`. 바이트는 바꾸지 않았고, `settings.json`의 설명 한 줄만 고쳤습니다.
    - 원래 `mod.json`은 `wireless/mod-2.4.5.json`, 컴파일용 stubs는 `wireless/stubs/`에 둡니다.
    - 2026-11-23: 순정 핫스팟 기능을 켜던 `patches.json`의 `featurexml.cfg` 줄 주석(part `projection`)을 빼고, `mod.json`의 `"wifi": {"hotspot": true}`로 HMG-API에 맡겼습니다. HMG-API 공식 무선 모드가 rc.8에서 한 것과 같은 길입니다(`wireless/README.md`).
  - `svc/hotspot.sh`의 자동 설정을 바꿨습니다.
    - 무선 모드 설치·업데이트 대신, 이 모드의 무선 기능을 HMG-API 1.1.0의 이 차 map(`state/local-map.json`)으로 확인하고 적용합니다.
    - `bin/status.sh`의 판정과 상태 파일 키, `scripts/post.sh`·`scripts/preun.sh`도 그에 맞췄습니다.
    - 삭제 때는 HMG-API에서 이 모드를 빼고 적용합니다.
- **뺀 것:**
  - NEMESIS 관련: NEMESIS 버전 판정, NEMESIS판·wireless.projection과의 충돌 확인, NEMESIS 문구
  - 다른 차: 차 목록, 차별 map, 패치 세트, 니로 featurexml 되돌리기
  - 제보 기능: 상태 화면의 제보 파일 만들기·QR, `bin/carreport.sh`, 리포트, USB 진단·로그 꺼내기
  - 그 밖: 이슈 자동 분류 워크플로·이슈 양식, 후원 링크, NEMESIS용 문서·빌드(`docs/install-guide.md`, `docs/car-report-guide.md`, `scripts/build-usb.sh`)
- **이름을 바꾼 것:** 원본과 섞이지 않게
  - HMG-API 모드 id `nx4-kor`(앱 목록 이름 "NX4 KOR: Tucson NX4 (Korea)"), USB 폴더 `NX4/`, 결과 파일 `hmgapi-nx4-kor-<판>.zip`·`-usb.zip`
  - 차 안 위치: 기록 `/data/nx4-kor`, 작업 폴더 `/data/local/tmp/nx4-kor`, 상태 파일 `/data/local/tmp/nx4-kor-*.txt`
  - 상태 화면 앱:
    - 이름 "NX4 KOR"(원본 "Korea Projection"), 안드로이드 패키지 `io.github.jayparklab.nx4kor`(원본 `korea.projection.app`)
    - 소스 `app/`, APK `NX4KOR.apk`, 서명 키는 저장소 밖(`.env.local`의 `NX4_APP_KEYS`, `scripts/build-app.sh`)
    - 화면이 열릴 때 `hmgapid service-start launch`를 부르고, 상태 파일이 새로 쓰이면 다시 그립니다
- **시험:** `tests/mod-test.sh`를 새로 넣었고 `tests/ReportTest.java`는 남은 기능에 맞췄습니다. 원본의 `tests/stub-test.sh`는 뺐습니다.
- **문서:** `README.md`, `docs/design.md`, `usb/README.txt`, `wireless/README.md`
- **2.1.0 USB 설치기(2026-11-23):** `usb/troubleShooter`가 HMG-API 쪽 일을 모두 맡습니다. 공식 무선 모드 설치(`--any-car`), 옛 2.0.x 되돌리기, 이 차의 map 만들기·확인, 계획 확인 뒤 적용입니다. `scripts/build.sh`는 공식 무선 모드 zip을 USB 묶음에 그대로 넣고(`scripts/fetch-wireless.sh`, 아래 "공식 무선 모드"), 옛 2.0.x의 되돌리기 스크립트를 이 저장소의 태그 `v2.0.4-beta.1`에서 그대로 꺼내 `NX4/legacy-2.0/`에 넣습니다.

## HMG-API (VysseCodes, AGPL-3.0)

- https://github.com/Open-HMG/HMG-API (예전 주소 `VysseCodes/HMG-API`)
- 이 모드의 무선 부분(`mod/hooks.jar`, `mod/recipes/`, `mod/files/libleafiaaac.so`, `mod/settings.json`, `mod/patches.json`, `mod/mod.json`의 `parts`·`feature_flags`·`hooks`)은 HMG-API의 "Wireless CarPlay + Android Auto" 모드(지금은 https://github.com/Open-HMG/hmgapi-wireless-cp-aa)를 Korea Projection이 한국 차용으로 고친 2.4.5입니다.
  - 바꾼 부분과 대응 소스, 다시 만드는 방법은 `wireless/README.md`에 있습니다.
  - Korea Projection 1.5.6까지는 코드(`hooks.jar`)가 업스트림과 같습니다.
- 1.5.7부터 모드 코드(`hooks.jar`, 모드 2.1.1부터)가 업스트림과 다릅니다. 소스는 포크 `StopDragon/HMG-API`의 `korea-build` 브랜치(업스트림 `v1.0.2`에서 시작)에 있습니다.
  - 업스트림 main의 커밋 `83eb4ef`(Narayan, "Fix CarPlay turns for left-hand traffic and omitted angles")를 그대로 가져왔습니다.
  - 계기판·HUD 회전 안내(`dipo/CpTurns.java`, `dipo/Dipo.java`)를 고쳤습니다. 바꾼 내용과 날짜는 파일 머리말 주석에 있습니다.
- `scripts/build.sh`는 HMG-API의 `tools/mkmodpkg.sh`로 모드를 서명합니다. USB 설치기 `usb/troubleShooter`는 HMG-API USB 설치기와 같은 방식(DSP Update OTA)을 씁니다.

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

## HMG-Seogaemo (seogaemo, AGPL-3.0)

- https://github.com/seogaemo/hmg-seogaemo (커밋 `26eeb97e`)
- 모드 2.1.1부터의 `dipo/CpTurns.java`에 seogaemo의 `modules/wireless-carplay-and-aa/payload/src/hmgapi/mods/wireless/dipo/CpTurns.java.src`에서 다음을 옮겨 쓰고 HMG-API 구조에 맞게 고쳤습니다.
  - 아이콘 대체 규칙(`fallbackIcon`, `bandedTurn`, `roundaboutIcon`, 빈 아이콘 `NO_ICON`)
  - HUD 빈 목록, 앞쪽 회전 아이콘 47~50
  - 안내 상태 주기 재전송(refresh)과 HUD 목록 재전송
- 옮긴 부분은 소스 주석에 "from HMG-Seogaemo"로 표시했습니다.

## BusyBox (GPL-2.0)

- https://busybox.net
- 모드에 `bin/busybox`가 들어 있습니다(Korea Projection 1.7.0부터 들어 있던 것과 같은 파일).
  - busybox가 없는 내비에서도 이 모드의 스크립트를 돌리려고 함께 넣었습니다. 내비에 `/system/bin/busybox`가 있으면 그것을 쓰고, 이 파일은 쓰지 않습니다.
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
