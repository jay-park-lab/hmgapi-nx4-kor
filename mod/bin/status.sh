#!/system/bin/sh
# NX4 KOR 상태: 상태 화면 앱(io.github.jayparklab.nx4kor)이 읽는 상태 파일을 쓴다.
# 앱이 열릴 때 hmgapid service-start launch → svc/launch.sh가 이 스크립트를 root로 부른다.
#   (인자 없음) 상태 파일을 쓰고, 재부팅 요청을 받는 감시자(--watch)를 10분 동안 띄운다.
#   --wait      설치가 진행 중이면 끝날 때까지(최대 15분) 기다렸다가 상태 파일을 다시 쓴다.
#   --watch     상태 화면의 [지금 재부팅] 요청을 받는다.
# 2.1.0의 판정은 "HMG-API + 공식 무선 모드(wireless-carplay-aa) + 이 모드" 구조를 본다: HMG-API 판, 공식 모드가 깔리고 켜졌는지와
# 그 판·훅, HMG-API 훅(map), HMG-API가 띄우는 프로젝션 AP, Wi-Fi 부품. 읽기만 하고 아무것도 바꾸지 않는다.
# 상태 파일에는 이름, 버전, 예/아니요, 개수만 넣는다(SSID, 비밀번호, 휴대폰 이름, MAC, IP 없음).
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
# busybox는 svc/lib.sh가 고른다(내비의 것, 없으면 모드에 함께 넣은 것)
APP=${APP:-/data/hmgapi/mods/nx4-kor}
. $APP/svc/lib.sh
umask 077
bbx mkdir -p $W 2>/dev/null
# --wait: 설치 중에 화면을 열면 뒤에서 한 번 더 돈다. 설치가 끝날 때까지(최대 15분) 기다렸다가 아래 보통 흐름으로
# 상태 파일을 다시 쓴다. 상태 화면 앱은 진행 막대를 보여 주다가 상태 파일이 새로 쓰이면 결과 화면으로 바뀐다.
WAITED=0
if [ "$1" = --wait ]; then
  _i=0
  while $BB grep -q '^state=run$' $PROG 2>/dev/null && [ $_i -lt 180 ]; do sleep 5; _i=$((_i+1)); done
  rm -f $W/wait.pid
  WAITED=1
fi

# 이 스크립트의 기록(감시자·재부팅 요청 줄). 여기서는 그대로 다시 정한다(PC 테스트가 이 줄의 경로를 바꾼다)
APLOG=/data/nx4-kor/logs/ap.log
# 서비스 래퍼(svc/env.sh)가 정한 위치
[ -n "$NX4_APLOG" ] && APLOG=$NX4_APLOG
# busybox가 없으면(모드에 함께 넣은 것까지 없음) 판정을 못 한다. 앱이 "지원하지 않는 내비" 화면을 보이게 짧은 상태 파일만 쓴다.
# 이 셸에는 printf가 없어 echo만 쓴다. .tmp에 쓴 뒤 바꾼다(열려 있는 화면이 반쯤 쓴 파일을 읽지 않게).
if ! has_bb; then
  _st=${STATUS:-/data/local/tmp/nx4-kor-status.txt}
  ( umask 022
    { echo "support=nobb"
      echo "product=$(getprop ro.build.product)"
      echo "platform=$(getprop ro.board.platform)"
      echo "pkgver=$(mod_ver)"
      echo "made=$(date '+%m-%d %H:%M')"
    } 2>/dev/null > $_st.tmp && chmod 644 $_st.tmp 2>/dev/null && mv $_st.tmp $_st 2>/dev/null )
  exit 0
