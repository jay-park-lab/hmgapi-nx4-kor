#!/bin/bash
# 커널 트리 준비(tcc803x 내비 커널 3.18.24-tcc와 모듈 배치를 맞춤). drivers/build-in-container.sh가 부른다. 컨테이너 안에서만.
# Korea Projection 1.8.0-beta.2의 build-tcc803x.sh(GPL-2.0)와 같은 단계다:
#   1. kernel.org 3.18.24를 푼다
#   2. 차의 TCC803X 기계 항목이 select하던 설정(kernel.org에 없음)을 Kconfig 끝에 붙여 살린다(빌드 트리에만)
#   3. 순정 커널에만 있는 구조체 필드를 같은 자리에 넣는다(hdr-patch.sh, hdr-patch-803x.sh. 동작은 바꾸지 않음)
#   4. 차 커널 설정으로 olddefconfig. gcc 4.7에 없는 -fstack-protector-strong만 REGULAR로(같은 __stack_chk_* 기호)
#   5. modules_prepare, kernel.release가 3.18.24-tcc인지 확인
# 이 파일은 drivers/kernel/에 있어, 바꾸면 build-in-container.sh의 커널 트리 재사용 표시(stamp)가 달라져 다시 준비한다.
# 쓰는 법: prepare.sh <커널 트리 경로> <linux-3.18.24.tar.xz> <차 커널 설정> <툴체인 폴더> <make -j>
set -euo pipefail
K=$1; KTAR=$2; CFG=$3; TC=$4; JOBS=$5
H=$(cd "$(dirname "$0")" && pwd)
. "$H/../lib.sh"

rm -rf "$(dirname "$K")"
mkdir -p "$(dirname "$K")"
tar -xJf "$KTAR" -C "$(dirname "$K")"
{ echo; echo "# kp: 차의 TCC803X 기계 항목이 select하던 것(kernel.org에 없음). 빌드 트리에만 붙인다"
  echo "config KP_TCC803X_LAYOUT"; echo "	def_bool y"
  for s in ARCH_DMA_ADDR_T_64BIT ZONE_DMA PINCTRL PINMUX PINCONF PM_GENERIC_DOMAINS PM_OPP USB_OTG; do echo "	select $s"; done; } >> "$K/arch/arm/Kconfig"
bash "$H/hdr-patch.sh" "$K"
bash "$H/hdr-patch-803x.sh" "$K"
cp "$CFG" "$K/.config"
"$K/scripts/config" --file "$K/.config" --disable CC_STACKPROTECTOR_STRONG --enable CC_STACKPROTECTOR_REGULAR
# olddefconfig도 호스트 gcc로 scripts/basic/fixdep·scripts/kconfig/conf를 만든다. 에뮬레이션 충돌에 대비해 같이 감싼다
make_retry "$(dirname "$K")/olddefconfig.log" "$K" -s ARCH=arm CROSS_COMPILE="$TC/bin/arm-eabi-" olddefconfig || die "olddefconfig"
make_retry "$(dirname "$K")/modules_prepare.log" "$K" -s ARCH=arm CROSS_COMPILE="$TC/bin/arm-eabi-" -j"$JOBS" modules_prepare \
  || die "modules_prepare"
[ "$(cat "$K/include/config/kernel.release")" = 3.18.24-tcc ] || die "kernel.release가 3.18.24-tcc가 아닙니다: $(cat "$K/include/config/kernel.release")"
