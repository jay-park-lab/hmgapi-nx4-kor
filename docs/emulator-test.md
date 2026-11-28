# 에뮬레이터 테스트 (관리 앱)

Android 에뮬레이터에서 NX4 KOR 관리 앱(`io.github.jayparklab.nx4kor/.StatusActivity`)을 실제로 띄워, 상태마다 화면이 맞게 나오는지와 [지금 재부팅] 버튼이 root 쪽 답에 맞게 안내하는지 봅니다.

차에서는 root 쪽 스크립트가 `/data/local/tmp/nx4-kor-*.txt`를 쓰고 앱은 그 파일만 읽습니다. 이 시험은 그 파일을 손으로 만들어 넣습니다. 그래서 **앱 화면과 앱·root 사이 파일 약속**을 보고, root 쪽 스크립트·HMG-API·Wi-Fi는 보지 않습니다(그쪽은 `tests/mod-test.sh`).

| 파일 (`/data/local/tmp/`) | 차에서 쓰는 쪽 | 시험에서 넣는 것 |
|---|---|---|
| `nx4-kor-status.txt` | `mod/bin/status.sh` | `tests/emu/scen.sh` |
| `nx4-kor-progress.txt` | USB 설치기 (설치 진행, 형식은 `mod/svc/lib.sh` `PROG`) | `tests/emu/scen.sh` |
| `nx4-kor-notice.txt` | 알림(2.0.x 서비스·USB 설치기) | `tests/emu/scen.sh hint` |
| `nx4-kor-hint.txt` | 2.0.x 서비스(`hint_write`). 2.1.0에는 쓰는 곳이 없고 앱은 그대로 읽음 | `tests/emu/scen.sh hint` |
| `nx4-kor-watch.txt` | `mod/bin/status.sh --watch` (재부팅 요청 감시자) | `tests/emu/watch.sh on` |
| `nx4-kor-reboot-result.txt` | `mod/bin/status.sh --watch` | `tests/emu/watch.sh answer <code>` |

앱이 쓰는 파일은 앱 폴더의 두 개입니다.
- `files/reboot.req`: [지금 재부팅] 요청(`<요청 id> <boot_id> <부팅 뒤 초>` 한 줄)
- `files/diag.ans`: 진단 기록 확인 창의 답(`<id> <답>` 한 줄). 차에서는 USB 설치기가 읽습니다(아래 "진단 기록 확인 창")

## 준비 (처음 한 번)

Android SDK 위치는 코드에 기본값이 없습니다. 저장소 맨 위 `.env.local`의 `ANDROID_HOME`에 적으면(`.env.example` 참고) `scripts/build-app.sh`와 `tests/emu/` 스크립트가 읽습니다. 아래에서 손으로 치는 명령은 셸에도 같은 값을 둡니다.

```sh
export ANDROID_HOME=<Android SDK를 둘 폴더>
```

### 1. JDK

JDK 21(Temurin)로 확인했습니다. **JDK 21에서는 build-tools 37 이상이 필요합니다.** build-tools 34의 d8(8.2.2)은 `StatusActivity`의 안쪽 클래스를 변환하다 NullPointerException으로 멈춥니다. `build-app.sh`는 설치된 build-tools 중 가장 높은 판을 고릅니다.

### 2. Android SDK

`cmdline-tools`만 받아 `sdkmanager`로 나머지를 설치합니다. 내려받을 파일 이름은 <https://developer.android.com/studio>의 "Command line tools only"(macOS)에서 확인합니다. 2026-11-19에는 `commandlinetools-mac-15641748_latest.zip`이었습니다.

```sh
mkdir -p $ANDROID_HOME/cmdline-tools
curl -sS -o /tmp/cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-mac-15641748_latest.zip
unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-unz
mv /tmp/cmdline-tools-unz/cmdline-tools $ANDROID_HOME/cmdline-tools/latest

yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --sdk_root=$ANDROID_HOME --licenses
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --sdk_root=$ANDROID_HOME \
  "platform-tools" "emulator" "build-tools;37.0.0" "platforms;android-19" \
  "system-images;android-24;default;arm64-v8a"
```

