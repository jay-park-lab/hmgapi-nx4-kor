#!/system/bin/sh
# 지우기 전 정리(bin/uninstall.sh가 서비스 ap를 멈춘 뒤 부른다):
#   1. 우리 hostapd·dnsmasq와 상태 화면 감시자를 멈추고 작업 파일을 지운다. NX4_UPDATE=1(새 판으로 바꾸기 전)이면 여기서 끝난다.
#   2. HMG-API에서 이 모드를 빼고 적용한다(무선 훅·기능 파일·네이티브 패치를 원래대로). 계획이 이 모드의 되돌리기뿐일 때만
#      적용하고, 아니면 HMG-API 앱에서 적용하라고 안내한다. HMG-API를 먼저 지웠으면 HMG-API 삭제가 이미 되돌렸다.
#   3. 이 모드가 직접 바꾼 것을 되돌린다: 무선 권한 파일(perms_revert), Wi-Fi 잠금, 순정 AP 저장값. 그리고 기록($BK)을 지운다.
# hotspot.sh 함수는 2번 전에 읽어 둔다(engine remove가 모드 폴더를 지운다).
# Wi-Fi는 껐다 켜지 않는다: 니로에서 Wi-Fi를 껐다 켜면 USB가 다시 붙고(Wi-Fi/블루투스 모듈이
# 같은 USB 버스에 있는 것으로 보임) 블루투스 카플레이가 재부팅 전까지 되지 않았다. 일반 Wi-Fi는 차를 껐다
# 켜면 돌아온다(wifi_on이 켜져 있으므로). 설치 전에 Wi-Fi가 꺼져 있던 차만 다시 끈다.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
umask 077
# busybox는 아래 hotspot.sh가 고른다(내비의 것, 없으면 모드에 함께 넣은 것)
BB=
# bin/uninstall.sh가 BK·NX4_APP를 넘긴다
BK=${BK:-/data/nx4-kor/backup}
APP=${NX4_APP:-/data/hmgapi/mods/nx4-kor}
HOTSPOT_LIB=1 . $APP/svc/hotspot.sh
# 쓸 수 있는 busybox가 없는 내비는 우리 hostapd를 켠 적이 없다: 오류 줄만 나오므로 건너뛴다
has_bb && stop_all
rm -f $CONF
# 상태 화면이 띄운 대기(status.sh --wait)와 감시자(--watch)를 멈춘다(업데이트 때도: 새 판이 다시 띄운다).
# 파일 첫 칸이 pid다. 명령줄은 NUL로 나뉘어 있어 busybox가 있으면 pcmd(NUL → 빈칸)로, 없으면 cat으로 읽어 본다
# (셸의 $(…)는 NUL을 버려 낱말이 붙지만 "status.sh"는 그대로 보인다).
for _pf in wait.pid watch.pid; do
  _wp=$(cat $W/$_pf 2>/dev/null); set -- $_wp
  [ -n "$1" ] || continue
  if has_bb; then _pc=$(pcmd $1); else _pc=$(cat /proc/$1/cmdline 2>/dev/null); fi
  case "$_pc" in *status.sh*) kill $1 2>/dev/null ;; esac
done
rm -f $PROG $PROG.tmp
rm -rf $W
# 상태 화면용 파일(bin/status.sh·서비스가 $W 밖에 쓴다). 업데이트 때도 지운다(새 판이 다시 쓴다)
rm -f /data/local/tmp/nx4-kor-status.txt /data/local/tmp/nx4-kor-status.txt.tmp
rm -f /data/local/tmp/nx4-kor-watch.txt /data/local/tmp/nx4-kor-watch.txt.tmp
rm -f $HINT $HINT.tmp
# 순정 hostapd가 돌고 있으면(순정 카플레이 AP 등) 그 주소는 순정 것이라 지우지 않는다(지우면 순정 카플레이가 끊김)
if ! { has_bb && stock_ap_on; }; then $BB ifconfig $WIF 0.0.0.0 2>/dev/null; fi
# 새 판으로 바꾸기 전(bin/uninstall.sh --update): Wi-Fi 설정과 기록은 그대로 두고 끝낸다. 모드는 HMG-API가 새 판으로 바꾼다
if [ "$NX4_UPDATE" = 1 ]; then
  echo "NX4 KOR 업데이트: 이전 판 정리"
  exit 0
fi
# 재부팅 결과 파일(status.sh rb_result, 상태 화면이 읽음)은 지울 때만 지운다
RBRES=${RBRES:-/data/local/tmp/nx4-kor-reboot-result.txt}
rm -f $RBRES $RBRES.tmp
modmsg=""
# 이 모드를 HMG-API에서 빼고 적용까지 끝내지 못했으면 1 (아래 권한 파일 되돌리기를 하지 않는다)
modhold=0
# HMG-API를 먼저 지웠는가: hmgapid 명령도, 설치 기록(installed.txt, HMG-API 삭제가 지운다)도 없다.
# 그때 HMG-API 삭제(engine restore)가 이 모드의 변경을 이미 원래대로 되돌렸다(남은 모드 폴더는 uninstall.sh가 지운다).
hmg_gone() { ! command -v hmgapid >/dev/null 2>&1 && [ ! -f ${HMGINST:-$HMGDATA/installed.txt} ]; }
if hmg_gone; then
  echo "HMG-API가 먼저 지워져 있음: HMG-API 삭제가 무선 기능을 이미 원래대로 되돌림"
elif [ ! -f $HMGDATA/mods/$MOD_ID/mod.json ]; then
  echo "HMG-API에 이 모드가 없음(이미 지워짐)"
