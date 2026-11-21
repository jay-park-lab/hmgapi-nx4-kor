#!/bin/sh
# PC(맥)에서 NX4 KOR 모드의 스크립트를 가짜 헤드유닛으로 돌린다.
#   sh tests/mod-test.sh                 스크립트 시험(실패하면 FAIL 줄과 종료 코드 1)
#   HMGAPI_SRC=<HMG-API 저장소> sh tests/mod-test.sh
#                                        + 임시 키로 scripts/build.sh를 끝까지 돌리고, 만든 모드를 HMG-API 엔진
#                                          (PC JVM)에 설치해 서비스·앱 등록과 차종 제한(NX4.KOR 260902만)을 본다
#                                          (HMGAPI_SRC는 .env.local에 적어도 된다)
# 가짜 도구: hmgapid, pm, am, getprop, settings, svc, sleep. 서비스 래퍼는 가짜 스크립트를 부르게 해서 넘기는 값을 보고,
# post.sh·preun.sh·hotspot.sh(setup_hmgapi)는 진짜를 돌린다.
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

# --- mod.json: NX4 KOR 모드 + 합친 무선 모드(2.4.5) ---
check "mod.json: 서비스·앱·런처, NX4.KOR 260902만, HMG-API 1.1.0-rc.4 이상, 따로 설치하는 무선 모드와 충돌 선언" 'python3 - "$PKG" <<PY
import json, os, sys
d = sys.argv[1]
m = json.load(open(os.path.join(d, "mod.json")))
assert m["id"] == "nx4-kor"
assert m["hmgapi"] == ">=1.1.0-rc.4", m["hmgapi"]
for s in m["services"]:
    assert os.path.isfile(os.path.join(d, s["script"])), s
assert {s["name"]: s["start"] for s in m["services"]} == {"ap": "android", "launch": "manual"}
assert all(s["user"] == "root" for s in m["services"])
assert m["apps"] == [{"apk": "app/NX4KOR.apk", "package": "io.github.jayparklab.nx4kor"}], m["apps"]
assert m["system"] == {"model": ["NX4", "NX4HEV"], "region": ["KOR"], "firmware": ["260902"]}
assert m["provides"]["launcher"][0]["class"] == ".StatusActivity"
assert m["conflicts"] == ["wireless-carplay-aa"]
assert "logs" not in m
PY'
check "mod.json: 무선 부분(parts·feature_flags·hooks)이 wireless/mod-2.4.5.json과 같고, 훅 jar·레시피·파일·설정이 있음" 'python3 - "$PKG" "$B/wireless/mod-2.4.5.json" <<PY
import json, os, sys
d = sys.argv[1]
m = json.load(open(os.path.join(d, "mod.json"))); w = json.load(open(sys.argv[2]))
for k in ("parts", "feature_flags", "hooks"):
    assert m[k] == w[k], k
assert os.path.isfile(os.path.join(d, m["hooks"]["jar"]))
for lib, rs in m["hooks"]["native"].items():
    for r in rs:
        assert os.path.isfile(os.path.join(d, r)), r
p = json.load(open(os.path.join(d, "patches.json")))
assert list(p) == ["changes"], list(p)
for c in p["changes"]:
    if "src" in c: assert os.path.isfile(os.path.join(d, c["src"])), c
s = json.load(open(os.path.join(d, "settings.json")))
keys = [x["key"] for x in s["settings"]]
assert keys == ["tbt", "tbt_fit", "bridge", "audio", "now_playing", "menu", "usb_drives", "aa_ready_resend", "aa_name_hold", "star_popup_skip"], keys
assert not os.path.exists(os.path.join(d, "patches")) and not os.path.exists(os.path.join(d, "stubs"))
PY'
check "hotspot.sh: 모드 id·HMG-API 최소 판이 mod.json과 같음, env.sh의 NX4_MOD_ID도 같음" \
  'grep -q "^MOD_ID=\${NX4_MOD_ID:-nx4-kor}$" $PKG/svc/hotspot.sh && grep -q "^HMG_MIN=1.1.0-rc.4$" $PKG/svc/hotspot.sh && grep -q "^NX4_MOD_ID=nx4-kor$" $PKG/svc/env.sh'
check "launch 서비스 이름 = 앱이 부르는 이름" 'grep -q "\"service-start\", \"launch\"" $B/app/java/io/github/jayparklab/nx4kor/StatusActivity.java'
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

# 가짜 모드 폴더: 래퍼(svc/ap.sh·launch.sh·env.sh, bin/uninstall.sh)는 진짜, 나머지 스크립트 자리에는 받은 환경을 적는 가짜.
# 가짜 preun.sh는 진짜처럼 삭제 때 HMG-API에서 이 모드를 뺀다
mkfix() {
  rm -rf $1; mkdir -p $1; cp -R $PKG/. $1/
  for s in scripts/post.sh svc/hotspot.sh bin/status.sh; do
    printf '#!/bin/sh\necho "%s NX4_APP=$NX4_APP APP=$APP BK=$BK APLOG=$APLOG NX4_UPDATE=$NX4_UPDATE NX4_APLOG=$NX4_APLOG" >> %s/stublog\necho "out of %s"\n' $s $T $s > $1/$s
  done
  printf '#!/bin/sh\necho "scripts/preun.sh NX4_APP=$NX4_APP APP=$APP BK=$BK APLOG=$APLOG NX4_UPDATE=$NX4_UPDATE NX4_APLOG=$NX4_APLOG" >> %s/stublog\n[ "$NX4_UPDATE" = 1 ] || { command -v hmgapid >/dev/null 2>&1 && hmgapid engine remove nx4-kor >/dev/null; }\nexit 0\n' $T > $1/scripts/preun.sh
  mkdir -p $1/app; echo apk > $1/app/NX4KOR.apk
}

