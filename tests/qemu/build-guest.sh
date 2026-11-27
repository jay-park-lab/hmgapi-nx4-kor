#!/bin/bash
# QEMU 동글 테스트(docs/qemu-dongle-test.md)의 게스트 커널과 드라이버. scripts/qemu-dongle-test.sh가 드라이버 빌드 이미지
# (drivers/Dockerfile) 안에서 부른다. 받은 자료(커널 묶음, 모비스 툴체인, 드라이버 bare 저장소)는 드라이버 빌드 볼륨의 것을 쓰고,
# 이 테스트는 볼륨의 /work/qemu에만 쓴다(차 빌드의 /work/k는 건드리지 않음).
#
# 커널: kernel.org 3.18.24를 QEMU virt(ARMv7, cortex-a15)용으로. 차 커널(모비스·tcc803x)은 QEMU에 그 보드가 없어 부팅하지 못하고,
# 차의 .ko는 그 커널 빌드에만 맞는다. 그래서 같은 판의 커널에 차와 같은 무선·코어 설정(cfg80211·WEXT·NL80211_TESTMODE·RFKILL·
# LPAE·HIGHMEM·PREEMPT·SMP·HZ 100·스택 보호 REGULAR, mac80211 없음, 내장 규제 DB 없음)을 주고, 같은 드라이버 소스와 우리 패치
# (drivers/<드라이버>/*.diff)를 그 커널에 맞춰 다시 빌드한다. 툴체인은 차 빌드와 같은 모비스 arm-eabi-4.7이다.
# 스택 보호: 차 설정은 STRONG이지만 GCC 4.7에 없어 차 빌드도 REGULAR로 빌드한다(drivers/kernel/prepare.sh). 여기도 REGULAR.
# 맞추지 못하는 것: CONFIG_WAKELOCK(안드로이드 커널에만 있음. RTL8831BU의 wake lock 코드는 게스트에서 돌지 않음)
# make는 차 빌드처럼 make_retry(drivers/lib.sh)로 돌린다: 맥에서는 이 이미지가 늘 amd64 에뮬레이션이라 컴파일러가 멈출 수 있다.
# 환경: DRIVER(rtl8831bu·rtl88x2bu), JOBS, MAKE_TRIES. 결과: /out/zImage, /out/guest.config, /out/bcmdhd.ko
set -eu
. /src/drivers/inputs.sh
. /src/drivers/lib.sh
DRIVER=${DRIVER:-rtl8831bu}
case "$DRIVER" in
  rtl8831bu) DGIT=rtl8831bu; DCOMMIT=$RTL8831BU_COMMIT ;;
  rtl88x2bu) DGIT=rtl88x2bu; DCOMMIT=$RTL88X2BU_COMMIT ;;
  *) echo "DRIVER는 rtl8831bu나 rtl88x2bu입니다: $DRIVER"; exit 1 ;;
esac
Q=/work/qemu
TC=/work/tc
K=$Q/linux-3.18.24
JOBS=${JOBS:-$(nproc)}
mkdir -p $Q /out
for f in /work/dl/linux-3.18.24.tar.xz $TC/bin/arm-eabi-gcc /work/dl/$DGIT.git; do
  [ -e $f ] || { echo "드라이버 빌드 볼륨에 $f가 없습니다. 먼저 sh scripts/build-driver.sh를 한 번 돌려 주세요"; exit 1; }
done
export ARCH=arm CROSS_COMPILE=$TC/bin/arm-eabi-

# 커널 설정. ARCH_EXYNOS4는 HZ를 200으로 묶으므로(HZ_FIXED) 끈다. 이 파일을 바꾸면 아래 표시가 달라져 커널을 다시 빌드한다
CFG_ON="ARCH_VIRT ARM_LPAE HIGHMEM SMP PREEMPT HZ_100 CC_STACKPROTECTOR_REGULAR PCI PCI_HOST_GENERIC USB_SUPPORT USB USB_EHCI_HCD
 USB_EHCI_PCI USB_EHCI_TT_NEWSCHED VIRTIO VIRTIO_MMIO VIRTIO_BLK EXT4_FS DEVTMPFS DEVTMPFS_MOUNT TMPFS WIRELESS CFG80211
 NL80211_TESTMODE CFG80211_WEXT CFG80211_DEFAULT_PS RFKILL MODULES MODULE_UNLOAD PACKET UNIX INET IPV6 PRINTK_TIME"
