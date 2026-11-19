# 고지 (NOTICE)

Korea Projection은 GNU AGPL-3.0입니다(`LICENSE`). 아래는 다른 프로젝트에서 가져오거나 바탕으로 삼은 부분과 그 원저작권입니다.

## 이 저장소의 변경 (jay-park-lab/hmgapi-nx4-kor, parkjoos, 2026-11-19부터, AGPL-3.0)

이 저장소(https://github.com/jay-park-lab/hmgapi-nx4-kor)는 Korea Projection(StopDragon, https://github.com/StopDragon/korea-projection, AGPL-3.0)을 2026-11-19에 고친 판입니다. 원본은 커밋 `e5221e0`(Korea Projection 1.7.4 뒤)입니다. 라이선스는 원본과 같은 AGPL-3.0이며, 바꾼 내용의 자세한 기록은 이 저장소의 git 기록에 있습니다.

- **더한 것:** NEMESIS 없이 HMG-API 모드로 설치하는 판(투싼 NX4 전용)
  - `standalone/`: `nx4-kor/mod.json`, 서비스 래퍼(`standalone/ap.sh`·`launch.sh`·`uninstall.sh`·`env.sh`), USB 설치기(`usb/troubleShooter`, `usb/README.txt`), `README.md`
  - `scripts/build-standalone.sh`: HMG-API의 `tools/mkmodpkg.sh`로 서명한 모드 zip과 USB 묶음을 만든다
  - `tests/standalone-test.sh`
- **바꾼 것:** 환경 변수가 있을 때만 다르게 돈다(없으면 원본과 같다)
  - `nemesis-pkg/korea.projection/svc/hotspot.sh`: `KP_APP_BY_HMGAPI=1`이면 상태 화면 앱 설치·삭제를 HMG-API에 맡긴다
  - `nemesis-pkg/korea.projection/scripts/post.sh`, `scripts/preun.sh`: `BK`·`KP_APP`를 받는다. `preun.sh`는 `KP_UPDATE=1`이면 업데이트 갈래로 끝나고, HMG-API를 먼저 지운 경우(`hmgapid`도 설치 기록도 없음) 남은 무선 모드 폴더를 지우고 권한 파일 되돌리기까지 간다
  - `nemesis-pkg/korea.projection/bin/status.sh`: `KP_APLOG`로 기록 위치를 받는다
  - `nemesis-pkg/app-src/java/io/github/jayparklab/nx4kor/StatusActivity.java`: 화면이 열릴 때 `hmgapid service-start launch`를 부르고, 상태 파일이 새로 쓰이면 다시 그린다
- **이름을 바꾼 것:** 원본과 섞이지 않게
  - HMG-API 모드 id `nx4-kor`(앱 목록 이름 "NX4 KOR: Tucson NX4 (Korea)"), USB 폴더 `NX4/`, 차 안 작업 폴더 `/data/nx4-kor`, 결과 파일 `hmgapi-nx4-kor-<판>.zip`·`-usb.zip`
  - 상태 화면 앱: 이름 "NX4 KOR"(원본 "Korea Projection"), 안드로이드 패키지 `io.github.jayparklab.nx4kor`(원본 `korea.projection.app`), 소스 폴더 `nemesis-pkg/app-src/java/io/github/jayparklab/nx4kor/`, APK `NX4KOR.apk`, 서명 키 `~/.local/share/hmgapi-nx4-kor/keys/`(`scripts/build-app.sh`). `svc/hotspot.sh`의 앱 id·요청 파일 경로도 따라 바꿨다
  - 그대로 둔 것: 원본 NEMESIS 패키지 id `korea.projection`(원본 판과 함께 설치되지 않게 알아보는 데 씀), 상태 파일 `/data/local/tmp/korea-projection-*`, 함께 넣는 무선 모드 id `wireless-carplay-aa`
- **뺀 것:** NEMESIS 버전 판정. `bin/status.sh`의 `nemesis version` 수집·`oldnemesis` 판정·상태 파일 `nemesis=`, 앱 `Report.java`의 최소 NEMESIS 버전·상태표 칸·QR 키
- **시험:** `tests/stub-test.sh`, `tests/ReportTest.java`의 기대값(상태표 14줄, 상태 키 42개)을 위 변경에 맞췄다
- **문서:** `README.md`를 이 포크 기준으로 다시 썼다

## NEMESIS (xwtk, AGPL-3.0)

- https://github.com/xwtk/hmg_nemesis
- Korea Projection은 NEMESIS 패키지(`korea.projection`)로 설치되고, NEMESIS의 패키지 형식(`NEMESIS.data`)과 서비스 실행 방식을 따릅니다.

## HMG-API (VysseCodes, AGPL-3.0)

- https://github.com/Open-HMG/HMG-API (예전 주소 `VysseCodes/HMG-API`)
- `nemesis-pkg/korea.projection/hmgapi/wireless-carplay-aa.zip`: HMG-API v1.0.2의 "Wireless CarPlay + Android Auto" 모드 2.1.0에 한국 차 데이터를 더하고 Korea Projection 개발 키로 다시 서명한 것입니다.
  - 바꾼 부분과 대응 소스, 다시 만드는 방법은 `hmgapi-mod/README.md`에 있습니다.
  - 1.5.6까지는 코드(`hooks.jar`)가 업스트림과 같습니다.
- `nemesis-pkg/korea.projection/hmgapi/maps/`: HMG-API map 형식의 차별 훅 map입니다. HMG-API `tools/report-map.py`로 만들었습니다.
- `nemesis-pkg/app-src/java/io/github/jayparklab/nx4kor/QrCode.java`: HMG-API의 QR 코드 생성 코드에서 `package` 줄만 바꿨습니다.
- 1.5.7부터 모드 코드(`hooks.jar`, 모드 2.1.1)가 업스트림과 다릅니다. 소스는 포크 `StopDragon/HMG-API`의 `korea-build` 브랜치(업스트림 `v1.0.2`에서 시작)에 있습니다.
  - 업스트림 main의 커밋 `83eb4ef`(Narayan, "Fix CarPlay turns for left-hand traffic and omitted angles")를 그대로 가져왔습니다.
  - 계기판·HUD 회전 안내(`dipo/CpTurns.java`, `dipo/Dipo.java`)를 고쳤습니다. 바꾼 내용과 날짜는 파일 머리말 주석에 있습니다.

## HMG-Seogaemo (seogaemo, AGPL-3.0)

- https://github.com/seogaemo/hmg-seogaemo (커밋 `26eeb97e`)
- 1.5.7 모드의 `dipo/CpTurns.java`에 seogaemo의 `modules/wireless-carplay-and-aa/payload/src/hmgapi/mods/wireless/dipo/CpTurns.java.src`에서 다음을 옮겨 쓰고 HMG-API 구조에 맞게 고쳤습니다.
  - 아이콘 대체 규칙(`fallbackIcon`, `bandedTurn`, `roundaboutIcon`, 빈 아이콘 `NO_ICON`)
  - HUD 빈 목록, 앞쪽 회전 아이콘 47~50
  - 안내 상태 주기 재전송(refresh)과 HUD 목록 재전송
- 옮긴 부분은 소스 주석에 "from HMG-Seogaemo"로 표시했습니다.

## BusyBox (GPL-2.0)

- https://busybox.net
- 1.7.0부터 릴리스 패키지(`korea.projection-*.zip`, USB 묶음 안의 `packages/korea.projection.zip`)에 `bin/busybox`가 들어 있습니다. 1.6.x 시험판에도 들어 있었고, 1.5.6에는 없습니다.
  - busybox가 없는 내비(K3·K8 등 tcc803x)에서 Korea Projection 스크립트를 돌리려고 함께 넣었습니다. 내비에 `/system/bin/busybox`가 있으면 그것을 쓰고, 이 파일은 쓰지 않습니다.
- BusyBox는 Korea Projection과 따로 동작하는 프로그램이고, AGPL-3.0이 아니라 **GNU GPL 2.0**으로 배포됩니다. 저희는 이 파일을 고치지 않았습니다.
- 파일: BusyBox v1.36.1, Alpine Linux 3.20 `busybox-static-1.36.1-r31` 패키지의 `/bin/busybox.static`(ARMv7 정적 링크, 877,900바이트)
  - SHA-256 `3d31efecd4d09625a5d04597ad857f3475d35e6d63a3365912a7edd4c60770a5`
  - Alpine 서명을 확인하는 `apk add busybox-static`(Docker `alpine:3.20`, linux/arm/v7)으로 받았습니다.
- 대응 소스
  - BusyBox 1.36.1: https://busybox.net/downloads/busybox-1.36.1.tar.bz2
  - Alpine 빌드 설정·패치(`APKBUILD`, 설정 파일, 패치): https://gitlab.alpinelinux.org/alpine/aports/-/tree/3.20-stable/main/busybox
- 라이선스 원문: https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
- 소스를 받기 어려우면 이슈로 알려 주세요. 위 소스를 직접 보내 드립니다.
