#!/usr/bin/env bash

set -euo pipefail

echo -e "${BLUE}[+] Generating chroot hooks...${NOCOLOR}"

# Hook: User Setup (create user with sudo privileges)
cat > "${CONFIG_DIR}/hooks/normal/009-user-setup.chroot" <<EOF
#!/bin/sh
set -eu

apt-get install -y sudo || true

if ! id -u ${SET_USERNAME} >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev ${SET_USERNAME}
fi

usermod -p '${USER_PASSWORD_HASH}' ${SET_USERNAME}

echo "${SET_USERNAME} ALL=(ALL:ALL) ALL" > /etc/sudoers.d/${SET_USERNAME}
chmod 0440 /etc/sudoers.d/${SET_USERNAME}

passwd -l root || true
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/009-user-setup.chroot"

# Hook: SSH & NetworkManager
cat > "${CONFIG_DIR}/hooks/normal/010-root-ssh.chroot" <<EOF
#!/bin/sh
set -eu

if [ "${ENABLE_SSH}" = "yes" ]; then
  systemctl enable ssh || true
fi
sed -i 's/^#\?Port.*/Port 22/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication ${ENABLE_SSH}/' /etc/ssh/sshd_config

systemctl enable NetworkManager || true

apt-get -y purge unattended-upgrades || true

debconf-set-selections <<'EOS'
keyboard-configuration keyboard-configuration/layoutcode string ${KEYMAP}
keyboard-configuration keyboard-configuration/modelcode  string ${KEYMAP_MODEL}
keyboard-configuration keyboard-configuration/variant    string ${KEYMAP_VARIANT}
EOS
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/010-root-ssh.chroot"

# Hook: Kiosk Setup
cat > "${CONFIG_DIR}/hooks/normal/020-kiosk.chroot" <<'HOOKEOF'
#!/bin/sh
set -eu

install -d /usr/local/bin
cat > /usr/local/bin/displayos-kiosk <<'EOK'
#!/usr/bin/env bash
set -e
URL="{{KIOSK_URL}}"
BROWSER="{{DEFAULT_BROWSER}}"
xset s off -dpms
xset s noblank
if [ -f /usr/local/share/displayos/wallpaper.png ]; then feh --bg-scale /usr/local/share/displayos/wallpaper.png; fi
if [ "$BROWSER" = "chromium" ]; then
  CMD=(chromium --no-first-run --kiosk --incognito --disable-translate --disable-infobars --start-maximized "$URL")
else
  CMD=(firefox-esr --kiosk "$URL")
fi
if [ "{{KIOSK_AUTORESTART}}" = "yes" ]; then
  while true; do "${CMD[@]}" || true; sleep 2; done
else
  exec "${CMD[@]}"
fi
EOK
chmod +x /usr/local/bin/displayos-kiosk

install -d /home/{{SET_USERNAME}}/.config/autostart
cat > /home/{{SET_USERNAME}}/.config/autostart/displayos.desktop <<'EOD'
[Desktop Entry]
Type=Application
Name=DisplayOS Kiosk
Exec=/usr/local/bin/displayos-kiosk
X-GNOME-Autostart-enabled=true
EOD
chown -R {{SET_USERNAME}}:{{SET_USERNAME}} /home/{{SET_USERNAME}}/.config
HOOKEOF

sed -i \
  -e "s|{{KIOSK_URL}}|${KIOSK_URL//\//\\/}|g" \
  -e "s|{{DEFAULT_BROWSER}}|${DEFAULT_BROWSER}|g" \
  -e "s|{{KIOSK_AUTORESTART}}|${KIOSK_AUTORESTART}|g" \
  -e "s|{{SET_USERNAME}}|${SET_USERNAME}|g" \
  "${CONFIG_DIR}/hooks/normal/020-kiosk.chroot"
chmod +x "${CONFIG_DIR}/hooks/normal/020-kiosk.chroot"

