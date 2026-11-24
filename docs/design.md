# NX4 KOR 설계

## 2.1.0 새 구조(계획)

2026-11-23에 방향을 다시 정했습니다([#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38), 할 일 [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45), 마일스톤 [2.1.0](https://github.com/jay-park-lab/hmgapi-nx4-kor/milestone/1)). 2.1.0은 다음 셋으로 됩니다.
- HMG-API(1.1.0-rc.8 이상)
- 공식 무선 모드 `wireless-carplay-aa`(2.2.0-rc.9 이상, 고치지 않음, NX4에는 `--any-car`로 설치)
- 이 저장소의 NX4 추가분

| 일 | 맡는 곳 | 2.0.x에서 |
|---|---|---|
| 무선 카플레이·AA 훅, 계기판·HUD 길안내 | 공식 무선 모드. 한국 맞춤(`tbt_fit`, `aa_name_hold`, `star_popup_skip`, 한국어 UTF-8 AA 레시피)이 필요하면 공식 모드에 기여 | 한국 포크 2.4.5를 이 모드에 합쳐 씀(2.1.0에서 뺌, 아래 "2.1.0 모드 구성") |
| 프로젝션 AP, 순정 핫스팟 기능 | HMG-API(`"wifi": {"projection": true}`) | `svc/hotspot.sh`가 순정 `hostapd`·`dnsmasq`로 직접 띄움 |
| HMG-API 설치·업데이트, 공식 모드 설치, NX4 map, 진단, 되돌리기(옛 NX4 KOR 2.0.x 정리 포함, 2.0.x는 `conflicts: ["wireless-carplay-aa"]`라 공식 모드와 함께 설 수 없음) | 이 저장소의 USB 설치기 | 설치기와 `setup_hmgapi` |
| 설치 진행·판정 화면 | 이 저장소의 상태 화면 앱(지금 UI 유지, 지우기 버튼은 두지 않음 [#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)). 판정은 새 구조에 맞춤 | 같은 앱 |
| USB Wi-Fi 동글 | 이 저장소(나중에) | 없음 |

- 공식 모드가 `replace`하는 훅 지점은 이 저장소의 추가 모드가 다시 걸 수 없습니다. 같은 지점을 `replace`하는 모드 둘은 함께 켜지지 않습니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)).
- HMG-API는 모드를 지울 때 선언한 것(`patches.json`, `apps`, `services` 등)만 되돌리고, 지울 때 부르는 콜백이 없습니다(rc.8). 그래서 새 구조에서는 바꾸는 것을 선언으로 둡니다. 그래야 HMG-API 앱에서 지워도 남는 것이 없습니다.
- 판: 베타도 판에 꼬리를 붙입니다(`2.0.4-beta.1`부터, `docs/git-flow.md` 규칙 4). 2.0.x의 마지막 `release/2.0.4`는 `main`에 합치지 않고 지웁니다(끝 커밋은 `v2.0.4-beta.1` 태그가 남김).
- 아래 절은 모두 2.1.0 코드입니다. USB 설치기(아래 "[설치·업데이트·지우기](#설치업데이트지우기-usbtroubleshooter)")가 HMG-API 쪽 일(옛 2.0.x 정리, 공식 무선 모드 설치, map 만들기·확인, 계획 확인 뒤 적용)을 모두 하고, nx4-kor 모드는 부팅 때 이 일을 하지 않습니다.

## 2.1.0 모드 구성 (`mod/`)

2.1.0의 `nx4-kor`는 상태 화면 앱과 그 앱이 부르는 서비스만 담은 HMG-API 모드입니다(#45 "지금 `nx4-kor` 모드에서 빼기"). 무선 카플레이·안드로이드 오토는 HMG-API와 공식 무선 모드가 맡고, 이 모드는 훅을 걸지 않으며 시스템 파일·Wi-Fi 설정을 바꾸지 않습니다.

> ⚠️ 2.1.0 구성은 차에서 아직 확인하지 않았습니다. PC 테스트(`tests/mod-test.sh`)와 HMG-API 1.1.0-rc.8 엔진(PC)에서만 확인했습니다. 2.0.x의 차 확인 결과(2026-11-23 NX4HEV 260902, USB 설치·map·상태 화면·진단 동작, Wi-Fi 부품 없음)는 [#23 기록](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23#issuecomment-7101713033)에 있습니다.

| `mod.json` 항목 | 하는 일 |
|---|---|
| `system` | `NX4`·`NX4HEV`, `KOR`, `260902`에만 설치됩니다 |
| `hmgapi` | `>=1.1.0-rc.8`(공식 무선 모드 2.2.0-rc.9가 요구하는 판) |
| `services` | `launch`(`svc/launch.sh`, root, 앱이 부를 때만) 하나 |
| `apps`, `provides.launcher` | 상태 화면 앱(`app/NX4KOR.apk`)과 앱 메뉴 타일. 타일 그림은 `icons/`의 순정 꼴 넷(낮·밤, 모드를 껐을 때의 회색 낮·밤)이고, 저장소의 `art/tile.svg`를 HMG-API `tools/mkicon.sh`로 만든 것입니다([#47](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/47)) |

- **빠진 것:** 한국 포크 무선 모드 2.4.5(`hooks`·`parts`·`feature_flags`, `hooks.jar`, 레시피 5개, `files/libleafiaaac.so`, `patches.json`, `settings.json`, 저장소의 `wireless/`), `"wifi": {"hotspot": true}`, `conflicts: ["wireless-carplay-aa"]`, 서비스 `ap`(`svc/ap.sh` → `svc/hotspot.sh`의 순정 `hostapd`·`dnsmasq` 핫스팟, Wi-Fi 설정 잠금, 칩 깨우기, 자동 설정 `setup_hmgapi`)와 `scripts/post.sh`. 공식 모드와 겹치는 훅이 남지 않습니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)).
- **`requires`로 공식 모드를 걸지 않습니다.** HMG-API는 요구한 모드가 없거나 꺼지면 이 모드의 앱·서비스까지 멈춥니다(rc.8 `docs/mod-reference.md` "Other mods", `engine/Engine.java` `visit`). 그러면 상태 화면이 그 사실을 알릴 수 없습니다. 대신 상태 화면이 공식 모드가 있는지·켜졌는지·판을 봅니다(아래 "상태 화면").
- **map 만들기·확인과 적용은 USB 설치기가 합니다**(#45, 다른 작업). 프로젝션 AP는 HMG-API가 공식 모드의 `"wifi": {"projection": true}` 요청으로 띄웁니다.
- 이 모드는 HMG-API에 선언한 것만 바꾸므로 HMG-API 앱에서 지워도 남는 것이 없습니다(상태 화면의 작업 파일 `/data/local/tmp/nx4-kor*`와 기록 `/data/nx4-kor`는 남음. USB `NX4/UNINSTALL`이 지움).

| 파일 | 하는 일 |
|---|---|
| `svc/env.sh` | 위치(`NX4_APP` 모드 폴더, `NX4_ROOT=/data/nx4-kor`, `APLOG`). `BK`는 2.0.x의 백업 폴더 이름(설치기가 옛 판을 알아보는 데 씀) |
| `svc/lib.sh` | 상태 화면과 지우기가 함께 쓰는 함수(busybox 고르기, 판 비교, 프로젝션 AP·Wi-Fi 칩 상태 읽기, 카플레이 연결 수, 재부팅 요청 받기). 2.0.x의 `svc/hotspot.sh`를 줄인 것입니다 |
| `svc/launch.sh` → `bin/status.sh` | 상태 파일(`/data/local/tmp/nx4-kor-status.txt`)과 재부팅 요청 감시자 |
| `bin/uninstall.sh` → `scripts/preun.sh` | 지우기(`engine remove`)·업데이트 전 정리 |

- **지우기**(`bin/uninstall.sh`): 상태 화면의 감시자를 멈추고 작업 파일을 지운 뒤 `hmgapid engine remove nx4-kor`를 합니다. HMG-API는 그때 앱·서비스 목록(`state/apps.txt`·`services.txt`)을 다시 써서 상태 화면 앱과 서비스를 내립니다(rc.8 `Packages.remove` → `LiveState.publish`). 이 모드는 적용할 것이 없으므로 계획을 보거나 적용하지 않습니다. 그다음 기록 폴더 `/data/nx4-kor`를 지웁니다.
  - 2.0.x의 백업 폴더(`$BK` = `/data/nx4-kor/backup`)가 있으면 그 폴더만 남깁니다. 2.1.0은 그 폴더를 만들지 않으므로, 있으면 2.0.x가 바꾼 것(Wi-Fi 설정 잠금, 치운 crc32 파일, 순정 AP 저장값)을 되돌릴 기록입니다. 출력에 "2.0.x USB(v2.0.4-beta.1) 또는 NX4 KOR 2.1.0 이후 USB의 UNINSTALL로 되돌려 주세요"를 남기고(설치기 `NX4/install.log`), 종료 코드는 0입니다(PR #50 리뷰 2·9).
  - `--update`(새 판으로 바꾸기 전)는 감시자와 작업 파일만 정리합니다. 설치 진행 기록은 USB 설치기가 쓰는 파일이라 두고, 지울 때만 지웁니다.
  - 2.0.x가 바꾼 것(Wi-Fi 설정 잠금, 무선 권한 파일, 순정 AP 저장값, 한국 포크 무선 기능)은 2.1.0의 지우기가 되돌리지 않습니다. USB 설치기가 2.1.0을 넣기 전에 옛 판 자신의 `bin/uninstall.sh`로 정리합니다.

## 상태 화면

- 앱이 열릴 때 `hmgapid service-start launch`를 부르고(hmgapid는 이 모드의 앱일 때만 받음), 상태 파일이 새로 쓰이면 다시 그립니다.
- 판정(`verdict`·`verdict_lv`·`verdict_msg`)은 `bin/status.sh`의 `st_verdict` 한 곳에서 정하고 앱은 그대로 보입니다. 앱은 오른쪽 칸의 판정·요약 3줄과 왼쪽 칸의 "자세히" 표를 상태 파일에서 그립니다. 화면 배치·디자인은 2.0.x와 같습니다(사용자 결정).
- 설치 진행(막대·단계·경과)은 USB 설치기가 쓰는 진행 기록 `/data/local/tmp/nx4-kor-progress.txt`(`pct state stage start t boot step ust ut`)를 2.0.x와 같은 방식으로 읽습니다.
- **판정**은 "HMG-API + 공식 무선 모드 + 이 모드" 구조를 봅니다. 읽기만 하고 아무것도 바꾸지 않습니다. 앞에서부터 처음 맞는 것이 판정입니다.

  | 차례 | 판정(`verdict`) | 보는 것 |
  |---|---|---|
  | 1 | `bootguard` | HMG-API 부팅 보호(커널 로그 zygote 줄, `hook/starts`) |
  | 2 | `installing` | 이번 부팅 진행 기록 `state=run` |
  | 3 | `nocar`(지우는 법 함께) | 투싼 NX4 한국 260902가 아님 |
  | 4 | `nohmgapi`, `oldhmgapi` | HMG-API(`installed.txt`)가 없거나 1.1.0-rc.8보다 낮음. 판 비교는 HMG-API `Version`·USB 설치기와 같은 규칙(rc 꼬리까지) |
  | 5 | `reboot`, `failed` | 이번 부팅 진행 기록 `state=reboot`, `state=fail`(설치기가 `stage`에 쓴 이유 문장을 그대로 보임) |
  | 6 | `nowireless`, `wirelessoff`, `oldwireless` | 공식 무선 모드 `wireless-carplay-aa`가 없음, HMG-API 앱에서 꺼 둠(`.disabled`), 2.2.0-rc.9보다 낮음 |
  | 7 | `hooksoff` | HMG-API 훅이 꺼짐(마지막 `hook map: …, hooks off` 줄). map 상태(`none`·`mismatch`·`mapped`)에 따라 안내가 다름 |
  | 8 | `wmhooksoff` | 공식 모드의 훅이 안 켜짐(HMG-API 로그 `mods: wireless-carplay-aa not loaded: …`). 같은 지점을 `replace`하는 다른 모드와 겹치면(`conflict`, #17) 겹치는 모드를 끄라고 안내 |
  | 9 | `bridgeoff` | 공식 모드 설정의 Wireless CarPlay(`bridge`)가 꺼짐 |
  | 10 | `nofeat` | 무선 카플레이 기능(`com.hkmc.software.connectivity.carplay_wireless`)이 아직 꺼짐 |
  | 11 | `noproj` | HMG-API에 공식 모드의 프로젝션 AP 요청이 없음(`state/wifi.txt`의 `projection wireless-carplay-aa` 줄) |
  | 12 | `connected` | 무선 카플레이 연결(로컬 포트 7000의 ESTABLISHED, Wi-Fi 쪽 주소) |
  | 13 | `otherwifi` | 순정(netd)이 아닌 `hostapd`(다른 무선 패키지, USB 동글 패키지 등) |
  | 14 | `aphotspot` | AP가 일반 핫스팟 SSID(softap.conf의 S1)로 떠 있음 |
  | 15 | `ready` | AP가 떠 있음(프로젝션 AP는 카플레이 SSID S2) |
  | 16 | `wificlient` | AP 없이 Wi-Fi 클라이언트(`wpa_supplicant`, HMG-API 집 Wi-Fi 포함)가 돎. HMG-API는 이때 라디오를 건드리지 않음 |
  | 17 | `apoff` | 이번 부팅에 떴다가 지금 꺼짐(`wifi/ap.boot`) |
  | 18 | `apwait` | 부팅 뒤 5분 전이고 AP가 아직 없음(`wifi/ap.fail`이 있어도). HMG-API 지기는 첫 시도가 실패하면 바로 `ap.fail`을 쓰고 다시 시도하며, 칩이 SDIO에 늦게 올라오는 첫 부팅도 있어 이 사이에는 "부품 없음"·"못 켬"으로 굳히지 않습니다 |
  | 19 | `nowifipart` | **Wi-Fi 부품이 없는 차**: 부팅 뒤 5분이 지났고, 순정 핫스팟 기능(칩 전원)은 켜졌는데 칩이 SDIO에 한 번도 안 보였고(HMG-API `public/wifi-chip`도 없음), `wlan0`이 없고, HMG-API가 이번 부팅에 AP를 띄우지 못함(`wifi/ap.fail`만). 2026-11-23 NX4HEV 260902가 이랬습니다. 유선 카플레이·안드로이드 오토와 계기판 길안내는 그대로라 "안 됨"으로 끝내지 않고(노랑), 무선은 USB Wi-Fi 동글([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48))을 기다립니다 |
  | 20 | `apfail` | 부팅 뒤 5분이 지나도 AP를 띄우지 못함(`wifi/ap.fail`, 또는 기록 없음). USB 동글처럼 `wlan0`이 있는 차도 여기로 옵니다 |

  - HMG-API의 프로젝션 AP 기록은 HMG-API Wi-Fi 지기(rc.8 `engine/HomeWifi.java`, 서비스 `hmgapi wifi`)의 것입니다. 부팅마다 Android Wi-Fi 서비스가 뜨자마자 한 번 띄우고, 이번 부팅 id를 `wifi/ap.boot`(떴거나 이미 떠 있었음, Wi-Fi 클라이언트가 켜져 있어 두었음)나 `wifi/ap.fail`(다시 시도 중)에 씁니다. 그 줄은 `/data/hmgapi/logs/hmgapi/wifi.log`에 남습니다. 차가 나중에 끈 AP는 지기가 다시 켜지 않고, 폰이 붙을 때 공식 모드가 다시 켭니다(rc.8 `hmgapi.hook.Wifi.projectionAp`).
  - 상태 파일 키: `wm`·`wm_ver`·`wm_on`·`wm_hooks`·`bridge`(공식 모드), `hooks`·`hookmap`(HMG-API 훅), `feat_carplay`·`feat_aa`·`feat_hotspot`·`feat_wifi`(순정 기능), `chip`·`wlan0`(Wi-Fi 칩·장치), `proj`·`ap_boot`·`ap_fail`·`ap`·`ap_mode`·`other_ap`·`wpa`(프로젝션 AP), `cp_conn`, `state`. 이름·버전·예/아니요·개수만 넣고 SSID·비밀번호·휴대폰 이름·MAC·IP는 넣지 않습니다.
  - 2.0.x 서비스가 쓰던 상태 안내 `/data/local/tmp/nx4-kor-hint.txt`(아이폰·AA 안내)는 2.1.0에 쓰는 곳이 없습니다. 앱은 그대로 읽지만 보통 아무것도 보이지 않습니다.
- [지금 재부팅]은 앱 개인 폴더의 `reboot.req`를 `status.sh --watch`(화면을 연 뒤 10분)가 받습니다. 설치 중(진행 기록 `run`), `/system`을 바꾸는 작업 중(HMG-API 적용·remount 등), HMG-API 부팅 보호에 걸릴 때는 거절합니다.
- 진단 기록 확인 창(`DiagActivity`)은 USB 설치기가 엽니다(아래 "진단 기록"). 투명 화면 위에 확인 창만 보이고, 답을 앱 개인 폴더의 `diag.ans`에 씁니다.
- **모양**은 투싼 NX4 순정 내비(표준형 5세대 와이드)의 타입1(어두운 화면)에 맞춥니다([#28](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/28)).
  - 색·글자 크기·여백은 `app/java/.../Ui.java` 한 곳에 둡니다. 값은 현대 국내형 Gen5W 웹 매뉴얼 그림에서 잰 근사값입니다. 크기는 1920x720 기준 px로 적고 화면 폭에 맞춰 늘이거나 줄입니다.
  - 결과 화면(본보기: 순정 설정 상세):
    - 위 제목 줄: 가운데 제목, 왼쪽 위 `<`가 [닫기]입니다.
    - 왼쪽 칸(1280): 요약 3줄을 흰 제목·회색 값의 목록 줄로, 그 아래 "자세히" 표, 맨 아래 확인 시각·앱 판·화면 크기 줄을 둡니다.
    - 오른쪽 칸(640, 분할 화면 자리): 판정, 지우는 법, 상태 안내, 알림을 두고, 맨 아래에 [지금 재부팅] 주 버튼 블록을 둡니다. 버튼 안내(보냄·거절·실패)는 버튼 바로 위에 나옵니다.
  - 설치 진행 화면(본보기: 순정 안내 화면): 가운데에 제목·단계·시안 막대·%·경과 시간·알림·안내를 두고, 맨 아래에 [닫기] 블록을 둡니다.
  - 색 띠는 문제일 때만 씁니다(2026-11-20 결정).
    - 정상인 판정과 좋은 소식 안내는 순정처럼 시안 세로 표시와 글자만 씁니다.
    - 확인 필요(노랑)·문제(빨강) 판정, 할 일이 있는 안내(노랑), 알림(연노랑)은 운전 중 한눈에 보이게 색을 채운 띠로 둡니다.
  - 글꼴은 시스템 기본 글꼴입니다. 독점 글꼴 파일은 넣지 않습니다.
  - 재부팅 확인 창은 순정 팝업 모양을 몰라 Holo `AlertDialog` 그대로입니다.
- 앱 메뉴 타일(`provides.launcher`)은 HMG-API가 이 모드를 올릴 때 런처 훅으로 넣습니다(rc.8 `hook/Mods.java`, 이 모드는 자기 훅이 없어도 타일이 생김). HMG-API 훅이 꺼진 동안(이 차의 map이 없거나 부팅 보호)에는 타일이 없습니다(앱·서비스는 그대로). 그때는 같은 USB로 Update OTA를 다시 누르면 상태 화면이 열립니다.

## 설치·업데이트·지우기 (`usb/troubleShooter`)

**2.1.0 구조입니다.** Engineering Mode → USB Copy → DSP → Update OTA가 `ota_package.tar`의 `troubleShooter`를 root로 돌립니다(HMG-API USB 설치기와 같은 길). HMG-API 쪽 일은 모두 이 설치기가 합니다. 예전(2.0.x)에는 모드 서비스(`setup_hmgapi`)가 부팅 뒤 map 만들기·확인과 적용을 했습니다.

스틱의 `NX4` 폴더:

| 경로 | 내용 |
|---|---|
| `install/hmgapi-nx4-kor.zip`, `install/payload/` | nx4-kor 모드(서명됨)와 그것을 푼 것(판 확인, 모드가 이미 지워졌을 때의 되돌리기) |
| `wireless/wireless-carplay-aa.zip`, `wireless/mod.json` | 공식 무선 모드(공식 릴리스 파일 그대로, `scripts/fetch-wireless.sh`)와 그 zip의 `mod.json`(판·HMG-API 최소 판을 zip을 풀지 않고 읽음) |
| `legacy-2.0/` | 옛 2.0.x의 되돌리기 스크립트(태그 `v2.0.4-beta.1`에서 그대로, `scripts/build.sh`). 2.0.x를 HMG-API 앱에서 지운 차를 되돌림 |
| `hmgapi/troubleShooter` | 같은 스틱에 함께 푼 HMG-API USB 묶음의 설치기 |
| `UNINSTALL`, `UNINSTALL-ALL`, `REINSTALL` | 아래 "지우기", "같은 판" |

**HMG-API 확인**(아무것도 바꾸기 전)
- HMG-API가 없으면 같은 스틱의 HMG-API 설치기로 넘기거나 멈춥니다.
- 최소 판은 설치기의 `HMG_MIN`(`1.1.0-rc.8`)과 스틱의 두 모드 `mod.json` `hmgapi`(`>=…`) 중 가장 높은 것입니다. 설치된 판(`installed.txt`의 `version`)이 낮으면 같은 스틱의 HMG-API 설치기가 그 판 이상(`HMGAPI/install/payload/VERSION`)일 때 그것으로 넘기고(업데이트 뒤 재부팅, Update OTA를 한 번 더), 아니면 "HMG-API <최소 판> 이상으로 먼저 올려 주세요"로 멈춥니다.
- 판 비교는 HMG-API `Version`과 같은 규칙(semver, `-rc.N`까지)입니다. 최소 판에 꼬리가 없으면 그 판의 rc도 채웁니다(`meetsHmgapi`). 판을 읽지 못하거나 비교할 수 없는 꼬리면 기록만 하고 지나갑니다(엔진이 설치할 때 다시 봄).

**설치·업데이트 순서**(같은 판도 같은 순서로 돌고, 이미 된 단계는 건너뜁니다)
0. **스틱 확인**: 스틱의 nx4-kor(`payload/mod.json`)가 아직 옛 2.0.x 꼴(`conflicts`에 `wireless-carplay-aa`)이면 아무것도 바꾸지 않고 멈춥니다. HMG-API는 설치 때 `conflicts`를 보지 않아 설치는 되지만, 끝 계획이 conflict 문제로 막혀 2.0.x를 되돌린 뒤 아무것도 적용하지 못한 채 끝나기 때문입니다(PR #52 리뷰 2). 그래서 nx4-kor 2.1.0(PR #50)이 합쳐진 뒤에 만든 묶음만 씁니다. release 워크플로도 묶음의 `payload/mod.json`을 확인합니다.
   - 같은 판(다시 설치하지 않음)이고 상태 화면 앱이 있으면 여기서 상태 화면을 먼저 엽니다. 아래 단계에서 멈춰도 화면이 열립니다.
1. **시작 전 계획**(`engine plan`): 다음이면 아무것도 바꾸지 않고 멈춥니다. 끝에서 적용할 수 없기 때문입니다.
   - 다른 모드의 적용하지 않은 변경(`change`·`update`·`setting`·`bind`)이나 HMG-API 밖에서 바뀐 파일(`rebase`)
   - 되돌리기 줄(`restore … (stock)`, `setting … back to stock`, `unbind`)이 있는데 이번에 지울 모드(옛 2.0.x, 2.0.x의 기록만 남은 것, 한국 차 빌드)가 없음. 되돌리기 줄에는 모드 이름이 없어, 이때는 앞서 다른 모드를 지우고 적용하지 않은 것입니다(PR #52 리뷰 1)
   - `engine plan`의 종료 코드가 0(계획)이나 3(문제 목록)이 아님. 예: rc.8의 "an earlier apply isn't finished or is a trial"(종료 1). 종료 코드는 `install.log`의 `--- engine plan (<꼴>, 종료 코드 <n>)` 줄에 남깁니다(`PLANFAIL_MSG`). 옛 2.0.x를 뺀 뒤의 계획이나 지우기 길에서 그러면 같은 문구로 끝납니다
   - 문제(`problem`, `nothing changed: N problem(s)`)는 시작 전에 거르지 않습니다. 어느 모드의 문제인지 줄로 가르기 어렵고, 옛 2.0.x와 한국 차 빌드의 conflict처럼 이번 실행이 푸는 문제도 있기 때문입니다. 그래서 다른 모드의 문제가 늘 남은 차는 설치·map 만들기를 다 한 뒤 끝 계획에서 `HOOKS_MSG`로 막힙니다(PR #52 리뷰 8). 그런 차는 HMG-API가 원래 아무것도 적용하지 못하는 상태이고, 끝 문구가 HMG-API 앱에서 보라고 안내합니다
2. **옛 NX4 KOR 2.0.x 되돌리기**(`old_revert`): 설치된 nx4-kor의 `mod.json` `conflicts`에 `wireless-carplay-aa`가 있으면 2.0.x로 봅니다(판 번호로 가르지 않음. `develop`의 판은 `release/`에서만 바뀜). 공식 모드와 함께 설 수 없으므로 끝까지 되돌린 뒤에만 새로 설치합니다.
   - 설치된 모드 폴더를 작업 폴더로 복사 → `engine remove nx4-kor` → 계획이 되돌리기와 우리 두 모드의 것뿐이면 `engine apply` → 옛 판의 `bin/uninstall.sh`를 사본으로 돌림.
   - 까닭: 2.0.x의 `preun.sh`는 HMG-API rc.7부터 계획에 늘 나오는 설명 줄(`home Wi-Fi`, `network`)을 변경으로 봐 적용하지 않고, 그러면 무선 권한 파일 되돌리기(`perms_revert`)도 건너뜁니다. 설치기가 먼저 빼고 적용하면 `preun.sh`는 "HMG-API에 이 모드가 없음"으로 보고 이 모드가 직접 바꾼 것(무선 권한 파일, Wi-Fi 잠금, 순정 AP 저장값)을 되돌리고 기록(`/data/nx4-kor`)을 지웁니다.
   - 뺀 뒤의 계획에 다른 모드의 변경이 있으면 적용하지 않고 멈춥니다("HMG-API 앱에서 적용").
   - 2.0.x의 기록(`/data/nx4-kor/backup`, 2.1.0은 쓰지 않음)이 남은 차는 스틱의 `NX4/legacy-2.0`으로 같은 차례로 되돌립니다(2026-11-23 사용자 결정). nx4-kor가 없는 차(HMG-API 앱에서 2.0.x를 지움)와, 2.0.x 위에 2.1.0 이후가 들어간 차(adb·HMG-API 앱으로 넣음. 2.1.0의 `uninstall.sh`는 이 기록을 남김) 모두입니다. 2.1.0 이후가 있으면 먼저 HMG-API에서 빼고(`engine remove`) 적용한 뒤 되돌리고, nx4-kor를 다시 설치합니다(상태 화면은 그 뒤에 엶, PR #52 리뷰 7). 그 폴더는 `scripts/build.sh`가 태그 `v2.0.4-beta.1`에서 그 판의 `bin/uninstall.sh`·`scripts/preun.sh`·`svc/env.sh`·`svc/hotspot.sh`·`mod.json`을 고치지 않고 꺼내 넣은 것입니다(`SOURCE`에 태그와 커밋). busybox는 설치기가 payload의 것을 사본에 넣습니다. 모드 폴더가 없으니 `engine remove`는 하지 않고, 앱 삭제가 적용되지 않아 계획에 남은 되돌리기 줄을 받아 적용한 뒤 그 `uninstall.sh`를 돌립니다.
     - 까닭: 2.1.0의 `bin/uninstall.sh`는 2.0.x가 바꾼 것을 되돌리지 못합니다(그 기록 폴더만 남김). 2.1.0을 둔 채 옛 `uninstall.sh`만 돌리면 옛 `preun.sh`가 2.1.0을 빼면서 rc.7부터의 설명 줄 때문에 적용과 권한 파일 되돌리기를 건너뜁니다. 그래서 설치기가 먼저 빼고 적용합니다.
     - `legacy-2.0`이 없는 스틱(직접 만든 묶음 등)이면 아무것도 바꾸지 않고 멈추고 2.0.x 릴리스 USB의 `NX4/UNINSTALL`로 안내합니다(`OLDLEFT_MSG`).
   - 2.1.0 이후의 기록만 남은 차는 스틱의 사본(`payload/bin/uninstall.sh`)으로 정리합니다. 실패해도 설치는 계속합니다.
3. **공식 무선 모드**(`wireless-carplay-aa`): 없거나 스틱의 판보다 낮으면 `hmgapid engine install <zip> --any-car`. NX4는 공식 모드의 `system` 목록에 없습니다. HMG-API는 `--any-car`를 `hmgapi.json` `overrides.ignore_system`에 남기고, 그 뒤 계획마다 `WARNING: wireless-carplay-aa: …`를 냅니다.
   - 차주가 넣은 것이라도 같거나 높은 판이면 그대로 둡니다(HMG-API는 낮은 판을 `--force` 없이 받지 않음). 판을 비교할 수 없으면 그대로 둡니다. `NX4/REINSTALL`이면 같은 판을 다시 설치합니다.
   - `mod.json` `name`에 "Korea Projection"이 든 것(한국 차 빌드 2.4.x, 같은 id)은 공식판이 아니고 작성자 키가 달라 그 위에 설치할 수 없습니다. 지우고(`engine remove`) 공식판을 설치합니다. 지우기는 2(옛 2.0.x 되돌리기)보다 먼저 합니다. 그래야 2의 적용에 한국 차 빌드의 적용하지 않은 변경이 섞이지 않습니다.
   - 꺼 둔 것(`.disabled`)은 켭니다(`hmgapid enable`).
4. **nx4-kor**: 같은 판이면 건너뜁니다(`NX4/REINSTALL`이면 다시). 업데이트면 돌던 서비스를 적어 두고 `bin/uninstall.sh --update` → `engine install` → 그 서비스를 다시 띄웁니다. 거절되면 예전 판의 서비스를 다시 띄우고 실패로 끝냅니다. 그다음 상태 화면을 엽니다.
5. **map**(2.0.x `hotspot.sh` `setup_hmgapi`와 같은 규칙): 이 차의 map(`state/local-map.json`)이 없으면 `engine map-car --write`(1~2분)로 만듭니다. "not written: HMG-API has a map"이면 HMG-API의 map을 씁니다. 그다음 늘 `engine verify-map`으로 확인합니다(확인을 통과해야 다음 시작부터 훅이 켜짐, `state/map-check.json`). 확인에 실패하면 이번에 만든 map만 지웁니다(`map-car --forget`). 이미 있던 map은 지우지 않습니다. 어느 쪽이든 적용하지 않고 실패로 끝냅니다.
6. **적용**: 계획(`plan_check final`)이 우리 두 모드(`[nx4-kor]`, `[wireless-carplay-aa]`, 둘이 함께인 `[nx4-kor, wireless-carplay-aa]`)의 변경과, 이번에 지우거나 판을 바꿔 설치한 모드의 되돌리기(`restore … (stock)`, `setting … back to stock`, `unbind`)뿐이고, 훅이 켜질 때(`hooks are off`·`hooks <id> won't load` 없음)만 `engine apply`를 합니다. `problem` 줄이나 모르는 줄이 있어도 적용하지 않습니다.
   - 설명 줄은 변경이 아닙니다: `app`·`service`·`usb`, `event`·`vehicle`·`driving`·`panel`·`button`, `home Wi-Fi`·`wifi`·`network`·`projection`, `note`·`probe`·`override`·`skip`·`WARNING`, `hooks … share it`, `<id>: part … left out`(HMG-API rc.4·rc.8 소스에서 확인). `mod-test.sh`가 HMG-API 엔진(PC)의 실제 계획으로도 봅니다.
7. 무엇이 바뀌었으면(옛 판 정리, 모드 설치·켜기, 처음 통과한 map 확인, 적용) 진행 기록을 "재부팅 필요"로 끝내고 상태 화면의 [지금 재부팅]을 안내합니다. 바뀐 것이 없으면 "설정이 끝나 있습니다"입니다. 설치기는 재부팅하지 않습니다.

**진행 기록**: `/data/local/tmp/nx4-kor-progress.txt`를 2.0.x 서비스(`hotspot.sh` `prog`)와 같은 꼴로 씁니다. 상태 화면 앱(`Report.java`)이 그대로 읽어 막대를 보입니다.
- 줄 차례: `pct`, `state`(`run`·`done`·`reboot`·`fail`), `stage`(한국어 문구), `start`, `t`, `boot`(이번 부팅 id), `step`(진행 중일 때 `<단계>/6`), `ust`, `ut`. 644로 씁니다.
- 단계: 1 시작, 2 옛 판 정리, 3 공식 무선 모드, 4 NX4 KOR, 5 map 만들기·확인, 6 적용. 건너뛰는 단계가 있습니다.
- 무엇을 바꾸기 시작한 뒤(시작 전 계획 확인 뒤)에만 씁니다. 그 전에 멈추면(HMG-API 없음·낮음, 다른 모드의 변경) 쓰지 않습니다.
- 끝의 `stage` 문구는 설치기 머리말의 `*_MSG` 값입니다. 상태 판정(`bin/status.sh`)이 이 문장으로 판정 코드를 가르므로 바꾸면 함께 봅니다. `OTHERPLAN_MSG`·`APPLYFAIL_MSG`·`DONE_REBOOT_MSG`·`DONE_MSG`는 2.0.x 서비스와 같은 문장입니다.

**같은 판**: 상태 화면을 맨 앞(위 0)에서 엽니다. 그래서 뒤 단계에서 멈춰도 화면이 열리고, 타일이 없을 때 상태 화면을 여는 길로도 씁니다(HMG-API가 없거나 응답하지 않으면 그 전에 멈춥니다). nx4-kor는 다시 설치하지 않고, 공식 무선 모드는 스틱보다 낮을 때만 올리며, map은 없을 때만 만듭니다. 그다음 map 확인과 계획을 봅니다.

**지우기**
- `NX4/UNINSTALL`: nx4-kor만 지웁니다. HMG-API, 공식 무선 모드, 이 차의 map은 남깁니다.
  - 설치된 모드의 `bin/uninstall.sh` → `scripts/preun.sh`(상태 화면 작업 파일 지우기 → HMG-API에서 이 모드를 뺌. 2.1.0은 시스템 파일을 바꾸지 않아 적용할 것이 없음) → 기록 지우기 → 재부팅.
  - 옛 2.0.x면 위 2와 같이 설치기가 먼저 빼고 되돌리기만 적용한 뒤(`plan_check revert`) 옛 판의 `uninstall.sh`를 사본으로 돌립니다.
  - HMG-API를 먼저 지웠어도 남은 모드 폴더나 스틱의 사본으로 되돌립니다. 이때 `/system`은 DSP OTA 프로세스에서 순정 `mount`로 엽니다.
  - 2.1.0 이후의 `uninstall.sh`는 2.0.x의 기록(`/data/nx4-kor/backup`)을 되돌리지 못해 그 폴더만 남깁니다(2.0.x 위에 adb·HMG-API 앱으로 2.1.0을 넣은 차, PR #50). 그러면 설치기가 스틱의 `NX4/legacy-2.0`으로 마저 되돌립니다.
  - 모드 폴더 없이 2.0.x의 기록(`/data/nx4-kor/backup`)만 남았으면 스틱의 `NX4/legacy-2.0`으로 되돌립니다(위 2와 같음). HMG-API도 없으면 계획·적용 없이 그 사본의 `uninstall.sh`만 돌립니다. `legacy-2.0`이 없는 스틱이면 지우지 않고 멈춥니다.
- `NX4/UNINSTALL-ALL`: 위와 같고, 그 뒤 공식 무선 모드도 `engine remove`하고 계획이 되돌리기뿐이면 적용합니다. 공식 무선 모드만 남은 차에서도 됩니다(그때 결과 문구는 "공식 무선 모드를 지웠습니다"). 계획에 다른 변경이 있으면 적용하지 않고 "HMG-API 앱에서 변경 사항을 적용해 주세요(무선 모드 삭제)"로 알립니다. HMG-API와 map은 남깁니다(2026-11-23 사용자 결정).
- 상태 화면에는 지우기 버튼을 두지 않습니다(2026-11-24 사용자 결정, [#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)).
  - 2.1.0의 nx4-kor는 시스템 파일·Wi-Fi 설정을 바꾸지 않습니다. 그래서 HMG-API 앱에서 지워도 HMG-API가 앱·서비스·타일을 내리고, 기록 파일(`/data/nx4-kor`, `/data/local/tmp/nx4-kor*`)만 남습니다. 남은 기록은 `NX4/UNINSTALL`로 지웁니다.
  - 그래서 앱이 자기 자신을 지우는 흐름(감시자가 지우기 스크립트를 임시 폴더로 옮겨 돌림)은 만들지 않습니다.
- 기록: 스틱의 `NX4/install.log`에 이어 씁니다. 시작할 때 스틱의 앞 기록을 내비 쪽 기록(`/data/local/tmp/nx4-kor-usb.log`)으로 옮겨 두고, 끝날 때 그 전체를 스틱에 씁니다. 그래서 여러 번 눌러도 앞의 시도가 남고(빈 줄로 나뉨), 한 번 누른 기록은 한 번만 들어갑니다. 비우려면 스틱에서 그 파일을 지웁니다.
- 진단 기록(`diag`): 공식 무선 모드를 이 차에서 시험하기 전에 알아 둘 것([#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38))을 adb 없이 가져오려고 둡니다.
  - **먼저 화면에서 묻습니다**(`ask_diag`). Car Report가 map 만들기와 같은 분석(MapProbe)을 돌려 1~2분 걸리기 때문입니다(PR #41 리뷰 1).
    - 스틱에 `NX4` 폴더가 있으면 지우기·설치·같은 판 어느 갈래든, **아무것도 바꾸기 전에** 상태 화면 앱의 확인 창을 엽니다(`am start -n io.github.jayparklab.nx4kor/.DiagActivity --es id <id> --ei wait 60 --el until <지금+15초>`).
    - 확인 창은 앱 개인 폴더의 `files/diag.ans`에 `<id> <답>` 한 줄을 씁니다. 열리면 `shown`, [모으기]는 `yes`, [건너뛰기]·뒤로는 `no`, 60초 안에 고르지 않으면 `timeout`을 쓰고 스스로 닫힙니다. 설치기는 자기가 준 id의 답만 믿습니다.
    - `until`은 설치기가 창이 뜨기를 기다리는 마지막 시각입니다. 그 뒤에 늦게 열린 창은 설치기가 이미 넘어가 아무도 답을 읽지 않으므로, 아무것도 쓰지 않고 바로 닫힙니다(PR #41 리뷰 6).
    - 확인 창은 자기 task로 열립니다(매니페스트 `taskAffinity=""`). 이번 부팅에 상태 화면을 열었어도 그 위에 얹히지 않고, 창 뒤에 DSP OTA 화면이 보입니다(PR #41 리뷰 7).
    - **[모으기]를 고른 때만** 스틱의 `NX4/diag/<시각>/`에 새로 모읍니다. 그 밖에는 모으지 않고 `install.log`에 까닭만 적은 뒤 설치기가 그대로 이어집니다.
      - 상태 화면 앱이 없음(HMG-API가 앱을 설치하기 전, 첫 설치)
      - 확인 창이 없는 예전 판 앱(`am start`가 Error를 냄), 또는 창이 15초 안에 뜨지 않음
      - [건너뛰기]·뒤로, 고르지 않음, 답이 오지 않음(최대 60초 + 30초)
    - 그래서 확인 창이 없는 예전 판(2.0.1-beta.1까지)에서 올리는 첫 Update OTA에서는 모으지 않습니다. 설치·설정이 끝나고 재부팅한 뒤 같은 USB로 한 번 더 누르면(같은 판: 상태 화면만 엶) 확인 창이 뜨고, 적용된 뒤의 상태가 담깁니다. 순정 md5는 `hmgapi-status.txt`에 있습니다.
    - 결과 안내(토스트)는 모은 뒤에 나오므로 마지막 문구가 가려지지 않습니다.
  - 담는 것:

    | 파일 | 내용 |
    |---|---|
    | `info.txt` | 스틱·설치된 모드 판, HMG-API 판, `getprop` 몇 개(`ro.build.product` 등), `/system/bin/busybox` 유무, md5에 쓴 busybox, `settings get global wifi_on`·`wifi_ap_on` |
    | `system-lib-md5.txt` | `/system/lib` 아래(하위 폴더 포함) 모든 파일과 링크의 md5와 경로. 공식 모드의 네이티브 레시피(`libCarPlayCore.so`, `libiap2session.so` 등)가 이 차의 라이브러리에 맞는지 PC에서 견줍니다 |
    | `system-lib-ls.txt` | 같은 폴더의 `ls -lR`(이름·크기·링크 대상). busybox 없이 모읍니다 |
    | `features.txt`, `permissions-ls.txt`, `featurexml-<onebin>.cfg` | 지금 켜진 순정 기능(`pm list features`), `/system/etc/permissions` 목록, 기능을 지우는 순정 설정 사본. Wi-Fi 칩 전원이 달린 순정 핫스팟 기능이 켜졌는지 봅니다(2.0.x 자동 설정의 "핫스팟 기능을 먼저 켜는 갈래") |
    | `hmgapi-status.txt` | `hmgapid engine status`. HMG-API가 바꾼 파일마다 순정·기대·지금 md5가 있어, 모드가 적용된 뒤에도 순정 md5를 압니다 |
    | `car-report.txt`, `car-report-*.json`·`.md` | `hmgapid engine report`(HMG-API Car Report)의 출력과 보고서 파일. 이 차에서 찾은 훅 지점(`map_car`), map 확인, 기능, 모드, 오류가 들어 있습니다. HMG-API가 VIN·일련번호를 넣지 않고 기록 줄을 가립니다 |
    | `logs/` | 이 모드의 `ap.log`, 서비스 기록(`/data/hmgapi/logs/nx4-kor/`), `/data/local/tmp/nx4-kor/*.txt`(map 만들기·확인·계획·적용 결과), `/data/local/tmp/nx4-kor-*.txt`(상태 파일), HMG-API 설치 기록 |

  - md5는 busybox로 셉니다. 내비의 `/system/bin/busybox`, 설치된 모드의 `bin/busybox`, 스틱의 `payload/bin/busybox`(`/data/local/tmp`로 복사해 실행하고 지움) 순으로 실행되는 첫 것을 씁니다. 모두 없으면 그렇다고 적고 이름·크기만 남깁니다.
  - HMG-API 명령(`engine status`·`report`)은 HMG-API가 응답할 때만 부릅니다. 둘 다 읽기만 합니다(Car Report는 HMG-API 폴더의 `public/reports`에도 씀).
  - 비밀번호가 든 Wi-Fi 설정 파일(`softap.conf`, `hostapd-nx4.conf`, `wpa_supplicant.conf`)과 이 모드의 백업 폴더(`/data/nx4-kor/backup`)는 넣지 않습니다.
  - 못 모은 것은 `install.log`에 적고 넘어갑니다. 설치·지우기 결과는 바꾸지 않습니다.

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
- busybox(BusyBox 1.36.1, Alpine 저장소에서 받아 `NOTICE.md`의 SHA-256과 맞을 때만. [`release.md`](release.md) "busybox")와 그 라이선스 안내(GPL-2.0, 대응 소스 위치): 모드의 `bin/busybox`·`bin/busybox-LICENSE.txt`, USB 맨 위 `BUSYBOX-LICENSE.txt`. 안내가 없으면 묶음을 만들지 않습니다.
- HMG-API USB 묶음을 함께 넣으면 그 판과 소스 위치: USB 맨 위 `HMGAPI-SOURCE.txt`
- USB `README.txt`에 이 묶음을 만든 소스 커밋을 적습니다(커밋하지 않은 수정이 있으면 그렇다고 적음).

## 다른 패키지·모드와 함께 쓸 때

2.1.0의 이 모드는 훅을 걸지 않고 Wi-Fi를 직접 쓰지 않습니다. 부딪히는 것은 공식 무선 모드와 HMG-API 프로젝션 AP 쪽이고, 이 모드는 상태 화면으로 알리기만 합니다.

| 함께 있는 것 | 일어나는 일 | 상태 화면 |
|---|---|---|
| NEMESIS로 설치한 무선·핫스팟 패키지(Korea Projection, 무선 패키지 등) | 그 패키지의 `hostapd`가 HMG-API 프로젝션 AP와 Wi-Fi를 다툽니다 | 순정(netd)이 띄운 것이 아닌 `hostapd`가 돌고 연결이 없으면 `otherwifi`(그 패키지를 지우고 재부팅). 설치기가 막을지는 [#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13) |
| 공식 무선 모드와 같은 훅 지점에 `replace` 훅을 거는 다른 HMG-API 모드(한국 계기판 맞춤 등) | HMG-API는 모드를 id 순서(`requires`로 이어진 모드가 먼저, 그다음 id 이름순)로 올리고, 같은 지점을 `replace`하는 뒤쪽 모드의 훅을 통째로 끕니다(계획 `hooks <id> won't load: conflict: …`, HMG-API 로그 `mods: <id> not loaded: conflict: …`). `wireless-carplay-aa`보다 id가 앞인 모드와 겹치면 공식 모드가 꺼집니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)) | 공식 모드가 꺼진 쪽이면 `wmhooksoff`(HMG-API 앱의 Mods에서 겹치는 모드를 끔). 한국 맞춤은 공식 모드에 기여하는 길로 갑니다(#38) |
| 공식 무선 모드를 꺼 두거나 지움 | 무선 카플레이·안드로이드 오토와 계기판 길안내가 없습니다. 이 모드는 `requires`로 걸지 않아 상태 화면은 그대로 열립니다 | `wirelessoff`, `nowireless` |
| HMG-API의 "집 Wi-Fi"(HMG-API 앱 설정 > Home Wi-Fi, 기본 꺼짐) | 차를 끈 지 30초 뒤나 주차하면 HMG-API가 프로젝션 AP를 끄고 내비의 Wi-Fi 클라이언트로 집 Wi-Fi에 붙고, 차가 켜지면 되돌립니다(rc.8 `engine/HomeWifi.java`). 둘 다 HMG-API가 하므로 2.0.x처럼 Wi-Fi 설정 잠금과 부딪히지 않습니다 | 클라이언트가 도는 동안 `wificlient` |
| 순정 일반 핫스팟을 켬(핫스팟 메뉴가 있는 차) | HMG-API 지기는 이미 떠 있는 AP를 그대로 둡니다. 일반 핫스팟 SSID로 떠 있으면 폰이 카플레이 Wi-Fi를 찾지 못할 수 있습니다 | `aphotspot`(순정 핫스팟을 끄고 재부팅) |

## 차에서 확인할 것

- **HMG-API가 NX4에서 map을 만들고(`map-car --write`) 확인(`verify-map`)을 통과하는지.** 실패하면 무선 기능을 적용하지 않습니다(`/data/local/tmp/nx4-kor/map-car.txt`, `verify-map.txt`).
- **공식 무선 모드(2.2.0-rc.9)의 훅 41개 지점이 NX4 map으로 켜지는지.** 하나라도 없으면 HMG-API가 그 모드의 훅을 끕니다(HMG-API 로그 `mods: wireless-carplay-aa not loaded: …`, 상태 화면 `wmhooksoff`). 켜지면 `mods: loaded wireless-carplay-aa …`가 남고 상태 화면 표의 "공식 무선 모드"가 "…, 켜짐"입니다. 공식 스택 차 테스트(#45 "정하기·차에서 보기")와 함께 봅니다.
- **공식 모드의 네이티브 레시피가 NX4 라이브러리에 맞는지**(`libCarPlayCore.so` 등). 맞지 않는 레시피는 아무것도 쓰지 않습니다. USB 진단 기록의 `system-lib-md5.txt`(순정 상태일 때)나 `hmgapi-status.txt`의 순정 md5로 레시피의 기대 md5와 견줍니다.
- **USB 진단 기록이 모이는지.**
  - 진단 확인 창이 DSP OTA 화면 위에 뜨는지, [모으기]·[건너뛰기]가 눌리는지(`install.log`의 "진단 기록: …" 줄).
  - [모으기] 뒤 `NX4/diag/<시각>/`가 생기고 `system-lib-md5.txt`에 md5가 있는지(`info.txt`의 `md5_busybox`가 무엇인지).
  - `car-report.txt`가 HMG-API의 "usage:"가 아니라 보고서인지(`engine report`가 없는 HMG-API 판이면 빠짐).
  - 모으는 데 얼마나 걸리는지. Car Report는 map 만들기와 같은 분석이라 1~2분을 어림합니다.
- **DSP OTA 뒤 재부팅하지 않고 끝내도 되는지.** OTA 화면이 이상하게 남으면 상태 화면의 [지금 재부팅]이나 RESET을 쓰세요.
- **DSP OTA 화면 위로 상태 화면이 열리는지**(`am start`). 안 열리면 재부팅 뒤 같은 USB로 Update OTA를 다시 누릅니다.
- HMG-API 설치기가 NX4의 `app_process`를 아는지(모르면 `HMGAPI/FORCE`).
- **Wi-Fi 부품이 없는 차에서 상태 화면이 "부품 없음"을 보이는지**(2026-11-23 NX4HEV 260902, 2.0.4-beta.1에서 순정 핫스팟 기능을 켜도 칩이 올라오지 않음, #38).
  - 공식 모드를 적용하고 재부팅한 뒤 HMG-API 기록 `/data/hmgapi/logs/hmgapi/wifi.log`에 `projection AP: not up yet, trying again (…)`이 남고, 상태 화면이 `nowifipart`(노랑, "Wi-Fi 부품이 없는 것으로 보여…")인지. 표의 "Wi-Fi 칩"이 "안 보임", "순정 핫스팟 기능"이 "예"인지
  - 부팅 뒤 5분 동안은 `apwait`("켜는 중")이고 그 뒤 `nowifipart`로 바뀌는지(첫 시도 실패로 `ap.fail`이 먼저 생겨도 5분 전에는 "부품 없음"이 나오지 않아야 함)
  - 유선 카플레이·안드로이드 오토와 계기판 길안내(공식 모드)가 그대로인지. HMG-API 지기가 부팅마다 AP를 다시 시도하면서(약 1분, 그 뒤 30초마다) 유선 연결이 끊기는지도 봅니다
  - 결과는 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에, 동글로 무선을 보는 일은 [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)에 적습니다.
- **함께 넣은 busybox가 NX4에서 도는지.** NX4 내비에 `/system/bin/busybox`가 없으면 상태 화면 스크립트는 모드의 `bin/busybox`(`/data/hmgapi/mods/nx4-kor/bin/busybox`)만 쓸 수 있습니다. 상태 화면이 "이 내비에서는 동작하지 않습니다(busybox를 실행하지 못함)"를 보이지 않아야 합니다.
- **HMG-API가 없는 차에서 릴리스 USB 하나로 설치되는지.** 첫 Update OTA에서 NX4 KOR 설치기가 스틱의 HMG-API 설치기(`NX4/hmgapi/troubleShooter`)로 넘겨 HMG-API가 설치되고 재부팅되는지, 두 번째 Update OTA에서 NX4 KOR가 설치되는지(USB의 `HMGAPI/install.log`, `NX4/install.log`).
- **HMG-API가 이 모드의 최소 판(1.1.0-rc.8)보다 낮은 차에서 HMG-API를 먼저 올리는지.** 첫 Update OTA가 따로 설치한 무선 모드(`wireless-carplay-aa`)를 지우지 않고 HMG-API 설치기의 업데이트 갈래로 HMG-API를 올린 뒤 재부팅하는지, 두 번째에 NX4 KOR가 설치되는지. HMG-API 설치기를 `/storage/upgrade`가 아니라 스틱의 `NX4/hmgapi`에서 `exec`로 돌리는 길은 차에서 처음 돕니다. NEMESIS로 설치한 HMG-API라면 NEMESIS 목록의 판도 함께 봅니다.
- **칩이 있는 차(또는 동글 뒤)에서 HMG-API 프로젝션 AP를 상태 화면이 바르게 읽는지.**
  - 부팅 뒤 `wifi.log`에 `projection AP: up in mode 2 (requested by wireless-carplay-aa)`(또는 `already up`)가 남고, 상태 화면이 `ready`, 표의 "무선 연결용 Wi-Fi"가 "켜짐"인지. 이 판정은 netd가 띄운 `hostapd` 설정의 `ssid=`가 softap.conf의 카플레이 SSID(S2)인지로 합니다(`svc/lib.sh` `ap_ssid`). 순정 일반 핫스팟 SSID(S1)면 `aphotspot`입니다.
  - 폰을 무선으로 붙이면 `connected`와 "카플레이 N대 연결됨"이 나오는지(로컬 포트 7000, Wi-Fi 쪽 주소)
  - 순정 무선 카플레이가 있는 트림에서도 같은지
  - 이 갈래들은 `tests/mod-test.sh`가 가짜 `ps`·`/proc`·softap.conf로 봅니다. 실제 `hostapd`의 부모·설정 경로·SSID가 그 꼴인지는 차에서만 확인됩니다.
- **HMG-API rc.8에서 이 모드의 `launch` 서비스가 도는지.** rc.5부터 `hmgapid`는 모드 서비스를 실효 그룹 2950(`MOD_GID`)과 `ANDROID_DNS_MODE=local`로 돌립니다. 상태 화면을 열면 상태 파일이 새로 쓰이고(화면 아래 "확인 …" 시각이 바뀜), [지금 재부팅]이 받아지면 확인한 것으로 봅니다.
- **상태 화면 모양이 차에서 맞게 보이는지**(#28 순정 5W 모양). 결과는 [#28](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/28)과 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에 적습니다.
  - 화면 아래 정보 줄의 화면 크기와 밀도. 크기는 화면 폭에 맞춰 늘이고 줄이므로 1920 폭이 아니면 글자가 함께 커지거나 작아집니다.
  - 시스템 상태 줄(시각 등)이 앱 위를 덮는지. 결과 화면의 화면 안 닫기는 왼쪽 위 `<` 하나뿐이라, 덮으면 `<`가 가려집니다. 그때는 제목 줄 높이를 고칩니다(#28 "정할 것" 4).
  - 순정 설정 화면과 나란히 보고 색·글자 크기·줄 높이가 맞는지. 다르면 `Ui.java` 값을 고칩니다.
  - 재부팅 확인 창(Holo)의 모양, 버튼을 누를 때의 색, 주간·야간 밝기에서 띠와 시안 글자가 잘 보이는지.
- **앱 메뉴 타일과 앱 아이콘이 맞게 보이는지**([#47](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/47)). 결과는 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에 적습니다.
  - 낮·밤 테마에서 NX4 KOR 타일이 순정 타일 사이에 어울리는지(크기, 위치, 그라데이션).
    - 크기가 순정과 다르면 화면 밀도도 함께 적습니다. HMG-API(rc.4 `HmgApi.icon()`)는 모드 그림을 밀도 보정 없이 99 px 그대로 쓰고, 순정 `hom_*_66`은 `drawable-hdpi` 자원이라 화면 밀도에 맞춰 바뀝니다. 그래서 밀도가 240이 아니면 크기가 다를 수 있습니다(코드를 읽고 추론).
  - HMG-API 앱에서 NX4 KOR를 껐을 때 타일이 회색(꺼짐) 그림으로 바뀌는지, 낮·밤 모두.
  - 설정 앱의 앱 목록에 NX4 KOR 앱 아이콘이 새 그림으로 보이는지.

확인하다 설치가 막히거나 상태 화면이 빨강·노랑이면 [`troubleshooting.md`](troubleshooting.md)를 봅니다.

정하지 않은 것은 [GitHub 이슈](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues?q=is%3Aissue+label%3A%22%EA%B2%B0%EC%A0%95+%ED%95%84%EC%9A%94%22)(라벨 `결정 필요`)에서 관리합니다. 차에서 확인한 결과는 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에 적습니다.
