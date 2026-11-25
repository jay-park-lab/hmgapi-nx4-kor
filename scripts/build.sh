#!/bin/sh
# NX4 KOR 묶음을 만든다(투싼 NX4 한국 내수 260902 전용, docs/design.md).
#   out/hmgapi-nx4-kor-<버전>.zip      HMG-API 모드(작성자 키로 서명): HMG-API 앱·adb·USB로 설치
#   out/hmgapi-nx4-kor-<버전>-usb.zip  USB 묶음: Engineering Mode > DSP > Update OTA로 설치
# 모드는 mod/ 폴더(mod.json, settings.json, 서비스·상태 스크립트)에 관리 앱, hooks.jar(hooks/src에서 만듦), busybox를 더한 것이다.
# 필요한 것: JDK, python3, zip/unzip, HMG-API 소스(서명 도구 tools/mkmodpkg.sh), 관리 앱 APK,
#   busybox를 Alpine에서 받을 때는 curl과 인터넷(NX4_BUSYBOX 참고).
# 환경 변수(명령 앞에 주거나 .env.local에 적는다. .env.example, scripts/local-env.sh):
#   HMGAPI_SRC      HMG-API 저장소 위치(필수). 서명은 그 tools/mkmodpkg.sh가 한다
#   NX4_MOD_KEY      모드 작성자 키(필수, 저장소 밖에 둔다). 처음 한 번:
#                     (cd $HMGAPI_SRC && mkdir -p out/engine-host && javac --release 8 -d out/engine-host core/runtime/java/hmgapi/engine/*.java)
#                     java -cp $HMGAPI_SRC/out/engine-host hmgapi.engine.Signing keygen $NX4_MOD_KEY
#                   HMG-API는 같은 키로 서명한 업데이트만 받는다: 이 키를 잃으면 모드를 지우고 다시 설치해야 한다
#   NX4_APK          관리 앱(기본 mod/app/NX4KOR.apk, scripts/build-app.sh로 만듦)
#   ANDROID_HOME     Android SDK. hooks.jar(한국 카플레이 길안내, #67)를 scripts/build-hooks.sh로 만들 때 쓴다
#   NX4_HOOKS_JAR    이미 만든 hooks.jar(주면 build-hooks.sh를 부르지 않고 그것을 넣는다. 테스트·관리용)
#   NX4_BUSYBOX      함께 넣을 busybox. 주지 않으면 mod/bin/busybox(있으면 SHA-256 확인 없이), 그것도 없으면 Alpine
#                   저장소에서 받는다(scripts/fetch-busybox.sh: BusyBox 1.36.1, NOTICE.md의 SHA-256과 같을 때만.
#                   <OUT>/busybox에 둠. 미러는 NX4_BUSYBOX_URL).
#                   none이면 넣지 않는다(내비에 /system/bin/busybox가 없으면 무선 설정을 하지 않는 묶음이 된다)
#   NX4_BUSYBOX_LICENSE  그 busybox의 라이선스 안내(GPL-2.0, 대응 소스 위치. 기본 <NX4_BUSYBOX>-LICENSE.txt)
#   HMGAPI_USB_ZIP  HMG-API USB 묶음(hmgapi-<버전>-usb.zip). 주면 같은 USB에 함께 넣는다(HMG-API가 없으면 그것부터 설치)
#   NX4_WIRELESS_ZIP  USB에 함께 넣을 공식 무선 모드 zip(wireless-carplay-aa-<판>.zip, 고치지 않은 공식 릴리스 파일). 주지 않으면
#                   공식 릴리스에서 받는다(scripts/fetch-wireless.sh: 고정한 판, NOTICE.md의 SHA-256과 같을 때만. <OUT>/wireless에 둠.
#                   미러는 NX4_WIRELESS_URL). 준 파일은 SHA-256을 보지 않고 쓴다(인터넷 없이 만들 때 받아 둔 파일을 가리킨다)
#   NX4_LEGACY_REF  옛 2.0.x 되돌리기 스크립트를 꺼낼 git 태그(기본 v2.0.4-beta.1, 2.0.x의 마지막 묶음). 테스트·관리용
#   OUT             결과 폴더(기본 out)
# 옛 2.0.x 되돌리기: 2.1.0의 nx4-kor는 2.0.x가 직접 바꾼 것(Wi-Fi 잠금, 순정 AP 저장값, 무선 권한 파일)을 되돌리지 못한다. 그래서
# 2.0.x를 HMG-API 앱에서 지운 차를 위해 그 판의 되돌리기 스크립트(bin/uninstall.sh, scripts/preun.sh, svc/env.sh, svc/hotspot.sh,
# mod.json)를 태그에서 고치지 않고 꺼내 USB의 NX4/legacy-2.0/에 넣는다(설치기 old_revert). busybox는 설치기가 payload의 것을 쓴다.
# 그 태그가 이 저장소에 있어야 한다(없으면 git fetch origin --tags).
# 라이선스: 모드와 USB에 LICENSE(AGPL-3.0)·NOTICE.md를 넣는다. busybox(GPL-2.0)를 넣으면 그 안내(bin/busybox-LICENSE.txt,
# USB 맨 위 BUSYBOX-LICENSE.txt)도 넣고, 안내가 없으면 만들지 않는다. HMG-API를 함께 넣으면
# 그 소스 위치(HMGAPI-SOURCE.txt)를, 공식 무선 모드(AGPL-3.0)는 그 판과 소스 위치(WIRELESS-SOURCE.txt)를 적는다.
# USB README.txt에는 이 묶음을 만든 소스 커밋을 적는다.
set -e
B=$(cd "$(dirname "$0")/.." && pwd)
. "$B/scripts/local-env.sh"
nx4_env "$B"
PKG=$B/mod
OUT=${OUT:-$B/out}
nx4_need HMGAPI_SRC "HMG-API 저장소 위치"
nx4_need NX4_MOD_KEY "모드 작성자 키 파일. 만드는 법은 이 파일 위 설명의 keygen"
[ -f "$HMGAPI_SRC/tools/mkmodpkg.sh" ] || { echo "HMGAPI_SRC에 tools/mkmodpkg.sh가 없습니다: $HMGAPI_SRC" >&2; exit 1; }
[ -f "$NX4_MOD_KEY" ] || { echo "키 파일이 없습니다: $NX4_MOD_KEY" >&2; exit 1; }
HMGAPI_SRC=$(cd "$HMGAPI_SRC" && pwd)
case $NX4_MOD_KEY in /*) ;; *) NX4_MOD_KEY=$PWD/$NX4_MOD_KEY ;; esac

# 판: mod.json의 version(관리 앱·USB 설치기도 이 값을 읽는다)
V=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$PKG/mod.json" | head -1)
[ -n "$V" ] || { echo "mod.json에서 판을 읽지 못했습니다" >&2; exit 1; }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
M=$W/nx4-kor
mkdir -p "$M"
cp -R "$PKG/." "$M/"
# NX4 map은 모드에 없다: 그 차에서 HMG-API가 만든다(USB 설치기 usb/troubleShooter가 engine map-car --write → verify-map)

APK=${NX4_APK:-$PKG/app/NX4KOR.apk}
[ -f "$APK" ] || { echo "관리 앱이 없습니다: $APK (scripts/build-app.sh로 만들거나 NX4_APK로 주세요)" >&2; exit 1; }
mkdir -p "$M/app"
[ "$APK" -ef "$M/app/NX4KOR.apk" ] || cp "$APK" "$M/app/NX4KOR.apk"

# hooks.jar(#67, 한국 카플레이 길안내): hooks/src를 HMG-API 런타임에 대고 만든다. 소스는 mod/ 밖에 두므로 모드에 들어가지 않는다
HJ=$NX4_HOOKS_JAR
if [ -z "$HJ" ]; then
  sh "$B/scripts/build-hooks.sh" "$W/hooks.jar" > "$W/build-hooks.out" 2>&1 || { cat "$W/build-hooks.out" >&2; echo "hooks.jar를 만들지 못했습니다(scripts/build-hooks.sh)" >&2; exit 1; }
  tail -n 1 "$W/build-hooks.out"
  HJ=$W/hooks.jar
fi
[ -f "$HJ" ] || { echo "hooks.jar가 없습니다: $HJ" >&2; exit 1; }
# 커밋에서 만들지 않은 jar가 배포 묶음에 말없이 들어가지 않게, 받은 파일이면 그렇다고 찍는다(docs/git-flow.md 규칙 7)
[ -z "$NX4_HOOKS_JAR" ] || echo "참고: hooks.jar는 NX4_HOOKS_JAR($NX4_HOOKS_JAR)를 넣었습니다. 배포 묶음은 비우고 만드세요(scripts/build-hooks.sh)"
cp "$HJ" "$M/hooks.jar"

# busybox: 이 모드의 스크립트는 busybox로 돈다. NX4 내비에 /system/bin/busybox가 없으면 함께 넣은 것만 쓸 수 있으므로
# 늘 넣는다(내비에 있으면 모드 스크립트가 그것을 먼저 쓴다). 넣지 않으려면 NX4_BUSYBOX=none
BBX=${NX4_BUSYBOX:-$PKG/bin/busybox}
if [ "$NX4_BUSYBOX" = none ]; then
  BBX=
  rm -f "$M/bin/busybox"
  echo "참고: busybox를 넣지 않습니다(NX4_BUSYBOX=none). 내비에 /system/bin/busybox가 없으면 무선 설정을 하지 않습니다"
elif [ -z "$NX4_BUSYBOX" ] && [ ! -f "$BBX" ]; then
  sh "$B/scripts/fetch-busybox.sh" "$OUT/busybox"
  BBX=$OUT/busybox/busybox
fi
if [ -n "$BBX" ]; then
  [ -f "$BBX" ] || { echo "busybox가 없습니다: $BBX (NX4_BUSYBOX를 비우면 Alpine에서 받습니다)" >&2; exit 1; }
  [ "$BBX" -ef "$M/bin/busybox" ] || cp "$BBX" "$M/bin/busybox"
  chmod 755 "$M/bin/busybox"
fi
# busybox는 GPL-2.0인 별개 프로그램이다: 넣으면 라이선스 안내(대응 소스 위치)도 넣어야 한다. 없으면 만들지 않는다
BBNOTE=bin/busybox-LICENSE.txt
if [ -n "$BBX" ]; then
  BBL=${NX4_BUSYBOX_LICENSE:-$BBX-LICENSE.txt}
  if [ -f "$BBL" ]; then
    [ "$BBL" -ef "$M/$BBNOTE" ] || cp "$BBL" "$M/$BBNOTE"
  else
    rm -f "$M/$BBNOTE"
    echo "busybox(GPL-2.0)를 넣는데 라이선스 안내($BBL)가 없습니다. NX4_BUSYBOX_LICENSE로 주세요." >&2
    exit 1
  fi
else
  rm -f "$M/$BBNOTE"
fi
# AGPL-3.0 원문과 고지(원저작권, 이 포크의 변경)
cp "$B/LICENSE" "$B/NOTICE.md" "$M/"
find "$M" -name '*.sh' -exec chmod 755 {} +

# 서명·묶기: HMG-API의 도구 그대로. 파일 순서·시각은 고정하지만 서명(ECDSA)이 만들 때마다 달라 zip은 매번 다르다
# mkmodpkg.sh는 모드 폴더의 build.sh를 서명 키를 받은 채로 실행하고 패키지에서는 뺀다(결과물에 남지 않음).
# 이 모드는 그 파일을 쓰지 않으므로, 있으면 만들지 않는다(docs/release.md "위험")
[ ! -e "$M/build.sh" ] || { echo "mod/build.sh는 쓰지 않습니다(HMG-API mkmodpkg.sh가 서명 키를 받은 채로 실행합니다). 지우고 다시 만드세요" >&2; exit 1; }
mkdir -p "$OUT"
Z=$(sh "$HMGAPI_SRC/tools/mkmodpkg.sh" "$M" "$NX4_MOD_KEY" | tail -1)
[ -f "$Z" ] || { echo "모드 zip을 만들지 못했습니다" >&2; exit 1; }
MZ=$OUT/hmgapi-nx4-kor-$V.zip
cp "$Z" "$MZ"
echo "만듦: $MZ"

# 공식 무선 모드(wireless-carplay-aa): USB 설치기가 NX4에 --any-car로 설치한다. 공식 릴리스 파일을 고치지 않고 넣는다
WZIP=$NX4_WIRELESS_ZIP
if [ -z "$WZIP" ]; then
  # 받지 못하거나 SHA-256이 다르면 fetch-wireless.sh가 멈추고(set -e) 여기서 끝난다
  sh "$B/scripts/fetch-wireless.sh" "$OUT/wireless" > "$W/fetch-wireless.out"
  head -n 1 "$W/fetch-wireless.out"
  WZIP=$(tail -n 1 "$W/fetch-wireless.out")
else
  echo "참고: NX4_WIRELESS_ZIP($WZIP)은 SHA-256을 보지 않고 씁니다"
fi
[ -f "$WZIP" ] || { echo "공식 무선 모드 zip이 없습니다: $WZIP (NX4_WIRELESS_ZIP을 비우면 공식 릴리스에서 받습니다)" >&2; exit 1; }
mkdir -p "$W/wireless"
unzip -p "$WZIP" mod.json > "$W/wireless/mod.json" 2>/dev/null || true
WID=$(sed -n 's/^ *"id": *"\([^"]*\)".*/\1/p' "$W/wireless/mod.json" | head -1)
WV=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$W/wireless/mod.json" | head -1)
[ "$WID" = wireless-carplay-aa ] && [ -n "$WV" ] || { echo "공식 무선 모드 zip이 아닙니다(mod.json id ${WID:-없음}): $WZIP" >&2; exit 1; }

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
  # HMG-API 묶음의 다른 USB 설치 길(NEMESIS.data)과 HMG-API 앱이 읽는 업데이트·모드 묶음(HMGAPI/updates)은 쓰지 않으므로 뺀다.
  # HMG-API 설치기는 HMGAPI/install만 쓴다. 공식 무선 모드는 우리 설치기가 고정한 판(NX4/wireless, 아래)으로 넣는다
  rm -f "$S/NEMESIS.data"
  rm -rf "$S/HMGAPI/updates"
  # HMG-API(AGPL-3.0)를 그대로 함께 배포하므로 그 판과 대응 소스 위치를 적는다
  HV=$(tr -d '\r\n' < "$S/HMGAPI/install/payload/VERSION" 2>/dev/null) || HV=
  if [ -n "$HV" ]; then HSRC=https://github.com/Open-HMG/HMG-API/tree/v$HV; else HSRC=https://github.com/Open-HMG/HMG-API/releases; fi
  cat > "$S/HMGAPI-SOURCE.txt" <<EOF
