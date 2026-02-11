# Troubleshooting

## Build Issues

### `lb: command not found`

The `live-build` package is not installed. This should be handled automatically by `scripts/02-prerequisites.sh`, but if the build fails before that step:

```bash
sudo apt-get update
sudo apt-get install live-build
```

### Permission denied during build

The build must be run as root:

```bash
sudo ./build.sh
```

If using environment overrides, use `sudo -E`:

```bash
sudo -E KIOSK_URL="https://example.com" ./build.sh
```

### Out of disk space

The build requires approximately 15 GB of free space. To reclaim space from previous builds:

```bash
sudo lb clean --purge
rm -rf cache/ chroot/ binary/ auto/ config/
```

Then re-run:

```bash
sudo ./build.sh
```

### Build produces no ISO

If `scripts/10-finalize.sh` reports "Build did not produce an ISO":

1. Check `output/build.log` for error details.
2. Common causes:
   - Network failure during `debootstrap` or package download.
   - Missing or broken packages in the package list.
   - Disk space exhaustion during `lb build`.
3. Try a clean rebuild:
   ```bash
   sudo lb clean --purge
   rm -rf cache/ chroot/ binary/ auto/ config/
   sudo ./build.sh
   ```

### Package not found during build

If `lb build` fails because a package is unavailable:

1. Verify the package name exists in Debian Bookworm:
   ```bash
   apt-cache search <package-name>
   ```
2. Check that `ARCHIVE_AREAS` in `config.env` includes the required area (`main`, `contrib`, `non-free`, `non-free-firmware`).
3. If using `chromium`, the package name in Debian is `chromium` (not `chromium-browser`).

## Installation Issues

### Installer does not auto-partition

Auto-partitioning is disabled by default as a safety measure. To enable it, set the token before building:

```bash
sudo -E ERASE_ALL_DATA_TOKEN=I_UNDERSTAND ./build.sh
```

Without this token, the installer will pause at the partitioning step and require manual input.

### Installer hangs at network configuration

The preseed sets a 5-second DHCP timeout. If no wired network is available, the installer may pause briefly. It should continue after the timeout. If it hangs indefinitely, check:

- That the ISO was built correctly.
- That the preseed file was generated (check `output/build.log` for step 8 output).

### Wrong keyboard layout after installation

Keyboard is configured in three places. If the layout is wrong:

1. Check `KEYMAP` in `config.env` (default: `no` for Norwegian).
2. Verify `KEYMAP_MODEL` (default: `pc105`).
3. Post-install fix:
   ```bash
   dpkg-reconfigure keyboard-configuration
   ```

## Runtime Issues

### Audio: pavucontrol shows "Establishing connection to PulseAudio..."

**Cause:** PipeWire services are not running for the current user.

**Solutions:**

1. Check if running as correct user (not root):
   ```bash
   whoami  # Should show your username (e.g., displayos), NOT 'root'
   ```

2. Verify PipeWire services are running:
   ```bash
   systemctl --user status pipewire wireplumber pipewire-pulse
   ```

3. Restart audio services if needed:
   ```bash
   systemctl --user restart pipewire wireplumber pipewire-pulse
   ```

4. Check for errors:
   ```bash
   journalctl --user -u pipewire -u wireplumber -u pipewire-pulse
   ```

See [Audio Configuration](AudioConfiguration.md) for detailed troubleshooting.

### Audio: pactl shows "Connection failure: Connection refused"

**Cause:** PipeWire's PulseAudio interface socket doesn't exist.

**Solutions:**

1. Check socket status:
   ```bash
   systemctl --user status pipewire-pulse.socket
   ```

2. Start the socket if inactive:
   ```bash
   systemctl --user start pipewire-pulse.socket
   ```

3. Verify socket file exists:
   ```bash
   ls -la /run/user/$(id -u)/pulse/native
   ```

### Audio: No sound output (but pavucontrol works)

**Cause:** Audio is routed to the wrong sink, or the sink is muted.

**Solutions:**

1. Check current sinks:
   ```bash
   pactl list short sinks
   ```

2. Check if sink is muted:
   ```bash
   pactl list sinks | grep -A 10 "Sink #0"
   ```

3. Unmute and set volume:
   ```bash
   pactl set-sink-mute 0 0
   pactl set-sink-volume 0 50%
   ```

4. Use pavucontrol GUI to check routing under "Output Devices" tab.

### `apt-get update` fails after installation

If APT points to `cdrom://` repositories instead of online mirrors, the APT fix hooks may not have applied correctly. Manually fix:

```bash
cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
EOF
apt-get update
```

### GRUB background not showing

- Ensure `assets/wallpaper.png` exists before building.
- The image must be PNG format. GRUB requires an 8-bit RGB PNG.
- `imagemagick` (included in the default packages) converts and resizes the image during the build. If `convert` is unavailable in the chroot, the raw image is copied instead, which may not be GRUB-compatible.

### Browser does not start

1. Check if the kiosk script exists:
   ```bash
   ls -la /usr/local/bin/displayos-kiosk
   ```
2. Check the autostart entry:
   ```bash
   ls -la /home/displayos/.config/autostart/displayos.desktop  # Replace 'displayos' with your username
   ```
3. Run the kiosk script manually to see errors:
   ```bash
   /usr/local/bin/displayos-kiosk
   ```
4. Verify the browser package is installed:
   ```bash
   which firefox-esr   # or: which chromium
   ```

### Screen goes blank / display power saving

The kiosk script disables DPMS and screen blanking. If the screen still blanks:

```bash
xset s off -dpms
xset s noblank
```

To make this persistent, verify the kiosk script is running at login.

### SSH connection refused

1. Check if SSH is enabled: verify `ENABLE_SSH=yes` was set during build.
2. Check if the service is running:
   ```bash
   systemctl status ssh
   ```
3. If not running:
   ```bash
   systemctl enable ssh
   systemctl start ssh
   ```

### Wallpaper not applied

1. Verify the wallpaper exists on the installed system:
   ```bash
   ls -la /usr/share/backgrounds/displayos-wallpaper.png
   ```
2. Manually restore:
   ```bash
   /usr/local/bin/restore-wallpaper
   ```

## Debug Mode

To get verbose output from the build:

```bash
sudo -E DEBUG=yes ./build.sh
```

This enables:

- Bash `set -x` tracing (every command is printed before execution).
- `LB_DEBUG=1` for live-build verbose output.
- All output is logged to `output/build.log`.

## Related Docs

- [Build Process](BuildProcess.md) — understanding the build pipeline
- [Configuration](Configuration.md) — verifying variable values
- [System Behavior](SystemBehavior.md) — understanding runtime behavior
