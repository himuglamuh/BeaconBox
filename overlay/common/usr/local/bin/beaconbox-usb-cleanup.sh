#!/bin/bash
set -euo pipefail

echo "[BeaconBox] Running stale USB cleanup..."

FILES_DIR="/srv/beaconbox/files"

# Lazy unmount any still-mounted but ghosted u-* mountpoints
for dir in "$FILES_DIR"/u-*; do
  if mountpoint -q "$dir"; then
    echo "[BeaconBox] Lazy unmounting $dir"
    umount -l "$dir" || echo "⚠️ Failed to lazy unmount $dir"
  fi
done

# Remove empty u-* directories
find "$FILES_DIR" -maxdepth 1 -type d -name 'u-*' -empty -exec rm -rf {} \;

# Remove broken symlinks
find "$FILES_DIR" -maxdepth 1 -type l -name 'u-*' ! -exec test -e {} \; -exec rm -f {} \;

echo "[BeaconBox] USB cleanup complete."
