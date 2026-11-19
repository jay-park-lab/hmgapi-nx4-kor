#!/bin/sh
# PC(맥)에서 standalone/(NEMESIS 없이 HMG-API 모드로 설치, 투싼 NX4) 스크립트를 가짜 헤드유닛으로 돌린다.
#   sh tests/standalone-test.sh                 스크립트 시험(실패하면 FAIL 줄과 종료 코드 1)
#   HMGAPI_SRC=<HMG-API 저장소> sh tests/standalone-test.sh
#                                               + 임시 키로 scripts/build-standalone.sh를 끝까지 돌리고, 만든 모드를 HMG-API 엔진
#                                                 (PC JVM)에 설치해 서비스·앱 등록과 차종 제한(NX4.KOR 260902만)을 본다
# 가짜 도구: hmgapid, pm, am, getprop, settings, svc, sleep. 실제 NEMESIS판 스크립트(post.sh·preun.sh·hotspot.sh)는 고친 부분만 직접 돌린다.
B=$(cd "$(dirname "$0")/.." && pwd)
SA=$B/standalone
PKG=$B/nemesis-pkg/korea.projection
T=$(mktemp -d /tmp/kp-sa.XXXXXX)
# KEEP=1: 시험 폴더를 남긴다(실패 원인 보기)
if [ -n "$KEEP" ]; then echo "시험 폴더: $T"; else trap 'rm -rf $T' EXIT; fi
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails+1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# --- 구문 검사: 차의 셸은 mksh. 있는 ksh 계열과 dash로 본다(stub-test.sh와 같은 이유) ---
KSHS=$(for s in mksh ksh dash; do command -v $s; done)
[ -n "$KSHS" ] || bad "구문 검사: mksh/ksh/dash 없음"
for f in $SA/nx4-kor/standalone/*.sh $SA/usb/troubleShooter $B/scripts/build-standalone.sh \
         $PKG/scripts/post.sh $PKG/scripts/preun.sh $PKG/bin/status.sh $PKG/svc/hotspot.sh; do
  for KSH in $KSHS; do check "구문 검사 $(basename $KSH): ${f#$B/}" '$KSH -n $f'; done
done

# --- mod.json ---
check "mod.json: JSON, 서비스 스크립트가 있음, 앱 경로가 hotspot.sh의 APK_SRC와 같음, NX4.KOR 260902만" 'python3 - "$SA/nx4-kor/mod.json" "$SA/nx4-kor" "$PKG/svc/hotspot.sh" <<PY
import json, os, re, sys
m = json.load(open(sys.argv[1]))
assert m["id"] == "nx4-kor"
for s in m["services"]:
    assert os.path.isfile(os.path.join(sys.argv[2], s["script"])), s
assert {s["name"]: s["start"] for s in m["services"]} == {"ap": "android", "launch": "manual"}
assert all(s["user"] == "root" for s in m["services"])
src = re.search(r"^APK_SRC=\\\$\{APK_SRC:-\\\$APP/(.*)\}$", open(sys.argv[3]).read(), re.M).group(1)
assert m["apps"] == [{"apk": src, "package": "io.github.jayparklab.nx4kor"}], (m["apps"], src)
assert m["system"] == {"model": ["NX4", "NX4HEV"], "region": ["KOR"], "firmware": ["260902"]}
assert m["provides"]["launcher"][0]["class"] == ".StatusActivity"
PY'
check "mod.json 판 = NEMESIS.data package-version" '[ "$(sed -n "s/^package-version=//p" $PKG/NEMESIS.data)" = "$(sed -n "s/^ *\"version\": *\"\([^\"]*\)\".*/\1/p" $SA/nx4-kor/mod.json | head -1)" ]'
check "launch 서비스 이름 = 앱이 부르는 이름" 'grep -q "\"service-start\", \"launch\"" $B/nemesis-pkg/app-src/java/io/github/jayparklab/nx4kor/StatusActivity.java'

# --- 가짜 도구 ---
mkdir -p $T/bin
HD=$T/root/data/hmgapi
cat > $T/bin/hmgapid <<E
#!/bin/sh
echo "hmgapid \$*" >> $T/calls
case "\$1 \$2" in
  "ping "*) exit 0 ;;
  "engine install")
    [ -f $T/install-fail ] && { echo "refused: test"; exit 1; }
    rm -rf $HD/mods/nx4-kor; mkdir -p $HD/mods/nx4-kor
    (cd $HD/mods/nx4-kor && unzip -q "\$3") || exit 1
    : > $T/app-ready
    echo "installed nx4-kor"; exit 0 ;;
  "engine remove") rm -rf $HD/mods/\$3; rm -f $T/app-ready; echo "removed \$3"; exit 0 ;;
  "service-stop "*) rm -f $T/ap-running; echo "stop: asked"; exit 0 ;;
  "service-start "*) echo "start: asked"; exit 0 ;;
  "services "*) [ -f $T/ap-running ] && echo "nx4-kor ap running 123 0"; echo "nx4-kor launch stopped 0 0"; exit 0 ;;
