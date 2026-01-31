#!/bin/bash
# =============================================================================
# DisplayOS ISO Build Script
# =============================================================================
# 
# This script creates a bootable DisplayOS ISO image
# 
# Usage:
#   sudo ./build_iso.sh [options]
#
# Options:
#   --arch=ARCH       Target architecture: amd64 (default) or arm64
#   --output=DIR      Output directory (default: ./output)
#   --clean           Clean build directory before starting
#   --debug           Enable debug mode (verbose output)
#   --no-luks         Disable LUKS encryption in installer
#   --skip-security   Skip security hardening (for testing/development)
#   --disable-ssh     Disable SSH on built ISO (enabled by default)
#   --help            Show this help message
#
# Requirements:
#   - Debian-based build system (Debian 12 Bookworm recommended)
#   - Root/sudo access
#   - Internet connection
#   - ~10GB free disk space
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Script metadata
readonly SCRIPT_NAME="DisplayOS Build Script"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Build configuration
BUILD_ARCH="amd64"
BUILD_OUTPUT="$PROJECT_ROOT/output"
BUILD_WORK="$PROJECT_ROOT/build"
BUILD_CLEAN=false
BUILD_DEBUG=false
ENABLE_LUKS=true
SKIP_SECURITY=false
ENABLE_SSH_ISO=true
APT_NO_RECOMMENDS=true

# Debian configuration
readonly DEBIAN_VERSION="bookworm"
readonly DEBIAN_MIRROR="https://deb.debian.org/debian"

# ISO configuration
readonly ISO_LABEL="DISPLAYOS"
readonly ISO_PUBLISHER="DisplayOS Project"
readonly ISO_VOLUME="DisplayOS Live"

# Log file - use ./build folder for output
LOG_FILE="$PROJECT_ROOT/build/displayos-build.log"

# =============================================================================
# COLORS AND FORMATTING
# =============================================================================

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly BOLD=''
    readonly NC=''
fi

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_init() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "========================================" >> "$LOG_FILE"
    echo "DisplayOS Build Log - $(date)" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Output to terminal based on level
    case "$level" in
        INFO)
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        DEBUG)
            if [[ "$BUILD_DEBUG" == true ]]; then
                echo -e "${BLUE}[DEBUG]${NC} $message"
            fi
            ;;
        STEP)
            echo -e "\n${BOLD}${BLUE}==> $message${NC}"
            ;;
    esac
}

# Function to log command output
log_output() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOG_FILE"
}