CFG_OFF="ARCH_EXYNOS4 PREEMPT_NONE PREEMPT_VOLUNTARY CC_STACKPROTECTOR_NONE CC_STACKPROTECTOR_STRONG CFG80211_INTERNAL_REGDB
 MAC80211 MODVERSIONS"
STAMP="$KERNEL_SHA256 $TOOLCHAIN_SHA256 $(sha256sum < "$0" | cut -d' ' -f1)"
if [ "$(cat $K.stamp 2>/dev/null)" = "$STAMP" ] && [ -f $K/arch/arm/boot/zImage ] && [ -f $K/Module.symvers ]; then
  echo "지난 게스트 커널을 씀"
else
  rm -rf $K $K.stamp
  tar -xJf /work/dl/linux-3.18.24.tar.xz -C $Q
  cd $K
  make -s multi_v7_defconfig
  args=
  for o in $CFG_ON; do args="$args -e $o"; done
  for o in $CFG_OFF; do args="$args -d $o"; done
  ./scripts/config $args
  make -s olddefconfig
  # 모듈은 하나도 만들지 않는다(빌드 시간). 드라이버가 쓰는 것은 모두 커널에 넣는다
  sed -i 's/=m$/=n/' .config
  make -s olddefconfig
  for o in $CFG_ON; do grep -q "^CONFIG_$o=y" .config || { echo "설정에 CONFIG_$o=y가 없습니다"; exit 1; }; done
  for o in $CFG_OFF; do ! grep -q "^CONFIG_$o=y" .config || { echo "설정에 CONFIG_$o=y가 남았습니다"; exit 1; }; done
  grep -qx 'CONFIG_HZ=100' .config || { echo "CONFIG_HZ가 100이 아닙니다(차와 같아야 함)"; exit 1; }
  make_retry $Q/zImage.log $K -j$JOBS zImage || { echo "게스트 커널을 빌드하지 못함($Q/zImage.log)"; exit 1; }
  make_retry $Q/modules.log $K -j$JOBS modules || { echo "게스트 커널의 modules(Module.symvers)를 만들지 못함($Q/modules.log)"; exit 1; }
  [ -f arch/arm/boot/zImage ] && [ -f Module.symvers ] || { echo "zImage나 Module.symvers가 없습니다"; exit 1; }
  echo "$STAMP" > $K.stamp
fi
cd $K
KREL=$(cat include/config/kernel.release)
cp arch/arm/boot/zImage /out/zImage
cp .config /out/guest.config
echo "게스트 커널: $KREL"

D=$Q/$DRIVER
rm -rf $D; mkdir -p $D
git -C /work/dl/$DGIT.git archive "$DCOMMIT" | tar -x -C $D
for p in /src/drivers/$DRIVER/*.diff; do
  patch -d $D -p1 -s --no-backup-if-mismatch < $p || { echo "패치가 맞지 않음: $p"; exit 1; }
done
make_retry $Q/$DRIVER.log $D -j$JOBS ARCH=arm CROSS_COMPILE=$TC/bin/arm-eabi- KSRC=$K KVER=$KREL USER_MODULE_NAME=bcmdhd \
  || { echo "드라이버 컴파일($DRIVER, $Q/$DRIVER.log)"; exit 1; }
cp $D/bcmdhd.ko /out/bcmdhd.ko
echo "드라이버: $DRIVER $DCOMMIT, 패치 $(ls /src/drivers/$DRIVER/*.diff | sed 's#.*/##' | tr '\n' ' ')"
$TC/bin/arm-eabi-strings /out/bcmdhd.ko | grep -E '^vermagic=' || true
