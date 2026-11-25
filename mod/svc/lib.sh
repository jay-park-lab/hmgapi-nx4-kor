#!/system/bin/sh
# NX4 KOR 공용 함수: 관리 앱 쪽(bin/status.sh)과 지우기 전 정리(scripts/preun.sh)가 ". svc/lib.sh"로 읽는다(혼자 돌지 않음).
# 2.1.0부터 무선 카플레이·안드로이드 오토는 HMG-API(2.1.1부터 1.1.0-rc.9 이상)와 공식 무선 모드 wireless-carplay-aa(2.2.0-rc.9 이상)가
# 맡는다. 프로젝션 AP는 HMG-API가 공식 모드의 "wifi": {"projection": true} 요청으로 띄운다. 이 모드는 핫스팟을 띄우지 않고
# 시스템 파일·Wi-Fi 설정도 바꾸지 않는다. 여기에는 상태를 읽는 함수와 관리 앱의 요청을 받는 데 쓰는 함수만 있다.
# 2.0.x의 svc/hotspot.sh(순정 hostapd·dnsmasq 핫스팟, Wi-Fi 잠금, 칩 깨우기, 자동 설정 setup_hmgapi)를 줄인 것이다.
# map 만들기·확인과 적용은 USB 설치기(usb/troubleShooter)가 한다.
# 시험: BB, SRC, W, BK, PROC, BOOT_ID, UPTIME, HMGDATA 등을 밖에서 정해 두면 그대로 쓴다.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
APP=${APP:-/data/hmgapi/mods/nx4-kor}
# busybox 고르기. 내비에 busybox가 있으면 그것을 쓰고, 없으면 모드에 함께 넣은 busybox(1.36.1, bin/busybox)를 쓴다.
# BB를 미리 정해 두면(테스트, 예전 호출) 그대로 쓴다. 쓸 수 있는지는 한 번 실행해 보고 BB_OK에 남긴다.
BB_SYS=${BB_SYS:-/system/bin/busybox}
BB_OWN=${BB_OWN:-$APP/bin/busybox}
if [ -z "$BB" ]; then
  if [ -x $BB_SYS ]; then BB=$BB_SYS
  else
    # zip에서 풀 때 실행 권한이 빠질 수 있다: 우리 파일이므로 한 번 준다(toolbox chmod)
    [ -f $BB_OWN ] && [ ! -x $BB_OWN ] && chmod 755 $BB_OWN 2>/dev/null
    BB=$BB_OWN
  fi
