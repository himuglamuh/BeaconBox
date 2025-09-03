#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

### --- CONFIG ---

CONFIG_FILE="config.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
IMAGE_NAME="beaconbox.img"
IMAGE_SIZE="2G"
BOOT_SIZE_MB=512
OVERLAY_DIR="$SCRIPT_DIR/overlay"
DEBIAN_VERSION="bookworm"
ARCH="arm64"
MIRROR="http://deb.debian.org/debian"
RPI_FIRMWARE_URL="https://github.com/raspberrypi/firmware/archive/refs/heads/master.tar.gz"

### --- HELPERS ---

function info()  { echo -e "[+] $1"; }
function warn()  { echo -e "[!] $1"; }
function fatal() { echo -e "[X] $1" >&2; cleanup_on_error; exit 1; }
function retry_apt() {
  local cmd="$1"
  local retries=3
  local delay=5
  
  for ((i=1; i<=retries; i++)); do
    info "Running apt command (attempt $i/$retries): $cmd"
    if eval "$cmd"; then
      return 0
    else
      if [ $i -lt $retries ]; then
        warn "Apt command failed, retrying in ${delay}s..."
        sleep $delay
        delay=$((delay * 2))  # Exponential backoff
      else
        warn "Apt command failed after $retries attempts"
        return 1
      fi
    fi
  done
}
function cleanup_on_error() {
  info "Cleaning up due to error..."
  
  # Kill any running systemd-nspawn processes
  pkill -f "systemd-nspawn.*$BUILD_DIR/root" 2>/dev/null || true
  sleep 2
  
  # Try to unmount in the correct order
  if mountpoint -q "$BUILD_DIR/root/boot" 2>/dev/null; then
    sudo umount "$BUILD_DIR/root/boot" 2>/dev/null || true
    sleep 1
  fi
  if mountpoint -q "$BUILD_DIR/root" 2>/dev/null; then
    sudo umount "$BUILD_DIR/root" 2>/dev/null || true
    sleep 1
  fi
  
  # Clean up loop devices
  cleanup_loop_devices || true
  
  # Remove any temporary files
  rm -f "$BUILD_DIR/raspberrypi.gpg.key" 2>/dev/null || true
  rm -f "$BUILD_DIR/raspberrypi-archive-keyring.gpg" 2>/dev/null || true
  rm -f wget-log* 2>/dev/null || true
  
  # Reset terminal state
  reset 2>/dev/null || true
}
trap 'fatal "Build failed at line $LINENO"' ERR

### --- PREREQ CHECK ---

for cmd in debootstrap rsync mkfs.vfat mkfs.ext4 mount umount losetup parted qemu-aarch64-static wget; do
  command -v "$cmd" >/dev/null || fatal "$cmd is not installed"
done

### --- CLEANUP OLD LOOPS ---

function cleanup_loop_devices() {
  local loopdevs
  loopdevs=$(losetup -a | grep "$BUILD_DIR/$IMAGE_NAME" | cut -d: -f1 || true)
  for loop in $loopdevs; do
    sudo losetup -d "$loop" || true
  done
}

cleanup_loop_devices || true
sudo umount -R "$BUILD_DIR/root/boot" || true 2>/dev/null || true
sudo umount -R "$BUILD_DIR/root/" || true 2>/dev/null || true
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

### --- IMAGE CREATION ---

IMAGE_PATH="$BUILD_DIR/$IMAGE_NAME"

info "Allocating disk image..."
if ! fallocate -l "$IMAGE_SIZE" "$IMAGE_PATH" 2>/dev/null; then
  dd if=/dev/zero of="$IMAGE_PATH" bs=1M count=$((2 * 1024)) status=progress
fi

info "Partitioning image..."
parted "$IMAGE_PATH" --script mklabel msdos
parted "$IMAGE_PATH" --script mkpart primary fat32 1MiB "$((BOOT_SIZE_MB + 1))"MiB
parted "$IMAGE_PATH" --script set 1 boot on
parted "$IMAGE_PATH" --script mkpart primary ext4 "$((BOOT_SIZE_MB + 1))"MiB 100%

info "Setting up loop devices..."
LOOP_DEV=$(sudo losetup --show -Pf "$IMAGE_PATH")

mkfs.vfat -F 32 -n "BOOT" "${LOOP_DEV}p1"
mkfs.ext4 -F -L "BB-ROOT" "${LOOP_DEV}p2"

