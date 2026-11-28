#!/system/bin/sh
# HMG-API 서비스 "dongle"(mod.json, start=boot, restart=false, root). USB Wi-Fi 동글(#48)의 드라이버를 순정 자리에 건다(#80 결정).
# 부팅 때 아래 1~5를 한 번 하고(기다림은 모두 부팅 뒤 시각과 횟수의 상한이 있음), 그 뒤 6처럼 다시 붙는 동글을 지켜본다.
#   1. Wi-Fi 칩이 있는 내비(lib.sh wifi_chip_seen)이거나 이 묶음에 동글 드라이버가 없으면 아무것도 하지 않는다.
#   2. 꽂힌 USB 장치에서 우리 드라이버가 받는 동글을 찾는다(lib.sh dongle_find, drivers/usb-ids.txt). 부팅 뒤
#      NX4_DONGLE_FIND초까지 NX4_DONGLE_POLL초마다 본다. 차의 데이터 포트 장치는 부팅 뒤 11.5~12초에 처음 보인다(11-26·27 진단
#      기록 5개, PR #99 리뷰 1). 동글이 없으면 6으로 간다(나중에 꽂으면 6이 켬. 관리 앱 [동글 켜기]도 그대로, #60).
#   3. 맞는 .ko를 /system/wifi/bcmdhd.ko 위에 bind mount한다(lib.sh ko_mount). 루트 이름공간의 /system이 shared라
#      system_server(HAL) 쪽에도 보인다(#80). 이번 부팅에 건 것을 DONGLE 기록에 한 줄 남긴다(부팅마다 한 번 씀).
#   4. 순정 HAL은 동글이 보이기 전(약 9.8초)에 순정 bcmdhd를 올리고, 그 모듈은 18초까지 칩을 찾다 포기한 채 남는다. HAL은 그 모듈이
#      올라 있다고 보고 다시 올리지 않으므로(11-26 진단: 그 줄은 부팅 때 한 번뿐), 순정(또는 이 모드의 다른 드라이버)이 올라 있으면
#      칩 찾기가 끝난 뒤(initstate live, NX4_DONGLE_LIVE초까지) rmmod한다. 그러면 다음 Wi-Fi 요청(HMG-API 지기는 처음 1분 동안
#      2초마다)에 HAL이 이 자리의 우리 것을 올린다. 내리기 전에 칩을 다시 본다: 칩이 있는 내비라도 HMG-API 표시 파일이 아직 없으면
#      1에서 빠지지 않고 SDIO 칩은 약 10초에야 보이므로, 그때 칩이 보이면 내리지 않고 건 것도 푼다. 순정은 이번 부팅에 칩 켜기를
#      포기한 줄(lib.sh dhd_gave_up)이 있을 때만 내린다(PR #99 리뷰 8).
#   5. 순정은 호스트 세션마다 USB 포트 전원을 한 번 껐다 켠다(꽂은 채 부팅 약 40초, 다시 붙기까지 3.4~3.8초, #48 차 기록).
#      그때 동글이 떨어졌다 다시 붙어 wlan0이 새로 생기는데, AP는 꺼진 채로 남을 수 있다(Android는 AP가 켜져 있다고 보고
#      HMG-API 지기는 이번 부팅에 띄웠다고 적어 둠, HMG-API #386). 동글의 장치 번호가 바뀔 때까지(부팅 뒤 NX4_DONGLE_SETTLE초까지)
#      기다리고, wlan0을 NX4_DONGLE_WLAN초, AP를 NX4_DONGLE_AP초 기다린 뒤:
#      - wlan0이 올라와 있고 hostapd가 돌면 그대로 둔다.
#      - 아니면 HMG-API 지기의 기록(wifi/ap.boot)과 상관없이 AP를 한 번 껐다 켠다(hooks.jar의 ApTool, Android Wi-Fi 서비스로.
#        차의 Wi-Fi 클라이언트가 켜져 있거나 되살릴 것이면 두고 끝냄). wlan0이 생기지 않았어도 한다: 껐다 켜면 HAL이 이 자리의
#        드라이버를 올린다. 지기에 맡기고 끝내면 지기가 AP를 이미 켜진 것으로 보고 손대지 않는 일이 있었다(#107, HMG-API #386).
#        껐다 켜지 못했거나 NX4_DONGLE_AP초 뒤에도 AP가 없으면 ap.boot·ap.fail을 지워 지기가 다시 시도하게 한다(PR #99 리뷰 4).
#      프로젝션 AP를 요청한 모드가 없으면 5는 하지 않는다.
#      동글로 AP를 띄웠으면 이번 부팅의 칩 없음 기록(nochip.sh)을 지운다: 관리 앱이 "Wi-Fi 부품 없음"이 아니라 실제 AP를 보게.
#   6. 다시 붙는 동글 지켜보기(#107): NX4_DONGLE_WATCH초(기본 5)마다 USB 장치 목록(이름과 장치 번호)만 셸 안에서 읽는다(외부 명령을
#      띄우지 않음). 목록이 바뀌고 우리 드라이버가 받는 동글이 새로 보이거나 장치 번호가 바뀌었으면(뺐다 꽂음, 포트 전원 껐다 켬,
#      QuickBoot에서 깨어남) 아래 --auto로 [동글 켜기]와 같은 일을 한다. 순정 포트가 유선 카플레이로 장치 모드가 되면 버스가
#      사라지는데, 그때는 동글이 보이지 않으니 하지 않는다. Wi-Fi 칩이 있는 내비, 동글 드라이버가 없는 묶음, 다른 것이 자리에 걸린
#      경우에는 지켜보지 않는다. 지켜보는 동안에는 dongle.pid를 쥐지 않아 [동글 켜기]를 막지 않는다.
# --now <요청 id>: 관리 앱 [동글 켜기](#60). 감시자(bin/status.sh --watch)가 요청을 받아 부른다. 부팅 뒤 꽂은 동글에 위 2~5를
#   한 번 하되 다음이 다르다.
#   - 찾기는 지금부터 NX4_DONGLE_NOWFIND초. 포트 끄고 켜기는 그 장치가 붙은 지(커널 줄 시각) NX4_DONGLE_NOWSETTLE초가 안 됐을 때만
#     기다린다(부팅 뒤 꽂으면 약 8초 뒤 순정이 껐다 켬).
#   - AP가 떠 있지 않으면 HMG-API 지기의 기록과 상관없이 ApTool로 한 번 껐다 켠다(그때 HAL이 우리 드라이버를 올림).
#   - 누르기 전·뒤를 $W/dongle-before.txt·dongle-after.txt에(lib.sh dongle_snap), 결과를 ${DGRES}에(관리 앱이 읽음) 쓴다.
#     결과를 쓰기 바로 앞에 상태 파일을 새로 쓴다(bin/status.sh): 관리 앱이 결과와 같은 때의 AP로 판정 띠를 그리게(#111).
#   부팅 서비스가 아직 돌고 있으면(같은 부팅의 dongle.pid) 하지 않고 busy로 답한다.
# --auto: 6이 부른다. --now와 같되 결과 파일·누르기 전·뒤 기록은 쓰지 않는다(그것은 [동글 켜기]의 것). 다른 동글 작업이 돌면 하지 않는다.
# 이 모드를 끄거나 지우면 hmgapid가 이 서비스의 프로세스 묶음을 내린다. 건 mount는 재부팅하면 풀린다(지울 때는 preun.sh가 푼다).
# 줄은 hmgapid 서비스 기록(logs/nx4-kor/dongle.log, USB 진단 logs/service/)에 남는다.
. ${NX4_APP:-${HMGAPI_MOD_DIR:-/data/hmgapi/mods/nx4-kor}}/svc/env.sh
. $NX4_APP/svc/lib.sh
FIND=${NX4_DONGLE_FIND:-30}
POLL=${NX4_DONGLE_POLL:-1}
LIVE=${NX4_DONGLE_LIVE:-30}
SETTLE=${NX4_DONGLE_SETTLE:-75}
SPOLL=${NX4_DONGLE_SPOLL:-2}
WLWAIT=${NX4_DONGLE_WLAN:-20}
APWAIT=${NX4_DONGLE_AP:-30}
# 부팅 뒤 초를 못 읽거나 멈춰 있어도 끝나도록 두 기다림에 횟수 상한도 둔다(기본은 시각 상한과 같은 길이, nochip.sh와 같은 방식)
FTRIES=${NX4_DONGLE_FTRIES:-$((FIND / POLL + 2))}
STRIES=${NX4_DONGLE_STRIES:-$((SETTLE / SPOLL + 2))}
# AP를 껐다 켜는 도구(hooks.jar의 io.github.jayparklab.nx4kor.hook.ApTool). PC 테스트는 NX4_APTOOL로 바꾼다
aptool() {
  if [ -n "$NX4_APTOOL" ]; then $NX4_APTOOL "$@"
  else CLASSPATH=$NX4_APP/hooks.jar app_process /system/bin io.github.jayparklab.nx4kor.hook.ApTool "$@"; fi
}
WATCH=${NX4_DONGLE_WATCH:-5}
say() { log_ts; echo "$_LT NX4 KOR 동글: $*"; }
NOW=; RQ=; AUTO=; QUICK=
if [ "$1" = --now ]; then
  NOW=1; QUICK=1; RQ=$2
  case "$RQ" in ''|*[!0-9]*) say "[동글 켜기] 요청 id가 없음: 하지 않음"; exit 0 ;; esac
