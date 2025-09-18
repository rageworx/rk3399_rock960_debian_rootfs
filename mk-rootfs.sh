#!/bin/bash -e

if [ ! $RELEASE ]; then
	RELEASE='bookworm'
fi

if [ ! $ARCH ]; then
	ARCH='arm64'
fi

./mk-$RELEASE-rootfs.sh