- `platforms;android-19`: 앱 빌드용(`build-app.sh`가 `android.jar`를 씀).
- `system-images;android-24;default;arm64-v8a`: 에뮬레이터 이미지. 앱은 API 19(Android 4.4)를 대상으로 빌드하지만, API 19 이미지는 32비트 ARM·x86뿐이라 Apple Silicon Mac에서 돌지 않아 arm64 이미지(Android 7.0)를 씁니다. Google Play가 없는 `default` 이미지라 `adb root`가 됩니다.
- 다 받으면 약 4.8GB입니다.

### 3. AVD(가상 기기) 만들기

```sh
echo no | ANDROID_SDK_ROOT=$ANDROID_HOME $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd \
  -n nx4kor -k "system-images;android-24;default;arm64-v8a" --force
```

`~/.android/avd/nx4kor.avd/config.ini`에서 아래 값을 바꿉니다(없는 줄은 끝에 더함).

```ini
hw.lcd.width=1920
hw.lcd.height=720
hw.lcd.density=240
hw.initialOrientation=landscape
hw.gpu.enabled=yes
hw.gpu.mode=auto
hw.keyboard=yes
showDeviceFrame=no
```

- 1920x720 가로는 NX4 내비 화면 크기입니다.
- 밀도 240(앱 아래 줄에 "밀도 1.5"로 보임)은 어림값입니다. 차에서 관리 앱 화면 아래 줄의 "화면 …(밀도 …)"를 보고 다르면 맞춥니다.
- `hw.gpu.mode=swiftshader_indirect`는 에뮬레이터 37.2가 받지 않고 `auto`로 바꿉니다.

### 4. 시험용 앱 빌드

시험용 서명 키로 빌드합니다. 명령 앞에 준 `NX4_APP_KEYS`가 `.env.local`의 배포용 키 폴더보다 앞섭니다. 키 폴더가 비어 있으면 `build-app.sh`가 새 키를 만듭니다.

```sh
NX4_APP_KEYS=<시험 키 폴더, 예: /tmp/nx4-kor-test-keys> sh scripts/build-app.sh
```

> ⚠️ `build-app.sh`는 언제나 `mod/app/NX4KOR.apk`에 씁니다. 시험이 끝나면 **배포용 키로 다시 빌드한 뒤** `scripts/build.sh`로 묶습니다. 시험 키로 서명한 앱을 차에 올리면, 다음 업데이트를 배포용 키로 서명했을 때 Android가 업데이트를 받지 않습니다.

## 에뮬레이터 켜기 (매번)

```sh
ANDROID_SDK_ROOT=$ANDROID_HOME $ANDROID_HOME/emulator/emulator -avd nx4kor -no-snapshot -no-boot-anim -no-audio > /tmp/nx4kor-emulator.log 2>&1 &

ADB=$ANDROID_HOME/platform-tools/adb
$ADB wait-for-device
until [ "$($ADB shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done

$ADB root
$ADB wait-for-device
$ADB shell setenforce 0
$ADB install -r mod/app/NX4KOR.apk
```

- `adb root`: 시험 파일을 `/data/local/tmp`에 넣고, 앱 폴더의 `reboot.req`를 읽으려면 root가 필요합니다.
- `setenforce 0`: Android 7은 adb로 넣은 `/data/local/tmp` 파일을 앱이 SELinux 때문에 읽지 못합니다. 그래서 에뮬레이터에서는 SELinux를 끕니다. **차에서 앱이 이 파일을 읽을 수 있는지는 이 시험이 보지 않습니다.**
- 부팅할 때마다 `adb root`와 `setenforce 0`을 다시 합니다.
- `adb install -r`이 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`로 실패하면 AVD에 다른 키로 서명한 앱이 남아 있는 것입니다. `$ADB uninstall io.github.jayparklab.nx4kor`로 지운 뒤 다시 설치합니다(앱 폴더의 테스트 파일도 함께 지워짐).

## 관리 앱 시나리오

```sh
for s in ready connected installing reboot failed nowireless nowifipart nocar nobb hint bootguard bootguard2; do
  sh tests/emu/shot.sh $s
