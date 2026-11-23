#!/bin/sh
# PC(맥)에서 NX4 KOR 모드의 스크립트를 가짜 헤드유닛으로 돌린다.
#   sh tests/mod-test.sh                 스크립트 시험(실패하면 FAIL 줄과 종료 코드 1)
#   HMGAPI_SRC=<HMG-API 저장소> sh tests/mod-test.sh
#                                        + 임시 키로 scripts/build.sh를 끝까지 돌리고, 만든 모드를 HMG-API 엔진
#                                          (PC JVM)에 설치해 서비스·앱 등록과 차종 제한(NX4.KOR 260902만)을 본다
#                                          (HMGAPI_SRC는 .env.local에 적어도 된다)
# 가짜 도구: hmgapid, pm, am, getprop, settings, svc, sleep. 서비스 래퍼는 가짜 스크립트를 부르게 해서 넘기는 값을 보고,
# preun.sh·status.sh(svc/lib.sh)는 진짜를 돌린다.
B=$(cd "$(dirname "$0")/.." && pwd)
# .env.local에서는 HMGAPI_SRC만 읽는다. 시험이 부르는 build.sh는 .env.local을 읽지 않게 한다
# (NX4_BUSYBOX 같은 개인 설정이 섞이면 시험 결과가 PC마다 달라진다)
. "$B/scripts/local-env.sh"
nx4_env "$B" HMGAPI_SRC
NX4_ENV_FILE=
export NX4_ENV_FILE
PKG=$B/mod
T=$(mktemp -d /tmp/nx4-kor-test.XXXXXX)
# KEEP=1: 시험 폴더를 남긴다(실패 원인 보기)
if [ -n "$KEEP" ]; then echo "시험 폴더: $T"; else trap 'rm -rf $T' EXIT; fi
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails+1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
V=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' $PKG/mod.json | head -1)

