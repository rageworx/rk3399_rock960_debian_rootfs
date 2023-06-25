#!/bin/bash

# Check root-priv.

if [ ${EUID} -ne 0 ];then
    echo "run as sudo."
    exit 0
fi

DST_DIR=./binary
OVL_DIR=./overlay
OVLFW_DIR=./overlay-firmware

if [ ! -e ${DST_DIR}/etc ]; then
    echo "Overlay directory seems not generated or empty"
    exit 0
fi

cp -rf ${OVL_DIR}/* ${DST_DIR}
cp -rf ${OVLFW_DIR}/* ${DST_DIR}

