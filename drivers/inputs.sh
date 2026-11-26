# USB Wi-Fi 동글 드라이버 빌드에 쓰는 바깥 자료(#48). 모두 공개 자료이고, 받은 뒤 아래 값으로 같은 것인지 확인한다.
# drivers/build-in-container.sh가 읽는다(. 으로). 값을 바꾸면 drivers/README.md 표도 함께 고친다.

# 커널 뼈대: kernel.org 3.18.24. 모비스 커널 소스에는 맨 위 Makefile·Kconfig, scripts/ 같은 빌드 뼈대가 빠져 있어 이것으로 채운다
KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.18.24.tar.xz
KERNEL_SHA256=ed54cf8c3ac6b95fc17b07b3a236bc42719c96fee08fe696cabfb5b8e07f8c1b

# 내비 커널 소스: 현대모비스가 GPL로 공개한 AVNT STD G50 WIDE(R9) 오픈소스 묶음의 커널 폴더 AVNT5W_TCC803XKK_kernel/.
# 원본 묶음(628MB, 커널 말고 다른 것도 들어 있음)은 https://www.mobis.com/kr/tech/rnd.do#open 에서 받는다. 빌드마다 원본을
# 받지 않도록 그 커널 폴더만 고치지 않고 묶어 이 저장소의 릴리스 자산으로 올려 두고 그것을 받는다
# (scripts/build-driver.sh --src-asset이 원본에서 이 자산을 만든다. drivers/README.md "커널 소스 자산")
MOBIS_ZIP_URL='https://www.mobis.com/cmm/fms/FileDown.do?fileId=FILE_000000000053942&fileSn=0&fileNm=OSA_202511031202036150.zip'
MOBIS_ZIP_SHA256=e7533517e65fb0af24a989ea4a7877cffcb29bed02a21c99b9277b1668c3bb20
MOBIS_DIR=AVNT5W_TCC803XKK_kernel
# 자산 파일과 그 sha256(받은 파일 확인), 푼 커널 폴더의 값(lib.sh tree_sum: 모든 파일의 sha256과 경로). 폴더 값은 원본 묶음에서
# 푼 것과 같다. 자산을 누가 다시 만들어도 이 값이 같으면 원본과 같은 파일이다
MOBIS_SRC_TAG=src-mobis-avnt5w-r9
MOBIS_SRC_FILE=mobis-avnt5w-r9-kernel.tar.xz
MOBIS_SRC_URL=https://github.com/jay-park-lab/hmgapi-nx4-kor/releases/download/$MOBIS_SRC_TAG/$MOBIS_SRC_FILE
MOBIS_SRC_SHA256=f72306a8e4b33c3080c54ce5b32ac7a4fa21a9cfa017d1488334ce86a08946bc
MOBIS_TREE_SHA256=14aa37f780731ddd1193ec87fa23ff0e55133a3672c33f95db79deeb15ec66a9

# 커널 설정: 모비스 커널 소스의 defconfig(모비스 빌드 스크립트 mobis_widenew_kernel_build.sh가 쓰는 것). 차의 /proc/config.gz와는
# USB 네트워크 드라이버 3개(CDC NCM, CDC subset, NET1080)만 달라 그것을 끄고, gcc 4.7에 없는 -fstack-protector-strong을
# REGULAR로 바꾼다(drivers/kernel/prepare.sh). 그 결과의 값(lib.sh kconfig_sum: 값이 있는 CONFIG_ 줄을 정렬한 것의 sha256,
# STRONG은 REGULAR로 봄)이 차 설정의 값과 같아야 한다. 우리 차 것은 USB 진단 기록 dongle/config.txt로 견준다
# (sh drivers/config-sum.sh config.txt)
MOBIS_DEFCONFIG=tcc803x_wide_pe_common_defconfig
KCONFIG_SUM=b2d522679fd9dc31121e8b9c7608e148860556b12818a13097484fa8a7f06ba3

# 툴체인: 모비스 커널 소스에 든 toolchain/arm-eabi-4.7.tar.gz(GCC 4.7). 순정 모듈이 "GNU C 4.7"로 빌드되어 같은 것을 쓴다.
# 안의 파일은 AOSP prebuilts arm-eabi-4.7과 같다(bin/arm-eabi-gcc sha256 89a07707…)
TOOLCHAIN_PATH=toolchain/arm-eabi-4.7.tar.gz
TOOLCHAIN_SHA256=769600669848d789bbc2b587f3c0e43d7009d0b12cafa87564c91d0827613382

# RTL88x2BU 드라이버: cilynx/rtl88x2bu(GPL-2.0)
RTL88X2BU_GIT=https://github.com/cilynx/rtl88x2bu.git
RTL88X2BU_COMMIT=fc158d1f71b9e5dfcd1fccaf4d28725b65086e3b

# 오브젝트 컴파일 옵션 묶음의 지문(lib.sh check_cflags: -m·-f·-W·-O·-g·-std·-D__LINUX_ARM_ARCH__의 sha256). 커널은 make마다
# 컴파일러에 물어(cc-option) 옵션을 정하므로, 에뮬레이션에서 물음이 실패하면 모든 오브젝트가 똑같이 다른 옵션으로 컴파일될 수
# 있다. 그래서 리눅스 x86(CI)에서 나온 값으로 고정하고 다르면 실패한다(PR #69 리뷰 18).
# 커널 소스·설정·툴체인·드라이버 Makefile·EXTRA_CFLAGS를 바꾸면 CI의 "컴파일 옵션 확인" 줄의 값으로 함께 바꾼다
EXPECTED_CFLAGS_SHA256=d81069ca7b7c0ec8cc22190bbfd4a500d981d2b34d876342b96fb3840ecd877f
