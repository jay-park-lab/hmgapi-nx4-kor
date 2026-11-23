> 🧪 **실험 중인 프로젝트입니다.** 일반 차주가 쓰기를 권하지 않습니다.
> - **2.1.0부터 구조를 다시 짭니다**(2026-11-23 결정, [#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38), 할 일 [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45)). 아래 "[방향: 2.1.0](#방향-210)"을 보세요.
> - 모드 구성·상태 화면·삭제 안내는 2.1.0 코드 기준입니다. "필요한 것"·"설치"는 아직 **2.0.x**(한국 포크 무선 모드 2.4.5와 핫스팟 서비스) 설치기 기준이고, USB 설치기를 바꾸는 작업([#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45))에서 고칩니다. 2.0.x는 정식으로 내지 않고 끝냅니다. 베타 묶음(`v2.0.0-beta.*`~`v2.0.4-beta.1`)은 [릴리스](https://github.com/jay-park-lab/hmgapi-nx4-kor/releases)에 그대로 둡니다.
> - 그래서 구성, 설치 방법, 판 번호가 예고 없이 크게 바뀔 수 있습니다.

## 방향: 2.1.0

2.1.0은 다음 셋으로 됩니다.
- **HMG-API**(1.1.0-rc.8 이상)
- **공식 무선 모드**([Open-HMG/hmgapi-wireless-cp-aa](https://github.com/Open-HMG/hmgapi-wireless-cp-aa) 2.2.0-rc.9 이상): 고치지 않고, NX4에는 HMG-API의 "Install anyway"(`--any-car`)로 넣습니다.
- **이 저장소의 NX4 추가분**

| 일 | 맡는 곳 |
|---|---|
| 무선 카플레이·안드로이드 오토 훅, 계기판·HUD 길안내 | 공식 무선 모드. 한국 계기판 맞춤이 필요하면 공식 모드에 기여합니다(같은 훅 지점을 `replace`하는 모드 둘은 함께 켜지지 않음, [#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)) |
| 핫스팟(프로젝션 AP), 순정 핫스팟 기능 | HMG-API(공식 모드가 `"wifi": {"projection": true}`로 요청) |
| HMG-API 설치·업데이트, 공식 모드 설치, NX4 map 만들기·확인, 진단, 되돌리기(옛 NX4 KOR 2.0.x 정리 포함. 2.0.x는 공식 모드와 함께 설 수 없음, `conflicts`) | 이 저장소의 USB 설치기 |
| 설치 진행·판정 화면 | 이 저장소의 상태 화면 앱. 지금 UI를 그대로 두고, 지우기 버튼을 더합니다([#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)) |
| USB Wi-Fi 동글 | 이 저장소(나중에). Wi-Fi 부품이 없는 차를 위한 길 |

- 뺀 것: 한국 포크 무선 모드 2.4.5(`hooks.jar`·레시피·`libleafiaaac.so`·`patches.json`·`settings.json`과 저장소의 `wireless/`), 순정 칩용 핫스팟 서비스(서비스 `ap`, `svc/hotspot.sh`의 핫스팟·칩 깨우기·Wi-Fi 잠금·자동 설정). `nx4-kor` 모드에는 상태 화면 앱과 그 서비스만 남았습니다(아래 "무엇을 하나").
- 판 번호: 베타도 판에 꼬리를 붙입니다. `2.0.4-beta.1`부터 그렇게 했고, 2.1.0의 첫 베타는 `2.1.0-beta.1`입니다([`docs/git-flow.md`](docs/git-flow.md) 규칙 4).
- 2.0.x의 마지막 `release/2.0.4`(`v2.0.4-beta.1`)는 `main`에 합치지 않고 지웁니다. 끝 커밋은 태그가 남깁니다.

**지금까지 차에서 본 것**(2026-11-23, NX4HEV 260902, [#23 기록](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23#issuecomment-7101713033))
- USB 설치·업데이트, HMG-API map 만들기·확인(훅 지점 393/393), 자동 설정, 상태 화면과 [지금 재부팅], 진단은 동작했습니다.
- 2.0.4-beta.1까지의 자동 설정은 HMG-API rc.7 계획의 새 설명 줄을 변경으로 봐서, 다 적용된 뒤에도 부팅마다 "적용할 것 있음"으로 갑니다.
  - Wi-Fi 칩이 없는 이 차에서는 부팅마다 Wi-Fi 깨우기 쪽으로 갑니다.
  - 칩이 있는 차라면 부팅마다 무선 기능을 다시 적용하고 "설정을 마쳤습니다. 재부팅해 주세요"를 띄웁니다. PC 시험에서 이 차의 계획 기록으로 재현했습니다.
  - 2.1.0에서는 자동 설정이 모드에서 빠지고 map·적용은 USB 설치기가 맡습니다. 설치기가 읽는 계획의 같은 문제는 설치기 작업에서 고칩니다([#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45)).
- 이 차는 Wi-Fi 부품이 없는 것으로 봅니다.
  - 순정 핫스팟 기능을 켜도(2.0.4-beta.1) 드라이버가 칩 전원을 넣지 못했습니다(`failed to power up DHD generic adapter`).
  - 그래서 무선은 이 차에서 확인하지 못했고, 동글로 시험할 예정입니다.

이 저장소는 [StopDragon/korea-projection](https://github.com/StopDragon/korea-projection)의 포크입니다. 원본과 다른 점은 다음과 같습니다.

- **HMG-API와 공식 무선 모드 위에 상태 화면을 얹습니다.** 원본은 NEMESIS 패키지이고, 한국 차 빌드 무선 모드(`wireless-carplay-aa`)를 HMG-API에 따로 설치합니다. 이 저장소의 2.1.0은 무선을 HMG-API와 공식 무선 모드(고치지 않음)에 맡기고, HMG-API 모드 `nx4-kor`에는 상태 화면만 담습니다. Engineering Mode의 USB 설치(DSP Update OTA)로 설치·업데이트·삭제합니다.
- **투싼 NX4 전용입니다.** 다른 차의 map·패치 세트·차 목록을 뺐습니다.
- **HMG-API 1.1.0-rc.8 이상에 맞췄습니다**(공식 무선 모드 2.2.0-rc.9가 요구하는 판). 이 차의 map은 HMG-API가 차에서 만들어 `state/local-map.json`에 둡니다.
- **제보 기능을 뺐습니다.** 제보 파일, QR, 이슈 자동 분류가 없습니다.
- **무선은 차에서 아직 확인하지 못했습니다**(위 "지금까지 차에서 본 것"). 시험판 묶음은 [릴리스](https://github.com/jay-park-lab/hmgapi-nx4-kor/releases)에 있고, 직접 만들 수도 있습니다([만들기와 시험](#만들기와-시험)).

> ⚠️ 차량 소프트웨어를 바꾸는 일입니다. 모든 책임은 설치하신 차주 본인에게 있습니다.

## 무엇을 하나

한국 현대·기아 내비(Gen5W 헤드유닛)는 Wi-Fi 칩을 켜지 않아 무선 카플레이와 무선 안드로이드 오토를 쓸 수 없습니다. 2.1.0에서는 HMG-API가 순정 핫스팟 기능을 켜고 무선 연결용 Wi-Fi(프로젝션 AP)를 띄우며, 공식 무선 모드가 무선 카플레이·안드로이드 오토 훅과 계기판·HUD 길안내를 겁니다. NX4 KOR는 이 차에 그것들을 넣고(USB 설치기) 제대로 됐는지 보여 줍니다(상태 화면).

| 구성 | 내용 |
|---|---|
| HMG-API(1.1.0-rc.8 이상) | 훅, 이 차의 map, 순정 핫스팟 기능, 프로젝션 AP |
| 공식 무선 모드 `wireless-carplay-aa`(2.2.0-rc.9 이상) | 무선 카플레이·안드로이드 오토, 계기판·HUD 길안내. 고치지 않고 NX4에는 "Install anyway"(`--any-car`)로 넣습니다 |
| HMG-API 모드 `nx4-kor` | 상태 화면 앱과 서비스 `launch`(화면이 열릴 때 `bin/status.sh`로 상태 파일을 새로 씀) 하나. 훅을 걸지 않고 시스템 파일·Wi-Fi 설정을 바꾸지 않습니다 |
| 상태 화면 앱 | "NX4 KOR"(`io.github.jayparklab.nx4kor`). 앱 메뉴에 타일이 생깁니다 |
| USB 설치기 | `usb/troubleShooter` |

| 이름 | 값 |
|---|---|
| HMG-API 모드 id | `nx4-kor` (HMG-API 앱 목록 이름 "NX4 KOR: Tucson NX4 (Korea)") |
| 상태 화면 앱 | "NX4 KOR", 패키지 `io.github.jayparklab.nx4kor` |
| USB 폴더 | `NX4/` |
| 차 안 기록 | `/data/nx4-kor` (상태 화면 감시자 기록 `logs/ap.log`) |
| 차 안 작업 폴더·상태 파일 | `/data/local/tmp/nx4-kor`, `/data/local/tmp/nx4-kor-*.txt` |

설계와 차에서 확인할 것은 [`docs/design.md`](docs/design.md)에 있습니다.

## 대상 차

**투싼 NX4**만 받습니다. 가솔린(`NX4`)과 하이브리드(`NX4HEV`), 한국 내비 소프트웨어 260902(`NX4….KOR.….260902`)입니다. 다른 차와 다른 소프트웨어에는 HMG-API가 설치하지 않습니다.

- 원본(Korea Projection)에서는 두 차 모두 무선 연결이 확인됐습니다([#125](https://github.com/StopDragon/korea-projection/issues/125), [#126](https://github.com/StopDragon/korea-projection/issues/126)). 다만 같은 판에서도 Wi-Fi 부품이 없는 차가 있습니다(2026-11-23 NX4HEV 260902, [#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38)). 그런 차에서는 상태 화면이 "Wi-Fi 부품이 없는 것으로 보여…"를 보이고, 무선은 USB Wi-Fi 동글([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48))을 기다립니다. 유선 카플레이·안드로이드 오토와 계기판 길안내는 그대로 씁니다.
- NX4 map은 HMG-API에도 이 모드에도 없습니다. HMG-API가 그 차의 파일로 map을 만들고(`engine map-car --write`) 차에서 확인한(`verify-map`) 뒤에만 훅이 켜집니다. 공식 무선 모드의 차 목록에도 NX4가 없어 "Install anyway"(`--any-car`)로 넣습니다.

## 필요한 것

- **USB 묶음** `hmgapi-nx4-kor-버전-usb.zip`: 이 저장소의 [릴리스](https://github.com/jay-park-lab/hmgapi-nx4-kor/releases)에서 받습니다. `v2.0.0-beta.3`부터 **HMG-API**(1.1.0-rc.7)가 함께 들어 있어, HMG-API가 없는 차도 이 USB 하나로 설치합니다. 직접 만들려면 [만들기와 시험](#만들기와-시험).
  - `v2.0.0-beta.1`에는 HMG-API가 없습니다. 그 묶음을 쓰면 HMG-API [릴리스](https://github.com/Open-HMG/HMG-API/releases)의 `hmgapi-버전-usb.zip`으로 HMG-API를 먼저 설치합니다. `v2.0.0-beta.2`는 빌드가 멈춰 릴리스가 없습니다.
- **HMG-API는 1.1.0-rc.4 이상**이어야 합니다. 이미 있는 HMG-API가 이보다 낮으면 USB 묶음의 HMG-API로 먼저 올립니다(아래 "설치" 2).
- FAT32로 포맷한 USB(32GB 이하 권장).

## 설치

1. `hmgapi-nx4-kor-버전-usb.zip`을 빈 USB 맨 위에 풉니다.
   ```
   USB
   ├─ ota_package.tar          NX4 KOR 설치기
   ├─ README.txt, LICENSE, NOTICE.md, HMGAPI-README.txt, HMGAPI-SOURCE.txt
   ├─ HMGAPI                   HMG-API(설치 payload)
   └─ NX4
       ├─ install              NX4 KOR(hmgapi-nx4-kor.zip, payload)
       └─ hmgapi               HMG-API 설치기
   ```
2. 시동을 건 채 차를 세우고 USB를 꽂은 뒤 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다.
   - **HMG-API가 없는 차:** "NX4 KOR: HMG-API를 먼저 설치합니다"가 나오고 HMG-API가 설치된 뒤 재부팅됩니다. 부팅이 끝나고 1~2분 뒤 **같은 USB로 Update OTA를 한 번 더** 누릅니다.
   - **HMG-API가 1.1.0-rc.4보다 낮은 차:** "NX4 KOR: HMG-API를 …에서 …(으)로 먼저 올립니다"가 나오고 HMG-API가 업데이트된 뒤 재부팅됩니다. 위와 같이 한 번 더 누릅니다. 이때는 따로 설치한 무선 모드도 아직 지우지 않습니다. USB에 HMG-API가 없으면 아무것도 바꾸지 않고 멈춥니다.
   - **HMG-API 1.1.0-rc.4 이상인 차:** 바로 NX4 KOR를 설치합니다.
   - USB의 `HMGAPI/install.log`에 `isn't a known stock build`가 있으면 HMG-API 설치기가 이 차의 `app_process`를 모르는 것입니다. 그때는 `HMGAPI/FORCE` 빈 파일을 만들고 다시 합니다(자기 책임).
   - HMG-API 앱의 "Check USB updates"로 모드를 넣는 HMG-API 문서의 방법은 처음에는 쓸 수 없습니다. HMG-API에 NX4 map이 없어 HMG-API 앱 타일이 생기지 않기 때문입니다.
3. 상태 화면이 열리고 설정 진행이 보입니다. OTA 화면의 오류 684는 정상입니다. map을 만들고 확인하는 동안 **3~5분 동안 끄지 마세요.**
4. "무선 카플레이 설정을 마쳤습니다"가 나오면 **[지금 재부팅]**을 누릅니다(또는 RESET 버튼). 시동만 끄면 내비가 꺼지지 않을 수 있습니다.
5. 폰에서 무선 카플레이(또는 무선 안드로이드 오토)를 연결합니다.

- **업데이트:** 새 판 USB로 같은 방법으로 합니다. 같은 판을 다시 설치하려면 `NX4/REINSTALL` 빈 파일을 만듭니다. 훅 코드만 바뀐 판이면 상태 화면이 재부팅을 안내합니다.
- **따로 설치한 무선 모드:** Korea Projection이나 HMG-API 공식판의 `wireless-carplay-aa`가 있으면 설치기가 먼저 지우고 적용합니다. NX4 KOR에 같은 훅이 들어 있어 둘을 함께 둘 수 없습니다(`mod.json`의 `conflicts`).
- **진단 기록:** 상태 화면 앱이 있으면 누를 때마다 설치기가 먼저 "진단 기록 모으기" 확인 창을 띄웁니다. [모으기]를 고르면 아무것도 바꾸기 전에 내비의 기록, HMG-API Car Report, `/system/lib` 파일의 이름·md5를 USB의 `NX4/diag/<시각>/`에 모읍니다(1~2분, 그동안 USB를 빼지 마세요). [건너뛰기]를 고르거나 60초 동안 고르지 않으면 모으지 않고 이어집니다. 담는 것은 [`docs/design.md`](docs/design.md) "진단 기록"에 있습니다.
- USB를 꽂아 둔 채로 두면 유선 안드로이드 오토가 시작되어 무선이 붙지 않을 수 있습니다. 끝나면 빼 주세요.
- **문제가 생기면:** 설치기와 상태 화면의 문구별 할 일, 부팅 보호, 되돌리는 길은 [`docs/troubleshooting.md`](docs/troubleshooting.md)에 있습니다.

## 상태 확인

- **앱 메뉴의 NX4 KOR 타일**을 누릅니다. 타일은 HMG-API 훅이 켜진 뒤(이 차의 map 확인 뒤 재부팅)에 생깁니다.
- 타일이 없을 때는 설치 USB로 Update OTA를 다시 누릅니다. 다시 설치하지 않고 **상태 화면만 엽니다.** HMG-API 훅이 꺼진 동안(map이 없거나 부팅 보호)에는 타일이 없습니다.
- 화면이 열릴 때 상태를 새로 씁니다. 읽기만 하고 차의 설정은 바꾸지 않습니다.

상태 화면은 순정 내비 설정 화면을 본뜬 모양입니다. 왼쪽 위 `<`를 누르면 닫힙니다.
- 오른쪽 칸의 판정: 준비됨·연결됨이면 시안 글자(띠 없음), 확인이 필요하면 노란 띠, 문제면 빨간 띠입니다. 판정은 HMG-API 판, 공식 무선 모드(설치·켜짐·판·훅), HMG-API 훅(map), 프로젝션 AP, Wi-Fi 부품을 차례로 봅니다. 판정 코드별 뜻은 [`docs/design.md`](docs/design.md) "상태 화면".
- 왼쪽 칸: 요약 3줄(설치 / 무선 Wi-Fi / 폰 연결)과 그 아래 자세한 상태표.
- 오른쪽 칸 판정 아래의 노란 띠: 설치 중 안내와 알림.
- **[지금 재부팅]**(오른쪽 칸 맨 아래): 차를 세운 상태에서만 누르세요. 켜진 지 3분이 안 됐으면 막힙니다. 재부팅을 짧게 여러 번 하면 HMG-API가 훅을 끄므로 3분 넘게 켜 두세요.

더 자세한 기록은 HMG-API 쪽에 있습니다: 프로젝션 AP는 `/data/hmgapi/logs/hmgapi/wifi.log`, 모드·훅은 HMG-API 앱의 Logs 탭. adb가 없으면 설치 USB로 Update OTA를 누르고 확인 창에서 [모으기]를 고르면 USB의 `NX4/diag/<시각>/logs/`에 함께 모입니다.

## HMG-API 앱의 설정

NX4 KOR에는 설정이 없습니다. 무선 기능의 설정은 HMG-API 앱의 "Wireless CarPlay + Android Auto"(공식 무선 모드)에 있습니다. 그중 `bridge`(Wireless CarPlay)를 끄면 무선 카플레이가 되지 않고 상태 화면이 `bridgeoff`를 보입니다. 계기판·HUD 길안내는 `tbt`(`tbt_standard`는 차의 순정 꼴)입니다. 설정을 바꾼 뒤에는 HMG-API 앱에서 변경 사항을 적용하고 재부팅합니다.

2.0.x의 `nx4-kor` 설정(`tbt_fit`, `aa_ready_resend`, `aa_name_hold`, `star_popup_skip` 등 한국 포크 기능)은 없어졌습니다. 공식 모드에 기여할지는 [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45)에서 차 테스트 뒤 정합니다.

## 알아 두실 점

- 설치 뒤 약 5분 동안 재부팅하지 마세요.
- **NEMESIS로 Korea Projection이나 다른 무선·핫스팟 패키지를 설치해 두었다면 먼저 지우세요.** 함께 두면 HMG-API의 프로젝션 AP와 Wi-Fi를 다툽니다(상태 화면 `otherwifi`). 공식 무선 모드와 같은 훅을 `replace`로 거는 다른 HMG-API 모드와도 함께 켤 수 없습니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)). 자세한 것은 [`docs/design.md`](docs/design.md) "다른 패키지·모드와 함께 쓸 때".
- 프로젝션 AP가 켜져 있는 동안에는 내비가 휴대폰 핫스팟(일반 Wi-Fi)에 붙을 수 없습니다. Wi-Fi 칩 하나가 AP 역할을 하기 때문입니다. HMG-API 앱의 "집 Wi-Fi"(Home Wi-Fi)를 켜면 주차한 동안만 HMG-API가 AP를 끄고 집 Wi-Fi에 붙습니다.
- **계기판·HUD 길안내의 한계:** 공식 무선 모드가 폰의 지도 앱이 보내 주는 정보(다음 회전의 종류·방향·남은 거리·도로 이름)까지만 보내서 순정 내비와 똑같지 않습니다. 지하차도·고가차도 구분, 일부 갈림길·회전교차로 모양, 방면 표시는 다르거나 나오지 않을 수 있고, 지도 앱마다 보내는 정보가 다릅니다.
- **map이 생기기 전(훅이 꺼진 동안)에는 HMG-API가 순정 OTA 업데이트를 막지 못합니다.** 펌웨어가 업데이트되면 HMG-API의 시스템 파일이 지워지니, 그때는 HMG-API부터 다시 설치합니다.

## 삭제

설치 USB의 `NX4` 폴더에 빈 파일 `UNINSTALL`을 만들고 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다. NX4 KOR(`nx4-kor`)에 대해서는 다음을 합니다.
- 상태 화면의 감시자를 멈추고 작업 파일(`/data/local/tmp/nx4-kor*`)을 지웁니다.
- HMG-API에서 이 모드를 지웁니다(`engine remove`). HMG-API가 상태 화면 앱과 서비스를 내립니다. 이 모드는 시스템 파일·Wi-Fi 설정을 바꾸지 않아 적용할 것이 없습니다.
- 기록 폴더(`/data/nx4-kor`)를 지웁니다. HMG-API가 만든 이 차의 map(`state/local-map.json`)은 남깁니다.

주의할 점:
- 공식 무선 모드·HMG-API를 함께 지울지와 USB `UNINSTALL`이 그것을 어떻게 하는지는 USB 설치기 작업([#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45))과 상태 화면 지우기 버튼([#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44))에서 정합니다.
- 2.0.x를 쓰던 차는 2.0.x가 바꾼 것(Wi-Fi 설정 잠금, 순정 핫스팟 저장값, 무선 권한 파일)이 남을 수 있습니다. 2.1.0의 지우기는 그것을 되돌리지 않습니다. USB 설치기가 2.1.0을 넣기 전에 옛 판 자신의 삭제(`bin/uninstall.sh`)로 정리합니다.
- HMG-API 일반 삭제(`HMGAPI/UNINSTALL`)는 모드 파일·설정을 남기고 모드 앱을 꺼 두기만 합니다. 모두 지우려면 `HMGAPI/UNINSTALL-PURGE`를 씁니다. HMG-API를 먼저 지운 뒤에도 USB `NX4/UNINSTALL`이 남은 모드 폴더와 상태 화면 앱을 지웁니다.

## 만들기와 시험

| 위치 | 내용 |
|---|---|
| `mod/` | HMG-API 모드 그대로: `mod.json`, 서비스·공용 함수(`svc/`), 상태·삭제(`bin/`), 삭제 전 정리(`scripts/`) |
| `app/` | 상태 화면 앱 소스 |
| `usb/` | USB 설치기(`troubleShooter`)와 USB 안내(`README.txt`) |
| `scripts/` | `build-app.sh`(상태 화면 앱), `build.sh`(서명한 모드 zip과 USB 묶음) |
| `docs/design.md` | 설계와 차에서 확인할 것 |
| `docs/troubleshooting.md` | 차에서 설치하다 문제가 생길 때 |
| `docs/emulator-test.md` | 에뮬레이터에서 상태 화면 앱 시험 |
| `docs/git-flow.md` | 브랜치 전략(Git Flow) |
| [GitHub 이슈](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues) | 정하지 않은 것(라벨 `결정 필요`), 차에서 확인할 일(`차 확인`), 릴리스 일(`릴리스`) |
| `docs/release.md` | 태그로 도는 배포(GitHub Actions)와 배포 키 |
| `tests/` | PC 시험(`mod-test.sh`), 에뮬레이터 시험 스크립트(`emu/`) |

**만들기**

저장소 밖 경로(Android SDK, 서명 키, HMG-API 소스)는 코드에 기본값이 없습니다. `.env.example`을 `.env.local`로 복사해 채웁니다(`.env.local`은 git에 넣지 않습니다). 명령 앞에 준 값이 `.env.local`보다 앞섭니다.

```sh
cp .env.example .env.local   # ANDROID_HOME, NX4_APP_KEYS, HMGAPI_SRC, NX4_MOD_KEY 채우기

# 1. 상태 화면 앱(Android SDK build-tools와 android-19 필요) → mod/app/NX4KOR.apk
#    NX4_APP_KEYS 폴더에 키가 없으면 처음에 만듭니다. 그 폴더는 따로 백업합니다
sh scripts/build-app.sh

# 2. 모드 작성자 키(처음 한 번, 저장소 밖에 보관. 업데이트도 같은 키로 서명해야 HMG-API가 받습니다)
cd <HMGAPI_SRC에 적은 HMG-API 소스>
mkdir -p out/engine-host
javac --release 8 -d out/engine-host core/runtime/java/hmgapi/engine/*.java
java -cp out/engine-host hmgapi.engine.Signing keygen <NX4_MOD_KEY에 적은 경로>

# 3. 묶음(결과: out/hmgapi-nx4-kor-버전.zip, out/hmgapi-nx4-kor-버전-usb.zip)
#    busybox는 Alpine 저장소에서 받아 넣습니다(scripts/fetch-busybox.sh, 인터넷 필요. NOTICE.md의 SHA-256과 같을 때만).
#    단 mod/bin/busybox가 있으면 그것을 확인 없이 먼저 씁니다. 예전에 둔 것이 있으면 지우고 만듭니다(docs/release.md "busybox")
#    선택: .env.local에 HMGAPI_USB_ZIP(hmgapi-버전-usb.zip)
sh scripts/build.sh
```

**PC 시험**
- `sh tests/mod-test.sh`: `mod.json`(뺀 것 포함), 서비스 래퍼, 삭제 전 정리, 상태 판정(공식 무선 모드·훅·프로젝션 AP·Wi-Fi 부품), [지금 재부팅] 요청, USB 설치기, 지우기(HMG-API를 먼저 지운 경우 포함), 상태 화면 앱의 `ReportTest`, 정적 검사. `HMGAPI_SRC`에 HMG-API 소스를 주면 빌드와 HMG-API 엔진(PC) 설치·계획·지우기, 차종 제한(NX4.KOR 260902만)까지 봅니다. 이 모드는 HMG-API 1.1.0-rc.8 이상을 요구하므로 `HMGAPI_SRC`도 v1.1.0-rc.8 이상이어야 합니다(낮으면 엔진이 설치를 거절하고 테스트가 실패로 알림).
- 에뮬레이터: 상태 화면 앱을 1920x720 에뮬레이터에 띄워 상태별 화면과 [지금 재부팅] 흐름을 봅니다. 준비와 순서는 [`docs/emulator-test.md`](docs/emulator-test.md).

## 라이선스

[GNU AGPL-3.0](LICENSE). 원본, HMG-API와 같은 라이선스입니다. 제조사 파일은 넣지 않습니다.

- 다른 프로젝트에서 가져온 부분과 원저작권, 이 저장소에서 바꾼 것은 [`NOTICE.md`](NOTICE.md)에 있습니다.
- 모드에 함께 넣는 `bin/busybox`는 별개 프로그램이며 **GPL-2.0**입니다. 출처와 대응 소스는 [`NOTICE.md`](NOTICE.md#busybox-gpl-20)에 있습니다.

## 바탕이 된 프로젝트

- [Korea Projection](https://github.com/StopDragon/korea-projection) — StopDragon (원본)
- [HMG-API](https://github.com/Open-HMG/HMG-API) — VysseCodes
- [Wireless CarPlay + Android Auto](https://github.com/Open-HMG/hmgapi-wireless-cp-aa) — VysseCodes (HMG-API 공식 무선 모드. 2.1.0은 이것을 고치지 않고 따로 설치해 씀)