# --- 구문 검사: 차의 셸은 mksh. 있는 ksh 계열과 dash로 본다(PC sh만으로는 ksh 계열에서만 틀리는 구문을 못 잡는다) ---
KSHS=$(for s in mksh ksh dash; do command -v $s; done)
[ -n "$KSHS" ] || bad "구문 검사: mksh/ksh/dash 없음"
for f in $PKG/svc/*.sh $PKG/bin/*.sh $PKG/scripts/*.sh $B/usb/troubleShooter $B/scripts/*.sh $B/tests/emu/*.sh; do
  for KSH in $KSHS; do check "구문 검사 $(basename $KSH): ${f#$B/}" '$KSH -n $f'; done
done

# --- mod.json: NX4 KOR 모드(2.1.0: 상태 화면 앱과 그 서비스만. 무선은 HMG-API와 공식 무선 모드 wireless-carplay-aa가 맡음) ---
check "mod.json: launch 서비스·앱·런처만, NX4.KOR 260902만, HMG-API 1.1.0-rc.8 이상, 훅·무선 부분·Wi-Fi 요청·충돌·requires 없음" 'python3 - "$PKG" <<PY
import json, os, sys
d = sys.argv[1]
m = json.load(open(os.path.join(d, "mod.json")))
assert m["id"] == "nx4-kor"
assert m["hmgapi"] == ">=1.1.0-rc.8", m["hmgapi"]
for s in m["services"]:
    assert os.path.isfile(os.path.join(d, s["script"])), s
assert [(s["name"], s["start"], s["user"], s["restart"]) for s in m["services"]] == [("launch", "manual", "root", False)], m["services"]
assert m["apps"] == [{"apk": "app/NX4KOR.apk", "package": "io.github.jayparklab.nx4kor"}], m["apps"]
assert m["system"] == {"model": ["NX4", "NX4HEV"], "region": ["KOR"], "firmware": ["260902"]}
# 앱 메뉴 타일은 하나. 그림 키(icon*)는 아래 타일 그림 테스트가 본다
assert list(m["provides"]) == ["launcher"] and len(m["provides"]["launcher"]) == 1, m["provides"]
t = m["provides"]["launcher"][0]
assert {k: t[k] for k in t if not k.startswith("icon")} == {"package": "io.github.jayparklab.nx4kor", "class": ".StatusActivity"}, t
# 공식 무선 모드와 같은 훅을 걸지 않는다(#17). requires로 걸면 공식 모드가 없거나 꺼질 때 HMG-API가 이 모드의 앱·서비스까지 멈춘다
for k in ("hooks", "parts", "feature_flags", "wifi", "conflicts", "requires", "logs", "probe", "network"):
    assert k not in m, k
PY'
check "빠진 것: 한국 포크 무선 모드(hooks.jar·레시피·libleafiaaac.so·patches.json·settings.json, wireless/), 핫스팟 서비스(svc/ap.sh·hotspot.sh, scripts/post.sh)" \
  '[ ! -e $PKG/hooks.jar ] && [ ! -e $PKG/recipes ] && [ ! -e $PKG/files ] && [ ! -e $PKG/patches.json ] && [ ! -e $PKG/settings.json ] && [ ! -e $B/wireless ] && [ ! -e $PKG/svc/ap.sh ] && [ ! -e $PKG/svc/hotspot.sh ] && [ ! -e $PKG/scripts/post.sh ] && [ -f $PKG/svc/lib.sh ]'
check "lib.sh: 모드 id·HMG-API 최소 판이 mod.json과 같음, 공식 무선 모드 최소 판, env.sh의 NX4_MOD_ID도 같음, 앱 Report의 최소 판도 같음" \
  'grep -q "^MOD_ID=\${NX4_MOD_ID:-nx4-kor}$" $PKG/svc/lib.sh && grep -q "^HMG_MIN=1.1.0-rc.8$" $PKG/svc/lib.sh && grep -q "^WM_ID=wireless-carplay-aa$" $PKG/svc/lib.sh && grep -q "^WM_MIN=2.2.0-rc.9$" $PKG/svc/lib.sh && grep -q "^NX4_MOD_ID=nx4-kor$" $PKG/svc/env.sh && grep -q "MIN_HMGAPI = \"1.1.0-rc.8\"" $B/app/java/io/github/jayparklab/nx4kor/Report.java && grep -q "MIN_WIRELESS = \"2.2.0-rc.9\"" $B/app/java/io/github/jayparklab/nx4kor/Report.java'
check "launch 서비스 이름 = 앱이 부르는 이름" 'grep -q "\"service-start\", \"launch\"" $B/app/java/io/github/jayparklab/nx4kor/StatusActivity.java'
# 앱 메뉴 타일 그림(#47): HMG-API tools/mkicon.sh가 만드는 순정 꼴(99x99 투명 타일) 넷. 원본 모양은 art/tile.svg
check "mod.json: 앱 메뉴 타일에 낮·밤·꺼짐(낮·밤) 그림 넷(icons/), 모두 모드 안의 99x99 투명 PNG(RGBA, 꺼짐은 투명 팔레트일 수 있음)" 'python3 - "$PKG" <<PY
import json, os, struct, sys
d = sys.argv[1]
t = json.load(open(os.path.join(d, "mod.json")))["provides"]["launcher"][0]
want = {"icon": "icons/icon.png", "icon_night": "icons/icon_night.png",
        "icon_disabled": "icons/icon_disabled.png", "icon_disabled_night": "icons/icon_disabled_night.png"}
assert {k: t.get(k) for k in want} == want, t
for f in want.values():
    b = open(os.path.join(d, f), "rb").read()
    assert b[1:4] == b"PNG" and b[12:16] == b"IHDR", f
    w, h, depth, ctype = struct.unpack(">IIBB", b[16:26])
    assert (w, h, depth) == (99, 99, 8) and (ctype == 6 or (ctype == 3 and b"tRNS" in b)), (f, w, h, depth, ctype)
PY'
check "상태 화면 앱 아이콘(android:icon) = 앱 메뉴 타일의 낮·밤 그림" \
  'grep -q "android:icon=\"@drawable/ic_launcher\"" $B/app/AndroidManifest.xml && cmp -s $B/app/res/drawable-hdpi/ic_launcher.png $PKG/icons/icon.png && cmp -s $B/app/res/drawable-night-hdpi/ic_launcher.png $PKG/icons/icon_night.png'
# HMG-API USB 묶음 안의 파일 이름 NEMESIS.data(빌드가 빼는 파일)는 그대로 둔다
check "NEMESIS·다른 차·제보 흔적 없음(모드·USB·빌드 스크립트)" \
  '! grep -rnE "NEMESIS|nemesis|KP_[A-Z]|korea\.projection|korea-projection|KoreaProjection|CARS_OK|CARS_TRY|CARS_SEEN|req_tick|report\.req|carreport|wireless\.projection|제보|QR" $PKG $B/usb $B/scripts --include=*.sh --include=troubleShooter --include=*.json --include=*.txt | grep -v "NEMESIS\.data"'

# 정적 검사: 맨 위(함수 밖) 기본값 대입이 아래에서 정해지는 변수를 먼저 쓰지 않음, "> 파일 2>/dev/null" 순서가 없음
python3 $B/tests/tools/defuse-check.py $PKG > $T/defuse.out 2>&1; DEFRC=$?
check "정적 검사: 정의 전에 쓰는 변수·'> 파일 2>/dev/null' 순서가 모드 스크립트에 없음(tests/tools/defuse-check.py)" '[ $DEFRC = 0 ] && [ ! -s $T/defuse.out ]'
# 상태 화면 앱: Report(상태 파일 읽기·판정 문구·상태표·재부팅 요청). android.* 없이 PC JVM으로 돈다
if command -v javac >/dev/null 2>&1; then
  J=$T/java; mkdir -p $J
  if javac -nowarn -encoding UTF-8 -d $J $B/app/java/io/github/jayparklab/nx4kor/Report.java $B/tests/ReportTest.java 2>$T/javac.err; then
    java -cp $J io.github.jayparklab.nx4kor.ReportTest > $T/java.out 2>&1; jr=$?
    grep -E "^FAIL" $T/java.out | sed 's/^/  [Java] /'
    check "상태 화면 앱 ReportTest 전부($(grep -c "^ok" $T/java.out)개)" '[ $jr -eq 0 ]'
  else
    cat $T/javac.err; check "상태 화면 앱 Report 컴파일" 'false'
  fi
else
  echo "skip ReportTest(javac 없음)"
fi

# --- 가짜 도구 ---
mkdir -p $T/bin
HD=$T/root/data/hmgapi
cat > $T/bin/hmgapid <<E
#!/bin/sh
echo "hmgapid \$*" >> $T/calls
H=\${HMGDATA:-$HD}
case "\$1 \$2" in
  "ping "*) exit 0 ;;
  "engine install")
    [ -f $T/install-fail ] && { echo "refused: test"; exit 1; }
    rm -rf $HD/mods/nx4-kor; mkdir -p $HD/mods/nx4-kor
    (cd $HD/mods/nx4-kor && unzip -q "\$3") || exit 1
    : > $T/app-ready
    echo "installed nx4-kor"; exit 0 ;;
  "engine remove") rm -rf \$H/mods/\$3; [ "\$3" = nx4-kor ] && rm -f $T/app-ready; echo "removed \$3"; exit 0 ;;
  "engine plan") cat $T/plan.out 2>/dev/null; exit 0 ;;
  "engine apply") exit \$(cat $T/apply.rc 2>/dev/null || echo 0) ;;
  "engine map-car")
    case "\$3" in
      --forget) rm -f \$H/state/local-map.json; echo "forgotten: /data/hmgapi/state/local-map.json"; exit 0 ;;
      --write)
        cat $T/mapcar.out 2>/dev/null
        [ -f $T/mapcar.writes ] && { mkdir -p \$H/state; echo '{"whole": true}' > \$H/state/local-map.json; }
        exit \$(cat $T/mapcar.rc 2>/dev/null || echo 0) ;;
    esac ;;
  "engine verify-map") exit \$(cat $T/verify.rc 2>/dev/null || echo 0) ;;
  "engine status") cat $T/status.out 2>/dev/null || echo "nothing"; exit 0 ;;
  "engine report")
    mkdir -p \$H/public/reports; echo '{"report": "test"}' > \$H/public/reports/car-report-test.json; echo "# test" > \$H/public/reports/car-report-test.md
    echo "report: car-report-test"; echo "saved: /data/hmgapi/public/reports/car-report-test.json"; exit 0 ;;
  "service-stop "*) rm -f $T/ap-running; echo "stop: asked"; exit 0 ;;
  "service-start "*) echo "start: asked"; exit 0 ;;
  "services "*) [ -f $T/ap-running ] && echo "nx4-kor ap running 123 0"; echo "nx4-kor launch stopped 0 0"; exit 0 ;;
esac
exit 0
E
# pm list features: $T/features(한 줄에 feature:<이름>)가 지금 켜진 순정 기능. 없으면 아무것도 없음
cat > $T/bin/pm <<E
#!/bin/sh
echo "pm \$*" >> $T/calls
[ "\$1" = path ] && [ -f $T/app-ready ] && echo "package:/data/app/io.github.jayparklab.nx4kor-1.apk"
[ "\$1 \$2" = "list features" ] && cat $T/features 2>/dev/null
exit 0
E
# 진단 기록 확인 창(DiagActivity): $T/diag.reply가 앱의 답. 없으면 확인 창이 없는 예전 판 앱(am이 Error를 냄).
# yes·no·timeout은 그 답을, silent는 창만 뜨고(shown) 답이 없음, noshow는 창이 뜨지 않음, wrongid는 다른 id의 yes를 쓴다
cat > $T/bin/am <<E
#!/bin/sh
echo "am \$*" >> $T/calls
case "\$*" in
  *DiagActivity*)
    id=; prev=
    for a in "\$@"; do [ "\$prev" = id ] && id=\$a; prev=\$a; done
    r=\$(cat $T/diag.reply 2>/dev/null)
    [ -n "\$r" ] || { echo "Error: Activity class {io.github.jayparklab.nx4kor/io.github.jayparklab.nx4kor.DiagActivity} does not exist."; exit 0; }
    A=$T/root/data/data/io.github.jayparklab.nx4kor/files
    mkdir -p \$A
    case "\$r" in
      noshow) ;;
      silent) echo "\$id shown" > \$A/diag.ans ;;
      wrongid) echo "0\$id yes" > \$A/diag.ans ;;
      *) echo "\$id \$r" > \$A/diag.ans ;;
    esac ;;
esac
exit 0
E
cat > $T/bin/getprop <<E
#!/bin/sh
case "\$1" in
  ro.build.product) echo \${FAKE_PROD:-NX4.KOR.0000.V039.001.260902} ;;
  sys.boot_completed) echo 1 ;;
  persist.sys.iap2.wifi) [ -f $T/iap2 ] && echo t ;;
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
# busybox 대신: 받은 명령을 그대로 실행
printf '#!/bin/sh\ncommand -v "$1" >/dev/null 2>&1 || exit 127\nexec "$@"\n' > $T/bin/bb
chmod +x $T/bin/*
P0=$T/bin:/usr/bin:/bin:/usr/sbin:/sbin
echo test-boot-id > $T/bootid
echo "100.00 50.00" > $T/uptime

# 가짜 모드 폴더: 래퍼(svc/launch.sh·env.sh, bin/uninstall.sh)는 진짜, 나머지 스크립트 자리에는 받은 환경을 적는 가짜.
# 가짜 preun.sh는 진짜처럼 삭제 때 HMG-API에서 이 모드를 뺀다
mkfix() {
  rm -rf $1; mkdir -p $1; cp -R $PKG/. $1/
  for s in bin/status.sh; do
    printf '#!/bin/sh\necho "%s NX4_APP=$NX4_APP APP=$APP BK=$BK APLOG=$APLOG NX4_UPDATE=$NX4_UPDATE NX4_APLOG=$NX4_APLOG" >> %s/stublog\necho "out of %s"\n' $s $T $s > $1/$s
  done
  printf '#!/bin/sh\necho "scripts/preun.sh NX4_APP=$NX4_APP APP=$APP BK=$BK APLOG=$APLOG NX4_UPDATE=$NX4_UPDATE NX4_APLOG=$NX4_APLOG" >> %s/stublog\n[ "$NX4_UPDATE" = 1 ] || { command -v hmgapid >/dev/null 2>&1 && hmgapid engine remove nx4-kor >/dev/null; }\nexit 0\n' $T > $1/scripts/preun.sh
  mkdir -p $1/app; echo apk > $1/app/NX4KOR.apk
}

F=$T/mod; mkfix $F

# --- launch.sh(이 모드의 서비스는 이것 하나) ---
rm -f $T/stublog
(env -u NX4_APP PATH=$P0 HMGAPI_MOD_DIR=$F NX4_ROOT=$T/kp sh $F/svc/launch.sh) > $T/l.out 2>&1
check "launch.sh: bin/status.sh를 모드 위치로 돌림(NX4_APLOG로 ap.log 위치를 넘김), 기록 폴더만 만듦(backup 없음)" \
  'grep -q "^bin/status.sh NX4_APP=$F APP=$F BK=$T/kp/backup APLOG=$T/kp/logs/ap.log NX4_UPDATE= NX4_APLOG=$T/kp/logs/ap.log" $T/stublog && [ -d $T/kp/logs ] && [ ! -d $T/kp/backup ]'

# --- uninstall.sh ---
ur() { (env -u NX4_APP PATH=$P0 HMGDATA=$HD NX4_ROOT=$T/kp sh $1/bin/uninstall.sh $2) > $T/u.out 2>&1; echo $? > $T/u.rc; }
mkdir -p $HD/mods; rm -rf $HD/mods/nx4-kor; cp -R $F $HD/mods/nx4-kor; I=$HD/mods/nx4-kor
mkdir -p $T/kp/logs; : > $T/calls; rm -f $T/stublog
ur $I --update
check "uninstall.sh --update: preun.sh를 NX4_UPDATE=1로(업데이트 갈래), 모드·기록 폴더는 지우지 않음, 서비스를 멈추지 않음(ap 서비스 없음)" \
  'grep -q "^scripts/preun.sh NX4_APP=$I .*NX4_UPDATE=1" $T/stublog && ! grep -q "engine remove" $T/calls && ! grep -q "service-stop" $T/calls && [ -d $I ] && [ -d $T/kp ] && [ "$(cat $T/u.rc)" = 0 ]'
: > $T/calls; rm -f $T/stublog
ur $I
check "uninstall.sh: preun.sh(삭제 갈래, HMG-API에서 모드를 뺌) → /data/nx4-kor 지움" \
  'grep -q "^scripts/preun.sh NX4_APP=$I .*NX4_UPDATE= " $T/stublog && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $I ] && [ ! -d $T/kp ] && [ "$(cat $T/u.rc)" = 0 ]'
# preun.sh가 모드를 빼지 못했으면(HMG-API 앱에서 지워야 함) 실패로 끝내고 알림
cp -R $F $I; printf '#!/bin/sh\nexit 0\n' > $I/scripts/preun.sh; mkdir -p $T/kp; : > $T/calls
ur $I
check "uninstall.sh: 모드가 HMG-API에 남았으면 실패(1)로 끝내고 HMG-API 앱에서 지우라고 알림(적용할 것은 없음)" '[ "$(cat $T/u.rc)" = 1 ] && grep -q "HMG-API 앱에서 NX4 KOR를 지워 주세요" $T/u.out && ! grep -q "적용해 주세요" $T/u.out'
rm -rf $I
# HMG-API를 먼저 지운 경우(hmgapid 명령·installed.txt 없음): preun.sh는 그대로 돌리고, 남은 모드 폴더를 직접 지우고, 앱은 pm으로 지움
cp -R $F $I; mkdir -p $T/kp; : > $T/calls; rm -f $T/stublog
(env -u NX4_APP PATH=$P0 HMGAPID=$T/nohmgapid HMGDATA=$HD NX4_ROOT=$T/kp sh $I/bin/uninstall.sh) > $T/u.out 2>&1; echo $? > $T/u.rc
check "uninstall.sh: HMG-API를 먼저 지웠으면 preun.sh로 되돌리고, 남은 모드 폴더·앱(pm)을 직접 지움" \
  '[ "$(cat $T/u.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$I .*NX4_UPDATE= " $T/stublog && grep -qx "pm uninstall io.github.jayparklab.nx4kor" $T/calls && [ ! -d $I ] && [ ! -d $T/kp ] && grep -q "HMG-API가 먼저 지워져" $T/u.out'
# 2.0.x의 백업(backup/: Wi-Fi 잠금·순정 AP 저장값을 되돌릴 기록)이 남은 차: 그 폴더만 남기고 2.0.x USB로 되돌리라고 알림(PR #50 리뷰 2)
rm -rf $I; cp -R $F $I; mkdir -p $T/kp/backup $T/kp/logs; echo orig > $T/kp/backup/wpaconf.orig; : > $T/kp/logs/ap.log; : > $T/calls; rm -f $T/stublog
ur $I
check "uninstall.sh: 2.0.x 백업(backup/)이 있으면 그것만 남기고(기록 그대로) 나머지를 지우고, 2.0.x USB의 UNINSTALL로 되돌리라고 알림" \
  '[ "$(cat $T/u.rc)" = 0 ] && grep -qx orig $T/kp/backup/wpaconf.orig && [ ! -d $T/kp/logs ] && [ ! -d $I ] && grep -q "백업 폴더($T/kp/backup)는 지우지 않았습니다" $T/u.out && grep -q "2.0.x USB(v2.0.4-beta.1) 또는 NX4 KOR 2.1.0 이후 USB의 UNINSTALL" $T/u.out' || cat $T/u.out
rm -rf $I $T/kp

# --- troubleShooter(USB 설치기) ---
R=$T/root; U=$T/usb0; K=$U/NX4
mkdir -p $R/data/local/tmp $K/install/payload
cp -R $F/. $K/install/payload/
(cd $K/install/payload && zip -q -r $K/install/hmgapi-nx4-kor.zip .)
# 설치기는 스틱의 NX4/install.log에 이어 쓴다. 시험마다 그 회의 기록만 보도록 지우고 돌린다(KEEPLOG=1이면 남김)
ts() { : > $T/calls; [ -n "$KEEPLOG" ] || rm -f $K/install.log; (env -u NX4_APP PATH=$P0 ROOT=$R HMGAPID=$T/bin/hmgapid NX4_USB_DIRS="$1" NX4_APP_WAIT=4 NX4_DIAG_WAIT=1 NX4_DIAG_SHOWN=1 sh $B/usb/troubleShooter) > $T/ts.out 2>&1; echo $? > $T/ts.rc; }
# 진단 기록 확인 창에는 [모으기]로 답한다(아래 확인 창 시험에서만 바꿈). 앱이 있는지는 $T/app-ready(가짜 pm)
echo yes > $T/diag.reply
# 진단 기록(diag)은 읽기만 하는 engine status·report를 부른다. "엔진을 부르지 않음"은 그 둘을 빼고 본다
engcalls() { grep -v -E "^hmgapid engine (status|report)$" $T/calls | grep -q "engine"; }
# 진단 기록 폴더(NX4/diag/<시각>) 하나: 시험 전에 rm -rf $K/diag 해 두고 그 회의 것만 본다
dg() { echo $K/diag/*; }
rm -rf $HD/mods/nx4-kor $R/data/nx4-kor
ts $T/nostick
check "USB 설치기: NX4 폴더가 없으면 아무것도 하지 않음" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "NX4 폴더가 없습니다" $T/ts.out && [ ! -s $T/calls ]'
mv $HD $T/hd.away
rm -rf $K/diag; : > $T/app-ready
ts $U
check "USB 설치기: HMG-API가 없으면 멈춤(설치 안 함)" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "HMG-API가 없습니다" $T/ts.out && ! grep -q "engine install" $T/calls'
check "USB 설치기 진단 기록: HMG-API가 없어도 [모으기]면 모으고(info·/system/lib), HMG-API 명령(engine status·report)은 부르지 않음" \
  '[ -f $(dg)/info.txt ] && [ -f $(dg)/system-lib-md5.txt ] && [ ! -f $(dg)/car-report.txt ] && ! grep -q "engine" $T/calls && grep -q "HMG-API가 응답하지 않아" $K/install.log'
rm -f $T/app-ready
mkdir -p $K/hmgapi $U/HMGAPI/install/payload; echo "# hmg-api" > $K/hmgapi/troubleShooter
ts $U
check "USB 설치기: HMG-API가 없고 같은 스틱에 HMG-API 설치기가 있으면 그것으로 넘김" '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "HMG-API 설치기로 넘김" $T/ts.out'
rm -rf $K/hmgapi $U/HMGAPI; mv $T/hd.away $HD
# 판 비교(HMG-API Version과 같은 규칙): 설치기의 vlt·hmg_meets만 꺼내, 구문 검사처럼 차의 셸(mksh)과 ksh·dash 중 있는 것마다 돌린다
sed -n '/^vlt() {/,/^}/p;/^hmg_meets() {/,/^}/p' $B/usb/troubleShooter > $T/vlt.sh
for VSH in $KSHS; do
  vcase() { $VSH -c '. "$1"; "$2" "$3" "$4"; echo $?' x $T/vlt.sh "$@"; }
  check "USB 설치기 판 비교($(basename $VSH)): 1.0.2 < 1.1.0-rc.3 < 1.1.0-rc.4 < 1.1.0-rc.10 < 1.1.0, beta < rc, 1.2.0-beta.1 > 1.1.0-rc.4" \
    '[ "$(vcase vlt 1.0.2 1.1.0-rc.3)$(vcase vlt 1.1.0-rc.3 1.1.0-rc.4)$(vcase vlt 1.1.0-rc.4 1.1.0-rc.10)$(vcase vlt 1.1.0-rc.10 1.1.0)$(vcase vlt 1.1.0-beta.9 1.1.0-rc.1)" = 00000 ] && [ "$(vcase vlt 1.1.0-rc.4 1.1.0-rc.4)$(vcase vlt 1.1.0 1.1.0-rc.10)$(vcase vlt 1.2.0-beta.1 1.1.0-rc.4)$(vcase vlt 1.1 1.1.0)" = 1111 ] && [ "$(vcase vlt 1.1.0-dev 1.1.0-rc)" = 2 ]'
  check "USB 설치기 판 비교($(basename $VSH)): 최소 판에 꼬리가 없으면 그 판의 rc도 채움(1.1.0-rc.1은 >=1.1.0), 꼬리가 있으면 꼬리까지 봄" \
    '[ "$(vcase hmg_meets 1.1.0-rc.1 1.1.0)$(vcase hmg_meets 1.1.0-rc.4 1.1.0-rc.4)$(vcase hmg_meets 1.1.0 1.1.0-rc.4)" = 000 ] && [ "$(vcase hmg_meets 1.0.9 1.1.0)$(vcase hmg_meets 1.1.0-rc.3 1.1.0-rc.4)" = 11 ]'
done
# release.yml "태그와 판 번호 확인"(그 step의 run 줄을 그대로 꺼내 돌림): 태그에서 v를 뗀 판이 mod.json·versionName과 같아야 함.
# 베타는 -beta.<n>까지 같아야 한다(git-flow 규칙 4). git은 흉내(커밋이 origin/release/2.0.3에 있음)
RV=$T/relver; rm -rf $RV; mkdir -p $RV/mod $RV/app $RV/bin
awk '/id: ver$/ { f = 1 } f && /run: \|$/ { r = 1; next } r && !/^          / && !/^$/ { exit } r { sub(/^          /, ""); print }' $B/.github/workflows/release.yml > $RV/ver.sh
printf '#!/bin/sh\ncase "$1" in rev-parse) echo 0123abc ;; branch) echo "  origin/release/2.0.3" ;; merge-base) exit 0 ;; esac\n' > $RV/bin/git; chmod +x $RV/bin/git
rvrun() {
  printf '{\n  "id": "nx4-kor",\n  "version": "%s"\n}\n' "$2" > $RV/mod/mod.json
  printf '<manifest\n    android:versionCode="42"\n    android:versionName="%s">\n' "$2" > $RV/app/AndroidManifest.xml
  : > $RV/out; (cd $RV && env PATH=$RV/bin:$P0 TAG=$1 GITHUB_OUTPUT=$RV/out sh ver.sh) > $RV/run.out 2>&1; echo $? > $RV/rc
}
rvrun v2.0.4-beta.2 2.0.4-beta.2
check "release.yml 판 확인: 베타 태그 v2.0.4-beta.2와 파일 판 2.0.4-beta.2 → 통과(version=2.0.4-beta.2, prerelease=true)" \
  '[ -s $RV/ver.sh ] && [ "$(cat $RV/rc)" = 0 ] && grep -qx "version=2.0.4-beta.2" $RV/out && grep -qx "prerelease=true" $RV/out' || cat $RV/run.out $RV/ver.sh
rvrun v2.0.4-beta.2 2.0.4
check "  베타 태그인데 파일 판에 꼬리가 없으면(예전 방식 2.0.4) 멈춤" '[ "$(cat $RV/rc)" != 0 ] && grep -q "mod/mod.json version(2.0.4)이 다릅니다" $RV/run.out' || cat $RV/run.out
rvrun v2.0.4 2.0.4
check "  정식 태그 v2.0.4와 파일 판 2.0.4 → 통과(prerelease=false)" '[ "$(cat $RV/rc)" = 0 ] && grep -qx "version=2.0.4" $RV/out && grep -qx "prerelease=false" $RV/out' || cat $RV/run.out
rvrun v2.0.4 2.0.4-beta.2
check "  정식 태그인데 파일 판이 베타면 멈춤(꼬리를 떼고 합쳐야 함)" '[ "$(cat $RV/rc)" != 0 ] && grep -q "다릅니다" $RV/run.out' || cat $RV/run.out
# 숫자의 앞자리 0(beta.02, 02.0.4)과 beta.0은 파일 판이 같아도 받지 않는다(PR #43 리뷰 4)
rvrun v2.0.4-beta.02 2.0.4-beta.02; _z1=$(cat $RV/rc); rvrun v2.0.04 2.0.04; _z2=$(cat $RV/rc); rvrun v2.0.4-beta.0 2.0.4-beta.0; _z3=$(cat $RV/rc)
check "  앞자리 0이 있는 태그(v2.0.4-beta.02, v2.0.04)와 beta.0은 파일 판이 같아도 멈춤" \
  '[ "$_z1" != 0 ] && [ "$_z2" != 0 ] && [ "$_z3" != 0 ] && grep -q "꼴이 아닙니다" $RV/run.out' || cat $RV/run.out
rvrun v2.0.10-beta.10 2.0.10-beta.10
check "  두 자리 숫자(v2.0.10-beta.10)는 통과" '[ "$(cat $RV/rc)" = 0 ]' || cat $RV/run.out
# HMG-API가 모드의 최소 판(mod.json "hmgapi")보다 낮으면: 따로 설치된 무선 모드를 지우기 전에, 스틱의 HMG-API 설치기로 올리거나 멈춤
NEEDV=$(sed -n 's/.*"hmgapi": *">=\([^"]*\)".*/\1/p' $PKG/mod.json)
mkdir -p $HD/mods/wireless-carplay-aa; echo '{"id": "wireless-carplay-aa"}' > $HD/mods/wireless-carplay-aa/mod.json
printf 'version 1.0.2\nbuild test\n' > $HD/installed.txt
ts $U
check "USB 설치기: HMG-API(1.0.2)가 최소 판($NEEDV)보다 낮고 스틱에 HMG-API가 없으면 아무것도 바꾸지 않고 멈춤(무선 모드도 그대로)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "HMG-API $NEEDV 이상으로 먼저 올려" $T/ts.out && ! engcalls && [ -f $HD/mods/wireless-carplay-aa/mod.json ]'
mkdir -p $K/hmgapi $U/HMGAPI/install/payload; echo "# hmg-api" > $K/hmgapi/troubleShooter; echo $NEEDV > $U/HMGAPI/install/payload/VERSION
ts $U
check "USB 설치기: ... 스틱에 최소 판 이상의 HMG-API 설치기가 있으면 그것으로 올림(무선 모드는 그대로, 엔진을 부르지 않음)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "HMG-API 설치기로 넘김(업데이트)" $T/ts.out && grep -q "1.0.2에서 $NEEDV(으)로" $T/ts.out && ! engcalls && [ -f $HD/mods/wireless-carplay-aa/mod.json ]'
printf 'version 1.1.0-rc.3\n' > $HD/installed.txt; echo 1.1.0-rc.3 > $U/HMGAPI/install/payload/VERSION
ts $U
check "USB 설치기: ... rc 꼬리까지 비교(1.1.0-rc.3 < $NEEDV), 스틱의 HMG-API도 낮으면 넘기지 않고 멈춤" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "이상으로 먼저 올려" $T/ts.out && ! engcalls && [ -f $HD/mods/wireless-carplay-aa/mod.json ]'
rm -rf $K/hmgapi $U/HMGAPI $HD/mods/wireless-carplay-aa
for hv in $NEEDV 1.1.0-rc.10 1.1.0 1.2.0-beta.1; do
  printf 'version %s\n' $hv > $HD/installed.txt
  ts $U
  check "USB 설치기: HMG-API $hv는 최소 판 이상이라 설치함" '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^hmgapid engine install" $T/calls'
  rm -rf $HD/mods/nx4-kor