HMG-API ${HV:-(판 모름)}: 이 USB의 HMGAPI 폴더, HMGAPI-README.txt, NX4/hmgapi/troubleShooter
- HMG-API 릴리스의 USB 묶음(hmgapi-${HV:-버전}-usb.zip)에서 HMG-API 설치에 쓰는 것만 고치지 않고 넣었습니다.
  설치기 위치만 옮겼고, NEMESIS.data와 HMGAPI/updates(HMG-API 앱용 업데이트와 공식 모드 묶음)는 뺐습니다.
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
# 옛 2.0.x 되돌리기 스크립트(위 머리말): 태그의 파일을 그대로
LREF=${NX4_LEGACY_REF:-v2.0.4-beta.1}
for f in bin/uninstall.sh scripts/preun.sh svc/env.sh svc/hotspot.sh mod.json; do
  mkdir -p "$S/NX4/legacy-2.0/$(dirname "$f")"
  (cd "$B" && git show "$LREF:mod/$f") > "$S/NX4/legacy-2.0/$f" 2>/dev/null \
    || { echo "옛 2.0.x 되돌리기 스크립트(mod/$f)를 git 태그 $LREF에서 꺼내지 못했습니다(git fetch origin --tags)" >&2; exit 1; }
done
chmod 755 "$S/NX4/legacy-2.0/bin/uninstall.sh" "$S/NX4/legacy-2.0/scripts/preun.sh" "$S/NX4/legacy-2.0/svc/env.sh" "$S/NX4/legacy-2.0/svc/hotspot.sh"
grep -q '"wireless-carplay-aa"' "$S/NX4/legacy-2.0/mod.json" \
  || { echo "git 태그 $LREF의 mod/mod.json이 옛 2.0.x(공식 무선 모드와 충돌 선언)가 아닙니다" >&2; exit 1; }
