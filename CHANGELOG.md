# Changelog

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
