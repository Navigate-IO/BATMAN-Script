#!/bin/bash
set -e

IFACE="wlan0"
MESH_IF="$IFACE"          # or create a separate interface if you prefer
MESH_ID="sdmahmesh"
FREQ="5180"
BAT_IP="192.168.50.1/24"  # change on the other Pi

# Clean up batman + wpa state
batctl if del "$MESH_IF" 2>/dev/null || true

systemctl stop wpa_supplicant 2>/dev/null || true
pkill -f "wpa_supplicant.*$IFACE" 2>/dev/null || true

ip link set "$IFACE" down 2>/dev/null || true

# 802.11s mesh point
iw dev "$MESH_IF" set type mp
ip link set "$MESH_IF" up

# Join mesh. Some drivers require channel width options, but try the simple form first.
iw dev "$MESH_IF" mesh join "$MESH_ID" freq "$FREQ"

# Batman on top
modprobe batman_adv
batctl if add "$MESH_IF"
ip link set up dev bat0

# IP on bat0
ip addr flush dev bat0
ip addr add "$BAT_IP" dev bat0
