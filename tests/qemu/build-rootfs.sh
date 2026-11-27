#!/bin/sh
# QEMU 동글 테스트(docs/qemu-dongle-test.md)의 게스트 루트 파일 시스템. scripts/qemu-dongle-test.sh가 드라이버 빌드 이미지
# (ubuntu 20.04, amd64) 안에서 부른다. Alpine 3.18 armv7(musl, busybox)에 hostapd·iw·iproute2를 넣고(tests/qemu/inputs.sh),
# 테스트 init(tests/qemu/nx4init)과 드라이버(/out/bcmdhd.ko)를 넣어 ext4 이미지(/out/rootfs.img)로 만든다.
set -eu
. /src/qemu/inputs.sh
W=/tmp/apkw; R=/tmp/rootfs
rm -rf $W $R; mkdir -p $W $R/etc/apk
cd $W
for f in "$QEMU_APK_STATIC $QEMU_APK_STATIC_SHA256" "$QEMU_ALPINE_KEYS $QEMU_ALPINE_KEYS_SHA256"; do
  set -- $f
  curl -fsS --retry 5 --retry-delay 5 -o $1 "$QEMU_ALPINE_MIRROR/x86_64/$1" || { echo "받지 못함: $1"; exit 1; }
  echo "$2  $1" | sha256sum -c --quiet - || { echo "sha256이 다릅니다: $1"; exit 1; }
done
tar -xzf $QEMU_APK_STATIC sbin/apk.static 2>/dev/null
tar -xzf $QEMU_ALPINE_KEYS usr/share/apk/keys 2>/dev/null
[ -x sbin/apk.static ] && [ -d usr/share/apk/keys/armv7 ] || { echo "apk.static이나 armv7 키를 꺼내지 못함"; exit 1; }
echo "$QEMU_ALPINE_MIRROR" > $R/etc/apk/repositories
./sbin/apk.static --root $R --arch armv7 --keys-dir $W/usr/share/apk/keys/armv7 --initdb --no-scripts --no-cache --quiet \
  add $QEMU_ALPINE_PKGS
./sbin/apk.static --root $R --arch armv7 info -v 2>/dev/null | grep -E '^(hostapd|iw|busybox|musl)-' | tr '\n' ' '; echo
mkdir -p $R/lib/modules $R/sbin $R/proc $R/sys $R/dev $R/run $R/tmp $R/var/run $R/var/log $R/data/misc/wifi
cp /src/qemu/nx4init $R/sbin/nx4init
chmod 755 $R/sbin/nx4init
cp /out/bcmdhd.ko $R/lib/modules/bcmdhd.ko
for f in usr/sbin/hostapd usr/sbin/iw sbin/ip bin/busybox; do [ -x $R/$f ] || { echo "루트 파일 시스템에 $f가 없습니다"; exit 1; }; done
rm -f /out/rootfs.img
mkfs.ext4 -q -L nx4root -d $R /out/rootfs.img 256M
echo "루트 파일 시스템: $(du -sh $R | cut -f1)"
