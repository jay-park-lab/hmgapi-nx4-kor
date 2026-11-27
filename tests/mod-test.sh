#!/bin/sh
# PC(맥)에서 NX4 KOR 모드의 스크립트를 가짜 헤드유닛으로 돌린다.
#   sh tests/mod-test.sh                 스크립트 시험(실패하면 FAIL 줄과 종료 코드 1)
#   HMGAPI_SRC=<HMG-API 저장소> sh tests/mod-test.sh
#                                        + 임시 키로 scripts/build.sh를 끝까지 돌리고, 만든 모드를 HMG-API 엔진
#                                          (PC JVM)에 설치해 서비스·앱 등록과 차종 제한(NX4.KOR 260902만)을 본다
#                                          (HMGAPI_SRC는 .env.local에 적어도 된다)
#                                          ANDROID_HOME(.env.local에 적어도 됨)이 있으면 hooks.jar도 진짜로 만든다(#67).
#                                          없으면 빌드 시험은 자리만 채운 hooks.jar로 본다
# 가짜 도구: hmgapid, pm, am, getprop, settings, svc, sleep. 서비스 래퍼는 가짜 스크립트를 부르게 해서 넘기는 값을 보고,
# preun.sh·status.sh(svc/lib.sh)는 진짜를 돌린다.
B=$(cd "$(dirname "$0")/.." && pwd)
# .env.local에서는 HMGAPI_SRC·ANDROID_HOME만 읽는다. 시험이 부르는 build.sh는 .env.local을 읽지 않게 한다
# (NX4_BUSYBOX 같은 개인 설정이 섞이면 시험 결과가 PC마다 달라진다)
. "$B/scripts/local-env.sh"
nx4_env "$B" HMGAPI_SRC ANDROID_HOME
NX4_ENV_FILE=
export NX4_ENV_FILE
PKG=$B/mod
T=$(mktemp -d /tmp/nx4-kor-test.XXXXXX)
# KEEP=1: 시험 폴더를 남긴다(실패 원인 보기)
if [ -n "$KEEP" ]; then echo "시험 폴더: $T"; else trap 'rm -rf $T' EXIT; fi
fails=0
ok() { echo "ok   $1"; }
# bad는 1을 돌려준다: check "…" '…' || cat <출력> 의 cat이 실패할 때만 돈다(PR #74 리뷰 7. 전에는 늘 0이라 돌지 않았음)
bad() { echo "FAIL $1"; fails=$((fails+1)); return 1; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
V=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' $PKG/mod.json | head -1)

# --- 구문 검사: 차의 셸은 mksh. 있는 ksh 계열과 dash로 본다(PC sh만으로는 ksh 계열에서만 틀리는 구문을 못 잡는다) ---
KSHS=$(for s in mksh ksh dash; do command -v $s; done)
[ -n "$KSHS" ] || bad "구문 검사: mksh/ksh/dash 없음"
for f in $PKG/svc/*.sh $PKG/bin/*.sh $PKG/scripts/*.sh $B/usb/troubleShooter $B/scripts/*.sh $B/tests/emu/*.sh $B/tests/qemu/*.sh $B/tests/qemu/nx4init; do
  for KSH in $KSHS; do check "구문 검사 $(basename $KSH): ${f#$B/}" '$KSH -n $f'; done
done

check "한국 길안내: 일반 도로 곧 회전 거리 600m(2026-11-26 사용자 결정, KP는 350m), 고속도로 출구 1050m 그대로" \
  'grep -q "static final int D_GENERAL = 600, D_EXPRESSWAY = 1050;" $B/hooks/src/io/github/jayparklab/nx4kor/hook/dipo/CpTurnsFit.java'

# --- mod.json: NX4 KOR 모드(관리 앱과 그 서비스, 한국 카플레이 길안내 훅 #67. 무선은 HMG-API와 공식 무선 모드 wireless-carplay-aa가 맡음) ---
check "mod.json: launch 서비스·앱·런처, 한국 길안내 훅(DiPO), NX4.KOR 260902만, HMG-API 1.1.0-rc.10 이상, 무선 부분·Wi-Fi 요청·충돌·requires 없음" 'python3 - "$PKG" "$B" <<PY
import json, os, sys
d = sys.argv[1]
m = json.load(open(os.path.join(d, "mod.json")))
assert m["id"] == "nx4-kor"
assert m["hmgapi"] == ">=1.1.0-rc.10", m["hmgapi"]
for s in m["services"]:
    assert os.path.isfile(os.path.join(d, s["script"])), s
# launch: 관리 앱이 부름. nochip: 칩 없는 차에서 HMG-API 지기의 다시 시도를 멈춤(부팅 때 한 번, 상주는 inotifyd뿐)
assert [(s["name"], s["start"], s["user"], s["restart"]) for s in m["services"]] == [("launch", "manual", "root", False), ("nochip", "boot", "root", False)], m["services"]
# 차 이벤트(car_events)를 쓰면 HMG-API가 차량 서비스(상주 Dalvik)를 새로 띄우므로(ModRuntime) 두지 않는다
assert "car_events" not in m and "vehicle" not in m, m.keys()
assert m["apps"] == [{"apk": "app/NX4KOR.apk", "package": "io.github.jayparklab.nx4kor"}], m["apps"]
assert m["system"] == {"model": ["NX4", "NX4HEV"], "region": ["KOR"], "firmware": ["260902"]}
# 앱 메뉴 타일은 하나. 그림 키(icon*)는 아래 타일 그림 테스트가 본다
assert list(m["provides"]) == ["launcher"] and len(m["provides"]["launcher"]) == 1, m["provides"]
t = m["provides"]["launcher"][0]
assert {k: t[k] for k in t if not k.startswith("icon")} == {"package": "io.github.jayparklab.nx4kor", "class": ".StatusActivity"}, t
# 한국 길안내 훅(#67): DiPO의 계기판 호출 8곳은 change(공식 모드의 replace와 함께 걸림, #17), DiPO의 길안내 Stop은 observe.
# replace는 쓰지 않는다(id가 앞이라 공식 모드와 겹치면 공식 모드가 꺼진다). requires로 걸면 공식 모드가 없거나 꺼질 때
# HMG-API가 이 모드의 앱·서비스까지 멈춘다
h = m["hooks"]
assert h["jar"] == "hooks.jar" and h["entry"] == "io.github.jayparklab.nx4kor.hook.Nx4KorHooks", h
nc = ["update_tbt_info", "update_tbt_sub_info_b", "update_tbt_sub_info_2c", "update_tp_turn_list_new", "update_lane_info",
      "update_tp_destination_name", "update_tp_crossroad_name", "update_tp_turn_list"]
want = {"dipo.iap2_proxy.stop_route_guidance": "observe"}
want.update({"framework.navigation_cluster." + p: "change" for p in nc})
assert h["points"] == want, h["points"]
assert set(h) == {"jar", "entry", "points"}, h
assert "replace" not in h["points"].values()
e = os.path.join(sys.argv[2], "hooks", "src", *h["entry"].split(".")) + ".java"
assert os.path.isfile(e), e
for k in ("parts", "feature_flags", "wifi", "conflicts", "requires", "logs", "probe", "network"):
    assert k not in m, k
PY'
check "빠진 것: 한국 포크 무선 모드(레시피·libleafiaaac.so·patches.json, wireless/), 핫스팟 서비스(svc/ap.sh·hotspot.sh, scripts/post.sh), 만든 hooks.jar(빌드가 넣음)" \
  '[ ! -e $PKG/hooks.jar ] && [ ! -e $PKG/recipes ] && [ ! -e $PKG/files ] && [ ! -e $PKG/patches.json ] && [ ! -e $B/wireless ] && [ ! -e $PKG/svc/ap.sh ] && [ ! -e $PKG/svc/hotspot.sh ] && [ ! -e $PKG/scripts/post.sh ] && [ -f $PKG/svc/lib.sh ]'
# kor_tbt_log(#77, 2026-11-26 사용자 결정): 켜고 끄는 설정으로 두고 기본은 끔(2.1.2-beta.2부터). KorTbt가 settingBoolean에
# 주는 기본값도 settings.json과 같아야 한다(설정 파일이 없을 때 같은 뜻)
check "settings.json: 한국 길안내(kor_tbt, 기본 켬)와 그 진단 줄(kor_tbt_log, 기본 끔)만, 다시 시작해 적용. KorTbt의 기본값도 끔" 'python3 - "$PKG" "$B/hooks/src/io/github/jayparklab/nx4kor/hook" <<PY
import json, os, sys
s = json.load(open(os.path.join(sys.argv[1], "settings.json")))
assert s["version"] == 1
got = [(x["key"], x["type"], x["default"], x["apply"]) for x in s["settings"]]
assert got == [("kor_tbt", "toggle", True, "restart"), ("kor_tbt_log", "toggle", False, "restart")], got
part = open(os.path.join(sys.argv[2], "dipo", "KorTbt.java")).read()
assert "settingBoolean(\"kor_tbt_log\", false)" in part
for x in s["settings"]:
    assert x["title"] and x["description"], x
PY'
# 한국 길안내 소스(#67): KP·seogaemo·공식 모드에서 가져온 파일은 출처 줄을 남기고, 진입 클래스·DiPO 부분이 설정 이름과 같은 이름을 쓴다
HK=$B/hooks/src/io/github/jayparklab/nx4kor/hook
check "hooks 소스: KP(korea-build ebca56f, 모드 2.4.10)에서 온 CpTurnsFit·CpTbt·CpIcons와 6258357 꼴의 PhoneBarOut, 공식 모드 스텁 4개에 출처·바꾼 것 줄(2026-11-26 다시 가져온 줄 포함), 진단 줄 한도 300" \
  '( for f in CpTurnsFit CpTbt CpIcons; do grep -q "korea-build ebca56f3824a2234e48b336abda927d7a635e243" $HK/dipo/$f.java && grep -q "Modified by NX4 KOR" $HK/dipo/$f.java || exit 1; done
     grep -q "6258357" $HK/dipo/PhoneBarOut.java && grep -q "Modified by NX4 KOR" $HK/dipo/PhoneBarOut.java || exit 1
     grep -q "static int distStrState" $HK/dipo/CpIcons.java && grep -q "CpIcons.distStrState" $HK/dipo/CpTurnsFit.java || exit 1
     for f in CpTurnsFit CpTbt CpIcons; do grep -q "^// Updated by NX4 KOR, 2026-11-26: taken again from KP.s mod 2.4.10" $HK/dipo/$f.java || exit 1; done
     grep -q "^    static final int DIAG_LOGS_MAX = 300;$" $HK/dipo/CpTurnsFit.java || exit 1
     for f in IIap2Listener IIap2Service Iap2ListenerInfo Iap2NotiMsg; do head -n 1 $B/hooks/stubs/com/tcc/iap2/$f.java | grep -q "hmgapi-wireless-cp-aa v2.2.0-rc.9" || exit 1; done
     grep -q "HMG-Seogaemo" $HK/dipo/CpTurnsFit.java )'
check "hooks 소스: 설정 kor_tbt·kor_tbt_log, DiPO 패키지, 앱 파트 클래스 이름, 리스너 종류 4096, 계기판 호출 8곳이 mod.json과 같음" 'python3 - "$PKG/mod.json" "$HK" <<PY
import json, re, sys
m = json.load(open(sys.argv[1]))
entry = open(sys.argv[2] + "/Nx4KorHooks.java").read()
part = open(sys.argv[2] + "/dipo/KorTbt.java").read()
assert "settingBoolean(\"kor_tbt\", true)" in entry
assert "settingBoolean(\"kor_tbt_log\", " in part   # its default is checked against settings.json above (#77)
# #77: CpTurnsFit sends through ClusterOut, which skips a call the official mod already carried (TbtGate.skipOurs)
fit = open(sys.argv[2] + "/dipo/CpTurnsFit.java").read()
assert "final ClusterOut cluster;" in fit and "CpTurnsFit(Context context, ClusterOut cluster, Runnable restart)" in fit
assert "new CpTurnsFit(app.context, new ClusterOut(c, gate)," in part
assert "\"com.daudio.app.dipo\"" in entry and "\"io.github.jayparklab.nx4kor.hook.dipo.KorTbt\"" in entry
assert "LISTENER_ROUTE_GUIDANCE = 4096" in part
a = re.search(r"CLUSTER_POINTS = \{(.*?)\};", part, re.S).group(1)
got = sorted(re.findall(r"\"(update_[a-z0-9_]+)\"", a))
want = sorted(p.split(".")[-1] for p, v in m["hooks"]["points"].items() if v == "change")
assert got == want, (got, want)
# ClusterOut checks the same 8 calls, each by the point name the hook records ours under (#77)
out = open(sys.argv[2] + "/dipo/ClusterOut.java").read()
assert sorted(re.findall(r"if \(skip\(\"(update_[a-z0-9_]+)\"", out)) == got, out
# and each method under the point the HMG-API Cluster calls for that method (rc.10 hook/Cluster.java), then that method
# of Cluster, once (PR #78 review 2: two names swapped passed the line above)
CL = {"tbtInfo": "update_tbt_info", "tbtSubInfo": "update_tbt_sub_info_b", "tbtSubInfo2C": "update_tbt_sub_info_2c",
      "turnListNew": "update_tp_turn_list_new", "laneInfo": "update_lane_info", "destinationName": "update_tp_destination_name",
      "crossroadName": "update_tp_crossroad_name", "turnList": "update_tp_turn_list"}
pairs = {}
for name, body in re.findall(r"\n    void (\w+)\((.*?)\n    }\n", out, re.S):
    pts = re.findall(r"skip\(\"(update_[a-z0-9_]+)\"", body)
    calls = re.findall(r"\bc\.(\w+)\(", body)
    assert len(pts) == 1 and calls == [name], (name, pts, calls)
    pairs[name] = pts[0]
assert pairs == CL, pairs
# CpTurnsFit starts the KorTbt restart on a thread of its own, so the restart runs it there (PR #78 review 6)
assert "restart.run()" not in fit and fit.count("new Thread(restart, ") >= 1, "restart"
assert "\"dipo.iap2_proxy.stop_route_guidance\"" in part
# 판단은 TbtGate가 한다(아래 호스트 테스트): 우리 호출 기록, 남의 호출에 줄 인자, 남의 Stop 미루기, 비켜 주기, 앱에서 끔
for s in ("gate.ours(point, p.args)", "gate.forOther(point, p.args.length, SystemClock.elapsedRealtime(), on)",
          "gate.stopSeen(", "gate.stopDue(", "gate.yielding(", "gate.heard(", "gate.setActive(turns.active())",
          # 2.1.2-beta.4: a call ours has nothing for yet waits for this thread (TbtGate.held), never on the main thread;
          # the listener numbers the update and its post says when this thread is through (done wakes the call)
          "boolean on = mod.enabled();", "c = gate.held(point, p.args.length, on, WAITS, waited);",
          # PR #85 리뷰 2: 붙잡은 호출은 kor_tbt_log일 때만, 우리 값·그대로 통과 모두. 리뷰 6: 줄 수는 TbtGate.heldLog가
          # 정함(모두 HELD_LOGS_MAX, 한 지점 HELD_LOGS_PER_POINT, 길안내가 꺼질 때(setActive)·연결이 끝날 때 다시 셈)
          "waited[0] >= 0L && t != null && t.debug && gate.heldLog(point)",
          "gate.heldLogsReset();",
          "Looper.myLooper() != Looper.getMainLooper()", "lock.wait(ms);", "final long seq = gate.heard(", "}, seq);",
          "if (seq > 0L) gate.done(seq);",
          # 앱에서 끄면 받지 않고, 상태와 "그렸다" 표시를 비우고, 다시 켜면 길안내 전체를 다시 요청한다(PR #68 리뷰 2·11)
          "if (!mod.enabled()) {", "turns.reset();", "turns.shown = false;", "turns.hudShown = false;", "if (wasOff) {",
          # giving way: REFRESH waits for the way to end, hearing again brings it back (#77, PR #78 review 5·10)
          "refreshBackedOff = yielding && turns.active();", "h.post(RESUME);", "handler.removeCallbacks(REFRESH);"):
    assert s in part, s
# PR #85 리뷰 5: post(r, seq)에서 done(seq)는 noteActive() 다음, finally 안(붙잡힌 공식 호출은 이 스레드가 길안내가
# 켜졌는지 적은 뒤에 다시 봄. 앞에 오면 우리 값이 생기기 전에 깨어 공식 값으로 통과)
body = part[part.index("static void post(final Runnable r, final long seq)"):]
body = body[:body.index("\n    }\n")]
assert re.search(r"noteActive\(\);\s*\}\s*finally\s*\{\s*if \(seq > 0L\) gate\.done\(seq\);", body), body
run = body[body.index("h.post(new Runnable()"):]
assert run.count("gate.done(") == 1 and run.index("noteActive();") < run.index("gate.done(seq);"), run
# 리뷰 6: 연결이 끝나면(리스너의 disconnected를 이 스레드가 처리한 뒤) 붙잡기 기록 줄 수를 다시 셈
assert re.search(r"turns\.disconnected\(\);\s*//[^\n]*\n\s*gate\.heldLogsReset\(\);", part), "heldLogsReset"
PY'
# KorTbt의 판단(TbtGate: 덮어쓰기, 비켜 주기, 남의 Stop 미루기, 앱에서 끔. PR #68 리뷰 1~4)을 PC에서 돌린다
if command -v javac >/dev/null 2>&1; then
  mkdir -p $T/gate
  javac --release 8 -Xlint:-options -nowarn -d $T/gate $HK/dipo/TbtGate.java $B/tests/tools/TbtGateTest.java > $T/gate.err 2>&1
  java -cp $T/gate io.github.jayparklab.nx4kor.hook.dipo.TbtGateTest > $T/gate.out 2>&1
  check "TbtGate(한국 길안내의 판단) $(grep -c '^ok ' $T/gate.out)개: 켜졌고 들을 때만 공식 호출을 덮음, 앱에서 끄면 통과, 공식은 계속 부르는데 우리만 3초 못 들으면 비켜 줌, 남의 Stop은 2초 안에 폰이 다시 보내면 지우지 않음(150ms 안에 온 것은 세지 않음), 공식 모드가 우리 최신 값을 900ms 안에 실어 보냈으면 같은 값의 우리 호출을 건너뜀(#77), 우리 값이 아직 없는 공식 호출은 우리 스레드가 들은 것을 모두 끝낼 때까지 250ms(길안내가 꺼져 있고 못 들었으면 50ms)까지 기다려 우리 값을 실음(2.1.2-beta.4, PR #85 리뷰 1·3·4), 그 기록은 길안내마다 100줄·한 지점 20줄까지(리뷰 6)" \
    'tail -n 1 $T/gate.out | grep -qx ok && ! grep -q "^FAIL" $T/gate.out' || cat $T/gate.err $T/gate.out
else
  echo "skip TbtGate 테스트(javac 없음)"
fi
check "hooks 소스: 순정 내비 쪽 막대 방송(PhoneBarOut)은 보내지 않음, KP의 순정 층(CpTurns)은 옮기지 않음" \
  '! grep -q "sendBroadcast" $HK/dipo/PhoneBarOut.java && [ ! -e $HK/dipo/CpTurns.java ] && ! grep -qE "new CpTurns\(|[^/ ]CpTurns\.[A-Za-z]+\(" $HK/dipo/*.java'
check "lib.sh: 모드 id·HMG-API 최소 판이 mod.json과 같음, 공식 무선 모드 최소 판, env.sh의 NX4_MOD_ID도 같음, 앱 Report의 최소 판도 같음" \
  'grep -q "^MOD_ID=\${NX4_MOD_ID:-nx4-kor}$" $PKG/svc/lib.sh && grep -q "^HMG_MIN=1.1.0-rc.10$" $PKG/svc/lib.sh && grep -q "^WM_ID=wireless-carplay-aa$" $PKG/svc/lib.sh && grep -q "^WM_MIN=2.2.0-rc.9$" $PKG/svc/lib.sh && grep -q "^NX4_MOD_ID=nx4-kor$" $PKG/svc/env.sh && grep -q "MIN_HMGAPI = \"1.1.0-rc.10\"" $B/app/java/io/github/jayparklab/nx4kor/Report.java && grep -q "MIN_WIRELESS = \"2.2.0-rc.9\"" $B/app/java/io/github/jayparklab/nx4kor/Report.java'
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
check "관리 앱 아이콘(android:icon) = 앱 메뉴 타일의 낮·밤 그림" \
  'grep -q "android:icon=\"@drawable/ic_launcher\"" $B/app/AndroidManifest.xml && cmp -s $B/app/res/drawable-hdpi/ic_launcher.png $PKG/icons/icon.png && cmp -s $B/app/res/drawable-night-hdpi/ic_launcher.png $PKG/icons/icon_night.png'
# HMG-API USB 묶음 안의 파일 이름 NEMESIS.data(빌드가 빼는 파일)는 그대로 둔다.
# USB 설치기의 Korea Projection 패키지 확인(#13)만 예외: NEMESIS·korea.projection은 세 가지 줄에서만 받는다.
#   설치기의 폴더 경로 한 줄(KORPROJ=…), 설치기의 문구 정의 한 줄(KORPROJ_MSG="…", 줄 전체가 아래 KORPROJ_TEXT와 같을 때만),
#   스틱 README에서 "NEMESIS에서 Korea Projection을 지우고 내비를 재부팅한 뒤"가 든 안내 줄.
# 2.1.1부터 스틱 README의 HMG-API 지우기 경고(NEMESIS 1.17, Open-HMG/HMG-API#397)도 받는다: 스틱 README에서
#   "NEMESIS 1.16"·"NEMESIS 1.17"·"NEMESIS 비상 USB"·"NEMESIS를 지우"가 든 줄. 모드·설치기·빌드 스크립트에는 여전히 두지 않는다.
# 2.1.2부터 NEMESIS가 깔린 차를 거절하는 확인(#75)도 받는다: 설치기의 실행 파일 경로 한 줄(NMS=…), 문구 정의 한 줄(NMS_MSG="…",
#   줄 전체가 아래 NMS_TEXT와 같을 때만), "#75"를 적은 설치기의 주석 줄, 스틱 README에서 "NEMESIS가 깔린 차"가 든 줄.
# 설치기의 다른 줄(문구를 주석으로 단 코드 줄 등)은 잡는다(PR #57 리뷰 3). 다른 흔적(KP_*, wireless.projection, 제보 등)은
# 그 줄들에서도 잡는다(앞의 grep은 예외 없이 본다)
KORPROJ_TEXT="NEMESIS에 Korea Projection이 설치되어 있어 설치하지 않았습니다. NEMESIS에서 Korea Projection을 지우고 내비를 재부팅한 뒤 다시 해 주세요. 아무것도 바꾸지 않았습니다."
NMS_TEXT="NEMESIS가 깔린 차에는 NX4 KOR를 설치하지 않습니다. NEMESIS를 지우기 전에 USB의 README.txt를 꼭 읽어 주세요. 아무것도 바꾸지 않았습니다."
TRACE_IN="$PKG $B/usb $B/scripts --include=*.sh --include=troubleShooter --include=*.json --include=*.txt"
check "NEMESIS·다른 차·제보 흔적 없음(모드·USB·빌드 스크립트. 설치기의 Korea Projection 패키지 확인(#13)·NEMESIS 거절(#75)과 스틱 README 안내·HMG-API 지우기 경고(#397)만 뺌)" \
  '! grep -rnE "KP_[A-Z]|korea-projection|KoreaProjection|CARS_OK|CARS_TRY|CARS_SEEN|req_tick|report\.req|carreport|wireless\.projection|제보|QR" $TRACE_IN && ! grep -rnE "NEMESIS|nemesis|korea\.projection" $TRACE_IN | grep -v "NEMESIS\.data" | grep -vE "^[^:]*/usb/troubleShooter:[0-9]+:KORPROJ=[$]ROOT/data/nemesis/apps/korea[.]projection$" | grep -vE "^[^:]*/usb/troubleShooter:[0-9]+:KORPROJ_MSG=\"$KORPROJ_TEXT\"$" | grep -vE "^[^:]*/usb/troubleShooter:[0-9]+:NMS=[$]ROOT/system/xbin/nemesis$" | grep -vE "^[^:]*/usb/troubleShooter:[0-9]+:NMS_MSG=\"$NMS_TEXT\"$" | grep -vE "^[^:]*/usb/troubleShooter:[0-9]+: *#.*#75" | grep -vE "^[^:]*/usb/README[.]txt:[0-9]+:.*NEMESIS에서 Korea Projection을 지우고 내비를 재부팅한 뒤" | grep -vE "^[^:]*/usb/README[.]txt:[0-9]+:.*(NEMESIS 1[.]1[67]|NEMESIS 비상 USB|NEMESIS를 지우|NEMESIS가 깔린 차)"'
# 정적 검사: 맨 위(함수 밖) 기본값 대입이 아래에서 정해지는 변수를 먼저 쓰지 않음, "> 파일 2>/dev/null" 순서가 없음
python3 $B/tests/tools/defuse-check.py $PKG > $T/defuse.out 2>&1; DEFRC=$?
check "정적 검사: 정의 전에 쓰는 변수·'> 파일 2>/dev/null' 순서가 모드 스크립트에 없음(tests/tools/defuse-check.py)" '[ $DEFRC = 0 ] && [ ! -s $T/defuse.out ]'
# 관리 앱: Report(상태 파일 읽기·판정 문구·상태표·재부팅 요청). android.* 없이 PC JVM으로 돈다
if command -v javac >/dev/null 2>&1; then
  J=$T/java; mkdir -p $J
  if javac -nowarn -encoding UTF-8 -d $J $B/app/java/io/github/jayparklab/nx4kor/Report.java $B/tests/ReportTest.java 2>$T/javac.err; then
    java -cp $J io.github.jayparklab.nx4kor.ReportTest > $T/java.out 2>&1; jr=$?
    grep -E "^FAIL" $T/java.out | sed 's/^/  [Java] /'
    check "관리 앱 ReportTest 전부($(grep -c "^ok" $T/java.out)개)" '[ $jr -eq 0 ]'
  else
    cat $T/javac.err; check "관리 앱 Report 컴파일" 'false'
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
  # ping.fails: 남은 실패 횟수(부를 때마다 1 줄임, always면 늘 실패). 없으면 답함
  "ping "*)
    f=\$(cat $T/ping.fails 2>/dev/null)
    [ "\$f" = always ] && { echo "hmgapid: not running" >&2; exit 1; }
    case "\$f" in ''|0) exit 0 ;; esac
    echo \$((f - 1)) > $T/ping.fails; echo "hmgapid: not running" >&2; exit 1 ;;
  "engine install")
    # zip의 mod.json id 폴더에 푼다(꺼 둔 표시 .disabled는 남김). install-fail은 모든 설치를, install-fail-<id>는 그 모드만 거절
    [ -f $T/install-fail ] && { echo "refused: test"; exit 1; }
    rm -rf $T/inst.tmp; mkdir -p $T/inst.tmp
    (cd $T/inst.tmp && unzip -q "\$3") || exit 1
    id=\$(sed -n 's/^ *"id": *"\([^"]*\)".*/\1/p' $T/inst.tmp/mod.json | head -1)
    [ -f $T/install-fail-\$id ] && { echo "refused: test \$id"; exit 3; }
    dis=; [ -f \$H/mods/\$id/.disabled ] && dis=1
    rm -rf \$H/mods/\$id; mkdir -p \$H/mods; mv $T/inst.tmp \$H/mods/\$id
    [ -n "\$dis" ] && : > \$H/mods/\$id/.disabled
    [ "\$id" = nx4-kor ] && : > $T/app-ready
    echo "installed \$id"; exit 0 ;;
  "engine remove") rm -rf \$H/mods/\$3; [ "\$3" = nx4-kor ] && rm -f $T/app-ready; echo "removed \$3"; exit 0 ;;
  # 계획: n번째 부름에 plan.out.<n>이 있으면 그것을, 없으면 plan.out을 보인다(부른 횟수는 plan.n)
  "engine plan")
    n=\$((\$(cat $T/plan.n 2>/dev/null || echo 0) + 1)); echo \$n > $T/plan.n
    if [ -f $T/plan.out.\$n ]; then cat $T/plan.out.\$n; else cat $T/plan.out 2>/dev/null; fi
    exit \$(cat $T/plan.rc.\$n 2>/dev/null || cat $T/plan.rc 2>/dev/null || echo 0) ;;
  "engine apply") exit \$(cat $T/apply.rc 2>/dev/null || echo 0) ;;
  "engine map-car")
    case "\$3" in
      --forget) rm -f \$H/state/local-map.json; echo "forgotten: /data/hmgapi/state/local-map.json"; exit 0 ;;
      --write)
        cat $T/mapcar.out 2>/dev/null
        [ -f $T/mapcar.writes ] && { mkdir -p \$H/state; echo '{"whole": true}' > \$H/state/local-map.json; }
        exit \$(cat $T/mapcar.rc 2>/dev/null || echo 0) ;;
    esac ;;
  # 통과하면 HMG-API처럼 state/map-check.json에 ok를 남긴다
  "engine verify-map")
    r=\$(cat $T/verify.rc 2>/dev/null || echo 0)
    [ "\$r" = 0 ] && { mkdir -p \$H/state; echo '{"ok": true}' > \$H/state/map-check.json; }
    exit \$r ;;
  "enable "*) rm -f \$H/mods/\$2/.disabled; echo "enabled (apply to change files)"; exit 0 ;;
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
  # 관리 앱이 열릴 때의 설치 진행 기록을 남긴다(USB 설치기가 쓰는 중인 기록의 꼴을 본다)
  *StatusActivity*) cp $T/root/data/local/tmp/nx4-kor-progress.txt $T/prog-at-open 2>/dev/null ;;
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
# 2.1.0: HMG-API 쪽 일(옛 2.0.x 정리, 공식 무선 모드 --any-car, nx4-kor, 이 차의 map 만들기·확인, 계획 확인 뒤 적용)을 설치기가 모두 한다
R=$T/root; U=$T/usb0; K=$U/NX4; PG=$R/data/local/tmp/nx4-kor-progress.txt
NEEDV=$(sed -n 's/^HMG_MIN=//p' $B/usb/troubleShooter)
WV=$(sed -n 's/^WV=//p' $B/scripts/fetch-wireless.sh)
# mod.json 고치기: 키=값(값이 -면 뺌, conflicts=<id>는 그 id 하나의 목록)
modset() { python3 -I - "$@" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p))
for kv in sys.argv[2:]:
    k, _, v = kv.partition("=")
    if v == "-": m.pop(k, None)
    elif k == "conflicts": m[k] = [v]
    else: m[k] = v
json.dump(m, open(p, "w"), indent=2)
PY
}
# 스틱: nx4-kor payload는 2.1.0 꼴(공식 무선 모드와 충돌을 선언하지 않음), 공식 무선 모드는 고정한 판(가짜 zip과 그 mod.json)
mkdir -p $R/data/local/tmp $K/install/payload $K/wireless
cp -R $F/. $K/install/payload/; modset $K/install/payload/mod.json conflicts=-
(cd $K/install/payload && zip -q -r $K/install/hmgapi-nx4-kor.zip .)
WM=$T/wmod; mkdir -p $WM
printf '{\n  "id": "wireless-carplay-aa",\n  "name": "Wireless CarPlay + Android Auto",\n  "version": "%s",\n  "hmgapi": ">=%s",\n  "authors": ["VysseCodes"]\n}\n' $WV $NEEDV > $WM/mod.json
(cd $WM && zip -q -r $K/wireless/wireless-carplay-aa.zip .); cp $WM/mod.json $K/wireless/mod.json
# 옛 2.0.x 되돌리기(build.sh가 태그 v2.0.4-beta.1에서 꺼내 넣는 NX4/legacy-2.0)를 흉내: 부른 위치·인자와 busybox를 받았는지 적고
# 기록 폴더를 지우는 가짜 uninstall.sh. 없는 스틱은 mv로 치워 흉내낸다(legoff·legon)
mkdir -p $K/legacy-2.0/bin
printf '{\n  "id": "nx4-kor",\n  "version": "2.0.4-beta.1",\n  "conflicts": [\n    "wireless-carplay-aa"\n  ]\n}\n' > $K/legacy-2.0/mod.json
printf '#!/bin/sh\nbb=; [ -f "$NX4_APP/bin/busybox" ] && bb=yes\necho "legacy-uninstall NX4_APP=$NX4_APP bb=$bb $*" >> %s/stublog\nrm -rf $NX4_ROOT\nexit 0\n' $T > $K/legacy-2.0/bin/uninstall.sh
echo "v2.0.4-beta.1 0000000" > $K/legacy-2.0/SOURCE
legoff() { mv $K/legacy-2.0 $T/legacy.away; }
legon() { mv $T/legacy.away $K/legacy-2.0; }
# 설치된 공식 무선 모드를 흉내: $1 판, $2 이름(기본 공식)
wmod() { mkdir -p $HD/mods/wireless-carplay-aa; printf '{\n  "id": "wireless-carplay-aa",\n  "name": "%s",\n  "version": "%s"\n}\n' "${2:-Wireless CarPlay + Android Auto}" $1 > $HD/mods/wireless-carplay-aa/mod.json; }
# 설치된 옛 NX4 KOR 2.0.x를 흉내(공식 무선 모드와 충돌 선언): $1 판. 그 판 자신의 bin/uninstall.sh는 부른 위치·인자를 적고
# 기록 폴더를 지우는 가짜(2.0.x는 Wi-Fi 잠금 등을 되돌린 뒤 지운다). 저장소의 uninstall.sh(2.1.0)와 상관없이 설치기의 차례만 본다
oldmod() {
  rm -rf $HD/mods/nx4-kor; mkdir -p $HD/mods; cp -R $F $HD/mods/nx4-kor; modset $HD/mods/nx4-kor/mod.json conflicts=wireless-carplay-aa version=$1
  printf '#!/bin/sh\necho "old-uninstall NX4_APP=$NX4_APP $*" >> %s/stublog\nrm -rf $NX4_ROOT\nexit 0\n' $T > $HD/mods/nx4-kor/bin/uninstall.sh
}
# 설치된 nx4-kor가 공식 무선 모드와 충돌을 선언하는가(옛 2.0.x 꼴)
old_conf() { grep -q '"conflicts"' $HD/mods/nx4-kor/mod.json; }
# 설치기는 스틱의 NX4/install.log에 이어 쓴다. 테스트마다 그 회의 기록만 보도록 지우고 돌린다(KEEPLOG=1이면 남김)
# TSX: 그 회에만 더 줄 환경(예: HMG-API 기다리기의 짧은 시간)
ts() { : > $T/calls; rm -f $PG $T/prog-at-open; [ -n "$KEEPLOG" ] || rm -f $K/install.log; (env -u NX4_APP $TSX PATH=$P0 ROOT=$R HMGAPID=$T/bin/hmgapid NX4_USB_DIRS="$1" NX4_APP_WAIT=4 NX4_DIAG_WAIT=1 NX4_DIAG_SHOWN=1 BOOT_ID=$T/bootid UPTIME=$T/uptime sh $B/usb/troubleShooter) > $T/ts.out 2>&1; echo $? > $T/ts.rc; }
pg() { sed -n "s/^$1=//p" $PG; }
# 호출 기록에서 그 줄이 처음 나온 위치(없으면 99999)
at() { _n=$(grep -n -- "$1" $T/calls | head -1 | cut -d: -f1); echo ${_n:-99999}; }
# HMG-API rc.8 계획: 늘 나오는 설명 줄(설치기가 변경으로 보지 않음)과 same뿐이라 적용할 것이 없다
cat > $T/plan-same <<'P'
same     /system/etc/permissions/com.hkmc.software.connectivity.carplay_wireless.xml [wireless-carplay-aa]
same     setting prop/persist.sys.iap2.wifi = t [wireless-carplay-aa]
WARNING: wireless-carplay-aa: this head unit isn't in its system list; overrides.ignore_system is set, going on at your own risk
app      io.github.jayparklab.nx4kor (app/NX4KOR.apk) [nx4-kor]
service  nx4-kor/ap as root, at android, restarted if it stops [nx4-kor]
home Wi-Fi  off
wifi     the projection AP up from boot, once each boot, unless a Wi-Fi client is on [wireless-carplay-aa]
network  no cellular [wireless-carplay-aa]
projection Android Auto density 160 [wireless-carplay-aa]
hooks    framework.context_impl.start_service: wireless-carplay-aa (replace), nx4-kor (observe) share it
P
# 처음 설치: 우리 두 모드의 변경(한 파일을 두 모드가 함께 바꾸는 줄 포함)과 설명 줄
{ echo 'change   /system/lib/libCarPlayCore.so [wireless-carplay-aa] -> 0123   [restart the head unit]'
  echo 'change   /system/onebin/nx4hev_kr/featurexml.cfg [nx4-kor, wireless-carplay-aa] -> 4567   [restart the head unit]'
  echo 'setting  prop/persist.sys.iap2.wifi = t [wireless-carplay-aa]'
  cat $T/plan-same; } > $T/plan-new
