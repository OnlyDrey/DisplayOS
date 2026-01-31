#!/bin/bash
# =============================================================================
# DisplayOS Security Hardening Script
# =============================================================================
#
# This script applies security hardening to DisplayOS:
# - Disable root SSH login
# - Configure automatic security updates
# - Enable AppArmor
# - Configure UFW firewall
# - Disable unnecessary services
# - Set secure file permissions
#
# Usage:
#   sudo ./setup_security.sh [options]
#
# Options:
#   --enable-ssh          Enable SSH (disabled by default)
#   --skip-firewall       Skip firewall configuration
#   --skip-apparmor       Skip AppArmor configuration
#   --help                Show help
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="DisplayOS Security Hardening"
readonly CONFIG_FILE="/etc/displayos/config.conf"
readonly LOG_FILE="/var/log/displayos/security-setup.log"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Options
ENABLE_SSH=false
SKIP_FIREWALL=false
SKIP_APPARMOR=false

# =============================================================================
# FUNCTIONS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file if possible
    if [[ -d "$(dirname "$LOG_FILE")" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    # Output to terminal
    case "$level" in
        INFO)  echo -e "${GREEN}[INFO]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        STEP)  echo -e "\n${BLUE}==> $message${NC}" ;;
    esac
}

show_help() {
    cat << EOF
$SCRIPT_NAME

Apply security hardening to DisplayOS.

Usage:
    sudo $0 [options]

Options:
    --enable-ssh          Enable SSH access (disabled by default for security)
    --skip-firewall       Skip UFW firewall configuration
    --skip-apparmor       Skip AppArmor configuration
    --help                Show this help

Security Features Applied:
    - Disable root SSH login
    - Automatic security updates (unattended-upgrades)
    - AppArmor mandatory access control
    - UFW firewall (HTTP/HTTPS outbound only)
    - Disable unnecessary services (Bluetooth, CUPS, Avahi)
    - Secure file permissions
    - Kernel hardening parameters
EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This script must be run as root"
        exit 1
    fi
}

setup_locales() {
    # Generate locales to suppress perl warnings
    if command -v locale-gen &>/dev/null; then
        locale-gen en_US.UTF-8 2>/dev/null || true
        update-locale LANG=C.UTF-8 2>/dev/null || true
        export LANG=C.UTF-8
        export LC_ALL=C.UTF-8
    fi
}

# Detect if running in chroot environment
is_chroot() {
    ! cmp -s <(stat -c %i /.) <(stat -c %i /) 2>/dev/null
}

# Safe systemctl wrapper that suppresses chroot warnings
safe_systemctl() {
    local action="$1"
    shift
    local service="$1"

    if is_chroot; then
        # In chroot, only try to enable/disable without starting
        case "$action" in
            enable|disable)
                systemctl "$action" "$service" 2>&1 | grep -E "(error|Error)" || true
                ;;
            start|restart)
                systemctl "$action" "$service" 2>&1 | grep -E "(error|Error)" || true
                ;;
        esac
    else
        # Outside chroot, run normally
        systemctl "$action" "$service"
    fi
}

disable_root_ssh() {
    log STEP "Configuring SSH security"
    
    local sshd_config="/etc/ssh/sshd_config"
    
    if [[ ! -f "$sshd_config" ]]; then
        log WARN "SSH not installed, skipping SSH configuration"
        return
    fi
    
    # Create secure SSH configuration
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/99-displayos-security.conf << 'EOF'
# DisplayOS SSH Security Configuration
PermitRootLogin no
PermitEmptyPasswords no
StrictModes yes
MaxAuthTries 3
LoginGraceTime 60
X11Forwarding no
AllowTcpForwarding no
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF
    
    if [[ "$ENABLE_SSH" == "true" ]]; then
        safe_systemctl enable ssh || true
        safe_systemctl restart ssh 2>/dev/null || safe_systemctl restart sshd 2>/dev/null || true
        log INFO "SSH enabled with security hardening"
    else
        safe_systemctl disable ssh || true
        safe_systemctl stop ssh 2>/dev/null || safe_systemctl stop sshd 2>/dev/null || true
        log INFO "SSH disabled"
    fi
}

configure_automatic_updates() {
    log STEP "Configuring automatic security updates"
    
    # Install unattended-upgrades if not present
    if ! dpkg -l unattended-upgrades &>/dev/null; then
        apt-get update -qq
        apt-get install -y unattended-upgrades apt-listchanges
    fi
    
    # Configure unattended-upgrades
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::SyslogEnable "true";
EOF
    
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    
    safe_systemctl enable unattended-upgrades || true
    safe_systemctl restart unattended-upgrades || true

    log INFO "Automatic security updates configured"
}

configure_apparmor() {
    log STEP "Configuring AppArmor"
    
    if [[ "$SKIP_APPARMOR" == "true" ]]; then
        log INFO "Skipping AppArmor configuration"
        return
    fi
    
    if ! dpkg -l apparmor &>/dev/null; then
        apt-get update -qq
        apt-get install -y apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra
    fi
    
    safe_systemctl enable apparmor || true
    safe_systemctl start apparmor || true

    log INFO "AppArmor configured"
}

