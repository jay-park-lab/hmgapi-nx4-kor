NX4 KOR @VERSION@ - USB로 설치 (투싼 NX4 한국 내수 260902)
==========================================================

HMG-API, 공식 무선 모드(wireless-carplay-aa, 고치지 않음), NX4 KOR(관리 앱)를 이 USB 하나로 설치합니다.
무선 카플레이·안드로이드 오토와 계기판·HUD 길안내는 공식 무선 모드가 합니다. NX4는 공식 모드의 차 목록에 없어
HMG-API의 "Install anyway"(--any-car)로 설치합니다.
이 폴더 안의 것을 모두 빈 USB(FAT32) 맨 위에 복사합니다.
  USB
  ├─ ota_package.tar             NX4 KOR 설치기
  ├─ README.txt
  ├─ LICENSE, NOTICE.md, WIRELESS-SOURCE.txt (BUSYBOX-LICENSE.txt: busybox를 함께 넣은 경우)
  ├─ HMGAPI, HMGAPI-README.txt, HMGAPI-SOURCE.txt   HMG-API (함께 넣은 경우)
  └─ NX4
      ├─ install (hmgapi-nx4-kor.zip, payload)
      ├─ wireless (wireless-carplay-aa.zip, mod.json)   공식 무선 모드
      ├─ legacy-2.0              옛 NX4 KOR 2.0.x를 되돌리는 스크립트(v2.0.4-beta.1에서 그대로)
      └─ hmgapi                  HMG-API 설치기 (함께 넣은 경우)

HMG-API 1.1.0-rc.10 이상이 필요합니다(2.1.1부터. 2.1.0은 rc.8 이상).
- HMGAPI 폴더가 있으면 HMG-API가 함께 들어 있는 묶음입니다(이 저장소의 릴리스 묶음).
  HMG-API가 없거나 1.1.0-rc.10보다 낮으면(2.1.0을 쓰던 차의 rc.8, rc.9 포함) 첫 번째 Update OTA가 HMG-API를 설치(또는 업데이트)하고
  재부팅합니다. rc.10으로 올리는 업데이트는 NEMESIS 1.17에서도 안전합니다(예전에 FORCE로 설치한 차 포함).
  부팅이 끝나면 바로 같은 USB로 Update OTA를 한 번 더 누르면 나머지가 설치됩니다.
  설치기가 HMG-API가 준비될 때까지 스스로 기다립니다(최대 약 5분, "HMG-API가 준비되기를 기다리는 중" 토스트).
  그동안 USB를 빼지 마세요.
- NEMESIS가 깔린 차에서는 이 USB가 HMG-API도 설치·업데이트하지 않습니다(아래 "NEMESIS가 깔린 차").
- HMG-API가 들어 있지 않은 묶음이면 HMG-API USB(hmgapi-<버전>-usb.zip)로 먼저 설치하고 재부팅한 뒤 이 USB를 씁니다.
  HMG-API가 낮은 판인데 이 USB에 HMG-API가 없으면 설치기가 아무것도 바꾸지 않고 멈춥니다.

설치·업데이트
  1. 시동을 걸고(차를 세운 상태) USB를 꽂습니다.
     NEMESIS가 깔린 차에는 설치하지 않습니다(아래 "NEMESIS가 깔린 차").
     Korea Projection을 설치해 두었다면 NEMESIS에서 Korea Projection을 지우고 내비를 재부팅한 뒤 합니다.
     함께 있으면 Wi-Fi를 다퉈 설치기가 아무것도 바꾸지 않고 멈춥니다(지우기는 막지 않습니다).
  2. Engineering Mode > USB Copy > DSP > Update OTA를 누릅니다.
     "HMG-API를 먼저 설치합니다" 또는 "HMG-API를 …(으)로 먼저 올립니다"가 나오면 재부팅을 기다렸다가 한 번 더 누릅니다.
  3. 설치기가 차례로 합니다(OTA 화면의 오류 684는 정상입니다).
     - 옛 NX4 KOR 2.0.x가 있으면 먼저 끝까지 되돌립니다(공식 무선 모드와 함께 쓸 수 없습니다).
       2.0.x를 HMG-API 앱에서 먼저 지운 차나 2.0.x 위에 2.1.0을 넣은 차도 남은 설정(Wi-Fi 잠금 등)을 NX4/legacy-2.0으로 되돌립니다.
     - 공식 무선 모드: 없거나 이 USB의 판보다 낮으면 설치합니다. 같거나 높은 판은 그대로 둡니다.
       Korea Projection의 한국 차 빌드(같은 이름의 무선 모드)는 공식판으로 바꿉니다.
     - NX4 KOR를 설치하고 관리 앱을 엽니다. 남은 진행은 관리 앱에 막대로 보입니다.
     - 처음에는 HMG-API가 이 차의 map을 만들고(1~2분) 확인합니다.
     - 바꿀 것이 우리 두 모드의 것뿐이면 적용합니다. 다른 모드의 바뀐 내용이 함께 있으면 적용하지 않고
       HMG-API 앱에서 적용하라고 안내합니다(시작할 때 이미 있으면 아무것도 바꾸지 않고 멈춥니다).
     모두 3~5분 걸립니다. 그동안 USB를 빼거나 끄지 마세요.
  4. 관리 앱에 "설정을 마쳤습니다"가 나오면 [지금 재부팅]을 누릅니다(또는 RESET).
  5. 재부팅 뒤 폰을 무선 카플레이·안드로이드 오토로 연결합니다. 이 차의 내비에 Wi-Fi 부품이 있어야 합니다.
  같은 판이 이미 있으면 다시 설치하지 않고 map 확인과 적용할 것만 봅니다. 그러면 "설정이 끝나 있습니다"가 나옵니다.

