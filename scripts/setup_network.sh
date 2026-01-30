#!/bin/bash
# =============================================================================
# DisplayOS Network Setup Script
# =============================================================================
#
# This script configures network management including:
# - NetworkManager setup
# - WiFi configuration
# - GUI Network Manager (nm-connection-editor) with Ctrl+Alt+W shortcut
# - Network system tray applet
#
# Usage:
#   sudo ./setup_network.sh [options]
#
# Options:
#   --wifi-ssid=SSID        Configure WiFi SSID
#   --wifi-password=PASS    Configure WiFi password
#   --static-ip=IP          Set static IP (format: IP/PREFIX)
#   --gateway=GW            Set gateway for static IP
#   --dns=DNS               Set DNS servers (comma-separated)
#   --help                  Show help
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="DisplayOS Network Setup"
readonly CONFIG_FILE="/etc/displayos/config.conf"
readonly DISPLAYOS_USER="displayos"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# =============================================================================
# FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    echo -e "\n${BLUE}==> $*${NC}"
}

show_help() {
    cat << EOF
$SCRIPT_NAME

Configure network management for DisplayOS.

Usage:
    sudo $0 [options]

Options:
    --wifi-ssid=SSID        Configure WiFi SSID
    --wifi-password=PASS    Configure WiFi password
    --wifi-security=TYPE    WiFi security (WPA-PSK, WPA-EAP, WEP, OPEN)
    --static-ip=IP          Set static IP (format: 192.168.1.100/24)
    --gateway=GW            Set gateway for static IP
    --dns=DNS               Set DNS servers (comma-separated)
    --help                  Show this help

Examples:
    sudo $0 --wifi-ssid="MyNetwork" --wifi-password="secret123"
    sudo $0 --static-ip=192.168.1.100/24 --gateway=192.168.1.1 --dns=8.8.8.8,8.8.4.4

Keyboard Shortcuts:
    Ctrl+Alt+W    Open Network Manager GUI (nm-connection-editor)

EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

install_packages() {
    log_step "Installing network management packages"
    
    local packages=(
        network-manager
        network-manager-gnome
        wireless-tools
        wpasupplicant
        rfkill
        iw
    )
    
    apt-get update -qq
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            log_info "Installing $pkg..."
            apt-get install -y "$pkg"
        else
            log_info "$pkg already installed"
        fi
    done
}

configure_networkmanager() {
    log_step "Configuring NetworkManager"
    
    # Main NetworkManager configuration
    cat > /etc/NetworkManager/NetworkManager.conf << 'EOF'
[main]
plugins=ifupdown,keyfile
dns=default

[ifupdown]
managed=true

[device]
wifi.scan-rand-mac-address=no

[connection]
# Automatically connect to known networks
autoconnect-retries=0

[logging]
level=WARN
EOF
    
    # Ensure NetworkManager manages all interfaces
    cat > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf << 'EOF'
[keyfile]
unmanaged-devices=none
EOF
    
    # Enable and restart NetworkManager
    systemctl enable NetworkManager
    systemctl restart NetworkManager || true
    
    log_info "NetworkManager configured"
}

setup_nm_applet_autostart() {
    log_step "Setting up Network Manager system tray applet"
    
    local autostart_dir="/home/$DISPLAYOS_USER/.config/autostart"
    mkdir -p "$autostart_dir"
    
    # Create autostart entry for nm-applet
    cat > "$autostart_dir/nm-applet.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Network Manager Applet
Comment=NetworkManager system tray applet
Exec=nm-applet
Icon=network-workgroup
Categories=System;
StartupNotify=false
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    
    chown -R "$DISPLAYOS_USER:$DISPLAYOS_USER" "$autostart_dir"
    
    log_info "nm-applet autostart configured"
}

setup_keyboard_shortcut() {
    log_step "Setting up Ctrl+Alt+W keyboard shortcut for Network Manager"
    
    local openbox_rc="/home/$DISPLAYOS_USER/.config/openbox/rc.xml"
    
    # Check if Openbox config exists
    if [[ ! -f "$openbox_rc" ]]; then
        log_warn "Openbox rc.xml not found, creating basic configuration"
        mkdir -p "$(dirname "$openbox_rc")"
        
        cat > "$openbox_rc" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
    <!-- Ctrl+Alt+W: Open Network Manager GUI -->
    <keybind key="C-A-w">
      <action name="Execute">
        <command>nm-connection-editor</command>
      </action>
    </keybind>
  </keyboard>
</openbox_config>
EOF
    else
        # Check if shortcut already exists
        if grep -q "C-A-w" "$openbox_rc"; then
            log_info "Ctrl+Alt+W shortcut already configured"
        else
            # Add the keybind before </keyboard>
            sed -i '/<\/keyboard>/i\
    <!-- Ctrl+Alt+W: Open Network Manager GUI -->\
    <keybind key="C-A-w">\
      <action name="Execute">\
        <command>nm-connection-editor</command>\
      </action>\
    </keybind>' "$openbox_rc"
            log_info "Added Ctrl+Alt+W shortcut to Openbox configuration"
        fi
    fi
    
    chown "$DISPLAYOS_USER:$DISPLAYOS_USER" "$openbox_rc"
    
    # Also create a standalone script for the shortcut
    cat > /usr/local/bin/displayos-network-manager << 'SCRIPT'
#!/bin/bash
# DisplayOS Network Manager Launcher
# Launched by Ctrl+Alt+W shortcut

# Set display if not set
export DISPLAY="${DISPLAY:-:0}"

# Launch nm-connection-editor
exec nm-connection-editor
SCRIPT
    
    chmod +x /usr/local/bin/displayos-network-manager
    
    log_info "Network Manager shortcut configured: Ctrl+Alt+W"
}

configure_wifi() {
    local ssid="$1"
    local password="$2"
    local security="${3:-WPA-PSK}"
    
    log_step "Configuring WiFi connection"
    
    if [[ -z "$ssid" ]]; then
        log_warn "No WiFi SSID provided, skipping WiFi configuration"
        return
    fi
    
    # Remove existing connection with same name if exists
    nmcli connection delete "$ssid" 2>/dev/null || true
    
    case "$security" in
        WPA-PSK|WPA2-PSK)
            nmcli connection add \
                type wifi \
                con-name "$ssid" \
                ifname "*" \
                ssid "$ssid" \
                wifi-sec.key-mgmt wpa-psk \
                wifi-sec.psk "$password" \
                connection.autoconnect yes \
                connection.autoconnect-priority 100
            ;;
        WEP)
            nmcli connection add \
                type wifi \
                con-name "$ssid" \
                ifname "*" \
                ssid "$ssid" \
                wifi-sec.key-mgmt none \
                wifi-sec.wep-key0 "$password" \
                connection.autoconnect yes
            ;;
        OPEN)
            nmcli connection add \
                type wifi \
                con-name "$ssid" \
                ifname "*" \
                ssid "$ssid" \
                connection.autoconnect yes
            ;;
        *)
            log_error "Unknown security type: $security"
            return 1
            ;;
    esac
    
    log_info "WiFi connection '$ssid' configured"
    
    # Update config file
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i "s|^WIFI_SSID=.*|WIFI_SSID=$ssid|" "$CONFIG_FILE"
        sed -i "s|^WIFI_PASSWORD=.*|WIFI_PASSWORD=$password|" "$CONFIG_FILE"
        sed -i "s|^WIFI_SECURITY=.*|WIFI_SECURITY=$security|" "$CONFIG_FILE"
    fi
}