elif [ "$1" = --auto ]; then
  AUTO=1; QUICK=1
fi
V0= N0=
# 6. 다시 붙는 동글 지켜보기. 목록은 셸 안에서만 읽는다(글롭·read): 5초마다 외부 명령을 띄우지 않게. 바뀌었을 때만 dongle_find
usb_sig() {
  _US=
  for _ud in $USBDEV/*; do
    [ -r "$_ud/devnum" ] || continue
    _un=; read -r _un < "$_ud/devnum" 2>/dev/null
    _US="$_US ${_ud##*/}:$_un"
  done
}
replug_watch() {
  [ "$WATCH" = 0 ] && exit 0
  say "다시 붙는 동글을 지켜봄(${WATCH}초마다 USB 장치 목록만 봄)"
  usb_sig; _wl=$_US
  if dongle_find; then _wd="$_DD:$_DNUM"; else _wd=; fi
  _wn=0
  while :; do
    # PC 테스트만 횟수를 둔다(NX4_DONGLE_WATCHN)
    [ -n "$NX4_DONGLE_WATCHN" ] && { _wn=$((_wn+1)); [ $_wn -gt "$NX4_DONGLE_WATCHN" ] && exit 0; }
    sleep $WATCH
    usb_sig
    [ "$_US" = "$_wl" ] && continue
    _wl=$_US
    if ! dongle_find; then
      [ -n "$_wd" ] && say "동글이 빠짐(다시 꽂으면 켬)"
      _wd=; continue
    fi
    [ "$_DD:$_DNUM" = "$_wd" ] && continue
    boot_secs
    say "동글 $_DV($_DD, 장치 번호 $_DNUM)가 새로 붙음(부팅 뒤 ${_U:-?}초): 켬"
    sh $NX4_APP/svc/dongle.sh --auto
    # 켜는 동안의 포트 끄고 켜기로 바뀐 번호는 새로 붙은 것으로 보지 않게, 끝난 뒤의 목록과 동글을 기준으로 삼는다
    usb_sig; _wl=$_US
    if dongle_find; then _wd="$_DD:$_DNUM"; else _wd=; fi
  done
}
# 동글로 AP를 띄웠으면 이번 부팅의 칩 없음 기록(nochip.sh)을 지운다: 관리 앱이 실제 AP를 보게(#107). nochip.sh는 다음에 지기가
# ap.boot를 지울 때 그 기록이 없음을 보고 물러난다
nochip_clear() {
  this_boot $NOCHIP || return 0
  rm -f $NOCHIP && say "동글로 AP를 띄워 이번 부팅의 칩 없음 기록을 지움"
}
# 끝내기: 부팅 서비스는 6으로 가고, [동글 켜기]는 누른 뒤 기록과 결과(code, 관리 앱이 읽음)를 남긴다
dg_done() {
  case $1 in ok|restarted) nochip_clear ;; esac
  if [ -n "$NOW" ]; then
    dongle_snap 2>/dev/null > $W/dongle-after.txt
    # 결과를 쓰기 바로 앞에 상태 파일을 새로 쓴다: 관리 앱은 결과를 받으면 상태 파일을 다시 읽어 판정 띠·표를 그리므로, 결과와
    # 같은 때의 AP를 보게 한다(#111). PC 테스트는 NX4_STATUS_CMD로 바꾼다
    ${NX4_STATUS_CMD:-sh $NX4_APP/bin/status.sh} </dev/null >/dev/null 2>&1
    ( umask 022; { echo "id=$RQ"; echo "boot=$(boot_id)"; echo "code=$1"; echo "usb=${V0:-none}"; echo "drv=${N0:-none}"; } > $DGRES.tmp \
        && $BB chmod 644 $DGRES.tmp && $BB mv -f $DGRES.tmp $DGRES ) 2>/dev/null
  fi
  rm -f $W/dongle.pid
  [ -z "$QUICK" ] && case $1 in chip|nodrivers|other|fail) ;; *) replug_watch ;; esac
  exit 0
}
# 한 번에 하나만(부팅 서비스와 [동글 켜기]): "<pid> <boot_id>". 이번 부팅에 살아 있는 다른 것이 있으면 하지 않는다
( umask 077; mkdir -p $W ) 2>/dev/null
_lk=$(cat $W/dongle.pid 2>/dev/null)
set -- $_lk
if [ -n "$1" ] && [ "$1" != "$$" ] && [ "$2" = "$(boot_id)" ] && [ -d $PROC/$1 ]; then
  say "다른 동글 작업이 도는 중(pid $1): 하지 않음"
  if [ -n "$NOW" ]; then
    ( umask 022; { echo "id=$RQ"; echo "boot=$(boot_id)"; echo "code=busy"; } > $DGRES.tmp && $BB chmod 644 $DGRES.tmp && $BB mv -f $DGRES.tmp $DGRES ) 2>/dev/null
  fi
  exit 0
