#!/bin/sh
# PC(맥)에서 가짜 헤드유닛 환경으로 NX4 KOR 모드의 핫스팟 서비스(svc/hotspot.sh)·상태(bin/status.sh)·설치·삭제 스크립트를 돌린다.
# Korea Projection의 시험(tests/stub-test.sh)에서 이 모드에 남은 기능의 시험만 남겼다. 통합 모드의 자동 설정(map·적용)·
# 래퍼·USB 설치기·빌드는 tests/mod-test.sh가 본다.
# 차에 올리기 전에 실행한다: sh tests/stub-test.sh   (실패하면 FAIL 줄과 종료 코드 1)
# 가짜 도구: getprop, pm, hmgapid, am, settings, svc, ps, netstat, sleep, busybox
B=$(cd "$(dirname "$0")/.." && pwd)
PKG=$B/mod
T=$(mktemp -d /tmp/kp-stub.XXXXXX)
# KEEP=1: 시험 폴더를 남긴다(실패 원인 보기)
if [ -n "$KEEP" ]; then echo "시험 폴더: $T"; else trap 'rm -rf $T' EXIT; fi
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails+1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# 차의 셸(mksh) 구문 검사. 아래 테스트는 bash로 돌아서 ksh 계열만 틀리는 구문을 못 잡는다
# (1.5.2: case 갈래 안의 ${_r%% (*} 때문에 모든 차에서 hotspot.sh가 시작되지 않았다).
# 있는 것을 모두 돌린다: ksh(맥 기본 ksh93)가 이번 버그를 잡았고, PC의 mksh는 차의 옛 mksh보다 너그러울 수 있다.
# 둘 다 없으면 건너뛰지 않고 실패로 둔다. 한계: eval 문자열 안, 실행할 때만 드러나는 차이, busybox 옵션은 못 잡는다.
KSHS=$(for s in mksh ksh; do command -v $s; done)
[ -n "$KSHS" ] || bad "구문 검사: mksh/ksh 없음"
# 4b K-11: 은퇴한 USB 도구(kp-update-test.sh·kp-probe.sh)의 구문 검사는 tests/legacy/legacy-test.sh로 옮겼다
for f in $PKG/svc/hotspot.sh $PKG/scripts/post.sh $PKG/scripts/preun.sh $PKG/bin/status.sh; do
  for KSH in $KSHS; do check "구문 검사 $(basename $KSH): ${f#$B/}" '$KSH -n $f'; done
done

mkdir -p $T/bin $T/app $T/w $T/apps $T/d $T/usb0/packages $T/logs
# 1.7.4(L-6): 없는 명령(맥에 없는 chown 등)은 오류 줄 없이 127로 실패한다(차의 busybox에 그 기능이 없는 것과 같은 결과, 잡음만 없앰)
# 1.7.4(B-15, 리뷰로 좁힘): 차의 busybox 1.8.1 grep에서 확실한 옵션(l n q v s c i H h e f L A B C E)만 받는다(w o r m a I F는 확실하지 않아 뺌). 그 밖의 글자(-x 등)나
# 긴 옵션(--…)이면 아무것도 내지 않고 2로 끝난다(1.8.1에서 안 되는 꼴이 PC 시험에서 통과하지 않게). 옵션은 첫 비옵션 인자 앞까지만 본다
cat > $T/bin/bb <<'BBE'
#!/bin/sh
command -v "$1" >/dev/null 2>&1 || exit 127
if [ "$1" = grep ]; then
  for _o in "$@"; do
    [ "$_o" = grep ] && continue
    case "$_o" in
      --) break ;;
      --*) exit 2 ;;
      -*) _r=${_o#-}; case "$_r" in *[!lnqvsciHhefLABCE0-9]*) exit 2 ;; esac ;;
      *) break ;;
    esac
  done
fi
exec "$@"
BBE
cat > $T/bin/getprop <<E
#!/bin/sh
case "\$1" in
  ro.build.product) cat $T/product 2>/dev/null || echo NX4.KOR.0000.V039.001.260902 ;;
  ro.mobis.targetdir) cat $T/targetdir 2>/dev/null || echo /system/onebin/nx4_kr ;;
  ro.mobis.onebindir) echo nx4_kr ;;
  sys.boot_completed) echo 1 ;;
  persist.sys.iap2.wifi) cat $T/iap2 2>/dev/null || echo 0 ;;
  *) echo 0 ;;
esac
E
cat > $T/bin/pm <<E
#!/bin/sh
[ -f $T/feat ] && echo feature:com.hkmc.software.connectivity.carplay_wireless
[ -f $T/hsfeat ] && echo feature:com.hkmc.software.wifihotspot
[ -f $T/nowififeat ] || echo feature:android.hardware.wifi
echo feature:android.hardware.wifi.direct
E
cat > $T/bin/nemesis <<E
#!/bin/sh
echo "nemesis \$*" >> $T/calls
case "\$1" in
  install) case "\$2" in
      *korea.projection.zip) [ -f $T/install_ok ] && mkdir -p $T/apps/korea.projection ;;
      *wireless.projection.zip) [ -f $T/wp_reinstall_fails ] || mkdir -p $T/apps/wireless.projection ;;
    esac ;;
  uninstall) [ "\$2" = wireless.projection ] && [ ! -f $T/wp_stuck ] && rmdir $T/apps/wireless.projection 2>/dev/null ;;
  version) echo 1.16.6 ;;
esac
exit 0
E
cat > $T/bin/hmgapid <<E
#!/bin/sh
echo "hmgapid \$*" >> $T/calls
exit 0
E
for c in svc settings; do printf '#!/bin/sh\necho "%s $*" >> %s/calls\necho 1\n' $c $T > $T/bin/$c; done
# 1.7.1: 패키지는 토스트(am) 대신 알림 기록(NOTICE)에 쓴다. 시험의 알림 기록 파일은 $T/notice(1.7.3 K-2에서 이름을 바꿈).
export NOTICE=$T/notice
printf '#!/bin/sh\ncat %s/ps 2>/dev/null\n' $T > $T/bin/ps
printf '#!/bin/sh\necho "tcp 0 0 192.168.43.1:7000 192.168.43.23:50000 ESTABLISHED"\n' > $T/bin/netstat
# 1.7.0 cp_count는 /proc/net/tcp·tcp6·if_inet6을 읽는다(전역 가짜: 192.168.43.1:7000 ESTABLISHED 1개)
mkdir -p $T/procnet; export PROCNET=$T/procnet
# 1.7.0: Launch마다 Car Report를 뒤에서 만든다. 기본 대기(5분)면 앞 Launch의 것이 잠금을 쥐고 남아 뒤 시험과 섞인다.
# Car Report 자체 시험(cr)은 값을 따로 준다.
export CR_WAIT=0.1 CR_MAX=5 CR_GRACE=0
# 1.7.0: Launch의 로그 모으기는 뒤에서(status.sh --collect) 돈다. 시험은 RPT_SYNC=1로 바로 하고, 뒤에서 도는 경로는 따로 본다.
# 저장 진행 기록(RPROG)도 가짜 위치로
export RPT_SYNC=1 RPROG=$T/rprog
printf '%s\n' "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode" "   0: 012BA8C0:1B58 172BA8C0:C350 01 00000000:00000000 00:00000000 00000000  1000        0 1" > $T/procnet/tcp
echo "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode" > $T/procnet/tcp6; : > $T/procnet/if_inet6
# 1.7.0 cp_count는 wlan0의 주소를 본다: 조회(인자가 wlan0 하나)일 때만 답하고, 설정 호출은 아무것도 내지 않는다
printf '#!/bin/sh\n[ "$#" = 1 ] && [ "$1" = wlan0 ] && { [ -f %s/ifc ] && cat %s/ifc || printf "wlan0 Link encap:Ethernet\\n  inet addr:192.168.43.1  Bcast:192.168.43.255  Mask:255.255.255.0\\n"; }\nexit 0\n' $T $T > $T/bin/ifconfig
printf '#!/bin/sh\n/bin/sleep 0.01\n' > $T/bin/sleep
cat > $T/bin/logcat <<'E'
#!/bin/sh
echo "11-06 20:49:35.100 D/WifiStateMachine(  500): SUP_DISCONNECTION_EVENT wlan0 a1:b2:c3:d4:e5:f6"
echo "11-06 20:49:35.200 D/WifiStateMachine(  500): CONNECT ssid=\"MyHomeNet\""
echo "11-06 20:49:35.300 E/hostapd ( 900): wpa_passphrase secret99"
echo "11-06 20:49:35.400 I/wpa_supplicant( 901): p2p device name Johns phone"
echo "11-06 20:49:35.500 I/OtherApp( 902): wifi stuff"
echo "11-06 20:49:35.600 D/WifiStateMachine(  500): NetworkInfo: type: WIFI extra: \"MyHomeNet\""
echo "11-06 20:49:35.700 I/hostapd ( 900): wlan0: STA xx WPA: pairwise key handshake completed (RSN)"
E
chmod +x $T/bin/*
# /sbin: 맥의 md5sum 위치
fixpath() { sed "s#^export PATH=.*#export PATH=$T/bin:/usr/bin:/bin:/sbin#" "$1"; }

# --- 1. hotspot.sh: softap.conf 해석, 설정 파일 이름 길이, printf ---
python3 - $T/softap.conf <<'E'
import struct,sys
u=lambda s:struct.pack('>H',len(s))+s.encode()
open(sys.argv[1],'wb').write(struct.pack('>i',3)+u('HotspotName1')+u('SSID\\cX')+u('x')+u('PASS\\word99'))
E
cp -R $PKG/* $T/app/
fixpath $PKG/svc/hotspot.sh > $T/app/svc/hotspot.sh
# 1.7.0: Launch의 로그 모으기가 carreport.sh를 직접 부른다. 헤드유닛 PATH로는 맥의 rm·sync를 못 찾아 잠금이 남으므로 맥 경로로
fixpath $PKG/bin/carreport.sh > $T/app/bin/carreport.sh
out=$(HOTSPOT_LIB=1 BB=$T/bin/bb SRC=$T/softap.conf W=$T/w sh -c '. '$T'/app/svc/hotspot.sh; parse_conf $SRC; printf "%s|%s|%s|%s\n" "$NS" "$S2" "$S4" "hostapd $CONF"')
# (맥의 sh echo는 \c를 해석하므로 테스트 쪽도 printf로 출력한다)
check "softap.conf 문자열 4개" '[ "${out%%|*}" = 4 ]'
check "백슬래시가 든 SSID/비밀번호 그대로" 'case "$out" in *"|SSID\\cX|PASS\\word99|"*) true;; *) false;; esac'
cmd=${out##*|}
check "hostapd 명령줄 ${#cmd}자 <= 45 (ps 잘림 대비)" '[ ${#cmd} -le 45 ]'
# 4b K-3: decode를 printf 한 번으로, o2d를 변수로 바꿨다. %·\·공백·한글(UTF-8)·끝 백슬래시가 든 softap.conf에서
# 결과(NS, S1~S5, conf_auth)가 고치기 전 함수(아래 $T/ref-parse.sh)와 바이트까지 같아야 한다
PK=$T/pk; mkdir -p $PK
# 기준: 1.7.2(고치기 전) decode·o2d·parse_conf·conf_auth 원본. 공개 저장소에도 이 시험이 그대로 돌게 파일 대신 여기에 둔다
cat > $T/ref-parse.sh <<'REFP'
# 1.7.2(4b 고치기 전) hotspot.sh의 decode·o2d·parse_conf·conf_auth 원본. 4b K-3 비교 시험(stub-test)의 기준값용이다.
# 제품 코드가 아니다. 고치지 마세요.
# the head unit's busybox (1.8.1) od only knows -b: bytes come as 3-digit octal
# octal bytes -> string
decode() {
  _s=""
  for _b in "$@"; do _s="$_s$($BB printf "\\$_b")"; done
  # mksh의 echo는 \ 이스케이프를 해석하므로 printf %s로 그대로 낸다
  $BB printf '%s\n' "$_s"
}

# one 3-digit octal byte -> decimal (digit by digit: no leading-zero ambiguity)
o2d() {
  _r=${1#?}
  echo $(( ${1%??}*64 + ${_r%?}*8 + ${_r#?} ))
}

# softap.conf on this unit (version 3) isn't stock WifiApConfigStore: Java writeUTF strings
# (2-byte length + bytes): S1 hotspot SSID, S2 CarPlay SSID, S3, S4 CarPlay passphrase.
# Lengths are checked before any arithmetic: a bad $(( )) kills the whole script.
parse_conf() {
  NS=0
  [ -s "$1" ] || return 1
  # od -b lines: 7-digit offset, then 3-digit bytes; keep the bytes only
  set -- $(for _t in $($BB od -b -v "$1"); do [ ${#_t} -eq 3 ] && echo $_t; done)
  N=$#
  [ $N -ge 4 ] || return 1
  i=0
  for _t in "$@"; do eval "o$i=$_t; b$i=$(o2d $_t)"; i=$((i+1)); done
  i=0
  while [ $((i+2)) -lt $N ]; do
    eval "_L=\$(( b$i*256 + b$((i+1)) ))"
    if [ $_L -ge 1 ] && [ $_L -le 63 ] && [ $((i+2+_L)) -le $N ]; then
      _ok=1; j=$((i+2))
      while [ $j -lt $((i+2+_L)) ]; do
        eval "_v=\$b$j"
        if [ $_v -lt 32 ] || [ $_v -gt 126 ]; then _ok=0; break; fi
        j=$((j+1))
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

# 1.5.6: 5GHz 149번으로 띄운다. 순정 핫스팟 기본값(softap.conf)도 5GHz 149번이다.
# 폭은 순정 netd의 149번 설정과 같은 40MHz(HT40+). 20MHz로는 재부팅 뒤 아이폰이 스스로 붙지 않았다(2026-11-07 니로).
# 니로에서 이 설정으로 AP가 뜨고 아이폰 카플레이가 연결됨을 확인했다(2026-11-07 5GHz 시험 USB, 국가 설정 없이).

conf_auth() {
  [ -s "$1" ] || return 0
  set -- $(for _t in $($BB od -b -v "$1"); do [ ${#_t} -eq 3 ] && echo $_t; done)
  _ca=0; _cn=$#; _ci=0
  for _t in "$@"; do eval "_cb$_ci=$(o2d $_t)"; _ci=$((_ci+1)); [ $_ci -ge 200 ] && break; done
  _ci=4
  for _k in 1 2; do
    [ $((_ci+1)) -lt $_cn ] || return 0
    eval "_L=\$(( _cb$_ci*256 + _cb$((_ci+1)) ))"
    [ $_L -le 63 ] || return 0
    _ci=$((_ci+2+_L))
  done
  [ $((_ci+3)) -lt $_cn ] && [ $((_ci+3)) -lt 200 ] || return 0
  eval "_h=\$_cb$_ci"
  [ $_h -le 127 ] || return 0
  eval "echo \$(( _cb$_ci*16777216 + _cb$((_ci+1))*65536 + _cb$((_ci+2))*256 + _cb$((_ci+3)) ))"
}
REFP
python3 - $PK <<'E'
import struct,sys
d=sys.argv[1]
u=lambda b:struct.pack('>H',len(b))+b
cases=[
 [b'My Car %d 50%',b'CP %s%n%%',b'x',b'a\\b\\\\c %s'],
 ['니로 카플'.encode(),'카플레이 Wi-Fi'.encode(),b'z',b'pass word% \\'],
 [b' lead sp ',b'\\n\\t\\0\\x41\\101',b'q',b'%%%%%%%%'+b'\\'*20],
 [b'A'*63,b'~!@#$%^&*()_+`-={}[]|:;"\'<>,.?/',b'r',b'end\\'],
 ['한글SSID%'.encode(),b'ok%1$s',b's','암호'.encode()+b'12345678'],
 # 4b 리뷰 L-2: 0x00·0xff·줄바꿈이 든 문자열, 길이 63·64, 길이만 맞고 깨진 꼬리
 [b'nul\x00in',b'ff\xffin',b'nl\nin',b'ok-ascii-1'],
 [b'B'*63,b'%'*63,b'C'*64,b'\\'*31+b'x'],
 [b'Z\x7f\x1fq',b'tail ok',b'\xff'*5,b'%s%s%s%s'],
]
for n,c in enumerate(cases):
    # 버전 3, 문자열 넷, 그 뒤 보안 방식 4바이트(conf_auth가 읽는 곳)와 꼬리
    open('%s/c%02d'%(d,n),'wb').write(struct.pack('>i',3)+b''.join(u(x) for x in c)+struct.pack('>i',4)+b'\x00\x95\x01')
# 잘린 파일: 둘째 문자열 가운데서 끊김, 길이 칸에서 끊김, 4바이트뿐
full=struct.pack('>i',3)+u(b'Trunc %d SSID')+u(b'Second\\str%')+u(b'x')+u(b'password99')
open('%s/c%02d'%(d,len(cases)),'wb').write(full[:4+2+13+2+5])
open('%s/c%02d'%(d,len(cases)+1),'wb').write(full[:4+2+13+1])
open('%s/c%02d'%(d,len(cases)+2),'wb').write(full[:4])
E
pk() { HOTSPOT_LIB=1 BB=$T/bin/bb SRC=$1 W=$T/w ${PKSH:-sh} -c '. '$T'/app/svc/hotspot.sh; '"$2"'parse_conf $SRC; printf "%s\n" "$NS" "$S1" "$S2" "$S3" "$S4" "$S5" "auth=$(conf_auth $SRC)"'; }
# 1.7.4(B-6): 한글(UTF-8)이 든 c01·c04는 1번째·3번째 문자열의 한글을 이제 읽으므로 예전과 다르다(아래에서 따로 봄). 나머지 9개는 그대로 같아야 한다
PKN=0; PKD=0
for f in $PK/c??; do pk $f '' > $f.new; pk $f '. '$T'/ref-parse.sh; ' > $f.old; PKN=$((PKN+1)); case $f in *c01|*c04) continue ;; esac; cmp -s $f.new $f.old && PKD=$((PKD+1)); done
check "  4b K-3: 특수 글자·0x00·0xff·줄바꿈·길이 63/64·잘린 softap.conf $PKN개(한글 2개 빼고 $PKD개) — parse_conf·conf_auth 결과가 고치기 전과 바이트까지 같음(sh)" '[ $PKN = 11 ] && [ $PKD = 9 ]'
# 4b 리뷰 L-2: 차와 같은 ksh 계열(mksh 등)로도 같은 비교
for PKSH in $KSHS; do
  PKN=0; PKD=0
  for f in $PK/c??; do pk $f '' > $f.kn; pk $f '. '$T'/ref-parse.sh; ' > $f.ko; PKN=$((PKN+1)); case $f in *c01|*c04) cmp -s $f.kn $f.new && PKD=$((PKD+1)); continue ;; esac; cmp -s $f.kn $f.ko && cmp -s $f.kn $f.new && PKD=$((PKD+1)); done
  check "  4b 리뷰 L-2: $(basename $PKSH)로도 $PKN개 모두 sh 결과와 같고, 한글 2개 말고는 고치기 전과도 같음" '[ $PKN = 11 ] && [ $PKD = $PKN ]'
done; unset PKSH
check "  4b 리뷰 L-2: 잘린·깨진 파일도 헛돌지 않음(4바이트뿐이면 NS=0, 둘째 문자열 중간에서 끊기면 첫 문자열만)" '[ "$(head -1 $PK/c10.new)" = 0 ] && [ "$(sed -n 1,2p $PK/c08.new | tr "\n" "|")" = "1|Trunc %d SSID|" ]'
check "  4b K-3: 비교가 헛돌지 않음(ASCII 문자열은 실제로 읽힘: % 와 \\ 가 그대로, conf_auth 숫자 나옴)" 'grep -qx "My Car %d 50%" $PK/c00.new && grep -qx "a\\\\b\\\\\\\\c %s" $PK/c00.new && grep -qx "CP %s%n%%" $PK/c00.old && grep -q "^auth=[0-9]" $PK/c00.new'
# 1.7.4(B-6): c01은 카플레이 SSID(2번째)가 한글이라 예전처럼 읽지 못하고(4개 못 채움), 1번째 한글 이름만 이제 읽힘.
# c04는 1·2·3번째를 읽고 4번째(카플레이 비밀번호)가 한글이라 3개에서 멈춤
check "  1.7.4 B-6: 견본 c01·c04 — 1번째 한글 이름은 읽고, hostapd에 들어가는 2·4번째의 한글은 예전처럼 읽지 않음(4개를 못 채움)" '[ "$(sed -n 1,2p $PK/c01.new | tr "\n" "|")" = "3|니로 카플|" ] && [ "$(sed -n 1,4p $PK/c04.new | tr "\n" "|")" = "3|한글SSID%|ok%1\$s|s|" ] && [ "$(head -1 $PK/c01.old)" -lt 3 ]'
# 1.7.4(B-6): 실제 순정 형식(버전, S1, S2, 키 관리 int, S3, S4, 채널 int 둘, bool, 빈 vendorSpecific, apMode)으로 만든 견본
python3 - $PK <<'E2'
import struct,sys
d=sys.argv[1]
u=lambda b:struct.pack('>H',len(b))+b
I=lambda n:struct.pack('>i',n)
def real(s1,s2,s3,s4): return I(3)+u(s1)+u(s2)+I(4)+u(s3)+u(s4)+I(149)+I(1)+b'\x00'+u(b'')+I(2)
open(d+'/k1','wb').write(real('내 차 핫스팟'.encode(),b'KP-CarPlay1',b'12345678',b'abcdEFGH1234'))
open(d+'/k2','wb').write(real('니로'.encode(),b'CP_A1','암호'.encode()+b'1234',b'pw12345678ab'))
open(d+'/k3','wb').write(real('\U0001F697car'.encode('utf-8'),b'CP_B2',b'x',b'pw12345678ab'))
open(d+'/k4','wb').write(real(b'MyCar',b'CP_C3',b'x',b'pw12345678ab'))
open(d+'/k5','wb').write(real(b'bad\xea\x80',b'CP_D4',b'x',b'pw12345678ab'))
open(d+'/k6','wb').write(real(b'MyCar','카플'.encode(),b'x',b'pw12345678ab'))
open(d+'/k7','wb').write(real(b'bad\xc0\x80x',b'CP_E5',b'x',b'pw12345678ab'))
E2
for f in k1 k2 k3 k4 k5 k6 k7; do pk $PK/$f '' | tr '\n' '|' > $PK/$f.new; pk $PK/$f '. '$T'/ref-parse.sh; ' | tr '\n' '|' > $PK/$f.old; done
check "1.7.4 B-6: 순정 일반 핫스팟 이름이 한글이면 1.7.3까지는 문자열 3개(서비스 시작 안 함), 이제 4개이고 카플레이 SSID·비밀번호가 제자리" '[ "$(cut -d"|" -f1 $PK/k1.old)" = 3 ] && [ "$(cat $PK/k1.new)" = "4|내 차 핫스팟|KP-CarPlay1|12345678|abcdEFGH1234||auth=4|" ]'
check "  B-6: 한글 이름·한글 섞인 일반 핫스팟 비밀번호(3번째)도 4개, 4바이트 글자(이모지) 이름도 4개" '[ "$(cat $PK/k2.new)" = "4|니로|CP_A1|암호1234|pw12345678ab||auth=4|" ] && [ "$(cut -d"|" -f1-3 $PK/k3.new)" = "4|🚗car|CP_B2" ]'
check "  B-6: 영문 이름 파일은 예전과 바이트까지 같음" 'cmp -s $PK/k4.new $PK/k4.old && [ "$(cut -d"|" -f1 $PK/k4.new)" = 4 ]'
check "  B-6: 끝이 잘린 UTF-8(EA 80)·C0 80은 예전처럼 문자열로 보지 않음(결과가 예전과 같음)" 'cmp -s $PK/k5.new $PK/k5.old && cmp -s $PK/k7.new $PK/k7.old'
check "  B-6: hostapd에 들어가는 카플레이 SSID(2번째)가 한글이면 예전처럼 받지 않음(결과가 예전과 같고 4개 못 채움)" 'cmp -s $PK/k6.new $PK/k6.old && [ "$(cut -d"|" -f1 $PK/k6.new)" -lt 4 ]'
for PKSH in $KSHS; do
  PKD=0; for f in k1 k2 k3 k4 k5 k6 k7; do [ "$(pk $PK/$f '' | tr '\n' '|')" = "$(cat $PK/$f.new)" ] && PKD=$((PKD+1)); done
  check "  B-6: $(basename $PKSH)로도 견본 7개 결과가 sh와 같음" '[ $PKD = 7 ]'
done; unset PKSH

# --- 1b. hotspot.sh fix_perms: HMG-API 기록과 같은 권한 파일 되돌리기 (11-06 차의 engine status 줄 그대로) ---
mkdir -p $T/fp/bin $T/fp/perms $T/fp/w
cat > $T/fp/status <<E
CHANGED  $T/fp/perms/com.hkmc.software.connectivity.androidauto_wireless.xml [wireless-carplay-aa] stock fa91812d3eeee415768018ab6ee6804a, expected fa91812d3eeee415768018ab6ee6804a, found absent
CHANGED  $T/fp/perms/com.hkmc.software.connectivity.carplay_wireless.xml [wireless-carplay-aa] stock 95ff801a064526de56059dba10960b05, expected 95ff801a064526de56059dba10960b05, found absent
ok       /system/lib/libleafiaaac.so [wireless-carplay-aa] stock absent, expected a63e6492f38d541518b9606a978f5da3
CHANGED  $T/fp/perms/com.hkmc.software.other.xml [x] stock 00000000000000000000000000000000, expected 00000000000000000000000000000000, found absent
CHANGED  /system/lib/libfoo.so [x] stock 1, expected 2, found absent
CHANGED  /system/onebin/depehev_kr/featurexml.cfg [wireless-carplay-aa] stock c3fa5e8597b0a3e437ee81a6efc0e63a, expected 2a7ca4d59cb0bc3e6165042c1b8c62bc, found c3fa5e8597b0a3e437ee81a6efc0e63a
E
cat > $T/fp/bin/hmgapid <<E
#!/bin/sh
echo "hmgapid \$*" >> $T/fp/calls
case "\$*" in
  ping) [ -f $T/fp/down ] && exit 1; exit 0 ;;
  "engine status") cat $T/fp/status ;;
  "engine plan") cat $T/fp/plan ;;
esac
exit 0
E
printf '#!/bin/sh\n/bin/sleep 0.01\n' > $T/fp/bin/sleep
chmod +x $T/fp/bin/*
cat > $T/fp/plan <<E
rebase   /system/onebin/depehev_kr/featurexml.cfg: changed outside HMG-API (now c3fa), the mods' changes go on it
same     $T/fp/perms/com.hkmc.software.connectivity.androidauto_wireless.xml [wireless-carplay-aa]
same     $T/fp/perms/com.hkmc.software.connectivity.carplay_wireless.xml [wireless-carplay-aa]
change   /system/onebin/depehev_kr/featurexml.cfg [wireless-carplay-aa] -> 2a7ca4d59cb0bc3e6165042c1b8c62bc   [restart the head unit]
same     setting prop/persist.ium.support = carplay [wireless-carplay-aa]
E
echo "/dev/block/system /system ext4 ro,relatime 0 0" > $T/fp/mounts
mkdir -p $T/fp/bk
fp() { (cd $T/fp && PATH=$T/fp/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 NOTICE=$T/fp/notice FIX_DELAY=0 BB=$T/bin/bb W=$T/fp/w BK=$T/fp/bk APLOG=$T/fp/ap.log PERMS=$T/fp/perms MOUNTS=$T/fp/mounts sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$T'/fp/bin:/usr/bin:/bin:/sbin; fix_perms'); }
fpreset() { rm -rf $T/fp/perms $T/fp/calls $T/fp/notice $T/fp/down; mkdir -p $T/fp/perms; }
# cwd($T/fp)에 한 글자 이름 "w" 폴더가 있다: "[wireless-carplay-aa]"가 파일 이름 패턴으로 풀리면 "w"로 바뀌어 잡힌다
fpreset; fp > $T/fp/out
check "fix_perms: 기록과 md5가 같은 권한 파일 2개만 씀" '[ "$(ls $T/fp/perms | wc -l | tr -d " ")" = 2 ] && [ "$(md5sum < $T/fp/perms/com.hkmc.software.connectivity.carplay_wireless.xml | cut -c1-32)" = 95ff801a064526de56059dba10960b05 ]'
check "  md5가 다른 권한 파일·라이브러리·설정 파일은 건드리지 않음" '[ ! -f $T/fp/perms/com.hkmc.software.other.xml ] && grep -q "건너뜀: com.hkmc.software.other" $T/fp/out'
check "  계획이 우리 것뿐 → 일반 apply, --force 안 씀, 재시작 안내" 'grep -qx "hmgapid engine apply" $T/fp/calls && ! grep -q -- --force $T/fp/calls && grep -q "기능 파일을 복구했습니다. 내비를 3분 후 재부팅해 주세요" $T/fp/notice'
check "  /system이 ro였으면 rw → ro로 되돌림" 'grep -q "remount rw" $T/fp/calls && grep -q "remount ro" $T/fp/calls'
check "  1.7.2 P-14: 새로 쓴 권한 파일 이름 2개를 삭제용 기록(perms.ours)에 남김(md5가 다른 것은 없음)" '[ "$(sort $T/fp/bk/perms.ours | tr "\n" " ")" = "com.hkmc.software.connectivity.androidauto_wireless com.hkmc.software.connectivity.carplay_wireless " ]'
rm -f $T/fp/perms/com.hkmc.software.connectivity.carplay_wireless.xml; fp > $T/fp/out
check "    다시 써도 기록에 같은 이름을 겹쳐 적지 않음" '[ "$(wc -l < $T/fp/bk/perms.ours | tr -d " ")" = 2 ]'
# 1.7.4(L-2b): 서비스 쪽 perms_seed 호출을 지웠다(옛 시험 2개는 tests/legacy/removed-1.7.4.md). 서비스는 ap.log에서 옮기지 않고,
# 삭제 때 perms_revert가 함수(perms_seed)로 찾는다(아래 삭제 시험)
# (옛 시험과 같은 준비: 권한 파일은 이미 되돌려져 있고 기록만 없음, ap.log에 1.7.1 꼴 줄. 1.7.3은 이 이름을 기록으로 옮겼다)
rm -f $T/fp/bk/perms.ours $T/fp/calls; printf '%s\n' "11-06 04:10:00 권한 파일 되돌림: com.hkmc.software.connectivity.carplay_wireless" > $T/fp/ap.log; fp > $T/fp/out; rm -f $T/fp/ap.log
check "    1.7.4 L-2b: 서비스 시작(_fix_perms가 실제로 돌아 HMG-API를 부름)은 ap.log의 옛 이름을 기록(perms.ours)으로 옮기지 않음" 'grep -q "^hmgapid " $T/fp/calls && ! grep -q "carplay_wireless" $T/fp/bk/perms.ours 2>/dev/null'
fpreset; rm -f $T/fp/calls $T/fp/notice; fp > $T/fp/out
rm -f $T/fp/calls $T/fp/notice; fp > $T/fp/out
check "  파일이 이미 있으면 다시 쓰지도 apply하지도 않음" '! grep -q "engine apply" $T/fp/calls && [ ! -f $T/fp/notice ]'
fpreset; echo "/dev/block/system /system ext4 rw,relatime 0 0" > $T/fp/mounts; fp > $T/fp/out
check "  /system이 원래 rw였으면 ro로 바꾸지 않음" '! grep -q "remount ro" $T/fp/calls'
echo "/dev/block/system /system ext4 ro,relatime 0 0" > $T/fp/mounts
fpreset; cp $T/fp/plan $T/fp/plan.ok; echo "change   /system/app/HKMC_DiPO.apk [other-mod] -> 1234   [restart the app]" >> $T/fp/plan; fp > $T/fp/out
check "  계획에 다른 변경이 있으면 apply하지 않고 앱에서 적용하라고 안내" '! grep -qx "hmgapid engine apply" $T/fp/calls && grep -q "HMG-API 앱에서" $T/fp/notice'
cp $T/fp/plan.ok $T/fp/plan
fpreset; sed 's/change   \/system\/onebin\/depehev_kr\/featurexml.cfg \[wireless-carplay-aa\]/change   \/system\/onebin\/depehev_kr\/featurexml.cfg [other-mod]/' $T/fp/plan.ok > $T/fp/plan; fp > $T/fp/out
check "  featurexml.cfg 변경이 다른 모드 것이면 apply 안 함" '! grep -qx "hmgapid engine apply" $T/fp/calls'
fpreset; cp $T/fp/plan.ok $T/fp/plan; echo "rebase   /system/app/X.apk: changed outside HMG-API (now 1), the mods' changes go on it" >> $T/fp/plan; fp > $T/fp/out
check "  featurexml.cfg 아닌 rebase가 있으면 apply 안 함" '! grep -qx "hmgapid engine apply" $T/fp/calls'
fpreset; cp $T/fp/plan.ok $T/fp/plan; echo "WARNING: the car's ADB TCP switch is on" >> $T/fp/plan; fp > $T/fp/out
check "  ADB 경고 같은 WARNING 줄은 막지 않음" 'grep -qx "hmgapid engine apply" $T/fp/calls'
fpreset; cp $T/fp/plan.ok $T/fp/plan; mv $T/fp/mounts $T/fp/mounts.x; fp > $T/fp/out; mv $T/fp/mounts.x $T/fp/mounts
check "  /proc/mounts를 못 읽으면 ro로 보고 ro로 되돌림" 'grep -q "remount ro" $T/fp/calls'
cp $T/fp/plan.ok $T/fp/plan
fpreset; touch $T/fp/down; fp > $T/fp/out
check "  HMG-API 데몬이 안 뜨면 아무것도 안 하고 기록만" '[ -z "$(ls $T/fp/perms)" ] && grep -q "데몬 응답 없음" $T/fp/out'

# 시작할 때의 stop_ap는 뒤에서 도는 확인 작업(fix.pid)을 건드리지 않고, 끝낼 때의 stop_all만 정리한다
mkdir -p $T/sa; echo "12345 boot" > $T/sa/fix.pid
(PATH=$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB=$T/bin/bb W=$T/sa sh -c '. '$T'/app/svc/hotspot.sh; stop_ap') >/dev/null 2>&1
check "stop_ap(시작 때)는 fix.pid를 남김" '[ -f $T/sa/fix.pid ]'
(PATH=$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB=$T/bin/bb W=$T/sa sh -c '. '$T'/app/svc/hotspot.sh; stop_all') >/dev/null 2>&1
check "stop_all(끝낼 때)는 fix.pid를 정리" '[ ! -f $T/sa/fix.pid ]'
# 1.5.6: 5GHz 149번 설정, Wi-Fi 연결 기록(커널 로그), 카플레이 연결 수 변화
WE=$T/we; mkdir -p $WE/bin $WE/w; echo boot-A > $WE/bootid
printf '#!/bin/sh\ncat %s/dmesg 2>/dev/null\n' $WE > $WE/bin/dmesg
printf '#!/bin/sh\ncat %s/netstat 2>/dev/null\n' $WE > $WE/bin/netstat; chmod +x $WE/bin/*
we() { (PATH=$WE/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB=$T/bin/bb W=$WE/w BOOT_ID=$WE/bootid CONF=$WE/hk.conf sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$WE'/bin:'$T'/bin:/usr/bin:/bin:/sbin; S2=SSIDx S4=PASS12345; '"$1"); }
we write_conf
check "1.5.6: 우리 hostapd는 5GHz 149번(hw_mode=a), 순정 netd와 같은 40MHz(HT40+), 2.4GHz 줄 없음" 'grep -qx "channel=149" $WE/hk.conf && grep -qx "hw_mode=a" $WE/hk.conf && grep -qx "ht_capab=\[HT40+\]\[SHORT-GI-20\]\[SHORT-GI-40\]" $WE/hk.conf && ! grep -q -e "^channel=6" -e "^hw_mode=g" $WE/hk.conf'
printf '%s\n' "<4>[   21.17] Firmware version = wl0: version 9.92.1" "<6>[  632.555666] CFG80211-ERROR) wl_cfg80211_set_channel : netdev_ifidx(10), chan_type(1) target channel(149) channel_width(1000)" "<6>[  632.605213] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **" "<4>[  701.367538] ETHER_TYPE_802_1X[wlan0] [RX] : M2 of 4way" "<4>[  701.372626] ETHER_TYPE_802_1X[wlan0] [RX] : M4 of 4way" "<6>[  773.805023] CFG80211-ERROR) wl_cfg80211_del_station : Disconnect STA : aa:bb:cc:dd:ee:ff scb_val.val 3" "no bracket line HANG" > $WE/dmesg
we wifi_events > $WE/out1
check "  Wi-Fi 연결 기록: 채널·AP 올라옴·연결(인증 끝)·끊김을 커널 시각과 함께, MAC은 없음" '[ "$(grep -c "Wi-Fi: " $WE/out1)" = 4 ] && grep -q "Wi-Fi: AP 채널 149 (커널 632초)" $WE/out1 && grep -q "Wi-Fi: AP 올라옴 (커널 632초)" $WE/out1 && grep -q "Wi-Fi: 기기 연결(Wi-Fi 인증 끝) (커널 701초)" $WE/out1 && grep -q "Wi-Fi: 기기 연결 끊김 (커널 773초)" $WE/out1 && ! grep -q -e "aa:bb" -e HANG $WE/out1'
we wifi_events > $WE/out2
check "  같은 커널 로그는 다시 남기지 않음(어디까지 남겼는지 기억)" '[ ! -s $WE/out2 ] && grep -q "^boot-A 773.805" $WE/w/ktime'
echo "<6>[  800.1] CFG80211-ERROR) wl_cfg80211_del_station : Disconnect STA : aa:bb:cc:dd:ee:ff" >> $WE/dmesg; we wifi_events > $WE/out3
check "  새로 생긴 줄만 남김" '[ "$(grep -c "Wi-Fi: " $WE/out3)" = 1 ] && grep -q "커널 800초" $WE/out3'
# 1.7.4(L-4): wifi_events·aa_events는 서비스가 읽어 둔 BID를 쓴다. BID가 있을 때와 없을 때 출력·기록이 바이트까지 같음
rm -f $WE/w/ktime $WE/bk/ktime 2>/dev/null; we wifi_events > $WE/l4a; cp $WE/w/ktime $WE/l4a.k
rm -f $WE/w/ktime $WE/bk/ktime 2>/dev/null; we 'BID=$(cat '$WE'/bootid); wifi_events' > $WE/l4b; cp $WE/w/ktime $WE/l4b.k
check "  1.7.4 L-4: 부팅 id를 BID로 받아도(30초마다 cat 안 함) wifi_events 출력·기록(ktime)이 바이트까지 같음, aa_events도 BID를 씀(소스)" '[ "$(sed "s/^[0-9-]* [0-9:]* //" $WE/l4a)" = "$(sed "s/^[0-9-]* [0-9:]* //" $WE/l4b)" ] && cmp -s $WE/l4a.k $WE/l4b.k && [ -s $WE/l4a.k ] && [ "$(grep -c "_bid=\${BID:-\$(cat \${BOOT_ID:-/proc/sys/kernel/random/boot_id} 2>/dev/null)}; _bid=\${_bid:-none}" $PKG/svc/hotspot.sh)" = 2 ]'
echo boot-B > $WE/bootid; printf '%s\n' "<6>[   30.5] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **" > $WE/dmesg; we wifi_events > $WE/out4
check "  재부팅하면(부팅 id가 다름) 커널 시각이 작아도 처음부터 남김" 'grep -q "Wi-Fi: AP 올라옴 (커널 30초)" $WE/out4'
echo boot-C > $WE/bootid; printf '%s\n' "<6>[    5.8] IPv6: ADDRCONF(NETDEV_CHANGE): ncm0: link becomes ready" "<6>[  300.0] CFG80211-ERROR) wl_cfg80211_del_station : Disconnect STA : ff:ff:ff:ff:ff:ff scb_val.val 3" "<4>[  301.0] dhd_os_send_hang: HANG event sent" > $WE/dmesg; we wifi_events > $WE/out5
check "  유선 카플레이(NETDEV_CHANGE)는 HANG으로 세지 않고, hostapd 시작 때 모두 비우는 끊김(ff:ff…)도 세지 않음, 진짜 HANG은 남김" '! grep -q "기기 연결 끊김" $WE/out5 && [ "$(grep -c "HANG" $WE/out5)" = 1 ] && grep -q "Wi-Fi 칩 응답 없음(HANG) (커널 301초)" $WE/out5'
# 1.7.1: 무선 AA 단계 기록(aa_events). 니로 성공 시도(2026-11-08 02:16)의 줄 꼴. 폰 이름(Pixel7·홍길동폰)이 섞여 있다.
echo boot-A > $WE/bootid
cat > $WE/aalog <<'E'
11-08 02:16:26.180 D/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] broadcast action = android.bluetooth.device.action.START_SPP_CONNECT_FOR_CONNECTIVITY
11-08 02:16:27.850 I/AAProjection(  775): WirelessExplorer : [Pixel7] Sent WifiVersionRequest, Protocol version is 1.0	isRetry :false
11-08 02:16:27.940 D/AAProjection(  775): WirelessExplorer : 	WifiVersionResponse hasDeviceSerial: true	wirelessSupported = true
11-08 02:16:31.950 I/PhoneProjection( 1660): [ f ] getWiFiApMode wifiMode = 2
11-08 02:16:32.120 D/AAProjection(  775): WirelessExplorer : isWifiApEnable = true, mode = 2
11-08 02:16:32.170 D/AAProjection(  775): WirelessExplorer : [홍길동폰] Sent start request
11-08 02:16:32.410 I/AAProjection(  775): GalReceiverService : MSG_WIFI_TRANSPORT_INIT retu = 0
11-08 02:16:33.000 I/OtherApp(  1): Sent start request from someone else
E
printf '#!/bin/sh\ncat %s/aalog\n' $WE > $WE/bin/logcat; chmod +x $WE/bin/logcat
we aa_events > $WE/aa1
check "1.7.1 AA 단계 기록: 성공 시도 7단계를 순서대로 ap.log에, 이름·다른 태그 줄은 없음" '[ "$(grep -c "안드로이드 오토: " $WE/aa1)" = 7 ] && grep -q "안드로이드 오토: 블루투스로 연결 시작(SPP) (02:16:26.180)" $WE/aa1 && grep -q "폰 무선 지원 true" $WE/aa1 && grep -q "AP 모드 2 " $WE/aa1 && grep -q "AP 켜짐 true 모드 2" $WE/aa1 && grep -q "폰에 Wi-Fi 연결 요청" $WE/aa1 && grep -q "Wi-Fi 연결 준비 결과 0" $WE/aa1 && ! grep -q -E "Pixel7|홍길동|someone" $WE/aa1'
we aa_events > $WE/aa2
check "  같은 줄은 다시 남기지 않음(logcat 시각 기억)" '[ ! -s $WE/aa2 ] && grep -q "^boot-A 11-08 02:16:32.410" $WE/w/aatime'
printf '%s\n' "11-08 02:20:00.000 D/AAProjection(  775): GalReceiverService : Received ACTION_WIRELESS_SPP_CONNECT_TIMEOUT, address = 11:22:33:44:55:66" "11-08 02:20:00.100 W/AAProjection(  775): WirelessExplorer : ==> rfcommDisconnect, Start Wireless Session and Attached, but rfcommDisconnect" "11-08 02:20:01.000 I/PhoneProjection( 1660): [ f ] getWiFiApMode wifiManager.isWifiApEnabled() = false, return APMode.UNKNOWN" >> $WE/aalog
we aa_events > $WE/aa3
check "  새 줄만: 시간 초과·RFCOMM 끊김·AP 모드 모름, 주소는 없음" '[ "$(grep -c "안드로이드 오토: " $WE/aa3)" = 3 ] && grep -q "SPP 연결 시간 초과" $WE/aa3 && grep -q "블루투스 RFCOMM 끊김" $WE/aa3 && grep -q "AP 모드 모름" $WE/aa3 && ! grep -q "11:22:33" $WE/aa3'
rm -f $WE/w/aatime; (AAEV_MAX=3; export AAEV_MAX; we aa_events) > $WE/aa4
check "  한 번에 최대 AAEV_MAX줄(재시도가 몰려도 ap.log가 넘치지 않음)" '[ "$(grep -c "안드로이드 오토: " $WE/aa4)" = 3 ]'
printf '%s\n' "11-08 02:20:02.000 E/AAProjection(  775): WirelessExplorer : isWifiApEnable = false !!!" >> $WE/aalog; we aa_events > $WE/aa3b
check "  mode가 없는 isWifiApEnable 줄(니로 실제 꼴)은 'AP 켜짐 false'만, 시각을 값으로 잘라 오지 않음(리뷰 M2)" 'grep -q "AP 켜짐 false (02:20:02.000)" $WE/aa3b && ! grep -q "모드 [0-9]" $WE/aa3b'
echo boot-B > $WE/bootid; we aa_events > $WE/aa5
check "  재부팅(부팅 id가 다름)하면 처음부터 다시 봄" '[ "$(grep -c "안드로이드 오토: " $WE/aa5)" = 11 ]'
check "  서비스 30초 회차·순정 AP 회차 모두 aa_events를 부름" '[ "$(grep -c "wifi_events; aa_events; cp_watch" $T/app/svc/hotspot.sh)" = 4 ]'
# 1.7.3(모드 2.4.1, A-1): 모드가 준비(1)를 다시 보낸 줄과 훅 줄. 숫자·이유만 옮기고, 혹시 섞인 MAC 꼴은 지움
rm -f $WE/w/aatime
printf '%s\n' "11-10 09:00:00.100 I/HMG-API (  775): Android Auto: ready resend hook in com.google.android.projection.sink (active only while sys.kp.aa_ap=1)" "11-10 09:00:05.200 I/HMG-API (  775): [wireless-carplay-aa] AA 준비 다시 보냄 2대" "11-10 09:00:06.300 I/HMG-API (  775): [wireless-carplay-aa] AA 준비 다시 보냄 0대 (이미 연결됨)" "11-10 09:00:07.400 I/HMG-API (  775): [wireless-carplay-aa] AA 준비 다시 보냄 1대 (실패 1) AA:BB:CC:DD:EE:FF" > $WE/aalog241
printf '#!/bin/sh\ncat %s/aalog241\n' $WE > $WE/bin/logcat; chmod +x $WE/bin/logcat
we aa_events > $WE/aa241
check "1.7.3 모드 2.4.1: '준비 다시 보냄 N대'·'0대 (이미 연결됨)'·훅 줄을 ap.log에, MAC 꼴은 지움" 'grep -q "안드로이드 오토: 모드가 준비 다시 보냄 2대 (09:00:05.200)" $WE/aa241 && grep -q "안드로이드 오토: 모드가 준비 다시 보냄 0대 (이미 연결됨) (09:00:06.300)" $WE/aa241 && grep -q "안드로이드 오토: 모드의 준비 다시 보내기 훅 걸림(com.google.android.projection.sink) (09:00:00.100)" $WE/aa241 && ! grep -q "AA:BB" $WE/aa241'
# 1.7.4(모드 2.4.2): 새 줄 두 가지. "신호 없음 60초"는 정상 줄로 표시하고, 판정(aa 안내)에는 쓰지 않음
printf '%s\n' "11-10 09:01:00.100 I/HMG-API (  775): [wireless-carplay-aa] AA 준비 다시 보냄 신호 기다림 12초" "11-10 09:01:00.200 I/HMG-API (  775): [wireless-carplay-aa] AA 준비 다시 보냄 1대" "11-10 09:02:00.300 I/HMG-API (  775): [wireless-carplay-aa] AA 준비 다시 보냄 0대 (신호 없음 60초)" "11-10 09:02:01.400 I/HMG-API (  775): [wireless-carplay-aa] AA 준비 다시 보냄 못 함 (IllegalStateException)" > $WE/aalog242
printf '#!/bin/sh\ncat %s/aalog242\n' $WE > $WE/bin/logcat; chmod +x $WE/bin/logcat; rm -f $WE/w/aatime $WE/hint
we 'HINT_ON=1; aa_events' > $WE/aa242; printf '#!/bin/sh\ncat %s/aalog2\n' $WE > $WE/bin/logcat; chmod +x $WE/bin/logcat; rm -f $WE/w/aatime
check "1.7.4 모드 2.4.2 줄: '신호 기다림 N초'는 '신호를 N초 기다린 뒤 다시 보냄', '0대 (신호 없음 60초)'는 정상 줄로 표시, 못 함은 그대로" 'grep -q "안드로이드 오토: 모드가 AA 신호를 12초 기다린 뒤 준비 다시 보냄 (09:01:00.100)" $WE/aa242 && grep -q "안드로이드 오토: 모드가 준비 다시 보냄 1대 (09:01:00.200)" $WE/aa242 && grep -q "안드로이드 오토: 모드: 60초 동안 AA 신호가 없어 준비 다시 보내기를 하지 않음(정상: AA를 쓰지 않아도 나옴) (09:02:00.300)" $WE/aa242 && grep -q "모드가 준비 다시 보냄 못 함 (IllegalStateException)" $WE/aa242 && ! grep -q "0대 (신호 없음" $WE/aa242'
check "  모드 2.4.2 줄(소스 검사): '준비 다시 보냄' 갈래는 판정 표시(f)를 세우지 않음(연결됨·안 됨 판정에 안 씀)" 'awk "/index\(\\\$0, \"AA 준비 다시 보냄\"\) > 0\)/{f=1} f{print} f&&/^ *else e = /{exit}" $PKG/svc/hotspot.sh > $WE/rsb && [ -s $WE/rsb ] && ! grep -q "f = " $WE/rsb'
# 확정 2.4.1: 모드 타이머 예외 줄(연결마다 한 번)을 ap.log에. 예외 이름만(영문·숫자·점)
rm -f $WE/w/aatime
printf '%s\n' "11-10 09:01:00.100 W/HMG-API (  775): [wireless-carplay-aa] AA: timer error java.lang.NullPointerException: x a1:b2:c3:d4:e5:f6" > $WE/aalogte
printf '#!/bin/sh\ncat %s/aalogte\n' $WE > $WE/bin/logcat; chmod +x $WE/bin/logcat
we aa_events > $WE/aate
check "  확정 2.4.1: 'AA: timer error <종류>' → '모드 타이머 오류(종류)' 한 줄, 뒤의 글·MAC은 옮기지 않음" 'grep -q "안드로이드 오토: 모드 타이머 오류(java.lang.NullPointerException) (09:01:00.100)" $WE/aate && ! grep -q "a1:b2" $WE/aate'
rm -f $WE/bin/logcat $WE/w/aatime; echo boot-A > $WE/bootid
: > $WE/bootid; printf '%s\n' "<6>[  400.0] ** AP/GO Link up event **" > $WE/dmesg; we wifi_events > $WE/out6; we wifi_events > $WE/out7
check "  부팅 id를 못 읽어도 같은 줄을 30초마다 다시 남기지 않음" '[ "$(grep -c "AP 올라옴" $WE/out6)" = 1 ] && [ ! -s $WE/out7 ]'
check "  디버그 로그는 태그와 상관없이 Wi-Fi 이름·비밀번호가 나올 수 있는 줄을 버림, 설치 때 함께 넣은 busybox를 지우지 않음(1.6.2)" 'grep -q "grep -v -i -E .ssid|psk \*\[=:\]|passphrase|password|bssid|key=." $T/app/svc/hotspot.sh && for l in "I/GPM ( 1): wifi ssid HomeNet" "I/GPM ( 1): psk=Secret1" "I/GPM ( 1): PSK : Secret2" "I/GPM ( 1): passphrase x"; do echo "$l" | grep -v -i -E "ssid|psk *[=:]|passphrase|password|bssid|key=" | grep -q . && exit 1; done; echo "I/Iap2Service ( 1): Wifi Access Auth Type :  WPA2_PSK" | grep -v -i -E "ssid|psk *[=:]|passphrase|password|bssid|key=" | grep -q WPA2_PSK && ! grep -q "rm .*bin/busybox" $T/app/scripts/post.sh'
mkdir -p $WE/pn; echo "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode" > $WE/pn/tcp6; : > $WE/pn/if_inet6; echo "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode" > $WE/pn/tcp
(PROCNET=$WE/pn; we cp_watch) > $WE/c1
printf '%s\n' "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode" "   0: 012BA8C0:1B58 172BA8C0:CB20 01 0" "   1: 012BA8C0:1B58 172BA8C0:BF68 06 0" > $WE/pn/tcp
(PROCNET=$WE/pn; we cp_watch) > $WE/c2; (PROCNET=$WE/pn; we cp_watch) > $WE/c3; echo "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode" > $WE/pn/tcp; (PROCNET=$WE/pn; we cp_watch) > $WE/c4
check "  카플레이 연결 수(ESTABLISHED만)가 바뀔 때만 남김: 0→1, 같으면 없음, 1→0" '[ ! -s $WE/c1 ] && grep -q "카플레이 연결 0 → 1" $WE/c2 && [ ! -s $WE/c3 ] && grep -q "카플레이 연결 1 → 0" $WE/c4'
# 1.7.0: 무선 카플레이 연결 수 = /proc/net/tcp·tcp6에서 로컬 포트 7000(1B58)·ESTABLISHED(01)·로컬 주소가 wlan0 주소인 것
mkdir -p $WE/pn
printf '%s\n' "fe80000000000000021122fffe334455 07 40 20 80    wlan0" "fe800000000000000a0b0cfffe0d0e0f 05 40 20 80     ncm0" > $WE/pn/if_inet6
printf '%s\n' "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode" "   0: 012BA8C0:1B58 172BA8C0:CB20 01 0" "   1: 0101A8C0:1B58 1401A8C0:C351 01 0" "   2: 00000000:1B58 00000000:0000 0A 0" "   3: 012BA8C0:1B58 172BA8C0:BF68 06 0" "   4: 012BA8C0:1B59 172BA8C0:BF69 01 0" > $WE/pn/tcp
printf '%s\n' "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode" "   0: 000080FE00000000FF221102554433FE:1B58 000080FE00000000FF221102AABBCCDD:C352 01 0" "   1: 000080FE00000000FF0C0B0A0F0E0DFE:1B58 000080FE00000000FF0C0B0A11223344:C353 01 0" "   2: 0000000000000000FFFF0000012BA8C0:1B58 0000000000000000FFFF0000172BA8C0:C354 01 0" > $WE/pn/tcp6
printf 'wlan0 Link encap:Ethernet\n  inet addr:192.168.43.1  Mask:255.255.255.0\n' > $T/ifc
check "1.7.0 cp_count: wlan0 IPv4·긴 IPv6·IPv4-in-IPv6만 셈(3), 다른 망·LISTEN·TIME_WAIT·다른 포트·유선(ncm0)은 안 셈" '[ "$(PROCNET=$WE/pn we cp_count)" = 3 ]'
printf 'wlan0 Link encap:Ethernet\n  inet addr:192.168.1.1  Mask:255.255.255.0\n' > $T/ifc
check "  순정 AP 차(wlan0 주소가 다름, K3)는 그 주소로 셈(192.168.1.1 1개 + wlan0 IPv6 1개)" '[ "$(PROCNET=$WE/pn we cp_count)" = 2 ]'
# 1.7.1: 순정 AP가 ap0에 뜨는 차(차에서 본 적 없음): wlan0 IPv4는 없고 ap0이 192.168.1.1
mkdir -p $WE/sn/ap0; printf 'eth0 x\n' > $T/ifc
printf '#!/bin/sh\n[ "$1" = ap0 ] && { printf "ap0 Link encap:Ethernet\\n  inet addr:192.168.1.1  Mask:255.255.255.0\\n"; exit 0; }\nexec %s/bin/ifconfig "$@"\n' $T > $WE/bin/ifconfig; chmod +x $WE/bin/ifconfig
check "1.7.1 cp_count: ap0 같은 인터페이스의 주소도 셈(ap0 IPv4 1개 + wlan0 IPv6 1개)" '[ "$(SYSNET=$WE/sn PROCNET=$WE/pn we cp_count)" = 2 ] && [ "$(SYSNET=$WE/sn we cp_ifs)" = "wlan0 ap0" ]'
check "  ap0이 없으면 wlan0만(wlan0 IPv6 1개)" '[ "$(SYSNET=$WE/nosn PROCNET=$WE/pn we cp_count)" = 1 ]'
rm -f $WE/bin/ifconfig; rm -rf $WE/sn
: > $WE/pn/if_inet6; printf 'eth0 x\n' > $T/ifc
check "  wlan0 주소를 못 읽으면 0" '[ "$(PROCNET=$WE/pn we cp_count)" = 0 ]'
rm -f $WE/pn/if_inet6 $WE/pn/tcp6; rm -f $T/ifc
check "  IPv6 파일이 없는 커널에서도 IPv4는 셈" '[ "$(PROCNET=$WE/pn we cp_count)" = 1 ]'
rm -rf $WE/pn/*
check "  /proc/net 파일이 하나도 없으면 0(멈추지 않음)" '[ "$(PROCNET=$WE/pn we cp_count </dev/null)" = 0 ]'
check "  리포트·상태 파일·알림·서비스 로그가 모두 cp_count를 씀(netstat으로 세는 곳이 남지 않음, status.sh는 K_CP 한 번으로 셈 — 4b K-3)" '! grep -n "netstat" $PKG/svc/hotspot.sh $PKG/bin/status.sh | grep -v "^[^:]*:[0-9]*:[[:space:]]*#" | grep -q . && [ "$(grep -c "cp_count)" $PKG/bin/status.sh)" = 1 ] && grep -q "K_CP=\$(cp_count)" $PKG/bin/status.sh'
# 1.7.0: 무선 안드로이드 오토 신호(기본 켜짐). 우리 hostapd가 돌 때만 sys.kp.aa_ap=1, 바뀔 때만 setprop. 1.7.4(L-9): 끄기 표시(aa-off)는 보지 않는다
printf '#!/bin/sh\ncase "$1" in sys.kp.aa_ap) cat %s/aaprop 2>/dev/null ;; *) exec %s/bin/getprop "$@" ;; esac\n' $WE $T > $WE/bin/getprop
printf '#!/bin/sh\necho "setprop $*" >> %s/setprops; [ "$1" = sys.kp.aa_ap ] && echo "$2" > %s/aaprop\nexit 0\n' $WE $WE > $WE/bin/setprop
chmod +x $WE/bin/getprop $WE/bin/setprop
cp $T/ps $WE/ps.keep 2>/dev/null; rm -f $WE/aaprop $WE/setprops $WE/aa-off
: > $WE/aa-off; echo "  1 root 0 S hostapd $WE/hk.conf" > $T/ps
(AAOFF=$WE/aa-off; export AAOFF; we aa_sig) > $WE/a1
check "1.7.4 L-9: 끄기 표시(aa-off)가 남아 있어도 aa_sig는 보지 않음(우리 hostapd면 1, 켜짐 로그)" '[ "$(cat $WE/aaprop)" = 1 ] && grep -q "무선 안드로이드 오토(시험) 켜짐" $WE/a1'
rm -f $WE/aaprop $WE/setprops
rm -f $WE/aa-off; (AAOFF=$WE/aa-off; export AAOFF; we aa_sig) > $WE/a2; (AAOFF=$WE/aa-off; export AAOFF; we aa_sig) > $WE/a3
check "  기본(끄기 표시 없음) + 우리 hostapd → 1, 로그 한 줄, 같은 값이면 다시 안 함" '[ "$(cat $WE/aaprop)" = 1 ] && [ "$(grep -c "sys.kp.aa_ap 1" $WE/setprops)" = 1 ] && grep -q "무선 안드로이드 오토(시험) 켜짐" $WE/a2 && [ ! -s $WE/a3 ]'
: > $T/ps; we aa_sig > $WE/a4
check "  우리 hostapd가 멈추면 0" '[ "$(cat $WE/aaprop)" = 0 ] && grep -q "신호 끔" $WE/a4'
echo "  1 root 0 S hostapd $WE/hk.conf" > $T/ps; we aa_sig >/dev/null; we stop_ap >/dev/null 2>&1
check "  stop_ap(서비스 끝·비켜 주기·삭제)는 신호를 0으로" '[ "$(cat $WE/aaprop)" = 0 ]'
echo "  1 root 0 S hostapd $WE/hk.conf" > $T/ps; we aa_sig >/dev/null
printf '%s\n' "  1 root 0 S hostapd $WE/hk.conf" "  2 root 0 S hostapd /data/misc/wifi/hostapd.conf" > $T/ps
we 'prod=TESTX.KOR.1.260902; ap_yield' >/dev/null 2>&1
check "  다른 hostapd에 비켜 주면 신호 0(리뷰 M1)" '[ "$(cat $WE/aaprop)" = 0 ]'
echo "  1 root 0 S hostapd $WE/hk.conf" > $T/ps
(PATH=$WE/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB=$T/bin/bb BB_OWN=$T/bin/bb W=$WE/w BOOT_ID=$WE/bootid CONF=$WE/hk.conf sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$WE'/bin:'$T'/bin:/usr/bin:/bin:/sbin; aa_sig') >/dev/null 2>&1
check "  1.7.2(P-6): 함께 넣은 busybox를 쓰는 내비(tcc803x)도 순정 AP 기록이 없으면 신호를 켬(BB_OWN 조건 뺌)" '[ "$(cat $WE/aaprop)" = 1 ]'
check "  로그·신호에 SSID·비밀번호 값이 없음" '! grep -q -e SSIDx -e PASS12345 $WE/a2 $WE/a4 $WE/setprops'
check "  순정 AP 경로(stock_ap_mode)는 신호를 켜지 않음(aa_sig를 부르지 않음)" '[ -z "$(awk "/^stock_ap_mode\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep "aa_sig")" ]'
check "  1.7.4 L-9: 설치(post.sh)는 USB의 kp-aa-off·kp-aa-on을 읽지 않고 끄기 표시를 만들거나 지우지 않음" '! grep -v "^ *#" $PKG/scripts/post.sh | grep -q -e "kp-aa-o" -e "aa-off"'
check "  모드의 hooks.jar(무선 2.4.5)에 AA 훅이 있음(속성 이름이 패키지와 같음, AP 설정 저장도 막음)" 'cp $PKG/hooks.jar $WE/hj.jar && unzip -p $WE/hj.jar classes.dex | strings | grep -qx "sys.kp.aa_ap" && unzip -p $WE/hj.jar classes.dex | strings | grep -qx "setWifiApConfiguration" && grep -q "^AAPROP=sys.kp.aa_ap$" $PKG/svc/hotspot.sh'
cp $WE/ps.keep $T/ps 2>/dev/null || : > $T/ps
# 1.7.0: Wi-Fi 장치(wlan0)가 없어 hostapd가 바로 꺼지는 차(그랜저 IG #52·#53). 이번 부팅에 한 번만 남기고 순정 Wi-Fi 기록을 파일로
echo boot-W > $WE/bootid; rm -f $WE/w/nowlan $WE/w/nowlan-wifi.txt; : > $T/ps
(WLAN=$WE/no-wlan0; export WLAN; we up) > $WE/u1 2>&1; (WLAN=$WE/no-wlan0; export WLAN; we up) > $WE/u2 2>&1
check "1.7.0 wlan0 없음: 처음 한 번 'Wi-Fi 장치(wlan0)가 없음'과 순정 Wi-Fi 기록 파일, 같은 부팅의 다음 시도는 조용히(34초마다 반복 줄 없음)" 'grep -q "Wi-Fi 장치(wlan0)가 없음" $WE/u1 && grep -q "^wifi_on=" $WE/w/nowlan-wifi.txt && [ "$(cat $WE/w/nowlan)" = boot-W ] && ! grep -q -e "hostapd 시작" -e "wlan0)가 없음" $WE/u2'
check "  5GHz 실패 문구로 오해하게 쓰지 않음" '! grep -q "5GHz" $WE/u1'
echo boot-X > $WE/bootid; (WLAN=$WE/no-wlan0; export WLAN; we up) > $WE/u3 2>&1
check "  다음 부팅에는 다시 한 번 남김" 'grep -q "Wi-Fi 장치(wlan0)가 없음" $WE/u3'
(we 'c=0; running() { c=$((c+1)); [ $c -gt 1 ]; }; up') > $WE/u4 2>&1
check "  wlan0가 생겨 hostapd가 켜지면 기록을 지우고 한 줄 남김" 'grep -q "Wi-Fi 장치(wlan0)가 생겨 hostapd가 켜짐" $WE/u4 && [ ! -f $WE/w/nowlan ]'
check "  상태 파일 nowlan 키" 'grep -q "K_NOWLAN=\$(yesno nowlan_now)" $PKG/bin/status.sh && grep -q "echo \"nowlan=\$K_NOWLAN\"" $PKG/bin/status.sh'
# 1.7.0: 폰 프로젝션 기록의 가리기(KPMASK). #47 꼴(괄호 안 한글·띄어쓰기 이름)과 한 낱말 이름(Pixel7 등), C·UTF-8 로케일 모두
for loc in C en_US.UTF-8; do
  (LC_ALL=$loc; export LC_ALL; we 'awk "$KPMASK"') < $B/tests/kpmask-sample.txt > $WE/km.$loc
done
check "1.7.0 가리기: 폰 이름·SSID·비밀번호·MAC·다른 IP가 0건(C·UTF-8)" '! grep -q -E "홍길동|Fold7|Pixel7|GalaxyS24|MyPhone|MyNet|secret|AA:BB|AA-BB|1234 5678|abcdefgh1|10\.0\.0\.5|01098765432|홍길동|Kim Office|0212345678|02-1234-5678|1588-1234|세종대로|Hong Gildong|시험용폰|시험폰2" $WE/km.C $WE/km.en_US.UTF-8 && grep -q "V039.001.260902" $WE/km.C && grep -q "\[   12.345678\] dhd_module_init" $WE/km.C && [ "$(wc -l < $WE/km.C)" = "$(wc -l < $B/tests/kpmask-sample.txt)" ]'
check "  원인 자료는 남김: isWifiApEnable 줄, 'Failed to find host IP/BSSID', 핫스팟 주소, pid, 숫자 괄호, 클래스 표시" 'grep -q "isWifiApEnable = false, mode = 0" $WE/km.C && grep -q "Failed to find host IP/BSSID 192.168.43.1" $WE/km.C && grep -q "( 1625)" $WE/km.C && grep -q "connectStatus (4)" $WE/km.C && grep -q "\[ WirelessPhoneProjectionService \]" $WE/km.C'
check "1.7.1 가리기: 커널 명령줄 btaddr·wifimac·serialno 값, 따옴표 안 SSID, 구분자 없는 MAC이 0건(C·UTF-8)" '! grep -q -E "A1B2C3D4E5F6|001122AABBCC|KMHXX12345|ABC6789XYZ|HomeWiFi|9C2F4A7B1E3D" $WE/km.C $WE/km.en_US.UTF-8 && grep -q "Kernel command line: console=ttyS0 androidboot.btaddr=\[가림" $WE/km.C'
check "  경로·빈 따옴표는 남김(원인 자료)" 'grep -q "\"/data/misc/wifi/wpa_supplicant.conf\"" $WE/km.C && grep -q "empty \"\"" $WE/km.C'
check "  디버그 로그 태그에 AAProjection·PhoneProjection·RFCOMM이 있고, 없는 태그(GPM*·GalReceiver*)는 뺌" 'grep -q "^TAGS=.*AAProjection|PhoneProjection.*bt-rfcomm" $PKG/svc/hotspot.sh && ! grep -q "^TAGS=.*GPM\[" $PKG/svc/hotspot.sh'
check "  디버그 로그 파이프가 KPMASK를 거침, awk가 안 되면 남기지 않음(기본은 꺼짐 그대로)" 'grep -q "awk \"\$KPMASK\" | \$_u >> \$W/cp.log" $PKG/svc/hotspot.sh && grep -q "디버그 로그 안 남김: 가리기" $PKG/svc/hotspot.sh && grep -q "\[ -f \$W/debug \] || return 0" $PKG/svc/hotspot.sh'

# --- 1.7.2 P-6: aa_sig 조건(BB_OWN 뺌, wlan0 주소 더함), 이유 파일 aa.why ---
mkdir -p $WE/bk; rm -f $WE/bk/* $WE/w/aa.why $WE/setprops; echo 0 > $WE/aaprop
cp $T/ps $WE/ps.keep2 2>/dev/null
wa() { (BK=$WE/bk AAOFF=$WE/bk/aa-off HINT=$WE/hint; export BK AAOFF HINT; we "$1"); }
echo "  1 root 0 S hostapd $WE/hk.conf" > $T/ps
wa aa_sig > $WE/p6a
check "1.7.2 P-6: 우리 hostapd + wlan0에 우리 AP 주소 → 1, 이유 on" '[ "$(cat $WE/aaprop)" = 1 ] && [ "$(cat $WE/w/aa.why)" = on ] && grep -q "켜짐: 모드에 우리 AP를 알림" $WE/p6a'
printf 'wlan0 Link encap:Ethernet\n  inet6 addr: fe80::1/64\n' > $T/ifc; wa aa_sig > $WE/p6b
check "  wlan0에 우리 AP 주소가 없으면 0, 이유 noaddr, 로그 한 줄에 이유" '[ "$(cat $WE/aaprop)" = 0 ] && [ "$(cat $WE/w/aa.why)" = noaddr ] && grep -q "신호 끔: 이유 wlan0에 우리 AP 주소 없음" $WE/p6b'
wa aa_sig > $WE/p6c
check "  신호가 그대로면 로그를 다시 남기지 않음" '[ ! -s $WE/p6c ]'
rm -f $T/ifc; wa aa_sig > $WE/p6d
check "  주소가 생기면 다음 점검에서 1" '[ "$(cat $WE/aaprop)" = 1 ] && grep -q "켜짐" $WE/p6d'
: > $T/ps; wa aa_sig > $WE/p6e
check "  hostapd가 없으면 0, 이유 nohostapd" '[ "$(cat $WE/aaprop)" = 0 ] && [ "$(cat $WE/w/aa.why)" = nohostapd ] && grep -q "이유 우리 hostapd 없음" $WE/p6e'
echo "  1 root 0 S hostapd $WE/hk.conf" > $T/ps; : > $WE/bk/stockap.seen; wa aa_sig > $WE/p6f
check "  순정 카플레이 AP를 본 차(stockap.seen)는 hostapd가 돌아도 0, 이유 stockap(순정 AP 경로 차는 신호를 켜지 않음)" '[ "$(cat $WE/aaprop)" = 0 ] && [ "$(cat $WE/w/aa.why)" = stockap ]'
rm -f $WE/bk/stockap.seen; : > $WE/bk/aa-off; wa aa_sig > $WE/p6g
check "  1.7.4 L-9: 끄기 파일이 남아 있어도 1, 이유 on(이유 off·'끄기 파일' 문구 없음)" '[ "$(cat $WE/aaprop)" = 1 ] && [ "$(cat $WE/w/aa.why)" = on ] && ! grep -q "끄기 파일" $PKG/svc/hotspot.sh'
rm -f $WE/bk/aa-off
(PATH=$WE/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB=$T/bin/bb BB_OWN=$T/bin/bb BK=$WE/bk W=$WE/w BOOT_ID=$WE/bootid CONF=$WE/hk.conf sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$WE'/bin:'$T'/bin:/usr/bin:/bin:/sbin; aa_sig') > $WE/p6h 2>&1
check "  함께 넣은 busybox(BB_OWN)여도 순정 AP 기록이 없으면 1(P-6: BB_OWN 조건 뺌)" '[ "$(cat $WE/aaprop)" = 1 ]'
wa 'aa_sig 0 yield' > $WE/p6i
check "  비켜 줄 때는 이유 yield, stop_ap는 이유 stop" '[ "$(cat $WE/w/aa.why)" = yield ] && grep -q "이유 다른 hostapd에 비켜 줌" $WE/p6i && wa "aa_sig; stop_ap" >/dev/null 2>&1 && [ "$(cat $WE/w/aa.why)" = stop ]'
check "  이유 파일·로그에 SSID·비밀번호 값이 없음" '! grep -q -e SSIDx -e PASS12345 $WE/w/aa.why $WE/p6a $WE/p6b $WE/p6e $WE/p6i'
check "  1.7.4 L-9: status.sh는 kp-aa-off·kp-aa-on·끄기 표시(AAOFF)를 읽지 않음" '! grep -v "^ *#" $PKG/bin/status.sh | grep -q -e "kp-aa-o" -e "AAOFF"'
# 1.7.4(L-9): 1.7.3 이하에서 꺼 둔 차. 서비스가 시작할 때(main) 남은 끄기 표시를 지우고 로그 한 줄, 그 뒤 점검에서 AA 신호가 켜짐
# (main은 부팅 완료를 기다리는 sleep에서 멈추게 하고, 그 앞까지만 돈다)
echo 0 > $WE/aaprop; : > $WE/bk/aa-off; wa 'getprop() { :; }; sleep() { exit 0; }; main' > $WE/l9m 2>&1
# (끄기 표시가 남아도 신호가 켜지는 것은 위 "끄기 파일이 남아 있어도 1, 이유 on" 시험이 본다)
check "1.7.4 L-9: 서비스 시작 때 남은 끄기 표시(aa-off)를 지우고 로그 한 줄" '[ ! -f $WE/bk/aa-off ] && [ "$(grep -c "예전 무선 안드로이드 오토 끄기 표시를 지웠습니다" $WE/l9m)" = 1 ]'
wa 'getprop() { :; }; sleep() { exit 0; }; main' > $WE/l9m2 2>&1
check "  L-9: 표시가 없으면 다시 시작해도 그 로그를 남기지 않음" '! grep -q "끄기 표시를 지웠습니다" $WE/l9m2'
# 묶음 E 리뷰(낮음 3): 표시를 못 지우면(백업 폴더를 못 씀) 지웠다는 로그를 남기지 않고 지나감(main은 계속 감)
: > $WE/bk/aa-off; chmod 555 $WE/bk; wa 'getprop() { :; }; sleep() { echo L9-WAIT-REACHED; exit 0; }; main' > $WE/l9m3 2>&1; chmod 755 $WE/bk
check "  L-9 리뷰: 끄기 표시를 못 지우면 '지웠습니다' 로그 없음(표시는 남음), 서비스는 부팅 완료 기다리기까지 감" '[ -f $WE/bk/aa-off ] && ! grep -q "끄기 표시를 지웠습니다" $WE/l9m3 && grep -qx L9-WAIT-REACHED $WE/l9m3'
check "1.7.4 D-14(묶음 E 리뷰): 설정이 끝난 차의 30초 점검 '준비됨' 진행 기록이 순정 Wi-Fi 쪽과 같은 '무선 카플레이·안드로이드 오토 준비됨.', 폰 안내 붙은 준비됨 문구 없음" '[ "$(grep -c "prog 100 done \"무선 카플레이·안드로이드 오토 준비됨.\"" $PKG/svc/hotspot.sh)" = 2 ] && ! grep -q "준비됨. 아이폰을 연결해 보세요" $PKG/svc/hotspot.sh $PKG/bin/status.sh'
rm -f $WE/bk/aa-off

# --- 1.7.2 P-4: AA 상태 안내(hint 파일), aa_events 새 줄 ---
echo boot-H > $WE/bootid; rm -f $WE/w/aatime $WE/hint
echo "  1 root 0 S hostapd $WE/hk.conf" > $T/ps; echo 1 > $WE/aaprop
cat > $WE/aalog2 <<'E'
11-08 02:07:57.610 I/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] isCheckReady ret = false
11-08 02:07:57.850 I/BTCMService( 1159): <> preConditionCheckForConnectSpp = false
11-08 02:07:57.870 D/PhoneProjection( 1660): [ b ] onSppConnect() ret = false
11-08 02:07:58.000 D/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] requestWLDeviceConnectStatusUpdate [Pixel7]
E
printf '#!/bin/sh\ncat %s/aalog2\n' $WE > $WE/bin/logcat; chmod +x $WE/bin/logcat
wa 'HINT_ON=1; aa_events' > $WE/h1
check "1.7.2 P-4: isCheckReady false 뒤 30초 안 onSppConnect false → 상태 안내 aa=bt, ap.log에 이유, 이름 없음" 'grep -qx "aa=bt" $WE/hint && grep -qx "boot=boot-H" $WE/hint && grep -q "폰 프로젝션 준비 확인 false" $WE/h1 && grep -q "헤드유닛 쪽 블루투스(SPP) 다시 연결 거절" $WE/h1 && grep -q "안내(상태 화면): 안드로이드 폰의 블루투스를 껐다 켜 주세요" $WE/h1 && ! grep -q Pixel7 $WE/h1 $WE/hint'
check "  안내 파일은 누구나 읽을 수 있게(644), 비밀값 없음" '[ "$(stat -f %Lp $WE/hint)" = 644 ] && ! grep -q -e SSIDx -e PASS12345 $WE/hint'
rm -f $WE/w/aatime $WE/hint
printf '%s\n' "11-08 02:07:00.000 I/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] isCheckReady ret = false" "11-08 02:07:57.870 D/PhoneProjection( 1660): [ b ] onSppConnect() ret = false" > $WE/aalog2
wa 'HINT_ON=1; aa_events' > $WE/h2
check "  isCheckReady false가 30초보다 앞이면 안내하지 않음(줄만 남김)" '! grep -q "^aa=bt" $WE/hint 2>/dev/null && grep -q "다시 연결 거절" $WE/h2'
rm -f $WE/w/aatime $WE/hint
printf '%s\n' "11-08 02:08:27.830 I/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] connectivityConnectionTimeout() ppType[2], tryCount[1], timeoutReason[2]" > $WE/aalog2
wa 'HINT_ON=1; aa_events' > $WE/h3
check "  PP 연결 시간 초과 tryCount 1은 기록만(재시도 중)" 'grep -q "폰 프로젝션 연결 시간 초과(시도 1)" $WE/h3 && ! grep -q "^aa=bt" $WE/hint 2>/dev/null'
echo "11-08 02:08:33.050 I/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] connectivityConnectionTimeout() ppType[2], tryCount[2], timeoutReason[2]" >> $WE/aalog2
wa 'HINT_ON=1; aa_events' > $WE/h4
check "  tryCount 2(재시도 포기) → aa=bt" 'grep -q "시도 2" $WE/h4 && grep -qx "aa=bt" $WE/hint && grep -q "다시 시도를 포기함" $WE/h4'
rm -f $WE/w/aatime $WE/hint
echo "11-08 01:56:34.170 E/PhoneProjection( 1669): [ WirelessPhoneProjectionService ] connectivityConnectPPHandler isConnectivityActivated return true" > $WE/aalog2
wa 'HINT_ON=1; aa_events' > $WE/h5
check "  isConnectivityActivated return true → aa=cpwait(카플레이가 연결되어 AA는 기다림)" 'grep -qx "aa=cpwait" $WE/hint && grep -q "카플레이 연결 중이라 건너뜀" $WE/h5'
rm -f $WE/w/aatime $WE/hint
printf '%s\n' "11-08 02:16:20.000 I/PhoneProjection( 1660): [ f ] getWiFiApMode wifiManager.isWifiApEnabled() = false, return APMode.UNKNOWN" "11-08 02:16:40.000 I/PhoneProjection( 1660): [ f ] getWiFiApMode wifiManager.isWifiApEnabled() = false, return APMode.UNKNOWN" > $WE/aalog2
wa 'HINT_ON=1; AA_ON_TM="11-08 02:16:30"; aa_events' > $WE/h6
check "  신호가 켜진 시각보다 먼저 온 'AP 모드 모름' → aa=bt, 뒤에 온 것은 기록만" 'grep -qx "aa=bt" $WE/hint && [ "$(grep -c "신호보다 먼저" $WE/h6)" = 2 ] && grep -q "신호보다 먼저 AP 모드를 물음" $WE/h6'
rm -f $WE/w/aatime $WE/hint
wa 'HINT_ON=1; aa_events' > $WE/h6b
check "  신호가 켜진 시각을 모르면(이번 실행에서 안 켜짐) 'AP 모드 모름'만으로는 안내 안 함" '! grep -q "^aa=bt" $WE/hint 2>/dev/null'
rm -f $WE/w/aatime $WE/hint
printf '%s\n' "11-08 02:07:57.610 I/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] isCheckReady ret = false" "11-08 02:07:57.870 D/PhoneProjection( 1660): [ b ] onSppConnect() ret = false" > $WE/aalog2
echo 0 > $WE/aaprop; wa 'HINT_ON=1; aa_events' > $WE/h7
check "  신호가 0인 차는 안내하지 않음(줄만 남김)" '! grep -q "^aa=bt" $WE/hint 2>/dev/null && grep -q "다시 연결 거절" $WE/h7'
rm -f $WE/w/aatime $WE/hint; echo 1 > $WE/aaprop; : > $WE/bk/aa-off; wa 'HINT_ON=1; aa_events' > $WE/h8; rm -f $WE/bk/aa-off
check "  1.7.4 L-9: 끄기 파일이 남아 있어도 신호가 1이면 안내함(aa=bt)" 'grep -qx "aa=bt" $WE/hint'
rm -f $WE/w/aatime $WE/hint
printf '%s\n' "11-08 02:07:57.610 I/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] isCheckReady ret = false" "11-08 02:07:57.870 D/PhoneProjection( 1660): [ b ] onSppConnect() ret = false" "11-08 02:09:00.000 I/AAProjection(  775): WirelessExplorer : 	Connection status STATUS_SUCCESS" "11-08 02:09:01.000 D/AAProjection(  775): WifiTransport : onConnectedCallback call  onConnected" > $WE/aalog2
wa 'HINT_ON=1; aa_events' > $WE/h9
check "  해소 줄(폰 Wi-Fi 접속 SUCCESS·TCP 연결)을 보면 aa=ok(연결됨)" 'grep -qx "aa=ok" $WE/hint && grep -q "폰 Wi-Fi 접속 SUCCESS" $WE/h9 && grep -q "TCP 연결됨" $WE/h9 && grep -q "무선 안드로이드 오토 연결됨" $WE/h9'
rm -f $WE/w/aatime $WE/hint
printf '%s\n' "11-08 02:07:57.610 I/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] isCheckReady ret = false" "11-08 02:07:57.870 D/PhoneProjection( 1660): [ b ] onSppConnect() ret = false" "11-08 02:09:00.000 D/AAProjection(  775): WirelessExplorer : isWifiApEnable = true, mode = 2" > $WE/aalog2
wa 'HINT_ON=1; aa_events' > $WE/h10
check "  AP 켜짐 true를 보면 안내를 지움(aa 빈 값)" 'grep -qx "aa=" $WE/hint && grep -q "안드로이드 오토 안내 지움" $WE/h10'
wa 'HINT_ON=1; HA=bt; HA_T=$(( $(date +%s) - 601 )); hint_tick' > $WE/h11
check "  10분 지나면 안내를 지움(hint_tick)" 'grep -qx "aa=" $WE/hint && grep -q "10분 지남" $WE/h11'
wa 'HINT_ON=1; HA=bt; HA_T=$(( $(date +%s) - 30 )); hint_tick' > $WE/h12
check "  10분 전에는 그대로" '[ ! -s $WE/h12 ]'
rm -f $WE/w/aatime $WE/hint
printf '%s\n' "11-08 03:00:00.000 D/AAProjection(  775): d : canStartConnection = false" "11-08 03:00:00.100 D/AAProjection(  775): d : getWirelessConnection = false" "11-08 03:00:01.000 I/AAProjection(  775): ConnectionHandler : Connection Error - retry Wireless connection" > $WE/aalog2
wa 'HINT_ON=1; aa_events' > $WE/h13
check "  문 3(canStartConnection·getWirelessConnection false)과 Wi-Fi 세션 재시도도 참거짓만 기록" 'grep -q "연결 시작 막힘(canStartConnection false)" $WE/h13 && grep -q "AA 무선 설정 꺼짐(getWirelessConnection false)" $WE/h13 && grep -q "Wi-Fi 세션 오류로 한 번 다시 시도" $WE/h13'
wa 'HINT_ON=1; aa_sig 0 stop' > /dev/null 2>&1
check "  신호를 끄면 '준비됨'·AA 안내를 지움" 'grep -qx "aa_ready=" $WE/hint && grep -qx "aa=" $WE/hint'
wa 'echo 0 > '$WE'/aaprop; HINT_ON=1; aa_sig' > /dev/null 2>&1
check "  신호가 켜지면 '준비됨' 시각(aa_ready)을 안내 파일에" 'grep -q "^aa_ready=[0-9][0-9]*$" $WE/hint'
rm -f $WE/hint; wa 'aa_sig 0 stop' >/dev/null 2>&1
check "  Launch(HINT_ON 없음)는 안내 파일을 쓰지 않음" '[ ! -f $WE/hint ]'
echo 0 > $WE/aaprop; : > $WE/bk/stockap.seen; wa 'HINT_ON=1; HA_READY=123; aa_sig' > /dev/null 2>&1; rm -f $WE/bk/stockap.seen
check "  리뷰 M-2: 신호가 이미 0이면(다른 곳에서 먼저 내림) 서비스 점검이 남은 '준비됨'을 지움" 'grep -qx "aa_ready=" $WE/hint'
check "  preun이 안내 파일을 지움" 'grep -q "rm -f \$HINT \$HINT.tmp" $PKG/scripts/preun.sh'

# --- 1.7.2 M-8 대신: GPM "준비(1)"가 PP에 닿는지 보는 진단 4줄(bt-aa-autoconnect.md 1-4) ---
# 니로 02:07 실패 부팅·00:08 부팅의 줄 꼴. 이름 자리에 가짜 폰 이름(숫자 섞음)을 넣어 새지 않는지 본다.
rm -f $WE/w/aatime $WE/hint
cat > $WE/aalog2 <<'E'
11-08 02:07:32.870 I/AAProjection(  775): GalReceiverService : PP Service is Running!
11-08 02:07:32.870 I/AAProjection(  775): GalReceiverService : send requestWLDeviceReadyStatusUpdate:  [Galaxy S23 77] 0
11-08 02:07:33.100 D/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] requestWLDeviceReadyStatusUpdate [], Ready (0)
11-08 02:07:57.690 D/AAProjection(  775): a : onBTCMSppStatusChanged, device: 김철수 폰 42 status: 2
11-08 02:09:27.070 I/AAProjection(  789): GalReceiverService : send requestWLDeviceReadyStatusUpdate:  [Galaxy S23 77] 1
11-08 02:09:27.300 D/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] requestWLDeviceReadyStatusUpdate [Galaxy S23 77], Ready (1)
11-08 02:09:27.400 D/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] requestWLDeviceReadyStatusUpdate, Ready = true, mStatusInfo.getReadyStatus (0)
11-08 02:09:27.500 D/PhoneProjection( 1660): [ WirelessPhoneProjectionService ] requestWLDeviceReadyStatusUpdate ready!, type: 2 connectStatus = 0
11-08 02:09:28.000 D/AAProjection(  789): a : onBTCMSppStatusChanged, device: 김철수 폰 42
11-08 02:09:29.000 D/LocalBluetoothManager( 2101): onBTCMSppStatusChanged...device.. AA:BB:CC:DD:EE:FF ...status... 0
11-08 02:09:30.000 D/AAProjection(  789): a : onBTCMSppStatusChanged, device: 김철수 폰 status: 9x
11-08 02:09:31.000 I/AAProjection(  789): GalReceiverService : send requestWLDeviceReadyStatusUpdate:  [Ready] 0
E
printf '#!/bin/sh\ncat %s/aalog2\n' $WE > $WE/bin/logcat; chmod +x $WE/bin/logcat
wa 'HINT_ON=1; aa_events' > $WE/m8a
check "1.7.2 M-8 진단: PP 서비스 시작·GPM 준비 N 보냄·PP 준비 N 받음·GPM SPP 상태 N을 시각과 함께" 'grep -q "안드로이드 오토: 폰 프로젝션 서비스 시작(AA 앱이 확인) (02:07:32.870)" $WE/m8a && grep -q "AA 앱(GPM)이 폰 프로젝션에 준비 0 보냄 (02:07:32.870)" $WE/m8a && grep -q "폰 프로젝션이 준비 0 받음 (02:07:33.100)" $WE/m8a && grep -q "AA 앱(GPM)이 블루투스 SPP 상태 2 받음 (02:07:57.690)" $WE/m8a && grep -q "AA 앱(GPM)이 폰 프로젝션에 준비 1 보냄 (02:09:27.070)" $WE/m8a && grep -q "폰 프로젝션이 준비 1 받음 (02:09:27.300)" $WE/m8a'
check "  상태 숫자가 없거나 숫자가 아니면 '?', 다른 준비 줄·다른 태그(LocalBluetoothManager)는 세지 않음" '[ "$(grep -c "SPP 상태 ? 받음" $WE/m8a)" = 2 ] && [ "$(grep -c "준비 [01] 받음" $WE/m8a)" = 2 ] && [ "$(grep -c "안드로이드 오토: " $WE/m8a)" = 9 ] && grep -q "준비 0 보냄 (02:09:31.000)" $WE/m8a'
check "  이름·주소·이름 속 숫자(23·77·42)가 새지 않고, 안내(hint)는 만들지 않음(기록만)" '! sed -n "s/.*안드로이드 오토: //p" $WE/m8a | grep -q -E "Galaxy|S23|77|김철수|42|AA:BB|9x" && ! grep -q -E "Galaxy|김철수|AA:BB" $WE/m8a && ! grep -q "^aa=bt" $WE/hint 2>/dev/null'
we aa_events > $WE/m8b
check "  같은 줄은 다시 남기지 않음" '[ ! -s $WE/m8b ]'
# logcat 가짜($WE/aalog2를 읽음)는 아래 P-5 시험도 쓰므로 남긴다
rm -f $WE/w/aatime $WE/hint

# --- 1.7.2 P-5: 아이폰이 Wi-Fi에 오지 않음 ---
rm -f $WE/w/aatime $WE/hint $WE/w/cpn
# 재리뷰 L4: 서비스 안의 기다림은 부팅 뒤 초로 잰다(가짜 부팅 뒤 1000초)
echo "1000.00 1.00" > $WE/uptime
# ㉑(흔들림 고침): 로그 시각 H0와 같은 순간의 시계 초(S0)를 한 번에 잡는다. aa_events는 IPH_AT = 부팅 뒤 초 - (지금 - 로그 시각)이므로
# 1000 - IPH_AT은 "H0 뒤 지난 초"다. 예전에는 0~2초로 못 박아 그 사이 실행이 2초를 넘으면 실패했다(11-13 3번 중 1번).
# 이제는 시험 직후 잰 실제 경과 초(+1, 초 단위 버림 여유) 이하인지 본다: 실행 속도와 무관하고, 지금 시각으로 잡는 잘못(값이 0)도
# 로그 시각을 무시하는 잘못(값이 크거나 숫자 아님)도 잡는다
read H0d H0t S0 <<EOF
$(date '+%m-%d %H:%M:%S %s')
EOF
H0="$H0d $H0t.000"
# $1 파일의 IPH=<초>가 0 이상이고 S0 뒤 지금까지 지난 초 + 1 이하인가
iph_since_h0() { _iv=$(sed -n 's/^IPH=//p' $1); case "$_iv" in ''|*[!0-9]*) return 1 ;; esac; [ "$_iv" -le $(( $(date +%s) - S0 + 1 )) ]; }
echo "$H0 I/HMG-API (  905): [wireless-carplay-aa] bridge: iAP2 connected comp=4" > $WE/aalog2
wa 'UPTIME='$WE'/uptime; HINT_ON=1; aa_events; echo "IPH=$((1000 - IPH_AT))"' > $WE/i1
check "1.7.2 P-5: iAP2 연결(구성요소 4) 줄 → 기록 한 줄과 판정 시작(로그 시각 기준)" 'grep -q "카플레이: 아이폰 블루투스 연결(iAP2)" $WE/i1 && iph_since_h0 $WE/i1'
echo 0 > $WE/w/cpn
wa 'UPTIME='$WE'/uptime; HINT_ON=1; IPH_AT=$((1000 - 61)); hint_tick' > $WE/i2
check "  60초 동안 기기 연결이 없으면 iph=wifi 안내와 ap.log 한 줄" 'grep -qx "iph=wifi" $WE/hint && grep -q "60초 동안 Wi-Fi에 오지 않음" $WE/i2'
rm -f $WE/hint; wa 'UPTIME='$WE'/uptime; HINT_ON=1; IPH_AT=$((1000 - 30)); hint_tick' > $WE/i3
check "  60초 전에는 안내 안 함" '[ ! -f $WE/hint ] && [ ! -s $WE/i3 ]'
wa 'UPTIME='$WE'/uptime; HINT_ON=1; IPH_AT=$((1000 - 61)); WCONN_AT=980; WSTA=1; hint_tick' > $WE/i4
check "  베타 1 리뷰 A: 우리 Wi-Fi에 기기가 붙어 있는데 카플레이가 60초 동안 없으면 'Wi-Fi에 오지 않음'이 아니라 iph=nocp(재부팅 안내), 로그에 원인" 'grep -qx "iph=nocp" $WE/hint && grep -q "60초 동안 카플레이가 시작되지 않음(우리 Wi-Fi에 붙은 기기 1대" $WE/i4 && ! grep -q "Wi-Fi에 오지 않음" $WE/i4'
rm -f $WE/hint
wa 'UPTIME='$WE'/uptime; HINT_ON=1; IPH_AT=$((1000 - 61)); WCONN_AT=700; WSTA=1; HA=ok; hint_tick' > $WE/i4b
check "  재리뷰 M3: 무선 AA가 연결된 동안(HA=ok)은 아이폰 안내를 내지 않음(쓰는 AA를 끊으라고 하지 않게)" '[ ! -f $WE/hint ] && [ ! -s $WE/i4b ]'
rm -f $WE/hint
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HI=nocp; HI_T=$(( $(date +%s) - 10 )); HI_U=990; WCONN_AT=1000; hint_tick' > $WE/i4c
check "  베타 1 리뷰 A: nocp 안내는 기기가 Wi-Fi에 붙었다고 지우지 않음(카플레이 연결·10분에만)" '[ ! -f $WE/hint ] && [ ! -s $WE/i4c ]'
echo 1 > $WE/w/cpn; wa 'UPTIME='$WE'/uptime; HINT_ON=1; HI=nocp; HI_T=$(( $(date +%s) - 10 )); HI_U=990; hint_tick' > $WE/i4d; echo 0 > $WE/w/cpn
check "  베타 1 리뷰 A: 카플레이가 연결되면 nocp 안내를 지움" 'grep -qx "iph=" $WE/hint && grep -q "안내(상태 화면) 지움: 카플레이 연결됨" $WE/i4d'
rm -f $WE/hint
# 재리뷰 M3: 무선 AA "연결됨"(aa=ok)은 10분으로 지우지 않고, 우리 AP의 기기가 끊김으로 0대가 됐을 때만 지움
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HA=ok; HA_T=$(( $(date +%s) - 700 )); WSTA=1; hint_tick; echo "HA=[$HA]"' > $WE/aa10
check "재리뷰 M3: 무선 AA 연결(ok)이 10분 넘게 이어져도 지우지 않음(10분 만료는 bt·cpwait 안내에만)" 'grep -qx "HA=\[ok\]" $WE/aa10 && ! grep -q "10분 지남" $WE/aa10'
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HA=ok; HA_T=1; WSTA=0; hint_tick; echo "HA=[$HA]"' > $WE/aa11
check "  재리뷰 M3: 기기 수가 0이어도 끊김 줄로 0이 된 것이 아니면(커널 줄을 놓친 경우) 한 회차로는 지우지 않음" 'grep -qx "HA=\[ok\]" $WE/aa11'
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HA=ok; HA_T=1; WSTA=0; hint_tick; hint_tick; echo "HA=[$HA]"' > $WE/aa11b
check "  확인 리뷰 M2: 무선 AA 연결됨인데 기기 0대가 두 회차(약 60초) 이어지면 지움" 'grep -qx "HA=\[\]" $WE/aa11b && grep -q "기기 0대가 두 회차 이어짐" $WE/aa11b'
rm -rf $WE/bk; mkdir -p $WE/bk; rm -f $WE/w/ktime
printf '%s\n' "<4>[  970.0] ETHER_TYPE_802_1X[wlan0] [RX] : M4 of 4way" "<6>[  975.0] CFG80211-ERROR) wl_cfg80211_del_station : Disconnect STA : aa:bb:cc:dd:ee:ff" > $WE/dmesg
wa 'UPTIME='$WE'/uptime; HINT_ON=1; WSTA=0; wifi_events >/dev/null; aa_hint ok; hint_tick; echo "HA=[$HA]"' > $WE/aa11c
check "  확인 리뷰 M2: 한 회차 안에 붙었다 끊긴 뒤 늦게 온 연결됨(ok)이 0대 기록을 지우지 않아 바로 지워짐" 'grep -qx "HA=\[\]" $WE/aa11c'
rm -rf $WE/bk; rm -f $WE/w/ktime $WE/dmesg
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HA=bt; HA_T=$(date +%s); HA_U=399; hint_tick; echo "HA=[$HA]"' > $WE/aa11d
check "  확인 리뷰 L3: 블루투스 안내(bt) 10분 지우기는 부팅 뒤 초로 잼(시계는 방금이어도 부팅 뒤 601초 지났으면 지움)" 'grep -qx "HA=\[\]" $WE/aa11d && grep -q "10분 지남" $WE/aa11d'
rm -rf $WE/bk; mkdir -p $WE/bk; rm -f $WE/w/ktime
printf '%s\n' "<4>[  950.0] ETHER_TYPE_802_1X[wlan0] [RX] : M4 of 4way" "<6>[  960.0] CFG80211-ERROR) wl_cfg80211_del_station : Disconnect STA : aa:bb:cc:dd:ee:ff" > $WE/dmesg
wa 'UPTIME='$WE'/uptime; HINT_ON=1; WSTA=0; HA=ok; HA_T=1; wifi_events >/dev/null; hint_tick; echo "HA=[$HA]"' > $WE/aa12
check "  재리뷰 M3: 연결된 기기가 끊겨 0대가 되면 AA 연결됨을 지움(로그에 까닭)" 'grep -qx "HA=\[\]" $WE/aa12 && grep -q "우리 Wi-Fi에 붙은 기기가 0대가 됨(무선 AA 끊김으로 봄)" $WE/aa12'
# 1.7.4 B-2 재현(#64 베타 2, 11-11 13:33·13:34 니로): 서비스 시작 회차에 dmesg(AP 올라옴뿐, 폰의 Wi-Fi 인증 줄은 아직 없음)를
# 먼저 읽고, 뒤에 읽은 logcat에 AA 연결됨(STATUS_SUCCESS)이 있다. 1.7.3은 같은 회차의 hint_tick이 "0대가 됨"으로 바로 지웠다
rm -rf $WE/bk; mkdir -p $WE/bk; rm -f $WE/w/ktime $WE/w/aatime $WE/hint; echo 1 > $WE/aaprop
printf '%s\n' "<6>[   28.0] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **" > $WE/dmesg
printf '%s\n' "$(date '+%m-%d %H:%M:%S').100 I/AAProjection(  775): WirelessExplorer : 	Connection status STATUS_SUCCESS" > $WE/aalog2
wa 'UPTIME='$WE'/uptime; HINT_ON=1; wifi_events >/dev/null; aa_events; hint_tick; echo "HA=[$HA] WSTA=[$WSTA]"; printf "<6>[   28.0] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **\n<4>[   35.0] ETHER_TYPE_802_1X[wlan0] [RX] : M4 of 4way\n" > '$WE'/dmesg; wifi_events >/dev/null; aa_events; hint_tick; echo "HA2=[$HA] WSTA2=[$WSTA]"' > $WE/b2a
check "1.7.4 B-2: AP 올라옴과 같은 회차에 뒤에 읽은 AA 연결됨은 지우지 않음(1.7.3은 '0대가 됨'으로 바로 지움, #64)" 'grep -qx "HA=\[ok\] WSTA=\[0\]" $WE/b2a && ! grep -q "0대가 됨" $WE/b2a && grep -qx "aa=ok" $WE/hint'
check "  B-2: 다음 회차에 폰의 Wi-Fi 인증 줄이 오면 기기 1대, 연결됨 그대로" 'grep -qx "HA2=\[ok\] WSTA2=\[1\]" $WE/b2a'
# (앞 시험이 $BK/ktime에 남긴 "커널 35초까지 봄"을 지운다: 남기면 이 AP 올라옴 줄을 이미 본 줄로 건너뛴다)
rm -rf $WE/bk; mkdir -p $WE/bk; rm -f $WE/w/ktime $WE/w/aatime $WE/hint; : > $WE/aalog2
printf '%s\n' "<6>[   28.0] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **" > $WE/dmesg
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HA=ok; HA_T=1; WSTA=1; wifi_events >/dev/null; aa_events; hint_tick; echo "HA=[$HA]"' > $WE/b2b
check "  B-2: 이미 연결됨이던 중에 AP가 다시 올라오고 새 연결됨이 없으면 예전처럼 바로 지움" 'grep -qx "HA=\[\]" $WE/b2b && grep -q "0대가 됨" $WE/b2b'
# 1.7.4 B-2 리뷰 반영: 같은 회차에 끊김(D)으로 0대 → AP 올라옴(L) → 늦은 연결됨(ok). 끊김 기록(1)을 L이 덮지 않아 예전처럼 지움
rm -rf $WE/bk; mkdir -p $WE/bk; rm -f $WE/w/ktime $WE/w/aatime $WE/hint; echo 1 > $WE/aaprop
printf '%s\n' "<6>[   20.0] CFG80211-ERROR) wl_cfg80211_del_station : Disconnect STA : aa:bb:cc:dd:ee:ff" "<6>[   28.0] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **" > $WE/dmesg
printf '%s\n' "$(date '+%m-%d %H:%M:%S').100 I/AAProjection(  775): WirelessExplorer : 	Connection status STATUS_SUCCESS" > $WE/aalog2
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HA=ok; HA_T=1; WSTA=1; wifi_events >/dev/null; echo "WG=[$WGONE]"; aa_events >/dev/null; hint_tick; echo "HA=[$HA]"' > $WE/b2c
check "  B-2 리뷰: 같은 회차에 끊김 뒤 AP가 다시 올라오면 끊김 기록을 덮지 않고(WGONE=1), 늦은 연결됨이 와도 예전처럼 지움" 'grep -qx "WG=\[1\]" $WE/b2c && grep -qx "HA=\[\]" $WE/b2c && grep -q "0대가 됨" $WE/b2c'
rm -rf $WE/bk; rm -f $WE/w/ktime $WE/w/aatime $WE/dmesg $WE/hint; : > $WE/aalog2
rm -rf $WE/bk; rm -f $WE/w/ktime $WE/w/aatime $WE/dmesg $WE/hint
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HA=ok; HI=wifi; HI_T=$(date +%s); HI_U=990; hint_tick' > $WE/aa13
check "  재리뷰 M3: 무선 AA가 연결되면 남아 있던 아이폰 안내도 지움" 'grep -qx "iph=" $WE/hint && grep -q "안내(상태 화면) 지움: 무선 안드로이드 오토 연결됨" $WE/aa13'
rm -rf $WE/bk; rm -f $WE/w/ktime $WE/dmesg $WE/hint
echo 1 > $WE/w/cpn; wa 'UPTIME='$WE'/uptime; HINT_ON=1; IPH_AT=$((1000 - 61)); hint_tick' > $WE/i5; echo 0 > $WE/w/cpn
check "  카플레이가 연결되어 있으면 안내 안 함" '[ ! -f $WE/hint ]'
: > $T/ps; wa 'UPTIME='$WE'/uptime; HINT_ON=1; IPH_AT=$((1000 - 61)); hint_tick' > $WE/i6; echo "  1 root 0 S hostapd $WE/hk.conf" > $T/ps
check "  우리 hostapd가 없으면 안내 안 함" '[ ! -f $WE/hint ]'
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HI=wifi; HI_T=$(( $(date +%s) - 10 )); HI_U=990; WCONN_AT=1000; hint_tick' > $WE/i7
check "  안내 뒤 기기가 연결되면 지움" 'grep -qx "iph=" $WE/hint && grep -q "아이폰이 Wi-Fi에 연결됨" $WE/i7'
wa 'UPTIME='$WE'/uptime; HINT_ON=1; HI=wifi; HI_T=$(( $(date +%s) - 601 )); HI_U=399; hint_tick' > $WE/i8
check "  10분 지나면 지움" 'grep -qx "iph=" $WE/hint'
rm -f $WE/w/aatime
printf '%s\n' "$H0 I/HMG-API (  905): [wireless-carplay-aa] bridge: iAP2 connected comp=4" "$H0 I/HMG-API (  905): [wireless-carplay-aa] bridge: iAP2 disconnected comp=4" > $WE/aalog2
wa 'UPTIME='$WE'/uptime; HINT_ON=1; aa_events; echo "IPH=[$IPH_AT]"' > $WE/i9
check "  iAP2가 끊기면 판정을 멈춤" 'grep -q "IPH=\[\]" $WE/i9 && grep -q "아이폰 블루투스 iAP2 끊김" $WE/i9'
rm -f $WE/w/aatime
printf '%s\n' "$H0 I/HMG-API (  905): [wireless-carplay-aa] bridge: iAP2 connected comp=1" "$H0 I/HMG-API (  905): [wireless-carplay-aa] bridge: iAP2 connected comp=4" > $WE/aalog2
wa 'UPTIME='$WE'/uptime; HINT_ON=1; aa_events; echo "IPH=[$IPH_AT]"' > $WE/i11
check "  리뷰 M-3: 유선(USB, 구성요소 1) 카플레이 중에는 블루투스 iAP2가 붙어도 아이폰 Wi-Fi 안내 판정을 하지 않음" 'grep -q "IPH=\[\]" $WE/i11 && grep -q "아이폰 USB(유선) iAP2 연결" $WE/i11'
rm -f $WE/w/aatime
printf '%s\n' "$H0 I/HMG-API (  905): [wireless-carplay-aa] bridge: iAP2 connected comp=1" "$H0 I/HMG-API (  905): [wireless-carplay-aa] bridge: iAP2 disconnected comp=1" "$H0 I/HMG-API (  905): [wireless-carplay-aa] bridge: iAP2 connected comp=4" > $WE/aalog2
wa 'UPTIME='$WE'/uptime; HINT_ON=1; aa_events; echo "IPH=$((1000 - IPH_AT))"' > $WE/i12
check "  유선이 끊긴 뒤의 블루투스 iAP2는 다시 판정함(㉑: H0 뒤 실제 경과 초 이하)" 'iph_since_h0 $WE/i12'
printf '%s\n' "<6>[  400.0] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **" "<4>[  701.372626] ETHER_TYPE_802_1X[wlan0] [RX] : M4 of 4way" > $WE/dmesg; echo "710.50 100.0" > $WE/uptime; rm -f $WE/w/ktime
wa 'UPTIME='$WE'/uptime; wifi_events; echo "WC=$WCONN_AT"' > $WE/i10
check "  wifi_events가 기기 연결 시각을 부팅 뒤 초(커널 시각 701초)로 기억(재리뷰 L4: 시계가 아니라 부팅 뒤 초로 비교)" 'grep -qx "WC=701" $WE/i10'
# --- 베타 2 차주 제보(#64): "can't create /ktime" ---
# 차와 같은 기본값(환경 변수 없음)으로 hotspot.sh를 읽었을 때 경로가 실제 기본값인지(예전에는 KTB가 /ktime)
DEFP=$(env -i PATH=/usr/bin:/bin HOTSPOT_LIB=1 sh -c '. '$PKG'/svc/hotspot.sh; echo "$KTB|$KT|$BK|$W|$AAOFF|$APON_ORIG"' 2>/dev/null)
check "베타 2 차주 제보: 환경 변수 없이(차와 같은 기본값) KTB·KT·BK·W·AAOFF·APON_ORIG가 실제 기본 경로(KTB=/data/nx4-kor/backup/ktime)" '[ "$DEFP" = "/data/nx4-kor/backup/ktime|/data/local/tmp/nx4-kor/ktime|/data/nx4-kor/backup|/data/local/tmp/nx4-kor|/data/nx4-kor/backup/aa-off|/data/nx4-kor/backup/wifi_ap_on.orig" ]'
check "1.7.4 B-7: 백업 폴더 경로는 hotspot.sh에 한 번만(BK 기본값, AAOFF보다 위), AAOFF·APON_ORIG·KTB는 \$BK를 씀" '[ "$(grep -c "/data/nx4-kor/backup" $PKG/svc/hotspot.sh)" = 1 ] && [ "$(grep -n "^BK=" $PKG/svc/hotspot.sh | cut -d: -f1)" -lt "$(grep -n "^AAOFF=" $PKG/svc/hotspot.sh | cut -d: -f1)" ] && grep -qx "AAOFF=\${AAOFF:-\$BK/aa-off}" $PKG/svc/hotspot.sh && grep -qx "KTB=\${KTB:-\$BK/ktime}" $PKG/svc/hotspot.sh && grep -qx "APON_ORIG=\${APON_ORIG:-\$BK/wifi_ap_on.orig}" $PKG/svc/hotspot.sh'
DEFP2=$(env -i PATH=/usr/bin:/bin BK=/x/bk HOTSPOT_LIB=1 sh -c '. '$PKG'/svc/hotspot.sh; echo "$KTB|$AAOFF|$APON_ORIG|$PERMS_OURS"' 2>/dev/null)
check "  B-7: BK를 바꾸면 KTB·AAOFF·APON_ORIG·PERMS_OURS가 모두 그 아래" '[ "$DEFP2" = "/x/bk/ktime|/x/bk/aa-off|/x/bk/wifi_ap_on.orig|/x/bk/perms.ours" ]'
# 정적 검사: 맨 위 기본값 대입이 아래에서 정해지는 변수를 먼저 쓰지 않음, "> 파일 2>/dev/null" 순서가 없음(tests/tools/defuse-check.py)
python3 $B/tests/tools/defuse-check.py $PKG > $T/defuse.out 2>&1; DEFRC=$?
check "  베타 2 차주 제보: 정적 검사 — 정의 전에 쓰는 변수·'> 파일 2>/dev/null' 순서가 패키지 스크립트에 없음" '[ $DEFRC = 0 ] && [ ! -s $T/defuse.out ]' || cat $T/defuse.out
# 검사기가 헛돌지 않는지: 예전 꼴(KTB=${KTB:-$BK/ktime}, "> $KTB 2>/dev/null")을 심은 사본에서는 잡아야 함
mkdir -p $T/defbad/svc $T/defbad/bin $T/defbad/scripts; cp $PKG/bin/status.sh $T/defbad/bin/; cp $PKG/scripts/post.sh $PKG/scripts/preun.sh $T/defbad/scripts/
# 1.7.4(B-7): BK 기본값이 맨 위로 옮겨졌으므로, 예전처럼 BK를 아래(옛 자리 주석 줄)에서 정하는 꼴로 되돌려 심는다
sed -e 's#^KTB=.*#KTB=${KTB:-$BK/ktime}#' -e 's#echo "$_bid $_kt $WSTA" 2>/dev/null > $KTB#echo "$_bid $_kt $WSTA" > $KTB 2>/dev/null#' \
  -e '/^BK=\${BK:-\/data\/nx4-kor\/backup}$/d' $PKG/svc/hotspot.sh | awk '{ print } /^HMG_MIN=/ { print "BK=${BK:-/data/nx4-kor/backup}" }' > $T/defbad/svc/hotspot.sh
python3 $B/tests/tools/defuse-check.py $T/defbad > $T/defbad.out 2>&1; DEFRC2=$?
check "  베타 2 차주 제보: 정적 검사가 예전 꼴을 잡음(KTB가 BK를 먼저 씀, '> \$KTB 2>/dev/null' 순서)" '[ $DEFRC2 = 1 ] && grep -q "KTB=…가 BK" $T/defbad.out && grep -q "^svc/hotspot.sh:[0-9]* \"> 파일 2>/dev/null\" 순서" $T/defbad.out'
rm -rf $T/defbad
# 동작: 백업 폴더($BK)를 쓸 수 없어도(차의 /ktime처럼) wifi_events가 셸 오류 줄을 ap.log(표준 오류)에 남기지 않음
mkdir -p $WE/robk; chmod 500 $WE/robk; rm -f $WE/w/ktime
printf '%s\n' "<6>[  990.0] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **" > $WE/dmesg
(PATH=$WE/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB=$T/bin/bb W=$WE/w BOOT_ID=$WE/bootid KTB=$WE/robk/sub/ktime sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$WE'/bin:'$T'/bin:/usr/bin:/bin:/sbin; wifi_events' > $WE/ro.out 2> $WE/ro.err)
check "  베타 2 차주 제보: 백업 사본을 쓸 수 없어도 셸 오류(can't create·Permission denied) 없이 \$W 기록은 씀" '[ ! -s $WE/ro.err ] && grep -q "AP 올라옴 (커널 990초)" $WE/ro.out && grep -q " 990.0 " $WE/w/ktime'
chmod 700 $WE/robk; rm -rf $WE/robk; rm -f $WE/dmesg $WE/w/ktime

# 베타 1 리뷰 A: 지금 우리 AP에 붙은 기기 수(WSTA)를 커널 줄로 센다(연결 +1, 끊김 -1, 브로드캐스트 끊김은 안 셈, AP 올라옴 0)
WBID=$(cat $WE/bootid); echo boot-A > $WE/bootid; rm -rf $WE/bk; mkdir -p $WE/bk; rm -f $WE/w/ktime
printf '%s\n' "<6>[  900.0] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **" "<4>[  901.0] ETHER_TYPE_802_1X[wlan0] [RX] : M4 of 4way" "<4>[  902.0] ETHER_TYPE_802_1X[wlan0] [RX] : M4 of 4way" "<6>[  903.0] CFG80211-ERROR) wl_cfg80211_del_station : Disconnect STA : aa:bb:cc:dd:ee:ff" "<6>[  904.0] CFG80211-ERROR) wl_cfg80211_del_station : Disconnect STA : ff:ff:ff:ff:ff:ff scb_val.val 3" > $WE/dmesg
wa 'UPTIME='$WE'/uptime; wifi_events; echo "WSTA=$WSTA"' > $WE/ws1
check "베타 1 리뷰 A: 붙은 기기 수 = 연결 2 - 끊김 1(브로드캐스트 끊김은 안 셈) = 1, 부팅 id·커널 초와 함께 \$W·\$BK에 둠" 'grep -qx "WSTA=1" $WE/ws1 && grep -qx "boot-A 904.0 1" $WE/w/ktime && grep -qx "boot-A 904.0 1" $WE/bk/ktime'
echo "<6>[  905.0] CFG80211-ERROR) wl_notify_connect_status_ap : ** AP/GO Link up event **" >> $WE/dmesg
wa 'UPTIME='$WE'/uptime; wifi_events; echo "WSTA=$WSTA"' > $WE/ws2
check "  베타 1 리뷰 A: 서비스가 다시 시작해도 기록에서 이어 받고, AP가 다시 올라오면 0" 'grep -qx "WSTA=0" $WE/ws2 && grep -qx "boot-A 905.0 0" $WE/bk/ktime'
# 베타 1 리뷰 C: 재부팅 없이 업데이트($W 지워짐)해도 \$BK의 기록으로 이미 남긴 커널 줄을 다시 쓰지 않음
rm -f $WE/w/ktime
wa 'UPTIME='$WE'/uptime; wifi_events' > $WE/ws3
check "베타 1 리뷰 C: \$W 기록이 지워져도(업데이트) \$BK 사본이 있으면 옛 'AP 채널'·'AP 올라옴' 줄을 다시 옮기지 않음" '[ ! -s $WE/ws3 ]'
echo boot-Z > $WE/bootid; rm -f $WE/w/ktime
wa 'UPTIME='$WE'/uptime; wifi_events' > $WE/ws4
check "  베타 1 리뷰 C: 부팅이 바뀌면(사본이 지난 부팅 것) 처음부터 다시 남김" 'grep -q "Wi-Fi: AP 올라옴 (커널 900초)" $WE/ws4'
echo "$WBID" > $WE/bootid; rm -rf $WE/bk; rm -f $WE/w/ktime $WE/dmesg
# 베타 1 리뷰 B: 시계가 맞기 전(연도가 패키지를 만든 해보다 이전)이면 ap.log 줄 앞에 시각 대신 "부팅 직후"
printf '#!/bin/sh\ncase "$1" in "+%%Y %%m-%%d %%H:%%M:%%S") echo "2016 01-01 18:30:05" ;; *) exec /bin/date "$@" ;; esac\n' > $WE/bin/date; chmod +x $WE/bin/date
echo "12.50 1.00" > $WE/upt12; we 'UPTIME='$WE'/upt12; log "시험 줄"' > $WE/lt1
we 'UPTIME='$WE'/upt12; log "권한 파일 되돌림: com.x.y"' > $WE/lt3
rm -f $WE/bin/date
we 'log "시험 줄"' > $WE/lt2
check "베타 1 리뷰 B·재리뷰 L6: 시계가 맞기 전이면 '부팅 직후(+12초) 시험 줄'(부팅 뒤 초), 맞은 뒤에는 'MM-DD HH:MM:SS 시험 줄'(예전 꼴)" 'grep -qx "부팅 직후(+12초) 시험 줄" $WE/lt1 && grep -q -E "^[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} 시험 줄$" $WE/lt2'
check "  재리뷰 L6: '부팅 직후(+N초)'도 두 칸이라 perms_seed의 칸 위치 읽기(\$3 == 권한, NF == 6)가 그대로 맞음" '[ "$(awk "\$3 == \"권한\" && \$4 == \"파일\" && \$5 == \"되돌림:\" && NF == 6 { print \$6 }" $WE/lt3)" = com.x.y ] && grep -q "^부팅 직후(+12초) 권한 파일 되돌림: com.x.y$" $WE/lt3'
check "  베타 1 리뷰 B: status.sh 감시자 로그(aplog)도 같은 log_ts를 씀" 'grep -q "^aplog() { log_ts; echo \"\$_LT \$\*\" 2>/dev/null >> \$APLOG; }$" $PKG/bin/status.sh'
rm -f $WE/bin/logcat $WE/w/aatime $WE/hint $WE/w/cpn $WE/dmesg $WE/w/ktime; echo boot-A > $WE/bootid
cp $WE/ps.keep2 $T/ps 2>/dev/null || : > $T/ps

# --- 1.7.2 P-3: softap.conf 변경 감시 ---
python3 - $WE/sa1 $WE/sa2 $WE/sa3 <<'E'
import struct,sys
u=lambda s:struct.pack('>H',len(s))+s.encode()
w=lambda p,s2,s4: open(p,'wb').write(struct.pack('>i',3)+u('HotspotName1')+u(s2)+struct.pack('>i',4)+u('hotpass123')+u(s4)+struct.pack('>i',149))
w(sys.argv[1],'OldCarSSID','OldPass12345'); w(sys.argv[2],'NewCarSSIDx','NewPass678901'); w(sys.argv[3],'OldCarSSID','OldPass12345')
open(sys.argv[3],'ab').write(b'\x00\x01')
E
cp $WE/sa1 $WE/softap.conf
mkdir -p $WE/pn0; echo "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode" > $WE/pn0/tcp
echo "  4321 root 0 S hostapd $WE/hk.conf" > $T/ps
wc3() { (SRC=$WE/softap.conf PROCNET=${PN:-$WE/pn0}; export SRC PROCNET; wa 'parse_conf $SRC; write_conf; CONF_SIG=$(conf_sig $SRC); kill() { echo "kill $*" >> '$WE'/kills; }; HINT_ON=1; '"$1"); }
rm -f $WE/kills $WE/hint; wc3 'conf_tick' > $WE/c0
check "1.7.2 P-3: softap.conf가 그대로면 아무것도 안 함" '[ ! -s $WE/c0 ] && [ ! -f $WE/kills ] && grep -qx "ssid=OldCarSSID" $WE/hk.conf'
wc3 'cp '$WE'/sa2 $SRC; conf_tick' > $WE/c1
check "  카플레이 SSID·비밀번호가 바뀌고 연결이 없으면 설정을 다시 쓰고 우리 hostapd만 다시 띄움, 로그에는 길이만" 'grep -qx "ssid=NewCarSSIDx" $WE/hk.conf && grep -qx "wpa_passphrase=NewPass678901" $WE/hk.conf && grep -qx "kill 4321" $WE/kills && grep -q "SSID 길이 10→11, 비밀번호 길이 12→13" $WE/c1 && ! grep -q -e NewCarSSIDx -e NewPass -e OldCarSSID -e OldPass $WE/c1'
cp $WE/sa1 $WE/softap.conf; rm -f $WE/kills $WE/hint
(PN=$PROCNET; wc3 'cp '$WE'/sa2 $SRC; conf_tick; echo "S2=${#S2}"; conf_tick') > $WE/c2
check "  카플레이가 연결되어 있으면 미루고(설정·hostapd 그대로) 상태 화면에 conf=wait, 안내·로그는 한 번" 'grep -qx "ssid=OldCarSSID" $WE/hk.conf && [ ! -f $WE/kills ] && grep -qx "conf=wait" $WE/hint && [ "$(grep -c "연결이 끝나면 핫스팟을 다시 시작" $WE/c2)" = 1 ] && grep -q "S2=10" $WE/c2'
cp $WE/sa1 $WE/softap.conf; rm -f $WE/kills $WE/hint
(PN=$PROCNET; wc3 'cp '$WE'/sa2 $SRC; conf_tick; parse_conf() { echo PARSED; }; conf_tick') > $WE/c2b
check "  리뷰 M-4: 미뤄 둔 같은 변경은 연결 중 다시 읽지 않음(parse_conf 안 부름)" '! grep -q PARSED $WE/c2b'
cp $WE/sa1 $WE/softap.conf; rm -f $WE/kills
(PN=$PROCNET; wc3 'cp '$WE'/sa2 $SRC; conf_tick; PROCNET='$WE'/pn0; conf_tick') > $WE/c3
check "  연결이 끝나면 다음 점검에서 다시 띄우고 안내를 지움" 'grep -qx "ssid=NewCarSSIDx" $WE/hk.conf && grep -qx "kill 4321" $WE/kills && grep -qx "conf=" $WE/hint'
cp $WE/sa1 $WE/softap.conf; rm -f $WE/kills
wc3 'cp '$WE'/sa3 $SRC; conf_tick' > $WE/c4
check "  파일은 바뀌었지만 카플레이 SSID·비밀번호가 같으면 다시 띄우지 않음" '[ ! -f $WE/kills ] && grep -qx "ssid=OldCarSSID" $WE/hk.conf && ! grep -q "핫스팟을" $WE/c4'
cp $WE/sa1 $WE/softap.conf; rm -f $WE/kills
wc3 'printf "\0\0\0\3" > $SRC; conf_tick; echo "S2=$S2 NS=$NS"; conf_tick' > $WE/c5
check "  새 파일을 읽지 못하면 지금 설정 그대로(값 되돌림), 로그 한 번" '[ ! -f $WE/kills ] && grep -qx "ssid=OldCarSSID" $WE/hk.conf && grep -q "S2=OldCarSSID NS=4" $WE/c5 && [ "$(grep -c "읽지 못함" $WE/c5)" = 1 ]'
cp $WE/sa1 $WE/softap.conf
check "  conf_auth: 카플레이 SSID 다음 정수(4)만, 문자열은 내지 않음" '[ "$(SRC=$WE/softap.conf wa "conf_auth \$SRC")" = 4 ] && [ -z "$(SRC=$WE/none wa "conf_auth \$SRC")" ]'
check "  서비스 30초 점검이 conf_tick(up 전)·hint_tick을 부르고, 시작 때 서명을 기억함, 순정 AP 경로는 부르지 않음" 'awk "/^main\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -A1 "ap_tick$" | grep -q "conf_tick" && grep -q "CONF_SIG=\$(conf_sig \$SRC)" $PKG/svc/hotspot.sh && [ -z "$(awk "/^stock_ap_mode\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -e conf_tick -e hint_tick)" ] && [ "$(awk "/^main\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -c "^ *hint_tick$")" = 2 ]'
cp $WE/ps.keep2 $T/ps 2>/dev/null || : > $T/ps

# --- 1.7.2 P-15: ap.log 크기 제한 ---
rm -f $WE/ap.log*
(wa 'APLOG='$WE'/ap.log; APMAX=200; fd_target() { echo "$APLOG"; }; aplog_open; i=0; while [ $i -lt 12 ]; do log "line $i"; i=$((i+1)); done; aplog_rotate; log after') >> $WE/ap.log
check "1.7.2 P-15: ap.log가 APMAX를 넘으면 ap.log.1로 옮기고 비운 뒤 이어서 씀(덧붙이기로 다시 열어 빈칸 없음)" 'grep -q "line 11" $WE/ap.log.1 && ! grep -q "line" $WE/ap.log && grep -q "after" $WE/ap.log && grep -q "ap.log.1로 옮김" $WE/ap.log && [ $(wc -c < $WE/ap.log) -lt 200 ]'
(wa 'APLOG='$WE'/ap.log; APMAX=10; fd_target() { echo "$APLOG"; }; aplog_open; log x2; aplog_rotate; log y2') >> $WE/ap.log
check "  최대 2개(ap.log, ap.log.1)만" '[ ! -f $WE/ap.log.2 ] && grep -q x2 $WE/ap.log.1 && grep -q y2 $WE/ap.log'
rm -f $WE/ap.log*; i=0; while [ $i -lt 20 ]; do echo "old line $i" >> $WE/ap.log; i=$((i+1)); done
wa 'APLOG='$WE'/ap.log; APMAX=10; aplog_open; aplog_rotate' > $WE/apo
check "  표준출력이 ap.log가 아니면(파이프 등) 밀지 않음" '[ ! -f $WE/ap.log.1 ] && grep -q "old line 19" $WE/ap.log'
check "  서비스는 시작 때 aplog_open, 점검마다 logrotate에서 aplog_rotate" 'awk "/^main\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "^  aplog_open$" && awk "/^logrotate\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "^  aplog_rotate$"'

# --- 1.7.2 P-16: killlog(NUL에 기대지 않음) ---
mkdir -p $WE/kp/777 $WE/kp/778; echo "777 (busybox) S 1 1" > $WE/kp/777/stat; echo "778 (sh) S 1 1" > $WE/kp/778/stat
printf '/system/bin/busybox\0uniq\0-c\0-f\0002\0' > $WE/kp/777/cmdline
kl() { rm -f $WE/kills; echo "$1" > $WE/w/log.pid; wa 'PROC='$WE'/kp; kill() { echo "kill $*" >> '$WE'/kills; }; killlog'; }
kl "777 boot-A"
check "1.7.2 P-16: log.pid의 pid가 이번 부팅의 busybox 애플릿(stat 이름 칸)이면 멈춤(cmdline NUL과 상관없음), log.pid 지움" 'grep -qx "kill 777" $WE/kills && [ ! -f $WE/w/log.pid ]'
kl "777 boot-OLD"
check "  지난 부팅의 pid는 멈추지 않음" '[ ! -f $WE/kills ] && [ ! -f $WE/w/log.pid ]'
kl "777"
check "  부팅 id가 없는 예전 형식(1.7.1까지)은 멈추지 않음" '[ ! -f $WE/kills ]'
kl "778 boot-A"
check "  이름이 busybox·uniq·grep이 아니면 멈추지 않음" '[ ! -f $WE/kills ]'
kl "779 boot-A"
check "  없는 pid는 멈추지 않음" '[ ! -f $WE/kills ]'
check "  logstart는 log.pid에 pid와 부팅 id를 함께 남김(4b K-7: 서비스가 시작 때 읽은 BID, 없으면 그때 읽음)" 'grep -q "echo \"\$! \${BID:-\$(cat \${BOOT_ID" $PKG/svc/hotspot.sh'

# --- 1.7.2 P-17·P-11 구조 확인 ---
check "1.7.2 P-17: 이번 부팅 첫 시작이면 svc.start와 표시 줄, 같은 부팅이면 '다시 시작'" 'grep -q "^SVC_MARK=\"서비스 시작: 이번 부팅 처음\"" $PKG/svc/hotspot.sh && awk "/^main\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "log \"\$SVC_MARK" && awk "/^main\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "서비스 다시 시작(같은 부팅"'
# 4b K-7: 작은 단순화(동작 그대로)
check "4b K-7: try_ready는 setup_done을 부름(같은 조건이 한 곳에)" 'awk "/^try_ready\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "^  setup_done$"'
check "  4b K-7: 지원 안 되는 차 대기도 idle_forever 꼴(sleep을 뒤에서 돌리고 wait, 리뷰 L-3; 제보 요청을 보던 idle_req는 없앰), sleep 3600 반복이 main에 남지 않음" '! awk "/^main\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "do sleep 3600; done" && [ "$(awk "/^main\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -c "^ *idle_forever$")" = 3 ] && ! grep -q "idle_req" $PKG/svc/hotspot.sh'
check "  4b K-7: 서비스는 시작 때 부팅 id를 한 번 읽어 BID에 둠" 'awk "/^main\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "^  BID=\$_sb$"'
check "  4b K-7(#65): 첫 시작 줄에 '재부팅 없이 설치·업데이트했으면 그 뒤 첫 시작'도 적음(표시 줄 SVC_MARK는 그대로)" 'grep -q "log \"\$SVC_MARK(부팅 뒤 \${_su:-?}초. 재부팅 없이 설치·업데이트했으면 그 뒤 첫 시작)\"" $PKG/svc/hotspot.sh'
# BID가 있으면 그것을 쓰고(부팅 id 파일을 다시 읽지 않음), 없으면 예전처럼 파일을 읽는다
echo boot-F > $WE/bootid; echo boot-M > $WE/w/nowlan
check "  4b K-7: BID가 있으면 그 값으로 이번 부팅을 봄, 없으면 부팅 id 파일을 읽음(예전 그대로)" '[ "$(we "BID=boot-M; NOWLAN=$WE/w/nowlan; nowlan_now && echo Y")" = Y ] && [ -z "$(we "NOWLAN=$WE/w/nowlan; nowlan_now && echo Y")" ]'
rm -f $WE/w/nowlan
rm -rf $WE

# --- 1.6.2: 순정 카플레이 AP(K3 BDPE #15)와 순정 일반 핫스팟 가리기, 우리 dnsmasq는 pid로만 ---
# 서비스 main을 가짜 차에서 돌린다. wait를 바꿔 n번째 대기 때 ps.n이 있으면 ps를 바꾸고(순정 AP가 꺼지거나 켜짐),
# SKW번째 대기에서 7로 끝낸다. kill은 기록만 한다. 순정 hostapd의 ps 줄은 80칸에서 잘린 모양, cmdline은 전체다.
SK=$T/sk; rm -rf $SK; mkdir -p $SK/bin $SK/stock $SK/proc/77 $SK/proc/78 $SK/proc/60
cat > $SK/bin/getprop <<E
#!/bin/sh
case "\$1" in
  ro.build.product) cat $SK/product ;;
  sys.boot_completed) echo 1 ;;
  persist.sys.iap2.wifi) echo t ;;
  *) echo 0 ;;
esac
E
printf '#!/bin/sh\ncat %s/ps 2>/dev/null\n' $SK > $SK/bin/ps
for c in svc hostapd dnsmasq killall settings ifconfig; do printf '#!/bin/sh\necho "%s $*" >> %s/calls\n' $c $SK > $SK/bin/$c; done
printf '#!/bin/sh\nexit 0\n' > $SK/bin/sleep
printf '#!/bin/sh\nexit 0\n' > $SK/bin/dmesg
printf '#!/bin/sh\nexit 0\n' > $SK/bin/netstat
printf '#!/bin/sh\nexit 1\n' > $SK/bin/hmgapid
chmod +x $SK/bin/*
echo boot-sk > $SK/bootid
printf '/system/bin/hostapd\0-e\0/data/misc/wifi/entropy.bin\0%s\0' $SK/stock/hostapd.conf > $SK/proc/77/cmdline
# 순정 hostapd·dnsmasq의 부모는 netd(pid 60)다(KitKat SoftapController). 우리 USB 스크립트 것은 부모가 netd가 아니다.
echo "60 (netd) S 1 60" > $SK/proc/60/stat
echo "77 (hostapd) S 60 77" > $SK/proc/77/stat
echo "78 (dnsmasq) S 60 78" > $SK/proc/78/stat
# ps가 자른 순정 hostapd 줄(설정 파일 경로가 끝까지 안 보임)과 순정 dnsmasq(우리 것과 명령 앞부분이 같음)
SPS1="  77 wifi      /system/bin/hostapd -e /data/misc/wifi/entropy.bin ${SK%/*}/sk/stock/hos"
SPS2="  78 nobody    dnsmasq --keep-in-foreground --no-resolv --no-poll --dhcp-authoritative --pid-file"
stockps() { printf '%s\n' "$SPS1" "$SPS2"; }
sconf() { printf 'interface=wlan0\ndriver=nl80211\nctrl_interface=/data/misc/wifi/hostapd\nssid=%s\nchannel=149\nhw_mode=a\nwpa_passphrase=word77x\n' "$1" > $SK/stock/hostapd.conf; }
skreset() { rm -rf $SK/w $SK/bk $SK/hd $SK/calls $SK/notice $SK/prog $SK/ps $SK/ps.* $SK/hostapd-kp.conf $SK/wifi $SK/out; mkdir -p $SK/w $SK/bk $SK/hd/mods/nx4-kor $SK/wifi; echo "ctrl_interface=wlan0" > $SK/wifi/wpa_supplicant.conf; chmod 644 $SK/wifi/wpa_supplicant.conf; echo '{"id": "nx4-kor"}' > $SK/hd/mods/nx4-kor/mod.json; echo NX4.KOR.0000.V039.001.260902 > $SK/product; : > $SK/ps; sconf 'SSID\cX'; }
skrun() { (PATH=$SK/bin:$T/bin:/usr/bin:/bin:/sbin env HOTSPOT_LIB=1 NOTICE=$SK/notice BB=$T/bin/bb W=$SK/w BK=$SK/bk HMGDATA=$SK/hd PROG=$SK/prog BOOT_ID=$SK/bootid PROC=$SK/proc CONF=$SK/hostapd-kp.conf SRC=$T/softap.conf WCONF=$SK/wifi/wpa_supplicant.conf WIFI_WAIT=0 WPDIR=$SK/none KT=$SK/w/kt "$@" ${SKSH:-sh} -c '. '$T'/app/svc/hotspot.sh; export PATH='$SK'/bin:'$T'/bin:/usr/bin:/bin:/sbin; fix_perms() { :; }; kill() { echo "kill $*" >> '$SK'/calls; }; _wc=0; wait() { _wc=$((_wc+1)); [ -f '$SK'/ps.$_wc ] && cp '$SK'/ps.$_wc '$SK'/ps; [ -f '$SK'/conf.$_wc ] && cp '$SK'/conf.$_wc '$SK'/stock/hostapd.conf; [ $_wc -ge ${SKW:-1} ] && exit 7; return 0; }; main') > $SK/out 2>&1; echo "rc=$?" >> $SK/out; }
# 우리 것을 하나도 하지 않았는가(svc wifi, hostapd·dnsmasq 시작, kill, Wi-Fi 잠금 파일)
noours() { ! grep -q -E "^(svc|hostapd|dnsmasq|kill|killall) " $SK/calls 2>/dev/null && [ "$(stat -f %Lp $SK/wifi/wpa_supplicant.conf)" = 644 ] && [ "$(cat $SK/wifi/wpa_supplicant.conf)" = "ctrl_interface=wlan0" ] && [ -z "$(ls $SK/wifi | grep -v "^wpa_supplicant.conf$")" ]; }
skreset; stockps > $SK/ps; skrun SKW=3
check "1.6.2·1.7.4 소유자 문구: 투싼 NX4 + 순정 카플레이 AP → 진행 기록 done '무선 카플레이·안드로이드 오토 준비됨.'(AA 안 끈 차)" 'grep -q "순정 카플레이 AP 사용: 우리 핫스팟을 켜지 않음 (카플레이 SSID 길이 7 일치)" $SK/out && grep -qx "state=done" $SK/prog && grep -qx "stage=무선 카플레이·안드로이드 오토 준비됨." $SK/prog'
check "  우리 hostapd·dnsmasq·svc wifi·Wi-Fi 잠금·kill 없음, 순정 AP 기록(stockap.seen)" 'noours && [ -f $SK/bk/stockap.seen ]'
check "  반복 없음: 3번 대기해도 로그는 처음 한 줄, '대기: 다른 hostapd' 없음, 60초 대기로 끝나지 않음(rc 7)" '[ "$(grep -c "순정 카플레이 AP" $SK/out)" = 1 ] && ! grep -q "대기: 다른 hostapd" $SK/out && grep -qx "rc=7" $SK/out'
check "  SSID·비밀번호 값은 로그·진행 기록에 없음(길이만)" '! grep -q -F -e "SSID\\cX" -e "HotspotName1" -e "word77x" -e "word99" $SK/out $SK/prog'
check "  우리 hostapd 설정 파일(5GHz 149)은 쓰기만 하고 띄우지 않음" 'grep -qx "channel=149" $SK/hostapd-kp.conf && ! grep -q "^hostapd " $SK/calls 2>/dev/null'
skreset; stockps > $SK/ps; sconf HotspotName1; skrun
check "1.6.2: NX4 + 순정 일반 핫스팟(핫스팟 SSID) → 지금처럼 비켜 줌(기다림), 준비됨·기록 없음" 'grep -q "대기: 다른 hostapd가 돌고 있음(순정 핫스팟 등, 판정 hotspot)" $SK/out && [ ! -f $SK/bk/stockap.seen ] && ! grep -q "내비 Wi-Fi" $SK/prog && noours'
skreset; stockps > $SK/ps; sconf OtherNet; skrun
check "  다른 SSID(판정 other)도 비켜 줌" 'grep -q "판정 other)" $SK/out && [ ! -f $SK/bk/stockap.seen ] && noours'
# 1.7.3: 순정 AP 회차는 30초 대기 두 번(사이에 제보 요청 점검) 뒤에 본문이 돈다: 가짜 wait 번호는 회차마다 2씩
skreset; stockps > $SK/ps; : > $SK/ps.2; stockps > $SK/ps.4; skrun SKW=8
check "1.6.2: 순정 AP가 도중에 사라지면 우리 AP로 바꾸지 않고 기다림, 다시 켜지면 기록(바뀔 때만 한 줄씩)" '[ "$(grep -c "순정 카플레이 AP가 꺼짐: 순정이 다시 켤 때까지 기다림" $SK/out)" = 1 ] && [ "$(grep -c "순정 카플레이 AP가 켜짐$" $SK/out)" = 1 ] && noours && grep -qx "rc=7" $SK/out'
skreset; : > $SK/bk/stockap.seen; skrun SKW=2
check "  순정 AP를 본 차는 다음 부팅에 순정 AP가 늦어도 우리 AP를 켜지 않고 기다림, 못 본 부팅을 셈(1)" 'grep -q "순정 카플레이 AP를 기다림" $SK/out && noours && ! grep -q "내비 Wi-Fi" $SK/prog 2>/dev/null && [ "$(cat $SK/bk/stockap.miss)" = "1 boot-sk" ]'
skrun SKW=2
check "  같은 부팅에 서비스가 다시 시작돼도 한 번만 셈" '[ "$(cat $SK/bk/stockap.miss)" = "1 boot-sk" ]'
stockps > $SK/ps.2; skrun SKW=3
check "  기다리다 순정 AP가 켜지면 셈을 0으로" '[ "$(cat $SK/bk/stockap.miss)" = "0 boot-sk" ] && grep -q "순정 카플레이 AP가 켜짐" $SK/out'
skreset; : > $SK/bk/stockap.seen; echo "3 boot-old" > $SK/bk/stockap.miss; skrun; /bin/sleep 1
check "  못 본 부팅이 3번 이어지면 기록을 지우고 보통 흐름(우리 핫스팟)으로" 'grep -q "3번의 부팅 동안 못 봄" $SK/out && [ ! -f $SK/bk/stockap.seen ] && grep -q "^hostapd " $SK/calls'
skreset; : > $SK/bk/stockap.seen; echo "2 boot-old" > $SK/bk/stockap.miss; skrun
check "  2번이면 아직 기다림" 'grep -q "순정 카플레이 AP를 기다림" $SK/out && noours'
# 리뷰 H2: 우리 USB 스크립트(cp-ap.sh)처럼 netd가 아닌 것이 카플레이 SSID로 띄운 hostapd는 순정으로 보지 않음
skreset; echo "77 (hostapd) S 1 77" > $SK/proc/77/stat; stockps > $SK/ps; skrun
check "  netd가 띄우지 않은 hostapd(카플레이 SSID라도)는 순정 카플레이 AP로 보지 않음(판정 unknown, 기록 없음)" 'grep -q "판정 unknown)" $SK/out && [ ! -f $SK/bk/stockap.seen ] && noours'
echo "77 (hostapd) S 60 77" > $SK/proc/77/stat
skreset; printf '/system/bin/hostapd\0%s\0' $SK/stock/hostapd-cp.conf > $SK/proc/77/cmdline; cp $SK/stock/hostapd.conf $SK/stock/hostapd-cp.conf; stockps > $SK/ps; skrun
check "  hostapd-cp.conf(USB 스크립트 설정)도 순정으로 보지 않음" 'grep -q "판정 unknown)" $SK/out && [ ! -f $SK/bk/stockap.seen ]'
printf '/system/bin/hostapd\0-e\0/data/misc/wifi/entropy.bin\0%s\0' $SK/stock/hostapd.conf > $SK/proc/77/cmdline
# 리뷰 M3: 일반 핫스팟을 기다리는 중 판정이 카플레이로 바뀌면 순정 AP 경로로, 순정이 잠깐 내려가도 바로 시작하지 않음
skreset; stockps > $SK/ps; sconf HotspotName1; sconf 'SSID\cX'; cp $SK/stock/hostapd.conf $SK/conf.1; sconf HotspotName1; skrun SKW=3
check "  기다리는 중 순정이 카플레이 AP로 바꾸면 순정 AP 경로로" 'grep -q "판정 hotspot)" $SK/out && grep -q "순정 카플레이 AP 사용" $SK/out && [ -f $SK/bk/stockap.seen ] && noours'
# 1.7.3: 다른 hostapd 대기도 30초 대기 두 번마다 한 번 본다(가짜 wait 번호 2씩)
skreset; stockps > $SK/ps; sconf HotspotName1; : > $SK/ps.2; stockps > $SK/ps.4; skrun SKW=5
check "  순정 hostapd가 한 번 안 보였다 다시 보이면 계속 기다림(우리 것 시작 안 함)" '! grep -q "다른 hostapd가 멈춤: 시작" $SK/out && noours'
skreset; stockps > $SK/ps; sconf HotspotName1; : > $SK/ps.2; skrun SKW=5; /bin/sleep 1
check "  두 번 이어서 안 보이면 그때 시작" '[ "$(grep -c "다른 hostapd가 멈춤: 시작" $SK/out)" = 1 ] && grep -q "^hostapd " $SK/calls'
sconf 'SSID\cX'
# busybox 없는 내비(함께 넣은 busybox, ps -o 형식): 순정 hostapd를 잠시 기다림
skreset; printf '%s\n' "PID   STAT COMMAND" "  77 S    /system/bin/hostapd -e /data/misc/wifi/entropy.bin $SK/stock/hostapd.conf" "  78 S    dnsmasq --keep-in-foreground --no-resolv --no-poll" > $SK/ps.1; skrun BB= BB_SYS=$SK/none BB_OWN=$T/bin/bb SKW=3
check "1.6.2: busybox 없는 내비(함께 넣은 busybox, ps -o) → 순정 AP를 기다렸다가 순정 AP로 준비됨" 'grep -q "순정 카플레이 AP를 최대 90초 기다림" $SK/out && grep -q "순정 카플레이 AP 사용" $SK/out && noours && grep -qx "state=done" $SK/prog'
skreset; skrun BB= BB_SYS=$SK/none BB_OWN=$T/bin/bb STOCK_GRACE=20 SKW=3; /bin/sleep 1  # 뒤에서 뜬 가짜 hostapd·dnsmasq가 기록을 쓸 틈
check "  기다려도 순정 AP가 없으면 우리 핫스팟(5GHz)을 켜고 dnsmasq pid를 남김" 'grep -q "최대 20초" $SK/out && grep -q "^svc wifi enable" $SK/calls && grep -q "^hostapd $SK/hostapd-kp.conf" $SK/calls && grep -q "^dnsmasq " $SK/calls && [ -s $SK/w/dnsmasq.pid ] && grep -qx "hw_mode=a" $SK/hostapd-kp.conf && [ ! -f $SK/bk/stockap.seen ]'
# 우리 핫스팟이 도는 중에 순정 카플레이 AP가 켜짐(ap_yield)
skl() { (PATH=$SK/bin:$T/bin:/usr/bin:/bin:/sbin env HOTSPOT_LIB=1 NOTICE=$SK/notice BB=$T/bin/bb W=$SK/w BK=$SK/bk HMGDATA=$SK/hd PROG=$SK/prog BOOT_ID=$SK/bootid PROC=$SK/proc CONF=$SK/hostapd-kp.conf SRC=${SKSRC:-$T/softap.conf} KT=$SK/w/kt sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$SK'/bin:'$T'/bin:/usr/bin:/bin:/sbin; kill() { echo "kill $*" >> '$SK'/calls; }; wait() { exit 7; }; parse_conf $SRC; '"$1"); }
skreset; mkdir -p $SK/proc/91; echo "91 (dnsmasq) S 1 91" > $SK/proc/91/stat; echo "91 boot-sk" > $SK/w/dnsmasq.pid
{ echo "  90 wifi      hostapd $SK/hostapd-kp.conf"; stockps; echo "  91 root      dnsmasq --keep-in-foreground --no-resolv --no-poll --dhcp-authoritative --pid-file"; } > $SK/ps
skl 'prod=NX4.KOR.0000.V039.001.260902; ap_yield' > $SK/out 2>&1
check "1.6.2: 우리 핫스팟 도는 중 순정 카플레이 AP가 켜지면 우리 hostapd·dnsmasq(pid)만 멈추고 순정 AP 경로로" 'grep -qx "kill 90" $SK/calls && grep -qx "kill 91" $SK/calls && ! grep -q -E "^kill (77|78)$" $SK/calls && [ ! -f $SK/w/dnsmasq.pid ] && grep -q "우리 핫스팟을 멈춤" $SK/out && grep -q "순정 카플레이 AP 사용" $SK/out && [ -f $SK/bk/stockap.seen ]'
# our_dhcp_on: pid 파일 기준(순정 dnsmasq를 우리 것으로 세지 않음)
skreset; stockps > $SK/ps
check "1.6.2 our_dhcp: 순정 dnsmasq만 돌면 우리 DHCP 아님(예전 명령 패턴은 우리 것으로 셌음)" '! skl our_dhcp_on && skl "running \"\$DNSMASQ\""'
mkdir -p $SK/proc/91; echo "91 (dnsmasq) S 1 91" > $SK/proc/91/stat
echo "91 boot-sk" > $SK/w/dnsmasq.pid
check "  pid 파일의 pid가 이번 부팅의 dnsmasq면 우리 DHCP" 'skl our_dhcp_on'
echo "91 boot-old" > $SK/w/dnsmasq.pid
check "  지난 부팅의 pid 파일은 무시" '! skl our_dhcp_on'
echo "91 boot-sk" > $SK/w/dnsmasq.pid; echo "91 (sleep) S 1 91" > $SK/proc/91/stat
check "  pid가 다른 프로그램이면 아님, 빈·숫자 아닌 pid도 아님" '! skl our_dhcp_on && echo "x1 boot-sk" > $SK/w/dnsmasq.pid && ! skl our_dhcp_on && : > $SK/w/dnsmasq.pid && ! skl our_dhcp_on'
skreset; stockps > $SK/ps; skl stop_ours
check "  stop_ours: 순정 hostapd가 돌고 pid 파일이 없으면 순정 dnsmasq를 죽이지 않음" '! grep -q "^kill" $SK/calls 2>/dev/null'
skreset; echo "  95 root      dnsmasq --keep-in-foreground --no-resolv --no-poll --dhcp-authoritative --pid-file" > $SK/ps; skl stop_ours
check "  stop_ours: 순정 hostapd가 없고 pid 파일도 없으면(예전 판이 띄운 우리 dnsmasq) 예전처럼 명령으로 멈춤" 'grep -qx "kill 95" $SK/calls'
# stock_ssid 판정
skreset
check "1.6.2 stock_ssid: 순정 hostapd 없음 → none" '[ "$(skl stock_ssid)" = none ]'
stockps > $SK/ps
check "  카플레이 SSID → carplay, 핫스팟 SSID → hotspot" '[ "$(skl stock_ssid)" = carplay ] && sconf HotspotName1 && [ "$(skl stock_ssid)" = hotspot ]'
printf 'ssid=a\nssid=b\n' > $SK/stock/hostapd.conf
check "  ssid 줄이 둘이면 unknown, ssid2=(16진)만 있으면 unknown" '[ "$(skl stock_ssid)" = unknown ] && printf "ssid2=53534944\n" > $SK/stock/hostapd.conf && [ "$(skl stock_ssid)" = unknown ]'
sconf 'SSID\cX'; mv $SK/proc/77 $SK/proc/77.x
check "  /proc의 명령줄을 못 읽으면 unknown(예전처럼 비켜 줌)" '[ "$(skl stock_ssid)" = unknown ]'
mv $SK/proc/77.x $SK/proc/77; rm $SK/stock/hostapd.conf
check "  설정 파일을 못 읽으면 unknown" '[ "$(skl stock_ssid)" = unknown ]'
sconf 'SSID\cX'
python3 - $SK/softap-same.conf <<'E'
import struct,sys
u=lambda s:struct.pack('>H',len(s))+s.encode()
open(sys.argv[1],'wb').write(struct.pack('>i',3)+u('SSID\\cX')+u('SSID\\cX')+u('x')+u('PASS\\word99'))
E
check "  핫스팟·카플레이 SSID가 같으면 가릴 수 없어 unknown" '[ "$(SKSRC=$SK/softap-same.conf skl stock_ssid)" = unknown ]'
printf 'interface=wlan0\nssid=SSID\\cX' > $SK/stock/hostapd.conf
check "  마지막 줄에 줄바꿈이 없어도 읽음" '[ "$(skl stock_ssid)" = carplay ]'
# 리뷰 M1: 예전 판 dnsmasq를 명령으로 찾을 때도 netd가 띄운 순정 dnsmasq는 멈추지 않음
skreset; echo "$SPS2" > $SK/ps; skl stop_ours
check "1.6.2 stop_ours: 순정 hostapd가 잠깐 없어도 netd가 띄운 dnsmasq는 멈추지 않음" '! grep -q "^kill" $SK/calls 2>/dev/null'
skreset; echo "$SPS2" > $SK/ps; echo "  96 root      dnsmasq --keep-in-foreground --no-resolv --no-poll --dhcp-authoritative --pid-file" >> $SK/ps; skl stop_ours
check "  같은 때 netd가 아닌 dnsmasq(예전 판의 우리 것)만 멈춤" 'grep -qx "kill 96" $SK/calls && ! grep -qx "kill 78" $SK/calls'
skreset; echo "  96 root      dnsmasq --keep-in-foreground --no-resolv --no-poll --dhcp-authoritative --pid-file" > $SK/ps; skl 'STOCK_MODE=1; stop_ours'
check "  순정 AP 경로(STOCK_MODE)에서는 명령으로 찾아 멈추지 않음" '! grep -q "^kill" $SK/calls 2>/dev/null'
# 순정 AP 경로에서 TERM을 받으면 바로 끝남(0), 순정 것은 멈추지 않음
skreset; stockps > $SK/ps
PATH=$SK/bin:$T/bin:/usr/bin:/bin:/sbin env HOTSPOT_LIB=1 BB=$T/bin/bb W=$SK/w BK=$SK/bk HMGDATA=$SK/hd PROG=$SK/prog BOOT_ID=$SK/bootid PROC=$SK/proc CONF=$SK/hostapd-kp.conf SRC=$T/softap.conf WCONF=$SK/wifi/wpa_supplicant.conf WPDIR=$SK/none KT=$SK/w/kt sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$SK'/bin:'$T'/bin:/usr/bin:/bin:/sbin; fix_perms() { :; }; kill() { echo "kill $*" >> '$SK'/calls; }; sleep() { /bin/sleep 2; }; main' > $SK/out 2>&1 &
SKPID=$!; /bin/sleep 1.5; kill -TERM $SKPID 2>/dev/null; wait $SKPID; echo "rc=$?" >> $SK/out
check "1.6.2: 순정 AP 경로에서 TERM을 받으면 정리하고 0으로 끝남, 순정 hostapd·dnsmasq는 멈추지 않음" 'grep -q "순정 카플레이 AP 사용" $SK/out && grep -q "멈춤$" $SK/out && grep -qx "rc=0" $SK/out && ! grep -q -E "^kill (77|78)$" $SK/calls 2>/dev/null'
# 리뷰 H1: 삭제·업데이트 때 순정 hostapd가 돌면 wlan0 주소를 지우지 않음
mkdir -p $SK/pbk $SK/phd
sed -e "s#^BB=.*#BB=$T/bin/bb#" -e "s#^BK=.*#BK=$SK/pbk#" -e "s#^APP=.*#APP=$T/app#" \
  -e "s#^HOTSPOT_LIB=1 [.] [$]APP/svc/hotspot.sh#&; export PATH=$SK/bin:$T/bin:/usr/bin:/bin:/sbin#" \
  -e "s#^export PATH=.*#export PATH=$SK/bin:$T/bin:/usr/bin:/bin:/sbin#" \
  -e "s#/data/local/tmp/nx4-kor-status#$SK/pstatus#g" $T/app/scripts/preun.sh > $SK/preun.sh
skpu() { rm -f $SK/calls; mkdir -p $SK/pbk; (env ${SKUPD:+KP_UPDATE=1} HMGDATA=$SK/phd W=$SK/pw PROC=$SK/proc PROG=$SK/pprog BOOT_ID=$SK/bootid CONF=$SK/hostapd-kp.conf WCONF=$SK/wifi/wpa_supplicant.conf sh $SK/preun.sh) > $SK/pout 2>&1; }
stockps > $SK/ps; skpu
check "1.6.2 삭제: 순정 hostapd가 돌면 wlan0 주소를 지우지 않음(순정 카플레이가 끊기지 않게)" '! grep -q "^ifconfig wlan0 0.0.0.0" $SK/calls 2>/dev/null'
: > $SK/ps; skpu
check "  순정 hostapd가 없으면 예전처럼 지움" 'grep -q "^ifconfig wlan0 0.0.0.0" $SK/calls'
# --- 1.7.2(P-7): 순정 AP 저장값(wifi_ap_on) 맞추기 ---
# 값을 기억하는 가짜 settings($SK/apon: 지금 값, 없으면 null). apon.ro가 있으면 put이 듣지 않음.
# "settings 명령 없음"은 $SK/bin·$T/bin의 settings를 잠시 치워서 만든다.
cp $SK/bin/settings $SK/settings.keep
cat > $SK/apset <<E
#!/bin/sh
echo "settings \$*" >> $SK/calls
case "\$1 \$3" in
  "get wifi_ap_on")
    # apon.after(N): N번째 get 직전에 값이 다시 1이 됨(세션 중 순정 AP 켜기가 1을 다시 씀)
    if [ -f $SK/apon.after ]; then echo x >> $SK/apon.gets; [ "\$(wc -l < $SK/apon.gets)" -eq "\$(cat $SK/apon.after)" ] && echo 1 > $SK/apon; fi
    cat $SK/apon 2>/dev/null || echo null ;;
  "put wifi_ap_on") [ -f $SK/apon.ro ] || echo "\$4" > $SK/apon ;;
esac
exit 0
E
chmod +x $SK/apset; cp $SK/apset $SK/bin/settings
# 우리 hostapd가 돌고 있는 ps(apon_off는 우리 hostapd가 돌 때만 바꾼다)
ourline() { echo "  90 wifi      hostapd $SK/hostapd-kp.conf"; }
ourps() { ourline > $SK/ps; }
apreset() { skreset; rm -f $SK/apon $SK/apon.ro $SK/apon.after $SK/apon.gets; echo NX4.KOR.0000.V039.001.260902 > $SK/product; ourps; }
apput() { grep -q "^settings put global wifi_ap_on" $SK/calls 2>/dev/null; }
apreset; echo 1 > $SK/apon; skrun; /bin/sleep 1
check "1.7.2 P-7: 우리 핫스팟이 도는 NX4 + wifi_ap_on=1 → 원래 값 1을 기록하고 0으로, 로그는 값만" '[ "$(cat $SK/apon)" = 0 ] && [ "$(cat $SK/bk/wifi_ap_on.orig)" = 1 ] && grep -q "순정 AP 저장값(wifi_ap_on) 1 → 0" $SK/out && grep -qx "rc=7" $SK/out'
apreset; echo 1 > $SK/apon; : > $SK/ps; skrun; /bin/sleep 1
check "  우리 hostapd가 돌지 않으면(켜지 못함) 바꾸지 않음(리뷰 L2)" 'grep -q "^hostapd " $SK/calls && [ "$(cat $SK/apon)" = 1 ] && [ ! -f $SK/bk/wifi_ap_on.orig ] && ! apput'
apreset; echo 1 > $SK/apon; skrun SKW=21; /bin/sleep 1
check "  30초 점검 20번째(10분)에 다시 봄: 값이 0이면 get 한 번뿐(put·로그 없음)" '[ "$(grep -c "^settings put global wifi_ap_on 0" $SK/calls)" = 1 ] && [ "$(grep -c "^settings get global wifi_ap_on" $SK/calls)" = 3 ] && [ "$(grep -c "wifi_ap_on" $SK/out)" = 1 ]'
apreset; echo 1 > $SK/apon; echo 3 > $SK/apon.after; skrun SKW=21; /bin/sleep 1
check "  시작 때 0으로 바꾼 뒤 세션 중 다시 1이 되면 10분 점검에서 또 0으로(리뷰 M2), 기록은 1 그대로" '[ "$(grep -c "^settings put global wifi_ap_on 0" $SK/calls)" = 2 ] && [ "$(cat $SK/apon)" = 0 ] && [ "$(cat $SK/bk/wifi_ap_on.orig)" = 1 ] && grep -qx "rc=7" $SK/out'
rm -f $SK/calls; skrun; /bin/sleep 1
check "  같은 부팅에 다시 시작(값 0): 기록은 1 그대로(0으로 덮지 않음), put 없음" '[ "$(cat $SK/bk/wifi_ap_on.orig)" = 1 ] && ! apput && ! grep -q "wifi_ap_on) 1 → 0" $SK/out'
echo 1 > $SK/apon; rm -f $SK/calls; skrun; /bin/sleep 1
check "  다른 곳에서 다시 1이 되면 다시 0으로, 기록은 1 그대로" '[ "$(cat $SK/apon)" = 0 ] && [ "$(cat $SK/bk/wifi_ap_on.orig)" = 1 ] && apput'
apreset; echo 0 > $SK/apon; skrun; /bin/sleep 1
check "  이미 0이면 아무것도 하지 않음(기록·put·로그 없음)" '[ ! -f $SK/bk/wifi_ap_on.orig ] && ! apput && ! grep -q "wifi_ap_on" $SK/out'
apreset; skrun; /bin/sleep 1
check "  값이 null(한 번도 안 씀)이면 그대로 두고 로그 한 줄, 기록 없음" '[ ! -f $SK/bk/wifi_ap_on.orig ] && ! apput && grep -q "wifi_ap_on) 그대로 둠: 값 없음·읽지 못함" $SK/out'
apreset; echo 1 > $SK/apon; : > $SK/apon.ro; skrun; /bin/sleep 1
check "  put이 듣지 않으면 로그 한 줄, 서비스는 계속 돎" 'grep -q "0으로 바꾸지 못함(지금 값 1)" $SK/out && grep -qx "rc=7" $SK/out'
apreset; echo 1 > $SK/apon; mv $SK/bin/settings $SK/settings.off; mv $T/bin/settings $T/settings.off; skrun; /bin/sleep 1
mv $SK/settings.off $SK/bin/settings; mv $T/settings.off $T/bin/settings
check "  settings 명령이 없으면 로그 한 줄만 남기고 넘어감(서비스는 계속, 기록 없음)" 'grep -q "맞추기 건너뜀: settings 명령 없음" $SK/out && [ ! -f $SK/bk/wifi_ap_on.orig ] && [ "$(cat $SK/apon)" = 1 ] && grep -qx "rc=7" $SK/out'
apreset; echo 1 > $SK/apon; : > $SK/bk/wifi.nochip; skrun; /bin/sleep 1
check "  Wi-Fi 칩 없음 기록(wifi.nochip)이 있는 차는 건드리지 않음" '[ "$(cat $SK/apon)" = 1 ] && [ ! -f $SK/bk/wifi_ap_on.orig ] && ! apput'
apreset; echo 1 > $SK/apon; echo NX4.KOR.0000.V039.001.260902 > $SK/product; skrun BB= BB_SYS=$SK/none BB_OWN=$T/bin/bb STOCK_GRACE=0; /bin/sleep 1
check "  함께 넣은 busybox를 쓰는 내비(tcc803x)는 우리 핫스팟이 돌아도 건드리지 않음" 'grep -q "시작 (NX4" $SK/out && [ "$(cat $SK/apon)" = 1 ] && [ ! -f $SK/bk/wifi_ap_on.orig ] && ! apput'
apreset; echo 1 > $SK/apon; echo NX4.KOR.0000.V039.001.260902 > $SK/product; { ourline; stockps; } > $SK/ps; skrun SKW=2
check "  순정 카플레이 AP 차(stockap 경로)는 건드리지 않음" 'grep -q "순정 카플레이 AP 사용" $SK/out && [ "$(cat $SK/apon)" = 1 ] && [ ! -f $SK/bk/wifi_ap_on.orig ] && ! apput'
apreset; echo 0 > $SK/apon; echo 1 > $SK/bk/wifi_ap_on.orig; echo NX4.KOR.0000.V039.001.260902 > $SK/product; stockps > $SK/ps; skrun SKW=2
check "  순정 카플레이 AP 경로로 가도 되돌리지 않음(0과 기록 그대로, 삭제 때 되돌림, 리뷰 M1)" 'grep -q "순정 카플레이 AP 사용" $SK/out && [ "$(cat $SK/apon)" = 0 ] && [ "$(cat $SK/bk/wifi_ap_on.orig)" = 1 ] && ! apput'
# preun(삭제): $SK/preun.sh, BK=$SK/pbk
apreset; : > $SK/ps; mkdir -p $SK/pbk; echo 1 > $SK/pbk/wifi_ap_on.orig; echo 0 > $SK/apon; skpu
check "  삭제(preun): 기록이 있고 지금 0이면 원래 값 1로 되돌림" '[ "$(cat $SK/apon)" = 1 ] && grep -q "wifi_ap_on) 되돌림: 0 → 1" $SK/pout && grep -q "NX4 KOR를 지웠습니다" $SK/pout'
apreset; mkdir -p $SK/pbk; echo 1 > $SK/pbk/wifi_ap_on.orig; echo 1 > $SK/apon; skpu
check "  삭제: 우리가 바꾼 뒤 다른 곳에서 바뀌었으면(지금 1) 그대로 둠(put 없음)" '[ "$(cat $SK/apon)" = 1 ] && ! apput && grep -q "다른 곳에서 바뀜(지금 값 1)" $SK/pout'
apreset; mkdir -p $SK/pbk; echo 0 > $SK/apon; skpu
check "  삭제: 기록이 없으면(우리가 바꾸지 않음) 0이어도 그대로" '[ "$(cat $SK/apon)" = 0 ] && ! apput'
apreset; mkdir -p $SK/pbk; echo 1 > $SK/pbk/wifi_ap_on.orig; echo 0 > $SK/apon; SKUPD=1; skpu; SKUPD=
check "  업데이트(preun KP_UPDATE=1, 새 판으로 바꾸기 전): 되돌리지 않고 기록도 남김" '[ "$(cat $SK/apon)" = 0 ] && [ "$(cat $SK/pbk/wifi_ap_on.orig)" = 1 ] && ! apput && grep -q "NX4 KOR 업데이트: 이전 판 정리" $SK/pout'
apreset; mkdir -p $SK/pbk; echo 1 > $SK/pbk/wifi_ap_on.orig; echo 0 > $SK/apon; mv $SK/bin/settings $SK/settings.off; mv $T/bin/settings $T/settings.off; skpu
mv $SK/settings.off $SK/bin/settings; mv $T/settings.off $T/bin/settings
check "  삭제: settings 명령이 없으면 로그 한 줄과 삭제 출력 안내, 삭제는 끝까지 진행" 'grep -q "되돌리기 건너뜀: settings 명령 없음" $SK/pout && grep -q "저장값(wifi_ap_on)을 되돌리지 못했습니다" $SK/pout && grep -q "NX4 KOR를 지웠습니다" $SK/pout && [ "$(cat $SK/apon)" = 0 ]'
apreset; mkdir -p $SK/pbk; echo 1 > $SK/pbk/wifi_ap_on.orig; rm -f $SK/apon; skpu
check "  삭제: 값을 읽지 못하면(null) 되돌리지 않고 안내" '! apput && grep -q "되돌리기 건너뜀: 값을 읽지 못함" $SK/pout && grep -q "되돌리지 못했습니다" $SK/pout'
cp $SK/settings.keep $SK/bin/settings; rm -f $SK/apon $SK/apon.ro
# 차의 셸(ksh 계열)로도 순정 AP 경로를 돌린다(read·$!·함수 바꾸기가 sh와 같은지)
for SKSH in $KSHS; do
  skreset; stockps > $SK/ps; : > $SK/ps.2; stockps > $SK/ps.4; skrun SKW=8
  check "1.6.2 $(basename $SKSH): 순정 AP 준비됨·꺼짐·켜짐, 우리 것 없음" 'grep -q "순정 카플레이 AP 사용" $SK/out && grep -q "순정 카플레이 AP가 꺼짐" $SK/out && grep -q "순정 카플레이 AP가 켜짐$" $SK/out && grep -qx "state=done" $SK/prog && noours && grep -qx "rc=7" $SK/out'
done
SKSH=
check "1.6.2: hotspot.sh에 순정 판정·끝나는 조건이 있는 대기(60초, TERM)" 'grep -q "^stock_ap_mode() {" $T/app/svc/hotspot.sh && grep -q "^stock_ssid() {" $T/app/svc/hotspot.sh && grep -q "^our_dhcp_on() {" $T/app/svc/hotspot.sh'
# --- 자동 설정(setup_hmgapi)의 Wi-Fi 칩 깨우기: 무선 기능을 처음 적용하기 전에 칩이 보이는지 본다 ---
# (map 만들기·확인·적용의 갈래는 tests/mod-test.sh가 본다)
X=$T/as; rm -rf $X; mkdir -p $X/bin
cat > $X/bin/hmgapid <<E
#!/bin/sh
echo "hmgapid \$*" >> $X/calls
case "\$1 \$2" in
  "ping "*) [ -f $X/down ] && exit 1; exit 0 ;;
  "engine verify-map") [ -f $X/vm_fail ] && { echo "the map doesn't fit"; exit 1; }; echo "map checked"; exit 0 ;;
  "engine map-car") [ "\$3" = --forget ] && { rm -f $X/hd/state/local-map.json; exit 0; }
    mkdir -p $X/hd/state; echo '{"whole": true}' > $X/hd/state/local-map.json
    echo "written: /data/hmgapi/state/local-map.json (this car's own map, status probed): run hmgapid engine verify-map, then restart, for its hooks"; exit 0 ;;
  "engine plan") [ -f $X/plan_fail ] && { echo "error: engine is busy"; exit 3; }; cat $X/plan; exit 0 ;;
  "engine apply") [ -f $X/apply_fail ] && exit 1; [ -f $X/chip_drop ] && { rm -rf $X/sdio; mkdir -p $X/sdio; exit 1; }; exit 0 ;;
  "engine remove") rm -rf $X/hd/mods/\$3; exit 0 ;;
  "engine status") [ -f $X/status ] && { cat $X/status; exit 4; }; echo "HMG-API owns no files"; exit 0 ;;
esac
exit 0
E
chmod +x $X/bin/hmgapid
PLAN_OK='change   /system/onebin/nx4_kr/featurexml.cfg [nx4-kor] -> 2a7c   [restart the head unit]
setting  prop/persist.sys.iap2.wifi = t [nx4-kor]
hook plan: nx4-kor on'
asreset() { rm -rf $X/hd $X/bk $X/w $X/calls $X/vm_fail $X/apply_fail $X/down $T/notice; : > $X/calls; mkdir -p $X/hd/maps $X/hd/mods/nx4-kor $X/bk $X/w; echo '{"id": "nx4-kor"}' > $X/hd/mods/nx4-kor/mod.json; mkdir -p $X/hd/public; : > $X/hd/public/wifi-chip; printf '%s\n' "$PLAN_OK" > $X/plan; }
as() { (PATH=$X/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB=$T/bin/bb APP=$T/app W=$X/w BK=$X/bk HMGDATA=$X/hd SDIO=$X/nosdio sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$X'/bin:'$T'/bin:/usr/bin:/bin:/sbin; setup_hmgapi'); }
# Wi-Fi 칩 깨우기 (한국 펌웨어에는 Wi-Fi를 켜는 메뉴가 없어, 한 번도 안 켠 차는 칩이 SDIO에 안 보인다)
cat > $X/bin/svc <<E
#!/bin/sh
echo "svc \$*" >> $X/calls
[ "\$*" = "wifi enable" ] && [ -f $X/chip_ok ] && mkdir -p $X/sdio/mmc1:0001:1
[ "\$*" = "wifi enable" ] && [ -f $X/svc_hang ] && exec /bin/sleep 30
[ "\$*" = "wifi enable" ] && [ -f $X/svc_fail ] && exit 3
exit 0
E
chmod +x $X/bin/svc
aw() { (PATH=$X/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BOOT_ID=$X/bootid NOTICE=$X/notices BB=$T/bin/bb APP=$T/app W=$X/w BK=$X/bk HMGDATA=$X/hd SDIO=$X/sdio WAKE_MAX=100 sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$X'/bin:'$T'/bin:/usr/bin:/bin:/sbin; setup_hmgapi'); }
awreset() { asreset; rm -rf $X/sdio $X/chip_ok $X/chip_drop $X/notices; rm -f $X/hd/public/wifi-chip; mkdir -p $X/sdio; echo 0 > $X/bk/wifi_on; [ -f $X/bootid ] || echo b0 > $X/bootid; }
asreset; rm -f $X/notices; as > $X/out
check "Wi-Fi 칩 기록이 있으면 Wi-Fi를 건드리지 않음" '! grep -q "svc wifi" $X/calls && grep -q "engine apply" $X/calls && ! grep -q "Wi-Fi를 한 번 켭니다" $X/notices 2>/dev/null'
awreset; mkdir -p $X/sdio/mmc1:0001:1; aw > $X/out
check "  칩이 SDIO에 이미 보이면 Wi-Fi를 건드리지 않음" '! grep -q "svc wifi" $X/calls && grep -q "engine apply" $X/calls'
awreset; touch $X/chip_ok; aw > $X/out
check "칩이 안 보이면 미리 안내하고 Wi-Fi를 한 번 켜고, 칩이 나타나면 무선 기능 적용" 'grep -q "Wi-Fi를 한 번 켭니다" $X/notices && grep -qx "svc wifi enable" $X/calls && grep -q "engine apply" $X/calls && grep -q "칩이 나타남" $X/out && [ ! -f $X/bk/wifi.nochip ] && ! grep -q "svc wifi disable" $X/calls'
check "  깨우기는 무선 기능 적용보다 먼저" '[ "$(grep -n "svc wifi enable" $X/calls | cut -d: -f1)" -lt "$(grep -n "engine apply" $X/calls | cut -d: -f1)" ]'
awreset; touch $X/chip_ok $X/chip_drop; aw > $X/out; rm -f $X/calls $X/notices; : > $X/calls; aw > $X/out2
check "칩이 잠깐 보였다 사라져 설치가 실패해도 다음 부팅에 Wi-Fi를 다시 켜지 않음 (wifi.woke)" '[ -f $X/bk/wifi.woke ] && ! grep -q "svc wifi" $X/calls && ! grep -q "engine apply" $X/calls && [ ! -s $X/notices ]'
# 1.7.3(W-4·G-1): 순정 module_version이 3이 아닌데 칩이 안 보이면 굳히지 않고 부팅마다 한 번씩, 최대 3번 깨운다(부팅은 boot_id로 셈)
echo b1 > $X/bootid; awreset; aw > $X/out
check "1.7.3 W-4: 첫 부팅에 Wi-Fi를 켜도 칩이 안 나타나면 무선 기능 적용 안 함, 칩 없음으로 굳히지 않음(wifi.wake 1번째), 다음 부팅에 다시" '! grep -q "engine apply" $X/calls && [ ! -f $X/bk/wifi.nochip ] && [ ! -f $X/bk/wifi.nopart ] && [ "$(cat $X/bk/wifi.wake)" = "1 b1" ] && grep -q "다음 부팅에 다시 깨움(1/3" $X/out'
check "  1.7.1: 그때의 순정 Wi-Fi 기록을 nochip-wifi.txt에 남김(가림: MAC·SSID 없음)" 'grep -q "칩 깨우기 실패 기록" $X/w/nochip-wifi.txt && grep -q "## logcat" $X/w/nochip-wifi.txt && grep -q "SUP_DISCONNEC" $X/w/nochip-wifi.txt'
check "  설치 전에 Wi-Fi가 꺼져 있었으면 다시 끔" 'grep -qx "svc wifi disable" $X/calls'
rm -f $X/calls $X/notices; : > $X/calls; aw > $X/out
check "  같은 부팅에 서비스가 다시 돌면 다시 켜지 않음(알림도 없음)" '! grep -q "svc wifi" $X/calls && [ ! -s $X/notices ] && [ "$(cat $X/bk/wifi.wake)" = "1 b1" ]'
echo b2 > $X/bootid; rm -f $X/calls; : > $X/calls; aw > $X/out
check "  2번째 부팅: 다시 깨움(2/3), 아직 굳히지 않음" 'grep -qx "svc wifi enable" $X/calls && [ "$(cat $X/bk/wifi.wake)" = "2 b2" ] && [ ! -f $X/bk/wifi.nochip ]'
echo b3 > $X/bootid; rm -f $X/calls $X/notices; : > $X/calls; aw > $X/out
check "  3번째 부팅에도 안 나타나면 칩 실패로 끝냄(wifi.nochip), 칩 실패 문구로 알림" 'grep -qx "svc wifi enable" $X/calls && [ -f $X/bk/wifi.nochip ] && grep -q "이 차는 Wi-Fi 칩이 켜지지 않아 무선 카플레이를 쓸 수 없습니다." $X/notices && ! grep -q "engine apply" $X/calls'
echo b4 > $X/bootid; rm -f $X/calls $X/notices; : > $X/calls; aw > $X/out
check "  그 뒤 부팅: Wi-Fi를 다시 켜지 않고, 알림도 없음" '! grep -q "svc wifi" $X/calls && ! grep -q "engine apply" $X/calls && [ ! -s $X/notices ]'
mkdir -p $X/sdio/mmc1:0001:1; rm -f $X/calls; : > $X/calls; aw > $X/out
check "  그 뒤 칩이 보이게 되면(차주가 켬) 기록과 상관없이 무선 기능 적용" 'grep -q "engine apply" $X/calls && ! grep -q "svc wifi" $X/calls'
# 1.7.3(W-1): 순정 module_version 3이면 깨우지 않고 바로 부품 없음
printf '#!/bin/sh\necho "11-10 09:00:00.000 D/WifiHW   (  500): wifi_get_module_version: 3"\n' > $X/bin/logcat; chmod +x $X/bin/logcat
echo b1 > $X/bootid; awreset; aw > $X/out
check "1.7.3 W-1: 순정 module_version=3이면 Wi-Fi를 켜지 않고(USB·블루투스가 다시 시작되지 않게) 부품 없음(wifi.nopart)으로 끝냄, W-1·W-6 문구" '! grep -q "svc wifi" $X/calls && [ -f $X/bk/wifi.nopart ] && [ "$(cat $X/bk/wifi.modver)" = 3 ] && grep -q "이 차의 내비에는 Wi-Fi 부품이 없어 무선 카플레이를 쓸 수 없습니다." $X/notices && ! grep -q "engine apply" $X/calls'
check "  판정 근거를 nochip-wifi.txt(·\$BK 사본)에 남김" 'grep -q "부품 없음 판정" $X/w/nochip-wifi.txt && [ -s $X/bk/nochip-wifi.txt ]'
rm -f $X/bin/logcat
# 깨운 뒤 순정이 module_version 3을 남기면(드라이버를 올려 보고서야 알 수 있는 차) 그때 부품 없음
printf '#!/bin/sh\n[ -f %s/modver3 ] && echo "11-10 09:00:00.000 D/WifiHW   (  500): wifi_get_module_version: 3"\nexit 0\n' $X > $X/bin/logcat; chmod +x $X/bin/logcat
cat > $X/bin/svc <<E2
#!/bin/sh
echo "svc \$*" >> $X/calls
[ "\$*" = "wifi enable" ] && : > $X/modver3
exit 0
E2
chmod +x $X/bin/svc; awreset; rm -f $X/modver3; aw > $X/out
check "  깨운 뒤 module_version=3이 나오면 그때 부품 없음(한 번만 깨움)" '[ "$(grep -c "svc wifi enable" $X/calls)" = 1 ] && [ -f $X/bk/wifi.nopart ] && [ ! -f $X/bk/wifi.nochip ]'
rm -f $X/bin/logcat $X/modver3
# 1.7.4(P-1, #276 레이·#252 팰리세이드): module_version 3 줄이 깨우기 초반에만 logcat에 있다가 버퍼가 밀려 사라지는 차.
# 예전에는 대기(최대 60초)가 끝난 뒤에만 읽어 놓치고 다음 부팅에 또 깨웠다. 깨우기 반복 안에서 읽어 첫 깨우기에 부품 없음으로 끝낸다.
# 가짜 sleep이 네 번째 부르면 그 줄을 지운다(밀림: 리뷰 반영 뒤 3회차마다 읽으므로 반복 안의 3회차 읽기로만 잡을 수 있고 반복 뒤 읽기로는 못 잡음). 가짜 svc wifi enable이 줄을 만든다(뒤에서 돌아 sleep 0.2로 틈을 줌)
p1reset() { awreset; rm -f $X/mv3live $X/sleepn $X/mvval $X/lcn $X/p1hang; : > $X/calls; }
printf '#!/bin/sh\necho x >> %s/lcn\n[ -f %s/mv3live ] && echo "11-14 09:00:00.000 D/WifiHW   (  500): wifi_get_module_version: $(cat %s/mvval 2>/dev/null || echo 3)"\nexit 0\n' $X $X $X > $X/bin/logcat; chmod +x $X/bin/logcat
# (깨우기 반복의 sleep 2만 센다: wifi_restore_off의 sleep 1은 세지 않음)
printf '#!/bin/sh\n/bin/sleep 0.2\n[ "$1" = 2 ] || exit 0\nn=$(( $(cat %s/sleepn 2>/dev/null || echo 0) + 1 )); echo $n > %s/sleepn\n[ $n -ge 4 ] && rm -f %s/mv3live\nexit 0\n' $X $X $X > $X/bin/sleep; chmod +x $X/bin/sleep
cat > $X/bin/svc <<E2
#!/bin/sh
echo "svc \$*" >> $X/calls
[ "\$*" = "wifi enable" ] && : > $X/mv3live
[ "\$*" = "wifi enable" ] && [ -f $X/chip_ok ] && mkdir -p $X/sdio/mmc1:0001:1
[ "\$*" = "wifi enable" ] && [ -f $X/p1hang ] && exec /bin/sleep 20
exit 0
E2
chmod +x $X/bin/svc
p1w() { (PATH=$X/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BOOT_ID=$X/bootid NOTICE=$X/notices BB=$T/bin/bb W=$X/w BK=$X/bk HMGDATA=$X/hd SDIO=$X/sdio WAKE_MAX=8 sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$X'/bin:'$T'/bin:/usr/bin:/bin:/sbin; wake_wifi; echo "rc=$?"'); }
echo p1a > $X/bootid; p1reset; p1w > $X/out
check "1.7.4 P-1: module_version 3 줄이 깨우기 초반에만 있다가 사라져도 첫 깨우기에 부품 없음(rc 1, wifi.nopart·wifi.modver 3, 근거 \$BK 사본, 깨우기 1번, 남은 대기 그만둠)" 'grep -qx "rc=1" $X/out && [ -f $X/bk/wifi.nopart ] && [ ! -f $X/bk/wifi.nochip ] && [ "$(cat $X/bk/wifi.modver)" = 3 ] && [ -s $X/bk/nochip-wifi.txt ] && [ "$(grep -c "^svc wifi enable" $X/calls)" = 1 ] && [ "$(cat $X/sleepn)" = 3 ] && grep -q "깨우는 중 순정 module_version=3" $X/out'
check "  P-1: 부품 없음으로 끝낼 때도 꺼져 있던 Wi-Fi를 다시 끔(예전 갈래와 같음)" 'grep -qx "svc wifi disable" $X/calls'
echo p1b > $X/bootid; rm -f $X/calls $X/sleepn; : > $X/calls; p1w > $X/out2
check "  P-1: 다음 부팅에는 깨우지 않음(부품 없음 기록)" 'grep -qx "rc=1" $X/out2 && ! grep -q "svc wifi enable" $X/calls'
echo p1c > $X/bootid; p1reset; echo 1 > $X/mvval; p1w > $X/out
check "  P-1: 깨우는 중 값이 3이 아니면(1) 예전과 같음: 대기를 다 하고 다음 부팅에 다시(rc 3, 1/3), 부품 없음 아님" 'grep -qx "rc=3" $X/out && [ ! -f $X/bk/wifi.nopart ] && [ "$(cat $X/bk/wifi.wake)" = "1 p1c" ] && [ "$(cat $X/sleepn)" = 8 ]'
# 리뷰 반영: logcat 전체 읽기는 3회차마다 + 반복 뒤 한 번(8회차면 module_version 읽기 2+1=3번, 8/3+1 이하). 그 밖에 깨우기 전 확인 1번과
# 근거 기록(wifi_record)의 2번이 있어 모두 6번 이하(매 회차 읽던 판은 8+1+1+2=12번)
check "  P-1 리뷰: 대기 8회차·값 1에서 logcat을 부른 횟수가 6번 이하(3회차마다 + 반복 뒤 + 깨우기 전 1·근거 기록 2)" '[ "$(wc -l < $X/lcn | tr -d " ")" -le 6 ]'
echo p1d > $X/bootid; p1reset; printf '#!/bin/sh\necho x >> %s/lcn\nexit 0\n' $X > $X/bin/logcat; chmod +x $X/bin/logcat; p1w > $X/out
check "  P-1: module_version 줄이 없으면 예전과 같음(rc 3, 대기를 다 함), logcat 6번 이하" 'grep -qx "rc=3" $X/out && [ ! -f $X/bk/wifi.nopart ] && [ "$(cat $X/sleepn)" = 8 ] && [ "$(wc -l < $X/lcn | tr -d " ")" -le 6 ]'
printf '#!/bin/sh\n[ -f %s/mv3live ] && echo "11-14 09:00:00.000 D/WifiHW   (  500): wifi_get_module_version: 3"\nexit 0\n' $X > $X/bin/logcat; chmod +x $X/bin/logcat
echo p1e > $X/bootid; p1reset; touch $X/chip_ok; p1w > $X/out
check "  P-1: module_version이 3이어도 칩이 나타나면 칩 쪽이 이김(rc 0, wifi.woke, 부품 없음 아님)" 'grep -qx "rc=0" $X/out && [ -f $X/bk/wifi.woke ] && [ ! -f $X/bk/wifi.nopart ]'
# 리뷰 낮음 3: svc wifi enable이 아직 돌 때 3을 봐서 일찍 끝내면 "끝나지 않아 멈춤"이 아니라 일찍 끝냈다고 남김
printf '#!/bin/sh\necho x >> %s/lcn\n[ -f %s/mv3live ] && echo "11-14 09:00:00.000 D/WifiHW   (  500): wifi_get_module_version: 3"\nexit 0\n' $X $X > $X/bin/logcat; chmod +x $X/bin/logcat
rm -rf $X/sdio/mmc1:0001:1; echo p1f > $X/bootid; p1reset; touch $X/p1hang; p1w > $X/out; rm -f $X/p1hang
check "  P-1 리뷰 낮음 3: 일찍 끝낼 때 svc를 멈춘 줄은 '기다리지 않고 멈춤(순정 module_version=3…)', '끝나지 않아 멈춤' 없음, 결과는 부품 없음" 'grep -q "svc wifi enable을 기다리지 않고 멈춤(순정 module_version=3을 봐서 일찍 끝냄)" $X/out && ! grep -q "끝나지 않아 멈춤" $X/out && grep -qx "rc=1" $X/out && [ -f $X/bk/wifi.nopart ]'
rm -f $X/bin/logcat $X/bin/sleep $X/mv3live $X/sleepn $X/mvval $X/chip_ok $X/lcn; rm -rf $X/sdio/mmc1:0001:1; echo b5 > $X/bootid
# 가짜 svc를 원래대로(칩 나타남·멈춤·실패 흉내)
cat > $X/bin/svc <<E2
#!/bin/sh
echo "svc \$*" >> $X/calls
[ "\$*" = "wifi enable" ] && [ -f $X/chip_ok ] && mkdir -p $X/sdio/mmc1:0001:1
[ "\$*" = "wifi enable" ] && [ -f $X/svc_hang ] && exec /bin/sleep 30
[ "\$*" = "wifi enable" ] && [ -f $X/svc_fail ] && exit 3
exit 0
E2
chmod +x $X/bin/svc
awreset; echo 1 > $X/bk/wifi_on; aw > $X/out
check "  설치 전에 Wi-Fi가 켜져 있었으면 끄지 않음" '! grep -q "svc wifi disable" $X/calls'
awreset; echo null > $X/bk/wifi_on; aw > $X/out
check "  설치 전 값이 null(한 번도 안 켬)이면 꺼져 있던 것으로 보고 끔" 'grep -qx "svc wifi disable" $X/calls'
awreset; rm -f $X/bk/wifi_on; aw > $X/out
check "  설치 전 기록이 없으면 끄지 않음" '! grep -q "svc wifi disable" $X/calls'
awreset; touch $T/nowififeat $X/chip_ok; aw > $X/out; rm -f $T/nowififeat
check "Android Wi-Fi 기능이 목록에 없어도(니로처럼) Wi-Fi를 켜서 칩을 깨움" 'grep -qx "svc wifi enable" $X/calls && grep -q "engine apply" $X/calls'
awreset; touch $X/svc_fail; aw > $X/out; rm -f $X/svc_fail
check "  svc wifi enable이 실패하면 종료 코드를 기록하고, 1.7.3: 다음 부팅에 다시(굳히지 않음)" 'grep -q "svc wifi enable 실패 (종료 코드 3)" $X/out && [ ! -f $X/bk/wifi.nochip ] && [ -f $X/bk/wifi.wake ] && ! grep -q "engine apply" $X/calls'
awreset; touch $X/svc_hang; aw > $X/out; rm -f $X/svc_hang
check "  svc wifi enable이 끝나지 않으면 대기 시간 뒤 멈추고 끝냄(다음 부팅에 다시)" 'grep -q "끝나지 않아 멈춤" $X/out && [ ! -f $X/bk/wifi.nochip ] && [ -f $X/bk/wifi.wake ] && ! grep -q "engine apply" $X/calls'
# 리뷰 H-1: 칩이 보이면 부품 없음·칩 실패·깨우기 기록을 지움(근거 기록 nochip-wifi.txt는 둠)
awreset; : > $X/bk/wifi.nopart; : > $X/bk/wifi.nochip; echo "2 b0" > $X/bk/wifi.wake; echo "판정 근거: x" > $X/bk/nochip-wifi.txt; mkdir -p $X/sdio/mmc1:0001:1; aw > $X/out
check "1.7.3 리뷰 H-1: 칩이 보이면 wifi.nopart·wifi.nochip을 지우고 무선 기능 적용, 근거 기록은 남김, 재리뷰 중간 2: 깨우기 횟수(wifi.wake)는 남김" '[ ! -f $X/bk/wifi.nopart ] && [ ! -f $X/bk/wifi.nochip ] && [ "$(cat $X/bk/wifi.wake)" = "2 b0" ] && [ -s $X/bk/nochip-wifi.txt ] && grep -q "engine apply" $X/calls && ! grep -q "svc wifi" $X/calls'
# 리뷰 M-1: 깨우기 전에 끝나는 조건을 본다
echo b5 > $X/bootid; awreset; echo "3 b4" > $X/bk/wifi.wake; aw > $X/out
check "1.7.3 리뷰 M-1: 횟수를 다 쓴 기록(3, 지난 부팅)이면 깨우지 않고 칩 실패로 끝냄(지난 깨우기 중 서비스가 멈춘 경우), 재리뷰 L-1: 꺼져 있던 Wi-Fi는 다시 끔" '! grep -q "svc wifi enable" $X/calls && grep -qx "svc wifi disable" $X/calls && [ -f $X/bk/wifi.nochip ]'
awreset; echo "x b4" > $X/bk/wifi.wake; aw > $X/out
check "  기록이 깨졌으면 깨우지 않음(안전 쪽), 재리뷰 L-1: 칩 실패로 굳히지도 않음" '! grep -q "svc wifi" $X/calls && [ ! -f $X/bk/wifi.nochip ] && grep -q "횟수 기록을 읽지 못해" $X/out'
awreset; mv $X/bootid $X/bootid.keep; aw > $X/out; mv $X/bootid.keep $X/bootid
check "  부팅 id를 못 읽으면 이번에는 깨우지 않음(부팅을 셀 수 없음), 칩 없음으로 굳히지도 않음" '! grep -q "svc wifi" $X/calls && [ ! -f $X/bk/wifi.nochip ] && grep -q "부팅 id를 읽지 못해" $X/out'
awreset; mkdir -p $X/bk/wifi.wake; aw > $X/out; rmdir $X/bk/wifi.wake
check "  깨우기 횟수를 기록하지 못하면 깨우지 않음" '! grep -q "svc wifi" $X/calls && grep -q "횟수를 기록하지 못해" $X/out'
# 재리뷰 중간 2: 칩이 보였다 안 보였다 하는 차(#52·#55 계열)에서도 깨우기는 모두 합쳐 3번까지(칩이 보이는 부팅에 횟수를 지우지 않음)
ww() { (PATH=$X/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BOOT_ID=$X/bootid NOTICE=$X/notices BB=$T/bin/bb W=$X/w BK=$X/bk HMGDATA=$X/hd SDIO=$X/sdio WAKE_MAX=3 sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$X'/bin:'$T'/bin:/usr/bin:/bin:/sbin; wake_wifi; echo "rc=$?"'); }
awreset; rm -f $X/calls; : > $X/calls
for b in 1 2 3 4 5 6 7 8; do
  echo "alt$b" > $X/bootid
  if [ $((b % 2)) = 1 ]; then mkdir -p $X/sdio/mmc1:0001:1; else rm -rf $X/sdio/mmc1:0001:1; fi
  ww >> $X/alt.out
done
check "1.7.3 재리뷰 중간 2: 칩이 보이는 부팅과 안 보이는 부팅이 8번 번갈아도 Wi-Fi 깨우기는 모두 3번, 그 뒤 칩 실패" '[ "$(grep -c "^svc wifi enable" $X/calls)" = 3 ] && [ -f $X/bk/wifi.nochip ] && [ "$(cut -d" " -f1 $X/bk/wifi.wake)" = 3 ]'
rm -f $X/alt.out; rm -rf $X/sdio/mmc1:0001:1
# 재리뷰 중간 4: 칩을 본 적 있는 차(wifi.woke)는 module_version 3이어도 부품 없음으로 굳히지 않음
printf '#!/bin/sh\necho "11-10 09:00:00.000 D/WifiHW   (  500): wifi_get_module_version: 3"\n' > $X/bin/logcat; chmod +x $X/bin/logcat
awreset; : > $X/bk/wifi.woke; ww > $X/out
check "1.7.3 재리뷰 중간 4: 칩을 본 적 있는 차(wifi.woke)는 module_version=3이어도 wifi.nopart를 쓰지 않음(깨우지도 않음)" '[ ! -f $X/bk/wifi.nopart ] && grep -qx "rc=2" $X/out && ! grep -q "svc wifi enable" $X/calls 2>/dev/null'
rm -f $X/bin/logcat
# 재리뷰 L-2: 1.7.0 근거 없던 칩 없음 차(다시 확인)도 새 근거 module_version이 3이 아니면 횟수를 남기고 다음 부팅에 다시
printf '#!/bin/sh\necho "11-10 09:00:00.000 D/WifiHW   (  500): wifi_get_module_version: 1"\n' > $X/bin/logcat; chmod +x $X/bin/logcat
echo r1 > $X/bootid; awreset; : > $X/bk/wifi.nochip; ww > $X/out
check "1.7.3 재리뷰 L-2: 근거 없던 칩 없음 기록 + 다시 확인에서 module_version=1 → 칩 없음 기록을 지우고 다음 부팅에 다시(rc 3, 1/3)" 'grep -qx "rc=3" $X/out && [ ! -f $X/bk/wifi.nochip ] && [ "$(cat $X/bk/wifi.wake)" = "1 r1" ] && [ -f $X/bk/nochip.rechk ]'
rm -f $X/bin/logcat; echo b5 > $X/bootid
check "  재리뷰 L-8: 설치 전 꺼져 있던 Wi-Fi 끄기(svc wifi disable)는 뒤에서 돌리고 회차 상한으로 기다림(소스)" 'awk "/^wifi_restore_off\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "( svc wifi disable >/dev/null 2>&1; echo \$? > \$W/svcoff.rc ) &" && ! grep -q "wifi_was_off && svc wifi disable" $PKG/svc/hotspot.sh'
# 1.7.4(L-2a): legacy_nochip_retry를 지웠다(옛 D-9 시험 5개는 tests/legacy/removed-1.7.4.md). 1.7.2가 남긴 wifi.nochip(wifi.wake 없음)은
# 다시 깨우지 않고 칩 실패 그대로(rc 2). 무선 모드를 넣지 않으므로 유선 카플레이는 그대로다(둘 다 안 되는 상태가 생기지 않음)
awreset; : > $X/bk/wifi.nochip; : > $X/bk/wifi.woke; echo "판정 근거: 순정 module_version=1 (3이면 …)" > $X/bk/nochip-wifi.txt; ww > $X/out
check "1.7.4 L-2a: 1.7.2가 남긴 wifi.nochip(wifi.wake 없음, 근거 1)은 다시 깨우지 않고 칩 실패 그대로(rc 2), 기록을 바꾸지 않음" 'grep -qx "rc=2" $X/out && ! grep -q "svc wifi" $X/calls 2>/dev/null && [ -f $X/bk/wifi.nochip ] && [ ! -f $X/bk/wifi.wake ] && [ ! -f $X/bk/wifi.nopart ]'
awreset; : > $X/bk/wifi.nochip; : > $X/bk/wifi.woke; echo "판정 근거: 순정 module_version=1 (3이면 …)" > $X/bk/nochip-wifi.txt; aw > $X/out
check "  L-2a: 그 상태에서 서비스 설정은 무선 모드를 설치·적용하지 않고 Wi-Fi도 켜지 않음(유선 카플레이에 손대지 않음)" '! grep -q "engine apply\|engine apply\|svc wifi" $X/calls 2>/dev/null'
echo b1 > $X/bootid
awreset; touch $X/chip_ok $X/vm_fail; aw > $X/out
check "map 확인이 실패하면 Wi-Fi를 켜지 않음 (모드를 넣지 않을 때는 깨우지 않음)" '! grep -q "svc wifi" $X/calls'
# 1.7.2(P-12): 칩 없음으로 멈췄는데 근거 기록(nochip-wifi.txt)이 없는 차(#58)는 한 번만 다시 확인
awreset; : > $X/bk/wifi.nochip; : > $X/bk/wifi.woke; aw > $X/out
check "1.7.2 P-12: wifi.nochip인데 근거 기록이 없으면 한 번 다시 깨워 근거(판정 근거 module_version 줄)를 남김" 'grep -qx "svc wifi enable" $X/calls && [ -f $X/bk/nochip.rechk ] && [ -f $X/bk/wifi.nochip ] && grep -q "^판정 근거: 순정 module_version=" $X/w/nochip-wifi.txt && grep -q "한 번만 다시 확인" $X/out'
check "  리뷰 M-1: 근거 사본을 업데이트에도 남는 \$BK에도 둠" 'grep -q "^판정 근거: 순정 module_version=" $X/bk/nochip-wifi.txt'
rm -f $X/calls $X/w/nochip-wifi.txt; : > $X/calls; aw > $X/out
check "  두 번째부터는 다시 깨우지 않음(횟수 제한 nochip.rechk)" '! grep -q "svc wifi" $X/calls'
awreset; : > $X/bk/wifi.nochip; echo "판정 근거: x" > $X/w/nochip-wifi.txt; aw > $X/out
check "  근거 기록이 이미 있으면 다시 깨우지 않음" '! grep -q "svc wifi" $X/calls && [ ! -f $X/bk/nochip.rechk ]'
awreset; : > $X/bk/wifi.nochip; echo "판정 근거: x" > $X/bk/nochip-wifi.txt; aw > $X/out
check "  리뷰 M-1: 업데이트로 \$W 기록이 지워져도 \$BK 사본이 있으면 다시 깨우지 않음" '! grep -q "svc wifi" $X/calls && [ ! -f $X/bk/nochip.rechk ]'
awreset; : > $X/bk/wifi.nochip; touch $X/chip_ok; aw > $X/out
check "  다시 확인에서 칩이 나타나면 칩 없음 기록을 지우고 무선 기능 적용를 이어 감" '[ ! -f $X/bk/wifi.nochip ] && grep -q "engine apply" $X/calls'
rm -f $X/bin/svc
# car_in: 차 목록 비교 (case 패턴은 변수로 '|'를 넘길 수 없어 목록을 하나씩 본다)
cin() { (HOTSPOT_LIB=1 BB=$T/bin/bb W=$X/w sh -c '. '$T'/app/svc/hotspot.sh; car_in "$1" "$CARS"' _ "$1"); }
cin() { (HOTSPOT_LIB=1 BB=$T/bin/bb sh -c '. '$T'/app/svc/hotspot.sh; car_in "$1" "$CARS"' x "$1"); }
check "car_in: 투싼 NX4·NX4 하이브리드 한국 260902만 맞음" 'cin NX4.KOR.0000.V039.001.260902 && cin NX4HEV.KOR.0000.V039.001.260902 && ! cin NX4.KOR.0000.V040.001.261101 && ! cin NX4.USA.0000.V039.001.260902 && ! cin DEPEHEV.KOR.0000.V039.001.260902 && ! cin ""'
rm -rf $X/cwd; mkdir -p $X/cwd; : > $X/cwd/NX4.KOR.x.260902
check "  현재 폴더에 패턴과 맞는 파일이 있어도 목록을 글자 그대로 비교" '(cd $X/cwd && cin NX4.KOR.0000.V039.001.260902)'

# --- 1.5.5: Wi-Fi 잠금 (설정 파일 root 소유 + crc32 치움, 니로에서 검증된 상태) ---
WF=$T/wf; mkdir -p $WF/bin
# svc wifi enable은 (설정 파일이 없으면) Wi-Fi 서비스처럼 system:wifi 소유 파일과 crc32를 만든다
cat > $WF/bin/svc <<E
#!/bin/sh
echo "svc \$*" >> $WF/calls
if [ "\$2" = enable ] && [ ! -f $WF/wifi/wpa_supplicant.conf ]; then
  echo "ctrl_interface=wlan0" > $WF/wifi/wpa_supplicant.conf; echo 1000:1010 > $WF/wifi/wpa_supplicant.conf.owner
  echo crc > $WF/wifi/wpa_supplicant_crc32.conf; echo 1000:1010 > $WF/wifi/wpa_supplicant_crc32.conf.owner
fi
E
printf '#!/bin/sh\necho "killall $*" >> %s/calls\n' $WF > $WF/bin/killall
printf '#!/bin/sh\ncat %s/ps 2>/dev/null\n' $WF > $WF/bin/ps
cat > $WF/bin/chown <<E
#!/bin/sh
echo "chown \$*" >> $WF/calls
echo "\$1" > "\$2.owner"
E
cat > $WF/bin/ls <<E
#!/bin/sh
if [ "\$1" = -ln ]; then
  case "\$2" in $WF/*)
    [ -e "\$2" ] || exit 1
    o=\$(cat "\$2.owner" 2>/dev/null || echo 0:0); echo "-rw-rw----    1 \${o%%:*}        \${o#*:}              88 Nov  2 17:25 \$2"; exit 0 ;;
  esac
fi
exec /bin/ls "\$@"
E
chmod +x $WF/bin/*
WC=$WF/wifi/wpa_supplicant.conf; WR=$WF/wifi/wpa_supplicant_crc32.conf
wfreset() { rm -rf $WF/calls $WF/notices $WF/bk $WF/w $WF/wlan0 $WF/out $WF/ps $WF/wifi $WF/prog; mkdir -p $WF/bk $WF/w $WF/wifi $WF/wlan0; }
wfsys() { echo "ctrl_interface=wlan0" > $WC; echo 1000:1010 > $WC.owner; echo crc > $WR; echo 1000:1010 > $WR.owner; }
wf() { (PATH=$WF/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 NOTICE=$WF/notices BB=$T/bin/bb W=$WF/w BK=$WF/bk WLAN=$WF/wlan0 WCONF=$WC WIFI_WAIT=0 PROG=$WF/prog BOOT_ID=$WF/bootid sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$WF'/bin:'$T'/bin:/usr/bin:/bin:/sbin; sleep() { :; }; wait() { exit 7; }; '"$1") > $WF/out 2>&1; echo $? >> $WF/out; }
wfreset; wfsys; wf 'wifi_lock; echo rc=$?'
check "Wi-Fi 잠금: system:wifi 설정 파일을 root 소유(660)로, crc32 파일은 백업 뒤 치움, 원래 소유자 기록" '[ "$(cat $WC.owner)" = 0:0 ] && [ ! -e $WR ] && [ "$(cat $WF/bk/wpaconf.orig)" = "1000:1010 660" ] && [ "$(cat $WF/bk/wpacrc.bak)" = crc ] && grep -qx "rc=0" $WF/out && grep -q "Wi-Fi 잠금: 설정 파일을 root 소유로" $WF/out'
wfsys; wf 'wifi_lock; echo rc=$?'
check "  Wi-Fi 서비스가 파일을 새로 만들어도 다시 잠그고, 원래 기록은 덮어쓰지 않음" '[ "$(cat $WC.owner)" = 0:0 ] && [ ! -e $WR ] && [ "$(cat $WF/bk/wpaconf.orig)" = "1000:1010 660" ]'
wf 'wifi_lock; echo rc=$?'
check "  이미 잠겨 있으면 아무것도 하지 않음(로그 없음)" 'grep -qx "rc=0" $WF/out && ! grep -q "Wi-Fi 잠금" $WF/out'
wfreset; wf 'wifi_lock; echo rc=$?'
check "  설정 파일이 아직 없으면 1(Wi-Fi 서비스가 처음 켤 때 만든다)" 'grep -qx "rc=1" $WF/out && [ ! -e $WF/bk/wpaconf.orig ]'
wfreset; wfsys; wf 'wifi_lock; wifi_unlock'
check "  되돌리기(preun): 원래 소유자(1000:1010)와 crc32 파일(내용·소유자)" '[ "$(cat $WC.owner)" = 1000:1010 ] && [ "$(cat $WR)" = crc ] && [ "$(cat $WR.owner)" = 1000:1010 ]'
wfreset; echo "  9 1010 wpa_supplicant -iwlan0" > $WF/ps; wf 'take_wlan0'
check "take_wlan0: 파일이 없던 차는 Wi-Fi를 켠 뒤 잠그고, wpa_supplicant를 한 번 멈춤(svc wifi disable 없음)" '[ "$(sed -n 1p $WF/calls)" = "svc wifi enable" ] && [ "$(cat $WC.owner)" = 0:0 ] && grep -qx "killall wpa_supplicant" $WF/calls && ! grep -q "svc wifi disable" $WF/calls'
wfreset; wfsys; wf 'take_wlan0'
check "  파일이 있던 차는 켜기 전에 잠금" '[ "$(sed -n 1p $WF/calls)" = "chown 0:0 $WC" ] && grep -qx "svc wifi enable" $WF/calls'
# 1.7.2(P-11): 같은 부팅에서 서비스만 다시 시작(SVC_FIRST=0) + wlan0 있음 + wpa_supplicant 없음 + wifi_on=1 → Wi-Fi 켜기·대기 건너뜀
wfreset; wfsys; : > $WF/ps; wf 'SVC_FIRST=0; take_wlan0'
check "1.7.2 P-11: 같은 부팅 다시 시작이고 드라이버(wlan0)가 있고 wpa_supplicant가 없으면 svc wifi enable·대기를 건너뜀(잠금은 함)" '! grep -q "svc wifi" $WF/calls && [ "$(cat $WC.owner)" = 0:0 ] && grep -q "Wi-Fi 켜기·대기를 건너뜀" $WF/out'
wfreset; wfsys; : > $WF/ps; wf 'SVC_FIRST=1; take_wlan0'
check "  부팅 뒤 첫 시작(또는 업데이트 뒤)은 예전처럼 켬" 'grep -qx "svc wifi enable" $WF/calls'
wfreset; wfsys; echo "  9 1010 wpa_supplicant -iwlan0" > $WF/ps; wf 'SVC_FIRST=0; take_wlan0'
check "  wpa_supplicant가 돌면 건너뛰지 않음" 'grep -qx "svc wifi enable" $WF/calls'
wfreset; wfsys; rm -rf "${WF:?}"/wlan0; : > $WF/ps; wf 'SVC_FIRST=0; take_wlan0'
check "  wlan0가 없으면 건너뛰지 않음" 'grep -qx "svc wifi enable" $WF/calls'
wfreset; : > $WF/ps; wf 'SVC_FIRST=0; take_wlan0'
check "  설정 파일이 아직 없으면(Wi-Fi 서비스가 만들어야 함) 건너뛰지 않음" 'grep -qx "svc wifi enable" $WF/calls'
wfreset; wfsys; echo "  9 1010 wpa_supplicant -iwlan0" > $WF/ps; wf 'ns=0; ap_tick; ap_tick; ap_tick; ap_tick; echo ns=$ns'
check "ap_tick: 잠금을 지키고, wpa_supplicant가 다시 뜨면 멈춤. SUPP_MAX번 넘게 이어지면 한 번만 알리고 계속(그만두지 않음)" '[ "$(cat $WC.owner)" = 0:0 ] && [ "$(grep -c "^killall wpa_supplicant" $WF/calls)" = 4 ] && grep -qx "ns=4" $WF/out && [ "$(grep -c "자꾸 끊깁니다" $WF/notices)" = 1 ] && [ -f $WF/bk/wifilock.told ] && [ "$(tail -1 $WF/out)" = 0 ]'
: > $WF/ps; wf 'ns=3; ap_tick; echo ns=$ns'
check "  wpa_supplicant가 없으면 0부터 다시 셈" 'grep -qx "ns=0" $WF/out'
# 4b K-4: 되풀이되는 줄은 이번 실행에서 3번까지 + "더 남기지 않음" 한 줄. 멈추기·다시 켜기 동작은 그대로
wfreset; wfsys; echo "  9 1010 wpa_supplicant -iwlan0" > $WF/ps; wf 'ns=0; ap_tick; ap_tick; ap_tick; ap_tick; ap_tick; ap_tick; echo ns=$ns'
check "  4b K-4: wpa_supplicant 6번 다시 뜸 → '다시 켜져서 멈춤' 3줄 + '더 남기지 않음' 1줄, 멈추기(killall)는 6번 그대로" '[ "$(grep -c "wpa_supplicant가 다시 켜져서 멈춤" $WF/out)" = 3 ] && [ "$(grep -c "wpa_supplicant가 자꾸 다시 켜짐: 이번 실행에서는 이 기록을 더 남기지 않음" $WF/out)" = 1 ] && [ "$(grep -c "^killall wpa_supplicant" $WF/calls)" = 6 ] && grep -qx "ns=6" $WF/out'
for _p in hostapd dnsmasq; do printf '#!/bin/sh\necho "%s $*" >> %s/calls\n' $_p $WF > $WF/bin/$_p; chmod +x $WF/bin/$_p; done
wfreset; wfsys; : > $WF/ps; wf "CONF=$WF/hk.conf; echo channel=149 > \$CONF; up; up; up; up; up; echo done"
# up은 hostapd를 뒤에서(&) 띄운다: 가짜 hostapd 5개가 기록을 남길 때까지 잠깐 기다린다(최대 약 3초)
_k=0; while [ "$(grep -c "^hostapd " $WF/calls 2>/dev/null)" != 5 ] && [ $_k -lt 30 ]; do /bin/sleep 0.1; _k=$((_k+1)); done
rm -f $WF/bin/hostapd $WF/bin/dnsmasq
check "  4b K-4: hostapd가 5번 바로 꺼짐 → '시작'·'4초 안에 꺼짐' 각 3줄 + '더 남기지 않음' 각 1줄" '[ "$(grep -c "hostapd 시작$" $WF/out)" = 3 ] && [ "$(grep -c "hostapd가 4초 안에 꺼짐(5GHz 149번" $WF/out)" = 3 ] && [ "$(grep -c "hostapd를 자꾸 다시 켬: 이번 실행에서는 이 기록을 더 남기지 않음" $WF/out)" = 1 ] && [ "$(grep -c "hostapd가 자꾸 4초 안에 꺼짐: 이번 실행에서는 이 기록을 더 남기지 않음" $WF/out)" = 1 ] && grep -qx done $WF/out'
check "  4b K-4: 기록을 줄여도 다시 시도는 그대로(up 5번 모두 hostapd를 띄움)" '[ "$(grep -c "^hostapd " $WF/calls)" = 5 ]'
check "  4b K-4: 제한은 log_cap 한 곳(4곳에서 씀, 묶음 H 최종의 dnsmasq 예전 방식으로 내림 포함)" '[ "$(grep -c "log_cap [A-Z_]* " $PKG/svc/hotspot.sh)" = 4 ] && grep -q "^log_cap() {" $PKG/svc/hotspot.sh'
# 4b 리뷰 M-1: 제한은 **이어진 실패**에만. 정상 다시 시작은 늘 남기고, 성공하면(hostapd가 살아 있음·wpa_supplicant 없음) 다시 센다
printf '#!/bin/sh\necho "hostapd $*" >> %s/calls\n[ -f %s/hok ] && echo "  1 root 0 S hostapd $*" > %s/ps\nexit 0\n' $WF $WF $WF > $WF/bin/hostapd
printf '#!/bin/sh\necho "dnsmasq $*" >> %s/calls\n' $WF > $WF/bin/dnsmasq; chmod +x $WF/bin/hostapd $WF/bin/dnsmasq
# 가짜 hostapd는 뒤에서(&) 돌며 ps를 쓴다: up 안의 4초 대기는 켜질 차례(hok)면 ps가 써질 때까지(최대 약 4초), 아니면 바로 넘어감
wfreset; wfsys; : > $WF/hok; wf "CONF=$WF/hk.conf; echo channel=149 > \$CONF; sleep() { if [ -f $WF/hok ]; then _w=0; while [ ! -s $WF/ps ] && [ \$_w -lt 40 ]; do /bin/sleep 0.1; _w=\$((_w+1)); done; fi; }; for k in 1 2 3 4 5; do : > $WF/ps; up; done; echo done"
check "  4b 리뷰 M-1: 정상 다시 시작 5번 → 'hostapd 시작' 5줄 모두 남음, hostapd '자꾸'·'꺼짐' 줄 없음(dnsmasq 가짜는 늘 꺼져 있어 그쪽 제한 줄은 따로)" '[ "$(grep -c "hostapd 시작$" $WF/out)" = 5 ] && ! grep -q "hostapd를 자꾸\|hostapd가 자꾸\|4초 안에 꺼짐" $WF/out && grep -qx done $WF/out'
wfreset; wfsys; rm -f $WF/hok; wf "CONF=$WF/hk.conf; echo channel=149 > \$CONF; sleep() { if [ -f $WF/hok ]; then _w=0; while [ ! -s $WF/ps ] && [ \$_w -lt 40 ]; do /bin/sleep 0.1; _w=\$((_w+1)); done; fi; }; for k in 1 2 3 4; do : > $WF/ps; up; done; : > $WF/hok; : > $WF/ps; up; rm -f $WF/hok; for k in 1 2; do : > $WF/ps; up; done; echo done"
check "  4b 리뷰 M-1: 실패 4번(3줄 + '더 남기지 않음') 뒤 한 번 성공하면 다시 셈(성공 줄 + 다음 실패 2번도 남음)" '[ "$(grep -c "hostapd 시작$" $WF/out)" = 6 ] && [ "$(grep -c "hostapd가 4초 안에 꺼짐(5GHz 149번" $WF/out)" = 5 ] && [ "$(grep -c "hostapd를 자꾸 다시 켬: 이번 실행에서는 이 기록을 더 남기지 않음" $WF/out)" = 1 ] && [ "$(grep -c "hostapd가 자꾸 4초 안에 꺼짐: 이번 실행에서는 이 기록을 더 남기지 않음" $WF/out)" = 1 ] && grep -qx done $WF/out'
rm -f $WF/bin/hostapd $WF/bin/dnsmasq $WF/hok
wfreset; wfsys; echo "  9 1010 wpa_supplicant -iwlan0" > $WF/ps; wf "ns=0; for k in 1 2 3 4; do ap_tick; done; : > $WF/ps; ap_tick; echo '  9 1010 wpa_supplicant -iwlan0' > $WF/ps; ap_tick; ap_tick; echo ns=\$ns"
check "  4b 리뷰 M-1: wpa_supplicant 4번(3줄 + 1줄) 뒤 없어지면 다시 셈(다음 2번도 남음), 멈추기는 6번 그대로" '[ "$(grep -c "wpa_supplicant가 다시 켜져서 멈춤" $WF/out)" = 5 ] && [ "$(grep -c "이 기록을 더 남기지 않음" $WF/out)" = 1 ] && [ "$(grep -c "^killall wpa_supplicant" $WF/calls)" = 6 ] && grep -qx "ns=2" $WF/out'
check "  4b 리뷰 L-5: 4초 안에 꺼짐 줄을 남기지 않을 때(4번째부터)는 채널을 읽는 awk를 띄우지 않음(소스)" 'grep -q "_hch=; \[ \${HA_DIES:-0} -lt 3 \] && _hch=" $PKG/svc/hotspot.sh'
echo boot-1 > $WF/bootid; wfreset; echo boot-1 > $WF/bootid; wf 'prog 40 run "map"; P_ON=0; ptrack 90 run "안 씀"'
check "진행 기록: pct·state·stage·boot를 644로 쓰고, P_ON=0이면 ptrack은 쓰지 않음" 'grep -qx "pct=40" $WF/prog && grep -qx "state=run" $WF/prog && grep -qx "stage=map" $WF/prog && grep -qx "boot=boot-1" $WF/prog && [ "$(stat -f %Lp $WF/prog)" = 644 ]'
wf 'prog 100 reboot "재부팅"; prog_final_this_boot && echo final=1; echo other > '$WF'/bootid; prog_final_this_boot || echo final=0'
check "  같은 부팅의 재부팅 필요·실패 기록은 '이미 끝남'으로 알아봄(다른 부팅 기록은 아님)" 'grep -qx "final=1" $WF/out && grep -qx "final=0" $WF/out'
echo boot-1 > $WF/bootid; wf 'prog 30 run "진행"; stop_all; cat '$WF'/prog'
check "  서비스가 설치 중에 멈추면 '중간에 멈춤' 실패로 남김" 'grep -qx "state=fail" $WF/prog && grep -q "중간에 멈췄습니다" $WF/prog'
wfreset; wfsys; echo bad > $WC.owner; wf 'wifi_lock; wifi_lock; wifi_lock; true'
check "  잠금 실패 로그는 부팅마다 한 번만" '[ "$(grep -c "Wi-Fi 잠금 실패" $WF/out)" = 1 ]'
check "차에 없는 printf를 busybox 없이 부르지 않음(awk 안의 printf \"%…와 주석 제외, 1.7.4 L-6: 은퇴 도구 두 개는 tests/legacy로, 디버그 로그 USB 때 USB 도구 usb-*/NEMESIS.sh도)" '[ -z "$(grep -n "printf " $PKG/svc/hotspot.sh $PKG/bin/status.sh $PKG/bin/carreport.sh $PKG/scripts/post.sh $PKG/scripts/preun.sh $B/usb-*/NEMESIS.sh | grep -v "BB printf" | grep -v "printf \"%" | grep -v -E "^[^:]+:[0-9]+:[[:space:]]*#")" ]'
check "서비스: 1.5.4의 'Wi-Fi 끄기' 방식은 없음(드라이버를 내려 #17에서 실패)" '! grep -q -e "svc wifi disable; _i" -e "give_up_ap" -e "WIFI_FW" $T/app/svc/hotspot.sh'
check "서비스: 트랩 뒤 대기는 sleep을 뒤에서 돌리고 wait (TERM에 바로 반응)" '! sed -n "/trap .stop_all/,\$p" $T/app/svc/hotspot.sh | grep -q "do sleep 3600; done"'

# preun(삭제 전 정리): HMG-API에서 이 모드를 빼고 적용, Wi-Fi 잠금·설치 전 Wi-Fi 값 되돌리기 (모드 빼기의 갈래는 tests/mod-test.sh도 본다)
PU=$T/pu; mkdir -p $PU/bk
sed -e "s#^BB=.*#BB=$T/bin/bb#" -e "s#^BK=.*#BK=$PU/bk#" -e "s#^APP=.*#APP=$T/app#" \
  -e "s#^HOTSPOT_LIB=1 [.] [$]APP/svc/hotspot.sh#&; export PATH=$X/bin:$T/bin:/usr/bin:/bin:/sbin#" \
  -e "s#^export PATH=.*#export PATH=$X/bin:$T/bin:/usr/bin:/bin:/sbin#" \
  -e "s#/data/local/tmp/nx4-kor-status#$PU/status#g" $T/app/scripts/preun.sh > $PU/preun.sh
pureset() { rm -rf $PU/bk $X/calls $T/notice $X/hd; : > $X/calls; mkdir -p $PU/bk $X/hd/mods/nx4-kor; echo '{"id": "nx4-kor"}' > $X/hd/mods/nx4-kor/mod.json; : > $X/hd/installed.txt; }
pu() { (${PUUPD:+env KP_UPDATE=1} env HMGDATA=$X/hd W=$PU/w sh $PU/preun.sh) > $PU/out 2>&1; }
pureset; printf '%s\n' "restore  /system/onebin/nx4_kr/featurexml.cfg (stock)" "setting  prop/persist.sys.iap2.wifi back to stock" > $X/plan; pu
check "삭제: HMG-API에서 이 모드를 remove → 계획이 되돌리기뿐 → 적용, 삭제 출력에 알림, 알림 기록도 지움" 'grep -qx "hmgapid engine remove nx4-kor" $X/calls && grep -qx "hmgapid engine apply" $X/calls && grep -q "NX4 KOR를 지웠습니다" $PU/out && [ ! -f $T/notice ]'
pureset; printf '%s\n' "restore  /system/x (stock)" "change   /system/app/Y.apk [other-mod] -> 1" > $X/plan; pu
check "  계획에 다른 변경이 있으면 지우기만 하고 적용은 앱에서 하라고 안내" 'grep -q "engine remove" $X/calls && ! grep -qx "hmgapid engine apply" $X/calls && grep -q "HMG-API 앱에서 변경 사항을 적용" $PU/out'
pureset; : > $PU/bk/automap.bad; PUUPD=1; pu; PUUPD=
check "업데이트(KP_UPDATE=1)는 모드를 지우지 않고 automap.bad를 남김" '! grep -q "engine remove" $X/calls && [ -f $PU/bk/automap.bad ] && grep -q "NX4 KOR 업데이트: 이전 판 정리" $PU/out'
pureset; : > $PU/bk/automap.bad; pu
check "  삭제하면 automap.bad도 지워짐(지운 뒤 다시 설치하면 다시 시도)" '[ ! -f $PU/bk/automap.bad ] && [ ! -d $PU/bk ]'
pureset; echo "1000:1010 660" > $PU/bk/wpaconf.orig; mkdir -p $PU/wifi; echo x > $PU/wifi/c.conf; echo 0:0 > $PU/wifi/c.conf.owner; rm -f $T/calls
cp $WF/bin/chown $X/bin/chown; (HMGDATA=$X/hd W=$PU/w WCONF=$PU/wifi/c.conf sh $PU/preun.sh) > $PU/out 2>&1; rm -f $X/bin/chown
check "삭제: Wi-Fi 잠금을 원래 소유자로 되돌림" '[ "$(cat $PU/wifi/c.conf.owner)" = 1000:1010 ] && grep -q "Wi-Fi 잠금 되돌림" $PU/out'
pureset; echo "1000:1010 660" > $PU/bk/wpaconf.orig; echo 0:0 > $PU/wifi/c.conf.owner
cp $WF/bin/chown $X/bin/chown; (env KP_UPDATE=1 HMGDATA=$X/hd W=$PU/w WCONF=$PU/wifi/c.conf sh $PU/preun.sh) > $PU/out 2>&1; rm -f $X/bin/chown
check "  업데이트(KP_UPDATE=1)는 잠금을 그대로 두고 기록도 남김" '[ "$(cat $PU/wifi/c.conf.owner)" = 0:0 ] && ! grep -q "잠금 되돌림" $PU/out && [ -f $PU/bk/wpaconf.orig ]'
pureset; echo null > $PU/bk/wifi_on; rm -f $T/calls; pu
check "삭제: 설치 전 Wi-Fi 값이 null(한 번도 안 켬)이면 Wi-Fi를 끔" 'grep -qx "svc wifi disable" $T/calls'
pureset; echo 1 > $PU/bk/wifi_on; rm -f $T/calls; pu
check "  설치 전에 켜져 있었으면 끄지 않음" '! grep -q "svc wifi disable" $T/calls 2>/dev/null'
pureset; rm -f $T/calls; pu
check "  설치 전 기록이 없으면 끄지 않음" '! grep -q "svc wifi disable" $T/calls 2>/dev/null'
printf '#!/bin/sh\necho "settings $*" >> %s/calls\ncat %s/wifiset\n' $T $X > $X/bin/settings; chmod +x $X/bin/settings
pureset; echo 1 > $PU/bk/wifi_on; echo 0 > $X/wifiset; rm -f $T/calls; pu
check "  설치 전에 켜져 있었는데 지금 wifi_on이 0이면(Wi-Fi 서비스 차) 값만 1로 되돌림" 'grep -qx "settings put global wifi_on 1" $T/calls && ! grep -q "svc wifi" $T/calls'
pureset; echo 1 > $PU/bk/wifi_on; echo 1 > $X/wifiset; rm -f $T/calls; pu
check "  지금도 1이면 건드리지 않음" '! grep -q "settings put" $T/calls 2>/dev/null'
pureset; echo null > $PU/bk/wifi_on; echo 0 > $X/wifiset; rm -f $T/calls; pu
check "  설치 전에 꺼져 있었으면 1로 바꾸지 않음" '! grep -q "settings put" $T/calls 2>/dev/null'
rm -f $X/bin/settings $X/wifiset
pureset; touch $X/down; pu; rm -f $X/down
check "  HMG-API 데몬이 응답하지 않으면 지우지 못하니 HMG-API 앱에서 지우라고 안내, 권한 파일 되돌리기 건너뜀" '! grep -q "engine remove" $X/calls && grep -q "HMG-API 앱에서 NX4 KOR를 지우고 변경 사항을 적용해 주세요" $PU/out && grep -q "되돌리기 건너뜀" $PU/out'
rm -f $T/notice

# --- 1c. 상태 화면 앱: Report(상태 파일 읽기·판정 문구·상태표·재부팅 요청) ---
if command -v javac >/dev/null 2>&1; then
  J=$T/java; mkdir -p $J
  if javac -nowarn -encoding UTF-8 -d $J $B/app/java/io/github/jayparklab/nx4kor/Report.java \
       $B/tests/ReportTest.java 2>$T/javac.err; then
    java -cp $J io.github.jayparklab.nx4kor.ReportTest > $T/java.out 2>&1
    jr=$?
    grep -E "^(ok|FAIL)" $T/java.out | sed 's/^/  [Java] /'
    check "Java 테스트 전부" '[ $jr -eq 0 ]'
  else
    cat $T/javac.err; check "Java 컴파일" 'false'
  fi
fi

# --- 1e. 디버그 로그: 잡음 줄 버리기, 연속 같은 줄 줄이기, 파이프를 멈추지 않고 밀어내기 ---
LG=$T/lg; mkdir -p $LG/bin $LG/w
cat > $LG/in.txt <<'E'
11-06 04:25:55.900 D/ClusterService(  705): updateTPCrossroadName()::crossroadname is TEST-RD
11-06 04:25:55.910 D/ClusterService(  705): getCANSTatus = true
11-06 04:25:55.920 I/TccCarPlay( 1087):  [TccCarPlay] TccCarPlay_iAPSendMessage() : data(0x5F862158) size(57)
11-06 04:25:55.930 I/TccCarPlay( 1087):  [TccCarPlayCBSession] iAPSendMessage Command Received
11-06 04:25:55.935 I/TccCarPlay( 1087):  [TccCarPlay] TccCarPlay_iAPSendMessage() : done with (0x00)
11-06 04:25:55.937 I/TccCarPlay( 1087):  [TccCarPlay] TccCarPlay_iAPSendMessage() : done with (0x01)
11-06 04:25:55.940 D/NavigationCluster( 1305): getCANStatus
11-06 04:25:55.945 D/NavigationCluster( 1305): updateTBTSubInfo() distance: 0.0 unit: 15
11-06 04:25:55.950 E/iAP2    ( 1085):  iAP2SessionPacketParseParamListNew(1221) (LocationInformationStart) invalid parameter =0
11-06 04:25:56.040 I/TccCarPlay( 1087):  [TccCarPlayAudioTinyALSA] TccCarPlayAudioTinyALSA_ThreadPlayback() : pcm_write failed retry(0)
11-06 04:25:56.050 I/TccCarPlay( 1087):  [TccCarPlayAudioTinyALSA] TccCarPlayAudioTinyALSA_ThreadPlayback() : pcm_write failed retry(0)
11-06 04:25:57.120 I/TccCarPlay( 1087):  [TccCarPlayAudioTinyALSA] TccCarPlayAudioTinyALSA_ThreadPlayback() : pcm_write failed retry(0)
11-06 04:25:57.200 I/OtherApp( 999): not ours
11-06 04:25:58.000 I/HMG-API ( 800): CarPlay: hud list type 72 next 0
E
cat $B/tests/kpmask-sample.txt >> $LG/in.txt
printf '#!/bin/sh\ncat %s/in.txt\n' $LG > $LG/bin/logcat
printf '#!/bin/sh\n[ "$1" = uniq ] && exit 1\nexec "$@"\n' > $LG/bin/bb-nouniq
chmod +x $LG/bin/*
lg() { (PATH=$LG/bin:/usr/bin:/bin HOTSPOT_LIB=1 BB=${1:-$T/bin/bb} W=$LG/w sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$LG'/bin:/usr/bin:/bin; logstart; wait'); }
rm -f $LG/w/*; lg
check "디버그 파일이 없으면 로그를 켜지 않음" '[ ! -f $LG/w/cp.log ] && [ ! -f $LG/w/log.pid ]'
: > $LG/w/debug; lg
check "잡음 줄(iAPSendMessage 확인 줄, getCANSTatus, getCANStatus, 교차로 이름)과 다른 태그는 버림" '! grep -q -E "Command Received|done with \(0x00\)|getCANSTatus|getCANStatus|crossroadname|OtherApp" $LG/w/cp.log'
check "  전송 실패(done with 0x01)는 남김" 'grep -q "done with (0x01)" $LG/w/cp.log'
check "  보낸 iAPSendMessage 줄(크기)은 남김 (위치 전송 확인용)" 'grep -q "iAPSendMessage() : data(0x5F862158) size(57)" $LG/w/cp.log'
check "  iAP2 태그(위치 요청)와 getCANStatus로 시작하지 않는 NavigationCluster 줄은 남김" 'grep -q "LocationInformationStart" $LG/w/cp.log && grep -q "updateTBTSubInfo" $LG/w/cp.log'
check "  HMG-API 줄은 남김" 'grep -q "hud list type 72" $LG/w/cp.log'
check "  1.7.0: 폰 프로젝션 줄(AAProjection·PhoneProjection)을 남기되 폰 이름·MAC·다른 IP는 가림" 'grep -q "isWifiApEnable = false, mode = 0" $LG/w/cp.log && grep -q "requestWLDeviceConnectStatusUpdate \[가림: 이름\]" $LG/w/cp.log && ! grep -q -E "홍길동|Fold7|Pixel7|GalaxyS24|MyPhone|MyNet|secret|AA:BB|10\.0\.0\.5" $LG/w/cp.log'
check "  연속된 pcm_write 3줄은 한 줄과 횟수 3으로" '[ $(grep -c pcm_write $LG/w/cp.log) -eq 1 ] && grep -q -E "^ *3 11-06 04:25:56.040 .*pcm_write" $LG/w/cp.log'
rm -f $LG/w/cp.log*; lg $LG/bin/bb-nouniq
check "uniq를 못 쓰면 줄이지 않고 그대로 남김(로그가 끊기지 않음)" '[ $(grep -c pcm_write $LG/w/cp.log) -eq 3 ] && ! grep -q getCANSTatus $LG/w/cp.log'
printf '#!/bin/sh\n[ "$1" = grep ] && [ "$2" = -E ] && case "$3" in *getCANSTatus*) exit 2;; esac\n[ "$1" = grep ] && [ "$2" = -v ] && case "$4" in *getCANSTatus*) exit 2;; esac\nexec "$@"\n' > $LG/bin/bb-badre; chmod +x $LG/bin/bb-badre
rm -f $LG/w/cp.log*; lg $LG/bin/bb-badre
check "DROP 정규식을 grep이 못 받으면 버리지 않고 그대로 남김(로그가 끊기지 않음)" 'grep -q "hud list type 72" $LG/w/cp.log && grep -q getCANSTatus $LG/w/cp.log'
lr() { (HOTSPOT_LIB=1 BB=$T/bin/bb W=$LG/w LOGMAX=100 sh -c '. '$T'/app/svc/hotspot.sh; logrotate'); }
rm -f $LG/w/cp.log*; /bin/sleep 30 >/dev/null 2>&1 & SP=$!; echo $SP > $LG/w/log.pid
printf '%0200d\n' 1 > $LG/w/cp.log; lr
check "LOGMAX를 넘으면 cp.log.1로 복사하고 cp.log를 비움" '[ -s $LG/w/cp.log.1 ] && [ ! -s $LG/w/cp.log ] && [ -f $LG/w/cp.log ]'
check "  밀어낼 때 로그 파이프를 멈추지 않음" 'kill -0 $SP 2>/dev/null && [ "$(cat $LG/w/log.pid)" = $SP ]'
echo small > $LG/w/cp.log; lr
check "  LOGMAX 아래면 그대로" '[ "$(cat $LG/w/cp.log)" = small ] && [ ! -f $LG/w/cp.log.2 ]'
for i in 2 3 4 5; do printf "%0200d\n" $i > $LG/w/cp.log; lr; done
check "  최대 4개(cp.log, .1~.3)만 남고 오래된 것부터 지워짐" '[ ! -f $LG/w/cp.log.4 ] && grep -q 5$ $LG/w/cp.log.1 && grep -q 3$ $LG/w/cp.log.3'
printf '#!/bin/sh\n[ "$1" = cp ] && { echo partial > "$4"; exit 1; }\nexec "$@"\n' > $LG/bin/bb-nocp; chmod +x $LG/bin/bb-nocp
printf '%0200d\n' 7 > $LG/w/cp.log; (HOTSPOT_LIB=1 BB=$LG/bin/bb-nocp W=$LG/w LOGMAX=100 sh -c '. '$T'/app/svc/hotspot.sh; logrotate')
check "  복사가 실패해도(공간 부족) cp.log를 비우고 반쯤 쓴 .1은 지움" '[ ! -s $LG/w/cp.log ] && [ ! -f $LG/w/cp.log.1 ]'
echo live > $LG/w/cp.log; exec 9>>$LG/w/cp.log; printf '%0200d\n' 8 >&9; lr; echo after >&9; exec 9>&-
check "  열린 채 이어 쓰는 중에 비워도(O_APPEND) 새 줄이 맨 앞부터 이어짐" '[ "$(cat $LG/w/cp.log)" = after ] && grep -q 8$ $LG/w/cp.log.1'
kill $SP 2>/dev/null; wait $SP 2>/dev/null; rm -f $LG/w/log.pid; printf '%0200d\n' 9 > $LG/w/cp.log; lr
check "  로그가 꺼져 있으면(log.pid 없음) 밀어내지 않음" 'grep -q 9$ $LG/w/cp.log'

# --- 1.7.4 Q-1: Wi-Fi 장치 이름을 WIF 한 곳으로. 고치기 전(코드의 $WIF를 wlan0으로 되돌리고 WIF 줄을 뺀 사본)과 고친 뒤가
# 같은 스텁 입력에서 hostapd 설정·up이 부르는 명령·ap.log 문구·Launch 상태 파일·리포트(시각 줄 제외)까지 바이트로 같아야 한다 ---
Q1=$T/q1; mkdir -p $Q1/bin $Q1/oldapp $Q1/wn $Q1/wo
cp -R $T/app/. $Q1/oldapp/
q1old() { sed -e '/^WIF=\${WIF:-wlan0}$/d' -e 's/\$WIF/wlan0/g' "$1"; }
q1old $T/app/svc/hotspot.sh > $Q1/oldapp/svc/hotspot.sh
q1old $T/stl.sh | sed "s#APP=\${APP:-[^}]*}#APP=$Q1/oldapp#" > $Q1/stl-old.sh
check "1.7.4 Q-1(기준: 지금 코드의 \$WIF를 wlan0으로 되돌린 사본, 1.7.3 전수 대조는 리뷰에서 따로 함): 되돌린 사본에는 \$WIF가 없고, 고친 판에는 WIF 줄이 hotspot.sh·status.sh에 하나씩" '! grep -q "\$WIF" $Q1/oldapp/svc/hotspot.sh $Q1/stl-old.sh && [ "$(grep -c "^WIF=\${WIF:-wlan0}$" $PKG/svc/hotspot.sh)" = 1 ] && [ "$(grep -c "^WIF=\${WIF:-wlan0}$" $PKG/bin/status.sh)" = 1 ]'
# 명령을 적어 두는 가짜(ifconfig는 조회 하나만 답함, hostapd·dnsmasq는 바로 끝남, ps는 빈 목록). up이 뒤에서 띄운 둘은 wait로 기다린다
printf '#!/bin/sh\necho "ifconfig $*" >> $Q1C\n[ "$#" = 1 ] && printf "%%s Link encap:Ethernet\\n  inet addr:192.168.43.1  Bcast:192.168.43.255  Mask:255.255.255.0\\n" "$1"\nexit 0\n' > $Q1/bin/ifconfig
printf '#!/bin/sh\necho "hostapd $*" >> $Q1C\n' > $Q1/bin/hostapd; printf '#!/bin/sh\necho "dnsmasq $*" >> $Q1C\n' > $Q1/bin/dnsmasq
printf '#!/bin/sh\n:\n' > $Q1/bin/ps; chmod +x $Q1/bin/*
q1lib() { (Q1C=$2/calls; export Q1C; HOTSPOT_LIB=1 BB=$T/bin/bb W=$2 BK=$2/bk CONF=$2/conf WLAN=$2/nowlan NOWLAN_LOG=$2/nowlan.txt BOOT_ID=$T/bootid sh -c '. '$1'; export PATH='$Q1'/bin:'$T'/bin:/usr/bin:/bin:/sbin; PS="$BB ps"; S2=CPssid1; S4=pass12345678; write_conf; up; wlan_has_ip && echo addr-ok; cp_ifs; wait' 2>/dev/null); }
q1lib $Q1/oldapp/svc/hotspot.sh $Q1/wo > $Q1/o.out; q1lib $T/app/svc/hotspot.sh $Q1/wn > $Q1/n.out
q1t() { sed -e 's/^[0-9][0-9]-[0-9][0-9] [0-9:]* //' -e 's/^부팅 직후([^)]*) //' "$1"; }
# 명령 기록: 작업 폴더 경로(wo·wn)는 W로 바꾸고, hostapd는 뒤에서 떠 순서가 흔들리므로 정렬해 비교한다
q1c() { sed "s#$Q1/w[on]/#W/#g" "$1" | sort; }
check "  Q-1: hostapd 설정·up이 부른 명령(ifconfig·hostapd·dnsmasq 인자)·ap.log 문구·주소 확인·셀 인터페이스가 \$WIF를 wlan0으로 되돌린 사본과 바이트까지 같음" 'cmp -s $Q1/wo/conf $Q1/wn/conf && [ "$(q1c $Q1/wo/calls)" = "$(q1c $Q1/wn/calls)" ] && [ "$(q1t $Q1/o.out)" = "$(q1t $Q1/n.out)" ] && grep -qx "interface=wlan0" $Q1/wn/conf && grep -q "^dnsmasq .*--interface=wlan0 " $Q1/wn/calls && grep -qx "ifconfig wlan0 192.168.43.1 netmask 255.255.255.0 up" $Q1/wn/calls'
mkdir -p $Q1/wx; (WIF=xx0; export WIF; q1lib $T/app/svc/hotspot.sh $Q1/wx) > $Q1/x.out
check "  Q-1: WIF=xx0이면 설정 interface=와 ifconfig·dnsmasq 인자가 xx0(문구 속 wlan0 글자는 그대로)" 'grep -qx "interface=xx0" $Q1/wx/conf && grep -qx "ifconfig xx0 192.168.43.1 netmask 255.255.255.0 up" $Q1/wx/calls && grep -q "^dnsmasq .*--interface=xx0 " $Q1/wx/calls && ! grep -q "wlan0" $Q1/wx/calls && grep -q "^xx0" $Q1/x.out'
# 상태 파일(키·판정)은 tests/mod-test.sh가 본다

# [지금 재부팅] 요청(status.sh --watch)은 tests/mod-test.sh가 본다

# ---- 1.6.0: busybox 고르기(내비의 것, 없으면 패키지에 함께 넣은 busybox 1.36.1) ----
BS=$T/bsel; mkdir -p $BS/sys $BS/own $BS/w
printf '#!/bin/sh\nexec "$@"\n' > $BS/sys/busybox; chmod 755 $BS/sys/busybox
printf '#!/bin/sh\nexec "$@"\n' > $BS/own/busybox; chmod 755 $BS/own/busybox
# 이 PC에서 실행되지 않는 busybox(예: noexec /data에 놓인 것)
printf '#!/bin/sh\nexit 126\n' > $BS/own/broken; chmod 755 $BS/own/broken
bsel() { (env HOTSPOT_LIB=1 W=$BS/w "$@" sh -c '. '$T'/app/svc/hotspot.sh; echo "BB=$BB"; echo "OK=$BB_OK"; echo "PS=$PS"'); }
printf '#!/bin/sh\n[ "$1" = true ] && { echo "true: applet not found" >&2; exit 127; }\nexec "$@"\n' > $BS/sys/notrue; chmod 755 $BS/sys/notrue
bsel BB= BB_SYS=$BS/sys/notrue BB_OWN=$BS/own/busybox > $BS/out
check "1.6.0: 내비 busybox는 실행 파일인지만 봄(true 명령이 없는 1.8.1이어도 그대로 씀, 확인된 차가 멈추지 않게)" 'grep -qx "BB=$BS/sys/notrue" $BS/out && grep -qx "OK=1" $BS/out'
bsel BB= BB_SYS=$BS/sys/busybox BB_OWN=$BS/own/busybox > $BS/out
check "  내비에 busybox가 있으면 그것을 쓰고 ps는 지금처럼(옵션 없음)" 'grep -qx "BB=$BS/sys/busybox" $BS/out && grep -qx "OK=1" $BS/out && grep -qx "PS=$BS/sys/busybox ps" $BS/out'
bsel BB= BB_SYS=$BS/none BB_OWN=$BS/own/busybox > $BS/out
check "  없으면 함께 넣은 busybox를 쓰고, ps는 상태 칸을 달라고 함(-o pid,stat,args)" 'grep -qx "BB=$BS/own/busybox" $BS/out && grep -qx "OK=1" $BS/out && grep -qx "PS=$BS/own/busybox ps -o pid,stat,args" $BS/out'
chmod 644 $BS/own/busybox; bsel BB= BB_SYS=$BS/none BB_OWN=$BS/own/busybox > $BS/out
check "  함께 넣은 busybox에 실행 권한이 없으면 755로 주고 씀" 'grep -qx "OK=1" $BS/out && [ "$(stat -f %Lp $BS/own/busybox)" = 755 ]'
bsel BB= BB_SYS=$BS/none BB_OWN=$BS/own/broken > $BS/out
check "  함께 넣은 busybox가 실행되지 않으면 쓸 수 없음(BB_OK=0 → busybox 없는 내비로 처리)" 'grep -qx "OK=0" $BS/out'
bsel BB= BB_SYS=$BS/none BB_OWN=$BS/none > $BS/out
check "  둘 다 없으면 쓸 수 없음" 'grep -qx "OK=0" $BS/out'
bsel BB=$BS/sys/busybox BB_SYS=$BS/none BB_OWN=$BS/own/busybox > $BS/out
check "  BB를 미리 정하면 그대로 씀(테스트·carreport 호출)" 'grep -qx "BB=$BS/sys/busybox" $BS/out && grep -qx "PS=$BS/sys/busybox ps" $BS/out'
(PATH=$NB/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB= BB_SYS=$BS/none BB_OWN=$BS/own/broken W=$NB/w2 BK=$NB/bk2 sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$NB'/bin:'$T'/bin:/usr/bin:/bin:/sbin; wait() { exit 7; }; main') > $BS/main.out 2>&1; echo $? >> $BS/main.out
check "  서비스: 쓸 수 있는 busybox가 없으면 지금처럼 로그만 남기고 대기" 'grep -q "busybox가 없음" $BS/main.out && [ "$(tail -1 $BS/main.out)" = 7 ]'
# ps -o pid,stat,args 형식(ARM 컨테이너에서 1.36.1로 본 모양): 좀비는 STAT Z, 이름은 [hostapd]
mv $T/ps $T/ps.keep 2>/dev/null
psx() { (PATH=$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB= BB_SYS=$BS/none BB_OWN=$T/bin/bb W=$BS/w sh -c '. '$T'/app/svc/hotspot.sh; export PATH='$T'/bin:/usr/bin:/bin:/sbin; '"$1"); }
printf '%s\n' "PID   STAT COMMAND" "  999997 Z    [hostapd]" "  999996 S    {busybox} grep hostapd" > $T/ps
check "  함께 넣은 busybox: 좀비 hostapd는 도는 것으로 보지 않음(running, stock_ap_on)" '! psx "running hostapd" && ! psx stock_ap_on'
printf '%s\n' "PID   STAT COMMAND" "  4321 S    hostapd /data/misc/wifi/hostapd-kp.conf" "  4322 S    dnsmasq --keep-in-foreground --no-resolv --no-poll --dhcp-authoritative --pid-file --interface=wlan0" "  4400 S    hostapd /data/misc/wifi/hostapd.conf" > $T/ps
check "  우리 hostapd는 도는 것으로, 순정 hostapd는 순정 핫스팟으로 봄" 'psx "running \"hostapd \$CONF\"" && psx stock_ap_on'
printf '#!/bin/sh\necho "kill $*" >> %s/kills\n' $BS > $BS/kill; chmod 755 $BS/kill; rm -f $BS/kills
psx 'kill() { echo "kill $*" >> '$BS'/kills; }; stop_ours'
check "  stop_ours는 우리 hostapd(PID 첫 칸)만 멈춤: 순정 hostapd가 돌 때 pid 파일 없는 dnsmasq는 순정 것일 수 있어 두기(1.6.2)" '[ "$(cat $BS/kills 2>/dev/null)" = "kill 4321" ]'
rm -f $T/ps; mv $T/ps.keep $T/ps 2>/dev/null
# post.sh·preun.sh·status.sh는 BB를 정하지 않고 hotspot.sh가 고르게 한다
check "  post.sh·preun.sh는 BB를 비워 두고 hotspot.sh를 ps보다 먼저 읽음(1.7.3 K-6: post.sh는 ps를 쓰지 않음)" 'grep -qx "BB=" $PKG/scripts/post.sh && grep -qx "BB=" $PKG/scripts/preun.sh && { ! grep -q "\$PS" $PKG/scripts/post.sh || [ "$(grep -n "hotspot.sh$" $PKG/scripts/post.sh | cut -d: -f1)" -lt "$(grep -n "\$PS" $PKG/scripts/post.sh | head -1 | cut -d: -f1)" ]; }'
check "  ps는 모두 \$PS로 부름(\$BB ps 직접 호출 없음)" '! grep -n -F "\$BB ps" $PKG/svc/hotspot.sh $PKG/bin/status.sh $PKG/scripts/post.sh $PKG/scripts/preun.sh | grep -v "then PS="'
check "  status.sh는 뒤에서 띄우는 감시자(--watch, 1.7.4 B-7 끝날 때 다시 띄움 포함)·--wait에 고른 BB를 넘김" '[ "$(grep -c "BB=\$BB .*setsid" $PKG/bin/status.sh)" = 3 ]'
# 1.6.2: busybox를 다시 함께 넣는다(1.5.6은 뺐다). vendor 사본과 같은 파일이고 실행 권한이 있다.
if [ -f $B/vendor/busybox/busybox ]; then
check "1.6.2: 패키지에 bin/busybox(755)가 있고 vendor 사본·README의 SHA-256과 같음" '[ -x $PKG/bin/busybox ] && [ "$(stat -f %Lp $PKG/bin/busybox)" = 755 ] && cmp -s $PKG/bin/busybox $B/vendor/busybox/busybox && grep -q "$(shasum -a 256 < $PKG/bin/busybox | cut -c1-64)" $B/vendor/busybox/README.md'
check "  vendor의 busybox는 ARM 32비트 정적 실행 파일(1.6.x 재개용)" 'file $B/vendor/busybox/busybox | grep -q "ELF 32-bit LSB executable, ARM.*statically linked"'
else
  echo "건너뜀: 함께 넣은 busybox 파일 확인 (공개 저장소에는 busybox 바이너리가 없음, 릴리스 zip에만)"
fi
bsel BB= BB_SYS=$BS/none BB_OWN=$T/app/bin/busybox > $BS/out
check "  내비에 busybox가 없고 패키지에도 없으면 BB_OK=0(서비스는 '지원 조사 중'으로 대기)" 'grep -qx "OK=0" $BS/out'
# 진짜 busybox 1.36.1(ARM)로 확인: Docker와 alpine:3.20 arm/v7 이미지가 이 PC에 있을 때만(없으면 건너뜀, 받지 않음)
# 디버그 로그 USB 작업 때: 이미지 조회가 가끔 "No such image"를 내므로, 안 되면 한 번 실행해 깨운다(받지 않음: --pull never)
if command -v docker >/dev/null 2>&1 && { docker image inspect --platform linux/arm/v7 alpine:3.20 >/dev/null 2>&1 || docker run --rm --pull never --platform linux/arm/v7 alpine:3.20 true >/dev/null 2>&1; }; then
  cat > $BS/real.sh <<'E'
B=/vb/busybox
mkdir -p /x; echo 'while :; do sleep 1; done' > /x/hostapd
$B sh /x/hostapd /data/misc/wifi/hostapd-kp.conf & hp=$!
$B sh /x/hostapd /data/misc/wifi/hostapd.conf & sp=$!
( $B sleep 0 & exec $B sleep 3 ) &
$B sleep 1
HOTSPOT_LIB=1 BB= BB_SYS=/nonexist BB_OWN=/vb/busybox APP=/app W=/tmp/w . /app/svc/hotspot.sh
echo "OK=$BB_OK"; echo "PS=$PS"
$PS | $B grep -q " Z " && echo zombie-seen
running "hostapd $CONF" && echo ours-running
stock_ap_on && echo stock-on
stop_ours; $B sleep 1
kill -0 $hp 2>/dev/null || echo ours-stopped
kill -0 $sp 2>/dev/null && echo stock-alive
kill $sp
printf '\000\005hi\377' > /tmp/b; set -- $(for _t in $($B od -b -v /tmp/b); do [ ${#_t} -eq 3 ] && echo $_t; done); echo "od=$*"
echo hi > /tmp/f; chmod 640 /tmp/f; echo "perm=$(f_perm /tmp/f) owner=$(f_owner /tmp/f)"
echo "md5=$(echo hi | $B md5sum)"
# 4b 리뷰 L-2: 진짜 busybox(printf·od)로 parse_conf·conf_auth가 1.7.2 원본과 같은가. 비교는 하위 셸에서(parse_conf가 B 등을 바꿈)
# 묶음 J: 1.7.4(B-6)부터 한글이 든 c01·c04는 1.7.2와 달라야 한다(PC 시험과 같은 기준). 나머지 9개는 같아야 한다.
# 실제 순정 꼴 견본 k1~k7까지 파일마다 결과의 md5를 내어 PC(가짜 busybox) 결과와 바이트까지 같은지 밖에서 대조한다(값 글자는 남기지 않음)
_pn=0; _pd=0; _pk=0
for f in /t/pk/c?? /t/pk/k?; do
  _pa=$(parse_conf $f; printf '%s|' "$NS" "$S1" "$S2" "$S3" "$S4" "$S5"; conf_auth $f)
  echo "pkh ${f##*/} $(printf '%s' "$_pa" | $B md5sum | $B awk '{ print $1 }')"
  case ${f##*/} in k?) continue ;; esac
  _pn=$((_pn+1))
  _pb=$(. /t/ref-parse.sh; parse_conf $f; printf '%s|' "$NS" "$S1" "$S2" "$S3" "$S4" "$S5"; conf_auth $f)
  case ${f##*/} in c01|c04) [ "$_pa" != "$_pb" ] && _pk=$((_pk+1)); continue ;; esac
  [ "$_pa" = "$_pb" ] && _pd=$((_pd+1))
done
echo "pkcmp=$_pd/$_pn ko=$_pk"
E
  cp -R $PK $BS/pk; cp $T/ref-parse.sh $BS/ref-parse.sh
  docker run --rm --pull never --platform linux/arm/v7 -v $T/app:/app:ro -v $B/vendor/busybox:/vb:ro -v $BS:/t:ro alpine:3.20 /vb/busybox sh /t/real.sh > $BS/real.out 2>&1
  check "  진짜 busybox(ARM 컨테이너): 실행됨, ps -o로 좀비를 보고 우리·순정 hostapd를 구분, 우리 것만 멈춤" 'grep -qx "OK=1" $BS/real.out && grep -qx "PS=/vb/busybox ps -o pid,stat,args" $BS/real.out && grep -qx zombie-seen $BS/real.out && grep -qx ours-running $BS/real.out && grep -qx stock-on $BS/real.out && grep -qx ours-stopped $BS/real.out && grep -qx stock-alive $BS/real.out'
  check "  4b 리뷰 L-2·묶음 J: 진짜 busybox로도 parse_conf·conf_auth가 1.7.2 원본과 같음(한글 아닌 9개), 한글이 든 c01·c04는 1.7.4 B-6대로 1.7.2와 다름" 'grep -qx "pkcmp=9/11 ko=2" $BS/real.out'
  # 묶음 J: 같은 파일(c00~c10, 순정 꼴 k1~k7)을 PC의 가짜 busybox로 읽은 결과의 md5와 줄마다 같은가
  for f in $PK/c?? $PK/k?; do _pa=$(HOTSPOT_LIB=1 BB=$T/bin/bb SRC=$f W=$T/w sh -c '. '$T'/app/svc/hotspot.sh; parse_conf $SRC; printf "%s|" "$NS" "$S1" "$S2" "$S3" "$S4" "$S5"; conf_auth $SRC'); echo "pkh ${f##*/} $(printf '%s' "$_pa" | md5 -q)"; done > $BS/pc.pkh
  check "  묶음 J: 진짜 busybox(ARM)와 PC(가짜 busybox)의 parse_conf·conf_auth 결과가 18개 파일(c00~c10, 순정 꼴 k1~k7) 모두 바이트까지 같음" '[ "$(grep -c "^pkh " $BS/pc.pkh)" = 18 ] && [ "$(grep "^pkh " $BS/real.out)" = "$(cat $BS/pc.pkh)" ]'
  check "  진짜 busybox: od -b -v 바이트, f_perm·f_owner, md5sum 표준입력" 'grep -qx "od=000 005 150 151 377" $BS/real.out && grep -qx "perm=640 owner=0:0" $BS/real.out && grep -qx "md5=764efa883dda1e11db47671c4a3bbd9e  -" $BS/real.out'
else
  echo "skip 진짜 busybox 확인(Docker 또는 alpine:3.20 arm/v7 이미지 없음)"
fi

# --- 1.7.3 6단계 패키지 전체 리뷰 반영(낮음) ---
S6=$T/s6; mkdir -p $S6/w $S6/bk
s6() { HOTSPOT_LIB=1 BB=$T/bin/bb W=$S6/w BK=$S6/bk sh -c '. '$T'/app/svc/hotspot.sh; '"$1" 2>&1; }
# L3: 계획의 WARNING 줄(ADB TCP 스위치 경고)은 변경이 아님
printf '%s\n' "same     /system/framework/hooks.jar [wireless-carplay-aa]" "WARNING: the car's ADB TCP switch is on" "hook plan: 3 of 3" > $S6/w/plan.txt
S6A=$(s6 'plan_nothing && echo yes || echo no')
printf '%s\n' "same     /system/framework/hooks.jar [wireless-carplay-aa]" "WARNING: x" "change   /system/app/X.apk [other] -> 1" > $S6/w/plan.txt
S6B=$(s6 'plan_nothing && echo yes || echo no')
check "6단계 리뷰 L3: plan_nothing은 WARNING 줄을 변경으로 보지 않음(다른 변경 줄이 있으면 그대로 변경)" '[ "$S6A" = yes ] && [ "$S6B" = no ]'
# L4: 설치 마무리가 진행 중(run)이면 순정 AP 경로가 "준비됨"으로 덮지 않음
printf 'pct=95\nstate=run\nstage=x\n' > $S6/prog
S6C=$(s6 'PROG='$S6'/prog; setup_done() { return 0; }; prog_final_this_boot() { return 1; }; prog() { echo "PROG $*"; }; stock_ap_ready; printf "state=done\n" > $PROG; stock_ap_ready')
check "6단계 리뷰 L4: stock_ap_ready는 진행 중(run, 95% 보류)이면 덮지 않고, 아니면 준비됨을 씀" '[ "$(echo "$S6C" | grep -c "^PROG 100 done")" = 1 ]'
# L5: 칩 실패 근거의 -84는 Wi-Fi 줄(dhd·bcmdhd·sdio·wlan)만
# 마지막 묶음(중간 2): 실제 커널 줄. 칩 실패 근거인 줄 5개는 하나씩 잡고, 무관한 줄 4개는 하나도 잡지 않음
printf '%s\n' "<3>[ 9.10] sdioh_buffer_tofrom_bus: TX FAILED ede1c000, addr=0x08000, pkt_len=1968, ERR=-84" > $S6/y1
printf '%s\n' "<3>[ 9.20] dhdsdio_probe_attach: si_attach failed!" > $S6/y2
printf '%s\n' "<3>[ 9.30] failed to power up DHD generic adapter, 0 retry left" > $S6/y3
printf '%s\n' "<3>[ 9.40] dhd_bus_start: failed to download firmware" > $S6/y4
printf '%s\n' "<3>[ 9.50] mmc1: error -84 whilst initialising SDIO card" > $S6/y5
printf '%s\n' "<3>[ 2.10] mmc0: error -84 whilst initialising SD card" "<3>[ 12.3] mmcblk0: error -84 transferring data, sector 1234, nr 8, cmd response 0x900, card status 0xb00" "<6>[ 30.1] wlan0 rssi=-84" "<6>[ 31.2] dhd_rx_frame: rssi -84 dbm" > $S6/n1
S6D=$(s6 'NOCHIP_LOG=/nonexist; for f in y1 y2 y3 y4 y5 n1; do NOWLAN_LOG='$S6'/$f; chip_fail_evidence && echo "$f=y" || echo "$f=n"; done' | tr '\n' ' ')
check "6단계 리뷰 L5·마지막 묶음 중간 2: ERR=-84(sdio)·si_attach·power up DHD·download firmware·SDIO 카드 error -84는 근거, mmc0 SD 카드·mmcblk0·rssi -84 두 줄은 근거 아님" '[ "$S6D" = "y1=y y2=y y3=y y4=y y5=y n1=n " ]'
rm -rf $S6

# 4b K-11(2026-11-10): 진단 USB 스크립트(kp-probe·kp-wifi-diag·5GHz·A/B·kp-sys-restore)의 시험은 tests/legacy/legacy-test.sh로 옮겼다(지우지 않음).

# --- 1.7.4 B-15: 패키지·USB 스크립트가 grep에 넘기는 옵션은 차의 busybox 1.8.1 grep에서 확실한 것만(l n q v s c i H h e f L A B C E) ---
# 리뷰 반영: grep 뒤 그 명령이 끝날 때(| ; & ) 줄 끝)까지의 모든 낱말에서 따옴표 밖 "-"로 시작하는 것을 본다(패턴 뒤 옵션·옵션 묶음도).
# 한계: 변수로 넘기는 옵션($OPT)과 따옴표 안의 옵션은 보지 못한다
cat > $T/g15.py <<'PYE'
import re,sys
ok=set('lnqvsciHhefLABCE0123456789')
def scan(line):
    out=[]
    for m in re.finditer(r'(?<![\w-])grep\b', line):
        rest=line[m.end():]
        i=0; q=None; tok=''; toks=[]
        while i < len(rest):
            ch=rest[i]
            if q:
                if ch==q: q=None
                tok+=ch
            elif ch in '\'"': q=ch; tok+=ch
            elif ch in ' \t\r\n': 
                if tok: toks.append(tok); tok=''
            elif ch in '|;&)`<>' : break
            else: tok+=ch
            i+=1
        if tok: toks.append(tok)
        for t in toks:
            if t.startswith('--') and t!='--': out.append(t)
            elif t.startswith('-') and t!='-' and not t[1:2].isdigit() and any(c not in ok for c in t[1:]): out.append(t)
    return out
n=0; bad=[]
for f in sys.argv[1:]:
    for i,l in enumerate(open(f,encoding='utf-8'),1):
        if l.lstrip().startswith('#'): continue
        r=scan(l); n+=len(re.findall(r'(?<![\w-])grep\b', l))
        bad+=['%s:%d %s' % ('/'.join(f.split('/')[-2:]), i, o) for o in r]
print(n, ' '.join(bad))
PYE
G15=$(python3 $T/g15.py $PKG/svc/hotspot.sh $PKG/bin/status.sh $PKG/scripts/post.sh $PKG/scripts/preun.sh $PKG/svc/ap.sh $PKG/svc/launch.sh $PKG/svc/env.sh $PKG/bin/uninstall.sh $B/usb/troubleShooter)
check "1.7.4 B-15: 패키지·USB 스크립트의 grep 옵션에 busybox 1.8.1에서 확실하지 않은 글자(-x·-w·-o 등)·긴 옵션이 없음(검사한 grep ${G15%% *}개)" '[ "${G15%% *}" -gt 40 ] && [ "$G15" = "${G15%% *} " ]'
# 검사기가 헛돌지 않는지: 옵션 앞·패턴 뒤·묶음·긴 옵션을 심은 사본은 모두 잡혀야 함(따옴표 안의 -84 같은 패턴은 잡지 않음)
mkdir -p $T/g15; printf '%s\n' "\$BB grep -qx 'aa=ok' \$HINT" "\$BB grep 'aa=ok' \$HINT -w" "\$BB grep -qvo x f | wc" "grep --line-buffered x f" "\$BB grep -i -E '(err)[ =:]*-84' f" > $T/g15/x.sh
G15B=$(python3 $T/g15.py $T/g15/x.sh)
check "  B-15: 검사기는 옵션 앞(-qx)·패턴 뒤(-w)·묶음(-qvo)·긴 옵션을 잡고, 따옴표 안 패턴(-84)은 잡지 않음(변이)" '[ "${G15B#* }" = "g15/x.sh:1 -qx g15/x.sh:2 -w g15/x.sh:3 -qvo g15/x.sh:4 --line-buffered" ]'
rm -rf $T/g15 $T/g15.py
# 가짜 bb의 grep 옵션 제한이 켜져 있음: -x는 2로 끝나고 아무것도 내지 않음
echo aa=ok > $T/g15f; G15C=$($T/bin/bb grep -qx aa=ok $T/g15f; echo "rc=$?"); G15D=$($T/bin/bb grep -q aa=ok $T/g15f; echo "rc=$?"); G15E=$($T/bin/bb grep -qw aa=ok $T/g15f; echo "rc=$?"); rm -f $T/g15f
check "  B-15: 시험의 가짜 bb는 1.8.1에서 확실하지 않은 grep 옵션(-x·-w)을 거절(rc 2), 있는 옵션(-q)은 그대로" '[ "$G15C" = "rc=2" ] && [ "$G15E" = "rc=2" ] && [ "$G15D" = "rc=0" ]'

# --- 1.7.4 베타 2(측정): 30초 측정 기록(perf_tick), 카플레이 소리 통계(aa_events), 제보 파일의 부하·소리 지연 칸(perf_report) ---
PF=$T/pf; mkdir -p $PF/w $PF/net $PF/proc $PF/bin; echo boot-P > $PF/bootid
pfreset() { rm -f $PF/w/perf.log $PF/w/perf.log.1 $PF/w/cpn; echo "1000.50 3" > $PF/up; echo "cpu  1000 0 500 8000 100 0 10 0 0 0" > $PF/kstat; echo "1.52 1.00 0.80 2/300 999" > $PF/load
  printf 'MemTotal: 2048000 kB\nMemFree: 307200 kB\nBuffers: 1024 kB\nCached: 716800 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n' > $PF/mem
  printf 'Inter-|   Receive\n face |bytes\n    lo: 1 1 0 0 0 0 0 0 1 1 0 0 0 0 0 0\n wlan0:999999 1000 1 2 0 0 0 0 888888 2000 3 4 0 0 0 0\n' > $PF/net/dev
  printf 'Tcp: RtoAlgorithm RtoMin RtoMax MaxConn ActiveOpens PassiveOpens AttemptFails EstabResets CurrEstab InSegs OutSegs RetransSegs InErrs OutRsts\nTcp: 1 200 120000 -1 5 5 0 0 2 900 800 7 0 0\nUdp: InDatagrams NoPorts InErrors OutDatagrams RcvbufErrors SndbufErrors\nUdp: 500 0 3 400 2 0\n' > $PF/net/snmp; }
# 차의 셸(mksh)과 ksh, sh에서 모두 돌린다. PATH를 비운 채 불러 프로세스를 하나도 띄우지 않는지도 본다(띄우면 "not found"로 값이 빈다)
pf() { (PATH=$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB=$T/bin/bb W=$PF/w BOOT_ID=$PF/bootid UPTIME=$PF/up KSTAT=$PF/kstat LOADAVG=$PF/load MEMINFO=$PF/mem PROCNET=$PF/net PROC=$PF/proc CONF=$PF/hk.conf APLOG=$PF/ap.log ${PFSH:-sh} -c '. '$T'/app/svc/hotspot.sh; export PATH='$T'/bin:/usr/bin:/bin:/sbin; '"$1"); }
PFRUN='mkdir -p $PROC/$$; echo "$$ (sh) S 1 1 1 0 -1 0 0 0 0 0 10 5 100 50 20 0 1 0" > $PROC/$$/stat; echo 1 > $CPN; AA_SOD=36305; WSTA=1; perf_start; PATH=/nonexistent; perf_begin; echo "1002.75 3" > $UPTIME; perf_tick; echo "cpu  1300 0 600 10000 200 0 10 0 0 0" > $KSTAT; echo "$$ (sh) S 1 1 1 0 -1 0 0 0 0 0 12 6 160 70 20 0 1 0" > $PROC/$$/stat; echo " wlan0:999999 1500 1 9 0 0 0 0 888888 2600 3 4 0 0 0 0" > $PROCNET/dev; echo "1030.00 3" > $UPTIME; perf_begin; echo "1034.12 3" > $UPTIME; perf_tick'
for PFSH in sh $KSHS; do
  pfreset; pf "$PFRUN" > $PF/out 2>&1
  check "1.7.4 베타 2 측정($(basename $PFSH)): 30초 측정 기록 첫 줄은 변화량을 '-'로, 시각·점검 시간(2.25초)·메모리·연결 수는 채움" '[ "$(sed -n 2p $PF/w/perf.log)" = "10:05:05 up=1002 load=1.52 cpu=- io=- svc=- tick=225 free=307200 cache=716800 cp=1 sta=1 rx=- tx=- rxe=- rxd=- txe=- txd=- udpe=- udpb=- retr=- dbg=0 wm=1 wn=16" ]'
  check "  둘째 줄은 지난 점검부터의 변화량: 내비 CPU 16%·입출력 대기 4%, 우리 서비스 0.83초, 점검 4.12초, Wi-Fi 받은 패킷 500·버림 7" '[ "$(sed -n 3p $PF/w/perf.log)" = "10:05:05 up=1034 load=1.52 cpu=16 io=4 svc=83 tick=412 free=307200 cache=716800 cp=1 sta=1 rx=500 tx=600 rxe=0 rxd=7 txe=0 txd=0 udpe=0 udpb=0 retr=0 dbg=0" ]'
  check "  프로세스를 띄우지 않음(PATH를 비워도 값이 같고 오류 줄 없음), 첫 줄은 서비스 시작 표시" '[ ! -s $PF/out ] && grep -q "^# 서비스 시작 .* up=1000$" $PF/w/perf.log && [ "$(grep -c . $PF/w/perf.log)" = 3 ]'
done
unset PFSH
pfreset; pf 'PERF_MAX=3; perf_start; for i in 1 2 3 4; do perf_begin; perf_tick; done; echo "N=$PF_N"' > $PF/out 2>&1
check "  크기 제한: PERF_MAX줄이 차면 perf.log.1로 밀고 새로 씀(최대 2개)" 'grep -qx "N=2" $PF/out && [ "$(grep -c "^--:--:-- up=1000 load=1.52 cpu=- io=- svc=- tick=0 free=307200 cache=716800 cp=0 sta=0 " $PF/w/perf.log.1)" = 2 ] && [ "$(grep -c . $PF/w/perf.log.1)" = 3 ] && [ "$(grep -c . $PF/w/perf.log)" = 2 ] && [ -z "$(ls $PF/w | grep -v -E "^perf\.log(\.1)?$")" ]'
pfreset; rm -f $PF/kstat $PF/load $PF/mem $PF/net/dev $PF/net/snmp $PF/up; pf 'perf_begin; perf_tick; perf_tick' > $PF/out 2>&1
check "  /proc 파일을 하나도 못 읽어도 오류 없이 '-'로 한 줄씩 남김(서비스 반복을 멈추지 않음)" '[ ! -s $PF/out ] && [ "$(grep -c "up=- load=- cpu=- io=- svc=- tick=- free=- cache=- cp=0 sta=0 rx=- tx=- rxe=- rxd=- txe=- txd=- udpe=- udpb=- retr=- dbg=0" $PF/w/perf.log)" = 2 ]'
check "  서비스 반복 두 곳(우리 핫스팟·순정 AP)이 대기 직후 perf_begin, 회차 끝에 perf_tick을 부름(소스)" '[ "$(grep -c "^    perf_begin$" $PKG/svc/hotspot.sh)" = 2 ] && [ "$(grep -c "^    perf_tick$" $PKG/svc/hotspot.sh)" = 2 ] && [ "$(awk "/^perf_tick\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -c -E "\\$\([^(]|\`")" = 0 ]'
# 카플레이 소리 통계: 순정 TccCarPlay 줄 꼴(니로 2026-11-06 cp.log). 이름이 든 줄(홍길동)은 옮기지 않는다
cat > $PF/cplog <<'E'
11-06 09:37:59.270 I/TccCarPlay( 1001):  [AirPlay] Main audio setting up AAC-LC/44100/2 for media, input no, loopback no
11-06 09:38:05.690 I/TccCarPlay( 1001):  [AirPlay] Alt audio setting up OPUS/48000/1
11-06 09:38:58.840 I/TccCarPlay( 1001):  [AirPlay] ### 1 glitches in the last minute of 26 minute(s) (7% glitchy)
11-06 10:01:38.960 I/TccCarPlay( 1001):  [AirPlay] Main audio setting up OPUS/16000/1 for telephony, input yes, loopback no
11-06 10:09:45.070 I/TccCarPlay( 1001):  [AirPlay] ### Lost packets 10315-10316 (+1, 1 total)
11-06 10:09:46.070 I/TccCarPlay( 1001):  [AirPlay] ### Unrecovered packets: 42041-59293 (17252) 17252 total
11-06 10:09:47.070 I/TccCarPlay( 1001):  [AirPlay] Jitter Buffer Discard Excess, prevSize=13440(280ms) newSize=9600(200ms)
11-06 10:09:48.070 I/TccCarPlay( 1001):  [AirPlay] ### Main: Buffering issues during session: Late=0 Missing=1 Gaps=0 Rebuffers=1
11-06 10:09:49.000 I/TccCarPlay( 1001): AirPlay session ended: Dur=1529 seconds Reason=-6753/0xFFFFE59F 
11-06 10:09:49.001 I/TccCarPlay( 1001): Glitches:    8%, 5 total, 2 glitchy minute(s)
11-06 10:09:49.002 I/TccCarPlay( 1001): Retransmits: 0 sent, 0 received, 0 futile, 0 not found, 0/0/0 ms min/max/avg, 0/0 ms retry min/max
11-06 10:09:49.003 I/TccCarPlay( 1001): Packets:     0 lost, 29991 unrecovered, 0 late, 0 max burst, 0 big losses, 16% compression
11-06 10:09:49.004 I/TccCarPlay( 1001): Time Sync:   2/171/22 ms min/max/avg RTT, -84101/2147483647/6313 µS min/max/avg offset, 0 step(s)
11-06 10:09:50.000 I/TccCarPlay( 1001):  [TccCarPlay] TccCarPlay_OnTelephony() : name(홍길동) Packets: 3 Main audio setting up 홍길동폰 for 홍길동, x
11-06 10:09:50.100 I/TccCarPlay( 1001):  [AirPlay] Main audio setting up Johns-iPhone for John Smith 010-1234-5678, x
11-06 10:09:50.200 I/TccCarPlay( 1001): AirPlay session ended: Dur=1 seconds Reason=0/0x0 peer=192.168.49.23 dev=A4:83:E7:11:22:33 Johns iPhone
11-06 10:09:50.300 I/TccCarPlay( 1001):  [AirPlay] Jitter Buffer Discard Excess, prevSize=1(2ms) newSize=3(4ms) John
11-06 10:09:51.000 E/Playback_if( 1007): =========> [94] Can't render and Drop (with 0 ms) for CarPlay because of Null surface ? 
11-06 10:09:52.000 E/AudioMixer(  146): STREAM UNDERRUN, clear 7680 bytes
E
printf '#!/bin/sh\ncat %s/cplog\n' $PF > $PF/bin/logcat; chmod +x $PF/bin/logcat
pfa() { (PATH=$PF/bin:$T/bin:/usr/bin:/bin:/sbin HOTSPOT_LIB=1 BB=$T/bin/bb W=$PF/w BOOT_ID=$PF/bootid UPTIME=$PF/up KSTAT=$PF/kstat LOADAVG=$PF/load MEMINFO=$PF/mem PROCNET=$PF/net PROC=$PF/proc CONF=$PF/hk.conf APLOG=$PF/ap.log ${PFASH:-sh} -c '. '$T'/app/svc/hotspot.sh; export PATH='$PF'/bin:'$T'/bin:/usr/bin:/bin:/sbin; '"$1"); }
rm -f $PF/w/aatime; pfa 'aa_events; echo "SOD=$AA_SOD"' > $PF/cp1 2>&1
check "1.7.4 베타 2 측정: 순정 카플레이의 소리 통계 줄을 ap.log에 '카플레이 소리:'로 옮김(끊김·잃은 패킷·지터 버퍼·세션 요약, 보조 소리 설정은 뺌)" '[ "$(grep -c "카플레이 소리: " $PF/cp1)" = 12 ] && grep -q "카플레이 소리: 지난 1분에 끊김 1번(26분 중 7%) (09:38:58.840)" $PF/cp1 && grep -q "카플레이 소리: 소리 설정 OPUS/16000/1 telephony" $PF/cp1 && grep -q "카플레이 소리: 패킷 잃음 +1(모두 1)" $PF/cp1 && grep -q "카플레이 소리: 되살리지 못한 패킷 17252(모두 17252)" $PF/cp1 && grep -q "지터 버퍼가 넘쳐 버림 prevSize=13440(280ms) newSize=9600(200ms)" $PF/cp1 && grep -q "세션 버퍼 문제(주 소리) Late=0 Missing=1 Gaps=0 Rebuffers=1" $PF/cp1 && grep -q "세션 요약 Wi-Fi 왕복 시간 2/171/22 ms (최소/최대/평균) (10:09:49.004)" $PF/cp1 && grep -q "세션 요약 패킷 0 , 29991 , 0 , 0 , 0 , 16% (잃음 · 못 되살림" $PF/cp1 && grep -q "세션 요약 재전송 0 , 0 , 0 , 0 , 0/0/0 , 0/0 (보냄" $PF/cp1 && ! grep -q "Alt\|OPUS/48000" $PF/cp1'
check "  리뷰 M3: 이름·주소가 섞인 줄(한글·영문 이름, 전화번호, IP, MAC)은 꼴이 달라 옮기지 않음, aa_events가 측정 기록용 시각(AA_SOD)을 남김" '! grep -q -E "홍길동|John|010-1234|192\.168|A4:83" $PF/cp1 && grep -q -E "^SOD=[0-9]+$" $PF/cp1'
# 리뷰 M2: 소리 줄이 몰려도 AA 단계 줄을 한도에서 밀어내지 않는다
cp $PF/cplog $PF/cplog.keep
{ i=0; while [ $i -lt 25 ]; do echo "11-06 11:00:0$((i % 10)).0$((i / 10))0 I/TccCarPlay( 1001):  [AirPlay] ### Lost packets 1-2 (+1, $i total)"; i=$((i+1)); done
  echo "11-06 11:00:30.000 I/PhoneProjection( 1660): [ f ] getWiFiApMode wifiMode = 2"; echo "11-06 11:00:31.000 D/AAProjection(  775): WirelessExplorer : isWifiApEnable = true, mode = 2"; } > $PF/cplog
rm -f $PF/w/aatime; pfa 'aa_events' > $PF/cp2 2>&1
check "  리뷰 M2: 소리 줄 25개가 몰려도 한 번에 16줄까지만, 같은 회차의 AA 단계 줄 2개는 그대로 남음" '[ "$(grep -c "카플레이 소리: " $PF/cp2)" = 16 ] && [ "$(grep -c "안드로이드 오토: " $PF/cp2)" = 2 ]'
cp $PF/cplog.keep $PF/cplog
# 리뷰 M1·L2·L3
pfreset; printf '%s\n' a b c d e > $PF/w/perf.log; pf 'perf_start; echo "N=$PF_N"' > $PF/out 2>&1
check "  리뷰 M1: 서비스가 시작할 때 이미 쌓인 줄 수를 이어 셈(재부팅·다시 시작으로 한도를 넘기지 않게)" 'grep -qx "N=6" $PF/out && [ "$(grep -c . $PF/w/perf.log)" = 6 ]'
pfreset; printf '%s\n' a b c d e > $PF/w/perf.log; pf 'PERF_MAX=5; perf_start; echo "N=$PF_N"' > $PF/out 2>&1
check "  리뷰 M1: 시작할 때 이미 한도면 그 자리에서 perf.log.1로 밀고 새로 씀" 'grep -qx "N=1" $PF/out && [ "$(grep -c . $PF/w/perf.log.1)" = 5 ] && [ "$(grep -c . $PF/w/perf.log)" = 1 ]'
pfreset; printf ' swlan0: 1 7777 0 0 0 0 0 0 1 7777 0 0 0 0 0 0\n wlan0: 1 1000 0 0 0 0 0 0 1 2000 0 0 0 0 0 0\n' > $PF/net/dev
pf 'perf_begin; perf_tick; printf " swlan0: 1 9999 0 0 0 0 0 0 1 9999 0 0 0 0 0 0\n wlan0: 1 1010 0 0 0 0 0 0 1 2020 0 0 0 0 0 0\n" > $PROCNET/dev; perf_tick' > $PF/out 2>&1
check "  리뷰 L2: Wi-Fi 숫자는 이름이 정확히 같은 장치 줄에서만(swlan0 줄이 앞에 있어도 wlan0)" 'grep -q " rx=10 tx=20 " $PF/w/perf.log'
pfreset; printf ' wlan0: 1 3000001000 0 0 0 0 0 0 1 5 0 0 0 0 0 0\n' > $PF/net/dev
pf 'perf_begin; perf_tick; printf " wlan0: 1 999999000 0 0 0 0 0 0 1 9 0 0 0 0 0 0\n" > $PROCNET/dev; perf_tick; printf " wlan0: 1 999999100 0 0 0 0 0 0 1 12 0 0 0 0 0 0\n" > $PROCNET/dev; perf_tick' > $PF/out 2>&1
check "  리뷰 L3: 10자리가 넘는 값(32비트 산술을 넘을 수 있음)은 '-'로 두고 음수를 찍지 않음, 그 뒤 값은 다시 이어 셈" '[ ! -s $PF/out ] && ! grep -q "=-[0-9]" $PF/w/perf.log && [ "$(sed -n 2p $PF/w/perf.log | grep -c " rx=- tx=4 ")" = 1 ] && [ "$(sed -n 3p $PF/w/perf.log | grep -c " rx=100 tx=3 ")" = 1 ]'
unset CPUINFO CPUPRESENT
# PF-1: 우리 dnsmasq는 표준입력이 FIFO인 채로 뜬다(순정 dnsmasq가 /dev/null 표준입력에서 쉬지 않고 도는 것을 막음)
printf '#!/bin/sh\nif [ -p /dev/fd/0 ]; then k=fifo; else k=other; fi\nrw=ro; ( echo x >&0 ) 2>/dev/null && rw=rw\necho "$k $*" >> %s/dcalls\necho "$rw $$" >> %s/dpid\n' $PF $PF > $PF/bin/dnsmasq
printf '#!/bin/sh\nexit 0\n' > $PF/bin/ifconfig; chmod +x $PF/bin/dnsmasq $PF/bin/ifconfig
PFUP='running() { return 0; }; aa_none() { :; }; dns_fifo_died() { return 1; }; DNSPID=$W/dnsmasq.pid; rm -f $DNSPID; up; wait; cat $DNSPID'
for PFASH in sh $(command -v mksh); do
  rm -f $PF/dcalls $PF/dpid $PF/w/dnsmasq.in
  # 리뷰 M2: 셸이 FIFO 열기에서 멈추면 시험이 끝없이 멈추지 않게 20초 뒤 끊는다(그때는 아래 항목이 실패)
  ( pfa "$PFUP" > $PF/up1 2>&1 ) & PFW=$!; ( sleep 20; kill $PFW 2>/dev/null ) >/dev/null 2>&1 & PFK=$!; wait $PFW 2>/dev/null; { kill $PFK; wait $PFK; } 2>/dev/null
  check "PF-1($(basename $PFASH)): FIFO가 읽기·쓰기로 열려 있고(끝이 오지 않음) pid 파일의 pid가 dnsmasq 자신" '[ "$(cat $PF/dpid 2>/dev/null)" = "rw $(sed "s/ .*//" $PF/up1 | grep -E "^[0-9]+$")" ] && grep -q "^fifo " $PF/dcalls'
done
unset PFASH
rm -f $PF/dcalls $PF/dpid $PF/w/dnsmasq.in; pfa "$PFUP" > $PF/up1 2>&1
check "PF-1: 우리 dnsmasq는 표준입력을 FIFO로 받아 뜸(옵션은 그대로), pid 파일에 pid와 부팅 id" '[ "$(cat $PF/dcalls)" = "fifo --keep-in-foreground --no-resolv --no-poll --dhcp-authoritative --pid-file --interface=wlan0 --bind-interfaces --dhcp-range=192.168.43.10,192.168.43.50,255.255.255.0,1h --dhcp-option=3 --dhcp-option=6" ] && [ -p $PF/w/dnsmasq.in ] && grep -q -E "^[0-9]+ boot-P$" $PF/up1 && grep -q "dnsmasq 시작" $PF/up1'
rm -f $PF/dcalls $PF/w/dnsmasq.in; echo junk > $PF/w/dnsmasq.in; pfa "$PFUP" > $PF/up2 2>&1
check "  그 자리에 보통 파일이 있으면 지우고 FIFO로 다시 만듦" '[ -p $PF/w/dnsmasq.in ] && grep -q "^fifo " $PF/dcalls'
rm -f $PF/dcalls $PF/w/dnsmasq.in; mkfifo -m 666 $PF/w/dnsmasq.in; PFI0=$(ls -i $PF/w/dnsmasq.in | awk '{print $1}'); pfa 'umask 077; '"$PFUP" > $PF/up2b 2>&1
check "  묶음 H(리뷰 낮음 2): FIFO가 이미 있어도 지우고 새로 만듦(서비스의 umask 077로 0600), 새 FIFO로 띄움" '[ -p $PF/w/dnsmasq.in ] && [ "$(stat -f %Lp $PF/w/dnsmasq.in)" = 600 ] && [ "$(ls -i $PF/w/dnsmasq.in | awk "{print \$1}")" != "$PFI0" ] && grep -q "^fifo " $PF/dcalls'
rm -f $PF/dcalls $PF/w/dnsmasq.in; mkfifo $PF/lnktarget; ln -s $PF/lnktarget $PF/w/dnsmasq.in; pfa 'umask 077; '"$PFUP" > $PF/up2c 2>&1
check "  묶음 H: 그 자리에 남이 넣은 링크가 있으면 링크만 지우고(가리키던 것은 그대로) 우리 FIFO를 새로 만듦" '[ -p $PF/w/dnsmasq.in ] && [ ! -L $PF/w/dnsmasq.in ] && [ -p $PF/lnktarget ] && grep -q "^fifo " $PF/dcalls'
rm -f $PF/lnktarget
printf '#!/bin/sh\ncase "$1" in mkfifo|mknod) exit 1 ;; esac\nexec "$@"\n' > $PF/bin/bbno; chmod +x $PF/bin/bbno
rm -f $PF/dcalls $PF/w/dnsmasq.in; pfa 'BB='$PF'/bin/bbno; running() { return 0; }; dns_fifo_died() { return 1; }; DNSPID=$W/dnsmasq.pid; rm -f $DNSPID; up; wait; rm -f $DNSPID; up; wait' > $PF/up3 2>&1
check "  FIFO를 못 만드는 내비(mkfifo·mknod 없음)는 예전 방식으로 띄우고 이유는 한 번만 남김(핫스팟을 막지 않음)" '[ "$(grep -c "^other --keep-in-foreground" $PF/dcalls)" = 2 ] && [ "$(grep -c "FIFO를 만들지 못함" $PF/up3)" = 1 ] && [ ! -e $PF/w/dnsmasq.in ]'
# 리뷰: FIFO 열기에서 멈춘 하위 셸(살아 있는데 dnsmasq가 아니고 부모가 서비스 셸)을 끝내고 예전 방식으로 내려감
rm -f $PF/dcalls $PF/w/dnsmasq.in; pfa 'running() { return 0; }; DNSPID=$W/dnsmasq.pid; DNS_FIFO=1; mkdir -p $PROC/777; echo "777 (sh) S $$ 1" > $PROC/777/stat; echo "777 boot-P" > $DNSPID; kill() { echo "kill $*"; }; dns_fifo_died() { return 1; }; up; wait' > $PF/up4 2>&1
check "  PF-1 리뷰: FIFO로 띄운 것이 멈춰 있으면(살아 있는데 dnsmasq가 아님) 끝내고 그 실행에서는 예전 방식으로 띄움, 이유는 한 번" 'grep -qx "kill 777" $PF/up4 && [ "$(grep -c "예전 방식으로 띄움" $PF/up4)" = 1 ] && grep -q "^other --keep-in-foreground" $PF/dcalls && ! grep -q "^fifo " $PF/dcalls'
rm -f $PF/dcalls; pfa 'running() { return 0; }; DNSPID=$W/dnsmasq.pid; DNS_FIFO=1; mkdir -p $PROC/778; echo "778 (sh) S 1 1" > $PROC/778/stat; echo "778 boot-P" > $DNSPID; kill() { echo "kill $*"; }; dns_fifo_died() { return 1; }; up; wait' > $PF/up5 2>&1
check "  부모가 서비스 셸이 아닌 pid(다시 쓰인 pid)는 죽이지 않음, 직전이 FIFO 방식인데 dnsmasq가 아니므로 그 실행은 예전 방식(묶음 H)" '! grep -q "^kill" $PF/up5 && grep -q "^other --keep-in-foreground" $PF/dcalls && ! grep -q "^fifo " $PF/dcalls'
# 묶음 H(PF-1 리뷰 중간 1): FIFO 방식으로 띄운 dnsmasq가 떠 있지 않으면 다음 up()에서 예전 방식(표준입력 리다이렉션 없음)으로 내림
# ①② 는 묶음 H 최종에서 살아 있는 가짜로 다시 썼다(아래 'H최종')
printf '#!/bin/sh\ncase "$1" in mkfifo|mknod) %s "$@" || exit 1; chmod 000 "$2"; exit 0 ;; esac\nexec %s "$@"\n' $T/bin/bb $T/bin/bb > $PF/bin/bbf0; chmod +x $PF/bin/bbf0
# ③ 정상: FIFO로 뜬 dnsmasq가 살아 있으면(가짜 /proc에 그 pid의 dnsmasq) 다음 up()은 다시 띄우지도 내리지도 않음
rm -f $PF/dcalls $PF/w/dnsmasq.in; pfa 'running() { return 0; }; dns_fifo_died() { return 1; }; DNSPID=$W/dnsmasq.pid; rm -f $DNSPID; up; wait; read p b < $DNSPID; mkdir -p $PROC/$p; echo "$p (dnsmasq) S $$ 1" > $PROC/$p/stat; ls -i $DNSIN; up; wait; up; wait; ls -i $DNSIN; echo "FIFO=$DNS_FIFO"; rm -rf $PROC/$p' > $PF/uph3 2>&1
check "  묶음 H: FIFO로 뜬 dnsmasq가 살아 있으면 다음 up()들은 다시 띄우지도 예전 방식으로 내리지도 않고, 그 FIFO도 다시 만들지 않음" '[ "$(grep -c . $PF/dcalls)" = 1 ] && grep -q "^fifo " $PF/dcalls && ! grep -q "떠 있지 않음" $PF/uph3 && grep -qx "FIFO=1" $PF/uph3 && [ "$(grep -c "dnsmasq.in$" $PF/uph3)" = 2 ] && [ "$(grep "dnsmasq.in$" $PF/uph3 | sort -u | grep -c .)" = 1 ]'
# ④ 끄기: stop_ours 뒤 FIFO dnsmasq(표준입력을 읽으며 기다리는 가짜)가 끝나고 남는 프로세스가 없음. 일부러 끈 것이므로 다음 up()은 FIFO 그대로
mkdir -p $PF/bin4; printf '#!/bin/sh\n[ -p /dev/fd/0 ] && echo "fifo $$" >> %s/dcalls4\nread x\n' $PF > $PF/bin4/dnsmasq; chmod +x $PF/bin4/dnsmasq
rm -f $PF/dcalls4 $PF/w/dnsmasq.in
PFSTOP='export PATH='$PF'/bin4:$PATH; running() { return 0; }; dns_fifo_died() { return 1; }; PS=true; DNSPID=$W/dnsmasq.pid; rm -f $DNSPID
mark() { read p b < $DNSPID; mkdir -p $PROC/$p; echo "$p (dnsmasq) S $$ 1" > $PROC/$p/stat; }
# 가짜가 실제로 떠서 FIFO를 쥘 때까지(줄 수가 $1이 될 때까지)만 기다린다. 시각이 아니라 조건을 본다(최대 약 10초)
seen() { i=0; while [ "$(grep -c "^fifo " '$PF'/dcalls4 2>/dev/null)" != "$1" ] && [ $i -lt 200 ]; do sleep 0.05; i=$((i+1)); done; }
up; mark; p1=$p; seen 1; stop_ours; wait $p1 2>/dev/null; kill -0 $p1 2>/dev/null && echo "alive1" || echo "gone1"; [ -f $DNSPID ] && echo pidfile1
up; mark; p2=$p; seen 2; stop_ours; wait $p2 2>/dev/null; kill -0 $p2 2>/dev/null && echo "alive2" || echo "gone2"; rm -rf $PROC/$p1 $PROC/$p2'
( pfa "$PFSTOP" > $PF/uph4 2>&1 ) & PFW=$!; ( sleep 20; kill $PFW 2>/dev/null ) >/dev/null 2>&1 & PFK=$!; wait $PFW 2>/dev/null; { kill $PFK; wait $PFK; } 2>/dev/null
check "  묶음 H: stop_ours 뒤 FIFO dnsmasq가 끝나고 pid 파일이 지워짐, 다음 up()도 FIFO 방식(일부러 끈 것은 내리지 않음), 남은 프로세스 0" 'grep -qx gone1 $PF/uph4 && grep -qx gone2 $PF/uph4 && ! grep -q pidfile1 $PF/uph4 && [ "$(grep -c "^fifo " $PF/dcalls4)" = 2 ] && ! grep -q "떠 있지 않음" $PF/uph4 && ! ps -axo command | grep -v grep | grep -q "$PF/bin4/dnsmasq"'
# --- 묶음 H 최종(리뷰 중간 1·2·3, 낮음 2·4·5) ---
# 살아 있는 가짜 dnsmasq: 살아 있는 동안만 가짜 /proc에 "(dnsmasq) S" stat을 둔다(죽은 것과 살아 있는 것을 실제로 가름).
# 모드($PF/lmode): fifodie = 표준입력이 FIFO면 바로 끝남, alldie = 늘 바로 끝남, 그 밖 = 끝날 때까지 산다(TERM이면 stat을 지우고 끝)
mkdir -p $PF/binL
cat > $PF/binL/dnsmasq <<E
#!/bin/sh
P=$PF; k=other; [ -p /dev/fd/0 ] && k=fifo
echo "\$k \$\$" >> \$P/lcalls
m=\$(cat \$P/lmode 2>/dev/null)
if [ "\$m" = alldie ] || { [ "\$m" = fifodie ] && [ \$k = fifo ]; }; then : > \$P/lstart.\$\$; exit 1; fi
nm=dnsmasq; [ "\$m" = asshell ] && nm=sh
mkdir -p \$P/proc/\$\$; echo "\$\$ (\$nm) S \$PPID 1" > \$P/proc/\$\$/stat
sp=; trap 'kill \$sp 2>/dev/null; rm -rf \$P/proc/\$\$; exit 0' TERM
: > \$P/lstart.\$\$
while :; do /bin/sleep 300 & sp=\$!; wait \$sp; done
E
chmod +x $PF/binL/dnsmasq
# 기다림은 시각이 아니라 조건: 지금 pid 파일의 가짜가 시작 표시를 남겼거나, 좀비·없음이 될 때까지(최대 약 10초).
# 서비스의 "FIFO 직후 1초"(sleep 1)도 이 기다림으로 바꿔 친다. tick = 서비스의 30초 점검 한 번(up)과 그 뒤 자리 잡기
PFL='export PATH='$PF'/binL:$PATH; running() { return 0; }; PS=true; DNSPID=$W/dnsmasq.pid
sleep() { read _p _b < $DNSPID 2>/dev/null; _i=0; while [ -n "$_p" ] && [ ! -f '$PF'/lstart.$_p ] && [ "$(ps -o stat= -p $_p 2>/dev/null | cut -c1)" != Z ] && kill -0 $_p 2>/dev/null && [ $_i -lt 200 ]; do command sleep 0.05; _i=$((_i+1)); done; }
tick() { TICK_N=$((${TICK_N:-0}+1)); up; sleep; }
alive() { read _p _b < $DNSPID; [ -f $PROC/$_p/stat ] && echo "alive $_p" || echo "dead $_p"; }
'
lreset() { rm -f $PF/lcalls $PF/lstart.* $PF/lmode $PF/w/dnsmasq.pid $PF/w/dnsmasq.in; }
# 끝난 뒤 살아 있는 가짜를 모두 끝내고, 남은 것이 없는지(최대 약 10초 조건 기다림)
lclean() { for p in $(awk '{print $2}' $PF/lcalls 2>/dev/null); do kill $p 2>/dev/null; done; i=0; while ps -axo command | grep -v grep | grep -q "$PF/binL/dnsmasq" && [ $i -lt 200 ]; do sleep 0.05; i=$((i+1)); done; }
lleft() { ! ps -axo command | grep -v grep | grep -q "$PF/binL/dnsmasq"; }
FBMSG="FIFO 표준입력으로 띄웠지만 떠 있지 않음"
# H최종 ① FIFO를 열 수 없음(만들 때마다 0000): 같은 점검 안에서 1초 확인으로 예전 방식이 떠 있어야 함, 다음 점검은 그대로
lreset; pfa 'BB='$PF'/bin/bbf0; '"$PFL"' rm -f $DNSPID; tick; alive; tick; alive' > $PF/hf1 2>&1; chmod 600 $PF/w/dnsmasq.in 2>/dev/null; lclean
check "  H재리뷰 낮음 1: FIFO 열기 실패 오류 줄(Permission denied·can't)이 서비스 출력(ap.log 쪽)으로 새지 않음" '! grep -q -i -e "denied" -e "can.t" $PF/hf1'
check "  H최종 ①: FIFO를 열 수 없으면 같은 점검에서 예전 방식으로 띄워 살아 있음(DHCP 공백 없음), 다음 점검은 다시 띄우지 않음, 이유 한 번" '[ "$(grep -c . $PF/lcalls)" = 1 ] && grep -q "^other " $PF/lcalls && [ "$(grep -c "^alive " $PF/hf1)" = 2 ] && [ "$(grep -c "$FBMSG" $PF/hf1)" = 1 ] && lleft'
# H최종 ② 표준입력이 FIFO일 때만 바로 끝남: 같은 점검에서 예전 방식, 그 뒤 점검들도 예전 방식에 머묾(FIFO 다시 안 띄움)
lreset; echo fifodie > $PF/lmode; pfa "$PFL"' rm -f $DNSPID; tick; alive; tick; tick; alive' > $PF/hf2 2>&1; lclean
check "  H최종 ②: FIFO에서만 바로 끝나면 같은 점검에서 예전 방식(살아 있음), 다음 점검들도 예전 방식에 머묾, 이유 한 번" '[ "$(sed -n 1p $PF/lcalls | cut -d" " -f1)" = fifo ] && [ "$(sed -n 2p $PF/lcalls | cut -d" " -f1)" = other ] && [ "$(grep -c . $PF/lcalls)" = 2 ] && [ "$(grep -c "^alive " $PF/hf2)" = 2 ] && [ "$(grep -c "$FBMSG" $PF/hf2)" = 1 ] && lleft'
# H최종 ③ 살아 있는 것을 본 뒤에 죽으면(몇 시간 잘 돌다 죽음) FIFO 탓으로 보지 않고 다시 FIFO
lreset; pfa "$PFL"' rm -f $DNSPID; tick; tick; read p0 b < $DNSPID; kill $p0; i=0; while [ -d $PROC/$p0 ] && [ $i -lt 200 ]; do command sleep 0.05; i=$((i+1)); done; tick; alive' > $PF/hf3 2>&1; lclean
check "  H최종 ③(중간 1): 점검에서 살아 있음을 본 FIFO dnsmasq가 나중에 죽으면 다시 FIFO로 띄움(예전 방식으로 내리지 않음)" '[ "$(grep -c "^fifo " $PF/lcalls)" = 2 ] && ! grep -q "^other " $PF/lcalls && grep -q "^alive " $PF/hf3 && ! grep -q "$FBMSG" $PF/hf3 && lleft'
# H최종 ④ FIFO와 무관한 즉시 종료(wlan0 없음 등)가 풀린 뒤에는 다시 FIFO. 그동안도 점검마다 dnsmasq를 하나 이상 띄움
lreset; echo alldie > $PF/lmode; pfa "$PFL"' rm -f $DNSPID; tick; echo "n1=$(grep -c . '$PF'/lcalls)"; tick; echo "n2=$(grep -c . '$PF'/lcalls)"; echo ok > '$PF'/lmode; tick; alive' > $PF/hf4 2>&1; lclean
check "  H최종 ④(중간 1): 무관한 즉시 종료가 풀리면 다시 FIFO로 떠 살아 있음, 그동안 점검마다 dnsmasq를 띄움(FIFO→예전→FIFO…)" '[ "$(tail -1 $PF/lcalls | cut -d" " -f1)" = fifo ] && grep -q "^alive " $PF/hf4 && n1=$(sed -n "s/^n1=//p" $PF/hf4) && n2=$(sed -n "s/^n2=//p" $PF/hf4) && [ "$n1" -ge 1 ] && [ "$n2" -gt "$n1" ] && lleft'
# H최종 ⑤ 늘 바로 끝나는 차(되풀이): 점검마다 띄우고 로그는 3번 한도(4번째에 "더 남기지 않음")
lreset; echo alldie > $PF/lmode; pfa "$PFL"' rm -f $DNSPID; tick; tick; tick; tick; tick; tick' > $PF/hf5 2>&1; lclean
check "  H최종 ⑤: 늘 바로 끝나는 dnsmasq여도 6번 점검에 6번 이상 띄우고, '떠 있지 않음' 로그는 3번 + 한도 줄 1번" '[ "$(grep -c . $PF/lcalls)" -ge 6 ] && [ "$(grep -c "$FBMSG" $PF/hf5)" = 3 ] && [ "$(grep -c "더 남기지 않음" $PF/hf5)" -ge 1 ] && lleft'
# H최종 ⑥(중간 3) 이 내비의 셸이 읽기·쓰기 열기를 받지 않음(확인 함수를 바꿔 침): 예전 방식, 로그 한 번
lreset; echo alldie > $PF/lmode; pfa "$PFL"' dns_rw_ok() { return 1; }; rm -f $DNSPID; tick; tick' > $PF/hf6 2>&1; lclean
check "  H최종 ⑥(중간 3): 셸이 FIFO 표준입력 열기를 받지 않으면 FIFO를 시도하지 않고 예전 방식, 로그는 한 번" '[ "$(grep -c "^other " $PF/lcalls)" = 2 ] && ! grep -q "^fifo " $PF/lcalls && [ "$(grep -c "셸이 FIFO 표준입력 열기를 받지 않음" $PF/hf6)" = 1 ] && lleft'
lreset; pfa "$PFL"' rm -f $DNSPID; tick; alive' > $PF/hf6b 2>&1; lclean
check "  H최종 ⑥: 받는 셸(PC sh)에서는 확인을 통과해 FIFO로 떠 살아 있음" '[ "$(grep -c . $PF/lcalls)" = 1 ] && grep -q "^fifo " $PF/lcalls && grep -q "^alive " $PF/hf6b && ! grep -q "받지 않음" $PF/hf6b && lleft'
check "  H최종 ⑥(소스): 파일 본문에서 읽기·쓰기 열기(<>)는 eval 작은따옴표 문자열 안에만 있음(주석 빼고), sh -n 통과" '[ -z "$(grep -n "<>" $PKG/svc/hotspot.sh | grep -v "^[0-9]*: *#" | grep -v "eval '"'"'")" ] && [ "$(grep -n "<>" $PKG/svc/hotspot.sh | grep -v "^[0-9]*: *#" | grep -c "eval '"'"'")" -ge 2 ] && sh -n $PKG/svc/hotspot.sh'
if command -v mksh >/dev/null 2>&1; then check "  H최종 ⑥(소스): mksh -n 통과" 'mksh -n $PKG/svc/hotspot.sh'; fi
# H최종 ⑦(중간 2) $BB에 mkfifo·mknod가 없으면 함께 넣은 busybox(BB_OWN)로 만듦
lreset; pfa 'BB='$PF'/bin/bbno; BB_OWN='$T'/bin/bb; '"$PFL"' rm -f $DNSPID; tick; alive' > $PF/hf7 2>&1; lclean
check "  H최종 ⑦(중간 2): 내비 busybox에 mkfifo·mknod가 없으면 함께 넣은 busybox로 FIFO를 만들어 FIFO로 띄움" '[ "$(grep -c . $PF/lcalls)" = 1 ] && grep -q "^fifo " $PF/lcalls && grep -q "^alive " $PF/hf7 && ! grep -q "FIFO를 만들지 못함" $PF/hf7 && lleft'
lreset; pfa 'BB='$PF'/bin/bbno; BB_OWN='$PF'/nobb; '"$PFL"' rm -f $DNSPID; tick; alive' > $PF/hf7b 2>&1; lclean
check "  H최종 ⑦: 둘 다 못 만들면 예전 방식(오류 줄 없이), 살아 있음" '[ "$(grep -c . $PF/lcalls)" = 1 ] && grep -q "^other " $PF/lcalls && grep -q "^alive " $PF/hf7b && grep -q "FIFO를 만들지 못함" $PF/hf7b && ! grep -q -i "not found\|no such" $PF/hf7b && lleft'
# H최종 ⑧(낮음 2) 좀비(상태 Z)는 살아 있다고 보지 않음
pfa 'DNSPID=$W/dnsmasq.pid; echo "991 boot-P" > $DNSPID; mkdir -p $PROC/991; echo "991 (dnsmasq) Z 1 1" > $PROC/991/stat; our_dhcp_on && echo z-on || echo z-off; echo "991 (dnsmasq) S 1 1" > $PROC/991/stat; our_dhcp_on && echo s-on || echo s-off; rm -rf $PROC/991 $DNSPID' > $PF/hf8 2>&1
check "  H최종 ⑧(낮음 2): our_dhcp_on은 좀비(Z) dnsmasq를 살아 있다고 보지 않음(S는 살아 있음)" 'grep -qx z-off $PF/hf8 && grep -qx s-on $PF/hf8'
# H최종 ⑨(낮음 5) restart_hostapd 직후 두 번째 up()은 막 뜬 dnsmasq를 죽이지도 다시 띄우지도 않음
lreset; pfa "$PFL"' rm -f $DNSPID; tick; read p0 b < $DNSPID; restart_hostapd; sleep; up; sleep; read p1 b < $DNSPID; echo "same=$([ "$p0" = "$p1" ] && echo y)"; alive' > $PF/hf9 2>&1; lclean
check "  H최종 ⑨(낮음 5): restart_hostapd 뒤 이어진 up()은 살아 있는 dnsmasq를 그대로 둠(새로 띄우지 않음, 죽이지 않음)" '[ "$(grep -c . $PF/lcalls)" = 1 ] && grep -qx "same=y" $PF/hf9 && grep -q "^alive " $PF/hf9 && lleft'
# H최종 ⑩(낮음 5) pid 파일이 남은 채 새 셸(서비스 다시 시작)로 시작: 살아 있으면 그대로, 죽었으면 FIFO로 새로 띄움
lreset; pfa "$PFL"' rm -f $DNSPID; tick' > $PF/hf10a 2>&1; pfa "$PFL"' tick; alive' > $PF/hf10b 2>&1
p0=$(awk '{print $2}' $PF/lcalls | head -1); kill $p0 2>/dev/null; i=0; while [ -d $PF/proc/$p0 ] && [ $i -lt 200 ]; do sleep 0.05; i=$((i+1)); done
pfa "$PFL"' tick; alive' > $PF/hf10c 2>&1; lclean
check "  H최종 ⑩(낮음 5): pid 파일이 남은 채 새 셸로 시작하면 살아 있는 dnsmasq는 그대로, 죽었으면 FIFO로 새로 띄움" '[ "$(grep -c "^fifo " $PF/lcalls)" = 2 ] && ! grep -q "^other " $PF/lcalls && grep -q "^alive " $PF/hf10b && grep -q "^alive " $PF/hf10c && ! grep -q "$FBMSG" $PF/hf10c && lleft'
# --- 묶음 H 재리뷰(중간 1·2, 낮음 2) ---
# 살아 있는 가짜 수와, 살아 있는 것이 pid 파일의 pid인지
lalive() { n=0; for p in $(awk '{print $2}' $PF/lcalls 2>/dev/null); do [ -d $PF/proc/$p ] && n=$((n+1)); done; echo $n; }
lpidok() { read p b < $PF/w/dnsmasq.pid; [ -d $PF/proc/$p ]; }
# 중간 1 재현: 1초 확인이 "죽음"을 돌려준 사이에 그 프로세스가 dnsmasq가 됨 → 예전 방식을 띄우기 전에 끝내야 하나만 산다
lreset; pfa "$PFL"' dns_fifo_died() { sleep; return 0; }; rm -f $DNSPID; tick' > $PF/hr1 2>&1
hr1n=$(lalive); lpidok && hr1p=y || hr1p=n; lclean
check "  H재리뷰 중간 1: 1초 확인이 '죽음'이라 한 사이 dnsmasq가 되어도, 예전 방식을 띄우기 전에 끝내 살아 있는 dnsmasq는 하나이고 pid 파일의 그 pid" '[ "$hr1n" = 1 ] && [ "$hr1p" = y ] && grep -q "^fifo " $PF/lcalls && grep -q "^other " $PF/lcalls && lleft'
# 중간 1(stop_ours): 아직 dnsmasq로 바뀌지 않은 우리 자식(이번 부팅, 부모가 서비스 셸)도 끝내고, 직후 남는 것 0
lreset; echo asshell > $PF/lmode; pfa "$PFL"' dns_fifo_died() { return 1; }; rm -f $DNSPID; tick; stop_ours; echo "pidfile=$([ -f $DNSPID ] && echo y)"' > $PF/hr2 2>&1
hr2n=$(lalive); hr2l=$(lleft && echo y); lclean
check "  H재리뷰 중간 1: stop_ours는 pid 파일의 우리 자식이 아직 dnsmasq가 아니어도 끝냄, 직후 남는 프로세스 0, pid 파일 지움" '[ "$hr2n" = 0 ] && [ "$hr2l" = y ] && grep -qx "pidfile=" $PF/hr2'
lreset; pfa "$PFL"' rm -f $DNSPID; tick; stop_ours' > $PF/hr2b 2>&1; hr2bn=$(lalive); hr2bl=$(lleft && echo y); lclean
check "  H재리뷰 중간 1: stop_ours 직후(따로 기다리지 않고) FIFO dnsmasq가 남지 않음" '[ "$hr2bn" = 0 ] && [ "$hr2bl" = y ]'
pfa 'DNSPID=$W/dnsmasq.pid; mkdir -p $PROC/993; echo "993 (dnsmasq) S 1 1" > $PROC/993/stat; echo "993 boot-P" > $DNSPID; kill() { echo "kill $*"; }; stop_ours; mkdir -p $PROC/994; echo "994 (sh) S 1 1" > $PROC/994/stat; echo "994 boot-P" > $DNSPID; up() { :; }; dns_stuck && echo stuck-killed; echo "995 boot-OLD" > $DNSPID; mkdir -p $PROC/995; echo "995 (sh) S $$ 1" > $PROC/995/stat; dns_stuck && echo old-killed; rm -rf $PROC/993 $PROC/994 $PROC/995 $DNSPID' > $PF/hr2c 2>&1
check "  H재리뷰 중간 1: 이름과 상관없이 끝내는 것은 이번 부팅·부모가 서비스 셸일 때만(부모가 다른 dnsmasq는 예전처럼 pid로만 끔, 다른 부팅 pid는 안 죽임)" 'grep -qx "kill 993" $PF/hr2c && ! grep -q "stuck-killed\|old-killed\|kill 994\|kill 995" $PF/hr2c'
# 중간 2: restart_hostapd(설정 바뀜)로 FIFO를 새로 띄운 같은 회차의 두 번째 up()은 OK로 두지 않고, 다음 회차에서 OK
lreset; pfa "$PFL"' rm -f $DNSPID; TICK_N=5; restart_hostapd; sleep; up; echo "ok1=$DNS_FIFO_OK"; tick; echo "ok2=$DNS_FIFO_OK"' > $PF/hr3 2>&1; lclean
check "  H재리뷰 중간 2: FIFO로 띄운 회차와 같은 회차에서 살아 있음을 봐도 DNS_FIFO_OK가 아니고, 다음 30초 회차에서 OK" 'grep -qx "ok1=" $PF/hr3 && grep -qx "ok2=1" $PF/hr3 && [ "$(grep -c "^fifo " $PF/lcalls)" = 1 ] && lleft'
check "  H재리뷰 중간 2(소스): 서비스 메인 반복이 30초 회차마다 TICK_N을 올림" 'awk "/^  while true; do\$/{f=1} f&&/TICK_N=/{print; exit}" $PKG/svc/hotspot.sh | grep -q "TICK_N=\$((\${TICK_N:-0}+1))"'
# 낮음 2: our_dhcp_on은 읽기 전에 변수를 비우고, 읽기 오류가 새지 않게 { read …; } 2>/dev/null
check "  H재리뷰 낮음 2(소스): our_dhcp_on은 pid 파일·stat을 읽기 전에 변수를 비우고 { read …; } 2>/dev/null 꼴로 읽음" '[ "$(awk "/^our_dhcp_on\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -c "{ read .*; } 2>/dev/null")" = 2 ] && awk "/^our_dhcp_on\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "_dp=; _db=" && awk "/^our_dhcp_on\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -q "_dc=; _ds="'
# 묶음 J 리뷰(낮음): dns_stuck은 끝났는지 1초 간격 세 번까지만 보고 넘어감. TERM을 무시하는 우리 자식(아직 dnsmasq가 아님)에서도
# up()이 돌아오고(시험의 상한 20초 안), 그 자식은 그대로 남아 있음(기다리지 않음). sleep은 몇 번 불렸는지 센다
mkdir -p $PF/binT; printf '#!/bin/sh\ntrap "" TERM\nmkdir -p %s/proc/$$; echo "$$ (sh) S $PPID 1" > %s/proc/$$/stat\necho "t $$" >> %s/tcalls\n: > %s/lstart.$$\nexec /bin/sleep 300\n' $PF $PF $PF $PF > $PF/binT/dnsmasq; chmod +x $PF/binT/dnsmasq
rm -f $PF/tcalls $PF/w/dnsmasq.pid $PF/w/dnsmasq.in
( pfa 'export PATH='$PF'/binT:$PATH; running() { return 0; }; PS=true; DNSPID=$W/dnsmasq.pid; dns_fifo_died() { return 1; }; NS=0
sleep() { NS=$((NS+1)); read _p _b < $DNSPID 2>/dev/null; _i=0; while [ -n "$_p" ] && [ ! -f '$PF'/lstart.$_p ] && [ $_i -lt 200 ]; do command sleep 0.05; _i=$((_i+1)); done; }
up; sleep; NS=0; DNS_FIFO_OK=; up; echo "returned sleeps=$NS"' > $PF/ht1 2>&1 ) & PFW=$!; ( sleep 20; kill $PFW 2>/dev/null ) >/dev/null 2>&1 & PFK=$!; wait $PFW 2>/dev/null; { kill $PFK; wait $PFK; } 2>/dev/null
htn=$(for p in $(awk '{print $2}' $PF/tcalls 2>/dev/null); do kill -0 $p 2>/dev/null && echo $p; done | grep -c .); htp=$(awk 'NR == 1 { print $2 }' $PF/tcalls); htfirst=alive; i=0; while kill -0 $htp 2>/dev/null && [ $i -lt 100 ]; do sleep 0.05; i=$((i+1)); done; kill -0 $htp 2>/dev/null || htfirst=dead; for p in $(awk '{print $2}' $PF/tcalls 2>/dev/null); do kill -9 $p 2>/dev/null; rm -rf $PF/proc/$p; done
check "  묶음 J 리뷰(낮음): TERM을 무시하는 우리 자식이어도 dns_stuck은 1초 간격 세 번만 보고 kill -9를 한 번 보낸 뒤 넘어가 up()이 돌아옴(그 자식은 끝남, 새로 띄운 것은 남음)" 'grep -q "^returned sleeps=" $PF/ht1 && [ "$(sed -n "s/^returned sleeps=//p" $PF/ht1)" -le 4 ] && [ "$htn" -ge 1 ] && [ "$htfirst" = dead ]'
# 묶음 H 최종: FIFO 쪽은 eval 한 줄, 예전 방식은 세 줄. 옵션 낱말을 뽑아 비교한다(FIFO 쪽의 따옴표 "$WIF"만 맞춤)
PFA1=$(sed -n "s/^ *eval 'dnsmasq \(.*\) >\/dev\/null 2>&1 <> .*/\1/p" $PKG/svc/hotspot.sh | sed 's/"//g' | tr -s ' ' '\n')
PFA2=$(awk '/^ *dnsmasq --keep-in-foreground/ { f = 1 } f { s = s " " $0 } f && /dhcp-option=6 >\/dev\/null 2>&1 &$/ { print s; exit }' $PKG/svc/hotspot.sh | sed 's/\\//g; s/^ *dnsmasq //; s/ >\/dev\/null 2>&1 &$//' | tr -s ' ' '\n' | grep .)
check "  리뷰 L1·묶음 H 최종: dnsmasq 옵션 두 벌이 글자까지 같음(표준입력 리다이렉션만 다름)" '[ -n "$PFA1" ] && [ "$PFA1" = "$PFA2" ] && [ "$(printf "%s\n" "$PFA1" | grep -c .)" = 10 ]'
check "  PF-1(소스)·묶음 H 최종: dnsmasq를 파이프로 띄우지 않음(왼쪽 프로세스가 남지 않게), 띄우는 곳은 dns_launch 두 갈래뿐(예전 방식 한 줄, FIFO는 eval 한 줄)" '[ "$(grep -c "^ *dnsmasq --keep-in-foreground" $PKG/svc/hotspot.sh)" = 1 ] && ! grep -q "| *dnsmasq --keep" $PKG/svc/hotspot.sh && [ "$(grep -c "^ *eval .dnsmasq --keep-in-foreground .* >/dev/null 2>&1 <> \"[$]DNSIN\" &.$" $PKG/svc/hotspot.sh)" = 1 ] && [ "$(grep -v "^ *#" $PKG/svc/hotspot.sh | grep -v "^DNSMASQ=" | grep -c "dnsmasq --keep-in-foreground")" = 2 ]'
# PF-5: /proc/net/dev 줄 꼴(이름 앞 탭, 콜론 뒤에 바로 숫자, 칸이 모자란 줄)
pfreset; printf '\twlan0:1 1000 0 0 0 0 0 0 1 2000 0 0 0 0 0 0\n' > $PF/net/dev
pf 'perf_begin; perf_tick; printf "wlan0:1 1030 0 2 0 0 0 0 1 2040 0 1 0 0 0 0\n" > $PROCNET/dev; perf_tick; printf " wlan0: 1 1040 0 2\n" > $PROCNET/dev; perf_tick' > $PF/out 2>&1
check "PF-5: Wi-Fi 줄 고르기 — 이름 앞이 탭이거나 줄 맨 앞이어도, 콜론 뒤에 숫자가 붙어도 읽음. 칸이 모자라면 보낸 쪽만 '-'" '[ ! -s $PF/out ] && [ "$(sed -n 2p $PF/w/perf.log | grep -c " rx=30 tx=40 rxe=0 rxd=2 txe=0 txd=1 ")" = 1 ] && [ "$(sed -n 3p $PF/w/perf.log | grep -c " rx=10 tx=- rxe=0 rxd=0 txe=- txd=- ")" = 1 ]'
check "  PF-5(소스): perf_tick에 continue와 두 자리 위치 인자가 없음" '[ "$(awk "/^perf_tick\(\) \{/,/^}/" $PKG/svc/hotspot.sh | grep -v "^ *#" | grep -c -E "continue|\\$\{1[0-9]\}")" = 0 ]'

echo "---"
[ $fails -eq 0 ] && echo "모두 통과" || { echo "실패 $fails개"; exit 1; }