LREV=$(cd "$B" && git rev-parse --short "$LREF^{commit}" 2>/dev/null) || LREV=
echo "$LREF ${LREV:-커밋 모름}" > "$S/NX4/legacy-2.0/SOURCE"
# 공식 무선 모드: zip 그대로와, 설치기가 판·HMG-API 최소 판을 풀지 않고 읽을 mod.json
mkdir -p "$S/NX4/wireless"
cp "$WZIP" "$S/NX4/wireless/wireless-carplay-aa.zip"
cp "$W/wireless/mod.json" "$S/NX4/wireless/mod.json"
WSHA=$( (sha256sum "$WZIP" 2>/dev/null || shasum -a 256 "$WZIP") | cut -d' ' -f1)
cat > "$S/WIRELESS-SOURCE.txt" <<EOF
공식 무선 모드 wireless-carplay-aa $WV: 이 USB의 NX4/wireless/wireless-carplay-aa.zip (mod.json은 그 zip에서 꺼낸 것)
- Open-HMG/hmgapi-wireless-cp-aa(VysseCodes)의 릴리스 파일 wireless-carplay-aa-$WV.zip을 고치지 않고 넣었습니다.
  SHA-256 $WSHA
- NX4 KOR USB 설치기가 투싼 NX4에 HMG-API의 "Install anyway"(engine install --any-car)로 설치합니다.
- 라이선스: GNU AGPL-3.0 (이 USB의 LICENSE와 같은 라이선스)
- 대응 소스: https://github.com/Open-HMG/hmgapi-wireless-cp-aa/tree/v$WV
EOF
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
