#!/bin/bash
set -e
IFACE="wlan0"
MESH_ID="sdmahmesh"
FREQ="5200"
BAT_IP=""

# ─── Get bat0 IP address ───
if [ -n "$BAT_IP" ]; then
    # Use env var or previously saved value
    echo "  → Using bat0 IP: $BAT_IP"
elif [ -t 0 ]; then
    # Interactive terminal — prompt for input
    while true; do
        read -p "Enter bat0 IP address for this Pi (e.g. 192.168.50.1): " BAT_IP_INPUT

        # Validate IP format (x.x.x.x where each octet is 0-255)
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
                echo "  → Using bat0 IP: $BAT_IP"

                # Save IP back to this script for future runs
                SCRIPT_PATH="$(realpath "$0")"
                sed -i "s|^BAT_IP=.*|BAT_IP=\"${BAT_IP}\"|" "$SCRIPT_PATH" 2>/dev/null || true

                # Also update systemd service if it exists
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
    echo "  Set BAT_IP before running, e.g.: BAT_IP=192.168.50.1/24 bash sdmah-mesh.sh"
    exit 1
fi

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

echo "  Mesh setup complete. bat0 IP: $BAT_IP"