mkdir -p "$BUILD_DIR/root"
sudo mount "${LOOP_DEV}p2" "$BUILD_DIR/root"
sudo mkdir -p "$BUILD_DIR/root/boot"
sudo mount "${LOOP_DEV}p1" "$BUILD_DIR/root/boot"

### --- FIRST-STAGE DEBOOTSTRAP ---

info "Running first-stage debootstrap..."
sudo debootstrap --arch="$ARCH" --foreign "$DEBIAN_VERSION" "$BUILD_DIR/root" "$MIRROR"
sudo cp /usr/bin/qemu-aarch64-static "$BUILD_DIR/root/usr/bin/"

### --- SECOND-STAGE (chroot) ---

info "Running second-stage debootstrap inside chroot..."
systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf /debootstrap/debootstrap --second-stage

### --- RASPBERRY PI FIRMWARE ---

info "Downloading Raspberry Pi firmware..."
wget -O "$BUILD_DIR/firmware.tar.gz" "$RPI_FIRMWARE_URL"
tar -xzf "$BUILD_DIR/firmware.tar.gz" -C "$BUILD_DIR"

info "Installing Raspberry Pi firmware..."
sudo cp -r "$BUILD_DIR/firmware-master/boot/"* "$BUILD_DIR/root/boot/"
sudo rm -f "$BUILD_DIR/root/boot/kernel"*.img || true
sudo rm -f "$BUILD_DIR/root/boot/"*.dtb || true

### --- INSTALL PACKAGES IN CHROOT ---

info "Installing essential packages..."
cat > "$BUILD_DIR/sources.list" << EOF
deb http://deb.debian.org/debian $DEBIAN_VERSION main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security $DEBIAN_VERSION-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $DEBIAN_VERSION-updates main contrib non-free non-free-firmware
EOF

sudo cp "$BUILD_DIR/sources.list" "$BUILD_DIR/root/etc/apt/sources.list"

systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf apt update
systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf apt install -y gnupg

info "Adding Raspberry Pi Foundation GPG key..."
wget -qO "$BUILD_DIR/raspberrypi.gpg.key" https://archive.raspberrypi.org/debian/raspberrypi.gpg.key || fatal "Failed to download Pi GPG key - required for Pi packages"

if ! gpg --dearmor < "$BUILD_DIR/raspberrypi.gpg.key" > "$BUILD_DIR/raspberrypi-archive-keyring.gpg" 2>/dev/null; then
  fatal "Failed to process Pi GPG key - gpg command failed"
fi

sudo mkdir -p "$BUILD_DIR/root/usr/share/keyrings"
sudo cp "$BUILD_DIR/raspberrypi-archive-keyring.gpg" "$BUILD_DIR/root/usr/share/keyrings/raspberrypi-archive-keyring.gpg"
info "Pi GPG key installed successfully"

info "Setting up package repositories..."
cat > "$BUILD_DIR/sources.list" << EOF
deb http://deb.debian.org/debian $DEBIAN_VERSION main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security $DEBIAN_VERSION-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $DEBIAN_VERSION-updates main contrib non-free non-free-firmware
deb [signed-by=/usr/share/keyrings/raspberrypi-archive-keyring.gpg] http://archive.raspberrypi.org/debian/ $DEBIAN_VERSION main
EOF

sudo cp "$BUILD_DIR/sources.list" "$BUILD_DIR/root/etc/apt/sources.list"
retry_apt "systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf apt update" || fatal "Failed to update package lists after retries"

info "Installing core system packages..."
retry_apt "systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf apt install -y \
  linux-image-arm64 \
  firmware-brcm80211 \
  openssh-server \
  wget \
  curl \
  systemd-resolved \
  systemd-timesyncd \
  ca-certificates \
  sudo" || fatal "Failed to install core system packages after retries"

info "Installing critical Pi packages (required for boot)..."
retry_apt "systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf apt install -y raspi-firmware" || fatal "Failed to install raspi-firmware - Pi image will not boot"

info "Installing optional Pi packages..."
for pkg in pi-bluetooth libraspberrypi-bin libraspberrypi0; do
  if ! systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf apt install -y "$pkg" 2>/dev/null; then
    warn "Failed to install optional package: $pkg (continuing...)"
  else
    info "Installed optional package: $pkg"
  fi
done

### --- CONFIGURE SYSTEM ---

info "Configuring system..."

# Enable SSH
systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf systemctl enable ssh

# Configure hostname
echo "beaconbox" | sudo tee "$BUILD_DIR/root/etc/hostname"

