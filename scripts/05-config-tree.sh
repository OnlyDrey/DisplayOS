#!/usr/bin/env bash

# [05] Prepare live-build Config Tree
# This script creates the directory structure and files for live-build configuration

echo -e "${BLUE}[+] Preparing live-build config tree...${NOCOLOR}"

# Clean and create directory structure
rm -rf "${CONFIG_DIR}"
mkdir -p \
  "${CONFIG_DIR}/package-lists" \
  "${CONFIG_DIR}/hooks/normal" \
  "${CONFIG_DIR}/includes.chroot/usr/local/share/displayos" \
  "${CONFIG_DIR}/includes.chroot/etc/apt" \
  "${CONFIG_DIR}/includes.chroot/etc/xdg/autostart" \
  "${CONFIG_DIR}/includes.chroot/usr/local/bin" \
  "${CONFIG_DIR}/includes.chroot/boot/grub" \
  "${CONFIG_DIR}/includes.binary/isolinux" \
  "${CONFIG_DIR}/includes.binary/boot/grub" \
  "${CONFIG_DIR}/includes.binary/preseed"

# Package List
echo -e "${BLUE}[+] Creating package list...${NOCOLOR}"
PLIST="${CONFIG_DIR}/package-lists/displayos.list.chroot"
printf "%s\n" "${PACKAGES[@]}" > "${PLIST}"

# Ensure required packages are present
for req in linux-image-amd64 live-boot live-config systemd-sysv; do
  if ! grep -qx "${req}" "${PLIST}"; then
    echo "${req}" >> "${PLIST}"
  fi
done

# Assets
echo -e "${BLUE}[+] Copying assets...${NOCOLOR}"
[ -f "${WALLPAPER_IMG}" ] && cp -f "${WALLPAPER_IMG}" "${CONFIG_DIR}/includes.chroot/usr/local/share/displayos/wallpaper.png" || true
[ -f "${WALLPAPER_IMG}" ] && cp -f "${WALLPAPER_IMG}" "${CONFIG_DIR}/includes.chroot/boot/grub/splash.png" || true
[ -f "${SPLASH_IMG}" ] && cp -f "${SPLASH_IMG}" "${CONFIG_DIR}/includes.binary/isolinux/splash.png" || true
[ -f "${SPLASH_IMG}" ] && cp -f "${SPLASH_IMG}" "${CONFIG_DIR}/includes.binary/boot/grub/splash.png" || true

# APT Sources List
echo -e "${BLUE}[+] Creating APT sources list...${NOCOLOR}"
cat > "${CONFIG_DIR}/includes.chroot/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian ${DISTRO} ${ARCHIVE_AREAS}
deb http://security.debian.org/debian-security ${DISTRO}-security ${ARCHIVE_AREAS}
deb http://deb.debian.org/debian ${DISTRO}-updates ${ARCHIVE_AREAS}
EOF

# Copy APT sources template for preseed to use during installation
cat > "${CONFIG_DIR}/includes.binary/preseed/sources.list" <<EOF
deb http://deb.debian.org/debian ${DISTRO} ${ARCHIVE_AREAS}
deb http://security.debian.org/debian-security ${DISTRO}-security ${ARCHIVE_AREAS}
deb http://deb.debian.org/debian ${DISTRO}-updates ${ARCHIVE_AREAS}
EOF

# Autostart entry for shortcuts
cat > "${CONFIG_DIR}/includes.chroot/etc/xdg/autostart/displayos-shortcuts.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=DisplayOS Shortcuts Seed
Exec=/usr/local/bin/displayos-ensure-shortcuts
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

# Shortcut enforcement script
cat > "${CONFIG_DIR}/includes.chroot/usr/local/bin/displayos-ensure-shortcuts" <<'EOF'
#!/bin/sh
xfconf-query -c xfce4-keyboard-shortcuts \
  -p "/commands/custom/<Primary><Alt>w" \
  -n -t string \
  -s "xfce4-terminal --title='Wi-Fi' --hide-menubar -x nmtui" || true
EOF
chmod +x "${CONFIG_DIR}/includes.chroot/usr/local/bin/displayos-ensure-shortcuts"

echo -e "${GREEN}[✓] Config tree prepared${NOCOLOR}"
