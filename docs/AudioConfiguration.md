# Audio Configuration

## Overview

DisplayOS uses **PipeWire** with **PulseAudio compatibility** for modern, reliable audio on the desktop. This architecture provides:

- Per-user audio sessions (essential for non-root desktop sessions)
- Compatibility with PulseAudio applications (pavucontrol, pactl, etc.)
- Modern audio routing and low-latency support
- Bluetooth and network audio support

## Why PipeWire?

Traditional PulseAudio installations can have issues when running as root or in kiosk environments. PipeWire solves these problems by:

1. **Proper user session isolation** - Each user gets their own audio session
2. **Better compatibility** - Works seamlessly with both ALSA and PulseAudio clients
3. **Modern architecture** - Designed for desktop Linux and handles complex audio routing
4. **No root issues** - Desktop runs as unprivileged user, audio "just works"

## Packages Included

The following packages are installed automatically:

| Package | Purpose |
|---------|---------|
| `pipewire` | Modern audio server (replaces PulseAudio server) |
| `pipewire-pulse` | PulseAudio compatibility layer (so pactl/pavucontrol work) |
| `wireplumber` | Session manager for PipeWire (handles device routing) |
| `pavucontrol` | PulseAudio Volume Control GUI |
| `pulseaudio-utils` | CLI tools (pactl, pacmd, etc.) |
| `alsa-utils` | ALSA utilities (alsamixer, aplay, etc.) |

**Note:** The `pulseaudio` package is installed but the PulseAudio daemon is **not** started. PipeWire's `pipewire-pulse` module provides the PulseAudio interface instead.

## How It Works

### 1. Global Service Enablement

During the ISO build, PipeWire services are enabled globally via the `070-audio.chroot` hook:

```bash
systemctl --global enable pipewire.service
systemctl --global enable wireplumber.service
systemctl --global enable pipewire-pulse.socket
```

This ensures that **every user** (including the autologin user) gets audio services automatically on login.

### 2. User Session Startup

When the configured user logs in (via LightDM autologin):

1. **systemd user session** starts
2. **PipeWire services** start automatically (via systemd user units)
3. **pipewire-pulse.socket** creates a PulseAudio-compatible interface
4. **pavucontrol and pactl** connect to PipeWire via this interface

### 3. Application Compatibility

- **PulseAudio clients** (pavucontrol, pactl, Firefox, Chromium) → connect to `pipewire-pulse`
- **ALSA clients** (older apps, games) → connect to PipeWire's ALSA plugin
- **Native PipeWire clients** → connect directly to PipeWire

Everything routes through PipeWire transparently.

## Verification Commands

After booting the installed system, verify audio is working:

### Check PipeWire Services

```bash
systemctl --user status pipewire wireplumber pipewire-pulse
```

**Expected output:**
- All services show `active (running)`
- No error messages in the status output

### Check Audio Server Connection

```bash
pactl info
```

**Expected output:**
```
Server String: /run/user/1000/pulse/native
Library Protocol Version: 35
Server Protocol Version: 35
Server Name: PulseAudio (on PipeWire 0.3.x)
...
```

**Key indicator:** "PulseAudio (on PipeWire)" confirms PipeWire is providing the PulseAudio interface.

### List Audio Sinks (Output Devices)

```bash
pactl list short sinks
```

**Expected output:**
```
0  alsa_output.pci-0000_00_1b.0.analog-stereo  module-alsa-card.c  s16le 2ch 44100Hz  SUSPENDED
```

At least one sink should appear. Status may be `SUSPENDED` (idle) or `RUNNING` (active).

### Test Audio Playback

```bash
# Play a test sound (requires audio file)
paplay /usr/share/sounds/alsa/Front_Center.wav

# Or use speaker-test
speaker-test -t sine -f 1000 -c 2 -l 1
```

### Open Volume Control GUI

```bash
pavucontrol
```

**Expected behavior:**
- Window opens immediately
- **No** "Establishing connection to PulseAudio..." message
- Tabs show: Playback, Recording, Output Devices, Input Devices, Configuration

## Troubleshooting

