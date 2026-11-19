#!/system/bin/sh
# NX4 KOR 모드를 지우거나(인자 없음), 새 판으로 바꾸기 전에 정리한다(--update).
# root로 돈다: USB 설치기(troubleShooter), 또는 adb에서
#   adb shell "hmgapid sh 'sh /data/hmgapi/mods/nx4-kor/bin/uninstall.sh'"
#   1. 서비스 ap를 멈춘다.
#   2. scripts/preun.sh: 우리 hostapd·dnsmasq를 멈추고, HMG-API에서 이 모드를 빼고 적용하고(무선 훅·기능 파일을 원래대로),
#      무선 권한 파일·Wi-Fi 잠금·순정 AP 저장값을 되돌리고, $BK를 지운다. --update면 작업 파일만 지운다.
#   3. HMG-API를 먼저 지운 경우(hmgapid도 설치 기록도 없음): HMG-API 삭제는 서비스를 멈추고 이 모드의 변경을 되돌리지만,
#      모드 폴더를 남기고(--purge 아니면) 앱은 꺼 두기만 한다. 그래서 모드 폴더를 직접 지우고 앱을 pm으로 지운다.
#      /system을 쓰기로 여는 일은 hmgapid가 없으면 못 하므로 USB 설치기가 미리 연다(DSP OTA 프로세스에서는 순정 mount가 된다).
#   4. 기록 폴더($KP_ROOT)를 지운다.
# KP_APP: 모드 파일 위치(기본: 이 스크립트가 든 모드 폴더). 모드 폴더가 없으면(HMG-API 앱에서 지움, HMG-API --purge) USB 설치기가
# 스틱에 든 같은 판의 사본 위치를 넘긴다: 그래도 2번(되돌리기)을 할 수 있다.
# 종료 코드: 0 끝남, 1 실패(출력에 이유).
case "$0" in */bin/uninstall.sh) _d=${0%/bin/uninstall.sh} ;; *) _d= ;; esac
KP_APP=${KP_APP:-${_d:-/data/hmgapi/mods/nx4-kor}}
. $KP_APP/svc/env.sh
umask 077
UPD=0
[ "$1" = --update ] && UPD=1
HMGAPID=${HMGAPID:-hmgapid}
HMGDATA=${HMGDATA:-/data/hmgapi}
APP_ID=io.github.jayparklab.nx4kor
HMG_GONE=0
if ! command -v $HMGAPID >/dev/null 2>&1 && [ ! -f $HMGDATA/installed.txt ]; then HMG_GONE=1; fi

# ap가 아직 돌고 있는가(hmgapid services: "<mod> <name> <state> <pid> <fails>")
ap_running() {
  $HMGAPID services $KP_MOD_ID 2>/dev/null | while read _m _n _s _rest; do
    [ "$_n" = ap ] && [ "$_s" = running ] && echo yes
  done | grep -q yes
}
# HMG-API가 없으면 남은 모드 폴더를 지우고 앱을 직접 지운다(HMG-API는 꺼 두기만 했다).
# HMG-API가 있으면 preun.sh가 이미 HMG-API에서 뺐다: 아직 남아 있으면 실패로 알린다
mod_out() {
  if [ $HMG_GONE = 1 ]; then
    rm -rf $HMGDATA/mods/$KP_MOD_ID
    pm uninstall $APP_ID >/dev/null 2>&1 && echo "상태 화면 앱을 지움"
    [ ! -d $HMGDATA/mods/$KP_MOD_ID ] || { echo "남은 모드 폴더를 지우지 못함: $HMGDATA/mods/$KP_MOD_ID"; return 1; }
    return 0
  fi
  [ -f $HMGDATA/mods/$KP_MOD_ID/mod.json ] || return 0
  echo "HMG-API에서 모드를 지우지 못함: HMG-API 앱에서 NX4 KOR를 지우고 변경 사항을 적용해 주세요"
  return 1
}

[ $HMG_GONE = 1 ] && echo "HMG-API가 먼저 지워져 있음: 이 모드가 직접 바꾼 것을 되돌리고 남은 모드 폴더·앱을 지웁니다"

if [ $HMG_GONE = 0 ]; then
  $HMGAPID service-stop $KP_MOD_ID ap >/dev/null 2>&1
  # hmgapid는 TERM을 보내고 5초 뒤 KILL한다(hotspot.sh는 TERM에 우리 hostapd·dnsmasq를 멈춘다). 끝날 때까지 최대 10초
  _i=0
  while [ $_i -lt 10 ] && ap_running; do sleep 1; _i=$((_i+1)); done
  ap_running && echo "서비스 ap가 아직 멈추지 않음: 계속함(preun.sh가 우리 hostapd·dnsmasq를 멈춘다)"
fi

if [ $UPD = 1 ]; then
  KP_UPDATE=1 sh $KP_APP/scripts/preun.sh
  rc=$?
  # 새 판의 ap.sh가 post.sh를 다시 돌리게 한다
  rm -f $BK/post.done
  exit $rc
fi

sh $KP_APP/scripts/preun.sh
rc=$?
[ $rc = 0 ] || echo "scripts/preun.sh 종료 코드 $rc (위 출력 참고). 모드는 계속 지운다"
mod_out || exit 1
rm -rf $KP_ROOT
echo "NX4 KOR 모드를 지웠습니다. 내비를 재부팅해 주세요."
exit 0
