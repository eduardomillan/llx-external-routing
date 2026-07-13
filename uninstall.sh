#!/usr/bin/env bash
# =============================================================================
# uninstall.sh
# Uninstalls External Routing from the system.
# Run as root: sudo ./uninstall.sh
# =============================================================================
set -euo pipefail

echo "=== External Routing - Uninstaller ==="
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo ./uninstall.sh)"
    exit 1
fi

# Stop and remove systemd timer
echo "[1/5] Stopping systemd timer..."
systemctl stop llx-external-routes-refresh.timer 2>/dev/null || true
systemctl disable llx-external-routes-refresh.timer 2>/dev/null || true
rm -f /etc/systemd/system/llx-external-routes-refresh.service
rm -f /etc/systemd/system/llx-external-routes-refresh.timer
systemctl daemon-reload 2>/dev/null || true
echo "  OK: Timer removed"

# Remove NetworkManager dispatcher
echo "[2/5] Removing NM dispatcher..."
rm -f /etc/NetworkManager/dispatcher.d/99-llx-external-routing
echo "  OK: Dispatcher removed"

# Remove scripts
echo "[3/5] Removing scripts..."
rm -f /usr/local/bin/llx-external-routing-dispatcher
rm -f /usr/local/bin/refresh-external-routes
echo "  OK: Scripts removed"

# Remove active routing rules
echo "[4/5] Cleaning up routing rules..."
TABLE_NUM=$(grep -E "^([0-9]+) external$" /etc/iproute2/rt_tables 2>/dev/null | awk '{print $1}' || echo "")
if [[ -n "$TABLE_NUM" ]]; then
    while ip rule del table "$TABLE_NUM" 2>/dev/null; do :; done
    ip route flush table "$TABLE_NUM" 2>/dev/null || true
    sed -i "/^$TABLE_NUM /d" /etc/iproute2/rt_tables 2>/dev/null || true
    echo "  OK: Rules and table $TABLE_NUM removed"
else
    echo "  OK: No active rules to clean"
fi

# Ask about configuration
echo "[5/5] Removing configuration..."
read -r -p "  Remove /etc/llx-external-routes/ (config + resolved IPs)? [y/N]: " respuesta
if [[ "$respuesta" =~ ^[yY]$ ]]; then
    rm -rf /etc/llx-external-routes
    echo "  OK: Configuration removed"
else
    echo "  OK: Configuration kept at /etc/llx-external-routes/"
fi

echo ""
echo "=== Uninstallation complete ==="
echo ""
echo "Removed files:"
echo "  /etc/NetworkManager/dispatcher.d/99-llx-external-routing"
echo "  /usr/local/bin/llx-external-routing-dispatcher"
echo "  /usr/local/bin/refresh-external-routes"
echo "  /etc/systemd/system/llx-external-routes-refresh.service"
echo "  /etc/systemd/system/llx-external-routes-refresh.timer"
