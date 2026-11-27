#!/system/bin/sh
# HMG-API 서비스 "dongle"(mod.json, start=boot, restart=false, root). USB Wi-Fi 동글(#48)의 드라이버를 순정 자리에 건다(#80 결정).
# 부팅 때 한 번 돌고 끝난다(상주하지 않음, 기다림은 모두 상한이 있음).
#   1. Wi-Fi 칩이 있는 내비(lib.sh wifi_chip_seen)이거나 이 묶음에 동글 드라이버가 없으면 아무것도 하지 않는다.
#   2. 꽂힌 USB 장치에서 우리 드라이버가 받는 동글을 찾는다(lib.sh dongle_find, drivers/usb-ids.txt). 부팅 뒤
#      NX4_DONGLE_FIND초까지 NX4_DONGLE_POLL초마다 본다. HMG-API 데몬은 부팅 약 2.6초에 이 서비스를 띄우고, 순정 HAL은
#      약 9.8초에 bcmdhd를 올린다(#80 차 기록 2026-11-27). 동글이 없으면 끝낸다(나중에 꽂으면 관리 앱 [동글 켜기], #60).
#   3. 맞는 .ko를 /system/wifi/bcmdhd.ko 위에 bind mount한다(lib.sh ko_mount). 루트 이름공간의 /system이 shared라
#      system_server(HAL) 쪽에도 보인다(#80). 이번 부팅에 건 것을 DONGLE 기록에 한 줄 남긴다(부팅마다 한 번 씀).
#      순정 bcmdhd가 이미 올라 있으면(늦게 건 경우) 그대로 두고 알린다: 순정 Wi-Fi 서비스가 실패한 뒤 드라이버를 내렸다 다시
#      올릴 때 우리 것이 올라간다[추정: 차 확인 #48].
#   4. 순정은 호스트 세션마다 USB 포트 전원을 한 번 껐다 켠다(꽂은 채 부팅 약 40초, 다시 붙기까지 3.4~3.8초, #48 차 기록).
#      그때 동글이 떨어졌다 다시 붙어 wlan0이 새로 생기는데, AP는 꺼진 채로 남을 수 있다(Android는 AP가 켜져 있다고 보고
#      HMG-API 지기는 이번 부팅에 띄웠다고 적어 둠, HMG-API #386). 동글의 장치 번호가 바뀔 때까지(부팅 뒤 NX4_DONGLE_SETTLE초까지)
#      기다리고, wlan0을 NX4_DONGLE_WLAN초, AP를 NX4_DONGLE_AP초 기다린 뒤:
#      - wlan0이 올라와 있고 hostapd가 돌면 그대로 둔다.
#      - HMG-API 지기가 이번 부팅에 AP를 띄웠다고 적었으면(wifi/ap.boot) AP를 한 번 껐다 켠다(hooks.jar의 ApTool,
#        Android Wi-Fi 서비스로. 차의 Wi-Fi 클라이언트가 켜져 있으면 두고 끝냄).
#      - 지기가 아직 띄우지 못했으면(다시 시도 중) 지기에 맡긴다.
#      프로젝션 AP를 요청한 모드가 없으면 4는 하지 않는다.
# 이 모드를 끄거나 지우면 hmgapid가 이 서비스의 프로세스 묶음을 내린다. 건 mount는 재부팅하면 풀린다(지울 때는 preun.sh가 푼다).
# 줄은 hmgapid 서비스 기록(logs/nx4-kor/dongle.log, USB 진단 logs/service/)에 남는다.
. ${NX4_APP:-${HMGAPI_MOD_DIR:-/data/hmgapi/mods/nx4-kor}}/svc/env.sh
. $NX4_APP/svc/lib.sh
FIND=${NX4_DONGLE_FIND:-9}
POLL=${NX4_DONGLE_POLL:-1}
SETTLE=${NX4_DONGLE_SETTLE:-75}
SPOLL=${NX4_DONGLE_SPOLL:-2}
WLWAIT=${NX4_DONGLE_WLAN:-20}
APWAIT=${NX4_DONGLE_AP:-30}
# AP를 껐다 켜는 도구(hooks.jar의 io.github.jayparklab.nx4kor.hook.ApTool). PC 테스트는 NX4_APTOOL로 바꾼다
aptool() {
  if [ -n "$NX4_APTOOL" ]; then $NX4_APTOOL "$@"
  else CLASSPATH=$NX4_APP/hooks.jar app_process /system/bin io.github.jayparklab.nx4kor.hook.ApTool "$@"; fi
}
say() { log_ts; echo "$_LT NX4 KOR 동글: $*"; }

