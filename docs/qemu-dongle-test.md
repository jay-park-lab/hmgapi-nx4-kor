# QEMU에서 USB Wi-Fi 동글 테스트

PC에 꽂은 동글을 QEMU 가상 머신(ARMv7)으로 넘겨, 우리 동글 드라이버와 패치가 실제 동글에서 도는지 차에 가기 전에 봅니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)).

## 무엇을 올리나

차에 넣을 `.ko`를 그대로 올리지는 못합니다.

- 차 커널(현대모비스 소스, Telechips tcc803x 보드용)은 QEMU에 그 보드가 없어 부팅하지 못합니다.
- 차의 `.ko`는 그 커널 빌드에만 맞습니다.

그래서 **같은 판의 커널**(kernel.org 3.18.24)을 QEMU `virt` 보드(ARMv7, cortex-a15)용으로 빌드합니다. 그 커널에 **같은 드라이버 소스와 우리 패치**(`drivers/<드라이버>/*.diff`)를 다시 빌드해 올립니다.

- 커널 설정의 무선·코어 부분은 차와 같게 둡니다. cfg80211(내장), `NL80211_TESTMODE`, `CFG80211_WEXT`, RFKILL, mac80211 없음, 내장 규제 DB 없음(`CFG80211_INTERNAL_REGDB` 꺼짐), LPAE·HIGHMEM·PREEMPT·SMP입니다(`tests/qemu/build-guest.sh`).
- 툴체인도 차 빌드와 같은 모비스 `arm-eabi-4.7`입니다. vermagic은 `3.18.24 SMP preempt mod_unload ARMv7 p2v8`로, 차(`3.18.24-tcc …`)와 판 꼬리만 다릅니다.
- USB는 차처럼 EHCI(PCI `usb-ehci`)에 고속(480 Mb/s)으로 붙습니다.
- 드라이버는 차의 순정 HAL이 `bcmdhd`에 주는 인자 그대로 올립니다: `iface_name=wlan0 firmware_path=… nvram_path=… clm_path=…`(USB 진단 기록 `dongle/wifi-strings.txt`).

### 보는 것과 못 보는 것

| 봄 | 못 봄(차에서 확인) |
|---|---|
| 동글이 이 드라이버로 잡히는지, `wlan0` | 차의 `.ko`와 보드(tcc803x USB) 자체 |
| 차 HAL 인자를 받는지(모르는 인자는 3.18이 경고만 남김) | 순정 HAL·`netd`·HMG-API가 AP를 켜는 흐름, `mac_address_read`·`wifi_check_module_info` |
| 채널 표(국가 코드에 따라 5GHz가 막히는지) | 순정이 부팅 약 40초에 포트 전원을 끄고 켜는 것([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48#issuecomment-7207207758)) |
| `hostapd`로 2.4GHz·5GHz 149번 AP, 폰으로 붙기 | 순정 USB 서비스의 AOA 요청 |
| 쓰는 중에 뽑았을 때 보호 패치(`nx4-protect:` 줄, 커널 멈춤 여부) | 무선 카플레이·안드로이드 오토 연결 |
| 드라이버 내리기(`rmmod`) | |

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

- `matrix`(기본, 사람 손 필요 없음, 약 5분):
  - 차 HAL 인자로 올린 채널 표
  - `rtw_country_code=KR`을 더해 올린 채널 표
  - 스캔
  - AP 넷: 2.4GHz 6번, 5GHz 149번(국가 코드 없음), 5GHz 149번(`hostapd` `country_code=KR`), 차와 같은 상태(HAL 인자만)로 5GHz 149번
- `interactive`:
  - `rtw_country_code=KR`로 올려 5GHz 149번 AP(SSID `NX4-QEMU-TEST`, 비밀번호 `nx4-qemu-test`)를 3분 띄웁니다. 폰에서 붙어 봅니다.
  - 그다음 "동글을 뽑아 주세요"가 나오면 PC에서 동글을 뽑습니다.
- 두 번째 인자로 드라이버를 고릅니다(`rtl8831bu` 기본, `rtl88x2bu`).
- 환경 변수:
  - `NX4_QEMU_USB=VID:PID`: 넘길 동글. 기본은 RTL8831BU `0bda:b831`, RTL88x2BU `0bda:b812`
  - `NX4_QEMU_AP_SECS`, `NX4_QEMU_UNPLUG_SECS`
  - `NX4_QEMU_NOBUILD=1`: 지난 빌드를 다시 씀
- 워크트리에는 `.env.local`이 없으니 명령 앞에 `NX4_ENV_FILE=<메인 체크아웃>/.env.local`을 줍니다.
- 결과는 `out/qemu-test/<드라이버>/`에 남습니다(`console-<모드>-<시각>.log`). 끝에 `== `(단계)와 `-- `(AP 결과) 줄을 모아 보여 줍니다.
- 맥에서는 QEMU가 `libusb_kernel_driver_active: -5`를 여러 번 찍습니다. 맥에 이 동글의 커널 드라이버가 없다는 뜻이라 스크립트가 거릅니다.
- VM에 동글이 보이지 않았으면 스크립트가 알립니다. PC에 꽂혀 있는지, 다른 가상 머신이 잡고 있지 않은지 봅니다.

## 결과

### 2026-11-27, RTL8831BU(사용자 동글 `0bda:b831`), `matrix`

| 단계 | 결과 |
|---|---|
| 드라이버 올리기(차 HAL 인자) | 됨. `wlan0` 생김. `bcmdhd: unknown parameter 'clm_path' ignored`(3.18이 모르는 인자를 넘김) |
| 채널 표(HAL 인자만) | 2.4GHz는 됨. **5GHz 36·149~165번이 모두 `no IR`**(전파를 먼저 낼 수 없음). 동글 efuse의 세계 공통 채널 계획으로 보임 |
| 채널 표(`rtw_country_code=KR`) | 5GHz 36·149~165번이 풀림 |
| 스캔 | 2.4GHz AP 10~11개. 5GHz는 0개(주변에 5GHz AP가 없었는지는 모름) |
| AP 2.4GHz 6번 | 섬 |
| AP 5GHz 149번(KR로 올림) | 섬. `hostapd`에 `country_code=KR`을 넣어도 섬 |
| AP 5GHz 149번(HAL 인자만, 지금 차와 같은 상태) | **서지 않음**: "Configured channel (149) … not found from the channel list … Hardware does not support configured channel" |
| `rmmod`(AP를 쓴 뒤) | 내려감. 드라이버 경고 하나(`rtw_warn_on` ← `rtw_phl_wifi_role_free`), 커널 멈춤 없음 |

**뜻하는 것:** 순정 HAL은 국가 코드를 넘기지 않습니다. 그래서 드라이버의 기본 국가 코드를 KR로 두지 않으면 차에서 5GHz 프로젝션 AP가 서지 않습니다. 4단계에서 HAL 패치에 넣습니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48)).

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
