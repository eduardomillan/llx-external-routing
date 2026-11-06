# Changelog

## [0.3] - 2026-11-06

### Added

- `IPS` config variable: route literal IPv4 addresses/CIDRs through external WiFi, bypassing DNS resolution (useful for non-domain targets like `172.28.222.250`).
- `llx-exroute-cli` CLI: `list`, `add domain|ip`, `remove domain|ip`. Edits `config.conf` and applies the change immediately via `refresh-external-routes`.
- `llx-exroute-cli get|set` for the rest of `config.conf` (`CORPORATE_IFACE`, `EXTERNAL_IFACE`, `ROUTING_TABLE`, `EXTERNAL_DNS`, `REFRESH_INTERVAL`, `LOG_FILE`, `VERBOSE`). `EXTERNAL_IFACE`/`ROUTING_TABLE` tear down the old table before applying.
- `llx-exroute-cli get` (no key, or `get all`) dumps every supported config value at once.
- `ENABLED` master switch in `config.conf`, managed via `llx-exroute-cli enable`/`disable`: disables routing fully (NetworkManager events and the refresh timer leave rules untouched while `ENABLED=0`) without touching Wi-Fi or the systemd timer. `disable` tears down live rules immediately; `enable` re-applies them if the external interface is up. Missing/empty `ENABLED` defaults to enabled.

### Changed

- The shipped `config.conf` template now ships with `DOMAINS=""` instead of real example domains (`tailscale.com`, `anydesk.com`, `facebook.com`, `fbcdn.net`). A fresh install no longer silently starts routing those out of the box; the previous values are now just an `# Example:` comment, matching how `IPS` already shipped empty. This only affects a brand-new `/etc/llx-external-routes/config.conf` — an existing one is left alone by `install.sh`, and dpkg's own conffile handling prompts (and defaults to keeping yours) on upgrade if you've edited it.

### Fixed

- `REFRESH_INTERVAL` is now actually wired to the systemd timer (`OnUnitActiveSec`): previously it was declared in `config.conf` but never read by any script, so changing it did nothing. `install.sh` and the `.deb` postinst now apply it to the timer unit at install time, and `llx-exroute-cli set REFRESH_INTERVAL <minutes>` applies it live.

### Changed

- Extracted shared logic (`log_msg`, DNS/gateway lookups, domain resolution) from both scripts into `scripts/lib/common-routing.sh`, sourced by both `llx-external-routing-dispatcher` and `refresh-external-routes`, to remove duplication.

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
