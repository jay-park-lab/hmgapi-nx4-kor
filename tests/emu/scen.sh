#!/bin/sh
# 에뮬레이터에 NX4 KOR 관리 앱용 가짜 상태 파일을 넣는다(시나리오 하나). adb root가 되어 있어야 한다.
#   sh tests/emu/scen.sh <시나리오>
#   시나리오: ready | connected | installing | reboot | failed | nowireless | nowifipart | dongleoff | nocar | nobb | hint | bootguard | bootguard2
# 차에서는 bin/status.sh(상태), USB 설치기(진행·알림)가 쓰는 파일이다. 힌트는 2.0.x 서비스가 쓰던 것(2.1.0에는 쓰는 곳 없음, 앱은 그대로 읽음).
# 방법은 docs/emulator-test.md.
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
hmgapi=version 1.1.0-rc.10 build 2026-11-25
wm=yes
wm_ver=2.2.0-rc.9
wm_on=yes
wm_hooks=on
bridge=on
hooks=on
hookmap=verified
kor_hooks=on
kor_hooks_why=
kor_tbt=on
kor_tbt_log=off
feat_carplay=yes
feat_aa=yes
feat_hotspot=yes
feat_wifi=yes
chip=yes
wlan0=yes
proj=yes
ap_boot=yes
ap_fail=no
ap=yes
ap_mode=projection
other_ap=no
wpa=no
made=$(date '+%Y-%m-%d %H:%M')
E
}
# 무선 연결용 Wi-Fi(프로젝션 AP)가 꺼진 꼴
noap() { sed -e 's/^ap=yes/ap=no/' -e 's/^ap_mode=projection/ap_mode=none/'; }
# HMG-API 부팅 보호로 이번 시작의 훅이 꺼진 꼴: 이번 부팅에 무선 연결용 Wi-Fi를 띄우지 않음(ap·ap_boot는 가정).
# hooks·wm_hooks·kor_hooks는 base 그대로(on) 둔다(kor_hooks는 #71). status.sh(hmg_hooks_load)는 이 셋을 HMG-API 기록의 마지막 "hook map: …, hooks on|off"와
# "mods: loaded <id>" 줄에서 읽는데, 이 줄은 훅 런타임이 쓰고 부팅 보호로 꺼진 시작에는 훅 런타임이 올라오지 않는다. 그래서 앞
# 시작이 남긴 켜짐 기록이 그대로 남을 것으로 본다(HMG-API rc.8 소스로 추론, PR #58 리뷰 1). 판정("훅 꺼짐")과 자세히 표의 훅 줄
# ("켜짐")이 엇갈려 보이는 것은 그 때문이다. 차의 값은 docs/design.md "차에서 확인할 것"
guard() { noap | sed -e 's/^ap_boot=yes/ap_boot=no/'; }
verdict() { printf 'verdict=%s\nverdict_lv=%s\nverdict_msg=%s\nverdict_end=%s\ns1=%s\ns2=%s\ns3=%s\n' "$@"; }
prog() { printf 'pct=%s\nstate=%s\nstage=%s\nstart=%s\nt=%s\nboot=%s\nstep=%s\nust=%s\nut=%s\n' "$1" "$2" "$3" $((NOW-120)) $NOW "$BOOT" "$4" $((UP-120)) $UP; }
: > $D/notice; : > $D/hint
case $S in
  ready)
    { base; echo "cp_conn=0"; echo "state=done"; verdict ready 0 "무선 카플레이·안드로이드 오토 준비됨." no "설치: 끝남" "무선 Wi-Fi: 켜짐(HMG-API)" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 done "무선 카플레이·안드로이드 오토 준비됨." "" > $D/prog ;;
  connected)
    { base; echo "cp_conn=1"; echo "state=done"; verdict connected 0 "무선 카플레이 연결됨" no "설치: 끝남" "무선 Wi-Fi: 켜짐(HMG-API)" "폰 연결: 카플레이 1대 연결됨"; } > $D/status
    prog 100 done "무선 카플레이·안드로이드 오토 준비됨." "" > $D/prog ;;
  installing)
    { base | noap | sed -e 's/^hooks=on/hooks=off/' -e 's/^hookmap=verified/hookmap=none/'; echo "cp_conn=0"; echo "state=run"
      verdict installing 1 "설치 중입니다. 끝날 때까지 기다려 주세요." no "설치: 진행 중" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 55 run "map을 확인하는 중입니다" 3/5 > $D/prog ;;
  reboot)
    { base | noap; echo "cp_conn=0"; echo "state=reboot"
      verdict reboot 1 "[지금 재부팅]을 눌러 내비를 재부팅해 주세요." no "설치: 재부팅 필요" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 reboot "무선 카플레이 설정을 마쳤습니다. [지금 재부팅]을 눌러 내비를 재부팅해 주세요." "" > $D/prog ;;
  failed)
    M="이 차의 map을 확인하지 못했습니다. USB의 NX4/install.log를 확인해 주세요."
    { base | noap | sed -e 's/^hooks=on/hooks=off/' -e 's/^hookmap=verified/hookmap=mismatch/'; echo "cp_conn=0"; echo "state=fail"
      verdict failed 2 "$M" no "설치: 안 됨(오른쪽 안내를 보세요)" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 fail "$M" "" > $D/prog ;;
  nowireless)
    M="공식 무선 모드(Wireless CarPlay + Android Auto)가 설치되어 있지 않습니다. NX4 KOR USB 설치기로 다시 설치해 주세요."
    { base | noap | sed -e 's/^wm=yes/wm=no/' -e 's/^wm_ver=.*/wm_ver=/' -e 's/^wm_on=yes/wm_on=no/' -e 's/^wm_hooks=on/wm_hooks=/'; echo "cp_conn=0"; echo "state=done"
      verdict nowireless 2 "$M" no "설치: 안 됨(오른쪽 안내를 보세요)" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 done "설치를 마쳤습니다." "" > $D/prog ;;
  nowifipart)
    M="이 차의 내비에는 Wi-Fi 부품이 없는 것으로 보여 무선 카플레이·안드로이드 오토를 쓸 수 없습니다. 유선 연결과 계기판 길안내는 그대로 쓸 수 있습니다."
    { base | noap | sed -e 's/^chip=yes/chip=no/' -e 's/^wlan0=yes/wlan0=no/' -e 's/^ap_boot=yes/ap_boot=no/' -e 's/^ap_fail=no/ap_fail=yes/'; echo "cp_conn=0"; echo "state=done"
      verdict nowifipart 1 "$M" no "설치: 끝남" "무선 Wi-Fi: 부품 없음(USB 동글 필요)" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 done "설치를 마쳤습니다." "" > $D/prog ;;
  dongleoff)
    # 칩이 없는 내비에 부팅 뒤 USB Wi-Fi 동글을 꽂았고 아직 켜지 않음(#60): [동글 켜기] 버튼과 표의 "USB Wi-Fi 동글" 줄
    M="USB Wi-Fi 동글이 꽂혀 있지만 아직 켜지 않았습니다. 오른쪽 아래 [동글 켜기]를 눌러 주세요."
    { base | noap | sed -e 's/^chip=yes/chip=no/' -e 's/^wlan0=yes/wlan0=no/' -e 's/^ap_boot=yes/ap_boot=no/'; echo "cp_conn=0"; echo "state=done"
      echo "dongle_drivers=yes"; echo "dongle=0bda:b831 rtl8831bu"; echo "dongle_on=none"; echo "dongle_btn=yes"
      verdict dongleoff 1 "$M" no "설치: 끝남" "무선 Wi-Fi: 동글 꽂힘(켜기 전)" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 done "설치를 마쳤습니다." "" > $D/prog ;;
  nocar)
    M="지원하지 않는 차입니다(투싼 NX4 한국 내수 260902 전용). 아무것도 바꾸지 않았습니다."
    { base | noap | sed -e 's/^product=.*/product=DEPEHEV.KOR.0000.V039.001.260902/' -e 's/^tested=yes/tested=no/'; echo "cp_conn=0"; echo "state=fail"
      verdict nocar 2 "$M" yes "설치: 안 됨(오른쪽 안내를 보세요)" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 fail "$M" "" > $D/prog ;;
  nobb)
    printf 'support=nobb\nproduct=NX4.KOR.0000.V039.001.260902\nplatform=tcc803x\npkgver=2.0.0\nmade=%s\n' "$(date '+%m-%d %H:%M')" > $D/status
    : > $D/prog ;;
  hint)
    { base; echo "cp_conn=0"; echo "state=done"; verdict ready 0 "무선 카플레이·안드로이드 오토 준비됨." no "설치: 끝남" "무선 Wi-Fi: 켜짐(HMG-API)" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 done "무선 카플레이·안드로이드 오토 준비됨." "" > $D/prog
    printf 'boot=%s\niph=wifi\niph_t=%s\naa=cpwait\naa_t=%s\n' "$BOOT" $NOW $NOW > $D/hint
    printf '%s %s %s\n' $NOW "$BOOT" "무선 카플레이 설정을 마쳤습니다. [지금 재부팅]을 눌러 내비를 재부팅해 주세요." > $D/notice ;;
  bootguard)
    # 수준 1: starts가 6보다 작아 재부팅만으로 훅이 다시 켜짐(status.sh st_verdict)
    M="HMG-API가 이번 부팅에만 무선 기능을 껐습니다(부팅 보호). 내비를 재부팅하고 3분 넘게 켜 두세요. 또 생기면 마지막으로 넣거나 바꾼 모드를 HMG-API 앱에서 꺼 주세요."
    { base | guard; echo "cp_conn=0"; echo "state=done"
      verdict bootguard 1 "$M" no "설치: HMG-API 훅 꺼짐(부팅 보호)" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 done "설치를 마쳤습니다." "" > $D/prog ;;
  bootguard2)
    # 수준 2: starts가 6 이상(또는 못 읽음)이라 다음 시작도 꺼짐 → HMG-API를 다시 설치
    M="HMG-API가 재부팅이 너무 잦은 것으로 보고 무선 기능을 껐습니다. HMG-API를 지우지 말고 HMG-API USB로 다시 설치(업데이트)한 뒤 재부팅하고, 3분 넘게 켜 두세요."
    { base | guard; echo "cp_conn=0"; echo "state=done"
      verdict bootguard 2 "$M" no "설치: HMG-API 훅 꺼짐(부팅 보호)" "무선 Wi-Fi: 꺼짐" "폰 연결: 지금 연결된 폰 없음"; } > $D/status
    prog 100 done "설치를 마쳤습니다." "" > $D/prog ;;
  *) echo "모르는 시나리오: $S" >&2; exit 2 ;;
esac
$ADB shell rm -f $T/nx4-kor-status.txt $T/nx4-kor-progress.txt $T/nx4-kor-notice.txt $T/nx4-kor-hint.txt >/dev/null
$ADB push $D/status $T/nx4-kor-status.txt >/dev/null
[ -s $D/prog ] && $ADB push $D/prog $T/nx4-kor-progress.txt >/dev/null
[ -s $D/notice ] && $ADB push $D/notice $T/nx4-kor-notice.txt >/dev/null
[ -s $D/hint ] && $ADB push $D/hint $T/nx4-kor-hint.txt >/dev/null
$ADB shell chmod 644 $T/nx4-kor-status.txt $T/nx4-kor-progress.txt $T/nx4-kor-notice.txt $T/nx4-kor-hint.txt 2>/dev/null
echo "scenario $S pushed (boot $BOOT)"
