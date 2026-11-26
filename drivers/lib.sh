# drivers/build-in-container.sh, drivers/kernel/prepare.sh, drivers/config-sum.sh가 함께 쓰는 함수(. 으로 읽음).
# config-sum.sh(kconfig_sum)는 PC에서도 돈다. 나머지는 컨테이너 안에서만 돈다.

say() { echo "== $*"; }
die() { echo "빌드 실패: $*" >&2; exit 2; }
sha_ok() { [ "$(sha256sum "$2" | cut -d' ' -f1)" = "$1" ]; }

# 커널 설정의 값: 값이 있는 CONFIG_ 줄(꺼진 것은 "# ... is not set"이라 빠짐)을 정렬한 것의 sha256. 머리말·빈 줄·줄 차례와
# 상관없이 설정 값이 같으면 같다. 차의 /proc/config.gz는 -fstack-protector-strong(STRONG)이고 빌드는 gcc 4.7에 맞춰 REGULAR로
# 바꾸므로, STRONG=y는 REGULAR=y로 보고 센다. 빌드한 설정(prepare.sh)과 차 설정(USB 진단 기록 dongle/config.txt)을 견주는 데 쓴다
kconfig_sum() {
  sed -e 's/^CONFIG_CC_STACKPROTECTOR_STRONG=y$/CONFIG_CC_STACKPROTECTOR_REGULAR=y/' "$1" \
    | grep -E '^CONFIG_[A-Za-z0-9_]+=' | LC_ALL=C sort -u | sha256sum | cut -d' ' -f1
}

# 폴더 하나의 값: 모든 파일의 sha256과 경로, 모든 링크의 경로와 대상을 이름 차례로 늘어놓은 것의 sha256.
# 묶음을 푼 결과가 원본과 같은 파일인지(모비스 커널 소스 자산) 확인하는 데 쓴다
tree_sum() {
  ( cd "$1"
    { find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
      find . -type l -printf '%p -> %l\n' | LC_ALL=C sort; } | sha256sum | cut -d' ' -f1 )
}

# make를 돌리되, qemu 에뮬레이션(Apple Silicon 맥)에서 컴파일러·어셈블러·호스트 도구가 Segmentation fault로 멈추면
# 이어서 다시 돌린다(모두 MAKE_TRIES번까지, 기본 8). make는 이어서 하므로 다 된 것은 다시 만들지 않아 결과는 같다.
# 다른 오류는 바로 멈춘다.
# 커널 3.18의 kbuild에는 .DELETE_ON_ERROR가 없어 멈춘 단계가 반쯤 쓴 파일을 남길 수 있다. 다시 돌리기 전에 make가 실패로
# 적은 대상([scripts/Makefile.<무엇>:<줄>: <대상>])을 지운다. 상대 경로는 make를 돈 폴더 기준이다.
#   make_retry <기록 파일> <make를 돈 폴더(-C)> make 인자...
make_retry() {
  _log=$1; _dir=$2; shift 2
  _n=1; _max=${MAKE_TRIES:-8}
  : > "$_log"
  until make -C "$_dir" "$@" > "$_log.try" 2>&1; do
    cat "$_log.try" >> "$_log"
    if [ $_n -lt $_max ] && grep -q -E 'Segmentation fault|internal compiler error' "$_log.try"; then
      echo "컴파일러가 멈춤(에뮬레이션), 이어서 다시 돌림($_n번째 실패, 모두 ${_max}번까지)"
      grep -o -E '\[scripts/Makefile\.[a-z]+:[0-9]+: [^]]+\]' "$_log.try" | sed -E 's/^\[[^ ]+ //; s/\]$//' | while read -r _t; do
        case "$_t" in /*) ;; *) _t=$_dir/$_t ;; esac
        if [ -f "$_t" ]; then rm -f "$_t"; fi
      done
      _n=$((_n+1))
      continue
    fi
    tail -30 "$_log.try"
    return 1
  done
  cat "$_log.try" >> "$_log"
  rm -f "$_log.try"
}

# 컴파일 옵션 확인. 커널은 make마다 컴파일러에 물어(cc-option) 옵션을 정한다. arch/arm/Makefile은 -march=armv7-a가 안 되면
# 조용히 -march=armv5t로 넘어가고, -fno-strict-overflow·-fconserve-stack 같은 옵션도 같은 식으로 붙는다. 에뮬레이션에서는 이
# 물음 중에 컴파일러가 멈춰 다른 옵션으로 컴파일될 수 있다(PR #69 리뷰 14: 실제로 armv5t로 컴파일되어 rev16 어셈블러 오류).
# 그래서 컴파일한 모든 오브젝트(.cmd 첫 줄이 arm-eabi-gcc)의 옵션(-m·-f·-W·-O·-g·-std·-D__LINUX_ARM_ARCH__) 묶음이
#   1. 서로 같고(make를 이어 돌린 사이에 바뀌지 않음) 2. -march=armv7-a이며 armv5t가 없고
#   3. EXPECTED_CFLAGS_SHA256(inputs.sh, CI 값)이 있으면 그 sha256과 같은지(한 번에 끝난 빌드에서 옵션 하나가 모두 똑같이
#      빠진 경우, 리뷰 18) 본다. 그 묶음의 sha256을 CFLAGS_SUM에 둔다
check_cflags() {
  _sets=/tmp/cflags.sets; : > $_sets
  for _c in $(find $1 -name '.*.o.cmd'); do
    head -1 "$_c" | grep -q 'arm-eabi-gcc' || continue
    head -1 "$_c" | tr ' ' '\n' | grep -E '^-(m|f|W|O|g$|std|D__LINUX_ARM_ARCH__)' | grep -v -E '^-Wp,' | LC_ALL=C sort -u | tr '\n' ' ' >> $_sets
    echo >> $_sets
  done
  [ -s $_sets ] || die "컴파일한 오브젝트의 .cmd를 찾지 못함"
  [ "$(LC_ALL=C sort -u $_sets | grep -c .)" = 1 ] \
    || die "오브젝트마다 컴파일 옵션이 다릅니다(에뮬레이션에서 kbuild cc-option 검사가 실패한 것으로 보임). 다시 돌려 주세요"
  grep -q -- '-march=armv7-a ' $_sets && ! grep -q -- 'armv5t' $_sets \
    || die "컴파일 옵션이 -march=armv7-a가 아닙니다(에뮬레이션에서 kbuild cc-option 검사가 실패한 것으로 보임). 다시 돌려 주세요"
  CFLAGS_SUM=$(head -1 $_sets | sha256sum | cut -d' ' -f1)
  echo "컴파일 옵션 확인: 오브젝트 $(grep -c . $_sets)개가 같음, -march=armv7-a ($CFLAGS_SUM)"
  if [ -n "${EXPECTED_CFLAGS_SHA256:-}" ] && [ "$CFLAGS_SUM" != "$EXPECTED_CFLAGS_SHA256" ]; then
    echo "옵션 묶음: $(head -1 $_sets)"
    die "컴파일 옵션 지문이 고정한 값과 다릅니다($CFLAGS_SUM, 고정 $EXPECTED_CFLAGS_SHA256). 에뮬레이션이면 다시 돌리고, 커널 설정·툴체인·드라이버 Makefile을 바꿨으면 CI 값으로 inputs.sh를 고칩니다"
  fi
}
