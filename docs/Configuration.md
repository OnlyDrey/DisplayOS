# Configuration

## Overview

All DisplayOS configuration is centralized in `config.env`. Every variable uses the `${VAR:-default}` pattern, so you can either edit the file directly or override any value via environment variables at build time.

## Variable Reference

### User / Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `SET_USERNAME` | `displayos` | Username for the non-root user (autologin + sudo) |
| `SET_PASSWORD` | *(empty)* | User password in cleartext; leave empty to auto-generate |
| `GENERATE_PASSWORD` | `yes` | If `SET_PASSWORD` is empty, generate a random 18-byte base64 password |

**Password behavior:**

- If `SET_PASSWORD` is set to a non-empty value, that value is used.
- If `SET_PASSWORD` is empty and `GENERATE_PASSWORD=yes`, a random password is generated via `openssl rand -base64 18`.
- The password (whether set or generated) is hashed with SHA-512 (`openssl passwd -6`) and embedded in the preseed and chroot hooks.
- The cleartext password is saved in `output/configuration.txt` for retrieval.

**User privileges:**

The configured user has full administrative privileges:
- Member of groups: `sudo`, `audio`, `video`, `plugdev`, `netdev`
- Can run any command via `sudo` (including `apt install`, system modifications, etc.)
- Root account is **locked** and accessible only via `sudo`

### Kiosk Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `KIOSK_URL` | `https://example.com` | URL displayed in the fullscreen browser |
| `KIOSK_AUTORESTART` | `yes` | Restart browser automatically if it exits or crashes |
| `DEFAULT_BROWSER` | `firefox-esr` | Browser to use: `firefox-esr` or `chromium` |

When `KIOSK_AUTORESTART=yes`, the kiosk script wraps the browser in a `while true` loop with a 2-second delay between restarts. When set to anything else, the browser runs via `exec` (no restart on exit).

### Identity / Branding

| Variable | Default | Description |
|----------|---------|-------------|
| `PRODUCT_NAME` | `DisplayOS` | Product name shown in GRUB menu, ISO volume label, and output filename |
| `SET_HOSTNAME` | `displayos` | System hostname applied to `/etc/hostname` and `/etc/hosts` |
| `ARCH` | `amd64` | Target architecture passed to `lb config` |
| `DISTRO` | `bookworm` | Debian release codename |
| `ISO_LABEL` | `${PRODUCT_NAME}_${DISTRO}_${ARCH}` | ISO volume label |

> NOTE: While `ARCH` and `DISTRO` are configurable, the default package list contains architecture-specific packages (`linux-image-amd64`, `grub-efi-amd64`). Changing `ARCH` to a different value requires updating the package list in `config.env` accordingly.

### Installer UI Branding

| Variable | Default | Description |
|----------|---------|-------------|
| `INSTALLER_PRIMARY_COLOR` | `#0197F6` | Primary brand color (buttons, highlights, banner) |
| `INSTALLER_SECONDARY_COLOR` | `#66C0F9` | Secondary color (active states, accents) |
| `INSTALLER_TEXT_COLOR` | `#99D5FB` | Text color on colored backgrounds |
| `INSTALLER_BG_COLOR` | `#001E31` | Dialog background color |

Colors must be in `#RRGGBB` hex format (6-digit, no shorthand). These colors are converted to GTK2 RGB values for the graphical installer and are documented separately in [Installer Branding](InstallerBranding.md).

### Locale / Time / Keyboard

| Variable | Default | Description |
|----------|---------|-------------|
| `TIMEZONE` | `Europe/Oslo` | System timezone (e.g., `America/New_York`, `Asia/Tokyo`) |
| `LOCALE` | `en_US.UTF-8` | System locale |
| `KEYMAP` | `no` | Keyboard layout code (e.g., `us`, `de`, `fr`, `gb`) |
| `KEYMAP_MODEL` | `pc105` | Keyboard model |
| `KEYMAP_VARIANT` | *(empty)* | Keyboard variant (leave empty for default) |

These values are applied in three places:

1. The preseed file (installer-time configuration).
2. The `010-root-ssh.chroot` hook (debconf-set-selections fallback).
3. The `lb config --bootappend-install` string.

