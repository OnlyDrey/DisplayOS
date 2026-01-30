# DisplayOS Setup Guide

This guide covers the complete installation and configuration of DisplayOS, a lightweight Linux distribution designed for digital signage and kiosk deployments.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Building the ISO](#building-the-iso)
3. [Installation](#installation)
4. [Initial Configuration](#initial-configuration)
5. [Network Setup](#network-setup)
6. [Security Configuration](#security-configuration)
7. [Customization](#customization)
8. [Troubleshooting](#troubleshooting)

---

## System Requirements

### Minimum Hardware (amd64)
- **CPU**: 64-bit processor (Intel/AMD)
- **RAM**: 2 GB minimum, 4 GB recommended
- **Storage**: 8 GB minimum, 16 GB recommended
- **Display**: Any resolution supported by the GPU

### Minimum Hardware (ARM/Raspberry Pi)
- **Device**: Raspberry Pi 3 or newer
- **RAM**: 1 GB minimum, 2 GB recommended
- **Storage**: 8 GB microSD card minimum
- **Display**: HDMI-compatible display

### Build System Requirements
- **OS**: Debian 12 (Bookworm) or Ubuntu 22.04+
- **RAM**: 4 GB minimum
- **Storage**: 20 GB free space
- **Access**: Root/sudo privileges
- **Network**: Internet connection for package downloads

---

## Building the ISO

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/displayos.git
cd displayos
```

### Step 2: Install Build Dependencies

The build script will automatically install dependencies, but you can pre-install them:

```bash
sudo apt-get update
sudo apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    rsync
```

### Step 3: Run the Build Script

```bash
# Make the script executable
chmod +x scripts/build_iso.sh

# Build for amd64 (default)
sudo ./scripts/build_iso.sh

# Build for ARM64
sudo ./scripts/build_iso.sh --arch=arm64

# Build with debug output
sudo ./scripts/build_iso.sh --debug

# Clean build (removes previous build artifacts)
sudo ./scripts/build_iso.sh --clean
```

### Step 4: Verify the Build

After a successful build, you'll find:
- `output/displayos-amd64.iso` - The bootable ISO image
- `output/displayos-amd64.iso.sha256` - SHA256 checksum
- `output/displayos-amd64.iso.md5` - MD5 checksum

Verify the checksum:
```bash
cd output
sha256sum -c displayos-amd64.iso.sha256
```

---

## Installation

### Creating Bootable Media

#### USB Drive (Recommended)

```bash
# Identify your USB drive (BE CAREFUL - this will erase all data)
lsblk

# Write the ISO (replace /dev/sdX with your USB device)
sudo dd if=output/displayos-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

#### Using Balena Etcher (GUI)

1. Download [Balena Etcher](https://www.balena.io/etcher/)
2. Select the DisplayOS ISO
3. Select your USB drive
4. Click "Flash!"

### Boot Options

When booting from the USB drive, you'll see three options:

1. **Start DisplayOS (Live Mode)** - Run directly from USB without installing
2. **Start DisplayOS (Safe Mode)** - Boot with basic graphics drivers
3. **Install DisplayOS** - Install to the internal drive

### Live Mode

Live mode is perfect for:
- Testing DisplayOS before installation
- Temporary deployments
- Recovery and troubleshooting

Note: Changes made in live mode are lost on reboot.

### Installation Process

1. Select "Install DisplayOS" from the boot menu
2. The installer will detect available disks
3. **Confirm disk selection** (this is the only prompt)
4. Wait for installation to complete (~5-10 minutes)
5. Remove the USB drive when prompted
6. Reboot into your new DisplayOS installation

### LUKS Encryption (Optional)

For encrypted installations, edit the preseed configuration before building:

1. Edit `src/preseed.cfg`
2. Uncomment the LUKS section at the bottom
3. Set your encryption password
4. Rebuild the ISO

---

## Initial Configuration

### Configuration File Location

All DisplayOS settings are stored in a single file:
```
/etc/displayos/config.conf
```

### Basic Configuration

After installation, edit the configuration:

```bash
# Login as displayos (password: displayos)
# Then edit the config:
sudo nano /etc/displayos/config.conf
```

### Essential Settings

```ini
# The URL to display
TARGET_URL=https://your-dashboard.example.com

# Browser selection (chromium or firefox)
BROWSER=chromium

# Display mode
DISPLAY_MODE=fullscreen

# Watchdog timeout (seconds)
WATCHDOG_TIMEOUT=30
```

### Apply Configuration Changes

After editing, restart the kiosk service:

```bash
sudo systemctl restart displayos-kiosk
```

---

## Network Setup

### Automatic Configuration

DisplayOS uses NetworkManager for network management. WiFi networks are configured automatically if credentials are provided in the config file.

### WiFi Configuration via Config File

Edit `/etc/displayos/config.conf`:

```ini
WIFI_SSID=YourNetworkName
WIFI_PASSWORD=YourWiFiPassword
WIFI_SECURITY=WPA-PSK
```

### WiFi Configuration via GUI

1. Press **Ctrl+Alt+W** to open Network Manager
2. Click "Add" to create a new connection
3. Select "Wi-Fi"
4. Enter your network details
5. Click "Save"

### WiFi Configuration via Command Line

```bash
# List available networks
nmcli device wifi list

# Connect to a network
nmcli device wifi connect "NetworkName" password "YourPassword"

# Check connection status
nmcli connection show --active
```

### Static IP Configuration

Edit the config file or use nmcli:

```bash
nmcli connection modify "Wired connection 1" \
    ipv4.method manual \
    ipv4.addresses 192.168.1.100/24 \
    ipv4.gateway 192.168.1.1 \
    ipv4.dns "8.8.8.8,8.8.4.4"
```

---

## Security Configuration

DisplayOS includes several security features by default. See the [Security Hardening](#security-hardening) section below for details.

### Security Hardening

Run the security script for additional hardening:

```bash
sudo /path/to/displayos/scripts/setup_security.sh
```

Options:
- `--enable-ssh` - Enable SSH access (disabled by default)
- `--skip-firewall` - Skip firewall configuration
- `--skip-apparmor` - Skip AppArmor configuration

### Firewall Rules

Default firewall rules (UFW):
- **Inbound**: All blocked (except SSH if enabled)
- **Outbound**: Only HTTP (80), HTTPS (443), DNS (53), NTP (123), DHCP (67/68)

To check firewall status:
```bash
sudo ufw status verbose
```

### Changing the Default Password

**Important**: Change the default password immediately after installation!

```bash
# Login as displayos
passwd
```

### Disabling Automatic Reboot

If you don't want automatic reboots after security updates:

```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
# Set: Unattended-Upgrade::Automatic-Reboot "false";
```

---

## Customization

### Changing the Wallpaper

1. Copy your wallpaper to `/usr/share/backgrounds/`
2. Update the Openbox or LightDM configuration
3. Restart the display manager

### Custom Browser Flags

Add custom Chromium flags in the config:

```ini
CHROMIUM_FLAGS=--disable-gpu --force-device-scale-factor=1.5
```

### Virtual Keyboard

Enable the on-screen keyboard for touchscreens:

```ini
VIRTUAL_KEYBOARD=true
VIRTUAL_KEYBOARD_THEME=dark
```

Toggle with **Ctrl+Alt+K**.

### Display Power Management

Configure screen blanking:

```ini
DPMS_ENABLED=true
DPMS_TIMEOUT=30  # minutes

# Or schedule on/off times
SCHEDULE_ENABLED=true
SCHEDULE_ON=08:00
SCHEDULE_OFF=22:00
```

---

## Troubleshooting

### Browser Won't Start

1. Check the kiosk service status:
   ```bash
   sudo systemctl status displayos-kiosk
   ```

2. View logs:
   ```bash
   sudo journalctl -u displayos-kiosk -f
   ```

3. Test browser manually:
   ```bash
   chromium --kiosk https://example.com
   ```

### Network Issues

1. Check NetworkManager status:
   ```bash
   nmcli general status
   nmcli device status
   ```

2. Restart networking:
   ```bash
   sudo systemctl restart NetworkManager
   ```

### Display Issues

1. Check X server:
   ```bash
   xdpyinfo
   ```

2. View display logs:
   ```bash
   cat /var/log/Xorg.0.log
   ```

### Exit Kiosk Mode

Press **Ctrl+Alt+Del** and enter the password to exit kiosk mode and access a terminal.

### Reset to Defaults

1. Boot into live mode from USB
2. Mount the installed system:
   ```bash
   sudo mount /dev/sda2 /mnt
   ```
3. Reset the config:
   ```bash
   sudo cp /mnt/etc/displayos/config.conf.default /mnt/etc/displayos/config.conf
   ```

---

## Getting Help

- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Check the `docs/` folder for more guides
- **Logs**: Most issues can be diagnosed from system logs

```bash
# View all DisplayOS logs
sudo journalctl -u "displayos-*"

# View system log
sudo journalctl -b
```
