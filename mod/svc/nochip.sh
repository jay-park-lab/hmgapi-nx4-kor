#!/system/bin/sh
# HMG-API 서비스 "nochip"(mod.json, start=boot, restart=false). Wi-Fi 칩이 없는 차(2026-11-23·26 NX4HEV 260902)에서
# HMG-API Wi-Fi 지기가 부팅 내내 프로젝션 AP를 다시 띄우려는 것을 멈춘다(순정 시스템 부하).
# 근거: HMG-API rc.10 engine/HomeWifi.java(서비스 "hmgapi wifi"의 스크립트)
#   - ap_keep: wifi/ap.boot에 이번 부팅 id가 있으면 시도하지 않는다. 없으면 약 2초마다 30번, 그 뒤 부팅이 끝날 때까지 30초마다
#     다시 시도하고, 시도마다 app_process(Dalvik)를 하나 띄운다(tool ensure-projection).
#   - woke: QuickBoot에서 깨어난 것을 알면(잠든 시간이 1분 넘음) ap.boot·ap.fail을 지우고 처음부터 다시 시도한다.
# 하는 일
#   1. 순정 Wi-Fi 드라이버의 결과를 기다린다(부팅 뒤 약 20초. NX4_NOCHIP_POLL초마다, 부팅 뒤 NX4_NOCHIP_MAX초까지).
#      칩·wlan0·USB Wi-Fi 동글이 보이면(lib.sh chip_or_dongle) 바로, 끝까지 포기한 줄이 없으면 그때 그냥 끝낸다.
#      포기한 줄이 있어도 부팅 뒤 NX4_NOCHIP_SETTLE(50)초까지는 기다린다: 동글을 꽂은 부팅에도 순정 드라이버가 먼저 올라 그
#      줄을 남기므로(#80) 동글이 USB에 올라올 틈을 둔다. 이 차는 부팅 약 40초에 앞쪽 USB 포트 전원을 껐다 켜고(dwc_otg_vbus_set
#      OFF→ON), 꽂힌 장치는 43~44초에야 다시 보인다(11-26 진단 기록 4개, #48 동글 세션). 그 틈에 보면 꽂힌 동글을 못 본다.
#   2. 이번 부팅에 칩이 없다고 볼 때(lib.sh nochip_now), 순정 핫스팟 기능 권한 파일이 있고 프로젝션 AP를 요청한 모드가 있을
#      때만 이번 부팅 id를 이 모드의 기록(NOCHIP, 관리 앱 판정·진단용)과 HMG-API의 ap.boot에 쓴다. 칩이 없으면 그 부팅의
#      시도는 어차피 실패한다(순정 드라이버를 다시 올리지 않음).
#   3. 그 뒤 wifi 폴더에서 파일이 지워질 때만 깨어나는 inotifyd(함께 넣은 busybox)를 띄워 두고, 지기가 깨어남에 ap.boot를
#      지우면 다시 쓴다. 주기적으로 깨지 않는다. 그때 칩·wlan0·동글이 보이면(나중에 꽂은 동글을 켜려고 ap.boot를 지운 경우 등)
#      다시 쓰지 않고 이 모드의 기록을 지운 뒤 inotifyd를 멈추고 끝낸다(물러남). 안 보여도 NX4_NOCHIP_RECHECK(5)초 뒤 한 번 더
#      본다(포트 전원을 껐다 켜는 4초쯤에는 꽂힌 동글이 안 보임). 그 사이 지기의 시도는 두어 번이다.
#      차량 서비스(car_events "wake")를 쓰지 않는 것은 그것이 HMG-API 차량 서비스(상주 Dalvik)를 새로 띄우기 때문이다
#      (ModRuntime). inotifyd가 없는 busybox면 2까지만 한다.
# 이 모드를 끄거나 지우면 hmgapid가 이 서비스의 프로세스 묶음(setsid)을 함께 내린다. 줄은 hmgapid 서비스 기록
# (logs/nx4-kor/nochip.log, USB 진단 logs/service/)에 남는다.
. ${NX4_APP:-${HMGAPI_MOD_DIR:-/data/hmgapi/mods/nx4-kor}}/svc/env.sh
. $NX4_APP/svc/lib.sh
NOCHIP_MAX=${NX4_NOCHIP_MAX:-120}
NOCHIP_POLL=${NX4_NOCHIP_POLL:-5}
NOCHIP_SETTLE=${NX4_NOCHIP_SETTLE:-50}
NOCHIP_RECHECK=${NX4_NOCHIP_RECHECK:-5}

