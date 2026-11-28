#!/system/bin/sh
# 지우기 전 정리(bin/uninstall.sh가 부른다). 2.1.0의 이 모드가 바꾸는 것은 HMG-API에 선언한 것(관리 앱·앱 메뉴 타일·
# launch·nochip·dongle 서비스, 한국 길안내 훅)과 관리 앱의 작업 파일, 칩 없음 기록, 2.2.0부터 USB Wi-Fi 동글 드라이버의 bind mount
# (재부팅하면 풀림)와 그 기록뿐이다. 시스템 파일·Wi-Fi 설정은 바꾸지 않으므로 되돌릴 것도 그것뿐이다. 서비스는 hmgapid가 내린다(아래 2).
#   1. 관리 앱이 띄운 대기(status.sh --wait)·감시자(--watch)를 멈추고 작업 폴더·상태 파일을 지운다. NX4_UPDATE=1(새 판으로
#      바꾸기 전)이면 여기서 끝난다. 설치 진행 기록은 USB 설치기가 쓰는 파일이라 업데이트 때는 두고, 지울 때만 지운다.
#   2. HMG-API에서 이 모드를 뺀다(engine remove). HMG-API(rc.8 Packages.remove → LiveState.publish)는 그때 앱·서비스 목록
#      (state/apps.txt·services.txt)을 다시 쓰고, hmgapid가 관리 앱을 지우고 launch 서비스를 내린다. 이 모드는 시스템 파일을
#      바꾸지 않아 적용(engine apply)할 것이 없으므로 계획을 보거나 적용하지 않는다(다른 모드가 쌓아 둔 변경도 건드리지 않음).
#      HMG-API를 먼저 지웠으면 HMG-API 삭제가 이미 내렸다.
# 2.0.x가 바꾼 것(Wi-Fi 설정 잠금, 무선 권한 파일, 순정 AP 저장값, 한국 포크 무선 기능)은 여기서 되돌리지 않는다. USB 설치기가
# 2.1.0을 넣기 전에 옛 판 자신의 bin/uninstall.sh로 정리한다.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
umask 077
# busybox는 아래 lib.sh가 고른다(내비의 것, 없으면 모드에 함께 넣은 것)
BB=
# bin/uninstall.sh가 NX4_APP를 넘긴다. lib.sh는 2번 전에 읽어 둔다(engine remove가 모드 폴더를 지운다)
APP=${NX4_APP:-/data/hmgapi/mods/nx4-kor}
. $APP/svc/lib.sh
# 관리 앱이 띄운 대기(status.sh --wait)와 감시자(--watch)를 멈춘다(업데이트 때도: 새 판이 다시 띄운다).
# 파일 첫 칸이 pid다. 명령줄은 NUL로 나뉘어 있어 busybox가 있으면 pcmd(NUL → 빈칸)로, 없으면 cat으로 읽어 본다
# (셸의 $(…)는 NUL을 버려 낱말이 붙지만 "status.sh"는 그대로 보인다).
for _pf in wait.pid watch.pid; do
  _wp=$(cat $W/$_pf 2>/dev/null); set -- $_wp
  [ -n "$1" ] || continue
  if has_bb; then _pc=$(pcmd $1); else _pc=$(cat /proc/$1/cmdline 2>/dev/null); fi
  case "$_pc" in *status.sh*) kill $1 2>/dev/null ;; esac
done
rm -rf $W
# 관리 앱용 파일(bin/status.sh가 $W 밖에 쓴다). 업데이트 때도 지운다(새 판이 다시 쓴다). 상태 안내(hint)는 2.0.x 서비스가 쓰던 것
rm -f /data/local/tmp/nx4-kor-status.txt /data/local/tmp/nx4-kor-status.txt.tmp
rm -f /data/local/tmp/nx4-kor-watch.txt /data/local/tmp/nx4-kor-watch.txt.tmp
rm -f $HINT $HINT.tmp
# [동글 켜기](#60) 결과(누르기 전·뒤 기록은 위 작업 폴더 $W에 있어 함께 지워짐)
rm -f $DGRES $DGRES.tmp
# 새 판으로 바꾸기 전(bin/uninstall.sh --update): 여기서 끝낸다. 모드는 HMG-API가 새 판으로 바꾼다
if [ "$NX4_UPDATE" = 1 ]; then
  echo "NX4 KOR 업데이트: 이전 판 정리"
  exit 0