# 계획을 정한다: $1은 늘, 그 뒤는 2번째·3번째… 부름(plan.out.<n>)
pset() { rm -f $T/plan.out.* $T/plan.rc.* $T/plan.n; cp $T/$1 $T/plan.out; shift; _n=2; for _p in "$@"; do cp $T/$_p $T/plan.out.$_n; _n=$((_n+1)); done; return 0; }
# 처음 설치처럼: map 없음, map-car --write가 map을 씀, verify-map 통과
mapnew() { rm -rf $HD/state $T/verify.rc; echo "written: /data/hmgapi/state/local-map.json (this car's own map, status probed): run \`hmgapid engine verify-map\`, then restart, for its hooks" > $T/mapcar.out; : > $T/mapcar.writes; rm -f $T/mapcar.rc; }
# 진단 기록 확인 창에는 [모으기]로 답한다(아래 확인 창 테스트에서만 바꿈). 앱이 있는지는 $T/app-ready(가짜 pm)
echo yes > $T/diag.reply
# 진단 기록(diag)은 읽기만 하는 engine status·report를 부른다. "엔진을 부르지 않음"은 그 둘을 빼고 본다
engcalls() { grep -v -E "^hmgapid engine (status|report)$" $T/calls | grep -q "engine"; }
# 진단 기록 폴더(NX4/diag/<시각>) 하나: 테스트 전에 rm -rf $K/diag 해 두고 그 회의 것만 본다
dg() { echo $K/diag/*; }
rm -rf $HD/mods/nx4-kor $R/data/nx4-kor
pset plan-new; mapnew
ts $T/nostick
check "USB 설치기: NX4 폴더가 없으면 아무것도 하지 않음" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "NX4 폴더가 없습니다" $T/ts.out && [ ! -s $T/calls ]'
mv $HD $T/hd.away
rm -rf $K/diag; : > $T/app-ready
ts $U
check "USB 설치기: HMG-API가 없으면 멈춤(설치 안 함, 진행 기록 없음)" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "HMG-API가 없습니다" $T/ts.out && ! grep -q "engine install" $T/calls && [ ! -f $PG ]'
check "USB 설치기 진단 기록: HMG-API가 없어도 [모으기]면 모으고(info·/system/lib), HMG-API 명령(engine status·report)은 부르지 않음" \
  '[ -f $(dg)/info.txt ] && [ -f $(dg)/system-lib-md5.txt ] && [ ! -f $(dg)/car-report.txt ] && ! grep -q "engine" $T/calls && grep -q "HMG-API가 응답하지 않아" $K/install.log && grep -qx "usb_wireless: $WV" $(dg)/info.txt'
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
# 계획 읽기(plan_check): 설치기의 함수만 꺼내 차의 셸마다 돌린다. 줄의 모드 목록이 우리 두 모드뿐인지(한 파일을 함께 바꾸는 "[a, b]" 포함)
sed -n '/^plan_ours() {/,/^}/p;/^plan_check() {/,/^}/p' $B/usb/troubleShooter > $T/pc.sh
printf 'change   /x [nx4-kor, other-mod] -> 1   [restart the head unit]\n' > $T/pc-mixed
printf 'restore  /system/lib/libleafiaaac.so (stock)\nsetting  persist.sys.iap2.wifi back to stock\nunbind   /system/x (stock again)\n' > $T/pc-revert
printf 'hooks are off on this car (no map): mods apply without their hooks\n' > $T/pc-hooksoff
printf 'something new  [nx4-kor]\n' > $T/pc-unknown
# 2.0.4-beta.1 차(NX4HEV, HMG-API rc.7)의 실제 plan.txt(PR #49 표본). 옛 설치기는 "home Wi-Fi  off"·"network  …"를 변경으로 봐 적용하지 않았다
cat > $T/pc-rc7car <<'P'
same     /system/etc/permissions/com.hkmc.software.connectivity.androidauto_wireless.xml [nx4-kor]
same     /system/etc/permissions/com.hkmc.software.connectivity.carplay_wireless.xml [nx4-kor]
same     /system/etc/permissions/com.hkmc.software.wifihotspot.xml [nx4-kor]
same     /system/lib/libleafiaaac.so [nx4-kor]
same     /system/onebin/nx4hev_kr/featurexml.cfg [nx4-kor]
same     setting prop/persist.iap2.iden.wireless = t [nx4-kor]
same     setting prop/persist.ium.support = carplay [nx4-kor]
same     setting prop/persist.sys.iap2.wifi = t [nx4-kor]
app      io.github.jayparklab.nx4kor (app/NX4KOR.apk) [nx4-kor]
service  nx4-kor/ap as root, at android, restarted if it stops [nx4-kor]
service  nx4-kor/launch as root, at manual [nx4-kor]
home Wi-Fi  off
network  no cellular [nx4-kor]
P
# rc.8 설명 줄 머리 표본(PR #49: ModRuntime·Projection·HomeWifi·Network가 내는 꼴, 공식 무선 모드의 wifi·방화벽 줄 포함)
cat > $T/pc-rc8desc <<'P'
same     /system/etc/permissions/com.hkmc.software.connectivity.carplay_wireless.xml [nx4-kor]
app      io.github.jayparklab.nx4kor (app/NX4KOR.apk) [nx4-kor]
event    park -> runs svc/park.sh as root (30 s at most); its apps and hooks hear it [nx4-kor]
vehicle  reads speed, gear [nx4-kor]
vehicle  may seat_heat (park only) [nx4-kor]
driving  io.github.jayparklab.nx4kor/.StatusActivity closes while the car's driving restriction is on [nx4-kor]
panel    "NX4" (io.github.jayparklab.nx4kor/.Widget) in the side panel [nx4-kor]
projection Android Auto density 160 [wireless-carplay-aa]
projection events to its apps [nx4-kor]
network  firewall filter input: accept tcp port 40515 in hotspot to hotspot (IPv4, 1 rule) (when settings.aa_firewall) [wireless-carplay-aa]
button   star short -> opens io.github.jayparklab.nx4kor/.StatusActivity [nx4-kor]
home Wi-Fi  on: while the car is off, the hotspot off and the car's Wi-Fi client on the saved networks
wifi     the projection AP up from boot, once each boot, unless a Wi-Fi client is on [wireless-carplay-aa]
network  home Wi-Fi only (no cellular) [nx4-kor]
network  no cellular (home Wi-Fi is off) [wireless-carplay-aa]
P
{ cat $T/pc-rc8desc; echo 'change   /system/etc/permissions/x.xml [nx4-kor] -> 1   [restart the head unit]'; } > $T/pc-rc8chg
printf 'hooks    wireless-carplay-aa won'"'"'t load: hook point dipo.x isn'"'"'t mapped on this car\n' > $T/pc-wontload
for VSH in $KSHS; do
  pcase() { $VSH -c 'MOD=nx4-kor; WMOD=wireless-carplay-aa; REMOVED=$4; . "$1"; plan_check "$2" "$3"; echo "$P_TODO:$P_WHY"' x $T/pc.sh "$@"; }
  check "USB 설치기 계획 읽기($(basename $VSH)): 우리 두 모드의 변경은 적용(final), rc.8 설명 줄·same만 있으면 할 일 없음, 다른 모드가 섞인 줄은 막음" \
    '[ "$(pcase $T/plan-new final 0)" = "1:" ] && [ "$(pcase $T/plan-same final 0)" = "0:" ] && [ "$(pcase $T/pc-mixed final 0)" = "1:other" ] && [ "$(pcase $T/pc-mixed pre 0)" = "1:other" ]'
  check "USB 설치기 계획 읽기($(basename $VSH)): 되돌리기는 이번에 모드를 지웠을 때만(final), 지우기(revert)는 되돌리기만, 훅이 꺼지면 final만 막음, 모르는 줄은 pre만 넘김" \
    '[ "$(pcase $T/pc-revert final 0)" = "1:other" ] && [ "$(pcase $T/pc-revert final 1)" = "1:" ] && [ "$(pcase $T/pc-revert revert 0)" = "1:" ] && [ "$(pcase $T/plan-new revert 0)" = "1:other" ] && [ "$(pcase $T/pc-hooksoff final 0)" = "0:hooks" ] && [ "$(pcase $T/pc-hooksoff remove 0)" = "0:" ] && [ "$(pcase $T/pc-unknown final 0)" = "0:other" ] && [ "$(pcase $T/pc-unknown pre 0)" = "0:" ]'
  check "USB 설치기 계획 읽기($(basename $VSH)): 차의 실제 rc.7 계획(home Wi-Fi·network 줄)과 rc.8 설명 줄은 할 일 없음, 설명 줄과 함께 온 change는 적용, hooks … won't load는 막음(… share it은 받음)" \
    '[ "$(pcase $T/pc-rc7car final 0)" = "0:" ] && [ "$(pcase $T/pc-rc8desc final 0)" = "0:" ] && [ "$(pcase $T/pc-rc8chg final 0)" = "1:" ] && [ "$(pcase $T/pc-wontload final 0)" = "0:hooks" ] && [ "$(pcase $T/plan-same final 0)" = "0:" ]'
done
# 커널 로그의 zygote 훅 줄 읽기(PR #61 리뷰 2): 설치기의 zyg_scan만 꺼내 차의 셸(mksh)과 ksh·dash 중 있는 것마다 돌리고,
# 관리 앱 쪽 status.sh zygote_info(busybox awk, 여기서는 PC의 awk)와 답("<ZH> <ZON>", 없으면 -)이 같은지 본다
sed -n '/^zyg_scan() {/,/^}/p' $B/usb/troubleShooter > $T/zs.sh
sed -n '/^zygote_info() {/,/^}/p' $PKG/bin/status.sh > $T/zi.sh
ZD=$T/zdm; mkdir -p $ZD
ZX='hmgapid, exec /system/bin/app_process.hmgapi-stock'
printf '<6>[   20.512345] hmgapi-hook: zygote, hooks on, start 2 (this boot 1), %s\n' "$ZX" > $ZD/on
{ echo "<6>[    3.100000] init: starting service zygote"; printf '<6>[   20.512345] hmgapi-hook: zygote, hooks on, start 2 (this boot 1), %s\n' "$ZX"
  echo "<6>[  140.600000] hmgapi-hook: zygote 1234 up 120 s, boot guard reset"; printf '<6>[  395.000001] hmgapi-hook: zygote, hooks on, start 1 (this boot 2), %s\n' "$ZX"; } > $ZD/twice
{ printf '[   20.5] hmgapi-hook: zygote, hooks on, start 3 (this boot 1), %s\n' "$ZX"; printf '[  130.0] hmgapi-hook: zygote, hooks off (boot guard, starts=6, this boot 3), %s\n' "$ZX"; } > $ZD/guard
printf '<6>[    5.0] hmgapi-hook: zygote, hooks off (disable file), %s\n' "$ZX" > $ZD/off
{ echo "<6>[    5.0] hmgapi-hook: app_process, exec x"; echo "<6>[    6.0] hmgapi-hook: zygote (re-exec), exec x"; echo "<6>[  125.0] hmgapi-hook: zygote 99 up 120 s, boot guard reset"; } > $ZD/none
: > $ZD/empty
printf 'hmgapi-hook: zygote, hooks on, start 1 (this boot 1), %s\n' "$ZX" > $ZD/nots
printf '<6>[12345.678901] hmgapi-hook: zygote, hooks on, start 1 (this boot 1), %s\n' "$ZX" > $ZD/big
zref() { (PATH=$P0 BB=$T/bin/bb NX4_DMESG=$1 sh -c '. "$1"; zygote_info; echo "${ZH:--} ${ZON:--}"' x $T/zi.sh); }
ZWANT="on 20|on 395|guard 20|off -|- -|- -|on -|on 12345"
ZREF=; for z in on twice guard off none empty nots big; do ZREF="$ZREF${ZREF:+|}$(zref $ZD/$z)"; done
check "status.sh zygote_info(관리 앱 쪽 기준)의 답이 예상과 같음(마지막 hooks on 시각, guard·off, 줄 없음, 시각 없음)" '[ "$ZREF" = "$ZWANT" ]' || echo "  $ZREF"
for VSH in $KSHS; do
  zcase() { $VSH -c '. "$1"; zyg_scan < "$2"' x $T/zs.sh "$1"; }
  ZGOT=; for z in on twice guard off none empty nots big; do ZGOT="$ZGOT${ZGOT:+|}$(zcase $ZD/$z)"; done
  check "USB 설치기 커널 로그 읽기($(basename $VSH)): zyg_scan의 답이 status.sh zygote_info와 같음" '[ "$ZGOT" = "$ZREF" ] && [ -n "$ZREF" ]' || echo "  $ZGOT"
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
# HMG-API가 최소 판(설치기 HMG_MIN, 스틱의 두 모드의 "hmgapi" 중 가장 높은 것)보다 낮으면: 아무것도 바꾸기 전에 스틱의 HMG-API 설치기로 올리거나 멈춤
wmod 2.2.0-rc.5
printf 'version 1.0.2\nbuild test\n' > $HD/installed.txt
ts $U
check "USB 설치기: HMG-API(1.0.2)가 최소 판($NEEDV)보다 낮고 스틱에 HMG-API가 없으면 아무것도 바꾸지 않고 멈춤(공식 무선 모드도 그대로, 진행 기록 없음)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "HMG-API $NEEDV 이상으로 먼저 올려" $T/ts.out && ! engcalls && grep -q "\"version\": \"2.2.0-rc.5\"" $HD/mods/wireless-carplay-aa/mod.json && [ ! -f $PG ]'
mkdir -p $K/hmgapi $U/HMGAPI/install/payload; echo "# hmg-api" > $K/hmgapi/troubleShooter; echo $NEEDV > $U/HMGAPI/install/payload/VERSION
ts $U
check "USB 설치기: ... 스틱에 최소 판 이상의 HMG-API 설치기가 있으면 그것으로 올림(엔진을 부르지 않음)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "HMG-API 설치기로 넘김(업데이트)" $T/ts.out && grep -q "1.0.2에서 $NEEDV(으)로" $T/ts.out && ! engcalls'
# 2.1.0이 받던 rc.8(NEMESIS 1.17에서 지우면 Android가 뜨지 않음)과 rc.9(FORCE로 설치한 NEMESIS 1.17 차를 올리면 Android가
# 뜨지 않음): 2.1.1부터 스틱의 HMG-API(rc.10)로 먼저 올린다(Open-HMG/HMG-API#397). rc.9 < rc.10은 꼬리를 숫자로 비교해야 나온다
printf 'version 1.1.0-rc.8\n' > $HD/installed.txt
ts $U
check "USB 설치기: HMG-API 1.1.0-rc.8(2.1.0이 받던 판)도 최소 판($NEEDV)보다 낮아 스틱의 HMG-API로 먼저 올림" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "HMG-API 설치기로 넘김(업데이트)" $T/ts.out && grep -q "1.1.0-rc.8에서 $NEEDV(으)로" $T/ts.out && ! engcalls'
printf 'version 1.1.0-rc.9\n' > $HD/installed.txt
ts $U
check "  1.1.0-rc.9도 최소 판($NEEDV)보다 낮아 먼저 올림(rc.9 < rc.10)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "HMG-API 설치기로 넘김(업데이트)" $T/ts.out && grep -q "1.1.0-rc.9에서 $NEEDV(으)로" $T/ts.out && ! engcalls'
printf 'version 1.1.0-rc.3\n' > $HD/installed.txt; echo 1.1.0-rc.3 > $U/HMGAPI/install/payload/VERSION
ts $U
check "USB 설치기: ... rc 꼬리까지 비교(1.1.0-rc.3 < $NEEDV), 스틱의 HMG-API도 낮으면 넘기지 않고 멈춤" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "이상으로 먼저 올려" $T/ts.out && ! engcalls'
# 공식 무선 모드가 더 높은 HMG-API를 요구하면 그 판이 최소 판(설치기 상수보다 높음)
printf 'version %s\n' $NEEDV > $HD/installed.txt; echo $NEEDV > $U/HMGAPI/install/payload/VERSION
cp $K/wireless/mod.json $T/wj.keep; modset $K/wireless/mod.json "hmgapi=>=1.2.0"
ts $U
check "USB 설치기: 스틱의 공식 무선 모드가 HMG-API 1.2.0 이상을 요구하면 HMG-API $NEEDV에서 멈춤(스틱의 HMG-API도 $NEEDV)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "HMG-API 1.2.0 이상으로 먼저 올려" $T/ts.out && ! engcalls'
cp $T/wj.keep $K/wireless/mod.json
rm -rf $K/hmgapi $U/HMGAPI $HD/mods/wireless-carplay-aa
for hv in $NEEDV 1.1.0-rc.11 1.1.0 1.2.0-beta.1; do
  printf 'version %s\n' $hv > $HD/installed.txt
  pset plan-new; mapnew
  ts $U
  check "USB 설치기: HMG-API $hv는 최소 판 이상이라 설치함" '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^hmgapid engine install .*/nx4-kor.zip$" $T/calls' || cat $T/ts.out
  rm -rf $HD/mods/nx4-kor $HD/mods/wireless-carplay-aa
done
rm -f $HD/installed.txt
# 처음 설치: 공식 무선 모드(--any-car) → nx4-kor → 관리 앱 → map 만들기 → 확인 → 계획 → 적용 → "재부팅 필요"
pset plan-new; mapnew
T0=$(date +%s)
ts $U
T1=$(date +%s)
check "USB 설치기: 새로 설치 → 공식 무선 모드(engine install <zip> --any-car) → nx4-kor → 관리 앱 → map-car --write → verify-map → 계획 → apply 차례, 재부팅하지 않음" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -qx "hmgapid engine install $R/data/local/tmp/nx4-kor-usb/wireless-carplay-aa.zip --any-car" $T/calls && grep -qx "hmgapid engine install $R/data/local/tmp/nx4-kor-usb/nx4-kor.zip" $T/calls && [ $(at "wireless-carplay-aa.zip --any-car") -lt $(at "nx4-kor.zip") ] && [ $(at "nx4-kor.zip") -lt $(at "StatusActivity") ] && [ $(at "StatusActivity") -lt $(at "map-car --write") ] && [ $(at "map-car --write") -lt $(at "verify-map") ] && [ $(at "verify-map") -lt $(at "engine apply") ] && ! grep -q "service-stop" $T/calls && ! grep -q "engine remove" $T/calls && [ -f $HD/mods/nx4-kor/mod.json ] && [ -f $HD/mods/wireless-carplay-aa/mod.json ] && [ -f $HD/state/local-map.json ] && [ ! -d $R/data/local/tmp/nx4-kor-usb ]' || { cat $T/ts.out; cat $T/calls; }
check "  진행 기록: 끝은 state=reboot(설정을 마쳤습니다, 100%, 이번 부팅 id, 644), 스틱의 install.log에 설치·계획·map 출력" \
  '[ "$(pg state)" = reboot ] && [ "$(pg pct)" = 100 ] && pg stage | grep -qF "설정을 마쳤습니다. [지금 재부팅]을 눌러 내비를 재부팅해 주세요" && [ "$(pg boot)" = test-boot-id ] && [ "$(ls -l $PG | cut -c1-10)" = "-rw-r--r--" ] && grep -q "설치됨: $V" $K/install.log && grep -q "공식 무선 모드 설치됨: $WV" $K/install.log && grep -q "^--- engine plan (final, 종료 코드 0)" $K/install.log && grep -q "^--- engine map-car --write" $K/install.log' || cat $PG
# 진행 기록의 꼴은 2.0.x 서비스(hotspot.sh prog)와 같다: 관리 앱(Report.java)이 그대로 읽는다
check "  진행 기록 꼴: 줄 차례 pct·state·stage·start·t·boot·step·ust·ut, 진행 중(관리 앱을 열 때)은 state=run·step=4/6, 시각·부팅 뒤 초(ust·ut=100)" \
  '[ "$(cut -d= -f1 $PG | tr "\n" " ")" = "pct state stage start t boot step ust ut " ] && [ "$(sed -n "s/^state=//p" $T/prog-at-open)" = run ] && [ "$(sed -n "s/^step=//p" $T/prog-at-open)" = 4/6 ] && [ "$(sed -n "s/^ust=//p" $T/prog-at-open)" = 100 ] && [ "$(sed -n "s/^ut=//p" $T/prog-at-open)" = 100 ] && [ "$(sed -n "s/^start=//p" $T/prog-at-open)" -ge $T0 ] && [ "$(sed -n "s/^t=//p" $T/prog-at-open)" -le $T1 ] && [ "$(pg step)" = "" ]' || { cat $T/prog-at-open; cat $PG; }
DUNTIL=$(sed -n 's/^am start -n .*DiagActivity .* --el until \([0-9][0-9]*\)$/\1/p' $T/calls)
check "USB 설치기 진단 기록: 확인 창(DiagActivity, id·기다릴 초·창을 기다리는 마지막 시각 until=시작+NX4_DIAG_SHOWN)을 먼저 띄우고 [모으기]면 아무것도 바꾸기 전에 모음(engine report가 engine install보다 먼저), 결과 안내가 마지막" \
  'grep -q "^am start -n io.github.jayparklab.nx4kor/.DiagActivity --es id [0-9][0-9]* --ei wait 1 --el until [0-9][0-9]*$" $T/calls && [ -n "$DUNTIL" ] && [ "$DUNTIL" -ge $((T0 + 1)) ] && [ "$DUNTIL" -le $((T1 + 1)) ] && [ $(at DiagActivity) -lt $(at "^hmgapid engine report") ] && [ $(at "^hmgapid engine report") -lt $(at "^hmgapid engine install") ] && [ "$(grep -n "진단 기록을 USB에 모으는 중입니다(1~2분)" $T/ts.out | cut -d: -f1)" -lt "$(grep -n "설치하는 중" $T/ts.out | head -1 | cut -d: -f1)" ] && tail -n 1 $T/ts.out | grep -q "설치를 마쳤습니다. 관리 앱의 \[지금 재부팅\]" && grep -q "\[모으기\]를 고름" $K/install.log'
cp $K/install.log $T/first.log; FIRSTN=$(($(wc -l < $T/first.log)))
# 같은 판: nx4-kor·공식 무선 모드를 다시 설치하지 않고 map도 만들지 않음. 있는 map을 확인하고, 계획에 할 일이 없으면 "설정이 끝나 있음"
pset plan-same
KEEPLOG=1; ts $U; KEEPLOG=
check "USB 설치기: 같은 판이 있으면 다시 설치하지 않고(map도 다시 만들지 않음) 관리 앱을 열고, map 확인·계획만 함 → 할 일 없음이면 state=done" \
  '[ "$(cat $T/ts.rc)" = 0 ] && ! grep -q "engine install" $T/calls && ! grep -q "map-car" $T/calls && grep -qx "hmgapid engine verify-map" $T/calls && ! grep -q "engine apply" $T/calls && grep -q "^am start -n io.github.jayparklab.nx4kor/.StatusActivity" $T/calls && grep -q "이미 설치되어" $T/ts.out && [ "$(pg state)" = done ] && [ "$(pg stage)" = "무선 카플레이 설정이 끝나 있습니다." ]' || { cat $T/ts.out; cat $PG; }
check "USB 설치기: 스틱의 install.log에 이어 씀(앞의 시도 기록이 그대로 맨 앞에 남고, 빈 줄 뒤에 이번 기록, 한 번씩만)" \
  '[ $FIRSTN -gt 0 ] && head -n $FIRSTN $K/install.log | cmp -s - $T/first.log && [ "$(grep -c "USB 설치기 시작" $K/install.log)" = 2 ] && [ "$(grep -c "설치됨: $V" $K/install.log)" = 1 ] && grep -q "같은 판($V)이 이미 설치됨" $K/install.log && [ "$(grep -n "설치됨: $V" $K/install.log | cut -d: -f1)" -lt "$(grep -n "같은 판" $K/install.log | cut -d: -f1)" ] && grep -qx "" $K/install.log' || cat $K/install.log
# 설치기는 nx4-kor의 판이 같은지만 본다(차례는 HMG-API engine install이 봄, git-flow 규칙 4): 설치된 판이 꼬리만 다른 베타($V-beta.1)여도
# 다른 판이라 예전 판을 정리하고 engine install을 부른다. 끝나면 가짜 engine install이 payload의 판($V)으로 되돌려 놓는다
modset $HD/mods/nx4-kor/mod.json version=$V-beta.1
ts $U
check "USB 설치기: 판은 같은지만 봄. 설치된 판이 $V-beta.1이면 $V와 다른 판이라 예전 판 정리 뒤 engine install(공식 무선 모드는 같은 판이라 그대로)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^hmgapid engine install .*/nx4-kor.zip$" $T/calls && ! grep -q "wireless-carplay-aa.zip" $T/calls && grep -q "$V-beta.1에서 $V(으)로 바꾸는 중" $T/ts.out && ! grep -q "같은 판" $K/install.log && grep -q "\"version\": \"$V\"" $HD/mods/nx4-kor/mod.json && [ "$(pg state)" = reboot ]' || { cat $T/ts.out; cat $K/install.log; }
# --- HMG-API 기다리기(부팅 직후에 Update OTA를 눌러도 됨, 2026-11-25) --- 대기 간격 1초, 최대 시간은 몇 초로 줄여 돌린다(uptime 100초)
# 1) hmgapid가 처음 두 번 답하지 않다가 답함: 기다린 뒤 진단 묻기·설치
rm -rf $HD/mods/nx4-kor $HD/mods/wireless-carplay-aa $K/diag; pset plan-new; mapnew
echo 2 > $T/ping.fails
TSX="NX4_HMG_POLL=1 NX4_HMG_WAIT=103 NX4_HMG_TRY=2"; ts $U; TSX=
PING3=$(grep -n "^hmgapid ping$" $T/calls | sed -n 3p | cut -d: -f1)
check "USB 설치기 HMG-API 기다리기: ping이 처음 두 번 실패해도 기다린 뒤(최대 부팅 뒤 NX4_HMG_WAIT초까지, 토스트 한 번) 진단 묻기·설치를 끝까지 함" \
  '[ "$(cat $T/ts.rc)" = 0 ] && [ "$(grep -c "HMG-API가 준비되기를 기다리는 중입니다(최대 1분). USB를 빼지 마세요." $T/ts.out)" = 1 ] && grep -q "부팅 뒤 100초): 최대 3초 기다림" $K/install.log && grep -q "HMG-API가 응답함(2초 기다림)" $K/install.log && [ -n "$PING3" ] && [ "$PING3" -lt $(at DiagActivity) ] && [ $(at DiagActivity) -lt $(at "^hmgapid engine install") ] && [ -f $HD/mods/nx4-kor/mod.json ] && [ "$(pg state)" = reboot ]' || { cat $T/ts.out; cat $T/calls; }
# 2) 끝까지 답하지 않음: 지금처럼 "재부팅하고 다시"로 멈춤. 늦게 눌렀어도(부팅 뒤 NX4_HMG_WAIT초가 지남) NX4_HMG_TRY초는 다시 묻는다
echo always > $T/ping.fails; cp $HD/mods/nx4-kor/mod.json $T/nx4mod.keep; rm -rf $K/diag
TSX="NX4_HMG_POLL=1 NX4_HMG_WAIT=0 NX4_HMG_TRY=2 NX4_TOAST_EVERY=1"; ts $U; TSX=
check "USB 설치기 HMG-API 기다리기: 끝까지 답이 없으면 아무것도 바꾸지 않고 멈춤(엔진·진행 기록 없음, 진단에 HMG-API 상태 없음), 늦게 눌러도 NX4_HMG_TRY초는 기다림, 토스트는 NX4_TOAST_EVERY초마다" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "기다려도 HMG-API가 응답하지 않습니다. 내비를 재부팅하고 다시 해 주세요. 아무것도 바꾸지 않았습니다." $T/ts.out && ! engcalls && ! grep -q "engine" $T/calls && [ ! -f $PG ] && [ "$(grep -c "HMG-API가 준비되기를 기다리는 중입니다" $T/ts.out)" = 2 ] && grep -q "최대 2초 기다림" $K/install.log && grep -q "HMG-API가 2초 기다려도 응답하지 않음" $K/install.log && cmp -s $T/nx4mod.keep $HD/mods/nx4-kor/mod.json' || { cat $T/ts.out; cat $T/calls; }
: > $K/UNINSTALL; rm -f $T/stublog
TSX="NX4_HMG_POLL=1 NX4_HMG_WAIT=0 NX4_HMG_TRY=1"; ts $U; TSX=
check "  지우기(UNINSTALL)도 기다린 뒤 답이 없으면 아무것도 지우지 않고 멈춤" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "기다려도 HMG-API가 응답하지 않습니다. 재부팅하고 다시" $T/ts.out && [ ! -f $T/stublog ] && ! grep -q "engine" $T/calls && [ -f $HD/mods/nx4-kor/mod.json ]' || cat $T/ts.out
rm -f $K/UNINSTALL
# 3) HMG-API가 없는 차(hmgapid 없음)는 기다리지 않고 지금처럼 멈춤(스틱에 HMG-API 설치기가 있으면 그것으로 넘김)
mv $HD $T/hd.away; rm -f $K/install.log
(env -u NX4_APP PATH=$P0 ROOT=$R HMGAPID=$T/nohmgapid NX4_USB_DIRS=$U NX4_APP_WAIT=1 NX4_DIAG_WAIT=1 NX4_DIAG_SHOWN=1 NX4_HMG_POLL=1 NX4_HMG_TRY=5 BOOT_ID=$T/bootid UPTIME=$T/uptime sh $B/usb/troubleShooter) > $T/ts.out 2>&1; echo $? > $T/ts.rc
check "USB 설치기 HMG-API 기다리기: HMG-API가 없는 차는 기다리지 않음(HMG-API가 없습니다로 바로 멈춤)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "HMG-API가 없습니다" $T/ts.out && ! grep -q "기다리는 중" $T/ts.out && ! grep -q "응답하지 않음" $R/data/local/tmp/nx4-kor-usb.log' || cat $T/ts.out
# hmgapid는 있는데 /data/hmgapi가 없는 차(PR #61 리뷰 4)도 설치 갈래가 "HMG-API 없음"으로 보므로 기다리지 않는다(기다렸다면 30초)
echo always > $T/ping.fails
W0=$(date +%s); TSX="NX4_HMG_POLL=1 NX4_HMG_WAIT=0 NX4_HMG_TRY=30"; ts $U; TSX=; W1=$(date +%s)
check "  hmgapid는 있는데 /data/hmgapi가 없으면 기다리지 않고 바로 HMG-API가 없습니다로 멈춤" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "HMG-API가 없습니다" $T/ts.out && ! grep -q "기다리는 중" $T/ts.out && [ $((W1 - W0)) -lt 20 ]' || cat $T/ts.out
mv $T/hd.away $HD; rm -f $T/ping.fails $K/install.log
# 4) HMG-API 부팅 보호: 이번 zygote 시작이 아직 확인되지 않았으면(starts ≥ 1) 재부팅 안내 전에 확인 시각(마지막 "hooks on" 줄 + 120 + 15초,
#    줄이 없으면 부팅 뒤 300초)까지 기다림. 가짜 커널 로그의 줄은 20초, uptime 100초, NX4_GUARD_DELAY로 남은 시간을 줄인다
#    status.sh take_rbreq처럼 HMG-API 판(installed.txt)이 있을 때만 본다
printf 'version %s\n' $NEEDV > $HD/installed.txt
mkdir -p $HD/hook; : > $HD/hook/enable; echo 2 > $HD/hook/starts
echo "<6>[   20.512345] hmgapi-hook: zygote, hooks on, start 2 (this boot 1), hmgapid, exec /system/bin/app_process.hmgapi-stock" > $T/dmesg
gfresh() { rm -rf $HD/mods/nx4-kor $HD/mods/wireless-carplay-aa; pset plan-new; mapnew; }
gfresh; TSX="NX4_HMG_POLL=1 NX4_GUARD_DELAY=68 NX4_DMESG=$T/dmesg"; ts $U; TSX=
gl() { _n=$(grep -n -- "$1" $K/install.log | head -1 | cut -d: -f1); echo ${_n:-99999}; }
check "USB 설치기 부팅 보호 기다리기: 이번 시작이 확인 전(starts=2)이면 적용 뒤·재부팅 안내 전에 확인 시각(20+68+15=103초)까지 기다림(토스트 한 번)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "starts=2, 부팅 뒤 100초, 확인 시각 103초): 최대 3초 기다린 뒤 재부팅을 안내" $K/install.log && grep -q "확인 시각까지 3초 기다림" $K/install.log && [ $(gl "적용함") -lt $(gl "부팅 보호") ] && [ $(gl "부팅 보호") -lt $(gl "설치를 마침") ] && [ "$(grep -c "HMG-API 시작 확인을 기다리는 중입니다(최대 1분). 아직 재부팅하지 마세요." $T/ts.out)" = 1 ] && [ "$(pg state)" = reboot ]' || { cat $T/ts.out; cat $K/install.log; }
# watcher가 starts를 0으로 쓰면 바로 멈춤(확인 시각은 먼 뒤)
gfresh; ( /bin/sleep 2; echo 0 > $HD/hook/starts ) & GBG=$!
G0=$(date +%s); TSX="NX4_HMG_POLL=1 NX4_GUARD_DELAY=600 NX4_DMESG=$T/dmesg"; ts $U; TSX=; G1=$(date +%s); wait $GBG
check "  watcher가 starts를 0으로 쓰면 확인 시각 전이라도 바로 멈춤" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "이번 시작이 확인됨(starts=0" $K/install.log && [ $((G1 - G0)) -lt 30 ] && [ "$(pg state)" = reboot ]' || cat $K/install.log
# 커널 로그에 이번 부팅 줄이 없으면 부팅 뒤 300초까지(uptime 298초로 2초)
echo 1 > $HD/hook/starts; echo "298.10 50.00" > $T/uptime
gfresh; TSX="NX4_HMG_POLL=1 NX4_DMESG=$T/nodmesg"; ts $U; TSX=
check "  커널 로그에 이번 zygote 줄이 없고 hook/enable이 있으면 부팅 뒤 300초까지 기다림" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "starts=1, 부팅 뒤 298초, 확인 시각 300초): 최대 2초" $K/install.log' || cat $K/install.log
echo "100.00 50.00" > $T/uptime
# 기다리지 않는 때: 이번 시작이 부팅 보호로 꺼짐(watcher 없음), starts=0(이미 확인됨), 줄이 없고 hook/disable이 있음, 바꾼 것이 없음
echo 7 > $HD/hook/starts; echo "<6>[   20.5] hmgapi-hook: zygote, hooks off (boot guard, starts=6, this boot 1), hmgapid, exec /system/bin/app_process.hmgapi-stock" > $T/dmesg-guard
gfresh; TSX="NX4_HMG_POLL=1 NX4_GUARD_DELAY=600 NX4_DMESG=$T/dmesg-guard"; ts $U; TSX=; _g1=$(cat $T/ts.rc); _g1l=$(grep -c "부팅 보호" $K/install.log)
echo 0 > $HD/hook/starts
gfresh; TSX="NX4_HMG_POLL=1 NX4_GUARD_DELAY=600 NX4_DMESG=$T/dmesg"; ts $U; TSX=; _g2=$(cat $T/ts.rc); _g2l=$(grep -c "부팅 보호" $K/install.log)
echo 3 > $HD/hook/starts; : > $HD/hook/disable
gfresh; TSX="NX4_HMG_POLL=1 NX4_DMESG=$T/nodmesg"; ts $U; TSX=; _g3=$(cat $T/ts.rc); _g3l=$(grep -c "부팅 보호" $K/install.log)
rm -f $HD/hook/disable; pset plan-same
TSX="NX4_HMG_POLL=1 NX4_GUARD_DELAY=600 NX4_DMESG=$T/dmesg"; ts $U; TSX=; _g4=$(cat $T/ts.rc); _g4l=$(grep -c "부팅 보호" $K/install.log); _g4s=$(pg state)
check "  기다리지 않음: 이번 시작의 훅이 부팅 보호로 꺼짐, starts=0, 줄이 없고 hook/disable이 있음, 같은 판에 바꿀 것이 없음(재부팅 안내 없음)" \
  '[ "$_g1$_g2$_g3$_g4" = 0000 ] && [ "$_g1l$_g2l$_g3l$_g4l" = 0000 ] && [ "$_g4s" = done ]'
