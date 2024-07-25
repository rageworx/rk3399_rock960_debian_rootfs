#!/bin/bash -e

# prevent perl warnings.
export LC_ALL=C
export LC_CTYPE=C

# Directory contains the target rootfs
TARGET_ROOTFS_DIR="binary"

if [ "$ARCH" == "armhf" ]; then
	ARCH='armhf'
elif [ "$ARCH" == "arm64" ]; then
	ARCH='arm64'
else
    echo -e "\033[36mAutomatically set ARCH default to arm64...\033[0m"
    ARCH='arm64'
fi

if [ ! $VERSION ]; then
	VERSION="debug"
fi

if [ ! -e linaro-buster-alip-*.tar.gz ]; then
	echo "\033[36m Run mk-base-debian.sh first \033[0m"
fi

MNTD=0

finish() {
    echo -e "\033[31m Error occured !\033[0m"
    if [ $MNTD -eq 1 ];then
	    sudo umount $TARGET_ROOTFS_DIR/dev
    fi
	exit -1
}
trap finish ERR

echo -e "\033[36m Extract image \033[0m"
sudo tar -xpf linaro-buster-alip-*.tar.gz

echo -e "\033[36m Copy overlay to rootfs \033[0m"
sudo mkdir -p $TARGET_ROOTFS_DIR/packages
sudo cp -rf packages/$ARCH/* $TARGET_ROOTFS_DIR/packages

# some configs
sudo cp -rf overlay/* $TARGET_ROOTFS_DIR/

echo -e "\033[36m Copy wifi drivers \033[0m"
if [ "$ARCH" == "armhf"  ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_32 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_32 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
elif [ "$ARCH" == "arm64"  ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_64 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_64 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
fi

# bt,wifi,audio firmware
echo -e "\033[36m Copy BT,audio drivers \033[0m"
if [ ! -e $TARGET_ROOTFS_DIR/system/lib/modules ];then
    sudo mkdir -p $TARGET_ROOTFS_DIR/system/lib/modules/
fi
if [ -e ../kernel/drivers/net/wireless/rockchip_wlan ];then
sudo find ../kernel/drivers/net/wireless/rockchip_wlan/*  -name "*.ko" | \
    xargs -n1 -i sudo cp {} $TARGET_ROOTFS_DIR/system/lib/modules/
fi

echo -e "\033[36m Copy overlay firmwares \033[0m"
sudo cp -rf overlay-firmware/* $TARGET_ROOTFS_DIR/

if [ -d "../modules" ]; then
    echo -e "\033[36m Copy addtional modules \033[0m"
    sudo cp -r ../modules/lib/modules $TARGET_ROOTFS_DIR/lib
fi

# adb
if [ "$ARCH" == "armhf" ]; then
	sudo cp -rf overlay-debug/usr/local/share/adb/adbd-32 $TARGET_ROOTFS_DIR/usr/local/bin/adbd
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp -rf overlay-debug/usr/local/share/adb/adbd-64 $TARGET_ROOTFS_DIR/usr/local/bin/adbd
fi

# glmark2
sudo rm -rf $TARGET_ROOTFS_DIR/usr/local/share/glmark2
sudo mkdir -p $TARGET_ROOTFS_DIR/usr/local/share/glmark2
if [ "$ARCH" == "armhf" ]; then
	sudo cp -rf overlay-debug/usr/local/share/glmark2/armhf/share/* $TARGET_ROOTFS_DIR/usr/local/share/glmark2
	sudo cp overlay-debug/usr/local/share/glmark2/armhf/bin/glmark2-es2 $TARGET_ROOTFS_DIR/usr/local/bin/glmark2-es2
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp -rf overlay-debug/usr/local/share/glmark2/aarch64/share/* $TARGET_ROOTFS_DIR/usr/local/share/glmark2
	sudo cp overlay-debug/usr/local/share/glmark2/aarch64/bin/glmark2-es2 $TARGET_ROOTFS_DIR/usr/local/bin/glmark2-es2
fi

if [ "$VERSION" == "debug" ] || [ "$VERSION" == "jenkins" ]; then
	# adb, video, camera  test file
	sudo cp -rf overlay-debug/etc $TARGET_ROOTFS_DIR/
	sudo cp -rf overlay-debug/lib $TARGET_ROOTFS_DIR/usr/
	sudo cp -rf overlay-debug/usr $TARGET_ROOTFS_DIR/
fi

if  [ "$VERSION" == "jenkins" ] ; then
	# network
	sudo cp -b /etc/resolv.conf  $TARGET_ROOTFS_DIR/etc/resolv.conf
fi

echo ">>>"
echo -e "\033[36m Change root on [\033[37m$TARGET_ROOTFS_DIR\033[36m]\033[0m"
echo "<<<"

if [ "$ARCH" == "armhf" ]; then
	sudo cp /usr/bin/qemu-arm-static $TARGET_ROOTFS_DIR/usr/bin/
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/
fi

echo -e " ... Bind-mounting /dev to $TARGET_ROOTFS_DIR/dev ... "
sudo mount -o bind /dev $TARGET_ROOTFS_DIR/dev
MNTD=1

cat << EOF | sudo chroot $TARGET_ROOTFS_DIR

chmod o+x /usr/lib/dbus-1.0/dbus-daemon-launch-helper
apt-get update
apt-get upgrade
apt-get install -y lxpolkit

echo exit 101 > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

#---------------vim, hdparm, ethtool-------
rm -rf /usr/share/vim/vim81/doc/*
apt-get install -y vim vim-runtime
apt --fix-broken install hdparm ethtool

#---------------power management --------------
apt-get install -y busybox pm-utils triggerhappy
cp /etc/Powermanager/triggerhappy.service  /lib/systemd/system/triggerhappy.service

#---------------ForwardPort Linaro overlay --------------
apt-get install -y e2fsprogs
wget https://releases.linaro.org/obs/linaro-overlay-buster/buster/all/linaro-overlay-minimal_1112.14_all.deb
wget https://releases.linaro.org/obs/linaro-overlay-buster/buster/all/96boards-tools-common_0.9_all.deb
dkpg -i *.deb
rm -rf *.deb
apt-get --fix-broken install -f -y

#---------------conflict workaround --------------
apt-get remove -y xserver-xorg-input-evdev
apt-get --fix-broken install -y xserver-xorg-input-all
apt-get --fix-broken install -y libfontenc-dev
apt-get --fix-broken install -y libx11-dev
apt-get --fix-broken install -y libdrm-dev
apt-get --fix-broken install -y libxfont-dev
apt-get --fix-broken install -y libunwind8 xserver-xorg-input-libinput 
apt-get --fix-broken install -y libdmx1 
apt-get --fix-broken install -y ibxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libxcb-xf86dri0 libxcb-xv0 libpixman-1-dev
apt-get --fix-broken install -y libxkbfile-dev libpciaccess-dev 
apt-get --fix-broken install -y mesa-common-dev

#---------------Video--------------
echo -e "\033[36m Setup Video.................... \033[0m"
apt-get install -y gstreamer1.0-plugins-base gstreamer1.0-tools gstreamer1.0-alsa gstreamer1.0-plugins-good  gstreamer1.0-plugins-bad alsa-utils

if [ -e /packages/$ARCH/video/mpp ];then
    dpkg -i  /packages/$ARCH/video/mpp/*.deb
    apt-get install -f -y
fi

#-----------MESA, XFCE4-----------
apt-get install -y nano pciutils
apt-get remove -y gnome-shell gnome-session*
apt-get install -y gnome-session-bin gnome-shell gdm3
apt-get install -y xfce4 lightdm
apt-get install -y xfce4-power-manager xfce4-power-manager-plugins

#--------------libdrm----------------
if [ -e /packages/$ARCH/libdrm ];then
   dpkg -i /packages/$ARCH/libdrm/libdrm-rockchip*_$ARCH.deb
   apt-get install -f -y
fi

#---------------TODO: USE DEB-------------- 

#---------SDL2+FFmpeg---------
apt-get install -y libsdl2-2.0-0:$ARCH libcdio-paranoia1:$ARCH libjs-bootstrap:$ARCH libjs-jquery:$ARCH
apt-get install -y ffmpeg:$ARCH

#-------------exFAT and fuse----------
apt-get install -y exfat-fuse:$ARCH exfat-utils:$ARCH

#---------------Custom Script-------------- 
systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service
systemctl mask wpa_supplicant-nl80211@.service
systemctl mask wpa_supplicant-wired@.service
systemctl mask wpa_supplicant.service
rm /lib/systemd/system/wpa_supplicant@.service

#---------------Clean-------------- 
ldconfig
rm -rf /var/lib/apt/lists/*
apt-get autoremove

EOF

sudo umount $TARGET_ROOTFS_DIR/dev
MNTD=0
