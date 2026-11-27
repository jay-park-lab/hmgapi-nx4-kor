#!/bin/sh
# USB Wi-Fi 동글 드라이버(GPL-2.0, #48)의 대응 소스 묶음을 만든다. 모드에 빌드한 .ko를 실어 내므로, 같은 판의 소스를 릴리스 자산으로
# 함께 낸다(.github/workflows/release.yml). PC에서도 돈다.
#   sh scripts/driver-source.sh <나올 파일.tar.gz>
# 담는 것(맨 위 폴더 hmgapi-nx4-kor-driver-source/):
#   rtl88x2bu-<커밋>/, rtl8831bu-<커밋>/   원본 드라이버를 drivers/inputs.sh의 고정 커밋 그대로(git archive, 우리 패치 전)
#   nx4-kor/drivers/, nx4-kor/scripts/build-driver.sh·local-env.sh   이 저장소 지금 커밋의 패치·커널 준비·빌드 스크립트
#   SOURCE.txt   무엇이 들었는지, 넣지 않은 커널 소스(이 저장소의 릴리스 자산 src-mobis-avnt5w-r9, kernel.org 3.18.24)와 툴체인의
#                위치·sha256, 빌드 방법
# 커널 소스는 크기 때문에 넣지 않는다(이미 이 저장소 릴리스와 kernel.org에 있고, 빌드는 sha256으로 같은 것인지 확인함).
# drivers/나 scripts/build-driver.sh·local-env.sh에 커밋하지 않은 수정이 있으면 멈춘다(묶음이 커밋과 같아야 함).
# 필요한 것: git, tar, gzip, 인터넷(원본 드라이버 받기). 원본 주소는 NX4_DRVSRC_RTL88X2BU_GIT·NX4_DRVSRC_RTL8831BU_GIT로 바꿀 수 있다(테스트·미러)
set -e
B=$(cd "$(dirname "$0")/.." && pwd)
OUTF=$1
[ -n "$OUTF" ] || { echo "쓰는 법: sh scripts/driver-source.sh <나올 파일.tar.gz>" >&2; exit 2; }
case $OUTF in /*) ;; *) OUTF=$PWD/$OUTF ;; esac
. "$B/drivers/inputs.sh"
RTL88X2BU_GIT=${NX4_DRVSRC_RTL88X2BU_GIT:-$RTL88X2BU_GIT}
RTL8831BU_GIT=${NX4_DRVSRC_RTL8831BU_GIT:-$RTL8831BU_GIT}
# 커밋은 PC 테스트만 바꾼다(가짜 저장소). 릴리스는 inputs.sh의 고정 커밋 그대로
RTL88X2BU_COMMIT=${NX4_DRVSRC_RTL88X2BU_COMMIT:-$RTL88X2BU_COMMIT}
RTL8831BU_COMMIT=${NX4_DRVSRC_RTL8831BU_COMMIT:-$RTL8831BU_COMMIT}
REV=$(cd "$B" && git rev-parse HEAD)
[ -z "$(cd "$B" && git status --porcelain -- drivers scripts/build-driver.sh scripts/local-env.sh)" ] \
  || { echo "drivers/나 scripts/build-driver.sh·local-env.sh에 커밋하지 않은 수정이 있습니다(묶음이 커밋 $REV와 달라짐)" >&2; exit 1; }
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
R=$W/hmgapi-nx4-kor-driver-source
mkdir -p "$R"
# 원본 드라이버 하나: 받아서(bare) 고정 커밋이 있는지 보고, 그 커밋을 그대로 푼다
get() {
  git clone -q --bare "$2" "$W/$1.git" || { echo "$1을 받지 못했습니다: $2" >&2; exit 1; }
  git --git-dir="$W/$1.git" cat-file -e "$3^{commit}" 2>/dev/null || { echo "$1에 커밋 $3이 없습니다" >&2; exit 1; }
  git --git-dir="$W/$1.git" archive --prefix="$1-$3/" "$3" | tar -x -C "$R"
}
get rtl88x2bu "$RTL88X2BU_GIT" "$RTL88X2BU_COMMIT"
get rtl8831bu "$RTL8831BU_GIT" "$RTL8831BU_COMMIT"
(cd "$B" && git archive --prefix=nx4-kor/ HEAD drivers scripts/build-driver.sh scripts/local-env.sh) | tar -x -C "$R"
# .ko에 들어가는 빌드 날짜·시각(__DATE__·__TIME__): scripts/build-driver.sh와 같게, drivers/나 그 스크립트를 마지막으로 바꾼 커밋의
# 시각(UTC). 묶음만으로 빌드할 때 같은 .ko를 얻으려면 이 값이 필요하다(PR #101 리뷰 2)
BT=$(cd "$B" && git log -1 --format=%ct -- drivers scripts/build-driver.sh)
BDATE=$(LC_ALL=C TZ=UTC date -r "$BT" '+%b %e %Y' 2>/dev/null || LC_ALL=C TZ=UTC date -d "@$BT" '+%b %e %Y')
BTIME=$(LC_ALL=C TZ=UTC date -r "$BT" '+%H:%M:%S' 2>/dev/null || LC_ALL=C TZ=UTC date -d "@$BT" '+%H:%M:%S')
cat > "$R/SOURCE.txt" <<EOF
NX4 KOR USB Wi-Fi 동글 드라이버의 대응 소스 (GNU GPL-2.0, 전문은 nx4-kor/drivers/COPYING)
같은 판의 NX4 KOR 모드에 든 drivers/<드라이버>/bcmdhd.ko를 만든 소스입니다.

이 묶음에 든 것
- rtl88x2bu-$RTL88X2BU_COMMIT/: RTL88x2BU 원본 드라이버 $RTL88X2BU_GIT 커밋 $RTL88X2BU_COMMIT 그대로(패치 전)
- rtl8831bu-$RTL8831BU_COMMIT/: RTL8831BU 원본 드라이버 $RTL8831BU_GIT 커밋 $RTL8831BU_COMMIT 그대로(패치 전)
- nx4-kor/drivers/: https://github.com/jay-park-lab/hmgapi-nx4-kor 커밋 $REV 의 drivers/
  - <드라이버>/*.diff: 우리 패치. 파일 이름 차례로 원본 폴더에서 patch -p1
  - kernel/prepare.sh: 커널 트리 준비, build-in-container.sh·lib.sh·Dockerfile·inputs.sh·config-sum.sh: 빌드
  - README.md: 패치와 빌드의 설명
- nx4-kor/scripts/build-driver.sh, local-env.sh: 위 빌드를 Docker로 돌리는 스크립트와 그것이 읽는 설정 읽기(AGPL-3.0)

넣지 않은 것(크기 때문. 빌드는 sha256으로 같은 것인지 확인)
- 현대모비스가 GPL로 공개한 내비 커널 소스의 커널 폴더: $MOBIS_SRC_URL
  sha256 $MOBIS_SRC_SHA256 (원본 묶음 $MOBIS_ZIP_URL sha256 $MOBIS_ZIP_SHA256)
- 커널 뼈대 kernel.org linux-3.18.24: $KERNEL_URL
  sha256 $KERNEL_SHA256
- 툴체인: 위 모비스 커널 소스의 $TOOLCHAIN_PATH (GCC 4.7, sha256 $TOOLCHAIN_SHA256)

빌드
- 쉬운 길: 이 저장소를 커밋 $REV 로 받은 뒤(git clone, 얕은 클론이 아니게) 저장소 맨 위에서 sh scripts/build-driver.sh
  (Docker, 리눅스 x86). 원본 드라이버는 위 주소에서 같은 커밋을 다시 받고, 커널 소스는 위 주소에서 받아 sha256을 맞춘다.
  결과는 out/drivers/tcc803x/<드라이버>/bcmdhd.ko와 빌드 정보 bcmdhd.ko.txt입니다.
- 이 묶음의 파일로 직접(원본 저장소가 없어져도): 커널 트리를 nx4-kor/drivers/kernel/prepare.sh로 준비하고, 원본 폴더에
  nx4-kor/drivers/<드라이버>/*.diff를 파일 이름 차례로 patch -p1 한 뒤 nx4-kor/drivers/build-in-container.sh의 build_driver처럼
  make ARCH=arm CROSS_COMPILE=<툴체인>/bin/arm-eabi- KSRC=<커널 트리> KVER=<커널 판> USER_MODULE_NAME=bcmdhd
  <변수>="-g -Wno-builtin-macro-redefined -include pin.h" 한다. <변수>는 rtl88x2bu가 EXTRA_CFLAGS, rtl8831bu가 USER_EXTRA_CFLAGS,
  pin.h는 __DATE__·__TIME__을 아래 값으로 다시 정의하는 머리 파일.
- 만든 .ko의 md5·sha256은 같은 판 모드의 drivers/<드라이버>/bcmdhd.ko.txt와 릴리스 실행 요약에 있습니다.
- .ko에 들어가는 빌드 날짜·시각(__DATE__·__TIME__, 같은 .ko를 얻으려면 필요): BUILD_DATE="$BDATE" BUILD_TIME="$BTIME"
  (drivers/나 scripts/build-driver.sh를 마지막으로 바꾼 커밋의 시각, UTC. build-driver.sh가 git에서 이렇게 정함)
자세한 것은 nx4-kor/drivers/README.md.
EOF
mkdir -p "$(dirname "$OUTF")"
(cd "$W" && tar -cf - hmgapi-nx4-kor-driver-source | gzip -9n) > "$OUTF.tmp"
mv -f "$OUTF.tmp" "$OUTF"
echo "만듦: $OUTF ($(wc -c < "$OUTF" | tr -d ' ') 바이트, 커밋 $REV)"