fi
# 상태 화면 앱(StatusActivity)이 읽는 key=value 파일. 앱은 root가 아니므로 누구나 읽을 수 있게(644)
# /data/local/tmp 바로 아래에 둔다. 값은 예/아니요·버전·개수뿐이다 (SSID, 비밀번호, 휴대폰 이름, MAC, IP 없음).
STATUS=${STATUS:-/data/local/tmp/nx4-kor-status.txt}
yesno() { if "$@" >/dev/null 2>&1; then echo yes; else echo no; fi; }
# 공식 무선 모드의 상태는 HMG-API 자기 파일로 본다(HMG-API hook/Mods.java, engine/Packages.java).
#   mods/<id>/mod.json 있음: 설치됨, mods/<id>/.disabled: HMG-API 앱에서 꺼 둠,
#   settings/<id>.json의 "bridge":false: 무선 카플레이(블루투스 브리지와 Wi-Fi 세션) 설정 꺼짐(공식 모드 settings.json)
# 켜 두었다는 것은 "꺼 두지 않았다"는 뜻일 뿐이다. HMG-API가 map·충돌로 건너뛴 경우는 훅 값(wm_hooks)으로 드러난다.
# bridge는 저장된 설정 값이라 적용(Apply changes) 전에는 실제 동작과 다를 수 있다.
WMDIR=${WMDIR:-$HMGDATA/mods/$WM_ID}
WMSET=${WMSET:-$HMGDATA/settings/$WM_ID.json}
wm_on_state() { if [ -f $WMDIR/mod.json ] && [ ! -f $WMDIR/.disabled ]; then echo yes; else echo no; fi; }
bridge_state() { if $BB grep -q '"bridge" *: *false' $WMSET 2>/dev/null; then echo off; else echo on; fi; }
# HMG-API가 부팅 때마다 남기는 줄(log.log.1이 더 오래됨)에서 마지막 것으로 본다. 이번 부팅의 줄을 놓치면 지난 부팅
# 기록일 수 있다(HMG-API 로그는 logcat에서 옮겨 적는다). map-check.json은 HMG-API 업데이트로 map이 바뀌어도 ok로 남을 수 있어 로그를 본다.
#   "hook map: <상태> for …, hooks on|off"(engine/CarMap.java): HMG-API 훅이 켜졌는가와 이 차 map의 상태(none, mismatch, mapped, verified 등)
#   "mods: loaded <id> <판>" / "mods: <id> not loaded: <이유>"(hook/Mods.java): 공식 무선 모드의 훅이 켜졌는가.
#     HMG-API는 모드가 선언한 훅 지점이 그 차 map에 없거나(change·replace는 HMG-API map에 있어야 함), 같은 지점을 replace하는
#     다른 모드와 겹치면(#17) 그 모드를 통째로 건너뛴다. 이유는 HMG-API가 남긴 영문 그대로(지점·모드 이름뿐, 개인정보 없음)
# _MH: "on", "off <이유>"(200자까지) 또는 빈 값(기록 없음). _HK: "on|off <상태>" 또는 빈 값. 로그는 한 번만 읽는다.
HMGLOG=${HMGLOG:-$HMGDATA/logs/hmgapi}
hmg_hooks_load() {
  [ "$HK_LOADED" = 1 ] && return 0
  HK_LOADED=1
  _hh=$($BB cat $HMGLOG/log.log.1 $HMGLOG/log.log 2>/dev/null | $BB awk -v id="$WM_ID" '
    index($0, "mods: loaded " id " ") > 0 { s = "on"; w = "" }
    index($0, "mods: " id " not loaded") > 0 { s = "off"; w = $0; if (index(w, "not loaded: ") > 0 || index(w, "not loaded live: ") > 0) sub(/.*not loaded( live)?: */, "", w); else w = "(예외, 자세한 이유는 HMG-API 로그)" }
    /hook map: .*, hooks on/ { h = "on"; i = index($0, "hook map: "); m = substr($0, i + 10); sub(/[ ,].*/, "", m) }
    /hook map: .*, hooks off/ { h = "off"; i = index($0, "hook map: "); m = substr($0, i + 10); sub(/[ ,].*/, "", m) }
    END { if (s == "off") print "MH off " substr(w, 1, 200); else print "MH " s
          if (h != "") print "HK " h " " m; else print "HK " }')
  _MH=; _HK=
  while IFS= read -r _hl; do
    case "$_hl" in "MH "*) _MH=${_hl#MH } ;; "HK "*) _HK=${_hl#HK } ;; esac
  done <<HKE
$_hh
HKE
}
# --- HMG-API 부팅 보호(boot guard) 알리기(읽기만, 값을 되돌리거나 HMG-API 파일을 쓰지 않음) ---
# 근거(HMG-API core/zygote/zygote.c): zygote가 시작할 때마다 /data/hmgapi/hook/starts를 1 올리고(bump_starts, 올리기 전 값을
# 돌려줌) 그 값이 MAXSTARTS(3) 이상이면 그 시작의 훅을 모두 끄고 커널 로그에 "hmgapi-hook: zygote, hooks off (boot guard, starts=N)"을
# 남긴다. 훅이 켜지면 "…, hooks on, start N"이고, GUARD_DELAY(120)초 뒤 zygote가 살아 있으면 watcher가 0으로 되돌린다.
# 그래서 지금 읽은 값(올린 뒤 값)이 4 이상이면 이번 시작은 훅이 꺼진 것이다(3이면 아직 켜진 시작 3번째: 2분 안에 또 재부팅하면 꺼짐).
# 0으로 되돌리는 것은 훅이 켜진 부팅의 watcher와 HMG-API 설치(install.sh: echo 0 > hook/starts)뿐이다.
HOOKSTARTS=${HOOKSTARTS:-/data/hmgapi/hook/starts}
# starts 값(숫자). 못 읽으면 빈 값
hook_starts() { _hs=; { read _hs < $HOOKSTARTS; } 2>/dev/null; case "$_hs" in ''|*[!0-9]*) _hs= ;; esac; echo "$_hs"; }
# zygote.c는 hook/enable이 있고 hook/disable이 없을 때만 훅을 켜고 starts를 올린다. 둘 중 하나라도 어긋나면 starts는
# 멈춘 옛 값이라 판정·거절에 쓰지 않는다. HOOKDIR는 starts 파일이 있는 폴더(PC 시험은 HOOKSTARTS로 바꿈)
HOOKDIR=${HOOKDIR:-${HOOKSTARTS%/*}}
hook_armed() { [ -f $HOOKDIR/enable ] && [ ! -f $HOOKDIR/disable ]; }
# HMG-API 설치 판(installed.txt의 version). 설치돼 있지 않으면 빈 값
hmg_ver() { $BB awk '$1 == "version" { print $2; exit }' ${HMGINST:-$HMGDATA/installed.txt} 2>/dev/null; }
# 이번 부팅 zygote의 훅 줄(커널 로그)을 읽어 ZH(마지막 줄: on·guard·off·빈 값 = 이번 부팅 줄 없음)와 ZON(마지막 "hooks on" 줄의
# 커널 시각, 정수 초, 없으면 빈 값)에 둔다. zygote가 같은 부팅에 다시 시작하면 줄이 여럿이다(마지막 것이 지금). NX4_DMESG는 PC 시험용
zygote_info() {
  ZH=; ZON=
  set -- $({ if [ -n "$NX4_DMESG" ]; then cat $NX4_DMESG; else dmesg; fi; } 2>/dev/null | $BB grep 'hmgapi-hook: zygote,' 2>/dev/null \
    | $BB awk '{ i = index($0, "["); j = index($0, "]"); t = ""; if (i > 0 && j > i) { t = substr($0, i + 1, j - i - 1); gsub(/ /, "", t); t = int(t + 0) } }
      index($0, "hooks on") > 0 { h = "on"; on = t; next } index($0, "hooks off (boot guard") > 0 { h = "guard"; next } index($0, "hooks off") > 0 { h = "off" }
      END { print (h == "" ? "-" : h), (on == "" ? "-" : on) }')
  [ "$1" = - ] || ZH=$1
  [ "$2" = - ] || ZON=$2
  return 0
}
# 부팅 뒤 초(시계가 바뀌어도 거꾸로 가지 않는다). 읽지 못하면 빈 값
up_s() { $BB awk '{ print int($1) }' $UPTIME 2>/dev/null; }
# 프로젝션 AP를 기다리는 시간(부팅 뒤 초). HMG-API Wi-Fi 지기는 Android Wi-Fi 서비스가 뜨자마자 한 번 띄우고, 안 되면 약 1분 동안
# 다시 시도한다. 그 안에 ap.boot·ap.fail이 모두 없으면 "켜는 중", 지나면 "켜지 않았음"으로 본다
AP_WAIT=${AP_WAIT:-300}

# --- 판정은 한 곳에서 ---
# st_collect가 판정에 쓰는 값을 한 번만 구하고(K_*), st_verdict가 차례대로 판정해 V_*에 둔다. 상태 파일(status_kv)에 쓰고,
# 상태 화면 앱은 상태 파일의 verdict·verdict_lv·verdict_msg를 그대로 보인다.
# 판정 순서: HMG-API 부팅 보호 → 설치 중 → 이 모드의 차가 아님 → HMG-API 판 → 설치기가 남긴 재부팅 필요·실패 →
# 공식 무선 모드(설치·켜짐·판) → HMG-API 훅(map) → 공식 모드의 훅 → 무선 카플레이 설정 → 무선 기능 → 프로젝션 AP 요청 →
# 연결됨 → 다른 Wi-Fi 패키지 → AP 켜짐(준비됨·일반 핫스팟) → Wi-Fi 클라이언트 → Wi-Fi 부품 없음 → AP 꺼짐·켜는 중·못 켬.
st_collect() {
  [ "$SC_DONE" = 1 ] && return 0
  SC_DONE=1
  K_PROD=$(getprop ro.build.product)
  K_FEATS="$(pm list features 2>/dev/null)
"
  K_BOOT=$(boot_id)
  parse_conf $SRC
  K_HMG=$(echo $($BB grep -E '^(version|build) ' ${HMGINST:-$HMGDATA/installed.txt} 2>/dev/null))
  _kv=${K_HMG#*version }; [ "$_kv" = "$K_HMG" ] && _kv=; K_HMGV=${_kv%% *}
  K_WM=$(yesno [ -f $WMDIR/mod.json ]); K_WMV=$(mod_ver $WMDIR/mod.json); K_WMON=$(wm_on_state); K_BRIDGE=$(bridge_state)
  hmg_hooks_load; K_MH=${_MH%% *}; K_MHWHY=; [ "$K_MH" = off ] && K_MHWHY=${_MH#off}; K_HK=${_HK%% *}; K_HKMAP=${_HK#* }
  K_AP=$(yesno ap_on); K_APMODE=$(ap_ssid); K_FOREIGN=$(yesno foreign_hostapd)
  K_CP=$(cp_count); K_WPA=$(yesno running wpa_supplicant)
  K_WLAN=$(yesno [ -d $SYSNET/$WIF ]); K_CHIP=$(yesno wifi_chip_seen)
  K_PROJ=$(yesno proj_asked $WM_ID); K_APBOOT=$(yesno this_boot $HMGWIFI/ap.boot); K_APFAIL=$(yesno this_boot $HMGWIFI/ap.fail)
  K_UP=$(up_s); case "$K_UP" in ''|*[!0-9]*) K_UP= ;; esac
  # HMG-API 부팅 보호. HMG-API가 설치돼 있을 때만 본다(지운 차·disable로 끈 차는 starts가 남아도 아님).
  # 이번 부팅 커널 로그에 zygote 줄이 있으면 그것을 따른다(마지막 줄: guard면 맞음, on·다른 off면 아님). 줄이 없을 때만 starts≥4를 쓴다
  K_STARTS=$(hook_starts); zygote_info; K_ZHOOK=$ZH; K_GUARD=no
  if [ -n "$K_HMGV" ]; then
    case "$K_ZHOOK" in
      guard) K_GUARD=yes ;;
      on|off) ;;
      *) hook_armed && [ -n "$K_STARTS" ] && [ "$K_STARTS" -ge 4 ] && K_GUARD=yes ;;
    esac
  fi
  # 이번 부팅의 설치 진행 기록(USB 설치기가 씀. 지난 부팅 것은 빈 값)
  K_PST=; K_PSTAGE=
  if [ "$($BB awk -F= '$1 == "boot" { print $2 }' $PROG 2>/dev/null)" = "$K_BOOT" ]; then
    K_PST=$($BB awk -F= '$1 == "state" { print $2 }' $PROG 2>/dev/null)
    K_PSTAGE=$($BB awk -F= '$1 == "stage" { sub(/^stage=/, ""); print; exit }' $PROG 2>/dev/null)
  fi
}
k_feat() { case "$K_FEATS" in *"feature:$1
"*) return 0 ;; esac; return 1; }
# 판정 결과: V_CODE(영문 낱말), V_LV(0 좋음·1 확인 필요·2 문제), V_MSG(한국어 한두 문장), V_END(yes면 "이 차는 안 됨"으로 끝나 지우는 법을
# 함께 보임), V_S1~3(차주용 요약 3줄: 설치·무선 Wi-Fi·폰 연결)
st_verdict() {
  st_collect
  V_CODE=; V_LV=1; V_MSG=; V_END=no
  # 지금 무선 카플레이가 연결돼 있는가. 연결 중이면 Wi-Fi 꺼짐 판정을 내지 않는다
  _vconn=no; [ "${K_CP:-0}" != 0 ] && _vconn=yes
  _vs() { V_CODE=$1; V_LV=$2; V_MSG=$3; }
  # HMG-API 부팅 보호에 걸려 이번 부팅 훅이 꺼짐. 연결 중이 아니면 다른 판정보다 앞에(이것을 풀지 않으면 다른 것은 의미 없음).
  # HMG-API를 지우면 모드가 바꾼 파일이 순정으로 돌아가 다시 적용해야 하므로, 지우지 말고 다시 설치(업데이트)하라고 쓴다.
  # 이번 부팅은 부팅 보호로 시작했는데 지금 starts가 4보다 작으면(걸린 부팅에서는 4 이상이 남는다) 그 사이 HMG-API를
  # 다시 설치해 0이 된 것이다. 같은 일을 또 시키지 않고 재부팅만 안내한다
  if [ "$K_GUARD" = yes ] && [ "$_vconn" = no ] && [ "$K_ZHOOK" = guard ] && [ -n "$K_STARTS" ] && [ "$K_STARTS" -lt 4 ]; then
    _vs bootguard 1 "HMG-API를 다시 설치한 것으로 보입니다. 내비를 재부팅하고 3분 넘게 켜 두세요."
  elif [ "$K_GUARD" = yes ] && [ "$_vconn" = no ]; then
    _vs bootguard 2 "HMG-API가 재부팅이 너무 잦은 것으로 보고 무선 기능을 껐습니다. HMG-API를 지우지 말고 HMG-API USB로 다시 설치(업데이트)한 뒤 재부팅하고, 3분 넘게 켜 두세요."
  elif [ "$K_PST" = run ]; then _vs installing 1 "설치 중입니다. 끝날 때까지 기다려 주세요."
  elif ! car_in "$K_PROD" "$CARS"; then _vs nocar 2 "$NOCAR_MSG"; V_END=yes
  elif [ -z "$K_HMGV" ]; then _vs nohmgapi 2 "$NOHMG_MSG"
  elif ver_lt "$K_HMGV" $HMG_MIN; then _vs oldhmgapi 2 "지원하지 않는 HMG-API 버전입니다. $HMG_MIN 이상으로 업데이트해 주세요."
  # 설치기가 이번 부팅에 남긴 결과(진행 기록). 실패 이유는 설치기가 stage에 한국어 문장으로 쓴다
  elif [ "$K_PST" = reboot ]; then _vs reboot 1 "내비를 3분 후 재부팅해 주세요."
  elif [ "$K_PST" = fail ] && [ -n "$K_PSTAGE" ]; then _vs failed 2 "$K_PSTAGE"
  # 공식 무선 모드(wireless-carplay-aa). 이 모드는 requires로 걸지 않으므로(lib.sh WM_ID) 없거나 꺼진 것을 여기서 알린다
  elif [ "$K_WM" = no ]; then
    _vs nowireless 2 "공식 무선 모드($WM_NAME)가 설치되어 있지 않습니다. NX4 KOR USB 설치기로 다시 설치해 주세요."
  elif [ "$K_WMON" = no ]; then
    _vs wirelessoff 2 "HMG-API 앱에서 $WM_NAME가 꺼져 있습니다. 켜고 변경 사항을 적용한 뒤 내비를 재부팅해 주세요."
  elif [ -z "$K_WMV" ] || ver_lt "$K_WMV" $WM_MIN; then
    _vs oldwireless 2 "공식 무선 모드 버전(${K_WMV:-알 수 없음})을 지원하지 않습니다. $WM_MIN 이상으로 업데이트해 주세요."
  elif [ "$K_HK" = off ]; then
    case "$K_HKMAP" in
      mapped) _vs hooksoff 1 "HMG-API 훅이 꺼져 있습니다. HMG-API 앱 Settings에서 'Check the map on this car'를 누른 뒤 내비를 재부팅해 주세요." ;;
      none) _vs hooksoff 1 "HMG-API에 이 차의 map이 없어 훅이 꺼져 있습니다. NX4 KOR USB 설치기를 다시 실행해 주세요(map을 만들고 확인합니다)." ;;
      mismatch) _vs hooksoff 1 "HMG-API map이 이 차의 소프트웨어와 맞지 않아 훅이 꺼져 있습니다. 내비 소프트웨어를 업데이트했다면 HMG-API와 NX4 KOR를 다시 설치해 주세요." ;;
      *) _vs hooksoff 1 "HMG-API 훅이 꺼져 있습니다(마지막 부팅 기록). 내비를 3분 후 재부팅한 뒤 다시 확인해 주세요." ;;
    esac
  elif [ "$K_MH" = off ]; then
    # 같은 지점을 replace하는 다른 모드와 겹치면(#17) HMG-API는 load 차례가 뒤인 모드를 끄고 이유에 "conflict"를 남긴다
    case "$K_MHWHY" in
      *conflict*) _vs wmhooksoff 2 "$WM_NAME가 다른 모드와 같은 훅을 써서 꺼졌습니다. HMG-API 앱의 Mods에서 겹치는 모드를 끈 뒤 내비를 재부팅해 주세요." ;;
      *) _vs wmhooksoff 2 "HMG-API가 이 차에서 $WM_NAME의 훅을 켜지 못했습니다. 내비를 3분 후 재부팅해도 같으면 HMG-API 앱의 Mods에서 이유를 확인해 주세요." ;;
    esac
  elif [ "$K_BRIDGE" = off ]; then
    _vs bridgeoff 2 "HMG-API 앱의 $WM_NAME 설정에서 'Wireless CarPlay'가 꺼져 있습니다. 켜고 변경 사항을 적용한 뒤 내비를 재부팅해 주세요."
  elif ! k_feat com.hkmc.software.connectivity.carplay_wireless; then
    _vs nofeat 2 "무선 카플레이 기능이 아직 켜지지 않았습니다. HMG-API 앱에서 변경 사항을 적용했는지 확인하고 내비를 3분 후 재부팅해 주세요."
  elif [ "$K_PROJ" = no ]; then
    _vs noproj 2 "HMG-API가 무선 연결용 Wi-Fi(프로젝션 AP)를 띄우도록 설정되지 않았습니다. HMG-API 앱에서 변경 사항을 적용한 뒤 내비를 재부팅해 주세요."
  elif [ "$_vconn" = yes ]; then _vs connected 0 "무선 카플레이 연결됨"
  elif [ "$K_FOREIGN" = yes ]; then
    # 순정(netd)이 아닌 hostapd(다른 무선 패키지, USB 동글 패키지 등)가 돌고 연결도 없음. HMG-API 프로젝션 AP와 Wi-Fi를 다툰다
    _vs otherwifi 2 "다른 Wi-Fi 패키지가 Wi-Fi를 쓰고 있어 함께 쓸 수 없습니다. 그 패키지를 지운 뒤 내비를 재부팅해 주세요."
  elif [ "$K_AP" = yes ] && [ "$K_APMODE" = hotspot ]; then
    # 순정 일반 핫스팟(S1)으로 떠 있음: 폰이 카플레이 Wi-Fi(S2)를 찾지 못한다. HMG-API 지기는 이미 떠 있는 AP는 그대로 둔다
    _vs aphotspot 1 "내비 Wi-Fi가 일반 핫스팟으로 켜져 있어 무선 카플레이가 붙지 않을 수 있습니다. 순정 핫스팟을 끄고 내비를 3분 후 재부팅해 주세요."
  elif [ "$K_AP" = yes ]; then _vs ready 0 "무선 카플레이·안드로이드 오토 준비됨."
  elif [ "$K_WPA" = yes ]; then
    # 내비의 Wi-Fi 클라이언트(HMG-API 집 Wi-Fi 포함)가 켜져 있으면 HMG-API 지기는 라디오를 건드리지 않는다(Wi-Fi 칩은 하나)
    _vs wificlient 1 "내비가 일반 Wi-Fi에 접속하는 중이라 무선 연결용 Wi-Fi가 꺼져 있습니다. HMG-API 앱의 Home Wi-Fi를 쓰면 주차를 풀 때 돌아옵니다."
  elif [ "$K_CHIP" = no ] && [ "$K_WLAN" = no ] && [ "$K_APFAIL" = yes ] && [ "$K_APBOOT" = no ] \
      && k_feat com.hkmc.software.wifihotspot; then
    # 칩 전원이 달린 순정 핫스팟 기능은 켜졌는데(HMG-API가 켬) 칩이 SDIO에 한 번도 보이지 않았고, HMG-API가 이번 부팅에 AP를
    # 띄우지 못했다. 2026-11-23 NX4HEV 260902가 이랬다(커널 "failed to power up DHD generic adapter", #38). 무선은 USB Wi-Fi 동글(#48)로.
    # 유선 카플레이·안드로이드 오토와 계기판 길안내(공식 모드)는 그대로라 "이 차는 안 됨"(지우는 법)으로 끝내지 않는다
    _vs nowifipart 1 "이 차의 내비에는 Wi-Fi 부품이 없는 것으로 보여 무선 카플레이·안드로이드 오토를 쓸 수 없습니다. 유선 연결과 계기판 길안내는 그대로 쓸 수 있습니다."
  elif [ "$K_APBOOT" = yes ]; then
    # 이번 부팅에 떴다가 지금은 꺼짐(차가 끈 것은 HMG-API 지기가 다시 켜지 않는다). 폰이 붙을 때 공식 모드가 다시 켠다(HMG-API rc.8)
    _vs apoff 1 "무선 연결용 Wi-Fi가 지금 꺼져 있습니다. 폰을 연결해 보고, 안 되면 내비를 3분 후 재부팅해 주세요."
  elif [ "$K_APFAIL" = yes ]; then
    _vs apfail 1 "HMG-API가 무선 연결용 Wi-Fi를 아직 켜지 못했습니다(다시 시도하는 중). 내비를 3분 후 재부팅해도 같으면 HMG-API 기록(/data/hmgapi/logs/hmgapi/wifi.log)을 확인해 주세요."
  elif [ -z "$K_UP" ] || [ "$K_UP" -lt "$AP_WAIT" ]; then
    _vs apwait 1 "무선 연결용 Wi-Fi를 켜는 중입니다. 1~2분 뒤 화면을 다시 열어 주세요."
  else
    _vs apfail 1 "HMG-API가 이번 부팅에 무선 연결용 Wi-Fi를 켜지 않았습니다. 내비를 3분 후 재부팅해도 같으면 HMG-API 기록(/data/hmgapi/logs/hmgapi/wifi.log)을 확인해 주세요."
  fi
  # 차주용 요약 3줄
  case "$V_CODE" in
    installing) V_S1="설치: 진행 중" ;;
    reboot) V_S1="설치: 재부팅 필요" ;;
    bootguard) V_S1="설치: HMG-API 훅 꺼짐(부팅 보호)" ;;
    ready|connected|aphotspot|wificlient|nowifipart|apoff|apfail|apwait|hooksoff) V_S1="설치: 끝남" ;;
    *) V_S1="설치: 안 됨(오른쪽 안내를 보세요)" ;;
  esac
  if [ "$V_CODE" = otherwifi ]; then V_S2="무선 Wi-Fi: 다른 패키지가 씀"
  elif [ "$K_AP" = yes ] && [ "$K_APMODE" = hotspot ]; then V_S2="무선 Wi-Fi: 일반 핫스팟으로 켜짐"
  elif [ "$K_AP" = yes ]; then V_S2="무선 Wi-Fi: 켜짐(HMG-API)"
  elif [ "$V_CODE" = nowifipart ]; then V_S2="무선 Wi-Fi: 부품 없음(USB 동글 필요)"
  elif [ "$V_CODE" = wificlient ]; then V_S2="무선 Wi-Fi: 일반 Wi-Fi 접속 중"
  elif [ "$V_CODE" = apwait ]; then V_S2="무선 Wi-Fi: 켜는 중"
  else V_S2="무선 Wi-Fi: 꺼짐"; fi
  if [ "${K_CP:-0}" != 0 ]; then V_S3="폰 연결: 카플레이 ${K_CP}대 연결됨"
  else V_S3="폰 연결: 지금 연결된 폰 없음"; fi
  return 0
}
status_kv() {
  st_collect
  st_verdict
  echo "product=$K_PROD"
  echo "targetdir=$(getprop ro.mobis.targetdir)"
  echo "pkgver=$(mod_ver)"
  # tested: 이 모드의 차인가 (앱은 no면 "지원하지 않는 차"로 보인다)
  car_in "$K_PROD" "$CARS" && echo "tested=yes" || echo "tested=no"
  echo "hmgapi=$K_HMG"
  # 공식 무선 모드: 설치됨·판·켜짐(꺼 두지 않음)·훅(on|off|빈 값)·무선 카플레이 설정(bridge)
  echo "wm=$K_WM"
  echo "wm_ver=$K_WMV"
  echo "wm_on=$K_WMON"
  echo "wm_hooks=$K_MH"
  echo "bridge=$K_BRIDGE"
  echo "hooks=$K_HK"
  echo "hookmap=$K_HKMAP"
  echo "feat_carplay=$(yesno k_feat com.hkmc.software.connectivity.carplay_wireless)"
  echo "feat_aa=$(yesno k_feat com.hkmc.software.connectivity.androidauto_wireless)"
  # 칩 전원이 달린 순정 핫스팟 기능(HMG-API가 공식 모드의 요청으로 켬)
  echo "feat_hotspot=$(yesno k_feat com.hkmc.software.wifihotspot)"
  echo "feat_wifi=$(yesno k_feat android.hardware.wifi)"
  echo "chip=$K_CHIP"
  echo "wlan0=$K_WLAN"
  # HMG-API 프로젝션 AP: 요청됨(state/wifi.txt), 이번 부팅에 띄움(ap.boot)·못 띄움(ap.fail), 지금 hostapd가 돎, 어느 SSID로 떴는지
  echo "proj=$K_PROJ"
  echo "ap_boot=$K_APBOOT"
  echo "ap_fail=$K_APFAIL"
  echo "ap=$K_AP"
  echo "ap_mode=$K_APMODE"
  echo "other_ap=$K_FOREIGN"
  echo "wpa=$K_WPA"
  echo "cp_conn=$K_CP"
  # 설치 진행 상태(run·done·reboot·fail, 없으면 none)
  _ps=$($BB awk -F= '$1 == "state" { print $2 }' $PROG 2>/dev/null); echo "state=${_ps:-none}"
  echo "made=$(date '+%Y-%m-%d %H:%M')"
  # 판정 결과(앱이 그대로 보인다)
  echo "verdict=$V_CODE"
  echo "verdict_lv=$V_LV"
  echo "verdict_msg=$V_MSG"
  echo "verdict_end=$V_END"
  echo "s1=$V_S1"
  echo "s2=$V_S2"
  echo "s3=$V_S3"
}
# ap.log에 한 줄. 감시자에서 쓴다. 시계가 맞기 전이면 시각 대신 "부팅 직후"(lib.sh log_ts)
aplog() { log_ts; echo "$_LT $*" 2>/dev/null >> $APLOG; }
# [지금 재부팅] 요청($RBREQ, lib.sh)을 하나 받는다. 재부팅해도 되면 0. 받으면 바로 지운다.
# 하지 않는 경우(모두 ap.log에 이유 한 줄): 이전 부팅·이미 받은 요청(reboot.last)·깨진 값, 40초(NX4_RB_MAX)보다 오래됨·나이를 모름,
# 이번 부팅 설치 진행 기록이 설치 중(state=run, USB 설치기가 씀), HMG-API 부팅 보호에 걸릴 때, /system을 바꾸는 작업
# (HMG-API 적용·remount 등)이 돌고 있음. 감시자만 부른다.
# 받지 않은 재부팅 요청·돌아온 재부팅 명령의 결과를 앱이 읽게 남긴다(644, 비밀값 없음, 요청 id를 읽었을 때만).
# 앱은 RB_WAIT(80초)를 다 기다리지 않고 이유에 맞는 문구를 보인다. RESET 안내는 명령이 돌아왔을 때(cmd)·모르는 코드·아무도 답하지
# 않을 때(감시자 없음), 그리고 설치 중·바깥 작업(install·sysw) 거절이 RB_STUCK_MAX(3)번 넘게 이어질 때(앱이 셈).
# 버튼은 늘 보이므로 "재부팅 필요"(state=reboot)일 때만 받지 않는다. /system이 rw인지는 보지 않는다(설치 직후 rw로 남을 수 있음).
# 설치기의 쓰기는 설치 중(run)과 /system 작업 확인(sysw)으로 막는다.
# code: install 설치 중 · sysw 바깥 /system 작업 · guard HMG-API 부팅 보호(2분 전) ·
#       (fix 설치 마무리 중: 2.0.x 서비스의 것. 2.1.0은 쓰지 않지만 앱은 그대로 읽는다) ·
#       old 오래됐거나 나이를 모름 · bad 이번 부팅의 새 요청이 아님 · cmd 재부팅 명령이 돌아왔거나 끝나지 않음
RBRES=${RBRES:-/data/local/tmp/nx4-kor-reboot-result.txt}
rb_result() {
  [ -n "$RQ_ID" ] || return 0
  umask 022
  { echo "id=$RQ_ID"; echo "boot=$(cat ${BOOT_ID:-/proc/sys/kernel/random/boot_id} 2>/dev/null)"; echo "code=$1"; } 2>/dev/null > $RBRES.tmp \
    && $BB chmod 644 $RBRES.tmp 2>/dev/null && $BB mv -f $RBRES.tmp $RBRES 2>/dev/null
  umask 077
  return 0
}
take_rbreq() {
  if ! req_peek $RBREQ $W/reboot.last; then
    # req_peek이 읽은 내용만 다룬다(그 뒤 막 들어온 새 요청을 지우지 않게, req_drop). 못 읽었으면(파일 없음) 할 일 없음.
    if [ -n "$RQ_RAW" ]; then
      # 지우지 못해 같은 파일이 남아도 1초마다 줄을 쌓지 않게, 같은 내용은 한 번만 기록한다
      if [ "$RQ_RAW" != "$(cat $W/reboot.bad 2>/dev/null)" ]; then
        echo "$RQ_RAW" > $W/reboot.bad
        aplog "재부팅 요청 거절: 이번 부팅의 새 요청이 아님(이전 부팅·이미 받은 요청·깨진 값)"
        rb_result bad
      fi
      req_drop $RBREQ
    fi
    return 1
  fi
  req_drop $RBREQ
  echo "$RQ_ID" > $W/reboot.last
  _un=$(up_s)
  case "$_un" in ''|*[!0-9]*) aplog "재부팅 요청 거절: 요청 나이를 알 수 없음"; rb_result old; return 1 ;; esac
  # 한도 40초. 앱의 실패 판정(RB_WAIT 80초)은 이 40초 + sync + 재부팅 명령 기다림 30초보다 길다. 나이가 음수(앞으로 온 요청)도 받지 않는다
  _ra=$((_un - RQ_EL))
  [ $_ra -ge 0 ] || { aplog "재부팅 요청 거절: 요청 시각이 지금보다 뒤임($_ra초)"; rb_result old; return 1; }
  [ $_ra -le ${NX4_RB_MAX:-40} ] || { aplog "재부팅 요청 거절: 오래된 요청(${_ra}초)"; rb_result old; return 1; }
  # 이번 부팅 설치 진행 기록이 run이어도, 마지막으로 쓴 지(ut, 부팅 뒤 초) RB_STALE초(900, 앱의 STALE과 같음)가
  # 넘었으면 멈춘 기록으로 보고 이 이유로는 막지 않는다(HMG-API 적용이 아직 돌면 아래 sysw로 막는다). ut가 없거나 숫자가 아니어도
  # 멈춘 기록으로 본다(버튼이 끝없이 "잠시 뒤 다시"만 내지 않게)
  if $BB grep -q '^state=run$' $PROG 2>/dev/null \
      && [ "$($BB awk -F= '$1 == "boot" { print $2 }' $PROG 2>/dev/null)" = "$(boot_id)" ]; then
    _put=$($BB awk -F= '$1 == "ut" { print $2 }' $PROG 2>/dev/null)
    case "$_put" in
      ''|*[!0-9]*) aplog "설치 진행 기록이 run인데 마지막 시각을 모름: 멈춘 기록으로 보고 설치 중으로는 막지 않음" ;;
      *) if [ $((_un - _put)) -le ${RB_STALE:-900} ]; then
           aplog "재부팅 요청 거절: 설치가 아직 진행 중(이번 부팅 설치 진행 기록 run)"
           rb_result install
           return 1
         fi
         aplog "설치 진행 기록이 run인 채 $((_un - _put))초 그대로: 멈춘 기록으로 보고 설치 중으로는 막지 않음" ;;
    esac
  fi
  # HMG-API watcher가 starts를 0으로 되돌리기 전에 다시 부팅하면 쌓여, 지금 값이 2·3이면 다음(또는 그다음) 시작에 훅이
  # 꺼진다. 앱은 root 파일 starts를 읽을 수 없어 root가 거절한다(code=guard, 앱은 "2~5분 뒤에"). 4 이상(이미 꺼짐)·못 읽음이면 막지 않는다.
  # watcher는 커널 부팅이 아니라 zygote 시작 뒤 GUARD_DELAY(120)초에 돈다(zygote.c start_watcher). 그래서 이번 부팅의
  # 마지막 "hooks on" 줄 커널 시각 + 120 + 여유 15초까지 막고, 그 줄이 없으면 부팅 뒤 300초까지 막는다(늘 끝이 있다). watcher가
  # 돌아 starts가 0·1이 되면 바로 풀린다
  # 10장 확인 리뷰 1: HMG-API가 설치돼 있지 않거나(--purge 없이 지워 starts가 남은 차) 이번 부팅 zygote 줄이 off·guard(disable 파일,
  # 이미 꺼짐)면 막지 않는다. 줄이 없으면 enable이 있고 disable이 없을 때만 본다(그래야 starts가 실제로 올라간다)
  _gst=$(hook_starts); zygote_info; _garm=no
  if [ -n "$(hmg_ver)" ]; then
    case "$ZH" in
      on) _garm=yes ;;
      '') hook_armed && _garm=yes ;;
    esac
  fi
  if [ -n "$ZON" ]; then _gend=$((ZON + ${NX4_GUARD_DELAY:-120} + 15)); else _gend=300; fi
  if [ $_garm = yes ] && [ -n "$_gst" ] && [ "$_gst" -ge 2 ] && [ "$_gst" -le 3 ] && [ "$_un" -lt $_gend ]; then
    aplog "재부팅 요청 거절: 부팅 뒤 ${_un}초(HMG-API 시작 확인 시각 ${_gend}초 전)이고 HMG-API 부팅 보호 횟수 starts=$_gst(3분 안에 재부팅을 반복하면 훅이 꺼짐)"
    rb_result guard
    return 1
  fi
  # 우리 밖에서 /system을 바꾸는 작업이 돌면 막는다(앱 문구는 "설정을 마무리하는 중"과 같은 fix)
  # 외부 작업 거절은 code=sysw(앱은 "마무리하는 중", 같은 이유가 이어지면 RESET 안내로 넘김)
  if sys_writer_busy; then aplog "재부팅 요청 거절: 시스템 영역을 바꾸는 작업이 도는 중($SYSW)"; rb_result sysw; return 1; fi
  return 0
}
# rw 확인을 뺀 대신, /system을 바꾸는 우리 밖의 프로세스가 지금 도는지 /proc/<pid>/cmdline으로 본다(ps는 80칸에서 잘림).
# 이름의 근거:
#   - HMG-API 엔진은 데몬이 "app_process /system/bin hmgapi.engine.Engine <op>"로 띄운다(HMG-API 포크 core/hmgapid/hmgapid.c
#     op_engine). 앱의 Apply changes도 데몬을 거친다(README의 hmgapi.app ops). /system을 바꾸는 op는 apply·restore·recover.
#   - /system remount는 "hmgapid remount rw|ro"(같은 파일 op_remount).
#   - HMG-API 부팅 스크립트(install/common/boot.sh)가 부팅마다 "sh /data/hmgapi/hook-check.sh"를 돌린다(remount rw → 쓰기 → ro).
#     엔진 update-hmgapi도 HMG-API 파일을 바꾼다.
# 빈 명령줄(커널 스레드)은 건너뛴다. 명령줄을 하나도 못 읽으면(busybox 1.8.1 tr이 NUL을 못 다루는 등) $PS로 한 번 더
# 본다(엔진 apply 명령줄은 약 60자라 ps의 80칸 안). 그래도 판단이 안 되면 막지 않고 로그만 남긴다(설치기의 쓰기는 진행 기록 run이
# 따로 막는다. 막는 쪽으로 두면 버튼이 영영 "마무리하는 중"만 보인다). SYSW에 찾은 것을 둔다.
sys_writer_busy() {
  SYSW=; _sn=0
  # pcmd를 믿을 수 없으면(명령줄이 잘리거나 붙음) /proc 판정을 쓰지 않고 바로 ps로 본다
  pcmd_ok || aplog "재부팅 요청: 프로세스 명령줄이 잘려 읽힘(tr). ps로 확인함"
  pcmd_ok && for _sd in $PROC/[0-9]*; do
    [ -d "$_sd" ] || continue
    _sp=${_sd##*/}
    [ "$_sp" = "$$" ] && continue
    _sc=" $(pcmd $_sp) "
    [ "$_sc" = "  " ] && continue
    _sn=$((_sn + 1))
    sysw_match "$_sc" && return 0
  done
  [ $_sn -gt 0 ] && return 1
  # 명령줄을 하나도 못 읽음: ps로 한 번 더(한 줄씩, 줄 끝에 빈칸을 붙여 같은 꼴로 비교)
  # (here-doc은 mksh가 임시 파일을 써야 해서 피하고, 줄바꿈으로 나눈다. ps 줄에 * 가 있어도 펼치지 않게 set -f)
  _sn=0; _pso=$($PS 2>/dev/null); _ifs=$IFS; IFS='
'; set -f
  for _sl in $_pso; do
    _sn=$((_sn + 1))
    if sysw_match " $_sl "; then IFS=$_ifs; set +f; return 0; fi
  done
  IFS=$_ifs; set +f
  [ $_sn -gt 1 ] && return 1
  aplog "재부팅 요청: 프로세스 명령줄을 읽지 못함(/proc·ps 모두). 막지 않음(설치기의 쓰기는 설치 진행 기록으로 막음)"
  return 1
}
# 명령줄 하나($1, 앞뒤 빈칸)가 /system을 바꾸는 작업인가. 찾으면 SYSW에 이름
sysw_match() {
  case "$1" in
    *" hmgapi.engine.Engine apply "*|*" hmgapi.engine.Engine restore "*|*" hmgapi.engine.Engine recover "*|*" hmgapi.engine.Engine update-hmgapi "*) SYSW="HMG-API 적용"; return 0 ;;
    *"hmgapid remount "*) SYSW="remount"; return 0 ;;
    *"hook-check.sh "*) SYSW="HMG-API 부팅 훅 확인"; return 0 ;;
  esac
  return 1
}
# 감시자: 상태 화면이 열릴 때(launch) 띄운다. 1초마다 재부팅 요청을 본다.
# 끝나는 조건: watch.until(부팅 뒤 초, launch가 "지금+WATCH_SECS"로 씀)이 지남. 화면을 다시 열면 늘어난다.
# 그 값을 읽지 못하거나 숫자가 아니면 바로 끝난다.
# 한 번에 하나만: watch.lock 폴더(mkdir은 한 번에 하나만 성공)와 watch.pid "<pid> <boot_id>". 잠금이 있는데 1초 뒤에도
# 살아 있는 감시자가 없으면(지난 부팅·죽은 감시자) 지우고 다시 잡는다. 상태 파일·앱 설치보다 먼저 돈다(시작이 늦지 않게).
# 감시자가 끝나는 시각(부팅 뒤 초)을 앱이 읽는 파일로 남긴다(644, 부팅 id·초뿐). 버튼은 늘 보이지만 감시자는
# 화면을 연 뒤 10분만 산다: 그 뒤 누르면 앱이 요청을 보내지 않고 "화면을 다시 연 뒤"라고 바로 알린다. 감시자가 끝날 때도 그 시각으로 씀
WATCHF=${WATCHF:-/data/local/tmp/nx4-kor-watch.txt}
watch_pub() {
  ( umask 022
    { echo "boot=$(cat ${BOOT_ID:-/proc/sys/kernel/random/boot_id} 2>/dev/null)"; echo "until=$1"; } > $WATCHF.tmp \
      && $BB chmod 644 $WATCHF.tmp && $BB mv -f $WATCHF.tmp $WATCHF ) 2>/dev/null
  return 0
}
if [ "$1" = --watch ]; then
  if ! $BB mkdir $W/watch.lock 2>/dev/null; then
    sleep 1
    st_alive $W/watch.pid --watch && exit 0
    rm -rf $W/watch.lock
    $BB mkdir $W/watch.lock 2>/dev/null || exit 0
  fi
  # 1초 반복에서 하위 셸을 줄인다. 끝 시각·부팅 뒤 초는 read로 읽고(up_s의 awk와 같은 정수 초), 요청 파일은
  # 있을 때만 본다(없으면 받는 함수가 할 일이 없다). 부팅 id는 요청을 받을 때마다 그대로 읽는다(못 읽으면 거절, 재리뷰)
  _me="$$ $(cat ${BOOT_ID:-/proc/sys/kernel/random/boot_id} 2>/dev/null)"
  echo "$_me" > $W/watch.pid
  # 새 감시자는 시작할 때 지금 끝 시각을 다시 쓴다(옛 감시자가 끝나며 덮었더라도 바로 맞게)
  _wu=; { read _wu < $W/watch.until; } 2>/dev/null; case "$_wu" in ''|*[!0-9]*) : ;; *) watch_pub $_wu ;; esac
  while :; do
    _wu=; _wn=
    { read _wu < $W/watch.until; } 2>/dev/null
    { read _wn _wx < $UPTIME; } 2>/dev/null; _wn=${_wn%%.*}
    case "$_wu" in ''|*[!0-9]*) break ;; esac
    case "$_wn" in ''|*[!0-9]*) break ;; esac
    if [ "$_wn" -ge "$_wu" ]; then
      # 끝내기 전에 1초 뒤 한 번 더 읽는다. 상태 화면이 막 늘렸으면(이 감시자가 살아 있다고 보고 새로 띄우지 않음) 계속
      sleep 1
      _wu=; { read _wu < $W/watch.until; } 2>/dev/null; { read _wn _wx < $UPTIME; } 2>/dev/null; _wn=${_wn%%.*}
      case "$_wu" in ''|*[!0-9]*) break ;; esac
      case "$_wn" in ''|*[!0-9]*) break ;; esac
      [ "$_wn" -lt "$_wu" ] || break
    fi
    # 재부팅 요청을 본다. 재부팅이 되면 이 셸도 함께 끝난다.
    # 남는 잠금(watch.lock)은 다음 부팅의 감시자가 "지난 부팅 것"으로 보고 지운다. 명령이 돌아오면(실패) 기록하고 계속 감시한다.
    if [ -f $RBREQ ] && take_rbreq; then
      aplog "상태 화면에서 재부팅 요청: 지금 재부팅함(sync 뒤 reboot)"
      # NX4_SYNC는 PC 시험용(NX4_REBOOT처럼). 차에서는 sync
      ${NX4_SYNC:-sync}
      # 검사와 재부팅 사이(특히 sync가 길 때) 시스템 영역을 바꾸는 작업이 새로 시작했으면 지금 거절한다
      if sys_writer_busy; then
        aplog "재부팅 요청 거절: sync 뒤 다시 보니 시스템 영역을 바꾸는 작업이 시작됨($SYSW)"
        rb_result sysw
      else
      # reboot 명령이 돌아오지 않을 수 있다(4.4 toolbox reboot은 sys.powerctl 뒤 기다릴 수 있음). 뒤에서 띄우고
      # NX4_RB_WAIT초(기본 30)만 기다린다. 끝나는 조건: 명령이 끝남 또는 시간. 그 뒤 기록하고 감시를 계속한다.
      # 끝났는지는 하위 셸이 남기는 reboot.rc(종료 코드)로 본다. kill -0은 끝난 자식(좀비)에도 성공해 쓸 수 없다(PC 시험에서 확인).
      rm -f $W/reboot.rc
      ( ${NX4_REBOOT:-/system/bin/reboot} </dev/null >/dev/null 2>&1; echo $? > $W/reboot.rc ) &
      _rw=0
      while [ ! -s $W/reboot.rc ] && [ $_rw -lt ${NX4_RB_WAIT:-30} ]; do sleep 1; _rw=$((_rw+1)); done
      if [ -s $W/reboot.rc ]; then
        aplog "재부팅 명령이 끝났지만 재부팅되지 않음(종료 코드 $(cat $W/reboot.rc 2>/dev/null))"
      else
        aplog "재부팅 명령이 ${NX4_RB_WAIT:-30}초 안에 끝나지 않음(아직 재부팅되지 않음)"
      fi
      rb_result cmd
      fi
    fi
    sleep 1
  done
  # 끝내기로 정한 뒤 상태 화면이 끝 시각을 늘렸으면, 그 상태 화면 갱신은 이 감시자가 살아 있다고 보고 새로 띄우지
  # 않았다. 그래서 끝 시각을 watch.pid를 지우기 전과 잠금을 푼 뒤 두 번 보고, 어느 쪽이든 늘어났으면 새 감시자를 **한 번만** 띄운다
  # (띄우는 곳은 아래 한 줄뿐). 부팅 뒤 초를 못 읽으면 띄우지 않는다(못 읽어 0으로 보면 끝 시각이 늘 커 보여 끝없이 띄우게 됨).
  # 새 감시자는 그 끝 시각에 끝나고, 그때 다시 볼 때는 늘어나지 않았으므로 또 띄우지 않는다
  _again=0
  watch_more() {
    _wu2=; _wn2=
    { read _wu2 < $W/watch.until; } 2>/dev/null
    { read _wn2 _wx < $UPTIME; } 2>/dev/null; _wn2=${_wn2%%.*}
    case "$_wu2" in ''|*[!0-9]*) return 1 ;; esac
    case "$_wn2" in ''|*[!0-9]*) return 1 ;; esac
    [ "$_wu2" -gt "$_wn2" ]
  }
  watch_more && _again=1
  [ "$(cat $W/watch.pid 2>/dev/null)" = "$_me" ] && rm -f $W/watch.pid
  rm -rf $W/watch.lock
  # 앱이 "감시자 끝남"을 알게 지금 시각으로 쓴다(못 읽으면 0). 그 사이 상태 화면이 새 끝 시각을 썼으면(이 감시자가 본 마지막
  # 값과 다름: 새 감시자가 뜸) 덮지 않는다
  _wn=; { read _wn _wx < $UPTIME; } 2>/dev/null; _wn=${_wn%%.*}; case "$_wn" in ''|*[!0-9]*) _wn=0 ;; esac
  _wf=; [ -f $WATCHF ] && _wf=$($BB awk -F= '$1 == "until" { print $2 }' $WATCHF 2>/dev/null)
  [ -z "$_wf" ] || [ "$_wf" = "$_wu" ] && watch_pub $_wn
  [ $_again = 1 ] || { watch_more && _again=1; }
  [ $_again = 1 ] && { BB=$BB $BB setsid sh $APP/bin/status.sh --watch </dev/null >/dev/null 2>&1 & }
  exit 0