# --- ap.sh ---
F=$T/mod; mkfix $F
apr() { (env -u NX4_APP PATH=$P0 HMGAPI_MOD_DIR=$F NX4_ROOT=$T/kp sh $F/svc/ap.sh) > $T/ap.out 2>&1; }
rm -f $T/stublog; apr
check "ap.sh: 처음에 post.sh를 한 번 돌리고 표시(post.done)를 남김" 'grep -q "^scripts/post.sh" $T/stublog && [ -f $T/kp/backup/post.done ]'
check "ap.sh: hotspot.sh에 위치를 넘김(APP=모드 폴더, BK·APLOG는 /data/nx4-kor 아래)" \
  'grep -q "^svc/hotspot.sh NX4_APP=$F APP=$F BK=$T/kp/backup APLOG=$T/kp/logs/ap.log NX4_UPDATE= NX4_APLOG=$T/kp/logs/ap.log" $T/stublog'
check "ap.sh: hotspot.sh 출력은 APLOG로(덧붙이기), 래퍼의 줄은 hmgapid 기록으로" 'grep -q "out of svc/hotspot.sh" $T/kp/logs/ap.log && ! grep -q "out of svc/hotspot.sh" $T/ap.out && grep -q "hotspot.sh 시작" $T/ap.out'
rm -f $T/stublog; apr
check "ap.sh: 두 번째 시작에는 post.sh를 다시 돌리지 않음" '! grep -q "^scripts/post.sh" $T/stublog && grep -q "^svc/hotspot.sh" $T/stublog'

# --- launch.sh ---
rm -f $T/stublog
(env -u NX4_APP PATH=$P0 HMGAPI_MOD_DIR=$F NX4_ROOT=$T/kp sh $F/svc/launch.sh) > $T/l.out 2>&1
check "launch.sh: bin/status.sh를 모드 위치로 돌림(NX4_APLOG로 ap.log 위치를 넘김)" 'grep -q "^bin/status.sh NX4_APP=$F APP=$F BK=$T/kp/backup APLOG=$T/kp/logs/ap.log NX4_UPDATE= NX4_APLOG=$T/kp/logs/ap.log" $T/stublog'

# --- uninstall.sh ---
ur() { (env -u NX4_APP PATH=$P0 HMGDATA=$HD NX4_ROOT=$T/kp sh $1/bin/uninstall.sh $2) > $T/u.out 2>&1; echo $? > $T/u.rc; }
mkdir -p $HD/mods; rm -rf $HD/mods/nx4-kor; cp -R $F $HD/mods/nx4-kor; I=$HD/mods/nx4-kor
mkdir -p $T/kp/backup; : > $T/kp/backup/post.done; : > $T/ap-running; : > $T/calls; rm -f $T/stublog
ur $I --update
check "uninstall.sh --update: 서비스 ap를 멈추고 멈출 때까지 기다림" 'grep -qx "hmgapid service-stop nx4-kor ap" $T/calls && grep -q "hmgapid services nx4-kor" $T/calls'
check "uninstall.sh --update: preun.sh를 NX4_UPDATE=1로(업데이트 갈래), 모드는 지우지 않음, post.done을 지워 새 판이 post.sh를 다시 돌리게" \
  'grep -q "^scripts/preun.sh NX4_APP=$I .*NX4_UPDATE=1" $T/stublog && ! grep -q "engine remove" $T/calls && [ -d $I ] && [ ! -f $T/kp/backup/post.done ] && [ "$(cat $T/u.rc)" = 0 ]'
: > $T/calls; rm -f $T/stublog
ur $I
check "uninstall.sh: preun.sh(삭제 갈래, HMG-API에서 모드를 뺌) → /data/nx4-kor 지움" \
  'grep -q "^scripts/preun.sh NX4_APP=$I .*NX4_UPDATE= " $T/stublog && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $I ] && [ ! -d $T/kp ] && [ "$(cat $T/u.rc)" = 0 ]'
# preun.sh가 모드를 빼지 못했으면(HMG-API 앱에서 지워야 함) 실패로 끝내고 알림
cp -R $F $I; printf '#!/bin/sh\nexit 0\n' > $I/scripts/preun.sh; mkdir -p $T/kp; : > $T/calls
ur $I
check "uninstall.sh: 모드가 HMG-API에 남았으면 실패(1)로 끝내고 HMG-API 앱에서 지우라고 알림" '[ "$(cat $T/u.rc)" = 1 ] && grep -q "HMG-API 앱에서 NX4 KOR를 지우고" $T/u.out'
rm -rf $I
# HMG-API를 먼저 지운 경우(hmgapid 명령·installed.txt 없음): preun.sh는 그대로 돌리고, 남은 모드 폴더를 직접 지우고, 앱은 pm으로 지움
cp -R $F $I; mkdir -p $T/kp; : > $T/calls; rm -f $T/stublog
(env -u NX4_APP PATH=$P0 HMGAPID=$T/nohmgapid HMGDATA=$HD NX4_ROOT=$T/kp sh $I/bin/uninstall.sh) > $T/u.out 2>&1; echo $? > $T/u.rc
check "uninstall.sh: HMG-API를 먼저 지웠으면 preun.sh로 되돌리고, 남은 모드 폴더·앱(pm)을 직접 지움" \
  '[ "$(cat $T/u.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$I .*NX4_UPDATE= " $T/stublog && grep -qx "pm uninstall io.github.jayparklab.nx4kor" $T/calls && [ ! -d $I ] && [ ! -d $T/kp ] && grep -q "HMG-API가 먼저 지워져" $T/u.out'

