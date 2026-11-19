#!/bin/sh
# NEMESIS 없는 내비용 묶음을 만든다(투싼 NX4 전용, standalone/README.md).
#   out/standalone/korea-projection-<버전>.zip              HMG-API 모드(작성자 키로 서명): HMG-API 앱·adb·USB로 설치
#   out/standalone/korea-projection-<버전>-standalone-usb.zip  USB 묶음: Engineering Mode > DSP > Update OTA로 설치
# 모드는 nemesis-pkg/korea.projection(NEMESIS판과 같은 스크립트)에 standalone/korea-projection(mod.json, 서비스 래퍼)을 얹은 것이다.
# 필요한 것: JDK, python3, zip/unzip, HMG-API 소스(서명 도구 tools/mkmodpkg.sh), 상태 화면 앱 APK.
# 환경 변수:
#   HMGAPI_SRC      HMG-API 저장소 위치(필수). 서명은 그 tools/mkmodpkg.sh가 한다
#   KP_MOD_KEY      모드 작성자 키(필수, 저장소 밖에 둔다). 처음 한 번:
#                     (cd $HMGAPI_SRC && mkdir -p out/engine-host && javac --release 8 -d out/engine-host core/runtime/java/hmgapi/engine/*.java)
#                     java -cp $HMGAPI_SRC/out/engine-host hmgapi.engine.Signing keygen ~/.local/share/korea-projection/keys/mod.key
#                   HMG-API는 같은 키로 서명한 업데이트만 받는다: 이 키를 잃으면 모드를 지우고 다시 설치해야 한다
#   KP_APK          상태 화면 앱(기본 nemesis-pkg/korea.projection/app/KoreaProjection.apk, scripts/build-app.sh로 만듦).
#                   standalone은 화면을 열 때 HMG-API 서비스 launch를 부르는 앱(1.7.4 뒤 StatusActivity)이어야 한다
#   KP_BUSYBOX      함께 넣을 busybox(기본 nemesis-pkg/korea.projection/bin/busybox. 없으면 내비의 /system/bin/busybox만 쓴다)
#   KP_PKG_ZIP      릴리스의 korea.projection.zip: KP_BUSYBOX가 없을 때 그 안의 bin/busybox를 쓴다
#   HMGAPI_USB_ZIP  HMG-API USB 묶음(hmgapi-<버전>-usb.zip). 주면 같은 USB에 함께 넣는다(HMG-API가 없으면 그것부터 설치)
#   OUT             결과 폴더(기본 out/standalone)
set -e
B=$(cd "$(dirname "$0")/.." && pwd)
PKG=$B/nemesis-pkg/korea.projection
SA=$B/standalone
OUT=${OUT:-$B/out/standalone}
: "${HMGAPI_SRC:?HMG-API 저장소 위치를 HMGAPI_SRC로 주세요}"
: "${KP_MOD_KEY:?모드 작성자 키를 KP_MOD_KEY로 주세요(위 설명의 keygen)}"
[ -f "$HMGAPI_SRC/tools/mkmodpkg.sh" ] || { echo "HMGAPI_SRC에 tools/mkmodpkg.sh가 없습니다: $HMGAPI_SRC" >&2; exit 1; }
[ -f "$KP_MOD_KEY" ] || { echo "키 파일이 없습니다: $KP_MOD_KEY" >&2; exit 1; }
HMGAPI_SRC=$(cd "$HMGAPI_SRC" && pwd)
case $KP_MOD_KEY in /*) ;; *) KP_MOD_KEY=$PWD/$KP_MOD_KEY ;; esac

# 판: NEMESIS.data의 package-version과 mod.json의 version이 같아야 한다(상태 화면·제보가 NEMESIS.data를 읽는다)
V=$(sed -n 's/^package-version=//p' "$PKG/NEMESIS.data" | tr -d '\r')
MV=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$SA/korea-projection/mod.json" | head -1)
[ -n "$V" ] && [ "$V" = "$MV" ] || { echo "판이 다릅니다: NEMESIS.data $V, standalone mod.json $MV" >&2; exit 1; }

W=$(mktemp -d /tmp/kp-standalone.XXXXXX)
trap 'rm -rf "$W"' EXIT
M=$W/korea-projection
mkdir -p "$M"
cp -R "$PKG/." "$M/"
cp -R "$SA/korea-projection/." "$M/"
# NX4 지도는 패키지에 없다: 그 차에서 HMG-API가 만든다(svc/hotspot.sh 자동 시험, engine map-car --write → verify-map).
# 다른 차의 지도는 이 묶음(NX4 전용)에 넣지 않는다
rm -rf "$M/hmgapi/maps"

APK=${KP_APK:-$PKG/app/KoreaProjection.apk}
[ -f "$APK" ] || { echo "상태 화면 앱이 없습니다: $APK (scripts/build-app.sh로 만들거나 KP_APK로 주세요)" >&2; exit 1; }
mkdir -p "$M/app"
[ "$APK" -ef "$M/app/KoreaProjection.apk" ] || cp "$APK" "$M/app/KoreaProjection.apk"

BBX=${KP_BUSYBOX:-$PKG/bin/busybox}
if [ -f "$BBX" ]; then
  [ "$BBX" -ef "$M/bin/busybox" ] || cp "$BBX" "$M/bin/busybox"
elif [ -n "$KP_PKG_ZIP" ]; then
  unzip -p "$KP_PKG_ZIP" bin/busybox > "$M/bin/busybox" || { echo "KP_PKG_ZIP에 bin/busybox가 없습니다" >&2; exit 1; }
else
  echo "참고: busybox를 넣지 않습니다(내비의 /system/bin/busybox가 있어야 무선 설정을 합니다)"
fi
[ -f "$M/bin/busybox" ] && chmod 755 "$M/bin/busybox"
find "$M" -name '*.sh' -exec chmod 755 {} +

# 서명·묶기: HMG-API의 도구 그대로(같은 모드와 키면 어느 PC에서나 같은 zip)
mkdir -p "$OUT"
Z=$(sh "$HMGAPI_SRC/tools/mkmodpkg.sh" "$M" "$KP_MOD_KEY" | tail -1)
[ -f "$Z" ] || { echo "모드 zip을 만들지 못했습니다" >&2; exit 1; }
MZ=$OUT/korea-projection-$V.zip
cp "$Z" "$MZ"
echo "만듦: $MZ"

# USB 묶음
S=$W/usb
mkdir -p "$S"
if [ -n "$HMGAPI_USB_ZIP" ]; then
  # HMG-API USB 묶음을 먼저 풀고, 그 ota_package.tar의 설치기를 KoreaProjection/hmgapi/로 옮긴다(우리 설치기가 HMG-API가 없을 때 부름).
  # 스틱 맨 위 ota_package.tar는 우리 것으로 바꾼다
  unzip -q "$HMGAPI_USB_ZIP" -d "$S"
  [ -d "$S/HMGAPI/install/payload" ] && [ -f "$S/ota_package.tar" ] || { echo "HMG-API USB 묶음이 아닙니다: $HMGAPI_USB_ZIP" >&2; exit 1; }
  mkdir -p "$S/KoreaProjection/hmgapi"
  python3 - "$S/ota_package.tar" "$S/KoreaProjection/hmgapi/troubleShooter" <<'PY'
import sys, tarfile
with tarfile.open(sys.argv[1]) as t:
    open(sys.argv[2], "wb").write(t.extractfile("troubleShooter").read())
PY
  [ -f "$S/README.txt" ] && mv "$S/README.txt" "$S/HMGAPI-README.txt"
  # NEMESIS USB Handler용 파일: NEMESIS가 없는 내비에는 쓸모없고, NEMESIS가 있으면 이 스틱으로 HMG-API를 깔려 하므로 뺀다
  rm -f "$S/NEMESIS.data"
fi
mkdir -p "$S/KoreaProjection/install/payload"
cp "$MZ" "$S/KoreaProjection/install/korea-projection.zip"
unzip -q "$MZ" -d "$S/KoreaProjection/install/payload"
python3 - "$SA/usb/troubleShooter" "$S/ota_package.tar" <<'PY'
import io, sys, tarfile
data = open(sys.argv[1], "rb").read()
# DSP 에이전트가 확실히 돌리는 꼴: 일반 파일 troubleShooter 하나, 0755, root (HMG-API tools/mkinstallers.sh와 같음)
with tarfile.open(sys.argv[2], "w", format=tarfile.GNU_FORMAT) as t:
    i = tarfile.TarInfo("troubleShooter"); i.size = len(data); i.mode = 0o755; i.uid = i.gid = 0; i.mtime = 0
    t.addfile(i, io.BytesIO(data))
PY
sed "s/@VERSION@/$V/" "$SA/usb/README.txt" > "$S/README.txt"
UZ=$OUT/korea-projection-$V-standalone-usb.zip
rm -f "$UZ"
(cd "$S" && export TZ=UTC LC_ALL=C && find . -type f | sort | zip -q -X -D "$UZ" -@)
echo "만듦: $UZ"
