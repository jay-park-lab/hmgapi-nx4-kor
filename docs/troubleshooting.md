# 차에서 설치하다 문제가 생길 때

USB로 설치하다 멈추거나, 설치 뒤 관리 앱이 빨강·노랑일 때 볼 문서입니다. 화면에 나오는 문구별로 할 일을 적고, 되돌리는 길을 가벼운 것부터 적었습니다.

> ⚠️ **아직 차에서 확인하지 않았습니다.** 아래는 다음 셋에서 모은 것입니다.
> - 이 저장소의 설치기(`usb/troubleShooter`)
> - 상태 판정(`mod/bin/status.sh`, 2.1.0: HMG-API + 공식 무선 모드 구조)과 지우기(`mod/bin/uninstall.sh`)
> - HMG-API 1.1.0-rc.7의 문서(`wiki/Troubleshooting.md`, `wiki/Uninstalling.md`)와 설치기(`install/common/install.sh`). NEMESIS 1.17에서 HMG-API를 지우거나 올리는 일은 HMG-API [1.1.0-rc.10 릴리스 노트](https://github.com/Open-HMG/HMG-API/releases/tag/v1.1.0-rc.10), [1.1.0-rc.9 릴리스 노트](https://github.com/Open-HMG/HMG-API/blob/v1.1.0-rc.9/.github/release-notes/v1.1.0-rc.9.md)(릴리스는 지워짐, 태그의 파일), [Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397)과 rc.10 설치기(`install/common/install.sh`)
>
> 차에서 다르게 동작하면 [GitHub 이슈](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues)에 적어 주세요(무선·동글은 [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)).

설치 순서는 [README](../README.md) "설치", 차에서 확인할 일은 [`design.md`](design.md) "차에서 확인할 것"에 있습니다.

## 먼저 지킬 것

- 시동을 건 채 차를 세워 두고 합니다.
- 설치 뒤 관리 앱이 "설정을 마쳤습니다"를 띄울 때까지(3~5분) **끄지 마세요.**
- **재부팅을 짧게 여러 번 이어서 하지 않습니다.** 켜진 지 2분이 안 돼 재부팅되는 일이 6번 이어지면 HMG-API가 훅을 끕니다(아래 "부팅 보호"). 관리 앱의 [지금 재부팅]은 그 횟수에 가까우면 스스로 막고, 설치기는 부팅 보호 확인이 끝난 뒤에 재부팅을 안내하므로, 재부팅하라는 안내가 나오면 바로 눌러도 됩니다.
- 끝나면 USB를 뺍니다. 꽂아 두면 유선 안드로이드 오토가 먼저 잡혀 무선이 붙지 않을 수 있습니다.
- Update OTA 뒤 OTA 화면에 나오는 **오류 684는 정상**입니다. 바꾼 것이 되돌려지지 않습니다.

## 무엇이 일어났는지 보는 곳

| 어디 | 무엇 | adb 필요 |
|---|---|---|
| USB `NX4/install.log` | NX4 KOR 설치기가 한 일. 누를 때마다 아래에 이어 씁니다(앞의 시도도 남음). 이번 시도는 **맨 아래**, 마지막 "NX4 KOR USB 설치기 시작" 줄부터입니다 | 아니오 |
| USB `HMGAPI/install.log` | HMG-API 설치기가 한 일 | 아니오 |
| USB `NX4/diag/<시각>/` | 누를 때 뜨는 확인 창에서 [모으기]를 고르면, 설치기가 아무것도 바꾸기 전에 모은 진단 기록. 아래 adb 줄의 기록(`logs/`), HMG-API Car Report와 상태, `/system/lib` 파일의 이름·md5, 내비 판, 동글 준비 정보(커널 설정·USB 장치, `dongle/`), 순정 iAP2 라이브러리·앱 사본과 관련 파일 목록(`iap2/`, 차선 안내 원인 [#90](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/90)) 등입니다. 담는 것은 [`design.md`](design.md) "진단 기록". 기록을 이슈에 올릴 때 `iap2/`는 순정 바이너리이므로 빼 주세요 | 아니오 |
| 관리 앱 화면 | 오른쪽 칸의 판정·안내와 왼쪽 칸의 요약·상태표. 사진으로 남겨 두면 좋습니다. 앱 메뉴의 NX4 KOR 타일로 엽니다. 타일이 없으면(HMG-API 훅이 꺼졌거나, HMG-API가 이 모드의 훅을 거절함) 같은 USB로 Update OTA를 다시 누릅니다(다시 설치하지 않고 관리 앱만 엶) | 아니오 |
| `/data/nx4-kor/logs/ap.log` | 관리 앱 감시자([지금 재부팅] 요청)의 기록 | 예 |
| `/data/hmgapi/logs/hmgapi/wifi.log` | HMG-API가 무선 연결용 Wi-Fi(프로젝션 AP)를 띄운 기록(`projection AP: …` 줄). 2.1.2-beta.4부터 USB 진단 기록의 `logs/hmgapi-wifi.log` | 예 |
| `/data/local/tmp/nx4-kor/` | map 만들기·확인·적용 출력(`map-car.txt`, `verify-map.txt`, `plan.txt`, `mod-apply.txt`) | 예 |
| HMG-API 앱의 Logs 탭, "Record a problem"(HMG-API rc.6부터) | HMG-API 쪽 기록 | 아니오. 다만 앱을 열 수 있어야 합니다(아래 "HMG-API 앱을 열 수 없을 때") |

## Update OTA를 누른 직후

"아무것도 바꾸지 않았습니다"가 붙은 메시지는 차를 그대로 두고 끝난 것입니다.

| 메시지 | 뜻 | 할 일 |
|---|---|---|
| USB에 NX4 폴더가 없습니다 | USB 맨 위에 풀지 않았음 | zip을 **USB 맨 위**에 풀었는지 봅니다. 폴더 안에 폴더가 또 생기면 안 됩니다. FAT32인지도 봅니다 |
| 확인 창 "진단 기록 모으기" | 정상 흐름. 관리 앱이 있으면 누를 때마다 아무것도 바꾸기 전에 묻습니다(HMG-API를 기다린 뒤. USB·NEMESIS·Korea Projection 확인에서 멈출 때는 멈추기 전에) | 기록이 필요하면 [모으기], 아니면 [건너뛰기]. 60초 안에 고르지 않으면 건너뜁니다. 어느 쪽이든 설치기는 이어집니다 |
| 진단 기록을 USB에 모으는 중입니다(1~2분). USB를 빼지 마세요 | [모으기]를 고름 | 다음 메시지가 나올 때까지 기다립니다 |
| HMG-API를 먼저 설치합니다 | 정상 흐름(HMG-API가 없는 차) | 재부팅을 기다렸다가, 부팅이 끝나면 바로 같은 USB로 **한 번 더** 누릅니다. 설치기가 HMG-API를 기다립니다(아래 줄) |
| HMG-API를 …에서 …(으)로 먼저 올립니다 | 정상 흐름(HMG-API가 1.1.0-rc.10보다 낮은 차(2.1.0을 쓰던 rc.8, rc.9 포함), 또는 USB의 모드가 더 높은 판을 요구). 아직 아무것도 바꾸지 않았습니다 | 위와 같이 한 번 더 누릅니다 |
| HMG-API가 준비되기를 기다리는 중입니다(최대 N분). USB를 빼지 마세요 | 정상 흐름. 부팅 직후라 HMG-API가 아직 답하지 않음. 답할 때까지 3초마다 다시 묻습니다(부팅 뒤 5분까지, 적어도 30초). USB 묶음이 잘못됐거나 NEMESIS·Korea Projection 패키지가 있으면 기다리지 않고 그 문구로 먼저 멈춥니다 | 다음 메시지가 나올 때까지 기다립니다 |
| 기다려도 HMG-API가 응답하지 않습니다 | 위처럼 기다렸는데도 HMG-API가 답하지 않음(멈췄거나 설치가 덜 됨). 아무것도 바꾸지 않았습니다 | 내비를 재부팅하고 부팅이 끝나면 다시 누릅니다. 같으면 USB의 `NX4/install.log`("HMG-API가 … 기다려도 응답하지 않음")와 HMG-API 설치 기록을 남깁니다 |
| HMG-API 시작 확인을 기다리는 중입니다(최대 N분). 아직 재부팅하지 마세요 | 정상 흐름. 설치는 끝났고, 이번 시작이 HMG-API 부팅 보호에 확인되기 전(켜진 지 2분 남짓 전)이라 재부팅 안내를 미룸. 지우기는 스스로 재부팅하기 전에 기다립니다 | 다음 메시지(재부팅 안내)가 나올 때까지 기다립니다. 그 전에 RESET으로 재부팅하지 마세요 |
| HMG-API …에는 설치할 수 없습니다. … 이상으로 먼저 올려 주세요 | HMG-API가 낮은데 USB에 그 판 이상의 HMG-API가 없음 | HMG-API가 든 2.1.1 이후 릴리스 USB 묶음(HMG-API 1.1.0-rc.10 포함)을 씁니다 |
| HMG-API가 없습니다. HMG-API USB 설치(HMGAPI 폴더)를 먼저 해 주세요 | HMG-API가 없는데 USB에 HMG-API가 없음 | 위와 같습니다 |
| USB에서 복사하지 못했습니다 / USB에 NX4/install(…)이 없습니다 / USB에 NX4/wireless(…)가 없습니다 | USB 읽기 문제나 파일 빠짐(2.0.x 묶음에는 `NX4/wireless`가 없음) | 2.1.0 이후 묶음인지 보고, USB를 다시 포맷해 zip을 다시 풉니다 |
| 이 USB의 NX4 KOR(…)는 옛 2.0.x 꼴(공식 무선 모드와 충돌)이라 이 설치기와 함께 쓸 수 없습니다 | 2.1.0 설치기에 2.0.x 모드가 든 묶음(직접 만든 묶음 등). 아무것도 바꾸지 않았습니다 | 2.1.0 이후의 릴리스 USB 묶음을 씁니다 |
| NEMESIS가 깔린 차에는 NX4 KOR를 설치하지 않습니다 | NEMESIS의 실행 파일(`/system/xbin/nemesis`)이 있음. 2.1.2부터 NEMESIS가 깔린 차에는 설치·업데이트(같은 판 다시 설치 포함)를 하지 않습니다([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)). HMG-API를 설치·업데이트하기 전에 멈춰 아무것도 바꾸지 않았습니다 | 쓰려면 NEMESIS를 지우고 내비를 재부팅한 뒤 다시 누릅니다. HMG-API가 있으면 지우지 말고 둔 채 NEMESIS를 지웁니다. 그 HMG-API가 1.1.0-rc.10보다 낮으면 NEMESIS를 지우기 전에 HMG-API 릴리스(NEMESIS Manager로 넣는 `hmgapi-<판>-nemesis.zip`, USB 묶음 `hmgapi-<판>-usb.zip`, update zip)로 rc.10 이상으로 올리고 두 번 재부팅합니다(`FORCE`로 설치한 NEMESIS 1.17 차는 반드시, [Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397)). 이 저장소의 USB는 쓰지 않습니다(2.1.1 이전은 NX4 KOR까지 설치함). Android가 뜨지 않는 차에서는 NEMESIS를 지우지 않습니다(아래 "HMG-API를 지운 뒤 Android가 뜨지 않을 때"). `UNINSTALL`은 막지 않습니다 |
| NEMESIS에 Korea Projection이 설치되어 있어 설치하지 않았습니다 | NEMESIS의 Korea Projection 패키지(`/data/nemesis/apps/korea.projection`)가 있음. 그 패키지의 `hostapd`가 HMG-API 프로젝션 AP와 Wi-Fi를 다툽니다. HMG-API를 설치·업데이트하기 전에 멈춰 아무것도 바꾸지 않았습니다 | NEMESIS에서 Korea Projection을 지우고 내비를 재부팅한 뒤 다시 누릅니다. 재부팅 전에는 그 패키지 폴더나 Wi-Fi가 남아 있을 수 있습니다. 다른 NEMESIS 패키지와 `UNINSTALL`은 막지 않습니다([#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13)) |
| HMG-API가 변경 사항 계획을 내지 못했습니다(끝나지 않은 적용 등) | `engine plan`이 계획을 내지 못함(끝나지 않은 적용·trial 등). 아무것도 바꾸지 않았습니다 | 내비를 재부팅하고 3분 넘게 기다린 뒤 다시 누릅니다. 같으면 `install.log`의 `--- engine plan (pre, 종료 코드 …)` 아래 줄을 남겨 알려 주세요 |
| HMG-API에 다른 모드의 적용하지 않은 변경이 있습니다. HMG-API 앱에서 먼저 적용한 뒤 다시 해 주세요 | 시작 전 계획에 다른 모드의 변경이나, 앞서 지우고 적용하지 않은 모드의 되돌리기(`restore` 등)가 있음. 끝에서 적용할 수 없어 아무것도 바꾸지 않았습니다 | HMG-API 앱에서 변경 사항을 적용하고 재부팅한 뒤 다시 누릅니다. 앱을 열 수 없으면 아래 "HMG-API 앱을 열 수 없을 때" |
| 옛 NX4 KOR(…)를 먼저 되돌리는 중 | 정상 흐름(2.0.x가 있는 차). 공식 무선 모드와 함께 쓸 수 없어 먼저 끝까지 되돌립니다 | 기다립니다 |
| 옛 NX4 KOR 2.0.x가 남긴 설정(Wi-Fi 잠금 등)을 되돌리는 중 | 정상 흐름(2.0.x를 HMG-API 앱에서 먼저 지운 차, 또는 2.0.x 위에 2.1.0 이후를 넣은 차. `/data/nx4-kor/backup`이 남음). USB의 `NX4/legacy-2.0`으로 되돌립니다. 2.1.0 이후가 있으면 HMG-API에서 뺀 뒤 다시 설치합니다 | 기다립니다 |
| 옛 NX4 KOR 2.0.x가 남긴 설정(Wi-Fi 잠금 등)이 있어 이 USB로는 되돌릴 수 없습니다 | 위와 같은 차(2.0.x를 앱에서 지운 차, 2.0.x 위에 2.1.0 이후를 넣은 차)인데 USB에 `NX4/legacy-2.0`이 없음(직접 만든 묶음 등). 아무것도 바꾸지 않았습니다. `UNINSTALL`이면 nx4-kor는 지우고 기록만 남겼다고 알립니다 | 릴리스 USB 묶음을 쓰거나, 2.0.x 릴리스 USB(`v2.0.4-beta.1`)의 `NX4/UNINSTALL`로 되돌리고 재부팅한 뒤 다시 누릅니다 |
| 옛 NX4 KOR를 되돌리지 못해 새로 설치하지 않았습니다 | 2.0.x를 HMG-API에서 빼거나 그 되돌리기를 하지 못함 | `install.log` 맨 아래를 봅니다. 아래 "되돌리기" 1단계(`UNINSTALL`)를 먼저 해 봅니다 |
| 공식 무선 모드(wireless-carplay-aa)를 설치하지 못했습니다 | HMG-API 엔진이 공식 무선 모드를 거절함 | `install.log` 맨 아래의 `refused:` 줄을 봅니다. 차주가 따로 넣은 다른 빌드(작성자 키가 다름)면 HMG-API 앱에서 그 모드를 지운 뒤 다시 누릅니다 |
| NX4 KOR 설치에 실패했습니다 | HMG-API 엔진이 NX4 KOR를 거절함 | `install.log` 맨 아래(마지막 "NX4 KOR USB 설치기 시작" 줄 뒤)의 `refused:` 줄을 봅니다. 위쪽은 앞의 시도입니다. 업데이트 중이었다면 예전 판의 서비스는 다시 띄워 둡니다 |
| 설치를 마쳤습니다. 관리 앱의 [지금 재부팅]이나 RESET으로 내비를 재부팅해 주세요 | 정상 흐름 | 관리 앱의 [지금 재부팅]을 누르거나 RESET으로 재부팅합니다 |
| 이미 설치되어 있고 설정이 끝나 있습니다 | 같은 판이 있고 map 확인·적용할 것도 없음 | 관리 앱만 봅니다. 같은 판을 다시 설치하려면 `NX4` 폴더에 빈 파일 `REINSTALL`을 만듭니다 |

HMG-API 설치기가 멈추면 USB의 `HMGAPI/install.log` 맨 아래 `FAIL:` 줄을 봅니다. 모두 아무것도 바꾸지 않고 멈춘 것입니다(HMG-API 1.1.0-rc.10 `install/common/install.sh`).

| `FAIL:` 줄 | 뜻 | 할 일 |
|---|---|---|
| `… isn't a known stock build, so nothing was changed. HMG-API only takes app_process builds it has checked …` | HMG-API가 이 차의 소프트웨어 판(`app_process`)을 아직 확인하지 않음. 1.1.0-rc.10부터는 `HMGAPI/FORCE`로 넘길 수 없습니다. 투싼 하이브리드(NX4HEV) 260902의 순정 `app_process`는 HMG-API가 아는 판입니다(2026-11-21 차에서 `FORCE` 없이 설치, [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)). 가솔린·디젤 NX4는 아직 모릅니다(HMG-API rc.10 `stock.txt`는 HMC KOR 260902를 확인하지 않은 이미지로 적음). 그런 차에서 나와도 차가 순정이 아니라는 뜻은 아닙니다 | [HMG-API 이슈](https://github.com/Open-HMG/HMG-API/issues/new/choose)에 그 줄과 차, 내비 소프트웨어 판을 올립니다. HMG-API가 그 판을 더한 뒤 다시 설치합니다 |
| `… is HMG-API's wrapper but its stock copy (app_process.hmgapi-stock) is gone, and there's no stock backup …` | 예전 HMG-API 삭제가 NEMESIS 1.17 차에 남긴 래퍼인데, 되돌릴 순정 백업도 없음(`UNINSTALL-PURGE`로 지움). 다음 재부팅부터 Android가 뜨지 않습니다 | **재부팅하지 말고** 아래 "HMG-API를 지운 뒤 Android가 뜨지 않을 때"와 [Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397)을 봅니다 |
| `… the stock copy HMG-API's wrapper runs, is itself an HMG-API wrapper …`, `… is NEMESIS LivePatch's script (an older release installed with FORCE), and … isn't a stock binary either …` | 예전 `FORCE` 설치가 래퍼나 NEMESIS 스크립트를 "순정" 사본으로 저장했고, 차에 순정 파일이 남지 않음 | 위와 같습니다 |

- 2.1.0 묶음(HMG-API rc.8)은 NEMESIS 1.17(LivePatch)의 `app_process` 스크립트를 몰라 `isn't a known stock build`로 거절했습니다. 이 문서는 그때 `FORCE`를 쓰라고 안내했습니다.
- 그렇게 설치한 NEMESIS 1.17 차는 **1.1.0-rc.9로 올리면 Android가 뜨지 않습니다**(rc.9가 마지막 순정 파일을 덮어씀).
- HMG-API rc.10은 NEMESIS가 남긴 순정 파일(`app_process.real`)로 새로 설치해 고칩니다(HMG-API 1.1.0-rc.10 릴리스 노트). 따로 받은 rc.9를 쓰지 않습니다. 2.1.2 이후 이 저장소의 묶음은 NEMESIS가 깔린 차에서 멈추므로([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)), HMG-API 릴리스의 USB(`hmgapi-<판>-usb.zip`, rc.10 이상), NEMESIS Manager용 `hmgapi-<판>-nemesis.zip`이나 update zip으로 올립니다. 2.1.1 이전 묶음은 HMG-API를 올린 뒤 NX4 KOR까지 설치하므로 NEMESIS가 깔린 차에는 쓰지 않습니다.

## 설치 뒤 관리 앱이 빨강·노랑일 때

판정 코드는 관리 앱 화면 왼쪽 표의 맨 아래 "판정 코드" 줄에 있습니다. 판정 차례와 보는 것은 [`design.md`](design.md) "관리 앱".

| 판정(문구 요지) | 할 일 |
|---|---|
| 설치 중입니다 (`installing`) | 기다립니다 |
| [지금 재부팅]을 눌러 내비를 재부팅해 주세요 (`reboot`) / 무선 카플레이 기능이 아직 켜지지 않았습니다 (`nofeat`) / HMG-API가 무선 연결용 Wi-Fi를 띄우도록 설정되지 않았습니다 (`noproj`) | [지금 재부팅]을 누릅니다. 재부팅 뒤에도 `nofeat`·`noproj`면 HMG-API 앱에서 변경 사항을 적용했는지 봅니다(아래 "HMG-API 앱을 열 수 없을 때") |
| 설치기가 남긴 실패 문장 (`failed`) | 그 문장대로 합니다. 문장별 할 일은 위 "Update OTA를 누른 직후" 표와 아래 세 줄에 있고, USB의 `NX4/install.log`에 자세한 까닭이 있습니다 |
| HMG-API가 이 차의 map을 만들지 못해… (`failed`) | 같은 USB로 Update OTA를 다시 누르면 다시 만듭니다. `install.log`의 `--- engine map-car --write` 아래 출력을 봅니다 |
| **이 차의 map을 확인하지 못해 무선 기능을 적용하지 않았습니다** (`failed`) | 이번에 만든 map은 지웠으니 다시 누르면 새로 만들어 확인합니다. 이미 있던 map은 지우지 않으므로 같은 결과가 납니다. `install.log`의 `--- engine verify-map` 아래 `FAILED` 줄을 남겨 알려 주세요 |
| HMG-API에 다른 모드의 바뀐 내용이 함께 있어… / HMG-API 계획에 켜지지 않는 훅이나 문제가 있어… / 무선 기능 적용에 실패했습니다 (`failed`) | 아래 "HMG-API 앱을 열 수 없을 때" |
| 공식 무선 모드(Wireless CarPlay + Android Auto)가 설치되어 있지 않습니다 (`nowireless`) / 공식 무선 모드 버전을 지원하지 않습니다 (`oldwireless`) | NX4 KOR USB 설치기로 다시 설치합니다(공식 모드를 넣음) |
| HMG-API 앱에서 Wireless CarPlay + Android Auto가 꺼져 있습니다 (`wirelessoff`) / 'Wireless CarPlay'가 꺼져 있습니다 (`bridgeoff`) | HMG-API 앱에서 켜고 적용한 뒤 재부팅합니다(아래 "HMG-API 앱을 열 수 없을 때") |
| HMG-API 훅이 꺼져 있습니다 (`hooksoff`) | 문구대로 합니다. map이 없으면(`none`) USB 설치기를 다시 실행하고, 그래도 같으면 USB 진단 기록을 남겨 알려 주세요 |
| Wireless CarPlay + Android Auto가 다른 모드와 같은 훅을 써서 꺼졌습니다 / 그 훅을 켜지 못했습니다 (`wmhooksoff`) | 다른 모드와 겹치면 HMG-API 앱의 Mods에서 겹치는 모드를 끕니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)). 아니면 재부팅하고, 같으면 Mods에서 이유를 봅니다. 이 차의 map에 공식 모드의 훅 지점이 없을 수 있습니다 |
| "자세히" 표 "한국 카플레이 길안내": 훅이 안 켜짐 (공식 모드 길안내로 동작: <이유>) | 판정은 그대로이고 공식 모드의 카플레이 길안내가 돕니다(#67의 0 m 멈춤 보정만 빠짐). 이때 앱 메뉴의 NX4 KOR 타일도 없으니 같은 USB로 Update OTA를 다시 눌러 관리 앱을 엽니다. 이유가 지점 문제면(이 차의 map에 그 지점이 없음 `hook point … isn't mapped on this car`, 이 차에서만 찾은 지점이라 `change` 훅을 걸 수 없음 `… is mapped on this car only …`, HMG-API가 모르는 지점 `… isn't one HMG-API has …`) USB 진단 기록을 남겨 [#71](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/71)에 알려 주세요. 다른 모드와 겹친다는 이유(`conflict`)면 HMG-API 앱의 Mods에서 그 모드를 끕니다. "꺼 둠 (설정…)"은 HMG-API 앱의 NX4 KOR 설정 `kor_tbt`를 끈 것입니다(바꾼 뒤 다시 시작해야 적용). "안 돎 (HMG-API 훅 꺼짐)"은 위 HMG-API 훅 줄을 따릅니다. "켜짐"인데 계기판에 한국 길안내가 안 보이면 HMG-API 앱 Logs 탭에서 `CarPlay (NX4 KOR): … stays off`·`didn't start` 줄을 봅니다 |
| HMG-API가 이번 부팅에만 무선 기능을 껐습니다(부팅 보호). … 또 생기면 마지막으로 넣거나 바꾼 모드를 HMG-API 앱에서 꺼 주세요 (`bootguard`, 노랑) | 내비를 재부팅하고 3분 넘게 켜 둡니다. 또 노랑이 나오면 마지막으로 넣거나 바꾼 모드를 HMG-API 앱에서 끕니다. 훅이 꺼진 동안에는 HMG-API 앱 타일이 없으니 아래 "HMG-API 앱을 열 수 없을 때"의 길로 엽니다. 아래 "부팅 보호" |
| **HMG-API가 재부팅이 너무 잦은 것으로 보고 무선 기능을 껐습니다** (`bootguard`, 빨강) | 아래 "부팅 보호"대로 HMG-API를 다시 설치합니다 |
| 다른 Wi-Fi 패키지가 Wi-Fi를 쓰고 있어… (`otherwifi`) | NEMESIS의 Korea Projection이나 다른 무선·핫스팟 패키지를 지우고 재부팅합니다([`design.md`](design.md) "다른 패키지·모드와 함께 쓸 때") |
| 내비 Wi-Fi가 일반 핫스팟으로 켜져 있어… (`aphotspot`) | 순정 핫스팟을 끄고 재부팅합니다 |
| 내비가 일반 Wi-Fi에 접속하는 중이라… (`wificlient`) | HMG-API 앱의 Home Wi-Fi를 쓰면 주차를 풀 때 돌아옵니다. 계속 그렇다면 Home Wi-Fi를 끕니다 |
| 이 차의 내비에는 Wi-Fi 부품이 없는 것으로 보여… (`nowifipart`) | 이 차에서는 무선을 쓸 수 없습니다. 유선 카플레이·안드로이드 오토와 계기판 길안내는 그대로입니다. 2.1.2-beta.4부터는 순정 드라이버가 이번 부팅에 칩 켜기를 포기한 것을 보고 부팅 직후부터 이렇게 나오고, 이 모드의 `nochip` 서비스가 HMG-API의 Wi-Fi 다시 시도(30초마다)를 그 부팅 동안 멈춥니다(USB 진단 기록 `logs/service/nochip.log`). 무선은 USB Wi-Fi 동글([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48), 2.2.0)로 합니다. 동글을 꽂은 채 시동을 켜거나, 부팅 뒤 꽂았으면 관리 앱 [동글 켜기]를 누릅니다(동글이 켜지면 이 판정이 사라짐). 결과를 [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)에 적어 주세요 |
| HMG-API가 무선 연결용 Wi-Fi를 켜는 중입니다 (`apwait`) | 1~2분 뒤 화면을 다시 엽니다. 켜는 것은 이 모드가 아니라 HMG-API이고, 관리 앱은 부팅 뒤 5분까지 기다립니다. Wi-Fi 부품이 없는 차는 2.1.2-beta.4부터 바로 "부품 없음"이 나오고, 커널 기록이 밀려나 그것을 못 본 때만 5분 동안 이렇게 나옵니다 |
| 무선 연결용 Wi-Fi가 지금 꺼져 있습니다 (`apoff`) / HMG-API가 무선 연결용 Wi-Fi를 켜지 못했습니다·켜지 않았습니다 (`apfail`) | 폰을 연결해 보고, 안 되면 재부팅합니다. 같으면 adb로 `/data/hmgapi/logs/hmgapi/wifi.log`를 봅니다 |
| 지원하지 않는 HMG-API 버전입니다 (`oldhmgapi`) / HMG-API가 없습니다 (`nohmgapi`) | HMG-API(1.1.0-rc.10 이상)가 든 2.1.1 이후 릴리스 USB로 다시 누릅니다. 2.1.0을 쓰던 차(HMG-API rc.8)나 따로 rc.9를 넣은 차도 같은 방법으로 올립니다. NEMESIS가 깔린 차는 이 저장소의 USB 대신 HMG-API 릴리스(NEMESIS Manager용 `hmgapi-<판>-nemesis.zip`, USB 묶음, update zip)로 올립니다([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75): 2.1.2 이후 USB는 멈추고 2.1.1 USB는 NX4 KOR까지 설치함) |
| 연결됨·준비됨(시안 글자)인데 폰이 붙지 않음 | USB를 뺐는지 봅니다. 폰의 Wi-Fi 설정에서 차 네트워크를 지우고 다시 연결해 봅니다 |

### HMG-API 앱을 열 수 없을 때

몇몇 안내는 "HMG-API 앱에서 …"라고 합니다. 그런데 HMG-API 앱 타일은 HMG-API 훅이 켜진 뒤에야 생기고, 훅은 이 차의 map이 확인된 뒤에 켜집니다. 그래서 처음 설치할 때는 **HMG-API 앱을 열 수 없습니다.** NEMESIS(My Packages → HMG-API → Launch)나 adb가 있어야 엽니다.

그때 현실적인 길은 NX4 KOR를 지우고(아래 "되돌리기" 1단계) 재부팅한 뒤, 같은 USB로 다시 설치하는 것입니다. 2.1.0 설치기는 map을 확인한 뒤, 계획이 NX4 KOR와 공식 무선 모드의 것뿐이면 직접 적용합니다. 다른 모드의 변경이 남아 있으면 그 모드를 HMG-API에서 지우거나 적용해야 하므로 HMG-API 앱이 필요합니다.

### 부팅 보호

HMG-API는 훅 때문에 내비가 제대로 뜨지 못한다고 보면 스스로 훅을 끄고 정상으로 띄웁니다(HMG-API rc.6부터의 기준). 다음 둘 중 하나일 때입니다.
- 한 번의 부팅 안에서 Android가 3번 못 뜸(`hook/boot`의 이번 부팅 횟수)
- 켠 지 2분 안에 꺼지기(재부팅·시동 끄기 포함)가 6번 이어짐(`hook/starts`)

훅이 꺼지면 무선 기능도 꺼집니다. 재부팅은 새 부팅이라 "한 번의 부팅 안" 횟수는 0부터 다시 셉니다. 그래서 관리 앱은 다음 재부팅에 훅이 다시 켜지는지에 따라 둘로 알립니다.
- 노랑 "이번 부팅에만 무선 기능을 껐습니다": `hook/starts`가 6보다 작아 재부팅만으로 다시 켜집니다. 아래 1을 한 뒤 3만 합니다. 한 부팅 안에서 3번 못 뜬 것은 훅이나 모드가 일으킨 것일 수 있어, 원인이 그대로면 재부팅 뒤 되풀이되다 빨강이 됩니다. 그래서 화면은 "또 생기면 마지막으로 넣거나 바꾼 모드를 HMG-API 앱에서 꺼 주세요."를 덧붙입니다. 훅이 꺼진 동안에는 HMG-API 앱 타일이 없으므로, 위 "HMG-API 앱을 열 수 없을 때"의 길(NEMESIS Launch나 adb)로 열어 끕니다. 그 길이 없으면 아래 "되돌리기"대로 그 모드를 지웁니다(NX4 KOR라면 USB `UNINSTALL`).
- 빨강 "재부팅이 너무 잦은 것으로 보고 …": 다음 부팅도 꺼집니다. 아래 1~3을 모두 합니다.

다시 켜려면:

1. 마지막으로 바꾼 것이 원인이면 먼저 되돌립니다(예: NX4 KOR를 지움).
2. **HMG-API를 지우지 말고 다시 설치(업데이트)합니다.** HMG-API 설치기는 설치할 때 이 횟수를 지웁니다(`hook/starts`를 0으로, `hook/boot` 삭제).
   - 이 저장소의 릴리스 USB는 HMG-API가 없거나 낮을 때만 HMG-API 설치기를 돌립니다. 그래서 여기서는 HMG-API 릴리스의 `hmgapi-<판>-usb.zip`을 따로 풀어 Update OTA를 누릅니다.
3. 재부팅하고 3분 넘게 켜 둡니다.

관리 앱의 [지금 재부팅]도 이 횟수를 봅니다. `hook/starts`가 5·6이면(2분을 버티지 못한 시작이 이번 것까지 5·6번 이어짐) 다음이나 그다음 시작에 훅이 꺼지므로, 이번 시작이 2분을 넘길 때까지(켠 지 3~5분) 재부팅을 거절하고 "… 3~5분 뒤에 다시 눌러 주세요."를 보입니다.

## 카플레이 계기판 길안내가 이상할 때

한국 카플레이 길안내([#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67), HMG-API 앱의 NX4 KOR 설정 `kor_tbt`)가 공식 무선 모드의 계기판·HUD 길안내를 덮어씁니다.

1. 이상하게 보인 시각을 적고, 그때 폰 화면의 안내(예: "차선 유지", "약간 좌회전")를 함께 남깁니다.
2. HMG-API 앱 Logs 탭(Everything)에서 그 시각 앞뒤의 `nx4-kor` 줄을 봅니다. `CarPlay: maneuver type … side … junction … exit …`가 받은 안내입니다(길·장소 이름은 남지 않음). 설정 `kor_tbt_log`가 켜져 있으면 곧 회전 판단, 계기판에 보낸 값, 보낸 HUD 목록(`CarPlay: hud list …`) 줄이 더 있습니다. 2.1.2-beta.2부터 기본으로 꺼져 있으니, 기록이 필요하면 HMG-API 앱의 NX4 KOR 설정에서 켜고 다시 시작합니다([#77](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/77)). 같은 시각의 `wireless-carplay-aa` 줄은 공식 모드의 것입니다. 공식 모드의 `CarPlay: hud list type …` 줄은 그 모드가 계산한 값이고, 이 모드가 길안내를 하는 동안(`guidance on` 뒤)에는 계기판에 이 모드의 값이 갑니다. 2.1.2-beta.4부터는 길안내를 시작할 때도 공식 모드의 호출이 이 모드의 값을 잠깐(250ms까지) 기다립니다(`docs/design.md` "공식 호출 잠깐 붙잡기"). `kor_tbt_log`를 켜면 붙잡은 결과가 `… held N ms, carries ours`(이 모드의 값을 실음) 또는 `…, passed as it was`(공식 모드의 값이 그대로 감) 줄로 남습니다.
3. `route guidance reaches this listener` 줄이 한 번도 없으면 이 모드가 길안내를 받지 못한 것입니다. 그때는 공식 모드 혼자 보냅니다. `giving way until it hears again` 줄이 있으면 그 뒤 이 모드가 다시 받을 때까지 공식 모드의 값이 그대로 갑니다. 공식 모드의 그림이 몇 초씩 보였다면 그 시각 앞뒤에 이 줄이나 `maneuver N unknown … asked again` 줄이 있는지도 적어 주세요.
4. 공식 모드 그대로 쓰려면 HMG-API 앱에서 NX4 KOR의 `kor_tbt`를 끄고 변경 사항을 적용한 뒤 재부팅합니다. 공식 무선 모드의 `tbt`는 켜 둡니다.
   - 먼 회전(600 m, 고속도로 출구 1,050 m 밖)의 큰 그림만 이상하면, `kor_tbt`는 켜 둔 채 `kor_tbt_far_big`만 끄고 다시 시작합니다. 먼 회전이 예전처럼 네모 칸 아이콘으로 돌아갑니다([#89](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/89)). `kor_tbt_log`를 켜면 먼 회전은 `-> near (far-big)`, 회전이 바뀌는 순간 붙잡은 것은 `-> held (put-off)` 줄로 보입니다.
   - 길안내 중 단속 카메라·제한속도 표시가 이상하거나 곧 회전 게이지가 엉뚱하게 차 있으면, 그 시각과 HMG-API 앱 Logs 탭의 `navigation (NX4 KOR): …` 줄을 [#96](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/96)에 적어 주세요. 이 모드는 순정 내비가 보내는 단속 정보 프레임에서 게이지 막대 칸만 바꿉니다. `kor_tbt`를 끄면 이것도 하지 않습니다.
5. 기록과 시각을 [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67)에 적어 주세요.

## 내비가 재부팅을 반복하거나 화면이 이상할 때

1. **우선 그대로 둡니다.** 위 "부팅 보호"가 훅을 끄고 정상으로 띄웁니다.
2. 정상으로 뜨면 NX4 KOR를 지우고(아래 1단계), 필요하면 위 "부팅 보호"의 2·3을 합니다.
3. Engineering Mode에 들어갈 수 있으면 USB로 되돌릴 수 있습니다(아래).

### HMG-API를 지운 뒤 Android가 뜨지 않을 때(NEMESIS 1.17)

NEMESIS 1.17(LivePatch)이 깔린 차에서 다음 둘 중 하나가 일어나면 Android가 뜨지 않습니다(부팅 화면에서 멈춤). NEMESIS 안전 모드도, 차를 껐다 켜는 것도 듣지 않습니다([Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397)).
- HMG-API 1.1.0-rc.8 이하를 지운 경우: 지운 뒤 첫 재부팅은 되고, 그다음 재부팅부터 뜨지 않습니다.
- 예전에 `HMGAPI/FORCE`로 설치한 HMG-API를 1.1.0-rc.9로 올린 경우: rc.9가 차에 남은 마지막 순정 파일을 덮어씁니다.

할 일:
- **rc.8 이하를 지웠고 아직 재부팅하지 않았으면:** 재부팅하기 전에 HMG-API 릴리스의 USB(`hmgapi-<판>-usb.zip`, 1.1.0-rc.10 이상)로 Update OTA를 누르거나 NEMESIS Manager로 `hmgapi-<판>-nemesis.zip`을 넣습니다. HMG-API 1.1.0-rc.10을 새로 설치하고, 그것이 고칩니다. 2.1.2 이후 이 저장소의 USB는 NEMESIS가 깔린 차에서 HMG-API를 설치하지 않습니다([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)).
- **rc.8 이하를 지웠고, 한 번 재부팅했고, Android가 아직 뜨면:**
  - 일반 삭제(`HMGAPI/UNINSTALL`)였으면 위와 같이 바로 다시 설치합니다. HMG-API의 백업(`/data/hmgapi/stock/`)에서 순정 파일을 되돌립니다.
  - `UNINSTALL-PURGE`였으면 백업이 없어 설치가 아무것도 바꾸지 않고 거절합니다(위 `FAIL:` 줄 표). #397을 따릅니다.
- **Android가 이미 뜨지 않으면:** #397을 따릅니다.
  - #397의 복구는 HMG-API 백업의 순정 `app_process`를 `app_process.real`에 되돌리고 재부팅하는 것입니다. 길은 NEMESIS 비상 USB(`NEMESIS.emergency`·`NEMESIS.data`·`NEMESIS.sh`)와, 미리 켜 둔 adb 둘입니다. 일반 삭제였을 때(백업이 남음)만 됩니다.
  - **비상 USB는 아직 차에서 된 적이 없습니다**(#397, 2026-11-25 기준). 한 차에서는 NEMESIS가 스틱을 돌리지 않았습니다. USB는 Android의 저장소 서비스가 붙이는데, Android가 뜨지 않으면 그 서비스도 돌지 않기 때문입니다. 안 되면 미리 켜 둔 adb나 대리점이 남은 길입니다.
  - `FORCE`로 설치한 차를 rc.9로 올려 뜨지 않게 된 경우에는 이 복구를 쓰지 않습니다. 차에 순정 파일이 남지 않았기 때문입니다. 그 차의 순정 펌웨어나 대리점 리플래시가 길이고, #397에 댓글로 알립니다(HMG-API 1.1.0-rc.10 릴리스 노트).
- **Android가 뜨지 않는 차에서 NEMESIS를 지우지 마세요.** 고쳐지지 않고, 위 복구에 쓰는 NEMESIS의 USB 처리와 root가 함께 없어집니다.
- 미리 막는 법은 [README](../README.md) "HMG-API를 지울 때"에 있습니다. 먼저 HMG-API를 rc.10 이상으로 올린 뒤 지우면 됩니다(HMG-API 릴리스의 USB·update zip·NEMESIS Manager용 `hmgapi-<판>-nemesis.zip`. 이 저장소의 USB는 NEMESIS가 깔린 차에서 쓰지 않음: 2.1.2 이후는 멈추고 2.1.1 이전은 NX4 KOR까지 설치함). 따로 받은 rc.9로 올리지 않습니다.

## 되돌리기(가벼운 것부터)

1. **NX4 KOR만 지우기**
   - 설치 USB의 `NX4` 폴더에 빈 파일 `UNINSTALL`을 만들고 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다.
   - 2.1.0 이후의 NX4 KOR는 HMG-API에서 이 모드를 지우고(관리 앱·서비스가 내려감) 작업 파일·기록 폴더를 지운 뒤 재부팅합니다. 시스템 파일·Wi-Fi 설정은 바꾸지 않았으므로 되돌릴 것이 없습니다.
   - 공식 무선 모드와 이 차의 map은 남깁니다. 공식 무선 모드도 지우려면 `UNINSTALL` 대신 `UNINSTALL-ALL`을 만듭니다.
   - 2.0.x를 쓰던 차에 남은 것(이 모드의 핫스팟, Wi-Fi 설정 파일 잠금, 순정 AP 저장값, 무선 권한 파일)은 설치기가 옛 판 자신의 되돌리기로 되돌립니다. 2.0.x가 아직 설치된 차는 그 모드의 사본으로, 2.0.x를 HMG-API 앱에서 먼저 지운 차나 2.0.x 위에 2.1.0 이후를 넣은 차(2.0.x의 기록 `/data/nx4-kor/backup`이 남음)는 USB의 `NX4/legacy-2.0`(2.0.x의 되돌리기 스크립트)으로 합니다. 그 폴더가 없는 USB면 기록만 남기고 그렇다고 알립니다. 그때는 2.0.x 릴리스 USB(`v2.0.4-beta.1`)의 `NX4/UNINSTALL`을 씁니다.
   - HMG-API를 먼저 지웠어도 됩니다. 그때는 남은 모드 폴더나 USB의 사본으로 되돌립니다. 자세한 것은 [README](../README.md) "삭제".
2. **HMG-API까지 지우기**
   - ⚠️ **NEMESIS 1.17이 깔린 차는 HMG-API를 1.1.0-rc.10 이상으로 올린 뒤에만 지웁니다.** rc.8 이하를 지우면 재부팅 한두 번 뒤 Android가 뜨지 않을 수 있습니다. `FORCE`로 설치한 차는 rc.9로 올리기만 해도 그렇습니다(위 "HMG-API를 지운 뒤 Android가 뜨지 않을 때", [Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397)).
     - 지울 때 도는 것은 그 HMG-API를 설치할 때 저장해 둔 삭제입니다. 그래서 새 판 HMG-API USB로 지워도 같습니다.
     - 먼저 HMG-API 릴리스의 update zip(HMG-API 앱 "Check USB updates")이나 USB(`hmgapi-<판>-usb.zip`)로 rc.10 이상으로 올리고 두 번 재부팅합니다(HMG-API 1.1.0-rc.10 릴리스 노트의 NEMESIS 1.17 안내). NEMESIS Manager용 `hmgapi-<판>-nemesis.zip`도 됩니다. 이 저장소의 USB는 쓰지 않습니다(2.1.2 이후는 멈추고, 2.1.1 이전은 NX4 KOR까지 설치함, #75).
     - 판은 관리 앱 "자세히" 표의 HMG-API 칸에서 봅니다.
     - NEMESIS 1.16 이하나 NEMESIS가 없는 차는 해당하지 않습니다.
   - **NX4 KOR를 먼저 지운 뒤에** 합니다. HMG-API 삭제는 HMG-API를 통해 바꾼 것만 되돌리므로, 2.0.x를 쓰던 차에서 순서를 바꾸면 2.0.x의 Wi-Fi 잠금이 남습니다.
   - 이 저장소의 릴리스 USB로는 지울 수 없습니다. 맨 위 설치기가 NX4 KOR 것이라 `HMGAPI/UNINSTALL`을 읽지 않습니다.
   - HMG-API 릴리스의 `hmgapi-<판>-usb.zip`을 따로 풀고, `HMGAPI` 폴더에 빈 파일 `UNINSTALL`을 만들어 Update OTA를 누릅니다.
   - `UNINSTALL`은 모드 파일과 설정을 남기고 모드 앱을 꺼 두기만 합니다. 모두 지우려면 `UNINSTALL-PURGE`를 씁니다.
3. **최후의 길: 순정 내비 업데이트**
   - 현대 내비게이션 업데이트로 순정 펌웨어를 다시 깔면 시스템 파일이 순정으로 돌아갑니다(HMG-API 문서 기준). HMG-API의 시스템 파일도 함께 사라집니다.
   - `/data`에 있는 것(이 모드의 기록, 2.0.x를 쓰던 차는 그 판의 Wi-Fi 설정 파일 잠금 등)은 남습니다. 그 뒤에도 Wi-Fi가 이상하면, NX4 KOR 릴리스 USB로 1단계(`NX4/UNINSTALL`)를 한 번 돌립니다. HMG-API가 없어도 USB의 사본과 남은 기록으로 되돌립니다. 2.0.x가 남긴 것(Wi-Fi 잠금 등)은 USB의 `NX4/legacy-2.0`으로 되돌립니다.

## 도움을 청할 때 남길 것

- 관리 앱 화면 사진(판정 줄과 상태표)
- USB의 `NX4/install.log`, `HMGAPI/install.log`
- USB의 `NX4/diag/` 폴더. 없거나 설정이 끝난 뒤의 기록이 필요하면, 재부팅하고 같은 USB로 Update OTA를 한 번 더 눌러 확인 창에서 [모으기]를 고른 뒤 가져옵니다(같은 판이면 기록을 모은 뒤 다시 설치하지 않고 관리 앱을 열어 map 확인·계획만 봅니다). 확인 창이 없는 예전 판에서 올리는 첫 설치 때는 묻지 않고 모으지도 않습니다.
  - 비밀번호가 든 Wi-Fi 설정 파일은 넣지 않고, Car Report는 HMG-API가 VIN·일련번호를 빼고 기록 줄을 가립니다. 그래도 공개 이슈에 올리기 전에 한 번 훑어봅니다.
  - **`iap2/` 폴더는 빼고 올립니다.** 순정 내비 파일(iAP2 라이브러리·앱)의 사본이라 공개하면 안 됩니다(폴더 안 `README.txt`에도 적혀 있음). 차선 안내 원인([#90](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/90))을 보는 데만 쓰고, 필요하면 공개하지 않는 길로 따로 전합니다.
- adb가 있으면 `/data/hmgapi/logs/hmgapi/wifi.log`, `/data/nx4-kor/logs/ap.log`, `/data/local/tmp/nx4-kor-status.txt`(USB 진단 기록의 `logs/`에도 일부 있음)
- 몇 번째 Update OTA에서, 어떤 메시지가 떴는지
- 내비 소프트웨어 판(`NX4.KOR.….260902`), 설치 전 HMG-API 판, 순정 무선 카플레이 트림인지

[GitHub 이슈](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues)에 올려 주세요. 2.1.0의 첫 차 확인 기록은 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)(닫음)에 있고, 무선·동글 결과는 [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)에 모읍니다.
