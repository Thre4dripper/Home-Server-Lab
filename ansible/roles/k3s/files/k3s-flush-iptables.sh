#!/bin/sh
# Flush only the K3s/flannel iptables rules without touching running containers
# or network namespaces. Safe to run while pods are live.
#
# k3s-killall.sh is too destructive for a cable-reconnect scenario: it tears
# down CNI veth interfaces and kills containerd shims, breaking any open pty
# sessions (VS Code terminals, SSH multiplexers) inside pod namespaces.
#
# This script only removes the specific chain rules that flannel/kube-proxy
# re-populate on K3s restart, which is all that's needed to unblock iptables
# after a link bounce.

set -e

flush_chains() {
    TOOL=$1  # iptables or ip6tables

    # Flush KUBE-* and CNI-* and FLANNEL-* rules in the filter table
    for chain in $($TOOL -t filter -L --line-numbers -n 2>/dev/null | awk '/^Chain (KUBE-|CNI-|FLANNEL-)/{print $2}'); do
        $TOOL -t filter -F "$chain" 2>/dev/null || true
        $TOOL -t filter -X "$chain" 2>/dev/null || true
    done

    # Flush KUBE-* rules in nat table
    for chain in $($TOOL -t nat -L --line-numbers -n 2>/dev/null | awk '/^Chain (KUBE-|CNI-|FLANNEL-)/{print $2}'); do
        $TOOL -t nat -F "$chain" 2>/dev/null || true
        $TOOL -t nat -X "$chain" 2>/dev/null || true
    done

    # Remove jump rules in built-in chains pointing to K3s chains
    for chain in PREROUTING INPUT FORWARD OUTPUT POSTROUTING; do
        for table in filter nat; do
            $TOOL -t "$table" -S "$chain" 2>/dev/null \
              | grep -E '\-j (KUBE-|CNI-|FLANNEL-)' \
              | sed 's/^-A/-D/' \
              | while read -r rule; do
                  $TOOL -t "$table" $rule 2>/dev/null || true
                done
        done
    done
}

flush_chains iptables
flush_chains ip6tables