# --- troubleShooter(USB 설치기) ---
R=$T/root; U=$T/usb0; K=$U/NX4
mkdir -p $R/data/local/tmp $K/install/payload
cp -R $F/. $K/install/payload/
(cd $K/install/payload && zip -q -r $K/install/hmgapi-nx4-kor.zip .)
ts() { : > $T/calls; (env -u NX4_APP PATH=$P0 ROOT=$R HMGAPID=$T/bin/hmgapid NX4_USB_DIRS="$1" NX4_APP_WAIT=4 sh $B/usb/troubleShooter) > $T/ts.out 2>&1; echo $? > $T/ts.rc; }
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
# 판 비교(HMG-API Version과 같은 규칙): 설치기의 vlt·hmg_meets만 꺼내, 구문 검사처럼 차의 셸(mksh)과 ksh·dash 중 있는 것마다 돌린다
sed -n '/^vlt() {/,/^}/p;/^hmg_meets() {/,/^}/p' $B/usb/troubleShooter > $T/vlt.sh
for VSH in $KSHS; do
  vcase() { $VSH -c '. "$1"; "$2" "$3" "$4"; echo $?' x $T/vlt.sh "$@"; }
  check "USB 설치기 판 비교($(basename $VSH)): 1.0.2 < 1.1.0-rc.3 < 1.1.0-rc.4 < 1.1.0-rc.10 < 1.1.0, beta < rc, 1.2.0-beta.1 > 1.1.0-rc.4" \
    '[ "$(vcase vlt 1.0.2 1.1.0-rc.3)$(vcase vlt 1.1.0-rc.3 1.1.0-rc.4)$(vcase vlt 1.1.0-rc.4 1.1.0-rc.10)$(vcase vlt 1.1.0-rc.10 1.1.0)$(vcase vlt 1.1.0-beta.9 1.1.0-rc.1)" = 00000 ] && [ "$(vcase vlt 1.1.0-rc.4 1.1.0-rc.4)$(vcase vlt 1.1.0 1.1.0-rc.10)$(vcase vlt 1.2.0-beta.1 1.1.0-rc.4)$(vcase vlt 1.1 1.1.0)" = 1111 ] && [ "$(vcase vlt 1.1.0-dev 1.1.0-rc)" = 2 ]'
  check "USB 설치기 판 비교($(basename $VSH)): 최소 판에 꼬리가 없으면 그 판의 rc도 채움(1.1.0-rc.1은 >=1.1.0), 꼬리가 있으면 꼬리까지 봄" \
    '[ "$(vcase hmg_meets 1.1.0-rc.1 1.1.0)$(vcase hmg_meets 1.1.0-rc.4 1.1.0-rc.4)$(vcase hmg_meets 1.1.0 1.1.0-rc.4)" = 000 ] && [ "$(vcase hmg_meets 1.0.9 1.1.0)$(vcase hmg_meets 1.1.0-rc.3 1.1.0-rc.4)" = 11 ]'
done
# HMG-API가 모드의 최소 판(mod.json "hmgapi")보다 낮으면: 따로 설치된 무선 모드를 지우기 전에, 스틱의 HMG-API 설치기로 올리거나 멈춤
NEEDV=$(sed -n 's/.*"hmgapi": *">=\([^"]*\)".*/\1/p' $PKG/mod.json)
mkdir -p $HD/mods/wireless-carplay-aa; echo '{"id": "wireless-carplay-aa"}' > $HD/mods/wireless-carplay-aa/mod.json
printf 'version 1.0.2\nbuild test\n' > $HD/installed.txt
ts $U
check "USB 설치기: HMG-API(1.0.2)가 최소 판($NEEDV)보다 낮고 스틱에 HMG-API가 없으면 아무것도 바꾸지 않고 멈춤(무선 모드도 그대로)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "HMG-API $NEEDV 이상으로 먼저 올려" $T/ts.out && ! grep -q "engine" $T/calls && [ -f $HD/mods/wireless-carplay-aa/mod.json ]'
mkdir -p $K/hmgapi $U/HMGAPI/install/payload; echo "# hmg-api" > $K/hmgapi/troubleShooter; echo $NEEDV > $U/HMGAPI/install/payload/VERSION
ts $U
check "USB 설치기: ... 스틱에 최소 판 이상의 HMG-API 설치기가 있으면 그것으로 올림(무선 모드는 그대로, 엔진을 부르지 않음)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "HMG-API 설치기로 넘김(업데이트)" $T/ts.out && grep -q "1.0.2에서 $NEEDV(으)로" $T/ts.out && ! grep -q "engine" $T/calls && [ -f $HD/mods/wireless-carplay-aa/mod.json ]'
printf 'version 1.1.0-rc.3\n' > $HD/installed.txt; echo 1.1.0-rc.3 > $U/HMGAPI/install/payload/VERSION
ts $U
check "USB 설치기: ... rc 꼬리까지 비교(1.1.0-rc.3 < $NEEDV), 스틱의 HMG-API도 낮으면 넘기지 않고 멈춤" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "이상으로 먼저 올려" $T/ts.out && ! grep -q "engine" $T/calls && [ -f $HD/mods/wireless-carplay-aa/mod.json ]'
rm -rf $K/hmgapi $U/HMGAPI $HD/mods/wireless-carplay-aa
for hv in $NEEDV 1.1.0-rc.10 1.1.0 1.2.0-beta.1; do
  printf 'version %s\n' $hv > $HD/installed.txt
  ts $U
  check "USB 설치기: HMG-API $hv는 최소 판 이상이라 설치함" '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^hmgapid engine install" $T/calls'
  rm -rf $HD/mods/nx4-kor
