# Changelog

All notable changes to DisplayOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-02-20

### Added

- **`unclutter` autostart** — the mouse cursor is now automatically hidden after 3 seconds of inactivity via a system-wide XDG autostart entry (`/etc/xdg/autostart/unclutter.desktop`) that runs `unclutter -idle 3` on XFCE session start. Previously `unclutter` was installed but never launched.
- **NTP time synchronization** — `systemd-timesyncd` (already in the package list) is now enabled as a system service at build time via the new `072-timesyncd.chroot` hook. Debian NTP pool servers are pre-configured in `/etc/systemd/timesyncd.conf.d/displayos.conf`, so the clock synchronizes automatically on first boot without any manual steps.

### Documentation

- [System Behavior](docs/SystemBehavior.md) — added **Time Synchronization** section covering `timedatectl status`, `set-ntp`, `set-timezone`, `show-timesync --all`, and custom NTP server configuration.
- [System Behavior](docs/SystemBehavior.md) — updated boot sequence diagram and Desktop Environment section to reflect that `unclutter -idle 3` now starts via XDG autostart (not a separate `unclutter-startup` package).

## [1.0.0] - 2026-02-11

### Added

**Core Distribution**
- Debian 12 Bookworm-based Linux distribution optimized for digital signage and kiosk systems
- Lightweight XFCE4 desktop environment for minimal resource usage
- Bootable hybrid ISO image supporting both UEFI and legacy BIOS systems
- Fully offline installation from live media with no network dependency

**Unattended Installation**
- Zero-touch deployment with preseeded Debian installer
- Automated partitioning with EFI and optional swap support
- Unattended system configuration requiring no user interaction during installation
- Handles systems with existing LVM/RAID/crypto metadata automatically

**Kiosk & Browser**
- Automatic fullscreen browser mode on boot (Firefox ESR or Chromium)
- Configurable display URL via `KIOSK_URL` environment variable
- Browser auto-restart on crash for 24/7 reliability
- Custom keyboard shortcuts (Ctrl+Alt+T for terminal, Ctrl+Alt+W for Wi-Fi)

**Audio System**
- Modern PipeWire audio server with WirePlumber session manager
- PulseAudio compatibility layer for broad application support
- Per-user audio sessions for non-root desktop operation
- pavucontrol GUI for audio device management
- Comprehensive troubleshooting documentation for common audio scenarios

**User & Security**
- Non-root autologin user with sudo privileges for secure administration
- Locked root account preventing direct root login
- SHA-512 password hashing with secure salt generation
- Kernel hardening parameters (kptr_restrict, syncookies, ICMP redirect protection)
- SSH server support for remote administration (configurable)

**Network & Connectivity**
- NetworkManager for unified wired and wireless network management
- DHCP auto-configuration for Ethernet connections
- Wi-Fi configuration via nmtui interface (Ctrl+Alt+W shortcut)
- Wireless tools and WPA supplicant support
- Network-free installation mode to prevent installer hangs on Wi-Fi-only systems

**Customization & Branding**
- Single `config.env` configuration file controlling all build parameters
- Custom product name, wallpaper, and splash screen support
- Branded GRUB bootloader with custom themes
- Debian installer UI customization (GTK2 themes, colors, header graphics)
- Locale, timezone, and keyboard layout configuration
- Environment variable overrides at build time

**Build System**
- 11-stage modular build pipeline using Debian live-build framework
- Automated dependency installation for build prerequisites
- Configuration validation and preflight checks
- Comprehensive build logging with output to `output/build.log`
- Configuration snapshot saved to `output/configuration.txt`
- Reproducible builds ensuring consistent output from identical configuration

**System Management**
- Working APT package manager with pre-configured Debian repositories
- Security updates enabled by default
- Hostname configuration with fallback to MAC-based naming
- Custom GRUB configuration for reliable boot behavior

### Documentation

- Complete documentation suite with 11 comprehensive guides
- [Configuration Reference](docs/Configuration.md) - All 30+ configuration variables explained
- [Audio Configuration](docs/AudioConfiguration.md) - PipeWire setup and troubleshooting
- [System Behavior](docs/SystemBehavior.md) - Runtime behavior and boot sequence
- [Build Process](docs/BuildProcess.md) - Detailed 11-stage build pipeline explanation
- [Troubleshooting](docs/Troubleshooting.md) - Solutions for build, installation, and runtime issues
- [Customization](docs/Customization.md) - Branding and behavior customization guide
- [Installer Branding](docs/InstallerBranding.md) - Debian installer UI theming
- [Host Requirements](docs/HostRequirements.md) - Build host dependencies and requirements
- [Directory Structure](docs/DirectoryStructure.md) - Repository and runtime file layout
- [Development](docs/Development.md) - Contributing and extending the build system
- [Overview](docs/Overview.md) - Project overview and architecture

### Security

- Non-root desktop user model with sudo-only administration
- Root account locked with no password login capability
- Kernel security parameters enforced via sysctl
- Offline-first installation eliminating network-based attack vectors during setup
- Minimal attack surface with only essential packages installed

[1.0.0]: https://github.com/OnlyDrey/DisplayOS/releases/tag/v1.0.0
