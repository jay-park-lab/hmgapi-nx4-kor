# 에뮬레이터 시험 (상태 화면 앱)

Android 에뮬레이터에서 NX4 KOR 상태 화면 앱(`io.github.jayparklab.nx4kor/.StatusActivity`)을 실제로 띄워, 상태마다 화면이 맞게 나오는지와 [지금 재부팅] 버튼이 root 쪽 답에 맞게 안내하는지 봅니다.

차에서는 root 쪽 스크립트가 `/data/local/tmp/nx4-kor-*.txt`를 쓰고 앱은 그 파일만 읽습니다. 이 시험은 그 파일을 손으로 만들어 넣습니다. 그래서 **앱 화면과 앱·root 사이 파일 약속**을 보고, root 쪽 스크립트·HMG-API·Wi-Fi는 보지 않습니다(그쪽은 `tests/mod-test.sh`).

| 파일 (`/data/local/tmp/`) | 차에서 쓰는 쪽 | 시험에서 넣는 것 |
|---|---|---|
| `nx4-kor-status.txt` | `mod/bin/status.sh` | `tests/emu/scen.sh` |
| `nx4-kor-progress.txt` | `mod/svc/hotspot.sh` (설치 진행) | `tests/emu/scen.sh` |
| `nx4-kor-notice.txt` | `mod/svc/hotspot.sh` (알림) | `tests/emu/scen.sh hint` |
| `nx4-kor-hint.txt` | `mod/svc/hotspot.sh` (`hint_write`) | `tests/emu/scen.sh hint` |
| `nx4-kor-watch.txt` | `mod/bin/status.sh --watch` (재부팅 요청 감시자) | `tests/emu/watch.sh on` |
| `nx4-kor-reboot-result.txt` | `mod/bin/status.sh --watch` | `tests/emu/watch.sh answer <code>` |

앱이 쓰는 파일은 앱 폴더의 `files/reboot.req` 하나입니다(`<요청 id> <boot_id> <부팅 뒤 초>` 한 줄).

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
- 밀도 240(앱 아래 줄에 "밀도 1.5"로 보임)은 어림값입니다. 차에서 상태 화면 아래 줄의 "화면 …(밀도 …)"를 보고 다르면 맞춥니다.
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

## 상태 화면 시나리오

```sh
for s in ready connected installing reboot mapfail oldmod nocar nobb hint; do
  sh tests/emu/shot.sh $s
done
```

`shot.sh`는 `scen.sh <시나리오>`로 파일을 넣고, 앱을 끈 뒤 다시 열고, 2초 기다렸다가 `out/emu/<시나리오>.png`를 찍습니다(`OUT=<폴더>`로 바꿀 수 있음). 바로 찍으면 앱이 그리기 전이라 런처가 찍힙니다.

| 시나리오 | 넣는 것 | 볼 것 |
|---|---|---|
| `ready` | `verdict=ready`, 진행 100% | 초록 "무선 카플레이·안드로이드 오토 준비됨.", [지금 재부팅], 요약 3줄(설치·무선 Wi-Fi·폰 연결), "자세히" 표, 아래 [닫기]와 확인 시각·앱 판·화면 크기 |
| `connected` | `cp_conn=1`, `verdict=connected` | 초록 "무선 카플레이 연결됨, 안드로이드 오토 준비됨", "폰 연결: 카플레이 1대 연결됨" |
| `installing` | 진행 `pct=55`, `step=3/5`, `state=run` | 상태 화면 대신 설치 진행 화면: "NX4 KOR 2.0.0 설치 중", "단계 3/5 · map을 확인하는 중입니다", 막대 55%, "경과 2분 02초", "보통 5분 안에 끝납니다 …", [닫기] |
| `reboot` | `verdict=reboot` | 노란 "내비를 3분 후 재부팅해 주세요." |
| `mapfail` | `verdict=mapfail`, `hookmap=mismatch` | 빨간 안내(긴 문구가 두 줄로 줄바꿈), "설치: 안 됨(위 안내를 보세요)" |
| `oldmod` | `verdict=oldmod`, `oldmod=yes` | 빨간 "따로 설치된 무선 모드(wireless-carplay-aa)가 있어 …" 두 줄 |
| `nocar` | 다른 차 `product`, `verdict_end=yes` | 빨간 "지원하지 않는 차입니다 …"와 지우는 방법 안내 |
| `nobb` | 짧은 상태 파일(`support=nobb`) | 노란 "이 내비에서는 동작하지 않습니다(busybox를 실행하지 못함) …", 짧은 표, **[지금 재부팅] 없음** |
| `hint` | `ready`와 같고 힌트(`iph=wifi`, `aa=cpwait`)·알림 | 주황 두 줄(아이폰 Wi-Fi 다시 연결, 안드로이드 오토는 카플레이 연결 중이라 대기), 연한 노란 "알림 HH:MM …", 그 아래 [지금 재부팅] |

각 파일의 키는 `mod/bin/status.sh`(`status_kv`, `st_verdict`)와 `app/java/.../Report.java`를 따릅니다. 판정 코드를 더하거나 문구를 바꾸면 `scen.sh`에도 같은 경우를 넣습니다.

## [지금 재부팅] 버튼

