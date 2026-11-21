# 차에서 설치하다 문제가 생길 때

USB로 설치하다 멈추거나, 설치 뒤 상태 화면이 빨강·노랑일 때 볼 문서입니다. 화면에 나오는 문구별로 할 일을 적고, 되돌리는 길을 가벼운 것부터 적었습니다.

> ⚠️ **아직 차에서 확인하지 않았습니다.** 아래는 다음 셋에서 모은 것입니다.
> - 이 저장소의 설치기(`usb/troubleShooter`)
> - 자동 설정(`mod/svc/hotspot.sh`)과 상태 판정(`mod/bin/status.sh`)
> - HMG-API 1.1.0-rc.7의 문서(`wiki/Troubleshooting.md`, `wiki/Uninstalling.md`)와 설치기(`install/common/install.sh`)
>
> 차에서 다르게 동작하면 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에 적어 주세요.

설치 순서는 [README](../README.md) "설치", 차에서 확인할 일은 [`design.md`](design.md) "차에서 확인할 것"에 있습니다.

## 먼저 지킬 것

- 시동을 건 채 차를 세워 두고 합니다.
- 설치 뒤 상태 화면이 "설정을 마쳤습니다"를 띄울 때까지(3~5분) **끄지 마세요.**
- **재부팅은 켠 지 3분이 지난 뒤에** 합니다. 짧게 여러 번 재부팅하면 HMG-API가 훅을 끕니다(아래 "부팅 보호").
- 끝나면 USB를 뺍니다. 꽂아 두면 유선 안드로이드 오토가 먼저 잡혀 무선이 붙지 않을 수 있습니다.
- Update OTA 뒤 OTA 화면에 나오는 **오류 684는 정상**입니다. 바꾼 것이 되돌려지지 않습니다.

## 무엇이 일어났는지 보는 곳

| 어디 | 무엇 | adb 필요 |
|---|---|---|
| USB `NX4/install.log` | NX4 KOR 설치기가 한 일. 누를 때마다 아래에 이어 씁니다(앞의 시도도 남음). 이번 시도는 **맨 아래**, 마지막 "NX4 KOR USB 설치기 시작" 줄부터입니다 | 아니오 |
| USB `HMGAPI/install.log` | HMG-API 설치기가 한 일 | 아니오 |
| 상태 화면 | 오른쪽 칸의 판정·안내와 왼쪽 칸의 요약·상태표. 사진으로 남겨 두면 좋습니다. 앱 메뉴의 NX4 KOR 타일로 엽니다. 타일이 없으면 같은 USB로 Update OTA를 다시 누릅니다(다시 설치하지 않고 상태 화면만 엶) | 아니오 |
| `/data/nx4-kor/logs/ap.log` | 이 모드 서비스의 기록 | 예 |
| `/data/local/tmp/nx4-kor/` | map 만들기·확인·적용 출력(`map-car.txt`, `verify-map.txt`, `plan.txt`, `mod-apply.txt`) | 예 |
| HMG-API 앱의 Logs 탭, "Record a problem"(HMG-API rc.6부터) | HMG-API 쪽 기록 | 아니오. 다만 앱을 열 수 있어야 합니다(아래 "HMG-API 앱을 열 수 없을 때") |

## Update OTA를 누른 직후

"아무것도 바꾸지 않았습니다"가 붙은 메시지는 차를 그대로 두고 끝난 것입니다.

| 메시지 | 뜻 | 할 일 |
|---|---|---|
| USB에 NX4 폴더가 없습니다 | USB 맨 위에 풀지 않았음 | zip을 **USB 맨 위**에 풀었는지 봅니다. 폴더 안에 폴더가 또 생기면 안 됩니다. FAT32인지도 봅니다 |
| HMG-API를 먼저 설치합니다 | 정상 흐름(HMG-API가 없는 차) | 재부팅을 기다렸다가, 부팅이 끝나고 1~2분 뒤 같은 USB로 **한 번 더** 누릅니다 |
| HMG-API를 …에서 …(으)로 먼저 올립니다 | 정상 흐름(HMG-API가 1.1.0-rc.4보다 낮은 차). 따로 설치한 무선 모드는 아직 지우지 않습니다 | 위와 같이 한 번 더 누릅니다 |
| HMG-API가 응답하지 않습니다 | HMG-API가 아직 안 떴거나 멈춤 | 내비를 재부팅하고 **3분 넘게** 기다린 뒤 다시 누릅니다 |
| HMG-API …에는 설치할 수 없습니다. … 이상으로 먼저 올려 주세요 | HMG-API가 낮은데 USB에 HMG-API가 없음 | HMG-API가 든 릴리스 USB 묶음(`v2.0.0-beta.3`부터)을 씁니다 |
| HMG-API가 없습니다. HMG-API USB 설치(HMGAPI 폴더)를 먼저 해 주세요 | HMG-API가 없는데 USB에 HMG-API가 없음 | 위와 같습니다 |
| USB에서 복사하지 못했습니다 / USB에 NX4/install(…)이 없습니다 | USB 읽기 문제나 파일 빠짐 | USB를 다시 포맷하고 zip을 다시 풉니다 |
| NX4 KOR 설치 실패: USB의 NX4/install.log를 보세요 | HMG-API 엔진이 설치를 거절함 | `install.log` 맨 아래(마지막 "NX4 KOR USB 설치기 시작" 줄 뒤)의 `refused:` 줄을 봅니다. 위쪽은 앞의 시도입니다. 업데이트 중이었다면 예전 판의 서비스는 다시 띄워 둡니다 |
| 이미 설치되어 있습니다 | 같은 판이 있음 | 상태 화면만 엽니다. 같은 판을 다시 설치하려면 `NX4` 폴더에 빈 파일 `REINSTALL`을 만듭니다 |