# Hook: LightDM Autologin
cat > "${CONFIG_DIR}/hooks/normal/030-autologin.chroot" <<EOF
#!/bin/sh
set -eu

install -d /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-displayos-autologin.conf <<'EOL'
[Seat:*]
autologin-user=${SET_USERNAME}
autologin-user-timeout=0
user-session=xfce
EOL

systemctl enable lightdm || true
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/030-autologin.chroot"

# Hook: Sysctl Hardening
cat > "${CONFIG_DIR}/hooks/normal/040-hardening.chroot" <<'EOF'
#!/bin/sh
set -eu
cat > /etc/sysctl.d/99-displayos.conf << 'EOS'
kernel.kptr_restrict=2
kernel.unprivileged_bpf_disabled=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
EOS
sysctl --system || true
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/040-hardening.chroot"

# Hook: Fix APT Repositories
cat > "${CONFIG_DIR}/hooks/normal/050-fix-apt.chroot" <<EOF
#!/bin/sh
set -eu
cat > /etc/apt/sources.list <<'EOS'
deb http://deb.debian.org/debian/ ${DISTRO} ${ARCHIVE_AREAS}
deb-src http://deb.debian.org/debian/ ${DISTRO} ${ARCHIVE_AREAS}

deb http://deb.debian.org/debian-security/ ${DISTRO}-security ${ARCHIVE_AREAS}
deb-src http://deb.debian.org/debian-security/ ${DISTRO}-security ${ARCHIVE_AREAS}

deb http://deb.debian.org/debian/ ${DISTRO}-updates ${ARCHIVE_AREAS}
deb-src http://deb.debian.org/debian/ ${DISTRO}-updates ${ARCHIVE_AREAS}
EOS
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/050-fix-apt.chroot"

# Hook: Hostname
cat > "${CONFIG_DIR}/hooks/normal/060-hostname.chroot" <<EOF
#!/bin/sh
set -eu
echo "${SET_HOSTNAME}" > /etc/hostname
sed -i '/127.0.1.1/d' /etc/hosts
printf "127.0.1.1\t%s\n" "${SET_HOSTNAME}" >> /etc/hosts
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/060-hostname.chroot"

# Hook: XFCE Configuration (workspace count + compositing)
cat > "${CONFIG_DIR}/hooks/normal/061-xfce-config.chroot" <<EOF
#!/bin/sh
set -eu

USER_HOME="/home/${SET_USERNAME}"
XFCE_CONFIG_DIR="\${USER_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml"

mkdir -p "\${XFCE_CONFIG_DIR}"

cat > "\${XFCE_CONFIG_DIR}/xfwm4.xml" <<'XFWM4EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="true"/>
    <property name="workspace_count" type="int" value="1"/>
  </property>
</channel>
XFWM4EOF

chown -R ${SET_USERNAME}:${SET_USERNAME} "\${USER_HOME}/.config"
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/061-xfce-config.chroot"

# Hook: GRUB Customization
cat > "${CONFIG_DIR}/hooks/normal/062-grub-customization.chroot" <<'GRUBEOF'
#!/bin/sh
set -eu

if [ -f /usr/local/share/displayos/wallpaper.png ]; then
  mkdir -p /boot/grub

  if command -v convert >/dev/null 2>&1; then
    convert /usr/local/share/displayos/wallpaper.png \
      -resize 1920x1080 \
      -gravity center \
      -extent 1920x1080 \
      -background black \
      -depth 8 \
      -type TrueColor \
      /boot/grub/background.png || cp /usr/local/share/displayos/wallpaper.png /boot/grub/background.png
  else
    cp /usr/local/share/displayos/wallpaper.png /boot/grub/background.png
  fi
fi

if [ -f /boot/grub/background.png ]; then
  if grep -q "^GRUB_BACKGROUND=" /etc/default/grub; then
    sed -i 's|^GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/background.png"|' /etc/default/grub
  else
    echo 'GRUB_BACKGROUND="/boot/grub/background.png"' >> /etc/default/grub
  fi