# Function to run commands and suppress terminal output, logging to file
run_quiet() {
    local cmd="$*"
    if [[ "$BUILD_DEBUG" == true ]]; then
        eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
    else
        eval "$cmd" >> "$LOG_FILE" 2>&1
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

show_help() {
    cat << EOF
${BOLD}$SCRIPT_NAME v$SCRIPT_VERSION${NC}

Build a bootable DisplayOS ISO image.

${BOLD}Usage:${NC}
    sudo $0 [options]

${BOLD}Options:${NC}
    --arch=ARCH       Target architecture: amd64 (default) or arm64
    --output=DIR      Output directory (default: ./output)
    --clean           Clean build directory before starting
    --debug           Enable debug mode (verbose output)
    --no-luks         Disable LUKS encryption in installer
    --skip-security   Skip security hardening (for testing/development)
    --disable-ssh     Disable SSH on built ISO (enabled by default)
    --help            Show this help message

${BOLD}Examples:${NC}
    sudo $0                          # Build amd64 ISO with security hardening (SSH enabled)
    sudo $0 --arch=arm64             # Build ARM64 ISO
    sudo $0 --clean --debug          # Clean build with debug output
    sudo $0 --disable-ssh            # Build with SSH disabled
    sudo $0 --skip-security          # Build without security hardening

${BOLD}Requirements:${NC}
    - Debian-based build system (Debian 12 Bookworm recommended)
    - Root/sudo access
    - Internet connection
    - ~10GB free disk space
EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This script must be run as root"
        echo "Try: sudo $0 $*"
        exit 1
    fi
}

check_dependencies() {
    log STEP "Checking build dependencies"

    local deps=(
        git
        wget
        curl
        debootstrap
        squashfs-tools
        xorriso
        isolinux
        syslinux-common
        grub-pc-bin
        grub-efi-amd64-bin
        mtools
        dosfstools
        rsync
        wget
        curl
    )

    local missing=()

    for dep in "${deps[@]}"; do
        if ! dpkg -l "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log INFO "Installing missing dependencies: ${missing[*]}"
        apt-get update >> "$LOG_FILE" 2>&1
        apt-get install -y "${missing[@]}" >> "$LOG_FILE" 2>&1
    fi

    log INFO "All dependencies satisfied"
}

cleanup() {
    # Unmount any mounted filesystems (redirect to log)
    if mountpoint -q "$BUILD_WORK/chroot/proc" 2>/dev/null; then
        umount -lf "$BUILD_WORK/chroot/proc" >> "$LOG_FILE" 2>&1 || true
    fi
    if mountpoint -q "$BUILD_WORK/chroot/sys" 2>/dev/null; then
        umount -lf "$BUILD_WORK/chroot/sys" >> "$LOG_FILE" 2>&1 || true
    fi
    if mountpoint -q "$BUILD_WORK/chroot/dev/pts" 2>/dev/null; then
        umount -lf "$BUILD_WORK/chroot/dev/pts" >> "$LOG_FILE" 2>&1 || true
    fi
    if mountpoint -q "$BUILD_WORK/chroot/dev" 2>/dev/null; then
        umount -lf "$BUILD_WORK/chroot/dev" >> "$LOG_FILE" 2>&1 || true
    fi
}

trap cleanup EXIT

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

prepare_build_environment() {
    log STEP "Preparing build environment"
    
    if [[ "$BUILD_CLEAN" == true ]] && [[ -d "$BUILD_WORK" ]]; then
        log INFO "Cleaning previous build directory"
        rm -rf "$BUILD_WORK"
    fi
    
    # Create directories
    mkdir -p "$BUILD_WORK"/{chroot,image/{live,isolinux,boot/grub},scratch}
    mkdir -p "$BUILD_OUTPUT"
    
    log INFO "Build directories created"
}

bootstrap_debian() {
    log STEP "Bootstrapping Debian $DEBIAN_VERSION ($BUILD_ARCH)"

    if [[ -f "$BUILD_WORK/chroot/etc/debian_version" ]]; then
        log INFO "Chroot already exists, skipping bootstrap"
        return
    fi

    # Redirect all debootstrap output to log file only
    debootstrap \
        --arch="$BUILD_ARCH" \
        --variant=minbase \
        --components=main,contrib,non-free,non-free-firmware \
        "$DEBIAN_VERSION" \
        "$BUILD_WORK/chroot" \
        "$DEBIAN_MIRROR" >> "$LOG_FILE" 2>&1

    log INFO "Bootstrap complete"
}

configure_chroot() {
    log STEP "Configuring chroot environment"

    # Mount necessary filesystems
    mount --bind /dev "$BUILD_WORK/chroot/dev"
    mount --bind /dev/pts "$BUILD_WORK/chroot/dev/pts"
    mount -t proc proc "$BUILD_WORK/chroot/proc"
    mount -t sysfs sysfs "$BUILD_WORK/chroot/sys"

    # Configure hostname
    echo "displayos" > "$BUILD_WORK/chroot/etc/hostname"

    # Configure hosts
    cat > "$BUILD_WORK/chroot/etc/hosts" << EOF
127.0.0.1       localhost
127.0.1.1       displayos

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

    # Configure apt sources
    cat > "$BUILD_WORK/chroot/etc/apt/sources.list" << EOF
deb $DEBIAN_MIRROR $DEBIAN_VERSION main contrib non-free non-free-firmware
deb $DEBIAN_MIRROR $DEBIAN_VERSION-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $DEBIAN_VERSION-security main contrib non-free non-free-firmware
EOF

    log INFO "Chroot configuration complete"
}

install_packages() {
    log STEP "Installing packages"

    # Copy package list to chroot
    cp "$PROJECT_ROOT/src/packages.list" "$BUILD_WORK/chroot/tmp/"

    # Create APT configuration to optimize installation
    cat > "$BUILD_WORK/chroot/etc/apt/apt.conf.d/99-displayos-optimize" << 'APTCONF'
// Reduce packages and I/O load
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::Get::AutomaticRemove "true";
APT::Get::Purge "true";
APT::Get::AllowUnauthenticated "true";

// Fix broken packages and resolve conflicts
APT::Fix-Missing "true";
APT::Aptitude::ProblemResolver::SolutionCost "100*canceled-actions,200*removals";

// Faster, less verbose output
quiet "1";
APTCONF

    # Create installation script with locale fixes and proper error handling
    cat > "$BUILD_WORK/chroot/tmp/install_packages.sh" << 'SCRIPT'
#!/bin/bash
set -e

# Suppress normal apt output but show warnings and errors
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Single apt-get update (most efficient)
echo "[$(date '+%H:%M:%S')] Updating package lists..." >&2
apt-get update 2>&1 | grep -E "(^Get:|^Err:|error|E:)" | tee /tmp/apt-update.log || true

# Ensure /boot directory exists with proper permissions
mkdir -p /boot
chmod 755 /boot

# Check if linux-image-amd64 is available
echo "[$(date '+%H:%M:%S')] Checking kernel package availability..." >&2
if apt-cache search linux-image-amd64 | grep -q "^linux-image-amd64"; then
    echo "[$(date '+%H:%M:%S')] ✓ linux-image-amd64 package found" >&2
else
    echo "[$(date '+%H:%M:%S')] WARNING: linux-image-amd64 not found in repositories" >&2
    echo "[$(date '+%H:%M:%S')] Available linux-image packages:" >&2
    apt-cache search "^linux-image-" | head -10 >&2
fi

# Get package list - ensure proper whitespace handling
PACKAGE_COUNT=$(grep -v '^#' /tmp/packages.list | grep -v '^$' | wc -l)
echo "[$(date '+%H:%M:%S')] Found $PACKAGE_COUNT packages to install..." >&2

# Read all packages into array (safer than passing as string)
declare -a PACKAGES_ARRAY
while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && PACKAGES_ARRAY+=("$pkg")
done < <(grep -v '^#' /tmp/packages.list | grep -v '^$')

echo "[$(date '+%H:%M:%S')] Packages to install: $(echo ${PACKAGES_ARRAY[@]} | tr ' ' '\n' | grep -c .)" >&2

# Install kernel package FIRST and explicitly
echo "[$(date '+%H:%M:%S')] Installing kernel package (linux-image-amd64)..." >&2
if apt-get install -y linux-image-amd64 2>&1 | tee -a /tmp/apt-install.log; then
    echo "[$(date '+%H:%M:%S')] ✓ Kernel package installed" >&2
else
    echo "[$(date '+%H:%M:%S')] ERROR: Kernel package installation failed!" >&2
    echo "[$(date '+%H:%M:%S')] Trying alternative: linux-image-686-pae..." >&2
    apt-get install -y linux-image-686-pae 2>&1 | tee -a /tmp/apt-install.log || \
    apt-get install -y linux-image-generic 2>&1 | tee -a /tmp/apt-install.log || true
fi

# Now install all other packages at once (excluding kernel packages already handled)
echo "[$(date '+%H:%M:%S')] Installing remaining $PACKAGE_COUNT packages (this may take 10-15 minutes)..." >&2
# Filter out kernel packages as they were handled separately
declare -a FILTERED_PACKAGES
for pkg in "${PACKAGES_ARRAY[@]}"; do
    if [[ ! "$pkg" =~ linux-image|linux-headers ]]; then
        FILTERED_PACKAGES+=("$pkg")
    fi
done

# First attempt: normal installation
if ! apt-get install -y -qq --no-install-recommends --no-install-suggests "${FILTERED_PACKAGES[@]}" 2>&1 | tee -a /tmp/apt-install.log; then
    echo "[$(date '+%H:%M:%S')] Warning: Package installation failed with broken dependencies" >&2
    echo "[$(date '+%H:%M:%S')] Attempting to fix broken dependencies (apt-get install -f)..." >&2
    if ! apt-get install -f -y -qq 2>&1 | tee -a /tmp/apt-install.log; then
        echo "[$(date '+%H:%M:%S')] Attempting more aggressive fix (apt-get dist-upgrade)..." >&2
        apt-get dist-upgrade -y -qq 2>&1 | tee -a /tmp/apt-install.log || true
    fi

    # Retry the original failed packages
    echo "[$(date '+%H:%M:%S')] Retrying failed packages..." >&2
    apt-get install -y -qq --no-install-recommends --no-install-suggests "${FILTERED_PACKAGES[@]}" 2>&1 | tee -a /tmp/apt-install.log || true
fi

# Generate locales AFTER packages are installed
echo "[$(date '+%H:%M:%S')] Generating locales..." >&2
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen 2>&1 | tee -a /tmp/apt-install.log || true
update-locale LANG=C.UTF-8 2>&1 | tee -a /tmp/apt-install.log || true

# Verify kernel was installed - CRITICAL CHECK
if [[ -f /boot/vmlinuz-* ]]; then
    KERNEL_FILE=$(ls -1 /boot/vmlinuz-* 2>/dev/null | head -1)
    echo "[$(date '+%H:%M:%S')] ✓ Found kernel: $KERNEL_FILE" >&2
else
    echo "[$(date '+%H:%M:%S')] FATAL: No kernel found in /boot directory" >&2
    echo "[$(date '+%H:%M:%S')] Checking installed kernel packages:" >&2
    dpkg -l | grep linux-image || echo "No linux-image packages installed" >&2
    echo "[$(date '+%H:%M:%S')] Available kernel packages:" >&2
    apt-cache search "^linux-image-" | head -15 >&2
    echo "[$(date '+%H:%M:%S')] ERROR: Kernel installation failed - cannot continue" >&2
    exit 1
fi

# Verify initramfs-tools is available
if command -v update-initramfs &>/dev/null; then
    echo "[$(date '+%H:%M:%S')] ✓ initramfs-tools found" >&2
else
    echo "[$(date '+%H:%M:%S')] WARNING: update-initramfs not found, initramfs-tools may not be installed" >&2
fi

# Generate initramfs for all installed kernels
echo "[$(date '+%H:%M:%S')] Generating initramfs..." >&2
update-initramfs -c -k all 2>&1 | tee -a /tmp/apt-install.log || true

# List what's in /boot after everything
echo "[$(date '+%H:%M:%S')] Boot directory contents:" >&2
ls -lh /boot/ 2>&1 | tee -a /tmp/apt-install.log || true

# Clean up package cache
echo "[$(date '+%H:%M:%S')] Cleaning up..." >&2
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[$(date '+%H:%M:%S')] Package installation complete" >&2
SCRIPT

    chmod +x "$BUILD_WORK/chroot/tmp/install_packages.sh"
    # Run installation and capture exit code to a temp file (outside chroot)
    local install_output="$BUILD_WORK/install_output.txt"
    chroot "$BUILD_WORK/chroot" /tmp/install_packages.sh > "$install_output" 2>&1
    local install_exit_code=$?

    # Display output with filtering
    while IFS= read -r line; do
        # Log everything to file
        echo "$line" >> "$LOG_FILE"

        # Show progress messages in terminal
        if [[ "$line" =~ \[.*\]\ (Updating|Installing|Generating|Cleaning|Package\ installation|complete|ERROR|FATAL|Kernel) ]]; then
            echo -e "${GREEN}[INST]${NC} $line"
        fi
    done < "$install_output"

    if [[ $install_exit_code -ne 0 ]]; then
        log ERROR "Package installation failed with exit code $install_exit_code"
        log ERROR "Full installation log:"
        cat "$install_output" >> "$LOG_FILE"
        return 1
    fi

    log INFO "Package installation complete"
}

configure_system() {
    log STEP "Configuring DisplayOS system"

    local chroot="$BUILD_WORK/chroot"

    # Create displayos user (only add groups that exist)
    chroot "$chroot" useradd -m -s /bin/bash -G sudo,audio,video displayos >> "$LOG_FILE" 2>&1 || true

    # Set password directly using usermod instead of chpasswd (PAM-independent)
    echo "displayos:displayos" | chroot "$chroot" chpasswd -c SHA512 >> "$LOG_FILE" 2>&1 || true
    
    # Create DisplayOS directories
    mkdir -p "$chroot/etc/displayos"
    mkdir -p "$chroot/var/log/displayos"
    mkdir -p "$chroot/usr/local/bin"
    
    # Copy configuration
    cp "$PROJECT_ROOT/config/config.conf" "$chroot/etc/displayos/"
    chmod 600 "$chroot/etc/displayos/config.conf"
    chown root:root "$chroot/etc/displayos/config.conf"
    
    # Copy systemd services
    cp "$PROJECT_ROOT/config/systemd/"*.service "$chroot/etc/systemd/system/"
    
    # Copy and install scripts
    install_displayos_scripts "$chroot"
    
    # Configure autologin
    configure_autologin "$chroot"
    
    # Configure Openbox for kiosk
    configure_openbox "$chroot"
    
    # Enable services (redirect to log, suppress systemd warnings in chroot)
    chroot "$chroot" systemctl enable displayos-kiosk.service >> "$LOG_FILE" 2>&1 || true
    chroot "$chroot" systemctl enable displayos-watchdog.service >> "$LOG_FILE" 2>&1 || true
    chroot "$chroot" systemctl enable displayos-shortcuts.service >> "$LOG_FILE" 2>&1 || true
    chroot "$chroot" systemctl enable NetworkManager.service >> "$LOG_FILE" 2>&1 || true

    log INFO "System configuration complete"
}

install_displayos_scripts() {
    local chroot="$1"
    
    # Browser start script
    cat > "$chroot/usr/local/bin/displayos-start-browser" << 'SCRIPT'
#!/bin/bash
# DisplayOS Browser Start Script

source /etc/displayos/config.conf

# Wait for X server
while ! xdpyinfo >/dev/null 2>&1; do
    sleep 1
done

# Configure display
if [[ -n "$RESOLUTION" ]]; then
    xrandr -s "$RESOLUTION" || true
fi

# Hide cursor if configured
if [[ "$SHOW_CURSOR" == "false" ]]; then
    unclutter -idle 0.1 -root &
elif [[ "$CURSOR_HIDE_TIMEOUT" -gt 0 ]]; then
    unclutter -idle "$CURSOR_HIDE_TIMEOUT" -root &
fi

# Build browser arguments
if [[ "$BROWSER" == "chromium" ]]; then
    BROWSER_CMD="chromium"
    BROWSER_ARGS=(
        --kiosk
        --incognito
        --no-first-run
        --disable-infobars
        --disable-session-crashed-bubble
        --disable-restore-session-state
        --disable-translate
        --noerrdialogs
        --disable-features=TranslateUI
        --check-for-update-interval=31536000
        --disable-pinch
        --overscroll-history-navigation=0
    )
    
    if [[ -n "$CHROMIUM_FLAGS" ]]; then
        BROWSER_ARGS+=($CHROMIUM_FLAGS)
    fi
    
    if [[ "$DISPLAY_MODE" != "fullscreen" ]]; then
        # Remove --kiosk for windowed mode
        BROWSER_ARGS=("${BROWSER_ARGS[@]/--kiosk/}")
    fi
else
    BROWSER_CMD="firefox-esr"
    BROWSER_ARGS=(
        --kiosk
        --private-window
    )
    
    if [[ -n "$FIREFOX_FLAGS" ]]; then
        BROWSER_ARGS+=($FIREFOX_FLAGS)
    fi
fi

# Clear browser data if configured
if [[ "$CLEAR_BROWSER_DATA" == "true" ]]; then
    rm -rf /home/displayos/.cache/chromium
    rm -rf /home/displayos/.mozilla/firefox
fi

# Log startup
echo "$(date): Starting $BROWSER_CMD with URL: $TARGET_URL" >> /var/log/displayos/kiosk.log

# Start browser
exec $BROWSER_CMD "${BROWSER_ARGS[@]}" "$TARGET_URL"
SCRIPT
    chmod +x "$chroot/usr/local/bin/displayos-start-browser"
    
    # Watchdog script
    cat > "$chroot/usr/local/bin/displayos-watchdog" << 'SCRIPT'
#!/bin/bash
# DisplayOS Watchdog Script

source /etc/displayos/config.conf

TIMEOUT="${WATCHDOG_TIMEOUT:-30}"
MAX_RESTARTS="${WATCHDOG_MAX_RESTARTS:-0}"
RESTART_DELAY="${WATCHDOG_RESTART_DELAY:-5}"
RESTART_COUNT=0

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*"
}

check_browser() {
    if [[ "$BROWSER" == "chromium" ]]; then
        pgrep -x chromium >/dev/null
    else
        pgrep -x firefox-esr >/dev/null
    fi
}

restart_browser() {
    log "Browser not responding, restarting..."
    
    # Kill existing browser processes
    pkill -9 chromium || true
    pkill -9 firefox-esr || true
    
    sleep "$RESTART_DELAY"
    
    # Restart the kiosk service
    systemctl restart displayos-kiosk
    
    ((RESTART_COUNT++))
    log "Browser restarted (attempt $RESTART_COUNT)"
}

# Main watchdog loop
log "Watchdog started with timeout: ${TIMEOUT}s"

while true; do
    if [[ "$WATCHDOG_ENABLED" != "true" ]]; then
        log "Watchdog disabled, sleeping..."
        sleep 60
        continue
    fi
    
    if ! check_browser; then
        if [[ "$MAX_RESTARTS" -eq 0 ]] || [[ "$RESTART_COUNT" -lt "$MAX_RESTARTS" ]]; then
            restart_browser
        else
            log "Maximum restart attempts ($MAX_RESTARTS) reached, giving up"
            exit 1
        fi
    fi
    
    sleep "$TIMEOUT"
done
SCRIPT
    chmod +x "$chroot/usr/local/bin/displayos-watchdog"
    
    # Keyboard shortcuts script
    cat > "$chroot/usr/local/bin/displayos-shortcuts" << 'SCRIPT'
#!/bin/bash
# DisplayOS Keyboard Shortcuts Handler

source /etc/displayos/config.conf

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> /var/log/displayos/shortcuts.log
}

