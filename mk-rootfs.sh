#!/bin/bash -e

if [ ! $RELEASE ]; then
	RELEASE='buster'
fi

./mk-rootfs-$RELEASE.sh
