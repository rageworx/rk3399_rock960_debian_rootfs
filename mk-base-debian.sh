#!/bin/bash -e
# Making base rootfs for Rockchip series

DO_CLEAN=1
TARGET='xfce'
RELEASE='bookworm'
ARCH='arm64'

if [ "$1" == "--noclean" ];then
    DO_CLEAN=0
fi

if [ "$TARGET" == "lite" ]; then
	BUILD_VERSION='base'
	echo -e "\033[1;36m set TARGET=lite, use $RELEASE-base-$ARCH to build ...... \033[0m"
else
	BUILD_VERSION=$TARGET
fi

if [ -e linaro-$RELEASE-$TARGET-$ARCH-alip-*.tar.gz ]; then
	rm linaro-$RELEASE-$TARGET-$ARCH-alip-*.tar.gz
fi


cd debian-build-service/$RELEASE-$BUILD_VERSION-$ARCH

echo -e "\033[1;36m Staring Download...... \033[0m"

if [ $DO_CLEAN -gt 0 ];then
make clean
fi

./configure

make

DATE=$(date +%Y%m%d)
if [ -e linaro-$RELEASE-alip-*.tar.gz ]; then
	sudo chmod 0666 linaro-$RELEASE-alip-*.tar.gz
	mv linaro-$RELEASE-alip-*.tar.gz ../../linaro-$RELEASE-$TARGET-$ARCH-alip-$DATE.tar.gz
else
	echo -e "\e[1;31m Failed to run livebuild, please check your network connection. \e[0m"
fi