done
```

`shot.sh`는 `scen.sh <시나리오>`로 파일을 넣고, 앱을 끈 뒤 다시 열고, 2초 기다렸다가 `out/emu/<시나리오>.png`를 찍습니다(`OUT=<폴더>`로 바꿀 수 있음). 바로 찍으면 앱이 그리기 전이라 런처가 찍힙니다.

결과 화면은 순정 설정 상세 화면 모양입니다([`design.md`](design.md) "관리 앱").

- 위 제목 줄: 가운데 "NX4 KOR 2.0.0"만(앱 안 `<`는 2026-11-27에 뺌. 닫기는 뒤로 키)
- 왼쪽 칸: 요약 3줄(흰 제목, 회색 값)과 "자세히" 표, 맨 아래 확인 시각·앱 판·화면 크기 줄
- 오른쪽 칸: 판정과 안내, 맨 아래 [지금 재부팅] 블록(시안 글자)

아래 "볼 것"은 오른쪽 칸 기준입니다.

| 시나리오 | 넣는 것 | 볼 것 |
|---|---|---|
| `ready` | `verdict=ready`, 진행 100% | 시안 세로 표시와 시안 글자 "무선 카플레이·안드로이드 오토 준비됨."(띠 없음), [지금 재부팅]. 왼쪽 칸에 설치 "끝남", 무선 Wi-Fi "켜짐(HMG-API)", 폰 연결 "지금 연결된 폰 없음", "자세히" 표(공식 무선 모드 "2.2.0-rc.9, 켜짐", 한국 카플레이 길안내 "켜짐"(#71), 무선 연결용 Wi-Fi "켜짐") |
| `connected` | `cp_conn=1`, `verdict=connected` | 시안 표시와 시안 "무선 카플레이 연결됨", 왼쪽 칸 폰 연결 "카플레이 1대 연결됨" |
| `installing` | 진행 `pct=55`, `step=3/5`, `state=run` | 결과 화면 대신 설치 진행 화면(가운데 정렬): "NX4 KOR 2.0.0 설치 중", "단계 3/5 · map을 확인하는 중입니다", 시안 막대 55%, 시안 "55%"와 회색 "경과 2분 02초", 회색 "보통 5분 안에 끝납니다 …", 맨 아래 [닫기] 블록 |
| `reboot` | `verdict=reboot` | 노란 띠 "[지금 재부팅]을 눌러 내비를 재부팅해 주세요." |
| `failed` | `verdict=failed`(설치기가 쓴 실패 문장), `hookmap=mismatch` | 빨간 띠(설치기 문장), 왼쪽 칸 설치 "안 됨(오른쪽 안내를 보세요)" |
| `nowireless` | `verdict=nowireless`, `wm=no` | 빨간 띠 "공식 무선 모드(Wireless CarPlay + Android Auto)가 설치되어 있지 않습니다 …", 표의 공식 무선 모드 "없음 (설치 필요)" |
| `nowifipart` | `verdict=nowifipart`(수준 1), `chip=no`, `ap_fail=yes` | 노란 띠 "이 차의 내비에는 Wi-Fi 부품이 없는 것으로 보여 …"(지우는 법 줄 없음), 왼쪽 칸 무선 Wi-Fi "부품 없음(USB 동글 필요)", 표의 Wi-Fi 칩 "안 보임" |
| `dongleoff` | `verdict=dongleoff`(수준 1), `chip=no`, `dongle_drivers=yes`, `dongle=0bda:b831 rtl8831bu`, `dongle_on=none`, `dongle_btn=yes`(#60) | 노란 띠 "USB Wi-Fi 동글이 꽂혀 있지만 아직 켜지 않았습니다. 오른쪽 아래 [동글 켜기]를 눌러 주세요.", 그 아래 [동글 켜기](보조)와 [지금 재부팅]. 오른쪽 칸이 넘치지 않는지. 왼쪽 칸 무선 Wi-Fi "동글 꽂힘(켜기 전)", 표의 USB Wi-Fi 동글 "RTL8831BU (0bda:b831), 드라이버 안 걸림". [동글 켜기]를 누르면 확인 창 뒤 "동글을 켜는 중입니다…(1~2분)"와 꺼진 버튼. 결과는 `files/dongle.req`의 id로 `/data/local/tmp/nx4-kor-dongle-result.txt`(`id=… boot=… code=ok drv=rtl8831bu`)를 넣어 봄. 결과를 넣기 전에 상태 파일을 `dongle_on=rtl8831bu`·`ap=yes`·`verdict=ready`로 바꿔 두면(root가 결과 바로 앞에 새로 쓰는 것을 흉내, #111), 결과를 받은 화면이 그 상태로 다시 그려져 띠가 "준비됨"이 되고 결과 안내가 버튼 위에 남는지 봄 |
| `nocar` | 다른 차 `product`, `verdict_end=yes` | 빨간 띠 "지원하지 않는 차입니다 …"와 그 아래 회색 지우는 방법 안내 |
| `nobb` | 짧은 상태 파일(`support=nobb`) | 노란 띠 "이 내비에서는 동작하지 않습니다(busybox를 실행하지 못함) …", 왼쪽 칸은 요약 없이 짧은 표, **[지금 재부팅] 없음** |
| `hint` | `ready`와 같고 힌트(`iph=wifi`, `aa=cpwait`)·알림 | 시안 판정 아래 노란 띠 두 개(아이폰 Wi-Fi 다시 연결, 안드로이드 오토는 카플레이 연결 중이라 대기), 연노랑 띠 "알림 HH:MM …", 맨 아래 [지금 재부팅] |
| `bootguard` | `verdict=bootguard`(수준 1, HMG-API 부팅 보호), 무선 연결용 Wi-Fi 꺼짐. `hooks`·`wm_hooks`·`kor_hooks`는 앞 시작의 기록 그대로 `on`(`scen.sh` `guard()` 주석, 차의 값은 [`design.md`](design.md) "차에서 확인할 것") | 노란 띠 "HMG-API가 이번 부팅에만 무선 기능을 껐습니다(부팅 보호). …"(5줄), 맨 아래 [지금 재부팅]. 왼쪽 칸 설치 "HMG-API 훅 꺼짐(부팅 보호)", 무선 Wi-Fi "꺼짐". 표의 공식 무선 모드 "2.2.0-rc.9, 켜짐", HMG-API 훅 "켜짐", 한국 카플레이 길안내 "켜짐"(판정과 엇갈림) |
| `bootguard2` | `bootguard`와 같고 수준 2 | 빨간 띠 "HMG-API가 재부팅이 너무 잦은 것으로 보고 무선 기능을 껐습니다. …"(5줄), 왼쪽 칸은 `bootguard`와 같음 |

각 파일의 키는 `mod/bin/status.sh`(`status_kv`, `st_verdict`)와 `app/java/.../Report.java`를 따릅니다. 판정 코드를 더하거나 문구를 바꾸면 `scen.sh`에도 같은 경우를 넣습니다.

## [지금 재부팅] 버튼

### 앱과 root 사이 약속

1. 버튼을 누르면 앱이 감시자 파일(`nx4-kor-watch.txt`: `boot=<boot_id>`, `until=<부팅 뒤 초>`)을 봅니다. 이번 부팅 것이 아니거나 3초 안에 끝나면 요청을 보내지 않고 바로 "관리 앱을 닫았다가 다시 연 뒤 눌러 주세요."를 보입니다.
2. 감시자가 있으면 확인 창("차를 세운 상태에서만 누르세요. …")을 띄웁니다. [재부팅]을 누르면 `files/reboot.req`를 쓰고, 버튼을 끄고, "재부팅합니다…"를 보입니다.
3. 1초마다 `nx4-kor-reboot-result.txt`(`id=`, `boot=`, `code=`)를 읽습니다. 내 요청 id와 이번 부팅의 답이면 아래 표대로 안내하고 버튼을 다시 켭니다. 80초(`RB_WAIT`) 안에 답이 없으면 실패로 봅니다.

| `code` | 안내 | 색 |
|---|---|---|
| `install`, `fix`, `sysw` | 설정을 마무리하는 중입니다. 잠시 뒤 다시 눌러 주세요. | 노랑 |
| `old`, `bad` | 재부팅 요청을 받지 못했습니다. 다시 눌러 주세요. | 노랑 |
| `guard` | HMG-API는 내비가 켜지고 2분 안의 재부팅이 6번 이어지면 무선 기능을 끕니다.<br>3~5분 뒤에 다시 눌러 주세요. | 노랑 |
| `cmd`, 그 밖의 값, 80초 동안 답 없음 | 재부팅하지 못했습니다. RESET 버튼으로 재부팅해 주세요. | 빨강 |

`install`·`fix`·`sysw` 거절이 처음 거절부터 900초(`RB_STUCK_SECS`) 넘게 이어지면 빨간 RESET 안내로 바꿉니다(`ReportTest`가 봄).

### 순서

좌표는 1920x720 화면 픽셀입니다.

- [지금 재부팅]은 오른쪽 칸 맨 아래에 붙어 있어 힌트·알림 줄과 관계없이 (1600, 672)입니다.
- 확인 창의 [재부팅]은 (1200, 471)입니다.
- 닫기는 뒤로 키(`keyevent 4`)입니다. 앱 안 왼쪽 위 `<`는 없습니다. 차에서는 시스템 줄의 `<`로 닫힐 것으로 보지만, 아직 차에서 확인하지 않았습니다(아래 "이 시험이 보지 않는 것").
- 버튼 안내(보냄·거절·실패)는 버튼 바로 위에 나옵니다.

```sh
ADB=$ANDROID_HOME/platform-tools/adb
shot() { $ADB exec-out screencap -p > out/emu/$1.png; }