elif ! hmgapid ping >/dev/null 2>&1; then
  # HMG-API 데몬이 응답하지 않으면 지울 수 없다. 차주에게 직접 지우라고 알린다
  echo "HMG-API 데몬 응답 없음: 모드를 지우지 못함"
  modhold=1
  modmsg=" HMG-API 앱에서 NX4 KOR를 지우고 변경 사항을 적용해 주세요."
elif ! hmgapid engine remove $MOD_ID > $BK/mod-remove.txt 2>&1; then
  echo "HMG-API에서 모드 지우기 실패 ($(cat $BK/mod-remove.txt 2>/dev/null))"
  modhold=1
  modmsg=" HMG-API 앱에서 NX4 KOR를 지우고 변경 사항을 적용해 주세요."
else
  # 계획이 이 모드의 되돌리기뿐일 때만 적용한다(다른 모드가 앱에서 쌓아 둔 변경까지 몰래 적용하지 않게).
  # app·service·usb 줄은 지금 켜져 있는 것의 설명이다. "nothing changed"(적용한 적이 없음)면 적용할 것이 없다.
  bad=0; todo=0
  hmgapid engine plan > $BK/plan.txt 2>&1 || bad=1
  while IFS= read -r l; do
    case "$l" in
      "restore  "*|"setting  "*" back to stock"*|"unbind   "*) todo=1 ;;
      "nothing changed"*problem*) bad=1 ;;
      "same     "*|"hook plan:"*|"note     "*|"WARNING"*|"nothing changed"*|"app      "*|"service  "*|"usb      "*|"") ;;
      *) bad=1 ;;
    esac
  done < $BK/plan.txt
  if [ $bad = 1 ]; then
    echo "모드를 지웠지만 적용하지 않음: 계획에 다른 변경이 있음 (HMG-API 앱에서 적용 필요)"
    modhold=1
    modmsg=" HMG-API 앱에서 변경 사항을 적용해 주세요(NX4 KOR 삭제)."
  elif [ $todo = 0 ]; then
    echo "HMG-API에서 이 모드를 지움(되돌릴 변경 없음)"
  elif hmgapid engine apply > $BK/apply.txt 2>&1; then
    echo "HMG-API에서 이 모드를 지우고 적용함(무선 기능을 원래대로)"
  else
    echo "모드를 지웠지만 적용 실패 (HMG-API 앱에서 적용 필요)"
    modhold=1
    modmsg=" HMG-API 앱에서 변경 사항을 적용해 주세요(NX4 KOR 삭제)."
  fi
fi
# fix_perms가 새로 쓴 무선 권한 파일을 지워 설치 전(파일 없음)으로 되돌린다. 모드를 지우고 적용한 뒤에 해야
# HMG-API가 아직 관리하는 파일인지 바르게 본다. 우리 것만, 내용이 그대로일 때만(perms_revert 설명). 실패하면 그대로 둔다.
# 모드 삭제를 적용하지 못했으면 HMG-API가 아직 그 파일을 어떻게 볼지 몰라(다음 적용이 "changed outside"로 멈출 수 있음) 건드리지 않는다.
if [ $modhold = 1 ]; then
  echo "무선 권한 파일 되돌리기 건너뜀: 모드 삭제가 적용되지 않음"
elif ! perms_revert; then
  modmsg="$modmsg 무선 기능 파일을 되돌리지 못했습니다(기록: /data/nx4-kor/logs/ap.log)."
fi
# Wi-Fi 잠금을 되돌린다: 설정 파일의 원래 소유자·권한, 치웠던 crc32 파일. 다음 부팅부터 Wi-Fi 서비스가
# 원래대로 wpa_supplicant를 띄운다(무선 카플레이 핫스팟은 이 모드와 함께 없어진다).
wifi_unlock && echo "Wi-Fi 잠금 되돌림"
# 1이 아니면 꺼져 있던 것으로 본다(한 번도 안 켠 차는 null일 수 있다). 기록이 없으면 건드리지 않는다.
[ -f $BK/wifi_on ] && [ "$(cat $BK/wifi_on 2>/dev/null)" != 1 ] && svc wifi disable
# Wi-Fi 서비스가 있는 차는 서비스가 Wi-Fi를 꺼 wifi_on이 0으로 바뀌었을 수 있다. 설치 전에 켜져 있었으면
# 값만 1로 되돌린다(지금 켜지는 않는다: 껐다 켜면 USB·블루투스가 다시 시작됨). 재부팅하면 원래대로 켜진다.
if [ -f $BK/wifi_on ] && [ "$(cat $BK/wifi_on 2>/dev/null)" = 1 ] && [ "$(settings get global wifi_on 2>/dev/null)" != 1 ]; then
  settings put global wifi_on 1
fi
# 서비스가 0으로 바꾼 순정 AP 저장값(wifi_ap_on)을 원래 값으로 되돌린다. 기록이 있고 지금 값이 아직 0일 때만
# (다른 곳에서 바꿨으면 그대로 둔다). 다음 부팅부터 순정이 예전처럼 AP를 복구한다.
# 되돌리지 못하면(settings 없음·실패) 기록은 아래에서 $BK와 함께 지워지므로 삭제 출력에 남긴다.
apon_restore || modmsg="$modmsg 순정 핫스팟 저장값(wifi_ap_on)을 되돌리지 못했습니다."
rm -rf $BK
# 상태 화면 앱도 함께 지워지므로 삭제 출력으로만 알린다. 알림 기록도 지운다.
rm -f $NOTICE $NOTICE.tmp
echo "NX4 KOR를 지웠습니다. 내비를 재부팅하면 일반 Wi-Fi가 원래대로 돌아옵니다.$modmsg"
exit 0
