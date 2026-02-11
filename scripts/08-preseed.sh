#!/usr/bin/env bash
set -euo pipefail

echo -e "${BLUE}[+] Generating installer preseed...${NOCOLOR}"

PRESEED_FILE="${CONFIG_DIR}/includes.binary/preseed/displayos.cfg"

# Partition recipe blocks
PART_BLOCK=""
if [[ "${ERASE_ALL_DATA_TOKEN:-}" == "I_UNDERSTAND" ]]; then
  echo -e "${RED}[!] Enabling destructive autopartitioning (GPT + BIOSGRUB + EFI + / [+swap])${NOCOLOR}"

  # Common partman safety/confirm knobs
  PART_BLOCK+=$'\n'
  PART_BLOCK+=$'d-i partman-partitioning/default_label string gpt\n'
  PART_BLOCK+=$'d-i partman-partitioning/choose_label select gpt\n'
  PART_BLOCK+=$'d-i partman/confirm_write_new_label boolean true\n'
  PART_BLOCK+=$'\n'
  PART_BLOCK+=$'# Wipe/replace any blocking metadata (LVM/MD/Crypto)\n'
  PART_BLOCK+=$'d-i partman-lvm/device_remove_lvm boolean true\n'
  PART_BLOCK+=$'d-i partman-md/device_remove_md boolean true\n'
  PART_BLOCK+=$'d-i partman-crypt/device_remove_crypt boolean true\n'
  PART_BLOCK+=$'d-i partman-lvm/confirm boolean true\n'
  PART_BLOCK+=$'d-i partman-lvm/confirm_nooverwrite boolean true\n'
  PART_BLOCK+=$'d-i partman-md/confirm boolean true\n'
  PART_BLOCK+=$'d-i partman-md/confirm_nooverwrite boolean true\n'
  PART_BLOCK+=$'\n'
  PART_BLOCK+=$'d-i partman-auto/method string regular\n'
  PART_BLOCK+=$'d-i partman-auto/choose_recipe select displayos_atomic\n'

  if [[ "${PARTITION_RECIPE:-efi_no_swap}" == "efi_with_swap" ]]; then
    PART_BLOCK+=$'d-i partman-auto/expert_recipe string \\\n'
    PART_BLOCK+=$'  displayos_atomic :: \\\n'
    # BIOS boot partition for GPT-on-BIOS: method{ biosgrub } [3](https://wiki.debian.org/DebianInstaller/Partman)
    PART_BLOCK+=$'    1 1 1 free \\\n'
    PART_BLOCK+=$'      $iflabel{ gpt } $reusemethod{ } \\\n'
    PART_BLOCK+=$'      method{ biosgrub } . \\\n'
    # EFI system partition: method{ efi } format{ } mountpoint{ /boot/efi } [6](https://serverfault.com/questions/722021/preseeding-debian-install-efi)
    PART_BLOCK+=$'    512 512 512 fat32 \\\n'
    PART_BLOCK+=$'      $iflabel{ gpt } $reusemethod{ } $primary{ } $bootable{ } \\\n'
    PART_BLOCK+=$'      method{ efi } format{ } mountpoint{ /boot/efi } . \\\n'
    # Swap
    PART_BLOCK+=$'    1024 2048 2048 linux-swap \\\n'
    PART_BLOCK+=$'      method{ swap } format{ } . \\\n'
    # Root
    PART_BLOCK+=$'    10000 1000000000 -1 ext4 \\\n'
    PART_BLOCK+=$'      method{ format } format{ } use_filesystem{ } filesystem{ ext4 } \\\n'
    PART_BLOCK+=$'      mountpoint{ / } .\n'
    PART_BLOCK+=$'\n'
    PART_BLOCK+=$'d-i partman/choose_partition select finish\n'
    PART_BLOCK+=$'d-i partman/confirm boolean true\n'
    PART_BLOCK+=$'d-i partman/confirm_nooverwrite boolean true\n'
  else
    PART_BLOCK+=$'d-i partman-auto/expert_recipe string \\\n'
    PART_BLOCK+=$'  displayos_atomic :: \\\n'
    PART_BLOCK+=$'    1 1 1 free \\\n'
    PART_BLOCK+=$'      $iflabel{ gpt } $reusemethod{ } \\\n'
    PART_BLOCK+=$'      method{ biosgrub } . \\\n'
    PART_BLOCK+=$'    512 512 512 fat32 \\\n'
    PART_BLOCK+=$'      $iflabel{ gpt } $reusemethod{ } $primary{ } $bootable{ } \\\n'
    PART_BLOCK+=$'      method{ efi } format{ } mountpoint{ /boot/efi } . \\\n'
    PART_BLOCK+=$'    10000 1000000000 -1 ext4 \\\n'
    PART_BLOCK+=$'      method{ format } format{ } use_filesystem{ } filesystem{ ext4 } \\\n'
    PART_BLOCK+=$'      mountpoint{ / } .\n'
    PART_BLOCK+=$'\n'
    PART_BLOCK+=$'d-i partman/choose_partition select finish\n'
    PART_BLOCK+=$'d-i partman/confirm boolean true\n'
    PART_BLOCK+=$'d-i partman/confirm_nooverwrite boolean true\n'
  fi
