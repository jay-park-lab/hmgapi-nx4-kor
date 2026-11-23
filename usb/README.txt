NX4 KOR @VERSION@ - USB로 설치 (투싼 NX4 한국 내수 260902, HMG-API 모드)
==========================================================

무선 카플레이·안드로이드 오토를 내비 핫스팟으로 씁니다. 계기판·HUD 길안내도 함께 들어 있습니다.
이 폴더 안의 것을 모두 빈 USB(FAT32) 맨 위에 복사합니다.
  USB
  ├─ ota_package.tar             NX4 KOR 설치기
  ├─ README.txt
  ├─ LICENSE, NOTICE.md (BUSYBOX-LICENSE.txt: busybox를 함께 넣은 경우)
  ├─ HMGAPI, HMGAPI-README.txt, HMGAPI-SOURCE.txt   HMG-API (함께 넣은 경우)
  └─ NX4
      ├─ install (hmgapi-nx4-kor.zip, payload)
      └─ hmgapi                  HMG-API 설치기 (함께 넣은 경우)

HMG-API 1.1.0-rc.4 이상이 필요합니다.
- HMGAPI 폴더가 있으면 HMG-API가 함께 들어 있는 묶음입니다(이 저장소의 릴리스 묶음).
  HMG-API가 없거나 1.1.0-rc.4보다 낮으면 첫 번째 Update OTA가 HMG-API를 설치(또는 업데이트)하고 재부팅합니다.
  부팅이 끝나고 1~2분 뒤 같은 USB로 Update OTA를 한 번 더 누르면 NX4 KOR가 설치됩니다.
- HMG-API가 들어 있지 않은 묶음이면 HMG-API USB(hmgapi-<버전>-usb.zip)로 먼저 설치하고 재부팅한 뒤 이 USB를 씁니다.
  HMG-API가 낮은 판인데 이 USB에 HMG-API가 없으면 설치기가 아무것도 바꾸지 않고 멈춥니다.

설치·업데이트
  1. 시동을 걸고(차를 세운 상태) USB를 꽂습니다.
  2. Engineering Mode > USB Copy > DSP > Update OTA를 누릅니다.
     "HMG-API를 먼저 설치합니다" 또는 "HMG-API를 …(으)로 먼저 올립니다"가 나오면 재부팅을 기다렸다가 한 번 더 누릅니다.
  3. "설치하는 중" 다음에 상태 화면이 열립니다. OTA 화면의 오류 684는 정상입니다.
  4. 상태 화면에 "설정을 마쳤습니다"가 나오면(3~5분) [지금 재부팅]을 누릅니다. 그동안 끄지 마세요.
     처음에는 HMG-API가 이 차의 map을 만들고 확인한 뒤 무선 기능을 적용합니다.
  5. 재부팅 뒤 폰을 무선 카플레이·안드로이드 오토로 연결합니다.
  따로 설치한 무선 모드(wireless-carplay-aa)가 있으면 설치기가 먼저 지웁니다(같은 기능이 NX4 KOR에 들어 있습니다).

상태 화면을 다시 열기
  HMG-API 훅이 켜지면 앱 메뉴에 NX4 KOR 타일이 생깁니다.
  타일이 없을 때(설정 전, 또는 HMG-API가 이 차에서 훅을 켜지 못했을 때)는 같은 USB로 Update OTA를 다시 누르면
  상태 화면만 열립니다(다시 설치하지 않음).

지우기
  NX4 폴더에 빈 파일 UNINSTALL을 만들고 Update OTA를 누릅니다. 되돌린 뒤 재부팅합니다.
  HMG-API 앱에서 모드를 먼저 지웠거나 HMG-API를 먼저 지웠더라도 이렇게 하면 Wi-Fi 설정까지 되돌립니다.
  둘 다 지울 때는 NX4 KOR를 먼저, HMG-API를 나중에 지우는 것을 권합니다.

같은 판을 다시 설치: NX4 폴더에 빈 파일 REINSTALL을 만듭니다.

한 일은 USB의 NX4/install.log(HMG-API 설치는 HMGAPI/install.log)에 남습니다. NX4/install.log는 누를 때마다 아래에 이어 씁니다. 내비의 기록은 /data/nx4-kor/logs/ap.log입니다.
상태 화면 앱이 있으면 누를 때마다 "진단 기록 모으기" 확인 창이 먼저 뜹니다. [모으기]를 고르면 진단 기록(내비의 기록,
  HMG-API Car Report, /system/lib 파일 이름·md5)을 NX4/diag/<시각>/에 모읍니다. 1~2분 걸리니 다음 메시지가 나올 때까지
  USB를 빼지 마세요. [건너뛰기]나 60초 동안 고르지 않으면 모으지 않고 이어집니다. Wi-Fi 비밀번호가 든 파일은 넣지 않습니다.
끝나면 USB를 빼 주세요(꽂혀 있으면 유선 안드로이드 오토가 시작될 수 있습니다).

라이선스
  NX4 KOR는 GNU AGPL-3.0입니다(LICENSE). Korea Projection(StopDragon)과 HMG-API의 Wireless CarPlay +
  Android Auto 모드(VysseCodes)를 바탕으로 했습니다.
  대응 소스: https://github.com/jay-park-lab/hmgapi-nx4-kor (이 묶음: @SOURCE_REV@)
  원본과 원저작권, 이 저장소에서 바꾼 것은 NOTICE.md에 있습니다.
  busybox(GPL-2.0)를 함께 넣었으면 BUSYBOX-LICENSE.txt, HMG-API를 함께 넣었으면 HMGAPI-SOURCE.txt를 보세요.
