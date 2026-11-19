#!/system/bin/sh
# HMG-API 서비스 "ap"(mod.json): NEMESIS svcmgr의 [service.0] 대신. hmgapid가 Android가 켜진 뒤 root로 띄우고,
# 끝나면 다시 띄우고, 모드를 끄거나 지우면 멈춘다(TERM, 5초 뒤 KILL).
#   1. NEMESIS판 korea.projection 패키지가 있으면 대기만 한다(둘이 같은 wlan0을 두고 다투지 않게).
#   2. 처음 한 번 scripts/post.sh를 돌린다(NEMESIS가 설치 때 하던 일: 설치 전 Wi-Fi 상태 기록, 디버그 표시).
#   3. svc/hotspot.sh를 그대로 띄운다. 출력은 NEMESIS판처럼 $APLOG(덧붙이기)로: hotspot.sh가 그 파일이면 크기 제한을 건다.
# 이 스크립트 자신의 몇 줄은 hmgapid 기록(/data/hmgapi/logs/korea-projection/ap.log, hmgapid service-log)에 남는다.
. ${KP_APP:-${HMGAPI_MOD_DIR:-/data/hmgapi/mods/korea-projection}}/standalone/env.sh
umask 077
mkdir -p $BK ${APLOG%/*}
if [ -d $KP_NEMESIS_PKG ]; then
  echo "$(date) NEMESIS판 Korea Projection($KP_NEMESIS_PKG)이 설치되어 있어 이 모드는 아무것도 하지 않습니다. 둘 중 하나만 쓰세요."
  # 끝내지 않는다: 끝나면 hmgapid가 다시 띄우고 실패 횟수를 센다
  while true; do sleep 3600; done
fi
# post.sh는 settings로 Wi-Fi 상태를 읽으므로 Android가 다 켜진 뒤에 돈다(start=android라 보통 이미 켜져 있다)
while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done
if [ ! -f $BK/post.done ]; then
  echo "$(date) 처음 시작(설치·업데이트 뒤): scripts/post.sh"
  if sh $KP_APP/scripts/post.sh >> $APLOG 2>&1; then
    : > $BK/post.done
  else
    echo "$(date) scripts/post.sh 실패: 다음 시작에 다시 함"
  fi
fi
echo "$(date) svc/hotspot.sh 시작 (기록 $APLOG)"
exec sh $KP_APP/svc/hotspot.sh >> $APLOG 2>&1