else
  echo "[SAFE] Disk erase is DISABLED. (Set ERASE_ALL_DATA_TOKEN=I_UNDERSTAND to enable.)"
  PART_BLOCK+=$'\n# Safety: do not partition automatically without the token\n'
  PART_BLOCK+=$'d-i partman/confirm boolean false\n'
fi

# Write the preseed file
cat > "${PRESEED_FILE}" <<EOF
### === DisplayOS Preseed (Debian live-installer) ===

# Non-interactive
d-i debconf/priority string critical

# Locale / keyboard / time
d-i debian-installer/locale string ${LOCALE}
d-i time/zone string ${TIMEZONE}
d-i clock-setup/utc boolean true
# Offline install: avoid NTP timeouts when netcfg is disabled
d-i clock-setup/ntp boolean false

# Keyboard (installer)
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/modelcode  string ${KEYMAP_MODEL}
d-i keyboard-configuration/layoutcode string ${KEYMAP}
d-i keyboard-configuration/variant    string ${KEYMAP_VARIANT}
d-i keyboard-configuration/xkb-keymap select ${KEYMAP}

# No mirror (install offline from live medium)
d-i mirror/country string manual
d-i apt-setup/use_mirror boolean false
d-i apt-setup/services-select multiselect
d-i apt-setup/disable-cdrom-entries boolean true

# Hardware detection - Load firmware without prompting
d-i hw-detect/load_firmware boolean true

# Network configuration - disabled
d-i netcfg/enable boolean false
d-i netcfg/get_hostname string ${SET_HOSTNAME}
d-i netcfg/get_domain string local

# Unmount any auto-mounted partitions that may block partman
d-i preseed/early_command string umount /media || true; umount /mnt || true

# Disk selection: first non-removable disk, excluding the disk backing /cdrom.
# Correct pattern: debconf-set partman-auto/disk inside partman/early_command [4](https://serverfault.com/questions/685251/unattended-installation-with-preseed-give-a-custom-device-to-partman-auto)
d-i partman/early_command string \\
  cdsrc="\$(mount | awk '\$3==\"/cdrom\" {print \$1}' | head -n1)"; \\
  cdparent=""; \\
  if [ -n "\$cdsrc" ]; then \\
    cdbase="\${cdsrc##*/}"; \\
    case "\$cdbase" in \\
      nvme*n*p*) cdparent="/dev/\${cdbase%p*}" ;; \\
      mmcblk*p*) cdparent="/dev/\${cdbase%p*}" ;; \\
      *)         cdparent="/dev/\${cdbase%%[0-9]*}" ;; \\
    esac; \\
  fi; \\
  for d in \$(list-devices disk); do \\
    base="\${d##*/}"; \\
    [ -r "/sys/block/\$base/removable" ] || continue; \\
    [ "\$(cat /sys/block/\$base/removable)" = "0" ] || continue; \\
    [ -n "\$cdparent" ] && [ "\$d" = "\$cdparent" ] && continue; \\
    debconf-set partman-auto/disk "\$d"; \\
    debconf-set partman/select_disk "\$d"; \\
    break; \\
  done; \\
  true

# User creation (no root login)
d-i passwd/root-login boolean false
d-i passwd/make-user boolean true
d-i passwd/user-fullname string ${SET_USERNAME}
d-i passwd/username string ${SET_USERNAME}
d-i passwd/user-password-crypted password ${USER_PASSWORD_HASH}

${PART_BLOCK}

# No popularity / no upgrades during install
popularity-contest popularity-contest/participate boolean false
d-i pkgsel/upgrade select none

# Bootloader
d-i grub-installer/only_debian boolean false
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default
d-i grub-installer/timeout string 5
d-i grub-installer/force-efi-extra-removable boolean true

# Late command: set APT sources and custom grub entries (kept from your original)
d-i preseed/late_command string \\
  ROOTDEV="\$(awk '\$2==\"/target\" {print \$1}' /proc/mounts)"; \\
  ROOTUUID="\$(blkid -s UUID -o value "\$ROOTDEV")"; \\
  echo "deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware" > /target/etc/apt/sources.list; \\
  echo "deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware" >> /target/etc/apt/sources.list; \\
  echo "deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /target/etc/apt/sources.list; \\
  mkdir -p /target/etc/grub.d; \\
  if [ -f /cdrom/preseed/grub.custom.in ]; then \\
    sed -e "s/{{ROOT_UUID}}/\${ROOTUUID}/g" \\
        -e "s/{{PRODUCT_NAME}}/\${PRODUCT_NAME}/g" \\
        -e "s/{{GFXMODE}}/1600x900/g" \\
        /cdrom/preseed/grub.custom.in > /target/etc/grub.d/40_custom; \\
    chmod +x /target/etc/grub.d/40_custom; \\
    in-target update-grub; \\
  fi

# Finish
d-i finish-install/reboot_in_progress note
EOF

chmod +x "${CONFIG_DIR}/hooks/normal/"*.chroot 2>/dev/null || true
echo -e "${GREEN}[✓] Preseed configuration generated: ${PRESEED_FILE}${NOCOLOR}"
