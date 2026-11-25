#!/bin/bash
# USB Wi-Fi 동글 드라이버를 tcc803x 내비 커널(3.18.24-tcc)에 맞춰 빌드한다(#48). scripts/build-driver.sh가 컨테이너
# (drivers/Dockerfile, linux/amd64) 안에서 부른다. PC에서만 돈다.
#   /src/drivers  이 저장소의 drivers/(읽기 전용)
#   /work         Docker 볼륨: 받은 자료(dl/)·툴체인(tc/)·준비한 커널(t803/)을 두고 다음 빌드에 다시 쓴다.
#                 macOS 파일 시스템은 대소문자를 가리지 않아 커널 소스를 풀 수 없으므로 볼륨에 둔다
#   /out          결과(.ko와 그 정보)
# 방법은 Korea Projection 1.8.0-beta.2의 build-tcc803x.sh(GPL-2.0 묶음)와 같다: kernel.org 3.18.24에 TCC803X가 select하던
# 설정을 살리고 헤더 구조체 배치를 순정과 맞춘 뒤(drivers/kernel/) 차 커널 설정으로 modules_prepare, 그 트리로 드라이버를 만든다.
# 환경 변수
#   MODE=kp-check  KP 1.8.0-beta.2 패키지의 88x2bu.ko와 같은 것이 만들어지는지(빌드 날짜·시각과 경로를 KP 값으로 고정, md5 비교)
#   MODE=nx4       이 저장소의 드라이버(지금은 KP와 같은 패치. 날짜·시각은 BUILD_DATE·BUILD_TIME으로 고정)
#   JOBS           make -j(기본 nproc)
set -euo pipefail
# 빌드 중에 PC 쪽 drivers/가 바뀌어도(bash는 스크립트를 읽어 가며 돈다) 흔들리지 않게 사본으로 돈다
if [ "${NX4_DRV_COPY:-}" != 1 ]; then
  rm -rf /tmp/drivers
  cp -r /src/drivers /tmp/drivers
  NX4_DRV_COPY=1 exec bash /tmp/drivers/build-in-container.sh
fi
S=/tmp/drivers
. $S/inputs.sh
MODE=${MODE:-nx4}
JOBS=${JOBS:-$(nproc)}
DL=/work/dl
TC=/work/tc
# 커널 트리 경로는 .ko에 문자열로 들어가므로 KP와 같게 둔다(kp-check의 md5 비교, PC·CI가 같은 .ko를 내려면 고정이어야 함)
K=/work/t803/k-kp-h2/linux-3.18.24
KREL=3.18.24-tcc
mkdir -p $DL $TC /out

. $S/lib.sh
# 받기: 없을 때만 받고, 다 받은 뒤에만 이름을 바꾼다
fetch() {
  [ -s "$2" ] && return 0
  curl -fsSL --retry 3 -o "$2.part" "$1" || die "받지 못함: $1"
  mv "$2.part" "$2"
}
# 툴체인: 커밋으로 고정한 묶음을 받아 폴더 전체 값으로 확인한다(묶음 파일은 받을 때마다 만들어져 그 sha256은 고정되지 않음).
# 볼륨에 있던 것이 다르면 한 번 다시 받는다
get_toolchain() {
  [ -x $TC/bin/arm-eabi-gcc ] && [ "$(tree_sum $TC)" = "$TOOLCHAIN_TREE_SHA256" ] && return 0
  rm -rf $TC; mkdir -p $TC
  curl -fsSL --retry 3 "$TOOLCHAIN_URL" | tar -xz -C $TC || die "툴체인을 받지 못함"
  [ "$(tree_sum $TC)" = "$TOOLCHAIN_TREE_SHA256" ] || die "툴체인 폴더 값이 다릅니다($(tree_sum $TC))"
}

say "1. 받은 자료 확인"
fetch "$KERNEL_URL" $DL/linux-3.18.24.tar.xz
sha_ok $KERNEL_SHA256 $DL/linux-3.18.24.tar.xz || die "커널 sha256이 다릅니다(지우고 다시: $DL/linux-3.18.24.tar.xz)"
fetch "$CARCFG_URL" $DL/config_tcc803x.txt
sha_ok $CARCFG_SHA256 $DL/config_tcc803x.txt || die "차 커널 설정 sha256이 다릅니다"
get_toolchain
$TC/bin/arm-eabi-gcc --version | head -1
if [ ! -d $DL/rtl88x2bu.git ]; then
  git clone -q --bare "$RTL88X2BU_GIT" $DL/rtl88x2bu.git || die "rtl88x2bu를 받지 못함"
fi
git -C $DL/rtl88x2bu.git cat-file -e "$RTL88X2BU_COMMIT^{commit}" 2>/dev/null \
  || git -C $DL/rtl88x2bu.git fetch -q origin || die "rtl88x2bu를 받지 못함"
git -C $DL/rtl88x2bu.git cat-file -e "$RTL88X2BU_COMMIT^{commit}" || die "rtl88x2bu 커밋이 없습니다: $RTL88X2BU_COMMIT"

say "2. 커널 준비(kernel/prepare.sh: kernel.org 3.18.24 + TCC803X select + 헤더 배치 패치 + 차 설정)"
# 입력이 같으면 지난 빌드의 커널 트리를 다시 쓴다. 커널 준비의 내용은 모두 drivers/kernel/에 있어 그 파일들의 값이 표시에 든다
STAMP="$KERNEL_SHA256 $CARCFG_SHA256 $TOOLCHAIN_TREE_SHA256 $(cat $S/kernel/* | sha256sum | cut -d' ' -f1)"
if [ "$(cat $K.stamp 2>/dev/null)" = "$STAMP" ] && [ -f $K/include/config/kernel.release ]; then
  echo "지난 빌드의 커널 트리를 씀"
