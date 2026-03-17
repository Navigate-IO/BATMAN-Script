#!/bin/bash
set -e
IFACE="wlan0"
MESH_ID="sdmahmesh"
FREQ="5200"
BAT_IP="192.168.50.1/24"    # change to .2 on the second Pi

# S1G channel config — uncomment ONE line:
#S1G_FREQ=920500; S1G_BW=1   # 1MHz
#S1G_FREQ=921000; S1G_BW=2   # 2MHz
S1G_FREQ=922000; S1G_BW=4    # 4MHz
#S1G_FREQ=916000; S1G_BW=8   # 8MHz

# Free the interface
batctl if del "$IFACE" 2>/dev/null || true
systemctl stop wpa_supplicant 2>/dev/null || true
pkill -f "wpa_supplicant.*$IFACE" 2>/dev/null || true
iw dev p2p-dev-"$IFACE" del 2>/dev/null || true
ip link set "$IFACE" down || true

# Set IBSS (ad-hoc) mode
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

# Set S1G channel and bandwidth (after everything is up)
sleep 5
morsectrl channel -c "$S1G_FREQ" -o "$S1G_BW" -p "$S1G_BW" -n 0
morsectrl bw "$S1G_BW"
sleep 3
# Set again in case driver reset it
morsectrl channel -c "$S1G_FREQ" -o "$S1G_BW" -p "$S1G_BW" -n 0
morsectrl bw "$S1G_BW"
sleep 1
echo "S1G config: $(morsectrl bw) | $(morsectrl channel)"