done
rm -f $HD/installed.txt
T0=$(date +%s)
ts $U
T1=$(date +%s)
check "USB 설치기: 새로 설치 → engine install, 앱이 깔리면 상태 화면을 엶, 재부팅하지 않음, 기록을 스틱에" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^hmgapid engine install .*/data/local/tmp/nx4-kor-usb/nx4-kor.zip" $T/calls && grep -q "^am start -n io.github.jayparklab.nx4kor/.StatusActivity" $T/calls && ! grep -q "service-stop" $T/calls && [ -f $HD/mods/nx4-kor/mod.json ] && grep -q "설치됨: $V" $K/install.log && [ ! -d $R/data/local/tmp/nx4-kor-usb ]'
DUNTIL=$(sed -n 's/^am start -n .*DiagActivity .* --el until \([0-9][0-9]*\)$/\1/p' $T/calls)
check "USB 설치기 진단 기록: 확인 창(DiagActivity, id·기다릴 초·창을 기다리는 마지막 시각 until=시작+NX4_DIAG_SHOWN)을 먼저 띄우고 [모으기]면 아무것도 바꾸기 전에 모음(engine report가 engine install보다 먼저), 결과 안내가 마지막" \
  'grep -q "^am start -n io.github.jayparklab.nx4kor/.DiagActivity --es id [0-9][0-9]* --ei wait 1 --el until [0-9][0-9]*$" $T/calls && [ -n "$DUNTIL" ] && [ "$DUNTIL" -ge $((T0 + 1)) ] && [ "$DUNTIL" -le $((T1 + 1)) ] && [ "$(grep -n "DiagActivity" $T/calls | cut -d: -f1)" -lt "$(grep -n "^hmgapid engine report" $T/calls | cut -d: -f1)" ] && [ "$(grep -n "^hmgapid engine report" $T/calls | cut -d: -f1)" -lt "$(grep -n "^hmgapid engine install" $T/calls | cut -d: -f1)" ] && [ "$(grep -n "진단 기록을 USB에 모으는 중입니다(1~2분)" $T/ts.out | cut -d: -f1)" -lt "$(grep -n "설치하는 중" $T/ts.out | cut -d: -f1)" ] && tail -n 1 $T/ts.out | grep -q "설치됨. 상태 화면에서" && grep -q "\[모으기\]를 고름" $K/install.log'
cp $K/install.log $T/first.log; FIRSTN=$(($(wc -l < $T/first.log)))
KEEPLOG=1; ts $U; KEEPLOG=
check "USB 설치기: 같은 판이 있으면 다시 설치하지 않고 상태 화면만 엶" '[ "$(cat $T/ts.rc)" = 0 ] && ! grep -q "engine install" $T/calls && grep -q "^am start" $T/calls && grep -q "이미 설치되어" $T/ts.out'
check "USB 설치기: 스틱의 install.log에 이어 씀(앞의 시도 기록이 그대로 맨 앞에 남고, 빈 줄 뒤에 이번 기록, 한 번씩만)" \
  '[ $FIRSTN -gt 0 ] && head -n $FIRSTN $K/install.log | cmp -s - $T/first.log && [ "$(grep -c "USB 설치기 시작" $K/install.log)" = 2 ] && [ "$(grep -c "설치됨: $V" $K/install.log)" = 1 ] && grep -q "같은 판($V)이 이미 설치됨" $K/install.log && [ "$(grep -n "설치됨: $V" $K/install.log | cut -d: -f1)" -lt "$(grep -n "같은 판" $K/install.log | cut -d: -f1)" ] && grep -qx "" $K/install.log' || cat $K/install.log
# 설치기는 이 모드의 판이 같은지만 본다(차례는 HMG-API engine install이 봄, git-flow 규칙 4): 설치된 판이 꼬리만 다른 베타($V-beta.1)여도
# 다른 판이라 예전 판을 정리하고 engine install을 부른다. 끝나면 가짜 engine install이 payload의 판($V)으로 되돌려 놓는다
sed "s/\"version\": \"$V\"/\"version\": \"$V-beta.1\"/" $HD/mods/nx4-kor/mod.json > $T/mj.tmp; mv $T/mj.tmp $HD/mods/nx4-kor/mod.json
ts $U
check "USB 설치기: 판은 같은지만 봄. 설치된 판이 $V-beta.1이면 $V와 다른 판이라 예전 판 정리 뒤 engine install(차례는 HMG-API가 봄)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^hmgapid engine install" $T/calls && grep -q "$V-beta.1에서 $V(으)로 바꾸는 중" $T/ts.out && ! grep -q "같은 판" $K/install.log && grep -q "\"version\": \"$V\"" $HD/mods/nx4-kor/mod.json' || { cat $T/ts.out; cat $K/install.log; }
# 진단 기록: /system/lib(하위 폴더·링크), 내비의 busybox, 이 모드의 기록. 비밀번호가 든 파일(Wi-Fi 설정, 백업 폴더)은 넣지 않음
mkdir -p $R/system/lib/hw $R/system/bin $R/data/nx4-kor/logs $R/data/nx4-kor/backup $R/data/local/tmp/nx4-kor $HD/logs/nx4-kor $R/data/misc/wifi
echo core > $R/system/lib/libCarPlayCore.so; echo hw > $R/system/lib/hw/gralloc.so; ln -s libCarPlayCore.so $R/system/lib/liblink.so
cp $T/bin/bb $R/system/bin/busybox
echo aplog > $R/data/nx4-kor/logs/ap.log; echo svclog > $HD/logs/nx4-kor/ap.log; echo hmgapi-install > $HD/install.log
echo mapcar > $R/data/local/tmp/nx4-kor/map-car.txt; echo status > $R/data/local/tmp/nx4-kor-status.txt
echo "wpa_passphrase=SECRETPW" > $R/data/misc/wifi/softap.conf; echo SECRETPW > $R/data/nx4-kor/backup/softap.conf
mkdir -p $R/system/etc/permissions $R/system/onebin/nx4hev_kr; : > $R/system/etc/permissions/com.hkmc.software.wifi.module.xml
echo "-/system/etc/permissions/com.hkmc.software.wifihotspot.xml" > $R/system/onebin/nx4hev_kr/featurexml.cfg
echo "feature:com.hkmc.software.wifi.module" > $T/features
rm -rf $K/diag
ts $U
check "USB 설치기 진단 기록: 순정 기능(pm list features), /system/etc/permissions 목록, onebin마다 featurexml.cfg 사본" \
  'grep -qx "feature:com.hkmc.software.wifi.module" $(dg)/features.txt && grep -q "com.hkmc.software.wifi.module.xml" $(dg)/permissions-ls.txt && grep -q "wifihotspot.xml" $(dg)/featurexml-nx4hev_kr.cfg' || ls $(dg)