fi
# 내비의 busybox는 예전처럼 실행 파일인지만 본다.
# 함께 넣은 busybox는 실제로 실행해 본다(/data가 noexec이거나 CPU가 맞지 않으면 쓰지 않는다).
BB_OK=0
if [ "$BB" = "$BB_OWN" ]; then "$BB" true >/dev/null 2>&1 && BB_OK=1
else [ -x "$BB" ] && BB_OK=1; fi
# 프로세스 목록. 1.36.1은 기본 출력에 상태 칸이 없어 좀비([hostapd])를 " Z "로 거르지 못한다: 함께 넣은
# busybox일 때만 상태 칸을 달라고 한다(PID STAT COMMAND, 첫 칸 PID는 1.8.1과 같다).
# 경로 문자열로 판단한다: 같은 파일을 다른 경로로 BB에 넘기면 기본 ps가 되어 좀비를 거르지 못한다.
if [ "$BB" = "$BB_OWN" ]; then PS="$BB ps -o pid,stat,args"; else PS="$BB ps"; fi
# 순정 Wi-Fi AP 설정(카플레이 SSID S2, 일반 핫스팟 SSID S1). AP가 프로젝션 AP인지 가리는 데만 읽고 값은 남기지 않는다
SRC=${SRC:-/data/misc/wifi/softap.conf}
# Wi-Fi 장치 이름은 여기 한 곳에서 정한다(기본값 wlan0). 주석·화면 문구 속 "wlan0" 글자는 그대로 둔다
WIF=${WIF:-wlan0}
# 관리 앱의 작업 폴더(감시자 pid·끝 시각, 받은 재부팅 요청). /data/local/tmp 아래라 재부팅 뒤에도 남는다
W=${W:-/data/local/tmp/nx4-kor}
BK=${BK:-/data/nx4-kor/backup}
PROC=${PROC:-/proc}
BOOT_ID=${BOOT_ID:-/proc/sys/kernel/random/boot_id}
UPTIME=${UPTIME:-/proc/uptime}
SYSNET=${SYSNET:-/sys/class/net}
# 이 모드가 동작하는 차: 투싼 NX4·NX4 하이브리드, 한국 내수 펌웨어 260902(mod.json "system"과 같다)
CARS='NX4.KOR.*.260902 NX4HEV.KOR.*.260902'
HMGDATA=${HMGDATA:-/data/hmgapi}
# 이 모드의 id(mod.json "id")
MOD_ID=${NX4_MOD_ID:-nx4-kor}
# 이 모드가 요구하는 HMG-API 판(mod.json "hmgapi"와 같게 둔다. 앱 Report.MIN_HMGAPI도 같게).
# rc.9: rc.8 이하는 LivePatch(app_process를 스크립트로 바꿈)가 깔린 차에서 지우면 Android가 뜨지 않을 수 있다(Open-HMG/HMG-API#397)
HMG_MIN=1.1.0-rc.9
# 공식 무선 모드(고치지 않음, NX4에는 USB 설치기가 --any-car로 넣는다). 판은 앱 Report.MIN_WIRELESS와 같게 둔다.
# mod.json "requires"로 걸지 않는다: 공식 모드가 없거나 꺼지면 HMG-API가 이 모드의 앱·서비스까지 멈춰 관리 앱이 알릴 수 없다
WM_ID=wireless-carplay-aa
WM_MIN=2.2.0-rc.9
WM_NAME='Wireless CarPlay + Android Auto'
# HMG-API가 Wi-Fi 칩을 찾는 곳(SystemCheck.java): SDIO 장치, 한 번 본 기록
SDIO=${SDIO:-/sys/bus/sdio/devices}
WIFI_SEEN=${WIFI_SEEN:-$HMGDATA/public/wifi-chip}
# HMG-API Wi-Fi 지기(HMG-API rc.8 engine/HomeWifi.java, 서비스 "hmgapi wifi")의 기록:
#   state/wifi.txt  모드가 요청한 것(엔진이 씀): "projection <모드>" 줄이 있으면 부팅마다 프로젝션 AP(apMode 2)를 한 번 띄운다
#   wifi/ap.boot    이번 부팅에 AP를 띄웠거나 이미 떠 있었음(또는 Wi-Fi 클라이언트가 켜져 있어 두었음): 부팅 id
#   wifi/ap.fail    이번 부팅에 띄우지 못하고 다시 시도하는 중: 부팅 id. 기록 줄은 logs/hmgapi/wifi.log
HMGWIFI=${HMGWIFI:-$HMGDATA/wifi}
WIFIASKS=${WIFIASKS:-$HMGDATA/state/wifi.txt}
# 설치 진행 기록(USB 설치기가 쓰고 관리 앱이 1초마다 읽음, 644, 비밀값 없음). 한 줄에 key=value:
#   pct, state(run 진행 중|done 준비됨|reboot 재부팅 필요|fail 실패), stage(지금 단계·실패 이유, 한국어), start·t(시각 초),
#   boot(부팅 id), step(N/M), ust·ut(부팅 뒤 초). 관리 앱은 이번 부팅의 기록만 본다
PROG=${PROG:-/data/local/tmp/nx4-kor-progress.txt}
# 알림 기록(한 줄에 "<시각(초)> <부팅 id> <문구>", 앱은 이번 부팅의 줄만 보인다)과 예전 판의 상태 안내. 지울 때 함께 지운다
NOTICE=${NOTICE:-/data/local/tmp/nx4-kor-notice.txt}
HINT=${HINT:-/data/local/tmp/nx4-kor-hint.txt}
# [지금 재부팅] 요청: 관리 앱이 앱 개인 폴더에 요청 파일을 쓴다. 내용은 한 줄 "<요청 id> <boot_id> <부팅 뒤 초>"
# (요청 id는 앱의 부팅 뒤 밀리초, 숫자만). 다른 앱은 이 폴더에 쓸 수 없다. 감시자(status.sh --watch)만 받는다.
RBREQ=${NX4_RBREQ:-/data/data/io.github.jayparklab.nx4kor/files/reboot.req}
NOCAR_MSG="지원하지 않는 차입니다(투싼 NX4 한국 내수 260902 전용). 아무것도 바꾸지 않았습니다."
NOHMG_MSG="HMG-API가 없습니다. HMG-API $HMG_MIN 이상을 먼저 설치해 주세요."

