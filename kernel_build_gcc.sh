#!/usr/bin/env bash
#
# Copyright (C) 2021 a xyzprjkt property
#

# Needed Secret Variable
# KERNEL_NAME | Your kernel name
# KERNEL_SOURCE | Your kernel link source
# KERNEL_BRANCH  | Your needed kernel branch if needed with -b. eg -b eleven_eas
# DEVICE_CODENAME | Your device codename
# DEVICE_DEFCONFIG | Your device defconfig eg. lavender_defconfig
# ANYKERNEL | Your Anykernel link repository if needed with -b. eg -b anykernel
# TG_TOKEN | Your telegram bot token
# TG_CHAT_ID | Your telegram private ci chat id
# BUILD_USER | Your username
# BUILD_HOST | Your hostname

echo "Downloading few Dependecies . . ."
# Kernel Sources
git clone --depth=1 $KERNEL_SOURCE $KERNEL_BRANCH $DEVICE_CODENAME
git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 -b gcc-master eva64
git clone --depth=1 https://github.com/mvaisakh/gcc-arm -b gcc-master eva32

# Main Declaration
KERNEL_ROOTDIR=$(pwd)/$DEVICE_CODENAME # IMPORTANT ! Fill with your kernel source root directory.
DEVICE_DEFCONFIG=$DEVICE_DEFCONFIG # IMPORTANT ! Declare your kernel source defconfig file here.
GCC64_ROOTDIR=$(pwd)/eva64 # IMPORTANT! Put your gcc arm64 directory here.
GCC32_ROOTDIR=$(pwd)/eva32 # IMPORTANT! Put your gcc arm directory here. 
ANYKERNEL_ROOTDIR=$(pwd)/$DEVICE_CODENAME/AnyKernel #IMPORTANT! Put your anykernel directory here. 
export KBUILD_BUILD_USER=$BUILD_USER # Change with your own name or else.
export KBUILD_BUILD_HOST=$BUILD_HOST # Change with your own hostname.
GCC_VER="$("$GCC64_ROOTDIR"/bin/aarch64-elf-gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
LLD_VER="$("$GCC64_ROOTDIR"/bin/aarch64-elf-ld.lld --version | head -n 1)"
export KBUILD_COMPILER_STRING="$GCC_VER with $LLD_VER"
IMAGE=$(pwd)/$DEVICE_CODENAME/out/arch/arm64/boot/Image.gz-dtb
DATE=$(date +"%F-%S")
START=$(date +"%s")
PATH="${PATH}:${GCC64_ROOTDIR}/bin/:{GCC32_ROOTDIR}/bin/"

# Checking environtment
# Warning !! Dont Change anything there without known reason.
function check() {
echo ================================================
echo xKernelCompiler
echo version : rev1.5 - gaspoll
echo ================================================
echo BUILDER NAME = ${KBUILD_BUILD_USER}
echo BUILDER HOSTNAME = ${KBUILD_BUILD_HOST}
echo DEVICE_DEFCONFIG = ${DEVICE_DEFCONFIG}
echo TOOLCHAIN_VERSION = ${KBUILD_COMPILER_STRING}
echo GCC64_ROOTDIR = ${GCC64_ROOTDIR}
echo GCC32_ROOTDIR = ${GCC32_ROOTDIR}
echo KERNEL_ROOTDIR = ${KERNEL_ROOTDIR}
echo ================================================
}

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
  -d "disable_web_page_preview=true" \
  -d "parse_mode=html" \
  -d text="$1"

}

# Post Main Information
tg_post_msg "<b>Cooking Kernel</b>%0AGCC Version : <code>${KBUILD_COMPILER_STRING}</code>"

# Compile
compile(){
tg_post_msg "<b>Cooking Kernel:</b><code>Compilation has started</code>"
cd ${KERNEL_ROOTDIR}
make -j$(nproc) O=out ARCH=arm64 ${DEVICE_DEFCONFIG}
make -j$(nproc) ARCH=arm64 O=out \
     CROSS_COMPILE=${GCC64_ROOTDIR}/bin/aarch64-elf- \
     CROSS_COMPILE_ARM32=${GCC32_ROOTDIR}/bin/arm-eabi- \
     AR=${GCC64_ROOTDIR}/bin/aarch64-elf-ar \
     AS=${GCC64_ROOTDIR}/bin/aarch64-elf-as \
     NM=${GCC64_ROOTDIR}/bin/aarch64-elf-nm \
     CC=${GCC64_ROOTDIR}/bin/aarch64-elf-gcc \
     LD=${GCC64_ROOTDIR}/bin/aarch64-elf-ld.lld \
     OBJCOPY=${GCC64_ROOTDIR}/bin/aarch64-elf-objcopy \
     OBJDUMP=${GCC64_ROOTDIR}/bin/aarch64-elf-objdump \
     OBJSIZE=${GCC64_ROOTDIR}/bin/aarch64-elf-size \
     READELF=${GCC64_ROOTDIR}/bin/aarch64-elf-readelf \
     STRIP=${GCC64_ROOTDIR}/bin/aarch64-elf-strip

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

  git clone --depth=1 $ANYKERNEL AnyKernel
	cp $IMAGE $ANYKERNEL_ROOTDIR
}

# Push kernel to channel
function push() {
    cd $ANYKERNEL_ROOTDIR
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=ue" \
        -F "parse_mode=html" \
        -F caption="Compile took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>$DEVICE_CODENAME</b> | <b>${KBUILD_COMPILER_STRING}</b>"
}
# Fin Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="Build throw an error(s)"
    exit 1
}

# Zipping
function zipping() {
    cd $ANYKERNEL_ROOTDIR || exit 1
    zip -r9 $KERNEL_NAME-$DEVICE_CODENAME-${DATE}.zip *
    cd ..
}
check
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