# This script sets up keyboard bindings using xbindkeys
# The actual bindings are defined in the Openbox configuration

# Keep the service running
log "Shortcuts handler started"

# Monitor for virtual keyboard toggle
while true; do
    sleep 3600
done
SCRIPT
    chmod +x "$chroot/usr/local/bin/displayos-shortcuts"
    
    # Config loader script
    cat > "$chroot/usr/local/bin/displayos-load-config" << 'SCRIPT'
#!/bin/bash
# DisplayOS Configuration Loader

CONFIG_FILE="/etc/displayos/config.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Validate configuration
source "$CONFIG_FILE"

if [[ -z "$TARGET_URL" ]]; then
    echo "ERROR: TARGET_URL not set in configuration"
    exit 1
fi

# Apply WiFi configuration if set
if [[ -n "$WIFI_SSID" ]] && [[ -n "$WIFI_PASSWORD" ]]; then
    nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" || true
fi

echo "Configuration loaded successfully"
exit 0
SCRIPT
    chmod +x "$chroot/usr/local/bin/displayos-load-config"
}

configure_autologin() {
    local chroot="$1"
    
    # Configure LightDM for autologin
    mkdir -p "$chroot/etc/lightdm/lightdm.conf.d"
    cat > "$chroot/etc/lightdm/lightdm.conf.d/50-displayos.conf" << EOF
[Seat:*]
autologin-user=displayos
autologin-user-timeout=0
user-session=openbox
EOF
}

