#!/system/bin/sh
# HMG-API 서비스 "launch"(mod.json, start=manual, restart=false).
# 상태 화면 앱(StatusActivity)이 열릴 때 `hmgapid service-start launch`로 부른다(hmgapid는 이 모드의 앱일 때만 받는다).
# bin/status.sh를 root로 한 번 돌리고 끝난다: 상태 파일을 새로 쓰고, [지금 재부팅]을 받는 감시자(status.sh --watch, 10분,
# 따로 setsid)를 띄운다. 앱은 상태 파일이 바뀌면 화면을 다시 그린다.
# 끝줄(한 줄 요약)은 hmgapid 기록(hmgapid service-log nx4-kor launch)에 남는다.
. ${KP_APP:-${HMGAPI_MOD_DIR:-/data/hmgapi/mods/nx4-kor}}/svc/env.sh
umask 077
mkdir -p $BK ${APLOG%/*}
exec sh $KP_APP/bin/status.sh