done
rm -f $HD/installed.txt
ts $U
check "USB 설치기: 새로 설치 → engine install, 앱이 깔리면 상태 화면을 엶, 재부팅하지 않음, 기록을 스틱에" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^hmgapid engine install .*/data/local/tmp/nx4-kor-usb/nx4-kor.zip" $T/calls && grep -q "^am start -n io.github.jayparklab.nx4kor/.StatusActivity" $T/calls && ! grep -q "service-stop" $T/calls && [ -f $HD/mods/nx4-kor/mod.json ] && grep -q "설치됨: $V" $K/install.log && [ ! -d $R/data/local/tmp/nx4-kor-usb ]'
ts $U
check "USB 설치기: 같은 판이 있으면 다시 설치하지 않고 상태 화면만 엶" '[ "$(cat $T/ts.rc)" = 0 ] && ! grep -q "engine install" $T/calls && grep -q "^am start" $T/calls && grep -q "이미 설치되어" $T/ts.out'
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
: > $K/UNINSTALL; : > $T/ap-running; rm -f $T/stublog; mkdir -p $R/data/nx4-kor/backup
ts $U
check "USB 설치기: UNINSTALL이면 설치된 모드의 uninstall.sh로 되돌리고 모드를 지움" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$HD/mods/nx4-kor " $T/stublog && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && grep -q "지웠습니다" $T/ts.out'
ts $U
check "USB 설치기: 지울 것이 없으면 아무것도 하지 않음" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "설치되어 있지 않습니다" $T/ts.out && ! grep -q "engine remove" $T/calls'
# 모드는 HMG-API 앱에서 먼저 지웠고 되돌릴 기록만 남은 경우: 스틱의 사본(/data로 복사)으로 되돌림
mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog
ts $U
check "USB 설치기: 모드가 이미 지워졌어도 기록이 남았으면 스틱의 사본으로 되돌림" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$R/data/local/tmp/nx4-kor-usb/payload " $T/stublog && [ ! -d $R/data/nx4-kor ] && [ ! -d $R/data/local/tmp/nx4-kor-usb ]'
# HMG-API를 먼저 지운 뒤(hmgapid 없음): 일반 삭제는 모드 폴더를 남긴다 → 그 폴더의 uninstall.sh로, purge는 /data/hmgapi째 없다 → 스틱 사본으로
ts0() { : > $T/calls; (env -u NX4_APP PATH=$P0 ROOT=$R HMGAPID=$T/nohmgapid NX4_USB_DIRS=$U NX4_APP_WAIT=4 sh $B/usb/troubleShooter) > $T/ts.out 2>&1; echo $? > $T/ts.rc; }
mkdir -p $HD/mods $R/data/nx4-kor/backup; cp -R $F $HD/mods/nx4-kor; rm -f $HD/installed.txt $T/stublog
ts0
check "USB 설치기: HMG-API를 먼저 지운 뒤(일반 삭제)에도 UNINSTALL이 됨: 남은 모드 폴더의 uninstall.sh로 되돌리고 모드 폴더·앱을 지움" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$HD/mods/nx4-kor " $T/stublog && grep -qx "pm uninstall io.github.jayparklab.nx4kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && [ ! -d $R/data/nx4-kor ] && grep -q "지웠습니다" $T/ts.out && grep -q "HMG-API가 없음" $K/install.log'
mv $HD $T/hd.purged; mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog
ts0
check "USB 설치기: HMG-API를 먼저 완전 삭제(--purge)한 뒤에도 기록이 남았으면 스틱의 사본으로 되돌림" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$R/data/local/tmp/nx4-kor-usb/payload " $T/stublog && [ ! -d $R/data/nx4-kor ]'
mv $T/hd.purged $HD
rm -f $K/UNINSTALL

# --- 진짜 스크립트: post.sh·preun.sh·hotspot.sh(setup_hmgapi) ---
# 차의 PATH로 바꾸는 맨 윗줄만 시험용 PATH로 바꾼 사본으로 돌린다. 나머지는 그대로
TP=$T/pkg; rm -rf $TP; cp -R $PKG $TP
for f in svc/hotspot.sh scripts/post.sh scripts/preun.sh bin/status.sh; do
  sed "s#^export PATH=.*#export PATH=$P0#" $PKG/$f > $TP/$f
done
# post.sh: 설치 전 Wi-Fi 상태 기록, 앱은 설치하지 않음(HMG-API가 설치)
: > $T/calls; rm -rf $T/pbk
(env PATH=$P0 BB_SYS=$T/bin/bb NX4_APP=$TP BK=$T/pbk W=$T/pw NOTICE=$T/pnotice BOOT_ID=$T/bootid sh $TP/scripts/post.sh) > $T/p.out 2>&1
check "post.sh: BK에 설치 전 Wi-Fi 상태를 적고 앱은 설치하지 않음(pm install 없음)" '[ "$(cat $T/pbk/wifi_on 2>/dev/null)" = 1 ] && grep -qx "settings get global wifi_on" $T/calls && ! grep -q "^pm" $T/calls' || cat $T/p.out
# preun.sh: 업데이트 갈래
prun() { (env PATH=${PP:-$P0} BB_SYS=$T/bin/bb NX4_APP=$TP BK=$T/ubk W=$T/uw CONF=$T/uconf HINT=$T/uhint PROG=$T/uprog NOTICE=$T/unotice HMGDATA=$T/uh BOOT_ID=$T/bootid MOUNTS=$T/mounts "$@" sh $TP/scripts/preun.sh) > $T/pu.out 2>&1; echo $? > $T/pu.rc; }
pureset() { rm -rf $T/ubk $T/uh; mkdir -p $T/ubk $T/uh/mods/nx4-kor; : > $T/ubk/keep; echo '{"id": "nx4-kor"}' > $T/uh/mods/nx4-kor/mod.json; : > $T/uh/installed.txt; : > $T/calls; }
pureset; prun NX4_UPDATE=1
check "preun.sh: NX4_UPDATE=1이면 업데이트 갈래로 끝나고 BK를 남김, 모드를 지우지 않음" '[ "$(cat $T/pu.rc)" = 0 ] && grep -q "NX4 KOR 업데이트: 이전 판 정리" $T/pu.out && [ -f $T/ubk/keep ] && ! grep -q "engine remove" $T/calls'
# preun.sh: 삭제 → HMG-API에서 이 모드를 빼고, 계획이 되돌리기뿐이면 적용
pureset; printf 'restore  /system/etc/permissions/com.hkmc.software.connectivity.carplay_wireless.xml [nx4-kor]\nsetting  persist.sys.iap2.wifi back to stock\nhook plan: 0 mods\n' > $T/plan.out
prun
check "preun.sh: 삭제면 engine remove nx4-kor → 계획(되돌리기뿐) → apply, BK 지움, 끝 문구" \
  '[ "$(cat $T/pu.rc)" = 0 ] && grep -qx "hmgapid engine remove nx4-kor" $T/calls && grep -qx "hmgapid engine apply" $T/calls && [ ! -d $T/ubk ] && grep -q "지우고 적용함" $T/pu.out && grep -q "NX4 KOR를 지웠습니다" $T/pu.out' || cat $T/pu.out
