#!/bin/sh
# USB Wi-Fi 동글 드라이버(.ko)를 Docker로 빌드한다(#48, drivers/README.md). PC에서만 돈다. 내비에는 아무것도 하지 않는다.
# 쓰는 법(저장소 맨 위에서):
#   sh scripts/build-driver.sh              이 저장소의 드라이버 → out/drivers/tcc803x/
#   sh scripts/build-driver.sh --kp-check   Korea Projection 1.8.0-beta.2의 88x2bu.ko와 md5까지 같은지 → out/drivers/kp-check/
# 필요한 것: docker(linux/amd64를 돌릴 수 있어야 함. Apple Silicon은 colima 등의 qemu 에뮬레이션). 받은 자료와 준비한 커널은
# Docker 볼륨 nx4kor-drivers에 두고 다시 쓴다(처음은 받기·커널 준비로 오래 걸림). 지우려면 docker volume rm nx4kor-drivers.
# 빌드 날짜·시각(.ko에 문자열로 들어감)은 drivers/나 이 스크립트를 마지막으로 바꾼 커밋의 시각으로 고정한다. 그래서 같은
# 커밋이면 같은 .ko가 나와야 하고(다르면 에뮬레이션 쪽을 의심), 문서처럼 드라이버와 상관없는 커밋만 쌓여서는 .ko가 바뀌지 않는다(얕은 클론은 안 됨).
# 환경 변수: NX4_DRV_JOBS(make -j), NX4_DRV_TRIES(에뮬레이션 충돌 때 make를 모두 몇 번까지 돌릴지, 기본 8),
#            NX4_DRV_VOLUME(볼륨 이름), NX4_DRV_IMAGE(이미지 이름)
# 이 스크립트는 저장소의 다른 PC 스크립트처럼 AGPL-3.0이다. 컨테이너 안에서 도는 drivers/는 GPL-2.0(drivers/COPYING).
set -eu
B=$(cd "$(dirname "$0")/.." && pwd)
MODE=nx4
case "${1:-}" in
  --kp-check) MODE=kp-check ;;
  "") ;;
  *) echo "쓰는 법: sh scripts/build-driver.sh [--kp-check]"; exit 1 ;;
esac
command -v docker >/dev/null 2>&1 || { echo "docker가 없습니다"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker가 돌고 있지 않습니다(colima start 등)"; exit 1; }
IMG=${NX4_DRV_IMAGE:-nx4kor-drvbuild}
VOL=${NX4_DRV_VOLUME:-nx4kor-drivers}
OUT=$B/out/drivers
mkdir -p "$OUT"

docker build -q --platform linux/amd64 -t "$IMG" "$B/drivers" >/dev/null
# Docker VM이 이 폴더를 볼 수 있는지(colima 등은 홈 폴더 같은 정해진 곳만 VM에 붙인다. 붙지 않은 곳이면 빈 폴더로 보임)
docker run --rm --platform linux/amd64 -v "$B/drivers":/src/drivers:ro "$IMG" test -f /src/drivers/build-in-container.sh \
  || { echo "Docker가 이 저장소 폴더를 보지 못합니다($B). Docker VM에 공유된 곳(예: 홈 폴더 아래)으로 옮겨 돌려 주세요"; exit 1; }

# drivers/나 이 스크립트를 마지막으로 바꾼 커밋의 시각(UTC)을 __DATE__ 꼴("Nov 25 2026", 날이 한 자리면 앞을 빈칸으로)과
# __TIME__ 꼴로. 달 이름이 로캘을 따르지 않게 LC_ALL=C(한국어 로캘이면 "11월"이 되어 CI와 .ko가 달라짐)
if [ "$(git -C "$B" rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then
  echo "얕은 클론에서는 빌드 날짜를 정할 수 없습니다(git fetch --unshallow, CI는 checkout fetch-depth: 0)"; exit 1
fi
T=$(git -C "$B" log -1 --format=%ct -- drivers scripts/build-driver.sh 2>/dev/null || true)
[ -n "$T" ] || { echo "drivers/를 바꾼 커밋을 찾지 못했습니다(git 저장소에서 돌려 주세요)"; exit 1; }
BDATE=$(LC_ALL=C TZ=UTC date -r "$T" '+%b %e %Y' 2>/dev/null || LC_ALL=C TZ=UTC date -d "@$T" '+%b %e %Y')
BTIME=$(LC_ALL=C TZ=UTC date -r "$T" '+%H:%M:%S' 2>/dev/null || LC_ALL=C TZ=UTC date -d "@$T" '+%H:%M:%S')
case "$BDATE $BTIME" in
  [A-Z][a-z][a-z]\ [\ 1-3][0-9]\ [0-9][0-9][0-9][0-9]\ [0-2][0-9]:[0-5][0-9]:[0-5][0-9]) ;;
  *) echo "빌드 날짜 꼴이 다릅니다: $BDATE $BTIME"; exit 1 ;;
esac
[ -z "$(git -C "$B" status --porcelain -- drivers scripts/build-driver.sh 2>/dev/null)" ] \
  || echo "알림: drivers/나 이 스크립트에 커밋하지 않은 수정이 있습니다(그 수정으로 빌드하지만 날짜는 마지막 커밋의 것)"

# 빌드한 곳의 CPU. x86_64가 아니면 linux/amd64 컨테이너는 에뮬레이션(qemu 등)으로 돈다. 에뮬레이션에서는 컴파일러가 멈추지
# 않고도 다른 코드를 낸 적이 있다(PR #69, 572128e: 첫 빌드 md5 5035d662…, 다시 빌드하니 CI와 같은 aabf4de7…).
# 그래서 차에 넣을 .ko는 리눅스 x86(CI·release 워크플로)에서 만든 것만 쓴다. 정보 파일에 남기고 끝에 알린다.
# 에뮬레이션인지는 Docker VM의 CPU(docker info)와 맥의 Apple Silicon 여부(hw.optional.arm64)로 본다. Rosetta로 돈 터미널에서는
# uname -m이 x86_64라 그것만으로는 모른다(PR #69 리뷰 15)
DARCH=$(docker info --format '{{.Architecture}}' 2>/dev/null || echo unknown)
EMU=no
case "$DARCH" in x86_64|amd64) ;; *) EMU=yes ;; esac
[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] && EMU=yes
HOST_ARCH="docker $DARCH, $(uname -s) $(uname -m)"
docker run --rm --platform linux/amd64 \
  -v "$VOL":/work -v "$B/drivers":/src/drivers:ro -v "$OUT":/out \
  -e MODE=$MODE -e JOBS="${NX4_DRV_JOBS:-}" -e MAKE_TRIES="${NX4_DRV_TRIES:-8}" -e BUILD_DATE="$BDATE" -e BUILD_TIME="$BTIME" \
  -e HOST_ARCH="$HOST_ARCH" -e BUILD_EMU=$EMU \
  "$IMG" bash /src/drivers/build-in-container.sh
case "$EMU" in
  no) ;;
  *) echo "알림: 이 PC($HOST_ARCH)에서는 에뮬레이션으로 빌드했습니다. 에뮬레이션은 멈추지 않고도 다른 코드를 낼 수 있어, 이 .ko는 차에 넣지 마세요."
     echo "      확인용입니다. 같은 커밋의 CI(drivers 워크플로) md5와 견주고, 차에는 CI·release 워크플로가 만든 .ko를 씁니다(drivers/README.md)." ;;
esac
