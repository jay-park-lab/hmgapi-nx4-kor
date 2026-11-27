#!/bin/bash
# 커널 트리 준비: 내비 커널(3.18.24-tcc)과 같은 트리를 만들어 modules_prepare까지 한다. drivers/build-in-container.sh가
# 컨테이너 안에서 부른다. 방법(drivers/README.md "커널 준비"):
#   1. kernel.org 3.18.24를 푼다(빌드 뼈대: 맨 위 Makefile·Kconfig, scripts/ 등. 모비스 커널 소스에는 이것이 없다)
#   2. 그 위에 모비스 커널 소스(AVNT5W_TCC803XKK_kernel/)를 그대로 덮는다. 같은 경로의 파일은 모비스 것이 된다. tcc803x 기계
#      코드(arch/arm/mach-tcc803x, plat-tcc)와 순정 커널의 구조체·Kconfig가 여기서 온다. toolchain/은 덮지 않는다(build-in-container.sh가
#      툴체인으로 따로 푼다). kernel.org에서 링크인 곳이 모비스 쪽에서는 폴더라(arch/arm/boot/dts/include/dt-bindings) cp가 아닌 tar로 덮는다
#   3. 모비스 defconfig → 차 설정과 다른 USB 네트워크 드라이버 3개를 끄고, gcc 4.7에 없는 -fstack-protector-strong을 REGULAR로
#      → olddefconfig. 결과가 차 설정과 같은지 kconfig_sum으로 확인(inputs.sh KCONFIG_SUM)
#   4. modules_prepare. kernel.release가 3.18.24-tcc인지 확인
# 이 파일은 drivers/kernel/에 있어, 바꾸면 build-in-container.sh의 커널 트리 재사용 표시(stamp)가 달라져 다시 준비한다.
# 쓰는 법: prepare.sh <커널 트리 경로> <linux-3.18.24.tar.xz> <모비스 커널 폴더> <툴체인 폴더> <make -j>
#   환경 변수 MOBIS_DEFCONFIG, KCONFIG_SUM(inputs.sh)
set -euo pipefail
K=$1; KTAR=$2; MSRC=$3; TC=$4; JOBS=$5
: "${MOBIS_DEFCONFIG:?}" "${KCONFIG_SUM:?}"
H=$(cd "$(dirname "$0")" && pwd)
. "$H/../lib.sh"
[ "$(basename "$K")" = linux-3.18.24 ] || die "커널 트리 경로는 .../linux-3.18.24여야 합니다(kernel.org 묶음의 폴더 이름): $K"

rm -rf "$(dirname "$K")"
mkdir -p "$(dirname "$K")"
tar -xJf "$KTAR" -C "$(dirname "$K")"
[ -f "$MSRC/arch/arm/mach-tcc803x/include/mach/io.h" ] || die "모비스 커널 폴더가 아닙니다(arch/arm/mach-tcc803x가 없음): $MSRC"
tar -C "$MSRC" --exclude=./toolchain -cf - . | tar -C "$K" -xf -

M() { make_retry "$(dirname "$K")/$1.log" "$K" -s ARCH=arm CROSS_COMPILE="$TC/bin/arm-eabi-" "${@:2}"; }
M defconfig "$MOBIS_DEFCONFIG" || die "make $MOBIS_DEFCONFIG"
"$K/scripts/config" --file "$K/.config" \
  --disable CC_STACKPROTECTOR_STRONG --enable CC_STACKPROTECTOR_REGULAR \
  --disable USB_NET_CDC_NCM --disable USB_NET_CDC_SUBSET --disable USB_NET_NET1080
M olddefconfig olddefconfig || die "make olddefconfig"
GOT=$(kconfig_sum "$K/.config")
[ "$GOT" = "$KCONFIG_SUM" ] || die "커널 설정이 차 설정과 다릅니다(kconfig_sum $GOT, 고정 $KCONFIG_SUM)"
echo "커널 설정: $MOBIS_DEFCONFIG 조정, 차 설정과 같음($GOT)"

M modules_prepare -j"$JOBS" modules_prepare || die "modules_prepare"
[ "$(cat "$K/include/config/kernel.release")" = 3.18.24-tcc ] || die "kernel.release가 3.18.24-tcc가 아닙니다: $(cat "$K/include/config/kernel.release")"