esac
exit 0
E
cat > $T/bin/pm <<E
#!/bin/sh
echo "pm \$*" >> $T/calls
[ "\$1" = path ] && [ -f $T/app-ready ] && echo "package:/data/app/io.github.jayparklab.nx4kor-1.apk"
exit 0
E
cat > $T/bin/am <<E
#!/bin/sh
echo "am \$*" >> $T/calls
exit 0
E
cat > $T/bin/getprop <<E
#!/bin/sh
case "\$1" in
  ro.build.product) echo NX4.KOR.0000.V039.001.260902 ;;
  sys.boot_completed) echo 1 ;;
  *) echo ;;
esac
E
cat > $T/bin/settings <<E
#!/bin/sh
echo "settings \$*" >> $T/calls
[ "\$1" = get ] && echo 1
exit 0
E
cat > $T/bin/svc <<E
#!/bin/sh
echo "svc \$*" >> $T/calls
E
# busybox 대신: 받은 명령을 그대로 실행(stub-test.sh의 bb와 같은 뜻)
printf '#!/bin/sh\ncommand -v "$1" >/dev/null 2>&1 || exit 127\nexec "$@"\n' > $T/bin/bb
chmod +x $T/bin/*
P0=$T/bin:/usr/bin:/bin:/usr/sbin:/sbin

# 가짜 패키지 파일(모드 폴더): standalone 래퍼는 진짜, NEMESIS판 스크립트 자리에는 받은 환경을 적는 가짜
mkfix() {
  rm -rf $1; mkdir -p $1/scripts $1/svc $1/bin $1/app
  cp -R $SA/nx4-kor/. $1/
  for s in scripts/post.sh scripts/preun.sh svc/hotspot.sh bin/status.sh; do
    printf '#!/bin/sh\necho "%s KP_APP=$KP_APP APP=$APP BK=$BK APLOG=$APLOG KP_APP_BY_HMGAPI=$KP_APP_BY_HMGAPI KP_UPDATE=$KP_UPDATE KP_APLOG=$KP_APLOG" >> %s/stublog\necho "out of %s"\n' $s $T $s > $1/$s
  done
  echo apk > $1/app/NX4KOR.apk
}

# --- ap.sh ---
F=$T/mod; mkfix $F
apr() { (env -u KP_APP PATH=$P0 HMGAPI_MOD_DIR=$F KP_ROOT=$T/kp KP_NEMESIS_PKG=$T/nemesis/korea.projection sh $F/standalone/ap.sh) > $T/ap.out 2>&1; }
rm -f $T/stublog; apr
check "ap.sh: 처음에 post.sh를 한 번 돌리고 표시(post.done)를 남김" 'grep -q "^scripts/post.sh" $T/stublog && [ -f $T/kp/backup/post.done ]'
check "ap.sh: hotspot.sh에 standalone 위치를 넘김(APP=모드 폴더, BK·APLOG는 /data/nx4-kor 아래, KP_APP_BY_HMGAPI=1)" \
  'grep -q "^svc/hotspot.sh KP_APP=$F APP=$F BK=$T/kp/backup APLOG=$T/kp/logs/ap.log KP_APP_BY_HMGAPI=1 KP_UPDATE= KP_APLOG=$T/kp/logs/ap.log" $T/stublog'
check "ap.sh: hotspot.sh 출력은 APLOG로(덧붙이기), 래퍼의 줄은 hmgapid 기록으로" 'grep -q "out of svc/hotspot.sh" $T/kp/logs/ap.log && ! grep -q "out of svc/hotspot.sh" $T/ap.out && grep -q "hotspot.sh 시작" $T/ap.out'
rm -f $T/stublog; apr
check "ap.sh: 두 번째 시작에는 post.sh를 다시 돌리지 않음" '! grep -q "^scripts/post.sh" $T/stublog && grep -q "^svc/hotspot.sh" $T/stublog'
# NEMESIS판이 있으면 대기만: 가짜 sleep이 부른 셸을 끝낸다
mkdir -p $T/nemesis/korea.projection $T/sb
printf '#!/bin/sh\necho slept >> %s/slept\nkill -TERM $PPID\nexit 0\n' $T > $T/sb/sleep; chmod +x $T/sb/sleep
rm -f $T/stublog $T/slept
(env -u KP_APP PATH=$T/sb:$P0 HMGAPI_MOD_DIR=$F KP_ROOT=$T/kp2 KP_NEMESIS_PKG=$T/nemesis/korea.projection sh $F/standalone/ap.sh) > $T/ap.out 2>&1
check "ap.sh: NEMESIS판 패키지가 있으면 아무것도 하지 않고 대기(끝내지 않음)" '[ -f $T/slept ] && [ ! -f $T/stublog ] && grep -q "NEMESIS판" $T/ap.out'

# --- launch.sh ---
rm -f $T/stublog
(env -u KP_APP PATH=$P0 HMGAPI_MOD_DIR=$F KP_ROOT=$T/kp KP_NEMESIS_PKG=$T/none sh $F/standalone/launch.sh) > $T/l.out 2>&1
check "launch.sh: bin/status.sh를 standalone 위치로 돌림(KP_APLOG로 ap.log 위치를 넘김)" 'grep -q "^bin/status.sh KP_APP=$F APP=$F BK=$T/kp/backup APLOG=$T/kp/logs/ap.log KP_APP_BY_HMGAPI=1 KP_UPDATE= KP_APLOG=$T/kp/logs/ap.log" $T/stublog'

# --- uninstall.sh ---
ur() { (env -u KP_APP PATH=$P0 HMGDATA=$HD KP_ROOT=$T/kp KP_NEMESIS_PKG=$T/none sh $1/standalone/uninstall.sh $2) > $T/u.out 2>&1; echo $? > $T/u.rc; }
mkdir -p $HD/mods; rm -rf $HD/mods/nx4-kor; cp -R $F $HD/mods/nx4-kor; I=$HD/mods/nx4-kor
mkdir -p $T/kp/backup; : > $T/kp/backup/post.done; : > $T/ap-running; : > $T/calls; rm -f $T/stublog
ur $I --update
check "uninstall.sh --update: 서비스 ap를 멈추고 멈출 때까지 기다림" 'grep -qx "hmgapid service-stop nx4-kor ap" $T/calls && grep -q "hmgapid services nx4-kor" $T/calls'
check "uninstall.sh --update: preun.sh를 KP_UPDATE=1로(업데이트 갈래), 모드는 지우지 않음, post.done을 지워 새 판이 post.sh를 다시 돌리게" \
  'grep -q "^scripts/preun.sh KP_APP=$I .*KP_UPDATE=1" $T/stublog && ! grep -q "engine remove" $T/calls && [ -d $I ] && [ ! -f $T/kp/backup/post.done ] && [ "$(cat $T/u.rc)" = 0 ]'
: > $T/calls; rm -f $T/stublog
ur $I
check "uninstall.sh: preun.sh(삭제 갈래) → engine remove → /data/nx4-kor 지움" \
  'grep -q "^scripts/preun.sh KP_APP=$I .*KP_UPDATE= " $T/stublog && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $I ] && [ ! -d $T/kp ] && [ "$(cat $T/u.rc)" = 0 ]'
# NEMESIS판이 있으면 preun.sh(그쪽 핫스팟을 멈춤)를 돌리지 않고 모드만 지움
cp -R $F $I; mkdir -p $T/kp; : > $T/calls; rm -f $T/stublog
(env -u KP_APP PATH=$P0 HMGDATA=$HD KP_ROOT=$T/kp KP_NEMESIS_PKG=$T/nemesis/korea.projection sh $I/standalone/uninstall.sh) > $T/u.out 2>&1
check "uninstall.sh: NEMESIS판이 있으면 preun.sh를 돌리지 않고 모드만 지움" '[ ! -f $T/stublog ] && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $T/kp ]'
# HMG-API를 먼저 지운 경우(hmgapid 명령·installed.txt 없음): preun.sh는 그대로 돌리고, 남은 모드 폴더를 직접 지우고, 앱은 pm으로 지움
cp -R $F $I; mkdir -p $T/kp; : > $T/calls; rm -f $T/stublog
(env -u KP_APP PATH=$P0 HMGAPID=$T/nohmgapid HMGDATA=$HD KP_ROOT=$T/kp KP_NEMESIS_PKG=$T/none sh $I/standalone/uninstall.sh) > $T/u.out 2>&1; echo $? > $T/u.rc
check "uninstall.sh: HMG-API를 먼저 지웠으면 preun.sh로 되돌리고, 남은 모드 폴더·앱(pm)을 직접 지움(hmgapid 안 부름)" \
  '[ "$(cat $T/u.rc)" = 0 ] && grep -q "^scripts/preun.sh KP_APP=$I .*KP_UPDATE= " $T/stublog && ! grep -q "^hmgapid" $T/calls && grep -qx "pm uninstall io.github.jayparklab.nx4kor" $T/calls && [ ! -d $I ] && [ ! -d $T/kp ] && grep -q "HMG-API가 먼저 지워져" $T/u.out'

# --- troubleShooter(USB 설치기) ---
R=$T/root; U=$T/usb0; K=$U/NX4
mkdir -p $R/data/local/tmp $K/install/payload
cp -R $F/. $K/install/payload/
(cd $K/install/payload && zip -q -r $K/install/hmgapi-nx4-kor.zip .)
ts() { : > $T/calls; (env -u KP_APP PATH=$P0 ROOT=$R HMGAPID=$T/bin/hmgapid KP_USB_DIRS="$1" KP_APP_WAIT=4 KP_NEMESIS_PKG=${NEM:-$T/none} sh $SA/usb/troubleShooter) > $T/ts.out 2>&1; echo $? > $T/ts.rc; }
rm -rf $HD/mods/nx4-kor $R/data/nx4-kor
ts $T/nostick
check "USB 설치기: NX4 폴더가 없으면 아무것도 하지 않음" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "NX4 폴더가 없습니다" $T/ts.out && [ ! -s $T/calls ]'
mv $HD $T/hd.away
ts $U
check "USB 설치기: HMG-API가 없으면 멈춤(설치 안 함)" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "HMG-API가 없습니다" $T/ts.out && ! grep -q "engine install" $T/calls'
mkdir -p $K/hmgapi $U/HMGAPI/install/payload; echo "# hmg-api" > $K/hmgapi/troubleShooter
ts $U
check "USB 설치기: HMG-API가 없고 같은 스틱에 HMG-API 설치기가 있으면 그것으로 넘김" '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "HMG-API 설치기로 넘김" $T/ts.out'
rm -rf $K/hmgapi $U/HMGAPI; mv $T/hd.away $HD
ts $U
check "USB 설치기: 새로 설치 → engine install, 앱이 깔리면 상태 화면을 엶, 재부팅하지 않음, 기록을 스틱에" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^hmgapid engine install .*/data/local/tmp/nx4-kor-usb/nx4-kor.zip" $T/calls && grep -q "^am start -n io.github.jayparklab.nx4kor/.StatusActivity" $T/calls && ! grep -q "service-stop" $T/calls && [ -f $HD/mods/nx4-kor/mod.json ] && grep -q "설치됨: 1.7.4" $K/install.log && [ ! -d $R/data/local/tmp/nx4-kor-usb ]'
ts $U
check "USB 설치기: 같은 판이 있으면 다시 설치하지 않고 상태 화면만 엶" '[ "$(cat $T/ts.rc)" = 0 ] && ! grep -q "engine install" $T/calls && grep -q "^am start" $T/calls && grep -q "이미 설치되어" $T/ts.out'
: > $K/REINSTALL; : > $T/ap-running; rm -f $T/stublog
ts $U
check "USB 설치기: REINSTALL이면 예전 판 정리(uninstall.sh --update) → engine install → 서비스 ap 다시 시작" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "KP_UPDATE=1" $T/stublog && grep -q "^hmgapid engine install" $T/calls && grep -qx "hmgapid service-start nx4-kor ap" $T/calls'
rm -f $K/REINSTALL
sed 's/"version": "1.7.4"/"version": "1.7.3"/' $HD/mods/nx4-kor/mod.json > $T/mj && mv $T/mj $HD/mods/nx4-kor/mod.json
: > $T/install-fail
ts $U
check "USB 설치기: 업데이트 설치가 거절되면 실패로 끝내고 예전 판의 서비스를 다시 띄움" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "설치 실패" $T/ts.out && grep -qx "hmgapid service-start nx4-kor ap" $T/calls'
rm -f $T/install-fail
mkdir -p $T/nemesis/korea.projection
NEM=$T/nemesis/korea.projection
ts $U
NEM=
check "USB 설치기: NEMESIS판이 있으면 설치하지 않음" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "NEMESIS판 Korea Projection이 설치되어" $T/ts.out && ! grep -q "engine install" $T/calls'
# 지우기
: > $K/UNINSTALL; : > $T/ap-running; rm -f $T/stublog; mkdir -p $R/data/nx4-kor/backup
ts $U
check "USB 설치기: UNINSTALL이면 설치된 모드의 uninstall.sh로 되돌리고 모드를 지움" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh KP_APP=$HD/mods/nx4-kor " $T/stublog && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && grep -q "지웠습니다" $T/ts.out'
ts $U
check "USB 설치기: 지울 것이 없으면 아무것도 하지 않음" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "설치되어 있지 않습니다" $T/ts.out && ! grep -q "engine remove" $T/calls'
# 모드는 HMG-API 앱에서 먼저 지웠고 되돌릴 기록만 남은 경우: 스틱의 사본(/data로 복사)으로 되돌림
mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog
ts $U
check "USB 설치기: 모드가 이미 지워졌어도 기록이 남았으면 스틱의 사본으로 되돌림" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh KP_APP=$R/data/local/tmp/nx4-kor-usb/payload " $T/stublog && [ ! -d $R/data/nx4-kor ] && [ ! -d $R/data/local/tmp/nx4-kor-usb ]'
# HMG-API를 먼저 지운 뒤(hmgapid 없음): 일반 삭제는 모드 폴더를 남긴다 → 그 폴더의 uninstall.sh로, purge는 /data/hmgapi째 없다 → 스틱 사본으로
ts0() { : > $T/calls; (env -u KP_APP PATH=$P0 ROOT=$R HMGAPID=$T/nohmgapid KP_USB_DIRS=$U KP_APP_WAIT=4 KP_NEMESIS_PKG=$T/none sh $SA/usb/troubleShooter) > $T/ts.out 2>&1; echo $? > $T/ts.rc; }
mkdir -p $HD/mods $R/data/nx4-kor/backup; cp -R $F $HD/mods/nx4-kor; rm -f $HD/installed.txt $T/stublog
ts0
check "USB 설치기: HMG-API를 먼저 지운 뒤(일반 삭제)에도 UNINSTALL이 됨: 남은 모드 폴더의 uninstall.sh로 되돌리고 모드 폴더·앱을 지움" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh KP_APP=$HD/mods/nx4-kor " $T/stublog && ! grep -q "^hmgapid" $T/calls && grep -qx "pm uninstall io.github.jayparklab.nx4kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && [ ! -d $R/data/nx4-kor ] && grep -q "지웠습니다" $T/ts.out && grep -q "HMG-API가 없음" $K/install.log'
mv $HD $T/hd.purged; mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog
ts0
check "USB 설치기: HMG-API를 먼저 완전 삭제(--purge)한 뒤에도 기록이 남았으면 스틱의 사본으로 되돌림" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh KP_APP=$R/data/local/tmp/nx4-kor-usb/payload " $T/stublog && ! grep -q "^hmgapid" $T/calls && [ ! -d $R/data/nx4-kor ]'
mv $T/hd.purged $HD
rm -f $K/UNINSTALL