fi

if grep -q "^GRUB_GFXMODE=" /etc/default/grub; then
  sed -i 's/^GRUB_GFXMODE=.*/GRUB_GFXMODE=auto/' /etc/default/grub
else
  echo 'GRUB_GFXMODE=auto' >> /etc/default/grub
fi

if grep -q "^GRUB_GFXPAYLOAD_LINUX=" /etc/default/grub; then
  sed -i 's/^GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/' /etc/default/grub
else
  echo 'GRUB_GFXPAYLOAD_LINUX=keep' >> /etc/default/grub
fi

sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="{{PRODUCT_NAME}}"/' /etc/default/grub

sed -i 's/^GRUB_DISABLE_RECOVERY=.*/GRUB_DISABLE_RECOVERY="false"/' /etc/default/grub
if ! grep -q "^GRUB_DISABLE_RECOVERY=" /etc/default/grub; then
  echo 'GRUB_DISABLE_RECOVERY="false"' >> /etc/default/grub
fi

sed -i 's/^GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU="false"/' /etc/default/grub
if ! grep -q "^GRUB_DISABLE_SUBMENU=" /etc/default/grub; then
  echo 'GRUB_DISABLE_SUBMENU="false"' >> /etc/default/grub
fi

if [ -f /etc/grub.d/30_uefi-firmware ]; then
  chmod +x /etc/grub.d/30_uefi-firmware
fi
GRUBEOF

sed -i "s/{{PRODUCT_NAME}}/${PRODUCT_NAME}/g" "${CONFIG_DIR}/hooks/normal/062-grub-customization.chroot"
chmod +x "${CONFIG_DIR}/hooks/normal/062-grub-customization.chroot"

# Hook: System-Wide Wallpaper Configuration
cat > "${CONFIG_DIR}/hooks/normal/065-system-wallpaper.chroot" <<'WALLEOF'
#!/bin/sh
set -eu

WALLPAPER_SRC="/usr/local/share/displayos/wallpaper.png"
WALLPAPER_CANON="/usr/share/backgrounds/displayos-wallpaper.png"
WALLPAPER_PICKER="/usr/share/wallpapers/displayos-wallpaper.png"
WALLPAPER_XFCE_BACKDROPS="/usr/share/xfce4/backdrops/displayos-wallpaper.png"

if [ -f "$WALLPAPER_SRC" ]; then
  mkdir -p /usr/share/backgrounds
  install -m 0644 "$WALLPAPER_SRC" "$WALLPAPER_CANON"
else
  echo "[DisplayOS] WARNING: Wallpaper source missing: $WALLPAPER_SRC" >&2
fi

mkdir -p /usr/share/wallpapers
ln -sf "$WALLPAPER_CANON" "$WALLPAPER_PICKER"

mkdir -p /usr/share/xfce4/backdrops
ln -sf "$WALLPAPER_CANON" "$WALLPAPER_XFCE_BACKDROPS"

cat > /usr/local/bin/displayos-apply-wallpaper <<'EOF'
#!/bin/sh
set -eu

WP="/usr/share/backgrounds/displayos-wallpaper.png"

command -v xfconf-query >/dev/null 2>&1 || exit 0
[ -f "$WP" ] || exit 0

USER_NAME="${USER:-unknown}"
LOG="/tmp/displayos-wallpaper-${USER_NAME}.log"

log() { printf '%s %s\n' "$(date -Is 2>/dev/null || date)" "$*" >>"$LOG"; }

log "=== start ==="
log "DISPLAY=${DISPLAY-} DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS-}"

i=0
while ! pgrep -x xfdesktop >/dev/null 2>&1; do
  i=$((i+1))
  if [ "$i" -ge 100 ]; then
    log "xfdesktop not running after wait; exiting."
    exit 0
  fi
  sleep 0.2
