#!/usr/bin/env bash
set -euo pipefail

# BeaconBox Prerequisites Installation Script
# This script installs the necessary tools to build Raspberry Pi images

function info()  { echo -e "[+] $1"; }
function warn()  { echo -e "[!] $1"; }
function fatal() { echo -e "[X] $1" >&2; exit 1; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   fatal "This script should not be run as root (use regular user with sudo access)"
fi

# Detect distribution
if command -v apt >/dev/null 2>&1; then
    DISTRO="debian"
elif command -v dnf >/dev/null 2>&1; then
    DISTRO="fedora"
elif command -v pacman >/dev/null 2>&1; then
    DISTRO="arch"
else
    fatal "Unsupported distribution. This script supports Debian/Ubuntu, Fedora, and Arch Linux."
fi

info "Detected distribution: $DISTRO"

case $DISTRO in
    "debian")
        info "Installing prerequisites for Debian/Ubuntu..."
        sudo apt update
        sudo apt install -y \
            debootstrap \
            rsync \
            dosfstools \
            e2fsprogs \
            parted \
            qemu-user-static \
            binfmt-support \
            systemd-container \
            wget \
            curl \
            build-essential \
            squashfs-tools \
            grub-pc-bin \
            grub-efi-amd64-bin \
            xorriso \
            iw \
            nftables \
            net-tools \
            iproute2
        ;;
    "fedora")
        info "Installing prerequisites for Fedora..."
        sudo dnf install -y \
            debootstrap \
            rsync \
            dosfstools \
            e2fsprogs \
            parted \
            qemu-user-static \
            systemd-container \
            wget \
            curl \
            @development-tools \
            squashfs-tools \
            grub2-pc \
            grub2-efi-x64 \
            xorriso \
            iw \
            nftables \
            net-tools \
            iproute
        ;;
    "arch")
        info "Installing prerequisites for Arch Linux..."
        sudo pacman -S --needed \
            debootstrap \
            rsync \
            dosfstools \
            e2fsprogs \
            parted \
            qemu-user-static \
            qemu-user-static-binfmt \
            systemd \
            wget \
            curl \
            base-devel \
            squashfs-tools \
            grub \
            libisoburn \
            iw \
            nftables \
            net-tools \
            iproute2
        ;;
esac

info "Prerequisites installed successfully!"
info "You can now run './build-pi.sh' to build your Raspberry Pi image."

# Verify installation
info "Verifying installation..."
MISSING_TOOLS=()

for cmd in debootstrap rsync mkfs.vfat mkfs.ext4 parted qemu-aarch64-static systemd-nspawn wget curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$cmd")
    fi
done

if [[ ${#MISSING_TOOLS[@]} -eq 0 ]]; then
    info "All required tools are available!"
else
    warn "Missing tools: ${MISSING_TOOLS[*]}"
    warn "Please install them manually or report this as an issue."
fi

