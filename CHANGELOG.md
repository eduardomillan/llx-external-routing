# Changelog

## [0.2] - 2026-07-13

### Fixed

- Fixed config file lookup: scripts now search `/etc/llx-external-routes/config.conf` (system path) first, falling back to relative path for development.
- Fixed gateway parsing: `nmcli -t` output includes field prefix (`IP4.GATEWAY:10.187.207.145`), now stripped correctly.
- Fixed DNS parsing: `nmcli -t` outputs `IP4.DNS[n]:` with brackets, regex updated.
- Fixed domain: `anydesk.net` (non-existent) corrected to `anydesk.com`.

## [0.1] - 2026-07-13

### Added

- NetworkManager dispatcher for automatic routing setup on WiFi connect/disconnect.
- Selective domain-based routing: route specific domains through external WiFi while default traffic goes through corporate interface.
- Configurable network interfaces (`CORPORATE_IFACE`, `EXTERNAL_IFACE`) via config file.
- Configurable domain list (initial: tailscale, anydesk, facebook).
- Systemd timer for periodic IP refresh (default every 15 minutes).
- DNS resolution for `www.` subdomains included automatically.
- Configuration file at `/etc/llx-external-routes/config.conf` (preserved on upgrades).
- Verbose logging to `/var/log/llx-external-routing.log` with configurable verbosity levels.
- Debian package (`.deb`) for easy installation and removal.
- Automatic cleanup of routing rules when external WiFi disconnects.
