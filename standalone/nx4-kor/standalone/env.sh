# Korea Projection을 NEMESIS 없이 HMG-API 모드로 돌릴 때의 위치. ap.sh·launch.sh·uninstall.sh와 USB 설치기가 읽는다(. 으로).
# NEMESIS판(nemesis-pkg/korea.projection)의 스크립트는 그대로 쓰고, NEMESIS가 정하던 위치만 여기서 바꿔 넘긴다.
#   KP_APP·APP  패키지 파일: HMG-API가 모드를 푸는 곳($HMGAPI_MOD_DIR, /data/hmgapi/mods/nx4-kor)
#               (NEMESIS판: /data/nemesis/apps/korea.projection)
#   BK          백업·기록. NEMESIS판은 /data/nemesis/backup/korea.projection이고 NEMESIS가 지운다. 여기서는 uninstall.sh가 지운다
#   APLOG       서비스 기록. NEMESIS판은 svcmgr가 쓰는 /data/nemesis/logs/korea.projection/ap.log. 여기서는 ap.sh가 직접 연다
#   KP_APP_BY_HMGAPI=1  상태 화면 앱은 HMG-API가 설치·삭제한다(mod.json "apps", svc/hotspot.sh install_app)
# 값은 밖에서 정해 두면 그대로 쓴다(USB 설치기·PC 시험).
# 차의 명령이 먼저, 부른 쪽의 PATH는 뒤에(hmgapid는 서비스에 순정 PATH를 준다. PC 시험은 가짜 도구를 뒤에 둔다)
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin${PATH:+:$PATH}
KP_ROOT=${KP_ROOT:-/data/nx4-kor}
KP_APP=${KP_APP:-${HMGAPI_MOD_DIR:-/data/hmgapi/mods/nx4-kor}}
APP=$KP_APP
BK=${BK:-$KP_ROOT/backup}
APLOG=${APLOG:-$KP_ROOT/logs/ap.log}
KP_APLOG=$APLOG
KP_APP_BY_HMGAPI=1
KP_MOD_ID=nx4-kor
# NEMESIS판 패키지가 함께 있으면 같은 wlan0·같은 작업 폴더를 두고 다툰다: 그때 이 모드는 아무것도 하지 않는다
KP_NEMESIS_PKG=${KP_NEMESIS_PKG:-/data/nemesis/apps/korea.projection}
export KP_ROOT KP_APP APP BK APLOG KP_APLOG KP_APP_BY_HMGAPI KP_MOD_ID KP_NEMESIS_PKG
