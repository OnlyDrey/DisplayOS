<img src="assets/branding/DisplayOS.png" alt="DisplayOS" width="400"/>
# DisplayOS

A lightweight, Debian-based Linux distribution designed for digital signage and kiosk deployments. DisplayOS boots directly into a browser in kiosk mode, displaying a user-defined URL.

## Features

- **Minimal Footprint**: Based on Debian Stable with only essential packages
- **Multi-Architecture**: Supports amd64 and ARM (Raspberry Pi)
- **Dual Boot Mode**: Compatible with Legacy BIOS/SeaBIOS and UEFI/OVMF
- **Browser Kiosk**: Chromium (primary) or Firefox in full-screen kiosk mode
- **Easy Configuration**: Single config file at `/etc/displayos/config.conf`
- **Network Management**: GUI and CLI tools with convenient shortcuts
- **Security Hardened**: AppArmor, firewall, automatic updates, optional LUKS encryption
- **Watchdog Service**: Automatic browser restart on crash
- **Touchscreen Support**: Virtual keyboard for touch displays

## Quick Start

### Prerequisites

- Debian-based build system (Debian 12 Bookworm recommended)
- At least 10GB free disk space
- Root/sudo access
- Internet connection

### Building DisplayOS

```bash
# Clone the repository
git clone https://github.com/OnlyDrey/DisplayOS.git
cd DisplayOS

# Make the build script executable
chmod +x scripts/build_iso.sh

# Run the build (requires root)
sudo ./scripts/build_iso.sh
```

The build process will create:
- `output/displayos-amd64.iso` - For standard PCs
- `output/displayos-arm64.iso` - For ARM devices (if building on ARM)

### Installation

1. Write the ISO to a USB drive:
   ```bash
   sudo dd if=output/displayos-amd64.iso of=/dev/sdX bs=4M status=progress
   ```

2. Boot from the USB drive

3. Choose installation mode:
   - **Live Mode**: Test without installing
   - **Install Mode**: Unattended installation (prompts only for disk confirmation)

### Configuration

Edit `/etc/displayos/config.conf` after installation:

```ini
# Target URL to display
TARGET_URL=https://example.com

# Browser selection (chromium or firefox)
BROWSER=chromium

# WiFi credentials (optional)
WIFI_SSID=MyNetwork
WIFI_PASSWORD=MySecretPassword

# Watchdog timeout in seconds
WATCHDOG_TIMEOUT=30
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `F5` | Reload browser |
| `Ctrl+Alt+Del` | Exit kiosk mode (requires password) |
| `Ctrl+Alt+K` | Toggle virtual keyboard |
| `Ctrl+Alt+W` | Open Network Manager GUI |

## Documentation

- [Setup Guide](docs/SETUP_GUIDE.md) - Detailed installation and configuration
- [Rebuild Guide](docs/REBUILD_GUIDE.md) - How to customize and rebuild the ISO
- [Configuration Reference](docs/CONFIGURATION.md) - All configuration options
- [Localization Guide](docs/LOCALIZATION.md) - Language and regional settings

## Project Structure

```
DisplayOS/
├── README.md                 # This file
├── LICENSE                   # Project license
├── docs/                     # Documentation
│   ├── SETUP_GUIDE.md
│   ├── REBUILD_GUIDE.md
│   ├── CONFIGURATION.md
│   └── LOCALIZATION.md
├── scripts/                  # Build and setup scripts
│   ├── build_iso.sh          # Main ISO build script
│   ├── setup_kiosk.sh        # Kiosk mode configuration
│   ├── setup_network.sh      # Network manager setup
│   └── setup_security.sh     # Security hardening
├── config/                   # Configuration templates
│   ├── config.conf           # Main config template
│   └── systemd/              # Systemd service files
│       ├── displayos-kiosk.service
│       ├── displayos-watchdog.service
│       └── displayos-network-shortcut.service
├── assets/                   # Visual assets
│   ├── wallpaper.png
│   └── branding/
│       └── logo-placeholder.png
└── src/                      # Source files
    ├── packages.list         # Required Debian packages
    ├── packages-arm.list     # ARM-specific packages
    └── preseed.cfg           # Unattended installation config
```

## Security Features

- Root SSH login disabled
- Automatic security updates via `unattended-upgrades`
- AppArmor enabled with browser profile
- UFW firewall (HTTP/HTTPS outbound only)
- Optional full-disk encryption (LUKS)
- Secure config file permissions (600)

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Debian Project
- Chromium and Firefox teams
- The open-source community

---

**DisplayOS** - Simple. Secure. Signage.
