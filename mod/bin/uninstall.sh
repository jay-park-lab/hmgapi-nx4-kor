#!/system/bin/sh
# NX4 KOR 모드를 지우거나(인자 없음), 새 판으로 바꾸기 전에 정리한다(--update).
# root로 돈다: USB 설치기(troubleShooter), 또는 adb에서
#   adb shell "hmgapid sh 'sh /data/hmgapi/mods/nx4-kor/bin/uninstall.sh'"
#   1. scripts/preun.sh: 관리 앱의 감시자를 멈추고 작업 파일을 지우고, HMG-API에서 이 모드를 뺀다(engine remove: HMG-API가
#      앱·서비스·타일을 내림. 이 모드는 적용할 것이 없어 적용하지 않음).
#      --update면 감시자와 작업 파일만 정리한다.
#   2. HMG-API를 먼저 지운 경우(hmgapid도 설치 기록도 없음): HMG-API 삭제는 이 모드의 서비스를 멈추지만, 모드 폴더를 남기고
#      (--purge 아니면) 앱은 꺼 두기만 한다. 그래서 모드 폴더를 직접 지우고 앱을 pm으로 지운다.
#   3. 기록 폴더($NX4_ROOT)를 지운다. 2.0.x의 백업 폴더($BK)가 남아 있으면 그것만 두고 2.0.x USB로 되돌리라고 알린다.
# 2.1.0의 이 모드는 시스템 파일·Wi-Fi 설정을 바꾸지 않는다(무선은 HMG-API와 공식 무선 모드가 맡음). 2.0.x가 바꾼 것은 그 판 자신의
# uninstall.sh가 되돌린다(USB 설치기가 2.1.0을 넣기 전에 부름).
# NX4_APP: 모드 파일 위치(기본: 이 스크립트가 든 모드 폴더). 모드 폴더가 없으면(HMG-API 앱에서 지움, HMG-API --purge) USB 설치기가
# 스틱에 든 같은 판의 사본 위치를 넘긴다: 그래도 1번을 할 수 있다.
# 종료 코드: 0 끝남, 1 실패(출력에 이유).
case "$0" in */bin/uninstall.sh) _d=${0%/bin/uninstall.sh} ;; *) _d= ;; esac
NX4_APP=${NX4_APP:-${_d:-/data/hmgapi/mods/nx4-kor}}
. $NX4_APP/svc/env.sh
umask 077
UPD=0
[ "$1" = --update ] && UPD=1
HMGAPID=${HMGAPID:-hmgapid}
HMGDATA=${HMGDATA:-/data/hmgapi}
APP_ID=io.github.jayparklab.nx4kor
HMG_GONE=0
if ! command -v $HMGAPID >/dev/null 2>&1 && [ ! -f $HMGDATA/installed.txt ]; then HMG_GONE=1; fi

# HMG-API가 없으면 남은 모드 폴더를 지우고 앱을 직접 지운다(HMG-API는 꺼 두기만 했다).
# HMG-API가 있으면 preun.sh가 이미 HMG-API에서 뺐다: 아직 남아 있으면 실패로 알린다
mod_out() {
  if [ $HMG_GONE = 1 ]; then
    rm -rf $HMGDATA/mods/$NX4_MOD_ID
    pm uninstall $APP_ID >/dev/null 2>&1 && echo "관리 앱을 지움"
    [ ! -d $HMGDATA/mods/$NX4_MOD_ID ] || { echo "남은 모드 폴더를 지우지 못함: $HMGDATA/mods/$NX4_MOD_ID"; return 1; }
    return 0
  fi
  [ -f $HMGDATA/mods/$NX4_MOD_ID/mod.json ] || return 0
  echo "HMG-API에서 모드를 지우지 못함: HMG-API 앱에서 NX4 KOR를 지워 주세요"
  return 1
}

[ $HMG_GONE = 1 ] && echo "HMG-API가 먼저 지워져 있음: 이 모드의 작업 파일을 지우고 남은 모드 폴더·앱을 지웁니다"

if [ $UPD = 1 ]; then
  NX4_UPDATE=1 sh $NX4_APP/scripts/preun.sh
  exit $?
fi

sh $NX4_APP/scripts/preun.sh
rc=$?
[ $rc = 0 ] || echo "scripts/preun.sh 종료 코드 $rc (위 출력 참고). 모드는 계속 지운다"
mod_out || exit 1
# 2.0.x의 백업 폴더($BK)가 남아 있으면 그것만 두고 지운다. 2.1.0은 ${BK}를 만들지 않는다: 있으면 2.0.x가 바꾼 것(Wi-Fi 설정 잠금,
# 치운 crc32 파일, 순정 AP 저장값)을 되돌릴 기록이다. 지우면 되돌릴 길이 없어진다(2.0.x 위에 adb·HMG-API 앱으로 2.1.0을 넣은 차 등,
# PR #50 리뷰 2). 2.0.x USB(v2.0.4-beta.1)의 UNINSTALL은 남은 ${NX4_ROOT}를 보고 스틱의 2.0.x 사본으로, 2.1.0 이후 USB의 UNINSTALL은
# 함께 든 2.0.x 되돌리기(NX4/legacy-2.0, USB 설치기 작업 #52)로 되돌린다. 이 줄은 설치기 기록(NX4/install.log)에 남는다.
# 화면(토스트)으로 알리는 것은 설치기가 한다(PR #50 리뷰 9)
if [ -d $BK ]; then
  for _f in $NX4_ROOT/*; do [ "$_f" = "$BK" ] || rm -rf "$_f"; done
  echo "NX4 KOR 모드를 지웠습니다. 내비를 재부팅해 주세요."
  echo "2.0.x가 바꾼 것(Wi-Fi 설정 잠금 등)을 되돌릴 기록이 남아 있어 백업 폴더($BK)는 지우지 않았습니다. 2.0.x USB(v2.0.4-beta.1) 또는 NX4 KOR 2.1.0 이후 USB의 UNINSTALL로 되돌려 주세요."
  exit 0
fi
rm -rf $NX4_ROOT
echo "NX4 KOR 모드를 지웠습니다. 내비를 재부팅해 주세요."
exit 0
