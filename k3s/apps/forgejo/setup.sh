#!/usr/bin/env bash
set -euo pipefail

# ─── App Configuration ───────────────────────────────────────────────────────
APP="forgejo"
NAMESPACE="git"
CONTAINER_PORT="3000"
EXTERNAL_PORT="8900"
DOMAIN="forgejo.home.ijlalahmad.dev"
DEFAULT_SHELL="sh"

# Components this app uses
HAS_PVC=true
HAS_SECRET=true
HAS_INGRESS=true
HAS_CONFIGMAP=false
HAS_RBAC=false

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

# ─── First-time setup notes ──────────────────────────────────────────────────
# 1. Generate proper secrets before sealing:
#      openssl rand -hex 32   # use output for FORGEJO_SECRET_KEY
#      openssl rand -hex 32   # use output for FORGEJO_INTERNAL_TOKEN
#    Edit secret.yaml with these values, then run: ./setup.sh seal
#
# 2. SQLite DB is stored at /data/gitea/forgejo.db on the PVC — no external DB needed.
#
# 3. SSH clone URL: git@forgejo.home.ijlalahmad.dev -p 30022
#
# 4. After first login, disable open registration:
#    Site Admin → Management → Disable self-registration
#    OR set FORGEJO__service__DISABLE_REGISTRATION=true and redeploy