fi

# 하위 셸 없이 이 셸에서 쓴다(그래야 끝의 한 줄 요약이 방금 구한 값 K_*를 다시 쓸 수 있다: softap.conf·연결 수·AP 판정을
# 두 번 구하지 않음). 상태 파일만 644로 만들고 umask는 되돌린다. parse_conf가 위치 인자를 바꾸지만 이 뒤에는 $1을 쓰지 않는다.
# 이 셸에서 바로 돈다. status_kv 안에 $(( ))를 넣을 때는 값이 숫자인지 먼저 확인하세요(틀린 산술은 상태 화면 갱신 전체를 끝냄)
umask 022
status_kv 2>/dev/null > $STATUS.tmp && $BB chmod 644 $STATUS.tmp && $BB mv -f $STATUS.tmp $STATUS
umask 077

# 감시자를 띄운다. 이미 살아 있으면 끝나는 시각만 늘린다. 설치 대기(--wait)가 끝났을 때도 지금부터 10분 동안 띄운다
# ([지금 재부팅]이 늘 보이므로, 설치 중 화면을 연 뒤 10분이 지나 버튼이 안 듣는 일이 없게).
# RPT_SYNC=1(PC 테스트)이면 띄우지 않는다(테스트가 --watch를 직접 부른다).
if [ "${RPT_SYNC:-0}" != 1 ]; then
  _wn=$(up_s)
  case "$_wn" in
    ''|*[!0-9]*) : ;;
    # 임시 파일에 쓴 뒤 이름을 바꾼다: 감시자가 1초마다 읽으므로 ">"로 바로 쓰면 비운 순간을 읽고 "값 없음"으로 끝날 수 있다
    # (PC 시험에서 화면을 다시 열 때 재현, 2026-11-10)
    *) echo $((_wn + ${WATCH_SECS:-600})) > $W/watch.until.tmp && $BB mv -f $W/watch.until.tmp $W/watch.until
       watch_pub $((_wn + ${WATCH_SECS:-600}))
       st_alive $W/watch.pid --watch || BB=$BB $BB setsid sh $APP/bin/status.sh --watch </dev/null >/dev/null 2>&1 & ;;
  esac