configure_static_ip() {
    local ip="$1"
    local gateway="$2"
    local dns="$3"
    local interface="${4:-eth0}"
    
    log_step "Configuring static IP"
    
    if [[ -z "$ip" ]]; then
        log_warn "No static IP provided, using DHCP"
        return
    fi
    
    # Create NetworkManager connection profile
    local con_name="static-$interface"
    
    # Remove existing static connection if exists
    nmcli connection delete "$con_name" 2>/dev/null || true
    
    # Build the nmcli command
    local nmcli_cmd="nmcli connection add type ethernet con-name \"$con_name\" ifname \"$interface\""
    nmcli_cmd+=" ipv4.method manual ipv4.addresses \"$ip\""
    
    if [[ -n "$gateway" ]]; then
        nmcli_cmd+=" ipv4.gateway \"$gateway\""
    fi
    
    if [[ -n "$dns" ]]; then
        nmcli_cmd+=" ipv4.dns \"$dns\""
    fi
    
    nmcli_cmd+=" connection.autoconnect yes"
    
    eval "$nmcli_cmd"
    
    log_info "Static IP configured: $ip"
    
    # Update config file
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i "s|^STATIC_IP=.*|STATIC_IP=$ip|" "$CONFIG_FILE"
        sed -i "s|^STATIC_GATEWAY=.*|STATIC_GATEWAY=$gateway|" "$CONFIG_FILE"
        sed -i "s|^STATIC_DNS=.*|STATIC_DNS=$dns|" "$CONFIG_FILE"
    fi
}

