## Introduction
A set of shell scripts that will build GNU/Linux distribution rootfs image
for rockchip platform.

## Available Distro
* Debian 10 (Buster-X11 and Wayland)
```
$ sudo dpkg -i ubuntu-build-service/packages/*
$ sudo apt-get install -f
```

## Default architecture target
* arm64.

## Upgrade QEMU
* Test your QEMU version,
```
$ qemu-aarch64-static --version
qemu-aarch64 version 2.5.0 (Debian 1:2.5+dfsg-5ubuntu10.51), Copyright (c) 2003-2008 Fabrice Bellard
```
* If qemu version is 2.5.0 or belower than 4.1.0, need to build it manually.
```
$ wget https://download.qemu.org/qemu-4.1.0.tar.xz 
$ mkdir qemu-4.1.0
$ tar -xf qemu-4.1.0.tar.xz -C qemu-4.1.0
$ cd qemu-4.1.0
$ ./configure --target-list=aarch64-linux-user --static
$ make
```
* Then install it to your system manually.
```
$ sudo cp aarch64-linux-user/qemu-aarch64 /usr/bin/qemu-aarch64-staic
```
* qemu 4.1.0 will prevent to occur errors about unhandled signal.

## Usage for 32bit Debian 10 (Buster-32)
Building a base debian system by ubuntu-build-service from linaro.

	RELEASE=buster TARGET=desktop ARCH=armhf ./mk-base-debian.sh

Building the rk-debian rootfs:

	RELEASE=buster ARCH=armhf ./mk-rootfs.sh

Building the rk-debain rootfs with debug:

	VERSION=debug ARCH=armhf ./mk-rootfs-buster.sh

Creating the ext4 image(linaro-rootfs.img):

	./mk-image.sh
---

## Usage for 64bit Debian 10 (Buster-64)
Building a base debian system by ubuntu-build-service from linaro.

	RELEASE=buster TARGET=desktop ARCH=arm64 ./mk-base-debian.sh

Building the rk-debian rootfs:

	RELEASE=buster ARCH=arm64 ./mk-rootfs.sh

Building the rk-debain rootfs with debug:

	VERSION=debug ARCH=arm64 ./mk-rootfs-buster.sh

Creating the ext4 image(linaro-rootfs.img):

	./mk-image.sh
---

## Cross Compile for ARM Debian

[Docker + Multiarch](http://opensource.rock-chips.com/wiki_Cross_Compile#Docker)

## Package Code Base

Please apply [those patches](https://github.com/rockchip-linux/rk-rootfs-build/tree/master/packages-patches) to release code base before rebuilding!

## Wayland issue
* xwayland + gbm3 will not works correctly by Rockchip RK3399 T860 GPU support issue by libEGL and libGBM.
* It is still developing for weston.
