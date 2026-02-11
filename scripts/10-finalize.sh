#!/usr/bin/env bash

# [10] Finalize and Collect Artifacts
# This script collects the built ISO and displays final information

echo -e "${BLUE}[+] Collecting ISO artifact...${NOCOLOR}"

GEN_ISO="$(ls -1t *.iso 2>/dev/null | head -n1 || true)"

if [ -n "${GEN_ISO}" ]; then
  FINAL="${OUTPUT_DIR}/${PRODUCT_NAME}-${DISTRO}-${ARCH}-unattended.iso"
  mv -f "${GEN_ISO}" "${FINAL}"
  echo -e "${GREEN}[✓] Build successful!${NOCOLOR}"
  echo -e "${YELLOW}[i] ISO: ${FINAL}${NOCOLOR}"
  echo -e "${YELLOW}[i] Build log: ${LOG_FILE}${NOCOLOR}"
  echo -e "${YELLOW}[i] Config dump: ${CONFIG_OUT}${NOCOLOR}"

  if [ -n "${ROOT_PASSWORD:-}" ]; then
    echo ""
    echo -e "${RED}[!] Root password (also in configuration.txt): ${ROOT_PASSWORD}${NOCOLOR}"
  fi
else
  echo -e "${RED}[!] Build did not produce an ISO${NOCOLOR}"
  echo -e "${YELLOW}[i] Check the log file: ${LOG_FILE}${NOCOLOR}"
  exit 1
fi