# PR #61 리뷰 3: 줄이 없을 때도 take_rbreq처럼 파일로 보아 이번 시작이 이미 부팅 보호로 꺼졌으면(guard_files) 기다리지 않는다.
# 이번 부팅 횟수(hook/boot "<이번 boot_id> <n>") ≥ 4, 또는 ≥ 1이고 starts ≥ 7. 다른 부팅의 hook/boot면 꺼진 것으로 보지 않고 기다린다.
# HMG-API 판(installed.txt)이 없어도 기다리지 않는다. 고친 것을 되돌려도 오래 걸리지 않게 uptime 298초(줄 없음 → 300초)로 돈다
echo "298.10 50.00" > $T/uptime
echo 7 > $HD/hook/starts; echo "test-boot-id 1" > $HD/hook/boot
gfresh; TSX="NX4_HMG_POLL=1 NX4_DMESG=$T/nodmesg"; ts $U; TSX=; _f1=$(cat $T/ts.rc)$(grep -c "부팅 보호" $K/install.log)
echo 4 > $HD/hook/starts; echo "test-boot-id 4" > $HD/hook/boot
gfresh; TSX="NX4_HMG_POLL=1 NX4_DMESG=$T/nodmesg"; ts $U; TSX=; _f2=$(cat $T/ts.rc)$(grep -c "부팅 보호" $K/install.log)
echo 7 > $HD/hook/starts; echo "old-boot-id 5" > $HD/hook/boot
gfresh; TSX="NX4_HMG_POLL=1 NX4_DMESG=$T/nodmesg"; ts $U; TSX=; _f3=$(cat $T/ts.rc); grep -q "starts=7, 부팅 뒤 298초, 확인 시각 300초)" $K/install.log; _f3l=$?
rm -f $HD/hook/boot $HD/installed.txt; echo 2 > $HD/hook/starts
gfresh; TSX="NX4_HMG_POLL=1 NX4_DMESG=$T/nodmesg"; ts $U; TSX=; _f4=$(cat $T/ts.rc)$(grep -c "부팅 보호" $K/install.log)
printf 'version %s\n' $NEEDV > $HD/installed.txt; echo "100.00 50.00" > $T/uptime
check "  줄이 없을 때 파일로 보아 이번 시작이 이미 꺼졌으면(이번 부팅 1번·starts 7, 이번 부팅 4번) 기다리지 않음, 다른 부팅의 기록이면 기다림, HMG-API 판이 없으면 기다리지 않음" \
  '[ "$_f1$_f2$_f4" = 000000 ] && [ "$_f3$_f3l" = 00 ]'
# 지우기(UNINSTALL)는 스스로 재부팅하므로 그 전에 기다림
echo 2 > $HD/hook/starts; : > $K/UNINSTALL; rm -f $T/stublog
TSX="NX4_HMG_POLL=1 NX4_GUARD_DELAY=67 NX4_DMESG=$T/dmesg"; ts $U; TSX=
check "  지우기(UNINSTALL)도 재부팅 전에 확인 시각까지 기다림" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "최대 2초 기다린 뒤 재부팅을 안내" $K/install.log && [ "$(grep -n "HMG-API 시작 확인을 기다리는 중" $T/ts.out | cut -d: -f1)" -lt "$(grep -n "지웠습니다. 재부팅합니다" $T/ts.out | cut -d: -f1)" ] && [ ! -d $HD/mods/nx4-kor ]' || cat $T/ts.out
rm -f $K/UNINSTALL $HD/installed.txt; rm -rf $HD/hook
# 다음 테스트가 쓰는 상태(같은 판의 nx4-kor·공식 무선 모드·map)로 되돌린다
gfresh; ts $U; pset plan-same
# 진단 기록: /system/lib(하위 폴더·링크), 내비의 busybox, 이 모드의 기록. 비밀번호가 든 파일(Wi-Fi 설정, 백업 폴더)은 넣지 않음
mkdir -p $R/system/lib/hw $R/system/bin $R/data/nx4-kor/logs $R/data/nx4-kor/backup $R/data/local/tmp/nx4-kor $HD/logs/nx4-kor $R/data/misc/wifi
echo core > $R/system/lib/libCarPlayCore.so; echo hw > $R/system/lib/hw/gralloc.so; ln -s libCarPlayCore.so $R/system/lib/liblink.so
cp $T/bin/bb $R/system/bin/busybox
echo aplog > $R/data/nx4-kor/logs/ap.log; echo svclog > $HD/logs/nx4-kor/ap.log; echo hmgapi-install > $HD/install.log; mkdir -p $HD/logs/hmgapi; echo hmgapiwifi > $HD/logs/hmgapi/wifi.log
echo mapcar > $R/data/local/tmp/nx4-kor/map-car.txt; echo status > $R/data/local/tmp/nx4-kor-status.txt
echo "wpa_passphrase=SECRETPW" > $R/data/misc/wifi/softap.conf; echo SECRETPW > $R/data/nx4-kor/backup/softap.conf
mkdir -p $R/system/etc/permissions $R/system/onebin/nx4hev_kr; : > $R/system/etc/permissions/com.hkmc.software.wifi.module.xml
echo "-/system/etc/permissions/com.hkmc.software.wifihotspot.xml" > $R/system/onebin/nx4hev_kr/featurexml.cfg
echo "feature:com.hkmc.software.wifi.module" > $T/features
# 동글 준비 정보(#48): 커널(/proc, /sys/module), 차 커널 설정, 순정 Wi-Fi 드라이버·HAL·hostapd, USB 장치, 네트워크 장치, 커널 로그.
# 일련번호·MAC은 들어가지 않아야 한다(SERIALX, MACX)
mkdir -p $R/proc/sys/kernel $R/sys/module/module/parameters $R/sys/module/tcc_dwc_otg/parameters $R/sys/module/cfg80211 $R/system/wifi \
  $R/sys/bus/usb/devices/1-1 $R/sys/bus/usb/devices/usb1 $R/sys/bus/usb/drivers/rtl88x2bu/1-1:1.0 $R/sys/class/net/wlan0
echo 3.18.24-tcc > $R/proc/sys/kernel/osrelease; echo 0 > $R/proc/sys/kernel/modules_disabled; echo N > $R/sys/module/module/parameters/sig_enforce
echo "Linux version 3.18.24-tcc (gcc version 4.7)" > $R/proc/version; echo "bcmdhd 1234 0 - Live 0x00000000" > $R/proc/modules
echo 1 > $R/sys/module/tcc_dwc_otg/parameters/vbus_control_enable
printf 'CONFIG_CFG80211=y\nCONFIG_MODVERSIONS=n\n' > $T/kconfig; gzip -c $T/kconfig > $R/proc/config.gz
printf 'dhd\nvermagic=3.18.24-tcc SMP preempt mod_unload ARMv7 p2v8 \nlicense=GPL\n' > $R/system/wifi/bcmdhd.ko; echo fw > $R/system/wifi/fw_bcmdhd.bin
printf 'wifi_load_driver\n/system/wifi/bcmdhd.ko\niface_name=\nwifi_check_module_info\nunrelated text\n' > $R/system/lib/libhardware_legacy.so
# #80 차 확인(mount.txt): init·이 설치기·system_server·이름에 hmgapi가 든 프로세스 모두의 ppid·시작 시각·mount 이름공간·SELinux
# 도메인, init과 이름공간이 다른 프로세스, mountinfo, SELinux, avc 줄.
# 이름공간 링크는 ls -l로 읽으므로 대상 이름만 가진 링크로 흉내 낸다. system_server는 다른 이름공간에 둔다.
# HMG-API 데몬(245)은 실제 모양(comm hmgapid, ppid 1)으로 두고, /proc 사전 순으로 그보다 앞서는 미끼를 둔다(PR #84 리뷰 1):
# 다른 이름공간의 hmgapid 클라이언트(12345, ppid 777), 차량 서비스 hmgapi.vehicle(1532), 이름에 공백·글롭 문자가 든 것(1600, 리뷰 4).
# 명령줄에만 hmgapid가 든 300(app_process)은 적지 않는다. 888은 이름공간 링크가 없다(읽지 못함, 리뷰 3)
for _p in 1 self 200 245 300 400 777 888 999 1532 1600 12345; do mkdir -p $R/proc/$_p/ns $R/proc/$_p/attr; done
for _p in 1 self 245 300 400 1532 1600 999; do ln -s 'mnt:[4026531840]' $R/proc/$_p/ns/mnt; done
ln -s 'mnt:[4026532001]' $R/proc/200/ns/mnt
for _p in 777 12345; do ln -s 'mnt:[4026532999]' $R/proc/$_p/ns/mnt; done
for _p in 1:init self:sh 200:system_server 245:hmgapid 300:app_process 400:zygote 777:com.example.app 888:kthreadx 999:deniedproc 1532:hmgapi.vehicle "1600:hmgapi w *" 12345:hmgapid; do
  echo "${_p#*:}" > "$R/proc/${_p%%:*}/comm"
