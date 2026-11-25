# USB Wi-Fi 동글 드라이버 빌드 환경(#48). scripts/build-driver.sh가 linux/amd64로 만든다.
# Ubuntu 20.04: 커널 3.18의 호스트 도구가 gcc 10 이후에서는 빌드되지 않는다(Korea Projection 1.8.0도 20.04에서 빌드함).
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends build-essential bc kmod cpio xz-utils git perl curl ca-certificates \
      libncurses-dev libssl-dev bison flex libelf-dev file patch \
 && rm -rf /var/lib/apt/lists/*
