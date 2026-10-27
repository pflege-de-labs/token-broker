#!/usr/bin/env bash
# Egress allowlist for the agent workspace; runs as root on every container start.
# Only domains in /etc/agent-firewall/domains resolve, and only their IPs are reachable.
# Based on anthropics/claude-code .devcontainer/init-firewall.sh. See docs/containers.md.
set -euo pipefail

conf=/etc/agent-firewall
# Root-owned, from the image: the agent must not choose what gets allowed.
domains=$(grep -v -e '^#' -e '^$' $conf/domains | paste -sd/ -)

# Re-runs find 127.0.0.1 in resolv.conf, so remember the container's own resolver.
upstream=$(awk '/^nameserver/ && $2 !~ /:/ && $2 != "127.0.0.1" {print $2}' /etc/resolv.conf)
if [ -n "$upstream" ]; then echo "$upstream" >$conf/upstream; else upstream=$(cat $conf/upstream); fi

pkill -x dnsmasq || true
# The old instance must release port 53 before the new one binds.
timeout 5 sh -c 'while ss -Hlnu "sport = :53" | grep -q .; do sleep 0.1; done'
# Filter table only; nat keeps Docker's embedded DNS working.
iptables -F
iptables -X
# Kept on re-runs: running processes still hold connections to IPs in it.
ipset create -exist allowed hash:net

{
  echo "listen-address=127.0.0.1"
  echo "bind-interfaces"
  # No default server: names outside the allowlist get no answer, so DNS cannot tunnel out.
  echo "no-resolv"
  for ns in $upstream; do echo "server=/$domains/$ns"; done
  # Every resolved IP joins the set, so rotating CDN addresses keep working.
  echo "ipset=/$domains/allowed"
} >$conf/dnsmasq.conf

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
for ns in $upstream; do
  for proto in udp tcp; do
    iptables -A OUTPUT -d "$ns" -p $proto --dport 53 -m owner --uid-owner dnsmasq -j ACCEPT
  done
done
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed dst -j ACCEPT
# Reject rather than drop, so blocked calls fail fast instead of hanging.
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# No IPv6 allowlist: block it entirely, or it would bypass the rules above.
ip6tables -F
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP

dnsmasq --conf-file=$conf/dnsmasq.conf --user=dnsmasq
# Rewritten in place: resolv.conf is a bind mount and cannot be replaced.
{ grep -v '^nameserver' /etc/resolv.conf || true; echo "nameserver 127.0.0.1"; } >$conf/resolv
cat $conf/resolv >/etc/resolv.conf

if curl -fsS --connect-timeout 5 -o /dev/null https://example.com 2>/dev/null; then
  echo "ERROR: firewall check failed, example.com is reachable" >&2; exit 1
fi
curl -fsS --connect-timeout 5 -o /dev/null https://api.github.com/zen \
  || { echo "ERROR: firewall check failed, api.github.com is blocked" >&2; exit 1; }
echo "Firewall active: egress limited to $conf/domains."
