#!/usr/bin/env bash

# [06] Generate Chroot Hooks
# This script creates the chroot hooks for live-build to execute during build

echo "[+] Generating chroot hooks..."

# Hook: Root password, SSH, NM, keyboard
cat > "${CONFIG_DIR}/hooks/normal/010-root-ssh.chroot" <<EOF
#!/bin/sh
set -e
# Root password
usermod -p '${ROOT_PASSWORD_HASH}' root || true

# SSH daemon
if [ "${ENABLE_SSH}" = "yes" ]; then
  systemctl enable ssh || true
fi
sed -i 's/^#\?Port.*/Port 22/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin ${ENABLE_SSH}/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication ${ENABLE_SSH}/' /etc/ssh/sshd_config

# NetworkManager
systemctl enable NetworkManager || true

# Auto-updates (disabled)
apt-get -y purge unattended-upgrades || true

# Keyboard debconf fallback
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
set -e

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

# XFCE autostart for root
install -d /root/.config/autostart
cat > /root/.config/autostart/displayos.desktop <<'EOD'
[Desktop Entry]
Type=Application
Name=DisplayOS Kiosk
Exec=/usr/local/bin/displayos-kiosk
X-GNOME-Autostart-enabled=true
EOD
HOOKEOF

# Substitute kiosk variables
sed -i \
  -e "s|{{KIOSK_URL}}|${KIOSK_URL//\//\\/}|g" \
  -e "s|{{DEFAULT_BROWSER}}|${DEFAULT_BROWSER}|g" \
  -e "s|{{KIOSK_AUTORESTART}}|${KIOSK_AUTORESTART}|g" \
  "${CONFIG_DIR}/hooks/normal/020-kiosk.chroot"
chmod +x "${CONFIG_DIR}/hooks/normal/020-kiosk.chroot"

# Hook: Root Autologin
cat > "${CONFIG_DIR}/hooks/normal/030-autologin.chroot" <<'EOF'
#!/bin/sh
set -e
install -d /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << 'EOG'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOG
systemctl daemon-reload || true

# Auto start XFCE on tty1
cat > /root/.bash_profile <<'EOP'
if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
  startxfce4
fi
EOP
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/030-autologin.chroot"

# Hook: Sysctl Hardening
cat > "${CONFIG_DIR}/hooks/normal/040-hardening.chroot" <<'EOF'
#!/bin/sh
set -e
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

# Hook: Hostname
cat > "${CONFIG_DIR}/hooks/normal/060-hostname.chroot" <<EOF
#!/bin/sh
set -e
echo "displayos" > /etc/hostname
sed -i '/127.0.1.1/d' /etc/hosts
printf "127.0.1.1\t%s\n" "displayos" >> /etc/hosts
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/060-hostname.chroot"

# Hook: XFCE Shortcut (belt & braces)
cat > "${CONFIG_DIR}/hooks/normal/061-xfce-shortcut.chroot" <<'EOF'
#!/bin/sh
set -e
su - root -c 'xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Primary><Alt>w" -n -t string -s "xfce4-terminal --title=\"Wi-Fi\" --hide-menubar -x nmtui"' || true
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/061-xfce-shortcut.chroot"

echo "[✓] Chroot hooks generated"