rm -f $T/features
CORE5=$(md5sum < $R/system/lib/libCarPlayCore.so | cut -d" " -f1)
check "USB 설치기 진단 기록: NX4/diag/<시각>/에 /system/lib 아래 모든 파일(하위 폴더·링크 포함)의 md5와 경로, ls -lR" \
  '[ "$(ls $K/diag | wc -l)" -eq 1 ] && grep -q "^$CORE5  .*/system/lib/libCarPlayCore.so$" $(dg)/system-lib-md5.txt && grep -q "^$CORE5  .*/system/lib/liblink.so$" $(dg)/system-lib-md5.txt && grep -q "  .*/system/lib/hw/gralloc.so$" $(dg)/system-lib-md5.txt && [ "$(wc -l < $(dg)/system-lib-md5.txt)" -eq 3 ] && grep -q "liblink.so -> libCarPlayCore.so" $(dg)/system-lib-ls.txt' || cat $(dg)/system-lib-md5.txt
check "USB 설치기 진단 기록: info.txt(판·getprop·내비 busybox 유무·wifi_ap_on), HMG-API 상태·Car Report 복사, 이 모드와 HMG-API 기록" \
  'grep -qx "installed_mod: $V" $(dg)/info.txt && grep -qx "usb_mod: $V" $(dg)/info.txt && grep -q "^ro.build.product: NX4.KOR" $(dg)/info.txt && grep -qx "system_busybox: yes" $(dg)/info.txt && grep -qx "md5_busybox: $R/system/bin/busybox" $(dg)/info.txt && grep -qx "wifi_ap_on: 1" $(dg)/info.txt && grep -qx "hmgapid engine status" $T/calls && [ -f $(dg)/hmgapi-status.txt ] && grep -q "^saved: " $(dg)/car-report.txt && [ -f $(dg)/car-report-test.json ] && [ -f $(dg)/car-report-test.md ] && grep -qx aplog $(dg)/logs/ap.log && grep -qx svclog $(dg)/logs/service/ap.log && grep -qx hmgapi-install $(dg)/logs/hmgapi-install.log && grep -qx mapcar $(dg)/logs/map-car.txt && grep -qx status $(dg)/logs/nx4-kor-status.txt && grep -q "진단 기록을 모음: NX4/diag/" $K/install.log' || cat $(dg)/info.txt
check "USB 설치기 진단 기록: 비밀번호가 든 파일(softap.conf, 백업 폴더)은 넣지 않음" '! grep -rq SECRETPW $K/diag'
# md5를 셀 busybox: 내비에 없으면 설치된 모드의 것, 그것도 없으면 스틱의 것을 /data로 복사해 쓰고 지움. 모두 없으면 그렇다고 적음
rm $R/system/bin/busybox; cp $T/bin/bb $HD/mods/nx4-kor/bin/busybox
ts $U
check "USB 설치기 진단 기록: 누를 때마다 새 폴더, 내비에 busybox가 없으면 설치된 모드의 busybox로 md5" \
  '[ "$(ls $K/diag | wc -l)" -eq 2 ] && grep -rqx "md5_busybox: $HD/mods/nx4-kor/bin/busybox" $K/diag && grep -rqx "system_busybox: no" $K/diag'
rm -rf $K/diag $HD/mods/nx4-kor/bin/busybox; cp $T/bin/bb $K/install/payload/bin/busybox
ts $U
check "USB 설치기 진단 기록: 설치된 모드에도 없으면 스틱의 busybox를 /data로 복사해 쓰고 지움" \
  'grep -qx "md5_busybox: $R/data/local/tmp/nx4-kor-diag-busybox" $(dg)/info.txt && grep -q "^$CORE5  " $(dg)/system-lib-md5.txt && [ ! -f $R/data/local/tmp/nx4-kor-diag-busybox ]'
rm -rf $K/diag $K/install/payload/bin/busybox
ts $U
check "USB 설치기 진단 기록: md5를 셀 busybox가 없으면 그렇다고 적고(이름·크기는 ls -lR) 설치기는 그대로 끝남" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -qx "md5_busybox: none" $(dg)/info.txt && grep -q "busybox가 없음" $(dg)/system-lib-md5.txt && grep -q "libCarPlayCore.so" $(dg)/system-lib-ls.txt && grep -q "busybox가 없어" $K/install.log'
# 확인 창에서 모으지 않는 경우: 진단 폴더를 만들지 않고 HMG-API 명령도 부르지 않으며, 설치기는 그대로 이어짐(같은 판: 상태 화면)
dno() { rm -rf $K/diag; ts $U; [ "$(cat $T/ts.rc)" = 0 ] && [ ! -d $K/diag ] && ! grep -q "engine report" $T/calls && grep -q "^am start -n io.github.jayparklab.nx4kor/.StatusActivity" $T/calls && grep -q "이미 설치되어" $T/ts.out && grep -q "$1" $K/install.log; }
echo no > $T/diag.reply
check "USB 설치기 진단 기록: [건너뛰기]·뒤로면 모으지 않고 설치기는 이어짐" 'dno "\[건너뛰기\]를 고름"'
echo timeout > $T/diag.reply
check "USB 설치기 진단 기록: 창이 스스로 닫히면(고르지 않음) 모으지 않음" 'dno "고르지 않아 건너뜀"'
echo silent > $T/diag.reply
check "USB 설치기 진단 기록: 창은 떴지만 답이 오지 않으면 기다림(NX4_DIAG_WAIT + 2×NX4_DIAG_SHOWN초) 뒤 모으지 않음" 'dno "답이 없어 건너뜀"'
echo noshow > $T/diag.reply
check "USB 설치기 진단 기록: 창이 NX4_DIAG_SHOWN초 안에 뜨지 않으면 모으지 않음" 'dno "확인 창이 뜨지 않음"'
echo wrongid > $T/diag.reply
check "USB 설치기 진단 기록: 다른 id(지난 시도)의 [모으기]는 믿지 않음" 'dno "확인 창이 뜨지 않음"'
rm -f $T/diag.reply
check "USB 설치기 진단 기록: 확인 창이 없는 예전 판 앱이면(am start가 Error) 기다리지 않고 모으지 않음" 'dno "확인 창을 열지 못함"'
echo yes > $T/diag.reply; rm -f $T/app-ready
rm -rf $K/diag; ts $U
check "USB 설치기 진단 기록: 상태 화면 앱이 없으면 묻지 못해 모으지 않음(확인 창을 띄우지 않음)" \
  '[ ! -d $K/diag ] && ! grep -q "DiagActivity" $T/calls && grep -q "앱이 없어 묻지 못함" $K/install.log'
: > $T/app-ready
rm -rf $R/system $R/data/misc $R/data/nx4-kor $R/data/local/tmp/nx4-kor $R/data/local/tmp/nx4-kor-status.txt $HD/logs $HD/install.log $HD/public
: > $K/REINSTALL; : > $T/ap-running; rm -f $T/stublog
ts $U
check "USB 설치기: REINSTALL이면 예전 판 정리(uninstall.sh --update) → engine install → 서비스 ap 다시 시작" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "NX4_UPDATE=1" $T/stublog && grep -q "^hmgapid engine install" $T/calls && grep -qx "hmgapid service-start nx4-kor ap" $T/calls'
rm -f $K/REINSTALL
# 따로 설치된 무선 모드: 지우고, 계획이 그 모드의 되돌리기뿐이면 적용한 뒤 설치
mkdir -p $HD/mods/wireless-carplay-aa; echo '{"id": "wireless-carplay-aa"}' > $HD/mods/wireless-carplay-aa/mod.json
printf 'restore  /system/lib/libleafiaaac.so [wireless-carplay-aa]\nsetting  persist.sys.iap2.wifi back to stock\napp      io.github.jayparklab.nx4kor [nx4-kor]\n' > $T/plan.out
: > $K/REINSTALL
ts $U
check "USB 설치기: 따로 설치된 wireless-carplay-aa를 engine remove → 계획 확인 → apply 뒤 설치" \
  '[ "$(cat $T/ts.rc)" = 0 ] && [ ! -d $HD/mods/wireless-carplay-aa ] && [ "$(grep -n "engine remove wireless-carplay-aa" $T/calls | cut -d: -f1)" -lt "$(grep -n "engine apply" $T/calls | cut -d: -f1)" ] && [ "$(grep -n "engine apply" $T/calls | cut -d: -f1)" -lt "$(grep -n "engine install" $T/calls | cut -d: -f1)" ] && grep -q "지우고 적용함" $K/install.log'
mkdir -p $HD/mods/wireless-carplay-aa; echo '{"id": "wireless-carplay-aa"}' > $HD/mods/wireless-carplay-aa/mod.json
printf 'restore  /system/lib/libleafiaaac.so [wireless-carplay-aa]\nchange   /system/framework/framework.odex [other-mod]\n' > $T/plan.out
ts $U
check "USB 설치기: 계획에 다른 변경이 있으면 지우기만 하고 적용하지 않음(설치는 계속)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && ! grep -q "engine apply" $T/calls && grep -q "^hmgapid engine install" $T/calls && grep -q "적용하지 않음" $K/install.log'
rm -f $K/REINSTALL $T/plan.out
sed "s/\"version\": \"$V\"/\"version\": \"1.9.9\"/" $HD/mods/nx4-kor/mod.json > $T/mj && mv $T/mj $HD/mods/nx4-kor/mod.json
: > $T/install-fail
ts $U
check "USB 설치기: 업데이트 설치가 거절되면 실패로 끝내고 예전 판의 서비스를 다시 띄움" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "설치 실패" $T/ts.out && grep -qx "hmgapid service-start nx4-kor ap" $T/calls'
rm -f $T/install-fail
# 지우기
: > $K/UNINSTALL; : > $T/ap-running; rm -f $T/stublog; mkdir -p $R/data/nx4-kor/logs
ts $U
check "USB 설치기: UNINSTALL이면 설치된 모드의 uninstall.sh로 되돌리고 모드를 지움" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$HD/mods/nx4-kor " $T/stublog && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && grep -q "지웠습니다" $T/ts.out'
ts $U
check "USB 설치기: 지울 것이 없으면 아무것도 하지 않음" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "설치되어 있지 않습니다" $T/ts.out && ! grep -q "engine remove" $T/calls'
# 모드는 HMG-API 앱에서 먼저 지웠고 되돌릴 기록만 남은 경우: 스틱의 사본(/data로 복사)으로 되돌림
# (2.1.0이 남기는 기록은 logs/. 2.0.x의 backup/은 2.1.0 uninstall.sh가 남기고 2.0.x USB로 안내한다, PR #50 리뷰 2)
mkdir -p $R/data/nx4-kor/logs; rm -f $T/stublog
ts $U
check "USB 설치기: 모드가 이미 지워졌어도 기록이 남았으면 스틱의 사본으로 되돌림" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$R/data/local/tmp/nx4-kor-usb/payload " $T/stublog && [ ! -d $R/data/nx4-kor ] && [ ! -d $R/data/local/tmp/nx4-kor-usb ]'
# HMG-API를 먼저 지운 뒤(hmgapid 없음): 일반 삭제는 모드 폴더를 남긴다 → 그 폴더의 uninstall.sh로, purge는 /data/hmgapi째 없다 → 스틱 사본으로
ts0() { : > $T/calls; rm -f $K/install.log; (env -u NX4_APP PATH=$P0 ROOT=$R HMGAPID=$T/nohmgapid NX4_USB_DIRS=$U NX4_APP_WAIT=4 sh $B/usb/troubleShooter) > $T/ts.out 2>&1; echo $? > $T/ts.rc; }
mkdir -p $HD/mods $R/data/nx4-kor/logs; cp -R $F $HD/mods/nx4-kor; rm -f $HD/installed.txt $T/stublog
ts0
check "USB 설치기: HMG-API를 먼저 지운 뒤(일반 삭제)에도 UNINSTALL이 됨: 남은 모드 폴더의 uninstall.sh로 되돌리고 모드 폴더·앱을 지움" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$HD/mods/nx4-kor " $T/stublog && grep -qx "pm uninstall io.github.jayparklab.nx4kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && [ ! -d $R/data/nx4-kor ] && grep -q "지웠습니다" $T/ts.out && grep -q "HMG-API가 없음" $K/install.log'
mv $HD $T/hd.purged; mkdir -p $R/data/nx4-kor/logs; rm -f $T/stublog
ts0
check "USB 설치기: HMG-API를 먼저 완전 삭제(--purge)한 뒤에도 기록이 남았으면 스틱의 사본으로 되돌림" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$R/data/local/tmp/nx4-kor-usb/payload " $T/stublog && [ ! -d $R/data/nx4-kor ]'
mv $T/hd.purged $HD
rm -f $K/UNINSTALL

# --- 진짜 스크립트: preun.sh·status.sh(svc/lib.sh) ---
# 차의 PATH로 바꾸는 맨 윗줄만 시험용 PATH로 바꾼 사본으로 돌린다. 나머지는 그대로
TP=$T/pkg; rm -rf $TP; cp -R $PKG $TP
for f in svc/lib.sh scripts/preun.sh bin/status.sh; do
  sed "s#^export PATH=.*#export PATH=$P0#" $PKG/$f > $TP/$f