done
echo hmgapid > $R/proc/300/cmdline
# stat: 1 pid, 2 (comm), 3 state, 4 ppid, 22 시작 시각(1/100초)
mkstat() { printf '%s (%s) S %s %s%s 100 0\n' "$1" "$2" "$3" "$(printf '0 %.0s' $(seq 1 17))" "$4" > "$R/proc/$5/stat"; }
mkstat 1 init 0 0 1; mkstat 4242 sh 1 99900 self; mkstat 200 system_server 150 1234 200; mkstat 245 hmgapid 1 810 245
mkstat 1532 hmgapi.vehicle 300 4100 1532; mkstat 1600 'hmgapi w *' 5 5000 1600; mkstat 12345 hmgapid 777 60000 12345
for _p in 1:u:r:init:s0 200:u:r:system_server:s0 245:u:r:init:s0; do echo "${_p#*:}" > $R/proc/${_p%%:*}/attr/current; done
_mi='1 0 179:2 / / ro,relatime shared:1 - ext4 /dev/root ro
20 1 179:3 / /system ro,relatime shared:2 - ext4 /dev/block/system ro
21 1 179:4 / /data rw,nosuid shared:3 - ext4 /dev/block/data rw
22 1 0:5 / /dev rw,nosuid shared:4 - tmpfs tmpfs rw'
printf '%s\n' "$_mi" > $R/proc/1/mountinfo; printf '%s\n' "$_mi" > $R/proc/self/mountinfo; printf '%s\n' "$_mi" > $R/proc/245/mountinfo
printf '%s\n' "$_mi" | sed 's/shared:\([0-9]\)/master:\1/' > $R/proc/200/mountinfo
printf '%s\n' "$_mi" | sed 's/shared:\([0-9]\)/master:9/' > $R/proc/12345/mountinfo
mkdir -p $R/sys/fs/selinux; echo 0 > $R/sys/fs/selinux/enforce
printf '#!/bin/sh\necho Permissive\n' > $T/bin/getenforce; chmod +x $T/bin/getenforce
printf 'driver=nl80211\n' > $R/system/bin/hostapd
for f in idVendor:0bda idProduct:b812 speed:480 bMaxPower:500mA bDeviceClass:00 manufacturer:Realtek product:802.11ac_NIC serial:SERIALX; do echo ${f#*:} > $R/sys/bus/usb/devices/1-1/${f%%:*}; done
for f in idVendor:1d6b idProduct:0002 speed:480; do echo ${f#*:} > $R/sys/bus/usb/devices/usb1/${f%%:*}; done
echo MACX > $R/sys/class/net/wlan0/address
# MAC이 든 줄(순정 bcmdhd, Realtek, 대시 꼴)은 빠져야 한다(PR #66 리뷰 1)
printf '%s\n' "<6>[   30.1] usb 1-1: new high-speed USB device number 2 using ehci-tcc" "<6>[   30.2] usb 1-1: SerialNumber: SERIALX" "<6>[   31.0] hmgapi-hook: something else" \
  "<4>[   32.0] dhd_attach: Broadcom Dongle Host Driver mac=00:90:4c:11:22:33" "<4>[   33.0] RTW: rtw_macaddr_cfg MAC Address  = 00:e0:4c:aa:bb:cc" \
  "<4>[   34.0] wlan0: link up 00-e0-4c-dd-ee-ff" "<4>[   35.0] RTW: rtw_ndev_init(wlan0) if1" \
  "<4>[   36.0] rtl88x2bu: hwaddr 00e04c445566" "<4>[   37.0] rtl88x2bu: probe 00E04C778899 done" \
  '<5>[   38.0] type=1400 audit(1795680663.510:42): avc: denied { module_load } for pid=245 comm="hmgapid" scontext=u:r:init:s0 tcontext=u:object_r:system_file:s0 tclass=system' \
  '<5>[   38.1] type=1400 audit(1795680663.520:43): avc: denied { read } for pid=777 comm="com.example.app" laddr=00:e0:4c:aa:bb:cc tclass=file' > $T/ddmesg
# 이 회는 진단 기록만 본다. backup이 있어 설치기가 2.0.x 되돌리기 길을 타지 않게 legacy-2.0을 치워(가드에서 아무것도 바꾸지 않고 멈춤)
# 진단 기록에 백업 폴더가 들어가지 않는지만 본다(PR #52 리뷰 10). 끝나면 backup을 지운다
rm -rf $K/diag; legoff
TSX="NX4_DMESG=$T/ddmesg"; ts $U; TSX=
check "USB 설치기 진단 기록: 순정 기능(pm list features), /system/etc/permissions 목록, onebin마다 featurexml.cfg 사본" \
  'grep -qx "feature:com.hkmc.software.wifi.module" $(dg)/features.txt && grep -q "com.hkmc.software.wifi.module.xml" $(dg)/permissions-ls.txt && grep -q "wifihotspot.xml" $(dg)/featurexml-nx4hev_kr.cfg' || ls $(dg)
rm -f $T/features
CORE5=$(md5sum < $R/system/lib/libCarPlayCore.so | cut -d" " -f1)
check "USB 설치기 진단 기록: NX4/diag/<시각>/에 /system/lib 아래 모든 파일(하위 폴더·링크 포함)의 md5와 경로, ls -lR" \
  '[ "$(ls $K/diag | wc -l)" -eq 1 ] && grep -q "^$CORE5  .*/system/lib/libCarPlayCore.so$" $(dg)/system-lib-md5.txt && grep -q "^$CORE5  .*/system/lib/liblink.so$" $(dg)/system-lib-md5.txt && grep -q "  .*/system/lib/hw/gralloc.so$" $(dg)/system-lib-md5.txt && [ "$(wc -l < $(dg)/system-lib-md5.txt)" -eq 4 ] && grep -q "liblink.so -> libCarPlayCore.so" $(dg)/system-lib-ls.txt' || cat $(dg)/system-lib-md5.txt
check "USB 설치기 진단 기록: info.txt(판·공식 무선 모드 판·getprop·내비 busybox 유무·wifi_ap_on), HMG-API 상태·Car Report 복사, 이 모드와 HMG-API 기록" \
  'grep -qx "installed_mod: $V" $(dg)/info.txt && grep -qx "usb_mod: $V" $(dg)/info.txt && grep -qx "installed_wireless: $WV" $(dg)/info.txt && grep -qx "usb_wireless: $WV" $(dg)/info.txt && grep -q "^ro.build.product: NX4.KOR" $(dg)/info.txt && grep -qx "system_busybox: yes" $(dg)/info.txt && grep -qx "md5_busybox: $R/system/bin/busybox" $(dg)/info.txt && grep -qx "wifi_ap_on: 1" $(dg)/info.txt && grep -qx "hmgapid engine status" $T/calls && [ -f $(dg)/hmgapi-status.txt ] && grep -q "^saved: " $(dg)/car-report.txt && [ -f $(dg)/car-report-test.json ] && [ -f $(dg)/car-report-test.md ] && grep -qx aplog $(dg)/logs/ap.log && grep -qx svclog $(dg)/logs/service/ap.log && grep -qx hmgapi-install $(dg)/logs/hmgapi-install.log && grep -qx hmgapiwifi $(dg)/logs/hmgapi-wifi.log && grep -qx mapcar $(dg)/logs/map-car.txt && grep -qx status $(dg)/logs/nx4-kor-status.txt && grep -q "진단 기록을 모음: NX4/diag/" $K/install.log' || cat $(dg)/info.txt
check "USB 설치기 진단 기록: 비밀번호가 든 파일(softap.conf, 백업 폴더)은 넣지 않음(이 회는 설치기가 아무것도 바꾸지 않음)" '! grep -rq SECRETPW $K/diag && ! engcalls'
DG=$(dg)/dongle
check "USB 설치기 진단 기록(동글 준비, #48): kernel.txt(커널 판·modules_disabled·sig_enforce·cfg80211·vbus 매개변수·boot_id), /proc/modules" \
  'grep -qx "osrelease: 3.18.24-tcc" $DG/kernel.txt && grep -q "^version: Linux version 3.18.24-tcc" $DG/kernel.txt && grep -qx "modules_disabled: 0" $DG/kernel.txt && grep -qx "sig_enforce: N" $DG/kernel.txt && grep -qx "cfg80211: yes" $DG/kernel.txt && grep -qx "tcc_dwc_otg/parameters/vbus_control_enable: 1" $DG/kernel.txt && grep -qx "boot_id: test-boot-id" $DG/kernel.txt && grep -q "^bcmdhd " $DG/modules.txt' || cat $DG/kernel.txt
KCG5=$(md5sum < $R/proc/config.gz | cut -d" " -f1); KCS=$(sha256sum < $T/kconfig | cut -d" " -f1)
check "USB 설치기 진단 기록(동글 준비): 차 커널 설정(/proc/config.gz) 사본과 푼 것, gz의 md5와 푼 것의 sha256" \
  'cmp -s $R/proc/config.gz $DG/config.gz && cmp -s $T/kconfig $DG/config.txt && grep -qx "config.gz md5: $KCG5" $DG/config-sum.txt && grep -qx "config.txt sha256: $KCS" $DG/config-sum.txt' || cat $DG/config-sum.txt
KO5=$(md5sum < $R/system/wifi/bcmdhd.ko | cut -d" " -f1)
check "USB 설치기 진단 기록(동글 준비): /system/wifi 목록·md5, 순정 bcmdhd.ko의 vermagic, HAL·hostapd의 드라이버 문자열(관계없는 줄은 뺌)" \
  'grep -q "fw_bcmdhd.bin" $DG/system-wifi-ls.txt && grep -qx "$KO5  /system/wifi/bcmdhd.ko" $DG/system-wifi-md5.txt && grep -q "^/system/wifi/bcmdhd.ko: vermagic=3.18.24-tcc SMP preempt mod_unload ARMv7 p2v8" $DG/ko-vermagic.txt && grep -qx "== /system/lib/libhardware_legacy.so" $DG/wifi-strings.txt && grep -qx "iface_name=" $DG/wifi-strings.txt && grep -qx "/system/wifi/bcmdhd.ko" $DG/wifi-strings.txt && grep -qx "driver=nl80211" $DG/wifi-strings.txt && ! grep -q "unrelated" $DG/wifi-strings.txt' || cat $DG/wifi-strings.txt $DG/ko-vermagic.txt
check "USB 설치기 진단 기록(동글 준비): USB 장치(ID·속도·전력·제품), 드라이버에 붙은 인터페이스, 네트워크 장치, 커널 로그의 USB·Wi-Fi 줄. 일련번호·MAC은 넣지 않음" \
  'grep -q "^1-1 0bda:b812 speed=480 maxpower=500mA class=00 manufacturer=Realtek product=802.11ac_NIC$" $DG/usb.txt && grep -q "^usb1 1d6b:0002 " $DG/usb.txt && grep -q "1-1" $DG/usb-ls.txt && grep -qx "== rtl88x2bu" $DG/usb-drivers.txt && grep -qx "1-1:1.0" $DG/usb-drivers.txt && grep -q "wlan0" $DG/net-ls.txt && grep -q "new high-speed USB device" $DG/dmesg-usb-wifi.txt && grep -q "rtw_ndev_init(wlan0)" $DG/dmesg-usb-wifi.txt && ! grep -q "hmgapi-hook" $DG/dmesg-usb-wifi.txt && ! grep -rqi -e SERIALX -e MACX -e 11:22:33 -e aa:bb:cc -e dd-ee-ff -e 445566 -e 778899 $K/diag && grep -q "동글 준비 정보를 모음" $K/install.log' || cat $DG/usb.txt $DG/dmesg-usb-wifi.txt
check "USB 설치기 진단 기록(동글 준비, #80): mount.txt에 SELinux(getenforce·enforce), init·설치기·system_server의 ppid·시작 시각·mount 이름공간·SELinux 도메인, 그 /·/system·/data mountinfo 줄(전파 표시)" \
  'grep -qx "selinux_getenforce: Permissive" $DG/mount.txt && grep -qx "selinux_enforce: 0" $DG/mount.txt && grep -qxF "proc init: pid=1 comm=init ppid=0 start=0.0s ns=mnt:[4026531840] se=u:r:init:s0" $DG/mount.txt && grep -qxF "proc self: pid=self comm=sh ppid=1 start=999.0s ns=mnt:[4026531840] se=?" $DG/mount.txt && grep -qxF "proc system_server: pid=200 comm=system_server ppid=150 start=12.3s ns=mnt:[4026532001] se=u:r:system_server:s0" $DG/mount.txt && grep -qx "== mountinfo system_server(200)" $DG/mount.txt && grep -q "^20 1 179:3 / /system ro,relatime master:2 " $DG/mount.txt && grep -q "^21 1 179:4 / /data .*shared:3" $DG/mount.txt && ! grep -q " /dev rw" $DG/mount.txt && grep -qx "wifi_check_module_info" $DG/wifi-strings.txt' || cat $DG/mount.txt
check "  HMG-API: 이름에 hmgapi가 든 프로세스를 모두 적고 데몬(comm hmgapid, ppid 1)에만 데몬 표시, mountinfo는 데몬 것. 사전 순으로 앞선 클라이언트·차량 서비스를 데몬으로 고르지 않음, 명령줄만 맞는 것은 적지 않음, 이름의 공백·글롭에도 시작 시각이 맞음(PR #84 리뷰 1·4)" \
  'grep -qxF "proc hmgapi: pid=245 comm=hmgapid ppid=1 start=8.1s ns=mnt:[4026531840] se=u:r:init:s0 데몬" $DG/mount.txt && grep -qxF "proc hmgapi: pid=12345 comm=hmgapid ppid=777 start=600.0s ns=mnt:[4026532999] se=?" $DG/mount.txt && grep -qxF "proc hmgapi: pid=1532 comm=hmgapi.vehicle ppid=300 start=41.0s ns=mnt:[4026531840] se=?" $DG/mount.txt && grep -qxF "proc hmgapi: pid=1600 comm=hmgapi w * ppid=5 start=50.0s ns=mnt:[4026531840] se=?" $DG/mount.txt && [ "$(grep -c " 데몬$" $DG/mount.txt)" = 1 ] && ! grep -q "^proc hmgapi: pid=300 " $DG/mount.txt && grep -qx "== mountinfo hmgapid 데몬(245)" $DG/mount.txt && ! grep -q "master:9" $DG/mount.txt' || cat $DG/mount.txt
check "  init과 이름공간이 다른 프로세스 목록(링크를 못 읽으면 ls 오류 문구), avc 줄(MAC 꼴이 든 줄은 뺌)(PR #84 리뷰 2·3)" \
  'sed -n "/^== mount 이름공간이 init/,/^== mountinfo init/p" $DG/mount.txt > $T/nsdiff && grep -qxF "pid=200 comm=system_server ns=mnt:[4026532001]" $T/nsdiff && grep -qxF "pid=777 comm=com.example.app ns=mnt:[4026532999]" $T/nsdiff && grep -qxF "pid=12345 comm=hmgapid ns=mnt:[4026532999]" $T/nsdiff && grep -q "^pid=888 comm=kthreadx ns=읽지 못함(.*888/ns/mnt" $T/nsdiff && ! grep -qE "^pid=(1|245|300|400|999|1532|1600) " $T/nsdiff && grep -qx "== avc(커널 기록, 앞 50줄)" $DG/mount.txt && grep -q "avc: denied { module_load } for pid=245 comm=\"hmgapid\"" $DG/mount.txt && ! grep -q "aa:bb:cc" $DG/mount.txt' || cat $DG/mount.txt
# 셸이 파일을 못 열 때의 문구(self·12345·1532·1600에는 attr/current가 없음)가 mount.txt에 섞이지 않음(PR #84 리뷰 5)
check "  파일을 못 연 셸 문구(attr/current·comm·stat)가 mount.txt에 섞이지 않음(PR #84 리뷰 5)" \
  '! grep -qE "attr/current|/comm|/stat|line [0-9]+:|cannot open" $DG/mount.txt' || cat $DG/mount.txt
# 차의 툴박스 ls처럼 링크 대상을 못 읽으면 아무것도 찍지 않는 경우(거절, PR #84 리뷰 3): 999의 이름공간 링크만 그렇게 흉내 낸다
printf '#!/bin/sh\nfor a; do case "$a" in */proc/999/ns/mnt) exit 1 ;; esac; done\nexec /bin/ls "$@"\n' > $T/bin/ls; chmod +x $T/bin/ls
rm -rf $K/diag; TSX="NX4_DMESG=$T/ddmesg"; ts $U; TSX=; rm -f $T/bin/ls; DG=$(dg)/dongle
check "  툴박스 ls가 링크 대상을 못 읽어 아무것도 찍지 않으면(거절) \"링크는 있음\"으로 적고 \"없음\"으로 적지 않음(PR #84 리뷰 3)" \
  'grep -qxF "pid=999 comm=deniedproc ns=읽지 못함(링크는 있음, 대상을 못 읽음: 거절일 수 있음)" $DG/mount.txt && ! grep -q "ns=없음" $DG/mount.txt && grep -qxF "proc system_server: pid=200 comm=system_server ppid=150 start=12.3s ns=mnt:[4026532001] se=u:r:system_server:s0" $DG/mount.txt' || cat $DG/mount.txt
legon; rm -rf $R/data/nx4-kor/backup
# 내비의 busybox에 strings·sha256sum·gunzip이 없으면 빈 값 대신 까닭을 적음(PR #66 리뷰 2)
printf '#!/bin/sh\ncase "$1" in strings|sha256sum|gunzip) echo "$1: applet not found" >&2; exit 127 ;; esac\ncommand -v "$1" >/dev/null 2>&1 || exit 127\nexec "$@"\n' > $R/system/bin/busybox
rm -rf $K/diag; ts $U; DG=$(dg)/dongle
check "USB 설치기 진단 기록(동글 준비): busybox에 gunzip·sha256sum·strings가 없으면 config.gz md5는 남기고, 풀지 못함·vermagic·문자열을 못 읽음을 적음" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -qx "config.gz md5: $KCG5" $DG/config-sum.txt && grep -q "^config.txt: busybox로 풀지 못함" $DG/config-sum.txt && [ ! -f $DG/config.txt ] && grep -q "strings나 grep" $DG/ko-vermagic.txt && grep -q "strings나 grep" $DG/wifi-strings.txt && grep -qx "$KO5  /system/wifi/bcmdhd.ko" $DG/system-wifi-md5.txt && grep -q "strings·grep이 없어" $K/install.log' || cat $DG/config-sum.txt $DG/ko-vermagic.txt
# gunzip은 있고 sha256sum만 없으면 sha256 줄에 까닭을 적음
printf '#!/bin/sh\ncase "$1" in sha256sum) exit 127 ;; esac\ncommand -v "$1" >/dev/null 2>&1 || exit 127\nexec "$@"\n' > $R/system/bin/busybox
rm -rf $K/diag; ts $U; DG=$(dg)/dongle
check "USB 설치기 진단 기록(동글 준비): sha256sum만 없으면 config.txt와 md5는 남기고 sha256 줄에 까닭을 적음" \
  'cmp -s $T/kconfig $DG/config.txt && grep -q "^config.txt md5: " $DG/config-sum.txt && grep -qx "config.txt sha256: busybox에 sha256sum이 없음(PC에서 셈)" $DG/config-sum.txt && grep -q "vermagic=3.18.24-tcc" $DG/ko-vermagic.txt' || cat $DG/config-sum.txt
cp $T/bin/bb $R/system/bin/busybox
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
check "USB 설치기 진단 기록(동글 준비): busybox가 없어도 커널 설정(config.gz)은 복사하고, md5·문자열이 빠졌다고 적음" \
  'cmp -s $R/proc/config.gz $(dg)/dongle/config.gz && [ ! -f $(dg)/dongle/config.txt ] && grep -q "busybox가 없음" $(dg)/dongle/config-sum.txt && grep -q "busybox가 없어" $(dg)/dongle/system-wifi-md5.txt && grep -q "0bda:b812" $(dg)/dongle/usb.txt'
rm -f $R/proc/config.gz; rm -rf $K/diag; ts $U
check "USB 설치기 진단 기록(동글 준비): /proc/config.gz가 없으면 그렇다고 적고 설치기는 그대로 끝남" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "config.gz 없음" $(dg)/dongle/config-sum.txt && grep -q "/proc/config.gz가 없음" $K/install.log'
rm -rf $R/proc $R/sys
# 확인 창에서 모으지 않는 경우: 진단 폴더를 만들지 않고 HMG-API 명령도 부르지 않으며, 설치기는 그대로 이어짐(같은 판: 관리 앱)
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
check "USB 설치기 진단 기록: 관리 앱이 없으면 묻지 못해 모으지 않음(확인 창을 띄우지 않음)" \
  '[ ! -d $K/diag ] && ! grep -q "DiagActivity" $T/calls && grep -q "앱이 없어 묻지 못함" $K/install.log'
: > $T/app-ready
rm -rf $R/system $R/data/misc $R/data/nx4-kor $R/data/local/tmp/nx4-kor $R/data/local/tmp/nx4-kor-status.txt $HD/logs $HD/install.log $HD/public
: > $K/REINSTALL; : > $T/ap-running; rm -f $T/stublog
ts $U
check "USB 설치기: REINSTALL이면 nx4-kor 예전 판 정리(uninstall.sh --update) → engine install → 돌던 서비스(ap) 다시 시작, 같은 판의 공식 무선 모드도 다시 설치" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "NX4_UPDATE=1" $T/stublog && grep -q "^hmgapid engine install .*/nx4-kor.zip$" $T/calls && grep -qx "hmgapid service-start nx4-kor ap" $T/calls && ! grep -q "service-start nx4-kor launch" $T/calls && grep -q "^hmgapid engine install .*/wireless-carplay-aa.zip --any-car$" $T/calls && [ "$(pg state)" = reboot ]' || cat $T/ts.out
rm -f $K/REINSTALL $T/ap-running
# 공식 무선 모드: 같거나 높은 판은 그대로, 낮은 판은 올림, 한국 차 빌드(Korea Projection)는 공식판으로 바꿈, 꺼져 있으면 켬
wmod 2.3.0
ts $U
check "USB 설치기: 공식 무선 모드가 스틱($WV)보다 높은 판(2.3.0)이면 그대로 둠(설치·지우기 없음)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && ! grep -q "wireless-carplay-aa" $T/calls && grep -q "\"version\": \"2.3.0\"" $HD/mods/wireless-carplay-aa/mod.json && grep -q "공식 무선 모드 2.3.0가 이미 있음" $K/install.log'
wmod 2.2.0-rc.5
ts $U
check "USB 설치기: 공식 무선 모드가 낮은 판(2.2.0-rc.5)이면 스틱의 판으로 올림(--any-car), 지우지 않음" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -qx "hmgapid engine install $R/data/local/tmp/nx4-kor-usb/wireless-carplay-aa.zip --any-car" $T/calls && ! grep -q "engine remove" $T/calls && grep -q "2.2.0-rc.5에서 $WV(으)로" $T/ts.out && grep -q "\"version\": \"$WV\"" $HD/mods/wireless-carplay-aa/mod.json'
wmod 2.4.5 "Korea Projection: Wireless CarPlay + Android Auto"
printf 'restore  /system/lib/libleafiaaac.so (stock)\n' > $T/plan-krfork; cat $T/plan-same >> $T/plan-krfork
pset plan-same plan-krfork plan-krfork
ts $U
check "USB 설치기: Korea Projection 한국 차 빌드(같은 id 2.4.5)는 지우고 공식판을 설치, 그 되돌리기(restore)를 계획에서 받아 적용" \
  '[ "$(cat $T/ts.rc)" = 0 ] && [ $(at "engine remove wireless-carplay-aa") -lt $(at "wireless-carplay-aa.zip --any-car") ] && grep -qx "hmgapid engine apply" $T/calls && grep -q "\"version\": \"$WV\"" $HD/mods/wireless-carplay-aa/mod.json && [ "$(pg state)" = reboot ]' || { cat $T/ts.out; cat $T/calls; }
pset plan-same
: > $HD/mods/wireless-carplay-aa/.disabled
ts $U
check "USB 설치기: 꺼 둔 공식 무선 모드는 켬(hmgapid enable) → 재부팅 안내" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -qx "hmgapid enable wireless-carplay-aa" $T/calls && [ ! -f $HD/mods/wireless-carplay-aa/.disabled ] && [ "$(pg state)" = reboot ]'
# 계획: 시작 전에 다른 모드의 적용하지 않은 변경이 있으면 아무것도 바꾸지 않음. 끝의 계획이 우리 것이 아니면 적용하지 않음
printf 'change   /system/framework/framework.odex [other-mod] -> 89ab   [restart the head unit]\n' > $T/plan-other; cat $T/plan-same >> $T/plan-other
wmod 2.2.0-rc.5; pset plan-other
ts $U
check "USB 설치기: 시작 전 계획에 다른 모드의 변경이 있으면 아무것도 바꾸지 않고 멈춤(설치·지우기·적용 없음, 진행 기록 없음), 같은 판이라 관리 앱은 먼저 엶" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "다른 모드의 적용하지 않은 변경이 있습니다" $T/ts.out && ! grep -q -E "engine (install|remove|apply)" $T/calls && [ ! -f $PG ] && grep -q "\"version\": \"2.2.0-rc.5\"" $HD/mods/wireless-carplay-aa/mod.json && [ $(at "StatusActivity") -lt $(at "engine plan") ]'
# 되돌리기 줄(restore …, 모드 이름 없음)이 시작 전 계획에 있는데 이번에 지울 모드가 없으면: 앞서 다른 모드를 지우고 적용하지 않은 것이라
# 끝에서 받을 수 없다. 설치·map 만들기 전에 멈춘다(PR #52 리뷰 1)
pset plan-krfork
ts $U
check "USB 설치기: 시작 전 계획에 되돌리기 줄이 있는데 이번에 지울 모드가 없으면 아무것도 바꾸지 않고 멈춤(설치·map·적용 없음, 진행 기록 없음)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "다른 모드의 적용하지 않은 변경이 있습니다" $T/ts.out && ! grep -q -E "engine (install|remove|apply|map-car|verify-map)" $T/calls && [ ! -f $PG ]'
# engine plan이 계획을 내지 못하면(rc.8: 끝나지 않은 적용·trial, 종료 1) 아무것도 바꾸지 않고 그 까닭으로 멈춤(PR #52 리뷰 3)
printf 'an earlier apply isn'"'"'t finished or is a trial: run `engine keep` (trial) or `engine recover` first\n' > $T/plan-notdone
pset plan-notdone; echo 1 > $T/plan.rc
ts $U
check "USB 설치기: engine plan이 0·3 말고 다른 종료 코드면(끝나지 않은 적용 등) 아무것도 바꾸지 않고 멈춤, 종료 코드를 기록에 남김" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "계획을 내지 못했습니다" $T/ts.out && ! grep -q -E "engine (install|remove|apply)" $T/calls && [ ! -f $PG ] && grep -q "^--- engine plan (pre, 종료 코드 1)" $K/install.log'
rm -f $T/plan.rc
wmod $WV; pset plan-same plan-other
ts $U
check "USB 설치기: 끝의 계획에 다른 모드의 변경이 섞이면 적용하지 않고 HMG-API 앱에서 적용하라고 안내(state=fail, 자동 설정과 같은 문구)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && ! grep -q "engine apply" $T/calls && [ "$(pg state)" = fail ] && pg stage | grep -q "다른 모드의 바뀐 내용이 함께 있어 자동으로 적용하지 않았습니다"' || cat $PG
printf 'hooks are off on this car (map not checked): mods apply without their hooks\n' > $T/plan-hooksoff; cat $T/plan-new >> $T/plan-hooksoff
pset plan-same plan-hooksoff
ts $U
check "USB 설치기: 끝의 계획에서 훅이 꺼져 있으면(hooks are off) 적용하지 않음(state=fail)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && ! grep -q "engine apply" $T/calls && [ "$(pg state)" = fail ] && pg stage | grep -q "켜지지 않는 훅"'
pset plan-same plan-krfork
ts $U
check "USB 설치기: 이번에 지우거나 판을 바꾼 모드가 없는데 끝 계획에 되돌리기(restore) 줄이 있으면 적용하지 않음" \
  '[ "$(cat $T/ts.rc)" = 1 ] && ! grep -q "engine apply" $T/calls && [ "$(pg state)" = fail ]'
# 판을 바꿔 설치한 모드(nx4-kor 업데이트)가 새 판에서 더는 바꾸지 않는 것의 되돌리기 줄은 끝 계획에서 받는다(PR #52 리뷰 1)
modset $HD/mods/nx4-kor/mod.json version=1.9.9
pset plan-same plan-krfork
ts $U
check "USB 설치기: nx4-kor를 판을 바꿔 설치했으면 끝 계획의 되돌리기 줄을 받아 적용" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "1.9.9에서 $V(으)로" $T/ts.out && grep -qx "hmgapid engine apply" $T/calls && [ "$(pg state)" = reboot ]' || { cat $T/ts.out; cat $K/install.log; }
# 스틱의 nx4-kor가 아직 옛 2.0.x 꼴(conflicts)이면 아무것도 바꾸기 전에 멈춤(PR #52 리뷰 2)
modset $K/install/payload/mod.json conflicts=wireless-carplay-aa
ts $U
check "USB 설치기: 스틱의 nx4-kor가 옛 2.0.x 꼴(공식 무선 모드와 충돌 선언)이면 아무것도 바꾸지 않고 멈춤" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "옛 2.0.x 꼴(공식 무선 모드와 충돌)이라 이 설치기와 함께 쓸 수 없습니다" $T/ts.out && ! engcalls && [ ! -f $PG ]'
modset $K/install/payload/mod.json conflicts=-
# 원본 Korea Projection 패키지(#13): 설치·업데이트 갈래(같은 판 포함)에서 그 패키지 폴더가 있으면 아무것도 바꾸기 전에 멈춘다.
# HMG-API 기다리기·HMG-API 확인(HMG-API 설치기로 넘기기) 앞이라 같은 판이어도 관리 앱을 열지 않는다. 진단 기록은 멈추기 전에 묻는다.
# 다른 NEMESIS 패키지는 막지 않고, 지우기 갈래도 막지 않는다. 진단 기록은 [건너뛰기]로 두어 HMG-API 명령이 하나도 없는지 본다
KPD=$R/data/nemesis/apps/korea.projection
KPMSG="NX4 KOR: $KORPROJ_TEXT"
mkdir -p $KPD; echo no > $T/diag.reply; pset plan-new; cp $HD/mods/nx4-kor/mod.json $T/kp-nx4.json
ts $U
check "USB 설치기(#13): NEMESIS의 Korea Projection 패키지 폴더가 있으면 아무것도 바꾸지 않고 멈춤(종료 1, 안내 문구, 진단 기록은 멈추기 전에 물음, HMG-API 명령 없음(HMG-API 기다리기보다 앞이라 ping도 없음), 같은 판이어도 관리 앱을 열지 않음, 진행 기록 없음)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qxF "$KPMSG" $T/ts.out && grep -q DiagActivity $T/calls && ! grep -q "^hmgapid" $T/calls && ! grep -q StatusActivity $T/calls && [ ! -f $PG ] && [ ! -d $R/data/local/tmp/nx4-kor-usb ] && cmp -s $T/kp-nx4.json $HD/mods/nx4-kor/mod.json && grep -q "원본 Korea Projection 패키지가 있음" $K/install.log' || { cat $T/ts.out; cat $T/calls; }
# PR #61 리뷰 1: Korea Projection 패키지가 있는 차와 잘못된 스틱(옛 2.0.x 꼴 payload, 묶음 없음)은 부팅 직후 HMG-API가 답하지 않아도
# 기다리지 않고 바로 원래 문구로 멈춘다(ping도 부르지 않음). 기다렸다면 NX4_HMG_TRY=30초가 걸린다
echo always > $T/ping.fails; echo yes > $T/diag.reply; rm -rf $K/diag
W0=$(date +%s); TSX="NX4_HMG_POLL=1 NX4_HMG_WAIT=0 NX4_HMG_TRY=30"; ts $U; TSX=; W1=$(date +%s)
check "  Korea Projection 패키지가 있으면 HMG-API가 답하지 않아도 기다리지 않고 바로 KORPROJ_MSG로 멈춤(진단 기록은 [모으기]면 모음)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qxF "$KPMSG" $T/ts.out && ! grep -q "기다리는 중" $T/ts.out && ! grep -q "응답하지 않습니다" $T/ts.out && [ $((W1 - W0)) -lt 20 ] && [ -f $(dg)/info.txt ] && [ ! -f $PG ]' || cat $T/ts.out
rm -rf $KPD $K/diag; cp $K/install/payload/mod.json $T/pay.keep; modset $K/install/payload/mod.json conflicts=wireless-carplay-aa
W0=$(date +%s); TSX="NX4_HMG_POLL=1 NX4_HMG_WAIT=0 NX4_HMG_TRY=30"; ts $U; TSX=; W1=$(date +%s)
_w1=$(cat $T/ts.rc); _w1t=$((W1 - W0)); grep -q "옛 2.0.x 꼴" $T/ts.out; _w1m=$?; grep -q "기다리는 중" $T/ts.out; _w1w=$?
cp $T/pay.keep $K/install/payload/mod.json; mv $K/wireless $T/wireless.away
W0=$(date +%s); TSX="NX4_HMG_POLL=1 NX4_HMG_WAIT=0 NX4_HMG_TRY=30"; ts $U; TSX=; W1=$(date +%s)
mv $T/wireless.away $K/wireless
check "  잘못된 스틱(옛 2.0.x 꼴 payload, NX4/wireless 없음)도 HMG-API를 기다리지 않고 바로 원래 문구로 멈춤(엔진 명령 없음)" \
  '[ "$_w1$_w1m$_w1w" = 101 ] && [ $_w1t -lt 20 ] && [ "$(cat $T/ts.rc)" = 1 ] && grep -q "USB에 NX4/wireless" $T/ts.out && ! grep -q "기다리는 중" $T/ts.out && [ $((W1 - W0)) -lt 20 ] && ! engcalls' || cat $T/ts.out
rm -f $T/ping.fails; rm -rf $K/diag; mkdir -p $KPD; echo no > $T/diag.reply
mv $HD $T/hd.away; mkdir -p $K/hmgapi $U/HMGAPI/install/payload; echo "# hmg-api" > $K/hmgapi/troubleShooter
ts $U
check "  HMG-API가 없고 스틱에 HMG-API 설치기가 있어도 그것으로 넘기기 전에 멈춤(HMG-API를 설치하지 않음)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qxF "$KPMSG" $T/ts.out && ! grep -q "HMG-API 설치기로 넘김" $T/ts.out && ! grep -q "HMG-API를 먼저 설치합니다" $T/ts.out' || cat $T/ts.out
rm -rf $K/hmgapi $U/HMGAPI; mv $T/hd.away $HD
# 다른 NEMESIS 패키지만 있으면(예전 안에서 함께 막으려던 wireless.projection 포함) 그대로 설치한다
rm -rf $KPD; mkdir -p $R/data/nemesis/apps/wireless.projection $R/data/nemesis/apps/other.package
modset $HD/mods/nx4-kor/mod.json version=1.9.9; pset plan-new
ts $U
check "  다른 NEMESIS 패키지(wireless.projection 등)만 있으면 막지 않고 그대로 설치(업데이트)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^hmgapid engine install .*/nx4-kor.zip$" $T/calls && grep -qx "hmgapid engine apply" $T/calls && [ "$(pg state)" = reboot ] && ! grep -q "Korea Projection" $T/ts.out' || { cat $T/ts.out; cat $T/calls; }
# 지우기(UNINSTALL)는 막지 않는다. 지운 뒤 다음 테스트를 위해 같은 판의 nx4-kor를 다시 둔다
mkdir -p $KPD; : > $K/UNINSTALL; rm -f $T/stublog
ts $U
check "  지우기(UNINSTALL)는 Korea Projection 패키지가 있어도 막지 않음" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && grep -q "NX4 KOR 모드를 지웠습니다" $T/ts.out && ! grep -qF "$KPMSG" $T/ts.out' || cat $T/ts.out
rm -f $K/UNINSTALL; rm -rf $R/data/nemesis; cp -R $F $HD/mods/nx4-kor; : > $T/app-ready; echo yes > $T/diag.reply
# NEMESIS가 깔린 차(#75): 실행 파일 /system/xbin/nemesis가 있으면 설치·업데이트(같은 판 포함)를 아무것도 바꾸기 전에 멈춘다.
# Korea Projection 확인과 같은 자리라 HMG-API 기다리기·HMG-API 설치기로 넘기기보다 앞이다. 지우기 갈래는 막지 않는다
NMB=$R/system/xbin/nemesis
NMMSG="NX4 KOR: $NMS_TEXT"
mkdir -p $R/system/xbin; printf '#!/system/bin/sh\necho 1.17\n' > $NMB; chmod 755 $NMB
echo no > $T/diag.reply; pset plan-new; cp $HD/mods/nx4-kor/mod.json $T/nm-nx4.json
ts $U
check "USB 설치기(#75): NEMESIS(/system/xbin/nemesis)가 있으면 같은 판이어도 아무것도 바꾸지 않고 멈춤(종료 1, 안내 문구, 진단 기록은 멈추기 전에 물음, HMG-API 명령 없음, 관리 앱을 열지 않음, 진행 기록 없음)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qxF "$NMMSG" $T/ts.out && grep -q DiagActivity $T/calls && ! grep -q "^hmgapid" $T/calls && ! grep -q StatusActivity $T/calls && [ ! -f $PG ] && [ ! -d $R/data/local/tmp/nx4-kor-usb ] && cmp -s $T/nm-nx4.json $HD/mods/nx4-kor/mod.json && grep -q "system/xbin/nemesis 있음: 설치하지 않음" $K/install.log' || { cat $T/ts.out; cat $T/calls; }
# PR #76 리뷰 6: NEMESIS와 Korea Projection 폴더가 함께 있으면 NEMESIS 확인이 먼저 멈춘다(두 확인의 차례)
mkdir -p $KPD
ts $U
rm -rf $R/data/nemesis
check "  NEMESIS와 Korea Projection 폴더가 함께 있으면 NEMESIS 문구로 멈춤(Korea Projection 확인보다 앞)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qxF "$NMMSG" $T/ts.out && ! grep -qF "$KPMSG" $T/ts.out && ! grep -q "원본 Korea Projection 패키지가 있음" $K/install.log' || cat $T/ts.out
: > $K/REINSTALL
ts $U
rm -f $K/REINSTALL
check "  같은 판 다시 설치(REINSTALL)도 멈춤" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qxF "$NMMSG" $T/ts.out && ! grep -q "^hmgapid" $T/calls && cmp -s $T/nm-nx4.json $HD/mods/nx4-kor/mod.json' || cat $T/ts.out
modset $HD/mods/nx4-kor/mod.json version=1.9.9; cp $HD/mods/nx4-kor/mod.json $T/nm-nx4.json
ts $U
check "  업데이트(설치된 판이 다름)도 멈춤(HMG-API 명령 없음, 설치된 nx4-kor 그대로)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qxF "$NMMSG" $T/ts.out && ! grep -q "^hmgapid" $T/calls && cmp -s $T/nm-nx4.json $HD/mods/nx4-kor/mod.json && [ ! -f $PG ]' || { cat $T/ts.out; cat $T/calls; }
mv $HD $T/hd.away; mkdir -p $K/hmgapi $U/HMGAPI/install/payload; echo "# hmg-api" > $K/hmgapi/troubleShooter
ts $U
check "  새 설치(HMG-API 없음)는 스틱에 HMG-API 설치기가 있어도 그것으로 넘기기 전에 멈춤(HMG-API를 설치하지 않음)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qxF "$NMMSG" $T/ts.out && ! grep -q "HMG-API 설치기로 넘김" $T/ts.out && ! grep -q "HMG-API를 먼저 설치합니다" $T/ts.out' || cat $T/ts.out
rm -rf $K/hmgapi $U/HMGAPI; mv $T/hd.away $HD
# 지우기(UNINSTALL)는 막지 않는다
: > $K/UNINSTALL; rm -f $T/stublog
ts $U
check "  지우기(UNINSTALL)는 NEMESIS가 있어도 막지 않음" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && grep -q "NX4 KOR 모드를 지웠습니다" $T/ts.out && ! grep -qF "$NMMSG" $T/ts.out' || cat $T/ts.out
rm -f $K/UNINSTALL $NMB; cp -R $F $HD/mods/nx4-kor; : > $T/app-ready; echo yes > $T/diag.reply
# map: HMG-API가 이 차 map을 이미 가짐 / 만들지 못함 / 확인 실패(이번에 만든 map만 지움)
pset plan-new; mapnew; echo "not written: HMG-API has a map for this car (nx4hev_kr): \`hmgapid engine map-car --local\` adds the points it lacks" > $T/mapcar.out; rm -f $T/mapcar.writes
ts $U
check "USB 설치기 map: HMG-API에 이 차 map이 있으면(not written) 그 map을 확인만 하고 적용" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -qx "hmgapid engine map-car --write" $T/calls && grep -qx "hmgapid engine verify-map" $T/calls && ! grep -q "forget" $T/calls && grep -qx "hmgapid engine apply" $T/calls && [ "$(pg state)" = reboot ]'
# HMG-API가 나중에 NX4 map을 담으면 --write는 "not written"(종료 0)이고 verify-map은 그 map을 본다: 확인에 실패해도 그 map은 지우지 않는다
mapnew; echo "not written: HMG-API has a map for this car (nx4hev_kr): \`hmgapid engine map-car --local\` adds the points it lacks" > $T/mapcar.out; rm -f $T/mapcar.writes; echo 1 > $T/verify.rc
ts $U
check "USB 설치기 map: HMG-API의 map(not written)이 확인에 실패해도 지우지 않음(map-car --forget 없음), 적용하지 않음" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qx "hmgapid engine verify-map" $T/calls && ! grep -q "forget" $T/calls && ! grep -q "engine apply" $T/calls && [ "$(pg state)" = fail ] && pg stage | grep -q "map을 확인하지 못해"'
mapnew; echo "not written: this unit's product (X) doesn't say its model, region and firmware" > $T/mapcar.out; rm -f $T/mapcar.writes; echo 5 > $T/mapcar.rc
ts $U
check "USB 설치기 map: map을 만들지 못하면 확인·적용하지 않고 실패(state=fail, map을 만들지 못해)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && ! grep -q "verify-map" $T/calls && ! grep -q "engine apply" $T/calls && [ "$(pg state)" = fail ] && pg stage | grep -q "map을 만들지 못해"'
mapnew; echo 1 > $T/verify.rc
ts $U
check "USB 설치기 map: 이번에 만든 map이 확인에 실패하면 그 map을 지우고(map-car --forget) 적용하지 않음" \
  '[ "$(cat $T/ts.rc)" = 1 ] && [ $(at "verify-map") -lt $(at "map-car --forget") ] && [ ! -f $HD/state/local-map.json ] && ! grep -q "engine apply" $T/calls && [ "$(pg state)" = fail ] && pg stage | grep -q "map을 확인하지 못해"'
mapnew; mkdir -p $HD/state; echo '{"whole": true}' > $HD/state/local-map.json; echo 1 > $T/verify.rc
ts $U
check "USB 설치기 map: 이미 있던 map은 확인에 실패해도 지우지 않음(만들지도 않음)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && ! grep -q "map-car" $T/calls && [ -f $HD/state/local-map.json ] && ! grep -q "engine apply" $T/calls && [ "$(pg state)" = fail ]'
rm -f $T/verify.rc
# 설치가 거절되면: nx4-kor 업데이트는 예전 판의 서비스를 다시 띄우고 실패, 공식 무선 모드가 거절되면 nx4-kor는 건드리지 않음
pset plan-new
modset $HD/mods/nx4-kor/mod.json version=1.9.9
: > $T/install-fail-nx4-kor; : > $T/ap-running
ts $U
check "USB 설치기: nx4-kor 업데이트 설치가 거절되면 실패(state=fail)로 끝내고 예전 판의 돌던 서비스를 다시 띄움" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "NX4 KOR 설치에 실패했습니다" $T/ts.out && grep -qx "hmgapid service-start nx4-kor ap" $T/calls && ! grep -q "engine apply" $T/calls && [ "$(pg state)" = fail ]'
rm -f $T/install-fail-nx4-kor $T/ap-running
wmod 2.2.0-rc.5; : > $T/install-fail-wireless-carplay-aa
ts $U
check "USB 설치기: 공식 무선 모드 설치가 거절되면 nx4-kor를 설치하지 않고 실패(state=fail)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "공식 무선 모드(wireless-carplay-aa)를 설치하지 못했습니다" $T/ts.out && ! grep -q "nx4-kor.zip" $T/calls && [ "$(pg state)" = fail ]'
rm -f $T/install-fail-wireless-carplay-aa; wmod $WV
# 옛 NX4 KOR 2.0.x(공식 무선 모드와 충돌 선언): 이 설치기가 먼저 HMG-API에서 빼고 계획(rc.8 설명 줄 포함)을 읽어 적용한 뒤,
# 옛 판의 uninstall.sh를 사본으로 돌려 직접 바꾼 것을 되돌리고, 그다음 새로 설치한다
oldmod 2.0.4-beta.1; mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog
printf 'restore  /system/lib/libleafiaaac.so (stock)\nrestore  /system/etc/permissions/com.hkmc.software.wifihotspot.xml (stock)\nsetting  prop/persist.ium.support back to stock\n' > $T/plan-oldgone; cat $T/plan-same >> $T/plan-oldgone
pset plan-same plan-oldgone plan-new; mapnew
ts $U
check "USB 설치기: 옛 2.0.x가 있으면 engine remove nx4-kor → 계획(되돌리기·rc.8 설명 줄) → apply → 옛 판 자신의 uninstall.sh(사본, 지우기) → 공식 무선 모드 → 새 nx4-kor" \
  '[ "$(cat $T/ts.rc)" = 0 ] && [ $(at "engine remove nx4-kor") -lt $(at "engine apply") ] && [ $(at "engine apply") -lt $(at "wireless-carplay-aa.zip") ] && grep -q "^old-uninstall NX4_APP=$R/data/local/tmp/nx4-kor-usb/old *$" $T/stublog && [ ! -d $R/data/nx4-kor ] && grep -q "옛 NX4 KOR(2.0.4-beta.1)를 먼저 되돌리는 중" $T/ts.out && [ "$(grep -c "^hmgapid engine apply$" $T/calls)" = 2 ] && grep -q "^hmgapid engine install .*/nx4-kor.zip$" $T/calls && ! old_conf && [ "$(pg state)" = reboot ] && [ ! -d $R/data/local/tmp/nx4-kor-usb ]' || { cat $T/ts.out; cat $T/calls; cat $T/stublog; }
oldmod 2.0.4-beta.1; mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog
printf 'update   /system/onebin/nx4hev_kr/featurexml.cfg [other-mod] -> cdef   [restart the head unit]\n' > $T/plan-oldother; cat $T/plan-oldgone >> $T/plan-oldother
pset plan-same plan-oldother
ts $U
check "USB 설치기: 옛 2.0.x를 뺀 계획에 다른 모드의 변경이 있으면 적용하지 않고 멈춤(새로 설치하지 않음, state=fail)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qx "hmgapid engine remove nx4-kor" $T/calls && ! grep -q "engine apply" $T/calls && ! grep -q "engine install" $T/calls && [ ! -f $T/stublog ] && [ "$(pg state)" = fail ] && pg stage | grep -q "다른 모드의 바뀐 내용"'
# 옛 2.0.x를 뺀 뒤의 계획이 종료 1(끝나지 않은 적용 등)이면 "다른 모드" 문구가 아니라 계획을 내지 못했다고 알린다(PR #52 리뷰 3)
oldmod 2.0.4-beta.1; mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog
pset plan-same plan-notdone; echo 1 > $T/plan.rc.2
ts $U
check "USB 설치기: 옛 2.0.x를 뺀 뒤 계획을 내지 못하면(종료 1) 적용·설치 없이 PLANFAIL_MSG로 끝남, 종료 코드를 기록" \
  '[ "$(cat $T/ts.rc)" = 1 ] && ! grep -q "engine apply" $T/calls && ! grep -q "engine install" $T/calls && [ "$(pg state)" = fail ] && pg stage | grep -q "계획을 내지 못했습니다" && grep -q "^--- engine plan (remove, 종료 코드 1)" $K/install.log' || { cat $T/ts.out; cat $PG; }
# 한국 차 빌드와 옛 2.0.x가 함께 있으면 한국 차 빌드를 먼저 지운다(옛 판 정리의 적용에 그 모드의 적용하지 않은 변경이 섞이지 않게)
oldmod 2.0.4-beta.1; wmod 2.4.5 "Korea Projection: Wireless CarPlay + Android Auto"; mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog
pset plan-same plan-oldgone plan-new; mapnew
ts $U
check "USB 설치기: Korea Projection 한국 차 빌드와 옛 2.0.x가 함께 있으면 한국 차 빌드를 먼저 지우고 → 옛 판 되돌리기 → 공식판 설치" \
  '[ "$(cat $T/ts.rc)" = 0 ] && [ $(at "engine remove wireless-carplay-aa") -lt $(at "engine remove nx4-kor") ] && [ $(at "engine remove nx4-kor") -lt $(at "wireless-carplay-aa.zip --any-car") ] && grep -q "\"version\": \"$WV\"" $HD/mods/wireless-carplay-aa/mod.json && grep -q "^old-uninstall NX4_APP=$R/data/local/tmp/nx4-kor-usb/old *$" $T/stublog && [ "$(pg state)" = reboot ]' || { cat $T/ts.out; cat $T/calls; }
# nx4-kor는 없고 2.0.x의 기록(/data/nx4-kor/backup)만 남은 차(HMG-API 앱에서 지움): 2.1.0 사본은 그것을 되돌리지 못하고 지우기만 한다.
# 스틱에 legacy-2.0이 없으면 아무것도 바꾸지 않고 2.0.x USB로 안내한다(기록은 그대로 남아 2.0.x USB의 UNINSTALL이 되돌릴 수 있다)
rm -rf $HD/mods/nx4-kor $R/data/nx4-kor; mkdir -p $R/data/nx4-kor/backup; echo 0 > $R/data/nx4-kor/backup/wifi_on; rm -f $T/stublog
pset plan-new; mapnew; legoff
ts $U
check "USB 설치기: nx4-kor 없이 2.0.x 기록(backup)만 남았고 스틱에 legacy-2.0이 없으면 아무것도 바꾸지 않고 멈춤(기록 그대로, 2.0.x USB로 안내, 진행 기록 없음)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "2.0.x 릴리스 USB(v2.0.4-beta.1)의 NX4/UNINSTALL" $T/ts.out && ! engcalls && [ -f $R/data/nx4-kor/backup/wifi_on ] && [ ! -f $T/stublog ] && [ ! -f $PG ]' || { cat $T/ts.out; cat $T/calls; }
legon
# 스틱의 legacy-2.0(그 판의 되돌리기)으로 되돌린다: payload의 busybox를 넣은 사본으로, 앱 삭제가 남긴 되돌리기 줄도 적용한 뒤 설치
cp $T/bin/bb $K/install/payload/bin/busybox; rm -f $T/stublog
pset plan-same plan-oldgone plan-new; mapnew
ts $U
check "USB 설치기: nx4-kor 없이 2.0.x 기록만 남았으면 스틱의 legacy-2.0(사본, payload busybox 포함)으로 되돌리고(남은 되돌리기 줄 적용) 새로 설치" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^legacy-uninstall NX4_APP=$R/data/local/tmp/nx4-kor-usb/old bb=yes *$" $T/stublog && [ ! -d $R/data/nx4-kor ] && ! grep -q "engine remove nx4-kor" $T/calls && [ $(at "engine apply") -lt $(at "nx4-kor.zip") ] && [ "$(grep -c "^hmgapid engine apply$" $T/calls)" = 2 ] && grep -q "2.0.x가 남긴 설정(Wi-Fi 잠금 등)을 되돌리는 중" $T/ts.out && [ -f $HD/mods/nx4-kor/mod.json ] && [ "$(pg state)" = reboot ]' || { cat $T/ts.out; cat $T/calls; cat $T/stublog; }
rm -f $K/install/payload/bin/busybox
# 2.0.x 위에 adb·HMG-API 앱으로 2.1.0 이후가 들어간 차(설치된 nx4-kor는 같은 판 2.1.0, 2.0.x 기록 backup이 남음): 2.1.0을 HMG-API에서 빼고
# 적용한 뒤 legacy-2.0으로 되돌리고 nx4-kor를 다시 설치한다. 관리 앱은 다시 설치한 뒤에 연다(PR #52 리뷰 7)
mkdir -p $R/data/nx4-kor/backup; echo 0 > $R/data/nx4-kor/backup/wifi_on; rm -f $T/stublog
pset plan-same plan-oldgone plan-new; mapnew
ts $U
check "USB 설치기: 2.1.0이 설치됐는데 2.0.x 기록(backup)이 남았으면 2.1.0을 빼고(engine remove) 적용 → legacy-2.0으로 되돌림 → nx4-kor 다시 설치 → 관리 앱" \
  '[ "$(cat $T/ts.rc)" = 0 ] && [ $(at "engine remove nx4-kor") -lt $(at "engine apply") ] && [ $(at "engine apply") -lt $(at "nx4-kor.zip") ] && [ $(at "nx4-kor.zip") -lt $(at "StatusActivity") ] && grep -q "^legacy-uninstall NX4_APP=$R/data/local/tmp/nx4-kor-usb/old " $T/stublog && [ ! -d $R/data/nx4-kor ] && [ -f $HD/mods/nx4-kor/mod.json ] && [ "$(pg state)" = reboot ]' || { cat $T/ts.out; cat $T/calls; cat $T/stublog; }
mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog; legoff
ts $U
check "  같은 차인데 스틱에 legacy-2.0이 없으면 아무것도 바꾸지 않고 멈춤(2.0.x USB로 안내, 기록 그대로)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "2.0.x 릴리스 USB(v2.0.4-beta.1)의 NX4/UNINSTALL" $T/ts.out && ! engcalls && [ -d $R/data/nx4-kor/backup ] && [ ! -f $PG ]'
legon; rm -rf $R/data/nx4-kor
# 2.1.0 이후의 기록만 남은 차: 스틱의 사본으로 정리한 뒤 설치
rm -rf $HD/mods/nx4-kor $R/data/nx4-kor; mkdir -p $R/data/nx4-kor/logs; rm -f $T/stublog
pset plan-new; mapnew
ts $U
check "USB 설치기: nx4-kor 없이 2.1.0 이후의 기록만 남았으면 스틱의 사본(uninstall.sh)으로 정리한 뒤 설치" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$R/data/local/tmp/nx4-kor-usb/payload " $T/stublog && [ ! -d $R/data/nx4-kor ] && grep -q "^hmgapid engine install .*/nx4-kor.zip$" $T/calls && [ "$(pg state)" = reboot ]' || cat $T/ts.out
# 지우기: nx4-kor만(공식 무선 모드·map은 남김). UNINSTALL-ALL이면 공식 무선 모드도
pset plan-krfork
: > $K/UNINSTALL; : > $T/ap-running; rm -f $T/stublog; mkdir -p $R/data/nx4-kor/logs
ts $U
check "USB 설치기: UNINSTALL이면 설치된 모드의 uninstall.sh로 되돌리고 모드를 지움, 공식 무선 모드·map은 남김" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$HD/mods/nx4-kor " $T/stublog && grep -qx "hmgapid engine remove nx4-kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && ! grep -q "engine remove wireless-carplay-aa" $T/calls && [ -f $HD/mods/wireless-carplay-aa/mod.json ] && [ -f $HD/state/local-map.json ] && grep -q "NX4 KOR 모드를 지웠습니다" $T/ts.out'
ts $U
check "USB 설치기: 지울 것이 없으면 아무것도 하지 않음" '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "설치되어 있지 않습니다" $T/ts.out && ! grep -q "engine remove" $T/calls'
# 2.0.x 위에 adb·HMG-API 앱으로 2.1.0이 들어간 차: 2.1.0의 uninstall.sh는 2.0.x의 기록(backup)을 되돌리지 못해 그 폴더만 남긴다(PR #50 리뷰 2).
# UNINSTALL은 스틱의 legacy-2.0으로 마저 되돌린다. 그 uninstall.sh를 흉내: 모드 폴더와 backup 밖의 기록만 지움
cp -R $F $HD/mods/nx4-kor; modset $HD/mods/nx4-kor/mod.json conflicts=-
printf '#!/bin/sh\necho "new-uninstall NX4_APP=$NX4_APP $*" >> %s/stublog\nrm -rf $HMGDATA/mods/nx4-kor\nfor f in $NX4_ROOT/*; do [ "$f" = "$NX4_ROOT/backup" ] || rm -rf "$f"; done\nexit 0\n' $T > $HD/mods/nx4-kor/bin/uninstall.sh
mkdir -p $R/data/nx4-kor/backup $R/data/nx4-kor/logs; rm -f $T/stublog; pset plan-oldgone
ts $U
check "USB 설치기: UNINSTALL에서 2.1.0의 uninstall.sh가 2.0.x 기록(backup)을 남기면 스틱의 legacy-2.0으로 마저 되돌림(되돌리기 줄 적용)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && [ "$(grep -n "^new-uninstall" $T/stublog | cut -d: -f1)" -lt "$(grep -n "^legacy-uninstall NX4_APP=$R/data/local/tmp/nx4-kor-usb/old " $T/stublog | cut -d: -f1)" ] && grep -qx "hmgapid engine apply" $T/calls && [ ! -d $R/data/nx4-kor ] && [ ! -d $HD/mods/nx4-kor ] && grep -q "지웠습니다" $T/ts.out && ! grep -q "되돌리지 못해 남겼습니다" $T/ts.out' || { cat $T/ts.out; cat $T/stublog; }
# 같은 차인데 스틱에 legacy-2.0이 없으면: nx4-kor는 지우고 2.0.x 기록은 남겼다고 화면(토스트)에도 알린다(#50 리뷰 9)
cp -R $F $HD/mods/nx4-kor; modset $HD/mods/nx4-kor/mod.json conflicts=-
printf '#!/bin/sh\necho "new-uninstall NX4_APP=$NX4_APP $*" >> %s/stublog\nrm -rf $HMGDATA/mods/nx4-kor\nfor f in $NX4_ROOT/*; do [ "$f" = "$NX4_ROOT/backup" ] || rm -rf "$f"; done\nexit 0\n' $T > $HD/mods/nx4-kor/bin/uninstall.sh
mkdir -p $R/data/nx4-kor/backup $R/data/nx4-kor/logs; rm -f $T/stublog; legoff
ts $U
check "  같은 차인데 스틱에 legacy-2.0이 없으면 nx4-kor는 지우고, 남긴 2.0.x 기록(backup)을 토스트로 알림(2.0.x USB로 안내)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^new-uninstall" $T/stublog && ! grep -q "^legacy-uninstall" $T/stublog && [ -d $R/data/nx4-kor/backup ] && grep -q "NX4 KOR 모드를 지웠습니다. 재부팅합니다. 옛 NX4 KOR 2.0.x의 기록(/data/nx4-kor/backup)은 이 USB로 되돌리지 못해 남겼습니다" $T/ts.out' || { cat $T/ts.out; cat $T/stublog; }
legon; rm -rf $R/data/nx4-kor
# 모드는 HMG-API 앱에서 먼저 지웠고 기록만 남은 경우: 2.0.x 기록이면 멈춤, 2.1.0 이후의 기록이면 스틱의 사본(/data로 복사)으로 정리
mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog; legoff
ts $U
check "USB 설치기: UNINSTALL인데 모드 폴더 없이 2.0.x 기록(backup)만 남았고 스틱에 legacy-2.0이 없으면 지우지 않고 멈춤(2.0.x USB로 안내)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "2.0.x 릴리스 USB(v2.0.4-beta.1)의 NX4/UNINSTALL" $T/ts.out && [ -d $R/data/nx4-kor/backup ] && [ ! -f $T/stublog ] && ! grep -q "engine remove" $T/calls'
legon; pset plan-oldgone
ts $U
check "USB 설치기: UNINSTALL인데 모드 폴더 없이 2.0.x 기록만 남았으면 스틱의 legacy-2.0(사본)으로 되돌림(남은 되돌리기 줄은 적용, 모드 지우기는 부르지 않음)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^legacy-uninstall NX4_APP=$R/data/local/tmp/nx4-kor-usb/old " $T/stublog && grep -qx "hmgapid engine apply" $T/calls && ! grep -q "engine remove" $T/calls && [ ! -d $R/data/nx4-kor ] && grep -q "지웠습니다" $T/ts.out' || { cat $T/ts.out; cat $T/calls; }
rm -rf $R/data/nx4-kor; mkdir -p $R/data/nx4-kor/logs; rm -f $T/stublog
ts $U
check "USB 설치기: 모드가 이미 지워졌어도 2.1.0 이후의 기록이 남았으면 스틱의 사본으로 정리" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$R/data/local/tmp/nx4-kor-usb/payload " $T/stublog && [ ! -d $R/data/nx4-kor ] && [ ! -d $R/data/local/tmp/nx4-kor-usb ]'
# 옛 2.0.x를 지울 때도 설치기가 먼저 빼고 되돌리기만 적용한 뒤 옛 판의 uninstall.sh(사본)를 돌린다
oldmod 2.0.4-beta.1; mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog
pset plan-oldgone
ts $U
check "USB 설치기: UNINSTALL에 옛 2.0.x면 engine remove → 계획(되돌리기뿐) → apply → 옛 판 uninstall.sh(사본), 공식 무선 모드는 남김" \
  '[ "$(cat $T/ts.rc)" = 0 ] && [ $(at "engine remove nx4-kor") -lt $(at "engine apply") ] && grep -q "^old-uninstall NX4_APP=$R/data/local/tmp/nx4-kor-usb/old *$" $T/stublog && [ ! -d $HD/mods/nx4-kor ] && [ ! -d $R/data/nx4-kor ] && ! grep -q "engine remove wireless-carplay-aa" $T/calls && grep -q "지웠습니다" $T/ts.out' || { cat $T/ts.out; cat $T/calls; }
rm -f $K/UNINSTALL
cp -R $F $HD/mods/nx4-kor; modset $HD/mods/nx4-kor/mod.json conflicts=-; mkdir -p $R/data/nx4-kor/logs; rm -f $T/stublog
: > $K/UNINSTALL-ALL; pset plan-krfork
ts $U
check "USB 설치기: UNINSTALL-ALL이면 nx4-kor를 지운 뒤 공식 무선 모드도 지우고(engine remove) 되돌리기를 적용, map은 남김" \
  '[ "$(cat $T/ts.rc)" = 0 ] && [ $(at "engine remove nx4-kor") -lt $(at "engine remove wireless-carplay-aa") ] && [ $(at "engine remove wireless-carplay-aa") -lt $(at "engine apply") ] && [ ! -d $HD/mods/wireless-carplay-aa ] && [ -f $HD/state/local-map.json ] && grep -q "NX4 KOR와 공식 무선 모드를 지웠습니다" $T/ts.out' || { cat $T/ts.out; cat $T/calls; }
wmod $WV; pset plan-krfork
ts $U
check "USB 설치기: UNINSTALL-ALL에 공식 무선 모드만 남았으면 그것만 지우고 적용, 결과 문구도 공식 무선 모드만(PR #52 리뷰 6)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -qx "hmgapid engine remove wireless-carplay-aa" $T/calls && grep -qx "hmgapid engine apply" $T/calls && grep -q "공식 무선 모드를 지웠습니다(NX4 KOR는 없었습니다)" $T/ts.out && ! grep -q "NX4 KOR와 공식 무선 모드를" $T/ts.out'
wmod $WV; pset plan-other
ts $U
check "USB 설치기: UNINSTALL-ALL에 공식 무선 모드만 남았으면 그것만 지우고, 계획에 다른 변경이 있으면 적용하지 않고 실패로 알림" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -qx "hmgapid engine remove wireless-carplay-aa" $T/calls && ! grep -q "engine apply" $T/calls && grep -q "변경 사항을 적용해 주세요(무선 모드 삭제)" $T/ts.out'
rm -f $K/UNINSTALL-ALL
# HMG-API를 먼저 지운 뒤(hmgapid 없음): 일반 삭제는 모드 폴더를 남긴다 → 그 폴더의 uninstall.sh로, purge는 /data/hmgapi째 없다 → 스틱 사본으로
: > $K/UNINSTALL
ts0() { : > $T/calls; rm -f $K/install.log; (env -u NX4_APP PATH=$P0 ROOT=$R HMGAPID=$T/nohmgapid NX4_USB_DIRS=$U NX4_APP_WAIT=4 BOOT_ID=$T/bootid UPTIME=$T/uptime sh $B/usb/troubleShooter) > $T/ts.out 2>&1; echo $? > $T/ts.rc; }
mkdir -p $HD/mods $R/data/nx4-kor/logs; cp -R $F $HD/mods/nx4-kor; rm -f $HD/installed.txt $T/stublog
ts0
check "USB 설치기: HMG-API를 먼저 지운 뒤(일반 삭제)에도 UNINSTALL이 됨: 남은 모드 폴더의 uninstall.sh로 되돌리고 모드 폴더·앱을 지움" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$HD/mods/nx4-kor " $T/stublog && grep -qx "pm uninstall io.github.jayparklab.nx4kor" $T/calls && [ ! -d $HD/mods/nx4-kor ] && [ ! -d $R/data/nx4-kor ] && grep -q "지웠습니다" $T/ts.out && grep -q "HMG-API가 없음" $K/install.log'
mv $HD $T/hd.purged; mkdir -p $R/data/nx4-kor/backup; rm -f $T/stublog; legoff
ts0
check "USB 설치기: HMG-API를 먼저 완전 삭제(--purge)했고 2.0.x 기록만 남았는데 스틱에 legacy-2.0이 없으면 지우지 않고 멈춤(2.0.x USB로 안내)" \
  '[ "$(cat $T/ts.rc)" = 1 ] && grep -q "2.0.x 릴리스 USB" $T/ts.out && [ -d $R/data/nx4-kor/backup ] && [ ! -f $T/stublog ]'
legon
ts0
check "USB 설치기: HMG-API를 먼저 완전 삭제(--purge)했고 2.0.x 기록만 남았으면 스틱의 legacy-2.0(사본)으로 바로 되돌림(HMG-API 명령 없음)" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^legacy-uninstall NX4_APP=$R/data/local/tmp/nx4-kor-usb/old " $T/stublog && [ ! -d $R/data/nx4-kor ] && ! grep -q "^hmgapid" $T/calls'
rm -rf $R/data/nx4-kor; mkdir -p $R/data/nx4-kor/logs
ts0
check "USB 설치기: HMG-API를 먼저 완전 삭제(--purge)한 뒤에도 2.1.0 이후의 기록이 남았으면 스틱의 사본으로 정리" \
  '[ "$(cat $T/ts.rc)" = 0 ] && grep -q "^scripts/preun.sh NX4_APP=$R/data/local/tmp/nx4-kor-usb/payload " $T/stublog && [ ! -d $R/data/nx4-kor ]'
mv $T/hd.purged $HD
rm -f $K/UNINSTALL $T/plan.out.* $T/plan.n

# --- 진짜 스크립트: preun.sh·status.sh(svc/lib.sh) ---
# 차의 PATH로 바꾸는 맨 윗줄만 시험용 PATH로 바꾼 사본으로 돌린다. 나머지는 그대로
TP=$T/pkg; rm -rf $TP; cp -R $PKG $TP
for f in svc/lib.sh scripts/preun.sh bin/status.sh; do
  sed "s#^export PATH=.*#export PATH=$P0#" $PKG/$f > $TP/$f
done
# preun.sh: 업데이트 갈래. 작업 폴더·관리 앱 파일만 지우고, 진행 기록(USB 설치기가 씀)·알림은 둔다
prun() { (env PATH=${PP:-$P0} BB_SYS=$T/bin/bb NX4_APP=$TP W=$T/uw HINT=$T/uhint PROG=$T/uprog NOTICE=$T/unotice RBRES=$T/urbres NOCHIP=$T/unochip HMGDATA=$T/uh BOOT_ID=$T/bootid "$@" sh $TP/scripts/preun.sh) > $T/pu.out 2>&1; echo $? > $T/pu.rc; }
pureset() {
  rm -rf $T/uw $T/uh; mkdir -p $T/uw $T/uh/mods/nx4-kor; : > $T/uw/watch.until
  for f in uhint uprog unotice urbres unochip; do echo x > $T/$f; done
  echo '{"id": "nx4-kor"}' > $T/uh/mods/nx4-kor/mod.json; : > $T/uh/installed.txt; : > $T/calls
}
pureset; prun NX4_UPDATE=1
check "preun.sh: NX4_UPDATE=1이면 작업 폴더·상태 안내를 지우고 끝남, 진행 기록(설치기가 씀)·알림은 둠, HMG-API를 부르지 않음" \
  '[ "$(cat $T/pu.rc)" = 0 ] && grep -q "NX4 KOR 업데이트: 이전 판 정리" $T/pu.out && [ ! -d $T/uw ] && [ ! -f $T/uhint ] && [ -f $T/uprog ] && [ -f $T/unotice ] && [ -f $T/unochip ] && ! grep -q "^hmgapid" $T/calls' || cat $T/pu.out
# preun.sh: 관리 앱이 띄운 감시자(status.sh --watch)를 멈춘다. 명령줄은 가짜 /proc의 cmdline(NUL로 나눔)으로 본다
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
  '[ "$(cat $T/pu.rc)" = 0 ] && grep -qx "hmgapid engine remove nx4-kor" $T/calls && ! grep -q "engine plan" $T/calls && ! grep -q "engine apply" $T/calls && [ ! -f $T/uprog ] && [ ! -f $T/unotice ] && [ ! -f $T/urbres ] && [ ! -f $T/unochip ] && grep -q "HMG-API에서 이 모드를 지움" $T/pu.out && grep -qx "NX4 KOR를 지웠습니다." $T/pu.out' || cat $T/pu.out
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
     HMGINST=$T/sinst HMGLOG=$T/shlog HOOKSTARTS=$T/shook/starts NX4_DMESG=$T/sdmesg NOCHIP=$T/snochip USBDEV=$T/susb RPT_SYNC=1 "$@" sh $TP/bin/status.sh) > $T/st.out 2>&1
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
# 준비된 차: HMG-API rc.10(훅 켜짐, map 확인됨), 공식 모드 2.2.0-rc.9가 켜지고 훅이 켜짐, 무선 기능·순정 핫스팟 기능 켜짐,
# 프로젝션 AP 요청이 있고 이번 부팅에 떠서 netd(99)가 띄운 hostapd(1234)가 카플레이 SSID(S2)로 돎, Wi-Fi 칩을 본 기록
streset() {
  rm -rf $SH $T/sw $T/sproc $T/sysnet $T/procnet $T/shlog $T/sprog $T/status.txt $T/ps.out $T/wifiseen $T/shook $T/snochip $T/susb
  mkdir -p $SH/mods/wireless-carplay-aa $SH/state $SH/wifi $SH/settings $T/sw $T/sproc/1234 $T/sproc/99 $T/sysnet/wlan0 $T/procnet $T/shlog $T/shook
  printf '{\n  "id": "wireless-carplay-aa",\n  "version": "2.2.0-rc.9"\n}\n' > $SH/mods/wireless-carplay-aa/mod.json
  printf 'version 1.1.0-rc.10\nbuild x\n' > $T/sinst
  printf '%s\n' feature:com.hkmc.software.connectivity.carplay_wireless feature:com.hkmc.software.connectivity.androidauto_wireless \
    feature:com.hkmc.software.wifihotspot > $T/features
  printf '%s\n' "11-23 06:00:01.000 I/HMG-API: hook map: verified for hyundai/nx4/kor/260902, hooks on" \
    "11-23 06:00:02.000 I/HMG-API: mods: wireless-carplay-aa: this mod is for other cars; overrides.ignore_system is set, loading it at the owner's risk" \
    "11-23 06:00:02.000 I/HMG-API: mods: loaded wireless-carplay-aa 2.2.0-rc.9" \
    "11-23 06:00:02.000 I/HMG-API: mods: loaded nx4-kor $V" > $T/shlog/log.log
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
# #71: 이 모드의 한국 카플레이 길안내(훅·설정). 판정은 바꾸지 않는다
streset; stsh
check "status.sh(#71): 이 모드의 훅이 켜졌으면 kor_hooks=on, 설정 파일이 없으면 kor_tbt=on·kor_tbt_log=off(기본), 판정 그대로" \
  '[ "$(sv kor_hooks)" = on ] && [ -z "$(sv kor_hooks_why)" ] && [ "$(sv kor_tbt)" = on ] && [ "$(sv kor_tbt_log)" = off ] && [ "$(sv verdict)" = ready ]' || cat $T/status.txt
check "  설정 파일이 없을 때의 값이 mod/settings.json의 기본과 같음(기본을 바꾸면 status.sh도, PR #83 리뷰 6)" \
  'python3 -c "import json,sys; d={x[\"key\"]: x[\"default\"] for x in json.load(open(sys.argv[1]))[\"settings\"]}; v=dict(l.rstrip(\"\\n\").split(\"=\",1) for l in open(sys.argv[2]) if \"=\" in l); assert v[\"kor_tbt\"]==(\"on\" if d[\"kor_tbt\"] else \"off\") and v[\"kor_tbt_log\"]==(\"on\" if d[\"kor_tbt_log\"] else \"off\"), (d, v[\"kor_tbt\"], v[\"kor_tbt_log\"])" $PKG/settings.json $T/status.txt'
streset; printf '{"kor_tbt": false, "kor_tbt_log": true}\n' > $SH/settings/nx4-kor.json; stsh
check "  HMG-API에 저장된 설정을 읽음(kor_tbt 끔 → off, kor_tbt_log 켬 → on)" '[ "$(sv kor_tbt)" = off ] && [ "$(sv kor_tbt_log)" = on ] && [ "$(sv verdict)" = ready ]' || cat $T/status.txt
streset; printf '{"kor_tbt_log": false, "kor_tbt": true}\n' > $SH/settings/nx4-kor.json; stsh
check "  kor_tbt 켬·kor_tbt_log 끔 저장(키 차례가 달라도) → on·off" '[ "$(sv kor_tbt)" = on ] && [ "$(sv kor_tbt_log)" = off ]' || cat $T/status.txt
streset; printf '%s\n' "x I/HMG-API: hook map: verified for hyundai/nx4/kor/260902, hooks on" "x I/HMG-API: mods: loaded wireless-carplay-aa 2.2.0-rc.9" \
  "x I/HMG-API: mods: nx4-kor not loaded: hook point framework.navigation_cluster.update_lane_info isn't mapped on this car (none): its hooks are off here, its other parts still apply" > $T/shlog/log.log; stsh
check "  이 모드의 훅이 안 켜졌으면 kor_hooks=off와 이유(HMG-API 영문 그대로), 공식 모드는 on, 판정 그대로" \
  '[ "$(sv kor_hooks)" = off ] && [ "$(sv kor_hooks_why)" = "hook point framework.navigation_cluster.update_lane_info isn'"'"'t mapped on this car (none): its hooks are off here, its other parts still apply" ] && [ "$(sv wm_hooks)" = on ] && [ "$(sv verdict)" = ready ]' || cat $T/status.txt
# PR #83 리뷰 3: 이번 부팅에 HMG-API 훅이 꺼졌으면("mods:" 줄 없음) 지난 부팅(log.log.1)의 "loaded"를 쓰지 않는다
streset; printf '%s\n' "x I/HMG-API: hook map: verified for hyundai/nx4/kor/260902, hooks on" "x I/HMG-API: mods: loaded wireless-carplay-aa 2.2.0-rc.9" "x I/HMG-API: mods: loaded nx4-kor $V" > $T/shlog/log.log.1
printf '%s\n' "x I/HMG-API: hook map: none for hyundai/nx4/kor/260902, hooks off" > $T/shlog/log.log; stsh
check "  이번 부팅에 HMG-API 훅이 꺼졌으면 지난 부팅의 loaded가 남지 않음(kor_hooks·wm_hooks 빈 값), 판정 hooksoff" \
  '[ -z "$(sv kor_hooks)" ] && [ -z "$(sv wm_hooks)" ] && [ "$(sv hooks)" = off ] && [ "$(sv verdict)" = hooksoff ]' || cat $T/status.txt
streset; printf '%s\n' "x I/HMG-API: hook map: verified for hyundai/nx4/kor/260902, hooks on" "x I/HMG-API: mods: loaded wireless-carplay-aa 2.2.0-rc.9" > $T/shlog/log.log; stsh
check "  이 모드의 줄이 없으면 kor_hooks 빈 값(관리 앱은 '-')" '[ -z "$(sv kor_hooks)" ] && grep -qx "kor_hooks=" $T/status.txt' || cat $T/status.txt
streset; stsh FAKE_PROD=DEPEHEV.KOR.0000.V039.001.260902
check "status.sh: NX4가 아니면 verdict=nocar, verdict_end=yes" '[ "$(sv verdict)" = nocar ] && [ "$(sv verdict_end)" = yes ] && [ "$(sv tested)" = no ]'
check "status.sh: 상태 파일과 한 줄 요약에 NEMESIS·Korea Projection·제보 문구 없음" '! grep -qE "NEMESIS|Korea Projection|제보|QR" $T/status.txt $T/st.out'
streset; rm -f $T/sinst; stsh
check "status.sh: HMG-API가 없으면 verdict=nohmgapi(1.1.0-rc.10 이상을 먼저)" '[ "$(sv verdict)" = nohmgapi ] && grep -q "1.1.0-rc.10 이상" $T/status.txt'
streset; printf 'version 1.1.0-rc.7\n' > $T/sinst; stsh
check "status.sh: HMG-API 1.1.0-rc.7(2.0.x가 받던 판)은 rc 꼬리까지 비교해 verdict=oldhmgapi" '[ "$(sv verdict)" = oldhmgapi ] && grep -q "1.1.0-rc.10 이상으로" $T/status.txt' || cat $T/status.txt
streset; printf 'version 1.1.0-rc.8\n' > $T/sinst; stsh
check "  1.1.0-rc.8(2.1.0이 받던 판, NEMESIS 1.17에서 지우면 위험 Open-HMG/HMG-API#397)도 verdict=oldhmgapi" '[ "$(sv verdict)" = oldhmgapi ] && grep -q "1.1.0-rc.10 이상으로" $T/status.txt' || cat $T/status.txt
streset; printf 'version 1.1.0-rc.9\n' > $T/sinst; stsh
check "  1.1.0-rc.9(FORCE로 설치한 NEMESIS 1.17 차를 올리면 위험, rc.10이 고침)도 verdict=oldhmgapi(rc.9 < rc.10)" '[ "$(sv verdict)" = oldhmgapi ] && grep -q "1.1.0-rc.10 이상으로" $T/status.txt' || cat $T/status.txt
streset; printf 'version 1.1.0-rc.11\n' > $T/sinst; stsh
check "  1.1.0-rc.11은 지원(ready)" '[ "$(sv verdict)" = ready ]' || cat $T/status.txt
# 설치 진행 기록(USB 설치기가 지금 형식 그대로 씀): 이번 부팅 것만
spr() { printf 'pct=%s\nstate=%s\nstage=%s\nstart=1\nt=2\nboot=%s\nstep=\nust=1\nut=95\n' "$1" "$2" "$3" "${4:-test-boot-id}" > $T/sprog; }
streset; spr 40 run "map을 확인하는 중입니다"; stsh
check "status.sh: 이번 부팅 진행 기록 state=run → verdict=installing" '[ "$(sv verdict)" = installing ] && [ "$(sv s1)" = "설치: 진행 중" ] && [ "$(sv state)" = run ]'
streset; spr 100 reboot "무선 카플레이 설정을 마쳤습니다. [지금 재부팅]을 눌러 내비를 재부팅해 주세요."; stsh
check "  state=reboot → verdict=reboot(재부팅 안내, 노랑), '3분 후' 없이 [지금 재부팅]을 누르라고 함" '[ "$(sv verdict)" = reboot ] && [ "$(sv verdict_lv)" = 1 ] && [ "$(sv s1)" = "설치: 재부팅 필요" ] && [ "$(sv verdict_msg)" = "[지금 재부팅]을 눌러 내비를 재부팅해 주세요." ]' || cat $T/status.txt
streset; spr 100 fail "이 차의 map을 확인하지 못했습니다(설치기 기록을 보세요)."; stsh
check "  state=fail → verdict=failed, 설치기가 쓴 이유 문장이 판정 문구(빨강)" '[ "$(sv verdict)" = failed ] && [ "$(sv verdict_lv)" = 2 ] && [ "$(sv verdict_msg)" = "이 차의 map을 확인하지 못했습니다(설치기 기록을 보세요)." ]' || cat $T/status.txt
streset; spr 100 fail "지난 부팅의 실패" other-boot; stsh
check "  지난 부팅의 진행 기록은 보지 않음(ready)" '[ "$(sv verdict)" = ready ]'
# 공식 무선 모드(requires로 걸지 않으므로 없거나 꺼진 것을 관리 앱이 알림)
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
# 이번 부팅에 칩이 없음(lib.sh nochip_now): 순정 드라이버가 이번 부팅에 칩 켜기를 포기한 커널 줄(11-26 진단의 그 줄), 또는 svc/nochip.sh의
# 기록. 그 부팅에는 칩이 올라오지 않으므로 부팅 뒤 5분("켜는 중")을 기다리지 않는다. nochip.sh가 쓴 ap.boot는 뜬 것이 아니다(apoff 아님)
DHDL="<4>[   18.039191] failed to power up DHD generic adapter, max retry reached**"
streset; noap; rm -f $T/wifiseen $SH/wifi/ap.boot; cat $T/bootid > $SH/wifi/ap.fail; echo "$DHDL" > $T/sdmesg; stsh
check "status.sh: 커널이 이번 부팅에 칩 켜기를 포기했고 칩을 본 적이 없으면 부팅 뒤 5분 전(100초)에도 verdict=nowifipart(켜는 중 아님)" \
  '[ "$(sv verdict)" = nowifipart ] && [ "$(sv nochip)" = yes ] && [ "$(sv nochip_mark)" = no ] && [ "$(sv s2)" = "무선 Wi-Fi: 부품 없음(USB 동글 필요)" ] && [ "$(sv verdict_lv)" = 1 ] && [ "$(sv verdict_end)" = no ]' || cat $T/status.txt
streset; noap; rm -f $T/wifiseen; cat $T/bootid > $T/snochip; stsh
check "  nochip.sh의 이번 부팅 기록이 있으면 커널 줄이 밀려나도 nowifipart, 그 ap.boot는 ap_boot=no·ap_fail=no로 내보냄(관리 앱 표가 '켰다가 꺼짐'·'다시 시도 중'을 보이지 않음, PR #86 리뷰 1)" \
  '[ "$(sv verdict)" = nowifipart ] && [ "$(sv nochip)" = yes ] && [ "$(sv nochip_mark)" = yes ] && [ "$(sv ap_boot)" = no ] && [ "$(sv ap_fail)" = no ]' || cat $T/status.txt
cat $T/bootid > $SH/wifi/ap.fail; stsh
check "  지기가 표시보다 먼저 한 번 시도해 ap.fail이 있어도 ap_fail=no(그 뒤 다시 시도하지 않음)" '[ "$(sv ap_fail)" = no ] && [ "$(sv verdict)" = nowifipart ]' || cat $T/status.txt
grep -v wifihotspot $T/features > $T/f2; mv $T/f2 $T/features; stsh
check "  순정 핫스팟 기능이 꺼진 드문 경우엔 부품 없음으로 보지 않고, nochip.sh의 ap.boot도 apoff로 보지 않음(부팅 뒤 5분 전: apwait)" \
  '[ "$(sv verdict)" = apwait ] && grep -qF "HMG-API가 무선 연결용 Wi-Fi를 켜는 중입니다" $T/status.txt' || cat $T/status.txt
streset; noap; echo "$DHDL" > $T/sdmesg; stsh
check "  칩을 본 적이 있으면(public/wifi-chip) 커널 줄이 있어도 칩 없음으로 보지 않음(apoff)" '[ "$(sv verdict)" = apoff ] && [ "$(sv nochip)" = no ]' || cat $T/status.txt
streset; noap; rm -f $T/wifiseen; echo other-boot > $T/snochip; stsh
check "  지난 부팅의 nochip 기록은 보지 않음(apoff)" '[ "$(sv nochip)" = no ] && [ "$(sv verdict)" = apoff ]' || cat $T/status.txt
streset; rm -f $T/wifiseen; echo "$DHDL" > $T/sdmesg; stsh
check "  wlan0이 있으면(USB 동글 등) 커널 줄이 있어도 칩 없음으로 보지 않음(ready)" '[ "$(sv nochip)" = no ] && [ "$(sv verdict)" = ready ]' || cat $T/status.txt
# usbdev <폴더> <이름> <vendor> <product>: 가짜 /sys/bus/usb/devices의 장치 하나
usbdev() { mkdir -p $1/$2; echo $3 > $1/$2/idVendor; echo $4 > $1/$2/idProduct; }
streset; noap; rm -f $T/wifiseen; echo "$DHDL" > $T/sdmesg; usbdev $T/susb 1-1 1d74 3104; usbdev $T/susb 4-1 058f 6387; stsh
check "  동글이 아닌 USB 장치(LG 모뎀 1d74:3104, USB 저장장치 058f:6387)만 있으면 칩 없음(nowifipart)" '[ "$(sv nochip)" = yes ] && [ "$(sv verdict)" = nowifipart ]' || cat $T/status.txt
usbdev $T/susb 2-1 0bda b812; stsh
check "  동글일 수 있는 USB 장치(Realtek 0bda:b812)가 있으면 커널 줄이 있어도 칩 없음으로 보지 않음(#80: 동글 부팅에도 순정 드라이버가 먼저 포기함)" '[ "$(sv nochip)" = no ] && [ "$(sv verdict)" != nowifipart ]' || cat $T/status.txt
cat $T/bootid > $T/snochip; stsh
check "  칩 없음 기록 뒤에 동글을 꽂았으면 기록을 믿지 않음(nochip_mark=no)" '[ "$(sv nochip_mark)" = no ] && [ "$(sv nochip)" = no ] && [ "$(sv verdict)" != nowifipart ]' || cat $T/status.txt
rm -rf $T/susb; usbdev $T/susb 1-1 2357 012d; stsh
check "  TP-Link(2357) 장치도 동글로 봄" '[ "$(sv nochip_mark)" = no ] && [ "$(sv nochip)" = no ]' || cat $T/status.txt
check "재부팅을 안내하는 문구에 '3분 후'가 없음(설치기는 부팅 보호 확인 뒤 안내하고 [지금 재부팅]이 보호를 막음). 부팅 보호 문구의 '3분 넘게 켜 두세요'만 남김" \
  '! grep -q "3분 후" $PKG/bin/status.sh $B/usb/troubleShooter $B/app/java/io/github/jayparklab/nx4kor/*.java && [ "$(grep -c "3분 넘게 켜 두세요" $PKG/bin/status.sh)" = 2 ]'

# --- svc/nochip.sh: 칩 없는 차에서 HMG-API Wi-Fi 지기의 다시 시도를 멈춤(HMG-API rc.10 engine/HomeWifi.java ap_keep·woke) ---
# 가짜 busybox(bbi): --list에 inotifyd가 있고, inotifyd는 지기가 깨어날 때처럼 ap.boot를 지운 뒤 "d 폴더 파일" 줄 둘(ap.boot,
# ap.fail)을 내고 끝난다(실제로는 지워질 때마다 줄을 내며 계속 돎). 받은 인자는 $T/ninoargs에
cat > $T/bin/bbi <<EOF
#!/bin/sh
case "\$1" in
  --list) echo inotifyd; exit 0 ;;
  inotifyd)
    echo "\$*" > $T/ninoargs; d=\${3%:d}
    # NINO_PLUG: 지우기 전에 동글을 꽂은 것처럼(가짜 USB 장치 0bda:b812)
    [ -n "\$NINO_PLUG" ] && { mkdir -p $T/nusb/2-1; echo 0bda > $T/nusb/2-1/idVendor; echo b812 > $T/nusb/2-1/idProduct; }
    # NINO_LATE: 지운 뒤 0.5초에 동글이 보임(포트 전원을 껐다 켜는 동안 안 보이던 것)
    [ -n "\$NINO_LATE" ] && ( /bin/sleep 0.5; mkdir -p $T/nusb/2-1; echo 0bda > $T/nusb/2-1/idVendor; echo b812 > $T/nusb/2-1/idProduct ) &
    rm -f "\$d/ap.boot"; printf 'd\t%s\tap.boot\nd\t%s\tap.fail\n' "\$d" "\$d"; exit 0 ;;
