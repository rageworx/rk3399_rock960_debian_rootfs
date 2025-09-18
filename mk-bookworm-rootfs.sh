#!/bin/bash -e

# Directory contains the target rootfs
TARGET_ROOTFS_DIR="binary"
SOC='rk3399'
TARGET='xfce'
ARCH=arm64
VERSION="release"

install_packages() {
    case $SOC in
        rk3399|rk3399pro)
        MALI=midgard-t86x-r18p0
        MALI_PKG=libmali-*$MALI*-x11*
        ISP=rkisp
        ;;
        rk3328|rk3528)
        MALI=utgard-450
        MALI_PKG=libmali-*$MALI*-x11*
        ISP=rkisp
        MIRROR=carp-rk352x
        ;;
        rk3128|rk3036)
        MALI=utgard-400
        MALI_PKG=libmali-*$MALI*-x11*
        ISP=rkisp
        ;;
        rk3562)
        MALI=bifrost-g52-g13p0
        MALI_PKG=libmali-*$MALI*-x11-wayland-gbm*
        ISP=rkaiq_rk3562
        MIRROR=carp-rk356x
        ;;
        rk356x|rk3566|rk3568)
        MALI=bifrost-g52-g13p0
        MALI_PKG=libmali-*$MALI*-x11-wayland-gbm*
        ISP=rkaiq_rk3568
        MIRROR=carp-rk356x
        ;;
        rk3576)
        MALI=bifrost-g52-g13p0
        MALI_PKG=libmali-*$MALI*-x11-wayland-gbm*
        ISP=rkaiq_rk3576
        ;;
        rk3588|rk3588s)
        MALI=valhall-g610-g24p0
        MALI_PKG=libmali-*$MALI*-x11-wayland-gbm*
        ISP=rkaiq_rk3588
        MIRROR=carp-rk3588
        ;;
    esac
}

if [ ! $VERSION ]; then
    VERSION="release"
fi

echo -e "\033[1;37m Building for $ARCH-$VERSION \033[0m"

if [ ! -e linaro-bookworm-$TARGET-$ARCH-alip-*.tar.gz ]; then
    echo "\033[1;31m Run mk-base-debian.sh first \033[0m"
    exit -1
fi

echo -e "\033[1;37m Extract image \033[0m"
sudo rm -rf $TARGET_ROOTFS_DIR
sudo tar -xpf linaro-bookworm-$TARGET-$ARCH-alip-*.tar.gz

# packages folder
sudo mkdir -p $TARGET_ROOTFS_DIR/packages
sudo cp -rpf packages/$ARCH/* $TARGET_ROOTFS_DIR/packages

#GPU/CAMERA packages folder
install_packages
sudo mkdir -p $TARGET_ROOTFS_DIR/packages/install_packages
sudo cp -rpfv packages/$ARCH/libmali/$MALI_PKG.deb $TARGET_ROOTFS_DIR/packages/install_packages
sudo cp -rpfv packages/$ARCH/${ISP:0:5}/camera_engine_$ISP*.deb $TARGET_ROOTFS_DIR/packages/install_packages

#linux kernel deb
if [ -e ../linux-headers* ]; then
    Image_Deb=$(basename ../linux-headers*)
    sudo mkdir -p $TARGET_ROOTFS_DIR/boot/kerneldeb
    sudo touch $TARGET_ROOTFS_DIR/boot/build-host
    sudo cp -vrpf ../${Image_Deb} $TARGET_ROOTFS_DIR/boot/kerneldeb
    sudo cp -vrpf ../${Image_Deb/headers/image} $TARGET_ROOTFS_DIR/boot/kerneldeb
fi

# overlay folder
echo -e "\033[1;37m Copying overlay ... \033[0m"
sudo cp -rpf overlay/* $TARGET_ROOTFS_DIR/

# overlay-firmware folder
echo -e "\033[1;37m Copying overlay-firmware ... \033[0m"
sudo cp -rpf overlay-firmware/* $TARGET_ROOTFS_DIR/

# overlay-debug folder
# adb, video, camera  test file
if [ "$VERSION" == "debug" ]; then
    echo -e "\033[1;37m Copying overlay-debug ... \033[0m"
    sudo cp -rpf overlay-debug/* $TARGET_ROOTFS_DIR/
fi

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

echo -e "\033[1;37m Change root.....................\033[0m"
ID=$(stat --format %u $TARGET_ROOTFS_DIR)

cat << EOF | sudo chroot $TARGET_ROOTFS_DIR

# Fixup owners
if [ $ID -ne 0 ]; then
fi
for u in \$(ls /home/); do
    chown -h -R \$u:\$u /home/\$u
done

ln -sf /run/resolvconf/resolv.conf /etc/resolv.conf

export LC_ALL=C.UTF-8

apt-get update
apt-get upgrade -y

export APT_INSTALL="apt-get install -fy --allow-downgrades"

echo -e "\033[1;37m ---------- Debian12 -------- \033[0m"
\${APT_INSTALL} dialog toilet u-boot-tools edid-decode logrotate fire-config lbc-test

passwd root <<IEOF
root
root
IEOF

systemctl disable apt-daily.service
systemctl disable apt-daily.timer

systemctl disable apt-daily-upgrade.timer
systemctl disable apt-daily-upgrade.service

# set localtime
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
if [[ "$TARGET" == "gnome" ]]; then
    \${APT_INSTALL} mpv fire-config-gui
elif [[ "$TARGET" == "xfce" ]]; then
    \${APT_INSTALL} mpv fire-config-gui
    chown -hR linaro:linaro /home/linaro/.config
elif [[ "$TARGET" == "lxde" ]]; then
    \${APT_INSTALL} mpv fire-config-gui
elif [ "$TARGET" == "lite" ]; then
    \${APT_INSTALL} bluez bluez-tools
fi

\${APT_INSTALL} /packages/install_packages/*.deb

\${APT_INSTALL} /boot/kerneldeb/* || true

echo -e "\033[1;37m ----- power management ----- \033[0m"
\${APT_INSTALL} pm-utils triggerhappy bsdmainutils
cp /etc/Powermanager/triggerhappy.service  /lib/systemd/system/triggerhappy.service
sed -i "s/#HandlePowerKey=.*/HandlePowerKey=ignore/" /etc/systemd/logind.conf

