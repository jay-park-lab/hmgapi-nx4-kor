#!/bin/sh
# QEMU에서 USB Wi-Fi 동글과 우리 드라이버를 테스트한다(#48, docs/qemu-dongle-test.md). PC에서만 돈다. 내비에는 아무것도 하지 않는다.
# 쓰는 법(저장소 맨 위에서): sh scripts/qemu-dongle-test.sh [matrix|interactive] [rtl8831bu|rtl88x2bu]
#   matrix(기본)   사람 손 없이: 차 HAL 인자로 올린 채널 표, rtw_country_code=KR로 올린 채널 표, 스캔, AP 조합
#   interactive    KR로 올려 5GHz 149번 AP(SSID NX4-QEMU-TEST, 비밀번호 nx4-qemu-test)를 띄워 폰으로 붙어 보고,
#                  그다음 쓰는 중에 동글을 뽑아 보호 패치를 본다
# 무엇을 보고 무엇을 못 보는지는 docs/qemu-dongle-test.md. 차의 .ko 자체가 아니라, 같은 판(3.18.24) 커널을 QEMU virt용으로 빌드해
# 같은 드라이버 소스와 우리 패치를 다시 빌드한 것을 올린다.
# 필요한 것: qemu-system-arm(맥: brew install qemu), docker(드라이버 빌드 이미지와 볼륨. 먼저 sh scripts/build-driver.sh를 한 번),
# PC에 꽂은 동글. 동글은 QEMU가 도는 동안 VM으로 넘어가 PC에서는 쓰지 못한다.
# 환경 변수: NX4_QEMU_USB(VID:PID, 기본 rtl8831bu 0bda:b831, rtl88x2bu 0bda:b812), NX4_QEMU_AP_SECS(AP 하나를 띄워 둘 초,
#            기본 matrix 30·interactive 180), NX4_QEMU_UNPLUG_SECS(뽑기를 기다릴 초, 기본 90), NX4_QEMU_NOBUILD=1(지난 빌드를 다시 씀),
#            NX4_QEMU_OUT(결과 폴더), NX4_DRV_DOCKER_CONTEXT·NX4_DRV_VOLUME·NX4_DRV_IMAGE·NX4_DRV_JOBS(scripts/build-driver.sh와 같음)
# 결과는 out/qemu-test/<드라이버>/에 남는다(zImage, bcmdhd.ko, rootfs.img, console-<모드>-<시각>.log).
set -eu
B=$(cd "$(dirname "$0")/.." && pwd)
usage() { echo "쓰는 법: sh scripts/qemu-dongle-test.sh [matrix|interactive] [rtl8831bu|rtl88x2bu]"; exit 1; }
MODE=${1:-matrix}
DRIVER=${2:-rtl8831bu}
case "$MODE" in matrix) DAP=30 ;; interactive) DAP=180 ;; *) usage ;; esac
case "$DRIVER" in rtl8831bu) DUSB=0bda:b831 ;; rtl88x2bu) DUSB=0bda:b812 ;; *) usage ;; esac
USB=${NX4_QEMU_USB:-$DUSB}
case "$USB" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f]:[0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "NX4_QEMU_USB는 VID:PID(소문자 16진수 넷:넷)입니다: $USB"; exit 1 ;;
esac
AP=${NX4_QEMU_AP_SECS:-$DAP}
UN=${NX4_QEMU_UNPLUG_SECS:-90}
for n in "$AP" "$UN"; do case "$n" in ''|*[!0-9]*) echo "초는 숫자로 주세요: $n"; exit 1 ;; esac; done
command -v qemu-system-arm >/dev/null 2>&1 || { echo "qemu-system-arm이 없습니다(맥: brew install qemu)"; exit 1; }
OUT=${NX4_QEMU_OUT:-$B/out/qemu-test/$DRIVER}
mkdir -p "$OUT"