esac
exec $T/bin/bb "\$@"
EOF
chmod +x $T/bin/bbi
NH=$T/nh
ncrun() {
  (env PATH=$P0 BB=$T/bin/bb NX4_APP=$TP NX4_ROOT=$T/nroot W=$T/nw BOOT_ID=$T/bootid UPTIME=$T/nuptime WIFI_SEEN=$T/nseen SDIO=$T/nosdio \
     SYSNET=$T/nsysnet NX4_DMESG=$T/ndmesg HMGDATA=$NH NOCHIP=$T/nnochip HOTSPOT_XML=$T/nhot.xml USBDEV=$T/nusb NX4_NOCHIP_POLL=1 NX4_NOCHIP_MAX=120 NX4_NOCHIP_RECHECK=0 \
     "$@" sh $TP/svc/nochip.sh) > $T/nc.out 2>&1; echo $? > $T/nc.rc
}
# 칩 없는 차(11-26 NX4HEV 260902): 칩을 본 기록·SDIO·wlan0 없음, 커널이 이번 부팅에 포기, 핫스팟 기능 권한 파일 있음, 공식 모드의 프로젝션 AP 요청
ncreset() {
  rm -rf $NH $T/nsysnet $T/nseen $T/nnochip $T/ninoargs $T/nusb $T/nw; mkdir -p $NH/state $T/nsysnet
  usbdev $T/nusb 1-1 1d74 3104; usbdev $T/nusb 4-1 058f 6387   # 순정 LG 모뎀, USB 저장장치(동글 아님)
  echo "projection wireless-carplay-aa" > $NH/state/wifi.txt; : > $T/nhot.xml
  printf '%s\n' "<4>[    9.709979] Power-up adapter 'DHD generic adapter'" "<4>[   11.772709] failed to power up DHD generic adapter, 3 retry left" "$DHDL" "<4>[   18.102925] dhd_module_init out" > $T/ndmesg
  echo "60.00 10.00" > $T/nuptime
}
ncreset; ncrun
check "nochip.sh: 칩 없는 부팅이면 이번 부팅 id를 이 모드의 기록(644)과 HMG-API의 wifi/ap.boot(600)에 쓰고, 한 줄로 알림" \
  '[ "$(cat $T/nc.rc)" = 0 ] && [ "$(cat $T/nnochip)" = "$(cat $T/bootid)" ] && [ "$(cat $NH/wifi/ap.boot)" = "$(cat $T/bootid)" ] && [ "$(ls -l $T/nnochip | cut -c1-10)" = "-rw-r--r--" ] && [ "$(ls -l $NH/wifi/ap.boot | cut -c1-10)" = "-rw-------" ] && [ ! -e $NH/wifi/ap.boot.nx4 ] && grep -q "Wi-Fi 칩 없음(순정 드라이버가 이번 부팅에 칩 켜기를 포기함): HMG-API의 프로젝션 AP 다시 시도를 이번 부팅에 멈춤" $T/nc.out' || cat $T/nc.out
check "  busybox에 inotifyd가 없으면 깨어난 뒤는 지키지 않는다고 남기고 끝남(상주 없음)" 'grep -q "inotifyd가 없어" $T/nc.out && [ ! -f $T/ninoargs ]' || cat $T/nc.out
ncreset; echo other-boot > $T/nnochip; mkdir -p $NH/wifi; echo other-boot > $NH/wifi/ap.boot; ncrun
check "  지난 부팅의 기록·ap.boot는 이번 부팅 id로 바꿈" '[ "$(cat $T/nnochip)" = "$(cat $T/bootid)" ] && [ "$(cat $NH/wifi/ap.boot)" = "$(cat $T/bootid)" ]' || cat $T/nc.out
ncreset; ncrun BB=$T/bin/bbi
check "  inotifyd가 있으면 wifi 폴더의 지우기만 보고(- $NH/wifi:d), 지기가 깨어나 ap.boot를 지우면 다시 씀(ap.fail은 그대로), 한 번만 알림" \
  '[ "$(cat $T/ninoargs)" = "inotifyd - $NH/wifi:d" ] && [ "$(cat $NH/wifi/ap.boot)" = "$(cat $T/bootid)" ] && [ "$(grep -c "ap.boot를 지움(QuickBoot에서 깨어남): 다시 씀" $T/nc.out)" = 1 ] && grep -q "wifi 폴더 보기를 마침" $T/nc.out && [ ! -e $T/nw/nochip.fifo ]' || cat $T/nc.out
ncreset; ncrun BB=$T/bin/bb BB_OWN=$T/bin/bbi
check "  내비 busybox에 inotifyd가 없으면 함께 넣은 busybox(BB_OWN)의 inotifyd를 씀(PR #86 리뷰 3)" \
  '[ "$(cat $T/ninoargs)" = "inotifyd - $NH/wifi:d" ] && [ "$(cat $NH/wifi/ap.boot)" = "$(cat $T/bootid)" ] && ! grep -q "inotifyd가 없어" $T/nc.out' || cat $T/nc.out
ncreset; ncrun BB=$T/bin/bbi NINO_PLUG=1
check "  기록 뒤에 동글을 꽂아 ap.boot가 지워지면 다시 쓰지 않고 칩 없음 기록을 지운 뒤 물러남(#80)" \
  '[ ! -e $NH/wifi/ap.boot ] && [ ! -e $T/nnochip ] && grep -q "동글이 보여 물러남" $T/nc.out && ! grep -q "다시 씀" $T/nc.out' || cat $T/nc.out
ncreset; ncrun BB=$T/bin/bbi NINO_LATE=1 NX4_NOCHIP_RECHECK=1
check "  ap.boot가 지워질 때 동글이 안 보여도 NX4_NOCHIP_RECHECK초 뒤 한 번 더 보고, 그때 보이면 물러남(포트 전원을 껐다 켜는 틈)" \
  '[ ! -e $NH/wifi/ap.boot ] && [ ! -e $T/nnochip ] && grep -q "동글이 보여 물러남" $T/nc.out && ! grep -q "다시 씀" $T/nc.out' || cat $T/nc.out