pureset; printf 'restore  /system/lib/libleafiaaac.so [nx4-kor]\nchange   /system/framework/framework.odex [other-mod]\n' > $T/plan.out
prun
check "preun.sh: 계획에 다른 모드의 변경이 있으면 적용하지 않고 HMG-API 앱에서 적용하라고 안내, 권한 파일 되돌리기 건너뜀" \
  '! grep -q "engine apply" $T/calls && grep -q "HMG-API 앱에서 변경 사항을 적용해 주세요" $T/pu.out && grep -q "되돌리기 건너뜀" $T/pu.out'
pureset; echo "nothing changed" > $T/plan.out
prun
check "preun.sh: 적용한 적이 없으면(nothing changed) 적용하지 않고 끝냄" '! grep -q "engine apply" $T/calls && grep -q "되돌릴 변경 없음" $T/pu.out && [ ! -d $T/ubk ]'
# preun.sh: HMG-API를 먼저 지웠으면(hmgapid 명령도 installed.txt도 없음) HMG-API를 부르지 않고 끝까지 감
mkdir -p $T/bin2; for b in $T/bin/*; do [ "${b##*/}" = hmgapid ] || cp $b $T/bin2/; done
P2=$T/bin2:/usr/bin:/bin:/usr/sbin:/sbin
sed "s#^export PATH=.*#export PATH=$P2#" $PKG/scripts/preun.sh > $TP/scripts/preun.sh
sed "s#^export PATH=.*#export PATH=$P2#" $PKG/svc/hotspot.sh > $TP/svc/hotspot.sh
pureset; rm -f $T/uh/installed.txt
(env PATH=$P2 BB_SYS=$T/bin2/bb NX4_APP=$TP BK=$T/ubk W=$T/uw CONF=$T/uconf HINT=$T/uhint PROG=$T/uprog NOTICE=$T/unotice HMGDATA=$T/uh BOOT_ID=$T/bootid sh $TP/scripts/preun.sh) > $T/pu.out 2>&1
check "preun.sh: HMG-API를 먼저 지웠으면 HMG-API를 부르지 않고 되돌리기를 끝까지 함, BK 지움" \
  '! grep -q "^hmgapid" $T/calls && grep -q "HMG-API가 먼저 지워져 있음" $T/pu.out && ! grep -q "되돌리기 건너뜀" $T/pu.out && [ ! -d $T/ubk ]' || cat $T/pu.out
sed "s#^export PATH=.*#export PATH=$P0#" $PKG/scripts/preun.sh > $TP/scripts/preun.sh
sed "s#^export PATH=.*#export PATH=$P0#" $PKG/svc/hotspot.sh > $TP/svc/hotspot.sh

# hotspot.sh perms_revert(삭제 때): 우리가 쓴 무선 권한 파일만, 내용이 그대로이고 HMG-API가 관리하지 않을 때만 지움
PR=$T/pr
CPW=com.hkmc.software.connectivity.carplay_wireless; APW=com.hkmc.software.connectivity.androidauto_wireless
prrun() { (env PATH=$P0 HOTSPOT_LIB=1 BB=$T/bin/bb APP=$TP W=$PR/w BK=$PR/bk PERMS=$PR/perms MOUNTS=$PR/mounts APLOG=$PR/ap.log HMGDATA=$PR/hd BOOT_ID=$T/bootid \
  sh -c ". $TP/svc/hotspot.sh; perms_revert; echo rc=\$?") > $PR/out 2>&1; }
prreset() {
  rm -rf $PR $T/status.out; mkdir -p $PR/perms $PR/bk $PR/w; : > $T/calls
  echo "/dev/block/system /system ext4 rw,relatime 0 0" > $PR/mounts
  for n in $CPW $APW; do printf '<permissions>\n    <feature name="%s" />\n</permissions>\n' $n > $PR/perms/$n.xml; echo $n >> $PR/bk/perms.ours; done
}
prreset; prrun
check "perms_revert: 우리가 쓴 무선 권한 파일 2개를 지움(/system이 rw면 remount 없음), 기록에 이름만" \
  'grep -qx rc=0 $PR/out && [ ! -e $PR/perms/$CPW.xml ] && [ ! -e $PR/perms/$APW.xml ] && grep -q "원래대로(없음): $CPW" $PR/out && ! grep -q remount $T/calls'
prreset; echo changed >> $PR/perms/$CPW.xml; prrun
check "  perms_revert: 내용이 바뀐 파일은 그대로 둠(다른 쪽이 바꾼 것)" '[ -e $PR/perms/$CPW.xml ] && [ ! -e $PR/perms/$APW.xml ] && grep -q "내용이 바뀜" $PR/out'
prreset; echo "CHANGED $PR/perms/$APW.xml [nx4-kor] expected x, found y" > $T/status.out; prrun
check "  perms_revert: HMG-API가 관리하는 파일은 HMG-API에 맡김" '[ -e $PR/perms/$APW.xml ] && [ ! -e $PR/perms/$CPW.xml ] && grep -q "HMG-API 모드가 관리 중" $PR/out'
prreset; echo "/dev/block/system /system ext4 ro,relatime 0 0" > $PR/mounts; prrun
check "  perms_revert: /system을 쓰기로 열지 못하면 아무것도 지우지 않고 실패(1)" 'grep -qx rc=1 $PR/out && [ -e $PR/perms/$CPW.xml ] && grep -qx "hmgapid remount rw" $T/calls && grep -q "열지 못함" $PR/out'

