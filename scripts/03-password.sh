#!/usr/bin/env bash

# [03] Root Password Handling
# This script handles password generation and hashing for the root user

echo "[+] Processing root password..."

# Generate password if needed
if [ -z "${ROOT_PASSWORD}" ] && [ "${GENERATE_ROOT_PASSWORD}" = "yes" ]; then
  ROOT_PASSWORD="$(openssl rand -base64 18)"
  export ROOT_PASSWORD
  echo "[i] Generated random root password"
fi

# Create password hash for system configuration
ROOT_PASSWORD_HASH="$(openssl passwd -6 "${ROOT_PASSWORD}")"
export ROOT_PASSWORD_HASH

echo "[✓] Root password processed"