NEMESIS가 깔린 차
  NX4 KOR는 NEMESIS가 깔린 차(/system/xbin/nemesis가 있음)에는 설치하지 않습니다. 순정 시스템에 부하를 더하지 않기 위해서입니다.
  설치기가 "NEMESIS가 깔린 차에는 NX4 KOR를 설치하지 않습니다"로 멈추고 아무것도 바꾸지 않습니다.
  같은 판 다시 설치·업데이트도 하지 않고, HMG-API도 설치·업데이트하지 않습니다. 지우기(UNINSTALL)는 막지 않습니다.
  쓰려면 NEMESIS를 지우고 내비를 재부팅한 뒤 다시 누릅니다. NEMESIS를 지우기 전에:
  - HMG-API가 있으면 그것은 지우지 말고 둔 채 NEMESIS를 지우세요(아래 "!!" 안내).
  - 그 HMG-API가 1.1.0-rc.10보다 낮으면 NEMESIS를 지우기 전에 HMG-API 릴리스로 rc.10 이상으로 올리고 두 번 재부팅합니다.
    HMGAPI/FORCE로 설치한 차(NEMESIS 1.17)는 꼭 이렇게 합니다(rc.9를 거치지 않음, HMG-API 1.1.0-rc.10 릴리스 노트).
  - Android가 뜨지 않는 차에서는 NEMESIS를 지우지 마세요.
  NEMESIS가 깔린 차에서 HMG-API를 올리거나 다시 설치할 때는 HMG-API 릴리스의 hmgapi-<버전>-nemesis.zip(NEMESIS Manager),
  USB 묶음(hmgapi-<버전>-usb.zip)이나 update zip(HMG-API 앱 "Check USB updates")을 씁니다(1.1.0-rc.10 이상).
  이 저장소의 USB는 쓰지 않습니다. 2.1.2 이후는 멈추고, 2.1.1 이전은 HMG-API를 올린 뒤 NX4 KOR까지 설치합니다.

관리 앱을 다시 열기
  HMG-API 훅이 켜지면 앱 메뉴에 NX4 KOR 타일이 생깁니다.
  타일이 없을 때(설정 전, 또는 HMG-API가 이 차에서 훅을 켜지 못했을 때)는 같은 USB로 Update OTA를 다시 누르면
  관리 앱이 먼저 열립니다(같은 판은 다시 설치하지 않음. HMG-API가 응답해야 합니다).
  NEMESIS가 깔린 차에서는 열리지 않고 설치기가 멈춥니다(위 "NEMESIS가 깔린 차").