done
# preun.sh: 업데이트 갈래. 작업 폴더·상태 화면 파일만 지우고, 진행 기록(USB 설치기가 씀)·알림은 둔다
prun() { (env PATH=${PP:-$P0} BB_SYS=$T/bin/bb NX4_APP=$TP W=$T/uw HINT=$T/uhint PROG=$T/uprog NOTICE=$T/unotice RBRES=$T/urbres HMGDATA=$T/uh BOOT_ID=$T/bootid "$@" sh $TP/scripts/preun.sh) > $T/pu.out 2>&1; echo $? > $T/pu.rc; }
pureset() {
  rm -rf $T/uw $T/uh; mkdir -p $T/uw $T/uh/mods/nx4-kor; : > $T/uw/watch.until
  for f in uhint uprog unotice urbres; do echo x > $T/$f; done
  echo '{"id": "nx4-kor"}' > $T/uh/mods/nx4-kor/mod.json; : > $T/uh/installed.txt; : > $T/calls
}
pureset; prun NX4_UPDATE=1
check "preun.sh: NX4_UPDATE=1이면 작업 폴더·상태 안내를 지우고 끝남, 진행 기록(설치기가 씀)·알림은 둠, HMG-API를 부르지 않음" \
  '[ "$(cat $T/pu.rc)" = 0 ] && grep -q "NX4 KOR 업데이트: 이전 판 정리" $T/pu.out && [ ! -d $T/uw ] && [ ! -f $T/uhint ] && [ -f $T/uprog ] && [ -f $T/unotice ] && ! grep -q "^hmgapid" $T/calls' || cat $T/pu.out
# preun.sh: 상태 화면이 띄운 감시자(status.sh --watch)를 멈춘다. 명령줄은 가짜 /proc의 cmdline(NUL로 나눔)으로 본다
# (멈출 프로세스는 하위 셸에서 띄워 이 셸의 작업으로 남지 않게 한다: 멈추면 바로 거둬져 kill -0이 실패한다)
pureset; (sleep 20 >/dev/null 2>&1 & echo $! > $T/slp.pid); SLP=$(cat $T/slp.pid)
mkdir -p $T/uproc/$SLP; printf 'sh\0/data/hmgapi/mods/nx4-kor/bin/status.sh\0--watch\0' > $T/uproc/$SLP/cmdline
echo "$SLP test-boot-id" > $T/uw/watch.pid; prun NX4_UPDATE=1 PROC=$T/uproc
_k=0; while kill -0 $SLP 2>/dev/null && [ $_k -lt 30 ]; do /bin/sleep 0.1; _k=$((_k+1)); done
check "  감시자(watch.pid의 status.sh)를 멈춤" '! kill -0 $SLP 2>/dev/null' || { kill $SLP 2>/dev/null; cat $T/pu.out; }
rm -rf $T/uproc $T/slp.pid
# preun.sh: 삭제 → HMG-API에서 이 모드를 뺀다(engine remove). 이 모드는 시스템 파일을 바꾸지 않아 계획·적용은 하지 않는다
# (앱·서비스는 HMG-API가 목록을 다시 써서 내림). 진행 기록·알림·재부팅 결과도 지운다
pureset; prun
check "preun.sh: 삭제면 engine remove nx4-kor만(계획·적용 없음), 진행 기록·알림·재부팅 결과 지움, 끝 문구" \
  '[ "$(cat $T/pu.rc)" = 0 ] && grep -qx "hmgapid engine remove nx4-kor" $T/calls && ! grep -q "engine plan" $T/calls && ! grep -q "engine apply" $T/calls && [ ! -f $T/uprog ] && [ ! -f $T/unotice ] && [ ! -f $T/urbres ] && grep -q "HMG-API에서 이 모드를 지움" $T/pu.out && grep -qx "NX4 KOR를 지웠습니다." $T/pu.out' || cat $T/pu.out
pureset; rm -f $T/uh/mods/nx4-kor/mod.json; prun
check "  HMG-API에 이 모드가 없으면(이미 지워짐) HMG-API에서 지우지 않음" '! grep -q "engine remove" $T/calls && grep -q "이미 지워짐" $T/pu.out' || cat $T/pu.out
# preun.sh: HMG-API를 먼저 지웠으면(hmgapid 명령도 installed.txt도 없음) HMG-API를 부르지 않고 끝까지 감
mkdir -p $T/bin2; for b in $T/bin/*; do [ "${b##*/}" = hmgapid ] || cp $b $T/bin2/; done
P2=$T/bin2:/usr/bin:/bin:/usr/sbin:/sbin
sed "s#^export PATH=.*#export PATH=$P2#" $PKG/scripts/preun.sh > $TP/scripts/preun.sh
sed "s#^export PATH=.*#export PATH=$P2#" $PKG/svc/lib.sh > $TP/svc/lib.sh
pureset; rm -f $T/uh/installed.txt
prun PATH=$P2 BB_SYS=$T/bin2/bb
check "preun.sh: HMG-API를 먼저 지웠으면 HMG-API를 부르지 않고 작업 파일을 지우고 끝냄" \
  '! grep -q "^hmgapid" $T/calls && grep -q "HMG-API가 먼저 지워져 있음" $T/pu.out && [ ! -d $T/uw ] && [ ! -f $T/uprog ] && [ "$(cat $T/pu.rc)" = 0 ]' || cat $T/pu.out
sed "s#^export PATH=.*#export PATH=$P0#" $PKG/scripts/preun.sh > $TP/scripts/preun.sh
sed "s#^export PATH=.*#export PATH=$P0#" $PKG/svc/lib.sh > $TP/svc/lib.sh

# --- status.sh: 판정(상태 파일). 2.1.0: HMG-API + 공식 무선 모드(wireless-carplay-aa) + 이 모드 ---
# 가짜 ps: $T/ps.out이 있으면 그 줄(PID … 명령), 없으면 이 PC의 ps. hostapd·wpa_supplicant가 도는지만 본다
printf '#!/bin/sh\nif [ -f %s/ps.out ]; then echo "PID USER TIME COMMAND"; cat %s/ps.out; else exec /bin/ps "$@"; fi\n' $T $T > $T/bin/ps; chmod +x $T/bin/ps
SH=$T/sh
stsh() {
  (env PATH=$P0 BB=$T/bin/bb APP=$TP W=$T/sw HMGDATA=$SH PROG=$T/sprog BOOT_ID=$T/bootid UPTIME=$T/suptime \
     WIFI_SEEN=$T/wifiseen SDIO=$T/nosdio SYSNET=$T/sysnet PROCNET=$T/procnet PROC=$T/sproc STATUS=$T/status.txt SRC=$T/softap.conf \
     HMGINST=$T/sinst HMGLOG=$T/shlog HOOKSTARTS=$T/sstarts NX4_DMESG=$T/sdmesg RPT_SYNC=1 "$@" sh $TP/bin/status.sh) > $T/st.out 2>&1
}
sv() { sed -n "s/^$1=//p" $T/status.txt; }
# 순정 AP 설정(softap.conf 형식 3: int, writeUTF 문자열 S1 일반 핫스팟 SSID, S2 카플레이 SSID, S3, S4 비밀번호)
python3 - $T/softap.conf <<'PY'
import struct, sys
d = struct.pack(">i", 3)
for s in (b"NX4 Hotspot", b"CarPlayNX4", b"x", b"SECRETPW123"):
    d += struct.pack(">H", len(s)) + s
open(sys.argv[1], "wb").write(d)
PY
# 준비된 차: HMG-API rc.8(훅 켜짐, map 확인됨), 공식 모드 2.2.0-rc.9가 켜지고 훅이 켜짐, 무선 기능·순정 핫스팟 기능 켜짐,
# 프로젝션 AP 요청이 있고 이번 부팅에 떠서 netd(99)가 띄운 hostapd(1234)가 카플레이 SSID(S2)로 돎, Wi-Fi 칩을 본 기록
streset() {
  rm -rf $SH $T/sw $T/sproc $T/sysnet $T/procnet $T/shlog $T/sprog $T/status.txt $T/ps.out $T/wifiseen $T/sstarts
  mkdir -p $SH/mods/wireless-carplay-aa $SH/state $SH/wifi $SH/settings $T/sw $T/sproc/1234 $T/sproc/99 $T/sysnet/wlan0 $T/procnet $T/shlog
  printf '{\n  "id": "wireless-carplay-aa",\n  "version": "2.2.0-rc.9"\n}\n' > $SH/mods/wireless-carplay-aa/mod.json
  printf 'version 1.1.0-rc.8\nbuild x\n' > $T/sinst
  printf '%s\n' feature:com.hkmc.software.connectivity.carplay_wireless feature:com.hkmc.software.connectivity.androidauto_wireless \
    feature:com.hkmc.software.wifihotspot > $T/features
  printf '%s\n' "11-23 06:00:01.000 I/HMG-API: hook map: verified for hyundai/nx4/kor/260902, hooks on" \
    "11-23 06:00:02.000 I/HMG-API: mods: wireless-carplay-aa: this mod is for other cars; overrides.ignore_system is set, loading it at the owner's risk" \
    "11-23 06:00:02.000 I/HMG-API: mods: loaded wireless-carplay-aa 2.2.0-rc.9" > $T/shlog/log.log
  echo "projection wireless-carplay-aa" > $SH/state/wifi.txt
  cat $T/bootid > $SH/wifi/ap.boot
  : > $T/wifiseen; : > $T/sdmesg
  echo "100.00 50.00" > $T/suptime
  echo "1234 root 0:00 hostapd -e /data/misc/wifi/entropy.bin $T/hapd.conf" > $T/ps.out
  echo "1234 (hostapd) S 99 1234" > $T/sproc/1234/stat; echo "99 (netd) S 1 99" > $T/sproc/99/stat
  printf 'hostapd\0-e\0/data/misc/wifi/entropy.bin\0%s\0' $T/hapd.conf > $T/sproc/1234/cmdline
  printf 'interface=wlan0\nssid=CarPlayNX4\nwpa_passphrase=SECRETPW123\n' > $T/hapd.conf
}
# 지금 Wi-Fi AP가 없는 차(hostapd·wlan0 없음)
noap() { : > $T/ps.out; rm -rf $T/sysnet/wlan0; }
streset; stsh
check "status.sh: 준비된 차 → verdict=ready(수준 0), 공식 모드·훅·프로젝션 AP 값, 요약 '무선 Wi-Fi: 켜짐(HMG-API)'" \
  '[ "$(sv verdict)" = ready ] && [ "$(sv verdict_lv)" = 0 ] && [ "$(sv wm)" = yes ] && [ "$(sv wm_ver)" = 2.2.0-rc.9 ] && [ "$(sv wm_on)" = yes ] && [ "$(sv wm_hooks)" = on ] && [ "$(sv hooks)" = on ] && [ "$(sv hookmap)" = verified ] && [ "$(sv proj)" = yes ] && [ "$(sv ap_boot)" = yes ] && [ "$(sv ap)" = yes ] && [ "$(sv ap_mode)" = projection ] && [ "$(sv chip)" = yes ] && [ "$(sv feat_hotspot)" = yes ] && [ "$(sv s2)" = "무선 Wi-Fi: 켜짐(HMG-API)" ] && [ "$(sv pkgver)" = "$V" ]' || cat $T/st.out $T/status.txt
check "  상태 파일·한 줄 요약에 SSID·비밀번호가 없고, 2.0.x 키(우리 핫스팟·합친 무선 모드)가 없음, 한 줄 요약에 판정 코드" \
  '! grep -qE "CarPlayNX4|SECRETPW|NX4 Hotspot" $T/status.txt $T/st.out && ! grep -qE "^(our_ap|our_dhcp|stock_ssid|stock_seen|applied|oldmod|mod_on|mod_hooks|nowlan|softap_strings|ssid_len|pass_len)=" $T/status.txt && grep -qx "NX4 KOR: 무선 연결용 Wi-Fi 켜짐, 카플레이 연결 0개, 판정 ready" $T/st.out' || cat $T/st.out