configure_openbox() {
    local chroot="$1"
    
    # Create Openbox config directory
    mkdir -p "$chroot/home/displayos/.config/openbox"
    
    # Openbox autostart (starts the kiosk browser)
    cat > "$chroot/home/displayos/.config/openbox/autostart" << 'EOF'
# DisplayOS Openbox Autostart

# Disable screen saver and power management
xset s off
xset -dpms
xset s noblank

# Start network manager applet
nm-applet &

# Start virtual keyboard daemon (if enabled)
if grep -q "VIRTUAL_KEYBOARD=true" /etc/displayos/config.conf; then
    onboard --size=800x200 &
fi

# The kiosk browser is started by systemd service
EOF
    
    # Openbox keyboard shortcuts (rc.xml)
    cat > "$chroot/home/displayos/.config/openbox/rc.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
    <!-- F5: Reload browser -->
    <keybind key="F5">
      <action name="Execute">
        <command>xdotool key --window $(xdotool search --name "Chromium" | head -1) F5</command>
      </action>
    </keybind>
    
    <!-- Ctrl+Alt+Del: Exit kiosk mode -->
    <keybind key="C-A-Delete">
      <action name="Execute">
        <command>/usr/local/bin/displayos-exit-kiosk</command>
      </action>
    </keybind>
    
    <!-- Ctrl+Alt+K: Toggle virtual keyboard -->
    <keybind key="C-A-k">
      <action name="Execute">
        <command>dbus-send --type=method_call --dest=org.onboard.Onboard /org/onboard/Onboard/Keyboard org.onboard.Onboard.Keyboard.ToggleVisible</command>
      </action>
    </keybind>
    
    <!-- Ctrl+Alt+W: Open Network Manager -->
    <keybind key="C-A-w">
      <action name="Execute">
        <command>nm-connection-editor</command>
      </action>
    </keybind>
  </keyboard>
  
  <applications>
    <!-- Make browsers fullscreen -->
    <application class="Chromium*">
      <fullscreen>yes</fullscreen>
      <decor>no</decor>
    </application>
    <application class="Firefox*">
      <fullscreen>yes</fullscreen>
      <decor>no</decor>
    </application>
  </applications>
</openbox_config>
EOF
    
    # Exit kiosk script
    cat > "$chroot/usr/local/bin/displayos-exit-kiosk" << 'SCRIPT'
#!/bin/bash
# DisplayOS Exit Kiosk Mode

source /etc/displayos/config.conf

# Show password dialog
PASSWORD=$(zenity --password --title="Exit Kiosk Mode" 2>/dev/null)

if [[ -z "$PASSWORD" ]]; then
    exit 0
fi

# Verify password (simplified check - in production use proper PAM)
# This checks against the displayos user password
if echo "$PASSWORD" | su -c "exit" displayos 2>/dev/null; then
    # Kill kiosk browser
    systemctl stop displayos-kiosk
    
    # Start a terminal for administration
    xterm &
else
    zenity --error --text="Invalid password" 2>/dev/null
fi
SCRIPT
    chmod +x "$chroot/usr/local/bin/displayos-exit-kiosk"
    
    # Set ownership
    chroot "$chroot" chown -R displayos:displayos /home/displayos >> "$LOG_FILE" 2>&1
}