# $1(제품명)이 $2(공백으로 나눈 패턴 목록)의 하나와 맞는가.
# case 패턴에는 변수로 '|'를 넘길 수 없어 하나씩 본다. 목록을 나눌 때 '*'가 파일 이름으로 풀리지 않게
# 잠시 set -f 한다(이미 -f면 그대로 둔다).
car_in() {
  _cr=1; _ci=$IFS; IFS=' '
  case $- in *f*) _cf=0 ;; *) _cf=1; set -f ;; esac
  for _ck in $2; do case "$1" in $_ck) _cr=0; break ;; esac; done
  [ $_cf = 1 ] && set +f
  IFS=$_ci
  return $_cr
}

# 부팅 직후 시계가 맞기 전에는 날짜가 "01-01 18:30:0x"처럼 찍혀 헷갈렸다(니로 차 로그). 연도가 이 패키지를
# 만든 해(NX4_YEAR0)보다 이전이면 시각 대신 "부팅 직후(+N초)"라고 쓴다. 하위 셸을 늘리지 않게 값은 _LT에 둔다(date 한 번)
NX4_YEAR0=${NX4_YEAR0:-2026}
log_ts() {
  _LT=$(date '+%Y %m-%d %H:%M:%S' 2>/dev/null); _ly=${_LT%% *}; _LT=${_LT#* }
  case "$_ly" in [0-9][0-9][0-9][0-9]) [ "$_ly" -lt $NX4_YEAR0 ] && { boot_secs; _LT="부팅 직후(+${_U:-?}초)"; } ;; esac
  return 0
}
# 부팅 뒤 초(정수)를 _U에. 하위 셸 없이 read로. 못 읽으면 빈 값
boot_secs() { _U=; { read _U _ux < $UPTIME; } 2>/dev/null; _U=${_U%%.*}; case "$_U" in ''|*[!0-9]*) _U= ;; esac; return 0; }
# 이번 부팅 id
boot_id() { cat $BOOT_ID 2>/dev/null; }

