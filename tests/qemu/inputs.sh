# QEMU 동글 테스트(docs/qemu-dongle-test.md)가 받는 바깥 자료. 받은 뒤 아래 값으로 같은 것인지 확인한다.
# tests/qemu/build-rootfs.sh가 읽는다(. 으로). 커널(kernel.org 3.18.24), 툴체인, 드라이버 소스는 drivers/inputs.sh의 값과
# 드라이버 빌드 볼륨(scripts/build-driver.sh가 받아 둔 것)을 그대로 쓴다.
# 이 파일과 tests/qemu/는 drivers/ 밖에 둔다: drivers/를 바꾼 커밋의 시각이 차에 넣을 .ko의 빌드 날짜가 되기 때문이다
# (scripts/build-driver.sh). 이 테스트를 고쳐도 차의 .ko는 바뀌지 않는다.

# 게스트 루트 파일 시스템: Alpine Linux 3.18 armv7(musl, busybox). 정적 apk와 서명 키 묶음을 받아 sha256으로 확인하고,
# 패키지는 그 키(armv7)로 서명을 확인해 넣는다(설치 스크립트는 돌리지 않음)
QEMU_ALPINE_MIRROR=https://dl-cdn.alpinelinux.org/alpine/v3.18/main
QEMU_APK_STATIC=apk-tools-static-2.14.4-r0.apk
QEMU_APK_STATIC_SHA256=7ed919a2e4ed18092d909a6f194457f4d74fcc62fd52ac9a80b9b54dc2d561cf
QEMU_ALPINE_KEYS=alpine-keys-2.4-r1.apk
QEMU_ALPINE_KEYS_SHA256=880983a4ba0e6403db432e7b2687af976e023567ab11d1428c758351011263e9
QEMU_ALPINE_PKGS="alpine-baselayout busybox musl hostapd iw iproute2"