configure_security() {
    if [[ "$SKIP_SECURITY" == true ]]; then
        log STEP "Skipping security hardening (--skip-security flag set)"
        return
    fi

    log STEP "Applying security hardening"

    local chroot="$BUILD_WORK/chroot"

    # Copy and run security setup script
    cp "$PROJECT_ROOT/scripts/setup_security.sh" "$chroot/tmp/"
    chmod +x "$chroot/tmp/setup_security.sh"

    # Build security setup command with options
    local security_cmd="/tmp/setup_security.sh"
    if [[ "$ENABLE_SSH_ISO" == true ]]; then
        security_cmd="$security_cmd --enable-ssh"
    fi

    # Redirect all security setup output to log file
    chroot "$chroot" $security_cmd >> "$LOG_FILE" 2>&1

    log INFO "Security hardening complete"
}

create_live_image() {
    log STEP "Creating live image"

    local chroot="$BUILD_WORK/chroot"
    local image="$BUILD_WORK/image"

    # Unmount chroot filesystems
    umount -lf "$chroot/proc" >> "$LOG_FILE" 2>&1 || true
    umount -lf "$chroot/sys" >> "$LOG_FILE" 2>&1 || true
    umount -lf "$chroot/dev/pts" >> "$LOG_FILE" 2>&1 || true
    umount -lf "$chroot/dev" >> "$LOG_FILE" 2>&1 || true

    # Create squashfs filesystem (redirect to log)
    log INFO "Creating squashfs filesystem..."
    mksquashfs "$chroot" "$image/live/filesystem.squashfs" \
        -comp xz \
        -e boot \
        -noappend >> "$LOG_FILE" 2>&1

    # Copy kernel and initrd with proper error handling
    log INFO "Extracting kernel and initramfs..."

    # Find and copy kernel
    if [[ -f "$chroot/boot/vmlinuz-"* ]]; then
        cp "$chroot/boot/vmlinuz-"* "$image/live/vmlinuz" >> "$LOG_FILE" 2>&1 || log ERROR "Failed to copy kernel"
    else
        log ERROR "No kernel found in chroot /boot directory"
        log ERROR "Available files in /boot:"
        ls -la "$chroot/boot/" >> "$LOG_FILE" 2>&1 || true
        log ERROR "Checking if linux-image-amd64 was installed:"
        chroot "$chroot" dpkg -l | grep linux-image >> "$LOG_FILE" 2>&1 || true
        return 1
    fi

    # Find and copy initrd
    if [[ -f "$chroot/boot/initrd.img-"* ]]; then
        cp "$chroot/boot/initrd.img-"* "$image/live/initrd" >> "$LOG_FILE" 2>&1 || log ERROR "Failed to copy initramfs"
    else
        log ERROR "No initramfs found in chroot /boot directory"
        log ERROR "Available files in /boot:"
        ls -la "$chroot/boot/" >> "$LOG_FILE" 2>&1 || true
        return 1
    fi

    log INFO "Live image created"
}

