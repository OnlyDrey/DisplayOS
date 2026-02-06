#!/usr/bin/env bash

# DisplayOS Build Orchestrator
# This script sources configuration and runs all build steps in sequence.

set -euo pipefail

# Get the directory where build.sh is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup Paths (before sourcing config)
export ROOT_DIR="${SCRIPT_DIR}"
export OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/output}"
export ASSETS_DIR="${ASSETS_DIR:-${ROOT_DIR}/assets}"
export CONFIG_DIR="${ROOT_DIR}/config"
export SCRIPTS_DIR="${ROOT_DIR}/scripts"

export LOG_FILE="${OUTPUT_DIR}/build.log"
export CONFIG_OUT="${OUTPUT_DIR}/configuration.txt"

# Source Configuration
CONFIG_FILE="${ROOT_DIR}/config.env"
if [ -f "${CONFIG_FILE}" ]; then
  # shellcheck source=config.env
  source "${CONFIG_FILE}"
else
  echo "[ERROR] Configuration file not found: ${CONFIG_FILE}"
  exit 1
fi

# Setup Asset Paths (after sourcing config)
export WALLPAPER_SRC="${WALLPAPER_SRC:-${ASSETS_DIR}/wallpaper.png}"
export SPLASH_IMG="${SPLASH_IMG:-${ASSETS_DIR}/splash.png}"
# export GRUB_THEME_DIR="${GRUB_THEME_DIR:-${ASSETS_DIR}/grub-theme}"

# Setup Packages Array
if [ -n "${PACKAGES:-}" ]; then
  # shellcheck disable=SC2206
  PACKAGES=(${PACKAGES})
else
  PACKAGES=("${DEFAULT_PACKAGES_ARRAY[@]}")
fi
export PACKAGES

# Helper function to run scripts
run_script() {
  local script_name="$1"
  local script_path="${SCRIPTS_DIR}/${script_name}"

  if [ -f "${script_path}" ]; then
    echo "[*] Running: ${script_name}"
    # Source the script so it has access to all variables
    source "${script_path}"
  else
    echo "[ERROR] Script not found: ${script_path}"
    exit 1
  fi
}

# Step 0: Initialize logging and debug
run_script "00-init.sh"
# Step 1: Pre-flight checks
run_script "01-preflight.sh"
# Step 2: Install prerequisites
run_script "02-prerequisites.sh"
# Step 3: Handle password generation
run_script "03-password.sh"
# Step 4: Dump effective configuration
run_script "04-dump-config.sh"
# Step 5: Prepare live-build config tree
run_script "05-config-tree.sh"
# Step 6: Generate chroot hooks
run_script "06-hooks.sh"
# Step 7: Generate installer preseed
run_script "07-preseed.sh"
# Step 8: Run live-build (clean, config, build)
run_script "08-livebuild.sh"
# Step 9: Finalize and collect artifacts
run_script "09-finalize.sh"

echo "[✓] DisplayOS build completed!"