HMG-API 설치 중 `HMGAPI/install.log`에 `isn't a known stock build`가 있으면, HMG-API 설치기가 이 차의 `app_process`를 모르는 것입니다. USB 맨 위 `HMGAPI` 폴더에 빈 파일 `FORCE`를 만들고 다시 누릅니다(**자기 책임**).

## 설치 뒤 상태 화면이 빨강·노랑일 때

| 판정(문구 요지) | 할 일 |
|---|---|
| 설치 중입니다 | 기다립니다 |
| 내비를 3분 후 재부팅해 주세요 / 무선 카플레이 기능이 아직 켜지지 않았습니다 / Wi-Fi를 켜는 중입니다 | 켠 지 3분이 지난 뒤 [지금 재부팅]을 누릅니다 |
| HMG-API가 이 차의 map을 만들지 못해… | 3분 뒤 재부팅하면 다시 시도합니다 |
| **이 차의 map을 확인하지 못해 무선 기능을 적용하지 않았습니다** | 확인에 한 번 실패하면 다시 시도하지 않습니다. 아래 "되돌리기" 1단계로 NX4 KOR를 지운 뒤 다시 설치하면 한 번 더 해 봅니다. 그래도 같으면 adb로 `verify-map.txt`가 필요합니다 |
| 순정 핫스팟이 켜져 있어 이번에는 설정하지 않았습니다 | 순정 핫스팟을 끄고 재부팅합니다. 순정 무선 카플레이 트림에서 늘 이렇다면 [#20](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/20)에 적어 주세요 |
| 따로 설치된 무선 모드(wireless-carplay-aa)가 있어… | 아래 "HMG-API 앱을 열 수 없을 때" |
| HMG-API에 다른 모드의 바뀐 내용이 함께 있어… / 무선 기능 적용에 실패했습니다 / HMG-API가 적용을 거절했습니다 | 아래 "HMG-API 앱을 열 수 없을 때" |
| HMG-API 앱에서 NX4 KOR가 꺼져 있습니다 / 'Wireless CarPlay'가 꺼져 있습니다 | 아래 "HMG-API 앱을 열 수 없을 때" |
| HMG-API 훅이 꺼져 있습니다 / NX4 KOR의 훅을 켜지 못했습니다 | 3분 뒤 재부팅합니다. 같으면 이 차의 map에 우리 훅 지점이 없을 수 있습니다. 기록을 남겨 알려 주세요 |
| **HMG-API가 재부팅이 너무 잦은 것으로 보고 무선 기능을 껐습니다** | 아래 "부팅 보호" |
| 다른 Wi-Fi 패키지가 핫스팟을 쓰고 있어… | NEMESIS의 Korea Projection이나 다른 무선·핫스팟 패키지를 지우고 재부팅합니다([`design.md`](design.md) "다른 패키지·모드와 함께 쓸 때") |
| 이 차는 Wi-Fi 칩이 켜지지 않아… / Wi-Fi 부품이 없어… | 이 차에서는 무선 카플레이를 쓸 수 없습니다 |
| 지원하지 않는 HMG-API 버전입니다 | HMG-API가 든 릴리스 USB로 다시 누릅니다 |
| 연결됨·준비됨(시안 글자)인데 폰이 붙지 않음 | 오른쪽 칸 판정 아래의 노란 띠를 봅니다. USB를 뺐는지도 봅니다 |

### HMG-API 앱을 열 수 없을 때

몇몇 안내는 "HMG-API 앱에서 …"라고 합니다. 그런데 HMG-API 앱 타일은 HMG-API 훅이 켜진 뒤에야 생기고, 훅은 이 차의 map이 확인된 뒤에 켜집니다. 그래서 처음 설치할 때는 **HMG-API 앱을 열 수 없습니다.** NEMESIS(My Packages → HMG-API → Launch)나 adb가 있어야 엽니다.

그때 현실적인 길은 NX4 KOR를 지우고(아래 "되돌리기" 1단계) 재부팅한 뒤, 같은 USB로 다시 설치하는 것입니다. 설치기는 다시 설치하기 전에, 따로 설치된 `wireless-carplay-aa`를 지우고 적용합니다.

### 부팅 보호

HMG-API는 훅 때문에 내비가 제대로 뜨지 못한다고 보면 스스로 훅을 끄고 정상으로 띄웁니다(HMG-API rc.6부터의 기준). 다음 둘 중 하나일 때입니다.
- 한 번의 부팅 안에서 Android가 3번 못 뜸
- 켠 지 2분 안에 꺼지기가 6번 이어짐

훅이 꺼지면 무선 기능도 꺼집니다. 다시 켜려면:

1. 마지막으로 바꾼 것이 원인이면 먼저 되돌립니다(예: NX4 KOR를 지움).
2. **HMG-API를 지우지 말고 다시 설치(업데이트)합니다.** HMG-API 설치기는 설치할 때 이 횟수를 지웁니다(`hook/starts`를 0으로, `hook/boot` 삭제).
   - 이 저장소의 릴리스 USB는 HMG-API가 없거나 낮을 때만 HMG-API 설치기를 돌립니다. 그래서 여기서는 HMG-API 릴리스의 `hmgapi-<판>-usb.zip`을 따로 풀어 Update OTA를 누릅니다.
3. 재부팅하고 3분 넘게 켜 둡니다.

## 내비가 재부팅을 반복하거나 화면이 이상할 때

1. **우선 그대로 둡니다.** 위 "부팅 보호"가 훅을 끄고 정상으로 띄웁니다.
2. 정상으로 뜨면 NX4 KOR를 지우고(아래 1단계), 필요하면 위 "부팅 보호"의 2·3을 합니다.
3. Engineering Mode에 들어갈 수 있으면 USB로 되돌릴 수 있습니다(아래).

## 되돌리기(가벼운 것부터)

1. **NX4 KOR만 지우기**
   - 설치 USB의 `NX4` 폴더에 빈 파일 `UNINSTALL`을 만들고 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다.
   - 다음을 되돌린 뒤 재부팅합니다: 이 모드의 핫스팟, Wi-Fi 설정 파일 잠금, 순정 AP 저장값, 무선 권한 파일.
   - HMG-API를 먼저 지웠어도 됩니다. 그때는 남은 모드 폴더나 USB의 사본으로 되돌립니다. 자세한 것은 [README](../README.md) "삭제".
2. **HMG-API까지 지우기**
   - **NX4 KOR를 먼저 지운 뒤에** 합니다. HMG-API 삭제는 HMG-API를 통해 바꾼 것만 되돌리므로, 순서를 바꾸면 Wi-Fi 잠금이 남습니다.
   - 이 저장소의 릴리스 USB로는 지울 수 없습니다. 맨 위 설치기가 NX4 KOR 것이라 `HMGAPI/UNINSTALL`을 읽지 않습니다.
   - HMG-API 릴리스의 `hmgapi-<판>-usb.zip`을 따로 풀고, `HMGAPI` 폴더에 빈 파일 `UNINSTALL`을 만들어 Update OTA를 누릅니다.
   - `UNINSTALL`은 모드 파일과 설정을 남기고 모드 앱을 꺼 두기만 합니다. 모두 지우려면 `UNINSTALL-PURGE`를 씁니다.
3. **최후의 길: 순정 내비 업데이트**
   - 현대 내비게이션 업데이트로 순정 펌웨어를 다시 깔면 시스템 파일이 순정으로 돌아갑니다(HMG-API 문서 기준). HMG-API의 시스템 파일도 함께 사라집니다.
   - `/data`에 있는 것(이 모드의 Wi-Fi 설정 파일 잠금, 기록 등)은 남습니다. 그 뒤에도 Wi-Fi가 이상하면, NX4 KOR 릴리스 USB로 1단계(`NX4/UNINSTALL`)를 한 번 돌립니다. HMG-API가 없어도 USB의 사본과 남은 기록으로 되돌립니다.

## 도움을 청할 때 남길 것

- 상태 화면 사진(판정 줄과 상태표)
- USB의 `NX4/install.log`, `HMGAPI/install.log`
- adb가 있으면 `/data/nx4-kor/logs/ap.log`와 `/data/local/tmp/nx4-kor/`의 txt 파일
- 몇 번째 Update OTA에서, 어떤 메시지가 떴는지
- 내비 소프트웨어 판(`NX4.KOR.….260902`), 설치 전 HMG-API 판, 순정 무선 카플레이 트림인지

[GitHub 이슈](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues)에 올려 주세요. 차에서 처음 확인하는 결과는 [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)에 모읍니다.