# hotspot.sh setup_hmgapi: 이 차의 map 만들기·확인 → 무선 기능 적용(통합한 모드)
SH=$T/sh
srun() {
  rm -f $T/sprog
  (env PATH=$P0 HOTSPOT_LIB=1 BB=$T/bin/bb APP=$TP W=$T/sw BK=$T/sbk HMGDATA=$SH PROG=$T/sprog NOTICE=$T/snotice BOOT_ID=$T/bootid \
     UPTIME=$T/uptime WIFI_SEEN=$T/wifiseen SDIO=$T/nosdio "$@" sh -c ". $TP/svc/hotspot.sh; mkdir -p \$W; P_ON=1; setup_hmgapi; echo rc=\$?") > $T/s.out 2>&1
}
st() { sed -n "s/^$1=//p" $T/sprog; }
sreset() {
  rm -rf $SH $T/sbk $T/sw $T/mapcar.* $T/verify.rc $T/apply.rc $T/iap2
  mkdir -p $SH/maps $SH/mods/nx4-kor $T/sbk; cp $PKG/mod.json $SH/mods/nx4-kor/mod.json; : > $T/wifiseen; : > $T/calls
  printf 'change   /system/etc/permissions/com.hkmc.software.connectivity.carplay_wireless.xml [nx4-kor]\nsetting  persist.sys.iap2.wifi = t [nx4-kor]\napp      io.github.jayparklab.nx4kor [nx4-kor]\nservice  nx4-kor ap\n' > $T/plan.out
  echo "written: /data/hmgapi/state/local-map.json (this car's own map, status probed): run \`hmgapid engine verify-map\`, then restart, for its hooks" > $T/mapcar.out
  : > $T/mapcar.writes
}
sreset; srun
check "setup_hmgapi: 처음(map 없음) → map-car --write → verify-map → 계획이 이 모드뿐 → apply → 재부팅 필요, 적용한 판 기록" \
  'grep -qx "hmgapid engine map-car --write" $T/calls && grep -qx "hmgapid engine verify-map" $T/calls && grep -qx "hmgapid engine apply" $T/calls && [ "$(st state)" = reboot ] && grep -q "설정을 마쳤습니다" $T/sprog && [ "$(cat $T/sbk/applied)" = "$V" ] && [ -f $T/sbk/automap.checked ] && [ -f $SH/state/local-map.json ]' || { cat $T/s.out; cat $T/sprog; }
: > $T/calls; : > $T/iap2
printf 'same     /system/etc/permissions/com.hkmc.software.connectivity.carplay_wireless.xml\nhook plan: 1 mod\napp      io.github.jayparklab.nx4kor [nx4-kor]\nservice  nx4-kor ap\nusb      none\n' > $T/plan.out
srun
check "setup_hmgapi: 다음 부팅(적용됨) → map을 다시 만들거나 확인하지 않고 적용도 하지 않음, 설정 끝(app·service·usb 줄은 변경이 아님)" \
  '! grep -q "map-car" $T/calls && ! grep -q "verify-map" $T/calls && ! grep -q "engine apply" $T/calls && [ "$(st state)" = done ]' || { cat $T/s.out; cat $T/sprog; }
echo 1.9.0 > $T/sbk/applied; : > $T/calls
srun
check "setup_hmgapi: 새 판인데 적용할 것이 없으면(훅 코드만 바뀜) 적용하지 않고 재부팅 안내, 판 기록을 바꿈" \
  '! grep -q "engine apply" $T/calls && [ "$(st state)" = reboot ] && grep -q "새 판($V)을 쓰려면" $T/sprog && [ "$(cat $T/sbk/applied)" = "$V" ]'
sreset; echo 3 > $T/verify.rc; srun
check "setup_hmgapi: map 확인 실패 → 만든 map을 지움(map-car --forget), automap.bad, 적용 안 함, 실패 문구" \
  'grep -qx "hmgapid engine map-car --forget" $T/calls && [ -f $T/sbk/automap.bad ] && [ ! -f $SH/state/local-map.json ] && ! grep -q "engine apply" $T/calls && [ "$(st state)" = fail ] && grep -q "map을 확인하지 못해" $T/sprog'
: > $T/calls; srun
check "setup_hmgapi: map 확인에 실패한 기록이 있으면 다시 만들지 않음" '! grep -q "map-car" $T/calls && [ "$(st state)" = fail ] && grep -q "map을 확인하지 못해" $T/sprog'
sreset; rm -f $T/mapcar.writes; echo "not written: HMG-API has a map for this car (hyundai/nx4/kor/260902): \`hmgapid engine map-car --local\` adds the points it lacks" > $T/mapcar.out; srun
check "setup_hmgapi: HMG-API에 이 차 map이 이미 있으면 그 map을 확인만 하고 적용(지우지 않음)" \
  '[ -f $T/sbk/automap.shipped ] && grep -qx "hmgapid engine verify-map" $T/calls && grep -qx "hmgapid engine apply" $T/calls && [ "$(st state)" = reboot ]'
sreset; rm -f $T/mapcar.writes; echo "map-car: 0 hook point(s) found" > $T/mapcar.out; srun
check "setup_hmgapi: map을 만들지 못하면 적용하지 않고 다음 부팅에 다시(실패 기록 없음)" \
  '! grep -q "engine apply" $T/calls && [ "$(st state)" = fail ] && grep -q "map을 만들지 못해" $T/sprog && [ ! -f $T/sbk/automap.bad ]'
sreset; printf 'change   /system/etc/permissions/x.xml [nx4-kor]\nchange   /system/framework/framework.odex [other-mod]\n' > $T/plan.out; srun
check "setup_hmgapi: 계획에 다른 모드의 변경이 있으면 적용하지 않고 HMG-API 앱에서 적용하라고 안내" \
  '! grep -q "engine apply" $T/calls && [ "$(st state)" = fail ] && grep -q "다른 모드의 바뀐 내용" $T/sprog'
sreset; mkdir -p $SH/mods/wireless-carplay-aa; echo '{}' > $SH/mods/wireless-carplay-aa/mod.json; srun
check "setup_hmgapi: 따로 설치된 무선 모드가 있으면 map·적용 없이 그 모드를 지우라고 안내" \
  '! grep -q "map-car" $T/calls && ! grep -q "engine apply" $T/calls && [ "$(st state)" = fail ] && grep -q "wireless-carplay-aa" $T/sprog'
