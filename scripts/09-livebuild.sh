#!/usr/bin/env bash
set -euo pipefail

echo -e "${BLUE}[+] Running live-build...${NOCOLOR}"

echo -e "${BLUE}[+] Cleaning previous build (lb clean --purge)...${NOCOLOR}"
sudo lb clean --purge >> "${LOG_FILE}" 2>&1 || true
sudo rm -rf cache/ chroot/ binary/ auto/ || true
echo -e "${GREEN}[✓] Clean completed${NOCOLOR}"

echo -e "${BLUE}[+] Configuring live-build (lb config)...${NOCOLOR}"

DI_GUI_FLAG=$([ "${DEBIAN_INSTALLER_GUI}" = "true" ] && echo "true" || echo "false")

sudo lb config \
  --distribution "${DISTRO}" \
  --architectures "${ARCH}" \
  --binary-images "${BINARY_IMAGES}" \
  --archive-areas "${ARCHIVE_AREAS}" \
  --debian-installer "${DEBIAN_INSTALLER}" \
  --debian-installer-gui "${DI_GUI_FLAG}" \
  --iso-application "${PRODUCT_NAME}" \
  --iso-volume "${PRODUCT_NAME}" \
  --apt-recommends "${APT_RECOMMENDS}" \
  --checksums sha256 \
  --bootloaders "syslinux,grub-efi" \
  --firmware-chroot true \
  --firmware-binary true \
  --system live \
  --bootappend-install "auto=true priority=critical preseed/file=/cdrom/preseed/displayos.cfg locale=${LOCALE} keyboard-configuration/xkb-keymap=${KEYMAP} console-setup/ask_detect=false netcfg/enable=false netcfg/get_hostname=${SET_HOSTNAME} netcfg/get_domain=local hw-detect/load_firmware=true" \
  --bootappend-live "boot=live components quiet splash" >> "${LOG_FILE}" 2>&1

echo -e "${GREEN}[✓] Configuration completed${NOCOLOR}"

echo -e "${BLUE}[+] Building ISO...${NOCOLOR}"
echo -e "${YELLOW}[i] Progress indicators:${NOCOLOR}"
echo -e "${YELLOW}    - Running debootstrap (bootstrap base system)${NOCOLOR}"
echo -e "${YELLOW}    - Installing packages (~800 packages)${NOCOLOR}"
echo -e "${YELLOW}    - Running chroot hooks (system configuration)${NOCOLOR}"
echo ""
echo -e "${YELLOW}[i] Detailed progress is logged to: ${LOG_FILE}${NOCOLOR}"
echo -e "${YELLOW}[i] To monitor in real-time: tail -f ${LOG_FILE}${NOCOLOR}"
echo ""

(
  stdbuf -oL sudo lb build 2>&1 \
    | tee -a "${LOG_FILE}" \
    | stdbuf -oL grep --line-buffered -v '^$' \
    | while IFS= read -r line; do

        case "$line" in
          *"Get:"*|*"Selecting previously"*|*"Preparing to unpack"*|*"Unpacking "*|*"Setting up "*|*"Removing "*|*"Writing to"*"completed successfully"*)
            continue
            ;;
        esac

        case "$line" in
          *"lb binary_rootfs"*|*"mksquashfs"*|*"squashfs"*|*"Exportable Squashfs"*|*"compressed data block size"*|*"Unrecognised xattr prefix"*)
            continue
            ;;
          *"lb binary_iso"*|*"xorriso"*|*"ISO image"*|*"Added to ISO image:"*|*"UPDATE :"*|*"ISO image produced:"*)
            continue
            ;;
          *"[0m lb bootstrap_debootstrap"*)
            echo -e "${YELLOW}  → Bootstrapping base system (debootstrap)...${NOCOLOR}"
            ;;
          *"[0m lb chroot_linux-image"*)
            echo -e "${YELLOW}  → Installing Linux kernel...${NOCOLOR}"
            ;;
          *"[0m lb chroot_hooks"*)
            echo -e "${YELLOW}  → Running chroot hooks (system configuration)...${NOCOLOR}"
            ;;
        esac
      done
) || {
  echo -e "${RED}[ERROR] Build failed. Check ${LOG_FILE} for details.${NOCOLOR}"
  exit 1
}

echo -e "${GREEN}[✓] live-build completed${NOCOLOR}"