### Problem: pavucontrol shows "Establishing connection to PulseAudio..."

**Cause:** PipeWire services are not running for the current user.

**Solutions:**

1. **Check if running as correct user (not root):**
   ```bash
   whoami  # Should show 'displayos' or your SET_USERNAME, NOT 'root'
   ```

   If you're logged in as root, audio won't work properly. Log out and let LightDM autologin handle the session.

2. **Check PipeWire service status:**
   ```bash
   systemctl --user status pipewire wireplumber pipewire-pulse
   ```

   If services are inactive or failed, restart them:
   ```bash
   systemctl --user restart pipewire wireplumber pipewire-pulse
   ```

3. **Check if systemd user session is running:**
   ```bash
   loginctl show-user $(whoami)
   ```

   Should show `State=active` or `State=lingering`.

4. **Check XDG_RUNTIME_DIR:**
   ```bash
   echo $XDG_RUNTIME_DIR  # Should be /run/user/1000 (or similar)
   ```

   If empty, the user session may not have initialized properly. Reboot or restart LightDM.

### Problem: pactl shows "Connection failure: Connection refused"

**Cause:** PipeWire's PulseAudio interface socket doesn't exist.

**Solutions:**

1. **Check socket status:**
   ```bash
   systemctl --user status pipewire-pulse.socket
   ```

   If not running:
   ```bash
   systemctl --user start pipewire-pulse.socket
   ```

2. **Check socket file exists:**
   ```bash
   ls -la /run/user/$(id -u)/pulse/native
   ```

   If missing, PipeWire isn't running or XDG_RUNTIME_DIR is wrong.

3. **Restart all audio services:**
   ```bash
   systemctl --user restart pipewire pipewire-pulse wireplumber
   ```

### Problem: No audio output (but pavucontrol works)

**Cause:** Audio is routed to the wrong sink, or the sink is muted.

**Solutions:**

1. **Check current sinks:**
   ```bash
   pactl list short sinks
   ```

2. **Check if sink is muted:**
   ```bash
   pactl list sinks | grep -A 10 "Sink #0"
   ```

   Look for `Mute: yes`. Unmute with:
   ```bash
   pactl set-sink-mute 0 0
   ```

3. **Set volume:**
   ```bash
   pactl set-sink-volume 0 50%
   ```

4. **Use pavucontrol GUI** to check routing under "Output Devices" tab.

### Problem: Audio works but has crackles/pops

**Cause:** Buffer size or latency issues.

**Solutions:**

1. **Increase PipeWire buffer size** (create `~/.config/pipewire/pipewire.conf.d/10-buffer.conf`):
   ```
   context.properties = {
       default.clock.rate = 48000
       default.clock.quantum = 1024
       default.clock.min-quantum = 512
   }
   ```

   Then restart:
   ```bash
   systemctl --user restart pipewire
   ```

2. **Check for USB audio device latency** - USB devices may need larger buffers.

### Problem: Services fail to start at login

**Cause:** Global enable didn't work, or systemd user session isn't starting.

**Solutions:**

1. **Manually enable services for current user:**
   ```bash
   systemctl --user enable pipewire.service
   systemctl --user enable wireplumber.service
   systemctl --user enable pipewire-pulse.socket
   systemctl --user start pipewire wireplumber pipewire-pulse
   ```

2. **Check service files exist:**
   ```bash
   ls -la /usr/lib/systemd/user/pipewire*
   ```

3. **Check journalctl for errors:**
   ```bash
   journalctl --user -u pipewire -u wireplumber -u pipewire-pulse
   ```

## Advanced: Using ALSA Directly

PipeWire includes an ALSA plugin that routes ALSA applications through PipeWire. This is configured automatically. To test:

```bash
# List ALSA cards
aplay -l

# Play audio via ALSA
aplay /usr/share/sounds/alsa/Front_Center.wav
```

ALSA output will go through PipeWire transparently.

## Related Docs

- [System Behavior](SystemBehavior.md) — boot sequence and user session startup
- [Troubleshooting](Troubleshooting.md) — general troubleshooting guide
- [Configuration](Configuration.md) — configuration variables
