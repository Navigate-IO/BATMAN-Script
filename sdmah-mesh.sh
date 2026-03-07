#!/bin/bash
set -e

IFACE="wlan0"
MESH_ID="sdmahmesh"
FREQ="5180"
BAT_IP="192.168.50.1/24"    # change to .2 on the second Pi

# Free the interface
batctl if del "$IFACE" 2>/dev/null || true

systemctl stop wpa_supplicant 2>/dev/null || true
pkill -f "wpa_supplicant.*$IFACE" 2>/dev/null || true

iw dev p2p-dev-"$IFACE" del 2>/dev/null || true

ip link set "$IFACE" down || true

# Set IBSS
iw dev "$IFACE" set type ibss
ip link set "$IFACE" up
iw dev "$IFACE" ibss join "$MESH_ID" "$FREQ"

# Batman
modprobe batman_adv
batctl if add "$IFACE"
ip link set up dev bat0

# IP on bat0
ip addr flush dev bat0
ip addr add "$BAT_IP" dev bat0
