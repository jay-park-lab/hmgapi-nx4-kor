#!/bin/sh
# NX4 KOR 모드의 hooks.jar를 만든다(#67, 한국 카플레이 길안내): hooks/src를 HMG-API 런타임(HMGAPI_SRC의 소스)에 대고
# 컴파일하고 d8로 덱스로 바꾼다. HMG-API tools/build-mod.sh와 같은 방법이다(컴파일용 스텁 hooks/stubs는 jar에 넣지 않음).
#   sh scripts/build-hooks.sh [나올 파일]     기본 out/hooks/hooks.jar
# 필요한 것: JDK, Android SDK(build-tools의 d8, platforms의 android.jar), HMG-API 소스.
# 경로는 명령 앞에 주거나 .env.local에 적는다(.env.example, scripts/local-env.sh):
#   ANDROID_HOME   Android SDK
#   HMGAPI_SRC     HMG-API 저장소(core/runtime/java, core/runtime/stubs)
set -e
B=$(cd "$(dirname "$0")/.." && pwd)
. "$B/scripts/local-env.sh"
nx4_env "$B"
nx4_need ANDROID_HOME "Android SDK 위치"
nx4_need HMGAPI_SRC "HMG-API 저장소 위치"
OUTJ=${1:-$B/out/hooks/hooks.jar}
case $OUTJ in /*) ;; *) OUTJ=$PWD/$OUTJ ;; esac
SDK=$ANDROID_HOME
HS=$(cd "$HMGAPI_SRC" && pwd)
[ -d "$HS/core/runtime/java/hmgapi/hook" ] || { echo "HMGAPI_SRC에 HMG-API 런타임(core/runtime/java)이 없습니다: $HS" >&2; exit 1; }
[ -d "$SDK/build-tools" ] || { echo "ANDROID_HOME에 build-tools가 없습니다: $SDK" >&2; exit 1; }
# 가장 높은 버전 (이름순이면 9.0.0이 34.0.0보다 뒤에 온다)
BT=$(ls -d "$SDK"/build-tools/*/ | sort -t/ -k1 -V | tail -n 1)
JAR=$(ls "$SDK"/platforms/*/android.jar 2>/dev/null | head -n 1)
[ -n "$JAR" ] || { echo "ANDROID_HOME에 platforms(android.jar)가 없습니다: $SDK" >&2; exit 1; }
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/rtstubs" "$W/rt" "$W/stubs" "$W/classes" "$W/dex"
J="javac --release 8 -Xlint:-options -nowarn -encoding UTF-8"
# HMG-API 런타임(컴파일용, jar에 넣지 않음): 차에서는 HMG-API가 같은 클래스를 올린다
$J -cp "$JAR" -d "$W/rtstubs" $(find "$HS/core/runtime/stubs" -name '*.java')
$J -cp "$JAR:$W/rtstubs" -d "$W/rt" $(find "$HS/core/runtime/java" -name '*.java')
# DiPO의 iAP2 라이브러리 시그니처(컴파일용, jar에 넣지 않음): 차에서는 DiPO의 클래스 로더에서 온다
$J -cp "$JAR" -d "$W/stubs" $(find "$B/hooks/stubs" -name '*.java')
$J -cp "$JAR:$W/rt:$W/rtstubs:$W/stubs" -d "$W/classes" $(find "$B/hooks/src" -name '*.java')
"$BT/d8" --release --min-api 19 --lib "$JAR" --classpath "$W/rt" --classpath "$W/rtstubs" --classpath "$W/stubs" \
  --output "$W/hooks.jar" $(find "$W/classes" -name '*.class')
# 덱스가 들었는지. 우리 클래스만 들었는지(런타임·스텁이 섞이면 차의 것과 부딪힌다)는 tests/mod-test.sh가 dexdump로 본다
unzip -l "$W/hooks.jar" | grep -q 'classes.dex' || { echo "hooks.jar에 classes.dex가 없습니다" >&2; exit 1; }
mkdir -p "$(dirname "$OUTJ")"
cp "$W/hooks.jar" "$OUTJ"
echo "만듦: $OUTJ ($(wc -c < "$OUTJ" | tr -d ' ') 바이트)"
