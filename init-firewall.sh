#!/bin/bash
# scc egress firewall — default-deny with a small allowlist.
# Runs as root from the entrypoint, before privileges are dropped.
# Requires NET_ADMIN + NET_RAW; the `scc` launcher adds these automatically
# whenever the firewall is enabled.
#
# Allowed egress:
#   * DNS, only to the resolvers configured in /etc/resolv.conf
#   * GitHub (its published IP ranges from api.github.com/meta)
#   * Anthropic/Claude endpoints, npm registry, PyPI
#   * anything in FIREWALL_EXTRA_DOMAINS (comma-separated)
#
# Known limits: domains are resolved to IPs once at container start, so CDN
# rotation can break an allowed host mid-session (restart the container to
# refresh), and DNS to the configured resolvers remains a narrow side channel.
set -euo pipefail

ALLOWED_DOMAINS="api.anthropic.com claude.ai statsig.anthropic.com statsig.com sentry.io registry.npmjs.org pypi.org files.pythonhosted.org"
EXTRA="${FIREWALL_EXTRA_DOMAINS:-}"

echo "scc-firewall: configuring default-deny egress..."

# Start clean. Chain policies are still ACCEPT here, so the fetches below work.
iptables -F
ipset destroy scc-allow 2>/dev/null || true
ipset create scc-allow hash:net family inet

# GitHub publishes its IP ranges; fetch them while egress is still open.
GH_META="$(curl -fsSL --max-time 15 https://api.github.com/meta)" || {
    echo "scc-firewall: ERROR: could not fetch GitHub IP ranges" >&2
    exit 1
}
printf '%s' "$GH_META" \
    | jq -r '.git[]?, .api[]?, .web[]?, .packages[]?, .pages[]?' \
    | grep -v ':' \
    | while read -r cidr; do ipset add scc-allow "$cidr" -exist; done

# Resolve allowlisted domains to their current IPv4 addresses.
for domain in $ALLOWED_DOMAINS ${EXTRA//,/ }; do
    for ip in $(dig +short A "$domain"); do
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            ipset add scc-allow "$ip/32" -exist
        fi
    done
done

# Base rules: loopback, established connections, DNS to configured resolvers.
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
while read -r ns; do
    iptables -A OUTPUT -d "$ns" -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -d "$ns" -p tcp --dport 53 -j ACCEPT
done < <(awk '/^nameserver[ \t]/ {print $2}' /etc/resolv.conf | grep -v ':' || true)

iptables -A OUTPUT -m set --match-set scc-allow dst -j ACCEPT

# Everything else: reject fast, DROP policy as backstop.
iptables -A OUTPUT -j REJECT --reject-with icmp-port-unreachable
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  DROP

# Close IPv6 entirely if present, so it can't be used as a bypass.
if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -F              2>/dev/null || true
    ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
    ip6tables -A INPUT  -i lo -j ACCEPT 2>/dev/null || true
    ip6tables -P INPUT   DROP 2>/dev/null || true
    ip6tables -P FORWARD DROP 2>/dev/null || true
    ip6tables -P OUTPUT  DROP 2>/dev/null || true
fi

# Verify: an allowlisted host must be reachable, an arbitrary one must not.
curl -fsS --max-time 10 https://api.github.com/zen >/dev/null || {
    echo "scc-firewall: ERROR: github.com unreachable after setup" >&2
    exit 1
}
if curl -fsS --max-time 5 https://example.com >/dev/null 2>&1; then
    echo "scc-firewall: ERROR: egress NOT blocked (example.com reachable)" >&2
    exit 1
fi
echo "scc-firewall: active (GitHub, Anthropic, npm, PyPI + extras allowed)"
