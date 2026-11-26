#!/bin/sh
# 차 커널 설정이 드라이버 빌드의 커널 설정과 같은지 PC에서 본다(#48). USB 진단 기록의 dongle/config.txt(/proc/config.gz를 푼 것)를
# 주면 그 값(lib.sh kconfig_sum)과 inputs.sh의 KCONFIG_SUM을 견준다. 다르면 빌드의 커널 설정을 그 차 것에 맞춰야 한다
# (drivers/README.md "커널 설정").
#   sh drivers/config-sum.sh <config.txt>
set -eu
[ $# = 1 ] && [ -f "$1" ] || { echo "쓰는 법: sh drivers/config-sum.sh <config.txt>"; exit 1; }
H=$(cd "$(dirname "$0")" && pwd)
. "$H/inputs.sh"
. "$H/lib.sh"
GOT=$(kconfig_sum "$1")
if [ "$GOT" = "$KCONFIG_SUM" ]; then
  echo "같음: $GOT"
else
  echo "다름: $GOT (빌드 $KCONFIG_SUM)"
  exit 3
fi
