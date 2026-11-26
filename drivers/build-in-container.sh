#!/bin/bash
# USB Wi-Fi 동글 드라이버를 tcc803x 내비 커널(3.18.24-tcc)에 맞춰 빌드한다(#48). scripts/build-driver.sh가 컨테이너
# (drivers/Dockerfile, linux/amd64) 안에서 부른다. PC에서만 돈다.
#   /src/drivers  이 저장소의 drivers/(읽기 전용)
#   /work         Docker 볼륨: 받은 자료(dl/)·툴체인(tc/)·준비한 커널(k/)을 두고 다음 빌드에 다시 쓴다.
#                 macOS 파일 시스템은 대소문자를 가리지 않아 커널 소스를 풀 수 없으므로 볼륨에 둔다
#   /out          결과(.ko와 그 정보)
# 방법(drivers/README.md "빌드 방법"): kernel.org 3.18.24 뼈대에 현대모비스가 GPL로 공개한 내비 커널 소스를 덮고, 모비스 defconfig를
# 차 설정과 같게 맞춰 modules_prepare(drivers/kernel/prepare.sh), 그 트리와 모비스 소스에 든 툴체인으로 드라이버를 만든다.
# 환경 변수
#   MODE=nx4        이 저장소의 드라이버 둘(RTL88x2BU, RTL8831BU. 날짜·시각은 BUILD_DATE·BUILD_TIME으로 고정)
#   MODE=src-asset  모비스 원본 묶음에서 커널 소스 자산(inputs.sh MOBIS_SRC_FILE)을 만든다 → /out/src/
#   JOBS            make -j(기본 nproc)
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
# 커널 트리 경로는 .ko에 문자열로 들어가므로 고정한다(PC·CI가 같은 .ko를 내려면 같아야 함)
K=/work/k/linux-3.18.24
# 모비스 커널 소스 자산을 푼 곳(그 안의 $MOBIS_DIR/)
MS=/work/mobis
KREL=3.18.24-tcc
mkdir -p $DL $TC /out

. $S/lib.sh
# 받기의 다시 묻기: curl --retry는 503 같은 잠깐의 오류(408·429·5xx)에서 다시 묻는다. 사이를 15초씩 두고 8번까지
CURL_RETRY="--retry 8 --retry-delay 15"
# 받기: 없을 때만 받고, 다 받은 뒤에만 이름을 바꾼다
fetch() {
  [ -s "$2" ] && return 0
  curl -fsSL $CURL_RETRY -o "$2.part" "$1" || die "받지 못함: $1"
  mv "$2.part" "$2"
}

# 커널 소스 자산 만들기: 모비스 원본 묶음(zip)을 받아 sha256을 확인하고, 그 안의 커널 폴더만 고치지 않고 tar.xz로 묶는다.
# 같은 입력이면 같은 파일이 나오게 이름 차례·시각·소유자를 고정한다(tar --sort=name·--mtime·--owner, xz 한 스레드).
# 푼 폴더의 값(tree_sum)이 inputs.sh의 MOBIS_TREE_SHA256과 같아야 한다
make_src_asset() {
  command -v unzip >/dev/null || die "unzip이 없습니다(drivers/Dockerfile)"
  fetch "$MOBIS_ZIP_URL" $DL/mobis-original.zip
  sha_ok $MOBIS_ZIP_SHA256 $DL/mobis-original.zip || die "모비스 원본 묶음 sha256이 다릅니다(지우고 다시: $DL/mobis-original.zip)"
  W=/work/src-asset; rm -rf $W; mkdir -p $W
  unzip -q $DL/mobis-original.zip "$MOBIS_DIR/*" -d $W || die "원본 묶음에서 $MOBIS_DIR/를 꺼내지 못함"
  GOT=$(tree_sum $W/$MOBIS_DIR)
  echo "커널 폴더 값 $GOT"
  [ "$GOT" = "$MOBIS_TREE_SHA256" ] || die "커널 폴더 값이 inputs.sh MOBIS_TREE_SHA256($MOBIS_TREE_SHA256)과 다릅니다"
  mkdir -p /out/src
  tar -C $W --sort=name --mtime='2025-11-03 00:00:00 UTC' --owner=0 --group=0 --numeric-owner --mode='u+rwX,go+rX,go-w' \
    --format=gnu -cf - "$MOBIS_DIR" | xz -9 -T1 > /out/src/$MOBIS_SRC_FILE
  rm -rf $W
  ( cd /out/src && sha256sum $MOBIS_SRC_FILE | tee $MOBIS_SRC_FILE.sha256 )
}
if [ "$MODE" = src-asset ]; then
  say "커널 소스 자산 만들기(모비스 원본 → $MOBIS_SRC_FILE)"
  make_src_asset
  exit 0
