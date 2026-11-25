#!/bin/sh
# 시나리오를 넣고 관리 앱을 새로 연 뒤 화면을 찍는다: sh tests/emu/shot.sh <시나리오>
# 결과: out/emu/<시나리오>.png (OUT으로 바꿀 수 있다). 방법은 docs/emulator-test.md.
E=$(cd "$(dirname "$0")" && pwd)
B=$(cd "$E/../.." && pwd)
. "$B/scripts/local-env.sh"
nx4_env "$B"
nx4_need ANDROID_HOME "Android SDK 위치"
ADB=$ANDROID_HOME/platform-tools/adb
OUT=${OUT:-$B/out/emu}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
sh "$E/scen.sh" "$1" >/dev/null || exit 1
$ADB shell am force-stop io.github.jayparklab.nx4kor
$ADB shell am start -W -n io.github.jayparklab.nx4kor/.StatusActivity >/dev/null
# 앱이 상태 파일을 읽고 그릴 때까지 기다린다(바로 찍으면 런처가 찍힌다)
sleep 2
$ADB exec-out screencap -p > "$OUT/$1.png"
echo "$OUT/$1.png"