fi

# 설치가 아직 진행 중이면 끝난 뒤에 한 번 더 돌도록 뒤에 남긴다(한 번에 하나만, 이번 부팅의 것만)
if [ $WAITED = 0 ] && $BB grep -q '^state=run$' $PROG 2>/dev/null; then
  # wait.pid도 "<pid> <boot_id>"로 쓰고 st_alive로 본다(지난 부팅의 같은 pid를 살아 있는 것으로 보지 않게)
  if ! st_alive $W/wait.pid --wait; then
    BB=$BB $BB setsid sh $APP/bin/status.sh --wait </dev/null >/dev/null 2>&1 &
    echo "$! ${BID:-$(cat ${BOOT_ID:-/proc/sys/kernel/random/boot_id} 2>/dev/null)}" > $W/wait.pid
  fi
fi
# 상태와 저장 진행은 이어서 열리는 화면(StatusActivity)이 보여 준다. 토스트는 쓰지 않는다.
# 표준출력에는 한 줄 요약을 남긴다(launch 서비스 기록·테스트용).
# 상태 파일을 쓸 때 구한 값(st_collect·st_verdict)을 다시 쓴다
a=꺼짐; [ "$K_AP" = yes ] && a=켜짐
echo "NX4 KOR: 무선 연결용 Wi-Fi $a, 카플레이 연결 ${K_CP:-0}개, 판정 $V_CODE"
exit 0
