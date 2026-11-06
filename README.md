# llx-External Routing

Selective domain-based routing for Linux. Routes traffic for specific domains through an external WiFi interface while the rest of the traffic uses the corporate connection by default.

## Table of contents

- [Structure](#structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Uninstallation](#uninstallation)
- [Configuration](#configuration)
  - [Domains](#domains)
  - [Literal IPs](#literal-ips)
  - [Interfaces](#interfaces)
- [CLI](#cli)
- [Usage](#usage)
  - [Automatic flow](#automatic-flow)
  - [Useful commands](#useful-commands)
- [How it works](#how-it-works)
  - [Components](#components)
- [Troubleshooting](#troubleshooting)
  - [Domains not resolving](#domains-not-resolving)
  - [Routing rules not created](#routing-rules-not-created)
  - [Timer not starting](#timer-not-starting)

## Structure

```
llx-external-routing/
├── conf/
│   └── config.conf                              # Main configuration
├── scripts/
│   ├── llx-external-routing-dispatcher               # NetworkManager dispatcher
│   ├── refresh-external-routes                   # Periodic IP refresh
│   ├── llx-exroute-cli                   # CLI: list/add/remove destinations
│   └── lib/
│       └── common-routing.sh                     # Shared helpers
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

# Literal IPv4 addresses/CIDRs to route through external WiFi (space-separated)
IPS="172.28.222.250 10.0.0.0/24"

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
- Ships empty by default (`DOMAINS=""`) — the shipped `config.conf` is a template, not a live example
- Automatically resolved to IPv4 addresses
- `www.` subdomains are also resolved
- To add/remove domains, edit `config.conf` and run `sudo /usr/local/bin/refresh-external-routes`, or use the [CLI](#cli): `sudo llx-exroute-cli add domain <domain>`

### Literal IPs

- One IPv4 address or CIDR per space in the `IPS` variable (e.g. `IPS="172.28.222.250 10.0.0.0/24"`)
- Ships empty by default (`IPS=""`)
- Used as-is, with **no DNS resolution** — useful for targets that aren't a domain (internal hosts, VPN endpoints, etc.)
- Invalid entries are skipped and logged as a warning
- IPv6 is not supported
- To add/remove IPs, edit `config.conf` and run `sudo /usr/local/bin/refresh-external-routes`, or use the [CLI](#cli): `sudo llx-exroute-cli add ip <ip[/cidr]>`

### Interfaces

- `CORPORATE_IFACE`: corporate network interface (default: eth0)
- `EXTERNAL_IFACE`: external WiFi interface (default: wlan0)
- Interface names can be changed in `config.conf`

## CLI

`llx-exroute-cli` lists, adds and removes domains/IPs without hand-editing `config.conf`. There is currently a single external interface (`EXTERNAL_IFACE`), so `list` groups destinations under it versus the corporate default route.

```bash
# List configured destinations, grouped by interface
llx-exroute-cli list

# Add a domain or a literal IP/CIDR (requires root)
sudo llx-exroute-cli add domain anydesk.com
sudo llx-exroute-cli add ip 172.28.222.250
sudo llx-exroute-cli add ip 10.0.0.0/24

# Remove a domain or IP (requires root)
sudo llx-exroute-cli remove domain anydesk.com
sudo llx-exroute-cli remove ip 172.28.222.250
```

`add`/`remove` write to `config.conf` and immediately run `refresh-external-routes` to apply the change. If `EXTERNAL_IFACE` isn't currently up, the config is still saved and the rule applies the next time it connects.

### Settings (`get`/`set`)

The rest of `config.conf` can also be managed from the CLI:

```bash
# Show every config value
llx-exroute-cli get
llx-exroute-cli get all   # same thing

# Show a single value
llx-exroute-cli get ROUTING_TABLE

# Change a value (requires root)
sudo llx-exroute-cli set CORPORATE_IFACE eth0
sudo llx-exroute-cli set EXTERNAL_IFACE wlan0
sudo llx-exroute-cli set ROUTING_TABLE 100
sudo llx-exroute-cli set EXTERNAL_DNS "8.8.8.8 1.1.1.1"
sudo llx-exroute-cli set REFRESH_INTERVAL 15
sudo llx-exroute-cli set LOG_FILE /var/log/llx-external-routing.log
sudo llx-exroute-cli set VERBOSE 1
```

- `EXTERNAL_IFACE` and `ROUTING_TABLE` tear down the live rules/routes under the old table number before applying the new value, so nothing is left orphaned.
- `CORPORATE_IFACE` is informational only — this tool never routes traffic through it explicitly, it's just whatever already has the default route. Changing it has no effect on live rules.
- `ROUTING_TABLE` is validated against `/etc/iproute2/rt_tables` (rejects kernel-reserved tables and numbers already used by another named table).
- `EXTERNAL_DNS` and `LOG_FILE` accept an empty value (`""`) to restore their defaults (DHCP-assigned DNS / logging disabled).
- `REFRESH_INTERVAL` (minutes) rewrites `OnUnitActiveSec` in the installed `llx-external-routes-refresh.timer` unit and runs `systemctl daemon-reload` + `systemctl restart llx-external-routes-refresh.timer` to apply it immediately. `install.sh` and the `.deb` postinst also apply whatever `REFRESH_INTERVAL` is in `config.conf` to the timer at install time.

### Master switch (`enable`/`disable`)

There's no persistent background process to start/stop: the NetworkManager dispatcher only runs on interface up/down events, and the refresh service is a `oneshot` triggered by the systemd timer (which does have real `systemctl start|stop llx-external-routes-refresh.timer`, see [Useful commands](#useful-commands)). To turn routing off altogether without touching Wi-Fi or the timer, use the `ENABLED` master switch:

```bash
sudo llx-exroute-cli disable   # removes live rules now, and stops NM/refresh from re-adding them
sudo llx-exroute-cli enable    # re-applies immediately if EXTERNAL_IFACE is up
```

`llx-exroute-cli list` shows the current state (`Routing: enabled` / `Routing: DISABLED`). Missing or empty `ENABLED` is treated as enabled (the pre-existing default behavior).

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

# List configured domains/IPs
llx-exroute-cli list

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

Traffic to 172.28.222.250 (listed in IPS):
  → No DNS resolution needed
  → ip rule: "if destination is 172.28.222.250, use table 100"
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
