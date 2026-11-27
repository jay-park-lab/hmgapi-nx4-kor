#!/bin/sh
# 차 커널 설정이 드라이버 빌드의 커널 설정과 같은지 PC에서 본다(#48). USB 진단 기록의 dongle/config.txt(/proc/config.gz를 푼 것)를
# 주면 그 값(lib.sh kconfig_sum)과 inputs.sh의 KCONFIG_SUM을 견준다. 다르면 빌드의 커널 설정을 그 차 것에 맞춰야 한다
# (drivers/README.md "커널 준비").
#   sh drivers/config-sum.sh <config.txt>
# 결과: 같음 0, 다름 3, 값을 세지 못함 1
set -eu
[ $# = 1 ] && [ -f "$1" ] || { echo "쓰는 법: sh drivers/config-sum.sh <config.txt>"; exit 1; }
grep -q '^CONFIG_[A-Za-z0-9_]*=' "$1" || { echo "커널 설정 파일이 아닙니다(값이 있는 CONFIG_ 줄이 없음): $1"; exit 1; }
H=$(cd "$(dirname "$0")" && pwd)
. "$H/inputs.sh"
. "$H/lib.sh"
# sha256sum이 없는 PC(macOS 14 이전 등)는 shasum -a 256으로 센다. 둘 다 없으면 멈춘다(빈 값을 "다름"으로 보이지 않게, PR #69 리뷰 22)
if ! command -v sha256sum >/dev/null 2>&1; then
  if command -v shasum >/dev/null 2>&1; then
    sha256sum() { shasum -a 256 "$@"; }
  else
    echo "sha256sum도 shasum도 없어 값을 세지 못합니다"
    exit 1
  fi
fi
GOT=$(kconfig_sum "$1")
echo "$GOT" | grep -qx '[0-9a-f]\{64\}' || { echo "값을 세지 못했습니다(${GOT:-빈 값})"; exit 1; }
if [ "$GOT" = "$KCONFIG_SUM" ]; then
  echo "같음: $GOT"
else
  echo "다름: $GOT (빌드 $KCONFIG_SUM)"
  exit 3
fi
