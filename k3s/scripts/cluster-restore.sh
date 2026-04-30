#!/usr/bin/env bash
set -euo pipefail
# cluster-restore.sh — Bootstrap or restore a k3s cluster from this git repo.
#
# Run this AFTER a full Pi wipe, hardware replacement, or fresh k3s install.
# The cluster state lives 100% in git (via SealedSecrets) — this script
# applies it all in the correct order and waits for everything to come up.
#
# Usage:
#   ./cluster-restore.sh             Full restore (interactive)
#   ./cluster-restore.sh --check     Preflight checks only
#   ./cluster-restore.sh --infra     Infra only (Sealed Secrets + Traefik)
#   ./cluster-restore.sh --apps      Apps only (assumes infra is ready)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}  [INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}  [ OK ]${NC} $*"; }
warn()    { echo -e "${YELLOW}  [WARN]${NC} $*"; }
err()     { echo -e "${RED}  [ERR ]${NC} $*"; }
step()    { echo -e "\n${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"; \
            echo -e "${CYAN}${BOLD}  $* ${NC}"; \
            echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}\n"; }
ask_yn()  { local msg="$1" def="${2:-y}"; echo -en "${CYAN}  $msg [${def}]: ${NC}"; local v; IFS= read -r v; v="${v:-$def}"; [[ "$v" =~ ^[Yy] ]]; }

SEALED_SECRETS_KEY_BACKUP="/home/pi/sealed-secrets-backup/master-sealing-key.yaml"
CERT_FILE="$REPO_ROOT/infra/sealed-secrets/public-cert.pem"
CONTROLLER_NAME="sealed-secrets-controller"
CONTROLLER_NS="kube-system"
NODE_IP="${K3S_NODE_IP:-192.168.0.108}"

# ─── Preflight ────────────────────────────────────────────────────────────────
check_preflight() {
  step "Preflight Checks"

  local pass=true

  echo -e "  ${BOLD}System:${NC}"
  # k3s
  if kubectl get nodes &>/dev/null; then
    local node_status; node_status=$(kubectl get nodes --no-headers | awk '{print $2}')
    if [[ "$node_status" == "Ready" ]]; then
      ok "k3s running — node is Ready"
    else
      err "k3s node not Ready (status: $node_status)"; pass=false
    fi
  else
    err "kubectl cannot reach cluster — is k3s running?"
    info "Start k3s: sudo systemctl start k3s"
    pass=false
  fi

  # tools
  for cmd in kubectl helm kubeseal; do
    if command -v "$cmd" &>/dev/null; then
      ok "$cmd: $($cmd version --client --short 2>/dev/null | head -1 || echo 'found')"
    else
      err "$cmd not found"
      case "$cmd" in
        helm)      info "Install: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash" ;;
        kubeseal)  info "Install: see k3s/scripts/install-kubeseal.sh or GitHub releases (ARM64)" ;;
      esac
      pass=false
    fi
  done

  echo ""
  echo -e "  ${BOLD}Sealed Secrets backup:${NC}"
  if [[ -f "$SEALED_SECRETS_KEY_BACKUP" ]]; then
    ok "Master key backup found: $SEALED_SECRETS_KEY_BACKUP"
  else
    warn "Master key backup not found at: $SEALED_SECRETS_KEY_BACKUP"
    warn "A NEW key will be generated — existing sealedsecret.yaml files CANNOT be decrypted with a new key"
    info "If you have the backup elsewhere, copy it to: $SEALED_SECRETS_KEY_BACKUP"
  fi

  echo ""
  echo -e "  ${BOLD}Host data directories:${NC}"
  for dir in /home/pi/k3s-volumes/apps /home/pi/k3s-volumes/databases; do
    if [[ -d "$dir" ]]; then
      local free; free=$(df -BG "$dir" | awk 'NR==2{print $4}')
      ok "$dir  ($free free)"
    else
      warn "$dir does not exist — will be created by PV (type: DirectoryOrCreate)"
    fi
  done

  $pass && ok "All preflight checks passed" || { err "Some checks failed — fix before continuing"; return 1; }
}

# ─── Namespaces ───────────────────────────────────────────────────────────────
apply_namespaces() {
  step "1. Namespaces"
  kubectl apply -f "$REPO_ROOT/base/namespaces/namespaces.yaml"
  echo ""
  kubectl get namespaces | grep -vE '^kube-|^default|^NAME'
  ok "Namespaces ready"
}

