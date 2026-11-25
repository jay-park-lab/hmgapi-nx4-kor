# USB Wi-Fi 동글 드라이버

투싼 NX4 한국 내비(tcc803x, 커널 `3.18.24-tcc`)에서 쓸 USB Wi-Fi 동글 드라이버를 만드는 곳입니다([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48) 2단계). 아직 모드에 넣지 않았고, 차에서 확인하지 않았습니다.

- 지금은 **RTL88x2BU**(ipTIME A3000MINI `0bda:b812`, TP-Link Archer T3U `2357:012d` 등) 하나입니다. RTL8831BU(`0bda:b831`)는 3단계입니다.
- 이 폴더(`drivers/`)의 패치·스크립트는 **GPL-2.0**입니다(드라이버가 GPL-2.0이기 때문, 전문은 `COPYING`). 저장소의 다른 부분은 AGPL-3.0이고, 이 폴더를 Docker로 돌리는 `scripts/build-driver.sh`도 AGPL-3.0입니다. 출처는 아래 "출처와 라이선스"에 있습니다.

## 방법

순정 Wi-Fi HAL이 Wi-Fi를 켤 때마다 `/system/wifi/bcmdhd.ko`를 `bcmdhd`라는 이름으로 올립니다(11-23 진단 기록 `nochip-wifi.txt`). 그래서 동글 드라이버를 그 자리에 둘 수 있게 만듭니다(#48 갈래 A).
- 모듈 이름을 `bcmdhd`로 빌드합니다(드라이버 Makefile의 `USER_MODULE_NAME`). HAL은 `/proc/modules`에서 이 이름으로 올라왔는지 보고, 내릴 때도 이 이름을 씁니다.
- 순정 HAL이 주는 인자를 받습니다(`rtl88x2bu/0002-nx4-hal.diff`).
  - `iface_name`: 첫 인터페이스 이름입니다. 드라이버의 `ifname`과 같은 값으로 씁니다. 동시 모드는 켜지 않아(드라이버 기본 플랫폼 설정) 인터페이스는 `wlan0` 하나입니다.
  - `firmware_path`, `nvram_path`: 순정 `bcmdhd`의 매개변수입니다. 받아 두기만 합니다. AOSP는 AP를 켜기 전에 `/sys/module/bcmdhd/parameters/firmware_path`에 쓰고, 실패하면 AP를 켜지 않습니다[추정: 이 차 HAL·netd의 문자열은 USB 진단 기록 `dongle/wifi-strings.txt`로 확인].
  - HAL이 이 밖의 인자를 더 주어도 커널 3.18은 "unknown parameter … ignored"를 남기고 그대로 올립니다(`kernel/module.c` `unknown_module_param_cb`).
- 그 밖은 Korea Projection 1.8.0-beta.2의 tcc803x 빌드와 같습니다(`rtl88x2bu/0001-kp-protect.diff`: 뽑을 때 보호, 수신 오류 반복 막기, 내릴 때 정리).

커널 쪽은 KP 1.8.0-beta.2의 `build-tcc803x.sh`와 같은 방법입니다.
1. kernel.org `linux-3.18.24`에, 차의 TCC803X 기계 항목이 `select`하던 설정(`ARCH_DMA_ADDR_T_64BIT`, `ZONE_DMA`, `PINCTRL`, `PINMUX`, `PINCONF`, `PM_GENERIC_DOMAINS`, `PM_OPP`, `USB_OTG`)을 살립니다.
2. 순정 커널에만 있는 구조체 필드를 같은 자리에 넣어 배치를 맞춥니다(`kernel/hdr-patch.sh`, `kernel/hdr-patch-803x.sh`). 동작 코드는 바꾸지 않습니다.
3. 차 커널 설정(`/proc/config.gz`를 푼 것)으로 `olddefconfig`, `modules_prepare`를 합니다. gcc 4.7에 없는 `-fstack-protector-strong`만 `REGULAR`로 바꿉니다.

1~3은 `kernel/prepare.sh` 한 곳에 있습니다. 준비한 커널 트리는 볼륨에 두고, 바깥 자료와 `kernel/`의 파일이 같으면 다시 씁니다(`kernel/`의 파일을 바꾸면 다시 준비함).
4. AOSP `arm-eabi-4.7`로 드라이버를 컴파일합니다. vermagic은 `3.18.24-tcc SMP preempt mod_unload ARMv7 p2v8`입니다.

## 빌드

Docker가 필요합니다(linux/amd64. Apple Silicon 맥은 colima 등이 qemu로 돌림). 저장소 맨 위에서:

```sh
sh scripts/build-driver.sh
```

- 결과: `out/drivers/tcc803x/rtl88x2bu/bcmdhd.ko`와 `bcmdhd.ko.txt`(드라이버 커밋, 패치 sha256, 커널·차 설정 sha256, 빌드 날짜, 매개변수, USB 별칭, md5·sha256, vermagic)
- 받은 자료와 준비한 커널은 Docker 볼륨 `nx4kor-drivers`에 두고 다음 빌드에 다시 씁니다. 처음에는 받기·커널 준비로 오래 걸립니다(qemu 에뮬레이션이면 수십 분).
- 드라이버는 컴파일 날짜·시각(`__DATE__`, `__TIME__`)을 문자열로 넣습니다. `drivers/`나 `scripts/build-driver.sh`를 마지막으로 바꾼 커밋의 시각(UTC, 달 이름은 로캘과 상관없이 영어)으로 고정합니다. 그래서 같은 커밋이면 같은 `.ko`가 다시 만들어지고, 드라이버와 상관없는 커밋만 쌓여서는 `.ko`가 바뀌지 않습니다. 기록이 다 있어야 하므로 얕은 클론에서는 멈춥니다.
- 컨테이너는 `drivers/`의 사본으로 돕니다. 빌드 중에 파일을 고쳐도 그 빌드는 바뀌지 않습니다.
- Apple Silicon 맥의 qemu 에뮬레이션에서는 컴파일러·어셈블러·커널의 호스트 도구가 가끔 `Segmentation fault`(`internal compiler error`)로 멈춥니다. 커널 준비와 드라이버 컴파일 모두, 그때만 `make`를 이어서 다시 돌립니다(모두 3번까지, `lib.sh` `make_retry`). 다시 돌리기 전에 make가 실패로 적은 대상을 지웁니다(커널 3.18의 kbuild에는 `.DELETE_ON_ERROR`가 없어 반쯤 쓴 파일이 남을 수 있음). 다 된 것은 다시 만들지 않아 결과는 같습니다. 세 번 모두 멈추면 그대로 다시 돌리면 이어집니다. 동시 작업 수(`NX4_DRV_JOBS`)를 줄여도 충돌은 날 수 있습니다.
- 저장소가 Docker VM에 공유된 곳에 있어야 합니다. colima는 기본으로 홈 폴더와 `/tmp/colima`만 VM에 붙입니다(`/var/folders` 같은 `mktemp -d` 자리는 안 됨). 붙지 않은 곳이면 스크립트가 먼저 알리고 멈춥니다.
- Docker가 이 셸의 프록시 설정을 이어받아 받기가 막히면, 프록시 변수를 뺀 셸에서 Docker(colima 등)를 다시 시작합니다.
- GitHub Actions(`.github/workflows/drivers.yml`)도 `drivers/`나 이 스크립트가 바뀐 `feature/` 푸시·PR마다 같은 방법으로 빌드합니다(`--kp-check`, 그다음 우리 드라이버). md5는 실행 요약에, `.ko`는 artifact `drivers-tcc803x`에 있습니다. 같은 커밋이면 PC와 md5가 같아야 합니다.

방법이 KP와 같은지 확인하려면:

```sh
sh scripts/build-driver.sh --kp-check
```

KP 1.8.0-beta.2 패키지의 `drv/tcc803x-a/88x2bu.ko`(md5 `e16ccc0208cb179586f71dfd67631edb`)와 같은 패치·날짜·시각·경로로 빌드하고 md5를 견줍니다. 다르면 실패로 끝납니다.

## 바깥 자료(`inputs.sh`)

받은 뒤 아래 값으로 같은 파일인지 확인합니다. 저장소에는 넣지 않습니다.

| 자료 | 위치 | 확인 |
|---|---|---|
| 커널 | kernel.org `linux-3.18.24.tar.xz` | sha256 `ed54cf8c…7f8c1b` |
| 툴체인 | AOSP `platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.7`, kitkat-release 브랜치의 커밋 `8b880805d454664b3eed11d0f053cdeafa1ff06e` | 푼 폴더 전체 값 `201fc602…c7c6bee`(모든 파일의 sha256과 링크, `lib.sh` `tree_sum`. 묶음 파일은 받을 때마다 만들어져 그 sha256은 고정되지 않음). 그 안의 `bin/arm-eabi-gcc`는 KP가 적은 sha256 `89a07707…`과 같음 |
| 차 커널 설정 | 공개 저장소 `JMK-labs/jmk-gen5w`의 커밋 `dcc71a04`, `driver/config_tcc803x.txt` | sha256 `d35af8a0…f82f9913`(KP 1.8.0이 쓴 설정과 같음) |
| 드라이버 | [cilynx/rtl88x2bu](https://github.com/cilynx/rtl88x2bu) | 커밋 `fc158d1f71b9e5dfcd1fccaf4d28725b65086e3b`(KP 1.8.0 tcc803x와 같음) |

- 차 커널 설정은 tcc803x 내비의 `/proc/config.gz`입니다. KP가 적은 출처(`JongMinKim-93/jmk-gen5w-ioniq5`)는 지금 404여서, 같은 파일(sha256이 같음)이 있는 공개 저장소의 커밋으로 고정했습니다. 그 저장소의 빌드 스크립트와 빌드 방법에는 재사용을 막는 조건이 붙어 있어(그 저장소 `driver/README.md`) 스크립트는 열어 보지 않았고 쓰지 않았습니다. 여기서 쓰는 것은 그 설정 파일 하나를 빌드 때 받는 것뿐입니다.
- 우리 차(NX4HEV 260902)의 `/proc/config.gz`는 USB 진단 기록 `dongle/config.txt`로 받습니다. sha256이 위 값과 다르면 우리 차 것으로 바꿉니다.

## 출처와 라이선스

| 파일 | 출처 | 라이선스 |
|---|---|---|
| `rtl88x2bu/0001-kp-protect.diff` | Korea Projection 1.8.0-beta.2 릴리스 첨부 `rtl88x2bu-source-1.8.0-beta.2.tar.gz`의 `tcc803x/kp-protect.diff` 그대로 | GPL-2.0 |
| `kernel/hdr-patch.sh`, `kernel/hdr-patch-803x.sh` | 같은 묶음의 `scripts/` 그대로 | GPL-2.0 |
| `kernel/prepare.sh` | 같은 묶음의 `build-tcc803x.sh`의 커널 준비 단계를 바탕으로 이 저장소가 고침 | GPL-2.0 |
| `rtl88x2bu/0002-nx4-hal.diff`, `build-in-container.sh`, `lib.sh`, `Dockerfile`, `inputs.sh`, `README.md` | 이 저장소 | GPL-2.0 |
| `COPYING` | GPL-2.0 전문(드라이버 원본 저장소의 `LICENSE`와 같음) | — |

`drivers/` 밖의 `scripts/build-driver.sh`(Docker를 부르는 PC 스크립트)와 `.github/workflows/drivers.yml`은 저장소의 다른 부분처럼 AGPL-3.0입니다.

- 드라이버 원본: cilynx/rtl88x2bu(Realtek 드라이버, GPL-2.0)
- Korea Projection: StopDragon, https://github.com/StopDragon/korea-projection/releases/tag/v1.8.0-beta.2
- 모드에 `.ko`를 넣어 내보낼 때는 이 폴더, 드라이버 원본 커밋, 커널·툴체인 위치를 함께 냅니다(GPL-2.0 대응 소스, #48 4단계).

## 차에서 확인할 것

[#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48) 체크리스트에 있습니다. 이 빌드에 걸린 것:
- 우리 차 `/proc/config.gz`의 sha256이 위 차 커널 설정과 같은지(USB 진단 기록 `dongle/config-sum.txt`)
- 순정 HAL이 주는 insmod 인자와 `bcmdhd` 매개변수 이름(`dongle/wifi-strings.txt`)
- HAL이 바꿔 둔 `bcmdhd.ko`를 올렸을 때 `wlan0`이 생기고 HMG-API가 AP를 띄우는지(149번 채널 포함)
