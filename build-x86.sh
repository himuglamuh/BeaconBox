#!/usr/bin/env bash
set -euo pipefail

ISO=${ISO:-beaconbox-x86.iso}
ROOTFS=./rootfs-amd64
WORKDIR=./iso
OVERLAY=./overlay

rm -f "$ISO"
sudo rm -rf "$ROOTFS" "$WORKDIR"
mkdir -p "$ROOTFS" "$WORKDIR"/{casper,boot/grub}

echo "[*] debootstrap (amd64, bookworm)…"
sudo debootstrap --arch=amd64 bookworm "$ROOTFS" http://deb.debian.org/debian

echo "[*] chroot packages + users…"
sudo chroot "$ROOTFS" /bin/bash -euxc '
  printf "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware\n" > /etc/apt/sources.list
  apt-get update
  apt-get install -y linux-image-amd64 systemd live-boot \
                     hostapd dnsmasq caddy iw wireless-regdb \
                     nftables grub-pc-bin grub-efi-amd64-bin \
                     net-tools iproute2
  useradd -m beacon || true
  echo "beacon:beacon" | chpasswd
  systemctl disable bluetooth || true; systemctl mask bluetooth || true
'

echo "[*] overlaying BeaconBox files…"
sudo rsync -a "$OVERLAY/common/" "$ROOTFS"/
sudo chmod +x "$ROOTFS"/usr/local/bin/beaconbox-apply-config "$ROOTFS"/usr/local/bin/beaconbox-net

echo "[*] enable services + render configs…"
sudo chroot "$ROOTFS" /bin/bash -euxc '
  systemctl enable hostapd dnsmasq
  systemctl enable beaconbox-net.service beaconbox-web.service nftables.service
  /usr/local/bin/beaconbox-apply-config
'

echo "[*] collect kernel/initrd and squashfs…"
KERNEL=$(basename "$ROOTFS"/boot/vmlinuz-*)
INITRD=$(basename "$ROOTFS"/boot/initrd.img-*)
cp "$ROOTFS/boot/$KERNEL" "$WORKDIR/casper/vmlinuz"
cp "$ROOTFS/boot/$INITRD" "$WORKDIR/casper/initrd"
sudo mksquashfs "$ROOTFS" "$WORKDIR/casper/filesystem.squashfs" -e boot

echo "[*] grub config…"
cat > "$WORKDIR/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5
menuentry "BeaconBox Live" {
  linux /casper/vmlinuz boot=live quiet
  initrd /casper/initrd
}
EOF

echo "[*] build ISO…"
grub-mkrescue -o "$ISO" "$WORKDIR"

echo "[✓] Built $ISO"
echo "Write to USB: sudo dd if=$ISO of=/dev/sdX bs=4M status=progress && sync"
