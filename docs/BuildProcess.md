# Build Process

## Overview

The build is orchestrated by `build.sh`, which sources `config.env` and then runs 11 numbered scripts in sequence. Each script is sourced (not executed as a subprocess) so that all share the same environment variables.

## Build Pipeline

```
build.sh
  │
  ├── 00-init.sh ............. Logging and debug setup
  ├── 01-preflight.sh ........ Check for leftover artifacts and assets
  ├── 02-prerequisites.sh .... Install build dependencies via apt
  ├── 03-password.sh ......... Generate/hash root password
  ├── 04-dump-config.sh ...... Save effective config to output/
  ├── 05-config-tree.sh ...... Create live-build config/ directory tree
  ├── 06-installer-branding.sh Generate installer GTK theme and newt palette
  ├── 07-hooks.sh ............ Generate chroot hooks
  ├── 08-preseed.sh .......... Generate Debian installer preseed file
  ├── 09-livebuild.sh ........ Run lb clean, lb config, lb build
  └── 10-finalize.sh ......... Move ISO to output/, display summary
```

## Step-by-Step Breakdown

### Step 0: Initialize (`scripts/00-init.sh`)

- Creates the `output/` directory.
- Redirects all subsequent stdout and stderr to both the console and `output/build.log` via `tee`.
- If `DEBUG=yes`, enables bash `set -x` tracing and sets `LB_DEBUG=1`.

### Step 1: Preflight Checks (`scripts/01-preflight.sh`)

- Warns if `chroot/` or `binary/` directories exist from a previous build.
- Checks that the `assets/` directory exists (creates it if missing).
- Warns if `wallpaper.png` or `splash.png` are missing from `assets/`.

> NOTE: This step does **not** verify root privileges or check for installed dependencies. Root is assumed because `build.sh` should be run with `sudo`. Dependencies are installed in step 2.

### Step 2: Install Prerequisites (`scripts/02-prerequisites.sh`)

Runs `apt-get update` and installs the following packages:

| Package | Purpose |
|---------|---------|
| `live-build` | Debian live system builder |
| `debootstrap` | Bootstrap a basic Debian system |
| `squashfs-tools` | Create squashfs filesystem |
| `xorriso` | Create ISO 9660 images |
| `isolinux` | BIOS bootloader for ISO |
| `syslinux-utils` | Syslinux utilities |
| `wget` | File downloader |
| `ca-certificates` | TLS certificate bundle |
| `openssl` | Password hashing |
| `zstd` | Compression |
| `dos2unix` | Line-ending conversion |

### Step 3: Password Generation (`scripts/03-password.sh`)

- If `ROOT_PASSWORD` is empty **and** `GENERATE_ROOT_PASSWORD=yes`, generates a random 18-byte base64 password using `openssl rand`.
- Creates a SHA-512 hash via `openssl passwd -6` and exports it as `ROOT_PASSWORD_HASH`.

### Step 4: Dump Configuration (`scripts/04-dump-config.sh`)

Writes the effective build configuration to `output/configuration.txt` for traceability. Includes the root password in cleartext so it can be retrieved after the build.

### Step 5: Prepare Config Tree (`scripts/05-config-tree.sh`)

Creates the `config/` directory structure that `live-build` expects:

```
config/
├── package-lists/
│   └── displayos.list.chroot      # Package list
├── hooks/normal/                   # Chroot hooks (populated in step 7)
├── includes.chroot/                # Files copied into the installed system
│   ├── usr/local/share/displayos/  # Wallpaper
│   ├── usr/local/bin/              # Kiosk helper scripts
│   ├── etc/apt/sources.list        # APT repositories
│   ├── etc/xdg/autostart/          # XDG autostart entries
│   └── root/.config/xfce4/         # XFCE configuration
├── includes.binary/                # Files placed on the ISO media
│   ├── isolinux/splash.png
│   ├── boot/grub/splash.png
│   └── preseed/sources.list
└── includes.installer/             # Files for the installer initrd (step 6)
```

Key actions:

- Generates the package list from `PACKAGES` (or `DEFAULT_PACKAGES_ARRAY`).
- Ensures essential packages (`linux-image-amd64`, `live-boot`, `live-config`, `systemd-sysv`) are always present.
- Copies wallpaper and splash images into the appropriate locations.
- Creates APT `sources.list` for both the chroot and the preseed.
- Creates the `displayos-ensure-shortcuts` script and XFCE autostart entry for keyboard shortcuts.
- Configures XFCE window manager defaults (compositing on, single workspace).

### Step 6: Installer Branding (`scripts/06-installer-branding.sh`)

Customizes the Debian Installer appearance:

1. **Installer header** — copies `assets/installer-header.png` to `config/includes.installer/usr/share/graphics/logo_debian.png`.
2. **GTK2 theme** — generates a `gtkrc` file at `config/includes.installer/usr/share/themes/Clearlooks/gtk-2.0/gtkrc` using the `INSTALLER_*_COLOR` variables from `config.env`. Colors are converted from hex to GTK's 0-65535 RGB range.
3. **Newt palette** — generates `config/includes.installer/usr/lib/newt/palette` for text-mode installer colors.

### Step 7: Generate Chroot Hooks (`scripts/07-hooks.sh`)

Creates shell scripts in `config/hooks/normal/` that `live-build` executes inside the chroot during the build:

| Hook | Purpose |
|------|---------|
| `010-root-ssh.chroot` | Sets root password hash, enables/configures SSH, enables NetworkManager, disables unattended-upgrades, sets keyboard via debconf |
| `020-kiosk.chroot` | Creates `/usr/local/bin/displayos-kiosk` (launches browser in kiosk mode with optional auto-restart), creates XFCE autostart `.desktop` entry |
| `030-autologin.chroot` | Configures systemd getty override for root autologin on tty1, creates `/root/.bash_profile` to auto-start XFCE |
| `040-hardening.chroot` | Writes sysctl rules to `/etc/sysctl.d/99-displayos.conf` (kptr_restrict, syncookies, disable redirects, etc.) |
| `050-fix-apt.chroot` | Writes official Debian mirror URLs to `/etc/apt/sources.list` |
| `060-hostname.chroot` | Sets `/etc/hostname` and updates `/etc/hosts` |
| `061-xfce-shortcut.chroot` | Registers `Ctrl+Alt+W` shortcut for `nmtui` via `xfconf-query` |
| `062-grub-customization.chroot` | Converts wallpaper for GRUB background, sets `GRUB_DISTRIBUTOR`, enables recovery mode and advanced submenu |
| `065-system-wallpaper.chroot` | Installs wallpaper system-wide for XFCE, GNOME/dconf, and LightDM; creates `/usr/local/bin/restore-wallpaper` |

Template variables (`{{KIOSK_URL}}`, `{{PRODUCT_NAME}}`, etc.) are substituted with `sed` after each hook file is written.

### Step 8: Generate Preseed (`scripts/08-preseed.sh`)

Creates `config/includes.binary/preseed/displayos.cfg` — a Debian preseed file that automates the installer:

- Locale, timezone, keyboard from config variables.
- Network: auto-select interface, skip wireless, 5-second DHCP timeout.
- Root-only account (no additional user).
- Password hash from step 3.
- Disk selection: first non-removable disk (via `partman/early_command`).
- Partitioning: **only** if `ERASE_ALL_DATA_TOKEN=I_UNDERSTAND`; supports `efi_no_swap` and `efi_with_swap` recipes.
- GRUB bootloader configuration with EFI support.
- `late_command` writes APT sources.list and optionally renders custom GRUB entries.

### Step 9: Run live-build (`scripts/09-livebuild.sh`)

1. `lb clean --purge` — removes all previous build state.
2. `rm -rf cache/ chroot/ binary/ auto/` — ensures a completely clean environment.
3. `lb config` — configures live-build with options derived from `config.env`:
   - Distribution, architecture, binary format, archive areas.
   - Debian installer mode (`live`), GUI enabled/disabled.
   - ISO application/volume labels from `PRODUCT_NAME`.
   - Boot append strings for both install and live modes.
   - Bootloaders: `syslinux,grub-efi`.
   - Firmware inclusion enabled for both chroot and binary.
4. `lb build` — performs the full build (debootstrap, chroot, squashfs, ISO assembly).

### Step 10: Finalize (`scripts/10-finalize.sh`)

- Finds the generated `.iso` file in the working directory.
- Moves it to `output/<PRODUCT_NAME>-<DISTRO>-<ARCH>-unattended.iso`.
- Prints the ISO path, log path, config dump path, and root password.
- Exits with error if no ISO was produced.

## Build Artifacts

After a successful build:

```
output/
├── DisplayOS-bookworm-amd64-unattended.iso   # Bootable hybrid ISO (BIOS + UEFI)
├── build.log                                  # Full build log
└── configuration.txt                          # Effective config snapshot (includes password)
```

## Cleaning Between Builds

For a completely fresh build:

```bash
sudo lb clean --purge
rm -rf cache/ chroot/ binary/ auto/ config/
sudo ./build.sh
```

The build script already runs `lb clean --purge` at the start of step 9, so a manual clean is only needed if you want to remove cached packages as well.

## Related Docs

- [Configuration](Configuration.md) — all config variables and their defaults
- [Host Requirements](HostRequirements.md) — build host dependencies
- [Directory Structure](DirectoryStructure.md) — repository layout
- [Development](Development.md) — adding hooks and extending the build
