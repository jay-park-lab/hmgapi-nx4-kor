#!/system/bin/sh
# NX4 KOR 상태: 상태 화면 앱(io.github.jayparklab.nx4kor)이 읽는 상태 파일을 쓴다.
# 앱이 열릴 때 hmgapid service-start launch → svc/launch.sh가 이 스크립트를 root로 부른다.
#   (인자 없음) 상태 파일을 쓰고, 재부팅 요청을 받는 감시자(--watch)를 10분 동안 띄운다.
#   --wait      설치가 진행 중이면 끝날 때까지(최대 15분) 기다렸다가 상태 파일을 다시 쓴다.
#   --watch     상태 화면의 [지금 재부팅] 요청을 받는다.
# 상태 파일에는 이름, 버전, 예/아니요, 개수, 길이만 넣는다(SSID, 비밀번호, 휴대폰 이름, MAC, IP 없음).
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
# busybox는 hotspot.sh가 고른다(내비의 것, 없으면 모드에 함께 넣은 것)
APP=${APP:-/data/hmgapi/mods/nx4-kor}
# Wi-Fi 장치 이름(hotspot.sh와 같은 기본값). 문구 속 "wlan0" 글자는 그대로 둔다
WIF=${WIF:-wlan0}
HOTSPOT_LIB=1 . $APP/svc/hotspot.sh
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

