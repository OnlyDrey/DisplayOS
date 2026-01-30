# DisplayOS Localization Guide

This guide explains how to configure DisplayOS for different languages, regions, and keyboard layouts.

## Table of Contents

1. [Overview](#overview)
2. [Keyboard Layout Configuration](#keyboard-layout-configuration)
3. [System Locale](#system-locale)
4. [Timezone Configuration](#timezone-configuration)
5. [Norwegian (nb_NO) Setup](#norwegian-nb_no-setup)
6. [Custom Wallpaper](#custom-wallpaper)
7. [Browser Localization](#browser-localization)
8. [Pre-Build Customization](#pre-build-customization)

---

## Overview

DisplayOS supports localization through several configuration options:

- **Keyboard layout**: Physical keyboard mapping
- **System locale**: Language for system messages
- **Timezone**: Local time configuration
- **Browser language**: Web content language preferences

---

## Keyboard Layout Configuration

### Using config.conf

Edit `/etc/displayos/config.conf`:

```ini
KEYBOARD_LAYOUT=no
KEYBOARD_VARIANT=
```

### Common Keyboard Layouts

| Layout Code | Language/Region |
|-------------|-----------------|
| `us` | US English (QWERTY) |
| `gb` | UK English |
| `de` | German (QWERTZ) |
| `fr` | French (AZERTY) |
| `no` | Norwegian |
| `se` | Swedish |
| `dk` | Danish |
| `fi` | Finnish |
| `es` | Spanish |
| `it` | Italian |
| `pt` | Portuguese |
| `br` | Brazilian Portuguese |
| `ru` | Russian |
| `jp` | Japanese |
| `kr` | Korean |
| `cn` | Chinese |
| `ara` | Arabic |

### Layout Variants

Some layouts have variants:

```ini
# US Dvorak
KEYBOARD_LAYOUT=us
KEYBOARD_VARIANT=dvorak

# German Mac keyboard
KEYBOARD_LAYOUT=de
KEYBOARD_VARIANT=mac

# UK Extended (with dead keys)
KEYBOARD_LAYOUT=gb
KEYBOARD_VARIANT=extd
```

### Applying Keyboard Changes

After changing the layout, either:

1. Restart the kiosk:
   ```bash
   sudo systemctl restart displayos-kiosk
   ```

2. Or apply immediately:
   ```bash
   setxkbmap no  # Replace 'no' with your layout code
   ```

### Testing Keyboard Layout

Open a terminal (Ctrl+Alt+T if enabled) and test special characters:

```bash
# For Norwegian: æ ø å Æ Ø Å
# For German: ä ö ü ß Ä Ö Ü
# For French: é è ê ë à â ç
```

---

## System Locale

### Setting the Locale

The system locale affects:
- Date and time formats
- Number formats (decimal separator)
- Currency formats
- Sorting order

### Configuration

Edit the preseed configuration before building (`src/preseed.cfg`):

```ini
d-i debian-installer/locale string nb_NO.UTF-8
d-i debian-installer/language string nb
d-i debian-installer/country string NO
```

### Post-Installation Locale Change

On a running system:

```bash
# Generate the locale
sudo locale-gen nb_NO.UTF-8

# Set as default
sudo update-locale LANG=nb_NO.UTF-8

# Apply immediately
export LANG=nb_NO.UTF-8
```

### Available Locales

List available locales:
```bash
locale -a
```

Generate a new locale:
```bash
sudo dpkg-reconfigure locales
```

---

## Timezone Configuration

### Using config.conf

```ini
TIMEZONE=Europe/Oslo
```

### Common Timezones

| Region | Timezone |
|--------|----------|
| Norway | `Europe/Oslo` |
| UK | `Europe/London` |
| Germany | `Europe/Berlin` |
| France | `Europe/Paris` |
| US East | `America/New_York` |
| US West | `America/Los_Angeles` |
| Japan | `Asia/Tokyo` |
| Australia | `Australia/Sydney` |

### Listing All Timezones

```bash
timedatectl list-timezones
```

### Manual Timezone Change

```bash
sudo timedatectl set-timezone Europe/Oslo
```

---

## Norwegian (nb_NO) Setup

Complete setup for Norwegian localization:

### Configuration File

```ini
# /etc/displayos/config.conf

# Norwegian keyboard
KEYBOARD_LAYOUT=no
KEYBOARD_VARIANT=

# Norwegian timezone
TIMEZONE=Europe/Oslo

# System hostname (optional)
HOSTNAME=skjerm-01
```

### Pre-Build Configuration

Edit `src/preseed.cfg` for the installer:

```ini
# Locale
d-i debian-installer/locale string nb_NO.UTF-8
d-i debian-installer/language string nb
d-i debian-installer/country string NO

# Keyboard
d-i keyboard-configuration/xkb-keymap select no
d-i keyboard-configuration/layoutcode string no

# Timezone
d-i time/zone string Europe/Oslo
```

### Browser Language

For Norwegian web content, add to config:

```ini
# Browser will request Norwegian content
CHROMIUM_FLAGS=--lang=nb-NO
```

### Virtual Keyboard Layout

If using the virtual keyboard with Norwegian:

```bash
# Edit onboard settings
gsettings set org.onboard layout '/usr/share/onboard/layouts/Compact.onboard'
gsettings set org.onboard system-theme-name 'Default'
```

### Norwegian Date Format

Ensure dates display in Norwegian format:

```bash
# In /etc/default/locale
LANG=nb_NO.UTF-8
LC_TIME=nb_NO.UTF-8
```

---

## Custom Wallpaper

### Requirements

- **Format**: PNG or JPG
- **Recommended size**: 1920x1080 (or match your display resolution)
- **Location**: `assets/wallpaper.png` (before build)

### Changing Wallpaper Before Build

1. Create or obtain your wallpaper image
2. Replace `assets/wallpaper.png`
3. Rebuild the ISO

### Changing Wallpaper After Installation

1. Copy your wallpaper:
   ```bash
   sudo cp my-wallpaper.png /usr/share/backgrounds/displayos-wallpaper.png
   ```

2. Update Openbox configuration:
   ```bash
   # Edit autostart
   nano ~/.config/openbox/autostart
   
   # Add line:
   feh --bg-scale /usr/share/backgrounds/displayos-wallpaper.png &
   ```

3. Install feh if not present:
   ```bash
   sudo apt install feh
   ```

### LightDM Background

For the login screen background:

```bash
sudo nano /etc/lightdm/lightdm-gtk-greeter.conf
```

Add or modify:
```ini
[greeter]
background=/usr/share/backgrounds/displayos-wallpaper.png
```

### Using a Solid Color

If you prefer a solid color background:

```bash
# In autostart:
xsetroot -solid "#1a1a2e" &
```

---

## Browser Localization

### Chromium Language

Set browser language via flags:

```ini
CHROMIUM_FLAGS=--lang=nb-NO
```

### Firefox Language

Firefox uses system locale by default. To force a specific language:

1. Create a Firefox policy file:
   ```bash
   sudo mkdir -p /etc/firefox/policies
   sudo nano /etc/firefox/policies/policies.json
   ```

2. Add:
   ```json
   {
     "policies": {
       "RequestedLocales": ["nb-NO", "en-US"]
     }
   }
   ```

### Accept-Language Header

Configure which languages the browser requests from websites:

For Chromium, add to config:
```ini
CHROMIUM_FLAGS=--accept-lang=nb-NO,nb,no,en
```

---

## Pre-Build Customization

### Modifying the Build Script

For comprehensive localization, edit `scripts/build_iso.sh`:

```bash
# In the configure_system function, add:

configure_locale() {
    log STEP "Configuring locale"
    
    local chroot="$BUILD_WORK/chroot"
    
    # Generate Norwegian locale
    chroot "$chroot" sed -i 's/# nb_NO.UTF-8/nb_NO.UTF-8/' /etc/locale.gen
    chroot "$chroot" locale-gen
    
    # Set default locale
    echo 'LANG=nb_NO.UTF-8' > "$chroot/etc/default/locale"
    
    # Set timezone
    chroot "$chroot" ln -sf /usr/share/zoneinfo/Europe/Oslo /etc/localtime
    echo "Europe/Oslo" > "$chroot/etc/timezone"
    
    # Set keyboard
    cat > "$chroot/etc/default/keyboard" << 'EOF'
XKBMODEL="pc105"
XKBLAYOUT="no"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
    
    log INFO "Locale configured for Norwegian (nb_NO)"
}
```

### Default Configuration Template

Modify `config/config.conf` with your preferred defaults:

```ini
# Default to Norwegian settings
KEYBOARD_LAYOUT=no
TIMEZONE=Europe/Oslo
```

---

## Quick Reference

### Norwegian Setup Checklist

- [ ] Set `KEYBOARD_LAYOUT=no` in config.conf
- [ ] Set `TIMEZONE=Europe/Oslo` in config.conf
- [ ] Configure locale in preseed.cfg (for installer)
- [ ] Add `--lang=nb-NO` to CHROMIUM_FLAGS
- [ ] Test special characters: æ ø å Æ Ø Å
- [ ] Verify date format displays correctly
- [ ] Custom wallpaper (optional)

### Keyboard Layout Quick Commands

```bash
# Check current layout
setxkbmap -query

# Change layout temporarily
setxkbmap no

# Change layout with variant
setxkbmap us -variant dvorak

# List available layouts
localectl list-x11-keymap-layouts
```

### Locale Quick Commands

```bash
# Check current locale
locale

# List available locales
locale -a

# Generate new locale
sudo locale-gen nb_NO.UTF-8

# Set system locale
sudo update-locale LANG=nb_NO.UTF-8
```

### Timezone Quick Commands

```bash
# Check current timezone
timedatectl

# List timezones
timedatectl list-timezones | grep Europe

# Set timezone
sudo timedatectl set-timezone Europe/Oslo
```
