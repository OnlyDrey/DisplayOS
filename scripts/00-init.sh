#!/usr/bin/env bash

# [00] Logging & Debug Setup
# This script initializes logging and debug mode

echo -e "${BLUE}[+] Initializing build environment...${NOCOLOR}"

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# Setup logging - tee to both console and log file
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "== ${PRODUCT_NAME} live-build started at $(date -Iseconds) =="
echo -e "${YELLOW}[i] Root directory: ${ROOT_DIR}${NOCOLOR}"
echo -e "${YELLOW}[i] Output directory: ${OUTPUT_DIR}${NOCOLOR}"
echo -e "${YELLOW}[i] Assets directory: ${ASSETS_DIR}${NOCOLOR}"
echo -e "${YELLOW}[i] Config directory: ${CONFIG_DIR}${NOCOLOR}"

# Enable debug mode if requested
if [ "${DEBUG}" = "yes" ]; then
  echo -e "${YELLOW}[i] Debug mode ENABLED${NOCOLOR}"
  set -x
  export LB_DEBUG=1
fi
