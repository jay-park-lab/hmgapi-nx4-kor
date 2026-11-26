> 🧪 **실험 중인 프로젝트입니다.** 일반 차주가 쓰기를 권하지 않습니다.
> - **2.1.1을 정식으로 냈습니다**(2026-11-26, [릴리스](https://github.com/jay-park-lab/hmgapi-nx4-kor/releases/tag/v2.1.1)). 2.1.0에 HMG-API 1.1.0-rc.10과 NEMESIS 1.17 경고를 더한 판입니다. 구조는 아래 "[2.1.0 구조](#210-구조)"를 보세요([#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38)).
> - 2.1.0은 2026-11-25에 태그(`v2.1.0`)만 달렸고 릴리스 묶음은 없습니다. 묶음을 만들기 전에 HMG-API가 rc.8 릴리스를 지워, 빌드가 HMG-API USB 묶음을 받지 못하고 멈췄습니다(배포 키는 쓰이지 않음).
> - 2.0.x는 정식으로 내지 않고 끝냈습니다. 베타 묶음(`v2.0.0-beta.*`~`v2.0.4-beta.1`)은 릴리스에 그대로 둡니다.
> - **무선 카플레이·안드로이드 오토는 차에서 아직 확인하지 못했습니다.** 테스트한 차(NX4HEV 260902)는 내비에 Wi-Fi 칩이 없습니다. USB Wi-Fi 동글 지원은 2.2.0에서 합니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48), [#60](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/60)).
> - 구성, 설치 방법, 판 번호가 예고 없이 바뀔 수 있습니다.
> - ⚠️ **NEMESIS 1.17이 깔린 차에서는 HMG-API를 1.1.0-rc.10 이상으로 올리기 전에 지우지 마세요**([Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397)).
>   - rc.8 이하를 지우면 재부팅 한두 번 뒤 Android가 뜨지 않을 수 있습니다.
>   - 2.1.0 안내대로 `HMGAPI/FORCE`로 HMG-API를 설치한 NEMESIS 1.17 차는 **1.1.0-rc.9로 올리면** Android가 뜨지 않습니다.
>   - 어느 쪽이든 HMG-API 릴리스(NEMESIS Manager로 넣는 `hmgapi-<판>-nemesis.zip`, USB 묶음 `hmgapi-<판>-usb.zip`, update zip)로 HMG-API 1.1.0-rc.10 이상으로 먼저 올립니다. 이 저장소의 USB는 쓰지 않습니다(2.1.2 이후는 멈추고, 2.1.1 이전은 HMG-API를 올린 뒤 NX4 KOR까지 설치함, [#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)). 아래 "[HMG-API를 지울 때](#hmg-api를-지울-때)".

## 2.1.0 구조

2.1.0은 다음 셋으로 됩니다.
- **HMG-API**(1.1.0-rc.10 이상. 2.1.0은 rc.8 이상이었고 2.1.1에서 올림)
- **공식 무선 모드**([Open-HMG/hmgapi-wireless-cp-aa](https://github.com/Open-HMG/hmgapi-wireless-cp-aa) 2.2.0-rc.9 이상): 고치지 않고, NX4에는 HMG-API의 "Install anyway"(`--any-car`)로 넣습니다.
- **이 저장소의 NX4 추가분**

| 일 | 맡는 곳 |
|---|---|
| 무선 카플레이·안드로이드 오토 훅, 계기판·HUD 길안내 | 공식 무선 모드. 카플레이 계기판·HUD 길안내는 이 저장소의 모드가 한국 차에 맞춰 덮어씁니다(Korea Projection·HMG-Seogaemo 보정, [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67)). 공식 모드와 같은 훅 지점은 `change`·`observe`로만 겁니다(`replace` 둘은 함께 켜지지 않음, [#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)). 그 밖의 한국 맞춤도 이 저장소의 모드에 넣습니다([#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64)) |
| 핫스팟(프로젝션 AP), 순정 핫스팟 기능 | HMG-API(공식 모드가 `"wifi": {"projection": true}`로 요청) |
| HMG-API 설치·업데이트, 공식 모드 설치, NX4 map 만들기·확인, 진단, 되돌리기(옛 NX4 KOR 2.0.x 정리 포함. 2.0.x는 공식 모드와 함께 설 수 없음, `conflicts`) | 이 저장소의 USB 설치기 |
| 설치 진행·판정 화면 | 이 저장소의 관리 앱. 지금 UI를 그대로 둡니다(지우기 버튼은 두지 않음, [#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)) |
| USB Wi-Fi 동글 | 이 저장소(2.2.0, [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)). Wi-Fi 부품이 없는 차를 위한 길 |

- 뺀 것: 한국 포크 무선 모드 2.4.5(`hooks.jar`·레시피·`libleafiaaac.so`·`patches.json`·`settings.json`과 저장소의 `wireless/`), 순정 칩용 핫스팟 서비스(서비스 `ap`, `svc/hotspot.sh`의 핫스팟·칩 깨우기·Wi-Fi 잠금·자동 설정). `nx4-kor` 모드에는 관리 앱과 그 서비스가 남았고, 한국 카플레이 길안내 훅을 더했습니다(아래 "무엇을 하나", [#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67)).
- 판 번호: 베타는 판에 꼬리를 붙이고(`2.1.0-beta.1`~`2.1.0-beta.3`), 정식에서 뗍니다([`docs/git-flow.md`](docs/git-flow.md) 규칙 4).

**차에서 본 것**(2026-11-25, 2.1.0-beta.3, NX4HEV 260902, [#23 기록](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23#issuecomment-7157758896))
- 동작함: USB 설치기(HMG-API rc.7에서 rc.8로 올리기, 옛 2.0.x 되돌리기, 공식 무선 모드 설치), map 확인(훅 지점 393/393), 적용, 관리 앱과 [지금 재부팅], 재부팅 뒤 HMG-API 훅과 공식 모드 훅 켜짐, 진단 기록.
- 이 차는 Wi-Fi 부품이 없습니다. 관리 앱 판정은 "켜는 중"(`apwait`) 뒤 "부품 없음"(`nowifipart`)으로 바뀌었고, HMG-API도 칩이 없다고 봅니다(`wifi_chip=false`). 그래서 무선은 동글로 확인합니다.

이 저장소는 [StopDragon/korea-projection](https://github.com/StopDragon/korea-projection)의 포크입니다. 원본과 다른 점은 다음과 같습니다.

- **HMG-API와 공식 무선 모드 위에 관리 앱을 얹습니다.** 원본은 NEMESIS 패키지이고, 한국 차 빌드 무선 모드(`wireless-carplay-aa`)를 HMG-API에 따로 설치합니다. 이 저장소의 2.1.0은 무선을 HMG-API와 공식 무선 모드(고치지 않음)에 맡기고, HMG-API 모드 `nx4-kor`에는 관리 앱만 담습니다. Engineering Mode의 USB 설치(DSP Update OTA)로 설치·업데이트·삭제합니다.
- **투싼 NX4 전용입니다.** 다른 차의 map·패치 세트·차 목록을 뺐습니다.
- **HMG-API 1.1.0-rc.10 이상에 맞췄습니다**(2.1.1부터). 공식 무선 모드 2.2.0-rc.9는 rc.8 이상을 요구하지만, 두 가지 까닭으로 올렸습니다([Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397)).
  - rc.8 이하는 NEMESIS 1.17에서 지우면 Android가 뜨지 않을 수 있습니다.
  - rc.9는 `FORCE`로 설치한 NEMESIS 1.17 차를 올리면 Android가 뜨지 않습니다.
- **이 차의 map은 HMG-API가 차에서 만들어** `state/local-map.json`에 둡니다.
- **제보 기능을 뺐습니다.** 제보 파일, QR, 이슈 자동 분류가 없습니다.
- **무선은 차에서 아직 확인하지 못했습니다**(위 "차에서 본 것"). 묶음은 [릴리스](https://github.com/jay-park-lab/hmgapi-nx4-kor/releases)에 있고, 직접 만들 수도 있습니다([만들기와 시험](#만들기와-시험)).

> ⚠️ 차량 소프트웨어를 바꾸는 일입니다. 모든 책임은 설치하신 차주 본인에게 있습니다.

## 무엇을 하나

한국 현대·기아 내비(Gen5W 헤드유닛)는 Wi-Fi 칩을 켜지 않아 무선 카플레이와 무선 안드로이드 오토를 쓸 수 없습니다. 2.1.0에서는 HMG-API가 순정 핫스팟 기능을 켜고 무선 연결용 Wi-Fi(프로젝션 AP)를 띄우며, 공식 무선 모드가 무선 카플레이·안드로이드 오토 훅과 계기판·HUD 길안내를 겁니다. NX4 KOR는 이 차에 그것들을 넣고(USB 설치기) 제대로 됐는지 보여 주며(관리 앱), 카플레이 계기판 길안내를 한국 차에 맞춥니다(한국 카플레이 길안내).

| 구성 | 내용 |
|---|---|
| HMG-API(1.1.0-rc.10 이상) | 훅, 이 차의 map, 순정 핫스팟 기능, 프로젝션 AP |
| 공식 무선 모드 `wireless-carplay-aa`(2.2.0-rc.9 이상) | 무선 카플레이·안드로이드 오토, 계기판·HUD 길안내. 고치지 않고 NX4에는 "Install anyway"(`--any-car`)로 넣습니다 |
| HMG-API 모드 `nx4-kor` | 관리 앱과 서비스 `launch`(화면이 열릴 때 `bin/status.sh`로 상태 파일을 새로 씀) 하나, 한국 카플레이 길안내 훅(`hooks.jar`, DiPO 안에서만). 시스템 파일·Wi-Fi 설정을 바꾸지 않습니다 |
| 한국 카플레이 길안내 | 공식 무선 모드는 카플레이 안내 중 자기 아이콘 표에 없는 것(차선 유지, 각도 없는 "약간 좌회전" 등)을 계기판에 보내지 않아, 앞 안내(예: 좌회전 0 m)에서 멈출 수 있습니다. 이 모드가 Korea Projection의 보정(HMG-Seogaemo 차선 그림 포함)으로 모든 안내에 화살표를 주고 1초마다 다시 보내, 공식 모드가 보내는 값을 그것으로 바꿉니다([#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67), [`docs/design.md`](docs/design.md) "한국 카플레이 길안내") |
| 관리 앱 | "NX4 KOR"(`io.github.jayparklab.nx4kor`). 앱 메뉴에 타일이 생깁니다 |
| USB 설치기 | `usb/troubleShooter` |

| 이름 | 값 |
|---|---|
| HMG-API 모드 id | `nx4-kor` (HMG-API 앱 목록 이름 "NX4 KOR: Tucson NX4 (Korea)") |
| 관리 앱 | "NX4 KOR", 패키지 `io.github.jayparklab.nx4kor` |
| USB 폴더 | `NX4/` |
| 차 안 기록 | `/data/nx4-kor` (관리 앱 감시자 기록 `logs/ap.log`) |
| 차 안 작업 폴더·상태 파일 | `/data/local/tmp/nx4-kor`, `/data/local/tmp/nx4-kor-*.txt` |

설계와 차에서 확인할 것은 [`docs/design.md`](docs/design.md)에 있습니다.

## 대상 차

**투싼 NX4**만 받습니다. 가솔린(`NX4`)과 하이브리드(`NX4HEV`), 한국 내비 소프트웨어 260902(`NX4….KOR.….260902`)입니다. 다른 차와 다른 소프트웨어에는 HMG-API가 설치하지 않습니다.

- 원본(Korea Projection)에서는 두 차 모두 무선 연결이 확인됐습니다([#125](https://github.com/StopDragon/korea-projection/issues/125), [#126](https://github.com/StopDragon/korea-projection/issues/126)). 다만 같은 판에서도 Wi-Fi 부품이 없는 차가 있습니다(2026-11-23 NX4HEV 260902, [#38](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/38)). 그런 차에서는 관리 앱이 "Wi-Fi 부품이 없는 것으로 보여…"를 보이고, 무선은 USB Wi-Fi 동글([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48))을 기다립니다. 유선 카플레이·안드로이드 오토와 계기판 길안내는 그대로 씁니다.
- NX4 map은 HMG-API에도 이 모드에도 없습니다. HMG-API가 그 차의 파일로 map을 만들고(`engine map-car --write`) 차에서 확인한(`verify-map`) 뒤에만 훅이 켜집니다. 공식 무선 모드의 차 목록에도 NX4가 없어 "Install anyway"(`--any-car`)로 넣습니다.

## 필요한 것

- **USB 묶음** `hmgapi-nx4-kor-버전-usb.zip`: 이 저장소의 [릴리스](https://github.com/jay-park-lab/hmgapi-nx4-kor/releases)에서 받습니다. 직접 만들려면 [만들기와 시험](#만들기와-시험).
  - 2.1.0부터 **HMG-API**와 **공식 무선 모드** `wireless-carplay-aa`(2.2.0-rc.9, 공식 릴리스 파일 그대로)가 함께 들어 있어, HMG-API가 없는 차도 이 USB 하나로 설치합니다. 함께 넣은 HMG-API는 2.1.1이 1.1.0-rc.10, 2.1.0이 rc.8입니다. 2.1.0 묶음의 rc.8은 NEMESIS 1.17이 먼저 깔린 차에 설치되지 않습니다("isn't a known stock build"). 2.1.2부터는 NEMESIS가 깔린 차에 아무것도 설치하지 않습니다([#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75), 아래 "알아 두실 점").
  - 2.0.x 베타 묶음: `v2.0.0-beta.3`부터 HMG-API(1.1.0-rc.7)가 들어 있고 공식 무선 모드는 없습니다. `v2.0.0-beta.1`에는 HMG-API도 없습니다. `v2.0.0-beta.2`는 빌드가 멈춰 릴리스가 없습니다.
- **HMG-API는 1.1.0-rc.10 이상**이어야 합니다(2.1.1부터. USB 설치기와 이 모드가 요구). 이미 있는 HMG-API가 이보다 낮으면(2.1.0을 쓰던 차의 rc.8, rc.9 포함) USB 묶음의 HMG-API로 먼저 올립니다(아래 "설치" 2).
  - rc.10으로 올리는 업데이트는 NEMESIS 1.17에서도 안전합니다. 예전에 `FORCE`로 설치한 차도 rc.10이 NEMESIS가 남긴 순정 파일로 다시 설치합니다.
  - 다만 2.1.2부터 USB 설치기는 **NEMESIS가 깔린 차에서 아무것도 하지 않습니다**(HMG-API도 올리지 않음, 아래 "알아 두실 점", [#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)). 그런 차에서 HMG-API를 올리거나 다시 설치할 때는 HMG-API [릴리스](https://github.com/Open-HMG/HMG-API/releases)의 NEMESIS용 묶음(`hmgapi-<판>-nemesis.zip`, NEMESIS Manager의 Package Store), USB 묶음(`hmgapi-<판>-usb.zip`)이나 update zip(HMG-API 앱 "Check USB updates")을 씁니다(1.1.0-rc.10 이상). 2.1.1 이전의 이 저장소 USB도 쓰지 않습니다(HMG-API를 올린 뒤 NX4 KOR까지 설치함).
  - 그런 차를 1.1.0-rc.9로 올리면 안 됩니다(HMG-API 1.1.0-rc.10 릴리스 노트).
- 무선을 쓰려면 내비에 Wi-Fi 부품이 있어야 합니다. 2026-11-23과 11-25에 본 NX4HEV는 부품이 없었습니다(위 "차에서 본 것").
- FAT32로 포맷한 USB(32GB 이하 권장).

## 설치

1. `hmgapi-nx4-kor-버전-usb.zip`을 빈 USB 맨 위에 풉니다.
   ```
   USB
   ├─ ota_package.tar          NX4 KOR 설치기
   ├─ README.txt, LICENSE, NOTICE.md, WIRELESS-SOURCE.txt, HMGAPI-README.txt, HMGAPI-SOURCE.txt
   ├─ HMGAPI                   HMG-API(설치 payload)
   └─ NX4
       ├─ install              NX4 KOR(hmgapi-nx4-kor.zip, payload)
       ├─ wireless             공식 무선 모드(wireless-carplay-aa.zip, mod.json)
       ├─ legacy-2.0           옛 NX4 KOR 2.0.x 되돌리기 스크립트(v2.0.4-beta.1에서 그대로)
       └─ hmgapi               HMG-API 설치기
   ```
2. 시동을 건 채 차를 세우고 USB를 꽂은 뒤 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다.
   - **NEMESIS가 깔린 차:** "NEMESIS가 깔린 차에는 NX4 KOR를 설치하지 않습니다"가 나오고 아무것도 바꾸지 않습니다(HMG-API 설치 전에 멈춤). 아래 "알아 두실 점".
   - **NEMESIS에 Korea Projection이 있는 차:** "NEMESIS에 Korea Projection이 설치되어 있어 설치하지 않았습니다"가 나오고 아무것도 바꾸지 않습니다(HMG-API 설치 전에 멈춤). NEMESIS에서 Korea Projection을 지우고 내비를 재부팅한 뒤 다시 누릅니다. 아래 "알아 두실 점".
   - **HMG-API가 없는 차:** "NX4 KOR: HMG-API를 먼저 설치합니다"가 나오고 HMG-API가 설치된 뒤 재부팅됩니다. 부팅이 끝나면 바로 **같은 USB로 Update OTA를 한 번 더** 눌러도 됩니다. 설치기가 HMG-API가 준비될 때까지 스스로 기다립니다(최대 약 5분, "HMG-API가 준비되기를 기다리는 중입니다" 토스트).
   - **HMG-API가 1.1.0-rc.10보다 낮은 차**(2.1.0을 쓰던 rc.8 차, rc.9 차 포함)**:** "NX4 KOR: HMG-API를 …에서 …(으)로 먼저 올립니다"가 나오고 HMG-API가 업데이트된 뒤 재부팅됩니다. 위와 같이 한 번 더 누릅니다. USB에 HMG-API가 없으면 아무것도 바꾸지 않고 멈춥니다.
   - **HMG-API 1.1.0-rc.10 이상인 차:** 바로 아래 3으로 갑니다.
   - USB의 `HMGAPI/install.log`에 `isn't a known stock build`가 있으면, HMG-API가 이 차의 소프트웨어 판(`app_process`)을 아직 확인하지 않은 것입니다. 아무것도 바뀌지 않았습니다.
     - 1.1.0-rc.10부터는 `HMGAPI/FORCE`로 넘길 수 없습니다. [HMG-API 이슈](https://github.com/Open-HMG/HMG-API/issues/new/choose)에 그 줄과 차, 내비 소프트웨어 판을 올리면 HMG-API가 그 판을 더합니다.
     - 투싼 하이브리드(NX4HEV) 260902의 순정 `app_process`는 HMG-API가 아는 판입니다(2026-11-21 차에서 `FORCE` 없이 설치, [#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23)).
     - 가솔린·디젤 NX4가 같은 파일인지는 아직 모릅니다. HMG-API rc.10은 현대 한국 260902 이미지(HMC KOR)를 아직 확인하지 않은 것으로 적습니다(`install/common/stock.txt`). 그런 차에서 이 문구가 나와도 차가 순정이 아니라는 뜻은 아니니, 위와 같이 HMG-API 이슈에 올립니다.
     - 2.1.0 묶음(rc.8)은 NEMESIS 1.17의 스크립트를 몰라 이 문구로 거절했고, 이 README는 그때 `FORCE`를 쓰라고 안내했습니다. 그렇게 설치한 차는 1.1.0-rc.9로 올리지 마세요. HMG-API rc.10이 NEMESIS가 남긴 순정 파일로 다시 설치해 고칩니다([#397](https://github.com/Open-HMG/HMG-API/issues/397)). NEMESIS가 깔린 차이므로 HMG-API 릴리스(NEMESIS Manager로 넣는 `hmgapi-<판>-nemesis.zip`, USB 묶음 `hmgapi-<판>-usb.zip`, update zip)로 올립니다(1.1.0-rc.10 이상). 이 저장소의 USB는 쓰지 않습니다(2.1.2 이후는 멈추고, 2.1.1 이전은 HMG-API를 올린 뒤 NX4 KOR까지 설치함, [#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)).
   - `… is HMG-API's wrapper but its stock copy (app_process.hmgapi-stock) is gone …`이나 `… stock copy HMG-API's wrapper runs, is …`가 있으면 예전 HMG-API 삭제나 `FORCE` 설치가 남긴 상태입니다. 아무것도 바뀌지 않았습니다. **재부팅하지 말고** [`docs/troubleshooting.md`](docs/troubleshooting.md) "HMG-API를 지운 뒤 Android가 뜨지 않을 때"와 [#397](https://github.com/Open-HMG/HMG-API/issues/397)을 봅니다.
   - HMG-API 앱의 "Check USB updates"로 모드를 넣는 HMG-API 문서의 방법은 처음에는 쓸 수 없습니다. HMG-API에 NX4 map이 없어 HMG-API 앱 타일이 생기지 않기 때문입니다. 이 USB 설치기가 map을 만들어 줍니다.
3. 설치기가 차례로 합니다. OTA 화면의 오류 684는 정상입니다. 모두 **3~5분** 걸리니 그동안 USB를 빼거나 끄지 마세요. 부팅 직후에 눌렀으면 HMG-API가 준비되기를 먼저 기다리고, 끝에 재부팅을 안내하기 전에 켜진 지 2분 남짓이 될 때까지(HMG-API 부팅 보호) 기다릴 수 있습니다.
   - HMG-API 앱에 다른 모드의 적용하지 않은 변경이 있으면 아무것도 바꾸지 않고 멈춥니다. HMG-API 앱에서 먼저 적용한 뒤 다시 누릅니다.
   - 옛 NX4 KOR 2.0.x가 있으면 먼저 끝까지 되돌립니다(Wi-Fi 잠금·순정 핫스팟 저장값·무선 권한 파일 포함). 2.0.x는 공식 무선 모드와 함께 쓸 수 없습니다.
   - 2.0.x를 HMG-API 앱에서 먼저 지운 차(모드 폴더 없이 `/data/nx4-kor/backup`만 남음)나 2.0.x 위에 2.1.0 이후를 adb 등으로 넣은 차(`backup`이 남음)도, USB에 함께 든 2.0.x의 되돌리기 스크립트(`NX4/legacy-2.0`, `v2.0.4-beta.1`에서 그대로)로 남은 설정을 되돌립니다.
   - **공식 무선 모드**를 설치합니다. NX4는 공식 모드의 차 목록에 없어 HMG-API의 "Install anyway"(`--any-car`)로 넣습니다. 이미 같거나 높은 판이 있으면 그대로 둡니다. Korea Projection의 한국 차 빌드(같은 이름 `wireless-carplay-aa`)는 공식판으로 바꿉니다.
   - NX4 KOR를 설치하고 관리 앱을 엽니다. 남은 진행은 관리 앱에 막대로 보입니다.
   - 처음에는 HMG-API가 이 차의 map을 만들고(1~2분) 확인합니다.
   - 바꿀 것이 NX4 KOR와 공식 무선 모드의 것뿐이면 적용합니다.
4. "무선 카플레이 설정을 마쳤습니다"가 나오면 **[지금 재부팅]**을 누릅니다(또는 RESET 버튼). 시동만 끄면 내비가 꺼지지 않을 수 있습니다.
5. 폰에서 무선 카플레이(또는 무선 안드로이드 오토)를 연결합니다.

- **업데이트:** 새 판 USB로 같은 방법으로 합니다. 같은 판이면 다시 설치하지 않고 map 확인과 적용할 것만 봅니다("설정이 끝나 있습니다"). 같은 판을 다시 설치하려면 `NX4/REINSTALL` 빈 파일을 만듭니다(같은 판의 공식 무선 모드도 다시 설치).
- **차주가 넣은 공식 무선 모드:** 같거나 높은 판이면 그대로 쓰고, 낮으면 USB의 판으로 올립니다. 꺼 두었으면 켭니다.
- **진단 기록:** 관리 앱이 있으면 누를 때마다 설치기가 먼저 "진단 기록 모으기" 확인 창을 띄웁니다. [모으기]를 고르면 아무것도 바꾸기 전에 내비의 기록, HMG-API Car Report, `/system/lib` 파일의 이름·md5, USB Wi-Fi 동글 드라이버를 만드는 데 쓸 커널 설정과 USB 장치 목록([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48))을 USB의 `NX4/diag/<시각>/`에 모읍니다(1~2분, 그동안 USB를 빼지 마세요). [건너뛰기]를 고르거나 60초 동안 고르지 않으면 모으지 않고 이어집니다. 담는 것은 [`docs/design.md`](docs/design.md) "진단 기록"에 있습니다.
- USB를 꽂아 둔 채로 두면 유선 안드로이드 오토가 시작되어 무선이 붙지 않을 수 있습니다. 끝나면 빼 주세요.
- **문제가 생기면:** 설치기와 관리 앱의 문구별 할 일, 부팅 보호, 되돌리는 길은 [`docs/troubleshooting.md`](docs/troubleshooting.md)에 있습니다.

## 상태 확인

- **앱 메뉴의 NX4 KOR 타일**을 누릅니다. 타일은 HMG-API 훅이 켜진 뒤(이 차의 map 확인 뒤 재부팅)에 생깁니다.
- 타일이 없을 때는 설치 USB로 Update OTA를 다시 누릅니다. 다시 설치하지 않고 **관리 앱만 엽니다.** HMG-API 훅이 꺼진 동안(map이 없거나 부팅 보호)에는 타일이 없습니다.
- 화면이 열릴 때 상태를 새로 씁니다. 읽기만 하고 차의 설정은 바꾸지 않습니다.

관리 앱은 순정 내비 설정 화면을 본뜬 모양입니다. 왼쪽 위 `<`를 누르면 닫힙니다.
- 오른쪽 칸의 판정: 준비됨·연결됨이면 시안 글자(띠 없음), 확인이 필요하면 노란 띠, 문제면 빨간 띠입니다. 판정은 HMG-API 판, 공식 무선 모드(설치·켜짐·판·훅), HMG-API 훅(map), 프로젝션 AP, Wi-Fi 부품을 차례로 봅니다. 판정 코드별 뜻은 [`docs/design.md`](docs/design.md) "관리 앱".
- 왼쪽 칸: 요약 3줄(설치 / 무선 Wi-Fi / 폰 연결)과 그 아래 자세한 상태표.
- 오른쪽 칸 판정 아래의 노란 띠: 설치 중 안내와 알림.
- **[지금 재부팅]**(오른쪽 칸 맨 아래): 차를 세운 상태에서만 누르세요. 켜진 지 2분이 안 돼 재부팅되거나 꺼지는 일이 6번 이어지면 HMG-API가 훅을 끄므로, 그 횟수에 가까우면 켜진 지 3~5분이 될 때까지 막힙니다. 재부팅한 뒤에는 3분 넘게 켜 두세요.

더 자세한 기록은 HMG-API 쪽에 있습니다: 프로젝션 AP는 `/data/hmgapi/logs/hmgapi/wifi.log`, 모드·훅은 HMG-API 앱의 Logs 탭. adb가 없으면 설치 USB로 Update OTA를 누르고 확인 창에서 [모으기]를 고르면 USB의 `NX4/diag/<시각>/logs/`에 함께 모입니다.

## HMG-API 앱의 설정

NX4 KOR("NX4 KOR: Tucson NX4 (Korea)")의 설정은 둘입니다.

| 설정 | 기본 | 하는 일 |
|---|---|---|
| `kor_tbt` "Korean CarPlay turn-by-turn on the cluster and HUD" | 켬 | 한국 카플레이 길안내(위 "무엇을 하나"). 끄면 공식 무선 모드의 길안내 그대로입니다 |
| `kor_tbt_log` "Log the CarPlay turn-by-turn diagnosis" | 끔(2.1.2-beta.2부터, [#77](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/77)) | Korea Projection의 진단 줄(곧 회전 판단, 계기판에 보낸 값, 차선, 처음 본 길안내 앱 이름)과 보낸 HUD 목록 줄(300줄까지)을 HMG-API 기록에 더 남깁니다. 꺼도 받은 안내의 숫자(종류·각도, 시작마다 300줄까지), 길안내 앱이 바뀐 줄(두 앱 이름), 지운 줄은 남습니다. 길·장소 이름은 어느 쪽이든 남기지 않습니다. 계기판이 이상하게 보였을 때 원인을 찾는 데 씁니다 |

`kor_tbt_log`는 2.1.2-beta.2부터 기본으로 꺼져 있습니다([#77](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/77)). 길안내가 이상할 때 기록을 모으려면 HMG-API 앱의 NX4 KOR 설정에서 켜고 다시 시작합니다. HMG-API 앱은 설정 하나를 바꿀 때 그 모드의 모든 값을 함께 저장하므로, 2.1.2-beta.1까지 NX4 KOR 설정을 바꾼 적이 있으면 이 설정이 켜진 채 남습니다. 그런 차는 HMG-API 앱에서 꺼 주세요.

무선 기능의 설정은 HMG-API 앱의 "Wireless CarPlay + Android Auto"(공식 무선 모드)에 있습니다. 그중 `bridge`(Wireless CarPlay)를 끄면 무선 카플레이가 되지 않고 관리 앱이 `bridgeoff`를 보입니다. 계기판·HUD 길안내는 `tbt`입니다. 한국 카플레이 길안내도 공식 모드의 `tbt`가 켜져 있어야 합니다(아이폰에 길안내를 받는다고 알리고, 순정 내비가 계기판에 끼어드는 것을 막는 일은 공식 모드가 합니다). 설정을 바꾼 뒤에는 HMG-API 앱에서 변경 사항을 적용하고 재부팅합니다.

2.0.x의 `nx4-kor` 설정(`tbt_fit`, `aa_ready_resend`, `aa_name_hold`, `star_popup_skip` 등 한국 포크 기능)은 없어졌습니다. `tbt_fit`에 해당하는 카플레이 보정은 `kor_tbt`로 다시 넣었고([#67](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/67)), 나머지를 이 모드에 넣을지는 [#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64)에서 정합니다.

## 알아 두실 점

- 설치 뒤 약 5분 동안 재부팅하지 마세요.
- **NEMESIS가 깔린 차에는 설치하지 않습니다**(2.1.2부터, [#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75), 2026-11-26 결정). 이 모드는 차 순정 시스템에 부하를 덜 주는 것을 목표로 하므로 NEMESIS와 함께 쓰지 않습니다.
  - USB 설치기는 `/system/xbin/nemesis`가 있으면(HMG-API가 NEMESIS를 알아보는 기준과 같음) 새 설치·업데이트·같은 판 다시 설치를 하지 않고 멈춥니다("NEMESIS가 깔린 차에는 NX4 KOR를 설치하지 않습니다", 아무것도 바꾸지 않음). HMG-API도 설치·업데이트하지 않습니다. USB 지우기(`UNINSTALL`)는 막지 않습니다.
  - 쓰려면 NEMESIS를 지우고 내비를 재부팅한 뒤 다시 누릅니다. HMG-API가 있으면 지우지 말고 둔 채 NEMESIS를 지웁니다(아래 "HMG-API를 지울 때"). 그 HMG-API가 1.1.0-rc.10보다 낮으면 NEMESIS를 지우기 전에 HMG-API 릴리스(NEMESIS Manager로 넣는 `hmgapi-<판>-nemesis.zip`, USB 묶음 `hmgapi-<판>-usb.zip`, update zip)로 rc.10 이상으로 올리고 두 번 재부팅합니다. `FORCE`로 설치한 NEMESIS 1.17 차는 반드시 이렇게 합니다(rc.9를 거치지 않음, HMG-API 1.1.0-rc.10 릴리스 노트, [#397](https://github.com/Open-HMG/HMG-API/issues/397)). 이 저장소의 USB는 쓰지 않습니다(2.1.2 이후는 멈추고, 2.1.1 이전은 HMG-API를 올린 뒤 NX4 KOR까지 설치함, [#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)). Android가 뜨지 않는 차에서는 NEMESIS를 지우지 마세요.
  - HMG-API 앱으로 모드 zip을 직접 넣었거나 이미 NEMESIS와 함께 쓰던 차에서 관리 앱과 길안내가 멈추지는 않습니다. 업데이트만 받지 못합니다.
- **NEMESIS로 Korea Projection이나 다른 무선·핫스팟 패키지를 설치해 두었다면 먼저 지우세요.** 함께 두면 HMG-API의 프로젝션 AP와 Wi-Fi를 다툽니다(관리 앱 판정 `otherwifi`). 그중 Korea Projection이 있으면 USB 설치기가 설치·업데이트를 하지 않고 멈춥니다("NEMESIS에 Korea Projection이 설치되어 있어 설치하지 않았습니다", 아무것도 바꾸지 않음). NEMESIS에서 Korea Projection을 지우고 내비를 재부팅한 뒤 다시 누릅니다. 다른 NEMESIS 패키지와 USB 지우기(`UNINSTALL`)는 막지 않습니다([#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13)). 공식 무선 모드와 같은 훅을 `replace`로 거는 다른 HMG-API 모드와도 함께 켤 수 없습니다([#17](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/17)). 자세한 것은 [`docs/design.md`](docs/design.md) "다른 패키지·모드와 함께 쓸 때".
- 프로젝션 AP가 켜져 있는 동안에는 내비가 휴대폰 핫스팟(일반 Wi-Fi)에 붙을 수 없습니다. Wi-Fi 칩 하나가 AP 역할을 하기 때문입니다. HMG-API 앱의 "집 Wi-Fi"(Home Wi-Fi)를 켜면 주차한 동안만 HMG-API가 AP를 끄고 집 Wi-Fi에 붙습니다.
- **계기판·HUD 길안내의 한계:** 공식 무선 모드가 폰의 지도 앱이 보내 주는 정보(다음 회전의 종류·방향·남은 거리·도로 이름)까지만 보내서 순정 내비와 똑같지 않습니다. 지하차도·고가차도 구분, 일부 갈림길·회전교차로 모양, 방면 표시는 다르거나 나오지 않을 수 있고, 지도 앱마다 보내는 정보가 다릅니다.
- **map이 생기기 전(훅이 꺼진 동안)에는 HMG-API가 순정 OTA 업데이트를 막지 못합니다.** 펌웨어가 업데이트되면 HMG-API의 시스템 파일이 지워지니, 그때는 HMG-API부터 다시 설치합니다.

## 삭제

> ⚠️ HMG-API까지 지우려면 먼저 아래 "[HMG-API를 지울 때](#hmg-api를-지울-때)"를 보세요. NEMESIS 1.17이 깔린 차에서 HMG-API를 1.1.0-rc.10보다 낮은 판으로 지우면 Android가 뜨지 않을 수 있습니다.

설치 USB의 `NX4` 폴더에 빈 파일 `UNINSTALL`을 만들고 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다. NX4 KOR(`nx4-kor`)를 지운 뒤 재부팅합니다. **HMG-API, 공식 무선 모드, 이 차의 map(`state/local-map.json`)은 남깁니다.**
- 관리 앱의 감시자를 멈추고 관리 앱의 작업 파일(`/data/local/tmp/nx4-kor*`)을 지웁니다. USB 설치기 자신의 기록(`/data/local/tmp/nx4-kor-usb.log`, 차에서는 `nx4-kor-ota-finish.sh`도)은 남깁니다.
- HMG-API에서 이 모드를 지웁니다(`engine remove`). HMG-API가 관리 앱과 서비스를 내립니다. 2.1.0의 이 모드는 시스템 파일·Wi-Fi 설정을 바꾸지 않아 적용할 것이 없습니다.
- 기록 폴더(`/data/nx4-kor`)를 지웁니다.
- 2.0.x를 쓰던 차는 2.0.x가 바꾼 것(그 판이 켠 핫스팟과 DHCP, 잠갔던 Wi-Fi 설정 파일의 소유자·권한, 순정 핫스팟 저장값, 무선 권한 파일)도 되돌립니다. 설치기가 HMG-API에서 그 판을 빼고 되돌리기만 적용한 뒤 그 판 자신의 삭제(`bin/uninstall.sh`)를 사본으로 돌립니다. 설치 전에 Wi-Fi가 꺼져 있던 차는 다시 끕니다. 계획에 다른 모드의 변경이 섞여 있으면 적용하지 않고 HMG-API 앱에서 적용하라고 안내합니다.

**공식 무선 모드도 지우려면** `UNINSTALL` 대신 `UNINSTALL-ALL`을 만듭니다. NX4 KOR를 지운 뒤 공식 무선 모드도 HMG-API에서 지우고, 계획이 되돌리기뿐이면 적용합니다. 공식 무선 모드만 남은 차에서도 됩니다. HMG-API와 map은 남깁니다.

주의할 점:
- **HMG-API 앱에서 모드만 지우거나 HMG-API를 먼저 지운 경우:** 2.1.0 이후는 관리 앱·서비스가 HMG-API와 함께 내려갑니다. HMG-API 앱에서 모드만 지우면 기록 파일만 남습니다(`engine remove`가 모드 폴더를 지움). HMG-API를 먼저 지우면 일반 삭제(`HMGAPI/UNINSTALL`)는 모드 폴더, 꺼 둔 관리 앱, 기록 파일을 남기고, `HMGAPI/UNINSTALL-PURGE`는 기록 파일만 남깁니다. 2.0.x는 Wi-Fi 설정 파일 잠금·순정 핫스팟 저장값·권한 파일이 그대로 남습니다(HMG-API 삭제는 HMG-API를 통해 바꾼 것만 되돌림). 어느 쪽이든 USB `UNINSTALL`을 하면 됩니다. HMG-API가 없어도 남은 모드 폴더나 USB의 사본으로 되돌리고, 남은 모드 폴더와 관리 앱도 지웁니다. NEMESIS 1.17이 깔린 차에서 rc.8 이하를 지웠다면 그보다 먼저 아래 "HMG-API를 지울 때"의 "이미 지웠다면"을 봅니다.
  - 2.0.x를 HMG-API 앱에서 지운 차(모드 폴더 없이 `/data/nx4-kor/backup`만 남음)나 2.0.x 위에 2.1.0 이후를 넣은 차(2.1.0을 지운 뒤 `backup`이 남음)는 USB의 `NX4/legacy-2.0`(2.0.x의 되돌리기 스크립트)으로 되돌립니다. 그 폴더가 없는 USB면 설치기가 기록을 지우지 않고 멈추거나 남겼다고 알리니, 2.0.x 릴리스 USB(`v2.0.4-beta.1`)의 `NX4/UNINSTALL`을 씁니다.
- 둘 다 지울 때는 **NX4 KOR를 먼저, HMG-API를 나중에** 지우세요. NEMESIS 1.17이 깔린 차는 그보다 먼저 HMG-API를 1.1.0-rc.10 이상으로 올립니다(아래 "HMG-API를 지울 때").
- HMG-API 일반 삭제(`HMGAPI/UNINSTALL`)는 모드 파일·설정을 남기고 모드 앱을 꺼 두기만 합니다. 모두 지우려면 `HMGAPI/UNINSTALL-PURGE`를 씁니다. 둘 다 아래 "HMG-API를 지울 때"를 먼저 봅니다.
- 관리 앱에는 지우기 버튼을 두지 않습니다([#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)). 2.1.0 이후는 HMG-API 앱에서 모드를 지워도 기록 파일(`/data/nx4-kor`, `/data/local/tmp/nx4-kor*`)만 남기 때문입니다.
  - 남은 기록은 USB `UNINSTALL`로 정리합니다. USB 설치기 자신의 기록(`nx4-kor-usb.log`, 차에서는 `nx4-kor-ota-finish.sh`도)은 남깁니다.
  - `/data/nx4-kor` 없이 `/data/local/tmp/nx4-kor*`만 남은 차에서는 `UNINSTALL`이 "NX4 KOR 모드가 설치되어 있지 않습니다"로 끝나고 아무것도 지우지 않습니다. 남은 것은 해가 없는 작은 파일입니다.
- 삭제할 때 Wi-Fi를 껐다 켜지 않습니다. 껐다 켜면 Wi-Fi·블루투스 모듈이 다시 시작되어 블루투스 카플레이가 재부팅 전까지 되지 않습니다(원본에서 니로로 확인). 재부팅하면 일반 Wi-Fi가 원래대로 돌아옵니다.

### HMG-API를 지울 때

> ⚠️ **NEMESIS 1.17이 깔린 차에서는 HMG-API를 1.1.0-rc.10 이상으로 올리기 전에 지우지 마세요**([Open-HMG/HMG-API#397](https://github.com/Open-HMG/HMG-API/issues/397)).
> - HMG-API 1.1.0-rc.8 이하를 NEMESIS 1.17에서 지우면 재부팅 한두 번 뒤 Android가 뜨지 않습니다.
> - `HMGAPI/FORCE`로 설치한 NEMESIS 1.17 차는 1.1.0-rc.9로 올리기만 해도 Android가 뜨지 않고, 차에 순정 파일이 남지 않습니다. 그런 차는 rc.9를 거치지 않고 rc.10으로 바로 올립니다.
> - 한번 Android가 뜨지 않으면 차주가 되돌리기 어렵습니다. 미리 켜 둔 adb가 아니면 대리점에 맡겨야 할 수 있습니다(아래 "이미 지웠다면").
> - NEMESIS 1.16 이하나 NEMESIS가 없는 차는 해당하지 않습니다.

- **까닭:**
  - NEMESIS 1.17(LivePatch)은 `/system/bin/app_process`를 자기 스크립트로 바꾸고 `app_process.real`로 Android를 띄웁니다.
  - rc.8 이하의 HMG-API 삭제는 이것을 모릅니다. 순정 파일을 NEMESIS 스크립트 자리(`app_process`)에 되돌리고, 래퍼가 부르는 순정 사본(`app_process.hmgapi-stock`)을 지웁니다.
  - 다음 부팅에 NEMESIS가 스크립트를 다시 씁니다. 그러면 `app_process.real`에 남은 HMG-API 래퍼가 지워진 사본을 불러 Android가 뜨지 않습니다.
  - rc.8 이하는 NEMESIS 1.17이 먼저 깔린 차에 설치를 거절했습니다("isn't a known stock build"). 그때 `FORCE`로 넘기면 NEMESIS의 스크립트를 "순정" 사본으로 저장합니다. 그런 차를 rc.9로 올리면 마지막 순정 파일을 덮어씁니다.
  - rc.9가 삭제를, rc.10이 `FORCE` 설치 차를 고쳤습니다(HMG-API 1.1.0-rc.10 릴리스 노트). rc.9 릴리스는 rc.10이 나오며 지워졌습니다.
- **지울 때 도는 것은 그 HMG-API를 설치(업데이트)할 때 저장해 둔 삭제입니다.** 그래서 새 판 HMG-API USB의 `HMGAPI/UNINSTALL`로 지워도 차에 든 판의 삭제가 돕니다. 반드시 **먼저 올린 뒤** 지웁니다.
  1. HMG-API 판을 봅니다. 관리 앱 "자세히" 표의 HMG-API 칸이나 HMG-API 앱에 나옵니다.
  2. 1.1.0-rc.10보다 낮으면 HMG-API 릴리스의 `hmgapi-<판>-update.zip`을 HMG-API 앱 "Check USB updates"로 넣거나 HMG-API 릴리스의 USB(`hmgapi-<판>-usb.zip`)로 올리고 두 번 재부팅합니다(rc.10 이상, HMG-API 1.1.0-rc.10 릴리스 노트의 NEMESIS 1.17 안내). NEMESIS Manager로 `hmgapi-<판>-nemesis.zip`을 넣어도 됩니다. 이 저장소의 USB는 쓰지 않습니다(2.1.2 이후는 멈추고, 2.1.1 이전은 HMG-API를 올린 뒤 NX4 KOR까지 설치함, [#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)).
  3. 재부팅한 뒤 NX4 KOR를 먼저(위 `UNINSTALL`), HMG-API를 나중에 지웁니다.
- **이미 rc.8 이하를 지웠다면**(#397, [HMG-API 1.1.0-rc.9 릴리스 노트](https://github.com/Open-HMG/HMG-API/blob/v1.1.0-rc.9/.github/release-notes/v1.1.0-rc.9.md)):
  - 지운 뒤 아직 재부팅하지 않았으면, 재부팅하기 전에 HMG-API 1.1.0-rc.10 이상을 새로 설치합니다. HMG-API 릴리스의 USB(`hmgapi-<판>-usb.zip`)로 Update OTA를 누르거나 NEMESIS Manager로 `hmgapi-<판>-nemesis.zip`을 넣습니다. 이 저장소의 USB는 쓰지 않습니다(2.1.2 이후는 멈추고, 2.1.1 이전은 HMG-API를 올린 뒤 NX4 KOR까지 설치함, [#75](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/75)).
  - 한 번 재부팅했고 Android가 아직 뜨는 경우:
    - 일반 삭제(`UNINSTALL`)였으면 위와 같이 바로 새로 설치합니다. HMG-API의 백업에서 순정 파일을 되돌려 놓습니다.
    - `UNINSTALL-PURGE`였으면 백업이 없어 설치가 거절하니 #397을 따릅니다.
  - Android가 이미 뜨지 않으면 #397을 따릅니다. #397의 복구(NEMESIS 비상 USB, adb)는 HMG-API의 백업에서 순정 파일을 `app_process.real`에 되돌립니다.
    - **비상 USB는 아직 차에서 된 적이 없습니다.** 한 차에서는 NEMESIS가 스틱을 돌리지 않았습니다. USB는 Android의 저장소 서비스가 붙이는데, Android가 뜨지 않으면 그 서비스도 돌지 않기 때문입니다.
    - 그래서 미리 켜 둔 adb나 대리점이 남은 길입니다.
    - `FORCE`로 설치한 차를 rc.9로 올려 Android가 뜨지 않게 된 경우에는 이 복구를 쓰지 않습니다. 차에 순정 파일이 남지 않아, 그 차의 순정 펌웨어나 대리점 리플래시가 길입니다(#397).
  - **Android가 뜨지 않는 차에서 NEMESIS를 지우지 마세요.** 고쳐지지 않고, 복구에 쓰는 NEMESIS의 USB 처리와 root도 함께 없어집니다.
- **NEMESIS도 지우는 차:**
  - rc.10으로 올리지 못한다면 **NEMESIS를 먼저, HMG-API를 나중에** 지우는 것도 안전한 차례입니다. #397의 표에서 HMG-API가 아직 있을 때 NEMESIS를 지우는 경우입니다. `FORCE`로 설치한 차는 rc.10으로 먼저 올리는 것이 차례이고(HMG-API 1.1.0-rc.10 릴리스 노트), 올리지 못하면 #397을 먼저 봅니다.
  - 거꾸로 rc.8 이하의 HMG-API를 지우고 재부팅한 뒤 NEMESIS를 지우면, 차주가 고칠 길이 없어 대리점에 맡겨야 할 수 있습니다.

## 만들기와 시험

| 위치 | 내용 |
|---|---|
| `mod/` | HMG-API 모드 그대로: `mod.json`, `settings.json`, 서비스·공용 함수(`svc/`), 상태·삭제(`bin/`), 삭제 전 정리(`scripts/`), 앱 메뉴 타일 그림(`icons/`) |
| `hooks/` | 한국 카플레이 길안내(`hooks.jar`) 소스(`src/`)와 컴파일용 DiPO iAP2 스텁(`stubs/`). `scripts/build-hooks.sh`가 만들고 `build.sh`가 모드에 넣습니다 |
| `art/` | 앱 메뉴 타일 모양의 원본(`tile.svg`). `mod/icons/`의 그림 넷은 이것을 HMG-API `tools/mkicon.sh`로 만든 것입니다 |
| `app/` | 관리 앱 소스 |
| `usb/` | USB 설치기(`troubleShooter`)와 USB 안내(`README.txt`) |
| `scripts/` | `build-app.sh`(관리 앱), `build-hooks.sh`(`hooks.jar`), `build.sh`(서명한 모드 zip과 USB 묶음) |
| `docs/design.md` | 설계와 차에서 확인할 것 |
| `docs/flow.md` | 설치부터 무선 연결·관리 앱·지우기까지의 처리 흐름 그림(mermaid) |
| `docs/troubleshooting.md` | 차에서 설치하다 문제가 생길 때 |
| `docs/emulator-test.md` | 에뮬레이터에서 관리 앱 테스트 |
| `docs/git-flow.md` | 브랜치 전략(Git Flow) |
| [GitHub 이슈](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues) | 정하지 않은 것(라벨 `결정 필요`), 차에서 확인할 일(`차 확인`), 릴리스 일(`릴리스`) |
| `docs/release.md` | 태그로 도는 배포(GitHub Actions)와 배포 키 |
| `tests/` | PC 시험(`mod-test.sh`), 에뮬레이터 시험 스크립트(`emu/`) |

**만들기**

저장소 밖 경로(Android SDK, 서명 키, HMG-API 소스)는 코드에 기본값이 없습니다. `.env.example`을 `.env.local`로 복사해 채웁니다(`.env.local`은 git에 넣지 않습니다). 명령 앞에 준 값이 `.env.local`보다 앞섭니다.

```sh
cp .env.example .env.local   # ANDROID_HOME, NX4_APP_KEYS, HMGAPI_SRC, NX4_MOD_KEY 채우기

# 1. 관리 앱(Android SDK build-tools와 android-19 필요) → mod/app/NX4KOR.apk
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
#    공식 무선 모드 zip은 공식 릴리스에서 받아 넣습니다(scripts/fetch-wireless.sh, 인터넷 필요. 고정한 판, NOTICE.md의 SHA-256과 같을 때만).
#    인터넷 없이 만들 때는 받아 둔 파일을 .env.local의 NX4_WIRELESS_ZIP으로 가리킵니다
#    hooks.jar(한국 카플레이 길안내)는 build.sh가 scripts/build-hooks.sh로 만듭니다(ANDROID_HOME과 HMGAPI_SRC 필요)
#    선택: .env.local에 HMGAPI_USB_ZIP(hmgapi-버전-usb.zip)
sh scripts/build.sh

# 앱 메뉴 타일 그림을 바꿀 때만(ImageMagick 필요): art/tile.svg → mod/icons/의 순정 꼴 그림 넷.
# 관리 앱 아이콘도 같은 그림(낮·밤)으로 둡니다(tests/mod-test.sh가 같은지 봅니다).
# 지금 그림은 HMG-API rc.4 mkicon.sh와 ImageMagick 7.1.2(librsvg 없음, 내장 SVG 렌더러)로 만들었습니다.
# ImageMagick 판이 다르거나 librsvg가 있으면 모양을 바꾸지 않아도 PNG가 조금 달라질 수 있으니, 모양을 바꿀 때만 다시 만듭니다
sh <HMGAPI_SRC에 적은 HMG-API 소스>/tools/mkicon.sh art/tile.svg mod/icons
cp mod/icons/icon.png app/res/drawable-hdpi/ic_launcher.png
cp mod/icons/icon_night.png app/res/drawable-night-hdpi/ic_launcher.png
```

**PC 시험**
- `sh tests/mod-test.sh`: `mod.json`(뺀 것 포함), 앱 메뉴 타일 그림과 앱 아이콘, 서비스 래퍼, 삭제 전 정리, 상태 판정(공식 무선 모드·훅·프로젝션 AP·Wi-Fi 부품), [지금 재부팅] 요청, USB 설치기(공식 무선 모드 설치, 옛 2.0.x 되돌리기, map 만들기·확인, 계획 읽기와 적용, 진행 기록), 지우기(HMG-API를 먼저 지운 경우, `UNINSTALL-ALL` 포함), 공식 무선 모드 받기(`fetch-wireless.sh`), 관리 앱의 `ReportTest`, 한국 카플레이 길안내의 판단(`TbtGateTest`), 정적 검사. `HMGAPI_SRC`에 HMG-API 소스를 주면 빌드와 HMG-API 엔진(PC) 설치·계획·지우기, 차종 제한(NX4.KOR 260902만)까지 봅니다. `ANDROID_HOME`도 있으면 `hooks.jar`를 진짜로 만들고 곧 회전 그림 판단(`NearFitTest`)도 돌립니다. 이 모드는 HMG-API 1.1.0-rc.10 이상을 요구하므로 `HMGAPI_SRC`도 v1.1.0-rc.10 이상이어야 합니다(낮으면 엔진이 설치를 거절하고 테스트가 실패로 알림).
- 에뮬레이터: 관리 앱을 1920x720 에뮬레이터에 띄워 상태별 화면과 [지금 재부팅] 흐름을 봅니다. 준비와 순서는 [`docs/emulator-test.md`](docs/emulator-test.md).

## 라이선스

[GNU AGPL-3.0](LICENSE). 원본, HMG-API와 같은 라이선스입니다. 제조사 파일은 넣지 않습니다.

- 다른 프로젝트에서 가져온 부분과 원저작권, 이 저장소에서 바꾼 것은 [`NOTICE.md`](NOTICE.md)에 있습니다.
- 모드에 함께 넣는 `bin/busybox`는 별개 프로그램이며 **GPL-2.0**입니다. 출처와 대응 소스는 [`NOTICE.md`](NOTICE.md#busybox-gpl-20)에 있습니다.

## 바탕이 된 프로젝트

- [Korea Projection](https://github.com/StopDragon/korea-projection) — StopDragon (원본)
- [HMG-API](https://github.com/Open-HMG/HMG-API) — VysseCodes
- [Wireless CarPlay + Android Auto](https://github.com/Open-HMG/hmgapi-wireless-cp-aa) — VysseCodes (HMG-API 공식 무선 모드. 2.1.0은 이것을 고치지 않고 따로 설치해 씀)