fi
echo "$$ $(boot_id)" > $W/dongle.pid 2>/dev/null
if [ -n "$QUICK" ]; then
  [ -n "$NOW" ] && dongle_snap 2>/dev/null > $W/dongle-before.txt
  boot_secs
  case "$_U" in ''|*[!0-9]*) _U=0 ;; esac
  FIND=$((_U + ${NX4_DONGLE_NOWFIND:-15}))
  FTRIES=${NX4_DONGLE_FTRIES:-$((${NX4_DONGLE_NOWFIND:-15} / POLL + 2))}
  if [ -n "$NOW" ]; then say "[동글 켜기] 요청 $RQ(부팅 뒤 ${_U}초)"; else say "[다시 붙음] 켜기 시작(부팅 뒤 ${_U}초)"; fi
fi

if wifi_chip_seen; then say "Wi-Fi 칩이 있는 내비: 할 일 없음"; dg_done chip; fi
[ -r "$DONGLE_IDS" ] || { say "이 묶음에 동글 드라이버가 없음($DONGLE_IDS): 할 일 없음"; dg_done nodrivers; }

# 2. 동글 찾기
_n=0
while ! dongle_find; do
  boot_secs; _n=$((_n+1))
  if [ -z "$_U" ] || [ "$_U" -ge "$FIND" ] || [ $_n -gt "$FTRIES" ]; then say "우리 드라이버가 받는 동글이 없음(부팅 뒤 ${_U:-?}초): 할 일 없음"; dg_done nodongle; fi
  sleep $POLL
