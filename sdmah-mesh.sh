#!/bin/bash
set -e

IFACE="wlan0"
MESH_CONF="/home/pi/sx-sdmah/conf/US/mesh_halow_open.conf"
BAT_IP=""
MODE="${MODE:-batman}"  # "batman" or "hwmp"

# ─── Get IP address ───
if [ -n "$BAT_IP" ]; then
    echo "  → Using IP: $BAT_IP"
elif [ -t 0 ]; then
    while true; do
        read -p "Enter IP address for this Pi (e.g. 192.168.50.1): " BAT_IP_INPUT
        if echo "$BAT_IP_INPUT" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
            VALID=true
            IFS='.' read -r o1 o2 o3 o4 <<< "$BAT_IP_INPUT"
            for octet in $o1 $o2 $o3 $o4; do
                if [ "$octet" -gt 255 ] 2>/dev/null; then
                    VALID=false
                fi
            done
            if $VALID; then
                BAT_IP="${BAT_IP_INPUT}/24"
                echo "  → Using IP: $BAT_IP"
                SCRIPT_PATH="$(realpath "$0")"
                sed -i "s|^BAT_IP=.*|BAT_IP=\"${BAT_IP}\"|" "$SCRIPT_PATH" 2>/dev/null || true
                for svc in mcs-matrix-tx.service mcs-matrix-rx.service; do
                    SVC_FILE="/etc/systemd/system/$svc"
                    if [ -f "$SVC_FILE" ]; then
                        sed -i "s|^Environment=TX_BAT_IP=.*|Environment=TX_BAT_IP=${BAT_IP}|" "$SVC_FILE" 2>/dev/null || true
                        sed -i "s|^Environment=RX_BAT_IP=.*|Environment=RX_BAT_IP=${BAT_IP}|" "$SVC_FILE" 2>/dev/null || true
                    fi
                done
                systemctl daemon-reload 2>/dev/null || true
                break
            fi
        fi
        echo "  Invalid IP address. Please try again."
    done
else
    echo "ERROR: No BAT_IP environment variable set and no terminal for input."
    echo "  Set BAT_IP before running, e.g.: BAT_IP=192.168.50.1/24 MODE=hwmp bash sdmah-mesh.sh"
    exit 1
fi

# ─── Free the interface ───
batctl if del "$IFACE" 2>/dev/null || true
ip link set bat0 down 2>/dev/null || true
killall wpa_supplicant_s1g 2>/dev/null || true
killall hostapd_s1g 2>/dev/null || true
systemctl stop wpa_supplicant 2>/dev/null || true
pkill -f "wpa_supplicant.*$IFACE" 2>/dev/null || true
iw dev p2p-dev-"$IFACE" del 2>/dev/null || true
ip link set "$IFACE" down || true

# ─── Start 802.11s mesh via wpa_supplicant_s1g ───
echo "  Starting 802.11s mesh (mode: $MODE)..."
wpa_supplicant_s1g -i "$IFACE" -c "$MESH_CONF" -B
sleep 5

if [ "$MODE" = "hwmp" ]; then
    # ─── HWMP: IP directly on wlan0, no batman ───
    ip addr flush dev "$IFACE"
    ip addr add "$BAT_IP" dev "$IFACE"
    echo "  HWMP mesh setup complete. $IFACE IP: $BAT_IP"
else
    # ─── Batman IV: IP on bat0 ───
    modprobe batman_adv
    batctl if add "$IFACE"
    ip link set up dev bat0
    ip addr flush dev bat0
    ip addr add "$BAT_IP" dev bat0
    echo "  Batman mesh setup complete. bat0 IP: $BAT_IP"
fi

echo "  Bandwidth: $(morsectrl bw 2>/dev/null || echo 'unknown')"
