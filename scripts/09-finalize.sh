#!/usr/bin/env bash

# [09] Finalize and Collect Artifacts
# This script collects the built ISO and displays final information

echo "[+] Collecting ISO artifact..."

GEN_ISO="$(ls -1t *.iso 2>/dev/null | head -n1 || true)"

if [ -n "${GEN_ISO}" ]; then
  FINAL="${OUTPUT_DIR}/${PRODUCT_NAME}-${DISTRO}-${ARCH}-unattended.iso"
  mv -f "${GEN_ISO}" "${FINAL}"
  echo "[✓] Build successful!"
  echo "[i] ISO: ${FINAL}"
  echo "[i] Build log: ${LOG_FILE}"
  echo "[i] Config dump: ${CONFIG_OUT}"

  if [ -n "${ROOT_PASSWORD:-}" ]; then
    echo ""
    echo "[!] Root password (also in configuration.txt): ${ROOT_PASSWORD}"
  fi
else
  echo "[!] Build did not produce an ISO"
  echo "[i] Check the log file: ${LOG_FILE}"
  exit 1
fi