# 무선 카플레이 AP를 누가 띄웠는가. ours: 우리 hostapd, stock: 순정이 카플레이 SSID로 띄움(hotspot.sh stock_ssid),
# none: 둘 다 아님. parse_conf를 먼저 부른다. 첫 인자로 이미 구한 stock_ssid 값을 받을 수 있다.
ap_mode() {
  if running "hostapd $CONF"; then echo ours
  elif [ "${1:-$(stock_ssid)}" = carplay ]; then echo stock
  else echo none; fi
}
# 서비스 기록 위치(hotspot.sh에도 같은 기본값이 있다). 여기서는 그대로 다시 정한다(PC 테스트가 이 줄의 경로를 바꾼다)
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
# /data/local/tmp 바로 아래에 둔다. 값은 예/아니요·버전·개수·길이뿐이다 (SSID, 비밀번호, 휴대폰 이름, MAC, IP 없음).
STATUS=${STATUS:-/data/local/tmp/nx4-kor-status.txt}
yesno() { if "$@" >/dev/null 2>&1; then echo yes; else echo no; fi; }
# 이 모드의 상태는 HMG-API 자기 파일로 본다. /data/hmgapi/mods/<id>/.disabled: 꺼짐,
# /data/hmgapi/settings/<id>.json의 "bridge":false: 무선 카플레이(블루투스 브리지) 설정 꺼짐 (Mods.java, settings.json)
HMGMOD=${HMGMOD:-$HMGDATA/mods/$MOD_ID}
HMGSET=${HMGSET:-$HMGDATA/settings/$MOD_ID.json}
# mod_on은 "꺼 두지 않았다"는 뜻일 뿐이다. HMG-API가 충돌·미지원으로 건너뛴 경우는 훅·무선 기능 값으로 드러난다.
# bridge는 저장된 설정 값이라 적용(Apply changes) 전에는 실제 동작과 다를 수 있다.
mod_on_state() { if [ -f $HMGMOD/mod.json ] && [ ! -f $HMGMOD/.disabled ]; then echo yes; else echo no; fi; }
bridge_state() { if $BB grep -q '"bridge" *: *false' $HMGSET 2>/dev/null; then echo off; else echo on; fi; }
# HMG-API가 부팅 때마다 남기는 "hook map: <상태> for …, hooks on|off" 줄 중 마지막 것 (log.log.1이 더 오래됨).
# 출력: "on|off <상태>" (상태: none, mismatch, mapped, verified 등). 줄이 없으면 빈 값.
# 이번 부팅의 줄을 놓치면 지난 부팅 기록일 수 있다(HMG-API 로그는 logcat에서 옮겨 적는다).
# map-check.json은 HMG-API 업데이트로 map이 바뀌어도 ok로 남을 수 있어 로그를 본다.
HMGLOG=${HMGLOG:-/data/hmgapi/logs/hmgapi}
# 이 모드의 훅이 실제로 켜졌는가. HMG-API는 모드가 선언한 훅 지점이 하나라도 그 차 map에 없으면 그 모드의 훅을
# 통째로 끄고 "mods: nx4-kor not loaded: <이유>"를 남긴다. 켜지면 "mods: loaded nx4-kor <판>".
# 두 로그 파일에서 마지막 줄로 판단한다.
# 출력: "on", "off <이유>", 또는 빈 값(기록 없음). 이유는 HMG-API가 남긴 영문 그대로(지점 이름뿐, 개인정보 없음), 200자까지.
# 무선 모드 훅(modhooks)과 HMG-API 훅(hooks) 기록을 HMG-API 로그를 한 번만 읽어 함께 구한다(예전에는 두 번 끝까지 읽음).
# _MH: "on", "off <이유>"(200자까지) 또는 빈 값. _HK: "on|off <상태>" 또는 빈 값.
hmg_hooks_load() {
  [ "$HK_LOADED" = 1 ] && return 0
  HK_LOADED=1
  _hh=$($BB cat $HMGLOG/log.log.1 $HMGLOG/log.log 2>/dev/null | $BB awk -v id="$MOD_ID" '
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
modhooks_state() { hmg_hooks_load; echo "$_MH"; }
# --- HMG-API 부팅 보호(boot guard) 알리기(읽기만, 값을 되돌리거나 HMG-API 파일을 쓰지 않음) ---
# 근거(HMG-API 포크 core/zygote/zygote.c): zygote가 시작할 때마다 /data/hmgapi/hook/starts를 1 올리고(bump_starts, 올리기 전 값을
# 돌려줌) 그 값이 MAXSTARTS(3) 이상이면 그 시작의 훅을 모두 끄고 커널 로그에 "hmgapi-hook: zygote, hooks off (boot guard, starts=N)"을
# 남긴다. 훅이 켜지면 "…, hooks on, start N"이고, GUARD_DELAY(120)초 뒤 zygote가 살아 있으면 watcher가 0으로 되돌린다.
# 그래서 지금 읽은 값(올린 뒤 값)이 4 이상이면 이번 시작은 훅이 꺼진 것이다(3이면 아직 켜진 시작 3번째: 2분 안에 또 재부팅하면 꺼짐).
# 0으로 되돌리는 것은 훅이 켜진 부팅의 watcher와 HMG-API 설치(install.sh: echo 0 > hook/starts)뿐이다.
HOOKSTARTS=${HOOKSTARTS:-/data/hmgapi/hook/starts}
# starts 값(숫자). 못 읽으면 빈 값
hook_starts() { _hs=; { read _hs < $HOOKSTARTS; } 2>/dev/null; case "$_hs" in ''|*[!0-9]*) _hs= ;; esac; echo "$_hs"; }
# 10장 확인 리뷰 2: zygote.c는 hook/enable이 있고 hook/disable이 없을 때만 훅을 켜고 starts를 올린다. 둘 중 하나라도 어긋나면 starts는
# 멈춘 옛 값이라 판정·거절에 쓰지 않는다. HOOKDIR는 starts 파일이 있는 폴더(PC 시험은 HOOKSTARTS로 바꿈)
HOOKDIR=${HOOKDIR:-${HOOKSTARTS%/*}}
hook_armed() { [ -f $HOOKDIR/enable ] && [ ! -f $HOOKDIR/disable ]; }
# HMG-API 설치 판(installed.txt의 version). 설치돼 있지 않으면 빈 값
hmg_ver() { $BB awk '$1 == "version" { print $2; exit }' ${HMGINST:-/data/hmgapi/installed.txt} 2>/dev/null; }
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
hooks_state() { hmg_hooks_load; echo "$_HK"; }

# --- 판정은 한 곳에서 ---
# st_collect가 판정에 쓰는 값을 한 번만 구하고(K_*), st_verdict가 차례대로 판정해 V_*에 둔다. 상태 파일(status_kv)에 쓰고,
# 상태 화면 앱은 상태 파일의 verdict·verdict_lv·verdict_msg를 그대로 보인다.
# 판정 순서: HMG-API 부팅 보호 → 설치 중 → 이 모드의 차가 아님 → HMG-API → Wi-Fi 부품·칩(근거 있는 끝) → Wi-Fi 확인 중 →
# 따로 설치된 무선 모드 → 다른 Wi-Fi 패키지 → 재부팅 필요 → 적용 거절·설정 실패 → 모드·설정·훅 → 무선 기능 → Wi-Fi·핫스팟 → 연결·준비됨.
st_collect() {
  [ "$SC_DONE" = 1 ] && return 0
  SC_DONE=1
  K_PROD=$(getprop ro.build.product)
  K_FEATS="$(pm list features 2>/dev/null)
"
  parse_conf $SRC
  K_HMG=$(echo $($BB grep -E '^(version|build) ' ${HMGINST:-/data/hmgapi/installed.txt} 2>/dev/null))
  _kv=${K_HMG#*version }; [ "$_kv" = "$K_HMG" ] && _kv=; K_HMGV=${_kv%% *}
  K_MODON=$(mod_on_state); K_BRIDGE=$(bridge_state); K_DONE=$(yesno setup_done)
  K_OLDMOD=$(yesno [ -f $HMGDATA/mods/$OLD_MOD/mod.json ])
  hmg_hooks_load; K_MH=${_MH%% *}; K_HK=${_HK%% *}; K_HKMAP=${_HK#* }
  K_OURAP=$(yesno running "hostapd $CONF"); K_DHCP=$(yesno our_dhcp_on)
  K_OTHER=$(yesno stock_ap_on); K_SSID=$(stock_ssid); K_APMODE=$(ap_mode $K_SSID)
  K_CP=$(cp_count); K_NOWLAN=$(yesno nowlan_now)
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
  K_AAOK=no; K_AARDY=no; K_AAWAIT=no
  if [ "$($BB awk -F= '$1 == "boot" { print $2 }' $HINT 2>/dev/null)" = "$(cat ${BOOT_ID:-/proc/sys/kernel/random/boot_id} 2>/dev/null)" ]; then
    # 차의 busybox 1.8.1 grep에는 -x가 없다: 줄 전체 비교는 셸로 한다(hotspot.sh has_line)
    # 무선 AA 연결은 우리 hostapd가 돌 때만 연결로 본다(서비스가 끊김 줄을 놓쳐 aa=ok가 남아도 핫스팟 꺼짐 판정이 가려지지 않게)
    [ "$K_OURAP" = yes ] && has_line 'aa=ok' $HINT && K_AAOK=yes
    # 카플레이가 연결되어 있어 AA가 기다리는 중(aa=cpwait, 상태 화면 노란 줄)
    has_line 'aa=cpwait' $HINT && K_AAWAIT=yes
    # 무선 안드로이드 오토 신호가 켜졌는가(서비스가 aa_ready에 켠 시각을 씀, 이번 부팅 것만)
    $BB grep -q '^aa_ready=[0-9][0-9]*$' $HINT 2>/dev/null && K_AARDY=yes
  fi
  # wlan0이 안 생긴 부팅 수(hotspot.sh nowlan_boot_count)
  K_NLB=0; [ -f $BK/nowlan.boots ] && read K_NLB _x < $BK/nowlan.boots; case "$K_NLB" in ''|*[!0-9]*) K_NLB=0 ;; esac
  # 이번 부팅의 설치 진행 기록(지난 부팅 것은 빈 값)
  K_PST=; K_PSTAGE=
  if [ "$($BB awk -F= '$1 == "boot" { print $2 }' $PROG 2>/dev/null)" = "$(cat ${BOOT_ID:-/proc/sys/kernel/random/boot_id} 2>/dev/null)" ]; then
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
  # 지금 폰이 연결돼 있는가(카플레이 연결 수 또는 이번 부팅 무선 AA 연결). 연결 중이면 핫스팟·Wi-Fi 꺼짐 판정을 내지 않는다
  _vconn=no; { [ "${K_CP:-0}" != 0 ] || [ "$K_AAOK" = yes ]; } && _vconn=yes
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
  # 기록이 있어도 지금 칩이 보이거나 무선 기능이 이미 적용돼 있으면(다른 앱으로 Wi-Fi를 켠 차 등) "안 됨"으로 보지 않는다
  elif [ -f $BK/wifi.nopart ] && [ "$K_DONE" = no ] && ! wifi_chip_seen; then _vs nopart 2 "$NOPART_MSG"; V_END=yes
  elif [ -f $BK/wifi.nochip ] && [ "$K_DONE" = no ] && ! wifi_chip_seen; then _vs nochip 2 "$NOCHIP_MSG"; V_END=yes
  elif [ "$K_DONE" = no ] && [ -f $BK/wifi.wake ] && [ ! -f $BK/wifi.woke ] && ! wifi_chip_seen \
      && wake_count && [ "$_wbad" = 0 ] && [ "$_wc" -lt "$WAKE_BOOTS" ]; then
    # 아직 깨울 횟수가 남았을 때만(칩을 한 번 본 차·횟수를 다 쓴 차는 원래 판정으로)
    _vs wificheck 1 "$WIFI_CHECK_MSG (확인 $_wc/$WAKE_BOOTS)"
  elif [ "$K_OLDMOD" = yes ]; then _vs oldmod 2 "$OLDMOD_MSG"
  elif [ "$K_OURAP" = no ] && [ "${K_CP:-0}" = 0 ] && [ "$K_AAOK" = no ] && foreign_hostapd; then
    # 우리 것도 순정(netd)도 아닌 hostapd(USB 동글 패키지 등)가 실제로 돌고, 연결도 없음. 순정 설정을 못 읽어
    # stock_ssid가 unknown인 경우(순정 카플레이 AP 차 등)는 여기로 오지 않는다
    _vs otherwifi 2 "다른 Wi-Fi 패키지가 핫스팟을 쓰고 있어 함께 쓸 수 없습니다. 그 패키지를 지운 뒤 내비를 재부팅해 주세요."
  elif [ "$K_PST" = reboot ]; then
    _vs reboot 1 "내비를 3분 후 재부팅해 주세요."
  elif [ "$K_PST" = fail ] && plan_this_boot && plan_problems | $BB grep -q .; then
    # HMG-API가 적용을 거절함(계획에 problem 줄). 우리가 넣지 않은 파일은 고치지 않는다
    _vs hmgrefuse 2 "HMG-API가 적용을 거절했습니다. HMG-API 앱의 'Can't apply' 창 아래쪽을 확인해 주세요."
  elif [ "$K_PST" = fail ] && [ -n "$K_PSTAGE" ]; then
    # 서비스가 진행 기록에 남긴 이유 문장(hotspot.sh)으로 판정 코드를 가른다
    case "$K_PSTAGE" in
      "$MAPFAIL_MSG") _vs mapfail 2 "$K_PSTAGE" ;;
      "$NOMAP_MSG") _vs nomap 2 "$K_PSTAGE" ;;
      # 다시 깨우지 않는 상태라 재부팅으로 안 바뀔 수 있다(문제, 빨강)
      "$WIFIGONE_MSG") _vs wifigone 2 "$K_PSTAGE" ;;
      "$OTHERPLAN_MSG") _vs otherplan 2 "$K_PSTAGE" ;;
      "$APPLYFAIL_MSG") _vs applyfail 2 "$K_PSTAGE" ;;
      *) _vs failed 2 "$K_PSTAGE" ;;
    esac
  elif [ "$K_MODON" = no ]; then _vs modoff 2 "HMG-API 앱에서 NX4 KOR가 꺼져 있습니다. 켜고 변경 사항을 적용한 뒤 내비를 재부팅해 주세요."
  elif [ "$K_BRIDGE" = off ]; then _vs bridgeoff 2 "HMG-API 앱의 NX4 KOR 설정에서 'Wireless CarPlay'가 꺼져 있습니다. 켜고 변경 사항을 적용한 뒤 내비를 재부팅해 주세요."
  elif [ "$K_HK" = off ]; then
    case "$K_HKMAP" in
      mapped) _vs hooksoff 1 "HMG-API 훅이 꺼져 있습니다. HMG-API 앱 Settings에서 'Check the map on this car'를 누른 뒤 내비를 재부팅해 주세요." ;;
      none) _vs hooksoff 1 "HMG-API에 이 차의 map이 없어 훅이 꺼져 있습니다. NX4 KOR를 지우고 다시 설치해 주세요." ;;
      mismatch) _vs hooksoff 1 "HMG-API map이 이 차의 소프트웨어와 맞지 않아 훅이 꺼져 있습니다. 내비 소프트웨어를 업데이트했다면 HMG-API와 NX4 KOR를 다시 설치해 주세요." ;;
      *) _vs hooksoff 1 "HMG-API 훅이 꺼져 있습니다(마지막 부팅 기록). 내비를 3분 후 재부팅한 뒤 다시 확인해 주세요." ;;
    esac
  elif [ "$K_MH" = off ]; then _vs modhooksoff 2 "HMG-API가 이 차에서 NX4 KOR의 훅을 켜지 못했습니다(이 차의 map에 없는 지점이 있음). 내비를 3분 후 재부팅해도 같으면 HMG-API 앱의 로그를 확인해 주세요."
  elif ! k_feat com.hkmc.software.connectivity.carplay_wireless; then _vs nofeat 2 "무선 카플레이 기능이 아직 켜지지 않았습니다. 내비를 3분 후 재부팅해 주세요."
  elif [ "$K_APMODE" != stock ] && [ -f $BK/stockap.seen ] && [ "$K_OURAP" = no ] && [ "$_vconn" = no ]; then
    _vs stockoff 1 "Wi-Fi가 지금 꺼져 있습니다. 아이폰을 연결해 보고, 안 되면 내비를 3분 후 재부팅해 주세요."
  elif [ "$K_APMODE" != stock ] && [ "$K_NOWLAN" = yes ] && [ "$K_OURAP" = no ] && [ "$_vconn" = no ] && [ "$K_NLB" -ge 3 ]; then
    # 무선 기능이 있는데 wlan0이 3번 넘는 부팅 동안 안 생김. 칩 실패는 근거(커널 칩 실패 줄·module_version 3)가 있을 때만
    if chip_fail_evidence; then _vs nowlanfail 2 "$NOCHIP_MSG"; V_END=yes
    else _vs nowlanrepeat 2 "Wi-Fi 장치가 계속 켜지지 않습니다. 내비를 3분 후 재부팅해도 같으면 기록(/data/nx4-kor/logs/ap.log)을 확인해 주세요."; fi
  elif [ "$K_APMODE" != stock ] && [ "$K_NOWLAN" = yes ] && [ "$K_OURAP" = no ] && [ "$_vconn" = no ]; then
    # wlan0이 이번 부팅에 생기지 않음 = Wi-Fi가 꺼져 있거나 늦게 켜짐. 서비스가 다시 켜므로 재부팅 뒤 다시 확인
    _nl=$K_NLB; [ "$_nl" -ge 1 ] || _nl=1
    _vs wifioff 1 "$WIFI_CHECK_MSG (확인 $_nl/3)"
  elif [ "$K_APMODE" != stock ] && { [ "$K_OURAP" = no ] || [ "$K_DHCP" = no ]; } && [ "$_vconn" = no ]; then
    _vs apoff 1 "핫스팟이 꺼져 있습니다. 내비를 3분 후 재부팅한 뒤 다시 확인해 주세요."
  elif [ "${K_CP:-0}" != 0 ] || [ "$K_AAOK" = yes ]; then
    if [ "${K_CP:-0}" != 0 ] && [ "$K_AAOK" = yes ]; then _vs connected 0 "무선 카플레이·안드로이드 오토 연결됨"
    # AA가 카플레이 때문에 기다리는 중(cpwait)이면 "준비됨"이라 하지 않는다(노란 안내 줄과 어긋나지 않게)
    elif [ "${K_CP:-0}" != 0 ] && [ "$K_AARDY" = yes ] && [ "$K_AAWAIT" = no ]; then _vs connected 0 "무선 카플레이 연결됨, 안드로이드 오토 준비됨"
    elif [ "${K_CP:-0}" != 0 ]; then _vs connected 0 "무선 카플레이 연결됨"
    # Wi-Fi는 하나이고 카플레이·AA가 같은 Wi-Fi를 쓰므로 AA가 붙었으면 카플레이도 준비된 것으로 보인다
    else _vs connected 0 "무선 안드로이드 오토 연결됨, 카플레이 준비됨"; fi
  # 순정 Wi-Fi 차도 둘 다 준비됨으로 보인다(같은 Wi-Fi). 순정 Wi-Fi 차에서 우리 AA 신호(aa_sig)를 켜지 않는 동작은 그대로다
  elif [ "$K_APMODE" = stock ]; then _vs ready 0 "무선 카플레이·안드로이드 오토 준비됨."
  elif [ "$K_AARDY" = yes ]; then _vs ready 0 "무선 카플레이·안드로이드 오토 준비됨."
  else _vs ready 0 "무선 카플레이 준비됨(안드로이드 오토는 준비 중)."
  fi
  # 차주용 요약 3줄
  case "$V_CODE" in
    installing) V_S1="설치: 진행 중" ;;
    reboot|wificheck) V_S1="설치: 재부팅 필요" ;;
    bootguard) V_S1="설치: HMG-API 훅 꺼짐(부팅 보호)" ;;
    ready|connected|stockoff|wifioff|nowlanrepeat|apoff|hooksoff) V_S1="설치: 끝남" ;;
    *) V_S1="설치: 안 됨(위 안내를 보세요)" ;;
  esac
  if [ "$K_OURAP" = yes ]; then V_S2="무선 Wi-Fi: 켜짐"
  elif [ "$K_APMODE" = stock ]; then V_S2="무선 Wi-Fi: 켜짐(내비 순정)"
  elif [ "$V_CODE" = nopart ]; then V_S2="무선 Wi-Fi: 부품 없음"
  elif [ "$V_CODE" = nochip ] || [ "$V_CODE" = nowlanfail ]; then V_S2="무선 Wi-Fi: 칩이 켜지지 않음"
  elif [ "$V_CODE" = nowlanrepeat ]; then V_S2="무선 Wi-Fi: 장치가 켜지지 않음(확인 중)"
  elif [ "$V_CODE" = wificheck ] || [ "$V_CODE" = wifioff ]; then V_S2="무선 Wi-Fi: 켜는 중(재부팅 뒤 확인)"
  elif [ "$V_CODE" = wifigone ]; then V_S2="무선 Wi-Fi: 칩이 지금 안 보임(전에는 보임)"
  else V_S2="무선 Wi-Fi: 꺼짐"; fi
  if [ "${K_CP:-0}" != 0 ]; then V_S3="폰 연결: 카플레이 ${K_CP}대 연결됨"
  elif [ "$K_AAOK" = yes ]; then V_S3="폰 연결: 안드로이드 오토 연결됨"
  else V_S3="폰 연결: 지금 연결된 폰 없음"; fi
  return 0
}
# plan.txt가 이번 부팅에 쓰였는가(서비스가 이번 부팅 처음 시작할 때 쓰는 svc.start보다 새것이고, svc.start가 이번 부팅 것)
plan_this_boot() {
  [ -f $W/plan.txt ] && [ -f $W/svc.start ] || return 1
  read _sb _sx < $W/svc.start
  [ "$_sb" = "$(cat ${BOOT_ID:-/proc/sys/kernel/random/boot_id} 2>/dev/null)" ] && [ $W/plan.txt -nt $W/svc.start ]
}
# HMG-API 계획(plan.txt)의 problem 줄(최대 10줄, 160자). 숫자·영문·경로 글자(쉼표·괄호 포함)만 남긴다(이름 등이 섞이지 않게)
plan_problems() {
  $BB grep '^problem' $W/plan.txt 2>/dev/null | $BB awk 'NR <= 10 { gsub(/[^A-Za-z0-9 ,()\/._:\[\]-]/, ""); print substr($0, 1, 160) }'
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
  echo "applied=$K_DONE"
  echo "oldmod=$K_OLDMOD"
  echo "mod_hooks=$K_MH"
  echo "mod_on=$K_MODON"
  echo "bridge=$K_BRIDGE"
  echo "hooks=$K_HK"
  echo "hookmap=$K_HKMAP"
  echo "feat_carplay=$(yesno k_feat com.hkmc.software.connectivity.carplay_wireless)"
  echo "feat_aa=$(yesno k_feat com.hkmc.software.connectivity.androidauto_wireless)"
  echo "feat_wifi=$(yesno k_feat android.hardware.wifi)"
  echo "wlan0=$(yesno [ -d /sys/class/net/$WIF ])"
  echo "softap_strings=${NS:-0}"
  echo "ssid_len=${#S2}"
  echo "pass_len=${#S4}"
  echo "our_ap=$K_OURAP"
  echo "our_dhcp=$K_DHCP"
  echo "other_ap=$K_OTHER"
  echo "stock_ssid=$K_SSID"
  echo "ap_mode=$K_APMODE"
  # 이 차에서 순정 카플레이 AP를 본 적이 있는가(서비스는 그 차에서 우리 핫스팟을 켜지 않는다)
  echo "stock_seen=$(yesno [ -f $BK/stockap.seen ])"
  echo "wpa=$(yesno running wpa_supplicant)"
  echo "cp_conn=$K_CP"
  # 설치 진행 상태(run·done·reboot·fail, 없으면 none)
  _ps=$($BB awk -F= '$1 == "state" { print $2 }' $PROG 2>/dev/null); echo "state=${_ps:-none}"
  # 이번 부팅에 Wi-Fi 장치(wlan0)가 생기지 않아 핫스팟을 못 켠 기록(hotspot.sh wlan_fail)
  echo "nowlan=$K_NOWLAN"
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
# 부팅 뒤 초(시계가 바뀌어도 거꾸로 가지 않는다). 읽지 못하면 빈 값
up_s() { $BB awk '{ print int($1) }' $UPTIME 2>/dev/null; }
# ap.log에 한 줄(서비스 로그와 같은 꼴). 상태 화면 갱신·감시자에서 쓴다
# 시계가 맞기 전이면 시각 대신 "부팅 직후"(hotspot.sh log_ts)
aplog() { log_ts; echo "$_LT $*" 2>/dev/null >> $APLOG; }
# [지금 재부팅] 요청($RBREQ, hotspot.sh)을 하나 받는다. 재부팅해도 되면 0. 받으면 바로 지운다.
# 하지 않는 경우(모두 ap.log에 이유 한 줄): 이전 부팅·이미 받은 요청(reboot.last)·깨진 값, 40초(NX4_RB_MAX)보다 오래됨·나이를 모름,
# 이번 부팅 설치 진행 기록이 설치 중(state=run), 설치 마무리(fix_perms: /system remount·
# 권한 파일·HMG-API map·적용을 모두 이 안에서 함)가 돌고 있음.
# 감시자만 부른다.
# 받지 않은 재부팅 요청·돌아온 재부팅 명령의 결과를 앱이 읽게 남긴다(644, 비밀값 없음, 요청 id를 읽었을 때만).
# 앱은 RB_WAIT(80초)를 다 기다리지 않고 이유에 맞는 문구를 보인다. RESET 안내는 명령이 돌아왔을 때(cmd)·모르는 코드·아무도 답하지
# 않을 때(감시자 없음), 그리고 설치 중·바깥 작업(install·sysw) 거절이 RB_STUCK_MAX(3)번 넘게 이어질 때(앱이 셈).
# 버튼은 늘 보이므로 "재부팅 필요"(state=reboot)일 때만 받지 않는다. /system이 rw인지는 보지 않는다(설치 직후 rw로 남을 수 있음).
# 우리 쪽 쓰기는 설치 중(run)·설치 마무리(fix.pid)로 막는다.
# code: install 설치 중 · fix 설치 마무리 중 · sysw 바깥 /system 작업 · guard HMG-API 부팅 보호(2분 전) ·
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
  # 넘었으면 멈춘 기록으로 보고 이 이유로는 막지 않는다(설치 마무리가 아직 돌면 아래 fix로 막는다). ut가 없거나 숫자가 아니어도
  # 멈춘 기록으로 본다(버튼이 끝없이 "잠시 뒤 다시"만 내지 않게)
  if $BB grep -q '^state=run$' $PROG 2>/dev/null \
      && [ "$($BB awk -F= '$1 == "boot" { print $2 }' $PROG 2>/dev/null)" = "$(cat ${BOOT_ID:-/proc/sys/kernel/random/boot_id} 2>/dev/null)" ]; then
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
  # 프로세스 확인을 못 하면(명령줄을 못 읽음) 돌고 있는 것으로 본다(pid_busy, 막는 쪽으로)
  pid_busy $W/fix.pid hotspot.sh && { aplog "재부팅 요청 거절: 설치 마무리(시스템 파일·HMG-API 적용)가 아직 도는 중"; rb_result fix; return 1; }
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
# 본다(엔진 apply 명령줄은 약 60자라 ps의 80칸 안). 그래도 판단이 안 되면 막지 않고 로그만 남긴다(우리 쪽 쓰기는 fix.pid·run 기록이
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
  aplog "재부팅 요청: 프로세스 명령줄을 읽지 못함(/proc·ps 모두). 막지 않음(우리 쪽 쓰기는 설치 기록·마무리 확인으로 막음)"
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
      # 검사와 재부팅 사이(특히 sync가 길 때) 바깥 작업·설치 마무리가 새로 시작했으면 지금 거절한다
      if sys_writer_busy || pid_busy $W/fix.pid hotspot.sh; then
        aplog "재부팅 요청 거절: sync 뒤 다시 보니 시스템 영역·설치 마무리 작업이 시작됨(${SYSW:-우리 작업})"
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
# 상태 파일을 쓸 때 구한 값(st_collect)을 다시 쓴다
c=$K_CP
# 순정 Wi-Fi 차는 판정 문구와 같은 뜻으로
if [ "$K_APMODE" = stock ]; then m="NX4 KOR: 무선 카플레이·안드로이드 오토 준비됨, 카플레이 연결 $c개"
else
  a=꺼짐; [ "$K_OURAP" = yes ] && a=켜짐
  d=꺼짐; [ "$K_DHCP" = yes ] && d=켜짐
  m="NX4 KOR: 핫스팟 $a, DHCP $d, 카플레이 연결 $c개"
fi
echo "$m"
exit 0
