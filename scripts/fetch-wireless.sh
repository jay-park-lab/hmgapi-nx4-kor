#!/bin/sh
# USB 묶음에 함께 넣을 공식 무선 모드 wireless-carplay-aa(AGPL-3.0)를 그 릴리스에서 받는다(NOTICE.md "공식 무선 모드").
#   sh scripts/fetch-wireless.sh <폴더>   → <폴더>/wireless-carplay-aa-<판>.zip (고치지 않은 원본)
# 받는 것: Open-HMG/hmgapi-wireless-cp-aa 릴리스 v<WV>의 wireless-carplay-aa-<WV>.zip(HMG-API 모드 zip, 작성자 서명 포함).
# NOTICE.md에 적은 SHA-256("공식 모드 zip SHA-256 `…`")과 같을 때만 둔다. 다르면 아무것도 두지 않고 멈춘다.
# 받은 것은 풀거나 실행하지 않는다(build.sh가 mod.json만 읽어 USB에 옮겨 담는다).
# 그 폴더에 이미 같은 SHA-256의 zip이 있으면 다시 받지 않는다. 마지막 줄에 그 zip의 경로를 쓴다.
# 필요한 것: curl, 인터넷(받을 때).
# NX4_WIRELESS_URL: 받을 주소(기본은 아래 GitHub 릴리스. 미러를 쓸 때. 같은 파일이어야 한다). https만(시험은 file://)
set -e
B=$(cd "$(dirname "$0")/.." && pwd)
D=$1
[ -n "$D" ] || { echo "쓰는 법: sh scripts/fetch-wireless.sh <폴더>" >&2; exit 2; }
# 판을 바꾸면 NOTICE.md의 판·파일 이름·SHA-256과 대응 소스 줄을 함께 바꾼다(tests/mod-test.sh가 둘이 같은지 본다)
WV=2.2.0-rc.9
NAME=wireless-carplay-aa-$WV.zip
URL=${NX4_WIRELESS_URL:-https://github.com/Open-HMG/hmgapi-wireless-cp-aa/releases/download/v$WV/$NAME}
EXP=$(sed -n 's/.*공식 모드 zip SHA-256 `\([0-9a-f]\{64\}\)`.*/\1/p' "$B/NOTICE.md" | head -1)
[ -n "$EXP" ] || { echo "NOTICE.md에서 공식 무선 모드 zip의 SHA-256을 읽지 못했습니다" >&2; exit 1; }
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

if [ -f "$D/$NAME" ] && [ "$(sha "$D/$NAME")" = "$EXP" ]; then
  echo "공식 무선 모드: 이미 받아 둠"
  echo "$D/$NAME"
  exit 0
fi

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
curl -fsSL --retry 3 --proto '=https,file' --proto-redir '=https' --tlsv1.2 -o "$W/$NAME" "$URL" \
  || { echo "공식 무선 모드를 받지 못했습니다: $URL" >&2; exit 1; }
GOT=$(sha "$W/$NAME")
[ "$GOT" = "$EXP" ] || { echo "공식 무선 모드 zip SHA-256($GOT)이 NOTICE.md($EXP)와 다릅니다: $URL" >&2; exit 1; }
mkdir -p "$D"
chmod 644 "$W/$NAME"
mv -f "$W/$NAME" "$D/$NAME"
echo "공식 무선 모드: 받음(SHA-256 $EXP)"
echo "$D/$NAME"
