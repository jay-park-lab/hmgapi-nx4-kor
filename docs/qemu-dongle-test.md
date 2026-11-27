# QEMU에서 USB Wi-Fi 동글 테스트

PC에 꽂은 동글을 QEMU 가상 머신(ARMv7)으로 넘겨, 우리 동글 드라이버와 패치가 실제 동글에서 도는지 차에 가기 전에 봅니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)).

## 무엇을 올리나

차에 넣을 `.ko`를 그대로 올리지는 못합니다.

- 차 커널(현대모비스 소스, Telechips tcc803x 보드용)은 QEMU에 그 보드가 없어 부팅하지 못합니다.
- 차의 `.ko`는 그 커널 빌드에만 맞습니다.

그래서 **같은 판의 커널**(kernel.org 3.18.24)을 QEMU `virt` 보드(ARMv7, cortex-a15)용으로 빌드합니다. 그 커널에 **같은 드라이버 소스와 우리 패치**(`drivers/<드라이버>/*.diff`)를 다시 빌드해 올립니다.

- 커널 설정의 무선·코어 부분은 차에 맞춥니다(`tests/qemu/build-guest.sh`).
  - 같게 둔 것: cfg80211(내장), `NL80211_TESTMODE`, `CFG80211_WEXT`, RFKILL, mac80211 없음, 내장 규제 DB 없음(`CFG80211_INTERNAL_REGDB` 꺼짐), LPAE·HIGHMEM·PREEMPT·SMP, `HZ=100`
  - 스택 보호는 REGULAR입니다. 차 설정은 STRONG이지만 GCC 4.7에 없어 차 빌드도 REGULAR로 빌드합니다(`drivers/kernel/prepare.sh`).
  - 맞추지 못한 것: `CONFIG_WAKELOCK`(안드로이드 커널에만 있음). RTL8831BU의 wake lock 코드는 게스트에서 돌지 않습니다.
- 툴체인도 차 빌드와 같은 모비스 `arm-eabi-4.7`입니다. vermagic은 `3.18.24 SMP preempt mod_unload ARMv7 p2v8`로, 차(`3.18.24-tcc …`)와 판 꼬리만 다릅니다.
- USB는 차처럼 EHCI(PCI `usb-ehci`)에 고속(480 Mb/s)으로 붙습니다.
- 드라이버는 차의 순정 HAL이 `bcmdhd`에 주는 인자 그대로 올립니다: `iface_name=wlan0 firmware_path=… nvram_path=… clm_path=…`(USB 진단 기록 `dongle/wifi-strings.txt`). 우리 HAL 패치가 기본 국가 코드를 KR로 두므로 이것만으로 KR입니다(`drivers/README.md` "드라이버를 순정 HAL 자리에 맞추기"). 국가 코드 없이 올릴 때는 `rtw_country_code=`(빈 값, 패치 전 원본과 같음)를 더합니다.

### 보는 것과 못 보는 것