configure_bootloader() {
    log STEP "Configuring bootloaders"
    
    local image="$BUILD_WORK/image"
    
    # ISOLINUX configuration (Legacy BIOS)
    cat > "$image/isolinux/isolinux.cfg" << EOF
UI vesamenu.c32
MENU TITLE DisplayOS Boot Menu
DEFAULT live
TIMEOUT 50
MENU RESOLUTION 1024 768

LABEL live
    MENU LABEL ^Start DisplayOS (Live Mode)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live components quiet splash

LABEL live-safe
    MENU LABEL Start DisplayOS (Safe Mode)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live components nomodeset

LABEL install
    MENU LABEL ^Install DisplayOS
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live components installer quiet

LABEL memtest
    MENU LABEL Memory Test
    KERNEL /isolinux/memtest86+
EOF
    
    # Copy ISOLINUX files
    if ! cp /usr/lib/ISOLINUX/isolinux.bin "$image/isolinux/" >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to copy isolinux.bin - is syslinux package installed?"
        return 1
    fi
    if ! cp /usr/lib/syslinux/modules/bios/{ldlinux.c32,vesamenu.c32,libcom32.c32,libutil.c32} "$image/isolinux/" >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to copy syslinux modules - is syslinux-common package installed?"
        return 1
    fi
    
    # GRUB configuration (UEFI)
    cat > "$image/boot/grub/grub.cfg" << EOF
set default=0
set timeout=5

menuentry "Start DisplayOS (Live Mode)" {
    linux /live/vmlinuz boot=live components quiet splash
    initrd /live/initrd
}

menuentry "Start DisplayOS (Safe Mode)" {
    linux /live/vmlinuz boot=live components nomodeset
    initrd /live/initrd
}

menuentry "Install DisplayOS" {
    linux /live/vmlinuz boot=live components installer quiet
    initrd /live/initrd
}
EOF
    
    # Create EFI boot image
    log INFO "Creating EFI boot image..."
    mkdir -p "$image/EFI/boot"

    if ! grub-mkimage \
        -o "$image/EFI/boot/bootx64.efi" \
        -O x86_64-efi \
        -p /boot/grub \
        part_gpt part_msdos fat iso9660 normal boot linux configfile \
        loopback chain efifwsetup efi_gop efi_uga ls search \
        search_label search_fs_uuid search_fs_file gfxterm gfxmenu \
        gfxterm_background gfxterm_menu test all_video loadenv exfat ext2 >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to create EFI boot image"
        return 1
    fi
    
    # Create EFI System Partition image
    truncate -s 10M "$BUILD_WORK/scratch/efi.img" || log ERROR "Failed to create EFI image file"
    if ! mkfs.vfat -F 12 "$BUILD_WORK/scratch/efi.img" >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to format EFI image"
        return 1
    fi
    if ! mmd -i "$BUILD_WORK/scratch/efi.img" ::/EFI >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to create EFI directory structure"
        return 1
    fi
    if ! mmd -i "$BUILD_WORK/scratch/efi.img" ::/EFI/boot >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to create EFI/boot directory"
        return 1
    fi
    if ! mcopy -i "$BUILD_WORK/scratch/efi.img" "$image/EFI/boot/bootx64.efi" ::/EFI/boot/ >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to copy bootx64.efi to EFI image"
        return 1
    fi
    
    log INFO "Bootloader configuration complete"
}

