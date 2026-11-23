# NX4 KOR 설계

## 2.1.0 새 구조(계획)

2026-11-23에 방향을 다시 정했습니다([#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38), 할 일 [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45), 마일스톤 [2.1.0](https://github.com/jay-park-lab/hmgapi-nx4-kor/milestone/1)). 2.1.0은 다음 셋으로 됩니다.
- HMG-API(1.1.0-rc.8 이상)
- 공식 무선 모드 `wireless-carplay-aa`(2.2.0-rc.9 이상, 고치지 않음, NX4에는 `--any-car`로 설치)
- 이 저장소의 NX4 추가분

| 일 | 맡는 곳 | 지금(2.0.x)에서 |
|---|---|---|
| 무선 카플레이·AA 훅, 계기판·HUD 길안내 | 공식 무선 모드. 한국 맞춤(`tbt_fit`, `aa_name_hold`, `star_popup_skip`, 한국어 UTF-8 AA 레시피)이 필요하면 공식 모드에 기여 | 한국 포크 2.4.5를 이 모드에 합쳐 씀(아래 "모드 구성") |
| 프로젝션 AP, 순정 핫스팟 기능 | HMG-API(`"wifi": {"projection": true}`) | `svc/hotspot.sh`가 순정 `hostapd`·`dnsmasq`로 직접 띄움 |
| HMG-API 설치·업데이트, 공식 모드 설치, NX4 map, 진단, 되돌리기(옛 NX4 KOR 2.0.x 정리 포함, 2.0.x는 `conflicts: ["wireless-carplay-aa"]`라 공식 모드와 함께 설 수 없음) | 이 저장소의 USB 설치기 | 설치기와 `setup_hmgapi` |
| 설치 진행·판정 화면 | 이 저장소의 상태 화면 앱(지금 UI 유지, 지우기 버튼 [#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)). 판정은 새 구조에 맞춤 | 같은 앱 |
| USB Wi-Fi 동글 | 이 저장소(나중에) | 없음 |

- 공식 모드가 `replace`하는 훅 지점은 이 저장소의 추가 모드가 다시 걸 수 없습니다. 같은 지점을 `replace`하는 모드 둘은 함께 켜지지 않습니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)).
- HMG-API는 모드를 지울 때 선언한 것(`patches.json`, `apps`, `services` 등)만 되돌리고, 지울 때 부르는 콜백이 없습니다(rc.8). 그래서 새 구조에서는 바꾸는 것을 선언으로 둡니다. 그래야 HMG-API 앱에서 지워도 남는 것이 없습니다.
- 판: 베타도 판에 꼬리를 붙입니다(`2.0.4-beta.1`부터, `docs/git-flow.md` 규칙 4). 2.0.x의 마지막 `release/2.0.4`는 `main`에 합치지 않고 지웁니다(끝 커밋은 `v2.0.4-beta.1` 태그가 남김).
- 이 문서의 아래 절은 지금 코드인 **2.0.x** 구조를 적은 것입니다. 2.1.0 코드가 들어오면 그 변경에서 고칩니다.

## 2.0.x 구조

NX4 KOR 2.0.x는 투싼 NX4(가솔린 `NX4`, 하이브리드 `NX4HEV`, 한국 내비 260902) 전용 HMG-API 모드 하나입니다. Korea Projection(StopDragon)의 핫스팟 서비스·상태 화면과, Korea Projection이 HMG-API에 따로 넣던 한국 차 빌드 무선 모드(`wireless-carplay-aa` 2.4.5)를 합쳤습니다.

> ⚠️ 차 확인은 일부만 됐습니다. 2026-11-23 NX4HEV 260902에서 2.0.2·2.0.4 베타로 다음이 동작했습니다([#23 기록](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23#issuecomment-7101713033)).
> - USB 설치·업데이트, map 만들기·확인(훅 지점 393/393), 자동 설정, 상태 화면과 [지금 재부팅], 진단
>
> 다만 자동 설정은 HMG-API rc.7 계획의 새 설명 줄(`home Wi-Fi  off`, `network  … [<mod>]`)을 `plan_nothing`이 변경으로 봐서, 다 적용된 뒤에도 부팅마다 Wi-Fi 깨우기 쪽으로 갑니다(2.1.0에서 고침, [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45)). 그 차는 Wi-Fi 부품이 없어 무선은 확인하지 못했습니다. 그 밖에는 PC 시험(`tests/mod-test.sh`)과 HMG-API 1.1.0-rc.4·rc.7 엔진(PC)에서만 확인했습니다. 아래 "차에서 확인할 것"을 먼저 봐 주세요.

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
   - **핫스팟 기능을 먼저 켜는 갈래(`hotspot_first`):** 칩이 안 보이고 순정 핫스팟 기능(`com.hkmc.software.wifihotspot`, `pm list features`)이 꺼져 있으면, 칩을 깨우거나 "부품 없음"으로 판정하지 않고 먼저 적용합니다.
     - 까닭: HMG-API는 한국 판처럼 이 기능이 꺼진 내비를 "칩에 전원이 안 들어감"(`SystemCheck`의 `unpowered`, Car Report `wifi: unpowered`)으로 봅니다.
     - 이 모드는 `mod.json`의 `"wifi": {"hotspot": true}`로 HMG-API에 이 기능을 켜 달라고 합니다(HMG-API rc.3부터, rc.7·rc.8 같음).
       - 순정 권한 파일이 있으면 HMG-API가 `featurexml.cfg`에서 그 파일을 지우는 줄을 막습니다.
       - 한국 판처럼 없으면 HMG-API가 자기 권한 파일을 이 모드 몫으로 넣습니다. 계획은 `change /system/etc/permissions/com.hkmc.software.wifihotspot.xml [nx4-kor]`이고 `mod-test.sh`의 엔진 시험이 봅니다.
       - 2.0.2까지는 `patches.json`의 줄 주석만 했는데, 순정 파일이 없는 한국 판에서는 기능이 켜지지 않았을 것입니다.
     - 2026-11-23 NX4HEV 260902(2.0.2): 기능이 꺼진 채 Wi-Fi를 깨우니 드라이버가 칩 전원을 넣지 못했고(`failed to power up DHD generic adapter`), 순정이 `module_version=3`을 남겼습니다. 그래서 2.0.2까지는 기능을 켜 보기도 전에 "부품 없음"으로 굳혔습니다.
     - **시험입니다. 칩이 살아날 가능성은 낮게 봅니다.**
       - Korea Projection 이슈 [#125](https://github.com/StopDragon/korea-projection/issues/125)를 보면, 같은 판(NX4HEV V039 260902, tcc803x)에서 무선이 되는 차도 순정 핫스팟 기능이 꺼져 있었습니다. 그 차는 Wi-Fi를 켜자 칩이 바로 보였습니다.
       - 같은 판에서 "부품 없음"인 차(2021년 7월 NX4HEV, 투싼 가솔린 여럿, #126)도 있습니다. 원본은 생산 시기·사양 차이로 보고, 1.8.0에서 USB Wi-Fi 동글을 시험 중입니다.
     - 적용하면 `$BK/wifi.hotspot`을 남기고 "Wi-Fi 칩 전원을 켜려고 순정 핫스팟 기능을 켰습니다. 내비를 3분 후 재부팅해 주세요"를 보입니다. 기능이 꺼진 채 지난 판이 남긴 부품 없음 기록(`wifi.nopart`)은 근거가 모자라 지웁니다.
     - 같은 때 모은 칩 근거도 켠 뒤의 판정에 쓰지 않습니다(`pre_hotspot_evidence`, PR #42 리뷰 5).
       - 순정 Wi-Fi 기록 `nochip-wifi.txt`(`$BK`와 `$W`)는 `nochip-wifi.pre-hotspot.txt`로 이름만 바꿔 진단용으로 남깁니다.
       - USB 진단 기록은 `$W`의 것만 `logs/`에 넣고 `$BK`(백업 폴더)는 넣지 않습니다. USB 업데이트는 `$W`를 지우므로(`preun.sh`), 2.0.2에서 올린 차처럼 `$BK` 사본만 남았으면 그것을 `$W`에도 둡니다. 다음 업데이트 전까지 진단 기록 `logs/nochip-wifi.pre-hotspot.txt`로 볼 수 있습니다(PR #42 리뷰 6).
       - 순정 `module_version` 기록(`$BK/wifi.modver`)은 지웁니다.
       - 그대로 두면 켠 뒤에 무슨 일이 있었든 세 번째 부팅 판정이 이 옛 근거로 `nowlanfail`이 됩니다.
     - 재부팅 뒤에는 부팅마다 `ap.log`에 "순정 핫스팟 기능을 켜 본 차: 지금 기능 켜짐|꺼짐, Wi-Fi 칩 보임|안보임"을 남깁니다. 칩이 보이면 핫스팟이 그대로 켜지고, 안 보이면 핫스팟 쪽의 Wi-Fi 장치 판정(`nowlan` 등)으로 갑니다.
     - **켜 본 뒤에도 칩이 없으면** 무선 기능은 적용된 채 남습니다. 예전에는 칩이 없는 차에 적용하지 않았으므로, 이 갈래에서 처음 생기는 상태입니다(PR #42 리뷰 2).
       - 적용돼 설정이 끝난 차(`setup_done`)가 되므로, 서비스가 부팅마다 핫스팟을 띄우려고 Wi-Fi를 한 번 켭니다(`take_wlan0`의 `svc wifi enable`). Wi-Fi를 켜면 USB·블루투스가 다시 시작돼 유선 카플레이가 잠깐 끊길 수 있습니다. 칩 깨우기(`wake_wifi`)는 이것을 몇 번으로 막아 두었지만, 여기서는 지울 때까지 부팅마다 합니다.
       - 상태 화면은 wlan0이 안 생기는 부팅을 셉니다. 두 부팅 동안은 "Wi-Fi를 켜는 중입니다… (확인 n/3)"(`wifioff`)이고, 세 번째 부팅부터 칩 실패 근거(커널의 `failed to power up DHD`, 순정 `module_version=3`)가 있으면 "이 차는 Wi-Fi 칩이 켜지지 않아…"(`nowlanfail`, 지우는 법)로 끝납니다. 근거가 없으면 "Wi-Fi 장치가 계속 켜지지 않습니다"(`nowlanrepeat`)에 머뭅니다. 그래서 최종 판정까지 재부팅을 세 번 합니다.
       - 이 근거는 켠 뒤의 기록에서 나옵니다. 부팅마다 wlan0이 없으면 `wlan_fail`이 순정 Wi-Fi 기록을 `$W/nowlan-wifi.txt`에 남기고, 그 안의 "판정 근거: 순정 module_version=…" 줄과 커널 줄을 `chip_fail_evidence`가 봅니다. 시험 결과도 이 파일(진단 기록 `logs/nowlan-wifi.txt`)로 봅니다.
       - 무선 iAP2 속성(`persist.sys.iap2.wifi=t`, `persist.iap2.iden.wireless=t`)과 무선 기능 파일이 Wi-Fi 없는 차에 켜진 채 남습니다. 유선 카플레이에 영향이 있는지는 차에서만 알 수 있습니다.
       - 그때는 USB `NX4/UNINSTALL`로 지웁니다. 부팅마다 Wi-Fi를 켜는 것을 코드로 줄일지는 차 결과를 보고 정합니다.
     - `"wifi": {"hotspot": true}`는 이 갈래만이 아니라 모드를 적용하는 모든 NX4에서 순정 핫스팟 기능을 켭니다. 칩이 있는 차에서는 순정 핫스팟 메뉴가 생기거나 순정이 AP를 띄울 수 있고, 그때 우리 핫스팟은 비켜 줍니다(`ap_yield`).
   - **부품 없음이 굳은 차(`nopart_final`):** 핫스팟 기능을 켜 본 뒤(`wifi.hotspot`)이거나 기능이 원래 켜져 있던 차의 `wifi.nopart`입니다. 서비스가 시작하자마자 그 판정을 진행 기록에 쓰고, 부팅마다 2분씩 "설치 중"을 다시 보이지 않습니다. "부품 없음" 알림도 처음 한 번만 씁니다.
5. 새 판으로 업데이트했는데 적용할 것이 없으면(훅 코드만 바뀜) 재부팅만 안내합니다.

핫스팟은 무선 기능이 적용된 뒤(`persist.sys.iap2.wifi=t`)에만 켭니다. 순정 무선 카플레이가 있는 트림은 순정 카플레이 AP를 그대로 씁니다.

## 상태 화면

- 앱이 열릴 때 `hmgapid service-start launch`를 부르고(hmgapid는 이 모드의 앱일 때만 받음), 상태 파일이 새로 쓰이면 다시 그립니다.
- 판정(`verdict`·`verdict_lv`·`verdict_msg`)은 `bin/status.sh`의 `st_verdict` 한 곳에서 정하고 앱은 그대로 보입니다.
- [지금 재부팅]은 앱 개인 폴더의 `reboot.req`를 `status.sh --watch`(화면을 연 뒤 10분)가 받습니다. 설치 중, 설치 마무리 중, `/system`을 바꾸는 작업 중, HMG-API 부팅 보호에 걸릴 때는 거절합니다.
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
    | `features.txt`, `permissions-ls.txt`, `featurexml-<onebin>.cfg` | 지금 켜진 순정 기능(`pm list features`), `/system/etc/permissions` 목록, 기능을 지우는 순정 설정 사본. Wi-Fi 칩 전원이 달린 순정 핫스팟 기능이 켜졌는지 봅니다(자동 설정 4의 "핫스팟 기능을 먼저 켜는 갈래") |
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
- **네이티브 레시피가 NX4 라이브러리에 맞는지**(`libCarPlayCore.so` 등). 맞지 않는 레시피는 아무것도 쓰지 않습니다. USB 진단 기록의 `system-lib-md5.txt`(순정 상태일 때)나 `hmgapi-status.txt`의 순정 md5로 레시피의 기대 md5와 견줍니다.
- **USB 진단 기록이 모이는지.**
  - 진단 확인 창이 DSP OTA 화면 위에 뜨는지, [모으기]·[건너뛰기]가 눌리는지(`install.log`의 "진단 기록: …" 줄).
  - [모으기] 뒤 `NX4/diag/<시각>/`가 생기고 `system-lib-md5.txt`에 md5가 있는지(`info.txt`의 `md5_busybox`가 무엇인지).
  - `car-report.txt`가 HMG-API의 "usage:"가 아니라 보고서인지(`engine report`가 없는 HMG-API 판이면 빠짐).
  - 모으는 데 얼마나 걸리는지. Car Report는 map 만들기와 같은 분석이라 1~2분을 어림합니다.
- **DSP OTA 뒤 재부팅하지 않고 끝내도 되는지.** OTA 화면이 이상하게 남으면 상태 화면의 [지금 재부팅]이나 RESET을 쓰세요.
- **DSP OTA 화면 위로 상태 화면이 열리는지**(`am start`). 안 열리면 재부팅 뒤 같은 USB로 Update OTA를 다시 누릅니다.
- HMG-API 설치기가 NX4의 `app_process`를 아는지(모르면 `HMGAPI/FORCE`).
- **순정 핫스팟 기능을 켜면 Wi-Fi 칩이 살아나는지.** 2.0.2에서 NX4HEV 260902는 칩이 안 보이고 순정 `module_version=3`이어서 "부품 없음"으로 끝났습니다. HMG-API는 같은 차를 `unpowered`(핫스팟 기능이 꺼져 칩에 전원이 안 들어감)로 봅니다.
  - 업데이트 뒤 첫 설정에서 "Wi-Fi 칩 전원을 켜려고 순정 핫스팟 기능을 켰습니다"가 나오고 재부팅을 안내하는지
  - 재부팅 뒤 `ap.log`의 "순정 핫스팟 기능을 켜 본 차: 지금 기능 …, Wi-Fi 칩 …" 줄. 기능이 "켜짐"인지(꺼짐이면 HMG-API가 켜지 못한 것: 진단 기록의 `featurexml-*.cfg`·`permissions-ls.txt`·`hmgapi-status.txt`를 봄), 칩이 "보임"인지
  - 칩이 보이면 핫스팟이 켜지고 폰이 붙는지. 안 보이면 진단 기록의 `logs/`(`nowlan-wifi.txt` 등)와 커널 줄(`failed to power up DHD`)이 그대로인지
  - 결과는 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에 적습니다. 칩이 끝내 없으면 무선 기능이 적용된 채 남으므로 NX4 KOR를 지웁니다.
  - 칩이 끝내 없을 때, 지우기 전까지 유선 카플레이·블루투스가 그대로인지 봅니다(부팅 직후 Wi-Fi를 켜면서 끊기는지 포함). 상태 화면이 "확인 1/3"·"2/3"을 거쳐 세 번째 부팅에 "칩이 켜지지 않아"로 끝나는지도 봅니다.
  - 칩이 있는 NX4에서는 순정 핫스팟 기능이 켜진 뒤에도 우리 핫스팟·무선 연결이 그대로인지 봅니다(순정 핫스팟 메뉴가 생기는지, 순정이 AP를 띄우는지).
- **함께 넣은 busybox가 NX4에서 도는지.** NX4 내비에 `/system/bin/busybox`가 없으면 모드의 `bin/busybox`(`/data/hmgapi/mods/nx4-kor/bin/busybox`)만 쓸 수 있습니다. `ap.log`에 "시작 안 함: busybox가 없음"이 없어야 하고, 상태 화면에 "쓸 수 있는 busybox가 없어" 알림이 없어야 합니다. 2.0.0-beta.4까지의 묶음에는 busybox가 없었습니다.
  - 함께 넣은 busybox를 쓰면 `hotspot.sh`가 K3·K8(tcc803x)용 갈래 두 개를 켭니다. 부팅마다 순정 카플레이 AP를 최대 90초 기다리고(`STOCK_GRACE`), 순정 AP 저장값 `wifi_ap_on`을 0으로 맞추지 않습니다(`apon_off`). NX4에서 처음 켜지는 것이라 함께 봅니다.
    - 부팅 뒤 `ap.log`의 "순정 카플레이 AP를 최대 90초 기다림(busybox 없는 내비)" 줄과 무선 연결까지 걸린 시간
    - `settings get global wifi_ap_on` 값, 순정 무선 카플레이가 있는 트림인지
    - 이 갈래를 NX4에 둘지는 [#37](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/37)에서 정합니다.
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
- **상태 화면 모양이 차에서 맞게 보이는지**(#28 순정 5W 모양). 결과는 [#28](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/28)과 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에 적습니다.
  - 화면 아래 정보 줄의 화면 크기와 밀도. 크기는 화면 폭에 맞춰 늘이고 줄이므로 1920 폭이 아니면 글자가 함께 커지거나 작아집니다.
  - 시스템 상태 줄(시각 등)이 앱 위를 덮는지. 결과 화면의 화면 안 닫기는 왼쪽 위 `<` 하나뿐이라, 덮으면 `<`가 가려집니다. 그때는 제목 줄 높이를 고칩니다(#28 "정할 것" 4).
  - 순정 설정 화면과 나란히 보고 색·글자 크기·줄 높이가 맞는지. 다르면 `Ui.java` 값을 고칩니다.
  - 재부팅 확인 창(Holo)의 모양, 버튼을 누를 때의 색, 주간·야간 밝기에서 띠와 시안 글자가 잘 보이는지.

확인하다 설치가 막히거나 상태 화면이 빨강·노랑이면 [`troubleshooting.md`](troubleshooting.md)를 봅니다.

정하지 않은 것은 [GitHub 이슈](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues?q=is%3Aissue+label%3A%22%EA%B2%B0%EC%A0%95+%ED%95%84%EC%9A%94%22)(라벨 `결정 필요`)에서 관리합니다. 차에서 확인한 결과는 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에 적습니다.
