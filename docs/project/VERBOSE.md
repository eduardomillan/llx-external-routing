# VERBOSE Levels

There are **3 levels** of `VERBOSE` defined in `conf/config.conf` (default: `1`).
The `log_msg()` function in both scripts compares the message level against `VERBOSE` — it only prints if `VERBOSE >= level`.

---

## Level 0 — Critical errors only

Only shown if `VERBOSE >= 0` (always, unless set to 0 or empty).

**Dispatcher** (`scripts/llx-external-routing-dispatcher`):
- Line 101: `ERROR: Could not get gateway for $EXTERNAL_IFACE`

**Refresh** (`scripts/refresh-external-routes`):
- Line 102: `ERROR: Could not get gateway for $EXTERNAL_IFACE`

---

## Level 1 — Operational (default)

Shown when `VERBOSE=1` (current default). Includes everything from level 0, plus:

**Dispatcher:**
| Line | Message |
|------|---------|
| 202 | `Dispatcher executed: interface=$IFACE action=$ACTION` |
| 96 | `Setting up external routing for interface $EXTERNAL_IFACE` |
| 101 | `ERROR: Could not get gateway...` |
| 104 | `External gateway: $gw` |
| 116 | `Default route added in table $ROUTING_TABLE via $gw` |
| 127 | `External routing configured successfully` |
| 163 | `WARNING: Could not resolve $domain` |
| 174 | `Domain $domain -> <IP list>` |
| 182 | `Removing external routing for interface $EXTERNAL_IFACE` |
| 195 | `External routing removed` |

**Refresh:**
| Line | Message |
|------|---------|
| 89 | `Starting external route refresh` |
| 92 | `Interface $EXTERNAL_IFACE is not up, skipping refresh` |
| 102 | `ERROR: Could not get gateway...` |
| 106 | `External gateway: $local_gw` |
| 136 | `WARNING: Could not resolve $domain` |
| 147 | `$domain -> <IP list>` |
| 153 | `Refresh completed` |

---

## Level 2 — Detailed / Verbose

Only shown when `VERBOSE=2`. Includes everything from levels 0 and 1, plus:

**Dispatcher:**
| Line | Message |
|------|---------|
| 149 | `DNS rule added: $dns -> table $ROUTING_TABLE` |
| 158 | `Resolving domain: $domain` |
| 171 | `Rule added: $ip -> table $ROUTING_TABLE ($domain)` |

**Refresh:**
| Line | Message |
|------|---------|
| 124 | `DNS rule: $dns -> table $ROUTING_TABLE` |
| 132 | `Resolving: $domain` |
| 144 | `Rule: $ip -> table $ROUTING_TABLE ($domain)` |

---

## Quick reference

| VERBOSE | What is shown | Recommended use |
|---------|---------------|-----------------|
| `0` | Fatal errors only | Production, minimal disk writes |
| `1` | Errors + full setup/teardown/refresh cycle | **Default** — balance between traceability and noise |
| `2` | All of the above + every DNS rule, every resolved domain, every individual IP added | Diagnostics/debug |

Logs are written to `/var/log/llx-external-routing.log` and also sent to syslog/journald via `logger -t llx-external-routing`.