if [ "${NX4_QEMU_NOBUILD:-0}" != 1 ]; then
  command -v docker >/dev/null 2>&1 || { echo "docker가 없습니다"; exit 1; }
  # 빌드 Docker context는 scripts/build-driver.sh와 같이 정한다(.env.local의 NX4_DRV_DOCKER_CONTEXT, 전역 기본은 바꾸지 않음)
  . "$B/scripts/local-env.sh"
  nx4_env "$B" NX4_DRV_DOCKER_CONTEXT || exit 1
  if [ -n "${NX4_DRV_DOCKER_CONTEXT:-}" ]; then
    if [ -n "${DOCKER_HOST:-}" ]; then
      echo "셸에 DOCKER_HOST($DOCKER_HOST)가 있어 NX4_DRV_DOCKER_CONTEXT($NX4_DRV_DOCKER_CONTEXT)가 무시됩니다(scripts/build-driver.sh와 같음)."
      exit 1
    fi
    DOCKER_CONTEXT=$NX4_DRV_DOCKER_CONTEXT
    export DOCKER_CONTEXT
  fi
  docker info >/dev/null 2>&1 || { echo "Docker가 돌고 있지 않습니다${DOCKER_CONTEXT:+(context $DOCKER_CONTEXT)}"; exit 1; }
  IMG=${NX4_DRV_IMAGE:-nx4kor-drvbuild}
  VOL=${NX4_DRV_VOLUME:-nx4kor-drivers}
  docker build -q --platform linux/amd64 -t "$IMG" "$B/drivers" >/dev/null
  echo "1. 게스트 커널·드라이버 빌드($DRIVER)"
  docker run --rm --platform linux/amd64 -v "$VOL":/work -v "$B/drivers":/src/drivers:ro -v "$B/tests/qemu":/src/qemu:ro \
    -v "$OUT":/out -e DRIVER="$DRIVER" -e JOBS="${NX4_DRV_JOBS:-}" "$IMG" bash /src/qemu/build-guest.sh
  echo "2. 게스트 루트 파일 시스템"
  docker run --rm --platform linux/amd64 -v "$B/tests/qemu":/src/qemu:ro -v "$OUT":/out "$IMG" sh /src/qemu/build-rootfs.sh
fi
for f in zImage rootfs.img bcmdhd.ko; do
  [ -s "$OUT/$f" ] || { echo "$OUT/$f가 없습니다(NX4_QEMU_NOBUILD 없이 다시 돌려 주세요)"; exit 1; }
done

LOG=$OUT/console-$MODE-$(date '+%Y%m%d-%H%M%S').log
if [ "$MODE" = interactive ]; then
  echo "3. QEMU($MODE, 동글 $USB를 VM으로 넘김, AP ${AP}초, 뽑기 ${UN}초)"
  echo "   AP가 뜨면 폰에서 NX4-QEMU-TEST(비밀번호 nx4-qemu-test)에 붙어 보고, \"동글을 뽑아 주세요\"가 나오면 PC에서 동글을 뽑아 주세요"
else
  echo "3. QEMU($MODE, 동글 $USB를 VM으로 넘김, AP 하나에 ${AP}초)"
fi
# QEMU의 libusb는 장치마다 macOS에서 "libusb_kernel_driver_active: -5"를 여러 번 찍는다(맥에는 이 동글의 커널 드라이버가 없음).
# 뜻이 없는 줄이라 거른다
qemu-system-arm -M virt,highmem=off -cpu cortex-a15 -smp 2 -m 1024 -display none -monitor none -serial stdio -no-reboot \
  -kernel "$OUT/zImage" \
  -append "console=ttyAMA0 root=/dev/vda rw rootfstype=ext4 init=/sbin/nx4init MODE=$MODE AP_SECS=$AP UNPLUG_SECS=$UN" \
  -drive if=none,file="$OUT/rootfs.img",format=raw,id=hd0 -device virtio-blk-device,drive=hd0 \
  -device usb-ehci,id=ehci -device usb-host,bus=ehci.0,vendorid=0x"${USB%%:*}",productid=0x"${USB#*:}" </dev/null 2>&1 \
  | grep -av 'libusb_kernel_driver_active' | tee "$LOG"
echo
echo "기록: $LOG"
grep -aq "^1-1 $USB " "$LOG" || echo "알림: VM에 동글($USB)이 보이지 않았습니다. PC에 꽂혀 있는지, 다른 프로그램(가상 머신 등)이 잡고 있지 않은지 봐 주세요"
grep -aE '^(== |-- )' "$LOG" | grep -av '^== 끝' || true
