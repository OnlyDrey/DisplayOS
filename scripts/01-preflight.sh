#!/usr/bin/env bash

# [01] Pre-flight Checks
# This script performs pre-build validation

echo -e "${BLUE}[+] Running pre-flight checks...${NOCOLOR}"

# Check for previous build artifacts
if [ -d chroot ] || [ -d binary ]; then
  echo -e "${YELLOW}[i] Detected previous build artifacts (chroot/ or binary/). That's fine.${NOCOLOR}"
fi

# Verify required directories exist
if [ ! -d "${ASSETS_DIR}" ]; then
  echo -e "${YELLOW}[WARNING] Assets directory not found: ${ASSETS_DIR}${NOCOLOR}"
  echo -e "${YELLOW}[i] Creating empty assets directory...${NOCOLOR}"
  mkdir -p "${ASSETS_DIR}"
fi

# Check for required assets (optional warnings)
if [ ! -f "${WALLPAPER_IMG}" ]; then
  echo -e "${YELLOW}[i] No wallpaper found at: ${WALLPAPER_IMG}${NOCOLOR}"
fi

if [ ! -f "${SPLASH_IMG}" ]; then
  echo -e "${YELLOW}[i] No splash image found at: ${SPLASH_IMG}${NOCOLOR}"
fi

echo -e "${GREEN}[✓] Pre-flight checks completed${NOCOLOR}"
