#!/bin/sh
# USB Wi-Fi 동글 드라이버(.ko)를 Docker로 빌드한다(#48, drivers/README.md). PC에서만 돈다. 내비에는 아무것도 하지 않는다.
# 쓰는 법(저장소 맨 위에서):
#   sh scripts/build-driver.sh              이 저장소의 드라이버 → out/drivers/tcc803x/
#   sh scripts/build-driver.sh --kp-check   Korea Projection 1.8.0-beta.2의 88x2bu.ko와 md5까지 같은지 → out/drivers/kp-check/
# 필요한 것: docker(linux/amd64를 돌릴 수 있어야 함. Apple Silicon은 colima 등의 qemu 에뮬레이션). 받은 자료와 준비한 커널은
# Docker 볼륨 nx4kor-drivers에 두고 다시 쓴다(처음은 받기·커널 준비로 오래 걸림). 지우려면 docker volume rm nx4kor-drivers.
# 빌드 날짜·시각(.ko에 문자열로 들어감)은 지금 커밋의 시각으로 고정해, 같은 커밋이면 PC와 CI가 같은 .ko를 만든다.
# 환경 변수: NX4_DRV_JOBS(make -j), NX4_DRV_VOLUME(볼륨 이름), NX4_DRV_IMAGE(이미지 이름)
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

# 커밋 시각(UTC)을 __DATE__ 꼴("Nov 25 2026", 날이 한 자리면 앞을 빈칸으로)과 __TIME__ 꼴로
T=$(git -C "$B" log -1 --format=%ct 2>/dev/null || date +%s)
BDATE=$(TZ=UTC date -r "$T" '+%b %e %Y' 2>/dev/null || TZ=UTC date -d "@$T" '+%b %e %Y')
BTIME=$(TZ=UTC date -r "$T" '+%H:%M:%S' 2>/dev/null || TZ=UTC date -d "@$T" '+%H:%M:%S')
[ -z "$(git -C "$B" status --porcelain -- drivers 2>/dev/null)" ] || echo "알림: drivers/에 커밋하지 않은 수정이 있습니다(그 수정으로 빌드함)"

docker run --rm --platform linux/amd64 \
  -v "$VOL":/work -v "$B/drivers":/src/drivers:ro -v "$OUT":/out \
  -e MODE=$MODE -e JOBS="${NX4_DRV_JOBS:-}" -e BUILD_DATE="$BDATE" -e BUILD_TIME="$BTIME" \
  "$IMG" bash /src/drivers/build-in-container.sh