ncreset; usbdev $T/nusb 2-1 0bda b812; ncrun
check "  부팅 때 동글일 수 있는 USB 장치(0bda:b812)가 있으면 아무것도 쓰지 않음(동글 부팅에도 순정 드라이버가 먼저 포기함, #80)" '[ ! -e $T/nnochip ] && [ ! -e $NH/wifi/ap.boot ] && grep -q "칩이나 USB Wi-Fi 동글이 있음" $T/nc.out' || cat $T/nc.out
# 포기한 줄이 있어도 부팅 뒤 50초(NX4_NOCHIP_SETTLE)까지는 동글이 USB에 올라올 틈을 둔다(이 차는 약 40초에 포트 전원을 껐다 켜
# 43~44초에 다시 보임): 41초에 줄이 있고 동글이 안 보이다가, 1.5초 뒤 동글이 보이고 51초가 됨
ncreset; echo "41.00 10.00" > $T/nuptime; (/bin/sleep 1.5; usbdev $T/nusb 2-1 0bda b831; echo "51.00 10.00" > $T/nuptime) & _ncw=$!; ncrun; wait $_ncw
check "  부팅 뒤 50초 전이면 기다리고(포트 전원을 껐다 켜는 틈), 그사이 동글이 보이면 아무것도 쓰지 않음" '[ ! -e $T/nnochip ] && [ ! -e $NH/wifi/ap.boot ] && grep -q "동글이 있음" $T/nc.out' || cat $T/nc.out
# 부팅 때도 정하기 전에 NX4_NOCHIP_RECHECK초 뒤 한 번 더 본다(포트 전원을 껐다 켜는 때가 늦게 밀린 부팅, PR #86 리뷰 7): 60초에 줄이
# 있고 동글이 안 보이다가 0.5초 뒤 보임
ncreset; (/bin/sleep 0.5; usbdev $T/nusb 2-1 0bda b812) & _ncw=$!; ncrun NX4_NOCHIP_RECHECK=1; wait $_ncw
check "  부팅 때도 정하기 전에 NX4_NOCHIP_RECHECK초 뒤 한 번 더 보고, 그때 동글이 보이면 아무것도 쓰지 않음(PR #86 리뷰 7)" '[ ! -e $T/nnochip ] && [ ! -e $NH/wifi/ap.boot ] && grep -q "동글이 있음" $T/nc.out' || cat $T/nc.out
ncreset; : > $T/nseen; ncrun
check "  칩을 본 적이 있으면(public/wifi-chip) 아무것도 쓰지 않음" '[ ! -e $T/nnochip ] && [ ! -e $NH/wifi/ap.boot ] && grep -q "Wi-Fi 칩이나 USB Wi-Fi 동글이 있음: 할 일 없음" $T/nc.out' || cat $T/nc.out
ncreset; mkdir -p $T/nsysnet/wlan0; ncrun
check "  wlan0이 있으면(USB 동글 등) 아무것도 쓰지 않음" '[ ! -e $T/nnochip ] && [ ! -e $NH/wifi/ap.boot ] && grep -q "Wi-Fi 칩이나 USB Wi-Fi 동글이 있음" $T/nc.out' || cat $T/nc.out
ncreset; rm -f $T/nhot.xml; ncrun
check "  순정 핫스팟 기능 권한 파일이 없으면 쓰지 않음" '[ ! -e $T/nnochip ] && [ ! -e $NH/wifi/ap.boot ] && grep -q "핫스팟 기능 권한 파일이 없음" $T/nc.out' || cat $T/nc.out
ncreset; echo home > $NH/state/wifi.txt; ncrun
check "  프로젝션 AP를 요청한 모드가 없으면 쓰지 않음" '[ ! -e $T/nnochip ] && [ ! -e $NH/wifi/ap.boot ] && grep -q "프로젝션 AP를 요청한 모드가 없음" $T/nc.out' || cat $T/nc.out
ncreset; echo "<4>[   18.102925] dhd_module_init out" > $T/ndmesg; echo "130.00 10.00" > $T/nuptime; ncrun
check "  부팅 뒤 NX4_NOCHIP_MAX(120)초까지 포기한 줄이 없으면(동글 드라이버, 칩 있음 등) 쓰지 않고 끝남" '[ "$(cat $T/nc.rc)" = 0 ] && [ ! -e $T/nnochip ] && [ ! -e $NH/wifi/ap.boot ] && grep -q "부팅 뒤 130초까지 순정 Wi-Fi 드라이버가 칩을 포기한 줄이 없음" $T/nc.out' || cat $T/nc.out
# 드라이버의 결과가 늦게 나옴: 줄이 없는 동안 NX4_NOCHIP_POLL초마다 다시 본다
ncreset; : > $T/ndmesg; (/bin/sleep 1.5; echo "$DHDL" > $T/ndmesg) & _ncw=$!; ncrun; wait $_ncw
check "  포기한 줄이 늦게 나오면 기다렸다가 씀" '[ "$(cat $NH/wifi/ap.boot)" = "$(cat $T/bootid)" ] && [ "$(cat $T/nnochip)" = "$(cat $T/bootid)" ]' || cat $T/nc.out
# 줄도 부팅 뒤 초도 못 읽어도 끝이 있음(NX4_NOCHIP_MAX/POLL + 2번)
ncreset; : > $T/ndmesg; rm -f $T/nuptime; ncrun NX4_NOCHIP_MAX=2
check "  부팅 뒤 초를 못 읽어도 정해진 횟수 뒤 끝남" '[ "$(cat $T/nc.rc)" = 0 ] && [ ! -e $NH/wifi/ap.boot ] && grep -q "부팅 뒤 ?초까지" $T/nc.out' || cat $T/nc.out
# HMG-API 부팅 보호(#18, HMG-API rc.6 이후 zygote.c: 올리기 전 값으로 이번 부팅 횟수 ≥ 3이거나 starts ≥ 6이면 그 시작의 훅을 끔).
# 파일 값은 이번 zygote 시작이 올린 뒤 값(hook/starts, hook/boot "<boot_id> <이번 부팅 횟수>"). 이번 부팅 커널 줄(NX4_DMESG)이
# 있으면 그것을 따르고, 없으면 파일로 본다. 다음 시작(재부팅)은 이번 부팅 횟수가 0부터라 starts < 6이면 재부팅만 안내(노랑),
# 아니면 다시 설치(빨강)
HK=$T/shook
# gset <starts, 빈 값이면 파일 없음> [hook/boot 내용, 없으면 파일 없음]. starts는 zygote처럼 줄바꿈 없이 쓴다
gset() { rm -f $HK/starts $HK/boot; [ -n "$1" ] && printf %s "$1" > $HK/starts; [ -n "$2" ] && echo "$2" > $HK/boot; return 0; }
zl() { printf '%s\n' "$@" > $T/sdmesg; }
ZL="hmgapid, exec /system/bin/app_process.hmgapi-stock"
GMSG1="HMG-API가 이번 부팅에만 무선 기능을 껐습니다(부팅 보호). 내비를 재부팅하고 3분 넘게 켜 두세요. 또 생기면 마지막으로 넣거나 바꾼 모드를 HMG-API 앱에서 꺼 주세요."
GMSG2="HMG-API가 재부팅이 너무 잦은 것으로 보고 무선 기능을 껐습니다. HMG-API를 지우지 말고 HMG-API USB로 다시 설치(업데이트)한 뒤 재부팅하고, 3분 넘게 켜 두세요."
# gv 1|2: 판정이 bootguard이고 그 수준·문구
gv() { [ "$(sv verdict)" = bootguard ] && [ "$(sv verdict_lv)" = $1 ] && if [ $1 = 1 ]; then [ "$(sv verdict_msg)" = "$GMSG1" ]; else [ "$(sv verdict_msg)" = "$GMSG2" ]; fi; }
streset; : > $HK/enable; zl "<6>[    9.812000] hmgapi-hook: zygote, hooks off (boot guard, starts=6, this boot 0), $ZL"; gset 7 "test-boot-id 1"; stsh
check "status.sh 부팅 보호: 이번 부팅 커널 줄이 boot guard이고 starts=7(다음 재부팅도 꺼짐) → bootguard 빨강(지우지 말고 다시 설치), 요약 '훅 꺼짐(부팅 보호)'" \
  'gv 2 && [ "$(sv s1)" = "설치: HMG-API 훅 꺼짐(부팅 보호)" ]' || cat $T/status.txt
zl "<6>[    9.812000] hmgapi-hook: zygote, hooks off (boot guard, starts=3, this boot 3), $ZL"; gset 4 "test-boot-id 4"; stsh
check "  한 부팅 안에서 3번 못 떠 꺼짐(this boot 3), starts=4 → 노랑 '이번 부팅에만 … 재부팅'(재부팅하면 이번 부팅 횟수 0부터, starts 4 < 6)" 'gv 1' || cat $T/status.txt
gset 5 "test-boot-id 4"; stsh; _g5=$(sv verdict_lv); gset 6 "test-boot-id 4"; stsh
check "  경계: starts=5면 노랑, 6이면 빨강(다음 시작이 starts 6으로 꺼짐)" '[ "$_g5" = 1 ] && gv 2' || cat $T/status.txt
gset 0; stsh
check "  그 사이 HMG-API를 다시 설치함(starts=0, hook/boot 지움) → 노랑 재부팅 안내" 'gv 1' || cat $T/status.txt
gset; stsh
check "  starts를 못 읽으면 빨강(다시 설치)" 'gv 2' || cat $T/status.txt
zl "<6>[    9.812000] hmgapi-hook: zygote, hooks on, start 6 (this boot 1), $ZL"; gset 6 "test-boot-id 1"; stsh
check "  커널 줄 'hooks on, start 6 (this boot 1)'이면 starts=6이어도 부팅 보호 아님(ready)" '[ "$(sv verdict)" = ready ]' || cat $T/status.txt
zl "<6>[    9.812000] hmgapi-hook: zygote, hooks on, start 3 (this boot 3), $ZL" "<6>[  200.100000] hmgapi-hook: zygote, hooks off (boot guard, starts=3, this boot 3), $ZL"
gset 4 "test-boot-id 4"; stsh; _gz1=$(sv verdict)
zl "<6>[    9.812000] hmgapi-hook: zygote, hooks off (boot guard, starts=3, this boot 3), $ZL" "<6>[  300.100000] hmgapi-hook: zygote, hooks on, start 1 (this boot 1), $ZL"
gset 1 "test-boot-id 1"; stsh
check "  zygote가 같은 부팅에 다시 시작하면 마지막 줄을 따름(on → guard는 부팅 보호, guard → on은 아님)" '[ "$_gz1" = bootguard ] && [ "$(sv verdict)" = ready ]' || cat $T/status.txt
zl "<6>[    3.000000] hmgapi-hook: zygote, hooks off (disable file), $ZL"; gset 9 "test-boot-id 9"; stsh
check "  커널 줄이 'hooks off (disable file)'이면 횟수가 높아도 부팅 보호 아님" '[ "$(sv verdict)" != bootguard ]' || cat $T/status.txt
# 커널 줄이 없을 때(로그가 밀려남 등): 파일로 본다. 이번 시작이 꺼짐 = 이번 부팅 횟수 ≥ 4, 또는 이번 부팅에 센 기록이 있고 starts ≥ 7
: > $T/sdmesg
gset 4 "test-boot-id 4"; stsh
check "status.sh 부팅 보호(커널 줄 없음): 이번 부팅 4번째 시작(hook/boot), starts=4 → bootguard 노랑" 'gv 1' || cat $T/status.txt
gset 3 "test-boot-id 3"; stsh
check "  이번 부팅 3번째 시작(올리기 전 2라 켜짐)이면 아님" '[ "$(sv verdict)" = ready ]' || cat $T/status.txt
gset 7 "test-boot-id 1"; stsh
check "  재부팅을 넘어 7번째(올리기 전 6)이고 이번 부팅 1번째 → bootguard 빨강" 'gv 2' || cat $T/status.txt
gset 6 "test-boot-id 1"; stsh; _gf6=$(sv verdict); gset 5 "test-boot-id 2"; stsh
check "  starts=6·5(올리기 전 5·4라 켜짐)면 아님(rc.4 규칙의 starts≥4로 보지 않음)" '[ "$_gf6" = ready ] && [ "$(sv verdict)" = ready ]' || cat $T/status.txt
gset 7 "other-boot 5"; stsh; _gfo=$(sv verdict); gset 7; stsh
check "  hook/boot가 다른 부팅 것이거나 없으면(이번 부팅 zygote가 세지 않음·watcher가 지움) starts=7이 남아 있어도 아님" '[ "$_gfo" = ready ] && [ "$(sv verdict)" = ready ]' || cat $T/status.txt
gset 4 "test-boot-id 4"; stsh BOOT_ID=$T/nobootid; _gnb=$(sv verdict); _gnbl=$(sv verdict_lv); gset 3; stsh BOOT_ID=$T/nobootid
check "  boot_id를 못 읽으면 zygote처럼 모든 시작을 한 부팅으로 셈: starts=4면 bootguard 빨강(다음 시작도 꺼짐), 3이면 아님" \
  '[ "$_gnb" = bootguard ] && [ "$_gnbl" = 2 ] && [ "$(sv verdict)" != bootguard ]' || cat $T/status.txt
gset 7 "test-boot-id 4"; : > $HK/disable; stsh; _gd=$(sv verdict); rm -f $HK/disable $HK/enable; stsh; _ge=$(sv verdict); : > $HK/enable
rm -f $T/sinst; stsh
check "  hook/disable이 있거나 hook/enable이 없으면(횟수가 멈춘 옛 값) 아님, HMG-API가 없으면 nohmgapi" '[ "$_gd" = ready ] && [ "$_ge" = ready ] && [ "$(sv verdict)" = nohmgapi ]' || cat $T/status.txt
: > $T/sdmesg
rm -f $T/ps.out $T/features

# status.sh --watch: 관리 앱의 [지금 재부팅] 요청(앱 개인 폴더의 reboot.req)을 받는 감시자
RW=$T/rw; rm -rf $RW; mkdir -p $RW/w $RW/bk $RW/proc
printf '#!/bin/sh\necho reboot >> %s/rbcalls\nexit 1\n' $RW > $T/bin/fakereboot; chmod +x $T/bin/fakereboot
echo "100.00 50.00" > $RW/uptime; echo 200 > $RW/w/watch.until
(env PATH=$P0 BB=$T/bin/bb APP=$TP W=$RW/w BK=$RW/bk PROG=$RW/prog NOTICE=$RW/notice BOOT_ID=$T/bootid UPTIME=$RW/uptime PROC=$RW/proc \
   NX4_RBREQ=$RW/reboot.req RBRES=$RW/rbres WATCHF=$RW/watchf NX4_REBOOT=$T/bin/fakereboot NX4_SYNC=true NX4_RB_WAIT=1 NX4_APLOG=$RW/ap.log \
   HOOKSTARTS=$RW/hook/starts HMGINST=$RW/inst NX4_DMESG=$RW/dmesg sh $TP/bin/status.sh --watch) > $RW/watch.out 2>&1 &
RWP=$!
# 감시자가 결과 파일에 이 요청 id와 code를 쓸 때까지 기다린다(최대 약 10초)
rbwait() { _k=0; until grep -qx "id=$1" $RW/rbres 2>/dev/null || [ $_k -ge 100 ]; do /bin/sleep 0.1; _k=$((_k+1)); done; }
rbreq() { echo "$1 $2 $3" > $RW/reboot.req.tmp; mv -f $RW/reboot.req.tmp $RW/reboot.req; rbwait $1; }
rbreq 5001 test-boot-id 95
check "status.sh --watch: 이번 부팅의 새 요청(5초 전) → sync 뒤 reboot을 부름, 명령이 돌아오면 결과 code=cmd(앱은 RESET 안내), 요청 지움" \
  '[ "$(grep -c reboot $RW/rbcalls 2>/dev/null)" = 1 ] && grep -qx "code=cmd" $RW/rbres && [ ! -f $RW/reboot.req ] && grep -q "관리 앱에서 재부팅 요청" $RW/ap.log'
rbreq 5002 other-boot 95
check "  지난 부팅의 요청 → reboot 안 부름, code=bad" '[ "$(grep -c reboot $RW/rbcalls)" = 1 ] && grep -qx "code=bad" $RW/rbres'
rbreq 5003 test-boot-id 30
check "  40초보다 오래된 요청 → reboot 안 부름, code=old" '[ "$(grep -c reboot $RW/rbcalls)" = 1 ] && grep -qx "code=old" $RW/rbres'
printf 'pct=40\nstate=run\nstage=x\nt=1\nboot=test-boot-id\nut=95\n' > $RW/prog
rbreq 5004 test-boot-id 95
check "  설치가 진행 중(이번 부팅 run, 마지막 기록 5초 전) → reboot 안 부름, code=install" '[ "$(grep -c reboot $RW/rbcalls)" = 1 ] && grep -qx "code=install" $RW/rbres'
# HMG-API 부팅 보호 거절(#18, HMG-API rc.6 이후). [지금 재부팅]은 새 커널 부팅이라 다음 zygote 시작의 이번 부팅 횟수는 0부터:
# starts(올린 뒤 값)가 6이면 다음 시작에, 5면 그다음 시작에 훅이 꺼진다. 그래서 5·6만 거절(code=guard). 부팅 뒤 100초
# (위 테스트까지는 HMG-API 설치 기록 $RW/inst가 없어 부팅 보호로는 막지 않았다)
rm -f $RW/prog; printf 'version 1.1.0-rc.10\n' > $RW/inst; mkdir -p $RW/hook; : > $RW/hook/enable; : > $RW/dmesg
rbn() { grep -c reboot $RW/rbcalls; }
# rgset <starts> [hook/boot 내용, 없으면 파일 없음]. starts는 zygote처럼 줄바꿈 없이 쓴다
rgset() { rm -f $RW/hook/starts $RW/hook/boot; printf %s "$1" > $RW/hook/starts; [ -n "$2" ] && echo "$2" > $RW/hook/boot; return 0; }
rgset 6 "test-boot-id 1"; c0=$(rbn); rbreq 5005 test-boot-id 95
check "status.sh --watch 부팅 보호: starts=6, 커널 줄 없음, 부팅 뒤 100초 → 거절(code=guard), reboot 안 부름, ap.log에 이유(300초 전)" \
  '[ "$(rbn)" = $c0 ] && grep -qx "code=guard" $RW/rbres && grep -q "재부팅 요청 거절: 부팅 뒤 100초(HMG-API 시작 확인 시각 300초 전)이고 HMG-API 부팅 보호 횟수 starts=6(켜지고 2분 안의 재부팅이 6번 이어지면" $RW/ap.log' || cat $RW/ap.log
rgset 5 "test-boot-id 1"; c0=$(rbn); rbreq 5006 test-boot-id 95
check "  starts=5(그다음 시작에 꺼짐)도 거절" '[ "$(rbn)" = $c0 ] && grep -qx "id=5006" $RW/rbres && grep -qx "code=guard" $RW/rbres'
rgset 4 "test-boot-id 1"; c0=$(rbn); rbreq 5007 test-boot-id 95
check "  starts=4면 받음(다음 시작 5·그다음 6까지 켜짐)" '[ "$(rbn)" = $((c0+1)) ] && grep -qx "code=cmd" $RW/rbres'
rgset 3 "test-boot-id 1"; c0=$(rbn); rbreq 5008 test-boot-id 95; _r3=$(rbn)
rgset 2 "test-boot-id 1"; rbreq 5009 test-boot-id 95
check "  rc.4 규칙에서 거절하던 starts=3·2는 받음" '[ "$_r3" = $((c0+1)) ] && [ "$(rbn)" = $((c0+2)) ]'
rgset 7 "test-boot-id 1"; c0=$(rbn); rbreq 5010 test-boot-id 95
check "  starts=7이고 이번 부팅에 센 기록이 있으면(파일로 보아 이번 시작이 이미 꺼짐) 막지 않음" '[ "$(rbn)" = $((c0+1)) ]'
rgset 6 "test-boot-id 4"; c0=$(rbn); rbreq 5011 test-boot-id 95
check "  커널 줄이 없어도 파일로 보아 이번 시작이 이미 꺼졌으면(이번 부팅 4번째) starts=6이어도 막지 않음" '[ "$(rbn)" = $((c0+1)) ]'
rgset 6 "other-boot 2"; c0=$(rbn); rbreq 5012 test-boot-id 95; _rob=$(rbn)
rgset 6; rbreq 5013 test-boot-id 95
check "  hook/boot가 다른 부팅 것이거나 없어도 starts=6이면 거절(다음 시작은 starts만 봄)" '[ "$_rob" = $c0 ] && [ "$(rbn)" = $c0 ] && grep -qx "id=5013" $RW/rbres && grep -qx "code=guard" $RW/rbres'
# 거절의 위쪽 끝(PR #55 리뷰 4): starts 7 이상이면 다음 시작은 거절하든 말든 꺼지므로 막지 않는다. 파일로 보아 이번 시작이 꺼졌다고
# 볼 수 없는 꼴(hook/boot가 다른 부팅 것·없음, 커널 줄 없음)로 두어, 위쪽 끝만으로 결과가 갈리게 한다
rgset 7 "other-boot 2"; c0=$(rbn); rbreq 5019 test-boot-id 95; _ro7=$(rbn)
rgset 7; rbreq 5020 test-boot-id 95
check "  hook/boot가 다른 부팅 것이거나 없고 starts=7이면 막지 않음(거절은 5·6까지)" '[ "$_ro7" = $((c0+1)) ] && [ "$(rbn)" = $((c0+2)) ] && grep -qx "id=5020" $RW/rbres && grep -qx "code=cmd" $RW/rbres'
rgset 6 "test-boot-id 1"; : > $RW/hook/disable; c0=$(rbn); rbreq 5014 test-boot-id 95; rm -f $RW/hook/disable; _rdis=$(rbn)
rm -f $RW/inst; rbreq 5015 test-boot-id 95; printf 'version 1.1.0-rc.10\n' > $RW/inst
check "  hook/disable이 있거나 HMG-API가 설치돼 있지 않으면 막지 않음" '[ "$_rdis" = $((c0+1)) ] && [ "$(rbn)" = $((c0+2)) ]'
# 커널 줄이 있으면 그것을 따른다. watcher는 "hooks on" 줄 시각 + 120초에 돌므로 그 + 15초까지 막는다(10초면 145초)
rgset 6 "test-boot-id 4"
printf '%s\n' "<6>[   10.200000] hmgapi-hook: zygote, hooks off (boot guard, starts=5, this boot 3), hmgapid, exec /system/bin/app_process.hmgapi-stock" > $RW/dmesg
c0=$(rbn); rbreq 5016 test-boot-id 95
check "  이번 부팅 커널 줄이 boot guard(이미 꺼짐)면 starts=6이어도 막지 않음" '[ "$(rbn)" = $((c0+1)) ]'
rgset 6 "test-boot-id 1"
printf '%s\n' "<6>[   10.200000] hmgapi-hook: zygote, hooks on, start 6 (this boot 1), hmgapid, exec /system/bin/app_process.hmgapi-stock" > $RW/dmesg
c0=$(rbn); rbreq 5017 test-boot-id 95
check "  커널 줄 'hooks on'(10초)이고 starts=6이면 10+120+15=145초 전(부팅 뒤 100초)에는 거절" '[ "$(rbn)" = $c0 ] && grep -qx "code=guard" $RW/rbres && grep -q "시작 확인 시각 145초 전" $RW/ap.log'
echo "150.00 50.00" > $RW/uptime; c0=$(rbn); rbreq 5018 test-boot-id 145
check "  145초가 지나면(부팅 뒤 150초) starts=6이어도 막지 않음" '[ "$(rbn)" = $((c0+1)) ]'
echo "100.00 50.00" > $RW/uptime; : > $RW/dmesg
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

# --- scripts/fetch-wireless.sh: 공식 무선 모드 zip을 공식 릴리스에서 받아, NOTICE.md의 SHA-256과 맞을 때만 둔다 ---
# 인터넷 없이: 가짜 zip(위 USB 설치기 테스트의 공식 무선 모드)을 file://로 주고, 그 SHA-256을 적은 가짜 NOTICE.md 옆에 스크립트를 둔다
FW=$T/fw; mkdir -p $FW/scripts; cp $B/scripts/fetch-wireless.sh $FW/scripts/
WZF=$T/fw-wireless.zip; (cd $WM && zip -q -r $WZF .)
fwnotice() { printf '## 공식 무선 모드\n  - 공식 모드 zip SHA-256 `%s`\n' "$1" > $FW/NOTICE.md; }
fwrun() { (env NX4_WIRELESS_URL="$1" sh "$2" "$3") > $T/fw.out 2>&1; echo $? > $T/fw.rc; }
fwnotice $(sha256 $WZF)
fwrun file://$WZF $FW/scripts/fetch-wireless.sh $T/fw-out
check "fetch-wireless: 받은 zip이 NOTICE.md의 SHA-256과 같으면 wireless-carplay-aa-<판>.zip으로 두고 마지막 줄에 그 경로를 씀" \
  '[ "$(cat $T/fw.rc)" = 0 ] && cmp -s $T/fw-out/wireless-carplay-aa-$WV.zip $WZF && [ "$(tail -n 1 $T/fw.out)" = "$T/fw-out/wireless-carplay-aa-$WV.zip" ]' || cat $T/fw.out
fwrun file://$T/none.zip $FW/scripts/fetch-wireless.sh $T/fw-out
check "fetch-wireless: 같은 SHA-256의 zip이 이미 있으면 다시 받지 않음" '[ "$(cat $T/fw.rc)" = 0 ] && grep -q "이미 받아 둠" $T/fw.out' || cat $T/fw.out
fwrun file://$WZF $B/scripts/fetch-wireless.sh $T/fw-bad
check "fetch-wireless: 받은 zip이 NOTICE.md의 SHA-256과 다르면 멈추고 아무것도 두지 않음" '[ "$(cat $T/fw.rc)" != 0 ] && grep -q "SHA-256.*다릅니다" $T/fw.out && [ ! -e $T/fw-bad ]' || cat $T/fw.out
fwrun file://$T/none.zip $FW/scripts/fetch-wireless.sh $T/fw-bad
check "fetch-wireless: 받지 못하면 멈춤" '[ "$(cat $T/fw.rc)" != 0 ] && grep -q "받지 못했습니다" $T/fw.out && [ ! -e $T/fw-bad ]' || cat $T/fw.out
check "fetch-wireless: 기본 주소는 Open-HMG/hmgapi-wireless-cp-aa 릴리스 v<판>의 wireless-carplay-aa-<판>.zip(https), NOTICE.md에 같은 판의 파일 이름·대응 소스와 SHA-256 하나" \
  '[ -n "$WV" ] && grep -q "https://github.com/Open-HMG/hmgapi-wireless-cp-aa/releases/download/v\$WV/\$NAME" $B/scripts/fetch-wireless.sh && grep -q "wireless-carplay-aa-$WV.zip" $B/NOTICE.md && grep -q "hmgapi-wireless-cp-aa/tree/v$WV" $B/NOTICE.md && [ "$(grep -c "공식 모드 zip SHA-256 \`[0-9a-f]\{64\}\`" $B/NOTICE.md)" = 1 ]'

# --- drivers/(USB Wi-Fi 동글 드라이버, #48) --- Docker 빌드는 scripts/build-driver.sh가 한다(오래 걸리고 인터넷이 필요해 여기서는
# 돌리지 않음). 여기서는 Docker 없이 볼 수 있는 것만: 구문, 바깥 자료 고정 값, 패치 차례와 꼴, 문서와 값이 같은지
DI=$B/drivers/inputs.sh
# inputs.sh의 꼴: 주소는 https, sha256은 64자리, 커밋은 40자리. 커널 소스 자산은 이 저장소 릴리스(v가 아닌 태그)의 파일
drv_inputs_ok() (
  . $DI
  for u in "$KERNEL_URL" "$MOBIS_ZIP_URL" "$MOBIS_SRC_URL" "$RTL88X2BU_GIT" "$RTL8831BU_GIT"; do case "$u" in https://*) ;; *) exit 1 ;; esac; done
  for h in "$KERNEL_SHA256" "$MOBIS_ZIP_SHA256" "$MOBIS_SRC_SHA256" "$MOBIS_TREE_SHA256" "$KCONFIG_SUM" "$TOOLCHAIN_SHA256" "$EXPECTED_CFLAGS_SHA256" "$EXPECTED_CFLAGS_SHA256_8831BU"; do
    echo "$h" | grep -qx '[0-9a-f]\{64\}' || exit 1
  done
  echo "$RTL88X2BU_COMMIT" | grep -qx '[0-9a-f]\{40\}' || exit 1
  echo "$RTL8831BU_COMMIT" | grep -qx '[0-9a-f]\{40\}' || exit 1
  [ "$MOBIS_SRC_URL" = "https://github.com/jay-park-lab/hmgapi-nx4-kor/releases/download/$MOBIS_SRC_TAG/$MOBIS_SRC_FILE" ] || exit 1
  case "$MOBIS_SRC_TAG" in v*) exit 1 ;; esac
  case "$MOBIS_ZIP_URL" in https://www.mobis.com/*) ;; *) exit 1 ;; esac
)
# 앞 8자리
p8() { echo "$1" | cut -c1-8; }
# README·NOTICE에 적은 값이 inputs.sh와 같은가: sha256은 앞 8자리, 드라이버 커밋·defconfig·자산 태그와 파일 이름은 전부
drv_docs_ok() (
  . $DI
  for v in $(p8 $KERNEL_SHA256) $(p8 $MOBIS_ZIP_SHA256) $(p8 $MOBIS_SRC_SHA256) $(p8 $MOBIS_TREE_SHA256) $(p8 $KCONFIG_SUM) \
      $(p8 $TOOLCHAIN_SHA256) $(p8 $EXPECTED_CFLAGS_SHA256) $(p8 $EXPECTED_CFLAGS_SHA256_8831BU) $RTL88X2BU_COMMIT $RTL8831BU_COMMIT \
      $MOBIS_DEFCONFIG $MOBIS_SRC_TAG $MOBIS_SRC_FILE $MOBIS_DIR; do
    grep -q "$v" $B/drivers/README.md || { echo "drivers/README.md에 없음: $v"; exit 1; }
  done
  for v in $RTL88X2BU_COMMIT $RTL8831BU_COMMIT $MOBIS_ZIP_SHA256 $MOBIS_SRC_TAG $MOBIS_DIR; do
    grep -q "$v" $B/NOTICE.md || { echo "NOTICE.md에 없음: $v"; exit 1; }
  done
)
# 드라이버 쪽 문서·코드에 다른 프로젝트(Korea Projection, JMK) 언급이 없는가(2026-11-26 사용자 결정: 드라이버는 그 둘과 관계없음)
drv_noref_ok() {
  ! grep -rn -i -E "korea ?projection|(^|[^a-z])kp([^a-z]|$)|kp-(check|protect)|jmk|jongmin" $B/drivers $B/scripts/build-driver.sh $B/.github/workflows/drivers.yml \
    && ! sed -n '/^## USB Wi-Fi 동글 드라이버/,/^## [^U]/p' $B/NOTICE.md | grep -i -E "korea ?projection|(^|[^a-z])kp([^a-z]|$)|jmk"
}
check "drivers: 빌드 스크립트 구문(bash -n·sh -n)" \
  'bash -n $B/drivers/build-in-container.sh && bash -n $B/drivers/lib.sh && bash -n $B/drivers/kernel/prepare.sh && sh -n $B/scripts/build-driver.sh && sh -n $B/drivers/config-sum.sh && bash -n $DI'
check "drivers/inputs.sh: 바깥 자료마다 https 주소와 sha256(또는 커밋), 커널 소스 자산은 이 저장소 릴리스(v가 아닌 태그), 원본은 mobis.com" 'drv_inputs_ok'
check "drivers: GPL-2.0 전문(drivers/COPYING), build-driver.sh는 빌드 날짜를 LC_ALL=C·UTC로, drivers/를 바꾼 마지막 커밋 시각에서" \
  'head -2 $B/drivers/COPYING | grep -q "GNU GENERAL PUBLIC LICENSE" && grep -q "Version 2, June 1991" $B/drivers/COPYING && [ "$(grep -o "LC_ALL=C TZ=UTC date" $B/scripts/build-driver.sh | grep -c .)" = 4 ] && [ "$(grep -o "date -[rd]" $B/scripts/build-driver.sh | grep -c .)" = 4 ] && grep -q "log -1 --format=%ct -- drivers scripts/build-driver.sh" $B/scripts/build-driver.sh && grep -q "fetch-depth: 0" $B/.github/workflows/drivers.yml'
check "drivers/rtl88x2bu: 패치는 번호 차례(0001 보호, 0002 HAL 맞춤)이고 -p1 꼴, nx4 빌드는 모듈 이름 bcmdhd·iface_name을 ifname으로 받음" \
  '[ "$(ls $B/drivers/rtl88x2bu/*.diff | xargs -n1 basename | tr "\n" " ")" = "0001-nx4-protect.diff 0002-nx4-hal.diff " ] && ! grep -h "^+++ " $B/drivers/rtl88x2bu/*.diff | grep -v "^+++ b/" | grep -q . && grep -q "build_driver rtl88x2bu \"\$RTL88X2BU_COMMIT\" /work/nx4/rtl88x2bu bcmdhd .*\"\$EXPECTED_CFLAGS_SHA256\" EXTRA_CFLAGS \$P1" $B/drivers/build-in-container.sh && grep -q "module_param_named(iface_name, ifname" $B/drivers/rtl88x2bu/0002-nx4-hal.diff && grep -q "module_param_string(firmware_path" $B/drivers/rtl88x2bu/0002-nx4-hal.diff'
# 3단계: RTL8831BU도 같은 커널 트리로, 모듈 이름 bcmdhd, 자기 지문으로, 패치 셋(보호·HAL·빌드)
P8=$B/drivers/rtl8831bu
check "drivers/rtl8831bu: 패치는 번호 차례(0001 보호, 0002 HAL 맞춤, 0003 빌드 맞춤)이고 -p1 꼴, nx4 빌드는 모듈 이름 bcmdhd·자기 지문·결과 tcc803x/rtl8831bu" \
  '[ "$(ls $P8/*.diff | xargs -n1 basename | tr "\n" " ")" = "0001-nx4-protect.diff 0002-nx4-hal.diff 0003-nx4-build.diff " ] && ! grep -h "^+++ " $P8/*.diff | grep -v "^+++ b/" | grep -q . && grep -q "build_driver rtl8831bu \"\$RTL8831BU_COMMIT\" /work/nx4/rtl8831bu bcmdhd .*\"\$EXPECTED_CFLAGS_SHA256_8831BU\" USER_EXTRA_CFLAGS \$P2" $B/drivers/build-in-container.sh && grep -q "report_driver rtl8831bu" $B/drivers/build-in-container.sh && grep -q "get_driver rtl8831bu \"\$RTL8831BU_GIT\" \"\$RTL8831BU_COMMIT\"" $B/drivers/build-in-container.sh && grep -q "cat out/drivers/tcc803x/rtl8831bu/bcmdhd.ko.txt" $B/.github/workflows/drivers.yml'
