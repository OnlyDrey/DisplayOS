<!-- LOGO -->
<h1>
<p align="center">
  <img src="assets/logo.png" alt="Logo" width="200">
  <br>DisplayOS
</h1>
  <p align="center">
    Build, boot, display.
    <br />
    <a href="#about">About</a>
    ·
    <a href="#features">Features</a>
    ·
    <a href="#quick-start">Quick Start</a>
    ·
    <a href="#keyboard-shortcuts">Keyboard Shortcuts</a>
    ·
    <a href="#documentation">Documentation</a>
  </p>
</p>

<p align="center">
  <a href="https://github.com/OnlyDrey/DisplayOS/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/GPL--3.0-blue?style=flat-square&logo=license&label=License" alt="License: GPL-3.0">
  </a>
  <a href="https://www.debian.org/">
    <img src="https://img.shields.io/badge/Debian-A81D33?style=flat-square&logo=debian&logoColor=white&label=Based%20on" alt="Debian">
  </a>
  <img src="https://img.shields.io/badge/amd64-green?style=flat-square&label=Architecture" alt="Architecture: amd64">
</p>

## About

**DisplayOS** is a lightweight, security-focused Linux distribution based on **Debian Bookworm**, built for **digital signage and kiosk systems**.

It produces a bootable ISO image that installs an unattended system booting directly into a fullscreen browser displaying a configurable URL. The build is driven entirely by a single configuration file (`config.env`) and a set of modular shell scripts that wrap Debian's `live-build` framework.

### Why DisplayOS?

- **Zero-touch deployment** - Build once, deploy anywhere with preseeded installation
- **Offline-first** - Complete installation from live media, no network required
- **Security by default** - Non-root desktop, locked root account, kernel hardening
- **Modern audio** - PipeWire with PulseAudio compatibility for reliable audio control
- **Reproducible** - Configuration-driven builds ensure consistency across deployments

## Features

- 🚀 **Fully unattended installer** with preseeded Debian installer
- 💿 **Offline installation** from live media
- 🔐 **Non-root autologin** with sudo privileges for administration
- 🌐 **Browser kiosk mode** (Firefox ESR or Chromium)
- 🔊 **PipeWire audio** with PulseAudio compatibility
- 📺 **Configurable display URL** via environment variables
- 🎨 **Custom branding** (wallpaper, GRUB theme, product name)
- 🔧 **SSH access** for remote administration
- 📦 **Working package manager** with pre-configured APT repositories

## Prerequisites

- A **Debian-based** Linux host (Debian 12+, Ubuntu 22.04+, or similar)
- **Root access** (via `sudo`)
- At least **15 GB** of free disk space
- Internet connection (for downloading Debian packages during build)

Build dependencies are installed automatically by the build script.

## Quick Start

### 1. Clone and prepare

```bash
git clone https://github.com/OnlyDrey/DisplayOS.git
cd DisplayOS
chmod +x build.sh scripts/*.sh
```

### 2. Configure

Edit `config.env` to set your kiosk URL, username, password, and other options:

```bash
nano config.env
```

Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `KIOSK_URL` | `https://example.com` | URL displayed in the fullscreen browser |
| `SET_USERNAME` | `displayos` | Username for the autologin user (has sudo) |
| `SET_PASSWORD` | *(empty)* | User password; leave empty to auto-generate |
| `DEFAULT_BROWSER` | `firefox-esr` | `firefox-esr` or `chromium` |
| `ENABLE_SSH` | `yes` | Enable SSH server on the installed system |

See [Configuration Reference](docs/Configuration.md) for all available variables.

### 3. Build the ISO

```bash
sudo ./build.sh
```

Or override variables at build time:

```bash
sudo -E KIOSK_URL="https://dashboard.example.com" SET_USERNAME="kiosk" SET_PASSWORD="changeme" ./build.sh
```

The output ISO is placed at:

```
output/DisplayOS-bookworm-amd64-unattended.iso
```

### 4. Write to USB

```bash
sudo dd if=output/DisplayOS-bookworm-amd64-unattended.iso of=/dev/sdX bs=4M status=progress
sync
```

Replace `/dev/sdX` with your USB device.

## Keyboard Shortcuts

| Shortcut | Action |
|--------|--------|
| `Ctrl+Alt+T` | Open terminal |
| `Ctrl+Alt+W` | Open Wi‑Fi configuration (`nmtui` in terminal) |

## Documentation

Comprehensive documentation is available in the `docs/` directory:

| Document | Description |
|----------|-------------|
| [Configuration Reference](docs/Configuration.md) | Complete variable reference for `config.env` |
| [Audio Configuration](docs/AudioConfiguration.md) | PipeWire setup and troubleshooting |
| [System Behavior](docs/SystemBehavior.md) | Runtime behavior and boot sequence |
| [Build Process](docs/BuildProcess.md) | Step-by-step build pipeline explanation |
| [Troubleshooting](docs/Troubleshooting.md) | Common issues and solutions |
| [Customization](docs/Customization.md) | How to customize branding and behavior |
| [Installer Branding](docs/InstallerBranding.md) | Theming the Debian installer UI |
| [Host Requirements](docs/HostRequirements.md) | Build host dependencies and requirements |
| [Directory Structure](docs/DirectoryStructure.md) | Repository and runtime file layout |
| [Development](docs/Development.md) | Contributing and extending the build |

## Folder Structure

```
DisplayOS/
├── build.sh              # Build orchestrator (entrypoint)
├── config.env            # All configuration variables
├── scripts/              # Numbered build stages (00 through 10)
├── assets/               # Wallpaper, splash, logo, installer header
├── docs/                 # Detailed documentation
├── config/               # Generated at build time by live-build
└── output/               # Build artifacts (ISO, log, config dump)
```

## License

DisplayOS is licensed under the [GNU General Public License v3.0](LICENSE).

## Acknowledgments

DisplayOS builds upon:

- [Debian GNU/Linux](https://www.debian.org/)
- [live-build](https://wiki.debian.org/DebianLive)
- [XFCE Desktop Environment](https://www.xfce.org/)
- [Firefox ESR](https://www.mozilla.org/firefox/enterprise/)
- [PipeWire](https://pipewire.org/)