done
V0=$_DV N0=$_DN D0=$_DD M0=$_DNUM

# 3. 걸기
boot_secs
ko_mount $N0; _r=$?
case $_r in
  0) say "동글 $V0($D0): $N0 드라이버를 ${KO_SLOT}에 걺(부팅 뒤 ${_U:-?}초)" ;;
  2) say "동글 $V0: ${KO_SLOT}에 다른 것이 걸려 있어 건드리지 않음"; dg_done other ;;
  *) say "동글 $V0: $N0 드라이버를 ${KO_SLOT}에 걸지 못함"; dg_done fail ;;
esac
( umask 022; echo "$(boot_id) $V0 $N0 ${_U:-?}" > $DONGLE.tmp 2>/dev/null && $BB mv -f $DONGLE.tmp $DONGLE ) || say "기록($DONGLE)을 쓰지 못함"

# 4. 먼저 올라 있는 다른 bcmdhd 내리기
_lm=$(bcmdhd_drv)
case $_lm in
  none|ours|$N0) ;;
  *)
    _i=0
    while [ "$(cat $SYSMOD/bcmdhd/initstate 2>/dev/null)" = coming ] && [ $_i -lt "$LIVE" ]; do sleep 1; _i=$((_i+1)); done
    boot_secs
    # 칩이 있는 내비인데 HMG-API 표시 파일(public/wifi-chip)이 아직 없으면 1에서 걸러지지 않는다: SDIO 칩은 순정 HAL이 칩 전원을
    # 켠 뒤(약 10초)에야 보인다. 그래서 내리기 전에 다시 보고, 칩이 보이면 내리지 않고 건 것도 푼다. 순정은 이번 부팅에 칩 켜기를
    # 포기한 줄이 있을 때만 내린다(PR #99 리뷰 8)
    if wifi_chip_seen; then
      rm -f $DONGLE
      if ko_umount; then say "Wi-Fi 칩이 보임(부팅 뒤 ${_U:-?}초): bcmdhd($_lm)를 두고 건 것을 풂"
      else say "Wi-Fi 칩이 보임(부팅 뒤 ${_U:-?}초): bcmdhd($_lm)를 두었지만 건 것을 풀지 못함(재부팅하면 풀림)"; fi
      dg_done chip
    fi
    if [ "$_lm" = stock ] && ! stock_gave_up; then
      say "순정 bcmdhd가 이번 부팅에 칩 켜기를 포기한 줄이 없음: 내리지 않음(이번 부팅에는 우리 드라이버가 올라가지 않을 수 있음, 재부팅하면 다시 봄)"
    elif bbx rmmod bcmdhd 2>/dev/null; then say "먼저 올라 있던 bcmdhd($_lm)를 내림(부팅 뒤 ${_U:-?}초): 다음 Wi-Fi 요청에 HAL이 ${N0}을 올림"
    elif ! bcmdhd_loaded; then say "먼저 올라 있던 bcmdhd($_lm)는 이미 내려감(HAL이 내렸음)"
    else say "먼저 올라 있던 bcmdhd($_lm)를 내리지 못함($(cat $SYSMOD/bcmdhd/initstate 2>/dev/null || echo ?)): HAL이 그것을 둔 채라 이번 부팅에는 우리 드라이버가 올라가지 않을 수 있음(재부팅하면 다시 봄)"; fi
    ;;
