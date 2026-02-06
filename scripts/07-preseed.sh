#!/usr/bin/env bash

# [07] Generate Installer Preseed
# This script creates the preseed configuration for the Debian installer

echo "[+] Generating installer preseed..."

PRESEED_FILE="${CONFIG_DIR}/includes.binary/preseed/displayos.cfg"

# Base Preseed Configuration
cat > "${PRESEED_FILE}" <<'EOF'
### === DisplayOS Preseed (Debian live-installer) ===

# Non-interactive
d-i debconf/priority string critical

# Locale / keyboard / time
d-i debian-installer/locale string {{LOCALE}}
d-i time/zone string {{TIMEZONE}}
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true

# Keyboard (installer)
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/modelcode  string {{KEYMAP_MODEL}}
d-i keyboard-configuration/layoutcode string {{KEYMAP}}
d-i keyboard-configuration/variant   string {{KEYMAP_VARIANT}}
d-i keyboard-configuration/xkb-keymap select {{KEYMAP}}

# No mirror (install offline from live medium)
d-i mirror/country string manual
d-i apt-setup/use_mirror boolean false

# Hostname / domain (preseeded so the installer won't ask)
d-i netcfg/get_hostname string displayos
d-i netcfg/get_domain string local

# (Optional, mostly for PXE/netboot) Restart netcfg early if needed
# d-i preseed/early_command string kill-all-dhcp; netcfg

# Root-only (no extra user)
d-i passwd/root-login boolean true
d-i passwd/make-user boolean false

# Preseed the root password (crypted) so the installer will not prompt.
# Filled from ${ROOT_PASSWORD_HASH} by sed later in the script.
d-i passwd/root-password-crypted password {{ROOT_PASSWORD_HASH}}

# Disk selection: first non-removable
d-i partman/early_command string \
  DISK=""; \
  for d in $(list-devices disk); do \
    base=$(basename "$d"); \
    if [ -f "/sys/block/${base}/removable" ] && [ "$(cat /sys/block/${base}/removable)" = "0" ]; then DISK="$d"; break; fi; \
  done; \
  if [ -z "$DISK" ]; then DISK="$(list-devices disk | head -n1)"; fi; \
  echo "Using disk: $DISK" > /tmp/selected_disk; \
  debconf-set partman-auto/disk "$DISK";

{{AUTO_PARTITION_STANZA}}

{{PARTMAN_BLOCK}}

# No popularity / no upgrades during install
popularity-contest popularity-contest/participate boolean false
d-i pkgsel/upgrade select none

# Bootloader
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/timeout string 0

# Render custom GRUB entries and update-grub on the target
d-i preseed/late_command string \
  ROOTDEV="$(awk '$2==\"/target\" {print $1}' /proc/mounts)"; \
  ROOTUUID="$(blkid -s UUID -o value \"$ROOTDEV\")"; \
  mkdir -p /target/etc/grub.d; \
  if [ -f /cdrom/preseed/grub.custom.in ]; then \
    sed -e "s/{{ROOT_UUID}}/${ROOTUUID}/g" \
        -e "s/{{PRODUCT_NAME}}/${PRODUCT_NAME}/g" \
        -e "s/{{GFXMODE}}/1600x900/g" \
        /cdrom/preseed/grub.custom.in > /target/etc/grub.d/40_custom; \
    chmod +x /target/etc/grub.d/40_custom; \
    in-target update-grub; \
  fi

# Finish
d-i finish-install/reboot_in_progress note
EOF

# Partitioning Configuration
if [ "${ERASE_ALL_DATA_TOKEN}" = "I_UNDERSTAND" ]; then
  echo "[!] Enabling destructive autopartitioning (GPT + EFI ESP + /)"

  if [ "${PARTITION_RECIPE}" = "efi_with_swap" ]; then
    PART_BLOCK='
d-i partman-partitioning/default_label string gpt
d-i partman-partitioning/choose_label select gpt
d-i partman/confirm_write_new_label boolean true

d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select displayos_efi_with_swap
d-i partman-auto/expert_recipe string \
  displayos_efi_with_swap :: \
    512 512 512 fat32 \
      $iflabel{ gpt } \
      $primary{ } $bootable{ } \
      method{ efi } format{ } \
      mountpoint{ /boot/efi } . \
    1024 2048 2048 linux-swap \
      $lvmignore{ } \
      method{ swap } format{ } . \
    10000 1000000000 -1 ext4 \
      method{ format } format{ } use_filesystem{ } filesystem{ ext4 } \
      mountpoint{ / } .

d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
'
  else
    PART_BLOCK='
d-i partman-partitioning/default_label string gpt
d-i partman-partitioning/choose_label select gpt
d-i partman/confirm_write_new_label boolean true

d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select displayos_efi_no_swap
d-i partman-auto/expert_recipe string \
  displayos_efi_no_swap :: \
    512 512 512 fat32 \
      $iflabel{ gpt } \
      $primary{ } $bootable{ } \
      method{ efi } format{ } \
      mountpoint{ /boot/efi } . \
    10000 1000000000 -1 ext4 \
      method{ format } format{ } use_filesystem{ } filesystem{ ext4 } \
      mountpoint{ / } .

d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
'
  fi

  # Add the "skip menu & always confirm" stanza for destructive builds
  AUTOPART='
d-i partman-auto/init_automatically_partition select Guided-use entire disk
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
'
else
  echo "[SAFE] Disk erase is DISABLED. (Set ERASE_ALL_DATA_TOKEN=I_UNDERSTAND to enable.)"
  PART_BLOCK='
# Safety: no automatic partitioning without token
d-i partman/confirm boolean false
'
  AUTOPART=''
fi

# Custom GRUB Template (optional)
#if [ -f "${ASSETS_DIR}/grub.cfg" ]; then
#  cp -f "${ASSETS_DIR}/grub.cfg" "${CONFIG_DIR}/includes.binary/preseed/grub.custom.in"
#fi

# Substitute Variables in Preseed
sed -i \
  -e "s/{{LOCALE}}/${LOCALE//\//\\/}/" \
  -e "s/{{KEYMAP}}/${KEYMAP//\//\\/}/" \
  -e "s/{{KEYMAP_MODEL}}/${KEYMAP_MODEL//\//\\/}/" \
  -e "s/{{KEYMAP_VARIANT}}/${KEYMAP_VARIANT//\//\\/}/" \
  -e "s/{{TIMEZONE}}/${TIMEZONE//\//\\/}/" \
  -e "s|{{ROOT_PASSWORD_HASH}}|${ROOT_PASSWORD_HASH//\//\\/}|g" \
  "${PRESEED_FILE}"

# Insert partitioning & autopart stanzas
sed -i "s|{{PARTMAN_BLOCK}}|$(echo "${PART_BLOCK}" | sed -e ':a' -e 'N' -e '$!ba' -e 's/[\/&]/\\&/g' -e 's/\n/\\n/g')|" "${PRESEED_FILE}"
sed -i "s|{{AUTO_PARTITION_STANZA}}|$(echo "${AUTOPART}" | sed -e ':a' -e 'N' -e '$!ba' -e 's/[\/&]/\\&/g' -e 's/\n/\\n/g')|" "${PRESEED_FILE}"

# Ensure hooks are executable
chmod +x "${CONFIG_DIR}/hooks/normal/"*.chroot 2>/dev/null || true

echo "[✓] Preseed configuration generated"