지우기
  NX4 폴더에 빈 파일 UNINSTALL을 만들고 Update OTA를 누릅니다. NX4 KOR를 되돌린 뒤 재부팅합니다.
  HMG-API, 공식 무선 모드, 이 차의 map은 남깁니다.
  공식 무선 모드도 지우려면 UNINSTALL 대신 UNINSTALL-ALL을 만듭니다(HMG-API와 map은 남김).
  HMG-API 앱에서 모드를 먼저 지웠거나 HMG-API를 먼저 지웠더라도 이렇게 하면 됩니다.
  옛 NX4 KOR 2.0.x를 HMG-API 앱에서 먼저 지운 차나 2.0.x 위에 2.1.0을 넣은 차는 2.0.x가 남긴 설정(Wi-Fi 잠금 등)을
  NX4/legacy-2.0으로 되돌립니다.
  둘 다 지울 때는 NX4 KOR를 먼저, HMG-API를 나중에 지우는 것을 권합니다.

  !! NEMESIS 1.17이 깔린 차에서는 HMG-API를 1.1.0-rc.10 이상으로 올리기 전에 지우지 마세요.
  HMG-API 1.1.0-rc.8 이하를 지우면 재부팅 한두 번 뒤 Android가 뜨지 않습니다.
  HMGAPI/FORCE로 설치한 차(NEMESIS 1.17)는 1.1.0-rc.9로 올리기만 해도 Android가 뜨지 않으니 rc.10으로 바로 올립니다.
  한번 Android가 뜨지 않으면 미리 켜 둔 adb나 대리점이 필요할 수 있습니다(NEMESIS 비상 USB는 아직 차에서 된 적이 없음).
  지울 때 도는 것은 그 HMG-API를 설치할 때 저장해 둔 삭제라서, 새 판 HMG-API USB의 HMGAPI/UNINSTALL로 지워도 같습니다.
  먼저 HMG-API를 1.1.0-rc.10 이상으로 올리고 두 번 재부팅한 뒤 지웁니다. 이 USB는 NEMESIS가 깔린 차에서 HMG-API를 올리지 않으므로
  HMG-API 릴리스의 USB(hmgapi-<버전>-usb.zip)나 update zip(HMG-API 앱 "Check USB updates")으로 올립니다
  (NEMESIS가 깔린 차는 NEMESIS Manager로 hmgapi-<버전>-nemesis.zip도 됩니다. 2.1.1 이전의 이 USB는 쓰지 않습니다).
  NEMESIS 1.16 이하나 NEMESIS가 없는 차는 해당하지 않습니다.
  이미 지웠고 Android가 아직 뜬다면, 다시 재부팅하기 전에 HMG-API 릴리스의 USB(1.1.0-rc.10 이상)로 HMG-API를 새로 설치합니다
  (이 USB는 NEMESIS가 깔린 차에서 HMG-API를 설치하지 않습니다. UNINSTALL-PURGE로 지웠으면 아래 주소를 봅니다).
  Android가 이미 뜨지 않으면 아래 주소를 따릅니다. 그때 NEMESIS를 지우지 마세요(복구할 길이 없어집니다).
    https://github.com/Open-HMG/HMG-API/issues/397
  자세한 것: 저장소 README "HMG-API를 지울 때"

같은 판을 다시 설치: NX4 폴더에 빈 파일 REINSTALL을 만듭니다(NX4 KOR와 같은 판의 공식 무선 모드를 다시 설치).

한 일은 USB의 NX4/install.log(HMG-API 설치는 HMGAPI/install.log)에 남습니다. NX4/install.log는 누를 때마다 아래에 이어 씁니다.
  HMG-API의 map 만들기·확인과 계획 출력도 함께 남습니다.
관리 앱이 있으면 누를 때마다 "진단 기록 모으기" 확인 창이 먼저 뜹니다. [모으기]를 고르면 진단 기록(내비의 기록,
  HMG-API Car Report, /system/lib 파일 이름·md5, USB Wi-Fi 동글 드라이버를 만드는 데 쓸 커널 설정과 USB 장치 목록,
  카플레이 차선 안내를 살필 순정 iAP2 라이브러리·앱 사본)을 NX4/diag/<시각>/에 모읍니다. 1~2분 걸리니 다음 메시지가 나올 때까지
  USB를 빼지 마세요. [건너뛰기]나 60초 동안 고르지 않으면 모으지 않고 이어집니다. Wi-Fi 비밀번호가 든 파일은 넣지 않습니다.
  기록을 이슈에 올릴 때는 iap2 폴더(순정 바이너리)를 빼 주세요. logs/hmgapi-log.log*(HMG-API 기록)에는
  길 이름·목적지 이름이 들 수 있으니 올리기 전에 살펴 주세요.
끝나면 USB를 빼 주세요(꽂혀 있으면 유선 안드로이드 오토가 시작될 수 있습니다).

라이선스
  NX4 KOR는 GNU AGPL-3.0입니다(LICENSE). Korea Projection(StopDragon)을 바탕으로 했습니다.
  대응 소스: https://github.com/jay-park-lab/hmgapi-nx4-kor (이 묶음: @SOURCE_REV@)
  원본과 원저작권, 이 저장소에서 바꾼 것은 NOTICE.md에 있습니다.
  NX4/legacy-2.0은 이 저장소의 태그 v2.0.4-beta.1에 있는 파일 그대로입니다(같은 대응 소스, 그 폴더의 SOURCE).
  공식 무선 모드(VysseCodes, AGPL-3.0)는 고치지 않고 넣었습니다. 판과 대응 소스는 WIRELESS-SOURCE.txt를 보세요.
  busybox(GPL-2.0)를 함께 넣었으면 BUSYBOX-LICENSE.txt, HMG-API를 함께 넣었으면 HMGAPI-SOURCE.txt를 보세요.
  USB Wi-Fi 동글 드라이버(NX4/install의 모드 zip 안 drivers/, GPL-2.0)를 넣었으면 전문과 대응 소스는 그 폴더의 COPYING·SOURCE.txt를 보세요.
