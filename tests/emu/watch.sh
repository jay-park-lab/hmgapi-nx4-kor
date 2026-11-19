#!/bin/sh
# [지금 재부팅] 시험용으로 root 감시자(bin/status.sh --watch)를 흉내 낸다. adb root가 되어 있어야 한다.
#   sh tests/emu/watch.sh off           감시자 파일·재부팅 결과·앱의 요청 기록을 지운다(감시자 없음)
#   sh tests/emu/watch.sh on            감시자 파일(boot, until=지금+600초)을 쓴다
#   sh tests/emu/watch.sh answer <code> 앱이 쓴 reboot.req의 id로 재부팅 결과를 쓴다
#                                       code: install·fix·sysw·old·bad·guard·cmd (앱의 Report.rbAnswer 참고)
# 방법은 docs/emulator-test.md.
B=$(cd "$(dirname "$0")/../.." && pwd)
. "$B/scripts/local-env.sh"
nx4_env "$B"
nx4_need ANDROID_HOME "Android SDK 위치"
ADB=$ANDROID_HOME/platform-tools/adb
T=/data/local/tmp
APPF=/data/data/io.github.jayparklab.nx4kor/files
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
BOOT=$($ADB shell cat /proc/sys/kernel/random/boot_id | tr -d '\r')
UP=$($ADB shell cat /proc/uptime | tr -d '\r' | cut -d. -f1)
case $1 in
  off)
    $ADB shell rm -f $T/nx4-kor-watch.txt $T/nx4-kor-reboot-result.txt $APPF/reboot.req $APPF/reboot-stuck.txt
    echo "watch off" ;;
  on)
    printf 'boot=%s\nuntil=%s\n' "$BOOT" $((UP+600)) > $D/w
    $ADB push $D/w $T/nx4-kor-watch.txt >/dev/null
    $ADB shell chmod 644 $T/nx4-kor-watch.txt
    echo "watch on: until $((UP+600)) (now $UP)" ;;
  answer)
    [ -n "$2" ] || { echo "code를 주세요: install fix sysw old bad guard cmd" >&2; exit 2; }
    REQ=$($ADB shell cat $APPF/reboot.req 2>/dev/null | tr -d '\r')
    [ -n "$REQ" ] || { echo "앱의 재부팅 요청(reboot.req)이 없습니다. [지금 재부팅] → [재부팅]을 먼저 누르세요." >&2; exit 1; }
    ID=$(echo "$REQ" | cut -d' ' -f1)
    echo "req: $REQ"
    printf 'id=%s\nboot=%s\ncode=%s\n' "$ID" "$BOOT" "$2" > $D/r
    $ADB push $D/r $T/nx4-kor-reboot-result.txt >/dev/null
    $ADB shell chmod 644 $T/nx4-kor-reboot-result.txt
    echo "answer $2 for id $ID" ;;
  *) echo "sh watch.sh off | on | answer <code>" >&2; exit 2 ;;
esac