streset; stsh FAKE_PROD=DEPEHEV.KOR.0000.V039.001.260902
check "status.sh: NX4가 아니면 verdict=nocar, verdict_end=yes" '[ "$(sv verdict)" = nocar ] && [ "$(sv verdict_end)" = yes ] && [ "$(sv tested)" = no ]'
check "status.sh: 상태 파일과 한 줄 요약에 NEMESIS·Korea Projection·제보 문구 없음" '! grep -qE "NEMESIS|Korea Projection|제보|QR" $T/status.txt $T/st.out'
streset; rm -f $T/sinst; stsh
check "status.sh: HMG-API가 없으면 verdict=nohmgapi(1.1.0-rc.8 이상을 먼저)" '[ "$(sv verdict)" = nohmgapi ] && grep -q "1.1.0-rc.8 이상" $T/status.txt'
streset; printf 'version 1.1.0-rc.7\n' > $T/sinst; stsh
check "status.sh: HMG-API 1.1.0-rc.7(2.0.x가 받던 판)은 rc 꼬리까지 비교해 verdict=oldhmgapi" '[ "$(sv verdict)" = oldhmgapi ] && grep -q "1.1.0-rc.8 이상으로" $T/status.txt' || cat $T/status.txt
streset; printf 'version 1.1.0-rc.10\n' > $T/sinst; stsh
check "  1.1.0-rc.10은 지원(ready)" '[ "$(sv verdict)" = ready ]' || cat $T/status.txt
# 설치 진행 기록(USB 설치기가 지금 형식 그대로 씀): 이번 부팅 것만
spr() { printf 'pct=%s\nstate=%s\nstage=%s\nstart=1\nt=2\nboot=%s\nstep=\nust=1\nut=95\n' "$1" "$2" "$3" "${4:-test-boot-id}" > $T/sprog; }
streset; spr 40 run "map을 확인하는 중입니다"; stsh
check "status.sh: 이번 부팅 진행 기록 state=run → verdict=installing" '[ "$(sv verdict)" = installing ] && [ "$(sv s1)" = "설치: 진행 중" ] && [ "$(sv state)" = run ]'
streset; spr 100 reboot "설정을 마쳤습니다. 내비를 3분 후 재부팅해 주세요."; stsh
check "  state=reboot → verdict=reboot(재부팅 안내, 노랑)" '[ "$(sv verdict)" = reboot ] && [ "$(sv verdict_lv)" = 1 ] && [ "$(sv s1)" = "설치: 재부팅 필요" ]'
streset; spr 100 fail "이 차의 map을 확인하지 못했습니다(설치기 기록을 보세요)."; stsh
check "  state=fail → verdict=failed, 설치기가 쓴 이유 문장이 판정 문구(빨강)" '[ "$(sv verdict)" = failed ] && [ "$(sv verdict_lv)" = 2 ] && [ "$(sv verdict_msg)" = "이 차의 map을 확인하지 못했습니다(설치기 기록을 보세요)." ]' || cat $T/status.txt
streset; spr 100 fail "지난 부팅의 실패" other-boot; stsh
check "  지난 부팅의 진행 기록은 보지 않음(ready)" '[ "$(sv verdict)" = ready ]'
# 공식 무선 모드(requires로 걸지 않으므로 없거나 꺼진 것을 상태 화면이 알림)
streset; rm -rf $SH/mods/wireless-carplay-aa; stsh
check "status.sh: 공식 무선 모드가 없으면 verdict=nowireless(USB 설치기로 다시 설치), wm=no" '[ "$(sv verdict)" = nowireless ] && [ "$(sv wm)" = no ] && [ "$(sv verdict_lv)" = 2 ] && grep -q "USB 설치기로 다시 설치" $T/status.txt' || cat $T/status.txt
streset; : > $SH/mods/wireless-carplay-aa/.disabled; stsh
check "  HMG-API 앱에서 꺼 두었으면 verdict=wirelessoff, wm_on=no" '[ "$(sv verdict)" = wirelessoff ] && [ "$(sv wm_on)" = no ]'
streset; sed 's/2.2.0-rc.9/2.2.0-rc.5/' $SH/mods/wireless-carplay-aa/mod.json > $T/wmj; mv $T/wmj $SH/mods/wireless-carplay-aa/mod.json; stsh
check "  판이 2.2.0-rc.9보다 낮으면 verdict=oldwireless(그 판과 최소 판)" '[ "$(sv verdict)" = oldwireless ] && grep -q "2.2.0-rc.5" $T/status.txt && grep -q "2.2.0-rc.9 이상으로" $T/status.txt' || cat $T/status.txt
streset; sed 's/2.2.0-rc.9/2.2.1/' $SH/mods/wireless-carplay-aa/mod.json > $T/wmj; mv $T/wmj $SH/mods/wireless-carplay-aa/mod.json; stsh
check "  2.2.1은 지원(ready)" '[ "$(sv verdict)" = ready ] && [ "$(sv wm_ver)" = 2.2.1 ]'
# HMG-API 훅·map(마지막 부팅 기록)
streset; printf '%s\n' "x I/HMG-API: hook map: none for hyundai/nx4/kor/260902, hooks off" > $T/shlog/log.log; stsh
check "status.sh: map이 없어 훅이 꺼졌으면 verdict=hooksoff, USB 설치기를 다시 실행하라고 안내" '[ "$(sv verdict)" = hooksoff ] && [ "$(sv hookmap)" = none ] && grep -q "USB 설치기를 다시 실행" $T/status.txt' || cat $T/status.txt
# 공식 모드의 훅: 같은 지점을 replace하는 다른 모드와 겹침(#17)과 그 밖의 이유
streset; printf '%s\n' "x I/HMG-API: hook map: verified for hyundai/nx4/kor/260902, hooks on" \
  "x I/HMG-API: mods: wireless-carplay-aa not loaded: conflict: wireless-carplay-aa 2.2.0-rc.9 and kr-tbt 1.0.0 both replace framework.navigation_cluster.update_tbt_info; turn one of them off" > $T/shlog/log.log; stsh
check "status.sh: 공식 모드가 다른 모드와 훅이 겹쳐 꺼졌으면 verdict=wmhooksoff, 겹치는 모드를 끄라고 안내" '[ "$(sv verdict)" = wmhooksoff ] && [ "$(sv wm_hooks)" = off ] && grep -q "겹치는 모드를 끈" $T/status.txt' || cat $T/status.txt
streset; printf '%s\n' "x I/HMG-API: hook map: verified for hyundai/nx4/kor/260902, hooks on" "x I/HMG-API: mods: wireless-carplay-aa not loaded: hook point dipo.carplay.session_created isn't in this car's map" > $T/shlog/log.log; stsh
check "  그 밖의 이유면 HMG-API 앱의 Mods에서 이유를 보라고 안내" '[ "$(sv verdict)" = wmhooksoff ] && grep -q "Mods에서 이유를" $T/status.txt' || cat $T/status.txt
streset; printf '{"bridge": false}\n' > $SH/settings/wireless-carplay-aa.json; stsh
check "status.sh: 공식 모드 설정의 Wireless CarPlay(bridge)가 꺼졌으면 verdict=bridgeoff" '[ "$(sv verdict)" = bridgeoff ] && [ "$(sv bridge)" = off ]'
streset; echo feature:com.hkmc.software.wifihotspot > $T/features; stsh
check "status.sh: 무선 카플레이 기능이 아직 꺼져 있으면 verdict=nofeat" '[ "$(sv verdict)" = nofeat ] && [ "$(sv feat_carplay)" = no ]'
streset; echo "home" > $SH/state/wifi.txt; stsh
check "status.sh: HMG-API에 공식 모드의 프로젝션 AP 요청이 없으면 verdict=noproj" '[ "$(sv verdict)" = noproj ] && [ "$(sv proj)" = no ]'
# 연결: wlan0 주소(IPv6)의 7000번 포트 ESTABLISHED 하나
streset; echo "fe800000000000000000000000000001 03 40 20 80 wlan0" > $T/procnet/if_inet6
echo "  0: 000080FE000000000000000001000000:1B58 000080FE000000000000000002000000:C350 01 00000000:00000000 00:00000000 00000000 0 0 1" > $T/procnet/tcp6
noap; stsh
check "status.sh: 무선 카플레이가 연결돼 있으면(AP 판정보다 앞) verdict=connected, 요약 '카플레이 1대 연결됨'" '[ "$(sv verdict)" = connected ] && [ "$(sv cp_conn)" = 1 ] && [ "$(sv s3)" = "폰 연결: 카플레이 1대 연결됨" ]' || cat $T/st.out $T/status.txt
# 순정(netd)이 아닌 hostapd: 부모가 netd가 아님
streset; echo "77 (fooapd) S 1 77" > $T/sproc/99/stat; stsh
check "status.sh: 순정이 아닌 hostapd(다른 Wi-Fi 패키지)가 돌면 verdict=otherwifi, other_ap=yes" '[ "$(sv verdict)" = otherwifi ] && [ "$(sv other_ap)" = yes ] && [ "$(sv s2)" = "무선 Wi-Fi: 다른 패키지가 씀" ]' || cat $T/status.txt
streset; printf 'interface=wlan0\nssid=NX4 Hotspot\n' > $T/hapd.conf; stsh
check "status.sh: AP가 일반 핫스팟 SSID(S1)로 떠 있으면 verdict=aphotspot, ap_mode=hotspot" '[ "$(sv verdict)" = aphotspot ] && [ "$(sv ap_mode)" = hotspot ] && [ "$(sv verdict_lv)" = 1 ]' || cat $T/status.txt
streset; echo "555 wifi 0:00 /system/bin/wpa_supplicant -iwlan0 -Dnl80211" > $T/ps.out; stsh
check "status.sh: AP 없이 Wi-Fi 클라이언트가 돌면 verdict=wificlient" '[ "$(sv verdict)" = wificlient ] && [ "$(sv wpa)" = yes ] && [ "$(sv ap)" = no ]' || cat $T/status.txt
# Wi-Fi 부품이 없는 차(2026-11-23 NX4HEV 260902): 순정 핫스팟 기능은 켜졌는데 칩이 SDIO에 한 번도 안 보였고, wlan0이 없고,
# HMG-API가 이번 부팅에 AP를 띄우지 못함(ap.fail만). 부팅 뒤 5분(AP_WAIT) 전에는 지기가 다시 시도하는 중이라 "켜는 중"(PR #50 리뷰 3)
streset; noap; rm -f $T/wifiseen $SH/wifi/ap.boot; cat $T/bootid > $SH/wifi/ap.fail; stsh
check "status.sh: Wi-Fi 부품이 없어 보여도 부팅 뒤 5분 전(100초)이면 verdict=apwait(부품 없음으로 굳히지 않음)" '[ "$(sv verdict)" = apwait ] && [ "$(sv ap_fail)" = yes ]' || cat $T/status.txt
echo "400.00 50.00" > $T/suptime; stsh
check "  5분이 지나면(400초) verdict=nowifipart(노랑, 동글), '안 됨'으로 끝내지 않음, 요약 '부품 없음(USB 동글 필요)'" \
  '[ "$(sv verdict)" = nowifipart ] && [ "$(sv verdict_lv)" = 1 ] && [ "$(sv verdict_end)" = no ] && [ "$(sv s2)" = "무선 Wi-Fi: 부품 없음(USB 동글 필요)" ] && [ "$(sv s1)" = "설치: 끝남" ] && [ "$(sv chip)" = no ] && [ "$(sv ap_fail)" = yes ]' || cat $T/status.txt
mkdir -p $T/sysnet/wlan0; stsh
check "  wlan0이 있으면(나중의 USB 동글 등) 부품 없음으로 보지 않음(apfail)" '[ "$(sv verdict)" = apfail ]' || cat $T/status.txt
rm -rf $T/sysnet/wlan0; grep -v wifihotspot $T/features > $T/f2; mv $T/f2 $T/features; stsh
check "  순정 핫스팟 기능(칩 전원)이 아직 꺼져 있으면 부품 없음으로 보지 않음(apfail)" '[ "$(sv verdict)" = apfail ]' || cat $T/status.txt
streset; noap; rm -f $SH/wifi/ap.boot; cat $T/bootid > $SH/wifi/ap.fail; echo "400.00 50.00" > $T/suptime; stsh
check "status.sh: 칩을 본 적이 있는데 부팅 뒤 5분이 지나도 AP를 못 띄움(ap.fail) → verdict=apfail(wifi.log 안내)" '[ "$(sv verdict)" = apfail ] && grep -q "wifi.log" $T/status.txt' || cat $T/status.txt
streset; noap; stsh
check "status.sh: 이번 부팅에 떴던 AP가 지금 꺼져 있으면 verdict=apoff" '[ "$(sv verdict)" = apoff ] && [ "$(sv ap_boot)" = yes ]' || cat $T/status.txt
streset; noap; echo other-boot > $SH/wifi/ap.boot; stsh
check "status.sh: 지난 부팅의 기록뿐이고 부팅 뒤 5분 전이면 verdict=apwait(켜는 중)" '[ "$(sv verdict)" = apwait ] && [ "$(sv ap_boot)" = no ] && [ "$(sv s2)" = "무선 Wi-Fi: 켜는 중" ]' || cat $T/status.txt
echo "400.00 50.00" > $T/suptime; stsh
check "  부팅 뒤 5분이 지나도 기록이 없으면 verdict=apfail(켜지 않았음)" '[ "$(sv verdict)" = apfail ] && grep -q "켜지 않았습니다" $T/status.txt' || cat $T/status.txt
rm -f $T/ps.out $T/features

# status.sh --watch: 상태 화면의 [지금 재부팅] 요청(앱 개인 폴더의 reboot.req)을 받는 감시자
RW=$T/rw; rm -rf $RW; mkdir -p $RW/w $RW/bk $RW/proc
printf '#!/bin/sh\necho reboot >> %s/rbcalls\nexit 1\n' $RW > $T/bin/fakereboot; chmod +x $T/bin/fakereboot
echo "100.00 50.00" > $RW/uptime; echo 200 > $RW/w/watch.until
(env PATH=$P0 BB=$T/bin/bb APP=$TP W=$RW/w BK=$RW/bk PROG=$RW/prog NOTICE=$RW/notice BOOT_ID=$T/bootid UPTIME=$RW/uptime PROC=$RW/proc \
   NX4_RBREQ=$RW/reboot.req RBRES=$RW/rbres WATCHF=$RW/watchf NX4_REBOOT=$T/bin/fakereboot NX4_SYNC=true NX4_RB_WAIT=1 NX4_APLOG=$RW/ap.log \
   HOOKSTARTS=$RW/nostarts HMGINST=$RW/noinst NX4_DMESG=$T/sdmesg sh $TP/bin/status.sh --watch) > $RW/watch.out 2>&1 &