fi

# 모비스 커널 소스 자산: 받아 sha256을 확인하고 풀어, 푼 폴더의 값을 확인한다(처음 한 번. 자산 sha256을 표시로 남겨 다시 씀)
get_mobis_src() {
  [ "$(cat $MS.stamp 2>/dev/null)" = "$MOBIS_SRC_SHA256" ] && [ -d $MS/$MOBIS_DIR ] && return 0
  rm -rf $MS $MS.stamp
  fetch "$MOBIS_SRC_URL" $DL/$MOBIS_SRC_FILE
  sha_ok $MOBIS_SRC_SHA256 $DL/$MOBIS_SRC_FILE || die "모비스 커널 소스 자산 sha256이 다릅니다(지우고 다시: $DL/$MOBIS_SRC_FILE)"
  mkdir -p $MS
  tar -xJf $DL/$MOBIS_SRC_FILE -C $MS || die "모비스 커널 소스 자산을 풀지 못함"
  [ "$(tree_sum $MS/$MOBIS_DIR)" = "$MOBIS_TREE_SHA256" ] || die "모비스 커널 폴더 값이 다릅니다($(tree_sum $MS/$MOBIS_DIR))"
  echo "$MOBIS_SRC_SHA256" > $MS.stamp
}
# 툴체인: 모비스 커널 소스에 든 묶음(sha256 고정)을 푼다. 폴더 경로가 .ko의 디버그 정보에 들어가므로 늘 $TC에 둔다
get_toolchain() {
  T=$MS/$MOBIS_DIR/$TOOLCHAIN_PATH
  [ -x $TC/bin/arm-eabi-gcc ] && [ "$(cat $TC.stamp 2>/dev/null)" = "$TOOLCHAIN_SHA256" ] && return 0
  sha_ok $TOOLCHAIN_SHA256 $T || die "툴체인 묶음 sha256이 다릅니다: $T"
  rm -rf $TC $TC.stamp; mkdir -p $TC
  tar -xzf $T -C $TC --strip-components=1 || die "툴체인 묶음을 풀지 못함"
  echo "$TOOLCHAIN_SHA256" > $TC.stamp
}

say "1. 받은 자료 확인"
fetch "$KERNEL_URL" $DL/linux-3.18.24.tar.xz
sha_ok $KERNEL_SHA256 $DL/linux-3.18.24.tar.xz || die "커널 sha256이 다릅니다(지우고 다시: $DL/linux-3.18.24.tar.xz)"
get_mobis_src
get_toolchain
$TC/bin/arm-eabi-gcc --version | head -1
# 드라이버 저장소: bare로 받아 두고, 고정한 커밋이 없으면 한 번 더 받는다. get_driver <이름> <주소> <커밋>
get_driver() {
  if [ ! -d $DL/$1.git ]; then
    git clone -q --bare "$2" $DL/$1.git || die "$1을 받지 못함"
  fi
  git -C $DL/$1.git cat-file -e "$3^{commit}" 2>/dev/null || git -C $DL/$1.git fetch -q origin || die "$1을 받지 못함"
  git -C $DL/$1.git cat-file -e "$3^{commit}" || die "$1 커밋이 없습니다: $3"
}
get_driver rtl88x2bu "$RTL88X2BU_GIT" "$RTL88X2BU_COMMIT"
get_driver rtl8831bu "$RTL8831BU_GIT" "$RTL8831BU_COMMIT"

