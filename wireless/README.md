# 무선 카플레이·안드로이드 오토 부분: 출처와 대응 소스

NX4 KOR 모드(`mod/`)의 무선 부분은 Korea Projection(StopDragon)이 HMG-API에 따로 넣던 한국 차 빌드 무선 모드 `wireless-carplay-aa` **2.4.5**를 그대로 합친 것입니다(Korea Projection 1.7.4, 커밋 `e5221e0`의 `nemesis-pkg/korea.projection/hmgapi/wireless-carplay-aa.zip`).

| `mod/`의 파일 | 2.4.5에서 |
|---|---|
| `hooks.jar` | 그대로(SHA-256 `6205d04888e4bdbdf2f120cf0695a81b0236471ccdfc88f1fa744884a19cb4e5`) |
| `recipes/*.recipe` 5개, `files/libleafiaaac.so` | 그대로 |
| `settings.json` | 그대로. `aa_ready_resend` 설명의 "Korea Projection"만 "NX4 KOR"로 바꿈 |
| `patches.json` | `changes` 5개만 남김. 차별 패치 세트(`cars`·`stock`·`expect`, `patches/`)는 뺐습니다. 모든 변경이 `stock: any`·속성·없는 파일 더하기라 세트가 없어도 같게 동작합니다 |
| `mod.json`의 `parts`·`feature_flags`·`hooks` | 그대로. `system`(다른 차), `logs`(HMG-API가 읽지 않음)는 뺐습니다 |

- 원래 `mod.json`: [`mod-2.4.5.json`](mod-2.4.5.json)
- 컴파일용 Android·벤더 클래스 시그니처: [`stubs/`](stubs/README.md)(빌드 때만 씁니다, 모드에는 넣지 않음)
- 모드 id가 `nx4-kor`로 바뀌어 차주 설정 파일은 `/data/hmgapi/settings/nx4-kor.json`입니다(예전 `wireless-carplay-aa.json`은 넘어오지 않음).
- `hooks.jar`가 쓰는 HMG-API 런타임 API(메서드 30개, 필드 15개, 재정의 4개)와 훅 지점은 HMG-API 1.1.0-rc.4에 모두 같은 꼴로 있습니다(2026-11-19 확인). 다시 빌드하지 않았습니다.

## 바탕이 된 것

- **HMG-API**(VysseCodes, AGPL-3.0)의 "Wireless CarPlay + Android Auto" 모드입니다. 지금은 따로 된 저장소 https://github.com/Open-HMG/hmgapi-wireless-cp-aa 에 있습니다.
  - Korea Projection 1.5.1~1.5.6은 업스트림 **2.1.0** 코드 그대로였습니다. HMG-API 태그 `v1.0.2`(커밋 `180185de2c57afb2cca4858d0be7828e8f1051d6`)의 `mods/wireless-carplay-aa/`입니다.
  - 그때의 `hooks.jar`는 업스트림 v1.0.0·v1.0.1·v1.0.2 릴리스와 바이트까지 같습니다(SHA-256 `b8525dfc1d0ce7539a5c7d4cae331ddc0464d78394f61ba72172e554fc7e973d`).
- **1.5.7부터 코드가 업스트림과 다릅니다.** 소스는 포크 `StopDragon/HMG-API`의 `korea-build` 브랜치(업스트림 `v1.0.2`에서 시작)에 있습니다.

| Korea Projection | 모드 | 바뀐 코드 | `hooks.jar` SHA-256 |
|---|---|---|---|
| 1.5.7 | 2.1.1 | 계기판·HUD 회전 안내(각도 없는 회전, 대체 화살표, 다시 보내기) | 릴리스 설명 참고 |
| 1.7.0 | 2.2.0 | 무선 안드로이드 오토(우리 핫스팟을 AA에 알림) | `42c2fbb2f0b1cc014154b8a8531b53b3f634753ee11f3fc156eda9c97f5b81ab` |
| 1.7.1 | 2.3.0 | 계기판·HUD 번호를 순정 한국 내비와 같게, 무선 카플레이 곡 정보 | `83aac4ca2dada357e031ea06dd058babe874eab7b9c3dc6ddecc981042128ac2`(포크 커밋 `38b4432`, `577434c`) |
| 1.7.2 | 2.4.0 | 곧 회전 큰 그림과 거리 막대, 경로 탐색·재탐색 화면, 블루투스 SPP 재시도 등 | `bcedcf279d62e06272425f5d0536dd5a752c2b3ba9e1d79e307a066296f866ce`(포크 커밋 `29c4e30`, `b02a141`) |
| 1.7.3 | 2.4.1 | Korea Projection 릴리스 설명 참고 | `07efaa70250663d0bfea13c29f839d20d7ef8073d67c36a0d132254145e29699` |
| 1.7.4 | 2.4.5 | 계기판 길안내를 순정 표대로 전달하고 보정(`tbt_fit`), 별표 키 팝업 건너뜀(`star_popup_skip`). 포크 커밋 `b573ac6` | `6205d04888e4bdbdf2f120cf0695a81b0236471ccdfc88f1fa744884a19cb4e5` |