create_network_scripts() {
    log_step "Creating network utility scripts"
    
    # WiFi connection script
    cat > /usr/local/bin/displayos-wifi-connect << 'SCRIPT'
#!/bin/bash
# Connect to WiFi from command line
# Usage: displayos-wifi-connect SSID PASSWORD

SSID="${1:-}"
PASSWORD="${2:-}"

if [[ -z "$SSID" ]]; then
    echo "Usage: $0 SSID [PASSWORD]"
    echo ""
    echo "Available networks:"
    nmcli device wifi list
    exit 1
fi

if [[ -n "$PASSWORD" ]]; then
    nmcli device wifi connect "$SSID" password "$PASSWORD"
else
    nmcli device wifi connect "$SSID"
fi
SCRIPT
    chmod +x /usr/local/bin/displayos-wifi-connect
    
    # Network status script
    cat > /usr/local/bin/displayos-network-status << 'SCRIPT'
#!/bin/bash
# Display network status
# Usage: displayos-network-status

echo "=== Network Status ==="
echo ""

echo "Connections:"
nmcli connection show --active
echo ""

echo "Devices:"
nmcli device status
echo ""

echo "WiFi Networks:"
nmcli device wifi list 2>/dev/null || echo "No WiFi adapter found"
echo ""

echo "IP Addresses:"
ip -brief addr show
SCRIPT
    chmod +x /usr/local/bin/displayos-network-status
    
    # Network restart script
    cat > /usr/local/bin/displayos-network-restart << 'SCRIPT'
#!/bin/bash
# Restart network services
# Usage: sudo displayos-network-restart

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

echo "Restarting NetworkManager..."
systemctl restart NetworkManager

echo "Waiting for network..."
sleep 3

nmcli device status
SCRIPT
    chmod +x /usr/local/bin/displayos-network-restart
    
    log_info "Network utility scripts created"
}

show_network_info() {
    echo ""
    echo -e "${GREEN}=== Network Configuration Complete ===${NC}"
    echo ""
    echo "Keyboard Shortcuts:"
    echo "  Ctrl+Alt+W    Open Network Manager GUI (nm-connection-editor)"
    echo ""
    echo "Command Line Tools:"
    echo "  nmcli                          NetworkManager CLI"
    echo "  displayos-wifi-connect         Connect to WiFi"
    echo "  displayos-network-status       Show network status"
    echo "  displayos-network-restart      Restart network services"
    echo ""
    echo "GUI Tools:"
    echo "  nm-connection-editor           Network connection editor"
    echo "  nm-applet                      System tray network applet"
    echo ""
    echo "Current Network Status:"
    nmcli device status
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local wifi_ssid=""
    local wifi_password=""
    local wifi_security="WPA-PSK"
    local static_ip=""
    local gateway=""
    local dns=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --wifi-ssid=*)
                wifi_ssid="${1#*=}"
                ;;
            --wifi-password=*)
                wifi_password="${1#*=}"
                ;;
            --wifi-security=*)
                wifi_security="${1#*=}"
                ;;
            --static-ip=*)
                static_ip="${1#*=}"
                ;;
            --gateway=*)
                gateway="${1#*=}"
                ;;
            --dns=*)
                dns="${1#*=}"
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    check_root
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}  $SCRIPT_NAME${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    
    install_packages
    configure_networkmanager
    setup_nm_applet_autostart
    setup_keyboard_shortcut
    create_network_scripts
    
    # Configure WiFi if provided
    if [[ -n "$wifi_ssid" ]]; then
        configure_wifi "$wifi_ssid" "$wifi_password" "$wifi_security"
    fi
    
    # Configure static IP if provided
    if [[ -n "$static_ip" ]]; then
        configure_static_ip "$static_ip" "$gateway" "$dns"
    fi
    
    show_network_info
}

main "$@"
