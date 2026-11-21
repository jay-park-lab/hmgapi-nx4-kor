#!/bin/sh
# 모드에 함께 넣을 busybox(GPL-2.0)를 Alpine Linux 저장소에서 받는다(NOTICE.md "BusyBox").
#   sh scripts/fetch-busybox.sh <폴더>   → <폴더>/busybox(0755)와 그 라이선스 안내 <폴더>/busybox-LICENSE.txt
# 받는 것: Alpine 3.20 busybox-static-1.36.1-r31(armv7) 패키지의 /bin/busybox.static(정적 링크, NX4 내비에서 그대로 돈다).
# NOTICE.md에 적은 SHA-256 두 개로 확인한다. 받은 패키지 파일(apk SHA-256)을 풀기 전에 보고, 꺼낸 busybox(SHA-256)를 둔 뒤
# 쓰기 전에 본다. 하나라도 다르면 아무것도 두지 않고 멈춘다. 받은 것은 실행하지 않는다.
# 그 폴더에 이미 같은 SHA-256의 busybox가 있으면 다시 받지 않는다(라이선스 안내는 늘 다시 쓴다).
# 필요한 것: curl, python3, 인터넷(받을 때).
# NX4_BUSYBOX_URL: 받을 주소(기본은 아래 Alpine CDN. 미러를 쓸 때. 같은 파일이어야 한다). https만(시험은 file://)
set -e
B=$(cd "$(dirname "$0")/.." && pwd)
D=$1
[ -n "$D" ] || { echo "쓰는 법: sh scripts/fetch-busybox.sh <폴더>" >&2; exit 2; }
URL=${NX4_BUSYBOX_URL:-https://dl-cdn.alpinelinux.org/alpine/v3.20/main/armv7/busybox-static-1.36.1-r31.apk}
# NOTICE.md BusyBox 절: "  - SHA-256 `<busybox>`", "  - … apk SHA-256 `<패키지 파일>`"
EXP=$(sed -n 's/^ *- SHA-256 `\([0-9a-f]\{64\}\)`.*/\1/p' "$B/NOTICE.md" | head -1)
EXPPKG=$(sed -n 's/.*apk SHA-256 `\([0-9a-f]\{64\}\)`.*/\1/p' "$B/NOTICE.md" | head -1)
[ -n "$EXP" ] && [ -n "$EXPPKG" ] || { echo "NOTICE.md에서 busybox와 패키지(apk)의 SHA-256을 읽지 못했습니다" >&2; exit 1; }
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

# 라이선스 안내(GPL-2.0: 대응 소스 위치). 문구를 고치면 이미 받아 둔 폴더에도 반영되게 늘 다시 쓴다
notice() {
  cat > "$1" <<EOF
BusyBox 1.36.1: 이 모드의 bin/busybox (GNU GPL 2.0)

bin/busybox는 BusyBox(https://busybox.net)입니다. NX4 KOR(AGPL-3.0)와 따로 동작하는 프로그램이고,
GNU General Public License 2.0으로 배포됩니다. 고치지 않고 그대로 넣었습니다.

- 파일: Alpine Linux 3.20 busybox-static-1.36.1-r31 패키지(armv7)의 /bin/busybox.static
  SHA-256 $EXP
- 대응 소스
  - BusyBox 1.36.1: https://busybox.net/downloads/busybox-1.36.1.tar.bz2
  - Alpine 빌드 설정·패치(APKBUILD, 설정 파일, 패치): https://gitlab.alpinelinux.org/alpine/aports/-/tree/3.20-stable/main/busybox
- 라이선스 원문: https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
- 소스를 받기 어려우면 https://github.com/jay-park-lab/hmgapi-nx4-kor/issues 로 알려 주세요. 위 소스를 직접 보내 드립니다.
EOF
  chmod 644 "$1"
}

if [ -f "$D/busybox" ] && [ "$(sha "$D/busybox")" = "$EXP" ]; then
  notice "$D/busybox-LICENSE.txt.tmp"
  mv -f "$D/busybox-LICENSE.txt.tmp" "$D/busybox-LICENSE.txt"
  echo "busybox: 이미 받아 둠($D/busybox)"
  exit 0
fi

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
curl -fsSL --retry 3 --proto '=https,file' --proto-redir '=https' --tlsv1.2 -o "$W/pkg.apk" "$URL" \
  || { echo "busybox 패키지를 받지 못했습니다: $URL" >&2; exit 1; }
GOT=$(sha "$W/pkg.apk")
[ "$GOT" = "$EXPPKG" ] || { echo "busybox 패키지 SHA-256($GOT)이 NOTICE.md의 apk SHA-256($EXPPKG)과 다릅니다: $URL" >&2; exit 1; }
# apk는 gzip으로 이어 붙인 tar다. 파일로 풀지 않고 bin/busybox.static만 읽어 쓴다
python3 -I - "$W/pkg.apk" "$W/busybox" <<'PY'
import sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as t:
    for m in t:
        if m.name == "bin/busybox.static" and m.isfile():
            open(sys.argv[2], "wb").write(t.extractfile(m).read())
            break
    else:
        sys.exit("패키지에 bin/busybox.static이 없습니다")
PY
GOT=$(sha "$W/busybox")
[ "$GOT" = "$EXP" ] || { echo "busybox SHA-256($GOT)이 NOTICE.md($EXP)와 다릅니다: $URL" >&2; exit 1; }

mkdir -p "$D"
notice "$W/busybox-LICENSE.txt"
chmod 755 "$W/busybox"
mv -f "$W/busybox" "$D/busybox"
mv -f "$W/busybox-LICENSE.txt" "$D/busybox-LICENSE.txt"
echo "busybox: 받음($D/busybox, SHA-256 $EXP)"
