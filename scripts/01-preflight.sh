#!/usr/bin/env bash

# [01] Pre-flight Checks
# This script performs pre-build validation

echo "[+] Running pre-flight checks..."

# Check for previous build artifacts
if [ -d chroot ] || [ -d binary ]; then
  echo "[i] Detected previous build artifacts (chroot/ or binary/). That's fine."
fi

# Verify required directories exist
if [ ! -d "${ASSETS_DIR}" ]; then
  echo "[WARNING] Assets directory not found: ${ASSETS_DIR}"
  echo "[i] Creating empty assets directory..."
  mkdir -p "${ASSETS_DIR}"
fi

# Check for required assets (optional warnings)
if [ ! -f "${WALLPAPER_SRC}" ]; then
  echo "[i] No wallpaper found at: ${WALLPAPER_SRC}"
fi

if [ ! -f "${SPLASH_IMG}" ]; then
  echo "[i] No splash image found at: ${SPLASH_IMG}"
fi

echo "[✓] Pre-flight checks completed"
