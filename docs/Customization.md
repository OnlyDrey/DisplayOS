# Customization

## Branding

### Product Name and Hostname

Edit `config.env`:

```bash
PRODUCT_NAME="MyCompany Kiosk"    # Shown in GRUB boot menu and ISO filename
SET_HOSTNAME="kiosk-lobby-01"     # System hostname
```

`PRODUCT_NAME` is substituted into the GRUB `GRUB_DISTRIBUTOR` value (via `062-grub-customization.chroot`), the ISO volume label, and the output filename.

### Visual Assets

Replace files in the `assets/` directory:

| File | Purpose | Recommended Size |
|------|---------|-----------------|
| `wallpaper.png` | Desktop background, GRUB background, LightDM background | 1920x1080+ PNG |
| `splash.png` | ISOLINUX and GRUB boot splash screen | 640x480 PNG for max compatibility |
| `installer-header.png` | Replaces Debian logo in installer header | PNG with transparency |
| `logo.png` | Project logo (README only, not used in build) | 256x256 or 512x512 PNG |

The wallpaper is automatically:

- Copied to the target system at `/usr/local/share/displayos/wallpaper.png`.
- Installed system-wide for XFCE (all monitors, all workspaces) and GNOME/dconf.
- Converted to 1920x1080 via ImageMagick for the GRUB background.
- Applied to LightDM login screen (if LightDM is present).

### GRUB Boot Menu

The build automatically configures GRUB with:

- **Custom OS name** from `PRODUCT_NAME` (replaces "Debian GNU/Linux").
- **Custom background** from `wallpaper.png`.
- **Recovery mode** enabled.
- **Advanced options submenu** enabled.
- **UEFI firmware setup entry** (on UEFI systems).
- **Graphics mode** set to `auto`.

This is handled by `062-grub-customization.chroot` (generated in `scripts/07-hooks.sh`).

### Installer Colors

See [Installer Branding](InstallerBranding.md) for color customization of the Debian installer UI.

## Adding Packages

Edit the `DEFAULT_PACKAGES_ARRAY` in `config.env`:

```bash
DEFAULT_PACKAGES_ARRAY=(
  # ... existing packages ...
  htop
  vim
  curl
  your-custom-package
)
```

Or override the entire package list at build time:

```bash
sudo -E PACKAGES="linux-image-amd64 live-boot live-config systemd-sysv xorg firefox-esr" ./build.sh
```

> NOTE: When using the `PACKAGES` override, essential packages are **not** automatically included. Make sure to include `linux-image-amd64`, `live-boot`, `live-config`, and `systemd-sysv` at minimum. The build script does add these if missing, but it is safer to be explicit.

## Changing the Kiosk URL

Edit `config.env`:

```bash
KIOSK_URL="https://dashboard.company.com/display"
```

Or at build time:

```bash
sudo -E KIOSK_URL="https://dashboard.company.com/display" ./build.sh
```

## Switching the Browser

The default browser is Firefox ESR. To switch to Chromium:

```bash
DEFAULT_BROWSER="chromium"
```

The kiosk script (`displayos-kiosk`) handles both browsers:

- **Firefox ESR**: launched with `--kiosk <URL>`.
- **Chromium**: launched with `--no-first-run --kiosk --incognito --disable-translate --disable-infobars --start-maximized <URL>`.

## Post-Install Package Management

The installed system comes with pre-configured APT repositories pointing to official Debian mirrors. After installation:

```bash
apt-get update
apt-get upgrade
apt-get install <package-name>
```

This is configured by both `050-fix-apt.chroot` (hook) and the preseed `late_command`.

## Keyboard Shortcuts

Two keyboard shortcuts are configured by default:

| Shortcut | Action |
|----------|--------|
| `Ctrl+Alt+T` | Open terminal (XFCE default) |
| `Ctrl+Alt+W` | Open Wi-Fi configuration (`nmtui` in terminal) |

The `Ctrl+Alt+W` shortcut is set up by:

1. `061-xfce-shortcut.chroot` hook (runs `xfconf-query` during build).
2. `displayos-ensure-shortcuts` script (runs at each login via XDG autostart as a fallback).

## Related Docs

- [Configuration](Configuration.md) — full variable reference
- [Installer Branding](InstallerBranding.md) — installer UI theming
- [Development](Development.md) — adding custom hooks
- [System Behavior](SystemBehavior.md) — runtime behavior
