#!/usr/bin/env bash

# [02] Install Build Prerequisites
# This script installs required build tools

echo "[+] Installing build prerequisites..."

sudo apt-get update
sudo apt-get install -y \
  live-build debootstrap squashfs-tools xorriso \
  isolinux syslinux-utils wget ca-certificates \
  openssl zstd dos2unix

echo "[✓] Build prerequisites installed"
