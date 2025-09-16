#!/bin/bash
set -euo pipefail

echo "[BeaconBox] Cleaning up stale USB links and dirs..."
/usr/local/bin/beaconbox-usb-cleanup.sh

DEV="$1"
NAME="$(basename "$DEV")"
MOUNT_POINT="/srv/beaconbox/files/u-$NAME"

mkdir -p "$MOUNT_POINT"
echo "[BeaconBox] Mounting $DEV at $MOUNT_POINT" >> /tmp/usb-mount.log
mount "$DEV" "$MOUNT_POINT" >> /tmp/usb-mount.log 2>&1 || echo "⚠️ Mount failed" >> /tmp/usb-mount.log