# 1. 감시자 없음 → 확인 창 없이 노란 띠 "관리 앱을 닫았다가 다시 연 뒤 눌러 주세요."
sh tests/emu/shot.sh ready
sh tests/emu/watch.sh off
$ADB shell input tap 1600 672; shot rb-nowatch

# 2. 감시자 있음 → 확인 창 → [재부팅] → 어두운 상자 "재부팅합니다…", 버튼 글자 회색(꺼짐)
sh tests/emu/watch.sh on
$ADB shell input tap 1600 672; sleep 1; shot rb-confirm
$ADB shell input tap 1200 471; sleep 1; shot rb-sent

# 3. root가 부팅 보호로 거절 → 노란 띠 RB_GUARD, 버튼 다시 켜짐(시안 글자)
sh tests/emu/watch.sh answer guard; sleep 2; shot rb-guard

# 4. 재부팅 명령이 돌아옴 → 빨간 띠 RESET 안내
$ADB shell input tap 1600 672; sleep 1
$ADB shell input tap 1200 471; sleep 1
sh tests/emu/watch.sh answer cmd; sleep 2; shot rb-failed

# 5. 뒤로 키 → 화면이 닫히고 런처로 돌아감. 왼쪽 위(60, 85)를 눌러도 아무 일 없음(앱 안 < 없음)
$ADB shell input tap 60 85; sleep 1; shot no-back
$ADB shell input keyevent 4; sleep 1; shot closed
```

`watch.sh answer`는 앱이 쓴 `reboot.req`의 id를 그대로 씁니다. [재부팅]을 누르기 전에 부르면 요청이 없다고 멈춥니다.

오른쪽 칸이 넘칠 때도 봅니다. `hint` 시나리오에서 감시자를 끄고 [지금 재부팅]을 누르면, 버튼 안내 띠가 알림 띠와 틈을 두고 따로 보이고, 넘친 목록의 아래 끝이 흐려져야 합니다(PR #34 리뷰 1).

```sh
sh tests/emu/shot.sh hint
sh tests/emu/watch.sh off
$ADB shell input tap 1600 672; shot rb-hint
```

## 진단 기록 확인 창

차에서는 USB 설치기(`usb/troubleShooter` `ask_diag`)가 root로 `DiagActivity`를 열고 `files/diag.ans`를 읽습니다([`design.md`](design.md) "진단 기록"). 여기서는 adb로 같은 명령을 내고 답 파일을 읽습니다.

- 확인 창의 [모으기]는 (808, 596), [건너뛰기]는 (1112, 596)입니다.
- 창 뒤는 투명해서 그 아래 화면(차에서는 DSP OTA 화면)이 그대로 보입니다.

```sh
ANS=/data/data/io.github.jayparklab.nx4kor/files/diag.ans
ask() { $ADB shell rm -f $ANS; $ADB shell am start -n io.github.jayparklab.nx4kor/.DiagActivity --es id $1 --ei wait $2 ${3:+--el until $3}; sleep 3; }