### SSH and Security

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_SSH` | `yes` | Enable SSH server; controls SSH daemon and authentication settings |

When `ENABLE_SSH=yes`:
- `ssh.service` is enabled via systemd.
- `PermitRootLogin` is set to `no` (root login disabled).
- `PasswordAuthentication` is set to `yes`.
- SSH access via the configured user account (has sudo privileges).

When `ENABLE_SSH=no` (or any other value):
- `ssh.service` is **not** enabled.
- SSH daemon configuration is still updated but service doesn't start.

### Disk Handling

| Variable | Default | Description |
|----------|---------|-------------|
| `PARTITION_RECIPE` | `efi_with_swap` | Partition layout: `efi_no_swap` or `efi_with_swap` |
| `ERASE_ALL_DATA_TOKEN` | *(empty)* | Must be set to `I_UNDERSTAND` to enable automatic partitioning |

> **Warning:** When `ERASE_ALL_DATA_TOKEN=I_UNDERSTAND`, the installer will **automatically erase all data** on the first non-removable disk without prompting. Use only when you understand the implications.

**Partition recipes:**

- `efi_no_swap` — 512 MB EFI System Partition + remainder as ext4 root.
- `efi_with_swap` — 512 MB ESP + 2 GB swap + remainder as ext4 root.

When the token is **not** set, `partman/confirm` is set to `false`, which prevents automatic partitioning. The installer will stop at the partitioning step for manual input.

### live-build Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BINARY_IMAGES` | `iso-hybrid` | ISO format; `iso-hybrid` creates a USB-bootable ISO |
| `ARCHIVE_AREAS` | `main contrib non-free non-free-firmware` | Debian archive areas to enable |
| `DEBIAN_INSTALLER` | `live` | Installer mode passed to `lb config --debian-installer` |
| `DEBIAN_INSTALLER_GUI` | `true` | Enable graphical installer |
| `APT_RECOMMENDS` | `false` | Install recommended packages (keep `false` for minimal image) |

### Debug

| Variable | Default | Description |
|----------|---------|-------------|
| `DEBUG` | `no` | When `yes`, enables `set -x` tracing and `LB_DEBUG=1` |

## Overriding at Build Time

Variables can be overridden without editing `config.env`:

```bash
# Single override
sudo -E KIOSK_URL="https://company.com/dashboard" ./build.sh

# Multiple overrides
sudo -E \
  KIOSK_URL="https://company.com" \
  PRODUCT_NAME="CompanyKiosk" \
  SET_HOSTNAME="kiosk-001" \
  SET_USERNAME="kiosk" \
  SET_PASSWORD="s3cure!" \
  ./build.sh

# Destructive build with auto-partitioning
sudo -E ERASE_ALL_DATA_TOKEN=I_UNDERSTAND ./build.sh
```

The `-E` flag preserves the calling user's environment through `sudo`.

## Package List

The default package list is defined in `config.env` as `DEFAULT_PACKAGES_ARRAY`. You can override the entire list by setting the `PACKAGES` environment variable (space-separated string), or edit the array directly.

Default packages by category:

| Category | Packages |
|----------|----------|
| Kernel / live | `linux-image-amd64`, `live-boot`, `live-config`, `systemd-sysv` |
| Bootloader | `grub-efi-amd64`, `efibootmgr`, `grub-customizer` |
| Firmware | `firmware-linux`, `firmware-linux-nonfree`, `firmware-iwlwifi`, `firmware-realtek`, `firmware-atheros`, `firmware-bnx2`, `firmware-bnx2x`, `wireless-tools`, `wpasupplicant` |
| Desktop | `xorg`, `xfce4`, `xfce4-terminal`, `lightdm`, `lightdm-gtk-greeter`, `network-manager`, `network-manager-gnome`, `sudo` |
| Tools | `openssh-server`, `feh`, `x11-xserver-utils`, `unclutter`, `imagemagick` |
| Audio | `pipewire`, `pipewire-pulse`, `wireplumber`, `pavucontrol`, `pulseaudio`, `alsa-utils` |
| Browser | `${DEFAULT_BROWSER}` (resolved to `firefox-esr` or `chromium`) |

## Asset Files

| File | Default Location | Purpose |
|------|-----------------|---------|
| Wallpaper | `assets/wallpaper.png` | Desktop background, GRUB background, LightDM background |
| Splash | `assets/splash.png` | ISOLINUX and GRUB boot splash |
| Installer header | `assets/installer-header.png` | Replaces Debian logo in installer UI |
| Logo | `assets/logo.png` | Project logo (used in README) |

Asset paths can be overridden: `WALLPAPER_IMG`, `SPLASH_IMG`, `INSTALLER_IMG`.

## Related Docs

- [Build Process](BuildProcess.md) — how variables flow through the build
- [Customization](Customization.md) — practical customization guide
- [Installer Branding](InstallerBranding.md) — detailed color theming
- [Audio Configuration](AudioConfiguration.md) — audio setup details