# --- 고친 NEMESIS판 스크립트(진짜) ---
# 차의 PATH로 바꾸는 맨 윗줄만 시험용 PATH로 바꾼 사본으로 돌린다(stub-test.sh와 같은 방법). 나머지는 그대로
TP=$T/pkg; rm -rf $TP; cp -R $PKG $TP
for f in svc/hotspot.sh scripts/post.sh scripts/preun.sh bin/status.sh; do
  sed "s#^export PATH=.*#export PATH=$P0#" $PKG/$f > $TP/$f
done
# hotspot.sh: HMG-API가 앱을 맡으면 install_app·remove_app이 pm을 부르지 않음
: > $T/calls
(PATH=$P0 HOTSPOT_LIB=1 BB=$T/bin/bb APP=$TP W=$T/hw BK=$T/hbk KP_APP_BY_HMGAPI=1 sh -c ". $TP/svc/hotspot.sh; install_app && remove_app; echo rc=\$?") > $T/h.out 2>&1
check "hotspot.sh: KP_APP_BY_HMGAPI=1이면 install_app·remove_app이 pm을 부르지 않음(앱은 HMG-API가 설치·삭제)" 'grep -q "^rc=0" $T/h.out && ! grep -q "^pm" $T/calls'
: > $T/calls
(PATH=$P0 HOTSPOT_LIB=1 BB=$T/bin/bb APP=$TP W=$T/hw BK=$T/hbk sh -c ". $TP/svc/hotspot.sh; remove_app") > $T/h.out 2>&1
check "hotspot.sh: NEMESIS판(KP_APP_BY_HMGAPI 없음)은 예전처럼 pm uninstall" 'grep -qx "pm uninstall io.github.jayparklab.nx4kor" $T/calls'
# post.sh: KP_APP·BK를 받으면 그 위치로(설치 전 Wi-Fi 상태 기록), 앱은 설치하지 않음
: > $T/calls; rm -rf $T/pbk
(env PATH=$P0 BB_SYS=$T/bin/bb KP_APP=$TP BK=$T/pbk W=$T/pw NOTICE=$T/pnotice KP_APP_BY_HMGAPI=1 sh $TP/scripts/post.sh) > $T/p.out 2>&1
check "post.sh: standalone이면 BK에 설치 전 Wi-Fi 상태를 적고 앱은 설치하지 않음(pm install 없음)" '[ "$(cat $T/pbk/wifi_on 2>/dev/null)" = 1 ] && grep -qx "settings get global wifi_on" $T/calls && ! grep -q "^pm install" $T/calls' || cat $T/p.out
# preun.sh: KP_UPDATE=1이면 업데이트 갈래(작업 파일만 지우고 BK·모드는 그대로)
mkdir -p $T/ubk; : > $T/ubk/keep; : > $T/calls
(env PATH=$P0 BB_SYS=$T/nobb KP_APP=$TP BK=$T/ubk W=$T/uw CONF=$T/uconf HINT=$T/uhint PROG=$T/uprog NOTICE=$T/unotice HMGDATA=$HD KP_APP_BY_HMGAPI=1 KP_UPDATE=1 sh $TP/scripts/preun.sh) > $T/pu.out 2>&1
echo $? > $T/pu.rc
check "preun.sh: KP_UPDATE=1이면 업데이트 갈래로 끝나고 BK를 남김, 모드를 지우지 않음" '[ "$(cat $T/pu.rc)" = 0 ] && grep -q "업데이트(HMG-API 모드): 이전 판 정리" $T/pu.out && [ -f $T/ubk/keep ] && ! grep -q "engine remove" $T/calls'
check "preun.sh: NEMESIS 갈래의 '업데이트: 이전 버전 정리' 문구는 한 줄뿐(stub-test가 그 줄 번호로 순서를 봄)" '[ "$(grep -c "업데이트: 이전 버전 정리" $PKG/scripts/preun.sh)" = 1 ]'
# preun.sh: HMG-API를 먼저 지웠으면(hmgapid 명령도 installed.txt도 없음) 남은 무선 모드 폴더를 지우고 끝까지 간다.
# hmgapid가 없는 PATH로 돌린다(그 밖의 가짜 도구는 같음)
mkdir -p $T/bin2; for b in $T/bin/*; do [ "${b##*/}" = hmgapid ] || cp $b $T/bin2/; done
P2=$T/bin2:/usr/bin:/bin:/usr/sbin:/sbin
TP2=$T/pkg2; rm -rf $TP2; cp -R $PKG $TP2
for f in svc/hotspot.sh scripts/preun.sh; do sed "s#^export PATH=.*#export PATH=$P2#" $PKG/$f > $TP2/$f; done
pg() { (env PATH=$P2 BB_SYS=$T/nobb KP_APP=$TP2 BK=$T/gbk W=$T/gw CONF=$T/gconf HINT=$T/ghint PROG=$T/gprog NOTICE=$T/gnotice HMGDATA=$T/gh KP_APP_BY_HMGAPI=1 sh $TP2/scripts/preun.sh) > $T/pg.out 2>&1; }
pgreset() { rm -rf $T/gh $T/gbk; mkdir -p $T/gh/mods/wireless-carplay-aa $T/gbk; echo '{"system": [{"region": "KOR"}]}' > $T/gh/mods/wireless-carplay-aa/mod.json; : > $T/gbk/mod.ours; : > $T/calls; }
pgreset; pg
check "preun.sh: HMG-API를 먼저 지웠으면 남은 무선 모드 폴더를 지우고 '데몬 응답 없음'으로 멈추지 않음(권한 파일 되돌리기로 감), BK 지움" \
  '[ ! -d $T/gh/mods/wireless-carplay-aa ] && grep -q "HMG-API가 먼저 지워져 있음: 남은 무선 모드 폴더를 지움" $T/pg.out && ! grep -q "데몬 응답 없음" $T/pg.out && ! grep -q "되돌리기 건너뜀" $T/pg.out && [ ! -d $T/gbk ]' || cat $T/pg.out
