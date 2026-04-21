#!/usr/bin/env bash
set -euo pipefail

# ─── App Configuration ───────────────────────────────────────────────────────
APP="homepage"
NAMESPACE="dashboard-network"
CONTAINER_PORT="3000"
EXTERNAL_PORT="8600"
DOMAIN="homepage.home.ijlalahmad.dev"
DEFAULT_SHELL="sh"

# Components this app uses
HAS_PVC=false
HAS_SECRET=true
HAS_INGRESS=true
HAS_CONFIGMAP=true
HAS_RBAC=true

# ─────────────────────────────────────────────────────────────────────────────
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_IP="${K3S_NODE_IP:-$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | tr ' ' '\n' | grep -v ':' | head -1 || echo '192.168.0.108')}"

_find_scripts() {
  local d="$1"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/scripts" && -f "$d/scripts/_app-ctl.sh" ]] && echo "$d/scripts" && return
    d="$(dirname "$d")"
  done
}
SCRIPTS_DIR="$(_find_scripts "$DEPLOY_DIR")"
[[ -z "$SCRIPTS_DIR" ]] && { echo "ERROR: k3s/scripts/_app-ctl.sh not found"; exit 1; }

# shellcheck source=../../scripts/_app-ctl.sh
source "$SCRIPTS_DIR/_app-ctl.sh"
main "$@"