sreset; echo 1 > $T/apply.rc; srun
check "setup_hmgapi: 적용 실패 → 실패 문구(HMG-API 앱 확인)" '[ "$(st state)" = fail ] && grep -q "적용에 실패했습니다" $T/sprog'
sreset; srun FAKE_PROD=DEPEHEV.KOR.0000.V039.001.260902
check "setup_hmgapi: NX4가 아니면 아무것도 하지 않음(지원하지 않는 차)" '[ ! -s $T/calls ] && [ "$(st state)" = fail ] && grep -q "투싼 NX4 한국 내수 260902 전용" $T/sprog'
# status.sh: 판정 몇 가지(상태 파일)
stsh() {
  (env PATH=$P0 BB=$T/bin/bb APP=$TP W=$T/sw BK=$T/sbk HMGDATA=$SH PROG=$T/sprog NOTICE=$T/snotice BOOT_ID=$T/bootid UPTIME=$T/uptime \
     WIFI_SEEN=$T/wifiseen SDIO=$T/nosdio STATUS=$T/status.txt HINT=$T/shint SRC=$T/nosoftap HMGINST=$T/sinst HMGLOG=$T/shlog \
     HOOKSTARTS=$T/sstarts NX4_DMESG=$T/sdmesg RPT_SYNC=1 "$@" sh $TP/bin/status.sh) > $T/st.out 2>&1
}
sv() { sed -n "s/^$1=//p" $T/status.txt; }
: > $T/sdmesg; printf 'version 1.1.0-rc.4\nbuild x\n' > $T/sinst
sreset; mkdir -p $SH/mods/wireless-carplay-aa; echo '{}' > $SH/mods/wireless-carplay-aa/mod.json; stsh
check "status.sh: 따로 설치된 무선 모드가 있으면 verdict=oldmod, 상태 파일에 판(mod.json)과 oldmod=yes" \
  '[ "$(sv verdict)" = oldmod ] && [ "$(sv oldmod)" = yes ] && [ "$(sv pkgver)" = "$V" ] && ! grep -qE "^(mod|modver|mod_pending|mod_pin|mod_foreign|wp|first)=" $T/status.txt' || cat $T/st.out
sreset; printf 'version 1.0.2\n' > $T/sinst; stsh
check "status.sh: HMG-API가 1.1.0-rc.4보다 낮으면 verdict=oldhmgapi" '[ "$(sv verdict)" = oldhmgapi ] && grep -q "1.1.0-rc.4 이상" $T/status.txt'
printf 'version 1.1.0-rc.4\n' > $T/sinst
sreset; stsh FAKE_PROD=DEPEHEV.KOR.0000.V039.001.260902
check "status.sh: NX4가 아니면 verdict=nocar, verdict_end=yes" '[ "$(sv verdict)" = nocar ] && [ "$(sv verdict_end)" = yes ] && [ "$(sv tested)" = no ]'
check "status.sh: 상태 파일과 한 줄 요약에 NEMESIS·Korea Projection·제보 문구 없음" '! grep -qE "NEMESIS|Korea Projection|제보|QR" $T/status.txt $T/st.out'

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

# --- scripts/fetch-busybox.sh: Alpine 패키지에서 busybox만 꺼내 NOTICE.md의 SHA-256과 맞을 때만 둔다 ---
# 인터넷 없이: 가짜 apk(gzip tar, bin/busybox.static)를 file://로 주고, 그 SHA-256을 적은 가짜 NOTICE.md 옆에 스크립트를 둔다
FB=$T/fb; mkdir -p $FB/scripts; cp $B/scripts/fetch-busybox.sh $FB/scripts/
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
FBSHA=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' $T/fb-bb)
printf '## BusyBox (GPL-2.0)\n  - SHA-256 `%s`\n' $FBSHA > $FB/NOTICE.md
fbrun() { (env NX4_BUSYBOX_URL="$1" sh "$2" "$3") > $T/fb.out 2>&1; echo $? > $T/fb.rc; }
fbrun file://$T/fb-pkg.apk $FB/scripts/fetch-busybox.sh $T/fb-out
check "fetch-busybox: 패키지의 bin/busybox.static을 꺼내 busybox(0755)로, SHA-256을 적은 GPL-2.0 안내(대응 소스 위치)와 함께 둠" \
  '[ "$(cat $T/fb.rc)" = 0 ] && cmp -s $T/fb-out/busybox $T/fb-bb && [ -x $T/fb-out/busybox ] && grep -q "$FBSHA" $T/fb-out/busybox-LICENSE.txt && grep -q "GPL" $T/fb-out/busybox-LICENSE.txt && grep -q "busybox-1.36.1.tar.bz2" $T/fb-out/busybox-LICENSE.txt' || cat $T/fb.out
fbrun file://$T/none.apk $FB/scripts/fetch-busybox.sh $T/fb-out
check "fetch-busybox: 같은 SHA-256의 busybox와 안내가 이미 있으면 다시 받지 않음" '[ "$(cat $T/fb.rc)" = 0 ] && grep -q "이미 받아 둠" $T/fb.out' || cat $T/fb.out
fbrun file://$T/fb-pkg.apk $B/scripts/fetch-busybox.sh $T/fb-bad
check "fetch-busybox: 꺼낸 busybox가 NOTICE.md의 SHA-256과 다르면 멈추고 아무것도 두지 않음" \
  '[ "$(cat $T/fb.rc)" != 0 ] && grep -q "다릅니다" $T/fb.out && [ ! -e $T/fb-bad/busybox ] && [ ! -e $T/fb-bad/busybox-LICENSE.txt ]' || cat $T/fb.out
