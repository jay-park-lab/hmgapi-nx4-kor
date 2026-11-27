# USB Wi-Fi 동글 드라이버

투싼 NX4 한국 내비(tcc803x, 커널 `3.18.24-tcc`)에서 쓸 USB Wi-Fi 동글 드라이버를 만드는 곳입니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48) 2·3단계). 아직 모드에 넣지 않았고, 차에서 확인하지 않았습니다.

- 드라이버는 둘입니다. 같은 커널 트리(아래 "커널 준비")와 같은 툴체인으로 빌드합니다.
  - **RTL88x2BU**(ipTIME A3000MINI `0bda:b812`, TP-Link Archer T3U `2357:012d` 등): [cilynx/rtl88x2bu](https://github.com/cilynx/rtl88x2bu), 패치 `rtl88x2bu/`
  - **RTL8831BU**(`0bda:b831`, Wi-Fi 6 AX900급 1T1R, 예: TOTOLINK X900USM. 같은 드라이버가 RTL8851BU `0bda:b851`도 받음): [hyeondg/rtl8831bu](https://github.com/hyeondg/rtl8831bu)(Realtek v1.19.10 G6/phl), 패치 `rtl8831bu/`
- 이 폴더(`drivers/`)의 패치·스크립트는 **GPL-2.0**입니다(드라이버와 커널이 GPL-2.0이기 때문, 전문은 `COPYING`). 저장소의 다른 부분은 AGPL-3.0이고, 이 폴더를 Docker로 돌리는 `scripts/build-driver.sh`도 AGPL-3.0입니다. 출처는 아래 "출처와 라이선스"에 있습니다.

## 한눈에

```
kernel.org linux-3.18.24 (빌드 뼈대)
  + 현대모비스 GPL 공개 소스의 내비 커널 폴더 AVNT5W_TCC803XKK_kernel/ (우리 릴리스 자산으로 받음)
  + 모비스 defconfig를 차 설정과 같게 맞춤 → modules_prepare           ← drivers/kernel/prepare.sh
  → 모비스 소스에 든 GCC 4.7로 드라이버 둘을 컴파일                      ← drivers/build-in-container.sh
      cilynx/rtl88x2bu + rtl88x2bu/ 패치 2개  → tcc803x/rtl88x2bu/bcmdhd.ko
      hyeondg/rtl8831bu + rtl8831bu/ 패치 3개 → tcc803x/rtl8831bu/bcmdhd.ko
  (둘 다 vermagic 3.18.24-tcc SMP preempt mod_unload ARMv7 p2v8, 모듈 이름 bcmdhd)
```

## 드라이버를 순정 HAL 자리에 맞추기

순정 Wi-Fi HAL이 Wi-Fi를 켤 때마다 `/system/wifi/bcmdhd.ko`를 `bcmdhd`라는 이름으로 올립니다(11-23 진단 기록 `nochip-wifi.txt`). 그래서 동글 드라이버를 그 자리에 둘 수 있게 만듭니다(#48 갈래 A).
- 모듈 이름을 `bcmdhd`로 빌드합니다(드라이버 Makefile의 `USER_MODULE_NAME`). HAL은 `/proc/modules`에서 이 이름으로 올라왔는지 보고, 내릴 때도 이 이름을 씁니다.
- 순정 HAL이 주는 인자를 받습니다(`rtl88x2bu/0002-nx4-hal.diff`, `rtl8831bu/0002-nx4-hal.diff`. 내용은 같고 넣는 파일만 다름: `os_intfs.c`, `rtw_cfg.c`. RTL88x2BU에는 아래 국가 코드의 `hal_com.c` 한 곳이 더 있음).
  - `iface_name`: 첫 인터페이스 이름입니다. 드라이버의 `ifname`과 같은 값으로 씁니다. 두 드라이버 모두 동시 모드를 켜지 않아(RTL88x2BU는 기본 플랫폼 설정, RTL8831BU는 Makefile `CONFIG_CONCURRENT_MODE = n`) 인터페이스는 `wlan0` 하나입니다.
  - `firmware_path`, `nvram_path`: 순정 `bcmdhd`의 매개변수입니다. 받아 두기만 합니다. AOSP는 AP를 켜기 전에 `/sys/module/bcmdhd/parameters/firmware_path`에 쓰고, 실패하면 AP를 켜지 않습니다[추정: 이 차 HAL·netd의 문자열은 USB 진단 기록 `dongle/wifi-strings.txt`로 확인].
  - HAL이 이 밖의 인자를 더 주어도 커널 3.18은 "unknown parameter … ignored"를 남기고 그대로 올립니다(`kernel/module.c` `unknown_module_param_cb`).
- 기본 국가 코드를 KR로 둡니다(같은 패치. 원본은 국가 코드 없음).
  - 순정 HAL은 `rtw_country_code`를 주지 않습니다(`dongle/wifi-strings.txt`의 insmod 인자).
  - 국가 코드 없이 올리면 5GHz 채널이 모두 `no IR`(전파를 먼저 낼 수 없음)이라, `hostapd` 설정에 국가 코드를 넣어도 5GHz 149번 AP가 서지 않았습니다. KR이면 섭니다([QEMU 동글 테스트](../docs/qemu-dongle-test.md), 2026-11-27).
  - 차 커널에는 내장 규제 DB가 없어(`CFG80211_INTERNAL_REGDB` 꺼짐) 채널을 풀 다른 길이 없다고 봅니다[추정: 안드로이드 4.4에는 보통 CRDA도 없음. 차에서 확인].
  - insmod 인자 `rtw_country_code=XX`를 주면 그 값을 씁니다.
  - RTL88x2BU는 동글 efuse의 채널 계획에 HW 고정 비트(0x80)가 있으면 국가 코드를 보지 않습니다(`hal/hal_com.c` `hal_com_config_channel_plan`). 그래서 같은 패치가 그 파일에서 `CONFIG_FORCE_SW_CHANNEL_PLAN`을 켜, 우리 국가 코드가 늘 이기게 합니다(이 설정을 보는 곳은 그 파일뿐, PR #97 리뷰 1). RTL8831BU에는 이 길이 없습니다.
  - 위 QEMU 결과는 RTL8831BU 동글로 본 것입니다. RTL88x2BU는 코드로만 봤습니다(RTL88x2BU 동글이 없음).
- HAL 문자열에는 `/sys/module/bcmdhd/parameters/mac_address_read`도 있습니다(`dongle/wifi-strings.txt`). 우리 드라이버에는 이 매개변수가 없습니다. HAL이 이것을 어떻게 쓰는지(못 읽으면 실패로 보는지)는 문자열만으로 알 수 없어 차에서 확인합니다(아래 "차에서 확인할 것"). 뜻을 모르는 값을 만들어 두지 않습니다.

## 보호 패치

### RTL88x2BU(`rtl88x2bu/0001-nx4-protect.diff`)

동글을 쓰다 뽑거나 동글이 망가졌을 때 내비 커널이 멈추지 않게 하는 패치입니다. 이 저장소가 드라이버 원본(`fc158d1f`)을 읽고 새로 썼습니다. **차에서 아직 확인하지 않았습니다**(#48 차 확인: 꽂은 채 뽑기, Wi-Fi 끄고 켜기, 수신이 멈춘 뒤 Wi-Fi 끄고 켜기, 오래 쓰기). 기록은 dmesg의 `nx4-protect:` 줄입니다(드라이버의 `RTW_PRINT`는 디버그 빌드에서만 찍혀 `printk`를 씁니다).

| 곳 | 원본의 문제 | 패치 |
|---|---|---|
| 뽑힘 `rtw_dev_remove` | 장치가 떨어졌다는 표시(surprise removed)를 네트워크 장치를 내린 **뒤에** 합니다. 그 사이 닫기가 없는 장치의 레지스터를 읽고 쓰며 기다릴 수 있습니다 | USB 장치가 이미 떨어졌으면(`USB_STATE_NOTATTACHED`) 네트워크 장치를 내리기 **전에** 표시합니다. `rmmod`처럼 장치가 붙어 있으면 그대로 둡니다 |
| 정리 `rtw_usb_primary_adapter_deinit` | 수신·송신 tasklet을 끝내지 않고 어댑터 메모리를 풉니다 | USB 요청을 거둔 뒤(`rtw_dev_unload`) 두 tasklet을 `tasklet_kill`로 끝내고 풉니다 |
| 열기 `netdev_open` | 아직 올리지 않은 어댑터(`bup`이 거짓)면 열기가 surprise removed 표시를 지우고 하드웨어를 초기화합니다. 내리는 중이거나 없는 장치에도 그렇게 합니다 | 내리는 중이거나 USB 장치가 떨어졌으면 `-ENODEV`로 열지 않습니다 |
| 수신 완료 `usb_read_port_complete`(두 수신 방식) | 오류로 끝나면 수신 요청을 곧바로 다시 겁니다. 연속 오류 세기는 한 번 성공하면 0이 되어, 오류와 성공이 섞이면 멈추지 않고 돕니다 | 성공과 상관없이 1초 안에 100번을 넘으면 surprise removed·drv stopped로 두고 다시 걸지 않습니다. 되살리려면 모듈을 다시 올립니다(Wi-Fi 끄고 켜기: 순정 HAL이 `bcmdhd`를 내렸다 올림, 재부팅, 동글 다시 꽂기). 인터페이스를 내렸다 올려서는 되살아나지 않습니다(`netdev_close`가 `rtw_dev_unload`를 부르지 않아 `bup`이 참으로 남고, 열기는 `bup`이 거짓일 때만 표시를 지움) |

`0002-nx4-hal.diff`보다 먼저 넣습니다(파일 이름 차례).

### RTL8831BU(`rtl8831bu/0001-nx4-protect.diff`)

같은 목적으로 이 드라이버(`fed914c8`, G6/phl 구조)를 읽고 새로 썼습니다. **차에서 확인하지 않았습니다.** 세 곳입니다.

| 곳 | 원본의 문제 | 패치 |
|---|---|---|
| 뽑힘 `rtw_dev_remove` | RTL88x2BU와 같음(표시를 네트워크 장치를 내린 뒤에 함) | USB 장치가 이미 떨어졌으면 내리기 전에 `dev_set_surprise_removed` |
| 열기 `netdev_open` | 내리는 중이거나 없는 장치도 하드웨어를 초기화하러 들어감 | 내리는 중이거나 USB 장치가 떨어졌으면 `-ENODEV` |
| 수신 완료 `rtw_usb_read_port_complete` | 완료는 phl에 넘깁니다. phl은 성공(·INVALID_PARAM) 뒤에만 수신 요청을 다시 걸고, 오류로 끝난 버퍼는 돌려놓기만 합니다(`phl_pend_rxbuf_usb`). 그래서 보통은 오류마다 걸린 요청(최대 `NR_RECV_URB`개)이 줄어 **수신이 기록 없이 멈춥니다**(오류가 계속 돌지는 않음). 성공 뒤 다시 걸기에 실패하면 10ms 지연 타이머가 요청을 다시 채워, 그때 오류가 몰릴 수 있습니다 | 그 좁은 경우만 막습니다: 1초 안에 100번을 넘으면 surprise removed·drv stopped로 두어 `rtw_usb_read_port`가 `RTW_CANNOT_RX`로 거절하게 합니다. 수신이 멈추면(`nx4-protect:` 줄 없이 멈춘 경우 포함) 되살리기는 모듈을 다시 올리기(Wi-Fi 끄고 켜기·재부팅·다시 꽂기). PR #81 리뷰 3 |

- RTL88x2BU의 네 번째(풀기 전 `tasklet_kill`)는 넣지 않았습니다. 이 드라이버의 tasklet은 phl 처리기이고, phl 정리가 `tasklet_kill`을 합니다(`phl/pltfm_ops_linux.h` `_os_tasklet_deinit`).

## RTL8831BU 빌드 맞춤(`rtl8831bu/0003-nx4-build.diff`)

원본을 그대로 빌드하면 첫 파일에서 GCC 4.7이 멈춥니다. 그것을 고치면 끝까지 빌드되지만(고친 파일의 경고 0), 그대로는 `.ko`가 이 커널에 없는 `strscpy`를 불러 차에서 올라가지 않습니다(아래 "커널 심볼 확인"이 잡음). 둘 다 고칩니다.
- `os_dep/osdep_service_linux.c`: 2바이트 카운터 `rtw_warn_on_cnt`(`u16`)를 4바이트 `ATOMIC_T*`로 바꿔 `ATOMIC_INC`에 넘깁니다. GCC 4.7의 ARM 인라인 어셈블리가 이것을 받지 않습니다("output number 2 not directly addressable"). 옆 2바이트까지 쓰는 것이기도 해서, 세기만 하는 카운터라 보통 더하기로 바꿉니다.
- `include/drv_conf.h`, `os_dep/linux/os_intfs.c`: 원본은 새 커널(`strlcpy`가 없어진 6.8 뒤)용으로 `#define strlcpy(a, b, c) strscpy(a, b, c)`를 두고, `rtw_ethtool_get_drvinfo`에서 `strscpy`를 바로 부릅니다. 3.18에는 `strscpy`가 없고(4.3에 생김) `strlcpy`는 매크로가 아닌 함수라 이 정의가 늘 켜집니다. 그래서 `.ko`가 `strscpy`를 불러 insmod가 `Unknown symbol strscpy`로 실패합니다. 정의를 빼고 다섯 곳을 `strlcpy`로 바꿉니다(PR #81 리뷰 1).
- `Makefile`: 디버그 로그를 끕니다(`CONFIG_RTW_DEBUG = n`, 원본은 켜져 있고 수준 4). 순정 시스템의 dmesg·CPU 부하를 줄입니다. RTL88x2BU도 끈 채로 빌드됩니다.
- 그 밖의 원본 설정은 그대로입니다: `-O1`(드라이버 Makefile이 붙임), 소프트 플로트(`-msoft-float -mfpu=vfp`, 커널과 같음), 공장 시험 기능(`CONFIG_MP_INCLUDED = y`), 동시 모드 끔.

## 두 드라이버와 자리 하나

두 드라이버 모두 모듈 이름 `bcmdhd`로 빌드해 순정 HAL 자리(`/system/wifi/bcmdhd.ko`)에 맞춥니다. 그런데 그 자리는 하나입니다. 그래서 이렇게 합니다([#80](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/80) 결정, 2026-11-27. 모드에 넣는 것은 #48 4단계).
- 두 드라이버를 모드 폴더에 함께 싣습니다. 시스템 파일은 바꾸지 않습니다(`patches.json`·순정 md5 확인 없음).
- 부팅 서비스(`start: boot`)와 관리 앱 [동글 켜기]([#60](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/60))가 꽂힌 동글의 USB ID를 sysfs에서 읽어, 맞는 `.ko`를 `/system/wifi/bcmdhd.ko` 위에 bind mount합니다.
- 시동마다 다시 겁니다(시동을 끄고 켜면 새로 부팅함). 부팅 서비스는 HMG-API 데몬(부팅 약 2.6초)이 띄우므로 순정 HAL이 `bcmdhd`를 올리는 때(약 9.8초) 전에 걸 수 있습니다.
- 순정이 포트 전원을 껐다 켠 뒤(꽂은 채 부팅 약 40초, 부팅 뒤 꽂으면 약 8초 뒤) `wlan0`·AP를 보고, 없으면 AP를 다시 켜게 합니다. 상주 루프는 두지 않습니다.

## 커널 준비(빌드 방법)

### 왜 차와 같은 커널 트리가 필요한가

`.ko`는 그것을 빌드한 커널 트리의 구조체 배치와 설정을 그대로 씁니다. 내비 커널은 kernel.org 3.18.24를 Telechips·현대모비스가 고친 것이라, kernel.org 트리로만 빌드하면 순정 커널에만 있는 구조체 필드와 tcc803x 기계 코드(`arch/arm/mach-tcc803x`, `plat-tcc`)가 빠져 배치가 어긋나거나 빌드가 되지 않습니다(kernel.org만으로는 `mach/io.h`가 없어 `modules_prepare`에서 멈춤).

### 내비 커널 소스: 현대모비스 GPL 공개 소스

- 현대모비스가 GPL에 따라 공개한 오픈소스 묶음 중 **AVNT STD G50 WIDE(R9)** 를 씁니다(https://www.mobis.com/kr/tech/rnd.do#open, 플랫폼 "AVNT STD G50 WIDE"). 묶음 sha256 `e7533517…`(628,620,694바이트), 커널은 그 안의 `AVNT5W_TCC803XKK_kernel/`(파일 30,048개)입니다.
- 이 폴더가 tcc803x 내비 커널입니다: `arch/arm/mach-tcc803x`, `arch/arm/plat-tcc`, defconfig(`tcc803x_wide_pe_common_defconfig` 등), 모비스 빌드 스크립트 `mobis_widenew_kernel_build.sh`(그 defconfig와 `toolchain/arm-eabi-4.7`로 빌드), 툴체인 묶음 `toolchain/arm-eabi-4.7.tar.gz`.
- 같은 페이지의 고지 묶음(`OSB_202606110414354220.zip`, sha256 `6afbc835…`, 안에 `Open Source S_W License Notice_AVNT5W_R9.html`)은 Linux Kernel을 GPL-2.0으로, 저작권자를 Hyundai Mobis·Telechips 등으로 적습니다.
- 이 폴더에는 빌드 뼈대가 빠져 있습니다: 맨 위 `Makefile`·`Kconfig`·`Kbuild`, `scripts/`, `Documentation/`, `tools/`, `samples/` 등. 모비스는 이 폴더를 자기 빌드 환경 안의 `kernel/`로 두고 빌드합니다. 그래서 빠진 뼈대를 같은 판의 kernel.org 3.18.24로 채웁니다.

### 단계(`kernel/prepare.sh`)

1. kernel.org `linux-3.18.24`를 풉니다(빌드 뼈대).
2. 그 위에 모비스 커널 폴더를 **고치지 않고 그대로** 덮습니다. 같은 경로의 파일은 모비스 것이 됩니다(tcc803x 기계 코드, 순정 커널의 구조체·Kconfig·Makefile). `toolchain/`은 덮지 않습니다(툴체인으로 따로 풂). kernel.org에서 링크인 곳이 모비스 쪽에서는 폴더라(`arch/arm/boot/dts/include/dt-bindings`) `cp`가 아닌 `tar`로 덮습니다.
3. 커널 설정: 모비스 defconfig `tcc803x_wide_pe_common_defconfig`(모비스 빌드 스크립트가 쓰는 것)를 차 설정과 같게 맞춥니다.
   - 모비스 defconfig는 차의 `/proc/config.gz`와 **USB 네트워크 드라이버 3개만** 다릅니다(`USB_NET_CDC_NCM`, `USB_NET_CDC_SUBSET`과 그 아래 `USB_ARMLINUX`·`USB_BELKIN`, `USB_NET_NET1080`이 모비스 쪽에만 켜져 있음). 차대로 끕니다.
   - 차 커널은 `-fstack-protector-strong`(GCC 4.9부터)으로 빌드됐지만 차의 모듈과 모비스 툴체인은 GCC 4.7이라, `REGULAR`로 바꿉니다(같은 `__stack_chk_*` 기호를 씀).
   - `olddefconfig` 뒤 설정 값(`lib.sh` `kconfig_sum`: 값이 있는 `CONFIG_` 줄을 정렬한 것의 sha256, `STRONG`은 `REGULAR`로 봄)이 `inputs.sh`의 `KCONFIG_SUM`(`b2d52267…`)과 같아야 합니다. 이 값은 tcc803x 내비 차의 `/proc/config.gz`를 같은 식으로 센 값입니다(값이 있는 줄 1,122개가 모두 같음).
4. `modules_prepare`를 하고 `kernel.release`가 `3.18.24-tcc`인지 봅니다(설정의 `LOCALVERSION="-tcc"`).

준비한 커널 트리는 Docker 볼륨에 두고, 바깥 자료와 `kernel/`의 파일이 같으면 다시 씁니다(`kernel/`의 파일을 바꾸면 다시 준비함).

### 툴체인

모비스 커널 폴더에 든 `toolchain/arm-eabi-4.7.tar.gz`(sha256 `76960066…`)를 풀어 씁니다. 순정 모듈이 "GNU C 4.7"로 빌드되어 있습니다. 안의 파일 107개는 AOSP `prebuilts/gcc/linux-x86/arm/arm-eabi-4.7`과 모두 같습니다(`bin/arm-eabi-gcc` sha256 `89a07707…`).

### 우리 차와 같은지

- 위 3의 차 설정 값은 같은 내비 플랫폼(tcc803x) 차에서 꺼낸 `/proc/config.gz`입니다. 우리 차(NX4HEV 260902)의 것은 USB 진단 기록 `dongle/config.txt`로 받아 PC에서 견줍니다.

  ```sh
  sh drivers/config-sum.sh <진단 기록>/dongle/config.txt
  ```

  "같음"(0)이면 그대로 씁니다. "다름"(3)이면 다른 줄을 보고 `prepare.sh`의 조정과 `KCONFIG_SUM`을 우리 차 것에 맞춥니다(#48). `sha256sum`이 없는 PC는 `shasum -a 256`으로 세고, 둘 다 없거나 설정 파일이 아니면 견주지 않고 멈춥니다(1).
- 빌드한 `.ko`의 vermagic이 순정 모듈의 것(`dongle/ko-vermagic.txt`)과 같은지도 봅니다.

## 커널 소스 자산

모비스 원본 묶음은 628MB이고 커널 말고 다른 것도 들어 있어, 빌드할 때마다 받지 않도록 **커널 폴더만 고치지 않고 묶어** 이 저장소의 릴리스 자산으로 올려 두었습니다. 빌드는 이것을 받습니다.

| 항목 | 값 |
|---|---|
| 릴리스 | [`src-mobis-avnt5w-r9`](https://github.com/jay-park-lab/hmgapi-nx4-kor/releases/tag/src-mobis-avnt5w-r9)(모드 배포가 아님. 시험판·최신 아님으로 둠) |
| 파일 | `mobis-avnt5w-r9-kernel.tar.xz`(102,365,660바이트, sha256 `f72306a8…`) |
| 안의 것 | `AVNT5W_TCC803XKK_kernel/` 그대로(파일 30,048개, 툴체인 묶음 포함) |
| 원본과 같은지 | 푼 폴더의 값(`lib.sh` `tree_sum`: 모든 파일의 sha256과 경로)이 원본 묶음에서 푼 것과 같은 `14aa37f7…`. 빌드는 받을 때마다 이 값을 봅니다 |
| 함께 올린 것 | 모비스 고지 원본 `OSB_202606110414354220.zip`(그대로), 출처를 적은 릴리스 설명 |
| 라이선스 | GPL-2.0(Linux Kernel). 원본 저작권은 Hyundai Mobis·Telechips 등에게 있습니다 |

자산은 원본에서 다시 만들 수 있습니다(누구나 원본과 같은지 확인할 수 있게).

```sh
sh scripts/build-driver.sh --src-asset
```

- 모비스 원본 묶음을 받아 sha256(`e7533517…`)을 확인하고, `AVNT5W_TCC803XKK_kernel/`만 꺼내 폴더 값을 확인한 뒤, 이름 차례·시각·소유자를 고정해 묶습니다(`tar --sort=name`, `xz -9` 한 스레드). 결과는 `out/drivers/src/`입니다.
- 자산을 바꿀 일이 생기면(모비스가 새 판을 냄 등) 새 태그로 올리고 `inputs.sh`의 `MOBIS_*` 값과 이 표를 고칩니다. 올린 자산은 바꾸지 않습니다.

  ```sh
  gh release create src-mobis-avnt5w-r9 out/drivers/src/mobis-avnt5w-r9-kernel.tar.xz <고지 zip> --target <커밋> --prerelease --latest=false --title "<제목>" --notes-file <설명>
  ```

- `v*`가 아닌 태그라 release 워크플로(모드 배포)는 돌지 않습니다. 다만 모드 릴리스의 `--generate-notes`가 바로 앞 릴리스부터 변경을 세므로, 이 자산 뒤 첫 모드 릴리스의 노트 범위를 확인합니다([`docs/release.md`](../docs/release.md)).

## 빌드

Docker가 필요합니다(linux/amd64. Apple Silicon 맥은 아래 "맥에서 빌드"). 저장소 맨 위에서:

```sh
sh scripts/build-driver.sh
```

- 결과: `out/drivers/tcc803x/rtl88x2bu/bcmdhd.ko`, `out/drivers/tcc803x/rtl8831bu/bcmdhd.ko`와 각각의 `bcmdhd.ko.txt`(드라이버 커밋, 패치 sha256, 커널·커널 소스 자산·설정·툴체인 값, 빌드 날짜, 컴파일 옵션 지문, 매개변수, USB 별칭, md5·sha256, vermagic)
- 받은 자료와 준비한 커널은 Docker 볼륨 `nx4kor-drivers`에 두고 다음 빌드에 다시 씁니다. 처음에는 받기·커널 준비로 오래 걸립니다(qemu 에뮬레이션이면 수십 분). 지우려면 `docker volume rm nx4kor-drivers`.
- 드라이버는 컴파일 날짜·시각(`__DATE__`, `__TIME__`)을 문자열로 넣습니다. `drivers/`나 `scripts/build-driver.sh`를 마지막으로 바꾼 커밋의 시각(UTC, 달 이름은 로캘과 상관없이 영어)으로 고정합니다. 그래서 같은 커밋이면 같은 `.ko`가 다시 만들어지고, 드라이버와 상관없는 커밋만 쌓여서는 `.ko`가 바뀌지 않습니다. 기록이 다 있어야 하므로 얕은 클론에서는 멈춥니다. 커널 트리 경로(`/work/k/linux-3.18.24`)와 툴체인 경로(`/work/tc`)도 `.ko`에 들어가 고정입니다.
- 컨테이너는 `drivers/`의 사본으로 돕니다. 빌드 중에 파일을 고쳐도 그 빌드는 바뀌지 않습니다.
- Apple Silicon 맥의 qemu 에뮬레이션에서는 컴파일러·어셈블러·커널의 호스트 도구가 가끔 `Segmentation fault`(`internal compiler error`)로 멈춥니다. 커널 준비와 드라이버 컴파일 모두, 그때만 `make`를 이어서 다시 돌립니다(모두 30번까지, `NX4_DRV_TRIES`로 바꿈, `lib.sh` `make_retry`. RTL8831BU는 오브젝트가 379개(RTL88x2BU 157개)라 충돌이 더 잦아, 8번으로는 한 빌드 안에서 다 써 버린 적이 있음). 다시 돌리기 전에 make가 실패로 적은 대상을 지웁니다(커널 3.18의 kbuild에는 `.DELETE_ON_ERROR`가 없어 반쯤 쓴 파일이 남을 수 있음). 다 된 것은 다시 만들지 않아 결과는 같습니다. 충돌이 없으면 한 번에 끝나므로(CI) 횟수를 늘려도 잃는 것이 없습니다. 이 맥에서는 세 번 연속 충돌도 여러 번 있었습니다. 끝까지 멈추면 빌드는 실패로 끝나고, 스크립트를 다시 돌리면 커널 준비를 마친 트리는 다시 쓰고 드라이버는 처음부터 다시 컴파일합니다. 동시 작업 수(`NX4_DRV_JOBS`)를 줄여도 충돌은 날 수 있습니다.
- 받기는 잠깐의 오류(503 등)면 15초씩 쉬며 8번까지 다시 묻습니다.
- `.env.local`의 `NX4_DRV_DOCKER_CONTEXT`가 있으면 이 빌드의 docker 명령에만 그 context를 씁니다(`DOCKER_CONTEXT`, 명령 앞에 준 값이 앞섬). 워크트리에서는 다른 PC 스크립트처럼 `NX4_ENV_FILE=<메인 체크아웃>/.env.local`로 가리킵니다.
- 저장소가 Docker VM에 공유된 곳에 있어야 합니다. colima는 기본으로 홈 폴더와 `/tmp/colima`(프로필이 `default`가 아니면 `/tmp/colima-<프로필>`, 예: `/tmp/colima-nx4`)만 VM에 붙입니다(`/var/folders` 같은 `mktemp -d` 자리는 안 됨). 붙지 않은 곳이면 스크립트가 먼저 알리고 멈춥니다.
- Docker가 이 셸의 프록시 설정을 이어받아 받기가 막히면, 프록시 변수를 뺀 셸에서 Docker(colima 등)를 다시 시작합니다.
- GitHub Actions(`.github/workflows/drivers.yml`)도 `drivers/`나 이 스크립트가 바뀐 `feature/` 푸시·PR마다 같은 방법으로 빌드합니다. md5는 실행 요약에, `.ko`는 artifact `drivers-tcc803x`에 있습니다. 같은 커밋이면 PC와 md5가 같아야 합니다(다르면 PC의 에뮬레이션 쪽을 의심합니다).

### 맥에서 빌드(Apple Silicon)

툴체인(GCC 4.7)과 커널의 호스트 도구가 x86_64용이라 맥에서는 linux/amd64 컨테이너를 에뮬레이션으로 돌립니다. colima의 기본 VM(이 맥은 Virtualization.Framework)은 Rosetta가 꺼져 있어 x86_64 컨테이너를 qemu 사용자 모드(`binfmt_misc`의 `qemu-x86_64`)로 돌려 느리고, 컴파일러가 자주 멈추거나(한 빌드에 20번) `cc-option` 물음이 실패해 `armv5t`로 넘어갔습니다. **Rosetta를 켠 colima 프로필을 이 빌드에만** 씁니다.

```sh
colima start -p nx4 --cpu 10 --memory 16 --vz-rosetta
docker context use colima
```

- 첫 줄은 Rosetta(Apple Virtualization.Framework)로 x86_64를 돌리는 VM을 따로 만듭니다. 다른 프로젝트가 쓰는 기본 VM(`default`, 프로필 `colima`)은 그대로입니다. 적용됐는지는 `colima ssh -p nx4 -- ls /proc/sys/fs/binfmt_misc`에 `rosetta`가 있는지로 봅니다.
- `colima start -p nx4`는 시작할 때마다 전역 기본 context를 `colima-nx4`로 바꿉니다. 둘째 줄로 기본을 되돌립니다.
- `.env.local`에 `NX4_DRV_DOCKER_CONTEXT=colima-nx4`를 적으면 `sh scripts/build-driver.sh`가 이 VM으로 빌드합니다(`.env.example`). 셸에 `DOCKER_HOST`가 있으면 docker가 그것을 먼저 써 이 값이 무시되므로, 스크립트가 알리고 멈춥니다(PR #81 리뷰 7).
- 이 VM은 Docker 볼륨을 따로 가져 첫 빌드는 처음부터 합니다. 2026-11-26 이 맥(M4 Max)에서 처음부터 끝까지(자산 받기·커널 준비·드라이버 둘) 344초였고, 컴파일러 충돌은 한 번도 없었으며, 두 `.ko`의 md5가 같은 커밋의 CI와 같았습니다(커밋 `1edffba`).
- 안 쓸 때는 `colima stop -p nx4`로 멈춥니다.
- Rosetta도 에뮬레이션입니다. 차에 넣을 `.ko`는 아래처럼 CI 것만 씁니다.

### 차에 넣을 `.ko`는 CI에서 만든 것만

- **차에 넣는 `.ko`는 리눅스 x86에서 만든 것만 씁니다**(CI `drivers` 워크플로의 artifact, 4단계부터는 release 워크플로. 2026-11-26 결정).
- 까닭: Apple Silicon 맥의 qemu 에뮬레이션에서 컴파일러가 **멈추지 않고도 다른 코드를 낸 적이 있습니다**. PR #69의 커밋 `572128e`를 PC에서 빌드했을 때 첫 빌드는 md5 `5035d662…`(`.text`가 다르고 여러 함수의 레지스터 배정·분기 배치가 다름)였습니다. 같은 커널 트리로 다시 빌드하니 CI와 같은 `aabf4de7…`가 나왔습니다. 충돌(Segmentation fault)은 알 수 있어 다시 돌리지만, 이런 조용한 차이는 결과를 보기 전에는 알 수 없었습니다.
- 알려진 원인 하나(PR #69 리뷰 14·18): 커널은 make마다 컴파일러에 물어(`cc-option`) 옵션을 정합니다. `arch/arm/Makefile`은 `-march=armv7-a`가 안 되면 조용히 `-march=armv5t`로 넘어가고, `-fno-strict-overflow`·`-fconserve-stack` 같은 옵션도 같은 식으로 붙습니다. 에뮬레이션에서 그 물음 중에 컴파일러가 멈추면 다른 옵션으로 컴파일됩니다. 리뷰 중에 실제로 `armv5t`로 컴파일되어 `rev16` 어셈블러 오류가 난 적이 있습니다. `572128e`의 조용한 차이는 충돌도 오류도 없어, 어느 옵션 때문이었는지(또는 이 까닭이었는지)는 확인하지 못했습니다.
- 그래서 빌드는 끝에 모든 오브젝트의 컴파일 옵션 묶음(`-m`·`-f`·`-W`·`-O`·`-g`·`-std`·`-D__LINUX_ARM_ARCH__`)을 봅니다(`lib.sh` `check_cflags`). 서로 같고, `-march=armv7-a`이며, 그 sha256이 `inputs.sh`의 고정 값과 같아야 합니다(드라이버 Makefile이 붙이는 옵션이 달라 따로 둠: RTL88x2BU `EXPECTED_CFLAGS_SHA256` CI 값 `d81069ca…`, RTL8831BU `EXPECTED_CFLAGS_SHA256_8831BU` CI 값 `9772552f…`). 아니면 실패로 끝납니다. 그 sha256은 `bcmdhd.ko.txt`의 `cflags` 줄에도 남습니다. 커널 소스·설정·툴체인·드라이버 Makefile·`EXTRA_CFLAGS`를 바꾸면 CI의 "컴파일 옵션 확인" 줄 값으로 `inputs.sh`를 함께 고칩니다.
- **커널 심볼 확인**(PR #81 리뷰 2): 커널 준비가 `modules_prepare`까지라 `Module.symvers`가 없어, modpost는 커널에 없는 심볼을 불러도 알리지 않습니다. 그런 `.ko`는 빌드·CI는 통과하고 차에서 `Unknown symbol`로 올라가지 않습니다. 그래서 빌드 끝에 `.ko`가 부르는 이름(`arm-eabi-nm -u`)이 모두 커널이 내보내는 것인지 봅니다(`lib.sh` `check_ksyms`). 내보내는 이름은 커널 트리 소스의 `EXPORT_SYMBOL(_GPL)(이름)`, `EXPORT_PER_CPU_SYMBOL(_GPL)(이름)`(이 커널은 SMP라 내보냄, 리뷰 5), `kernel/params.c`의 `STANDARD_PARAM_DEF`가 만드는 `param_ops_*`입니다(`kernel_exports`, 빌드마다 새로 만듦, 몇 초).
  - 설정으로 빌드하지 않는 파일의 것도 목록에 들어가, 확인을 통과해도 차 커널에 다 있다는 뜻은 아닙니다. 그래서 차에서 dmesg에 `Unknown symbol`이 없는지도 봅니다.
  - 거꾸로 위 꼴이 아닌 다른 매크로로 내보내는 이름은 목록에 빠져 거짓으로 걸릴 수 있습니다. 걸리면 그 이름을 커널 소스에서 찾아보고, 정말 내보내는 것이면 `kernel_exports`에 그 꼴을 더합니다.
- 그래도 PC 빌드는 개발·확인용입니다. `scripts/build-driver.sh`는 Docker VM의 CPU가 x86_64가 아니거나 맥이 Apple Silicon이면(Rosetta 터미널 포함) 끝에 알리고, `bcmdhd.ko.txt`에 `build host <Docker VM CPU>, <OS CPU> (emulated: …)`를 적습니다. PC 결과를 쓰려면 같은 커밋의 CI md5와 같은지 먼저 봅니다.

## 바깥 자료(`inputs.sh`)

받은 뒤 아래 값으로 같은 파일인지 확인합니다. 저장소에는 넣지 않습니다.

| 자료 | 위치 | 확인 |
|---|---|---|
| 커널 뼈대 | kernel.org `linux-3.18.24.tar.xz` | sha256 `ed54cf8c…7f8c1b` |
| 내비 커널 소스 | 이 저장소 릴리스 `src-mobis-avnt5w-r9`의 `mobis-avnt5w-r9-kernel.tar.xz`(원본: 현대모비스 AVNT STD G50 WIDE R9 묶음, sha256 `e7533517…`) | 파일 sha256 `f72306a8…`, 푼 폴더 값 `14aa37f7…` |
| 커널 설정 | 내비 커널 소스의 `tcc803x_wide_pe_common_defconfig`를 조정 | 설정 값 `b2d52267…`(차 설정과 같음) |
| 툴체인 | 내비 커널 소스의 `toolchain/arm-eabi-4.7.tar.gz` | sha256 `76960066…` |
| 드라이버 RTL88x2BU | [cilynx/rtl88x2bu](https://github.com/cilynx/rtl88x2bu) | 커밋 `fc158d1f71b9e5dfcd1fccaf4d28725b65086e3b` |
| 드라이버 RTL8831BU | [hyeondg/rtl8831bu](https://github.com/hyeondg/rtl8831bu) | 커밋 `fed914c8931f3a768afe087dea9998965816f37e` |

## 출처와 라이선스

| 파일 | 출처 | 라이선스 |
|---|---|---|
| `rtl88x2bu/0001-nx4-protect.diff`, `rtl88x2bu/0002-nx4-hal.diff` | 이 저장소(드라이버 원본에 대는 패치) | GPL-2.0 |
| `rtl8831bu/0001-nx4-protect.diff`, `rtl8831bu/0002-nx4-hal.diff`, `rtl8831bu/0003-nx4-build.diff` | 이 저장소(드라이버 원본에 대는 패치) | GPL-2.0 |
| `kernel/prepare.sh`, `build-in-container.sh`, `lib.sh`, `config-sum.sh`, `Dockerfile`, `inputs.sh`, `README.md` | 이 저장소 | GPL-2.0 |
| `COPYING` | GPL-2.0 전문(드라이버 원본 저장소의 `LICENSE`와 같음) | — |

`drivers/` 밖의 `scripts/build-driver.sh`(Docker를 부르는 PC 스크립트)와 `.github/workflows/drivers.yml`은 저장소의 다른 부분처럼 AGPL-3.0입니다.

- 드라이버 원본: cilynx/rtl88x2bu(Realtek 드라이버, GPL-2.0)
- 드라이버 원본: hyeondg/rtl8831bu(Realtek 드라이버 v1.19.10). 저장소에 LICENSE 파일은 없고, 소스 머리말이 Realtek의 GPL-2.0("version 2 of the GNU General Public License")입니다. LICENSE 없는 개인 저장소라 사라질 수 있으므로, 4단계에서 `.ko`를 내보낼 때 이 커밋의 소스 사본을 모비스 커널 소스처럼 이 저장소의 릴리스 자산으로 둡니다(GPL-2.0 대응 소스, PR #81 리뷰 4, #48)
- 내비 커널 소스: 현대모비스 AVNT STD G50 WIDE(R9) 오픈소스(Linux Kernel, GPL-2.0). 위 "커널 소스 자산"
- 커널 뼈대: kernel.org Linux 3.18.24(GPL-2.0)
- 모드에 `.ko`를 넣어 내보낼 때는 이 폴더, 드라이버 원본 커밋, 커널 소스 자산·kernel.org 위치를 함께 냅니다(GPL-2.0 대응 소스, #48 4단계).

## 차에서 확인할 것

[#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48) 체크리스트에 있습니다. 이 빌드에 걸린 것:
- 우리 차 커널 설정이 빌드의 설정과 같은지(`sh drivers/config-sum.sh dongle/config.txt`)
- 빌드한 `.ko`의 vermagic이 순정 모듈의 것과 같은지(`dongle/ko-vermagic.txt`)
- HAL이 올릴 때 dmesg에 `Unknown symbol`이 없는지(두 드라이버, 빌드의 커널 심볼 확인이 못 잡는 설정 차이)
- 순정 HAL이 주는 insmod 인자와 `bcmdhd` 매개변수 이름(`dongle/wifi-strings.txt`)
- HAL이 우리 `.ko`를 받는지: `mac_address_read`가 없어도 HAL이 Wi-Fi를 켜는지(`wifi_check_module_info`, WifiHW logcat)
- 국가 코드: 기본 KR로 올린 드라이버의 5GHz 채널(`iw phy`의 `no IR`), netd가 만드는 `hostapd.conf`의 `country_code` 줄(비밀번호가 든 파일이라 그 줄만), 순정 `bcmdhd.cal`의 `ccode` 줄
  - 드라이버가 쓰는 국가 코드와 채널 계획: `/proc/net/<드라이버 이름>/wlan0/country_code`, `chan_plan`. 폴더 이름은 모듈 이름(`bcmdhd`)이 아니라 드라이버의 `DRV_NAME`입니다(RTL88x2BU `rtl88x2bu`, RTL8831BU `rtl8851bu`, 두 드라이버 모두 `CONFIG_PROC_DEBUG = y`). dmesg의 채널 계획 줄(`RTW_PRINT`)은 디버그 로그를 끈 우리 빌드에서는 찍히지 않습니다(PR #97 리뷰 3).
  - RTL88x2BU 동글은 QEMU로도 보지 못했으므로 차에서 5GHz 149번 AP가 서는지
- HAL이 바꿔 둔 `bcmdhd.ko`를 올렸을 때 `wlan0`이 생기고 HMG-API가 AP를 띄우는지(149번 채널 포함)
- RTL8831BU 동글을 꽂았을 때 USB ID(`0bda:b831`)와 이 드라이버가 붙는지, `wlan0`과 AP(149번 채널 포함). 동글이 실제로 RTL8831BU인지는 `lsusb` ID로 확인합니다(RTL8851BU `0bda:b851`도 이 드라이버가 받음)
- 보호 패치(두 드라이버): 쓰는 중에 동글을 뽑아도 내비가 멈추지 않는지, Wi-Fi를 끄고 켜도 되는지, 수신 오류로 멈춘(`nx4-protect: … rx stopped`) 뒤 Wi-Fi를 끄고 켜면 AP가 돌아오는지, dmesg의 `nx4-protect:` 줄
- RTL8831BU: `nx4-protect:` 줄 없이 수신만 멈추는지(AP는 떠 있는데 폰이 통신하지 못함), 그때 Wi-Fi를 끄고 켜면 돌아오는지(PR #81 리뷰 3)
