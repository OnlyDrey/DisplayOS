#!/usr/bin/env bash

# [04] Dump Effective Configuration
# This script saves the effective configuration for traceability and debugging

echo "[+] Dumping effective configuration..."

mkdir -p "${OUTPUT_DIR}"

{
  echo "# DisplayOS Build Configuration"
  echo "# Generated: $(date -Iseconds)"
  echo ""
  echo "# Security"
  echo "ROOT_PASSWORD=${ROOT_PASSWORD}"
  echo "ENABLE_SSH=${ENABLE_SSH}"
  echo ""
  echo "# Kiosk & Customization"
  echo "KIOSK_URL=${KIOSK_URL}"
  echo "DEFAULT_BROWSER=${DEFAULT_BROWSER}"
  echo "KIOSK_AUTORESTART=${KIOSK_AUTORESTART}"
  echo "WALLPAPER_SRC=${WALLPAPER_SRC}"
  echo "SPLASH_IMG=${SPLASH_IMG}"
  echo ""
  echo "# Identity"
  echo "PRODUCT_NAME=${PRODUCT_NAME}"
  echo "DISTRO=${DISTRO}"
  echo "ARCH=${ARCH}"
  echo "ISO_LABEL=${ISO_LABEL}"
  echo ""
  echo "# Locale"
  echo "TIMEZONE=${TIMEZONE}"
  echo "LOCALE=${LOCALE}"
  echo "KEYMAP=${KEYMAP}"
  echo "KEYMAP_MODEL=${KEYMAP_MODEL}"
  echo "KEYMAP_VARIANT=${KEYMAP_VARIANT}"
  echo ""
  echo "# Disk"
  echo "ERASE_ALL_DATA_TOKEN=${ERASE_ALL_DATA_TOKEN}"
} > "${CONFIG_OUT}"

echo ""
echo "[✓] Configuration saved to: ${CONFIG_OUT}"