pgreset; : > $T/gh/installed.txt; pg
check "preun.sh: HMG-API 설치 기록이 남아 있는데 hmgapid가 안 되면 예전처럼 '데몬 응답 없음'(모드 폴더를 지우지 않음)" \
  '[ -d $T/gh/mods/wireless-carplay-aa ] && grep -q "데몬 응답 없음" $T/pg.out'
# status.sh: 고친 곳
check "status.sh: KP_APLOG가 있으면 APLOG를 그 위치로(NEMESIS 위치 줄은 그대로 두어 stub-test의 바꾸기가 맞게)" 'grep -q "^APLOG=/data/nemesis/logs/korea.projection/ap.log$" $PKG/bin/status.sh && grep -q "^\[ -n \"\$KP_APLOG\" \] && APLOG=\$KP_APLOG$" $PKG/bin/status.sh'
# NEMESIS 버전 로직은 걷어냈다: 수집(nemesis version)·판정(oldnemesis, 1.16)·상태 파일 키(nemesis=)·앱의 최소 버전·표 칸·QR 키
check "NEMESIS 버전 로직 없음(status.sh·앱 Report·standalone)" \
  '! grep -rnE --exclude=README.md "nemesis version|K_NEM|oldnemesis|nemesis=|1\.16|MIN_NEMESIS|\"nemesis\"|KP_STANDALONE" $PKG/bin $PKG/svc $PKG/scripts $B/nemesis-pkg/app-src $SA'