fi
# 지울 때만: 설치 진행 기록, 재부팅 결과 파일(status.sh rb_result), 알림 기록, 칩 없음 기록(svc/nochip.sh). 관리 앱도 함께
# 지워진다. 칩 없음 기록은 업데이트 때 두어 이번 부팅의 판정을 잇는다(새 판의 nochip 서비스가 다음 부팅에 다시 쓴다).
# nochip.sh가 쓴 HMG-API의 wifi/ap.boot는 부팅 id만 든 HMG-API의 부팅마다의 파일이라 두고, 다음 부팅부터는 HMG-API 지기가 다시 시도한다
RBRES=${RBRES:-/data/local/tmp/nx4-kor-reboot-result.txt}
rm -f $PROG $PROG.tmp $RBRES $RBRES.tmp $NOTICE $NOTICE.tmp $NOCHIP $NOCHIP.nx4
# USB Wi-Fi 동글(svc/dongle.sh): 이 모드가 순정 Wi-Fi 드라이버 자리(/system/wifi/bcmdhd.ko)에 건 bind mount를 풀고 그 기록을 지운다.
# 다음에 순정 HAL이 올리는 것은 순정 드라이버다(이미 올라 있는 동글 드라이버는 HAL이 내릴 때까지 남음). 업데이트 때는 두어
# 이번 부팅의 동글을 잇는다(다음 부팅에 새 판의 서비스가 다시 건다). 풀지 못하면 알린다(재부팅하면 풀림)
if ko_on && [ "$_KO" != other ]; then
  if ko_umount; then echo "USB Wi-Fi 동글 드라이버($_KO)를 순정 자리에서 풂"
  else echo "USB Wi-Fi 동글 드라이버($_KO)를 순정 자리에서 풀지 못함(재부팅하면 풀림)"; fi
fi
rm -f $DONGLE $DONGLE.tmp
modmsg=""
# HMG-API를 먼저 지웠는가: hmgapid 명령도, 설치 기록(installed.txt, HMG-API 삭제가 지운다)도 없다.
# 그때 HMG-API 삭제가 이 모드의 앱·서비스를 이미 내렸다(남은 모드 폴더·앱은 uninstall.sh가 지운다).
hmg_gone() { ! command -v hmgapid >/dev/null 2>&1 && [ ! -f ${HMGINST:-$HMGDATA/installed.txt} ]; }
if hmg_gone; then
  echo "HMG-API가 먼저 지워져 있음: HMG-API 삭제가 이 모드를 이미 내림"
elif [ ! -f $HMGDATA/mods/$MOD_ID/mod.json ]; then
  echo "HMG-API에 이 모드가 없음(이미 지워짐)"
elif ! hmgapid ping >/dev/null 2>&1; then
  # HMG-API 데몬이 응답하지 않으면 지울 수 없다. 차주에게 직접 지우라고 알린다
  echo "HMG-API 데몬 응답 없음: 모드를 지우지 못함"
  modmsg=" HMG-API 앱에서 NX4 KOR를 지워 주세요."
elif ! _rmo=$(hmgapid engine remove $MOD_ID 2>&1); then
  echo "HMG-API에서 모드 지우기 실패 ($_rmo)"
  modmsg=" HMG-API 앱에서 NX4 KOR를 지워 주세요."
else
  echo "HMG-API에서 이 모드를 지움(관리 앱과 서비스는 HMG-API가 내림)"
fi
echo "NX4 KOR를 지웠습니다.$modmsg"
exit 0