# 1. 창이 뜨면 "<id> shown", [모으기] → "<id> yes", 창이 닫힘
ask 1001 60; shot diag-ask; $ADB shell cat $ANS
$ADB shell input tap 808 596; sleep 2; $ADB shell cat $ANS

# 2. [건너뛰기] → "no", 뒤로(keyevent 4) → "no"
ask 1002 60; $ADB shell input tap 1112 596; sleep 2; $ADB shell cat $ANS
ask 1003 60; $ADB shell input keyevent 4; sleep 2; $ADB shell cat $ANS

# 3. 고르지 않음(wait 5초) → "timeout", 창이 스스로 닫힘
ask 1004 5; sleep 5; $ADB shell cat $ANS

# 4. id 없이 열면 아무것도 쓰지 않고 바로 닫힘(답 파일 없음)
$ADB shell am force-stop io.github.jayparklab.nx4kor
$ADB shell rm -f $ANS; $ADB shell am start -W -n io.github.jayparklab.nx4kor/.DiagActivity; $ADB shell cat $ANS

# 5. until(설치기가 창을 기다리는 마지막 시각)이 지난 뒤 열리면 쓰지 않고 바로 닫힘. 아직이면 평소대로 뜸
ask 1005 60 $(( $($ADB shell date +%s | tr -d '\r') - 1 )); $ADB shell cat $ANS
ask 1006 60 $(( $($ADB shell date +%s | tr -d '\r') + 15 )); $ADB shell cat $ANS; $ADB shell input keyevent 4

