#!/usr/bin/env bash
set -euo pipefail

# ─── App Configuration ───────────────────────────────────────────────────────
APP="mongodb"
NAMESPACE="databases"
CONTAINER_PORT="27017"
EXTERNAL_PORT=""
DOMAIN=""
DEFAULT_SHELL="bash"

HAS_PVC=true
HAS_SECRET=true
HAS_INGRESS=false
HAS_CONFIGMAP=true
HAS_RBAC=false

# ─────────────────────────────────────────────────────────────────────────────
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_IP="${K3S_NODE_IP:-$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | tr ' ' '\n' | grep -v ':' | head -1 || echo '192.168.0.108')}"

_find_scripts() {
  local d="$1"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/scripts" && -f "$d/scripts/_db-ctl.sh" ]] && echo "$d/scripts" && return
    d="$(dirname "$d")"
  done
}
SCRIPTS_DIR="$(_find_scripts "$DEPLOY_DIR")"
[[ -z "$SCRIPTS_DIR" ]] && { echo "ERROR: k3s/scripts/_db-ctl.sh not found"; exit 1; }

# shellcheck source=../../scripts/_db-ctl.sh
source "$SCRIPTS_DIR/_db-ctl.sh"

# ─── MongoDB-specific hooks ──────────────────────────────────────────────────

# Reads & URL-encodes the password so it can be embedded in a URI.
_mongo_password() {
  kubectl get secret mongodb-secret -n "$NAMESPACE" \
    -o jsonpath='{.data.MONGO_INITDB_ROOT_PASSWORD}' | base64 -d | \
    sed 's/!/%21/g; s/@/%40/g; s/:/%3A/g; s|/|%2F|g'
}

_db_connection_string() {
  local scope="${1:-external}"
  local user; user="$(kubectl get secret mongodb-secret -n "$NAMESPACE" -o jsonpath='{.data.MONGO_INITDB_ROOT_USERNAME}' | base64 -d)"
  local pass; pass="$(_mongo_password)"

  case "$scope" in
    external)
      echo "mongodb://${user}:${pass}@mongo-0.home.ijlalahmad.dev,mongo-1.home.ijlalahmad.dev,mongo-2.home.ijlalahmad.dev:27017/?replicaSet=rs0&tls=true&authSource=admin"
      echo ""
      info "TLS uses Let's Encrypt \u2014 no CA file needed (trusted by OS / Compass / DataGrip out of the box)."
      info "For a plaintext connection, use: ./setup.sh connection-string internal (no TLS) or append &tls=false."
      ;;
    internal)
      echo "mongodb://${user}:${pass}@mongodb.databases.svc.cluster.local:27017/?replicaSet=rs0&authSource=admin"
      ;;
    *)
      err "Usage: ./setup.sh connection-string [external|internal]"; exit 1 ;;
  esac
}

_db_dump_cmd() {
  local out="$1"
  local pod; pod="$(_get_pod)"
  [[ -z "$pod" ]] && { err "No running mongodb pod"; exit 1; }
  kubectl exec -n "$NAMESPACE" "$pod" -- bash -c \
    'mongodump --quiet --uri="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@localhost:27017/?authSource=admin" --archive --gzip' > "$out"
}

_db_restore_cmd() {
  local in="$1"
  local pod; pod="$(_get_pod)"
  [[ -z "$pod" ]] && { err "No running mongodb pod"; exit 1; }
  kubectl exec -i -n "$NAMESPACE" "$pod" -- bash -c \
    'mongorestore --quiet --uri="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@localhost:27017/?authSource=admin" --archive --gzip --drop' < "$in"
}

db_main "$@"