esac

# 5. 포트 끄고 켜기 뒤 AP
proj_asked || { say "프로젝션 AP를 요청한 모드가 없음: 걸기만 하고 끝냄"; dg_done noproj; }
if [ -n "$QUICK" ]; then
  # 붙은 지 NX4_DONGLE_NOWSETTLE초가 안 됐을 때만 순정의 포트 끄고 켜기를 기다린다(그 시각까지). 붙은 때를 모르면 기다리지 않는다
  _since=$(dongle_since $D0 $M0)
  case "$_since" in ''|*[!0-9]*) SETTLE=0 ;; *) SETTLE=$((_since + ${NX4_DONGLE_NOWSETTLE:-20})) ;; esac
  STRIES=${NX4_DONGLE_STRIES:-$((${NX4_DONGLE_NOWSETTLE:-20} / SPOLL + 2))}
fi
cyc=no
_n=0
while :; do
  boot_secs; _n=$((_n+1))
  [ -n "$_U" ] && [ "$_U" -lt "$SETTLE" ] && [ $_n -le "$STRIES" ] || break
  sleep $SPOLL
  dongle_find || continue
  [ "$_DD:$_DNUM" = "$D0:$M0" ] && continue
  cyc=yes; break
done
if ! dongle_find; then say "동글이 빠짐: 끝냄(다시 꽂으면 켬)"; dg_done gone; fi
boot_secs
if [ $cyc = yes ]; then say "동글이 다시 붙음(포트 전원 껐다 켬, 장치 번호 $M0 → $_DNUM, 부팅 뒤 ${_U:-?}초)"
elif [ -n "$QUICK" ] && [ "$SETTLE" = 0 ]; then say "동글이 붙은 때를 모름(커널 줄 없음): 포트 끄고 켜기를 기다리지 않음"
elif [ -n "$QUICK" ] && [ "$_since" -lt "$((${_U:-0} - ${NX4_DONGLE_NOWSETTLE:-20}))" ]; then say "동글이 붙은 지 오래됨(부팅 뒤 ${_since}초): 포트 끄고 켜기를 기다리지 않음"
else say "부팅 뒤 ${_U:-?}초까지 동글이 다시 붙지 않음(포트 전원을 껐다 켜지 않았거나 그 전에 걸었음)"; fi
if [ -z "$QUICK" ]; then
  # 부팅: wlan0을 기다리고(HAL이 우리 것을 올렸으면 동글이 다시 붙을 때 생김) AP를 기다린다. 그래도 없으면 아래에서 껐다 켠다(#107)
  _i=0
  while [ ! -d $SYSNET/$WIF ] && [ $_i -lt "$WLWAIT" ]; do sleep 1; _i=$((_i+1)); done
  [ -d $SYSNET/$WIF ] || say "${WIF}이 생기지 않음(${WLWAIT}초): AP를 껐다 켜 HAL이 드라이버를 올리게 함"
  _i=0
  while [ -d $SYSNET/$WIF ] && ! { wlan_up && ap_on; } && [ $_i -lt "$APWAIT" ]; do sleep 1; _i=$((_i+1)); done