# 헤드유닛 busybox의 od는 -b만 안다: 바이트가 8진 3자리로 나온다. decode는 8진 바이트들 → 문자열.
# 형식 문자열은 "\NNN"(8진 이스케이프)만으로 만들어 % 나 \ 같은 글자도 이스케이프로만 들어간다(형식 지시자로 읽히지 않음)
decode() {
  _f=""
  for _b in "$@"; do _f="$_f\\$_b"; done
  $BB printf "$_f\n"
}
# 8진 3자리 바이트 하나 → 10진(자리마다 계산: 앞의 0을 8진으로 잘못 읽지 않게). 결과는 _d에(하위 셸 없이)
o2d() {
  _r=${1#?}
  _d=$(( ${1%??}*64 + ${_r%?}*8 + ${_r#?} ))
}
# 이 내비의 softap.conf(형식 3)는 순정 안드로이드 WifiApConfigStore 꼴이 아니다: 자바 writeUTF 문자열(2바이트 길이 + 바이트)로
# S1 일반 핫스팟 SSID, S2 카플레이 SSID, S3, S4 카플레이 비밀번호가 들어 있다. NS는 읽은 문자열 수.
# 산술 전에 길이를 먼저 확인한다: 틀린 $(( ))는 스크립트 전체를 끝낸다.
# 1번째·3번째 문자열(S1·S3)에서만 올바른 UTF-8 여러 바이트 글자(앞 바이트 C2~F4 + 이어지는 바이트 80~BF)를 받는다
# (순정 일반 핫스팟 이름이 한글인 차). S2·S4는 32~126만 받는다.
parse_conf() {
  NS=0
  [ -s "$1" ] || return 1
  # od -b 줄: 7자리 위치 다음에 3자리 바이트들. 바이트만 남긴다
  set -- $(for _t in $($BB od -b -v "$1"); do [ ${#_t} -eq 3 ] && echo $_t; done)
  N=$#
  [ $N -ge 4 ] || return 1
  i=0
  for _t in "$@"; do o2d $_t; eval "o$i=$_t; b$i=$_d"; i=$((i+1)); done
  i=0
  while [ $((i+2)) -lt $N ]; do
    eval "_L=\$(( b$i*256 + b$((i+1)) ))"
    if [ $_L -ge 1 ] && [ $_L -le 63 ] && [ $((i+2+_L)) -le $N ]; then
      _ok=1; j=$((i+2)); _e=$((i+2+_L))
      # 이번 문자열이 몇 번째가 되는가: 1·3번째(S1·S3)만 UTF-8 글자를 받는다
      case $NS in 0|2) _u8=1 ;; *) _u8=0 ;; esac
      while [ $j -lt $_e ]; do
        eval "_v=\$b$j"
        if [ $_v -ge 32 ] && [ $_v -le 126 ]; then j=$((j+1)); continue; fi
        if [ $_u8 = 1 ] && [ $_v -ge 194 ] && [ $_v -le 244 ]; then
          # 이어지는 바이트 수: C2~DF 1개, E0~EF 2개, F0~F4 3개. 모두 80~BF이고 문자열 안에 있어야 한다
          if [ $_v -le 223 ]; then _n=1; elif [ $_v -le 239 ]; then _n=2; else _n=3; fi
          [ $((j+_n)) -lt $_e ] || { _ok=0; break; }
          _k=1
          while [ $_k -le $_n ]; do
            eval "_w=\$b$((j+_k))"
            if [ $_w -lt 128 ] || [ $_w -gt 191 ]; then _ok=0; break; fi
            _k=$((_k+1))
          done
          [ $_ok = 1 ] || break
          j=$((j+1+_n)); continue
        fi
        _ok=0; break
      done
      if [ $_ok -eq 1 ]; then
        B=""; j=$((i+2))
        while [ $j -lt $((i+2+_L)) ]; do eval "B=\"\$B \$o$j\""; j=$((j+1)); done
        NS=$((NS+1))
        eval "S$NS=\$(decode \$B)"
        i=$((i+2+_L)); continue
      fi
    fi
    i=$((i+1))
  done
}

# 살아 있는 프로세스가 있는가(이름·명령줄 일부). 좀비([hostapd], 상태 Z)는 세지 않는다
running() { $PS | $BB grep -v grep | $BB grep -v " Z " | $BB grep -q "$1"; }
# Wi-Fi AP(hostapd)가 떠 있는가. 2.1.0의 이 모드는 hostapd를 띄우지 않는다: 프로젝션 AP·순정 핫스팟(netd가 띄움)이나
# 다른 패키지의 것이다
ap_on() { running hostapd; }
# hostapd의 pid들
hostapd_pids() { $PS | $BB grep -v grep | $BB grep -v " Z " | $BB grep hostapd | $BB awk '{print $1}'; }
# $1(pid)의 부모가 netd인가. /proc/<pid>/stat의 4번째 칸이 부모 pid다(이름 칸에 공백이 없는 프로그램만 본다).
by_netd() {
  [ -r $PROC/$1/stat ] || return 1
  read _n1 _n2 _n3 _pp _nr < $PROC/$1/stat
  case "$_pp" in ''|*[!0-9]*) return 1 ;; esac
  [ -r $PROC/$_pp/stat ] || return 1
  read _n1 _n2 _nr < $PROC/$_pp/stat
  [ "$_n2" = "(netd)" ]
}
# 순정(netd가 띄움)이 아닌 hostapd가 실제로 돌고 있는가(다른 무선 패키지·USB 동글 패키지 등). HMG-API의 프로젝션 AP도
# 순정 경로(netd)로 뜬다. 부모를 읽지 못하면 순정일 수 있으므로 세지 않는다(그때는 "다른 Wi-Fi 패키지"로 판정하지 않음)
foreign_hostapd() {
  for _fh in $(hostapd_pids); do
    [ -r $PROC/$_fh/stat ] || continue
    read _f1 _f2 _f3 _fpp _fr < $PROC/$_fh/stat
    case "$_fpp" in ''|*[!0-9]*) continue ;; esac
    [ -r $PROC/$_fpp/stat ] || continue
    by_netd $_fh && continue
    return 0
  done
  return 1
}
# 순정(netd가 띄운) hostapd의 설정 파일(마지막 .conf 인자). 못 찾으면 1.
# 설정 파일 경로는 ps가 아니라 /proc/<pid>/cmdline에서 읽는다(netd의 "hostapd -e <entropy> <conf>"는 ps가 80칸에서 자른다)
ap_conf() {
  for _hp in $(hostapd_pids); do
    [ -r $PROC/$_hp/cmdline ] && by_netd $_hp || continue
    _sc=
    for _a in $($BB tr '\0' ' ' < $PROC/$_hp/cmdline 2>/dev/null); do case "$_a" in *.conf) _sc=$_a ;; esac; done
    [ -n "$_sc" ] && [ -r "$_sc" ] && { echo "$_sc"; return 0; }
  done
  return 1
}
# 떠 있는 순정 AP가 어느 쪽인가. softap.conf에는 SSID가 둘 있다: S1 일반 핫스팟, S2 카플레이용(ConnectivitySSID).
# HMG-API의 프로젝션 AP(apMode 2)는 카플레이 SSID로 뜬다(HMG-API rc.5 ProjectionAp). 값은 비교만 하고 어디에도 남기지 않는다.
# 출력: none(hostapd 없음) | projection(S2) | hotspot(S1, 일반 핫스팟) | other | unknown(netd가 띄운 것이 아님, 설정을 못 읽음,
# ssid 줄이 없거나 여럿, softap.conf를 못 읽음, 두 SSID가 같음). parse_conf가 먼저 돌아 S1·S2·NS가 있어야 한다.
ap_ssid() {
  ap_on || { echo none; return 0; }
  _sf=$(ap_conf) || { echo unknown; return 0; }
  _ss=; _sn=0
  while IFS= read -r _l || [ -n "$_l" ]; do
    case "$_l" in ssid=*) _ss=${_l#ssid=}; _sn=$((_sn+1)) ;; esac
  done < "$_sf"
  if [ $_sn -ne 1 ] || [ -z "$_ss" ] || [ "${NS:-0}" -lt 4 ] || [ ${#S2} -lt 1 ] || [ "$S1" = "$S2" ]; then echo unknown
  elif [ "$_ss" = "$S2" ]; then echo projection
  elif [ "$_ss" = "$S1" ]; then echo hotspot
  else echo other; fi
  return 0
}

# 지금 무선 카플레이 연결 수: 로컬 포트 7000(DiPO, 16진 1B58)의 ESTABLISHED(01) 연결 중 로컬 주소가 wlan0(또는 AP 인터페이스
# ap*·softap*·swlan*)의 주소인 것. /proc/net/tcp·tcp6을 직접 읽는다(netstat은 긴 IPv6 주소를 자를 수 있다). 주소는 32비트 단위로
# 바이트가 뒤집혀 있다(리틀 엔디언). IPv6는 /proc/net/if_inet6(네트워크 순서), IPv4는 ifconfig의 inet addr로 맞춘다.
# 유선 카플레이(USB 네트워크 ncm0)는 세지 않는다. IPv4가 IPv6 꼴(::ffff:)이어도 맞춘다.
PROCNET=${PROCNET:-/proc/net}
cp_ifs() {
  _ci=$WIF
  for _x in $SYSNET/ap* $SYSNET/softap* $SYSNET/swlan*; do [ -e "$_x" ] && _ci="$_ci ${_x##*/}"; done
  echo $_ci
}
cp_count() {
  _ifl=$(cp_ifs)
  _v4=; for _x in $_ifl; do
    _a=$($BB ifconfig $_x 2>/dev/null | $BB awk '/inet addr:/ { a = $0; sub(/.*inet addr:/, "", a); sub(/ .*/, "", a); print a; exit }')
    [ -n "$_a" ] && _v4="$_v4 $_a"
  done
  # 있는 파일만 넘긴다(IPv6가 꺼진 커널에는 if_inet6·tcp6이 없다. 하나도 없으면 awk가 표준입력을 기다리므로 0)
  _pf=; for _x in if_inet6 tcp tcp6; do [ -r $PROCNET/$_x ] && _pf="$_pf $PROCNET/$_x"; done
  [ -n "$_pf" ] || { echo 0; return 0; }
  $BB awk -v v4="$_v4" -v ifl=" $_ifl " '
    function le(w) { return substr(w, 7, 2) substr(w, 5, 2) substr(w, 3, 2) substr(w, 1, 2) }
    BEGIN { k = split(v4, vs, " "); for (i = 1; i <= k; i++) if (split(vs[i], o, ".") == 4) ok4[sprintf("%02X%02X%02X%02X", o[1], o[2], o[3], o[4])] = 1 }
    FILENAME ~ /if_inet6$/ { if (index(ifl, " " $6 " ") > 0) ok6[toupper($1)] = 1; next }
    $4 == "01" && split($2, p, ":") == 2 && p[2] == "1B58" {
      a = toupper(p[1])
      # busybox 1.8.1 awk가 함수 호출 결과로 in을 못 쓸 수 있어 변수에 담아 본다
      if (length(a) == 8) { k = le(a); if (k in ok4) n++; next }
      if (length(a) != 32) next
      f = le(substr(a, 1, 8)) le(substr(a, 9, 8)) le(substr(a, 17, 8)) le(substr(a, 25, 8))
      if (f in ok6) n++
      else if (substr(f, 1, 24) == "00000000000000000000FFFF") { k = substr(f, 25, 8); if (k in ok4) n++ }
    }
    END { print n + 0 }' $_pf 2>/dev/null || echo 0
}

# Wi-Fi 칩을 본 적이 있는가(HMG-API SystemCheck와 같은 기준: SDIO 장치가 지금 있거나, HMG-API가 한 번 본 기록)
wifi_chip_seen() {
  [ -f $WIFI_SEEN ] || [ -n "$(ls $SDIO 2>/dev/null)" ]
}
# 파일($1)에 이번 부팅 id가 적혀 있는가(HMG-API Wi-Fi 지기의 ap.boot·ap.fail)
this_boot() { [ -s "$1" ] && [ "$(cat "$1" 2>/dev/null)" = "$(boot_id)" ]; }
# HMG-API에 프로젝션 AP를 요청한 모드가 있는가(state/wifi.txt의 "projection <모드>" 줄). $1을 주면 그 모드만
proj_asked() {
  [ -f $WIFIASKS ] || return 1
  while read -r _pw _pm _px; do
    [ "$_pw" = projection ] || continue
    [ -z "$1" ] || [ "$_pm" = "$1" ] && return 0
  done < $WIFIASKS
  return 1
}

# mod.json 꼴 파일($1, 없으면 이 모드의 mod.json)의 "version" 값. 못 읽으면 빈 값
mod_ver() {
  _mv=
  while IFS= read -r _l; do
    case "$_l" in
      *'"version"'*) _mv=${_l#*\"version\"}; _mv=${_mv#*\"}; _mv=${_mv%%\"*}; break ;;
    esac
  done < ${1:-$APP/mod.json} 2>/dev/null
  echo "$_mv"
}
# 판 비교: $1이 $2보다 낮은가. HMG-API Version과 같은 규칙(semver, major.minor.patch 다음 "-" 꼬리까지: 1.1.0-rc.4 < 1.1.0-rc.8
# < 1.1.0-rc.10 < 1.1.0, alpha < beta < rc). USB 설치기 vlt와 같다. "+빌드"는 보지 않는다.
# 돌려주는 값: 0 낮음, 1 같거나 높음, 2 비교할 수 없음(숫자가 아님, 모르는 꼬리). if에서는 2도 "낮지 않음"으로 읽힌다.
ver_lt() {
  _x=${1%%+*}; _y=${2%%+*}; _xt=; _yt=
  case $_x in *-*) _xt=${_x#*-}; _x=${_x%%-*} ;; esac
  case $_y in *-*) _yt=${_y#*-}; _y=${_y%%-*} ;; esac
  [ -n "$_x" ] && [ -n "$_y" ] || return 2
  _i=0
  while [ $_i -lt 3 ]; do
    _a=${_x%%.*}; _b=${_y%%.*}
    case $_x in *.*) _x=${_x#*.} ;; *) _x= ;; esac
    case $_y in *.*) _y=${_y#*.} ;; *) _y= ;; esac
    [ -n "$_a" ] || _a=0
    [ -n "$_b" ] || _b=0
    case $_a$_b in *[!0-9]*) return 2 ;; esac
    [ "$_a" -lt "$_b" ] && return 0
    [ "$_a" -gt "$_b" ] && return 1
    _i=$((_i+1))
  done
  [ "$_xt" = "$_yt" ] && return 1
  [ -z "$_xt" ] && return 1
  [ -z "$_yt" ] && return 0
  _xt=$_xt.; _yt=$_yt.
  while [ -n "$_xt" ] && [ -n "$_yt" ]; do
    _a=${_xt%%.*}; _xt=${_xt#*.}
    _b=${_yt%%.*}; _yt=${_yt#*.}
    [ "$_a" = "$_b" ] && continue
    case $_a in ''|*[!0-9]*) _na= ;; *) _na=1 ;; esac
    case $_b in ''|*[!0-9]*) _nb= ;; *) _nb=1 ;; esac
    if [ -n "$_na" ] && [ -n "$_nb" ]; then
      [ "$_a" -lt "$_b" ] && return 0
      return 1
    fi
    [ -n "$_na" ] && return 0
    [ -n "$_nb" ] && return 1
    for _w in _a _b; do
      eval "_c=\$$_w"
      case $_c in alpha) _c=1 ;; beta) _c=2 ;; rc) _c=3 ;; *) return 2 ;; esac
      eval "$_w=\$_c"
    done
    [ "$_a" -lt "$_b" ] && return 0
    return 1
  done
  [ -z "$_xt" ] && [ -n "$_yt" ] && return 0
  return 1
}