echo -e "\033[1;37m ----------- RGA  ----------- \033[0m"
\${APT_INSTALL} /packages/rga2/*.deb


if [[ "$TARGET" == "gnome" || "$TARGET" == "xfce" || "$TARGET" == "lxde" ]]; then
    echo -e "\033[1;37m ------ Setup Video---------- \033[0m"
    \${APT_INSTALL} gstreamer1.0-plugins-bad gstreamer1.0-plugins-base gstreamer1.0-plugins-ugly gstreamer1.0-tools gstreamer1.0-alsa \
    gstreamer1.0-plugins-base-apps

    \${APT_INSTALL} /packages/mpp/*
    \${APT_INSTALL} /packages/gst-rkmpp/*.deb
    \${APT_INSTALL} /packages/gstreamer/*.deb
    \${APT_INSTALL} /packages/gst-plugins-base1.0/*.deb
    \${APT_INSTALL} /packages/gst-plugins-bad1.0/*.deb
    \${APT_INSTALL} /packages/gst-plugins-good1.0/*.deb
elif [ "$TARGET" == "lite" ]; then
    echo -e "\033[1;37m ------ Setup Video---------- \033[0m"
    \${APT_INSTALL} /packages/mpp/*
    \${APT_INSTALL} /packages/gst-rkmpp/*.deb
fi

if [[ "$TARGET" == "gnome" ]]; then
    echo -e "\033[1;37m ----- Install Xserver------- \033[0m"
    \${APT_INSTALL} /packages/xserver/xserver-xorg-*.deb

    apt-mark hold xserver-xorg-core xserver-xorg-legacy
elif [[ "$TARGET" == "xfce" || "$TARGET" == "lxde" ]]; then
    echo -e "\033[1;37m ----- Install Xserver------- \033[0m"
    \${APT_INSTALL} /packages/xserver/*.deb

    apt-mark hold xserver-common xserver-xorg-core xserver-xorg-legacy
fi

if [[ "$TARGET" == "gnome" || "$TARGET" == "xfce" || "$TARGET" == "lxde" ]]; then
    echo -e "\033[1;37m ----- Install Camera ------- \033[0m"
    \${APT_INSTALL} cheese v4l-utils
    \${APT_INSTALL} /packages/libv4l/*.deb
    \${APT_INSTALL} /packages/cheese/*.deb

    echo -e "\033[1;37m ----- Wayland/Weston ------- \033[0m"
    \${APT_INSTALL} libseat-dev
    \${APT_INSTALL} /packages/weston/*.deb
    \${APT_INSTALL} /packages/wayland/*.deb

    echo -e "\033[1;37m -------     ibus    -------- \033[0m"
    \${APT_INSTALL} ibus ibus-libpinyin

    echo -e "\033[1;37m -------   pipewire  -------- \033[0m"
    \${APT_INSTALL} pipewire pipewire-pulse pipewire-alsa libspa-0.2-bluetooth
    \${APT_INSTALL} /packages/pipewire/*.deb
    \${APT_INSTALL} /packages/wireplumber/*.deb
    find /usr/lib/systemd/ -name "wireplumber*.service" | xargs sed -i "/Environment/s/$/ DISPLAY=:0/"

    # echo -e "\033[1;37m ------ Install openbox ----- \033[0m"
    # \${APT_INSTALL} /packages/openbox/*.deb

    if [ -e /packages/chromium ];then 
        echo -e "\033[1;37m ------ update chromium ----- \033[0m"
        \${APT_INSTALL} /packages/chromium/*.deb
    fi
fi

echo -e "\033[1;37m ------- Install libdrm ------ \033[0m"
\${APT_INSTALL} /packages/libdrm/*.deb

if [[ "$TARGET" == "gnome" || "$TARGET" == "xfce" || "$TARGET" == "lxde" ]]; then
    echo -e "\033[1;37m ------ libdrm-cursor -------- \033[0m"
    \${APT_INSTALL} /packages/libdrm-cursor/*.deb

    echo -e "\033[1;37m --------  blueman  ---------- \033[0m"
    \${APT_INSTALL} blueman
    echo exit 101 > /usr/sbin/policy-rc.d
    chmod +x /usr/sbin/policy-rc.d
    \${APT_INSTALL} blueman
    rm -f /usr/sbin/policy-rc.d

    \${APT_INSTALL} /packages/blueman/*.deb

    if [ "$VERSION" == "debug" ]; then
    echo -e "\033[1;37m ------ Install glmark2 ------ \033[0m"
    \${APT_INSTALL} /packages/glmark2/*.deb
    fi
fi

if [ -e "/usr/lib/aarch64-linux-gnu" ] ;
then
echo -e "\033[1;37m ------- move rknpu2 --------- \033[0m"
mkdir -p /etc/rockchip/pkgs
mv /packages/rknpu2/rknpu2.tar  /ect/rockchip/pkgs
fi

echo -e "\033[1;37m ----- Install rktoolkit ----- \033[0m"
\${APT_INSTALL} /packages/rktoolkit/*.deb

if [[ "$TARGET" == "gnome" || "$TARGET" == "xfce" || "$TARGET" == "lxde" ]]; then
    sed -i 's/^# *\(C.UTF-8\)/\1/' /etc/locale.gen
    echo "LANG=C.UTF-8" >> /etc/default/locale

    # Generate locale
    locale-gen
fi

# HACK debian11.3 to fix bug
#\${APT_INSTALL} fontconfig --reinstall

# HACK to disable the kernel logo on bootup
if [ -e /sys/class/graphics/fb ];then
    sed -i "/exit 0/i \ echo 3 > /sys/class/graphics/fb0/blank" /etc/rc.local
fi

# mark package to hold
apt list --upgradable | cut -d/ -f1 | xargs apt-mark hold

#---------------Custom Script--------------
systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service
systemctl disable hostapd
rm /lib/systemd/system/wpa_supplicant@.service

#---------------Clean--------------
if [ -e "/usr/lib/arm-linux-gnueabihf/dri" ] ;
then
    # Only preload libdrm-cursor for X
    sed -i "1aexport LD_PRELOAD=/usr/lib/arm-linux-gnueabihf/libdrm-cursor.so.1" /usr/bin/X
    cd /usr/lib/arm-linux-gnueabihf/dri/
    cp kms_swrast_dri.so swrast_dri.so rockchip_dri.so /
    rm /usr/lib/arm-linux-gnueabihf/dri/*.so
    mv /*.so /usr/lib/arm-linux-gnueabihf/dri/
elif [ -e "/usr/lib/aarch64-linux-gnu/dri" ];
then
    # Only preload libdrm-cursor for X
    sed -i "1aexport LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libdrm-cursor.so.1" /usr/bin/X
    cd /usr/lib/aarch64-linux-gnu/dri/
    cp kms_swrast_dri.so swrast_dri.so rockchip_dri.so /
    rm /usr/lib/aarch64-linux-gnu/dri/*.so
    mv /*.so /usr/lib/aarch64-linux-gnu/dri/
    rm /etc/profile.d/qt.sh
fi
cd -

rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/
rm -rf /packages/
rm -rf /boot/*
rm -rf /sha256sum*

EOF

TARGET=$TARGET SOC=$SOC ./mk-image.sh 