fi
if wlan_up && ap_on; then say "AP 떠 있음($WIF 올라옴, hostapd 돎): 할 일 없음"; dg_done ok; fi
_ab="HMG-API 지기는 $(this_boot $HMGWIFI/ap.boot && echo "이번 부팅에 띄웠다고 적음" || echo "아직 띄우지 못함")"
say "AP가 없음($_ab, $WIF $(wlan_up && echo 올라옴 || { [ -d $SYSNET/$WIF ] && echo 내려감 || echo 없음; }), hostapd $(ap_on && echo 돎 || echo 없음)): AP를 껐다 켬"
_o=$(aptool restart 2>&1); _r=$?
_o=$(echo "$_o" | $BB tr '\n' ' ')
say "AP 껐다 켜기: ${_o:-출력 없음}(종료 코드 $_r)"
# 껐다 켠 뒤 wlan0이 올라오고 hostapd가 도는지 NX4_DONGLE_AP초까지 본다
_i=0
[ $_r = 0 ] && while ! { wlan_up && ap_on; } && [ $_i -lt "$APWAIT" ]; do sleep 1; _i=$((_i+1)); done
if wlan_up && ap_on; then say "AP 떠 있음($WIF 올라옴, hostapd 돎)"; dg_done ok; fi
# 이번 부팅 기록이 남으면 지기가 다시 보지 않는다: 지워서 지기가 다시 시도하게 한다(지기는 10초마다 봄, PR #99 리뷰 4)
rm -f $HMGWIFI/ap.boot $HMGWIFI/ap.fail
if [ $_r != 0 ]; then say "AP를 켜지 못해 HMG-API 지기의 이번 부팅 기록(ap.boot)을 지움: 지기가 다시 시도함"
else say "AP가 아직 없음(${APWAIT}초): HMG-API 지기의 이번 부팅 기록(ap.boot)을 지워 지기가 다시 시도하게 함"; fi
dg_done noap
