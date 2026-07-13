# llx-External Routing

Selective domain-based routing for Linux. Routes traffic for specific domains through an external WiFi interface while the rest of the traffic uses the corporate connection by default.

## Structure

```
llx-external-routing/
├── conf/
│   └── config.conf                              # Main configuration
├── scripts/
│   ├── llx-external-routing-dispatcher               # NetworkManager dispatcher
│   └── refresh-external-routes                   # Periodic IP refresh
├── systemd/
│   ├── llx-external-routes-refresh.service           # Systemd service
│   └── llx-external-routes-refresh.timer             # Timer (every 15 min)
├── ipsets/                                       # Resolved IPs (auto-generated)
├── install.sh                                    # Installer
└── uninstall.sh                                  # Uninstaller
```

## Requirements

- Linux with NetworkManager
- `iproute2` (command `ip`)
- `dnsutils` (command `dig`)
- `nmcli` (NetworkManager CLI)
- Root permissions to install

## Installation

```bash
sudo ./install.sh
```

## Uninstallation

```bash
sudo ./uninstall.sh
```

## Configuration

The configuration file is located at `/etc/llx-external-routes/config.conf`:

```bash
# Network interfaces
CORPORATE_IFACE="eth0"        # Corporate interface (default gateway)
EXTERNAL_IFACE="wlan0"        # External WiFi interface (selective routing)

# Routing table
ROUTING_TABLE=100

# Domains to route through external WiFi (space-separated)
DOMAINS="tailscale.com tailscale.io anydesk.net facebook.com fbcdn.net"

# External DNS (empty = use DHCP-assigned)
EXTERNAL_DNS=""

# Refresh interval in minutes
REFRESH_INTERVAL=15

# Log file
LOG_FILE="/var/log/llx-external-routing.log"

# Verbosity level: 0=minimal, 1=normal, 2=verbose
VERBOSE=1
```

### Domains

- One domain per space in the `DOMAINS` variable
- Automatically resolved to IPv4 addresses
- `www.` subdomains are also resolved
- To add/remove domains, edit `config.conf` and run `sudo /usr/local/bin/refresh-external-routes`

### Interfaces

- `CORPORATE_IFACE`: corporate network interface (default: eth0)
- `EXTERNAL_IFACE`: external WiFi interface (default: wlan0)
- Interface names can be changed in `config.conf`

## Usage

### Automatic flow

1. Connect external WiFi (mobile hotspot, etc.)
2. NetworkManager dispatcher detects the connection and sets up routing
3. Configured domains are routed through external WiFi
4. Rest of the traffic goes through the corporate connection
5. Timer refreshes IPs every 15 minutes

### Useful commands

```bash
# Check timer status
systemctl status llx-external-routes-refresh.timer

# Force manual refresh
sudo /usr/local/bin/refresh-external-routes

# View logs
tail -f /var/log/llx-external-routing.log
journalctl -u llx-external-routes-refresh -f

# View active routing rules
ip rule list

# View resolved IPs for a domain
cat /etc/llx-external-routes/ipsets/facebook.com.ips

# View external routing table
ip route show table 100

# Enable/disable timer
sudo systemctl start llx-external-routes-refresh.timer
sudo systemctl stop llx-external-routes-refresh.timer
```

## How it works

```
Traffic to facebook.com:
  → DNS resolution → 157.240.x.x
  → ip rule: "if destination is 157.240.x.x, use table 100"
  → Table 100: "default via <WiFi-gateway> dev wlan0"
  → Goes out through external WiFi ✓

Traffic to google.com:
  → No match in rules
  → Table main: "default via 172.28.222.1 dev eth0"
  → Goes out through corporate ✓
```

### Components

- **NetworkManager dispatcher**: runs automatically when WiFi connects/disconnects. Creates routing rules and resolves domains.
- **Refresh script**: re-resolves domain IPs periodically. Useful because IPs for services like Facebook change frequently.
- **Systemd timer**: runs the refresh script every 15 minutes (configurable).

## Troubleshooting

### Domains not resolving

```bash
# Check dig works
dig +short facebook.com

# Check logs
tail -20 /var/log/llx-external-routing.log
```

### Routing rules not created

```bash
# Check external interface has an IP
ip addr show wlan0

# Check gateway
nmcli -t -f IP4.GATEWAY device show wlan0

# Check rules
ip rule list | grep "lookup 100"
```

### Timer not starting

```bash
systemctl status llx-external-routes-refresh.timer
journalctl -u llx-external-routes-refresh -n 50
```
