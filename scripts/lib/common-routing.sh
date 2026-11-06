# =============================================================================
# common-routing.sh
# Shared helpers for llx-external-routing-dispatcher and refresh-external-routes.
# Must be sourced after config.conf; expects $ROUTING_TABLE, $EXTERNAL_IFACE,
# $EXTERNAL_DNS, $DOMAINS, $IPS, $LOG_FILE, $VERBOSE, $IPSETS_DIR and $LOG_TAG
# to already be set by the caller.
# =============================================================================

log_msg() {
    local level="$1"
    shift
    local msg="$*"
    if [[ "${VERBOSE:-0}" -ge "$level" ]]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local line="[$timestamp] [${LOG_TAG:-llx}] $msg"
        if [[ -n "${LOG_FILE:-}" ]]; then
            mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
            echo "$line" >> "$LOG_FILE" 2>/dev/null || true
        fi
        logger -t llx-external-routing "$msg" 2>/dev/null || true
    fi
}

is_external_up() {
    local state
    state=$(cat "/sys/class/net/$EXTERNAL_IFACE/operstate" 2>/dev/null || echo "down")
    [[ "$state" == "up" ]]
}

# ENABLED=0 fully disables routing; missing/empty defaults to enabled.
is_routing_enabled() {
    [[ "${ENABLED:-1}" != "0" ]]
}

# Removes all "ip rule"/"ip route" entries for a routing table and drops
# it from /etc/iproute2/rt_tables.
teardown_table() {
    local table="$1"
    while ip rule del table "$table" 2>/dev/null; do :; done
    ip route flush table "$table" 2>/dev/null || true
    if grep -q "^$table " /etc/iproute2/rt_tables 2>/dev/null; then
        sed -i "/^$table /d" /etc/iproute2/rt_tables 2>/dev/null || true
    fi
}

get_external_gateway() {
    local gw
    gw=$(nmcli -t -f IP4.GATEWAY device show "$EXTERNAL_IFACE" 2>/dev/null | head -1 | sed 's/^IP4.GATEWAY://')
    if [[ -z "$gw" ]]; then
        gw=$(ip route show dev "$EXTERNAL_IFACE" default 2>/dev/null | awk '/default/ {print $3}' | head -1)
    fi
    echo "$gw"
}

get_external_dns() {
    if [[ -n "${EXTERNAL_DNS:-}" ]]; then
        echo "$EXTERNAL_DNS"
        return
    fi
    nmcli -t -f IP4.DNS device show "$EXTERNAL_IFACE" 2>/dev/null | \
        sed 's/^IP4.DNS\[[0-9]*\]://' | sort -u | tr '\n' ' '
}

resolve_domain() {
    local domain="$1"
    local ips=""
    local resolved
    resolved=$(dig +short +time=3 +tries=1 "$domain" A 2>/dev/null | grep -E '^[0-9]+\.' || true)
    if [[ -n "$resolved" ]]; then
        ips="$resolved"
    fi
    resolved=$(dig +short +time=3 +tries=1 "www.$domain" A 2>/dev/null | grep -E '^[0-9]+\.' || true)
    if [[ -n "$resolved" ]]; then
        ips="$ips $resolved"
    fi
    echo "$ips" | tr ' ' '\n' | sort -uV | grep -v '^$' || true
}

# Validates a literal IPv4 address, optionally with a /prefix (CIDR notation).
is_valid_ipv4_cidr() {
    local target="$1"
    local ip="${target%%/*}"
    local prefix=""
    if [[ "$target" == *"/"* ]]; then
        prefix="${target#*/}"
    fi

    [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1

    local octet
    local IFS=.
    for octet in $ip; do
        (( octet <= 255 )) || return 1
    done

    if [[ -n "$prefix" ]]; then
        [[ "$prefix" =~ ^[0-9]{1,2}$ ]] || return 1
        (( prefix <= 32 )) || return 1
    fi

    return 0
}

# Resolves $DOMAINS, saves each domain's IPs under $IPSETS_DIR, and adds
# "ip rule" entries routing them through $ROUTING_TABLE.
add_domain_rules() {
    local domain
    for domain in ${DOMAINS:-}; do
        log_msg 2 "Resolving domain: $domain"
        local ips
        ips=$(resolve_domain "$domain")

        if [[ -z "$ips" ]]; then
            log_msg 1 "WARNING: Could not resolve $domain"
            continue
        fi

        echo "$ips" > "$IPSETS_DIR/${domain}.ips"

        local ip
        for ip in $ips; do
            ip rule add to "$ip" table "$ROUTING_TABLE" priority 20 2>/dev/null || true
            log_msg 2 "Rule added: $ip -> table $ROUTING_TABLE ($domain)"
        done

        log_msg 1 "Domain $domain -> $(echo "$ips" | tr '\n' ' ')"
    done
}

# Adds "ip rule" entries for literal IPs/CIDRs listed in $IPS, bypassing DNS.
add_static_ip_rules() {
    local target
    for target in ${IPS:-}; do
        if ! is_valid_ipv4_cidr "$target"; then
            log_msg 0 "WARNING: Invalid entry in IPS, skipping: $target"
            continue
        fi

        ip rule add to "$target" table "$ROUTING_TABLE" priority 20 2>/dev/null || true
        log_msg 1 "Static IP $target -> table $ROUTING_TABLE"
    done
}
