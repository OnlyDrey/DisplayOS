# DisplayOS Rebuild Guide

This guide explains how to customize and rebuild the DisplayOS ISO to create your own tailored distribution.

## Table of Contents

1. [Overview](#overview)
2. [Customization Points](#customization-points)
3. [Modifying Packages](#modifying-packages)
4. [Custom Configuration](#custom-configuration)
5. [Branding and Assets](#branding-and-assets)
6. [Advanced Modifications](#advanced-modifications)
7. [Testing Your Build](#testing-your-build)
8. [Automation](#automation)

---

## Overview

DisplayOS is designed to be easily customizable. The modular structure allows you to:

- Add or remove packages
- Pre-configure settings
- Apply custom branding
- Include additional scripts
- Modify the boot process

All customizations should be made in the source files before running the build script.

---

## Customization Points

### Project Structure

```
displayos/
├── config/
│   ├── config.conf          # Default configuration template
│   └── systemd/             # Systemd service files
├── scripts/
│   ├── build_iso.sh         # Main build script
│   └── setup_*.sh           # Setup scripts (included in image)
├── src/
│   ├── packages.list        # Debian packages to install
│   ├── packages-arm.list    # ARM-specific packages
│   └── preseed.cfg          # Unattended installer config
├── assets/
│   ├── wallpaper.png        # Default wallpaper
│   └── branding/            # Logos and branding assets
└── docs/                    # Documentation
```

### Where to Make Changes

| What to Change | File/Location |
|----------------|---------------|
| Installed packages | `src/packages.list` |
| Default settings | `config/config.conf` |
| Browser URL | `config/config.conf` |
| Keyboard shortcuts | `scripts/setup_kiosk.sh` |
| Security settings | `scripts/setup_security.sh` |
| Boot menu | `scripts/build_iso.sh` (ISOLINUX/GRUB sections) |
| Installation defaults | `src/preseed.cfg` |
| Branding/wallpaper | `assets/` directory |

---

## Modifying Packages

### Adding Packages

Edit `src/packages.list` and add packages (one per line):

```bash
# My custom additions
vlc
libreoffice-writer
custom-package
```

### Removing Packages

Comment out or delete packages from `src/packages.list`:

```bash
# Removed: we don't need Firefox
# firefox-esr
```

### Architecture-Specific Packages

For ARM-specific packages, edit `src/packages-arm.list`:

```bash
# Raspberry Pi specific
libraspberrypi0
rpi-eeprom
```

### Package Verification

Before building, verify packages exist:

```bash
# Check if a package exists in Debian repos
apt-cache show package-name
```

---

## Custom Configuration

### Default URL

Edit `config/config.conf`:

```ini
TARGET_URL=https://your-company-dashboard.com
```

### Pre-configured WiFi

```ini
WIFI_SSID=CompanyWiFi
WIFI_PASSWORD=SecurePassword123
WIFI_SECURITY=WPA-PSK
```

### Custom Hostname

```ini
HOSTNAME=lobby-display-01
```

### Timezone and Locale

```ini
TIMEZONE=Europe/Oslo
KEYBOARD_LAYOUT=no
```

### Browser Selection

```ini
BROWSER=firefox  # or chromium
```

---

## Branding and Assets

### Custom Wallpaper

1. Create your wallpaper image (recommended: 1920x1080 PNG)
2. Replace `assets/wallpaper.png`
3. The build script will include it automatically

### Custom Boot Screen

Edit the ISOLINUX configuration in `scripts/build_iso.sh`:

```bash
# Find the isolinux.cfg section and modify:
MENU TITLE Your Company Name - Boot Menu
```

### Logo and Branding Files

Add files to `assets/branding/`:
- `logo.png` - Company logo
- `splash.png` - Boot splash screen
- `favicon.ico` - Browser favicon

### LightDM Greeter Customization

Create a custom greeter configuration:

```bash
# Add to build script, in configure_system function:
cat > "$chroot/etc/lightdm/lightdm-gtk-greeter.conf" << EOF
[greeter]
background=/usr/share/backgrounds/company-background.png
theme-name=Adwaita-dark
icon-theme-name=Adwaita
font-name=Sans 11
EOF
```

---

## Advanced Modifications

### Custom Scripts

Add scripts that run during installation or boot:

1. Create your script in `scripts/`
2. Reference it in the build script's `configure_system` function:

```bash
# In build_iso.sh, add to configure_system():
cp "$PROJECT_ROOT/scripts/my_custom_script.sh" "$chroot/usr/local/bin/"
chmod +x "$chroot/usr/local/bin/my_custom_script.sh"
```

### Systemd Services

Create custom services in `config/systemd/`:

```ini
# config/systemd/my-service.service
[Unit]
Description=My Custom Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/my_script.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

### Kernel Parameters

Modify boot parameters in the GRUB/ISOLINUX configurations:

```bash
# In build_iso.sh, grub.cfg section:
linux /live/vmlinuz boot=live components quiet splash my_param=value
```

### Custom Preseed

Modify `src/preseed.cfg` for installer customization:

```ini
# Change default user
d-i passwd/username string kiosk-user
d-i passwd/user-fullname string Kiosk Display User

# Set timezone
d-i time/zone string Europe/London
```

### Build Script Modifications

The build script (`scripts/build_iso.sh`) is modular. Key functions:

| Function | Purpose |
|----------|---------|
| `bootstrap_debian` | Base system installation |
| `install_packages` | Package installation |
| `configure_system` | System configuration |
| `configure_security` | Security hardening |
| `create_live_image` | SquashFS creation |
| `configure_bootloader` | GRUB/ISOLINUX setup |
| `create_iso` | Final ISO generation |

---

## Testing Your Build

### Quick Testing with QEMU

```bash
# Install QEMU
sudo apt install qemu-system-x86

# Test BIOS boot
qemu-system-x86_64 \
    -cdrom output/displayos-amd64.iso \
    -m 2048 \
    -enable-kvm

# Test UEFI boot (requires OVMF)
sudo apt install ovmf
qemu-system-x86_64 \
    -cdrom output/displayos-amd64.iso \
    -m 2048 \
    -enable-kvm \
    -bios /usr/share/ovmf/OVMF.fd
```

### Testing with VirtualBox

1. Create a new VM (Type: Linux, Version: Debian 64-bit)
2. Allocate at least 2 GB RAM
3. Mount the ISO as optical drive
4. Enable EFI in Settings > System (for UEFI testing)
5. Start the VM

### Testing Installation

To test the installer without affecting a real disk:

```bash
# Create a virtual disk
qemu-img create -f qcow2 test-disk.qcow2 20G

# Test installation
qemu-system-x86_64 \
    -cdrom output/displayos-amd64.iso \
    -hda test-disk.qcow2 \
    -m 2048 \
    -enable-kvm
```

### Checklist

Before deploying, verify:

- [ ] System boots in Live mode (BIOS)
- [ ] System boots in Live mode (UEFI)
- [ ] Browser starts and loads URL
- [ ] Network connectivity works
- [ ] WiFi connects (if configured)
- [ ] Keyboard shortcuts function
- [ ] Virtual keyboard works (if enabled)
- [ ] Installation completes successfully
- [ ] System reboots after installation
- [ ] Watchdog restarts crashed browser

---

## Automation

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
# .github/workflows/build.yml
name: Build DisplayOS

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y debootstrap squashfs-tools xorriso isolinux
    
    - name: Build ISO
      run: sudo ./scripts/build_iso.sh
    
    - name: Upload artifact
      uses: actions/upload-artifact@v3
      with:
        name: displayos-iso
        path: output/displayos-*.iso
```

### Version Tagging

Include version information in your build:

```bash
# In build_iso.sh, add to configure_system():
echo "VERSION=1.0.0" > "$chroot/etc/displayos/version"
echo "BUILD_DATE=$(date -I)" >> "$chroot/etc/displayos/version"
echo "GIT_HASH=$(git rev-parse --short HEAD)" >> "$chroot/etc/displayos/version"
```

### Automated Testing

Create a test script:

```bash
#!/bin/bash
# test_build.sh

ISO="output/displayos-amd64.iso"

# Verify ISO exists
[[ -f "$ISO" ]] || { echo "ISO not found"; exit 1; }

# Verify ISO is bootable
xorriso -indev "$ISO" -pvd_info 2>/dev/null | grep -q "Volume id" || {
    echo "ISO not valid"
    exit 1
}

# Verify size is reasonable (> 500MB)
SIZE=$(stat -f%z "$ISO" 2>/dev/null || stat -c%s "$ISO")
[[ $SIZE -gt 500000000 ]] || {
    echo "ISO too small: $SIZE bytes"
    exit 1
}

echo "Build verification passed!"
```

---

## Quick Reference

### Rebuild Commands

```bash
# Full rebuild (clean)
sudo ./scripts/build_iso.sh --clean

# Debug build (verbose output)
sudo ./scripts/build_iso.sh --debug

# ARM build
sudo ./scripts/build_iso.sh --arch=arm64

# Custom output directory
sudo ./scripts/build_iso.sh --output=/path/to/output
```

### Common Modifications

| Task | File to Edit |
|------|--------------|
| Change default URL | `config/config.conf` |
| Add software | `src/packages.list` |
| Change keyboard layout | `config/config.conf` |
| Modify boot menu | `scripts/build_iso.sh` |
| Add custom script | `scripts/` + build script |
| Change wallpaper | `assets/wallpaper.png` |
| Modify security | `scripts/setup_security.sh` |