- 1.7.1의 차로 조합 그림 표는 seogaemo(커밋 `26eeb97`, AGPL-3.0)에서 옮겼습니다. 출처는 소스 파일 머리말에 적었습니다.

## 공식 무선 모드 v2.2.0-rc.5와 비교 (2026-11-19)

[v2.2.0-rc.5](https://github.com/Open-HMG/hmgapi-wireless-cp-aa/releases/tag/v2.2.0-rc.5)(2026-11-18, `hmgapi >=1.1.0-rc.3`)와 비교했습니다.

| 항목 | 2.4.5(한국 포크, 이 모드) | v2.2.0-rc.5 |
|---|---|---|
| 지원 차 | 한국 차(이 모드는 NX4만) | 미국·캐나다 7항목. **한국 차·NX4 없음** |
| 순정 핫스팟 메뉴 | `patches.json`의 featurexml 줄 주석 | `"wifi": {"hotspot": true}`(HMG-API가 같은 줄을 처리) |
| 훅 지점 | 36개 | 36개에 4개 더함(`btsettings.projection_helper.open_wireless_page`, `iap2.init_info.use_vehicle_information`·`use_vehicle_status`, `dipo.carplay.disable_bluetooth`) |
| 네이티브 레시피 | 5개 | 3개 더함(한국 260902 빌드 `libCarPlayCore` 프레임 레시피 `carplay-core-frames-ef49c09b`, 캐나다 AA, 260507 identity) |
| 한국 포크에만 | AA 핫스팟 신호(`sys.kp.aa_ap`), AA 준비 다시 보내기, 별표 키 팝업 건너뜀, `tbt_fit` 보정, SPP 재시도, 한국어 UTF-8 수정 AA 레시피 | — |
| rc.5에만 | — | 1분쯤 뒤 무선 카플레이 끊김 수정(BT 유지), 길안내 재연결, Wi-Fi 끊김 10초 버티기, `libleafiaaac` 경쟁 수정, 방화벽·공유 identity 설정 |

- **rc.5를 그대로 쓸 수는 없습니다.** 한국 차를 받지 않고, 위 한국 포크 기능이 없습니다.
- 그래서 지금은 2.4.5를 유지합니다. 차에서 시험해 볼 만한 것(코드 수정 없이):
  - rc.5의 `carplay-core-frames-ef49c09b.recipe`를 `libCarPlayCore.so` 레시피 목록 맨 앞에 더하기. 이 레시피의 원본 md5는 한국 260902 빌드의 것과 같습니다. NX4 라이브러리와 맞는지는 차에서 확인해야 합니다.
  - rc.5의 `libleafiaaac.so`로 바꾸기.
- 길게 보면 한국 포크의 변경을 rc.5 위로 옮겨(BT 유지·재연결·`wifi.hotspot`을 받기) 다시 빌드하는 것이 좋습니다.

## 직접 다시 만들기

`hooks.jar`를 소스에서 다시 빌드하려면(준비물: JDK 17, Android SDK build-tools·`android.jar`, Python 3, HMG-API `build.sh`와 같음):

```sh
git clone https://github.com/StopDragon/HMG-API.git
cd HMG-API
git checkout b573ac6        # korea-build, 모드 2.4.5
sh build.sh mods            # → out/mods/wireless-carplay-aa/hooks.jar
cp out/mods/wireless-carplay-aa/hooks.jar <이 저장소>/mod/hooks.jar
```

- `hooks.jar`의 바이트는 d8 버전에 따라 달라집니다. 업스트림 v1.0.2 릴리스는 d8 9.2.4(Android SDK build-tools 37.0.0)로 빌드됐고, JDK 17과 그 d8로 v1.0.2를 빌드하면 배포본과 바이트까지 같습니다(Korea Projection, 2026-11-07 확인). JDK 21과 d8 8.x를 함께 쓰면 빌드가 멈춥니다.
- 그다음 `scripts/build.sh`로 NX4 KOR 모드를 서명합니다. HMG-API는 **같은 id, 같은 키로 서명한 업데이트만** 받습니다.

## 라이선스

이 폴더와 `mod/`의 무선 부분은 AGPL-3.0입니다(저장소 `LICENSE`, 원저작권 고지는 `NOTICE.md`).