say "2. 커널 준비(kernel/prepare.sh: kernel.org 3.18.24 뼈대 + 모비스 커널 소스 + 모비스 defconfig를 차 설정에 맞춤)"
# 입력이 같으면 지난 빌드의 커널 트리를 다시 쓴다. 커널 준비의 내용은 모두 drivers/kernel/에 있어 그 파일들의 값이 표시에 든다
STAMP="$KERNEL_SHA256 $MOBIS_SRC_SHA256 $MOBIS_DEFCONFIG $KCONFIG_SUM $TOOLCHAIN_SHA256 $(cat $S/kernel/* | sha256sum | cut -d' ' -f1)"
if [ "$(cat $K.stamp 2>/dev/null)" = "$STAMP" ] && [ -f $K/include/config/kernel.release ]; then
  echo "지난 빌드의 커널 트리를 씀"
else
  rm -f $K.stamp
  MOBIS_DEFCONFIG=$MOBIS_DEFCONFIG KCONFIG_SUM=$KCONFIG_SUM \
    bash $S/kernel/prepare.sh $K $DL/linux-3.18.24.tar.xz $MS/$MOBIS_DIR $TC $JOBS
  echo "$STAMP" > $K.stamp
fi
# 커널이 내보내는 이름 목록(lib.sh kernel_exports). 준비한 트리마다 한 번 만든다(트리를 다시 준비하면 stamp가 더 새것이 됨)
if [ ! -s $K.exports ] || [ $K.stamp -nt $K.exports ]; then
  kernel_exports $K > $K.exports.tmp || die "커널이 내보내는 이름 목록을 만들지 못함"
  mv $K.exports.tmp $K.exports
fi

# 드라이버 하나 빌드: $1 이름(rtl88x2bu·rtl8831bu, bare 저장소 $DL/<이름>.git), $2 커밋, $3 폴더, $4 모듈 이름, $5 날짜, $6 시각,
# $7 고정한 컴파일 옵션 지문, $8 우리 옵션을 넘길 make 변수, 그 뒤 패치 파일들(차례대로 patch -p1).
# 우리 옵션(-g, 날짜 고정)을 넘기는 변수는 드라이버 Makefile에 따라 다르다. RTL88x2BU는 자기 옵션을 ccflags-y에 넣어 명령줄의
# EXTRA_CFLAGS로 넘긴다. RTL8831BU는 include 경로까지 EXTRA_CFLAGS에 넣으므로 명령줄 EXTRA_CFLAGS가 그것을 덮어써 버린다
# (drv_types.h를 못 찾음). 그래서 Makefile 첫 줄이 받는 USER_EXTRA_CFLAGS로 넘긴다
build_driver() {
  DN=$1; DC=$2; D=$3; MNAME=$4; BDATE=$5; BTIME=$6; DEXP=$7; DVAR=$8; shift 8
  rm -rf $D; mkdir -p $D
  git -C $DL/$DN.git archive "$DC" | tar -x -C $D
  for p in "$@"; do
    patch -d $D -p1 -s --no-backup-if-mismatch < "$p" || die "패치가 맞지 않음: $p"
  done
  # 드라이버가 컴파일 날짜·시각(__DATE__, __TIME__)을 문자열로 넣는다. 고정해야 같은 .ko가 다시 만들어진다
  printf '#undef __DATE__\n#define __DATE__ "%s"\n#undef __TIME__\n#define __TIME__ "%s"\n' "$BDATE" "$BTIME" > /tmp/pin.h
  # 에뮬레이션에서 컴파일러가 멈추면 이어서 다시 돌린다(lib.sh make_retry)
  make_retry $D.log $D -j$JOBS ARCH=arm CROSS_COMPILE=$TC/bin/arm-eabi- KSRC=$K KVER=$KREL USER_MODULE_NAME=$MNAME \
    "$DVAR=-g -Wno-builtin-macro-redefined -include /tmp/pin.h" || die "드라이버 컴파일($DN)"
  check_cflags $D "$DEXP"
  # 커널이 내보내지 않는 심볼을 부르면 차에서 올라가지 않는다(lib.sh check_ksyms)
  $TC/bin/arm-eabi-nm -u $D/$MNAME.ko | awk '{print $NF}' > /tmp/undef.txt
  check_ksyms /tmp/undef.txt $K.exports
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

# 결과와 정보 파일: $1 이름, $2 커밋, $3 폴더, 그 뒤 패치 파일들. /out/tcc803x/<이름>/bcmdhd.ko와 bcmdhd.ko.txt
report_driver() {
  RN=$1; RC=$2; RD=$3; shift 3
  O=/out/tcc803x/$RN
  mkdir -p $O
  cp $RD/bcmdhd.ko $O/bcmdhd.ko
  { echo "driver $RN $RC"
    for p in "$@"; do echo "patch ${p#$S/} $(sha256sum "$p" | cut -d' ' -f1)"; done
    echo "kernel linux-3.18.24 $KERNEL_SHA256"
    echo "kernel source $MOBIS_SRC_FILE $MOBIS_SRC_SHA256 (tree $MOBIS_TREE_SHA256)"
    echo "kernel config $MOBIS_DEFCONFIG adjusted, kconfig_sum $KCONFIG_SUM"
    echo "toolchain $TOOLCHAIN_PATH $TOOLCHAIN_SHA256"
    echo "build date $BUILD_DATE $BUILD_TIME"
    # 오브젝트 컴파일 옵션 묶음의 sha256(check_cflags). PC와 CI가 같아야 한다
    echo "cflags $CFLAGS_SUM"
    # 빌드한 곳(scripts/build-driver.sh가 줌: Docker VM의 CPU, OS·CPU)과 에뮬레이션인지(BUILD_EMU). 에뮬레이션 빌드는 차에 넣지 않는다(drivers/README.md)
    case "${BUILD_EMU:-}" in
      no) echo "build host ${HOST_ARCH:-unknown}" ;;
      *) echo "build host ${HOST_ARCH:-unknown} (emulated: check against CI, do not ship)" ;;
    esac
    # 3.18의 모듈에는 modinfo name이 없다. 커널이 쓰는 이름(struct module의 name)은 .gnu.linkonce.this_module에 있다
    $TC/bin/arm-eabi-objcopy -O binary --only-section=.gnu.linkonce.this_module $O/bcmdhd.ko /tmp/this_module.bin
    echo "module name $(strings -n 3 /tmp/this_module.bin | head -1)"
    modinfo -F parm $O/bcmdhd.ko | grep -E '^(ifname|iface_name|firmware_path|nvram_path):' | sed 's/^/parm /'
    modinfo -F alias $O/bcmdhd.ko | sed 's/^/alias /'
    ko_info $O/bcmdhd.ko; } | tee $O/bcmdhd.ko.txt
}