RWP=$!
# 감시자가 결과 파일에 이 요청 id와 code를 쓸 때까지 기다린다(최대 약 10초)
rbwait() { _k=0; until grep -qx "id=$1" $RW/rbres 2>/dev/null || [ $_k -ge 100 ]; do /bin/sleep 0.1; _k=$((_k+1)); done; }
rbreq() { echo "$1 $2 $3" > $RW/reboot.req.tmp; mv -f $RW/reboot.req.tmp $RW/reboot.req; rbwait $1; }
rbreq 5001 test-boot-id 95
check "status.sh --watch: 이번 부팅의 새 요청(5초 전) → sync 뒤 reboot을 부름, 명령이 돌아오면 결과 code=cmd(앱은 RESET 안내), 요청 지움" \
  '[ "$(grep -c reboot $RW/rbcalls 2>/dev/null)" = 1 ] && grep -qx "code=cmd" $RW/rbres && [ ! -f $RW/reboot.req ] && grep -q "상태 화면에서 재부팅 요청" $RW/ap.log'
rbreq 5002 other-boot 95
check "  지난 부팅의 요청 → reboot 안 부름, code=bad" '[ "$(grep -c reboot $RW/rbcalls)" = 1 ] && grep -qx "code=bad" $RW/rbres'
rbreq 5003 test-boot-id 30
check "  40초보다 오래된 요청 → reboot 안 부름, code=old" '[ "$(grep -c reboot $RW/rbcalls)" = 1 ] && grep -qx "code=old" $RW/rbres'
printf 'pct=40\nstate=run\nstage=x\nt=1\nboot=test-boot-id\nut=95\n' > $RW/prog
rbreq 5004 test-boot-id 95
check "  설치가 진행 중(이번 부팅 run, 마지막 기록 5초 전) → reboot 안 부름, code=install" '[ "$(grep -c reboot $RW/rbcalls)" = 1 ] && grep -qx "code=install" $RW/rbres'
kill $RWP 2>/dev/null; wait $RWP 2>/dev/null
check "  감시자가 끝 시각 파일(boot·until, 앱이 읽음)을 씀" 'grep -qx "boot=test-boot-id" $RW/watchf && grep -qx "until=200" $RW/watchf'

# --- scripts/fetch-busybox.sh: Alpine 패키지에서 busybox만 꺼내, 패키지와 busybox가 NOTICE.md의 SHA-256과 맞을 때만 둔다 ---
# 인터넷 없이: 가짜 apk(gzip tar, bin/busybox.static)를 file://로 주고, 그 SHA-256들을 적은 가짜 NOTICE.md 옆에 스크립트를 둔다
FB=$T/fb; mkdir -p $FB/scripts; cp $B/scripts/fetch-busybox.sh $FB/scripts/
sha256() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
# 가짜 NOTICE.md: $1 = 패키지(apk) 파일, $2 = busybox SHA-256(NOTICE.md BusyBox 절과 같은 꼴)
fbnotice() { printf '## BusyBox (GPL-2.0)\n  - SHA-256 `%s`\n  - 패키지 파일 `x.apk`(armv7)의 apk SHA-256 `%s`\n' "$2" "$(sha256 $1)" > $FB/NOTICE.md; }
mkapk() { python3 - "$@" <<'PY'
import io, sys, tarfile
out, name = sys.argv[1], sys.argv[2]
with tarfile.open(out, "w:gz") as t:
    for n, data in ((".PKGINFO", b"pkgname = busybox-static\n"), (name, b"\177ELF fake busybox\n")):
        i = tarfile.TarInfo(n); i.size = len(data); i.mode = 0o755
        t.addfile(i, io.BytesIO(data))
PY
}
mkapk $T/fb-pkg.apk bin/busybox.static
mkapk $T/fb-nobb.apk bin/busybox
printf '\177ELF fake busybox\n' > $T/fb-bb
FBSHA=$(sha256 $T/fb-bb)
fbrun() { (env NX4_BUSYBOX_URL="$1" sh "$2" "$3") > $T/fb.out 2>&1; echo $? > $T/fb.rc; }
fbnotice $T/fb-pkg.apk $FBSHA
fbrun file://$T/fb-pkg.apk $FB/scripts/fetch-busybox.sh $T/fb-out
check "fetch-busybox: 패키지의 bin/busybox.static을 꺼내 busybox(0755)로, SHA-256을 적은 GPL-2.0 안내(대응 소스 위치)와 함께 둠" \
  '[ "$(cat $T/fb.rc)" = 0 ] && cmp -s $T/fb-out/busybox $T/fb-bb && [ -x $T/fb-out/busybox ] && grep -q "$FBSHA" $T/fb-out/busybox-LICENSE.txt && grep -q "GPL" $T/fb-out/busybox-LICENSE.txt && grep -q "busybox-1.36.1.tar.bz2" $T/fb-out/busybox-LICENSE.txt' || cat $T/fb.out
cp $T/fb-out/busybox-LICENSE.txt $T/fb-notice; echo "old notice" > $T/fb-out/busybox-LICENSE.txt
fbrun file://$T/none.apk $FB/scripts/fetch-busybox.sh $T/fb-out
check "fetch-busybox: 같은 SHA-256의 busybox가 이미 있으면 다시 받지 않고, 라이선스 안내는 지금 문구로 다시 씀" \
  '[ "$(cat $T/fb.rc)" = 0 ] && grep -q "이미 받아 둠" $T/fb.out && cmp -s $T/fb-out/busybox-LICENSE.txt $T/fb-notice' || cat $T/fb.out
fbrun file://$T/fb-pkg.apk $B/scripts/fetch-busybox.sh $T/fb-bad
check "fetch-busybox: 받은 패키지가 NOTICE.md의 apk SHA-256과 다르면 풀기 전에 멈추고 아무것도 두지 않음" \
  '[ "$(cat $T/fb.rc)" != 0 ] && grep -q "패키지 SHA-256.*다릅니다" $T/fb.out && [ ! -e $T/fb-bad/busybox ] && [ ! -e $T/fb-bad/busybox-LICENSE.txt ]' || cat $T/fb.out
fbnotice $T/fb-pkg.apk 0000000000000000000000000000000000000000000000000000000000000000
fbrun file://$T/fb-pkg.apk $FB/scripts/fetch-busybox.sh $T/fb-bad
check "fetch-busybox: 패키지는 맞아도 꺼낸 busybox가 NOTICE.md의 SHA-256과 다르면 멈추고 아무것도 두지 않음" \
  '[ "$(cat $T/fb.rc)" != 0 ] && grep -q "^busybox SHA-256.*다릅니다" $T/fb.out && [ ! -e $T/fb-bad/busybox ] && [ ! -e $T/fb-bad/busybox-LICENSE.txt ]' || cat $T/fb.out
fbnotice $T/fb-nobb.apk $FBSHA
fbrun file://$T/fb-nobb.apk $FB/scripts/fetch-busybox.sh $T/fb-bad
check "fetch-busybox: 패키지에 bin/busybox.static이 없으면 멈춤" '[ "$(cat $T/fb.rc)" != 0 ] && grep -q "busybox.static이 없습니다" $T/fb.out && [ ! -e $T/fb-bad/busybox ]' || cat $T/fb.out
fbrun file://$T/none.apk $FB/scripts/fetch-busybox.sh $T/fb-bad
check "fetch-busybox: 받지 못하면 멈춤" '[ "$(cat $T/fb.rc)" != 0 ] && grep -q "받지 못했습니다" $T/fb.out && [ ! -e $T/fb-bad/busybox ]' || cat $T/fb.out
check "fetch-busybox: 기본 주소는 Alpine v3.20 main armv7의 busybox-static-1.36.1-r31(https), NOTICE.md에 같은 판과 SHA-256 두 개(busybox, apk)" \
  'grep -q "https://dl-cdn.alpinelinux.org/alpine/v3.20/main/armv7/busybox-static-1.36.1-r31.apk" $B/scripts/fetch-busybox.sh && grep -q "busybox-static-1.36.1-r31" $B/NOTICE.md && [ "$(grep -c "^ *- SHA-256 \`[0-9a-f]\{64\}\`" $B/NOTICE.md)" = 1 ] && [ "$(grep -c "apk SHA-256 \`[0-9a-f]\{64\}\`" $B/NOTICE.md)" = 1 ]'

