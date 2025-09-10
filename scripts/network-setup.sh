#!/bin/bash
set -e

# FreeBSD VM Network Configuration
# Configures bridge networking and firewall rules

BRIDGE_NAME="${BRIDGE_NAME:-freebsd-br0}"
BRIDGE_IP="${BRIDGE_IP:-10.0.100.1}"
BRIDGE_NETMASK="${BRIDGE_NETMASK:-255.255.255.0}"
VM_IP="${VM_IP:-10.0.100.10}"
DNS_SERVERS="${DNS_SERVERS:-8.8.8.8,8.8.4.4}"

setup_bridge() {
    echo "Setting up bridge network: $BRIDGE_NAME"
    
    # Create bridge if it doesn't exist
    if ! ip link show "$BRIDGE_NAME" &>/dev/null; then
        ip link add name "$BRIDGE_NAME" type bridge
        ip addr add "${BRIDGE_IP}/24" dev "$BRIDGE_NAME"
        ip link set "$BRIDGE_NAME" up
    fi
    
    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    
    # Setup NAT with iptables
    iptables -t nat -A POSTROUTING -s "${BRIDGE_IP%.*}.0/24" ! -d "${BRIDGE_IP%.*}.0/24" -j MASQUERADE
    iptables -A FORWARD -s "${BRIDGE_IP%.*}.0/24" -j ACCEPT
    iptables -A FORWARD -d "${BRIDGE_IP%.*}.0/24" -m state --state RELATED,ESTABLISHED -j ACCEPT
}

setup_tap() {
    TAP_DEVICE="${1:-tap0}"
    echo "Setting up TAP device: $TAP_DEVICE"
    
    # Create TAP device
    if ! ip link show "$TAP_DEVICE" &>/dev/null; then
        ip tuntap add "$TAP_DEVICE" mode tap
        ip link set "$TAP_DEVICE" master "$BRIDGE_NAME"
        ip link set "$TAP_DEVICE" up
    fi
}

configure_dhcp() {
    echo "Configuring DHCP for FreeBSD VMs"
    
    cat > /tmp/dnsmasq-freebsd.conf <<EOF
interface=$BRIDGE_NAME
bind-interfaces
dhcp-range=${BRIDGE_IP%.*}.100,${BRIDGE_IP%.*}.200,12h
dhcp-option=option:router,$BRIDGE_IP
dhcp-option=option:dns-server,$DNS_SERVERS
dhcp-host=52:54:00:12:34:56,$VM_IP,freebsd-vm
EOF
    
    # Start dnsmasq if available
    if command -v dnsmasq &>/dev/null; then
        dnsmasq -C /tmp/dnsmasq-freebsd.conf --pid-file=/tmp/dnsmasq-freebsd.pid
        echo "DHCP server started"
    else
        echo "Warning: dnsmasq not found, DHCP not configured"
    fi
}

teardown() {
    echo "Tearing down network configuration"
    
    # Stop dnsmasq
    [ -f /tmp/dnsmasq-freebsd.pid ] && kill "$(cat /tmp/dnsmasq-freebsd.pid)" 2>/dev/null || true
    
    # Remove iptables rules
    iptables -t nat -D POSTROUTING -s "${BRIDGE_IP%.*}.0/24" ! -d "${BRIDGE_IP%.*}.0/24" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -s "${BRIDGE_IP%.*}.0/24" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -d "${BRIDGE_IP%.*}.0/24" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    
    # Remove bridge
    ip link delete "$BRIDGE_NAME" 2>/dev/null || true
}

case "${1:-setup}" in
    setup)
        setup_bridge
        setup_tap
        configure_dhcp
        echo "Network setup complete"
        ;;
    teardown)
        teardown
        echo "Network teardown complete"
        ;;
    *)
        echo "Usage: $0 {setup|teardown}"
        exit 1
        ;;
esac