else
  rm -f $K.stamp
  bash $S/kernel/prepare.sh $K $DL/linux-3.18.24.tar.xz $DL/config_tcc803x.txt $TC $JOBS
  echo "$STAMP" > $K.stamp
fi

# 드라이버 하나 빌드: $1 폴더, $2 모듈 이름(빈 값이면 드라이버 기본 88x2bu), $3 날짜, $4 시각, 그 뒤 패치 파일들(차례대로 patch -p1)
build_88x2bu() {
  D=$1; MNAME=$2; BDATE=$3; BTIME=$4; shift 4
  rm -rf $D; mkdir -p $D
  git -C $DL/rtl88x2bu.git archive "$RTL88X2BU_COMMIT" | tar -x -C $D
  for p in "$@"; do
    patch -d $D -p1 -s --no-backup-if-mismatch < "$p" || die "패치가 맞지 않음: $p"
  done
  # 드라이버가 컴파일 날짜·시각(__DATE__, __TIME__)을 문자열로 넣는다. 고정해야 같은 .ko가 다시 만들어진다
  printf '#undef __DATE__\n#define __DATE__ "%s"\n#undef __TIME__\n#define __TIME__ "%s"\n' "$BDATE" "$BTIME" > /tmp/pin.h
  # 에뮬레이션에서 컴파일러가 멈추면 이어서 다시 돌린다(lib.sh make_retry)
  make_retry $D.log $D -j$JOBS ARCH=arm CROSS_COMPILE=$TC/bin/arm-eabi- KSRC=$K KVER=$KREL ${MNAME:+USER_MODULE_NAME=$MNAME} \
    EXTRA_CFLAGS="-g -Wno-builtin-macro-redefined -include /tmp/pin.h" || die "드라이버 컴파일"
}
# 결과 정보: modinfo와 md5·sha256
ko_info() {
  echo "md5 $(md5sum "$1" | cut -d' ' -f1)"
  echo "sha256 $(sha256sum "$1" | cut -d' ' -f1)"
  echo "size $(stat -c %s "$1")"
  modinfo -F vermagic "$1" | sed 's/^/vermagic /'
  modinfo -F srcversion "$1" | sed 's/^/srcversion /'
  modinfo -F license "$1" | sed 's/^/license /'
}

case "$MODE" in
  kp-check)
    say "3. KP 1.8.0-beta.2와 같은지(날짜·시각·경로를 KP 값으로)"
    D=/work/t803/d-kp-h2-pkp
    build_88x2bu $D "" "$KP_88X2BU_DATE" "$KP_88X2BU_TIME" $S/rtl88x2bu/0001-kp-protect.diff
    mkdir -p /out/kp-check
    cp $D/88x2bu.ko /out/kp-check/88x2bu.ko
    ko_info /out/kp-check/88x2bu.ko | tee /out/kp-check/88x2bu.ko.txt
    GOT=$(md5sum /out/kp-check/88x2bu.ko | cut -d' ' -f1)
    if [ "$GOT" = "$KP_88X2BU_MD5" ]; then
      echo "KP와 같음: md5 $GOT"
    else
      echo "KP와 다름: md5 $GOT (KP $KP_88X2BU_MD5)"; exit 3
    fi
    ;;
  nx4)
    say "3. 드라이버(rtl88x2bu $RTL88X2BU_COMMIT + 패치, 모듈 이름 bcmdhd)"
    : "${BUILD_DATE:?BUILD_DATE(예: Nov 25 2026)를 주세요}" "${BUILD_TIME:?BUILD_TIME(예: 12:00:00)을 주세요}"
    D=/work/nx4/rtl88x2bu
    PATCHES=$(ls $S/rtl88x2bu/*.diff | sort)
    # 순정 HAL이 /system/wifi/bcmdhd.ko를 bcmdhd라는 이름으로 올리고 내리므로(/proc/modules, rmmod) 모듈 이름을 맞춘다
    # shellcheck disable=SC2086
    build_88x2bu $D bcmdhd "$BUILD_DATE" "$BUILD_TIME" $PATCHES
    O=/out/tcc803x/rtl88x2bu
    mkdir -p $O
    cp $D/bcmdhd.ko $O/bcmdhd.ko
    { echo "driver rtl88x2bu $RTL88X2BU_COMMIT"
      for p in $PATCHES; do echo "patch ${p#$S/} $(sha256sum "$p" | cut -d' ' -f1)"; done
      echo "kernel linux-3.18.24 $KERNEL_SHA256"
      echo "car config $CARCFG_SHA256"
      echo "build date $BUILD_DATE $BUILD_TIME"
      # 3.18의 모듈에는 modinfo name이 없다. 커널이 쓰는 이름(struct module의 name)은 .gnu.linkonce.this_module에 있다
      $TC/bin/arm-eabi-objcopy -O binary --only-section=.gnu.linkonce.this_module $O/bcmdhd.ko /tmp/this_module.bin
      echo "module name $(strings -n 3 /tmp/this_module.bin | head -1)"
      modinfo -F parm $O/bcmdhd.ko | grep -E '^(ifname|iface_name|firmware_path|nvram_path):' | sed 's/^/parm /'
      modinfo -F alias $O/bcmdhd.ko | sed 's/^/alias /'
      ko_info $O/bcmdhd.ko; } | tee $O/bcmdhd.ko.txt
    ;;
  *) die "MODE는 kp-check 또는 nx4: $MODE" ;;
esac
