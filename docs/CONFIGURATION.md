# DisplayOS Configuration Reference

Complete reference for all configuration options in `/etc/displayos/config.conf`.

## Table of Contents

1. [Configuration File Overview](#configuration-file-overview)
2. [Display Settings](#display-settings)
3. [Network Settings](#network-settings)
4. [Watchdog Settings](#watchdog-settings)
5. [System Settings](#system-settings)
6. [User Interface](#user-interface)
7. [Security Settings](#security-settings)
8. [Logging](#logging)
9. [Advanced Browser Options](#advanced-browser-options)
10. [Display Power Management](#display-power-management)

---

## Configuration File Overview

### Location
```
/etc/displayos/config.conf
```

### Permissions
The configuration file should have restricted permissions:
```bash
chmod 600 /etc/displayos/config.conf
chown root:root /etc/displayos/config.conf
```

### Applying Changes
After editing the configuration, restart the kiosk service:
```bash
sudo systemctl restart displayos-kiosk
```

### File Format
- Lines starting with `#` are comments
- Empty lines are ignored
- Format: `KEY=value` (no spaces around `=`)
- String values don't require quotes (but can include them)

---

## Display Settings

### TARGET_URL

**Description**: The URL to display in kiosk mode.

**Type**: String (URL)

**Default**: `https://example.com`

**Examples**:
```ini
TARGET_URL=https://dashboard.example.com
TARGET_URL=https://signage.company.com/display/1
TARGET_URL=file:///var/www/html/index.html
```

---

### BROWSER

**Description**: Browser to use for kiosk mode.

**Type**: String (`chromium` or `firefox`)

**Default**: `chromium`

**Notes**:
- Chromium is recommended for better kiosk mode support
- Firefox will be used as fallback if Chromium fails

**Example**:
```ini
BROWSER=chromium
```

---

### DISPLAY_MODE

**Description**: Browser window mode.

**Type**: String (`fullscreen` or `windowed`)

**Default**: `fullscreen`

**Notes**:
- `fullscreen`: Maximized kiosk mode (recommended for production)
- `windowed`: Normal window (useful for debugging)

**Example**:
```ini
DISPLAY_MODE=fullscreen
```

---

### RESOLUTION

**Description**: Force a specific screen resolution.

**Type**: String (WIDTHxHEIGHT) or empty

**Default**: (empty - auto-detect)

**Examples**:
```ini
RESOLUTION=1920x1080
RESOLUTION=1280x720
RESOLUTION=3840x2160
```

---

## Network Settings

### WIFI_SSID

**Description**: WiFi network name to connect to.

**Type**: String

**Default**: (empty)

**Example**:
```ini
WIFI_SSID=CompanyWiFi
```

---

### WIFI_PASSWORD

**Description**: WiFi network password.

**Type**: String

**Default**: (empty)

**Security Note**: This is stored in plain text. Ensure the config file has restricted permissions (chmod 600).

**Example**:
```ini
WIFI_PASSWORD=MySecretPassword123
```

---

### WIFI_SECURITY

**Description**: WiFi security type.

**Type**: String

**Options**: `WPA-PSK`, `WPA-EAP`, `WEP`, `OPEN`

**Default**: `WPA-PSK`

**Example**:
```ini
WIFI_SECURITY=WPA-PSK
```

---

### STATIC_IP

**Description**: Static IP address configuration.

**Type**: String (IP/PREFIX format) or empty for DHCP

**Default**: (empty - use DHCP)

**Example**:
```ini
STATIC_IP=192.168.1.100/24
```

---

### STATIC_GATEWAY

**Description**: Default gateway for static IP configuration.

**Type**: String (IP address)

**Default**: (empty)

**Example**:
```ini
STATIC_GATEWAY=192.168.1.1
```

---

### STATIC_DNS

**Description**: DNS servers for static IP configuration.

**Type**: String (comma-separated IP addresses)

**Default**: (empty)

**Example**:
```ini
STATIC_DNS=8.8.8.8,8.8.4.4
```

---

## Watchdog Settings

### WATCHDOG_TIMEOUT

**Description**: Time in seconds before the browser is considered unresponsive and restarted.

**Type**: Integer (10-300)

**Default**: `30`

**Example**:
```ini
WATCHDOG_TIMEOUT=30
```

---

### WATCHDOG_ENABLED

**Description**: Enable or disable the watchdog service.

**Type**: Boolean (`true` or `false`)

**Default**: `true`

**Example**:
```ini
WATCHDOG_ENABLED=true
```

---

### WATCHDOG_MAX_RESTARTS

**Description**: Maximum number of restart attempts before giving up.

**Type**: Integer (0 = unlimited)

**Default**: `0`

**Example**:
```ini
WATCHDOG_MAX_RESTARTS=10
```

---

### WATCHDOG_RESTART_DELAY

**Description**: Delay in seconds between restart attempts.

**Type**: Integer

**Default**: `5`

**Example**:
```ini
WATCHDOG_RESTART_DELAY=5
```

---

## System Settings

### HOSTNAME

**Description**: System hostname.

**Type**: String

**Default**: `displayos`

**Example**:
```ini
HOSTNAME=lobby-display-01
```

---

### TIMEZONE

**Description**: System timezone.

**Type**: String (TZ database name)

**Default**: `UTC`

**Common Values**:
- `UTC`
- `Europe/Oslo`
- `Europe/London`
- `America/New_York`
- `America/Los_Angeles`
- `Asia/Tokyo`

Use `timedatectl list-timezones` for a complete list.

**Example**:
```ini
TIMEZONE=Europe/Oslo
```

---

### KEYBOARD_LAYOUT

**Description**: Keyboard layout.

**Type**: String (XKB layout code)

**Default**: `no` (Norwegian)

**Common Values**:
- `us` - US English
- `gb` - UK English
- `de` - German
- `fr` - French
- `no` - Norwegian
- `se` - Swedish
- `dk` - Danish
- `es` - Spanish
- `it` - Italian

**Example**:
```ini
KEYBOARD_LAYOUT=no
```

---

### KEYBOARD_VARIANT

**Description**: Keyboard layout variant.

**Type**: String or empty

**Default**: (empty)

**Examples**:
```ini
KEYBOARD_VARIANT=dvorak
KEYBOARD_VARIANT=mac
```

---

## User Interface

### VIRTUAL_KEYBOARD

**Description**: Enable on-screen virtual keyboard for touchscreens.

**Type**: Boolean (`true` or `false`)

**Default**: `false`

**Notes**: Toggle with Ctrl+Alt+K

**Example**:
```ini
VIRTUAL_KEYBOARD=true
```

---

### VIRTUAL_KEYBOARD_THEME

**Description**: Visual theme for the virtual keyboard.

**Type**: String (`default`, `dark`, `small`)

**Default**: `default`

**Example**:
```ini
VIRTUAL_KEYBOARD_THEME=dark
```

---

### SHOW_CURSOR

**Description**: Show or hide the mouse cursor.

**Type**: Boolean (`true` or `false`)

**Default**: `true`

**Notes**: Set to `false` for touchscreen-only displays.

**Example**:
```ini
SHOW_CURSOR=true
```

---

### CURSOR_HIDE_TIMEOUT

**Description**: Hide the cursor after this many seconds of inactivity.

**Type**: Integer (0 to disable)

**Default**: `5`

**Example**:
```ini
CURSOR_HIDE_TIMEOUT=5
```

---

## Security Settings

### SSH_ENABLED

**Description**: Enable SSH remote access.

**Type**: Boolean (`true` or `false`)

**Default**: `false`

**Security Note**: Enabling SSH may expose the system to remote attacks. Use strong passwords or key-based authentication.

**Example**:
```ini
SSH_ENABLED=false
```

---

### AUTO_UPDATES

**Description**: Enable automatic security updates.

**Type**: Boolean (`true` or `false`)

**Default**: `true`

**Notes**: Updates are applied automatically and may cause a reboot at 4 AM.

**Example**:
```ini
AUTO_UPDATES=true
```

---

### KIOSK_EXIT_PASSWORD

**Description**: Password hash for exiting kiosk mode (Ctrl+Alt+Del).

**Type**: String (password hash)

**Default**: (uses system user password)

**Generate with**:
```bash
openssl passwd -6
```

**Example**:
```ini
KIOSK_EXIT_PASSWORD=$6$rounds=4096$salt$hashedpassword
```

---

## Logging

### DEBUG_MODE

**Description**: Enable verbose debug logging.

**Type**: Boolean (`true` or `false`)

**Default**: `false`

**Example**:
```ini
DEBUG_MODE=false
```

---

### LOG_FILE

**Description**: Location of the kiosk log file.

**Type**: String (file path)

**Default**: `/var/log/displayos/kiosk.log`

**Example**:
```ini
LOG_FILE=/var/log/displayos/kiosk.log
```

---

### LOG_ROTATION

**Description**: Log rotation frequency.

**Type**: String (`daily`, `weekly`, `monthly`)

**Default**: `daily`

**Example**:
```ini
LOG_ROTATION=daily
```

---

### LOG_RETENTION

**Description**: Number of log files to keep.

**Type**: Integer

**Default**: `7`

**Example**:
```ini
LOG_RETENTION=7
```

---

## Advanced Browser Options

### CHROMIUM_FLAGS

**Description**: Additional command-line flags for Chromium.

**Type**: String (space-separated flags)

**Default**: (empty)

**Common Flags**:
- `--disable-gpu` - Disable hardware acceleration
- `--disable-software-rasterizer` - Disable software rendering
- `--force-device-scale-factor=1.5` - Scale UI
- `--autoplay-policy=no-user-gesture-required` - Allow autoplay

**Example**:
```ini
CHROMIUM_FLAGS=--disable-gpu --force-device-scale-factor=1.5
```

---

### FIREFOX_FLAGS

**Description**: Additional command-line flags for Firefox.

**Type**: String (space-separated flags)

**Default**: (empty)

**Example**:
```ini
FIREFOX_FLAGS=-safe-mode
```

---

### BROWSER_CACHE_SIZE

**Description**: Browser cache size in megabytes.

**Type**: Integer (0 to disable caching)

**Default**: `100`

**Example**:
```ini
BROWSER_CACHE_SIZE=100
```

---

### CLEAR_BROWSER_DATA

**Description**: Clear browser cache and data on startup.

**Type**: Boolean (`true` or `false`)

**Default**: `false`

**Example**:
```ini
CLEAR_BROWSER_DATA=true
```

---

### USER_AGENT

**Description**: Custom browser user agent string.

**Type**: String or empty (use default)

**Default**: (empty)

**Example**:
```ini
USER_AGENT=DisplayOS/1.0 Chromium
```

---

## Display Power Management

### DPMS_ENABLED

**Description**: Enable display power management (screen blanking).

**Type**: Boolean (`true` or `false`)

**Default**: `false`

**Example**:
```ini
DPMS_ENABLED=true
```

---

### DPMS_TIMEOUT

**Description**: Time in minutes before the screen blanks.

**Type**: Integer (0 to disable)

**Default**: `0`

**Example**:
```ini
DPMS_TIMEOUT=30
```

---

### SCHEDULE_ENABLED

**Description**: Enable scheduled display on/off.

**Type**: Boolean (`true` or `false`)

**Default**: `false`

**Example**:
```ini
SCHEDULE_ENABLED=true
```

---

### SCHEDULE_ON

**Description**: Time to turn the display on (24-hour format).

**Type**: String (HH:MM)

**Default**: `08:00`

**Example**:
```ini
SCHEDULE_ON=08:00
```

---

### SCHEDULE_OFF

**Description**: Time to turn the display off (24-hour format).

**Type**: String (HH:MM)

**Default**: `22:00`

**Example**:
```ini
SCHEDULE_OFF=22:00
```

---

## Example Configuration Files

### Minimal Configuration

```ini
TARGET_URL=https://example.com
BROWSER=chromium
```

### Corporate Signage

```ini
# Corporate digital signage configuration
TARGET_URL=https://signage.company.com/display/lobby

BROWSER=chromium
DISPLAY_MODE=fullscreen

WIFI_SSID=Corporate-WiFi
WIFI_PASSWORD=SecurePassword123
WIFI_SECURITY=WPA-PSK

HOSTNAME=lobby-display-01
TIMEZONE=America/New_York
KEYBOARD_LAYOUT=us

WATCHDOG_TIMEOUT=30
WATCHDOG_ENABLED=true

SHOW_CURSOR=false
VIRTUAL_KEYBOARD=false

SSH_ENABLED=false
AUTO_UPDATES=true
```

### Interactive Kiosk

```ini
# Interactive touchscreen kiosk
TARGET_URL=https://kiosk.example.com

BROWSER=chromium
DISPLAY_MODE=fullscreen
RESOLUTION=1920x1080

STATIC_IP=10.0.1.50/24
STATIC_GATEWAY=10.0.1.1
STATIC_DNS=10.0.1.1

HOSTNAME=info-kiosk-01
TIMEZONE=Europe/Oslo
KEYBOARD_LAYOUT=no

WATCHDOG_TIMEOUT=60
WATCHDOG_ENABLED=true

SHOW_CURSOR=true
CURSOR_HIDE_TIMEOUT=10
VIRTUAL_KEYBOARD=true
VIRTUAL_KEYBOARD_THEME=dark

SSH_ENABLED=true
AUTO_UPDATES=true
DEBUG_MODE=false
```