if wifi_chip_seen; then say "Wi-Fi 칩이 있는 내비: 할 일 없음"; exit 0; fi
[ -r "$DONGLE_IDS" ] || { say "이 묶음에 동글 드라이버가 없음($DONGLE_IDS): 할 일 없음"; exit 0; }

# 2. 동글 찾기
while ! dongle_find; do
  boot_secs
  if [ -z "$_U" ] || [ "$_U" -ge "$FIND" ]; then say "우리 드라이버가 받는 동글이 없음(부팅 뒤 ${_U:-?}초): 할 일 없음"; exit 0; fi
  sleep $POLL
done
V0=$_DV N0=$_DN D0=$_DD M0=$_DNUM

# 3. 걸기
boot_secs
ko_mount $N0; _r=$?
case $_r in
  0) say "동글 $V0($D0): $N0 드라이버를 $KO_SLOT에 걺(부팅 뒤 ${_U:-?}초)" ;;
  2) say "동글 $V0: $KO_SLOT에 다른 것이 걸려 있어 건드리지 않음"; exit 0 ;;
  *) say "동글 $V0: $N0 드라이버를 $KO_SLOT에 걸지 못함"; exit 0 ;;
esac
( umask 022; echo "$(boot_id) $V0 $N0 ${_U:-?}" > $DONGLE.tmp 2>/dev/null && $BB mv -f $DONGLE.tmp $DONGLE ) || say "기록($DONGLE)을 쓰지 못함"
if bcmdhd_loaded && ! bcmdhd_ours; then
  say "순정 bcmdhd가 이미 올라 있음(늦게 걺): 순정 Wi-Fi 서비스가 드라이버를 다시 올릴 때 우리 것이 올라감"
fi

# 4. 포트 끄고 켜기 뒤 AP
proj_asked || { say "프로젝션 AP를 요청한 모드가 없음: 걸기만 하고 끝냄"; exit 0; }
cyc=no
while :; do
  boot_secs
  [ -n "$_U" ] && [ "$_U" -lt "$SETTLE" ] || break
  sleep $SPOLL
  dongle_find || continue
  [ "$_DD:$_DNUM" = "$D0:$M0" ] && continue
  cyc=yes; break
done
if ! dongle_find; then say "동글이 빠짐: 끝냄(다시 꽂으면 관리 앱 [동글 켜기])"; exit 0; fi
boot_secs
if [ $cyc = yes ]; then say "동글이 다시 붙음(포트 전원 껐다 켬, 장치 번호 $M0 → $_DNUM, 부팅 뒤 ${_U:-?}초)"
else say "부팅 뒤 ${_U:-?}초까지 동글이 다시 붙지 않음(포트 전원을 껐다 켜지 않았거나 그 전에 걸었음)"; fi
_i=0
while [ ! -d $SYSNET/$WIF ] && [ $_i -lt "$WLWAIT" ]; do sleep 1; _i=$((_i+1)); done
[ -d $SYSNET/$WIF ] || { say "$WIF이 생기지 않음(${WLWAIT}초): 순정 Wi-Fi 서비스에 맡김"; exit 0; }
_i=0
while ! { wlan_up && ap_on; } && [ $_i -lt "$APWAIT" ]; do sleep 1; _i=$((_i+1)); done
if wlan_up && ap_on; then say "AP 떠 있음($WIF 올라옴, hostapd 돎): 할 일 없음"; exit 0; fi
if ! this_boot $HMGWIFI/ap.boot; then say "AP가 아직 없음: HMG-API 지기가 다시 시도 중이라 맡김"; exit 0; fi
say "AP가 없음(HMG-API는 이번 부팅에 띄웠다고 적음, $WIF $(wlan_up && echo 올라옴 || echo 내려감), hostapd $(ap_on && echo 돎 || echo 없음)): AP를 껐다 켬"
_o=$(aptool restart 2>&1); _r=$?
_o=$(echo "$_o" | $BB tr '\n' ' ')
say "AP 껐다 켜기: ${_o:-출력 없음}(종료 코드 $_r)"
exit 0
