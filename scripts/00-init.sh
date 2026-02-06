#!/usr/bin/env bash

# [00] Logging & Debug Setup
# This script initializes logging and debug mode

echo "[+] Initializing build environment..."

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# Setup logging - tee to both console and log file
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "== ${PRODUCT_NAME} live-build started at $(date -Iseconds) =="
echo "[i] Root directory: ${ROOT_DIR}"
echo "[i] Output directory: ${OUTPUT_DIR}"
echo "[i] Assets directory: ${ASSETS_DIR}"
echo "[i] Config directory: ${CONFIG_DIR}"

# Enable debug mode if requested
if [ "${DEBUG}" = "yes" ]; then
  echo "[i] Debug mode ENABLED"
  set -x
  export LB_DEBUG=1
fi