check "drivers/rtl8831bu: HAL 인자(iface_name을 ifname으로, firmware_path·nvram_path는 받아 두기만), 빌드 맞춤(디버그 로그 끔, rtw_warn_on_cnt를 ATOMIC_INC에 넘기지 않음)" \
  'grep -q "^+module_param_named(iface_name, ifname, charp, 0644);" $P8/0002-nx4-hal.diff && grep -q "^+module_param_string(firmware_path" $P8/0002-nx4-hal.diff && grep -q "^+module_param_string(nvram_path" $P8/0002-nx4-hal.diff && grep -q "^+CONFIG_RTW_DEBUG = n$" $P8/0003-nx4-build.diff && grep -q "^-CONFIG_RTW_DEBUG = y$" $P8/0003-nx4-build.diff && grep -q "^-		ATOMIC_INC((ATOMIC_T \*)&rtw_warn_on_cnt);" $P8/0003-nx4-build.diff && grep -q "^+		rtw_warn_on_cnt++;" $P8/0003-nx4-build.diff'
# 리뷰 81-1: 3.18에 없는 strscpy를 부르지 않게(drv_conf.h의 strlcpy→strscpy 정의를 빼고 os_intfs.c 다섯 곳을 strlcpy로)
check "drivers/rtl8831bu 빌드 맞춤: strlcpy를 strscpy로 바꾸던 정의를 빼고, rtw_ethtool_get_drvinfo의 strscpy 다섯 곳을 strlcpy로" \
  'grep -q "^-#define strlcpy(a, b, c) strscpy(a, b, c)$" $P8/0003-nx4-build.diff && [ "$(grep -c "^+[[:space:]]*strlcpy(info->" $P8/0003-nx4-build.diff)" = 5 ] && [ "$(grep -c "^-[[:space:]]*strscpy(info->" $P8/0003-nx4-build.diff)" = 5 ] && ! grep -q "^+[[:space:]]*strscpy(" $P8/0003-nx4-build.diff'
check "drivers/rtl8831bu 보호 패치: 뽑힘 때 USB_STATE_NOTATTACHED면 먼저 surprise removed, 열기 거부(-ENODEV), 수신 오류 1초 100번이면 surprise removed·drv stopped, 기록은 printk, 되살리기는 모듈 다시 올리기" \
  '[ "$(grep -c "^+.*interface_to_usbdev(pusb_intf)->state == USB_STATE_NOTATTACHED" $P8/0001-nx4-protect.diff)" = 1 ] && grep -q "^+		dev_set_surprise_removed(dvobj);" $P8/0001-nx4-protect.diff && grep -q "^+		return -ENODEV;" $P8/0001-nx4-protect.diff && grep -q "^+#define NX4_RXERR_LIMIT 100$" $P8/0001-nx4-protect.diff && [ "$(grep -c "^+		nx4_rx_error_flood(dvobj);" $P8/0001-nx4-protect.diff)" = 1 ] && grep -q "^+	dev_set_drv_stopped(d);" $P8/0001-nx4-protect.diff && ! grep -q "^+.*RTW_PRINT" $P8/0001-nx4-protect.diff && [ "$(grep -c "^+.*printk(KERN_[A-Z]* \"nx4-protect: " $P8/0001-nx4-protect.diff)" = 3 ] && grep -q "되살리려면 모듈을 다시 올린다" $P8/0001-nx4-protect.diff && grep -q "두 드라이버와 자리 하나" $B/drivers/README.md'
# 리뷰 81-3: phl은 오류 뒤 다시 걸지 않는다(성공·INVALID_PARAM 뒤에만). 수신이 기록 없이 멈출 수 있다고 적고 차 확인에 둔다
check "drivers/rtl8831bu 보호 패치·README: 수신 설명이 phl 동작(오류 뒤 다시 걸지 않아 요청이 줄어 멈춤)과 맞고, 기록 없이 멈추는지 차 확인에 있음" \
  'grep -q "다시 걸지 않는다(phl_pend_rxbuf_usb는" $P8/0001-nx4-protect.diff && ! grep -q "phl이 수신 요청을 다시 건다" $P8/0001-nx4-protect.diff && grep -q "수신이 기록 없이 멈춥니다" $B/drivers/README.md && grep -q "RTL8831BU: \`nx4-protect:\` 줄 없이 수신만 멈추는지" $B/drivers/README.md'
# 보호 패치의 네 곳(drivers/README.md "보호 패치")과 기록 방식(RTW_PRINT는 CONFIG_RTW_DEBUG=n이면 컴파일되지 않아 printk)
PD=$B/drivers/rtl88x2bu/0001-nx4-protect.diff
check "drivers 보호 패치: 뽑힘 때 USB_STATE_NOTATTACHED면 먼저 surprise removed, 풀기 전 tasklet_kill 둘, 열기 거부(-ENODEV), 수신 오류 1초 100번이면 다시 걸지 않음(두 곳), 기록은 printk" \
  '[ "$(grep -c "^+.*interface_to_usbdev(pusb_intf)->state == USB_STATE_NOTATTACHED" $PD)" = 1 ] && [ "$(grep -c "^+	tasklet_kill(&padapter->\(recvpriv.recv\|xmitpriv.xmit\)_tasklet);" $PD)" = 2 ] && grep -q "^+		return -ENODEV;" $PD && grep -q "^+#define NX4_RXERR_LIMIT 100$" $PD && [ "$(grep -c "^+			if (!nx4_rx_error_flood(padapter))" $PD)" = 2 ] && ! grep -q "^+.*RTW_PRINT" $PD && [ "$(grep -c "^+.*printk(KERN_[A-Z]* \"nx4-protect: " $PD)" = 3 ]'
# 리뷰 21: 수신 오류로 멈춘 뒤 되살리는 길은 모듈 다시 올리기(netdev_close가 rtw_dev_unload를 부르지 않아 down/up으로는 안 됨)
check "drivers 보호 패치·README: 수신 오류로 멈춘 뒤 되살리기는 모듈 다시 올리기(Wi-Fi 끄고 켜기 등), 인터페이스 down/up으로 되살아난다고 적지 않음" \
  'grep -q "^+ \* 수신을 다시 걸지 않는다. 되살리려면 모듈을 다시 올린다" $PD && grep -q "인터페이스를 내렸다 올려서는 되살아나지 않는다" $PD && ! grep -q "다시 열려 되살아난다\|인터페이스를 내렸다 올리거나" $PD $B/drivers/README.md && grep -q "되살리려면 모듈을 다시 올립니다" $B/drivers/README.md'
check "drivers: README·NOTICE의 값(커널 뼈대·모비스 원본·자산·폴더 값, 설정 값, 툴체인, 컴파일 옵션 지문, 드라이버 커밋)이 inputs.sh와 같음" 'drv_docs_ok'
# 리뷰 15·19·20: 판정 두 줄 자체와 끝 알림(nx4 빌드일 때), 정보 파일의 (emulated: …), README 규칙
check "drivers: 차에 넣을 .ko는 CI 것만 — build-driver.sh가 빌드한 CPU를 넘기고 x86_64가 아니면 알림, 정보 파일에 build host, README에 규칙" \
  'grep -q -- "-e HOST_ARCH=\"\$HOST_ARCH\" -e BUILD_EMU=\$EMU" $B/scripts/build-driver.sh && grep -q "docker info --format .{{.Architecture}}." $B/scripts/build-driver.sh && grep -q "^\[ \"\$(sysctl -n hw.optional.arm64 2>/dev/null)\" = 1 \] && EMU=yes" $B/scripts/build-driver.sh && grep -q "^case \"\$DARCH\" in x86_64|amd64) ;; \*) EMU=yes ;; esac" $B/scripts/build-driver.sh && grep -q "^  \"nx4 yes\") echo \"알림: .*이 .ko는 차에 넣지 마세요" $B/scripts/build-driver.sh && grep -q "(emulated: check against CI, do not ship)" $B/drivers/build-in-container.sh && grep -q "차에 넣을 \`.ko\`는 CI에서 만든 것만" $B/drivers/README.md'
check "drivers: 드라이버 쪽 문서·스크립트·CI와 NOTICE 드라이버 절에 Korea Projection·JMK 언급 없음" 'drv_noref_ok'
check "drivers: 커널 소스 자산 — build-driver.sh --src-asset, 원본 zip sha256·폴더 값 확인, 이름 차례·시각·소유자 고정 tar와 한 스레드 xz, 빌드는 받은 자산의 sha256과 푼 폴더 값을 확인" \
  'grep -q "^  --src-asset) MODE=src-asset ;;" $B/scripts/build-driver.sh && grep -q "sha_ok \$MOBIS_ZIP_SHA256" $B/drivers/build-in-container.sh && grep -q "\[ \"\$GOT\" = \"\$MOBIS_TREE_SHA256\" \]" $B/drivers/build-in-container.sh && grep -q -- "--sort=name --mtime=" $B/drivers/build-in-container.sh && grep -q "xz -9 -T1" $B/drivers/build-in-container.sh && grep -q "sha_ok \$MOBIS_SRC_SHA256" $B/drivers/build-in-container.sh && grep -q "tree_sum \$MS/\$MOBIS_DIR)\" = \"\$MOBIS_TREE_SHA256\"" $B/drivers/build-in-container.sh && grep -q "sha_ok \$TOOLCHAIN_SHA256" $B/drivers/build-in-container.sh'
check "drivers/kernel/prepare.sh: kernel.org 뼈대에 모비스 폴더를 tar로 덮고(toolchain 빼고) defconfig → 조정 → olddefconfig, 설정 값이 KCONFIG_SUM과 같아야 함" \
  'grep -q "tar -C \"\$MSRC\" --exclude=./toolchain -cf - . | tar -C \"\$K\" -xf -" $B/drivers/kernel/prepare.sh && grep -q "^M defconfig \"\$MOBIS_DEFCONFIG\"" $B/drivers/kernel/prepare.sh && grep -q -- "--disable USB_NET_CDC_NCM --disable USB_NET_CDC_SUBSET --disable USB_NET_NET1080" $B/drivers/kernel/prepare.sh && grep -q -- "--disable CC_STACKPROTECTOR_STRONG --enable CC_STACKPROTECTOR_REGULAR" $B/drivers/kernel/prepare.sh && grep -q "\[ \"\$GOT\" = \"\$KCONFIG_SUM\" \]" $B/drivers/kernel/prepare.sh'
# lib.sh kconfig_sum, config-sum.sh: 머리말·꺼진 줄·차례와 상관없이 값이 같으면 같음, 차 설정의 STRONG은 REGULAR로 봄
KS=$T/ks; mkdir -p $KS/d
printf '#\n# Linux/arm 3.18.24 Kernel Configuration\n#\nCONFIG_ARM=y\nCONFIG_CC_STACKPROTECTOR=y\nCONFIG_CC_STACKPROTECTOR_STRONG=y\n# CONFIG_CC_STACKPROTECTOR_REGULAR is not set\nCONFIG_LOCALVERSION="-tcc"\nCONFIG_HZ=100\n' > $KS/car.txt
printf 'CONFIG_HZ=100\n# CONFIG_CC_STACKPROTECTOR_STRONG is not set\nCONFIG_CC_STACKPROTECTOR_REGULAR=y\nCONFIG_LOCALVERSION="-tcc"\n\nCONFIG_CC_STACKPROTECTOR=y\nCONFIG_ARM=y\n# CONFIG_USB_NET_NET1080 is not set\n' > $KS/built.config
sed 's/^CONFIG_HZ=100$/CONFIG_HZ=200/' $KS/built.config > $KS/other.config
ksum() { bash -c '. "$1"; kconfig_sum "$2"' x $B/drivers/lib.sh "$1"; }
check "drivers/lib.sh kconfig_sum: 차 설정(STRONG, 머리말)과 빌드 설정(REGULAR, 다른 차례·꺼진 줄)이 같은 값, 값 하나가 다르면 다른 값" \
  '[ "$(ksum $KS/car.txt)" = "$(ksum $KS/built.config)" ] && [ "$(ksum $KS/car.txt)" != "$(ksum $KS/other.config)" ] && ksum $KS/car.txt | grep -qx "[0-9a-f]\{64\}"'
cp $B/drivers/lib.sh $B/drivers/config-sum.sh $KS/d/; sed "s/^KCONFIG_SUM=.*/KCONFIG_SUM=$(ksum $KS/car.txt)/" $DI > $KS/d/inputs.sh
(sh $KS/d/config-sum.sh $KS/built.config) > $KS/same.out 2>&1; echo $? > $KS/same.rc
(sh $KS/d/config-sum.sh $KS/other.config) > $KS/diff.out 2>&1; echo $? > $KS/diff.rc
check "drivers/config-sum.sh: 진단 기록 config.txt가 KCONFIG_SUM과 같으면 \"같음\"(0), 다르면 \"다름\"(3)" \
  '[ "$(cat $KS/same.rc)" = 0 ] && grep -q "^같음: " $KS/same.out && [ "$(cat $KS/diff.rc)" = 3 ] && grep -q "^다름: " $KS/diff.out' || cat $KS/same.out $KS/diff.out
# 리뷰 22: sha256sum이 없는 PC. 스크립트가 쓰는 도구만 둔 PATH로(sha256sum 없이) 돌린다
mkdir -p $KS/nb $KS/nb2
for _t in sed grep sort cut dirname; do ln -sf "$(command -v $_t)" $KS/nb/$_t; ln -sf "$(command -v $_t)" $KS/nb2/$_t; done
command -v shasum >/dev/null 2>&1 && ln -sf "$(command -v shasum)" $KS/nb/shasum
(env PATH=$KS/nb2 /bin/sh $KS/d/config-sum.sh $KS/built.config) > $KS/none.out 2>&1; echo $? > $KS/none.rc
check "drivers/config-sum.sh: sha256sum도 shasum도 없으면 \"다름\" 대신 세지 못한다고 멈춤(1)" \
  '[ "$(cat $KS/none.rc)" = 1 ] && grep -q "sha256sum도 shasum도 없어" $KS/none.out && ! grep -q "^다름" $KS/none.out' || cat $KS/none.out
(sh $KS/d/config-sum.sh $KS/d/inputs.sh) > $KS/nocfg.out 2>&1; echo $? > $KS/nocfg.rc
check "drivers/config-sum.sh: CONFIG_ 줄이 없는 파일은 설정 파일이 아니라고 멈춤(1, \"다름\"이 아님)" \
  '[ "$(cat $KS/nocfg.rc)" = 1 ] && grep -q "커널 설정 파일이 아닙니다" $KS/nocfg.out' || cat $KS/nocfg.out
if [ -e $KS/nb/shasum ]; then
  (env PATH=$KS/nb /bin/sh $KS/d/config-sum.sh $KS/built.config) > $KS/sha.out 2>&1; echo $? > $KS/sha.rc
  check "drivers/config-sum.sh: sha256sum이 없으면 shasum -a 256으로 세어 같은 결과(\"같음\")" \
    '[ "$(cat $KS/sha.rc)" = 0 ] && grep -q "^같음: " $KS/sha.out' || cat $KS/sha.out
fi
# 리뷰 81-2: lib.sh kernel_exports·check_ksyms. 가짜 커널 트리(EXPORT_SYMBOL 여러 꼴, .S, params.c의 STANDARD_PARAM_DEF)로
KX=$T/kx; mkdir -p $KX/k/kernel $KX/k/lib $KX/k/arch
printf 'EXPORT_SYMBOL(foo);\nEXPORT_SYMBOL_GPL( bar );\nint baz; /* EXPORT_SYMBOL(no_such) 같은 주석은 들어가도 됨 */\n' > $KX/k/lib/a.c
printf 'EXPORT_SYMBOL(__aeabi_x)\n' > $KX/k/arch/b.S
# 리뷰 81-5: EXPORT_PER_CPU_SYMBOL(_GPL)도 내보내는 것(SMP), EXPORT_UNUSED_SYMBOL은 이 설정에서 내보내지 않음
printf 'EXPORT_PER_CPU_SYMBOL(softnet_data);\nEXPORT_PER_CPU_SYMBOL_GPL(irq_regs);\nEXPORT_UNUSED_SYMBOL(unused_one);\n' > $KX/k/kernel/percpu.c
printf 'STANDARD_PARAM_DEF(int, int, "%%i", kstrtoint);\nSTANDARD_PARAM_DEF(uint, unsigned int, "%%u", kstrtouint);\n' > $KX/k/kernel/params.c
bash -c '. "$1"; kernel_exports "$2"' x $B/drivers/lib.sh $KX/k > $KX/exports.txt
printf 'foo\nbar\n__aeabi_x\nparam_ops_int\nparam_ops_uint\nfoo\n' > $KX/ok.txt
printf 'foo\nstrscpy\nparam_ops_int\n' > $KX/bad.txt
(bash -c '. "$1"; check_ksyms "$2" "$3"' x $B/drivers/lib.sh $KX/ok.txt $KX/exports.txt) > $KX/ok.out 2>&1; echo $? > $KX/ok.rc
(bash -c '. "$1"; check_ksyms "$2" "$3"' x $B/drivers/lib.sh $KX/bad.txt $KX/exports.txt) > $KX/bad.out 2>&1; echo $? > $KX/bad.rc
check "drivers/lib.sh kernel_exports: EXPORT_SYMBOL·EXPORT_SYMBOL_GPL(빈칸 포함)·.S·EXPORT_PER_CPU_SYMBOL(_GPL)의 이름과 STANDARD_PARAM_DEF의 param_ops_*를 정렬해 냄, EXPORT_UNUSED_SYMBOL은 넣지 않음" \
  'for n in __aeabi_x bar foo param_ops_int param_ops_uint softnet_data irq_regs; do grep -qx "$n" $KX/exports.txt || exit 1; done; ! grep -qx unused_one $KX/exports.txt && [ "$(LC_ALL=C sort -u $KX/exports.txt | cmp -s - $KX/exports.txt; echo $?)" = 0 ]' || cat $KX/exports.txt
check "drivers/lib.sh check_ksyms: 부르는 것이 모두 내보내는 것이면 통과(개수), 하나라도 없으면 그 이름을 보이고 실패" \
  '[ "$(cat $KX/ok.rc)" = 0 ] && grep -q "부르는 것 5개가 모두 커널이 내보내는 것" $KX/ok.out && [ "$(cat $KX/bad.rc)" != 0 ] && grep -q "커널이 내보내지 않는 심볼을 부릅니다.*strscpy" $KX/bad.out' || cat $KX/ok.out $KX/bad.out
check "drivers: 빌드는 드라이버마다 nm -u로 커널 심볼을 확인하고, 내보내는 이름 목록은 준비한 트리마다 한 번 만듦. README·차 확인에 Unknown symbol" \
  '! grep -q "\$K.stamp -nt \$K.exports" $B/drivers/build-in-container.sh && grep -q "check_ksyms /tmp/undef.txt \$K.exports" $B/drivers/build-in-container.sh && grep -q "\$TC/bin/arm-eabi-nm -u \$D/\$MNAME.ko" $B/drivers/build-in-container.sh && grep -q "kernel_exports \$K > \$K.exports.tmp" $B/drivers/build-in-container.sh && grep -q "\*\*커널 심볼 확인\*\*" $B/drivers/README.md && grep -q "dmesg에 \`Unknown symbol\`이 없는지" $B/drivers/README.md'
# .env.local의 NX4_DRV_DOCKER_CONTEXT: build-driver.sh가 이 빌드의 docker 명령에만 DOCKER_CONTEXT로 준다(명령 앞 값이 앞섬).
# 가짜 docker는 받은 DOCKER_CONTEXT를 적고 docker info에서 실패해, 스크립트가 그 앞에서 멈춘다
DX=$T/dx; mkdir -p $DX/bin
printf '#!/bin/sh\necho "ctx=${DOCKER_CONTEXT:-none}" >> %s/calls\nexit 1\n' $DX > $DX/bin/docker; chmod +x $DX/bin/docker
printf 'NX4_DRV_DOCKER_CONTEXT=ctx-from-file\n' > $DX/env
# 셸에 export된 값을 물려받지 않게 세 변수를 뺀다(리뷰 81-9)
dxrun() { rm -f $DX/calls; (env -u DOCKER_CONTEXT -u NX4_DRV_DOCKER_CONTEXT -u DOCKER_HOST PATH=$DX/bin:$PATH "$@" sh $B/scripts/build-driver.sh) > $DX/out 2>&1; echo $? > $DX/rc; }
dxrun NX4_ENV_FILE=$DX/env; cp $DX/calls $DX/calls.file 2>/dev/null; cp $DX/out $DX/out.file
dxrun NX4_ENV_FILE=$DX/env NX4_DRV_DOCKER_CONTEXT=ctx-cmd; cp $DX/calls $DX/calls.cmd 2>/dev/null
dxrun NX4_ENV_FILE=; cp $DX/calls $DX/calls.none 2>/dev/null
# 리뷰 81-7: DOCKER_HOST가 있으면 docker가 DOCKER_CONTEXT보다 먼저 쓰므로, context를 쓸 때는 알리고 멈춘다(docker를 부르지 않음).
# context가 없으면 DOCKER_HOST를 그대로 둔다
dxrun NX4_ENV_FILE=$DX/env DOCKER_HOST=unix:///nx4-test.sock; cp $DX/rc $DX/rc.host; cp $DX/out $DX/out.host; [ -e $DX/calls ] && cp $DX/calls $DX/calls.host
dxrun NX4_ENV_FILE= DOCKER_HOST=unix:///nx4-test.sock; cp $DX/calls $DX/calls.hostonly 2>/dev/null
check "scripts/build-driver.sh: .env.local의 NX4_DRV_DOCKER_CONTEXT를 이 빌드의 docker에만 DOCKER_CONTEXT로 줌(명령 앞 값이 앞섬, 없으면 셸 기본), 알림에 context, DOCKER_HOST가 있으면 알리고 멈춤" \
  '[ "$(cat $DX/rc.host)" = 1 ] && grep -q "DOCKER_HOST(unix:///nx4-test.sock)가 있어 NX4_DRV_DOCKER_CONTEXT(ctx-from-file)가 무시됩니다" $DX/out.host && [ ! -e $DX/calls.host ] && grep -qx "ctx=none" $DX/calls.hostonly && grep -qx "ctx=ctx-from-file" $DX/calls.file && grep -q "Docker context: ctx-from-file" $DX/out.file && grep -q "context ctx-from-file" $DX/out.file && grep -qx "ctx=ctx-cmd" $DX/calls.cmd && grep -qx "ctx=none" $DX/calls.none && ! grep -q "docker context use" $B/scripts/build-driver.sh && grep -q "^# NX4_DRV_DOCKER_CONTEXT=" $B/.env.example' || cat $DX/out.file $DX/calls.file
# --- scripts/qemu-dongle-test.sh(docs/qemu-dongle-test.md): QEMU에서 동글 테스트. 진짜 빌드·QEMU는 동글과 Docker가 있는 PC에서만
# 돌린다. 여기서는 인자·멈춤, 가짜 docker로 빌드 두 단계(같은 볼륨·이미지, 이 테스트 폴더, 드라이버), 가짜 qemu로 넘기는 인자와 기록을 본다
QX=$T/qx; mkdir -p $QX/bin $QX/noqemu $QX/out
qxrun() { (env -u DOCKER_CONTEXT -u NX4_DRV_DOCKER_CONTEXT -u DOCKER_HOST NX4_QEMU_OUT=$QX/out "$@" sh $B/scripts/qemu-dongle-test.sh $QARGS) > $QX/run.out 2>&1; echo $? > $QX/run.rc; }
QARGS=bogus; qxrun PATH=$QX/noqemu:$P0; cp $QX/run.out $QX/usage.out; cp $QX/run.rc $QX/usage.rc
QARGS=matrix; qxrun PATH=$QX/noqemu:$P0; cp $QX/run.out $QX/noq.out; cp $QX/run.rc $QX/noq.rc
# 가짜 qemu: 받은 인자를 적고, 게스트처럼 libusb 잡음·USB 목록·단계 줄을 찍는다. 가짜 docker: 인자와 context를 적고, 폴더 공유
# 확인(test -f, touch /out/.nx4-visible)은 QX_NOVIS·QX_NOOUT이 없으면 된 것처럼 한다
printf '#!/bin/sh\necho "$*" > %s/qemu.args\necho "qemu-system-arm: libusb_kernel_driver_active: -5 [NOT_FOUND]"\necho "1-1 0bda:b831 speed=480 802.11ax WLAN Adapter"\necho "== A. 차 HAL 인자 그대로(국가 코드 없음)"\necho "-- a149 결과: AP로 섬=yes, 가장 많이 붙은 기기 0개, 채널: 149 (5745 MHz)"\necho "== 끝"\n' $QX > $QX/bin/qemu-system-arm
cat > $QX/bin/docker <<'E'
#!/bin/sh
echo "ctx=${DOCKER_CONTEXT:-none} $*" >> @QX@/docker.calls
case "$*" in
  *"test -f /src/qemu/build-guest.sh"*) [ -z "${QX_NOVIS:-}" ]; exit $? ;;
  *"touch /out/.nx4-visible"*)
    if [ -z "${QX_NOOUT:-}" ]; then for a in "$@"; do case "$a" in *:/out) touch "${a%:/out}/.nx4-visible" ;; esac; done; fi ;;
esac
exit 0
E
sed -i.bak "s#@QX@#$QX#" $QX/bin/docker
# 멈춘 게스트 흉내: pidfile에 자기 pid를 쓰고 끝나지 않음(exec라 그 pid를 끝내면 출력도 끝남)
mkdir -p $QX/hang
printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do [ "$1" = -pidfile ] && echo $$ > "$2"; shift; done\necho "1-1 0bda:b831 speed=480 802.11ax WLAN Adapter"\necho "== A. 차 HAL 인자 그대로(국가 코드 없음)"\nexec sleep 60\n' > $QX/hang/qemu-system-arm
chmod +x $QX/bin/qemu-system-arm $QX/bin/docker $QX/hang/qemu-system-arm
QARGS=matrix; qxrun PATH=$QX/bin:$P0 NX4_QEMU_NOBUILD=1; cp $QX/run.out $QX/nofile.out; cp $QX/run.rc $QX/nofile.rc
: > $QX/out/zImage; for f in zImage rootfs.img bcmdhd.ko; do echo x > $QX/out/$f; done
QARGS=matrix; qxrun PATH=$QX/bin:$P0 NX4_QEMU_NOBUILD=1; cp $QX/run.out $QX/m.out; cp $QX/run.rc $QX/m.rc; cp $QX/qemu.args $QX/m.args
QARGS="interactive rtl88x2bu"; qxrun PATH=$QX/bin:$P0 NX4_QEMU_NOBUILD=1 NX4_QEMU_AP_SECS=45; cp $QX/run.out $QX/i.out; cp $QX/run.rc $QX/i.rc; cp $QX/qemu.args $QX/i.args
QARGS=matrix; qxrun PATH=$QX/bin:$P0 NX4_QEMU_NOBUILD=1 NX4_QEMU_USB=0BDA:B831; cp $QX/run.out $QX/badusb.out; cp $QX/run.rc $QX/badusb.rc
# 리뷰 93-1: 게스트가 멈추면 NX4_QEMU_TIMEOUT초 뒤 QEMU를 끝내고 알림, 게스트는 panic=1
QARGS=matrix; _t0=$(date +%s); qxrun PATH=$QX/hang:$QX/bin:$P0 NX4_QEMU_NOBUILD=1 NX4_QEMU_TIMEOUT=3; _t1=$(date +%s); cp $QX/run.out $QX/hang.out
# 리뷰 93-9: 본 스크립트를 TERM으로 끝내면 지킴이·QEMU가 남지 않음(뒤로 돌린 sh는 SIGINT를 무시하므로 TERM으로 본다).
# 파일 이름은 실행마다 달라(pid) 다른 실행의 QEMU를 건드리지 않는다
# env가 sh를 exec하므로 $!가 본 스크립트의 pid다
env -u DOCKER_CONTEXT -u NX4_DRV_DOCKER_CONTEXT -u DOCKER_HOST NX4_QEMU_OUT=$QX/out PATH=$QX/hang:$QX/bin:$P0 NX4_QEMU_NOBUILD=1 NX4_QEMU_TIMEOUT=100 sh $B/scripts/qemu-dongle-test.sh matrix > $QX/term.out 2>&1 &
_qs=$!
_i=0; while [ $_i -lt 20 ] && ! ls $QX/out/qemu.$_qs.pid >/dev/null 2>&1; do sleep 1; _i=$((_i + 1)); done
_qp=$(cat $QX/out/qemu.$_qs.pid 2>/dev/null)
kill -TERM $_qs 2>/dev/null; sleep 4
_qalive=no; [ -n "$_qp" ] && kill -0 "$_qp" 2>/dev/null && _qalive=yes
_qleft=$(pgrep -f "$B/scripts/qemu-dongle-test.sh matrix" | tr '\n' ' ')
_qfiles=$(ls $QX/out/qemu.* 2>/dev/null | tr '\n' ' ')
[ -n "$_qp" ] && kill "$_qp" 2>/dev/null
printf 'NX4_DRV_DOCKER_CONTEXT=ctx-qemu\n' > $QX/env
rm -f $QX/docker.calls
QARGS="matrix rtl88x2bu"; qxrun PATH=$QX/bin:$P0 NX4_ENV_FILE=$QX/env; cp $QX/run.rc $QX/b.rc; cp $QX/docker.calls $QX/b.calls
# 리뷰 93-7: Docker VM이 저장소·결과 폴더를 못 보면 멈춤, 결과 폴더는 절대 경로로
QARGS=matrix; qxrun PATH=$QX/bin:$P0 NX4_ENV_FILE=$QX/env QX_NOVIS=1; cp $QX/run.out $QX/novis.out; cp $QX/run.rc $QX/novis.rc
QARGS=matrix; qxrun PATH=$QX/bin:$P0 NX4_ENV_FILE=$QX/env QX_NOOUT=1; cp $QX/run.out $QX/noout.out; cp $QX/run.rc $QX/noout.rc
mkdir -p $QX/rel/out; for f in zImage rootfs.img bcmdhd.ko; do echo x > $QX/rel/out/$f; done
rm -f $QX/docker.calls
QARGS=matrix; (cd $QX/rel && env -u DOCKER_CONTEXT -u NX4_DRV_DOCKER_CONTEXT -u DOCKER_HOST PATH=$QX/bin:$P0 NX4_ENV_FILE=$QX/env NX4_QEMU_OUT=out sh $B/scripts/qemu-dongle-test.sh matrix) > $QX/rel.out 2>&1
check "scripts/qemu-dongle-test.sh: 모르는 모드는 쓰는 법, qemu-system-arm이 없으면 설치 안내, VID:PID 꼴 확인, 빌드 결과가 없으면 멈춤" \
  '[ "$(cat $QX/usage.rc)" = 1 ] && grep -q "쓰는 법: sh scripts/qemu-dongle-test.sh" $QX/usage.out && [ "$(cat $QX/noq.rc)" = 1 ] && grep -q "qemu-system-arm이 없습니다(맥: brew install qemu)" $QX/noq.out && [ "$(cat $QX/badusb.rc)" = 1 ] && grep -q "NX4_QEMU_USB는 VID:PID" $QX/badusb.out && [ "$(cat $QX/nofile.rc)" = 1 ] && grep -q "zImage가 없습니다" $QX/nofile.out' || cat $QX/usage.out $QX/noq.out $QX/nofile.out
check "  QEMU: virt(ARMv7)에 EHCI로 동글(드라이버별 기본 VID:PID)을 넘기고, MODE·AP·뽑기 초와 panic=1을 게스트에 줌. 기록에서 libusb 잡음은 거르고 단계 줄을 모아 보임" \
  '[ "$(cat $QX/m.rc)" = 0 ] && grep -q -- "-M virt,highmem=off -cpu cortex-a15" $QX/m.args && grep -q "device usb-ehci,id=ehci -device usb-host,bus=ehci.0,vendorid=0x0bda,productid=0xb831" $QX/m.args && grep -q "panic=1 init=/sbin/nx4init MODE=matrix AP_SECS=30 UNPLUG_SECS=90" $QX/m.args && grep -q -- "-pidfile $QX/out/qemu\.[0-9]*\.pid" $QX/m.args && [ "$(cat $QX/i.rc)" = 0 ] && ! ls $QX/out/qemu.* >/dev/null 2>&1 && grep -q "vendorid=0x0bda,productid=0xb812" $QX/i.args && grep -q "MODE=interactive AP_SECS=45" $QX/i.args && grep -q "폰에서 NX4-QEMU-TEST" $QX/i.out && ! grep -q libusb_kernel_driver_active $QX/out/console-matrix-*.log && grep -q "^-- a149 결과: AP로 섬=yes" $QX/m.out && ! grep -q "VM에 동글(0bda:b831)이 보이지 않았습니다" $QX/m.out && grep -q "VM에 동글(0bda:b812)이 보이지 않았습니다" $QX/i.out && ! grep -q "끝까지 돌지 못했습니다" $QX/m.out' || cat $QX/m.out $QX/m.args
check "  멈춘 게스트: NX4_QEMU_TIMEOUT초 뒤 QEMU를 끝내고 시간 제한과 \"== 끝\" 없음을 알림(리뷰 93-1)" \
  'grep -q "3초가 지나도 끝나지 않아 QEMU를 끝냈습니다" $QX/hang.out && grep -q "게스트가 끝까지 돌지 못했습니다" $QX/hang.out && [ $((_t1 - _t0)) -lt 30 ]' || cat $QX/hang.out
check "  본 스크립트를 TERM으로 끝내면 QEMU·지킴이가 남지 않고 실행마다 다른 이름의 파일도 지움(리뷰 93-9)" \
  '[ -n "$_qp" ] && [ "$_qalive" = no ] && [ -z "$_qleft" ] && [ -z "$_qfiles" ] && grep -q "PIDF=\$OUT/qemu.\$RUN.pid" $B/scripts/qemu-dongle-test.sh && grep -q "kill -0 \$RUN" $B/scripts/qemu-dongle-test.sh' || echo "  qemu=$_qp alive=$_qalive left=$_qleft files=$_qfiles"
check "  빌드: 드라이버 빌드와 같은 이미지·볼륨·context(.env.local NX4_DRV_DOCKER_CONTEXT)로 게스트 커널·드라이버(DRIVER, make 다시 돌리기 횟수), 루트 파일 시스템을 차례로. 게스트 쪽 파일은 drivers/ 밖(tests/qemu/)" \
  '[ "$(cat $QX/b.rc)" = 0 ] && grep -q "^ctx=ctx-qemu run .*-v nx4kor-drivers:/work .*/tests/qemu:/src/qemu:ro .*-e DRIVER=rtl88x2bu .*-e MAKE_TRIES=30 nx4kor-drvbuild bash /src/qemu/build-guest.sh" $QX/b.calls && grep -q "^ctx=ctx-qemu run .*/tests/qemu:/src/qemu:ro .*nx4kor-drvbuild sh /src/qemu/build-rootfs.sh" $QX/b.calls && [ "$(grep -n build-guest.sh$ $QX/b.calls | tail -1 | cut -d: -f1)" -lt "$(grep -n build-rootfs.sh $QX/b.calls | cut -d: -f1)" ] && [ ! -e $B/drivers/qemu ] && grep -q "^QEMU_APK_STATIC_SHA256=[0-9a-f]\{64\}$" $B/tests/qemu/inputs.sh && grep -q "^QEMU_ALPINE_KEYS_SHA256=[0-9a-f]\{64\}$" $B/tests/qemu/inputs.sh && grep -q "make_retry \$Q/zImage.log" $B/tests/qemu/build-guest.sh && grep -q "make_retry \$Q/\$DRIVER.log" $B/tests/qemu/build-guest.sh' || cat $QX/b.calls
