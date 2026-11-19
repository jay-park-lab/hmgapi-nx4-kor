Korea Projection @VERSION@ - NEMESIS 없이 USB로 설치 (투싼 NX4 전용)
==========================================================

이 폴더 안의 것을 모두 빈 USB(FAT32) 맨 위에 복사합니다.
  USB
  ├─ ota_package.tar
  ├─ README.txt
  └─ KoreaProjection
      ├─ install (korea-projection.zip, payload)
      └─ hmgapi (HMG-API USB 묶음을 함께 넣은 경우만)

HMG-API가 먼저 있어야 합니다(1.0.2 이상, NEMESIS는 필요 없음).
- HMG-API USB 묶음(hmgapi-<버전>-usb.zip)을 이 묶음에 함께 넣어 만들었으면 같은 USB로 두 번 하면 됩니다:
  첫 번째는 HMG-API를 설치하고 재부팅, 두 번째에 Korea Projection을 설치합니다.
- 아니면 HMG-API USB로 먼저 설치하고 재부팅한 뒤 이 USB를 씁니다.

설치·업데이트
  1. 시동을 걸고(차를 세운 상태) USB를 꽂습니다.
  2. Engineering Mode > USB Copy > DSP > Update OTA를 누릅니다.
  3. "설치하는 중" 다음에 상태 화면이 열립니다. OTA 화면의 오류 684는 정상입니다.
  4. 상태 화면에 "설정을 마쳤습니다"가 나오면(3~5분) [지금 재부팅]을 누릅니다. 그동안 끄지 마세요.
  5. 재부팅 뒤 폰을 무선 카플레이·안드로이드 오토로 연결합니다.

상태 화면을 다시 열기
  HMG-API 훅이 켜지면 앱 메뉴에 Korea Projection 타일이 생깁니다.
  그 전에는 같은 USB로 Update OTA를 다시 누르면 상태 화면만 열립니다(다시 설치하지 않음).

지우기
  KoreaProjection 폴더에 빈 파일 UNINSTALL을 만들고 Update OTA를 누릅니다. 되돌린 뒤 재부팅합니다.
  HMG-API 앱에서 모드를 먼저 지웠거나 HMG-API를 먼저 지웠더라도 이렇게 하면 Wi-Fi 설정까지 되돌립니다.
  둘 다 지울 때는 Korea Projection을 먼저, HMG-API를 나중에 지우는 것을 권합니다.

같은 판을 다시 설치: KoreaProjection 폴더에 빈 파일 REINSTALL을 만듭니다.

한 일은 USB의 KoreaProjection/install.log에 남습니다.
끝나면 USB를 빼 주세요(꽂혀 있으면 유선 안드로이드 오토가 시작될 수 있습니다).