# 이번 부팅 id를 파일($1)에 쓴다(같은 폴더의 임시 파일에 쓴 뒤 바꿈: 지기가 반쯤 쓴 파일을 읽지 않게). 이미 이번 부팅 것이면 그대로
put_boot() {
  this_boot "$1" && return 0
  _pb=$(boot_id)
  [ -n "$_pb" ] || return 1
  echo "$_pb" 2>/dev/null > "$1.nx4" && $BB mv -f "$1.nx4" "$1" 2>/dev/null
}
# 1. 드라이버의 결과를 기다린다. 칩 없음이면 0
wait_driver() {
  _wi=0
  while [ $_wi -le $((NOCHIP_MAX / NOCHIP_POLL + 1)) ]; do
    if chip_or_dongle; then echo "NX4 KOR: Wi-Fi 칩이나 USB Wi-Fi 동글이 있음: 할 일 없음"; return 1; fi
    boot_secs
    if dhd_gave_up && { [ -z "$_U" ] || [ "$_U" -ge $NOCHIP_SETTLE ]; }; then
      # 정하기 전에 NX4_NOCHIP_RECHECK초 뒤 한 번 더 본다: 포트 전원을 껐다 켜는 때가 늦은 부팅에 밀려 그 틈(약 4초)에
      # 걸렸으면 꽂힌 동글이 안 보인다(깨어날 때와 같음, PR #86 리뷰 7)
      sleep $NOCHIP_RECHECK
      if chip_or_dongle; then echo "NX4 KOR: Wi-Fi 칩이나 USB Wi-Fi 동글이 있음: 할 일 없음"; return 1; fi
      return 0
    fi
    [ -n "$_U" ] && [ "$_U" -ge $NOCHIP_MAX ] && break
    sleep $NOCHIP_POLL
    _wi=$((_wi+1))
  done
  echo "NX4 KOR: 부팅 뒤 ${_U:-?}초까지 순정 Wi-Fi 드라이버가 칩을 포기한 줄이 없음: 할 일 없음"
  return 1
}
# 2. 이 모드의 기록과 HMG-API의 ap.boot에 이번 부팅 id를 쓴다
mark() {
  [ -f $HOTSPOT_XML ] || { echo "NX4 KOR: 칩이 없어 보이지만 순정 핫스팟 기능 권한 파일이 없음: 할 일 없음"; return 1; }
  proj_asked || { echo "NX4 KOR: 칩이 없어 보이지만 프로젝션 AP를 요청한 모드가 없음: 할 일 없음"; return 1; }
  ( umask 022; put_boot $NOCHIP ) || { echo "NX4 KOR: 칩 없음 기록($NOCHIP)을 쓰지 못함"; return 1; }
  ( umask 077; mkdir -p $HMGWIFI 2>/dev/null; put_boot $HMGWIFI/ap.boot ) || { echo "NX4 KOR: $HMGWIFI/ap.boot를 쓰지 못함"; return 1; }
  return 0
}
# 3. 지기가 ap.boot를 지우면(깨어남) 다시 쓴다. inotifyd는 "d<TAB>폴더<TAB>파일" 줄을 FIFO로 내고(- : 표준출력), 이 셸은 그것을
# 읽는다. FIFO로 받는 것은 물러날 때 inotifyd를 멈추려고(파이프라인이면 pid를 모름)
watch_wake() {
  # inotifyd: 고른 busybox(내비의 것이 있으면 그것)에 없으면 함께 넣은 busybox(1.36.1)의 것(PR #86 리뷰 3)
  IBB=
  for _ib in $BB $BB_OWN; do
    [ -x "$_ib" ] || continue
    "$_ib" --list 2>/dev/null | $BB grep -qx inotifyd && { IBB=$_ib; break; }
  done
  if [ -z "$IBB" ]; then
    echo "NX4 KOR: busybox에 inotifyd가 없어 QuickBoot에서 깨어난 뒤에는 지키지 않음"
    return 0
  fi
  _fifo=$W/nochip.fifo
  ( umask 077; mkdir -p $W 2>/dev/null; rm -f $_fifo; $BB mkfifo $_fifo 2>/dev/null ) || { echo "NX4 KOR: ${_fifo}를 만들지 못해 깨어난 뒤에는 지키지 않음"; return 0; }
  $IBB inotifyd - $HMGWIFI:d > $_fifo 2>/dev/null &
  _ip=$!
  while read -r _we _wd _wf; do
    [ "$_wf" = ap.boot ] || continue
    chip_or_dongle || sleep $NOCHIP_RECHECK
    if chip_or_dongle; then
      rm -f $NOCHIP
      log_ts; echo "$_LT NX4 KOR: Wi-Fi 칩이나 USB Wi-Fi 동글이 보여 물러남(ap.boot를 다시 쓰지 않고 칩 없음 기록을 지움)"
      break
    fi
    this_boot $NOCHIP || { log_ts; echo "$_LT NX4 KOR: 칩 없음 기록이 없어져 물러남"; break; }
    if ( umask 077; put_boot $HMGWIFI/ap.boot ); then
      log_ts; echo "$_LT NX4 KOR: HMG-API가 ap.boot를 지움(QuickBoot에서 깨어남): 다시 씀"
    fi
  done < $_fifo
  kill $_ip 2>/dev/null
  rm -f $_fifo
  echo "NX4 KOR: wifi 폴더 보기를 마침"
}

if wait_driver && mark; then
  echo "NX4 KOR: Wi-Fi 칩 없음(순정 드라이버가 이번 부팅에 칩 켜기를 포기함): HMG-API의 프로젝션 AP 다시 시도를 이번 부팅에 멈춤"
  watch_wake
fi
exit 0