case "$MODE" in
  nx4)
    : "${BUILD_DATE:?BUILD_DATE(예: Nov 25 2026)를 주세요}" "${BUILD_TIME:?BUILD_TIME(예: 12:00:00)을 주세요}"
    # 순정 HAL이 /system/wifi/bcmdhd.ko를 bcmdhd라는 이름으로 올리고 내리므로(/proc/modules, rmmod) 두 드라이버 모두 모듈 이름을
    # bcmdhd로 한다. 차에는 그 자리에 하나만 둔다(어느 것을 둘지는 4단계, drivers/README.md "두 드라이버와 자리 하나")
    say "3. 드라이버 RTL88x2BU(rtl88x2bu $RTL88X2BU_COMMIT + 패치, 모듈 이름 bcmdhd)"
    P1=$(ls $S/rtl88x2bu/*.diff | sort)
    # shellcheck disable=SC2086
    build_driver rtl88x2bu "$RTL88X2BU_COMMIT" /work/nx4/rtl88x2bu bcmdhd "$BUILD_DATE" "$BUILD_TIME" "$EXPECTED_CFLAGS_SHA256" EXTRA_CFLAGS $P1
    # shellcheck disable=SC2086
    report_driver rtl88x2bu "$RTL88X2BU_COMMIT" /work/nx4/rtl88x2bu $P1
    say "4. 드라이버 RTL8831BU(rtl8831bu $RTL8831BU_COMMIT + 패치, 모듈 이름 bcmdhd)"
    P2=$(ls $S/rtl8831bu/*.diff | sort)
    # shellcheck disable=SC2086
    build_driver rtl8831bu "$RTL8831BU_COMMIT" /work/nx4/rtl8831bu bcmdhd "$BUILD_DATE" "$BUILD_TIME" "$EXPECTED_CFLAGS_SHA256_8831BU" USER_EXTRA_CFLAGS $P2
    # shellcheck disable=SC2086
    report_driver rtl8831bu "$RTL8831BU_COMMIT" /work/nx4/rtl8831bu $P2
    ;;
  *) die "MODE는 nx4 또는 src-asset: $MODE" ;;
esac