| 봄 | 못 봄(차에서 확인) |
|---|---|
| 동글이 이 드라이버로 잡히는지, `wlan0` | 차의 `.ko`와 보드(tcc803x USB) 자체 |
| 차 HAL 인자를 받는지(모르는 인자는 3.18이 경고만 남김) | 순정 HAL·`netd`·HMG-API가 AP를 켜는 흐름, `mac_address_read`·`wifi_check_module_info` |
| 채널 표(국가 코드에 따라 5GHz가 막히는지) | 순정이 부팅 약 40초에 포트 전원을 끄고 켜는 것([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48#issuecomment-7207207758)) |
| `hostapd`로 2.4GHz·5GHz 149번 AP, 폰으로 붙기 | 순정 USB 서비스의 AOA 요청 |
| 쓰는 중에 뽑았을 때 보호 패치(`nx4-protect:` 줄, 커널 멈춤 여부) | 무선 카플레이·안드로이드 오토 연결 |
| 드라이버 내리기(`rmmod`) | 드라이버의 wake lock(`CONFIG_WAKELOCK`), 차의 규제 정보 처리(게스트에는 CRDA도 없음) |

## 필요한 것

- **QEMU**: 맥은 `brew install qemu`(`qemu-system-arm`).
- **Docker와 드라이버 빌드 볼륨**: `sh scripts/build-driver.sh`를 한 번 돌려 둡니다. 이 테스트는 그 볼륨(`nx4kor-drivers`)에 받아 둔 커널 묶음·툴체인·드라이버 소스를 다시 쓰고, 볼륨의 `/work/qemu`에만 씁니다. Docker context도 `.env.local`의 `NX4_DRV_DOCKER_CONTEXT`를 똑같이 씁니다(`drivers/README.md` "맥에서 빌드").
- **동글**: PC에 꽂아 둡니다. QEMU가 도는 동안 VM으로 넘어가 PC에서는 쓰지 못합니다.
- 게스트 루트 파일 시스템은 Alpine Linux 3.18 armv7에 `hostapd`·`iw`·`iproute2`를 넣어 만듭니다. 받는 묶음과 sha256은 `tests/qemu/inputs.sh`에 있습니다.

## 돌리기

저장소 맨 위에서:

```bash
sh scripts/qemu-dongle-test.sh matrix
```

```bash
sh scripts/qemu-dongle-test.sh interactive
```

- `matrix`(기본, 사람 손 필요 없음, 약 6분):
  - 국가 코드 없이(`rtw_country_code=`) 올린 채널 표
  - HAL 인자만으로(기본 KR, 차에서 올라가는 모양) 올린 채널 표
  - 스캔
  - AP 다섯
    - HAL 인자만으로 올린 드라이버: 2.4GHz 6번, 5GHz 149번(`hostapd` 국가 코드 없음), 5GHz 149번(`hostapd` `country_code=KR`)
    - 국가 코드 없이 올린 드라이버: 5GHz 149번(`hostapd` 국가 코드 없음), 5GHz 149번(`hostapd` `country_code=KR`)
- `interactive`:
  - HAL 인자만으로(기본 KR) 올려 5GHz 149번 AP(SSID `NX4-QEMU-TEST`, 비밀번호 `nx4-qemu-test`)를 3분 띄웁니다. 폰에서 붙어 봅니다.
  - 그다음 "동글을 뽑아 주세요"가 나오면 PC에서 동글을 뽑습니다.
- 두 번째 인자로 드라이버를 고릅니다(`rtl8831bu` 기본, `rtl88x2bu`).
- 환경 변수:
  - `NX4_QEMU_USB=VID:PID`: 넘길 동글. 기본은 RTL8831BU `0bda:b831`, RTL88x2BU `0bda:b812`
  - `NX4_QEMU_AP_SECS`, `NX4_QEMU_UNPLUG_SECS`
  - `NX4_QEMU_NOBUILD=1`: 지난 빌드를 다시 씀
  - `NX4_QEMU_TIMEOUT`: 이 초가 지나도 끝나지 않으면 QEMU를 끝냄(기본은 모드와 AP 초로 셈)
- 워크트리에는 `.env.local`이 없으니 명령 앞에 `NX4_ENV_FILE=<메인 체크아웃>/.env.local`을 줍니다.
- 결과는 `out/qemu-test/<드라이버>/`에 남습니다(`console-<모드>-<시각>.log`). 끝에 `== `(단계)와 `-- `(결과) 줄을 모아 보여 줍니다. 결과 줄은 insmod(종료 코드·`wlan0`), 채널(5GHz no IR 수), 스캔, AP마다(끝까지 hostapd가 살아 있고 AP였는지, 붙은 기기 수), rmmod(종료 코드, 그 사이 늘어난 커널 경고·멈춤 줄 수), 뽑기입니다.
- 게스트가 멈춰도 끝납니다. 게스트 커널은 패닉 1초 뒤 재부팅하고(`panic=1`, `-no-reboot`라 QEMU가 끝남), 스크립트는 시간 제한이 지나면 QEMU를 끝냅니다. 기록에 `== 끝`이 없거나 시간 제한에 걸렸으면 알립니다.
- 중간에 Ctrl-C(또는 TERM)로 멈추면 QEMU와 시간 제한 지킴이도 함께 끝납니다. 동글은 PC로 돌아옵니다. 실행마다 다른 이름의 파일을 써서, 바로 다시 돌려도 앞 실행이 새 실행의 QEMU를 건드리지 않습니다.
- Docker VM이 저장소나 결과 폴더를 보지 못하면(colima는 홈 폴더 같은 정해진 곳만 붙임) 멈추고 알립니다.
- 맥에서는 QEMU가 `libusb_kernel_driver_active: -5`를 여러 번 찍습니다. 맥에 이 동글의 커널 드라이버가 없다는 뜻이라 스크립트가 거릅니다.
- VM에 동글이 보이지 않았으면 스크립트가 알립니다. PC에 꽂혀 있는지, 다른 가상 머신이 잡고 있지 않은지 봅니다.

## 결과

### 2026-11-27, RTL8831BU(사용자 동글 `0bda:b831`), `matrix`, HAL 패치의 기본 국가 코드 KR

아래 첫 결과로 HAL 패치의 기본 국가 코드를 KR로 둔 뒤 돌린 결과입니다(`drivers/*/0002-nx4-hal.diff`).

| 단계 | 결과 |
|---|---|
| 채널 표(국가 코드 없이, `rtw_country_code=`) | 5GHz 149·153·157번이 모두 `no IR`(아래 첫 결과와 같음) |
| 채널 표(HAL 인자만, 기본 KR) | `no IR` 없음 |
| 스캔(HAL 인자만) | 2.4GHz AP 11개, 5GHz 0개 |
| AP 2.4GHz 6번(HAL 인자만) | 섬 |
| AP 5GHz 149번(HAL 인자만, `hostapd` 국가 코드 없음·`country_code=KR`) | **둘 다 섬** |
| AP 5GHz 149번(국가 코드 없이, `hostapd` 국가 코드 없음·`country_code=KR`) | 둘 다 서지 않음(아래 첫 결과와 같음, "Configured channel (149) … not found") |
| `rmmod` | 모두 종료 코드 0, 커널 멈춤 없음. AP를 쓴 뒤 내릴 때 드라이버 경고 하나(아래와 같음) |

차에서 순정 HAL이 주는 인자만으로 올라가도 5GHz 149번 AP를 띄울 수 있게 되었습니다(게스트 기준. 차 확인은 [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)).

### 2026-11-27, RTL8831BU(사용자 동글 `0bda:b831`), `matrix`, HAL 패치에 국가 코드가 없을 때

PR #93 리뷰 반영 뒤 판(게스트 `HZ=100`, 스택 보호 REGULAR)으로 다시 돌린 결과입니다. 처음 판(HZ 200, 스택 보호 없음)과 같았습니다. 이때는 "HAL 인자만"이 국가 코드 없음이었고, KR은 `rtw_country_code=KR`을 더해 올렸습니다.

| 단계 | 결과 |
|---|---|
| 드라이버 올리기(차 HAL 인자) | 됨, `wlan0`. `bcmdhd: unknown parameter 'clm_path' ignored`(3.18이 모르는 인자를 넘김) |
| 채널 표(HAL 인자만) | 2.4GHz는 됨. **5GHz 36·149~165번이 모두 `no IR`**(전파를 먼저 낼 수 없음). 동글 efuse의 세계 공통 채널 계획으로 보임 |
| 채널 표(`rtw_country_code=KR`) | 5GHz 36·149~165번이 풀림 |
| 스캔 | 2.4GHz AP 8~11개. 5GHz는 0개(주변에 5GHz AP가 없었는지는 모름) |
| AP 2.4GHz 6번(KR) | 섬 |
| AP 5GHz 149번(KR, `hostapd` 국가 코드 없음·`country_code=KR`) | 둘 다 섬 |
| AP 5GHz 149번(HAL 인자만, `hostapd` 국가 코드 없음) | **서지 않음**: "Configured channel (149) … not found from the channel list … Hardware does not support configured channel" |
| AP 5GHz 149번(HAL 인자만, `hostapd` `country_code=KR`) | **서지 않음**: "Frequency 5745 (primary) not allowed for AP mode, flags: 0x3 NO-IR". 게스트에는 CRDA도 내장 규제 DB도 없어 hostapd의 국가 코드로는 채널이 풀리지 않음 |
| `rmmod` | 모두 종료 코드 0, 커널 멈춤 없음. AP를 쓴 뒤 내릴 때 드라이버 경고 하나(`rtw_warn_on` ← `rtw_phl_wifi_role_free`) |

**뜻하는 것[추정]:** 이 테스트가 보인 것은 "국가 코드 없이 올린 드라이버에서는 hostapd 설정의 국가 코드와 상관없이 5GHz 149번 AP가 서지 않는다(CRDA·내장 규제 DB가 없을 때)"입니다. 차도 그렇다고 보는 전제는 아래와 같습니다.

- 순정 HAL은 `rtw_country_code`를 넘기지 않습니다(`dongle/wifi-strings.txt`의 insmod 인자).
- 차 커널도 내장 규제 DB가 없고(`CFG80211_INTERNAL_REGDB` 꺼짐), 안드로이드 4.4에는 보통 CRDA가 없습니다.
- 순정 `bcmdhd`는 국가 코드를 `nvram_path`(`bcmdhd.cal`)의 `ccode` 같은 값으로 받을 수 있지만, 우리 패치는 `nvram_path`를 받아 두기만 합니다.

그래서 HAL 패치의 기본 국가 코드를 KR로 두었습니다(위 결과). 차 확인(netd가 만드는 `hostapd.conf`의 `country_code` 줄(비밀번호가 든 파일이라 그 줄만), `bcmdhd.cal`의 `ccode` 줄)은 [#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)과 `drivers/README.md` "차에서 확인할 것"에 있습니다.

폰으로 붙기와 쓰는 중에 뽑기(`interactive`)는 아직 하지 않았습니다.

## 파일

| 파일 | 내용 |
|---|---|
| `scripts/qemu-dongle-test.sh` | PC에서 부르는 것: 빌드(Docker) → 루트 파일 시스템 → QEMU, 기록 |
| `tests/qemu/build-guest.sh` | 게스트 커널(3.18.24, QEMU virt)과 드라이버 빌드(드라이버 빌드 이미지 안) |
| `tests/qemu/build-rootfs.sh` | Alpine armv7 루트 파일 시스템(ext4 이미지) |
| `tests/qemu/nx4init` | 게스트 안에서 도는 테스트(`MODE=matrix`·`interactive`) |
| `tests/qemu/inputs.sh` | 받는 묶음과 sha256 |

`tests/qemu/`는 `drivers/` 밖에 둡니다. `drivers/`를 바꾼 커밋의 시각이 차에 넣을 `.ko`의 빌드 날짜가 되기 때문입니다(`scripts/build-driver.sh`). 이 테스트를 고쳐도 차의 `.ko`는 바뀌지 않습니다.
