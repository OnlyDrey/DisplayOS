#!/usr/bin/env bash

# [08] Run live-build
# This script executes live-build clean, config, and build commands

echo "[+] Running live-build..."

# Clean Previous Build
echo "[+] Running sudo lb clean --purge..."
sudo lb clean --purge || true
sudo rm -rf cache/ chroot/ binary/ auto/ || true

# Configure live-build
echo "[+] Running sudo lb config..."

DI_GUI_FLAG=$([ "${DEBIAN_INSTALLER_GUI}" = "true" ] && echo "true" || echo "false")

sudo lb config \
  --distribution "${DISTRO}" \
  --architectures "${ARCH}" \
  --binary-images "${BINARY_IMAGES}" \
  --archive-areas "${ARCHIVE_AREAS}" \
  --debian-installer "${DEBIAN_INSTALLER}" \
  --debian-installer-gui "${DI_GUI_FLAG}" \
  --iso-application "${PRODUCT_NAME}" \
  --iso-volume "${PRODUCT_NAME}" \
  --apt-recommends "${APT_RECOMMENDS}" \
  --checksums sha256 \
  --bootappend-install "auto=true priority=critical preseed/file=/cdrom/preseed/displayos.cfg locale=${LOCALE} keyboard-configuration/xkb-keymap=${KEYMAP} console-setup/ask_detect=false" \
  --bootappend-live "boot=live components quiet"

# Build
echo "[+] Running sudo lb build (this can take a while)..."
sudo lb build

echo "[✓] live-build completed"