### 앱과 root 사이 약속

1. 버튼을 누르면 앱이 감시자 파일(`nx4-kor-watch.txt`: `boot=<boot_id>`, `until=<부팅 뒤 초>`)을 봅니다. 이번 부팅 것이 아니거나 3초 안에 끝나면 요청을 보내지 않고 바로 "상태 화면을 닫았다가 다시 연 뒤 눌러 주세요."를 보입니다.
2. 감시자가 있으면 확인 창("차를 세운 상태에서만 누르세요. …")을 띄웁니다. [재부팅]을 누르면 `files/reboot.req`를 쓰고, 버튼을 끄고, "재부팅합니다…"를 보입니다.
3. 1초마다 `nx4-kor-reboot-result.txt`(`id=`, `boot=`, `code=`)를 읽습니다. 내 요청 id와 이번 부팅의 답이면 아래 표대로 안내하고 버튼을 다시 켭니다. 80초(`RB_WAIT`) 안에 답이 없으면 실패로 봅니다.

| `code` | 안내 | 색 |
|---|---|---|
| `install`, `fix`, `sysw` | 설정을 마무리하는 중입니다. 잠시 뒤 다시 눌러 주세요. | 노랑 |
| `old`, `bad` | 재부팅 요청을 받지 못했습니다. 다시 눌러 주세요. | 노랑 |
| `guard` | 3분 안에 재부팅을 반복하면 HMG-API가 무선 기능을 끕니다. … | 노랑 |
| `cmd`, 그 밖의 값, 80초 동안 답 없음 | 재부팅하지 못했습니다. RESET 버튼으로 재부팅해 주세요. | 빨강 |

`install`·`fix`·`sysw` 거절이 처음 거절부터 900초(`RB_STUCK_SECS`) 넘게 이어지면 빨간 RESET 안내로 바꿉니다(`ReportTest`가 봄).

### 순서

좌표는 1920x720 화면 픽셀이고, `ready` 화면(힌트 줄 없음) 기준입니다. 힌트·알림 줄이 있으면 버튼이 아래로 내려가므로 화면을 찍어 보고 좌표를 고칩니다.

```sh
ADB=$ANDROID_HOME/platform-tools/adb
shot() { $ADB exec-out screencap -p > out/emu/$1.png; }

# 1. 감시자 없음 → 확인 창 없이 노란 "상태 화면을 닫았다가 다시 연 뒤 눌러 주세요."
sh tests/emu/shot.sh ready
sh tests/emu/watch.sh off
$ADB shell input tap 110 222;  shot rb-nowatch

# 2. 감시자 있음 → 확인 창 → [재부팅] → "재부팅합니다…", 버튼 꺼짐
sh tests/emu/watch.sh on
$ADB shell input tap 110 222;  sleep 1; shot rb-confirm
$ADB shell input tap 1211 476; sleep 1; shot rb-sent

# 3. root가 부팅 보호로 거절 → 노란 RB_GUARD, 버튼 다시 켜짐
sh tests/emu/watch.sh answer guard; sleep 2; shot rb-guard

# 4. 재부팅 명령이 돌아옴 → 빨간 RESET 안내
$ADB shell input tap 110 222;  sleep 1
$ADB shell input tap 1211 476; sleep 1
sh tests/emu/watch.sh answer cmd; sleep 2; shot rb-failed
```

`watch.sh answer`는 앱이 쓴 `reboot.req`의 id를 그대로 씁니다. [재부팅]을 누르기 전에 부르면 요청이 없다고 멈춥니다.

## 끝난 뒤

```sh
$ADB logcat -d -b crash               # 비어 있으면 앱이 죽은 적 없음
$ADB logcat -d -s AndroidRuntime:E
$ADB emu kill                         # 에뮬레이터 끄기
sh scripts/build-app.sh               # .env.local의 NX4_APP_KEYS(배포용 키)로 다시 빌드
```

## 이 시험이 보지 않는 것

- root 쪽 스크립트(`svc/hotspot.sh`, `bin/status.sh --watch`), HMG-API 엔진, 실제 Wi-Fi·카플레이·안드로이드 오토. 판정 코드가 맞게 나오는지는 `tests/mod-test.sh`가 봅니다.
- 차의 Android와의 차이(에뮬레이터는 Android 7.0): 글꼴, 화면 밀도, 위젯 모양, SELinux와 파일 권한(차에서 앱이 `/data/local/tmp` 파일을 읽을 수 있는지).
- 차의 실제 재부팅. 이 시험의 `watch.sh`는 감시자의 답만 흉내 냅니다.

## 마지막 결과

2026-11-19, 앱 2.0.0(versionCode 38), 에뮬레이터 37.2.13, Android 7.0 arm64 이미지.

- 시나리오 9개 모두 위 표대로 나옴.
- [지금 재부팅] 4단계(감시자 없음, 확인 창, 요청 보냄, `guard`·`cmd` 답) 모두 위 표대로 나옴. `reboot.req`는 `<id> <boot_id> <초>` 형식.
- `logcat` 크래시 없음.
- 사소한 점: 확인 창이 떠 있는 동안 그 뒤에 직전 안내(예: 감시자 없음)가 남아 보임. [재부팅]을 누르면 바로 바뀜.
