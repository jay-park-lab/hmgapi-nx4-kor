# NX4 KOR의 위치. svc/ap.sh·svc/launch.sh·bin/uninstall.sh와 USB 설치기가 읽는다(. 으로).
#   NX4_APP·APP  모드 파일: HMG-API가 모드를 푸는 곳($HMGAPI_MOD_DIR, /data/hmgapi/mods/nx4-kor)
#   NX4_ROOT     이 모드의 기록 폴더(/data/nx4-kor). 지울 때 bin/uninstall.sh가 지운다
#   BK          백업·기록($NX4_ROOT/backup)
#   APLOG       서비스 기록($NX4_ROOT/logs/ap.log). svc/ap.sh가 hotspot.sh의 출력을 여기에 덧붙인다
# 값은 밖에서 정해 두면 그대로 쓴다(USB 설치기·PC 시험).
# 차의 명령이 먼저, 부른 쪽의 PATH는 뒤에(hmgapid는 서비스에 순정 PATH를 준다. PC 시험은 가짜 도구를 뒤에 둔다)
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin${PATH:+:$PATH}
NX4_ROOT=${NX4_ROOT:-/data/nx4-kor}
NX4_APP=${NX4_APP:-${HMGAPI_MOD_DIR:-/data/hmgapi/mods/nx4-kor}}
APP=$NX4_APP
BK=${BK:-$NX4_ROOT/backup}
APLOG=${APLOG:-$NX4_ROOT/logs/ap.log}
NX4_APLOG=$APLOG
NX4_MOD_ID=nx4-kor
export NX4_ROOT NX4_APP APP BK APLOG NX4_APLOG NX4_MOD_ID
