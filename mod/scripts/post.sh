#!/system/bin/sh
# 설치·업데이트 뒤 서비스가 처음 시작할 때 한 번(svc/ap.sh): 삭제 때 되돌릴 Wi-Fi 설정을 적어 둔다.
# 상태 화면 앱은 HMG-API가 mod.json "apps"로 설치한다.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
# busybox는 아래 hotspot.sh가 고른다(내비의 것, 없으면 모드에 함께 넣은 것). 비워 두면 고른다.
BB=
# svc/env.sh가 BK·NX4_APP를 넘긴다
BK=${BK:-/data/nx4-kor/backup}
umask 077
mkdir -p $BK
[ -f $BK/wifi_on ] || settings get global wifi_on 2>/dev/null > $BK/wifi_on
APP=${NX4_APP:-/data/hmgapi/mods/nx4-kor}
HOTSPOT_LIB=1 . $APP/svc/hotspot.sh
# 쓸 수 있는 busybox가 없는 내비: 무선 설정은 하지 않는다(서비스도 대기만 함). 한 번 알린다(상태 화면 알림 기록·ap.log)
if ! has_bb; then
  notice "NX4 KOR: 이 내비에서는 쓸 수 있는 busybox가 없어 동작하지 않습니다. 무선 설정은 하지 않았습니다."
fi
exit 0