# Configure hosts file
cat > "$BUILD_DIR/hosts" << EOF
127.0.0.1	localhost
::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters
127.0.1.1	beaconbox
EOF
sudo cp "$BUILD_DIR/hosts" "$BUILD_DIR/root/etc/hosts"

# Set up fstab
cat > "$BUILD_DIR/fstab" << EOF
proc            /proc           proc    defaults          0       0
LABEL=BOOT      /boot           vfat    defaults          0       2
LABEL=BB-ROOT   /               ext4    defaults,noatime  0       1
EOF
sudo cp "$BUILD_DIR/fstab" "$BUILD_DIR/root/etc/fstab"

# Create default user
systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf useradd -m -s /bin/bash -G sudo pi
echo 'pi:raspberry' | systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf chpasswd
echo 'root:raspberry' | systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf chpasswd

# Configure network interfaces
cat > "$BUILD_DIR/interfaces" << EOF
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

# Ethernet
auto eth0
iface eth0 inet dhcp

# WiFi (managed by wpa_supplicant)
allow-hotplug wlan0
iface wlan0 inet manual
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOF
sudo cp "$BUILD_DIR/interfaces" "$BUILD_DIR/root/etc/network/interfaces"

# Enable systemd-resolved for DNS
systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf systemctl enable systemd-resolved
systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf systemctl enable systemd-timesyncd

# Create wpa_supplicant config directory
sudo mkdir -p "$BUILD_DIR/root/etc/wpa_supplicant"
cat > "$BUILD_DIR/wpa_supplicant.conf" << EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

# Example WiFi network (uncomment and configure as needed)
# network={
#     ssid="YourNetworkName"
#     psk="YourPassword"
# }
EOF
sudo cp "$BUILD_DIR/wpa_supplicant.conf" "$BUILD_DIR/root/etc/wpa_supplicant/wpa_supplicant.conf"

# Configure locale and timezone
echo 'LANG=en_US.UTF-8' | sudo tee "$BUILD_DIR/root/etc/default/locale"
systemd-nspawn -D build/root --bind-ro=/etc/resolv.conf ln -sf /usr/share/zoneinfo/UTC /etc/localtime

### --- OVERLAY COPY ---

info "Copying overlays..."
sudo rsync -a "$OVERLAY_DIR/common/" "$BUILD_DIR/root/" --chown=0:0
sudo rsync -rt --no-owner --no-group "$OVERLAY_DIR/pi/boot/" "$BUILD_DIR/root/boot/"

### --- FINAL CLEANUP ---

info "Image creation complete: $IMAGE_PATH"
info "Flash the image to your SD card using: 'sudo dd if=$IMAGE_PATH of=/dev/sdX bs=4M status=progress conv=fsync' or use the Raspberry Pi Imager tool."

info "Cleaning up..."

# Kill any remaining systemd-nspawn processes
pkill -f "systemd-nspawn.*$BUILD_DIR/root" 2>/dev/null || true
sleep 2

# Remove files from chroot
sudo rm -f "$BUILD_DIR/root/usr/bin/qemu-aarch64-static" || true

# Remove build artifacts
sudo rm -rf "$BUILD_DIR/firmware-master" || true
sudo rm -f "$BUILD_DIR/firmware.tar.gz" || true
sudo rm -f "$BUILD_DIR/sources.list" || true
sudo rm -f "$BUILD_DIR/hosts" || true
sudo rm -f "$BUILD_DIR/fstab" || true
sudo rm -f "$BUILD_DIR/interfaces" || true
sudo rm -f "$BUILD_DIR/wpa_supplicant.conf" || true
sudo rm -f "$BUILD_DIR/raspberrypi.gpg.key" || true
sudo rm -f "$BUILD_DIR/raspberrypi-archive-keyring.gpg" || true
rm -f wget-log* || true

# Unmount in proper order with retries
for i in {1..3}; do
  if mountpoint -q "$BUILD_DIR/root/boot" 2>/dev/null; then
    sudo umount "$BUILD_DIR/root/boot" 2>/dev/null && break || sleep 2
  else
    break
  fi
done

for i in {1..3}; do
  if mountpoint -q "$BUILD_DIR/root" 2>/dev/null; then
    sudo umount "$BUILD_DIR/root" 2>/dev/null && break || sleep 2
  else
    break
  fi
done

# Detach loop device with retry
for i in {1..3}; do
  if sudo losetup -d "$LOOP_DEV" 2>/dev/null; then
    break
  else
    sleep 2
  fi
done

info "Build completed successfully!"
