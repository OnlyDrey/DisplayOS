# Host Requirements

## Build Host

### Operating System

The build must be run on a **Debian-based** Linux distribution:

- Debian 12 (Bookworm) or newer — recommended
- Ubuntu 22.04 LTS or newer
- Other Debian derivatives (Linux Mint, etc.) — should work but are not tested

### Privileges

The build script must be run as **root** (via `sudo`). Several steps require root access:

- `apt-get install` for build dependencies
- `lb config` and `lb build` (live-build operates on chroot environments)
- Creating and mounting filesystems

### Disk Space

| Phase | Space Required |
|-------|---------------|
| Build dependencies | ~500 MB |
| Debootstrap + chroot | ~3-5 GB |
| Squashfs + ISO assembly | ~3-5 GB |
| Package cache | ~2-4 GB |
| Final ISO | ~1-3 GB |
| **Total recommended** | **15 GB free** |

An SSD is recommended for faster build times.

### Network

An internet connection is required during the build for:

- `apt-get update` and package installation (step 2).
- `debootstrap` to download the base Debian system (step 9, inside `lb build`).
- Package installation in the chroot (step 9).

The network is **not** required during installation of the built ISO — the ISO contains all packages.

## Build Dependencies

These are installed automatically by `scripts/02-prerequisites.sh`:

| Package | Version | Purpose |
|---------|---------|---------|
| `live-build` | 1:20230502+ | Debian live system builder (`lb` command) |
| `debootstrap` | 1.0.128+ | Bootstrap a base Debian filesystem |
| `squashfs-tools` | 1:4.5+ | Create compressed squashfs filesystems |
| `xorriso` | 1.5.4+ | ISO 9660 / El Torito image creation |
| `isolinux` | 3:6.04+ | BIOS boot support for ISOs |
| `syslinux-utils` | 3:6.04+ | Syslinux-related utilities |
| `wget` | 1.21+ | HTTP downloader |
| `ca-certificates` | any | Root CA certificates for HTTPS |
| `openssl` | 3.0+ | Password hashing (`openssl passwd -6`) |
| `zstd` | 1.5+ | Zstandard compression |
| `dos2unix` | 7.4+ | Line-ending conversion |

> NOTE: Version numbers listed are from Debian Bookworm. Older versions may work but are not tested.

## Target Hardware Requirements

The ISO produced by DisplayOS is designed for systems meeting these minimum specs:

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 64-bit x86 (amd64) | Any modern x86_64 processor |
| RAM | 2 GB | 4 GB |
| Storage | 10 GB | 20 GB (for logs, caches, updates) |
| Graphics | Any framebuffer-capable GPU | Hardware-accelerated GPU |
| Boot | UEFI or Legacy BIOS | UEFI |
| Network | Ethernet (optional) | Ethernet or Wi-Fi |

## Related Docs

- [Build Process](BuildProcess.md) — what the build does at each step
- [Configuration](Configuration.md) — configuring the build
- [Troubleshooting](Troubleshooting.md) — common build issues