done
log "xfdesktop is running."

keys=""
i=0
while [ -z "$keys" ]; do
  keys="$(xfconf-query -c xfce4-desktop -l 2>>"$LOG" | grep -E '/last-image$' || true)"
  i=$((i+1))
  if [ "$i" -ge 100 ]; then
    log "No /last-image keys found after wait; exiting."
    exit 0
  fi
  sleep 0.2
done

log "Found /last-image keys:"
printf '%s\n' "$keys" >>"$LOG"

cur_swn="$(xfconf-query -c xfce4-desktop -p /backdrop/single-workspace-number 2>/dev/null || true)"
case "$cur_swn" in
  ""|"-1")
    xfconf-query -c xfce4-desktop -p /backdrop/single-workspace-number -n -t int -s 1 2>>"$LOG" || true
    log "Set /backdrop/single-workspace-number=1 (was '$cur_swn')"
    ;;
  *)
    log "single-workspace-number is '$cur_swn' (leaving as-is)"
    ;;
esac

printf '%s\n' "$keys" | while IFS= read -r p; do
  [ -n "$p" ] || continue

  xfconf-query -c xfce4-desktop -p "$p" -s "$WP" 2>>"$LOG" \
    || xfconf-query -c xfce4-desktop -p "$p" -n -t string -s "$WP" 2>>"$LOG"

  base="${p%/last-image}"
  xfconf-query -c xfce4-desktop -p "$base/image-style" -s 5 -t int 2>>"$LOG" \
    || xfconf-query -c xfce4-desktop -p "$base/image-style" -n -t int -s 5 2>>"$LOG"

  log "Applied: $p -> $WP ; ${base}/image-style=5"
done

if command -v xfdesktop >/dev/null 2>&1; then
  xfdesktop --reload 2>>"$LOG" || true
  log "Ran: xfdesktop --reload"
fi

log "=== end ==="
exit 0
EOF
chmod +x /usr/local/bin/displayos-apply-wallpaper

mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/displayos-wallpaper.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=DisplayOS Wallpaper
Exec=/usr/local/bin/displayos-apply-wallpaper
OnlyShowIn=XFCE;
NoDisplay=true
EOF

if [ -f "$WALLPAPER_CANON" ] && [ -f /etc/lightdm/lightdm-gtk-greeter.conf ]; then
  if grep -q "^background=" /etc/lightdm/lightdm-gtk-greeter.conf; then
    sed -i "s|^background=.*|background=$WALLPAPER_CANON|" /etc/lightdm/lightdm-gtk-greeter.conf
  else
    echo "background=$WALLPAPER_CANON" >> /etc/lightdm/lightdm-gtk-greeter.conf
  fi
fi

cat > /usr/local/bin/restore-wallpaper <<'EOF'
#!/bin/sh
set -eu
if [ ! -x /usr/local/bin/displayos-apply-wallpaper ]; then
  echo "displayos-apply-wallpaper not found"
  exit 1
fi
/usr/local/bin/displayos-apply-wallpaper
echo "Wallpaper restore attempted. Check /tmp/displayos-wallpaper-\${USER:-unknown}.log for details."
EOF
chmod +x /usr/local/bin/restore-wallpaper

echo "[DisplayOS] System-wide wallpaper configured (XFCE)."
WALLEOF

chmod +x "${CONFIG_DIR}/hooks/normal/065-system-wallpaper.chroot"

# Hook: PipeWire Audio Services
cat > "${CONFIG_DIR}/hooks/normal/070-audio.chroot" <<'EOF'
#!/bin/sh
set -eu

systemctl --global enable pipewire.service || true
systemctl --global enable wireplumber.service || true
systemctl --global enable pipewire-pulse.socket || true

echo "[DisplayOS] PipeWire services enabled globally."
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/070-audio.chroot"

echo -e "${GREEN}[✓] Chroot hooks generated${NOCOLOR}"
