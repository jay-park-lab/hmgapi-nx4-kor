#!/system/bin/sh
# HMG-API 서비스 "ap"(mod.json): hmgapid가 Android가 켜진 뒤 root로 띄우고, 끝나면 다시 띄우고,
# 모드를 끄거나 지우면 멈춘다(TERM, 5초 뒤 KILL).
#   1. 설치·업데이트 뒤 처음 한 번 scripts/post.sh를 돌린다(설치 전 Wi-Fi 상태 기록).
#   2. svc/hotspot.sh를 띄운다. 출력은 $APLOG(덧붙이기)로: hotspot.sh가 그 파일이면 크기 제한을 건다.
# 이 스크립트 자신의 몇 줄은 hmgapid 기록(/data/hmgapi/logs/nx4-kor/ap.log, hmgapid service-log)에 남는다.
. ${NX4_APP:-${HMGAPI_MOD_DIR:-/data/hmgapi/mods/nx4-kor}}/svc/env.sh
umask 077
mkdir -p $BK ${APLOG%/*}
# post.sh는 settings로 Wi-Fi 상태를 읽으므로 Android가 다 켜진 뒤에 돈다(start=android라 보통 이미 켜져 있다)
while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done
if [ ! -f $BK/post.done ]; then
  echo "$(date) 처음 시작(설치·업데이트 뒤): scripts/post.sh"
  if sh $NX4_APP/scripts/post.sh >> $APLOG 2>&1; then
    : > $BK/post.done
  else
    echo "$(date) scripts/post.sh 실패: 다음 시작에 다시 함"
  fi
fi
echo "$(date) svc/hotspot.sh 시작 (기록 $APLOG)"
exec sh $NX4_APP/svc/hotspot.sh >> $APLOG 2>&1