# --- 관리 앱의 요청과 그 감시자 ---
# /proc/<pid>/cmdline은 인자를 NUL로 나눈다. busybox 1.8.1 grep은 첫 NUL 뒤를 못 볼 수 있어 NUL을 빈칸으로
# 바꾼 한 줄로 본다. 읽지 못하면 빈 값.
pcmd() { $BB tr '\0' ' ' < $PROC/$1/cmdline 2>/dev/null; }
# pcmd를 믿을 수 있는가. 차의 busybox 1.8.1 tr이 NUL을 바꾸지 못하면 명령줄이 첫 NUL에서 잘리거나("sh")
# NUL이 빠져 붙는다("sh/data/…status.sh--watch"). 둘 다 낱말이 하나뿐이다. 그래서 자기 명령줄(/proc/$$, 셸 + 스크립트로
# 늘 둘 이상)을 읽어 낱말이 둘 이상이면 믿는다. 자기 것을 읽을 수 없으면(PC 시험의 가짜 /proc 등) 판단할 수 없어 믿는 것으로 둔다
# (차에서는 /proc/$$가 늘 있다). 부를 때마다 본다(하위 셸 하나)
pcmd_ok() {
  [ -r $PROC/$$/cmdline ] || return 0
  set -- $(pcmd $$)
  [ $# -ge 2 ]
}
# 요청 파일($1)을 읽어 RQ_ID·RQ_EL을 정한다. 읽은 내용은 RQ_RAW에 둔다(못 읽으면 빈 값). 이번 부팅의 요청이고, 값이 숫자이고, 이미 받은 요청($2 파일의 id)이
# 아니면 0. 받지 않는 요청을 지울 때는 req_drop을 쓴다. 지우지 못해 남은 요청을 다시 받지 않게 하는 판단이 여기 하나뿐이다.
req_peek() {
  RQ_ID=; RQ_EL=; RQ_RAW=; _rl=$2
  _rq=$(cat $1 2>/dev/null) || return 1
  RQ_RAW=$_rq
  set -- $_rq
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  case "$3" in ''|*[!0-9]*) return 1 ;; esac
  RQ_ID=$1; RQ_EL=$3
  [ "$1" != "$(cat $_rl 2>/dev/null)" ] && [ -n "$2" ] && [ "$2" = "${BID:-$(boot_id)}" ]
}
# 받지 않는 요청 지우기: req_peek이 읽은 그 내용(RQ_RAW)일 때만 지운다. 파일을 다시 보고 지우면, req_peek이 읽은 뒤(파일 없음)
# 막 들어온 새 요청을 "받지 않는 요청"으로 지울 수 있다(2026-11-10 PC 시험에서 찾은 경쟁). 지웠으면 0.
req_drop() {
  [ -n "$RQ_RAW" ] && [ "$(cat $1 2>/dev/null)" = "$RQ_RAW" ] && rm -f $1 2>/dev/null
}
# "<pid> <boot_id>" 파일의 pid가 이번 부팅에 살아 있는 status.sh인가(자기 자신은 뺀다). $2를 주면 명령줄에 그 인자
# (--watch·--wait)도 낱말로 있어야 한다. watch.pid·wait.pid에 쓴다. 명령줄은 pcmd로 읽는다(NUL → 빈칸).
# 못 읽으면 "없음"으로 본다(감시자가 막혀 영영 안 뜨는 것이 더 나쁘다).
st_alive() {
  _sl=$(cat $1 2>/dev/null) || return 1
  _sa=$2
  set -- $_sl
  [ -n "$1" ] && [ "$1" != "$$" ] && [ "$2" = "${BID:-$(boot_id)}" ] && [ -d $PROC/$1 ] || return 1
  _sc=" $(pcmd $1) "
  case "$_sc" in *status.sh*) ;; *) return 1 ;; esac
  [ -z "$_sa" ] && return 0
  case "$_sc" in *" $_sa "*) return 0 ;; esac
  return 1
}

# 쓸 수 있는 busybox가 없을 때(내비에 없고, 함께 넣은 것도 실행되지 않음: 예 /data가 noexec): 관리 앱은 "지원하지 않는 내비"를 보인다
has_bb() { [ "$BB_OK" = 1 ]; }
# 명령: busybox가 있으면 busybox로, 없으면 toolbox의 같은 이름으로.
bbx() { if has_bb; then $BB "$@"; else "$@"; fi; }
