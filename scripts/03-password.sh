#!/usr/bin/env bash

set -euo pipefail

echo -e "${BLUE}[+] Processing user password...${NOCOLOR}"

if [ -z "${SET_PASSWORD}" ] && [ "${GENERATE_PASSWORD}" = "yes" ]; then
  SET_PASSWORD="$(openssl rand -base64 18)"
  export SET_PASSWORD
  echo -e "${YELLOW}[i] Generated random password for user${NOCOLOR}"
fi

USER_PASSWORD_HASH="$(openssl passwd -6 "${SET_PASSWORD}")"
export USER_PASSWORD_HASH

echo -e "${GREEN}[✓] User password processed${NOCOLOR}"
