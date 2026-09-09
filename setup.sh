#!/bin/bash
# Reproduces the Mac-APFS-mount environment from scratch on this Linux-on-USB
# image (e.g. after rebuilding the image, or setting up a second stick).
# Run manually: bash setup.sh
# Needs sudo for package installs, DKMS registration, and /etc/fuse.conf.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Installing build dependencies =="
sudo apt update
sudo apt install -y fuse3 libfuse3-dev zlib1g-dev cmake git bzip2 \
    libattr1-dev libicu-dev libbz2-dev build-essential

echo "== Building apfs-fuse (userspace driver; handles encrypted volumes) =="
if [ ! -d "$HOME/apfs-fuse" ]; then
    git clone https://github.com/sgan81/apfs-fuse.git --recursive "$HOME/apfs-fuse"
fi
mkdir -p "$HOME/apfs-fuse/build"
(cd "$HOME/apfs-fuse/build" && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j"$(nproc)")

echo "== Installing linux-apfs-rw kernel module via DKMS (handles unencrypted volumes) =="
echo "   Ubuntu's packaged apfs-dkms is stale and fails to build on newer kernels;"
echo "   using upstream instead."
sudo apt purge -y apfs-dkms 2>/dev/null || true
if [ ! -d "$HOME/linux-apfs-rw" ]; then
    git clone https://github.com/linux-apfs/linux-apfs-rw.git "$HOME/linux-apfs-rw"
fi
DKMS_VERSION=$(grep PACKAGE_VERSION "$HOME/linux-apfs-rw/dkms.conf" | cut -d'"' -f2)
if [ ! -d "/usr/src/linux-apfs-rw-$DKMS_VERSION" ]; then
    sudo cp -r "$HOME/linux-apfs-rw" "/usr/src/linux-apfs-rw-$DKMS_VERSION"
    sudo dkms add -m linux-apfs-rw -v "$DKMS_VERSION"
fi
sudo dkms build -m linux-apfs-rw -v "$DKMS_VERSION" || true
sudo dkms install -m linux-apfs-rw -v "$DKMS_VERSION" || true
sudo modprobe apfs

echo "== Enabling FUSE's allow_other for non-root users =="
if ! grep -q "^user_allow_other" /etc/fuse.conf; then
    sudo sed -i 's/^#user_allow_other/user_allow_other/' /etc/fuse.conf
    grep -q "^user_allow_other" /etc/fuse.conf || echo "user_allow_other" | sudo tee -a /etc/fuse.conf >/dev/null
fi

echo "== Installing desktop launchers =="
mkdir -p "$HOME/.local/share/applications"
cp "$SCRIPT_DIR"/mount-mac-disk.desktop "$SCRIPT_DIR"/unmount-mac-disk.desktop "$HOME/.local/share/applications/"
chmod +x "$HOME/.local/share/applications"/mount-mac-disk.desktop "$HOME/.local/share/applications"/unmount-mac-disk.desktop
if [ -d "$HOME/Desktop" ]; then
    cp "$SCRIPT_DIR"/mount-mac-disk.desktop "$SCRIPT_DIR"/unmount-mac-disk.desktop "$HOME/Desktop/"
    chmod +x "$HOME/Desktop"/mount-mac-disk.desktop "$HOME/Desktop"/unmount-mac-disk.desktop
fi
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "== Done. Use \"Mount Mac Disk\" / \"Unmount Mac Disk\" from the Applications menu or Desktop. =="