fbrun file://$T/fb-nobb.apk $FB/scripts/fetch-busybox.sh $T/fb-bad
check "fetch-busybox: 패키지에 bin/busybox.static이 없으면 멈춤" '[ "$(cat $T/fb.rc)" != 0 ] && grep -q "busybox.static이 없습니다" $T/fb.out && [ ! -e $T/fb-bad/busybox ]' || cat $T/fb.out
fbrun file://$T/none.apk $FB/scripts/fetch-busybox.sh $T/fb-bad
check "fetch-busybox: 받지 못하면 멈춤" '[ "$(cat $T/fb.rc)" != 0 ] && grep -q "받지 못했습니다" $T/fb.out && [ ! -e $T/fb-bad/busybox ]' || cat $T/fb.out
check "fetch-busybox: 기본 주소는 Alpine v3.20 main armv7의 busybox-static-1.36.1-r31(https), NOTICE.md와 같은 판" \
  'grep -q "https://dl-cdn.alpinelinux.org/alpine/v3.20/main/armv7/busybox-static-1.36.1-r31.apk" $B/scripts/fetch-busybox.sh && grep -q "busybox-static-1.36.1-r31" $B/NOTICE.md'

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
  check "USB 묶음: payload = 서명된 모드를 푼 것(mod.json, 스크립트, 무선 훅·레시피·패치·설정, 앱, busybox, 서명), 따로 넣는 무선 모드 zip 없음" \
    '[ -f $P/mod.json ] && [ -f $P/svc/ap.sh ] && [ -f $P/svc/hotspot.sh ] && [ -f $P/hooks.jar ] && [ -f $P/patches.json ] && [ -f $P/settings.json ] && [ -f $P/files/libleafiaaac.so ] && [ "$(ls $P/recipes | wc -l | tr -d " ")" = 5 ] && [ -f $P/app/NX4KOR.apk ] && [ -f $P/bin/busybox ] && [ -d $P/META-HMGAPI ] && [ ! -d $P/hmgapi ] && [ ! -d $P/patches ]'
  check "라이선스: 모드에 LICENSE·NOTICE.md·bin/busybox-LICENSE.txt, USB 맨 위에 LICENSE·NOTICE.md·BUSYBOX-LICENSE.txt(저장소와 같은 내용)" \
    'cmp -s $P/LICENSE $B/LICENSE && cmp -s $P/NOTICE.md $B/NOTICE.md && cmp -s $P/bin/busybox-LICENSE.txt $T/test-bb-LICENSE.txt && cmp -s $T/ux/LICENSE $B/LICENSE && cmp -s $T/ux/NOTICE.md $B/NOTICE.md && cmp -s $T/ux/BUSYBOX-LICENSE.txt $T/test-bb-LICENSE.txt'
  check "라이선스: HMG-API를 함께 넣으면 HMGAPI-SOURCE.txt에 판과 대응 소스(태그), README.txt에 이 묶음의 소스 커밋" \
    'grep -q "^HMG-API 1.1.0:" $T/ux/HMGAPI-SOURCE.txt && grep -q "https://github.com/Open-HMG/HMG-API/tree/v1.1.0" $T/ux/HMGAPI-SOURCE.txt && grep -q "AGPL-3.0" $T/ux/HMGAPI-SOURCE.txt && grep -q "https://github.com/jay-park-lab/hmgapi-nx4-kor (이 묶음: [0-9a-f]\{7,\}" $T/ux/README.txt && ! grep -q "@SOURCE_REV@" $T/ux/README.txt'
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
  # HMG-API 엔진(PC JVM)으로 설치: 가짜 헤드유닛
  eng() { (HMGAPI_ROOT=$1 HMGAPI_HOST=1 HMGAPI_PRODUCT=$2 java -cp $T/eh hmgapi.engine.Engine install $T/out/hmgapi-nx4-kor-$V.zip) > $T/eng.out 2>&1; echo $? > $T/eng.rc; }
  for prod in NX4.KOR.0000.V039.001.260902 CVEV.USA.0000.V015 DEPEHEV.KOR.0000.V039.001.260902 NX4.KOR.0000.V040.001.261101; do
    ER=$T/er-$prod; mkdir -p $ER/system/etc/permissions $ER/data/hmgapi/mods $ER/data/hmgapi/settings
    printf 'ro.build.product=%s\n' $prod > $ER/system/build.prop
    printf 'version 1.1.0-rc.4\n' > $ER/data/hmgapi/installed.txt
  done
  ER=$T/er-NX4.KOR.0000.V039.001.260902; eng $ER NX4.KOR.0000.V039.001.260902
  # hmgapid는 상대 경로를 /data/hmgapi/mods/<모드>/ 아래로 푼다(svc_start): sh /data/hmgapi/mods/nx4-kor/svc/ap.sh
  check "HMG-API 엔진: NX4.KOR 260902에 설치됨(서명 확인), 서비스 ap(root, android, 다시 시작)·launch(manual)·앱이 등록됨, 무선 훅 파일이 모드 폴더에" \
    '[ "$(cat $T/eng.rc)" = 0 ] && grep -q "installed nx4-kor $V (author key" $T/eng.out && grep -qx "nx4-kor ap root android yes script svc/ap.sh -" $ER/data/hmgapi/state/services.txt && grep -qx "nx4-kor launch root manual no script svc/launch.sh -" $ER/data/hmgapi/state/services.txt && grep -qx "io.github.jayparklab.nx4kor nx4-kor" $ER/data/hmgapi/state/apps.txt && [ -f $ER/data/hmgapi/mods/nx4-kor/hooks.jar ] && [ -f $ER/data/hmgapi/mods/nx4-kor/recipes/carplay-core-wifi.recipe ]' || cat $T/eng.out
  for prod in CVEV.USA.0000.V015 DEPEHEV.KOR.0000.V039.001.260902 NX4.KOR.0000.V040.001.261101; do
    ER=$T/er-$prod; eng $ER $prod
    check "HMG-API 엔진: $prod 에는 설치하지 않음(NX4.KOR 260902 전용)" '[ "$(cat $T/eng.rc)" != 0 ] && grep -q "refused" $T/eng.out && [ ! -d $ER/data/hmgapi/mods/nx4-kor ]' || cat $T/eng.out
  done
else
  echo "skip 빌드·HMG-API 엔진 시험(HMGAPI_SRC 없음)"
fi

echo
if [ $fails = 0 ]; then echo "모두 통과"; else echo "실패 $fails개"; exit 1; fi
