# NX4 KOR 설계

2.1.0의 처리 흐름(설치·업데이트, 재부팅 뒤 무선 연결, 관리 앱, 지우기)을 그림으로 줄인 것은 [`flow.md`](flow.md)에 있습니다. 이 문서의 흐름을 바꾸면 그 그림도 함께 고칩니다.

## 2.1.0 구조

2026-11-23에 방향을 다시 정하고([#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38), 할 일 [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45), 마일스톤 [2.1.0](https://github.com/jay-park-lab/hmgapi-nx4-kor/milestone/1)) 2026-11-25에 2.1.0 태그를 달았습니다. 2.1.0 릴리스 묶음은 HMG-API가 rc.8 릴리스를 지워 만들지 못했고, HMG-API 1.1.0-rc.10으로 고친 2.1.1을 2026-11-26에 정식으로 냈습니다(PR #70). 2.1.0은 다음 셋으로 됩니다.
- HMG-API(1.1.0-rc.10 이상. 2.1.0은 rc.8 이상, 2.1.1에서 올림. 아래 "2.1.0 모드 구성"의 `hmgapi`)
- 공식 무선 모드 `wireless-carplay-aa`(2.2.0-rc.9 이상, 고치지 않음, NX4에는 `--any-car`로 설치)
- 이 저장소의 NX4 추가분

| 일 | 맡는 곳 | 2.0.x에서 |
|---|---|---|
| 무선 카플레이·AA 훅, 계기판·HUD 길안내 | 공식 무선 모드. 카플레이 계기판·HUD 길안내는 이 저장소의 모드가 한국 차에 맞춰 덮어씁니다(아래 "[한국 카플레이 길안내](#한국-카플레이-길안내-hooks-67)", [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67)). 그 밖의 한국 맞춤(`aa_name_hold`, `star_popup_skip` 등)도 이 저장소의 모드에 넣습니다([#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64)). 다른 프로젝트에 기여하는 길은 쓰지 않습니다(2026-11-25 사용자 결정) | 한국 포크 2.4.5를 이 모드에 합쳐 씀(2.1.0에서 뺌, 아래 "2.1.0 모드 구성") |
| 프로젝션 AP, 순정 핫스팟 기능 | HMG-API(`"wifi": {"projection": true}`) | `svc/hotspot.sh`가 순정 `hostapd`·`dnsmasq`로 직접 띄움 |
| HMG-API 설치·업데이트, 공식 모드 설치, NX4 map, 진단, 되돌리기(옛 NX4 KOR 2.0.x 정리 포함, 2.0.x는 `conflicts: ["wireless-carplay-aa"]`라 공식 모드와 함께 설 수 없음) | 이 저장소의 USB 설치기 | 설치기와 `setup_hmgapi` |
| 설치 진행·판정 화면 | 이 저장소의 관리 앱(지금 UI 유지, 지우기 버튼은 두지 않음 [#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)). 판정은 새 구조에 맞춤 | 같은 앱 |
| USB Wi-Fi 동글 | 이 저장소(2.2.0, [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)) | 없음 |

- 공식 모드가 `replace`하는 훅 지점은 이 저장소의 모드가 `replace`로 다시 걸 수 없습니다. 같은 지점을 `replace`하는 모드 둘은 함께 켜지지 않습니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)). `change`·`observe`는 `replace`와 함께 걸립니다(HMG-API `HookPlan`). 그래서 이 저장소의 훅은 `change`·`observe`만 씁니다.
- HMG-API는 모드를 지울 때 선언한 것(`patches.json`, `apps`, `services` 등)만 되돌리고, 지울 때 부르는 콜백이 없습니다(rc.8). 그래서 새 구조에서는 바꾸는 것을 선언으로 둡니다. 그래야 HMG-API 앱에서 지워도 남는 것이 없습니다.
- 판: 베타도 판에 꼬리를 붙입니다(`2.0.4-beta.1`부터, `docs/git-flow.md` 규칙 4). 2.0.x의 마지막 `release/2.0.4`는 `main`에 합치지 않고 지웁니다(끝 커밋은 `v2.0.4-beta.1` 태그가 남김).
- 아래 절은 모두 2.1.0 코드입니다. USB 설치기(아래 "[설치·업데이트·지우기](#설치업데이트지우기-usbtroubleshooter)")가 HMG-API 쪽 일(옛 2.0.x 정리, 공식 무선 모드 설치, map 만들기·확인, 계획 확인 뒤 적용)을 모두 하고, nx4-kor 모드는 부팅 때 이 일을 하지 않습니다.

## 2.1.0 모드 구성 (`mod/`)

`nx4-kor`는 관리 앱과 그 앱이 부르는 서비스, 한국 카플레이 길안내 훅(아래 "[한국 카플레이 길안내](#한국-카플레이-길안내-hooks-67)", [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67))을 담은 HMG-API 모드입니다(2.1.0 할 일 #45 "지금 `nx4-kor` 모드에서 빼기"로 줄인 뒤 #67에서 길안내 훅을 더함). 무선 카플레이·안드로이드 오토는 HMG-API와 공식 무선 모드가 맡습니다. 이 모드의 훅은 DiPO(카플레이 앱) 안과, 곧 회전 게이지 막대 칸을 바꾸려고 순정 내비(`com.mnsoft.navi`) 안의 단속 정보 프레임 두 메서드에만 겁니다([#96](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/96), 아래 "곧 회전 게이지"). 시스템 파일·Wi-Fi 설정은 바꾸지 않습니다.

> 2.1.0 구성은 2026-11-25 차(NX4HEV 260902, 2.1.0-beta.3)에서 무선을 빼고 확인했습니다: USB 설치, map 확인, 적용, 관리 앱과 [지금 재부팅], 재부팅 뒤 훅 켜짐([#23 기록](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23#issuecomment-7157758896)). 이 차는 Wi-Fi 부품이 없어 무선은 동글로 확인합니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)). PC 테스트의 HMG-API 엔진은 2.1.1부터 1.1.0-rc.10입니다.

| `mod.json` 항목 | 하는 일 |
|---|---|
| `system` | `NX4`·`NX4HEV`, `KOR`, `260902`에만 설치됩니다 |
| `hmgapi` | `>=1.1.0-rc.10`(2.1.1부터, 2026-11-25·26 사용자 결정. 2.1.0은 공식 무선 모드 2.2.0-rc.9가 요구하는 rc.8이었음). rc.8 이하는 NEMESIS 1.17(LivePatch)을 몰라, 그 위에서 지우면 재부팅 한두 번 뒤 Android가 뜨지 않고, 업데이트도 zygote 래퍼를 실제로 바꾸지 못하며, NEMESIS 1.17이 먼저 깔린 차에는 설치를 거절합니다(rc.9 `install/common/lib.sh` `nemesis_livepatch`가 고침). rc.9는 그 거절을 `FORCE`로 넘겨 설치한 차를 올리면 마지막 순정 파일을 덮어써 Android가 뜨지 않습니다(rc.10이 고침, HMG-API 1.1.0-rc.10 릴리스 노트). 근거는 [Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397). 처음에 rc.9로 정했다가, 리뷰 중 rc.10이 나오며 rc.9 릴리스가 지워져 rc.10으로 올렸습니다(PR #70). 최소 판을 올려 두면 USB 설치기가 rc.8·rc.9 차의 HMG-API를 스틱의 rc.10으로 먼저 올립니다(업데이트는 안전). 2.1.2부터 NEMESIS가 깔린 차에서는 설치기가 HMG-API도 올리지 않고 멈추므로, 그런 차는 HMG-API 릴리스의 USB·update zip으로 올립니다([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)). `svc/lib.sh` `HMG_MIN`, 관리 앱 `Report.MIN_HMGAPI`, 설치기 `HMG_MIN`도 같은 판 |
| `services` | `launch`(`svc/launch.sh`, root, 앱이 부를 때만), `nochip`(`svc/nochip.sh`, root, 부팅 때 한 번, 2.1.2-beta.4부터. 아래 "[Wi-Fi 칩이 없는 차](#wi-fi-칩이-없는-차의-hmg-api-다시-시도-멈추기-svcnochipsh)"). `car_events`는 쓰지 않습니다(쓰면 HMG-API 차량 서비스가 새로 뜸) |
| `apps`, `provides.launcher` | 관리 앱(`app/NX4KOR.apk`)과 앱 메뉴 타일. 타일 그림은 `icons/`의 순정 꼴 넷(낮·밤, 모드를 껐을 때의 회색 낮·밤)이고, 저장소의 `art/tile.svg`를 HMG-API `tools/mkicon.sh`로 만든 것입니다([#47](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/47)) |
| `hooks` | 한국 카플레이 길안내(#67): `hooks.jar`(저장소의 `hooks/src`를 `scripts/build-hooks.sh`로 만듦), 진입 클래스 `io.github.jayparklab.nx4kor.hook.Nx4KorHooks`, 훅 지점 9곳. DiPO 안 계기판 호출 `framework.navigation_cluster.*` 8곳은 `change`, DiPO의 길안내 멈춤 `dipo.iap2_proxy.stop_route_guidance`는 `observe`. `replace`는 쓰지 않습니다. 이 밖에 순정 내비 안 `NavigationCluster.updateTBTTrapInfo`·`updateTBTTrapInfoNew`에 이름으로 훅을 겁니다(map에 없는 메서드라 `points`에 없음, 단속 정보 프레임의 막대 칸만 바꿈, #96) |
| `settings.json` | `kor_tbt`(한국 카플레이 길안내, 기본 켬), `kor_tbt_far_big`(먼 회전도 큰 그림, 기본 켬, [#89](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/89)), `kor_tbt_log`(그 진단 줄, 2.1.2-beta.2부터 기본 끔, [#77](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/77)). 모두 HMG-API 앱에서 바꾸고 다시 시작하면 적용됩니다 |

- **빠진 것:** 한국 포크 무선 모드 2.4.5(`parts`·`feature_flags`, 그 `hooks.jar`·`settings.json`, 레시피 5개, `files/libleafiaaac.so`, `patches.json`, 저장소의 `wireless/`), `"wifi": {"hotspot": true}`, `conflicts: ["wireless-carplay-aa"]`, 서비스 `ap`(`svc/ap.sh` → `svc/hotspot.sh`의 순정 `hostapd`·`dnsmasq` 핫스팟, Wi-Fi 설정 잠금, 칩 깨우기, 자동 설정 `setup_hmgapi`)와 `scripts/post.sh`. 공식 모드와 `replace`로 겹치는 훅이 없습니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)).
- **`requires`로 공식 모드를 걸지 않습니다.** HMG-API는 요구한 모드가 없거나 꺼지면 이 모드의 앱·서비스까지 멈춥니다(rc.8 `docs/mod-reference.md` "Other mods", `engine/Engine.java` `visit`). 그러면 관리 앱이 그 사실을 알릴 수 없습니다. 대신 관리 앱이 공식 모드가 있는지·켜졌는지·판을 봅니다(아래 "관리 앱").
- **map 만들기·확인과 적용은 USB 설치기가 합니다**(#45에서 정함, PR #52). 프로젝션 AP는 HMG-API가 공식 모드의 `"wifi": {"projection": true}` 요청으로 띄웁니다.
- 이 모드는 HMG-API에 선언한 것만 바꾸므로 HMG-API 앱에서 지워도 남는 것이 없습니다(관리 앱의 작업 파일 `/data/local/tmp/nx4-kor*`와 기록 `/data/nx4-kor`는 남음. USB `NX4/UNINSTALL`이 지움).

| 파일 | 하는 일 |
|---|---|
| `svc/env.sh` | 위치(`NX4_APP` 모드 폴더, `NX4_ROOT=/data/nx4-kor`, `APLOG`). `BK`는 2.0.x의 백업 폴더 이름(설치기가 옛 판을 알아보는 데 씀) |
| `svc/lib.sh` | 관리 앱·`nochip` 서비스·지우기가 함께 쓰는 함수(busybox 고르기, 판 비교, 프로젝션 AP·Wi-Fi 칩 상태 읽기, 이번 부팅에 칩이 없는지, 카플레이 연결 수, 재부팅 요청 받기). 2.0.x의 `svc/hotspot.sh`를 줄인 것입니다 |
| `svc/launch.sh` → `bin/status.sh` | 상태 파일(`/data/local/tmp/nx4-kor-status.txt`)과 재부팅 요청 감시자 |
| `svc/nochip.sh` | 칩이 없는 부팅이면 HMG-API Wi-Fi 지기의 다시 시도를 멈춤(칩 없음 기록 `/data/local/tmp/nx4-kor-nochip.txt`, HMG-API `wifi/ap.boot`) |
| `bin/uninstall.sh` → `scripts/preun.sh` | 지우기(`engine remove`)·업데이트 전 정리 |

- **지우기**(`bin/uninstall.sh`): 관리 앱의 감시자를 멈추고 작업 파일을 지운 뒤 `hmgapid engine remove nx4-kor`를 합니다. HMG-API는 그때 앱·서비스 목록(`state/apps.txt`·`services.txt`)을 다시 써서 관리 앱과 서비스를 내립니다(rc.8 `Packages.remove` → `LiveState.publish`). 이 모드는 적용할 것이 없으므로 계획을 보거나 적용하지 않습니다. 그다음 기록 폴더 `/data/nx4-kor`를 지웁니다.
  - 2.0.x의 백업 폴더(`$BK` = `/data/nx4-kor/backup`)가 있으면 그 폴더만 남깁니다. 2.1.0은 그 폴더를 만들지 않으므로, 있으면 2.0.x가 바꾼 것(Wi-Fi 설정 잠금, 치운 crc32 파일, 순정 AP 저장값)을 되돌릴 기록입니다. 출력에 "2.0.x USB(v2.0.4-beta.1) 또는 NX4 KOR 2.1.0 이후 USB의 UNINSTALL로 되돌려 주세요"를 남기고(설치기 `NX4/install.log`), 종료 코드는 0입니다(PR #50 리뷰 2·9).
  - `--update`(새 판으로 바꾸기 전)는 감시자와 작업 파일만 정리합니다. 설치 진행 기록은 USB 설치기가 쓰는 파일이라 두고, 지울 때만 지웁니다.
  - 2.0.x가 바꾼 것(Wi-Fi 설정 잠금, 무선 권한 파일, 순정 AP 저장값, 한국 포크 무선 기능)은 2.1.0의 지우기가 되돌리지 않습니다. USB 설치기가 2.1.0을 넣기 전에 옛 판 자신의 `bin/uninstall.sh`로 정리합니다.

### Wi-Fi 칩이 없는 차의 HMG-API 다시 시도 멈추기 (`svc/nochip.sh`)

2026-11-26 차(NX4HEV 260902, 2.1.2-beta.3)의 진단 기록과 HMG-API rc.10 소스로, 칩이 없는 차에서 HMG-API Wi-Fi 지기가 운전 내내 프로젝션 AP를 다시 띄우려 하는 것을 찾았습니다. 순정 시스템에 걸리는 부하라서 이 모드가 멈춥니다(2026-11-26 사용자 결정, 2.1.2-beta.4).

- **원인:** 지기(`engine/HomeWifi.java`, 서비스 `hmgapi wifi`)는 공식 모드의 `"wifi": {"projection": true}` 요청으로 부팅마다 AP를 띄웁니다.
  - 못 띄우면 약 2초마다 30번, 그 뒤로는 부팅이 끝날 때까지 30초마다 다시 시도합니다. 시도마다 `app_process`(Dalvik)를 하나 띄웁니다(`tool ensure-projection`).
  - QuickBoot에서 깨어나면(`woke`) 처음부터 다시 합니다.
  - 칩이 없는 차에서는 이 시도가 하나도 성공하지 못합니다.
- **멈추는 법:** 지기는 `wifi/ap.boot`에 이번 부팅 id가 있으면 시도하지 않습니다(`ap_keep`). `nochip` 서비스(start `boot`, `restart` false)가 칩이 없는 부팅이면 그 id를 씁니다.
  1. 순정 Wi-Fi 드라이버의 결과를 기다립니다(부팅 뒤 약 20초. 5초마다, 부팅 뒤 120초까지). 포기한 줄이 있어도 부팅 뒤 50초까지는 기다려 USB Wi-Fi 동글이 올라올 틈을 둡니다. 이 차는 부팅 약 40초에 앞쪽 USB 포트 전원을 껐다 켜서(`dwc_otg_vbus_set` OFF→ON), 꽂힌 장치가 43~44초에야 다시 보이기 때문입니다(11-26 진단 기록 4개, 동글 세션 지적). 정하기 전에 5초 뒤 한 번 더 보고, 그때 동글이 보이면 아무것도 쓰지 않습니다(포트 전원을 껐다 켜는 때가 늦은 부팅에 밀린 경우, PR #86 리뷰 7).
  2. 칩이 없는 부팅인지 봅니다(`lib.sh` `nochip_now`). 이 내비에서 칩을 본 적이 없고(HMG-API `public/wifi-chip`, SDIO 장치), `wlan0`이 없고, USB Wi-Fi 동글일 수 있는 장치(`lib.sh` `dongle_present`: Realtek `0bda`·TP-Link `2357`, 동글 드라이버가 받는 `0bda:b812`·`2357:012d`·`0bda:b831`·`0bda:b851`의 만든 곳)가 없고, 커널 기록에 `failed to power up DHD generic adapter, max retry reached`가 있어야 합니다. 그 부팅에는 드라이버를 다시 올리지 않아 칩이 올라오지 않습니다(11-26 진단: 부팅 뒤 19분 동안 그 줄은 부팅 때 한 번뿐).
  3. 순정 핫스팟 기능 권한 파일(`/system/etc/permissions/com.hkmc.software.wifihotspot.xml`)과 프로젝션 AP 요청이 있을 때만, 이번 부팅 id를 이 모드의 기록 `/data/local/tmp/nx4-kor-nochip.txt`(관리 앱 판정·진단용)와 HMG-API `wifi/ap.boot`에 씁니다.
  4. 그 뒤 `wifi` 폴더에서 파일이 지워질 때만 깨어나는 `inotifyd`(함께 넣은 busybox 1.36.1)를 띄워 둡니다. 지기가 깨어남에 `ap.boot`를 지우면 다시 씁니다. 주기적으로 깨지 않습니다. 그때 칩·`wlan0`·동글이 보이면(나중에 꽂은 동글을 켜려고 `ap.boot`를 지운 경우 등) 다시 쓰지 않고, 칩 없음 기록을 지운 뒤 `inotifyd`를 멈추고 끝냅니다. 안 보여도 5초 뒤 한 번 더 보고 씁니다(포트 전원을 껐다 켜는 4초쯤에는 꽂힌 동글이 안 보임). 그래서 깨어날 때마다 지기의 시도는 두어 번 남습니다. `inotifyd`가 없는 busybox면 3까지만 합니다.
- **차 이벤트를 쓰지 않는 까닭:** HMG-API `car_events`의 `wake`로도 깨어남을 받을 수 있습니다. 하지만 하나라도 쓰면 hmgapid가 HMG-API 차량 서비스(`hmgapi.vehicle.Hub`, 상주 Dalvik)를 띄웁니다(rc.10 `ModRuntime`). 이 차에서는 지금 그것을 쓰는 모드가 없어 돌지 않습니다.
- **하지 않는 차:** 칩이 있는 차, 순정 핫스팟 기능이 없는 차, USB Wi-Fi 동글을 꽂은 차([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)·[#80](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/80)). 그때는 아무것도 쓰지 않고 끝납니다(상주 없음).
  - 동글을 꽂은 부팅에도 순정 드라이버가 먼저 올라 포기한 줄과 "`wlan0` 없음"이 생기고, 그 뒤에 동글 드라이버가 순정 자리에 올라 `wlan0`이 생깁니다(2.2.0 계획, #80 동글 세션 지적). 그래서 커널 줄과 `wlan0`만으로는 동글 차를 가르지 못해 USB 장치를 봅니다.
  - Realtek·TP-Link의 다른 USB 장치(카드 읽개 등)가 꽂혀 있어도 물러납니다. 잘못 동글로 보면 예전처럼 다시 시도할 뿐이고, 잘못 칩 없음으로 보면 동글 AP를 막으므로 넓게 잡습니다.
- **위험:** HMG-API rc.10의 내부 파일(`wifi/ap.boot`)에 기댑니다. HMG-API가 이 파일을 바꾸면 효과만 없어지고 예전처럼 다시 시도합니다. rc.10에서 이 파일을 읽는 곳은 지기 자신과 이 모드의 관리 앱뿐입니다. 관리 앱은 이 모드가 쓴 `ap.boot`를 "떴다가 꺼짐"(`apoff`)으로 보지 않습니다.
- **끄기·지우기:** 이 모드를 끄거나 지우면 hmgapid가 서비스의 프로세스 묶음(setsid)을 함께 내립니다. 칩 없음 기록은 지울 때 지우고 업데이트 때는 둡니다. `ap.boot`는 부팅마다 바뀌는 HMG-API 파일이라 둡니다.
- **기록:** 줄은 hmgapid 서비스 기록 `logs/nx4-kor/nochip.log`(USB 진단 기록 `logs/service/`)에 남습니다. 지기의 기록 `wifi.log`도 2.1.2-beta.4부터 진단 기록 `logs/hmgapi-wifi.log`로 모읍니다.

### 한국 카플레이 길안내 (`hooks/`, #67)

공식 무선 모드 2.2.0-rc.9는 카플레이가 보낸 안내 중 자기 아이콘 표에 없는 것(차선 유지, 각도 없는 "약간 좌·우회전", 각도가 딱 맞지 않는 회전 등)이나 내용(iAP2 121)을 받지 못한 안내를 계기판에 보내지 않습니다. 그러면 계기판에는 앞 안내(예: 좌회전 0 m)가 남습니다(2026-11-25 차, [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67)). Korea Projection(KP)과 HMG-Seogaemo가 같은 문제를 이미 고쳤으므로, 그 코드를 이 모드로 가져와 공식 모드 옆에서 돌립니다(2026-11-25 사용자 결정 A2).

- **공식 모드의 `tbt`는 켠 채로 둡니다.** 공식 모드가 계속 하는 일: 아이폰에 "이 차는 길안내를 받는다"고 알리기(`iap2.init_info`), 순정 내비가 계기판에 끼어드는 것 막기(순정 내비 프로세스의 `framework.navigation_cluster.*` `replace`), 안드로이드 오토 계기판 길안내, 무선 전환 뒤 길안내 다시 요청. 그래서 `tbt`를 끄면 아이폰이 길안내를 보내지 않아 이 모드의 길안내도 멈출 것으로 봅니다(공식 코드 근거, 차에서 확인하지 않음).
  - 공식 모드의 `tbt_standard`("Turns in the car's own format", 기본 끔, 재시작해야 적용)는 회전까지 약 457 m(1,500 ft, `CpTurns.GUIDE_WINDOW`) 안에서 공식 모드도 순정 내비 형식(회전 종류·각도·거리 막대, AR HUD 애니메이션)으로 보내게 합니다. 그보다 멀면 공식 모드도 프로젝션 아이콘입니다. 카플레이는 이 모드가 길안내 중 공식 모드의 계기판 값을 바꾸므로 그 설정과 상관없이 이 모드의 기준(일반 350 m, 고속도로 출구 1,050 m)으로 그려집니다. 그 설정이 보이는 것은 공식 값이 그대로 나가는 때뿐입니다. 안내 시작·재개 순간(아래 "공식 호출 잠깐 붙잡기"), 이 모드가 그리지 못한 안내(이 모드의 리스너만 내용 121을 놓쳐 붙잡아도 이 모드의 값이 생기지 않음, 다시 요청해 받을 때까지 3~5초), 이 모드가 비켜 주는 동안(이 모드의 리스너가 3초 넘게 못 들음, `giving way`), 그리고 안드로이드 오토(이 모드가 손대지 않음)입니다. 켜 두어도 이 모드와 겹치는 곳은 없습니다(2026-11-26, 공식 모드 2.2.0-rc.9 소스로 확인).
- **이 모드가 하는 일**(DiPO 프로세스 안, `hooks/src/.../hook/dipo/KorTbt.java`):
  1. iAP2 서버에 자기 길안내 리스너(`NX4KOR_RG`, 종류 4096, 공식 모드의 `HMGAPI_RG`와 같은 종류)를 등록해 120·121·122를 받습니다.
  2. KP의 `CpTurnsFit`(seogaemo 차선 그림 포함)으로 계기판·HUD에 보낼 값을 정해 HMG-API `Cluster` API로 보냅니다. 표에 없는 안내도 가까운 화살표로 보내고, 길안내 중에는 1초마다 다시 보냅니다(KP `refresh`). 내용(121)을 3초 넘게 못 받으면 길안내를 다시 요청합니다(KP 2.4.7).
  3. DiPO 안 계기판 호출 8곳을 `change`로 겁니다. 이 모드의 스레드가 보낸 값을 기억하고, 길안내가 켜진 동안 다른 스레드(공식 모드)가 부르면 인자를 이 모드의 마지막 값으로 바꿉니다. 그래서 두 엔진이 계기판에서 다투지 않습니다. 이 모드의 길안내가 꺼져 있으면(리스너가 받은 것이 없거나 안내가 끝남) 공식 모드의 호출은 그대로 갑니다. 다만 이 모드의 리스너가 같은 갱신을 막 받았거나 곧 받을 때는 아래 "공식 호출 잠깐 붙잡기"처럼 이 모드의 값을 잠깐 기다립니다.
     - **중복 호출 줄이기**([#77](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/77), 2026-11-26): 공식 모드의 호출이 이 모드의 값을 실어 가므로, 계기판은 같은 지점을 두 번 받습니다(폰 갱신 하나에 공식 5회와 이 모드 4회, KP는 4회). `change` 훅은 공식 모드의 호출을 건너뛸 수 없어(HMG-API가 되돌림), 이 모드 쪽을 줄입니다. 보낼 값이 이 모드가 마지막에 보낸 것과 같고, 공식 모드의 호출이 900ms 안에 그 최신 값을 실어 갔으면 이 모드의 호출을 건너뜁니다(`ClusterOut`, `TbtGate.skipOurs`). 공식 모드가 보내지 않는 안내(위 #67의 0 m 멈춤)와 폰이 조용할 때의 1초 다시 보내기(공식 모드는 다시 보내지 않음)는 그대로 나갑니다. 이름·회전 목록은 이 모드의 입력 값으로 견줍니다(공식 모드 호출의 인자는 견줄 수 없는 프레임워크 객체).
     - **비켜 주기:** 공식 모드는 3초 넘게 계속 부르는데(마지막 호출도 3초 안) 이 모드의 리스너는 3초 넘게 아무것도 받지 못하면(폰은 보내는데 이 모드만 못 받음), 공식 모드의 호출을 그대로 보내고 이 모드의 1초 다시 보내기도 멈춥니다. 이 모드가 다시 받거나 공식 모드도 3초 조용하면 돌아옵니다(로그 `giving way until it hears again`). 신호 대기처럼 폰이 아무에게도 보내지 않는 동안이나, 공식 모드가 한 번 부르고 모두 조용해진 때는 비켜 주지 않습니다(PR #68 리뷰 3·13). 비켜 주는 동안은 1초마다 깨지 않고 비키기가 끝날 시각(공식 모드의 마지막 호출 3초 뒤)에 다시 봅니다(#77).
     - **공식 호출 잠깐 붙잡기**(2.1.2-beta.4, [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67)): 두 리스너는 같은 갱신을 따로 받습니다. 이 모드가 아직 그린 것이 없을 때(길안내 시작, 멈춤·앱 바뀜·안내 끝 뒤 다시 시작) 공식 모드의 스레드가 먼저 그리면, 그 한 묶음(화살표·길 이름·HUD 목록·2C·남은 거리·다음 회전)이 공식 모드 값 그대로 계기판에 갔습니다. 공식 모드에는 다시 보내기 타이머가 없어, 그 그림은 이 모드의 스레드가 보낼 때까지 남았습니다(2026-11-26 차 기록: 공식 모드의 `CarPlay: hud list type 70 next 0`이 이 모드의 `guidance on`보다 먼저 나옴). 이제 이 모드가 줄 값이 없는 공식 호출(길안내 꺼짐, 또는 그 지점을 이 모드가 아직 부르지 않음)은 이 모드의 리스너가 받은 것을 이 모드의 스레드가 모두 끝낼 때까지 최대 250ms(`TbtGate.HOLD_MS`) 기다렸다가, 그사이 이 모드의 값이 생기면 그 값을 싣습니다. 기다리는 사이 리스너가 더 받은 것도 끝날 때까지 기다립니다(앞의 121만 끝나고 길안내를 켤 120이 아직이면 끝난 것이 아님, PR #85 리뷰 1).
       - 이 모드의 길안내가 꺼져 있고 리스너가 그 갱신을 아직 받지 않았으면(공식 모드 쪽이 먼저 받음) 받기까지 50ms(`TbtGate.HEAR_MS`)만 기다립니다.
       - 길안내가 켜져 있는데 이 모드가 부르지 않는 지점(차로를 보내지 않는 앱의 차로, 공식 모드의 HUD 지우기 등)은 이미 받은 것만 끝나길 기다리고, 오지 않을 수도 있는 갱신을 50ms씩 기다리지는 않습니다. 켜져 있으면 화살표·이름·HUD 같은 주된 값은 이미 이 모드 것이라, 이 모드가 부르지 않는 지점은 곧 부를 지점이 아닐 때가 많기 때문입니다(PR #85 리뷰 3).
       - 그래도 값이 없으면 지금처럼 그대로 보내고, 리스너가 새 갱신을 받기 전에는 다시 기다리지 않습니다. 그래서 갱신 하나에 많아야 한 번 기다리고, 아무것도 받지 못하는 리스너면 처음 한 번 50ms 뒤로는 기다리지 않습니다(공식 모드 혼자).
       - 앱에서 이 모드를 껐을 때, 비켜 주는 동안, 메인 스레드의 호출, 이 모드의 값이 있는데 인자 개수만 다른 호출은 기다리지 않습니다. 이 모드의 값이 아직 없을 때는 인자 개수를 알 수 없어 기다린 뒤, 개수가 다르면 그대로 보냅니다(PR #85 리뷰 4).
       - 공식 모드의 스레드만 `Object.wait`로 기다리고(바쁜 반복 없음), 이 모드의 스레드가 갱신을 끝내면 깨웁니다(`TbtGate.done`, `noteActive` 다음). 이 모드의 스레드는 공식 모드를 기다리지 않습니다.
       - 이 모드가 그 갱신으로도 그리지 못하면(내용 121을 못 받은 회전 등) 공식 모드의 값이 그대로 가는 것은 전과 같습니다.
       - 기록 줄은 기본으로 늘지 않습니다. `kor_tbt_log`를 켜면 붙잡은 호출마다 `<지점> from the official mod held N ms, carries ours`(우리 값을 실음) 또는 `…, passed as it was`(기다렸지만 공식 값 그대로)가 남습니다(PR #85 리뷰 2). 줄 수는 모두 100줄(`TbtGate.HELD_LOGS_MAX`), 한 지점 20줄(`HELD_LOGS_PER_POINT`)까지이고, 이 모드의 길안내가 꺼질 때(`guidance off`)와 연결이 끝날 때 다시 셉니다. 그래서 다음 길안내 시작의 붙잡기는 늘 남고, 길안내 중 이 모드가 부르지 않는 지점(출발 화면에서 공식 모드의 HUD 지우기가 보내는 차로 등)이 줄을 다 쓰지 못합니다(PR #85 리뷰 6. 다른 기록 한도는 프로세스마다 한 번이지만, 이 줄은 시작 때 보려는 것이라 길안내마다 셈).
  4. 이 모드 것이 아닌 길안내 멈춤(`dipo.iap2_proxy.stop_route_guidance`, `observe`)을 보면 2초 뒤에 이 모드의 안내를 지웁니다. 그 사이 폰이 다시 보내면 지우지 않습니다. 멈춤 뒤 150ms 안에 온 것은 멈춤 전에 폰이 보낸 것이므로 세지 않습니다(다시 요청은 멈춤, 200ms, 시작이라 그보다 늦게 옴, 리뷰 12). 공식 모드도 같은 길로 다시 요청(멈춤 뒤 시작: 길안내 앱 이름이 바뀔 때, 무선에서 감시가 다시 요청할 때)을 하므로, 바로 지우면 계기판이 깜빡이기 때문입니다. DiPO가 정말로 멈추면(카플레이 끝남) 폰이 더 보내지 않아 2초 뒤 지워집니다. 이 모드 자신의 다시 요청은 처음부터 뺍니다(PR #68 리뷰 1).
  5. HMG-API 앱에서 NX4 KOR를 재시작 없이 끄면 HMG-API가 이 모드의 훅을 통과시키고, 이 모드도 받기·다시 보내기를 멈추고 상태와 "그렸다" 표시를 비웁니다(지우지는 않음: 공식 모드가 이어 그림). 다시 켜면 처음 받을 때 폰에 길안내 전체를 다시 요청합니다(폰은 갱신을 항목마다 보내, 상태 항목이 없는 갱신만으로는 "안내 끝"으로 읽히기 때문, PR #68 리뷰 2·11). 그 다시 요청의 멈춤에 공식 모드가 HUD(거리·차선·목록)를 비우므로, 다시 켠 직후 HUD가 1초 안팎 빌 수 있습니다. 계기판 화살표는 그대로입니다(리뷰 14, 재시작 없이 다시 켤 때만).
  - 3·4·5의 판단, 중복 호출 줄이기, 공식 호출 잠깐 붙잡기는 `TbtGate.java`에 따로 두고 `tests/mod-test.sh`가 PC에서 돌립니다(`tests/tools/TbtGateTest.java`. 붙잡기는 가짜 시계·대기로, 깨우기는 실제 스레드 둘로 테스트).
  - KP 2.4.10에서 더해진 곧 회전 그림 판단(아래 "가져온 것과 바꾼 것"), `CpIcons`, 곧 회전 거리(`near()`를 직접 불러 일반 600 m·나갈 때 650 m·고속도로 출구 1,050 m, `dynamicD`·`bar`)는 `tests/tools/NearFitTest.java`로 돌립니다. `hooks/src` 전체를 `scripts/build-hooks.sh`와 같은 클래스 경로로 컴파일해야 해서, `HMGAPI_SRC`와 `ANDROID_HOME`이 있을 때만 돕니다(없으면 skip 줄에 나옴).
- **설정:** `kor_tbt`를 끄면 위 일을 하나도 하지 않아 공식 모드 그대로입니다. `kor_tbt_far_big`(기본 켬)을 끄면 먼 회전을 KP처럼 네모 칸 아이콘으로 보냅니다(아래 "먼 회전도 큰 그림"). `kor_tbt_log`는 KP의 진단 줄(곧 회전 판단의 차로 수·거리·D, 계기판에 보낸 값, 차선, 처음 본 길안내 앱 이름)과 보낸 HUD 목록 줄(`CarPlay: hud list …`, 시작마다 300줄까지, #77. 공식 모드도 자기 것을 남김), 붙잡은 공식 호출 줄(`… from the official mod held N ms, …`, 길안내·연결마다 100줄, 한 지점 20줄까지, 위 "공식 호출 잠깐 붙잡기")을 HMG-API 기록에 더 남깁니다. 2.1.2-beta.2부터 기본으로 끕니다(2026-11-26 사용자 결정, #77: 켜고 끄는 설정으로 두고 기본은 끔). 기록이 필요하면 HMG-API 앱의 NX4 KOR 설정에서 켜고 다시 시작합니다. HMG-API 앱은 설정 하나를 바꿀 때 그 모드의 모든 값을 함께 저장하므로, 2.1.2-beta.1까지 설정을 바꾼 적이 있는 차는 켜진 채 남습니다(그때의 기본이 켬). 꺼도 받은 안내의 숫자 줄(`CarPlay: maneuver type … side … junction … exit …`, 시작마다 300줄까지), 길안내 앱이 바뀐 줄(`route guidance source changed from <앱> to <앱>`), 지운 줄(`turn-by-turn cleared`)은 남습니다. 길 이름·장소 이름은 어느 쪽이든 남기지 않습니다. 줄 머리는 공식 모드처럼 `CarPlay:`이고, HMG-API 앱 기록에서 출처가 `nx4-kor`로 나옵니다.
- **가져온 것과 바꾼 것**(`NOTICE.md`):
  - KP `StopDragon/HMG-API` `korea-build` `ebca56f`(무선 모드 2.4.10, Korea Projection 1.8.1): `CpTurnsFit.java`·`CpTbt.java`(그대로, 패키지·로그만 바꿈), `CpTurns.java`의 `exactIcon`·`distStrState`(`CpIcons.java`). `CpTurnsFit`의 seogaemo 출처 줄은 그대로 둡니다. 처음(2026-11-25)에는 `6258357`(2.4.9)에서 가져왔고, 2026-11-26에 2.4.10에서 다시 가져왔습니다.
  - 2.4.10에서 더해진 카플레이 곧 회전 그림(KP도 차에서 아직 확인하지 않음):
    - 회전교차로 32: 오른쪽 통행이고 폰이 출구 각도를 줄 때. 들어가기(종류 6)는 출구를 몰라 그대로 출구 아이콘입니다.
    - 지하차도 46(왼쪽·오른쪽 모두)·고가 44(왼쪽만. 오른쪽 고가 번호는 KP가 순정에서 보지 못해 넣지 않음): 왼쪽·오른쪽이 갈리는 회전(좌·우회전, 약간 좌·우, 갈림, 길 끝 좌·우: 종류 1·2·13·14·20·21·49·50)에서, 폰 안내 문구나 길 이름에 "지하차도·지하도로·고가차도·고가도로"가 있고 두 글 어디에도 "방면·옆길·측도·사거리·교차로·입구·앞" 등 18 낱말이 없을 때. 지하차도와 고가 낱말이 함께 있으면 바꾸지 않습니다.
    - 각도를 주지 않는 진입 램프(종류 9)는 직진 대신 순정 오른쪽 진입 모양(13, 22.5도). iAP2가 램프가 어느 쪽인지 주지 않아 왼쪽 램프도 이 모양입니다.
    - 기록 줄에 표시 거리 문자열의 유무·단위(`dist str N units U`, 문자열 자체는 남기지 않음).
  - **곧 회전 거리(2026-11-26 사용자 결정, 2.1.2-beta.4):** 일반 도로에서 큰 도로 그림·거리 막대("곧 회전" 화면)를 여는 거리 `D_GENERAL`을 KP의 350 m에서 600 m로 늘렸습니다. 그 밖에서는 계기판에 네모 칸 아이콘(먼 회전, 프로젝션 아이콘 번호)이 나와 투박하다는 사용자 의견 때문입니다. 고속도로 출구 1,050 m와, 처음 받은 거리가 더 짧으면 D를 그만큼 줄이는 규칙(`dynamicD`)은 그대로입니다. 근거는 다른 프로젝트의 값입니다: 서개모가 기아 NEEV KOR에서 본 순정 창 150~600 m(시내 150~375 m, 고속도로 580~600 m, 서개모 `.agents/cluster-ar-view.md`), 공식 모드 457 m(`GUIDE_WINDOW`), `HMG_Phone_Projection_TBT` 기본 400 m. 일반 회전에서 본 순정 최대 375 m보다는 깁니다. 막대(10~90)는 600 m에 걸쳐 더 천천히 줄어듭니다. KP·서개모·JMK 모두 먼 회전은 아이콘이고, 먼 회전까지 큰 그림으로 보낸 프로젝트는 없습니다.
  - **먼 회전도 큰 그림(2026-11-27 사용자 결정, [#89](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/89), 설정 `kor_tbt_far_big` 기본 켬):** 2.1.2-beta.5 주행 뒤 사용자 의견은 두 가지였습니다. 먼 회전 칸(네모 아이콘)은 큰 의미가 없고, 회전이 바뀔 때 그 칸이 잠깐 끼는 깜빡임이 보인다는 것입니다. 그래서 KP와 다르게 바꿨습니다.
    - **D 밖의 회전:** 곧 회전과 같은 큰 그림에 막대를 가득 찬 채(90, `BAR_FULL`)로 보냅니다. D(일반 600 m, 고속도로 출구 1,050 m)부터 막대가 지금처럼 줄어듭니다. 진단 줄은 `-> near (far-big)`입니다. 들어가고 나가는 히스테리시스(`nearOn`)는 그대로입니다. 그림이 같고 막대만 90이라 경계에서 모양이 바뀌지 않습니다.
      - 큰 그림이 있는 모든 종류가 같습니다. 그래서 먼 직진·길 따라가기(종류 3·5, 예: 고속도로의 "30 km 직진")도 큰 직진 그림(막대 90)이 됩니다(PR #94 리뷰 1). 회전교차로(32)·지하차도(46)·고가(44) 그림도 먼 거리부터 나옵니다.
      - 도로 이름: `turn()`은 큰 그림일 때 회전 뒤 도로 이름(`crossroadName`)을 보냅니다(순정은 멀 때 빈 이름). 그래서 몇 km 앞 회전에서도 도로 이름이 계기판에 나옵니다.
    - **회전이 바뀌는 순간(네이버 지도 꼴):** 새 회전의 첫 거리가 앞 회전 값과 같아 미루는 그 한 번(`put-off`)은 먼 회전 칸 대신 계기판·HUD를 그대로 둡니다(PR #94 리뷰 3: `turn()`이 HUD 목록·거리도 보내지 않음, 그 한 번은 HUD 화살표도 앞 회전 그대로). 이미 그린 것이 있을 때만이고(`shown`, 없으면 KP처럼 아이콘), 뛴 거리 붙잡기(`jump-hold`)와 같은 길(`nearHeld`)입니다. 진단 줄은 `-> held (put-off)`입니다. 그 뒤 폰의 다음 갱신 전에 1초 다시 보내기가 묵은 거리로 다시 물으면(`stale-dist`), 새 회전의 큰 그림을 막대 90으로 보냅니다(거리 숫자는 다음 갱신까지 앞 회전 값).
      - `stale-dist`는 #89 선택지 1에서 "아이콘 그대로"로 적었던 것과 다르게 큰 그림으로 했습니다(PR #94 리뷰 2). 미루기를 붙잡은 뒤 0.9~1.9초에 오는 다시 보내기가 네이버 지도의 진짜 거리(약 0.93~0.98초 뒤)보다 먼저 오면 `stale-dist`가 되는데, 거기서 아이콘이면 없애려던 깜빡임이 남기 때문입니다.
    - **같은 회전에서 거리가 뛸 때(카카오내비 꼴):** 뛴 값이 D 밖이어도 한 번 붙잡습니다(`staysNear`). 앞 회전 그림을 새 거리로 다시 그리지 않으려는 것입니다.
    - **아이콘 그대로:** 큰 그림이 없는 종류(목적지·경유지·출발·페리, `type`)와 폰이 거리를 한 번도 주지 않은 때(`no-dist`)입니다.
    - **남는 것:** 묵은 짧은 거리를 받아들인 큰 그림(`d 30`, 막대 20~40)이 한 번 나갔다가 진짜 거리로 다시 그려지는 일은 그대로입니다(같은 큰 그림 안에서 막대가 뜀).
    - **끄면:** KP 그대로(D 밖은 먼 회전 칸, 미루기·묵은 거리도 먼 회전 칸)입니다. 클래스의 기본값은 KP 쪽(`farBig` false)이고, `KorTbt`가 설정에서 켭니다.
    - **근거·테스트:** 2.1.2-beta.5 로그(#64). `NearFitTest`의 farBig 경우를 봅니다(2,400 m·5,000 m의 막대 90, 600 m부터 그대로, 목적지·거리 없음은 아이콘, 미루기 붙잡기와 그린 것이 없을 때의 아이콘, 묵은 거리의 그림, 뛴 거리 붙잡기, 끄면 KP).
  - KP 2.4.10은 진단 줄 한도를 300에서 1200으로 올렸지만 이 모드는 300으로 둡니다(PR #74). `kor_tbt_log`를 켜면 그 줄이 쌓이고, HMG-API 앱 Logs 탭은 공식 모드와 함께 쓰는 `log.log`의 마지막 64KB만 보여 주기 때문입니다.
  - **곧 회전 게이지(단속 정보 프레임 막대, 2026-11-27, [#96](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/96)):** 계기판은 곧 회전 큰 그림 옆의 거리 게이지를 `updateTBTInfo`의 막대 인자가 아니라, 순정 내비(`com.mnsoft.navi`)가 보내는 **단속 정보 프레임**(`NavigationCluster.updateTBTTrapInfo`·`updateTBTTrapInfoNew`)의 막대 칸(`barGraphLevel`)으로 그립니다. KP가 2026-11-09 차 로그로 찾았고, 회전 프레임 막대만 보낸 시험판에서는 게이지가 늘 비어 있었습니다.
    - 이 모드도 2.1.2까지는 KP의 `TrapBar`를 가져오지 않아 같았습니다(`PhoneBarOut`은 아무것도 보내지 않음). 그래서 2.1.2-beta.5 주행에서 게이지가 비어 있었고, 로그의 막대 값(90→10)은 보낸 값일 뿐이었습니다.
    - 지금은 KP와 같게 합니다.
      - DiPO의 `CpTurnsFit`이 막대(곧 회전이면 10~90, 먼 회전 칸이면 0, 안내가 끝나면 `NONE`)를 `PhoneBarOut`으로 방송합니다(`io.github.jayparklab.nx4kor.PHONE_BAR`, 값이 바뀔 때와 10초마다).
      - 진입 클래스가 순정 내비 프로세스에서 `TrapBar`를 겁니다(`kor_tbt` 켬). `TrapBar`는 단속 정보 프레임의 **막대 칸만** 폰 막대로 바꿉니다. 단속 카메라·제한속도 같은 다른 칸은 순정 값 그대로입니다.
      - 방송이 오면 순정이 마지막으로 보낸 단속 정보에 막대만 바꿔 다시 보냅니다(200 ms 간격 이상, 순정 호출을 한 번도 못 봤으면 보내지 않음). 다시 보내는 사이 순정 호출이 끼어들면 최신 순정 값으로 한 번 더 보냅니다.
      - 순정 막대로 되돌리는 때: 안내가 끝난 `NONE` 방송, 폰 안내가 끝난 뒤의 다음 순정 단속 정보 호출, 방송이 3분 끊긴 때(시계). 그리고 이 모드에만 있는 두 경우(PR #98 리뷰 2·3, KP에는 없음):
        - DiPO가 공식 모드에 비켜 줄 때(`TbtGate.yielding`). 그동안은 `turn()`이 돌지 않아 막대도 보내지 않으므로, 비켜 주기에 들어갈 때 `NONE`을 보냅니다. 다시 들으면 바뀐 막대를 바로 보냅니다.
        - HMG-API 앱에서 모드를 끌 때. DiPO가 `NONE`을 보냅니다. 이름 훅은 HMG-API의 모드 끔 감싸기(`mod.hook` 지점만)가 없어 `TrapBar`가 직접 `mod.enabled()`를 봅니다. 꺼져 있으면 순정 호출을 폰 안내가 아닌 것처럼 그대로 보내고(최신 순정 값은 기억), 방송은 `NONE`으로 봅니다.
      - 폰 안내 여부는 카플레이만 봅니다(`Car.carPlayGuiding`, PR #98 리뷰 5). 막대를 보내는 쪽이 DiPO뿐이기 때문입니다. KP는 안드로이드 오토도 보내 `Car.phoneGuiding`을 썼습니다.
    - 두 메서드는 HMG-API map에 없어 그 프로세스에서 이름으로 겁니다(`Hooks.findAndHookMethod`, KP와 같음). 그래서 `mod.json` `hooks.points`에는 없습니다. 이 차에 그 메서드가 없으면 한 줄 남기고 아무것도 하지 않습니다(객체 판은 칸이 모두 `public int`일 때만).
    - KP는 순정 내비의 다른 계기판 호출에도 훅을 걸어 거기서도 되돌릴지 봤지만(`Wireless.navigation`), 이 모드는 그 호출에 훅을 걸지 않습니다(순정 내비가 폰 안내 중 계기판에 끼어드는 것은 공식 모드가 막음). 위 세 가지로 되돌립니다.
    - 공식 무선 모드는 단속 정보 프레임을 건드리지 않습니다(2.2.0-rc.9 `hooks.jar`에 그 이름이 없음).
    - 기록(모두 숫자만)
      - 설치: `navigation (NX4 KOR): phone turn bar goes into the stock trap frame (N hooks)`
      - 처음 받은 방송: `… first phone turn bar heard (B), stock trap frame seen: yes|no`. 처음 본 순정 호출: `… first stock trap frame (17 ints|object, bar B)`. 둘 다 한 번씩입니다(PR #98 리뷰 4). 차에서 게이지가 비어 있을 때 "방송이 오지 않음"과 "순정 단속 정보 프레임을 아직 못 봄"을 가르려는 것입니다.
      - 막대를 바꾸거나 다시 보낸 줄은 프로세스마다 30줄까지입니다.
    - 테스트: `tests/tools/trapbar/`(KP의 PC 테스트 틀, 가짜 시계·대기열·계기판)로 `TrapBarTest`를 돌립니다. `PhoneBarOut`이 `PhoneBar`와 이름·값·간격이 같은지, DiPO 방송이 `TrapBar`까지 닿는지도 봅니다.
  - KP의 순정 층 `CpTurns`(설정 `tbt_fit` 끔)와 무선 전환 뒤 다시 요청 `RgAsk`는 가져오지 않았습니다(무선 전환 뒤 다시 요청은 공식 모드가 함).
  - 공식 모드의 iAP2 스텁 4개(`hooks/stubs/com/tcc/iap2`, 컴파일할 때만 쓰고 `hooks.jar`에는 넣지 않음).
- **빌드:** `scripts/build-hooks.sh`가 `hooks/src`를 HMG-API 런타임 소스(`HMGAPI_SRC`의 `core/runtime`)에 대고 컴파일해 d8로 `hooks.jar`를 만듭니다(Android SDK, `ANDROID_HOME`). `scripts/build.sh`가 그것을 모드에 넣어 서명합니다.
- **테스트**(`tests/mod-test.sh`): HMG-API 엔진의 `HookPlan`에 이 모드와 공식 모드 rc.9의 훅 선언(`tests/fixtures/wireless-carplay-aa-2.2.0-rc.9-hooks.json`)을 NX4 map 지점(`tests/fixtures/nx4-map-points.txt`, 2026-11-25 Car Report의 393점)으로 함께 올려 둘 다 올라오는지, `replace`를 하나라도 섞으면 공식 모드가 꺼지는지를 봅니다. `hooks.jar` 덱스에 이 모드의 클래스만 들었는지도 봅니다.
- **한계(차에서 확인):**
  - 리스너 둘이 같은 종류(4096)로 함께 받는지는 iAP2 서버 소스가 없어 차에서만 확인됩니다. 이 모드의 리스너가 아무것도 받지 못하면 공식 모드가 그대로 보내고, 공식 모드가 받지 못하면 이 모드가 혼자 보냅니다. 받다가 이 모드만 끊기면 3초 뒤 비켜 줍니다(위 3). HMG-API 기록의 `CarPlay (NX4 KOR): route guidance reaches this listener`가 받은 표시입니다.
  - 남의 멈춤을 2초 미루므로, 카플레이가 끝난 뒤 계기판의 화살표가 지워지기까지 2초쯤 걸립니다.
  - 무선(동글, #48)에서는 공식 모드가 자기 블루투스 브리지 세션의 끝(`disconnected`)을 거르지만, 이 모드는 그 세션을 알 수 없어 거르지 못합니다. 무선 카플레이에서 길안내가 잠깐 지워졌다 다시 나오는지 봅니다.

## 관리 앱

- 앱이 열릴 때 `hmgapid service-start launch`를 부르고(hmgapid는 이 모드의 앱일 때만 받음), 상태 파일이 새로 쓰이면 다시 그립니다.
- 판정(`verdict`·`verdict_lv`·`verdict_msg`)은 `bin/status.sh`의 `st_verdict` 한 곳에서 정하고 앱은 그대로 보입니다. 앱은 오른쪽 칸의 판정·요약 3줄과 왼쪽 칸의 "자세히" 표를 상태 파일에서 그립니다. 화면 배치·디자인은 2.0.x와 같습니다(사용자 결정).
- 설치 진행(막대·단계·경과)은 USB 설치기가 쓰는 진행 기록 `/data/local/tmp/nx4-kor-progress.txt`(`pct state stage start t boot step ust ut`)를 2.0.x와 같은 방식으로 읽습니다.
- **판정**은 "HMG-API + 공식 무선 모드 + 이 모드" 구조를 봅니다. 읽기만 하고 아무것도 바꾸지 않습니다. 앞에서부터 처음 맞는 것이 판정입니다.

  | 차례 | 판정(`verdict`) | 보는 것 |
  |---|---|---|
  | 1 | `bootguard` | HMG-API 부팅 보호(rc.6 이후 규칙). 이번 부팅 커널 로그의 zygote 줄을 따르고, 그 줄이 없으면 `hook/starts`·`hook/boot`로 봄. 다음 재부팅에 훅이 다시 켜지면(`starts` 6 미만) 재부팅을 안내하고 또 생기면 마지막으로 넣거나 바꾼 모드를 끄라고 함(노랑), 아니면 다시 설치를 안내(빨강) |
  | 2 | `installing` | 이번 부팅 진행 기록 `state=run` |
  | 3 | `nocar`(지우는 법 함께) | 투싼 NX4 한국 260902가 아님 |
  | 4 | `nohmgapi`, `oldhmgapi` | HMG-API(`installed.txt`)가 없거나 1.1.0-rc.10보다 낮음(2.1.1부터. 2.1.0은 rc.8). 판 비교는 HMG-API `Version`·USB 설치기와 같은 규칙(rc 꼬리까지) |
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
  | 17 | `nowifipart` | **이번 부팅에 칩이 없음**(`nochip`): `nochip` 서비스의 기록이 이번 부팅 것이거나 지금 커널 기록으로 그렇게 보이고(위 "Wi-Fi 칩이 없는 차"), 순정 핫스팟 기능이 켜짐. 그 부팅에는 칩이 올라오지 않으므로 부팅 뒤 5분(`apwait`)을 기다리지 않습니다(2.1.2-beta.4) |
  | 18 | `apoff` | 이번 부팅에 떴다가 지금 꺼짐(`wifi/ap.boot`). `nochip` 서비스가 쓴 `ap.boot`(`nochip_mark`)는 뜬 것이 아니므로 빼고 봅니다 |
  | 19 | `apwait` | 부팅 뒤 5분 전이고 AP가 아직 없음(`wifi/ap.fail`이 있어도). HMG-API 지기는 첫 시도가 실패하면 바로 `ap.fail`을 쓰고 다시 시도하며, 칩이 SDIO에 늦게 올라오는 첫 부팅도 있어 이 사이에는 "부품 없음"·"못 켬"으로 굳히지 않습니다. 문구는 켜는 것이 HMG-API임을 밝힙니다 |
  | 20 | `nowifipart` | **Wi-Fi 부품이 없는 차**(17을 못 본 경우: 커널 줄이 밀려남 등): 부팅 뒤 5분이 지났고, 순정 핫스팟 기능(칩 전원)은 켜졌는데 칩이 SDIO에 한 번도 안 보였고(HMG-API `public/wifi-chip`도 없음), `wlan0`이 없고, HMG-API가 이번 부팅에 AP를 띄우지 못함(`wifi/ap.fail`만). 2026-11-23 NX4HEV 260902가 이랬습니다. 유선 카플레이·안드로이드 오토와 계기판 길안내는 그대로라 "안 됨"으로 끝내지 않고(노랑), 무선은 USB Wi-Fi 동글([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48))을 기다립니다 |
  | 21 | `apfail` | 부팅 뒤 5분이 지나도 AP를 띄우지 못함(`wifi/ap.fail`, 또는 기록 없음). USB 동글처럼 `wlan0`이 있는 차도 여기로 옵니다 |

  - 부팅 보호의 근거는 HMG-API rc.6 이후 `core/zygote/zygote.c`입니다([#18](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/18)). 2.1.0은 HMG-API 1.1.0-rc.8 이상만 받으므로 rc.4의 규칙(`starts` 3에서 끔)은 두지 않습니다.
    - zygote가 시작할 때마다 `hook/starts`(120초를 버티지 못한 시작이 재부팅을 넘어 이어진 횟수)와 `hook/boot`(`<boot_id> <이번 커널 부팅 안의 횟수>`)를 1씩 올립니다. 올리기 전 값으로 이번 부팅 횟수가 3 이상이거나 `starts`가 6 이상이면 그 시작의 훅을 끕니다. 훅이 켜진 시작이 120초를 버티면 두 값을 지웁니다(HMG-API 설치도 지움). boot_id가 없으면 모든 시작을 한 부팅으로 셉니다.
    - 관리 앱이 읽는 값은 이번 시작이 올린 뒤 값입니다. 커널 줄이 없으면 이번 부팅 횟수 4 이상, 또는 이번 부팅에 센 기록이 있고 `starts` 7 이상일 때 꺼진 것으로 봅니다. `hook/boot`가 다른 부팅 것이거나 없으면 `starts`는 지난 값이라 그것만으로 보지 않습니다.
    - 재부팅은 새 커널 부팅이라 다음 시작은 `starts`만 봅니다. 그래서 노랑·빨강을 `starts` 6에서 나눕니다.
  - HMG-API의 프로젝션 AP 기록은 HMG-API Wi-Fi 지기(rc.8 `engine/HomeWifi.java`, 서비스 `hmgapi wifi`)의 것입니다. 부팅마다 Android Wi-Fi 서비스가 뜨자마자 한 번 띄우고, 이번 부팅 id를 `wifi/ap.boot`(떴거나 이미 떠 있었음, Wi-Fi 클라이언트가 켜져 있어 두었음)나 `wifi/ap.fail`(다시 시도 중)에 씁니다. 그 줄은 `/data/hmgapi/logs/hmgapi/wifi.log`에 남습니다. 차가 나중에 끈 AP는 지기가 다시 켜지 않고, 폰이 붙을 때 공식 모드가 다시 켭니다(rc.8 `hmgapi.hook.Wifi.projectionAp`). 칩이 없는 부팅이면 이 모드의 `nochip` 서비스가 `ap.boot`를 써서 지기의 다시 시도를 멈춥니다(위).
  - 상태 파일 키: `wm`·`wm_ver`·`wm_on`·`wm_hooks`·`bridge`(공식 모드), `hooks`·`hookmap`(HMG-API 훅), `kor_hooks`·`kor_hooks_why`·`kor_tbt`·`kor_tbt_log`(이 모드의 한국 카플레이 길안내, 아래), `feat_carplay`·`feat_aa`·`feat_hotspot`·`feat_wifi`(순정 기능), `chip`·`wlan0`(Wi-Fi 칩·장치), `nochip`·`nochip_mark`(이번 부팅에 칩이 없음, `nochip` 서비스가 `ap.boot`를 씀. 그때 `ap_boot`·`ap_fail`은 `no`로 내보냄), `proj`·`ap_boot`·`ap_fail`·`ap`·`ap_mode`·`other_ap`·`wpa`(프로젝션 AP), `cp_conn`, `state`. 이름·버전·예/아니요·개수만 넣고 SSID·비밀번호·휴대폰 이름·MAC·IP는 넣지 않습니다.
  - **한국 카플레이 길안내 줄**([#71](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/71), 2026-11-26): "자세히" 표의 "한국 카플레이 길안내" 칸에 HMG-API가 이 모드의 훅(#67)을 올렸는지 보입니다. DiPO 안에서 길안내를 시작했는지는 아닙니다(stepofspec 999 이상, 계기판 서비스 없음, 앱 부분 실패면 "켜짐"이어도 돌지 않음. HMG-API 앱 Logs 탭의 `CarPlay (NX4 KOR): … stays off`·`didn't start` 줄로 봄, PR #83 리뷰 4).
    - `kor_hooks`는 공식 모드의 `wm_hooks`와 같은 HMG-API 기록 줄(`mods: loaded nx4-kor …` / `mods: nx4-kor not loaded: <이유>`)에서, 같은 한 번의 읽기로 정합니다. 이유는 HMG-API 영문 그대로(지점·모드 이름뿐) `kor_hooks_why`에 200자까지 둡니다. rc.10의 지점 이유는 `hook point <지점> isn't mapped on this car (…)`, `… is mapped on this car only, which is enough for observe hooks: a change hook needs it …`(이 모드의 계기판 지점 8곳은 `change`), `… isn't one HMG-API has …`입니다(`engine/HookPlan.java`, PR #83 리뷰 1).
    - 부팅마다 그 부팅의 `hook map:` 줄이 `mods:` 줄보다 먼저 옵니다. 훅이 꺼진 부팅은 `mods:` 줄이 없으므로 `hook map:` 줄에서 두 모드의 값을 비웁니다(지난 부팅의 "loaded"가 남지 않음). 관리 앱은 HMG-API 훅이 꺼졌으면 이 칸을 "안 돎 (HMG-API 훅 꺼짐)"으로 보입니다(PR #83 리뷰 3).
    - `kor_tbt`·`kor_tbt_log`는 HMG-API에 저장된 소유자 값(`/data/hmgapi/settings/nx4-kor.json`)을 보고, 없으면 `mod/settings.json` 기본(켬·끔, mod-test가 같은지 봄)입니다. 저장된 값이므로, HMG-API 앱에서 바꾼 뒤 다시 시작하기 전에는 실제 동작과 다를 수 있습니다(`"apply": "restart"`, PR #83 리뷰 5·6).
    - 칸: "안 돎 (HMG-API 훅 꺼짐)", "꺼 둠 (설정, 공식 모드 길안내로 동작)"(`kor_tbt` 끔), "훅이 안 켜짐 (공식 모드 길안내로 동작: <이유>)", "켜짐", "켜짐 (진단 기록 켬)"(`kor_tbt_log` 켬), 기록이 없으면 "-".
    - 판정은 바꾸지 않습니다. 이 모드의 훅이 없어도 공식 모드의 카플레이 길안내는 돌기 때문입니다(관리 앱 UI는 그대로 두고 표에 줄 하나만 더함).
    - 길안내를 실제로 받고 있는지(`route guidance reaches this listener` 줄)는 보이지 않습니다. 그 줄은 HMG-API 앱 Logs 탭에서 봅니다.
  - 2.0.x 서비스가 쓰던 상태 안내 `/data/local/tmp/nx4-kor-hint.txt`(아이폰·AA 안내)는 2.1.0에 쓰는 곳이 없습니다. 앱은 그대로 읽지만 보통 아무것도 보이지 않습니다.
- [지금 재부팅]은 앱 개인 폴더의 `reboot.req`를 `status.sh --watch`(화면을 연 뒤 10분)가 받습니다. 설치 중(진행 기록 `run`), `/system`을 바꾸는 작업 중(HMG-API 적용·remount 등), HMG-API 부팅 보호에 걸릴 때는 거절합니다.
  - 부팅 보호 거절은 `hook/starts`가 5·6이고, 이번 시작의 watcher가 돌기 전("hooks on" 줄 시각 + 135초, 그 줄이 없으면 부팅 뒤 300초)일 때입니다. 재부팅은 새 커널 부팅이라 다음 시작의 이번 부팅 횟수는 0부터이고, `starts`가 6이면 다음 시작에, 5면 그다음 시작에 훅이 꺼지기 때문입니다. 이번 시작이 이미 꺼졌으면(커널 줄 guard, 또는 파일로 보아 꺼짐) 막지 않습니다. 앱은 "HMG-API는 내비가 켜지고 2분 안의 재부팅이 6번 이어지면 무선 기능을 끕니다."와 그 아래 줄 "3~5분 뒤에 다시 눌러 주세요."를 보입니다.
- 진단 기록 확인 창(`DiagActivity`)은 USB 설치기가 엽니다(아래 "진단 기록"). 투명 화면 위에 확인 창만 보이고, 답을 앱 개인 폴더의 `diag.ans`에 씁니다.
- **모양**은 투싼 NX4 순정 내비(표준형 5세대 와이드)의 타입1(어두운 화면)에 맞춥니다([#28](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/28)).
  - 색·글자 크기·여백은 `app/java/.../Ui.java` 한 곳에 둡니다. 값은 현대 국내형 Gen5W 웹 매뉴얼 그림에서 잰 근사값입니다. 크기는 1920x720 기준 px로 적고 화면 폭에 맞춰 늘이거나 줄입니다.
  - 결과 화면(본보기: 순정 설정 상세):
    - 위 제목 줄: 가운데 제목만 둡니다. 닫기는 차 화면 맨 위 시스템 줄의 `<`(뒤로)로 합니다. 앱 안 왼쪽 위에 있던 `<`는 바로 위 시스템 줄의 `<`와 겹쳐 뺐습니다(2026-11-27 사용자 결정).
    - 왼쪽 칸(1280): 요약 3줄을 흰 제목·회색 값의 목록 줄로, 그 아래 "자세히" 표, 맨 아래 확인 시각·앱 판·화면 크기 줄을 둡니다.
    - 오른쪽 칸(640, 분할 화면 자리): 판정, 지우는 법, 상태 안내, 알림을 두고, 맨 아래에 [지금 재부팅] 주 버튼 블록을 둡니다. 버튼 안내(보냄·거절·실패)는 버튼 바로 위에 나옵니다.
  - 설치 진행 화면(본보기: 순정 안내 화면): 가운데에 제목·단계·시안 막대·%·경과 시간·알림·안내를 두고, 맨 아래에 [닫기] 블록을 둡니다.
  - 색 띠는 문제일 때만 씁니다(2026-11-20 결정).
    - 정상인 판정과 좋은 소식 안내는 순정처럼 시안 세로 표시와 글자만 씁니다.
    - 확인 필요(노랑)·문제(빨강) 판정, 할 일이 있는 안내(노랑), 알림(연노랑)은 운전 중 한눈에 보이게 색을 채운 띠로 둡니다.
  - 글꼴은 시스템 기본 글꼴입니다. 독점 글꼴 파일은 넣지 않습니다.
  - 재부팅 확인 창은 순정 팝업 모양을 몰라 Holo `AlertDialog` 그대로입니다.
- 앱 메뉴 타일(`provides.launcher`)은 HMG-API가 이 모드를 올릴 때 런처 훅으로 넣습니다(rc.10 `hook/Mods.java` `loadOne`). HMG-API 훅이 꺼진 동안(이 차의 map이 없거나 부팅 보호)에는 타일이 없습니다(앱·서비스는 그대로). 그때는 같은 USB로 Update OTA를 다시 누르면 관리 앱이 열립니다.
  - 2.1.0까지는 이 모드에 자기 훅이 없어 HMG-API 훅만 켜지면 타일이 생겼습니다. #67로 훅이 생긴 뒤로는 **HMG-API가 이 모드의 훅을 거절하면(지점이 이 차의 map에 없음, 이 차에서만 찾은 지점이라 `change`를 걸 수 없음, HMG-API가 모르는 지점, 다른 모드와 겹침) 타일도 없습니다.** HMG-API는 거절한 모드를 기록만 하고 건너뛰어 타일을 넣지 않기 때문입니다(`Mods.load`, PR #83 리뷰 2). 앱·서비스와 공식 모드의 무선·길안내는 그대로이고, 관리 앱은 같은 USB로 Update OTA를 다시 눌러 엽니다("한국 카플레이 길안내" 줄에 이유가 보임). 이 차의 map에는 이 모드의 지점 9곳이 모두 있습니다(`tests/fixtures/nx4-map-points.txt`). 그대로 둘지는 [#71](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/71)에 적었습니다.

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
- **HMG-API 기다리기**(2026-11-25, 부팅이 끝나면 바로 눌러도 되게): HMG-API(`hmgapid`와 `/data/hmgapi` 모두)가 있으면 `hmgapid ping`에 답할 때까지 기다립니다. HMG-API가 없는 차(설치 갈래가 "HMG-API 없음"으로 보는 차와 같음)는 기다리지 않습니다.
  - 차례(PR #61 리뷰 1): HMG-API가 필요 없는 시작 전 확인(아래 0의 스틱 묶음·옛 2.0.x 꼴 payload·NEMESIS·Korea Projection 패키지) 뒤, HMG-API 판 확인 앞입니다. 잘못된 스틱이나 NEMESIS·Korea Projection 패키지가 있는 차는 부팅 직후에도 기다리지 않고 바로 그 문구로 멈춥니다. 지우기 갈래는 그런 확인이 없어 갈래에 들어가자마자 기다립니다.
  - 진단 기록 묻기는 기다린 뒤입니다(진단이 HMG-API 상태·Car Report를 모으므로). 그 앞의 시작 전 확인에서 멈출 때는 예전처럼 멈추기 전에 묻습니다. 그때는 기다리지 않으므로 HMG-API가 바로 답할 때만 HMG-API 상태가 들어갑니다.
  - 근거(HMG-API 1.1.0-rc.8): `hmgapid daemon`은 zygote가 시작할 때마다 zygote 래퍼가 띄우고(`core/zygote/zygote.c` `start_hmgapid`), 부팅 훅(`hmgapid boot`)도 없으면 띄웁니다. 소켓을 열기 전에는 "not running"이고, 일꾼 8개(`MAX_WORKERS`)가 차면 75(busy)로 바로 끊습니다(`core/hmgapid/hmgapid.c`). 부팅 뒤에는 `boot.sh`(`install/common/boot.sh`)가 binds·앱 설치·`engine recover`를 바로, `map-car --local`을 90초 뒤, 앱 목록 동기화를 120초 뒤에 돌립니다.
  - 시간: 3초마다 다시 묻고, 부팅 뒤 300초까지 기다립니다(관리 앱의 Wi-Fi 기다림 `AP_WAIT`, 재부팅 거절의 줄 없을 때 끝과 같은 300초). 늦게 눌렀어도 30초는 다시 묻습니다. 그래서 최대 약 5분입니다. 기다리는 동안 토스트("HMG-API가 준비되기를 기다리는 중입니다(최대 N분). USB를 빼지 마세요.")를 처음과 1분마다 띄웁니다. 끝까지 답이 없으면 지금처럼 "기다려도 HMG-API가 응답하지 않습니다. … 재부팅하고 다시"로 멈춥니다(아무것도 바꾸지 않음). 지우기도 같습니다.
  - HMG-API 부팅 작업은 기다리지 않습니다. 설치기가 부르는 engine 명령은 모두 `state/engine.lock`을 잡고 하나씩 돌기 때문입니다(`core/runtime/java/hmgapi/engine/Engine.java` `lock`, 최대 15분 기다림). `engine recover`가 돌면 설치기의 첫 engine 명령(시작 전 계획)이 기다리고, recover가 재부팅하면 아무것도 바꾸기 전에 끊깁니다. `map-car --local --if-needed`는 HMG-API에 이 차의 map이 있을 때만 점을 더하는데 rc.8에는 NX4 map이 없어 아무것도 쓰지 않습니다(`engine/MapProbe.java` `run`). 나중에 NX4 map이 들어와도 설치기의 `map-car --write`는 "not written"으로 끝나고, `--local`이 쓰는 점은 HMG-API가 스스로 확인한 뒤 다음 시작부터 씁니다.
- **재부팅 안내 전 부팅 보호 기다리기**: 무엇이 바뀌어 재부팅을 안내하기 직전(지우기는 스스로 재부팅하기 직전)에, 이번 zygote 시작이 HMG-API 부팅 보호에 아직 확인되지 않았으면(`hook/starts` ≥ 1) 확인 시각까지 기다립니다. 훅이 켜진 시작이 120초(`GUARD_DELAY`)를 버티면 watcher가 `starts`를 0으로 씁니다. 그 전에 재부팅하면 `starts`가 쌓이고 6번 이어지면 다음 시작의 훅이 꺼지기 때문입니다(`core/zygote/zygote.c`).
  - 확인 시각은 관리 앱의 [지금 재부팅] 거절(`mod/bin/status.sh` `take_rbreq`)과 같습니다: 이번 부팅 커널 로그의 마지막 "hooks on" 줄 시각 + 120 + 15초, 그 줄이 없으면 부팅 뒤 300초. `take_rbreq`는 `starts`가 5·6일 때만 막지만, 설치기는 RESET으로 하는 재부팅을 막을 수 없으므로 1부터 기다립니다. `starts`가 0이 되면 바로 멈춥니다.
  - 기다리지 않는 때(`status.sh` `take_rbreq`와 같은 규칙): HMG-API 판(`installed.txt`)이 없음, `starts`를 못 읽음·0, 이번 부팅 줄이 off·guard(watcher가 없음), 줄이 없고 `hook/enable`이 없거나 `hook/disable`이 있거나 파일로 보아 이번 시작이 이미 부팅 보호로 꺼짐(`guard_files`: 이번 부팅 횟수 ≥ 4, 또는 이번 부팅에 센 기록이 있고 `starts` ≥ 7).
  - 기다리는 동안 진행 기록은 `state=run`("재부팅해도 되는 때를 기다리는 중입니다")이라 [지금 재부팅]도 받지 않고, 토스트를 한 번 띄웁니다. map 만들기(1~2분)가 끼면 보통 이미 지나 있습니다.
  - `status.sh`는 busybox awk를 쓰고 설치기는 툴박스·mksh만 쓰므로 같은 계산을 mksh로 옮겨 두었습니다(`zygote_info`·`zyg_scan`·`guard_files`). `tests/mod-test.sh`가 `zyg_scan`을 차의 셸 계열(mksh·ksh·dash 중 있는 것)마다 돌려 `status.sh` `zygote_info`와 답을 맞춥니다. 바꾸면 둘을 함께 봅니다.
- HMG-API가 없으면 같은 스틱의 HMG-API 설치기로 넘기거나 멈춥니다.
- 최소 판은 설치기의 `HMG_MIN`(`1.1.0-rc.10`, 2.1.1부터. 2.1.0은 rc.8)과 스틱의 두 모드 `mod.json` `hmgapi`(`>=…`) 중 가장 높은 것입니다. 설치된 판(`installed.txt`의 `version`)이 낮으면 같은 스틱의 HMG-API 설치기가 그 판 이상(`HMGAPI/install/payload/VERSION`)일 때 그것으로 넘기고(업데이트 뒤 재부팅, Update OTA를 한 번 더), 아니면 "HMG-API <최소 판> 이상으로 먼저 올려 주세요"로 멈춥니다.
- 판 비교는 HMG-API `Version`과 같은 규칙(semver, `-rc.N`까지)입니다. 최소 판에 꼬리가 없으면 그 판의 rc도 채웁니다(`meetsHmgapi`). 판을 읽지 못하거나 비교할 수 없는 꼬리면 기록만 하고 지나갑니다(엔진이 설치할 때 다시 봄).

**설치·업데이트 순서**(같은 판도 같은 순서로 돌고, 이미 된 단계는 건너뜁니다)
0. **스틱 확인**: 스틱의 nx4-kor(`payload/mod.json`)가 아직 옛 2.0.x 꼴(`conflicts`에 `wireless-carplay-aa`)이면 아무것도 바꾸지 않고 멈춥니다. HMG-API는 설치 때 `conflicts`를 보지 않아 설치는 되지만, 끝 계획이 conflict 문제로 막혀 2.0.x를 되돌린 뒤 아무것도 적용하지 못한 채 끝나기 때문입니다(PR #52 리뷰 2). 그래서 nx4-kor 2.1.0(PR #50)이 합쳐진 뒤에 만든 묶음만 씁니다. release 워크플로도 묶음의 `payload/mod.json`을 확인합니다.
   - **NEMESIS**([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75), 2026-11-26 사용자 결정): NEMESIS의 실행 파일(`/system/xbin/nemesis`, HMG-API `engine/NemesisSync.java`가 NEMESIS가 있다고 보는 기준과 같음)이 있으면 아무것도 바꾸지 않고 멈춥니다(`NMS_MSG`: "NEMESIS가 깔린 차에는 NX4 KOR를 설치하지 않습니다. NEMESIS를 지우기 전에 USB의 README.txt를 꼭 읽어 주세요."). 이 모드는 순정 시스템에 KP 모드보다 부하를 덜 주는 것을 목표로 하므로 NEMESIS와 함께 쓰지 않습니다.
     - 새 설치·업데이트·같은 판 다시 설치(`REINSTALL` 포함)를 모두 거절하고, HMG-API도 설치·업데이트하지 않습니다. 지우기(`UNINSTALL`·`UNINSTALL-ALL`)는 막지 않습니다.
     - USB 설치기만 봅니다(사용자 결정). HMG-API 앱으로 모드 zip을 직접 넣었거나 이미 NEMESIS와 함께 쓰던 차에서 관리 앱과 길안내 훅은 그대로 돕니다.
     - NEMESIS 1.17 차에서 HMG-API를 rc.10으로 올리거나 지운 뒤 다시 설치하는 길(#397)은 이 USB가 아니라 HMG-API 릴리스의 USB·update zip으로 안내합니다(README "HMG-API를 지울 때", `usb/README.txt` "NEMESIS가 깔린 차"). NEMESIS를 지우는 차례도 그 안내를 따릅니다. HMG-API를 둔 채 NEMESIS를 지우고, 그 HMG-API가 rc.10보다 낮으면 먼저 HMG-API 릴리스로 rc.10 이상으로 올립니다(`FORCE` 차는 반드시, HMG-API 1.1.0-rc.10 릴리스 노트, PR #76 리뷰 3).
     - 차례와 진단 기록 묻기는 아래 Korea Projection 패키지와 같고, 그보다 앞에서 봅니다.
   - **Korea Projection 패키지**([#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13), 2026-11-24 사용자 결정): NEMESIS의 Korea Projection 패키지 폴더(`/data/nemesis/apps/korea.projection`, KP 1.8.0 `NEMESIS.data`의 `id=korea.projection`)가 있으면 아무것도 바꾸지 않고 멈춥니다(`KORPROJ_MSG`: "NEMESIS에 Korea Projection이 설치되어 있어 설치하지 않았습니다. NEMESIS에서 Korea Projection을 지우고 내비를 재부팅한 뒤 다시 해 주세요."). 그 패키지의 `hostapd`가 HMG-API 프로젝션 AP와 Wi-Fi를 다투기 때문입니다.
     - 재부팅까지 안내하는 것은 패키지 폴더가 재부팅 때 없어지거나 그 `hostapd`가 재부팅 전까지 남는 차가 있을 수 있어서입니다(PR #57 리뷰 1). 토스트, README, `usb/README.txt`, `docs/troubleshooting.md`의 안내가 모두 같은 뜻입니다.
     - 그 패키지 폴더만 봅니다. NEMESIS 자체는 위 NEMESIS 확인이 먼저 막으므로, 이 확인은 NEMESIS 실행 파일 없이 폴더만 남은 차에서 멈춥니다. 다른 NEMESIS 패키지 폴더(`wireless.projection` 등)만으로는 막지 않습니다. 지우기(`UNINSTALL`·`UNINSTALL-ALL`)도 막지 않습니다.
     - HMG-API에 든 한국 차 빌드 무선 모드(같은 id `wireless-carplay-aa`, 이름 "Korea Projection…")는 이것과 따로, 아래 3에서 공식판으로 바꿉니다.
     - 차례: HMG-API 기다리기보다 앞이라 부팅 직후에도 기다리지 않고 바로 멈춥니다. 진단 기록은 멈추기 전에 묻습니다. 스틱 확인 뒤, 위 "HMG-API 확인" 앞에서 봅니다. HMG-API가 없거나 낮으면 HMG-API 확인이 같은 스틱의 HMG-API 설치기로 넘겨 HMG-API를 설치·업데이트하고 재부팅하므로, 그 전에 멈춰야 아무것도 바꾸지 않습니다. 그래서 같은 판이어도 관리 앱은 열지 않고 토스트로만 알립니다.
   - 같은 판(다시 설치하지 않음)이고 관리 앱이 있으면 여기서 관리 앱을 먼저 엽니다. 아래 단계에서 멈춰도 화면이 열립니다.
1. **시작 전 계획**(`engine plan`): 다음이면 아무것도 바꾸지 않고 멈춥니다. 끝에서 적용할 수 없기 때문입니다.
   - 다른 모드의 적용하지 않은 변경(`change`·`update`·`setting`·`bind`)이나 HMG-API 밖에서 바뀐 파일(`rebase`)
   - 되돌리기 줄(`restore … (stock)`, `setting … back to stock`, `unbind`)이 있는데 이번에 지울 모드(옛 2.0.x, 2.0.x의 기록만 남은 것, 한국 차 빌드)가 없음. 되돌리기 줄에는 모드 이름이 없어, 이때는 앞서 다른 모드를 지우고 적용하지 않은 것입니다(PR #52 리뷰 1)
   - `engine plan`의 종료 코드가 0(계획)이나 3(문제 목록)이 아님. 예: rc.8의 "an earlier apply isn't finished or is a trial"(종료 1). 종료 코드는 `install.log`의 `--- engine plan (<꼴>, 종료 코드 <n>)` 줄에 남깁니다(`PLANFAIL_MSG`). 옛 2.0.x를 뺀 뒤의 계획이나 지우기 길에서 그러면 같은 문구로 끝납니다
   - 문제(`problem`, `nothing changed: N problem(s)`)는 시작 전에 거르지 않습니다. 어느 모드의 문제인지 줄로 가르기 어렵고, 옛 2.0.x와 한국 차 빌드의 conflict처럼 이번 실행이 푸는 문제도 있기 때문입니다. 그래서 다른 모드의 문제가 늘 남은 차는 설치·map 만들기를 다 한 뒤 끝 계획에서 `HOOKS_MSG`로 막힙니다(PR #52 리뷰 8). 그런 차는 HMG-API가 원래 아무것도 적용하지 못하는 상태이고, 끝 문구가 HMG-API 앱에서 보라고 안내합니다
2. **옛 NX4 KOR 2.0.x 되돌리기**(`old_revert`): 설치된 nx4-kor의 `mod.json` `conflicts`에 `wireless-carplay-aa`가 있으면 2.0.x로 봅니다(판 번호로 가르지 않음. `develop`의 판은 `release/`에서만 바뀜). 공식 모드와 함께 설 수 없으므로 끝까지 되돌린 뒤에만 새로 설치합니다.
   - 설치된 모드 폴더를 작업 폴더로 복사 → `engine remove nx4-kor` → 계획이 되돌리기와 우리 두 모드의 것뿐이면 `engine apply` → 옛 판의 `bin/uninstall.sh`를 사본으로 돌림.
   - 까닭: 2.0.x의 `preun.sh`는 HMG-API rc.7부터 계획에 늘 나오는 설명 줄(`home Wi-Fi`, `network`)을 변경으로 봐 적용하지 않고, 그러면 무선 권한 파일 되돌리기(`perms_revert`)도 건너뜁니다. 설치기가 먼저 빼고 적용하면 `preun.sh`는 "HMG-API에 이 모드가 없음"으로 보고 이 모드가 직접 바꾼 것(무선 권한 파일, Wi-Fi 잠금, 순정 AP 저장값)을 되돌리고 기록(`/data/nx4-kor`)을 지웁니다.
   - 뺀 뒤의 계획에 다른 모드의 변경이 있으면 적용하지 않고 멈춥니다("HMG-API 앱에서 적용").
   - 2.0.x의 기록(`/data/nx4-kor/backup`, 2.1.0은 쓰지 않음)이 남은 차는 스틱의 `NX4/legacy-2.0`으로 같은 차례로 되돌립니다(2026-11-23 사용자 결정). nx4-kor가 없는 차(HMG-API 앱에서 2.0.x를 지움)와, 2.0.x 위에 2.1.0 이후가 들어간 차(adb·HMG-API 앱으로 넣음. 2.1.0의 `uninstall.sh`는 이 기록을 남김) 모두입니다. 2.1.0 이후가 있으면 먼저 HMG-API에서 빼고(`engine remove`) 적용한 뒤 되돌리고, nx4-kor를 다시 설치합니다(관리 앱은 그 뒤에 엶, PR #52 리뷰 7). 그 폴더는 `scripts/build.sh`가 태그 `v2.0.4-beta.1`에서 그 판의 `bin/uninstall.sh`·`scripts/preun.sh`·`svc/env.sh`·`svc/hotspot.sh`·`mod.json`을 고치지 않고 꺼내 넣은 것입니다(`SOURCE`에 태그와 커밋). busybox는 설치기가 payload의 것을 사본에 넣습니다. 모드 폴더가 없으니 `engine remove`는 하지 않고, 앱 삭제가 적용되지 않아 계획에 남은 되돌리기 줄을 받아 적용한 뒤 그 `uninstall.sh`를 돌립니다.
     - 까닭: 2.1.0의 `bin/uninstall.sh`는 2.0.x가 바꾼 것을 되돌리지 못합니다(그 기록 폴더만 남김). 2.1.0을 둔 채 옛 `uninstall.sh`만 돌리면 옛 `preun.sh`가 2.1.0을 빼면서 rc.7부터의 설명 줄 때문에 적용과 권한 파일 되돌리기를 건너뜁니다. 그래서 설치기가 먼저 빼고 적용합니다.
     - `legacy-2.0`이 없는 스틱(직접 만든 묶음 등)이면 아무것도 바꾸지 않고 멈추고 2.0.x 릴리스 USB의 `NX4/UNINSTALL`로 안내합니다(`OLDLEFT_MSG`).
   - 2.1.0 이후의 기록만 남은 차는 스틱의 사본(`payload/bin/uninstall.sh`)으로 정리합니다. 실패해도 설치는 계속합니다.
3. **공식 무선 모드**(`wireless-carplay-aa`): 없거나 스틱의 판보다 낮으면 `hmgapid engine install <zip> --any-car`. NX4는 공식 모드의 `system` 목록에 없습니다. HMG-API는 `--any-car`를 `hmgapi.json` `overrides.ignore_system`에 남기고, 그 뒤 계획마다 `WARNING: wireless-carplay-aa: …`를 냅니다.
   - 차주가 넣은 것이라도 같거나 높은 판이면 그대로 둡니다(HMG-API는 낮은 판을 `--force` 없이 받지 않음). 판을 비교할 수 없으면 그대로 둡니다. `NX4/REINSTALL`이면 같은 판을 다시 설치합니다.
   - `mod.json` `name`에 "Korea Projection"이 든 것(한국 차 빌드 2.4.x, 같은 id)은 공식판이 아니고 작성자 키가 달라 그 위에 설치할 수 없습니다. 지우고(`engine remove`) 공식판을 설치합니다. 지우기는 2(옛 2.0.x 되돌리기)보다 먼저 합니다. 그래야 2의 적용에 한국 차 빌드의 적용하지 않은 변경이 섞이지 않습니다.
   - 꺼 둔 것(`.disabled`)은 켭니다(`hmgapid enable`).
4. **nx4-kor**: 같은 판이면 건너뜁니다(`NX4/REINSTALL`이면 다시). 업데이트면 돌던 서비스를 적어 두고 `bin/uninstall.sh --update` → `engine install` → 그 서비스를 다시 띄웁니다. 거절되면 예전 판의 서비스를 다시 띄우고 실패로 끝냅니다. 그다음 관리 앱을 엽니다.
5. **map**(2.0.x `hotspot.sh` `setup_hmgapi`와 같은 규칙): 이 차의 map(`state/local-map.json`)이 없으면 `engine map-car --write`(1~2분)로 만듭니다. "not written: HMG-API has a map"이면 HMG-API의 map을 씁니다. 그다음 늘 `engine verify-map`으로 확인합니다(확인을 통과해야 다음 시작부터 훅이 켜짐, `state/map-check.json`). 확인에 실패하면 이번에 만든 map만 지웁니다(`map-car --forget`). 이미 있던 map은 지우지 않습니다. 어느 쪽이든 적용하지 않고 실패로 끝냅니다.
6. **적용**: 계획(`plan_check final`)이 우리 두 모드(`[nx4-kor]`, `[wireless-carplay-aa]`, 둘이 함께인 `[nx4-kor, wireless-carplay-aa]`)의 변경과, 이번에 지우거나 판을 바꿔 설치한 모드의 되돌리기(`restore … (stock)`, `setting … back to stock`, `unbind`)뿐이고, 훅이 켜질 때(`hooks are off`·`hooks <id> won't load` 없음)만 `engine apply`를 합니다. `problem` 줄이나 모르는 줄이 있어도 적용하지 않습니다.
   - 설명 줄은 변경이 아닙니다: `app`·`service`·`usb`, `event`·`vehicle`·`driving`·`panel`·`button`, `home Wi-Fi`·`wifi`·`network`·`projection`, `note`·`probe`·`override`·`skip`·`WARNING`, `hooks … share it`, `<id>: part … left out`(HMG-API rc.4·rc.8 소스에서 확인). `mod-test.sh`가 HMG-API 엔진(PC)의 실제 계획으로도 봅니다.
7. 무엇이 바뀌었으면(옛 판 정리, 모드 설치·켜기, 처음 통과한 map 확인, 적용) 진행 기록을 "재부팅 필요"로 끝내고 관리 앱의 [지금 재부팅]을 안내합니다. 바뀐 것이 없으면 "설정이 끝나 있습니다"입니다. 설치기는 재부팅하지 않습니다.

**진행 기록**: `/data/local/tmp/nx4-kor-progress.txt`를 2.0.x 서비스(`hotspot.sh` `prog`)와 같은 꼴로 씁니다. 관리 앱(`Report.java`)이 그대로 읽어 막대를 보입니다.
- 줄 차례: `pct`, `state`(`run`·`done`·`reboot`·`fail`), `stage`(한국어 문구), `start`, `t`, `boot`(이번 부팅 id), `step`(진행 중일 때 `<단계>/6`), `ust`, `ut`. 644로 씁니다.
- 단계: 1 시작, 2 옛 판 정리, 3 공식 무선 모드, 4 NX4 KOR, 5 map 만들기·확인, 6 적용. 건너뛰는 단계가 있습니다.
- 무엇을 바꾸기 시작한 뒤(시작 전 계획 확인 뒤)에만 씁니다. 그 전에 멈추면(NEMESIS, Korea Projection 패키지, HMG-API 없음·낮음, 다른 모드의 변경) 쓰지 않습니다.
- 끝의 `stage` 문구는 설치기 머리말의 `*_MSG` 값입니다. 상태 판정(`bin/status.sh`)이 이 문장으로 판정 코드를 가르므로 바꾸면 함께 봅니다. `OTHERPLAN_MSG`·`APPLYFAIL_MSG`·`DONE_REBOOT_MSG`·`DONE_MSG`는 2.0.x 서비스와 같은 문장입니다.

**같은 판**: 관리 앱을 맨 앞(위 0)에서 엽니다. 그래서 뒤 단계에서 멈춰도 화면이 열리고, 타일이 없을 때 관리 앱을 여는 길로도 씁니다(NEMESIS나 Korea Projection 패키지가 있거나 HMG-API가 없거나 응답하지 않으면 그 전에 멈춥니다). nx4-kor는 다시 설치하지 않고, 공식 무선 모드는 스틱보다 낮을 때만 올리며, map은 없을 때만 만듭니다. 그다음 map 확인과 계획을 봅니다.

**지우기**
- `NX4/UNINSTALL`: nx4-kor만 지웁니다. HMG-API, 공식 무선 모드, 이 차의 map은 남깁니다.
  - 설치된 모드의 `bin/uninstall.sh` → `scripts/preun.sh`(관리 앱 작업 파일 지우기 → HMG-API에서 이 모드를 뺌. 2.1.0은 시스템 파일을 바꾸지 않아 적용할 것이 없음) → 기록 지우기 → 재부팅.
  - 옛 2.0.x면 위 2와 같이 설치기가 먼저 빼고 되돌리기만 적용한 뒤(`plan_check revert`) 옛 판의 `uninstall.sh`를 사본으로 돌립니다.
  - HMG-API를 먼저 지웠어도 남은 모드 폴더나 스틱의 사본으로 되돌립니다. 이때 `/system`은 DSP OTA 프로세스에서 순정 `mount`로 엽니다.
  - 2.1.0 이후의 `uninstall.sh`는 2.0.x의 기록(`/data/nx4-kor/backup`)을 되돌리지 못해 그 폴더만 남깁니다(2.0.x 위에 adb·HMG-API 앱으로 2.1.0을 넣은 차, PR #50). 그러면 설치기가 스틱의 `NX4/legacy-2.0`으로 마저 되돌립니다.
  - 모드 폴더 없이 2.0.x의 기록(`/data/nx4-kor/backup`)만 남았으면 스틱의 `NX4/legacy-2.0`으로 되돌립니다(위 2와 같음). HMG-API도 없으면 계획·적용 없이 그 사본의 `uninstall.sh`만 돌립니다. `legacy-2.0`이 없는 스틱이면 지우지 않고 멈춥니다.
- `NX4/UNINSTALL-ALL`: 위와 같고, 그 뒤 공식 무선 모드도 `engine remove`하고 계획이 되돌리기뿐이면 적용합니다. 공식 무선 모드만 남은 차에서도 됩니다(그때 결과 문구는 "공식 무선 모드를 지웠습니다"). 계획에 다른 변경이 있으면 적용하지 않고 "HMG-API 앱에서 변경 사항을 적용해 주세요(무선 모드 삭제)"로 알립니다. HMG-API와 map은 남깁니다(2026-11-23 사용자 결정).
- 설치기는 HMG-API를 지우지 않습니다(`UNINSTALL`·`UNINSTALL-ALL` 모두). HMG-API를 지우라고 하는 안내에는 모두 NEMESIS 1.17 경고를 둡니다: README "HMG-API를 지울 때", `troubleshooting.md` "되돌리기" 2, USB `README.txt` "지우기".
  - HMG-API 1.1.0-rc.8 이하를 NEMESIS 1.17에서 지우면 재부팅 한두 번 뒤 Android가 뜨지 않습니다([Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397)).
  - 지울 때 도는 것은 그 판을 설치할 때 저장한 삭제입니다. 그래서 먼저 rc.10 이상으로 올린 뒤 지우라고 안내합니다. 2.1.2부터 이 USB는 NEMESIS가 깔린 차에서 HMG-API를 올리지 않으므로(#75) 올리는 길은 HMG-API 릴리스(NEMESIS Manager용 `hmgapi-<판>-nemesis.zip`, USB 묶음, update zip)로 안내합니다. 2.1.1 이전의 이 USB는 HMG-API를 올린 뒤 NX4 KOR까지 설치하므로 NEMESIS가 깔린 차에는 안내하지 않습니다(PR #76 리뷰 1).
  - `FORCE`로 설치한 NEMESIS 1.17 차는 rc.9로 올리기만 해도 Android가 뜨지 않으므로, rc.9로 올리지 말라는 것도 함께 적습니다.
  - #397의 비상 USB 복구는 차에서 된 적이 없다는 것도 함께 적습니다.
- 관리 앱에는 지우기 버튼을 두지 않습니다(2026-11-24 사용자 결정, [#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)).
  - 2.1.0의 nx4-kor는 시스템 파일·Wi-Fi 설정을 바꾸지 않습니다. 그래서 HMG-API 앱에서 지워도 HMG-API가 앱·서비스·타일을 내리고, 기록 파일(`/data/nx4-kor`, `/data/local/tmp/nx4-kor*`)만 남습니다.
  - 남은 기록은 `NX4/UNINSTALL`로 정리합니다. 설치기 자신의 기록(`nx4-kor-usb.log`, 차에서는 `nx4-kor-ota-finish.sh`도)은 남깁니다. `/data/nx4-kor` 없이 `/data/local/tmp/nx4-kor*`만 남은 차에서는 "설치되어 있지 않습니다"로 끝나고 지우지 않습니다(설치기는 모드 폴더, 2.0.x 기록, `/data/nx4-kor` 중 하나가 있어야 지움). 남은 것은 해가 없는 작은 파일입니다.
  - 그래서 앱이 자기 자신을 지우는 흐름(감시자가 지우기 스크립트를 임시 폴더로 옮겨 돌림)은 만들지 않습니다.
- 기록: 스틱의 `NX4/install.log`에 이어 씁니다. 시작할 때 스틱의 앞 기록을 내비 쪽 기록(`/data/local/tmp/nx4-kor-usb.log`)으로 옮겨 두고, 끝날 때 그 전체를 스틱에 씁니다. 그래서 여러 번 눌러도 앞의 시도가 남고(빈 줄로 나뉨), 한 번 누른 기록은 한 번만 들어갑니다. 비우려면 스틱에서 그 파일을 지웁니다.
- 진단 기록(`diag`): 공식 무선 모드를 이 차에서 시험하기 전에 알아 둘 것([#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38))을 adb 없이 가져오려고 둡니다.
  - **먼저 화면에서 묻습니다**(`ask_diag`). Car Report가 map 만들기와 같은 분석(MapProbe)을 돌려 1~2분 걸리기 때문입니다(PR #41 리뷰 1).
    - 스틱에 `NX4` 폴더가 있으면 지우기·설치·같은 판 어느 갈래든, **아무것도 바꾸기 전에** 관리 앱의 확인 창을 엽니다(`am start -n io.github.jayparklab.nx4kor/.DiagActivity --es id <id> --ei wait 60 --el until <지금+15초>`).
    - 확인 창은 앱 개인 폴더의 `files/diag.ans`에 `<id> <답>` 한 줄을 씁니다. 열리면 `shown`, [모으기]는 `yes`, [건너뛰기]·뒤로는 `no`, 60초 안에 고르지 않으면 `timeout`을 쓰고 스스로 닫힙니다. 설치기는 자기가 준 id의 답만 믿습니다.
    - `until`은 설치기가 창이 뜨기를 기다리는 마지막 시각입니다. 그 뒤에 늦게 열린 창은 설치기가 이미 넘어가 아무도 답을 읽지 않으므로, 아무것도 쓰지 않고 바로 닫힙니다(PR #41 리뷰 6).
    - 확인 창은 자기 task로 열립니다(매니페스트 `taskAffinity=""`). 이번 부팅에 관리 앱을 열었어도 그 위에 얹히지 않고, 창 뒤에 DSP OTA 화면이 보입니다(PR #41 리뷰 7).
    - **[모으기]를 고른 때만** 스틱의 `NX4/diag/<시각>/`에 새로 모읍니다. 그 밖에는 모으지 않고 `install.log`에 까닭만 적은 뒤 설치기가 그대로 이어집니다.
      - 관리 앱이 없음(HMG-API가 앱을 설치하기 전, 첫 설치)
      - 확인 창이 없는 예전 판 앱(`am start`가 Error를 냄), 또는 창이 15초 안에 뜨지 않음
      - [건너뛰기]·뒤로, 고르지 않음, 답이 오지 않음(최대 60초 + 30초)
    - 그래서 확인 창이 없는 예전 판(2.0.1-beta.1까지)에서 올리는 첫 Update OTA에서는 모으지 않습니다. 설치·설정이 끝나고 재부팅한 뒤 같은 USB로 한 번 더 누르면(같은 판: 관리 앱만 엶) 확인 창이 뜨고, 적용된 뒤의 상태가 담깁니다. 순정 md5는 `hmgapi-status.txt`에 있습니다.
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
    | `logs/` | 이 모드의 `ap.log`, 서비스 기록(`/data/hmgapi/logs/nx4-kor/`, `nochip.log` 포함), `/data/local/tmp/nx4-kor/*.txt`(map 만들기·확인·계획·적용 결과), `/data/local/tmp/nx4-kor-*.txt`(상태 파일, 칩 없음 기록), HMG-API 설치 기록, HMG-API Wi-Fi 지기 기록(`hmgapi-wifi.log`, 2.1.2-beta.4부터) |
    | `dongle/` | USB Wi-Fi 동글 드라이버를 이 차 커널에 맞춰 빌드하고 순정 HAL 자리에 잇는 데 필요한 것([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48) 1단계). 아래 표 |
    | `iap2/` | 순정 iAP2 파일 사본과 목록(설치기 `diag_iap2`, 2026-11-27). 카플레이 차선 안내가 계기판에 오지 않는 원인([#90](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/90))을 PC에서 봅니다. 아이폰에 알리는 CarPlay 연결 정보(iAP2 identification)를 만드는 쪽입니다. 들어 있는 것: `/system/lib`의 `.so`와 `/system/app`의 apk·odex 중 이름에 iap2가 든 것(대소문자 가리지 않음). 공식 모드의 `carplay-identification-fc7` 패치가 고치려다 이 차에서 실패하는 네이티브 `libiap2session.so`와, Java 쪽 연결 정보 메시지(`Iap2ServerApp.odex`의 `Iap2InitInformationMsg`, HMG-API 훅 지점 `iap2.init_info`)가 여기 듭니다. `files.txt`는 `/system` 몇 폴더(두 단계까지)의 이름에 iap2·carplay가 든 파일 경로(이름만), `README.txt`는 공개하지 말라는 안내입니다. 복사하지 못한 파일은 지우고 `failed.txt`에 적고, 맞는 파일이 없으면 `none.txt`. **순정 바이너리이므로 이 폴더는 공개 이슈에 올리지 않습니다** |

  - `dongle/`(설치기 `diag_dongle`, 읽기만 함):

    | 파일 | 내용 |
    |---|---|
    | `kernel.txt`, `modules.txt` | 커널 판(`osrelease`, `/proc/version`), 모듈 적재 조건(`modules_disabled`, `sig_enforce`), `cfg80211`이 있는지, USB 포트 전원 매개변수(`/sys/module/*/parameters/vbus*`), `boot_id`(시동 끄고 켜기가 새 부팅인지 견줌), `wifi.interface`·`wlan.driver.status`, `/proc/modules` |
    | `config.gz`, `config.txt`, `config-sum.txt` | 차 커널 설정(`/proc/config.gz`)과 푼 것, gz의 md5와 푼 것의 md5·sha256. 드라이버 빌드의 커널 설정과 같은지 PC에서 견줍니다(`sh drivers/config-sum.sh config.txt`, `drivers/README.md` "커널 준비"). 없으면 그렇다고 적습니다 |
    | `system-wifi-ls.txt`, `system-wifi-md5.txt`, `ko-vermagic.txt` | `/system/wifi`(순정 `bcmdhd.ko` 등)의 목록·md5, `/system/wifi`·`/system/lib/modules`의 `.ko`마다 vermagic |
    | `wifi-strings.txt` | 순정 HAL(`libhardware_legacy.so`)·`hostapd`·`wpa_supplicant`·`netd`에서 드라이버 관련 문자열만(모듈 이름, insmod 인자 `iface_name` 등, `nl80211`, `add_ie`) |
    | `usb.txt`, `usb-ls.txt`, `usb-drivers.txt` | USB 장치의 ID·속도·전력·종류·제조사·제품 이름(일련번호는 넣지 않음), 버스·컨트롤러 경로, 드라이버에 붙은 인터페이스 |
    | `net-ls.txt`, `dmesg-usb-wifi.txt` | 네트워크 장치 이름과 경로(MAC은 넣지 않음), 커널 로그 중 USB·Wi-Fi 줄. `SerialNumber` 줄과 MAC이 든 줄(`mac=`, `MAC Address`, `macaddr`, `hwaddr`, `xx:xx:xx:xx:xx:xx`·`xx-xx-…`·구분자 없는 12자리 꼴)은 뺌(PR #66 리뷰 1·3). 12자리 꼴은 같은 길이의 다른 16진수·숫자가 든 줄도 빼지만, 공개 이슈에 올릴 기록이라 덜 남기는 쪽을 골랐습니다 |
    | `mount.txt` | 두 동글 드라이버 중 하나를 순정 `bcmdhd.ko` 자리에 bind mount하는 안([#80](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/80))을 가르는 값. SELinux 모드(`getenforce`, `/sys/fs/selinux/enforce`), init·이 설치기·`system_server`(Wi-Fi HAL이 insmod하는 곳)와 이름에 `hmgapi`가 든 프로세스 모두의 ppid·시작 시각(부팅 뒤 초, 순정 bcmdhd는 약 9.7초에 올라감)·mount 이름공간(`/proc/<pid>/ns/mnt`)·SELinux 도메인(`attr/current`). HMG-API 쪽은 데몬(comm `hmgapid`, ppid 1)에 "데몬"을 붙입니다. 부팅 서비스는 데몬이 띄우므로 데몬의 시작 시각을 봅니다. 요청 worker·클라이언트(`hmgapid`)와 차량 서비스(`hmgapi.vehicle`)도 함께 적힙니다. init과 mount 이름공간이 다른 프로세스 목록(앞 100줄), init·설치기·`system_server`·데몬의 `/`·`/system`·`/data` mountinfo 줄(전파 표시 `shared`·`master`), 커널 기록의 `avc:` 줄(앞 50줄, MAC 꼴은 뺌). 이름공간 링크가 있는데 대상을 못 읽으면(거절, 차의 툴박스 `ls`는 이때 아무것도 찍지 않음) "링크는 있음"으로, 링크가 없으면 `ls`의 오류 문구로 적어 둘을 가릅니다. busybox 없이 `/proc`와 커널 기록만 읽습니다. `wifi-strings.txt`도 HAL의 모듈 확인 문자열(`module_info`·`module_version`·`/proc/modules`)을 찾습니다 |

    md5·압축 풀기·문자열은 busybox로 합니다. busybox가 없으면 `config.gz` 복사와 목록만 남기고 그렇다고 적습니다. 고른 busybox에 `gunzip`·`sha256sum`·`strings`(또는 `grep -m`·`-E`)가 없으면 빈 값 대신 그 까닭을 적고(`config-sum.txt`, `ko-vermagic.txt`, `wifi-strings.txt`, PR #66 리뷰 2), `config.gz`는 PC에서 풉니다. `config-sum.txt` 첫 줄에 쓴 busybox를 적습니다. 동글을 꽂은 채 모으면 그 동글의 ID와 경로도 담깁니다.

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

이 모드의 훅은 한국 카플레이 길안내뿐이고(위 "[한국 카플레이 길안내](#한국-카플레이-길안내-hooks-67)"), Wi-Fi를 직접 쓰지 않습니다. 부딪히는 것은 공식 무선 모드와 HMG-API 프로젝션 AP 쪽이고, 이 모드는 관리 앱으로 알리기만 합니다.
- DiPO 안 계기판 호출 8곳(`change`)과 길안내 멈춤(`observe`). `mod.json` `hooks.points`에 선언해 HMG-API 계획(충돌 검사)에 보입니다.
- 순정 내비 안 단속 정보 프레임 두 메서드(`NavigationCluster.updateTBTTrapInfo`·`updateTBTTrapInfoNew`). map에 없는 메서드라 이름으로 걸고 선언하지 않아, **HMG-API 계획에 보이지 않습니다**(#96). 막대 칸(`barGraphLevel`)만 바꿉니다. 같은 메서드를 바꾸는 다른 모드(Korea Projection의 `TrapBar` 등)가 있으면 그 칸이 겹칩니다. 공식 무선 모드는 이 프레임을 건드리지 않습니다.

| 함께 있는 것 | 일어나는 일 | 관리 앱 판정 |
|---|---|---|
| NEMESIS 자체, NEMESIS로 설치한 무선·핫스팟 패키지(Korea Projection, 무선 패키지 등) | 2.1.2부터 USB 설치기는 NEMESIS가 깔린 차(`/system/xbin/nemesis`)에서 설치·업데이트를 하지 않고 멈춥니다([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75), 2026-11-26 사용자 결정. 관리 앱·훅은 그대로). 무선·핫스팟 패키지는 그 `hostapd`가 HMG-API 프로젝션 AP와 Wi-Fi를 다툽니다. 그중 Korea Projection(`/data/nemesis/apps/korea.projection`)이 있으면 USB 설치기가 설치·업데이트를 하지 않고 멈춥니다(위 "설치·업데이트 순서" 0, [#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13) 2026-11-24 사용자 결정). NEMESIS 실행 파일 없이 다른 NEMESIS 패키지 폴더만 남은 것과 지우기는 막지 않습니다 | 순정(netd)이 띄운 것이 아닌 `hostapd`가 돌고 연결이 없으면 `otherwifi`(그 패키지를 지우고 재부팅) |
| 공식 무선 모드와 같은 훅 지점에 `replace` 훅을 거는 다른 HMG-API 모드(한국 계기판 맞춤 등) | HMG-API는 모드를 id 순서(`requires`로 이어진 모드가 먼저, 그다음 id 이름순)로 올리고, 같은 지점을 `replace`하는 뒤쪽 모드의 훅을 통째로 끕니다(계획 `hooks <id> won't load: conflict: …`, HMG-API 로그 `mods: <id> not loaded: conflict: …`). `wireless-carplay-aa`보다 id가 앞인 모드와 겹치면 공식 모드가 꺼집니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)) | 공식 모드가 꺼진 쪽이면 `wmhooksoff`(HMG-API 앱의 Mods에서 겹치는 모드를 끔). 한국 맞춤은 이 저장소의 모드가 `change`·`observe`로만 겁니다(#67) |
| 공식 무선 모드를 꺼 두거나 지움 | 무선 카플레이·안드로이드 오토와 계기판 길안내가 없습니다. 이 모드는 `requires`로 걸지 않아 관리 앱은 그대로 열립니다 | `wirelessoff`, `nowireless` |
| HMG-API의 "집 Wi-Fi"(HMG-API 앱 설정 > Home Wi-Fi, 기본 꺼짐) | 차를 끈 지 30초 뒤나 주차하면 HMG-API가 프로젝션 AP를 끄고 내비의 Wi-Fi 클라이언트로 집 Wi-Fi에 붙고, 차가 켜지면 되돌립니다(rc.8 `engine/HomeWifi.java`). 둘 다 HMG-API가 하므로 2.0.x처럼 Wi-Fi 설정 잠금과 부딪히지 않습니다 | 클라이언트가 도는 동안 `wificlient` |
| NEMESIS 1.17(LivePatch) | NEMESIS가 `/system/bin/app_process`를 자기 스크립트로 바꾸고 `app_process.real`로 Android를 띄웁니다(부팅마다 다시 씀). HMG-API 1.1.0-rc.9부터 이것을 알아보고 래퍼를 `app_process.real`에 넣습니다. rc.8 이하는 이것을 모릅니다. 그래서 NEMESIS 1.17이 먼저 깔린 차에는 설치를 거절하고("isn't a known stock build"), 업데이트도 래퍼를 실제로 바꾸지 못하며, 지우면 재부팅 한두 번 뒤 Android가 뜨지 않습니다. 그 거절을 `FORCE`로 넘겨 설치한 차는 rc.9로 올리면 Android가 뜨지 않고, rc.10이 그런 차를 NEMESIS가 남긴 순정 파일로 다시 설치합니다([Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397), HMG-API 1.1.0-rc.10 릴리스 노트). 2.1.1부터 이 모드와 설치기의 최소 판을 rc.10으로 두어, 설치기가 낮은 HMG-API를 스틱의 rc.10으로 먼저 올립니다. 지우기 안내는 위 "지우기" | 관리 앱은 NEMESIS 판을 보지 않습니다. HMG-API가 rc.10보다 낮으면 `oldhmgapi` |
| 순정 일반 핫스팟을 켬(핫스팟 메뉴가 있는 차) | HMG-API 지기는 이미 떠 있는 AP를 그대로 둡니다. 일반 핫스팟 SSID로 떠 있으면 폰이 카플레이 Wi-Fi를 찾지 못할 수 있습니다 | `aphotspot`(순정 핫스팟을 끄고 재부팅) |

## 차에서 확인할 것

- **HMG-API가 NX4에서 map을 만들고(`map-car --write`) 확인(`verify-map`)을 통과하는지.** 실패하면 무선 기능을 적용하지 않습니다(`/data/local/tmp/nx4-kor/map-car.txt`, `verify-map.txt`). 2026-11-23 만들기, 11-25 확인 393/393으로 확인했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)).
- **공식 무선 모드(2.2.0-rc.9)의 훅 41개 지점이 NX4 map으로 켜지는지.** 하나라도 없으면 HMG-API가 그 모드의 훅을 끕니다(HMG-API 로그 `mods: wireless-carplay-aa not loaded: …`, 관리 앱 판정 `wmhooksoff`). 켜지면 `mods: loaded wireless-carplay-aa …`가 남고 관리 앱 상태표의 "공식 무선 모드"가 "…, 켜짐"입니다. 2026-11-25 2.1.0-beta.3에서 켜짐을 확인했습니다(`wm_hooks=on`, [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)).
- **공식 모드의 네이티브 레시피가 NX4 라이브러리에 맞는지**(`libCarPlayCore.so` 등). 맞지 않는 레시피는 아무것도 쓰지 않습니다. USB 진단 기록의 `system-lib-md5.txt`(순정 상태일 때)나 `hmgapi-status.txt`의 순정 md5로 레시피의 기대 md5와 견줍니다. 2026-11-25 진단 기록으로 견줘 5개 중 4개 라이브러리가 맞거나 고칠 것이 없었고, `libCarPlayAudio.so`만 판이 달라 무선 소리로 확인합니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)).
- **USB 진단 기록이 모이는지.** 2026-11-25 확인 창에서 [모으기]를 골라 `NX4/diag/20261125-173958`이 모였습니다(Car Report 포함, [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)). USB `NX4/install.log`로 보면 [모으기](17:39:58)부터 다 모일 때(17:40:30)까지 약 30초 걸렸습니다.
  - 진단 확인 창이 DSP OTA 화면 위에 뜨는지, [모으기]·[건너뛰기]가 눌리는지(`install.log`의 "진단 기록: …" 줄).
  - [모으기] 뒤 `NX4/diag/<시각>/`가 생기고 `system-lib-md5.txt`에 md5가 있는지(`info.txt`의 `md5_busybox`가 무엇인지).
  - `car-report.txt`가 HMG-API의 "usage:"가 아니라 보고서인지(`engine report`가 없는 HMG-API 판이면 빠짐).
  - 모으는 데 얼마나 걸리는지. Car Report는 map 만들기와 같은 분석이라 1~2분을 어림합니다.
  - `dongle/`에 차 커널 설정(`config.gz`·`config.txt`)이 있는지, `config.txt`가 드라이버 빌드의 커널 설정과 같은지(`sh drivers/config-sum.sh config.txt`가 "같음"), `wifi-strings.txt`에 HAL이 올리는 모듈 이름·insmod 인자가 보이는지. `mount.txt`에서 `system_server`의 mount 이름공간이 HMG-API 데몬과 같은지(다르면 mountinfo의 `shared`·`master`로 bind mount가 전해지는지), init과 이름공간이 다른 프로세스가 있는지, SELinux 모드와 데몬·`system_server`의 도메인, `avc:` 줄, HMG-API 데몬이 순정 bcmdhd(약 9.7초)보다 늦게 뜨는지([#80](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/80)). DSP OTA 프로세스에서 `/proc/config.gz`·`/sys`를 읽을 수 있는지도 여기서 드러납니다. 결과는 [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)에 적습니다.
  - `iap2/`에 순정 `libiap2session.so`와 `Iap2ServerApp.odex`(또는 apk)가 있는지, 라이브러리의 md5가 `system-lib-md5.txt`의 값과 같은지, `files.txt`에 다른 iAP2·CarPlay 파일이 보이는지. PC에서 CarPlay 연결 정보에 차선 안내 항목이 있는지 읽고, 결과는 [#90](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/90)에 적습니다.
- **카플레이 차선 안내가 계기판에 나오는지**([#90](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/90)). 2.1.2-beta.5에서 티맵은 폰 화면에 차선 안내가 나와도 계기판에는 한 번도 나오지 않았습니다. `kor_tbt_log`를 켜고 애플 지도로 차선 안내가 나오는 교차로를 지나며, HMG-API 앱 Logs 탭(Everything)에 `CarPlay diag: lane guidance index …` 줄과 `link`가 `-`가 아닌 `maneuver` 줄이 있는지 봅니다. 애플 지도도 오지 않으면 차 쪽(연결 정보) 문제로 봅니다.
- **DSP OTA 뒤 재부팅하지 않고 끝내도 되는지.** OTA 화면이 이상하게 남으면 관리 앱의 [지금 재부팅]이나 RESET을 쓰세요. 2026-11-25에 확인했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)).
- **DSP OTA 화면 위로 관리 앱이 열리는지**(`am start`). 안 열리면 재부팅 뒤 같은 USB로 Update OTA를 다시 누릅니다. 2026-11-25에 확인했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)).
- **HMG-API 설치기가 NX4의 `app_process`를 아는지.**
  - 하이브리드(NX4HEV) 260902는 확인했습니다. 2026-11-21에 `FORCE` 없이 설치됐고(`stock (Kia EV6 US 260507)`, md5 `33f79811…`, [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)), rc.10 `stock.txt`에도 같은 md5가 있습니다.
  - **가솔린·디젤 NX4(`NX4.KOR…260902`)는 아직 확인하지 않았습니다.** HMG-API rc.10 `stock.txt`는 HMC KOR 260902를 확인하지 않은 이미지로 적습니다. rc.10부터 `HMGAPI/FORCE`가 없어 모르는 판은 늘 거절합니다. 그런 차에서 `isn't a known stock build`가 나오면 그 줄로 HMG-API 이슈를 열어 판을 더해야 합니다. USB `HMGAPI/install.log`의 `app_process: stock (…)` 줄로 봅니다.
- **NEMESIS가 깔린 차에서 USB 설치가 실제로 멈추는지**([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75), 2.1.2부터). Update OTA를 누르면 토스트 "NEMESIS가 깔린 차에는 NX4 KOR를 설치하지 않습니다…"로 멈추고, 아무것도 바뀌지 않는지(HMG-API 설치·업데이트 없음, 진행 기록 없음) 봅니다. USB의 `NX4/install.log`에 `…/system/xbin/nemesis 있음: 설치하지 않음`이 남아야 합니다. DSP OTA 프로세스가 `/system/xbin/nemesis`를 보지 못하면 조용히 지나가 예전처럼 설치합니다. 테스트 차는 NEMESIS가 없어, NEMESIS 차를 가진 사용자의 기록으로 확인합니다.
- **Korea Projection이 설치된 차에서 USB 설치가 실제로 멈추는지**([#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13)). Update OTA를 누르면 토스트 "NEMESIS에 Korea Projection이 설치되어 있어 설치하지 않았습니다…"로 멈추고, 아무것도 바뀌지 않는지(HMG-API 설치·업데이트 없음, 진행 기록 없음) 봅니다. USB의 `NX4/install.log`에 `원본 Korea Projection 패키지가 있음(…)`이 남아야 합니다. 설치기가 그 폴더를 보지 못하면(경로가 다르거나 DSP OTA 프로세스에서 접근이 막힘) 조용히 지나가 예전처럼 설치합니다.
- **NEMESIS에서 Korea Projection을 지우고 재부팅하면 `/data/nemesis/apps/korea.projection` 폴더가 없어지는지**([#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13)). 지운 직후(재부팅 전)에도 없어지는지 함께 봅니다. USB 설치기는 그 폴더만 보고 멈추므로, 재부팅한 뒤에도 폴더가 남으면 계속 "NEMESIS에 Korea Projection이 설치되어 있어…"로 멈춥니다.
- **Wi-Fi 부품이 없는 차에서 관리 앱이 "부품 없음"을 보이고 HMG-API의 다시 시도가 멈추는지**(2026-11-23 NX4HEV 260902, 2.0.4-beta.1에서 순정 핫스팟 기능을 켜도 칩이 올라오지 않음, #38. 다시 시도 멈추기는 2.1.2-beta.4부터).
  - 재부팅 뒤 USB 진단 기록 `logs/service/nochip.log`에 "Wi-Fi 칩 없음(순정 드라이버가 이번 부팅에 칩 켜기를 포기함): HMG-API의 프로젝션 AP 다시 시도를 이번 부팅에 멈춤"이 남고, `logs/nx4-kor-nochip.txt`가 그 부팅 id인지. 상태 파일은 `nochip=yes`, `nochip_mark=yes`
  - 관리 앱 판정이 부팅 직후부터 `nowifipart`(노랑, "Wi-Fi 부품이 없는 것으로 보여…")인지(5분 동안 "켜는 중"이 나오지 않아야 함). 표의 "Wi-Fi 칩"이 "안 보임", "순정 핫스팟 기능"이 "예"인지
  - 다시 시도가 멈췄는지는 기록으로 직접 볼 수 없습니다. rc.10 지기는 `projection AP: not up yet, trying again (…)`을 부팅마다 처음 실패할 때 한 줄만 남기고 그 뒤 시도는 남기지 않습니다(고치기 전에도 한 줄, PR #86 리뷰 2). 그래서 `nochip.log`의 줄과 `nochip_mark=yes`, adb가 있으면 `/data/hmgapi/wifi/ap.boot`가 그 부팅 id인지로 봅니다(지기는 그 파일이 이번 부팅 것이면 시도하지 않음). 상태 파일의 `ap_boot`·`ap_fail`은 이때 `no`입니다
  - 차를 1분 넘게 껐다가 QuickBoot로 다시 켰을 때 `hmgapi-wifi.log`에 `back from a suspend`, `nochip.log`에 "HMG-API가 ap.boot를 지움(QuickBoot에서 깨어남): 다시 씀"이 한 줄씩 남는지
  - 유선 카플레이·안드로이드 오토와 계기판 길안내(공식 모드)가 그대로인지
  - 2026-11-25 2.1.0-beta.3과 11-26 2.1.2-beta.3에서는 부팅 뒤 5분 동안 `apwait`였다가 `nowifipart`로 바뀌었습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23), 11-26 진단 기록 `launch.log`). 결과와 유선 연결·계기판 길안내는 [#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64), 동글로 무선을 보는 일은 [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)에 적습니다.
- **함께 넣은 busybox가 NX4에서 도는지.** NX4 내비에 `/system/bin/busybox`가 없으면 관리 앱이 부르는 스크립트는 모드의 `bin/busybox`(`/data/hmgapi/mods/nx4-kor/bin/busybox`)만 쓸 수 있습니다. 관리 앱이 "이 내비에서는 동작하지 않습니다(busybox를 실행하지 못함)"를 보이지 않아야 합니다. 2026-11-25 진단 기록 `info.txt`가 `system_busybox: no`, `md5_busybox: /data/hmgapi/mods/nx4-kor/bin/busybox`였고(내비에 busybox가 없어 모드의 것을 씀), 관리 앱이 이 문구 없이 판정을 보여 확인한 것으로 봅니다.
- **HMG-API가 없는 차에서 릴리스 USB 하나로 설치되는지.** 첫 Update OTA에서 NX4 KOR 설치기가 스틱의 HMG-API 설치기(`NX4/hmgapi/troubleShooter`)로 넘겨 HMG-API가 설치되고 재부팅되는지, 두 번째 Update OTA에서 NX4 KOR가 설치되는지(USB의 `HMGAPI/install.log`, `NX4/install.log`). 2026-11-21에 확인했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)).
- **HMG-API가 이 모드의 최소 판(1.1.0-rc.10, 2.1.0은 rc.8)보다 낮은 차에서 HMG-API를 먼저 올리는지.** 첫 Update OTA가 따로 설치한 무선 모드(`wireless-carplay-aa`)를 지우지 않고 HMG-API 설치기의 업데이트 갈래로 HMG-API를 올린 뒤 재부팅하는지, 두 번째에 NX4 KOR가 설치되는지. HMG-API 설치기를 `/storage/upgrade`가 아니라 스틱의 `NX4/hmgapi`에서 `exec`로 돌리는 길은 차에서 처음 돕니다. NEMESIS로 설치한 HMG-API라면 NEMESIS 목록의 판도 함께 봅니다. 2026-11-25 rc.7에서 rc.8로 올리고 재부팅한 뒤 두 번째에 설치되는 것을 확인했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)).
  - 2.1.1: 2.1.0을 쓰던 차(rc.8)가 rc.10으로 올라가는지. rc.10은 HMG-API도 차에서 아직 확인하지 않은 판입니다(HMG-API 1.1.0-rc.10 릴리스 노트). 올린 뒤 관리 앱의 HMG-API 칸이 `1.1.0-rc.10`이고 훅이 켜지는지 봅니다.
  - NEMESIS 1.17 차라면 올린 뒤 재부팅을 두 번 해도 Android가 뜨는지, `/data/hmgapi/install.log`에 `app_process.real`이 적히는지도 봅니다(HMG-API 1.1.0-rc.10 릴리스 노트 "What to test").
- **USB 설치기가 HMG-API가 준비될 때까지 기다리는지**(PR #61). HMG-API를 올린 재부팅이 끝나자마자 바로 Update OTA를 누르면 "HMG-API가 준비되기를 기다리는 중" 토스트가 뜨고, 준비되면 이어서 설치하는지(최대 약 5분, USB `NX4/install.log`). 2026-11-25에는 재부팅 약 3분 뒤에 눌러 HMG-API가 이미 준비돼 있었고, 기다리는 갈래는 아직 보지 못했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)). 결과는 [#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64)에 적습니다.
- **칩이 있는 차(또는 동글 뒤)에서 HMG-API 프로젝션 AP를 관리 앱이 바르게 읽는지.**
  - 부팅 뒤 `wifi.log`에 `projection AP: up in mode 2 (requested by wireless-carplay-aa)`(또는 `already up`)가 남고, 관리 앱 판정이 `ready`, 표의 "무선 연결용 Wi-Fi"가 "켜짐"인지. 이 판정은 netd가 띄운 `hostapd` 설정의 `ssid=`가 softap.conf의 카플레이 SSID(S2)인지로 합니다(`svc/lib.sh` `ap_ssid`). 순정 일반 핫스팟 SSID(S1)면 `aphotspot`입니다.
  - 폰을 무선으로 붙이면 `connected`와 "카플레이 N대 연결됨"이 나오는지(로컬 포트 7000, Wi-Fi 쪽 주소)
  - 순정 무선 카플레이가 있는 트림에서도 같은지
  - 이 갈래들은 `tests/mod-test.sh`가 가짜 `ps`·`/proc`·softap.conf로 봅니다. 실제 `hostapd`의 부모·설정 경로·SSID가 그 꼴인지는 차에서만 확인됩니다.
- **HMG-API 부팅 보호의 기록이 rc.8 소스와 같은 꼴인지**([#18](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/18)). adb로 `dmesg`의 zygote 줄이 `hmgapi-hook: zygote, hooks on, start N (this boot M)`인지, `/data/hmgapi/hook/boot`가 `<boot_id> <횟수>`인지 봅니다. 관리 앱을 열 무렵 그 줄이 `dmesg`에 남아 있는지도 봅니다(없으면 관리 앱은 `hook/starts`·`hook/boot`로 판정합니다).
- **부팅 보호 때 관리 앱 "자세히" 표의 훅 줄(HMG-API 훅, 공식 무선 모드의 훅)이 무엇으로 보이는지.** 판정은 "훅 꺼짐(부팅 보호)"이지만, `status.sh`(`hmg_hooks_load`)는 이 줄들을 HMG-API 기록의 마지막 `hook map: …, hooks on|off`·`mods: loaded …` 줄에서 읽습니다. 부팅 보호로 꺼진 시작에는 이 줄을 쓰는 훅 런타임이 올라오지 않아 앞 시작의 "켜짐"이 남을 것으로 봅니다(rc.8 소스로 추론, `tests/emu/scen.sh` `bootguard`도 그렇게 넣음). 상태 파일의 `hooks`·`wm_hooks`·`kor_hooks`(함께 `ap`·`ap_boot`)를 적고, 엇갈림을 고칠지는 그 뒤에 정합니다. (HMG-API 훅이 꺼졌다는 `hook map:` 줄이 이번 부팅에 남으면 `wm_hooks`·`kor_hooks`는 빈 값이 되고 "한국 카플레이 길안내" 칸은 "안 돎"입니다. 부팅 보호는 그 줄도 남기지 않는 것으로 봐서 이 경우에 들지 않습니다, PR #83 리뷰 3)
- **HMG-API rc.8에서 이 모드의 `launch` 서비스가 도는지.** rc.5부터 `hmgapid`는 모드 서비스를 실효 그룹 2950(`MOD_GID`)과 `ANDROID_DNS_MODE=local`로 돌립니다. 관리 앱을 열면 상태 파일이 새로 쓰이고(화면 아래 "확인 …" 시각이 바뀜), [지금 재부팅]이 받아지면 확인한 것으로 봅니다. 2026-11-25에 확인했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)).
- **한국 카플레이 길안내가 도는지**([#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67), 위 "[한국 카플레이 길안내](#한국-카플레이-길안내-hooks-67)"). 결과는 #67에 적습니다. 확인할 때는 HMG-API 앱의 NX4 KOR 설정에서 `kor_tbt_log`를 켜고 다시 시작합니다(2.1.2-beta.2부터 기본 끔, #77. 곧 회전 판단과 보낸 값의 `CarPlay diag: …` 줄, HUD 목록 줄은 켜야 남음).
  - HMG-API 기록(Everything)에 `nx4-kor`의 `CarPlay (NX4 KOR): Iap2SvcInit(NX4KOR_RG, 0x1000) = true`, 길안내를 시작하면 `route guidance reaches this listener`가 남는지(리스너 둘이 함께 받는지). 공식 모드의 `CarPlay: hud list type …` 줄도 함께 늘어나는지
  - 2026-11-25 19:35처럼 공식 모드만으로 멈추던 곳에서 계기판이 0 m에 멈추지 않는지. 멈추면 그때의 `CarPlay: maneuver type … side … junction … exit …` 줄(이 모드의 기록)을 적습니다
  - 길안내 중 `guidance on: the official mod's cluster calls get ours`, 끝나면 `guidance off` 줄이 나오는지. 카플레이를 끊거나 길안내를 끝낸 뒤 2초쯤 안에 계기판의 화살표가 지워지는지
  - 길안내 앱을 바꾸거나(애플 지도 ↔ 네이버 지도) 애플 지도로 갈 때 계기판이 비었다 돌아오는 깜빡임이 없는지(남의 멈춤 2초 미루기)
  - `giving way until it hears again` 줄이 나오는지(나오면 이 모드의 리스너만 끊긴 것: 그 앞뒤 기록을 #67에)
  - 길안내를 시작하거나 앱을 바꾼 직후 계기판에 공식 모드의 그림(곧 회전 큰 그림 대신 작은 화살표 등)이 잠깐 나왔다 바뀌지 않는지(2.1.2-beta.4, 위 "공식 호출 잠깐 붙잡기"). `kor_tbt_log`를 켜면 `… from the official mod held N ms, carries ours`(붙잡아 우리 값을 실음)·`…, passed as it was`(기다렸지만 공식 값 그대로) 줄로 붙잡은 결과가 보입니다. `passed as it was`가 시작 때 자주 나오면 그 N과 앞뒤 기록을 #67에 적습니다(250·50ms가 짧은지 봄). 그래도 공식 그림이 몇 초씩 나오면 그때 `maneuver N unknown … asked again`·`giving way` 줄이 있는지 함께 #67에 적습니다
  - 차선 정보를 보내는 앱(애플 지도 등)으로 차선 안내가 나오는 교차로에서 차선 그림이 나오는지(카카오내비는 차선을 보내지 않음)
  - 일반 도로 곧 회전 거리 600 m(2.1.2-beta.4부터, 그 전은 350 m). `kor_tbt_log`를 켜면 `CarPlay diag: … d 600 -> near (in-d)`로 보입니다.
    - 떨어진 회전: 회전 약 600 m 전부터 큰 도로 그림과 거리 막대가 나오고, 막대가 60 m마다 한 칸씩 끝까지 자연스럽게 줄어드는지. 나갈 때는 650 m를 넘어야 먼 회전으로 돌아갑니다
    - **새로 생기는 동작:** 앞 회전을 지나자마자 다음 회전이 350~600 m 앞이면, 이제 바로 큰 그림(막대 90)으로 시작합니다(그 전에는 350 m까지 먼 회전 칸). 자연스러운지 봅니다
    - **전부터 있던 동작이 600 m까지 넓어짐:** 네이버 지도에서 두 곧 회전 사이에 미루기(`put-off`, 새 회전의 첫 거리를 앞 회전 값으로 보고 한 번 미룸)로 먼 회전 칸이 약 1초 끼는 일이, 전에는 다음 회전이 350 m 안일 때만이었고 이제 600 m 안이면 생깁니다. 자주 보이면 `CarPlay diag: … -> far (put-off)` 줄을 #67에 적습니다
    - 가까운 두 회전이 이어질 때 그림이 번갈아 바뀌지 않는지(위 네이버 지도의 약 1초 먼 회전 칸 말고)
    - 600 m 확인 결과(2.1.2-beta.5, 2026-11-27, #64): 600 m에서 바로 큰 그림, 앞 회전 직후에도 바로 큰 그림. 막대는 로그에서 60 m마다 한 칸씩 줄었지만 계기판 게이지는 늘 비어 있었습니다(아래 "곧 회전 게이지", #96). 회전이 바뀔 때 잠깐 깜빡임이 보여 아래 "먼 회전도 큰 그림"으로 이어졌습니다
  - **곧 회전 게이지**(#96, 위 "곧 회전 게이지"). 결과는 #96에 적습니다.
    - 곧 회전 큰 그림 옆 거리 게이지가 거리에 따라 차고 줄어드는지(600 m에서 가득, 60 m마다 한 칸). 먼 회전 큰 그림(#89)에서는 가득 찬 채인지
    - 길안내 중 단속 카메라·제한속도 표시가 그대로인지
    - 단속 카메라를 지나 경고가 사라진 뒤, 곧 회전 막대가 바뀔 때 그 카메라 경고·제한속도가 다시 뜨지 않는지(다시 보내기는 순정이 마지막으로 보낸 단속 정보 프레임을 막대만 바꿔 보냄, PR #98 리뷰 6)
    - 내비를 켠 직후 단속 카메라가 없는 길에서 카플레이 안내를 시작해도 게이지가 차는지. 순정 단속 정보 프레임을 한 번도 못 봤으면 보내지 않으므로, 비어 있으면 `first phone turn bar heard (…), stock trap frame seen: no` 줄이 있는지 봅니다(PR #98 리뷰 4)
    - 카플레이를 끊거나 안내를 끝내면 순정 막대로 돌아오는지. HMG-API 앱에서 NX4 KOR를 끄거나 `giving way` 줄이 나올 때도 돌아오는지
    - HMG-API 앱 Logs 탭에 `navigation (NX4 KOR): phone turn bar goes into the stock trap frame (N hooks)`가 나오는지(N이 0이면 이 차에 그 메서드가 없음)
  - **먼 회전도 큰 그림**(`kor_tbt_far_big` 켬, [#89](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/89)). 결과는 #89에 적습니다. 위 600 m 항목의 "먼 회전"·"먼 회전 칸"은 이 설정을 끈 때의 일입니다.
    - 600 m(고속도로 출구 1,050 m)보다 먼 회전에 네모 칸 아이콘 대신 큰 도로 그림이 나오는지. 그 그림에서 거리가 km 단위("2.4 km")로 맞게 보이는지. 진단 줄은 `-> near (far-big)`입니다
    - 막대가 가득 찬 채로 있다가 600 m부터 한 칸씩 줄어드는지
    - 회전이 바뀔 때 네모 칸 아이콘이 잠깐 끼던 깜빡임이 없어졌는지(`-> held (put-off)`, `-> near (stale-dist)` 줄). 그 순간 HUD 화살표가 약 1초 앞 회전으로 남는 것이 거슬리지 않는지
    - 먼 직진·길 따라가기(고속도로의 긴 구간 등)도 큰 직진 그림이 되는데, 그것이 자연스러운지
    - 먼 회전에서도 계기판에 회전 뒤 도로 이름이 나오는지, 맞는 이름인지
    - 회전교차로(32)·지하차도(46)·고가(44) 그림이 먼 거리에서도 맞게 나오는지
    - 목적지·경유지에서는 아이콘 그대로인지
    - 설정을 끄고 다시 시작하면 예전처럼 먼 회전 칸이 나오는지
  - KP 2.4.10에서 더해진 곧 회전 그림(2.1.2-beta.2부터): 회전교차로 앞에서 순정 회전교차로 큰 그림(32)이, 지하차도로 들어가는 회전에서 지하차도 그림(46)이, 왼쪽으로 올라가는 고가에서 고가 그림(44)이 나오는지. 각도를 주지 않는 앱(애플 지도·네이버 지도)에서 고속도로 진입로가 직진 대신 오른쪽 갈림 모양으로 나오는지. 다르게 나오면 그때의 `CarPlay: maneuver type …`·`CarPlay: near layout display …` 줄을 #67에 적습니다. 아래는 바뀌지 않는 것이 맞습니다:
    - 회전교차로에 들어갈 때(종류 6)나 폰이 출구 각도를 주지 않을 때: 출구 아이콘 그대로
    - 왼쪽 진입 램프: 오른쪽 갈림 모양(폰이 램프 쪽을 주지 않음)
    - 시설 이름에 "방면·옆길·측도·사거리·교차로·입구·앞" 같은 낱말이 붙었을 때(예: "해찬나래지하차도 방면")와 오른쪽 고가: 보통 회전 그림
  - HMG-API 앱에서 `kor_tbt`를 끄고 다시 시작하면 공식 모드 그대로 돌아가는지(`Korean turn-by-turn off` 줄). HMG-API 앱의 Mods에서 NX4 KOR를 재시작 없이 끄면 길안내 중 계기판이 공식 모드 것으로 바뀌고 두 값이 번갈아 나오지 않는지(`mod turned off` 줄). 다시 켜면 `mod turned on again: route guidance asked again` 뒤 한국 길안내로 돌아오는지(HUD가 1초 안팎 비는 것은 알려진 일)
  - 안드로이드 오토 계기판 길안내가 그대로인지(공식 모드가 함)
- **관리 앱 결과 화면이 차 화면 맨 위 시스템 줄의 `<`(뒤로)로 닫히는지**(2026-11-27 앱 안 `<`를 뺌, PR #88). 앱 안 닫기가 없어 결과 화면을 닫는 길은 이것뿐입니다. 안 닫혀도 홈·지도 키로는 벗어날 수 있습니다. 결과는 [#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64)에 적습니다.
- **관리 앱 모양이 차에서 맞게 보이는지**(#28 순정 5W 모양). 2026-11-25에 화면 크기·밀도(1920x720, 1.5)와 상태 줄이 앱 위를 덮지 않는 것을 확인했고, 나머지(순정 화면 비교, 확인 창 색, 주간·야간)는 확인하지 않기로 했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)).
  - 화면 아래 정보 줄의 화면 크기와 밀도. 크기는 화면 폭에 맞춰 늘이고 줄이므로 1920 폭이 아니면 글자가 함께 커지거나 작아집니다.
  - 시스템 상태 줄(시각 등)이 앱 위를 덮는지. 덮으면 제목이 가려지니 제목 줄 높이를 고칩니다(#28 "정할 것" 4).
  - 순정 설정 화면과 나란히 보고 색·글자 크기·줄 높이가 맞는지. 다르면 `Ui.java` 값을 고칩니다.
  - 재부팅 확인 창(Holo)의 모양, 버튼을 누를 때의 색, 주간·야간 밝기에서 띠와 시안 글자가 잘 보이는지.
- **앱 메뉴 타일과 앱 아이콘이 맞게 보이는지**([#47](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/47)). 2026-11-25 앱 메뉴에 NX4 KOR 타일이 보이는 것은 확인했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)). 아래 나머지를 보면 [#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64)에 적습니다.
  - 낮·밤 테마에서 NX4 KOR 타일이 순정 타일 사이에 어울리는지(크기, 위치, 그라데이션).
    - 크기가 순정과 다르면 화면 밀도도 함께 적습니다. HMG-API(rc.4 `HmgApi.icon()`)는 모드 그림을 밀도 보정 없이 99 px 그대로 쓰고, 순정 `hom_*_66`은 `drawable-hdpi` 자원이라 화면 밀도에 맞춰 바뀝니다. 그래서 밀도가 240이 아니면 크기가 다를 수 있습니다(코드를 읽고 추론).
  - HMG-API 앱에서 NX4 KOR를 껐을 때 타일이 회색(꺼짐) 그림으로 바뀌는지, 낮·밤 모두.
  - 설정 앱의 앱 목록에 NX4 KOR 앱 아이콘이 새 그림으로 보이는지.

확인하다 설치가 막히거나 관리 앱이 빨강·노랑이면 [`troubleshooting.md`](troubleshooting.md)를 봅니다.

정하지 않은 것은 [GitHub 이슈](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues?q=is%3Aissue+label%3A%22%EA%B2%B0%EC%A0%95+%ED%95%84%EC%9A%94%22)(라벨 `결정 필요`)에서 관리합니다. 차에서 확인한 결과는 그 항목을 맡은 이슈(무선·동글은 [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48), 그 밖은 [#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64))에 적습니다. 2.1.0의 첫 차 확인 기록은 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)(닫음)에 있습니다.
