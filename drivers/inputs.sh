# USB Wi-Fi 동글 드라이버 빌드에 쓰는 바깥 자료(#48). 모두 공개 자료이고, 받은 뒤 아래 값으로 같은 것인지 확인한다.
# drivers/build-in-container.sh가 읽는다(. 으로). 값을 바꾸면 drivers/README.md 표도 함께 고친다.

# 커널: kernel.org 3.18.24(차 커널 3.18.24-tcc의 바탕)
KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.18.24.tar.xz
KERNEL_SHA256=ed54cf8c3ac6b95fc17b07b3a236bc42719c96fee08fe696cabfb5b8e07f8c1b

# 툴체인: AOSP arm-eabi-4.7(kitkat-release 브랜치의 커밋 8b880805로 고정). 순정 모듈이 "GNU C 4.7"로 빌드됨.
# googlesource의 묶음 파일은 받을 때마다 만들어져 묶음의 sha256은 고정되지 않는다. 그래서 푼 폴더 전체 값(lib.sh tree_sum:
# 모든 파일의 sha256과 링크)으로 확인한다. 그 안의 bin/arm-eabi-gcc는 KP가 적은 sha256 89a07707…과 같다
TOOLCHAIN_URL=https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.7/+archive/8b880805d454664b3eed11d0f053cdeafa1ff06e.tar.gz
TOOLCHAIN_TREE_SHA256=201fc60234606b9b6abb8d31ac6cd90bf3b7726c681c6ad9a0bdce7c0c7c6bee

# 차 커널 설정(tcc803x, /proc/config.gz를 푼 것). Korea Projection 1.8.0이 쓴 설정과 sha256이 같다.
# KP가 적은 출처(JongMinKim-93/jmk-gen5w-ioniq5)는 404라 같은 파일이 있는 공개 저장소의 커밋으로 고정한다.
# 우리 차(NX4HEV)의 /proc/config.gz는 USB 진단 기록(dongle/config.txt)으로 받아 이것과 견준다
CARCFG_URL=https://raw.githubusercontent.com/JMK-labs/jmk-gen5w/dcc71a04e38ed4d62263709358a021ad03792a9f/driver/config_tcc803x.txt
CARCFG_SHA256=d35af8a0e9d098a47720ea66de594f21691d3d9608ce388ed199e0a5f82f9913

# RTL88x2BU 드라이버: cilynx/rtl88x2bu(GPL-2.0). KP 1.8.0의 tcc803x 빌드와 같은 커밋
RTL88X2BU_GIT=https://github.com/cilynx/rtl88x2bu.git
RTL88X2BU_COMMIT=fc158d1f71b9e5dfcd1fccaf4d28725b65086e3b

# Korea Projection 1.8.0-beta.2 패키지의 tcc803x용 88x2bu.ko. 같은 방법으로 빌드되는지(빌드 날짜·시각을 KP 값으로
# 고정하면 md5까지 같음) 확인하는 데 쓴다(build-driver.sh --kp-check)
KP_88X2BU_MD5=e16ccc0208cb179586f71dfd67631edb
KP_88X2BU_DATE="Nov 18 2026"
KP_88X2BU_TIME="14:07:25"