# --- 끝까지: 빌드 → HMG-API 엔진에 설치(HMGAPI_SRC가 있을 때만) ---
if [ -n "$HMGAPI_SRC" ]; then
  HS=$(cd "$HMGAPI_SRC" && pwd)
  mkdir -p $T/eh && javac --release 8 -Xlint:-options -nowarn -d $T/eh $HS/core/runtime/java/hmgapi/engine/*.java 2>/dev/null
  java -cp $T/eh hmgapi.engine.Signing keygen $T/test-mod.key >/dev/null 2>&1
  echo "not a real apk" > $T/test.apk
  printf '\177ELF fake busybox' > $T/test-bb
  # HMG-API USB 묶음 흉내(HMGAPI/install/payload, ota_package.tar 안의 troubleShooter)
  mkdir -p $T/hu/HMGAPI/install/payload; echo "# HMG-API troubleShooter" > $T/hu/troubleShooter; echo 1.1.0 > $T/hu/HMGAPI/install/payload/VERSION
  python3 -c 'import tarfile,sys; t=tarfile.open(sys.argv[1],"w"); t.add(sys.argv[2],"troubleShooter"); t.close()' $T/hu/ota_package.tar $T/hu/troubleShooter
  printf '[nemesis]\n' > $T/hu/NEMESIS.data; echo hmgapi > $T/hu/README.txt; rm $T/hu/troubleShooter
  (cd $T/hu && zip -q -r $T/hmgapi-usb.zip .)
  bld() { (HMGAPI_SRC=$HS KP_MOD_KEY=$T/test-mod.key KP_APK=$T/test.apk HMGAPI_USB_ZIP=$T/hmgapi-usb.zip "$@" sh $B/scripts/build-standalone.sh) > $T/build.out 2>&1; echo $? > $T/build.rc; }
  # busybox(GPL-2.0)를 넣는데 그 라이선스 안내가 없으면 만들지 않는다
  bld env KP_BUSYBOX=$T/test-bb OUT=$T/out-nolic
  check "빌드: busybox를 넣는데 라이선스 안내가 없으면 만들지 않음" '[ "$(cat $T/build.rc)" != 0 ] && grep -q "라이선스 안내" $T/build.out && [ ! -f $T/out-nolic/hmgapi-nx4-kor-1.7.4-usb.zip ]'
  echo "BusyBox GPL-2.0 test notice" > $T/test-bb-LICENSE.txt
  bld env KP_BUSYBOX=$T/test-bb OUT=$T/out
  check "빌드: 모드 zip과 USB 묶음을 만듦" '[ "$(cat $T/build.rc)" = 0 ] && [ -f $T/out/hmgapi-nx4-kor-1.7.4.zip ] && [ -f $T/out/hmgapi-nx4-kor-1.7.4-usb.zip ]' || cat $T/build.out
  rm -rf $T/ux; mkdir -p $T/ux; (cd $T/ux && unzip -q $T/out/hmgapi-nx4-kor-1.7.4-usb.zip)
  check "USB 묶음: ota_package.tar = 우리 troubleShooter(0755, root), HMG-API 설치기는 NX4/hmgapi로, NEMESIS.data 뺌, README 판 채움" \
    'python3 -c "import tarfile,sys; t=tarfile.open(sys.argv[1]); m=t.getmembers(); assert [x.name for x in m]==[\"troubleShooter\"] and m[0].mode==0o755 and m[0].uid==0; assert t.extractfile(\"troubleShooter\").read()==open(sys.argv[2],\"rb\").read()" $T/ux/ota_package.tar $SA/usb/troubleShooter && grep -q "HMG-API troubleShooter" $T/ux/NX4/hmgapi/troubleShooter && [ ! -f $T/ux/NEMESIS.data ] && [ -d $T/ux/HMGAPI/install/payload ] && grep -q "HMG-API NX4 KOR 1.7.4" $T/ux/README.txt'
  check "USB 묶음: payload = 서명된 모드를 푼 것(mod.json, 래퍼, NEMESIS판 스크립트, 앱, busybox, 서명), 다른 차 map은 뺌" \
    '[ -f $T/ux/NX4/install/payload/mod.json ] && [ -f $T/ux/NX4/install/payload/standalone/ap.sh ] && [ -f $T/ux/NX4/install/payload/svc/hotspot.sh ] && [ -f $T/ux/NX4/install/payload/app/NX4KOR.apk ] && [ -f $T/ux/NX4/install/payload/bin/busybox ] && [ -d $T/ux/NX4/install/payload/META-HMGAPI ] && [ ! -d $T/ux/NX4/install/payload/hmgapi/maps ] && [ -f $T/ux/NX4/install/payload/hmgapi/wireless-carplay-aa.zip ]'
  P=$T/ux/NX4/install/payload
  check "라이선스: 모드에 LICENSE·NOTICE.md·bin/busybox-LICENSE.txt, USB 맨 위에 LICENSE·NOTICE.md·BUSYBOX-LICENSE.txt(저장소와 같은 내용)" \
    'cmp -s $P/LICENSE $B/LICENSE && cmp -s $P/NOTICE.md $B/NOTICE.md && cmp -s $P/bin/busybox-LICENSE.txt $T/test-bb-LICENSE.txt && cmp -s $T/ux/LICENSE $B/LICENSE && cmp -s $T/ux/NOTICE.md $B/NOTICE.md && cmp -s $T/ux/BUSYBOX-LICENSE.txt $T/test-bb-LICENSE.txt'
  check "라이선스: HMG-API를 함께 넣으면 HMGAPI-SOURCE.txt에 판과 대응 소스(태그), README.txt에 이 묶음의 소스 커밋" \
    'grep -q "^HMG-API 1.1.0:" $T/ux/HMGAPI-SOURCE.txt && grep -q "https://github.com/Open-HMG/HMG-API/tree/v1.1.0" $T/ux/HMGAPI-SOURCE.txt && grep -q "AGPL-3.0" $T/ux/HMGAPI-SOURCE.txt && grep -q "https://github.com/jay-park-lab/hmgapi-nx4-kor (이 묶음: [0-9a-f]\{7,\}" $T/ux/README.txt && ! grep -q "@SOURCE_REV@" $T/ux/README.txt'
  # busybox 없이 만들면 그 안내도 없다(HMG-API도 함께 넣지 않으면 HMGAPI-SOURCE.txt도 없다)
  (HMGAPI_SRC=$HS KP_MOD_KEY=$T/test-mod.key KP_APK=$T/test.apk KP_BUSYBOX=$T/nobb OUT=$T/out-nobb sh $B/scripts/build-standalone.sh) > $T/build.out 2>&1; echo $? > $T/build.rc
  rm -rf $T/ux2; mkdir -p $T/ux2; (cd $T/ux2 && unzip -q $T/out-nobb/hmgapi-nx4-kor-1.7.4-usb.zip 2>/dev/null)
  check "라이선스: busybox·HMG-API 없이 만들면 BUSYBOX-LICENSE.txt·HMGAPI-SOURCE.txt 없음, LICENSE·NOTICE.md는 있음" \
    '[ "$(cat $T/build.rc)" = 0 ] && [ ! -f $T/ux2/BUSYBOX-LICENSE.txt ] && [ ! -f $T/ux2/NX4/install/payload/bin/busybox-LICENSE.txt ] && [ ! -f $T/ux2/HMGAPI-SOURCE.txt ] && [ -f $T/ux2/LICENSE ] && [ -f $T/ux2/NOTICE.md ]' || cat $T/build.out
  # HMG-API 엔진(PC JVM)으로 설치: 가짜 헤드유닛
  eng() { (HMGAPI_ROOT=$1 HMGAPI_HOST=1 HMGAPI_PRODUCT=$2 java -cp $T/eh hmgapi.engine.Engine install $T/out/hmgapi-nx4-kor-1.7.4.zip) > $T/eng.out 2>&1; echo $? > $T/eng.rc; }
  for prod in NX4.KOR.0000.V039.001.260902 CVEV.USA.0000.V015 DEPEHEV.KOR.0000.V039.001.260902 NX4.KOR.0000.V040.001.261101; do
    ER=$T/er-$prod; mkdir -p $ER/system/etc/permissions $ER/data/hmgapi/mods $ER/data/hmgapi/settings
    printf 'ro.build.product=%s\n' $prod > $ER/system/build.prop
    eng $ER $prod
  done
  ER=$T/er-NX4.KOR.0000.V039.001.260902; eng $ER NX4.KOR.0000.V039.001.260902
  # hmgapid는 상대 경로를 /data/hmgapi/mods/<모드>/ 아래로 푼다(svc_start): sh /data/hmgapi/mods/nx4-kor/standalone/ap.sh
  check "HMG-API 엔진: NX4.KOR 260902에 설치됨(서명 확인), 서비스 ap(root, android, 다시 시작)·launch(manual)·앱이 등록됨" \
    '[ "$(cat $T/eng.rc)" = 0 ] && grep -q "installed nx4-kor 1.7.4 (author key" $T/eng.out && grep -qx "nx4-kor ap root android yes script standalone/ap.sh -" $ER/data/hmgapi/state/services.txt && grep -qx "nx4-kor launch root manual no script standalone/launch.sh -" $ER/data/hmgapi/state/services.txt && grep -qx "io.github.jayparklab.nx4kor nx4-kor" $ER/data/hmgapi/state/apps.txt'
  for prod in CVEV.USA.0000.V015 DEPEHEV.KOR.0000.V039.001.260902 NX4.KOR.0000.V040.001.261101; do
    ER=$T/er-$prod; eng $ER $prod
    check "HMG-API 엔진: $prod 에는 설치하지 않음(NX4.KOR 260902 전용)" '[ "$(cat $T/eng.rc)" != 0 ] && grep -q "refused" $T/eng.out && [ ! -d $ER/data/hmgapi/mods/nx4-kor ]' || cat $T/eng.out
  done
else
  echo "skip 빌드·HMG-API 엔진 시험(HMGAPI_SRC 없음)"
fi

echo
if [ $fails = 0 ]; then echo "모두 통과"; else echo "실패 $fails개"; exit 1; fi