create_iso() {
    log STEP "Creating ISO image"

    local image="$BUILD_WORK/image"
    local iso_file="$BUILD_OUTPUT/displayos-${BUILD_ARCH}.iso"

    # Redirect xorriso output to log
    if ! xorriso \
        -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "$ISO_LABEL" \
        -publisher "$ISO_PUBLISHER" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -eltorito-alt-boot \
        -e --interval:appended_partition_2:all:: \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -append_partition 2 0xef "$BUILD_WORK/scratch/efi.img" \
        -output "$iso_file" \
        "$image" >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to create ISO with xorriso"
        return 1
    fi

    # Verify ISO was created
    if [[ ! -f "$iso_file" ]]; then
        log ERROR "ISO file was not created: $iso_file"
        return 1
    fi

    # Calculate checksum
    log INFO "Calculating checksums..."
    cd "$BUILD_OUTPUT"
    if ! sha256sum "displayos-${BUILD_ARCH}.iso" > "displayos-${BUILD_ARCH}.iso.sha256" 2>&1; then
        log ERROR "Failed to calculate SHA256 checksum"
        return 1
    fi
    if ! md5sum "displayos-${BUILD_ARCH}.iso" > "displayos-${BUILD_ARCH}.iso.md5" 2>&1; then
        log ERROR "Failed to calculate MD5 checksum"
        return 1
    fi

    log INFO "ISO created: $iso_file"
    log INFO "Size: $(du -h "$iso_file" | cut -f1)"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --arch=*)
                BUILD_ARCH="${1#*=}"
                ;;
            --output=*)
                BUILD_OUTPUT="${1#*=}"
                ;;
            --clean)
                BUILD_CLEAN=true
                ;;
            --debug)
                BUILD_DEBUG=true
                ;;
            --no-luks)
                ENABLE_LUKS=false
                ;;
            --skip-security)
                SKIP_SECURITY=true
                ;;
            --disable-ssh)
                ENABLE_SSH_ISO=false
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done

    # Validate architecture
    if [[ "$BUILD_ARCH" != "amd64" ]] && [[ "$BUILD_ARCH" != "arm64" ]]; then
        echo "ERROR: Invalid architecture: $BUILD_ARCH (must be amd64 or arm64)"
        exit 1
    fi

    # Create build directory and initialize logging
    mkdir -p "$BUILD_WORK" "$BUILD_OUTPUT"
    log_init
    check_root "$@"

    echo -e "\n${BOLD}========================================${NC}"
    echo -e "${BOLD}  DisplayOS Build Script v$SCRIPT_VERSION${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo -e "Architecture: ${GREEN}$BUILD_ARCH${NC}"
    echo -e "Output: ${GREEN}$BUILD_OUTPUT${NC}"
    echo -e "Log: ${GREEN}$LOG_FILE${NC}"
    if [[ "$SKIP_SECURITY" == true ]]; then
        echo -e "Security: ${YELLOW}DISABLED (--skip-security)${NC}"
    else
        echo -e "Security: ${GREEN}Enabled${NC}"
    fi
    if [[ "$ENABLE_SSH_ISO" == true ]]; then
        echo -e "SSH on ISO: ${GREEN}ENABLED (default)${NC}"
    else
        echo -e "SSH on ISO: ${YELLOW}DISABLED (--disable-ssh)${NC}"
    fi
    echo -e ""
    
    # Run build steps
    check_dependencies
    prepare_build_environment
    bootstrap_debian
    configure_chroot
    install_packages
    configure_system
    configure_security
    create_live_image
    configure_bootloader
    create_iso
    
    log STEP "Build completed successfully"
    echo -e ""
    echo -e "${GREEN}${BOLD}✓ Build completed successfully!${NC}"
    echo -e ""
    echo -e "ISO created: ${BOLD}$BUILD_OUTPUT/displayos-${BUILD_ARCH}.iso${NC}"
    echo -e "ISO size: ${BOLD}$(du -h "$BUILD_OUTPUT/displayos-${BUILD_ARCH}.iso" 2>/dev/null | cut -f1 || echo "N/A")${NC}"
    echo -e "Checksums: ${BOLD}$BUILD_OUTPUT/displayos-${BUILD_ARCH}.iso.{sha256,md5}${NC}"
    echo -e "Full log: ${BOLD}$LOG_FILE${NC}"
    echo -e ""
}

main "$@"
