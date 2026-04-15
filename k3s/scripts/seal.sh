#!/usr/bin/env bash
set -euo pipefail
# seal.sh — Seal a secret.yaml into a sealedsecret.yaml using the cluster's public cert.
#
# Usage:
#   ./seal.sh <path/to/secret.yaml>   Seal one file
#   ./seal.sh --all                   Seal all secret.yaml files under k3s/apps/
#   ./seal.sh --fetch-cert            Re-fetch public cert from the cluster (auto-done on first run)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERT="$REPO_ROOT/infra/sealed-secrets/public-cert.pem"
CONTROLLER_NAME="sealed-secrets-controller"
CONTROLLER_NS="kube-system"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*"; }

_check_deps() {
  for cmd in kubectl kubeseal; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Required command not found: $cmd"
      [[ "$cmd" == "kubeseal" ]] && echo "  Install: see k3s/scripts/cluster-restore.sh"
      exit 1
    fi
  done
}

_ensure_cert() {
  if [[ ! -f "$CERT" ]]; then
    warn "Public cert not found at $CERT — fetching from cluster..."
    mkdir -p "$(dirname "$CERT")"
    kubeseal \
      --controller-name="$CONTROLLER_NAME" \
      --controller-namespace="$CONTROLLER_NS" \
      --fetch-cert > "$CERT"
    ok "Cert fetched → $CERT  (safe to commit to git)"
  fi
}

seal_one() {
  local input="$1"

  # Resolve to absolute path
  [[ "$input" != /* ]] && input="$PWD/$input"

  if [[ ! -f "$input" ]]; then
    error "File not found: $input"; return 1
  fi
  if [[ "$(basename "$input")" != "secret.yaml" ]]; then
    error "Expected a file named 'secret.yaml', got: $(basename "$input")"
    return 1
  fi

  local output; output="$(dirname "$input")/sealedsecret.yaml"

  info "Sealing: $input"
  # Use kubectl create --dry-run=client (NOT apply) to normalise stringData → data (base64).
  # 'apply --dry-run=client' merges with the existing cluster resource, so the old 'data:' field
  # wins over the new 'stringData:', causing re-seals to silently encrypt the old password.
  # 'create --dry-run=client' has no merge step — it always converts fresh from the local file.
  kubectl create --dry-run=client -o yaml -f "$input" 2>/dev/null | \
    kubeseal \
      --controller-name="$CONTROLLER_NAME" \
      --controller-namespace="$CONTROLLER_NS" \
      --cert "$CERT" \
      --format yaml > "$output"

  ok "→ $(dirname "$input")/sealedsecret.yaml"
}

seal_all() {
  local count=0 failed=0
  info "Sealing all secret.yaml files under $REPO_ROOT/apps/ ..."
  echo ""
  while IFS= read -r f; do
    if seal_one "$f"; then
      (( count++ )) || true
    else
      (( failed++ )) || true
    fi
  done < <(find "$REPO_ROOT/apps" -name "secret.yaml" | sort)
  echo ""
  ok "Done — $count sealed, $failed failed"
}

fetch_cert() {
  info "Re-fetching public cert from cluster..."
  mkdir -p "$(dirname "$CERT")"
  kubeseal \
    --controller-name="$CONTROLLER_NAME" \
    --controller-namespace="$CONTROLLER_NS" \
    --fetch-cert > "$CERT"
  ok "Cert saved → $CERT"
  echo ""
  openssl x509 -in "$CERT" -noout -dates 2>/dev/null || true
}

show_usage() {
  echo "Usage:"
  echo "  $(basename "$0") <path/to/secret.yaml>   Seal a single secret"
  echo "  $(basename "$0") --all                   Seal all secret.yaml files in apps/"
  echo "  $(basename "$0") --fetch-cert            Re-fetch public cert from cluster"
  echo ""
  echo "Notes:"
  echo "  • sealedsecret.yaml is written next to the input secret.yaml"
  echo "  • secret.yaml is gitignored; sealedsecret.yaml is safe to commit"
  echo "  • Public cert is cached at: $CERT"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
_check_deps

case "${1:-}" in
  --all)        _ensure_cert; seal_all ;;
  --fetch-cert) fetch_cert ;;
  ""|-h|--help) show_usage ;;
  *)            _ensure_cert; seal_one "$1" ;;
esac
