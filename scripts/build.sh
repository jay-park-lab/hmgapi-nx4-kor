#!/bin/sh
# NX4 KOR 묶음을 만든다(투싼 NX4 한국 내수 260902 전용, docs/design.md).
#   out/hmgapi-nx4-kor-<버전>.zip      HMG-API 모드(작성자 키로 서명): HMG-API 앱·adb·USB로 설치
#   out/hmgapi-nx4-kor-<버전>-usb.zip  USB 묶음: Engineering Mode > DSP > Update OTA로 설치
# 모드는 mod/ 폴더(mod.json, 서비스·상태 스크립트, 무선 훅·네이티브 패치)에 상태 화면 앱과 busybox를 더한 것이다.
# 필요한 것: JDK, python3, zip/unzip, HMG-API 소스(서명 도구 tools/mkmodpkg.sh), 상태 화면 앱 APK.
# 환경 변수:
#   HMGAPI_SRC      HMG-API 저장소 위치(필수). 서명은 그 tools/mkmodpkg.sh가 한다
#   KP_MOD_KEY      모드 작성자 키(필수, 저장소 밖에 둔다). 처음 한 번:
#                     (cd $HMGAPI_SRC && mkdir -p out/engine-host && javac --release 8 -d out/engine-host core/runtime/java/hmgapi/engine/*.java)
#                     java -cp $HMGAPI_SRC/out/engine-host hmgapi.engine.Signing keygen ~/.local/share/hmgapi-nx4-kor/keys/mod.key
#                   HMG-API는 같은 키로 서명한 업데이트만 받는다: 이 키를 잃으면 모드를 지우고 다시 설치해야 한다
#   KP_APK          상태 화면 앱(기본 mod/app/NX4KOR.apk, scripts/build-app.sh로 만듦)
#   KP_BUSYBOX      함께 넣을 busybox(기본 mod/bin/busybox. 없으면 내비의 /system/bin/busybox만 쓴다)
#   KP_BUSYBOX_LICENSE  그 busybox의 라이선스 안내(GPL-2.0, 대응 소스 위치. 기본 <KP_BUSYBOX>-LICENSE.txt)
#   KP_PKG_ZIP      Korea Projection 릴리스의 패키지 zip: 위 둘이 없을 때 그 안의
#                   bin/busybox와 bin/busybox-LICENSE.txt를 쓴다(같은 BusyBox 1.36.1, NOTICE.md)
#   HMGAPI_USB_ZIP  HMG-API USB 묶음(hmgapi-<버전>-usb.zip). 주면 같은 USB에 함께 넣는다(HMG-API가 없으면 그것부터 설치)
#   OUT             결과 폴더(기본 out)
# 라이선스: 모드와 USB에 LICENSE(AGPL-3.0)·NOTICE.md를 넣는다. busybox(GPL-2.0)를 넣으면 그 안내(bin/busybox-LICENSE.txt,
# USB 맨 위 BUSYBOX-LICENSE.txt)도 넣고, 안내가 없으면 만들지 않는다. HMG-API를 함께 넣으면
# 그 소스 위치(HMGAPI-SOURCE.txt)를 적는다. USB README.txt에는 이 묶음을 만든 소스 커밋을 적는다.
set -e
B=$(cd "$(dirname "$0")/.." && pwd)
PKG=$B/mod
OUT=${OUT:-$B/out}
: "${HMGAPI_SRC:?HMG-API 저장소 위치를 HMGAPI_SRC로 주세요}"
: "${KP_MOD_KEY:?모드 작성자 키를 KP_MOD_KEY로 주세요(위 설명의 keygen)}"
[ -f "$HMGAPI_SRC/tools/mkmodpkg.sh" ] || { echo "HMGAPI_SRC에 tools/mkmodpkg.sh가 없습니다: $HMGAPI_SRC" >&2; exit 1; }
[ -f "$KP_MOD_KEY" ] || { echo "키 파일이 없습니다: $KP_MOD_KEY" >&2; exit 1; }
HMGAPI_SRC=$(cd "$HMGAPI_SRC" && pwd)
case $KP_MOD_KEY in /*) ;; *) KP_MOD_KEY=$PWD/$KP_MOD_KEY ;; esac

# 판: mod.json의 version(상태 화면·USB 설치기도 이 값을 읽는다)
V=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$PKG/mod.json" | head -1)
[ -n "$V" ] || { echo "mod.json에서 판을 읽지 못했습니다" >&2; exit 1; }

W=$(mktemp -d /tmp/nx4-kor-build.XXXXXX)
trap 'rm -rf "$W"' EXIT
M=$W/nx4-kor
mkdir -p "$M"
cp -R "$PKG/." "$M/"
# NX4 map은 모드에 없다: 그 차에서 HMG-API가 만든다(svc/hotspot.sh setup_hmgapi, engine map-car --write → verify-map)

APK=${KP_APK:-$PKG/app/NX4KOR.apk}
[ -f "$APK" ] || { echo "상태 화면 앱이 없습니다: $APK (scripts/build-app.sh로 만들거나 KP_APK로 주세요)" >&2; exit 1; }
mkdir -p "$M/app"
[ "$APK" -ef "$M/app/NX4KOR.apk" ] || cp "$APK" "$M/app/NX4KOR.apk"

BBX=${KP_BUSYBOX:-$PKG/bin/busybox}
if [ -f "$BBX" ]; then
  [ "$BBX" -ef "$M/bin/busybox" ] || cp "$BBX" "$M/bin/busybox"
elif [ -n "$KP_PKG_ZIP" ]; then
  unzip -p "$KP_PKG_ZIP" bin/busybox > "$M/bin/busybox" || { echo "KP_PKG_ZIP에 bin/busybox가 없습니다" >&2; exit 1; }
else
  echo "참고: busybox를 넣지 않습니다(내비의 /system/bin/busybox가 있어야 무선 설정을 합니다)"
fi
[ -f "$M/bin/busybox" ] && chmod 755 "$M/bin/busybox"
# busybox는 GPL-2.0인 별개 프로그램이다: 넣으면 라이선스 안내(대응 소스 위치)도 넣어야 한다. 없으면 만들지 않는다
BBNOTE=bin/busybox-LICENSE.txt
BBL=${KP_BUSYBOX_LICENSE:-$BBX-LICENSE.txt}
if [ -f "$M/bin/busybox" ]; then
  if [ -f "$BBL" ]; then
    [ "$BBL" -ef "$M/$BBNOTE" ] || cp "$BBL" "$M/$BBNOTE"
  elif [ -n "$KP_PKG_ZIP" ] && unzip -p "$KP_PKG_ZIP" $BBNOTE > "$M/$BBNOTE" 2>/dev/null && [ -s "$M/$BBNOTE" ]; then
    :
  else
    rm -f "$M/$BBNOTE"
    echo "busybox(GPL-2.0)를 넣는데 라이선스 안내($BBNOTE)가 없습니다. KP_BUSYBOX_LICENSE로 주거나 KP_PKG_ZIP에 들어 있어야 합니다." >&2
    exit 1
  fi
else
  rm -f "$M/$BBNOTE"
fi
# AGPL-3.0 원문과 고지(원저작권, 이 포크의 변경)
cp "$B/LICENSE" "$B/NOTICE.md" "$M/"
find "$M" -name '*.sh' -exec chmod 755 {} +

# 서명·묶기: HMG-API의 도구 그대로(같은 모드와 키면 어느 PC에서나 같은 zip)
mkdir -p "$OUT"
Z=$(sh "$HMGAPI_SRC/tools/mkmodpkg.sh" "$M" "$KP_MOD_KEY" | tail -1)
[ -f "$Z" ] || { echo "모드 zip을 만들지 못했습니다" >&2; exit 1; }
MZ=$OUT/hmgapi-nx4-kor-$V.zip
cp "$Z" "$MZ"
echo "만듦: $MZ"

# USB 묶음
S=$W/usb
mkdir -p "$S"
if [ -n "$HMGAPI_USB_ZIP" ]; then
  # HMG-API USB 묶음을 먼저 풀고, 그 ota_package.tar의 설치기를 NX4/hmgapi/로 옮긴다(우리 설치기가 HMG-API가 없을 때 부름).
  # 스틱 맨 위 ota_package.tar는 우리 것으로 바꾼다
  unzip -q "$HMGAPI_USB_ZIP" -d "$S"
  [ -d "$S/HMGAPI/install/payload" ] && [ -f "$S/ota_package.tar" ] || { echo "HMG-API USB 묶음이 아닙니다: $HMGAPI_USB_ZIP" >&2; exit 1; }
  mkdir -p "$S/NX4/hmgapi"
  python3 - "$S/ota_package.tar" "$S/NX4/hmgapi/troubleShooter" <<'PY'
import sys, tarfile
with tarfile.open(sys.argv[1]) as t:
    open(sys.argv[2], "wb").write(t.extractfile("troubleShooter").read())
PY
  [ -f "$S/README.txt" ] && mv "$S/README.txt" "$S/HMGAPI-README.txt"
  # HMG-API 묶음의 다른 USB 설치 길(NEMESIS.data)은 쓰지 않으므로 뺀다
  rm -f "$S/NEMESIS.data"
  # HMG-API(AGPL-3.0)를 그대로 함께 배포하므로 그 판과 대응 소스 위치를 적는다
  HV=$(tr -d '\r\n' < "$S/HMGAPI/install/payload/VERSION" 2>/dev/null) || HV=
  if [ -n "$HV" ]; then HSRC=https://github.com/Open-HMG/HMG-API/tree/v$HV; else HSRC=https://github.com/Open-HMG/HMG-API/releases; fi
  cat > "$S/HMGAPI-SOURCE.txt" <<EOF
HMG-API ${HV:-(판 모름)}: 이 USB의 HMGAPI 폴더, HMGAPI-README.txt, NX4/hmgapi/troubleShooter
- HMG-API 릴리스의 USB 묶음(hmgapi-${HV:-버전}-usb.zip)을 고치지 않고 넣었습니다(설치기 위치만 옮기고 NEMESIS.data는 뺐습니다).
- 라이선스: GNU AGPL-3.0 (이 USB의 LICENSE와 같은 라이선스)
- 대응 소스: $HSRC
EOF
fi
# 라이선스 원문과 고지. busybox를 넣었으면 그 안내도 맨 위에(압축을 풀지 않고도 보이게)
cp "$B/LICENSE" "$B/NOTICE.md" "$S/"
[ -f "$M/$BBNOTE" ] && cp "$M/$BBNOTE" "$S/BUSYBOX-LICENSE.txt"
mkdir -p "$S/NX4/install/payload"
cp "$MZ" "$S/NX4/install/hmgapi-nx4-kor.zip"
unzip -q "$MZ" -d "$S/NX4/install/payload"
python3 - "$B/usb/troubleShooter" "$S/ota_package.tar" <<'PY'
import io, sys, tarfile
data = open(sys.argv[1], "rb").read()
# DSP 에이전트가 확실히 돌리는 꼴: 일반 파일 troubleShooter 하나, 0755, root (HMG-API tools/mkinstallers.sh와 같음)
with tarfile.open(sys.argv[2], "w", format=tarfile.GNU_FORMAT) as t:
    i = tarfile.TarInfo("troubleShooter"); i.size = len(data); i.mode = 0o755; i.uid = i.gid = 0; i.mtime = 0
    t.addfile(i, io.BytesIO(data))
PY
# 이 묶음을 만든 소스(AGPL 대응 소스): 커밋, 커밋하지 않은 수정이 있으면 그렇다고 적는다
SRCREV=$(cd "$B" && git rev-parse --short HEAD 2>/dev/null) || SRCREV=
[ -n "$SRCREV" ] && [ -n "$(cd "$B" && git status --porcelain 2>/dev/null)" ] && SRCREV="$SRCREV, 커밋하지 않은 수정 포함"
sed -e "s/@VERSION@/$V/" -e "s#@SOURCE_REV@#${SRCREV:-커밋 모름}#" "$B/usb/README.txt" > "$S/README.txt"
UZ=$OUT/hmgapi-nx4-kor-$V-usb.zip
rm -f "$UZ"
(cd "$S" && export TZ=UTC LC_ALL=C && find . -type f | sort | zip -q -X -D "$UZ" -@)
echo "만듦: $UZ"