# ─── Sealed Secrets ───────────────────────────────────────────────────────────
setup_sealed_secrets() {
  step "2. Sealed Secrets Controller"

  # Add helm repo
  helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets 2>/dev/null || true
  helm repo update sealed-secrets > /dev/null

  if helm status "$CONTROLLER_NAME" -n "$CONTROLLER_NS" &>/dev/null; then
    info "Sealed Secrets controller already installed — upgrading..."
    helm upgrade "$CONTROLLER_NAME" sealed-secrets/sealed-secrets \
      -n "$CONTROLLER_NS" \
      --set fullnameOverride="$CONTROLLER_NAME" > /dev/null
    ok "Upgraded"
  else
    info "Installing Sealed Secrets controller..."
    helm install "$CONTROLLER_NAME" sealed-secrets/sealed-secrets \
      -n "$CONTROLLER_NS" \
      --set fullnameOverride="$CONTROLLER_NAME" > /dev/null
    ok "Installed"
  fi

  # Restore the master sealing key (CRITICAL — must happen before controller reads secrets)
  if [[ -f "$SEALED_SECRETS_KEY_BACKUP" ]]; then
    info "Restoring master sealing key from backup..."

    # Wait for controller to be running (it auto-generates a key on first start)
    local attempts=0
    until kubectl get pods -n "$CONTROLLER_NS" -l app.kubernetes.io/name=sealed-secrets \
        --field-selector=status.phase=Running -o name 2>/dev/null | grep -q pod; do
      sleep 3; (( attempts++ ))
      [[ $attempts -gt 20 ]] && { err "Controller pod never started"; exit 1; }
      echo -n "."
    done
    echo ""

    # Delete auto-generated key, apply backup key, restart controller
    kubectl delete secret -n "$CONTROLLER_NS" \
      -l sealedsecrets.bitnami.com/sealed-secrets-key \
      --ignore-not-found=true > /dev/null

    kubectl apply -f "$SEALED_SECRETS_KEY_BACKUP" > /dev/null
    ok "Backup key applied"

    kubectl rollout restart deployment/"$CONTROLLER_NAME" -n "$CONTROLLER_NS" > /dev/null
    kubectl rollout status deployment/"$CONTROLLER_NAME" -n "$CONTROLLER_NS" --timeout=60s
    ok "Controller restarted with restored key"
  else
    warn "No backup key found — controller will generate a NEW key"
    warn "Your existing sealedsecret.yaml files will need to be re-sealed with the new key"
    warn "After restore: run  scripts/seal.sh --all  then  kubectl apply -f each sealedsecret.yaml"

    # Still wait for controller
    kubectl rollout status deployment/"$CONTROLLER_NAME" -n "$CONTROLLER_NS" --timeout=60s
  fi

  # Update/fetch public cert for future sealing
  mkdir -p "$(dirname "$CERT_FILE")"
  kubeseal --controller-name="$CONTROLLER_NAME" \
           --controller-namespace="$CONTROLLER_NS" \
           --fetch-cert > "$CERT_FILE"
  ok "Public cert updated → $CERT_FILE"
}

# ─── Traefik ──────────────────────────────────────────────────────────────────
setup_traefik() {
  step "3. Traefik Ingress Controller"

  helm repo add traefik https://helm.traefik.io/traefik 2>/dev/null || true
  helm repo update traefik > /dev/null

  kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f - > /dev/null

  if helm status traefik -n traefik &>/dev/null; then
    info "Traefik already installed — upgrading from values.yaml..."
    helm upgrade traefik traefik/traefik \
      -n traefik \
      -f "$REPO_ROOT/infra/traefik/values.yaml" > /dev/null
  else
    info "Installing Traefik..."
    helm install traefik traefik/traefik \
      -n traefik \
      -f "$REPO_ROOT/infra/traefik/values.yaml" > /dev/null
  fi

  kubectl rollout status deployment/traefik -n traefik --timeout=60s
  ok "Traefik ready"
}

# ─── Apps ─────────────────────────────────────────────────────────────────────

# Apply one app's directory — handles presence/absence of each manifest type
apply_app() {
  local app_dir="$1"
  local app_name; app_name="$(basename "$app_dir")"

  echo -en "  ${BLUE}$app_name${NC}"

  # Apply in correct dependency order
  local manifests=(pvc.yaml configmap.yaml sealedsecret.yaml rbac.yaml deployment.yaml service.yaml ingress.yaml)
  local applied=0
  for f in "${manifests[@]}"; do
    if [[ -f "$app_dir/$f" ]]; then
      kubectl apply -f "$app_dir/$f" > /dev/null 2>&1 && (( applied++ )) || true
    fi
  done

  echo -e "  ${DIM:-}($applied files)${NC:-}"
}

apply_all_apps() {
  step "4. Applications"

  # Databases first (other apps may depend on them)
  if [[ -d "$REPO_ROOT/databases" ]]; then
    echo -e "  ${BOLD}Databases:${NC}"
    for db_dir in "$REPO_ROOT/databases"/*/; do
      [[ -d "$db_dir" ]] && apply_app "$db_dir"
    done
  fi

  echo ""
  echo -e "  ${BOLD}Apps:${NC}"
  for app_dir in "$REPO_ROOT/apps"/*/; do
    [[ -d "$app_dir" ]] && apply_app "$app_dir"
  done

  ok "All manifests applied"
}