# 6. 관리 앱을 연 뒤 홈으로 나간 상태에서 열어도, 창 뒤에 관리 앱이 아니라 그 전 화면(런처)이 보임(자기 task)
$ADB shell am start -n io.github.jayparklab.nx4kor/.StatusActivity; sleep 2; $ADB shell input keyevent 3; sleep 1
ask 1007 60; shot diag-own-task
$ADB shell input tap 1112 596; sleep 2
$ADB shell dumpsys activity activities | grep mResumedActivity   # 런처
```

## 끝난 뒤

```sh
$ADB logcat -d -b crash               # 비어 있으면 앱이 죽은 적 없음
$ADB logcat -d -s AndroidRuntime:E
$ADB emu kill                         # 에뮬레이터 끄기
sh scripts/build-app.sh               # .env.local의 NX4_APP_KEYS(배포용 키)로 다시 빌드
```

## 이 시험이 보지 않는 것

- root 쪽 스크립트(`bin/status.sh`·`--watch`, `svc/lib.sh`), HMG-API 엔진, 실제 Wi-Fi·카플레이·안드로이드 오토. 판정 코드가 맞게 나오는지는 `tests/mod-test.sh`가 봅니다.
- 차의 Android와의 차이(에뮬레이터는 Android 7.0): 글꼴, 화면 밀도, 위젯 모양, SELinux와 파일 권한(차에서 앱이 `/data/local/tmp` 파일을 읽을 수 있는지).
  - 화면 크기는 밀도가 아니라 화면 폭에 맞춰 늘이거나 줄이므로(`Ui.px`) 밀도가 달라도 배치는 같습니다.
  - 에뮬레이터 맨 위의 Android 상태 줄(시각·배터리)이 차에서 어떻게 보일지는 이 시험이 보지 않습니다.
  - 줄 나누기: 에뮬레이터(Android 7)는 한글을 띄어쓰기뿐 아니라 글자 사이에서도 줄을 바꿉니다(예: "눌 / 러 주세요"). 차(Android 4.4로 추정)는 줄 나누기가 다를 수 있으므로, 띠 문구가 어디서 끊기는지는 차에서 확인합니다.
- 순정 화면과 얼마나 같은지. 색·크기는 매뉴얼 그림에서 잰 근사값입니다([#28](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/28)).
- 차의 실제 재부팅. 이 시험의 `watch.sh`는 감시자의 답만 흉내 냅니다.
- 진단 확인 창이 DSP OTA 화면 위에 뜨는지, USB 설치기가 답을 기다리는 흐름. 설치기 쪽은 `tests/mod-test.sh`가 가짜 `am`으로 봅니다.
- 차 화면 맨 위 시스템 줄의 `<`가 앱에 뒤로 키로 가는지. 이 시험은 `keyevent 4`만 봅니다(차에서 확인, [`design.md`](design.md) "차에서 확인할 것", 결과는 [#64](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/64)).

## 마지막 결과

2026-11-27, 제목 줄의 앱 안 `<`를 뺀 앱(테스트 키), 같은 에뮬레이터·이미지, 창 없이.

- `nowifipart`: 제목 줄에 가운데 "NX4 KOR 2.0.0"만 보이고 왼쪽 위 `<`가 없음. 나머지(노란 띠, 요약 3줄, [지금 재부팅])는 전과 같음.
- 왼쪽 위(60, 85)를 눌러도 관리 앱이 그대로 앞에 있음. 뒤로 키(`keyevent 4`)를 누르면 런처로 돌아감.
- `installing`: 설치 진행 화면은 전과 같음(제목 줄이 없고 맨 아래 [닫기] 블록).
- `logcat`에 이 앱의 크래시 없음(에뮬레이터가 켜질 때의 `BatteryService` 한 건뿐).

아래는 그 전 결과입니다.

2026-11-24, PR #50(2.1.0 상태 판정)의 앱(테스트 키), 에뮬레이터 37.2.13, Android 7.0 arm64 이미지, 창 없이(`-no-window`) 띄워 화면을 찍음.

- 시나리오 10개(`ready connected installing reboot failed nowireless nowifipart nocar nobb hint`) 모두 위 표대로 나옴.
  - 자세히 표를 내려 보면 새 줄(공식 무선 모드 "2.2.0-rc.9, 켜짐", 순정 핫스팟 기능 (Wi-Fi 칩 전원), Wi-Fi 칩, 무선 연결용 Wi-Fi (HMG-API))이 줄바꿈 없이 한 줄씩 보임.
  - `nowifipart`: 노란 띠 네 줄, 지우는 법 줄 없음, 표의 Wi-Fi 칩 "안 보임", 무선 연결용 Wi-Fi "꺼짐 (켜지 못함, 다시 시도 중)".
  - `nowireless`: 빨간 띠 네 줄, 표의 무선 연결용 Wi-Fi "꺼짐 (이번 부팅에 켰다가 꺼짐)".
- [지금 재부팅] 5단계(감시자 없음, 확인 창, 보냄, `guard`·`cmd` 답, `<` 닫기) 모두 위대로 나옴.
- `logcat`에 이 앱의 크래시 없음.

아래는 그 전 결과입니다.

2026-11-20, 앱 2.0.0(versionCode 38, 순정 5W 모양 #28), 에뮬레이터 37.2.13, Android 7.0 arm64 이미지.

- 시나리오 9개 모두 위 표대로 나옴. 바꾸기 전(2026-11-19 모양)과 나란히 찍어 비교함.
- [지금 재부팅] 4단계(감시자 없음, 확인 창, 요청 보냄, `guard`·`cmd` 답)와 `<` 닫기 모두 위대로 나옴. `reboot.req`는 `<id> <boot_id> <초>` 형식.
- 오른쪽 칸이 넘칠 때(`rb-hint`): 버튼 안내 띠가 알림 띠와 틈을 두고 따로 보이고, 넘친 알림 띠의 아래 끝이 흐려짐(PR #34 리뷰 1을 고친 뒤 다시 봄).
- `logcat`에 이 앱의 크래시 없음. 에뮬레이터가 켜질 때 시스템의 `BatteryService`가 남긴 크래시 한 건은 앱과 관계없음.
- 사소한 점: 확인 창이 떠 있는 동안 그 뒤에 직전 안내(예: 감시자 없음)가 남아 보임. [재부팅]을 누르면 바로 바뀜.

진단 기록 확인 창은 2026-11-23, PR #41 브랜치의 앱(시험 키), 같은 에뮬레이터에서 봤습니다.

- 투명 화면 위에 확인 창("진단 기록 모으기", 본문, [모으기]·[건너뛰기])만 보임
- 답 파일:
  - 창이 뜨면 `<id> shown`
  - [모으기]는 `yes`, [건너뛰기]·뒤로는 `no`
  - 5초 동안 고르지 않으면 `timeout`. 모두 창이 닫힘
- id 없이 열면 답 파일을 쓰지 않고 바로 닫힘
- `until`이 지난 뒤 열면 답 파일을 쓰지 않고 바로 닫힘. 아직이면 평소대로 `shown`(PR #41 리뷰 6)
- 관리 앱을 연 뒤 홈으로 나가 관리 앱 task가 뒤에 있어도, 창 뒤에 런처가 보이고 [건너뛰기] 뒤에도 런처가 앞에 옴(자기 task, PR #41 리뷰 7)
- 이 앱의 크래시 없음
