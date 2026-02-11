# System Behavior

## Boot Sequence

After installation, the system follows this boot path:

```
GRUB  -->  systemd  -->  LightDM (autologin as configured user)
                              |
                              +--> XFCE session for user
                                     |
                                     +--> displayos-kiosk (autostart)
                                     +--> displayos-apply-wallpaper (autostart)
```

1. **GRUB** boots the kernel with the `PRODUCT_NAME` branding and custom background.
2. **systemd** starts services, including LightDM display manager.
3. **LightDM** automatically logs in the configured user (set via `SET_USERNAME` in `config.env`).
4. **XFCE** starts for the user and triggers autostart entries:
   - `displayos-kiosk` — the kiosk browser launcher (in user's home directory).
   - `displayos-apply-wallpaper` — applies the wallpaper to XFCE desktop (system-wide autostart).

## User Account Model

The system is configured with:

- **One non-root user** — specified by `SET_USERNAME` (default: `displayos`)
- **Full sudo privileges** — the user can run any command via `sudo` (passwordless or with user password)
- **Root account locked** — root login is disabled, accessible only via `sudo` from the configured user
- **Autologin enabled** — LightDM automatically logs in the user on boot (no password prompt)

### User Groups

The configured user is a member of:

| Group | Purpose |
|-------|---------|
| `sudo` | Administrative privileges (can run `sudo`) |
| `audio` | Access to audio devices |
| `video` | Access to video devices and GPU |
| `plugdev` | Access to pluggable devices (USB, etc.) |
| `netdev` | Network device management |

### Security Model

- **Desktop runs as unprivileged user** (not root) for security and proper per-user audio sessions
- **Root access via sudo** — administrator can run `sudo -i` or `sudo <command>` as needed
- **No root SSH login** — SSH access via the configured user account only
- **Password set during build** — either specified via `SET_PASSWORD` or auto-generated

## Kiosk Mode

The kiosk launcher (`/usr/local/bin/displayos-kiosk`) performs these steps:

1. Disables screen blanking and DPMS (`xset s off -dpms`, `xset s noblank`).
2. Sets the desktop wallpaper via `feh --bg-scale` (if `wallpaper.png` exists).
3. Launches the configured browser in kiosk/fullscreen mode:
   - **Firefox ESR**: `firefox-esr --kiosk <URL>`
   - **Chromium**: `chromium --no-first-run --kiosk --incognito --disable-translate --disable-infobars --start-maximized <URL>`
4. If `KIOSK_AUTORESTART=yes`, the browser is wrapped in a `while true` loop that restarts it after a 2-second delay on exit or crash.

The kiosk script is installed to the user's autostart directory:
- Location: `/home/${SET_USERNAME}/.config/autostart/displayos.desktop`

## Audio System

DisplayOS uses **PipeWire** with **PulseAudio compatibility**:

- **PipeWire services** are enabled globally during build (`systemctl --global enable`)
- **User session** automatically starts `pipewire`, `wireplumber`, and `pipewire-pulse` on login
- **pavucontrol and pactl** work out of the box via PipeWire's PulseAudio interface
- **No root audio issues** because desktop runs as unprivileged user

See [Audio Configuration](AudioConfiguration.md) for detailed audio setup and troubleshooting.

## Network

- **NetworkManager** is enabled and manages all network interfaces.
- **Wired (Ethernet)**: auto-configured via DHCP.
- **Wireless (Wi-Fi)**: can be configured post-install using:
  - `Ctrl+Alt+W` keyboard shortcut (opens `nmtui` in a terminal).
  - `nmtui` from any terminal.
  - `nmcli device wifi connect "SSID" password "passphrase"` from the command line.

## SSH Access

When `ENABLE_SSH=yes` (the default):

- SSH daemon listens on port 22.
- Root login is **disabled** (`PermitRootLogin no`).
- Password authentication is enabled for the configured user.
- Connect with: `ssh <username>@<ip-address>` (e.g., `ssh displayos@192.168.1.100`)

Once logged in via SSH, you can switch to root with:

```bash
sudo -i
```

The password is the value of `SET_PASSWORD` (or the auto-generated password found in `output/configuration.txt`).

## Security Hardening

The `040-hardening.chroot` hook applies these sysctl settings via `/etc/sysctl.d/99-displayos.conf`:

| Setting | Value | Purpose |
|---------|-------|---------|
| `kernel.kptr_restrict` | `2` | Hide kernel pointers from all users |
| `kernel.unprivileged_bpf_disabled` | `1` | Disable unprivileged BPF |
| `net.ipv4.conf.all.rp_filter` | `1` | Enable reverse path filtering |
| `net.ipv4.tcp_syncookies` | `1` | Enable SYN cookies against SYN floods |
| `net.ipv4.conf.all.accept_redirects` | `0` | Reject ICMP redirects |
| `net.ipv4.conf.all.secure_redirects` | `0` | Reject secure ICMP redirects |
| `net.ipv6.conf.all.accept_redirects` | `0` | Reject IPv6 ICMP redirects |
| `net.ipv4.conf.all.accept_source_route` | `0` | Reject source-routed packets |

Additionally:

- `unattended-upgrades` is purged during the build to prevent automatic updates.
- Passwords are hashed with SHA-512.
- Root account is locked (no root login).

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Alt+T` | Open terminal (XFCE default) |
| `Ctrl+Alt+W` | Open Wi-Fi configuration (`nmtui` in terminal) |

## Desktop Environment

- **XFCE4** with compositing enabled and a single workspace.
- **Screen blanking** disabled by the kiosk script.
- **Wallpaper** set system-wide (XFCE, LightDM, and GRUB) from `assets/wallpaper.png`.
- **`unclutter`** is included in the package list to hide the mouse cursor after inactivity.

## LightDM Display Manager

LightDM is configured for autologin via `/etc/lightdm/lightdm.conf.d/50-displayos-autologin.conf`:

```ini
[Seat:*]
autologin-user=<SET_USERNAME>
autologin-user-timeout=0
user-session=xfce
```

- **No password prompt** on boot
- **Greeter background** set to custom wallpaper (if available)
- **Session type** is XFCE

## APT Repositories

The installed system has pre-configured APT sources pointing to official Debian mirrors:

```
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
```

This is set up in three places for redundancy:

1. `050-fix-apt.chroot` hook (during build chroot phase).
2. `config/includes.chroot/etc/apt/sources.list` (file overlay).
3. Preseed `late_command` (during installation).

## Administrative Tasks

Common administrative tasks can be performed via sudo:

```bash
# Install packages
sudo apt update
sudo apt install <package-name>

# System updates
sudo apt upgrade

# Modify system configuration
sudo nano /etc/some-config-file

# Restart services
sudo systemctl restart <service-name>

# View system logs
sudo journalctl -xe

# Switch to root shell
sudo -i
```

## Related Docs

- [Configuration](Configuration.md) — variables that control system behavior
- [Audio Configuration](AudioConfiguration.md) — audio system details
- [Customization](Customization.md) — changing kiosk URL, browser, shortcuts
- [Troubleshooting](Troubleshooting.md) — runtime issues