check "  Docker VM이 저장소나 결과 폴더를 못 보면 멈추고, 상대 경로 결과 폴더는 절대 경로로 넘김(리뷰 93-7)" \
  '[ "$(cat $QX/novis.rc)" = 1 ] && grep -q "Docker가 이 저장소 폴더를 보지 못합니다" $QX/novis.out && [ "$(cat $QX/noout.rc)" = 1 ] && grep -q "결과 폴더(.*)에 쓴 파일이 이 PC에 보이지 않습니다" $QX/noout.out && grep -q -- "-v $QX/rel/out:/out" $QX/docker.calls && ! grep -q -- "-v out:/out" $QX/docker.calls' || cat $QX/novis.out $QX/noout.out $QX/rel.out
# 리뷰 93-4: 게스트의 AP 판정(ap_ok)을 가짜 pidof로 직접 본다: hostapd가 끝났으면 마지막이 AP여도 섬이 아님
sed -n '/^ap_ok() {/,/^}/p' $B/tests/qemu/nx4init > $QX/apok.sh
mkdir -p $QX/pyes $QX/pno
printf '#!/bin/sh\nexit 0\n' > $QX/pyes/pidof; printf '#!/bin/sh\nexit 1\n' > $QX/pno/pidof; chmod +x $QX/pyes/pidof $QX/pno/pidof
apok() { PATH=$1:$P0 sh -c '. "$1"; ap_ok "$2" && echo yes || echo no' x $QX/apok.sh "$2"; }
_ap="$(apok $QX/pyes ' type AP channel 149 (5745 MHz)')$(apok $QX/pno ' type AP channel 149 (5745 MHz)')$(apok $QX/pyes ' type managed channel 36 (5180 MHz)')$(apok $QX/pno '')"
check "  게스트 init: AP 판정은 끝까지 hostapd가 살아 있고 마지막 정보가 AP일 때만 섬(가짜 pidof로 넷: 살아 있음·AP=섬, 끝남·AP, 살아 있음·managed, 끝남·없음=아님)" \
  '[ "$_ap" = yesnonono ] && grep -q "if ap_ok \"\$t\"; then ok=yes; else ok=no; fi" $B/tests/qemu/nx4init' || echo "  $_ap"
check "  게스트 init: 차 HAL 인자 그대로 insmod, matrix는 국가 코드 없음·KR 채널 표와 5GHz 149번 AP 넷(HAL 인자만 + hostapd KR 포함), 결과 줄에 insmod·채널·rmmod(경고·멈춤 수)" \
  'grep -q "^HAL_ARGS=\"iface_name=wlan0 firmware_path=/data/misc/wifi/fw_bcmdhd.bin nvram_path=/data/misc/wifi/bcmdhd.cal clm_path=/system/wifi/89359.clm_blob\"" $B/tests/qemu/nx4init && grep -q "load B rtw_country_code=KR" $B/tests/qemu/nx4init && grep -q "ap a149hal a 149 \"\"" $B/tests/qemu/nx4init && grep -q "ap a149halkr a 149 KR" $B/tests/qemu/nx4init && grep -q "echo \"-- rmmod 결과(\$1): 종료 코드 \$rc, 경고" $B/tests/qemu/nx4init && grep -q "echo \"-- 채널 결과(\$1)" $B/tests/qemu/nx4init && grep -q "echo \"-- insmod 결과(" $B/tests/qemu/nx4init'
# lib.sh make_retry: 가짜 make. $MR/plan의 줄마다 한 번씩: segv(에뮬레이션 충돌 꼴, 실패 대상 둘: 상대 경로 호스트 도구와
# 절대 경로 .ko), err(다른 오류), ok. 부른 횟수는 $MR/calls
MR=$T/mr; mkdir -p $MR/bin $MR/k/scripts/dtc
cat > $MR/bin/make <<E
#!/bin/sh
n=\$(( \$(cat $MR/calls 2>/dev/null || echo 0) + 1 )); echo \$n > $MR/calls
case "\$(sed -n "\${n}p" $MR/plan)" in
  segv) echo "Segmentation fault (core dumped)"; echo "make[2]: *** [scripts/Makefile.host:108: scripts/dtc/flattree.o] Error 139"
        echo "make[2]: *** [scripts/Makefile.modpost:90: $MR/out/bcmdhd.ko] Error 4"; exit 2 ;;
  err) echo "foo.c:1: error: something"; exit 2 ;;
  *) echo built; exit 0 ;;
esac
E
chmod +x $MR/bin/make
mr() { rm -f $MR/calls; printf '%s\n' "$@" > $MR/plan; mkdir -p $MR/out; : > $MR/k/scripts/dtc/flattree.o; : > $MR/out/bcmdhd.ko
  (env PATH=$MR/bin:$PATH $MRX bash -c '. "$1"; make_retry "$2" "$3" -j2' x $B/drivers/lib.sh $MR/log $MR/k) > $MR/out.txt 2>&1; echo $? > $MR/rc; }
mr segv ok
check "drivers/lib.sh make_retry: 에뮬레이션 충돌(Segmentation fault)이면 실패한 대상(make 폴더 기준 상대 경로, 절대 경로 .ko)을 지우고 이어서 다시 돌려 성공" \
  '[ "$(cat $MR/rc)" = 0 ] && [ "$(cat $MR/calls)" = 2 ] && [ ! -e $MR/k/scripts/dtc/flattree.o ] && [ ! -e $MR/out/bcmdhd.ko ] && grep -q "다시 돌림(1번째 실패" $MR/out.txt && grep -q built $MR/log && grep -q "Segmentation fault" $MR/log' || cat $MR/out.txt
mr $(i=0; while [ $i -lt 30 ]; do printf 'segv '; i=$((i+1)); done) ok
check "drivers/lib.sh make_retry: 기본은 모두 30번까지(서른 번째도 충돌이면 실패)" '[ "$(cat $MR/rc)" = 1 ] && [ "$(cat $MR/calls)" = 30 ] && grep -q "모두 30번까지" $MR/out.txt' || cat $MR/out.txt
MRX=MAKE_TRIES=4; mr segv segv segv ok; MRX=
check "drivers/lib.sh make_retry: MAKE_TRIES(build-driver.sh NX4_DRV_TRIES, 기본 30)로 횟수를 바꿈" \
  '[ "$(cat $MR/rc)" = 0 ] && [ "$(cat $MR/calls)" = 4 ] && grep -q "모두 4번까지" $MR/out.txt && grep -q "MAKE_TRIES=\"\${NX4_DRV_TRIES:-30}\"" $B/scripts/build-driver.sh' || cat $MR/out.txt
mr err ok
check "drivers/lib.sh make_retry: 다른 오류는 다시 돌리지 않고 바로 실패, 대상은 지우지 않음" \
  '[ "$(cat $MR/rc)" = 1 ] && [ "$(cat $MR/calls)" = 1 ] && [ -e $MR/k/scripts/dtc/flattree.o ] && grep -q "error: something" $MR/out.txt' || cat $MR/out.txt
check "drivers/kernel/prepare.sh: 커널 준비의 make(defconfig, olddefconfig, modules_prepare)는 모두 make_retry로(리뷰 10·17)" \
  'grep -q "^M() { make_retry " $B/drivers/kernel/prepare.sh && grep -q "^M defconfig " $B/drivers/kernel/prepare.sh && grep -q "^M olddefconfig olddefconfig" $B/drivers/kernel/prepare.sh && grep -q "^M modules_prepare .*modules_prepare" $B/drivers/kernel/prepare.sh && ! grep -q "^ *make " $B/drivers/kernel/prepare.sh'
# lib.sh check_cflags(리뷰 14): 가짜 .cmd(첫 줄이 컴파일 명령)로
CF=$T/cf
cfrun() { (env $CFX bash -c '. "$1"; check_cflags "$2"' x $B/drivers/lib.sh $CF) > $CF.out 2>&1; echo $? > $CF.rc; }
cfobj() { mkdir -p $CF/$1; printf 'cmd_%s/x.o := /work/tc/bin/arm-eabi-gcc -Wp,-MD,%s/.x.o.d -O2 %s -fno-common -Wall -c -o %s/x.o %s/x.c\n' $CF/$1 $CF/$1 "$2" $CF/$1 $CF/$1 > $CF/$1/.x.o.cmd; }
rm -rf $CF; cfobj a "-march=armv7-a -mabi=aapcs-linux"; cfobj b "-march=armv7-a -mabi=aapcs-linux"
printf 'cmd_%s/built-in.o := arm-eabi-ld -EL -r -o built-in.o a.o\n' $CF > $CF/.built-in.o.cmd
cfrun
check "drivers/lib.sh check_cflags: 모든 오브젝트의 옵션이 같고 -march=armv7-a면 통과(링크 .cmd·-Wp 경로는 보지 않음)" \
  '[ "$(cat $CF.rc)" = 0 ] && grep -q "오브젝트 2개가 같음, -march=armv7-a" $CF.out' || cat $CF.out
# 고정한 지문(inputs.sh EXPECTED_CFLAGS_SHA256, 리뷰 18): 같으면 통과, 모든 오브젝트가 똑같이 옵션 하나가 빠져 다르면 실패
CFS=$(sed -n 's/.*(\([0-9a-f]\{64\}\))$/\1/p' $CF.out)
CFX=EXPECTED_CFLAGS_SHA256=$CFS; cfrun
check "drivers/lib.sh check_cflags: 옵션 지문이 EXPECTED_CFLAGS_SHA256과 같으면 통과" '[ "$(cat $CF.rc)" = 0 ] && [ -n "$CFS" ]' || cat $CF.out
cfobj a "-march=armv7-a -mabi=aapcs-linux -fno-strict-overflow"; cfobj b "-march=armv7-a -mabi=aapcs-linux -fno-strict-overflow"; cfrun; CFX=
check "drivers/lib.sh check_cflags: 모든 오브젝트가 똑같이 옵션이 달라(서로는 같음) 지문이 고정 값과 다르면 실패하고 옵션 묶음을 보임" \
  '[ "$(cat $CF.rc)" != 0 ] && grep -q "컴파일 옵션 지문이 고정한 값과 다릅니다" $CF.out && grep -q "옵션 묶음: .*-fno-strict-overflow" $CF.out' || cat $CF.out
cfobj a "-march=armv7-a -mabi=aapcs-linux"; cfobj b "-march=armv7-a -mabi=aapcs-linux"
cfobj b "-march=armv5t -Wa,-march=armv7-a -mabi=aapcs-linux"; cfrun
check "drivers/lib.sh check_cflags: 한 오브젝트라도 옵션이 다르면(cc-option이 armv5t로 넘어감) 실패" \
  '[ "$(cat $CF.rc)" != 0 ] && grep -q "오브젝트마다 컴파일 옵션이 다릅니다" $CF.out' || cat $CF.out
cfobj a "-march=armv5t -Wa,-march=armv7-a -mabi=aapcs-linux"; cfrun
check "drivers/lib.sh check_cflags: 모두 같아도 armv7-a가 아니면 실패" \
  '[ "$(cat $CF.rc)" != 0 ] && grep -q "\-march=armv7-a가 아닙니다" $CF.out' || cat $CF.out

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
  # HMG-API 엔진의 훅 계획(#67): 이 모드와 공식 무선 모드 v2.2.0-rc.9(그 훅 선언, tests/fixtures)를 NX4 map(차에서 만든 393점)에 함께 올린다.
  # 같은 지점을 둘 다 replace할 때만 뒤쪽이 꺼지므로(HookPlan), 우리 change·observe는 공식 모드와 함께 올라와야 한다
  javac --release 8 -Xlint:-options -nowarn -cp $T/eh -d $T/eh $B/tests/tools/HookPlanCheck.java 2>/dev/null
  hpc() { java -cp $T/eh HookPlanCheck "$1" $B/tests/fixtures/wireless-carplay-aa-2.2.0-rc.9-hooks.json $B/tests/fixtures/nx4-map-points.txt > $T/hp.out 2>&1; echo $? > $T/hp.rc; }
  hpc $PKG/mod.json
  check "HMG-API 훅 계획: NX4 map에서 이 모드와 공식 무선 모드 rc.9가 함께 올라옴(거부 없음, 순서 nx4-kor 다음 wireless-carplay-aa, 계기판 8곳 change와 replace 함께, Stop은 observe 둘)" \
    '[ "$(cat $T/hp.rc)" = 0 ] && grep -qx "order \[nx4-kor, wireless-carplay-aa\]" $T/hp.out && [ "$(grep -c "^hooks    framework.navigation_cluster.update_[a-z0-9_]*: nx4-kor (change), wireless-carplay-aa (replace) share it$" $T/hp.out)" = 8 ] && grep -qx "hooks    dipo.iap2_proxy.stop_route_guidance: nx4-kor (observe), wireless-carplay-aa (observe) share it" $T/hp.out && ! grep -q "won.t load" $T/hp.out' || cat $T/hp.out
  # 이 테스트가 막아야 할 것을 막는지: 우리가 계기판 한 곳을 replace로 걸면 공식 모드가 통째로 꺼진다
  python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); m["hooks"]["points"]["framework.navigation_cluster.update_tbt_info"]="replace"; json.dump(m, open(sys.argv[2],"w"))' $PKG/mod.json $T/mod-replace.json
  hpc $T/mod-replace.json
  check "  우리가 한 곳이라도 replace로 걸면 공식 무선 모드가 꺼짐(HookPlan이 거부, 이 테스트가 잡음)" \
    '[ "$(cat $T/hp.rc)" != 0 ] && grep -q "^hooks    wireless-carplay-aa won.t load: .*both replace" $T/hp.out' || cat $T/hp.out
  # 이 차의 map에 없는 지점을 걸면 우리 훅이 올라오지 않는다(map에 있는지는 위 393점으로 본다)
  python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); m["hooks"]["points"]["dipo.no_such_point"]="observe"; json.dump(m, open(sys.argv[2],"w"))' $PKG/mod.json $T/mod-nopoint.json
  hpc $T/mod-nopoint.json
  check "  NX4 map에 없는 지점을 걸면 이 모드의 훅이 올라오지 않음(그래서 위 9점이 모두 map에 있어야 함)" \
    '[ "$(cat $T/hp.rc)" != 0 ] && grep -q "^hooks    nx4-kor won.t load: " $T/hp.out' || cat $T/hp.out
  # ClusterOut(#77)의 메서드마다 건너뛰기에 쓰는 지점 이름이 HMG-API Cluster가 그 메서드로 부르는 지점과 같은지(PR #78 리뷰 2)
  check "  ClusterOut의 메서드 8개가 HMG-API Cluster와 같은 지점 이름으로 건너뛰기를 봄" 'python3 - "$HS/core/runtime/java/hmgapi/hook/Cluster.java" "$B/hooks/src/io/github/jayparklab/nx4kor/hook/dipo/ClusterOut.java" <<PY
import re, sys
cl, out = open(sys.argv[1]).read(), open(sys.argv[2]).read()
want = {}
for name, body in re.findall(r"\n    public void (\w+)\((.*?)\n    }\n", cl, re.S):
    pts = re.findall(r"call\(\"(update_[a-z0-9_]+)\"", body)
    if pts: want[name] = pts[0]
got = {}
for name, body in re.findall(r"\n    void (\w+)\((.*?)\n    }\n", out, re.S):
    got[name] = re.findall(r"skip\(\"(update_[a-z0-9_]+)\"", body)[0]
assert got and all(want.get(k) == v for k, v in got.items()), (got, want)
PY'
  # hooks.jar(#67): ANDROID_HOME이 있으면 scripts/build-hooks.sh로 진짜로 만든다. 없으면 빌드 시험은 자리만 채운 파일로 본다
  if [ -n "$ANDROID_HOME" ]; then
    (HMGAPI_SRC=$HS ANDROID_HOME=$ANDROID_HOME sh $B/scripts/build-hooks.sh $T/hooks.jar) > $T/hooks.out 2>&1; echo $? > $T/hooks.rc
    check "build-hooks: hooks.jar를 만듦(hooks/src를 HMG-API 런타임에 대고 컴파일, d8)" '[ "$(cat $T/hooks.rc)" = 0 ] && [ -s $T/hooks.jar ]' || cat $T/hooks.out
    DD=$(ls -d "$ANDROID_HOME"/build-tools/*/ | sort -t/ -k1 -V | tail -n 1)dexdump
    if [ -x "$DD" ]; then
      "$DD" $T/hooks.jar 2>/dev/null | sed -n "s/^ *Class descriptor *: '\(.*\)'$/\1/p" > $T/hooks.classes
      check "  hooks.jar 덱스에는 우리 클래스만(HMG-API 런타임·iAP2 스텁 없음), 진입 클래스와 DiPO 부분이 있음" \
        '[ -s $T/hooks.classes ] && ! grep -v "^Lio/github/jayparklab/nx4kor/hook/" $T/hooks.classes && grep -qx "Lio/github/jayparklab/nx4kor/hook/Nx4KorHooks;" $T/hooks.classes && grep -qx "Lio/github/jayparklab/nx4kor/hook/dipo/KorTbt;" $T/hooks.classes && grep -qx "Lio/github/jayparklab/nx4kor/hook/dipo/CpTurnsFit;" $T/hooks.classes' || cat $T/hooks.classes
    fi
    # KP 2.4.10에서 더해진 곧 회전 그림 판단(회전교차로 32, 각도 없는 진입 램프, 지하차도·고가)과 CpIcons를 PC에서 돌린다(PR #74 리뷰 6).
    # hooks/src를 build-hooks.sh와 같은 클래스 경로(android.jar, HMG-API 런타임·스텁, iAP2 스텁)로 컴파일한다
    AJ=$(ls "$ANDROID_HOME"/platforms/*/android.jar 2>/dev/null | head -n 1)
    F=$T/fit
    mkdir -p $F/rtstubs $F/rt $F/stubs $F/classes
    ( set -e
      J="javac --release 8 -Xlint:-options -nowarn -encoding UTF-8"
      $J -cp "$AJ" -d $F/rtstubs $(find "$HS/core/runtime/stubs" -name '*.java')
      $J -cp "$AJ:$F/rtstubs" -d $F/rt $(find "$HS/core/runtime/java" -name '*.java')
      $J -cp "$AJ" -d $F/stubs $(find "$B/hooks/stubs" -name '*.java')
      $J -cp "$AJ:$F/rt:$F/rtstubs:$F/stubs" -d $F/classes $(find "$B/hooks/src" -name '*.java') $B/tests/tools/NearFitTest.java
      java -cp "$AJ:$F/rt:$F/rtstubs:$F/stubs:$F/classes" io.github.jayparklab.nx4kor.hook.dipo.NearFitTest ) > $T/fit.out 2>&1
    check "  곧 회전 그림(KP 2.4.10)과 곧 회전 거리 $(grep -c '^ok ' $T/fit.out)개: 회전교차로 32는 오른쪽 통행·출구 각도 있을 때만(들어가기 6은 그대로), 각도 없는 진입 램프는 오른쪽 진입 모양, 지하차도 46(좌·우)·고가 44(왼쪽만)는 시설 낱말이 있고 부정·옆길 낱말이 없을 때만, CpIcons, 곧 회전 거리(near() 직접: 일반 600m, 나갈 때 650m, 고속도로 출구 1050m, 막대 60m마다)" \
      'tail -n 1 $T/fit.out | grep -qx ok && ! grep -q "^FAIL" $T/fit.out' || cat $T/fit.out
  else
    echo "skip hooks.jar 빌드·곧 회전 그림 테스트(NearFitTest)(ANDROID_HOME 없음): 빌드 시험은 자리만 채운 hooks.jar로 봄"
    echo "placeholder hooks.jar" > $T/hooks.jar
  fi
  # 공식 무선 모드는 위 가짜 zip을 준다(받지 않음). 받는 길은 아래 NX4_WIRELESS_URL 테스트에서 본다
  bld() { (HMGAPI_SRC=$HS NX4_MOD_KEY=$T/test-mod.key NX4_APK=$T/test.apk NX4_HOOKS_JAR=$T/hooks.jar HMGAPI_USB_ZIP=$T/hmgapi-usb.zip NX4_WIRELESS_ZIP=$WZF "$@" sh $B/scripts/build.sh) > $T/build.out 2>&1; echo $? > $T/build.rc; }
  # hooks.jar를 받지 않았고 만들 수도 없으면(ANDROID_HOME 없음) 묶음을 만들지 않는다
  bld env -u NX4_HOOKS_JAR -u ANDROID_HOME NX4_BUSYBOX=$T/test-bb OUT=$T/out-nohooks
  check "빌드: hooks.jar를 만들지 못하면(ANDROID_HOME 없음) 묶음을 만들지 않음" \
    '[ "$(cat $T/build.rc)" != 0 ] && grep -q "hooks.jar를 만들지 못했습니다" $T/build.out && [ ! -f $T/out-nohooks/hmgapi-nx4-kor-$V.zip ]' || cat $T/build.out
  # busybox(GPL-2.0)를 넣는데 그 라이선스 안내가 없으면 만들지 않는다
  bld env NX4_BUSYBOX=$T/test-bb OUT=$T/out-nolic
  check "빌드: busybox를 넣는데 라이선스 안내가 없으면 만들지 않음" '[ "$(cat $T/build.rc)" != 0 ] && grep -q "라이선스 안내" $T/build.out && [ ! -f $T/out-nolic/hmgapi-nx4-kor-$V-usb.zip ]'
  echo "BusyBox GPL-2.0 test notice" > $T/test-bb-LICENSE.txt
  bld env NX4_BUSYBOX=$T/test-bb OUT=$T/out
  check "빌드: 모드 zip과 USB 묶음을 만듦, 받은 hooks.jar(NX4_HOOKS_JAR)를 넣었다고 찍음" '[ "$(cat $T/build.rc)" = 0 ] && [ -f $T/out/hmgapi-nx4-kor-$V.zip ] && [ -f $T/out/hmgapi-nx4-kor-$V-usb.zip ] && grep -q "hooks.jar는 NX4_HOOKS_JAR($T/hooks.jar)를 넣었습니다" $T/build.out' || cat $T/build.out
  rm -rf $T/ux; mkdir -p $T/ux; (cd $T/ux && unzip -q $T/out/hmgapi-nx4-kor-$V-usb.zip)
  check "USB 묶음: HMG-API 앱용 업데이트·공식 모드 묶음(HMGAPI/updates)은 넣지 않음, HMGAPI-SOURCE.txt에 뺀 것을 적음" \
    '[ ! -e $T/ux/HMGAPI/updates ] && grep -q "HMGAPI/updates" $T/ux/HMGAPI-SOURCE.txt'
  check "USB 묶음: ota_package.tar = 우리 troubleShooter(0755, root), HMG-API 설치기는 NX4/hmgapi로, NEMESIS.data 뺌, README 판 채움" \
    'python3 -c "import tarfile,sys; t=tarfile.open(sys.argv[1]); m=t.getmembers(); assert [x.name for x in m]==[\"troubleShooter\"] and m[0].mode==0o755 and m[0].uid==0; assert t.extractfile(\"troubleShooter\").read()==open(sys.argv[2],\"rb\").read()" $T/ux/ota_package.tar $B/usb/troubleShooter && grep -q "HMG-API troubleShooter" $T/ux/NX4/hmgapi/troubleShooter && [ ! -f $T/ux/NEMESIS.data ] && [ -d $T/ux/HMGAPI/install/payload ] && grep -q "NX4 KOR $V" $T/ux/README.txt'
  P=$T/ux/NX4/install/payload
  check "USB 묶음: payload = 서명된 모드를 푼 것(mod.json, settings.json, 스크립트, 앱, hooks.jar, busybox, 서명), 훅 소스·한국 포크 무선 부분(레시피·패치)·핫스팟 서비스 없음" \
    '[ -f $P/mod.json ] && cmp -s $P/settings.json $PKG/settings.json && [ -f $P/svc/launch.sh ] && [ -f $P/svc/lib.sh ] && [ -f $P/bin/status.sh ] && [ -f $P/bin/uninstall.sh ] && [ -f $P/scripts/preun.sh ] && [ -f $P/app/NX4KOR.apk ] && cmp -s $P/hooks.jar $T/hooks.jar && [ -f $P/bin/busybox ] && [ -d $P/META-HMGAPI ] && [ ! -e $P/src ] && [ ! -e $P/stubs ] && [ ! -e $P/recipes ] && [ ! -e $P/files ] && [ ! -e $P/patches.json ] && [ ! -e $P/svc/ap.sh ] && [ ! -e $P/svc/hotspot.sh ] && [ ! -d $P/hmgapi ] && [ ! -d $P/patches ]'
  check "라이선스: 모드에 LICENSE·NOTICE.md·bin/busybox-LICENSE.txt, USB 맨 위에 LICENSE·NOTICE.md·BUSYBOX-LICENSE.txt(저장소와 같은 내용)" \
    'cmp -s $P/LICENSE $B/LICENSE && cmp -s $P/NOTICE.md $B/NOTICE.md && cmp -s $P/bin/busybox-LICENSE.txt $T/test-bb-LICENSE.txt && cmp -s $T/ux/LICENSE $B/LICENSE && cmp -s $T/ux/NOTICE.md $B/NOTICE.md && cmp -s $T/ux/BUSYBOX-LICENSE.txt $T/test-bb-LICENSE.txt'
  check "USB 묶음: 공식 무선 모드 zip 그대로(NX4/wireless/wireless-carplay-aa.zip)와 그 mod.json, WIRELESS-SOURCE.txt(판·SHA-256·대응 소스·AGPL-3.0)" \
    'cmp -s $T/ux/NX4/wireless/wireless-carplay-aa.zip $WZF && cmp -s $T/ux/NX4/wireless/mod.json $WM/mod.json && grep -q "^공식 무선 모드 wireless-carplay-aa $WV:" $T/ux/WIRELESS-SOURCE.txt && grep -q "$(sha256 $WZF)" $T/ux/WIRELESS-SOURCE.txt && grep -q "hmgapi-wireless-cp-aa/tree/v$WV" $T/ux/WIRELESS-SOURCE.txt && grep -q "AGPL-3.0" $T/ux/WIRELESS-SOURCE.txt' || ls -R $T/ux
  # 옛 2.0.x 되돌리기(NX4/legacy-2.0): 태그 v2.0.4-beta.1의 파일 그대로
  legcmp() { for f in bin/uninstall.sh scripts/preun.sh svc/env.sh svc/hotspot.sh mod.json; do (cd $B && git show v2.0.4-beta.1:mod/$f) | cmp -s - $T/ux/NX4/legacy-2.0/$f || return 1; done; grep -q "^v2.0.4-beta.1 [0-9a-f]\{7,\}$" $T/ux/NX4/legacy-2.0/SOURCE; }
  check "USB 묶음: 옛 2.0.x 되돌리기(NX4/legacy-2.0)는 태그 v2.0.4-beta.1의 uninstall.sh·preun.sh·env.sh·hotspot.sh·mod.json 그대로, SOURCE에 태그와 커밋" 'legcmp' || ls -R $T/ux/NX4
  check "라이선스: HMG-API를 함께 넣으면 HMGAPI-SOURCE.txt에 판과 대응 소스(태그), README.txt에 이 묶음의 소스 커밋" \
    'grep -q "^HMG-API 1.1.0:" $T/ux/HMGAPI-SOURCE.txt && grep -q "https://github.com/Open-HMG/HMG-API/tree/v1.1.0" $T/ux/HMGAPI-SOURCE.txt && grep -q "AGPL-3.0" $T/ux/HMGAPI-SOURCE.txt && grep -q "https://github.com/jay-park-lab/hmgapi-nx4-kor (이 묶음: [0-9a-f]\{7,\}" $T/ux/README.txt && ! grep -q "@SOURCE_REV@" $T/ux/README.txt'
  check "모드 zip: 앱 메뉴 타일 그림 넷(icons/)이 저장소의 mod/icons 그대로 들어감" 'python3 - $T/out/hmgapi-nx4-kor-$V.zip $PKG/icons <<PY
import os, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for n in ("icon.png", "icon_night.png", "icon_disabled.png", "icon_disabled_night.png"):
    assert z.read("icons/" + n) == open(os.path.join(sys.argv[2], n), "rb").read(), n
PY'
  # 옛 2.0.x 되돌리기 스크립트를 꺼낼 태그가 없으면 만들지 않는다
  bld env NX4_BUSYBOX=$T/test-bb NX4_LEGACY_REF=v0.0.0-none OUT=$T/out-noleg
  check "빌드: 옛 2.0.x 되돌리기 스크립트를 꺼낼 git 태그가 없으면 만들지 않음" \
    '[ "$(cat $T/build.rc)" != 0 ] && grep -q "git 태그 v0.0.0-none에서 꺼내지 못했습니다" $T/build.out && [ ! -f $T/out-noleg/hmgapi-nx4-kor-$V-usb.zip ]' || cat $T/build.out
  # 공식 무선 모드가 아닌 zip(다른 id)은 넣지 않는다
  mkdir -p $T/notw; printf '{\n  "id": "other-mod",\n  "version": "1.0.0"\n}\n' > $T/notw/mod.json; (cd $T/notw && zip -q -r $T/notw.zip .)
  bld env NX4_BUSYBOX=$T/test-bb NX4_WIRELESS_ZIP=$T/notw.zip OUT=$T/out-notw
  check "빌드: NX4_WIRELESS_ZIP이 공식 무선 모드(id wireless-carplay-aa)가 아니면 만들지 않음" \
    '[ "$(cat $T/build.rc)" != 0 ] && grep -q "공식 무선 모드 zip이 아닙니다" $T/build.out && [ ! -f $T/out-notw/hmgapi-nx4-kor-$V-usb.zip ]' || cat $T/build.out
  # NX4_WIRELESS_ZIP을 주지 않으면 공식 릴리스에서 받는다: 받은 zip이 NOTICE.md의 SHA-256과 다르면 만들지 않는다(가짜 zip을 file://로)
  bld env -u NX4_WIRELESS_ZIP NX4_BUSYBOX=$T/test-bb NX4_WIRELESS_URL=file://$WZF OUT=$T/out-wfetch
  check "빌드: NX4_WIRELESS_ZIP이 없으면 공식 릴리스에서 받고, SHA-256이 NOTICE.md와 다르면 만들지 않음" \
    '[ "$(cat $T/build.rc)" != 0 ] && grep -q "공식 무선 모드 zip SHA-256.*다릅니다" $T/build.out && [ ! -f $T/out-wfetch/wireless/wireless-carplay-aa-$WV.zip ] && [ ! -f $T/out-wfetch/hmgapi-nx4-kor-$V-usb.zip ]' || cat $T/build.out
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
  (HMGAPI_SRC=$HS NX4_MOD_KEY=$T/test-mod.key NX4_APK=$T/test.apk NX4_HOOKS_JAR=$T/hooks.jar NX4_BUSYBOX=none NX4_WIRELESS_ZIP=$WZF OUT=$T/out-nobb sh $B/scripts/build.sh) > $T/build.out 2>&1; echo $? > $T/build.rc
  rm -rf $T/ux2; mkdir -p $T/ux2; (cd $T/ux2 && unzip -q $T/out-nobb/hmgapi-nx4-kor-$V-usb.zip 2>/dev/null)
  check "라이선스: NX4_BUSYBOX=none·HMG-API 없이 만들면 busybox·BUSYBOX-LICENSE.txt·HMGAPI-SOURCE.txt 없음, LICENSE·NOTICE.md는 있음" \
    '[ "$(cat $T/build.rc)" = 0 ] && grep -q "NX4_BUSYBOX=none" $T/build.out && [ ! -f $T/ux2/NX4/install/payload/bin/busybox ] && [ ! -f $T/ux2/BUSYBOX-LICENSE.txt ] && [ ! -f $T/ux2/NX4/install/payload/bin/busybox-LICENSE.txt ] && [ ! -f $T/ux2/HMGAPI-SOURCE.txt ] && [ -f $T/ux2/LICENSE ] && [ -f $T/ux2/NOTICE.md ]' || cat $T/build.out
  # HMG-API 엔진(PC JVM)으로 설치: 가짜 헤드유닛. 이 모드는 HMG-API 1.1.0-rc.10 이상을 요구한다(mod.json "hmgapi").
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
  check "HMG-API 엔진($HSV): NX4.KOR 260902에 설치됨(서명 확인), 서비스는 launch(root, manual)·nochip(root, boot), 앱이 등록됨, hooks.jar·settings.json이 있음, 무선 파일 없음" \
    '[ "$(cat $T/eng.rc)" = 0 ] && grep -q "installed nx4-kor $V (author key" $T/eng.out && [ "$(grep -c "^nx4-kor " $ER/data/hmgapi/state/services.txt)" = 2 ] && grep -q "^nx4-kor launch root manual " $ER/data/hmgapi/state/services.txt && grep -q "^nx4-kor nochip root boot no " $ER/data/hmgapi/state/services.txt && ! grep -q "^hmgapi vehicle " $ER/data/hmgapi/state/services.txt && grep -qx "io.github.jayparklab.nx4kor nx4-kor" $ER/data/hmgapi/state/apps.txt && cmp -s $ER/data/hmgapi/mods/nx4-kor/hooks.jar $T/hooks.jar && [ -f $ER/data/hmgapi/mods/nx4-kor/settings.json ] && [ ! -e $ER/data/hmgapi/mods/nx4-kor/recipes ]' || { cat $T/eng.out; cat $ER/data/hmgapi/state/services.txt; }
  engp() { (HMGAPI_ROOT=$ER HMGAPI_HOST=1 HMGAPI_PRODUCT=NX4.KOR.0000.V039.001.260902 java -cp $T/eh hmgapi.engine.Engine $1) > $T/engp.out 2>&1; echo $? > $T/engp.rc; }
  # 참고: $1은 따옴표 없이 넘겨 "remove nx4-kor"처럼 두 낱말도 받는다
  # 계획에는 지금 켜진 것의 설명 줄(app·service, HMG-API 기본 network  no cellular [nx4-kor] 등)만 나오고, 적용하면 할 것이 없다
  engp plan
  check "HMG-API 엔진 계획: 이 모드의 줄은 설명뿐(change·restore·setting 줄 없음), 문제 없음" \
    '[ "$(cat $T/engp.rc)" = 0 ] && ! grep -E "\[nx4-kor\]" $T/engp.out | grep -qvE "^(app|service|network) " && grep -q "^app .*io.github.jayparklab.nx4kor.*\[nx4-kor\]" $T/engp.out && ! grep -qiE "problem|conflict|requires" $T/engp.out' || cat $T/engp.out
  # USB 설치기의 계획 읽기(plan_check)가 이 HMG-API 엔진이 실제로 내는 계획 줄을 아는지: 이 모드만 설치한 계획은 설명 줄뿐이라
  # 할 일 없음, 모르는 줄 없음이어야 한다(PC에는 map이 없어 "hooks are off" 줄이 나오므로 훅 줄을 보지 않는 remove 꼴로 본다)
  pcreal() { sh -c 'MOD=nx4-kor; WMOD=wireless-carplay-aa; REMOVED=0; . "$1"; plan_check "$2" remove; echo "$P_TODO:$P_WHY"' x $T/pc.sh $T/engp.out; }
  check "USB 설치기 계획 읽기: HMG-API 엔진(PC)의 실제 계획(이 모드만 설치)을 할 일 없음으로 읽음(설명 줄뿐, 모르는 줄 없음)" '[ "$(pcreal)" = "0:" ]' || cat $T/engp.out
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
  echo "skip 빌드·HMG-API 엔진 시험·곧 회전 그림 테스트(NearFitTest)(HMGAPI_SRC 없음)"
fi

echo
if [ $fails = 0 ]; then echo "모두 통과"; else echo "실패 $fails개"; exit 1; fi