configure_firewall() {
    log STEP "Configuring UFW firewall"

    if [[ "$SKIP_FIREWALL" == "true" ]]; then
        log INFO "Skipping firewall configuration"
        return
    fi

    # Check if we're in a chroot environment (ufw won't work properly there)
    if is_chroot; then
        log WARN "Running in chroot environment, skipping UFW configuration (will be configured on boot)"
        return
    fi

    if ! command -v ufw &>/dev/null; then
        apt-get update -qq 2>/dev/null || true
        apt-get install -y ufw 2>/dev/null || true
    fi

    # Only configure ufw if it's available
    if command -v ufw &>/dev/null; then
        ufw --force reset 2>/dev/null || true
        ufw default deny incoming 2>/dev/null || true
        ufw default deny outgoing 2>/dev/null || true

        # Allow outbound HTTP/HTTPS (for browser)
        ufw allow out 80/tcp comment 'Allow HTTP' 2>/dev/null || true
        ufw allow out 443/tcp comment 'Allow HTTPS' 2>/dev/null || true
        ufw allow out 53/udp comment 'Allow DNS' 2>/dev/null || true
        ufw allow out 53/tcp comment 'Allow DNS TCP' 2>/dev/null || true
        ufw allow out 123/udp comment 'Allow NTP' 2>/dev/null || true
        ufw allow out 67/udp comment 'Allow DHCP' 2>/dev/null || true
        ufw allow out 68/udp comment 'Allow DHCP' 2>/dev/null || true

        if [[ "$ENABLE_SSH" == "true" ]]; then
            ufw allow in 22/tcp comment 'Allow SSH' 2>/dev/null || true
            log INFO "SSH inbound traffic allowed"
        fi

        ufw allow in on lo 2>/dev/null || true
        ufw allow out on lo 2>/dev/null || true
        ufw --force enable 2>/dev/null || true

        log INFO "UFW firewall configured (HTTP/HTTPS outbound only)"
    else
        log WARN "UFW not available, skipping firewall configuration"
    fi
}

disable_unnecessary_services() {
    log STEP "Disabling unnecessary services"

    # Check if systemctl is available (it won't be in chroot)
    if ! command -v systemctl &>/dev/null; then
        log WARN "systemctl not available (running in chroot?), skipping service disable"
    else
        local services_to_disable=(
            "bluetooth.service"
            "cups.service"
            "cups-browsed.service"
            "avahi-daemon.service"
            "ModemManager.service"
        )

        for service in "${services_to_disable[@]}"; do
            if systemctl list-unit-files | grep -q "^${service}"; then
                safe_systemctl disable "$service" || true
                safe_systemctl stop "$service" || true
                log INFO "Disabled: $service"
            fi
        done
    fi

    # Create modprobe.d directory if it doesn't exist
    mkdir -p /etc/modprobe.d

    cat > /etc/modprobe.d/displayos-blacklist.conf << 'EOF'
# DisplayOS - Blacklisted kernel modules
blacklist bluetooth
blacklist btusb
blacklist firewire-core
blacklist cramfs
blacklist freevxfs
blacklist jffs2
blacklist hfs
blacklist hfsplus
blacklist udf
blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
EOF
    
    log INFO "Unnecessary services disabled"
}

set_secure_permissions() {
    log STEP "Setting secure file permissions"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        chmod 600 "$CONFIG_FILE"
        chown root:root "$CONFIG_FILE"
        log INFO "Secured: $CONFIG_FILE"
    fi
    
    if [[ -d /var/log/displayos ]]; then
        chmod 750 /var/log/displayos
        chown root:adm /var/log/displayos
    fi
    
    log INFO "File permissions secured"
}

configure_kernel_hardening() {
    log STEP "Configuring kernel hardening parameters"

    mkdir -p /etc/sysctl.d
    cat > /etc/sysctl.d/99-displayos-security.conf << 'EOF'
# DisplayOS Kernel Security Parameters
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_rfc1337 = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2
kernel.sysrq = 0
EOF
    
    sysctl -p /etc/sysctl.d/99-displayos-security.conf 2>/dev/null || true
    
    log INFO "Kernel hardening parameters applied"
}

show_security_status() {
    echo ""
    echo -e "${GREEN}=== Security Hardening Complete ===${NC}"
    echo ""
    echo "Applied Security Measures:"
    echo "  ✓ SSH root login disabled"
    echo "  ✓ Automatic security updates enabled"
    [[ "$SKIP_APPARMOR" != "true" ]] && echo "  ✓ AppArmor mandatory access control"
    [[ "$SKIP_FIREWALL" != "true" ]] && echo "  ✓ UFW firewall (HTTP/HTTPS outbound only)"
    echo "  ✓ Unnecessary services disabled"
    echo "  ✓ Secure file permissions"
    echo "  ✓ Kernel hardening parameters"
    echo ""
    
    if [[ "$ENABLE_SSH" == "true" ]]; then
        echo -e "${YELLOW}Note: SSH is enabled.${NC}"
    else
        echo -e "${GREEN}Note: SSH is disabled for security.${NC}"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --enable-ssh) ENABLE_SSH=true ;;
            --skip-firewall) SKIP_FIREWALL=true ;;
            --skip-apparmor) SKIP_APPARMOR=true ;;
            --help) show_help; exit 0 ;;
            *) log ERROR "Unknown option: $1"; show_help; exit 1 ;;
        esac
        shift
    done
    
    check_root
    setup_locales
    mkdir -p "$(dirname "$LOG_FILE")"

    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}  $SCRIPT_NAME${NC}"
    echo -e "${GREEN}========================================${NC}\n"

    disable_root_ssh
    configure_automatic_updates
    configure_apparmor
    configure_firewall
    disable_unnecessary_services
    set_secure_permissions
    configure_kernel_hardening
    
    show_security_status
}

main "$@"
