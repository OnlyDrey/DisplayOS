#!/usr/bin/env bash

set -euo pipefail

echo -e "${BLUE}[+] Installing build prerequisites...${NOCOLOR}"

echo -e "${YELLOW}[i] Running apt-get update (details in log)...${NOCOLOR}"
sudo apt-get update >> "${LOG_FILE}" 2>&1

echo -e "${YELLOW}[i] Installing packages: live-build, debootstrap, squashfs-tools, xorriso...${NOCOLOR}"
sudo apt-get install -y \
  live-build debootstrap squashfs-tools xorriso \
  isolinux syslinux-utils wget ca-certificates \
  openssl zstd dos2unix >> "${LOG_FILE}" 2>&1

echo -e "${GREEN}[✓] Build prerequisites installed${NOCOLOR}"
