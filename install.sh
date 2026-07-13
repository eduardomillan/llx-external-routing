#!/usr/bin/env bash
# =============================================================================
# install.sh
# Installs External Routing on the system.
# Run as root: sudo ./install.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== External Routing - Installer ==="
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo ./install.sh)"
    exit 1
fi

# Check dependencies
echo "[1/6] Checking dependencies..."
for cmd in ip nmcli dig; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "  ERROR: '$cmd' not found. Install with:"
        case "$cmd" in
            dig) echo "    sudo apt install dnsutils" ;;
            *) echo "    sudo apt install $cmd" ;;
        esac
        exit 1
    fi
done
echo "  OK: All dependencies found"

# Create config directory
echo "[2/6] Creating directories..."
mkdir -p /etc/llx-external-routes/ipsets
mkdir -p /var/log
echo "  OK: Directories created"

# Copy config (don't overwrite if exists)
echo "[3/6] Installing configuration..."
if [[ -f /etc/llx-external-routes/config.conf ]]; then
    echo "  WARNING: /etc/llx-external-routes/config.conf already exists, not overwriting"
    echo "  Compare with $SCRIPT_DIR/conf/config.conf for new options"
else
    cp "$SCRIPT_DIR/conf/config.conf" /etc/llx-external-routes/config.conf
    echo "  OK: Configuration installed to /etc/llx-external-routes/config.conf"
fi

# Install scripts
echo "[4/6] Installing scripts..."
cp "$SCRIPT_DIR/scripts/llx-external-routing-dispatcher" /usr/local/bin/llx-external-routing-dispatcher
cp "$SCRIPT_DIR/scripts/refresh-external-routes" /usr/local/bin/refresh-external-routes
chmod 755 /usr/local/bin/llx-external-routing-dispatcher
chmod 755 /usr/local/bin/refresh-external-routes
echo "  OK: Scripts installed to /usr/local/bin/"

# Install NetworkManager dispatcher
echo "[5/6] Configuring NetworkManager dispatcher..."
mkdir -p /etc/NetworkManager/dispatcher.d
cat > /etc/NetworkManager/dispatcher.d/99-llx-external-routing << 'DISPATCHER'
#!/usr/bin/env bash
exec /usr/local/bin/llx-external-routing-dispatcher "$@"
DISPATCHER
chmod 755 /etc/NetworkManager/dispatcher.d/99-llx-external-routing
echo "  OK: Dispatcher installed to /etc/NetworkManager/dispatcher.d/99-llx-external-routing"

# Install systemd timer
echo "[6/6] Configuring systemd timer..."
cp "$SCRIPT_DIR/systemd/llx-external-routes-refresh.service" /etc/systemd/system/
cp "$SCRIPT_DIR/systemd/llx-external-routes-refresh.timer" /etc/systemd/system/
chmod 644 /etc/systemd/system/llx-external-routes-refresh.service
chmod 644 /etc/systemd/system/llx-external-routes-refresh.timer
systemctl daemon-reload
systemctl enable llx-external-routes-refresh.timer
systemctl start llx-external-routes-refresh.timer
echo "  OK: Timer installed and enabled"

echo ""
echo "=== Installation complete ==="
echo ""
echo "Installed files:"
echo "  /etc/llx-external-routes/config.conf          - Main configuration"
echo "  /etc/llx-external-routes/ipsets/              - Resolved IPs"
echo "  /usr/local/bin/llx-external-routing-dispatcher - NM dispatcher"
echo "  /usr/local/bin/refresh-external-routes     - Refresh script"
echo "  /etc/NetworkManager/dispatcher.d/99-llx-external-routing"
echo "  /etc/systemd/system/llx-external-routes-refresh.service"
echo "  /etc/systemd/system/llx-external-routes-refresh.timer"
echo ""
echo "Usage:"
echo "  1. Edit /etc/llx-external-routes/config.conf with your domains"
echo "  2. Connect external WiFi - routing activates automatically"
echo "  3. View logs: journalctl -u llx-external-routes-refresh -f"
echo "  4. Verify: ip rule list"
echo "  5. Force refresh: sudo /usr/local/bin/refresh-external-routes"
echo ""
echo "To uninstall: sudo /path/to/uninstall.sh"
