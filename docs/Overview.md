# Overview

## What is DisplayOS?

DisplayOS is a Debian-based Linux distribution purpose-built for digital signage and kiosk deployments. It produces a bootable ISO image containing a fully automated Debian installer that, once installed, boots directly into a fullscreen browser displaying a configurable URL.

## Design Goals

- **Unattended operation** — zero-touch installation and boot via preseeded Debian installer.
- **Reproducible builds** — a single `config.env` file drives the entire build; same config produces the same ISO.
- **Minimal footprint** — only the packages required for XFCE, a browser, and networking are included.
- **Security by default** — kernel hardening via sysctl, SHA-512 password hashing, configurable SSH.
- **Offline installation** — the ISO contains everything needed; no network is required during install.

## High-Level Architecture

```
config.env ──> build.sh ──> scripts/00..10 ──> live-build ──> ISO
                  │
                  ├─ config/hooks/normal/*.chroot   (chroot hooks)
                  ├─ config/includes.chroot/         (files for the installed system)
                  ├─ config/includes.binary/          (files on the ISO media)
                  ├─ config/includes.installer/        (files for the installer initrd)
                  └─ config/package-lists/             (package list)
```

1. **`config.env`** defines every tunable (URL, password, locale, branding colors, packages, disk options).
2. **`build.sh`** sources the config, sets up paths, and runs each numbered script in order.
3. **Scripts `00` through `10`** perform initialization, preflight checks, dependency installation, password hashing, config-tree generation, installer branding, chroot hook generation, preseed generation, `lb config` + `lb build`, and artifact collection.
4. **`live-build`** (`lb`) does the heavy lifting: debootstrap, chroot, squashfs, and ISO assembly.
5. The final ISO lands in `output/`.

## Key Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| Base system | Debian 12 (Bookworm) | Stable, well-supported foundation |
| Desktop | XFCE4 | Lightweight desktop environment |
| Browser | Firefox ESR or Chromium | Fullscreen kiosk display |
| Init | systemd | Service management |
| Bootloader | GRUB2 (EFI + BIOS) | Dual-mode boot with custom branding |
| Installer | Debian Installer (preseeded) | Fully automated installation |
| Build tool | live-build | Debian ISO construction |
| Networking | NetworkManager | Wired and wireless connectivity |

## Use Cases

- Retail digital signage
- Dashboard displays (NOC, analytics, metrics)
- Information kiosks (wayfinding, schedules)
- Industrial HMI panels
- Event and conference displays

## Related Docs

- [Build Process](BuildProcess.md) — detailed build pipeline
- [Configuration](Configuration.md) — all configuration variables
- [System Behavior](SystemBehavior.md) — what the installed system does at runtime