# --- 끝까지: 빌드 → HMG-API 엔진에 설치(HMGAPI_SRC가 있을 때만) ---
if [ -n "$HMGAPI_SRC" ]; then
  HS=$(cd "$HMGAPI_SRC" && pwd)
  mkdir -p $T/eh && javac --release 8 -Xlint:-options -nowarn -d $T/eh $HS/core/runtime/java/hmgapi/engine/*.java 2>/dev/null
  java -cp $T/eh hmgapi.engine.Signing keygen $T/test-mod.key >/dev/null 2>&1
  echo "not a real apk" > $T/test.apk
  printf '\177ELF fake busybox' > $T/test-bb
  # HMG-API USB 묶음 흉내(HMGAPI/install/payload, ota_package.tar 안의 troubleShooter)
  mkdir -p $T/hu/HMGAPI/install/payload $T/hu/HMGAPI/updates; echo "# HMG-API troubleShooter" > $T/hu/troubleShooter; echo 1.1.0 > $T/hu/HMGAPI/install/payload/VERSION
  # HMG-API 릴리스 묶음처럼 HMG-API 앱용 업데이트·공식 모드 묶음(HMGAPI/updates)도 둔다(우리 묶음에서는 빠져야 함)
  echo zip > $T/hu/HMGAPI/updates/wireless-carplay-aa-2.2.0-rc.5.zip
  python3 -c 'import tarfile,sys; t=tarfile.open(sys.argv[1],"w"); t.add(sys.argv[2],"troubleShooter"); t.close()' $T/hu/ota_package.tar $T/hu/troubleShooter
  printf '[nemesis]\n' > $T/hu/NEMESIS.data; echo hmgapi > $T/hu/README.txt; rm $T/hu/troubleShooter
  (cd $T/hu && zip -q -r $T/hmgapi-usb.zip .)
  bld() { (HMGAPI_SRC=$HS NX4_MOD_KEY=$T/test-mod.key NX4_APK=$T/test.apk HMGAPI_USB_ZIP=$T/hmgapi-usb.zip "$@" sh $B/scripts/build.sh) > $T/build.out 2>&1; echo $? > $T/build.rc; }
  # busybox(GPL-2.0)를 넣는데 그 라이선스 안내가 없으면 만들지 않는다
  bld env NX4_BUSYBOX=$T/test-bb OUT=$T/out-nolic
  check "빌드: busybox를 넣는데 라이선스 안내가 없으면 만들지 않음" '[ "$(cat $T/build.rc)" != 0 ] && grep -q "라이선스 안내" $T/build.out && [ ! -f $T/out-nolic/hmgapi-nx4-kor-$V-usb.zip ]'
  echo "BusyBox GPL-2.0 test notice" > $T/test-bb-LICENSE.txt
  bld env NX4_BUSYBOX=$T/test-bb OUT=$T/out
  check "빌드: 모드 zip과 USB 묶음을 만듦" '[ "$(cat $T/build.rc)" = 0 ] && [ -f $T/out/hmgapi-nx4-kor-$V.zip ] && [ -f $T/out/hmgapi-nx4-kor-$V-usb.zip ]' || cat $T/build.out
  rm -rf $T/ux; mkdir -p $T/ux; (cd $T/ux && unzip -q $T/out/hmgapi-nx4-kor-$V-usb.zip)
  check "USB 묶음: HMG-API 앱용 업데이트·공식 모드 묶음(HMGAPI/updates)은 넣지 않음, HMGAPI-SOURCE.txt에 뺀 것을 적음" \
    '[ ! -e $T/ux/HMGAPI/updates ] && grep -q "HMGAPI/updates" $T/ux/HMGAPI-SOURCE.txt'
  check "USB 묶음: ota_package.tar = 우리 troubleShooter(0755, root), HMG-API 설치기는 NX4/hmgapi로, NEMESIS.data 뺌, README 판 채움" \
    'python3 -c "import tarfile,sys; t=tarfile.open(sys.argv[1]); m=t.getmembers(); assert [x.name for x in m]==[\"troubleShooter\"] and m[0].mode==0o755 and m[0].uid==0; assert t.extractfile(\"troubleShooter\").read()==open(sys.argv[2],\"rb\").read()" $T/ux/ota_package.tar $B/usb/troubleShooter && grep -q "HMG-API troubleShooter" $T/ux/NX4/hmgapi/troubleShooter && [ ! -f $T/ux/NEMESIS.data ] && [ -d $T/ux/HMGAPI/install/payload ] && grep -q "NX4 KOR $V" $T/ux/README.txt'
  P=$T/ux/NX4/install/payload
  check "USB 묶음: payload = 서명된 모드를 푼 것(mod.json, 스크립트, 앱, busybox, 서명), 한국 포크 무선 부분(훅·레시피·패치·설정)과 핫스팟 서비스 없음" \
    '[ -f $P/mod.json ] && [ -f $P/svc/launch.sh ] && [ -f $P/svc/lib.sh ] && [ -f $P/bin/status.sh ] && [ -f $P/bin/uninstall.sh ] && [ -f $P/scripts/preun.sh ] && [ -f $P/app/NX4KOR.apk ] && [ -f $P/bin/busybox ] && [ -d $P/META-HMGAPI ] && [ ! -e $P/hooks.jar ] && [ ! -e $P/recipes ] && [ ! -e $P/files ] && [ ! -e $P/patches.json ] && [ ! -e $P/settings.json ] && [ ! -e $P/svc/ap.sh ] && [ ! -e $P/svc/hotspot.sh ] && [ ! -d $P/hmgapi ] && [ ! -d $P/patches ]'
  check "라이선스: 모드에 LICENSE·NOTICE.md·bin/busybox-LICENSE.txt, USB 맨 위에 LICENSE·NOTICE.md·BUSYBOX-LICENSE.txt(저장소와 같은 내용)" \
    'cmp -s $P/LICENSE $B/LICENSE && cmp -s $P/NOTICE.md $B/NOTICE.md && cmp -s $P/bin/busybox-LICENSE.txt $T/test-bb-LICENSE.txt && cmp -s $T/ux/LICENSE $B/LICENSE && cmp -s $T/ux/NOTICE.md $B/NOTICE.md && cmp -s $T/ux/BUSYBOX-LICENSE.txt $T/test-bb-LICENSE.txt'
  check "라이선스: HMG-API를 함께 넣으면 HMGAPI-SOURCE.txt에 판과 대응 소스(태그), README.txt에 이 묶음의 소스 커밋" \
    'grep -q "^HMG-API 1.1.0:" $T/ux/HMGAPI-SOURCE.txt && grep -q "https://github.com/Open-HMG/HMG-API/tree/v1.1.0" $T/ux/HMGAPI-SOURCE.txt && grep -q "AGPL-3.0" $T/ux/HMGAPI-SOURCE.txt && grep -q "https://github.com/jay-park-lab/hmgapi-nx4-kor (이 묶음: [0-9a-f]\{7,\}" $T/ux/README.txt && ! grep -q "@SOURCE_REV@" $T/ux/README.txt'
  check "모드 zip: 앱 메뉴 타일 그림 넷(icons/)이 저장소의 mod/icons 그대로 들어감" 'python3 - $T/out/hmgapi-nx4-kor-$V.zip $PKG/icons <<PY
import os, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for n in ("icon.png", "icon_night.png", "icon_disabled.png", "icon_disabled_night.png"):
    assert z.read("icons/" + n) == open(os.path.join(sys.argv[2], n), "rb").read(), n
PY'
  # NX4_BUSYBOX로 준 파일이 없으면 busybox 없이 만들지 않고 멈춘다
  bld env NX4_BUSYBOX=$T/nobb OUT=$T/out-missing
  check "빌드: NX4_BUSYBOX로 준 파일이 없으면 만들지 않음" '[ "$(cat $T/build.rc)" != 0 ] && grep -q "busybox가 없습니다" $T/build.out && [ ! -f $T/out-missing/hmgapi-nx4-kor-$V-usb.zip ]'
  # NX4_BUSYBOX를 주지 않으면 Alpine에서 받는다: 받은 busybox가 NOTICE.md의 SHA-256과 다르면 만들지 않는다
  # (가짜 패키지를 file://로 준다. 이 PC의 mod/bin/busybox가 있으면 받지 않으므로 건너뛴다)
  if [ ! -f $PKG/bin/busybox ]; then
    bld env -u NX4_BUSYBOX NX4_BUSYBOX_URL=file://$T/fb-pkg.apk OUT=$T/out-fetch
    check "빌드: NX4_BUSYBOX가 없으면 Alpine 패키지를 받고, SHA-256이 NOTICE.md와 다르면 만들지 않음" \
      '[ "$(cat $T/build.rc)" != 0 ] && grep -q "NOTICE.md" $T/build.out && grep -q "다릅니다" $T/build.out && [ ! -f $T/out-fetch/busybox/busybox ] && [ ! -f $T/out-fetch/hmgapi-nx4-kor-$V-usb.zip ]' || cat $T/build.out
  fi
  # NX4_BUSYBOX=none이면 busybox 없이 만들고, 그 안내도 없다(HMG-API도 함께 넣지 않으면 HMGAPI-SOURCE.txt도 없다)
  (HMGAPI_SRC=$HS NX4_MOD_KEY=$T/test-mod.key NX4_APK=$T/test.apk NX4_BUSYBOX=none OUT=$T/out-nobb sh $B/scripts/build.sh) > $T/build.out 2>&1; echo $? > $T/build.rc
  rm -rf $T/ux2; mkdir -p $T/ux2; (cd $T/ux2 && unzip -q $T/out-nobb/hmgapi-nx4-kor-$V-usb.zip 2>/dev/null)
  check "라이선스: NX4_BUSYBOX=none·HMG-API 없이 만들면 busybox·BUSYBOX-LICENSE.txt·HMGAPI-SOURCE.txt 없음, LICENSE·NOTICE.md는 있음" \
    '[ "$(cat $T/build.rc)" = 0 ] && grep -q "NX4_BUSYBOX=none" $T/build.out && [ ! -f $T/ux2/NX4/install/payload/bin/busybox ] && [ ! -f $T/ux2/BUSYBOX-LICENSE.txt ] && [ ! -f $T/ux2/NX4/install/payload/bin/busybox-LICENSE.txt ] && [ ! -f $T/ux2/HMGAPI-SOURCE.txt ] && [ -f $T/ux2/LICENSE ] && [ -f $T/ux2/NOTICE.md ]' || cat $T/build.out
  # HMG-API 엔진(PC JVM)으로 설치: 가짜 헤드유닛. 이 모드는 HMG-API 1.1.0-rc.8 이상을 요구한다(mod.json "hmgapi").
  # 엔진은 자기 판(Engine.HMGAPI_VERSION)으로 그것을 보므로, HMGAPI_SRC가 그보다 낮으면 설치 시험을 할 수 없다
  MV=$(sed -n 's/.*"hmgapi": *">=\([^"]*\)".*/\1/p' $PKG/mod.json)
  HSV=$(sed -n 's/.*HMGAPI_VERSION = "\(.*\)";/\1/p' $HS/core/runtime/java/hmgapi/engine/Engine.java)
  eng() { (HMGAPI_ROOT=$1 HMGAPI_HOST=1 HMGAPI_PRODUCT=$2 java -cp $T/eh hmgapi.engine.Engine install $T/out/hmgapi-nx4-kor-$V.zip) > $T/eng.out 2>&1; echo $? > $T/eng.rc; }
  for prod in NX4.KOR.0000.V039.001.260902 CVEV.USA.0000.V015 DEPEHEV.KOR.0000.V039.001.260902 NX4.KOR.0000.V040.001.261101; do
    ER=$T/er-$prod; mkdir -p $ER/system/etc/permissions $ER/data/hmgapi/mods $ER/data/hmgapi/settings
    printf 'ro.build.product=%s\n' $prod > $ER/system/build.prop
    printf 'version %s\n' "$HSV" > $ER/data/hmgapi/installed.txt
  done
  ER=$T/er-NX4.KOR.0000.V039.001.260902; eng $ER NX4.KOR.0000.V039.001.260902
  if env PATH=$P0 BB=$T/bin/bb APP=$TP sh -c '. $APP/svc/lib.sh; ver_lt "$1" "$2"' x "$HSV" "$MV"; then
    check "HMG-API 엔진($HSV): 최소 판($MV)보다 낮은 HMG-API는 이 모드를 거절함" '[ "$(cat $T/eng.rc)" != 0 ] && grep -q "needs HMG-API >=$MV" $T/eng.out' || cat $T/eng.out
    bad "HMG-API 엔진 설치 시험: HMGAPI_SRC의 HMG-API($HSV)가 이 모드의 최소 판($MV)보다 낮아 설치·계획을 볼 수 없음. HMGAPI_SRC를 v$MV 이상으로 올려 주세요"
  else
  # hmgapid는 상대 경로를 /data/hmgapi/mods/<모드>/ 아래로 푼다(svc_start): sh /data/hmgapi/mods/nx4-kor/svc/launch.sh
  check "HMG-API 엔진($HSV): NX4.KOR 260902에 설치됨(서명 확인), 서비스는 launch(root, manual) 하나, 앱이 등록됨, 훅·무선 파일 없음" \
    '[ "$(cat $T/eng.rc)" = 0 ] && grep -q "installed nx4-kor $V (author key" $T/eng.out && [ "$(grep -c "^nx4-kor " $ER/data/hmgapi/state/services.txt)" = 1 ] && grep -q "^nx4-kor launch root manual " $ER/data/hmgapi/state/services.txt && grep -qx "io.github.jayparklab.nx4kor nx4-kor" $ER/data/hmgapi/state/apps.txt && [ ! -e $ER/data/hmgapi/mods/nx4-kor/hooks.jar ] && [ ! -e $ER/data/hmgapi/mods/nx4-kor/recipes ]' || { cat $T/eng.out; cat $ER/data/hmgapi/state/services.txt; }
  engp() { (HMGAPI_ROOT=$ER HMGAPI_HOST=1 HMGAPI_PRODUCT=NX4.KOR.0000.V039.001.260902 java -cp $T/eh hmgapi.engine.Engine $1) > $T/engp.out 2>&1; echo $? > $T/engp.rc; }
  # 참고: $1은 따옴표 없이 넘겨 "remove nx4-kor"처럼 두 낱말도 받는다
  # 계획에는 지금 켜진 것의 설명 줄(app·service, HMG-API 기본 network  no cellular [nx4-kor] 등)만 나오고, 적용하면 할 것이 없다
  engp plan
  check "HMG-API 엔진 계획: 이 모드의 줄은 설명뿐(change·restore·setting 줄 없음), 문제 없음" \
    '[ "$(cat $T/engp.rc)" = 0 ] && ! grep -E "\[nx4-kor\]" $T/engp.out | grep -qvE "^(app|service|network) " && grep -q "^app .*io.github.jayparklab.nx4kor.*\[nx4-kor\]" $T/engp.out && ! grep -qiE "problem|conflict|requires" $T/engp.out' || cat $T/engp.out
  engp apply
  check "  적용하면 할 것이 없음(nothing to do): 이 모드는 시스템 파일·설정을 바꾸지 않음" '[ "$(cat $T/engp.rc)" = 0 ] && grep -qx "nothing to do" $T/engp.out' || cat $T/engp.out
  engp "remove nx4-kor"
  check "  engine remove만으로 앱·서비스 목록(state/apps.txt·services.txt)에서 빠짐: hmgapid가 내리므로 지울 때 적용하지 않음(preun.sh)" \
    '[ "$(cat $T/engp.rc)" = 0 ] && ! grep -q "nx4-kor" $ER/data/hmgapi/state/services.txt && ! grep -q "io.github.jayparklab.nx4kor" $ER/data/hmgapi/state/apps.txt && [ ! -d $ER/data/hmgapi/mods/nx4-kor ]' || { cat $T/engp.out; cat $ER/data/hmgapi/state/services.txt $ER/data/hmgapi/state/apps.txt; }
  for prod in CVEV.USA.0000.V015 DEPEHEV.KOR.0000.V039.001.260902 NX4.KOR.0000.V040.001.261101; do
    ER=$T/er-$prod; eng $ER $prod
    check "HMG-API 엔진: $prod 에는 설치하지 않음(NX4.KOR 260902 전용)" '[ "$(cat $T/eng.rc)" != 0 ] && grep -q "refused" $T/eng.out && ! grep -q "needs HMG-API" $T/eng.out && [ ! -d $ER/data/hmgapi/mods/nx4-kor ]' || cat $T/eng.out
  done
  fi
  # HMG-API가 모드를 설치할 때 보는 판 차례(Packages.check의 Version, 낮은 판은 --force 없이 거절): 베타 판이 정식보다 낮고 서로 차례대로
  cat > $T/VerChk.java <<'J'
import hmgapi.engine.Version;
public class VerChk {
    public static void main(String[] a) {
        for (int i = 0; i + 1 < a.length; i++) {
            if (new Version(a[i]).compareTo(new Version(a[i + 1])) >= 0) { System.out.println("not lower: " + a[i] + " " + a[i + 1]); System.exit(1); }
        }
        System.out.println("ok");
    }
}
J
  javac --release 8 -Xlint:-options -nowarn -cp $T/eh -d $T/eh $T/VerChk.java 2>/dev/null
  java -cp $T/eh VerChk 2.0.2 2.0.3 2.0.4-beta.1 2.0.4-beta.2 2.0.4-beta.10 2.0.4 2.0.5-beta.1 > $T/verchk.out 2>&1
  check "HMG-API 판 차례(모드 설치가 보는 것): 2.0.3(꼬리 없는 v2.0.3-beta.1) < 2.0.4-beta.1 < 2.0.4-beta.2 < 2.0.4-beta.10 < 2.0.4 < 2.0.5-beta.1" 'grep -qx ok $T/verchk.out' || cat $T/verchk.out
  java -cp $T/eh VerChk 2.0.3-beta.2 2.0.3 > $T/verchk.out 2>&1
  check "  정식 2.0.3이 들어간 차에는 2.0.3-beta.2가 낮은 판(그래서 새 방식은 2.0.4-beta.1부터)" 'grep -qx ok $T/verchk.out' || cat $T/verchk.out
else
  echo "skip 빌드·HMG-API 엔진 시험(HMGAPI_SRC 없음)"
fi

echo
if [ $fails = 0 ]; then echo "모두 통과"; else echo "실패 $fails개"; exit 1; fi
