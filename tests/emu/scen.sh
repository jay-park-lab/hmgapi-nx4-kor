#!/bin/sh
# 에뮬레이터에 NX4 KOR 상태 화면용 가짜 상태 파일을 넣는다(시나리오 하나). adb root가 되어 있어야 한다.
#   sh tests/emu/scen.sh <시나리오>
#   시나리오: ready | connected | installing | reboot | mapfail | oldmod | nocar | nobb | hint
# 차에서는 bin/status.sh(상태), svc/hotspot.sh(진행·알림·힌트)가 쓰는 파일이다. 방법은 docs/emulator-test.md.
B=$(cd "$(dirname "$0")/../.." && pwd)
. "$B/scripts/local-env.sh"
nx4_env "$B"
nx4_need ANDROID_HOME "Android SDK 위치"
ADB=$ANDROID_HOME/platform-tools/adb
S=$1
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
BOOT=$($ADB shell cat /proc/sys/kernel/random/boot_id | tr -d '\r')
NOW=$($ADB shell date +%s | tr -d '\r')
UP=$($ADB shell cat /proc/uptime | tr -d '\r' | cut -d. -f1)
T=/data/local/tmp
base() {
  cat <<E
product=NX4.KOR.0000.V039.001.260902
targetdir=/system/onebin/nx4_kr
pkgver=2.0.0
tested=yes
hmgapi=version 1.1.0-rc.4 build 2026-11-17
applied=yes
oldmod=no
mod_hooks=on
mod_on=yes
bridge=on
hooks=on
hookmap=verified
feat_carplay=yes
feat_aa=yes
feat_wifi=yes
wlan0=yes
softap_strings=4
ssid_len=12
pass_len=10
our_ap=yes
our_dhcp=yes
other_ap=no
stock_ssid=none
ap_mode=ours
stock_seen=no
wpa=no
nowlan=no
made=$(date '+%Y-%m-%d %H:%M')
E
}
verdict() { printf 'verdict=%s\nverdict_lv=%s\nverdict_msg=%s\nverdict_end=%s\ns1=%s\ns2=%s\ns3=%s\n' "$@"; }
prog() { printf 'pct=%s\nstate=%s\nstage=%s\nstart=%s\nt=%s\nboot=%s\nstep=%s\nust=%s\nut=%s\n' "$1" "$2" "$3" $((NOW-120)) $NOW "$BOOT" "$4" $((UP-120)) $UP; }
: > $D/notice; : > $D/hint
case $S in
  ready)
    { base; echo "cp_conn=0"; echo "state=done"; verdict ready 0 "무선 카플레이·안드로이드 오토 준비됨." no "설치: 끝남" "무선 Wi-Fi: 켜짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 done "무선 카플레이·안드로이드 오토 준비됨." "" > $D/prog ;;
  connected)
    { base; echo "cp_conn=1"; echo "state=done"; verdict connected 0 "무선 카플레이 연결됨, 안드로이드 오토 준비됨" no "설치: 끝남" "무선 Wi-Fi: 켜짐" "폰 연결: 카플레이 1대 연결됨"; } > $D/status
    prog 100 done "무선 카플레이·안드로이드 오토 준비됨." "" > $D/prog ;;
  installing)
    { base | sed -e 's/^applied=yes/applied=no/' -e 's/^our_ap=yes/our_ap=no/' -e 's/^our_dhcp=yes/our_dhcp=no/' -e 's/^ap_mode=ours/ap_mode=none/' -e 's/^hooks=on/hooks=off/' -e 's/^hookmap=verified/hookmap=none/'; echo "cp_conn=0"; echo "state=run"
      verdict installing 1 "설치 중입니다. 끝날 때까지 기다려 주세요." no "설치: 진행 중" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 55 run "map을 확인하는 중입니다" 3/5 > $D/prog ;;
  reboot)
    { base | sed -e 's/^our_ap=yes/our_ap=no/' -e 's/^our_dhcp=yes/our_dhcp=no/' -e 's/^ap_mode=ours/ap_mode=none/'; echo "cp_conn=0"; echo "state=reboot"
      verdict reboot 1 "내비를 3분 후 재부팅해 주세요." no "설치: 재부팅 필요" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 reboot "무선 카플레이 설정을 마쳤습니다. 내비를 3분 후 재부팅해 주세요." "" > $D/prog ;;
  mapfail)
    M="이 차의 map을 확인하지 못해 무선 기능을 적용하지 않았습니다. NX4 KOR를 지우고 다시 설치해도 같으면 기록(/data/nx4-kor/logs/ap.log)을 확인해 주세요."
    { base | sed -e 's/^applied=yes/applied=no/' -e 's/^our_ap=yes/our_ap=no/' -e 's/^our_dhcp=yes/our_dhcp=no/' -e 's/^ap_mode=ours/ap_mode=none/' -e 's/^hooks=on/hooks=off/' -e 's/^hookmap=verified/hookmap=mismatch/'; echo "cp_conn=0"; echo "state=fail"
      verdict mapfail 2 "$M" no "설치: 안 됨(위 안내를 보세요)" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 fail "$M" "" > $D/prog ;;
  oldmod)
    M="따로 설치된 무선 모드(wireless-carplay-aa)가 있어 무선 기능을 적용하지 않았습니다. HMG-API 앱에서 그 모드를 지우고 변경 사항을 적용한 뒤 내비를 재부팅해 주세요."
    { base | sed -e 's/^applied=yes/applied=no/' -e 's/^oldmod=no/oldmod=yes/' -e 's/^our_ap=yes/our_ap=no/' -e 's/^our_dhcp=yes/our_dhcp=no/' -e 's/^ap_mode=ours/ap_mode=none/'; echo "cp_conn=0"; echo "state=fail"
      verdict oldmod 2 "$M" no "설치: 안 됨(위 안내를 보세요)" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 fail "$M" "" > $D/prog ;;
  nocar)
    M="지원하지 않는 차입니다(투싼 NX4 한국 내수 260902 전용). 아무것도 바꾸지 않았습니다."
    { base | sed -e 's/^product=.*/product=DEPEHEV.KOR.0000.V039.001.260902/' -e 's/^tested=yes/tested=no/' -e 's/^applied=yes/applied=no/' -e 's/^our_ap=yes/our_ap=no/' -e 's/^our_dhcp=yes/our_dhcp=no/' -e 's/^ap_mode=ours/ap_mode=none/'; echo "cp_conn=0"; echo "state=fail"
      verdict nocar 2 "$M" yes "설치: 안 됨(위 안내를 보세요)" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 fail "$M" "" > $D/prog ;;
  nobb)
    printf 'support=nobb\nproduct=NX4.KOR.0000.V039.001.260902\nplatform=tcc803x\npkgver=2.0.0\nmade=%s\n' "$(date '+%m-%d %H:%M')" > $D/status
    : > $D/prog ;;
  hint)
    { base; echo "cp_conn=0"; echo "state=done"; verdict ready 0 "무선 카플레이·안드로이드 오토 준비됨." no "설치: 끝남" "무선 Wi-Fi: 켜짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 done "무선 카플레이·안드로이드 오토 준비됨." "" > $D/prog
    printf 'boot=%s\niph=wifi\niph_t=%s\naa=cpwait\naa_t=%s\n' "$BOOT" $NOW $NOW > $D/hint
    printf '%s %s %s\n' $NOW "$BOOT" "무선 카플레이 설정을 마쳤습니다. 내비를 3분 후 재부팅해 주세요." > $D/notice ;;
  *) echo "모르는 시나리오: $S" >&2; exit 2 ;;
esac
$ADB shell rm -f $T/nx4-kor-status.txt $T/nx4-kor-progress.txt $T/nx4-kor-notice.txt $T/nx4-kor-hint.txt >/dev/null
$ADB push $D/status $T/nx4-kor-status.txt >/dev/null
[ -s $D/prog ] && $ADB push $D/prog $T/nx4-kor-progress.txt >/dev/null
[ -s $D/notice ] && $ADB push $D/notice $T/nx4-kor-notice.txt >/dev/null
[ -s $D/hint ] && $ADB push $D/hint $T/nx4-kor-hint.txt >/dev/null
$ADB shell chmod 644 $T/nx4-kor-status.txt $T/nx4-kor-progress.txt $T/nx4-kor-notice.txt $T/nx4-kor-hint.txt 2>/dev/null
echo "scenario $S pushed (boot $BOOT)"