# ─── Wait for rollouts ────────────────────────────────────────────────────────
wait_for_apps() {
  step "5. Waiting for Deployments to Roll Out"

  local failed=0
  while IFS= read -r line; do
    local ns; ns=$(echo "$line" | awk '{print $1}')
    local name; name=$(echo "$line" | awk '{print $2}')
    echo -en "  Waiting for $ns/$name..."
    if kubectl rollout status deployment/"$name" -n "$ns" --timeout=120s > /dev/null 2>&1; then
      echo -e " ${GREEN}✓${NC}"
    else
      echo -e " ${YELLOW}(slow — check: kubectl rollout status deployment/$name -n $ns)${NC}"
      (( failed++ )) || true
    fi
  done < <(kubectl get deployments -A --no-headers 2>/dev/null | \
           grep -vE '^kube-system|^traefik' | \
           awk '{print $1" "$2}')

  [[ "$failed" -eq 0 ]] && ok "All deployments ready" || warn "$failed deployment(s) still rolling out"
}

# ─── Status summary ───────────────────────────────────────────────────────────
print_summary() {
  step "Cluster Status"

  echo -e "  ${BOLD}Pods:${NC}"
  kubectl get pods -A --no-headers 2>/dev/null | \
    grep -vE '^kube-system.*coredns|^kube-system.*metrics|^kube-system.*local-path|^kube-system.*svclb' | \
    awk '{
      status = $4
      color = "\033[0;32m"                              # green = Running
      if (status != "Running") color = "\033[0;33m"    # yellow = other
      if (status == "Error" || status == "CrashLoop") color = "\033[0;31m"  # red
      printf "  %s%-12s  %-30s  %s%s\033[0m\n", color, $1, $2, status, ""
    }'

  echo ""
  echo -e "  ${BOLD}Access URLs:${NC}"
  echo "  Domain (via Traefik :80):"
  for domain in homarr.lan pihole.lan dashdot.lan jellyfin.lan files.lan n8n.lan portainer.lan ha.lan traefik.lan; do
    echo "    http://$domain"
  done
  echo ""
  echo "  Direct IP:port:"
  echo "    http://$NODE_IP:8100   Homarr"
  echo "    http://$NODE_IP:8110   Pi-hole"
  echo "    http://$NODE_IP:8120   Dashdot"
  echo "    http://$NODE_IP:8200   Jellyfin"
  echo "    http://$NODE_IP:8300   Filebrowser"
  echo "    http://$NODE_IP:8400   n8n"
  echo "    http://$NODE_IP:8500   Portainer"
  echo "    http://$NODE_IP:8123   Home Assistant"
  echo ""

  ok "Restore complete!"
  echo ""
  echo -e "  ${YELLOW}Remember:${NC}"
  echo "  • Laptop DNS should be set to $NODE_IP (Pi-hole) only"
  echo "  • If sealing key was NEW, re-seal all secrets: scripts/seal.sh --all"
  echo "  • Backup the sealing key: /home/pi/sealed-secrets-backup/master-sealing-key.yaml"
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
case "${1:-}" in
  --check)
    check_preflight
    ;;
  --infra)
    check_preflight
    apply_namespaces
    setup_sealed_secrets
    setup_traefik
    ;;
  --apps)
    apply_all_apps
    wait_for_apps
    print_summary
    ;;
  "")
    echo -e "\n${BOLD}${CYAN}"
    echo "  ┌──────────────────────────────────────────────┐"
    echo "  │  k3s Cluster Restore                         │"
    echo "  │  Home Server Lab                             │"
    echo "  └──────────────────────────────────────────────┘"
    echo -e "${NC}"
    echo -e "  This will apply all manifests from git to the cluster."
    echo -e "  Existing resources will be updated (idempotent).\n"

    if ! ask_yn "Continue?"; then echo "Aborted."; exit 0; fi
    echo ""

    check_preflight
    apply_namespaces
    setup_sealed_secrets
    setup_traefik
    apply_all_apps
    wait_for_apps
    print_summary
    ;;
  --help|-h)
    echo "Usage: $(basename "$0") [--check | --infra | --apps | --help]"
    echo ""
    echo "  (no flag)  Full restore: preflight → namespaces → infra → apps → status"
    echo "  --check    Preflight checks only (does not modify cluster)"
    echo "  --infra    Infra only: Sealed Secrets controller + Traefik"
    echo "  --apps     Apps only (assumes infra already running)"
    ;;
  *)
    err "Unknown option: $1"; echo "Run with --help for usage."; exit 1 ;;
esac
