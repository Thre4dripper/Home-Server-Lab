#!/usr/bin/env bash
# _app-ctl.sh — Shared Kubernetes app management library
#
# Sourced by each per-app setup.sh. Do NOT execute directly.
# The sourcing setup.sh must set these variables before sourcing this file:
#
#   APP            deployment/pod label name (e.g. "homarr")
#   NAMESPACE      kubernetes namespace
#   DEPLOY_DIR     absolute path to the app's manifest directory
#   DOMAIN         domain name for access display (or "" if none)
#   EXTERNAL_PORT  LoadBalancer external port (or "" if none/hostNetwork)
#   CONTAINER_PORT container listening port
#   DEFAULT_SHELL  shell to use for exec (default: sh)
#   HAS_PVC        true/false — app has persistent storage
#   HAS_SECRET     true/false — app has a SealedSecret
#   HAS_INGRESS    true/false — app has an IngressRoute
#   HAS_CONFIGMAP  true/false — app has a ConfigMap
#   HAS_RBAC       true/false — app has RBAC manifests

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

info()   { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()     { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()    { echo -e "${RED}[ERR]${NC}   $*"; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $* ${NC}"; }
dim()    { echo -e "${DIM}$*${NC}"; }

# ─── Internal helpers ─────────────────────────────────────────────────────────

# Get the first running pod name for APP in NAMESPACE
_get_pod() {
  kubectl get pods -n "$NAMESPACE" -l app="$APP" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

# Get ANY pod (including non-running) for crash inspection
_get_any_pod() {
  kubectl get pods -n "$NAMESPACE" -l app="$APP" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

# Exit if no running pod found, otherwise echo the pod name
_require_running() {
  local pod; pod="$(_get_pod)"
  if [[ -z "$pod" ]]; then
    err "No running pod found for $APP in $NAMESPACE"
    info "Hint: ./setup.sh status  — to see what's wrong"
    info "Hint: ./setup.sh events  — to see k8s events"
    exit 1
  fi
  echo "$pod"
}

# Apply manifests in correct dependency order
_apply_ordered() {
  local files=(pvc.yaml configmap.yaml sealedsecret.yaml rbac.yaml deployment.yaml service.yaml ingress.yaml)
  for f in "${files[@]}"; do
    if [[ -f "$DEPLOY_DIR/$f" ]]; then
      kubectl apply -f "$DEPLOY_DIR/$f" > /dev/null
      echo -e "  ${GREEN}✓${NC} $f"
    fi
  done
}

# Delete manifests in reverse dependency order
_delete_ordered() {
  local files=(ingress.yaml service.yaml deployment.yaml rbac.yaml sealedsecret.yaml configmap.yaml)
  for f in "${files[@]}"; do
    if [[ -f "$DEPLOY_DIR/$f" ]]; then
      kubectl delete -f "$DEPLOY_DIR/$f" --ignore-not-found=true > /dev/null
      echo -e "  ${GREEN}✓${NC} deleted $f"
    fi
  done
}

# Resolve the k3s/scripts directory (works at any nesting depth)
_find_scripts_dir() {
  local d="$1"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/scripts" && -f "$d/scripts/_app-ctl.sh" ]] && echo "$d/scripts" && return
    d="$(dirname "$d")"
  done
  echo ""
}

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_deploy() {
  echo -e "\n${BOLD}Deploying ${CYAN}$APP${NC}${BOLD} → ${CYAN}$NAMESPACE${NC}\n"
  _apply_ordered
  echo ""

  if kubectl get deployment "$APP" -n "$NAMESPACE" &>/dev/null; then
    # Force a rollout restart so pods always pick up the latest Secret/ConfigMap values.
    # kubectl apply only restarts pods when the Deployment spec changes; a Secret value
    # change is invisible to the Deployment spec, so pods would keep the stale env vars
    # until the next natural restart. rollout restart bumps the restartedAt annotation,
    # triggering a new ReplicaSet and fresh env injection on every deploy.
    kubectl rollout restart deployment/"$APP" -n "$NAMESPACE" > /dev/null
    info "Waiting for rollout (timeout: 120s)..."
    if kubectl rollout status deployment/"$APP" -n "$NAMESPACE" --timeout=120s; then
      ok "Rollout complete"
    else
      warn "Rollout timed out — run: ./setup.sh events"
    fi
  fi
  echo ""
  cmd_status
}

cmd_teardown() {
  local purge=false
  [[ "${1:-}" == "--purge" ]] && purge=true

  # Warn if ArgoCD manages this app
  if kubectl get application "$APP" -n argocd &>/dev/null; then
    warn "ArgoCD manages '$APP' — selfHeal will recreate these resources!"
    info "To pause:   ./setup.sh disable   (sets replicas: 0 in git)"
    info "To remove:  comment out in applicationset.yaml, commit & push"
    echo ""
  fi

  if $purge; then
    echo -e "\n${RED}${BOLD}⚠ WARNING: --purge will permanently delete PVCs and all stored data!${NC}"
    read -r -p "  Type 'yes' to confirm: " confirm
    [[ "$confirm" != "yes" ]] && echo "  Aborted." && return 0
    echo ""
  fi

  info "Removing $APP resources from cluster..."
  _delete_ordered

  if $purge && ${HAS_PVC:-false}; then
    info "Deleting PVCs..."
    kubectl get pvc -n "$NAMESPACE" 2>/dev/null | grep -i "$APP" | awk '{print $1}' | \
      xargs -r kubectl delete pvc -n "$NAMESPACE" --ignore-not-found=true
    info "Deleting PVs..."
    kubectl get pv 2>/dev/null | grep -i "$APP" | awk '{print $1}' | \
      xargs -r kubectl delete pv --ignore-not-found=true
  fi

  ok "Teardown complete"
  echo ""
}

cmd_status() {
  header "Pod(s)"
  kubectl get pods -n "$NAMESPACE" -l app="$APP" \
    -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp,NODE:.spec.nodeName' \
    2>/dev/null || echo "  No pods found"

  header "Deployment"
  kubectl get deployment "$APP" -n "$NAMESPACE" 2>/dev/null || echo "  No deployment found"

  if kubectl get svc "$APP" -n "$NAMESPACE" &>/dev/null; then
    header "Service & Endpoints"
    kubectl get svc "$APP" -n "$NAMESPACE"
    echo ""
    kubectl get endpoints "$APP" -n "$NAMESPACE" 2>/dev/null | tail -1
  fi

  if ${HAS_INGRESS:-false}; then
    header "IngressRoute"
    kubectl get ingressroute "$APP" -n "$NAMESPACE" 2>/dev/null || echo "  No IngressRoute found"
  fi

  if ${HAS_PVC:-false}; then
    header "Storage (PVC / PV)"
    kubectl get pvc -n "$NAMESPACE" 2>/dev/null | grep -i "$APP" || echo "  No PVCs found"
  fi

  header "Resource Usage (live)"
  kubectl top pods -n "$NAMESPACE" -l app="$APP" 2>/dev/null || \
    dim "  (metrics-server unavailable or pod not ready yet)"

  header "Recent Events"
  kubectl get events -n "$NAMESPACE" \
    --sort-by='.lastTimestamp' 2>/dev/null | \
    grep -iE "$APP|Warning|Error|Failed|BackOff|OOM" | tail -8 \
    || dim "  No notable events"

  header "Access"
  [[ -n "${DOMAIN:-}" ]] && echo -e "  Domain  : ${GREEN}http://$DOMAIN${NC}"
  [[ -n "${EXTERNAL_PORT:-}" ]] && echo -e "  Direct  : ${GREEN}http://${NODE_IP:-192.168.0.108}:$EXTERNAL_PORT${NC}"
  [[ -z "${DOMAIN:-}" && -z "${EXTERNAL_PORT:-}" ]] && dim "  (internal-only — no LoadBalancer/Ingress)"
  echo ""
}

cmd_logs() {
  local follow="-f"
  local tail="--tail=100"
  local previous=""
  local extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-follow|-n) follow="" ;;
      --previous|-p)  previous="--previous"; follow="" ;;
      --tail|-t)      tail="--tail=${2:?'--tail requires a number'}"; shift ;;
      -c|--container) extra_args+=("-c" "${2:?'-c requires a container name'}"); shift ;;
      *) extra_args+=("$1") ;;
    esac
    shift
  done

  local pod; pod="$(_get_any_pod)"
  if [[ -z "$pod" ]]; then
    err "No pod found for $APP in $NAMESPACE"; exit 1
  fi

  [[ -n "$previous" ]] && info "Showing logs from previous (crashed) container"
  [[ -n "$follow" ]]   && info "Streaming logs — Ctrl+C to stop"

  kubectl logs $follow $tail $previous "${extra_args[@]}" \
    -n "$NAMESPACE" "$pod"
}

cmd_shell() {
  local pod; pod="$(_require_running)"
  local shell="${1:-${DEFAULT_SHELL:-sh}}"
  info "Opening shell in $pod  (exit with Ctrl+D)"
  kubectl exec -it -n "$NAMESPACE" "$pod" -- "$shell"
}

cmd_restart() {
  info "Restarting $APP (rollout restart)..."
  kubectl rollout restart deployment/"$APP" -n "$NAMESPACE"
  echo ""
  kubectl rollout status deployment/"$APP" -n "$NAMESPACE" --timeout=120s
  ok "Restarted — new pod is live"
}

cmd_rollback() {
  header "Rollout History (before rollback)"
  kubectl rollout history deployment/"$APP" -n "$NAMESPACE"
  echo ""
  info "Rolling back to previous revision..."
  kubectl rollout undo deployment/"$APP" -n "$NAMESPACE"
  echo ""
  kubectl rollout status deployment/"$APP" -n "$NAMESPACE" --timeout=120s
  echo ""
  header "Rollout History (after rollback)"
  kubectl rollout history deployment/"$APP" -n "$NAMESPACE"
  ok "Rolled back"
}

cmd_history() {
  header "Rollout History — $APP"
  kubectl rollout history deployment/"$APP" -n "$NAMESPACE"
}

cmd_update() {
  local new_image="${1:-}"
  if [[ -z "$new_image" ]]; then
    err "Usage: ./setup.sh update <image:tag>"
    echo "  Example: ./setup.sh update ghcr.io/homarr-labs/homarr:v0.15.0"
    exit 1
  fi
  info "Updating $APP → $new_image"
  kubectl set image deployment/"$APP" "$APP=$new_image" -n "$NAMESPACE"
  echo ""
  kubectl rollout status deployment/"$APP" -n "$NAMESPACE" --timeout=120s
  ok "Updated to $new_image"
  echo ""
  cmd_history
}

cmd_scale() {
  local replicas="${1:-}"
  if [[ -z "$replicas" ]] || ! [[ "$replicas" =~ ^[0-9]+$ ]]; then
    err "Usage: ./setup.sh scale <number>"
    echo "  Example (stop):    ./setup.sh scale 0"
    echo "  Example (start):   ./setup.sh scale 1"
    exit 1
  fi
  info "Scaling $APP to $replicas replica(s)..."
  kubectl scale deployment/"$APP" -n "$NAMESPACE" --replicas="$replicas"
  if [[ "$replicas" -gt 0 ]]; then
    kubectl rollout status deployment/"$APP" -n "$NAMESPACE" --timeout=60s
  fi
  ok "Scaled to $replicas"
}

cmd_events() {
  header "Events — $NAMESPACE (latest 30, sorted by time)"
  # Show all events, color warnings red
  kubectl get events -n "$NAMESPACE" \
    --sort-by='.lastTimestamp' \
    -o custom-columns='TIME:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT:.involvedObject.name,MESSAGE:.message' \
    2>/dev/null | tail -31 | \
    awk 'NR==1{print} NR>1{if($2=="Warning") printf "\033[0;31m"; print; printf "\033[0m"}' \
    || dim "  No events in $NAMESPACE"
}

cmd_resources() {
  header "Live Resource Usage — $APP"
  kubectl top pods -n "$NAMESPACE" -l app="$APP" 2>/dev/null || \
    warn "metrics-server unavailable or pod not ready"

  header "Configured Requests & Limits"
  kubectl get deployment "$APP" -n "$NAMESPACE" \
    -o jsonpath='{range .spec.template.spec.containers[*]}  {.name}:{"\n"}    requests: cpu={.resources.requests.cpu}  memory={.resources.requests.memory}{"\n"}    limits:   cpu={.resources.limits.cpu}  memory={.resources.limits.memory}{"\n"}{end}' \
    2>/dev/null || dim "  No resource config found"
  echo ""
}

cmd_describe() {
  header "Deployment — $APP"
  kubectl describe deployment "$APP" -n "$NAMESPACE"

  local pod; pod="$(_get_any_pod)"
  if [[ -n "$pod" ]]; then
    header "Pod — $pod"
    kubectl describe pod "$pod" -n "$NAMESPACE"
  fi
}

cmd_pvc() {
  if ! ${HAS_PVC:-false}; then
    info "$APP has no persistent storage configured"; return
  fi

  header "PersistentVolumeClaims — $NAMESPACE"
  kubectl get pvc -n "$NAMESPACE" 2>/dev/null | grep -i "$APP" || echo "  None found"
  echo ""

  header "PersistentVolumes (host paths)"
  kubectl get pvc -n "$NAMESPACE" 2>/dev/null | grep -i "$APP" | awk '{print $3}' | \
  while IFS= read -r pv_name; do
    echo -e "  PV: ${BOLD}$pv_name${NC}"
    kubectl get pv "$pv_name" -o jsonpath='  ├ Status:   {.status.phase}{"\n"}  ├ Capacity: {.spec.capacity.storage}{"\n"}  └ Path:     {.spec.hostPath.path}{"\n"}' 2>/dev/null
    echo ""
  done
}

# ─── ArgoCD integration ──────────────────────────────────────────────────────

# Find the REPO_ROOT (the directory that contains k3s/)
_find_repo_root() {
  local d="$1"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/k3s" && -d "$d/k3s/apps" ]] && echo "$d" && return
    d="$(dirname "$d")"
  done
  echo ""
}

cmd_sync() {
  header "ArgoCD Sync — $APP"
  if ! kubectl get application "$APP" -n argocd &>/dev/null; then
    warn "No ArgoCD Application named '$APP' found in argocd namespace"
    info "Register it first: kubectl apply -f k3s/infra/argocd/applications/$APP.yaml"
    return 1
  fi
  info "Triggering sync for $APP..."
  kubectl annotate application "$APP" -n argocd \
    argocd.argoproj.io/refresh=hard --overwrite > /dev/null
  # Wait a moment then show status
  sleep 2
  kubectl get application "$APP" -n argocd \
    -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision' \
    2>/dev/null
}

cmd_argocd_status() {
  header "ArgoCD Application — $APP"
  if ! kubectl get application "$APP" -n argocd &>/dev/null; then
    warn "No ArgoCD Application named '$APP' — not yet registered with ArgoCD"
    local repo_root; repo_root="$(_find_repo_root "$DEPLOY_DIR")"
    local app_yaml="$repo_root/k3s/infra/argocd/applications/$APP.yaml"
    if [[ -f "$app_yaml" ]]; then
      info "Application YAML exists: $app_yaml"
      info "Apply it with: kubectl apply -f $app_yaml"
    fi
    return 0
  fi
  kubectl get application "$APP" -n argocd \
    -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision' \
    2>/dev/null
  echo ""
  # Show any sync errors
  local conditions
  conditions=$(kubectl get application "$APP" -n argocd \
    -o jsonpath='{.status.conditions[*].message}' 2>/dev/null)
  [[ -n "$conditions" ]] && warn "Conditions: $conditions"
  # Resources managed by ArgoCD
  header "Managed Resources"
  kubectl get application "$APP" -n argocd \
    -o jsonpath='{range .status.resources[*]}  {.kind}/{.name}  ({.health.status}){"\n"}{end}' \
    2>/dev/null || echo "  (none)"
}

cmd_diff() {
  header "ArgoCD Diff — $APP (live vs git)"
  if ! kubectl get application "$APP" -n argocd &>/dev/null; then
    warn "No ArgoCD Application named '$APP'"; return 1
  fi
  # Use kubectl to trigger a diff via ArgoCD's refresh
  kubectl get application "$APP" -n argocd -o yaml 2>/dev/null | \
    grep -A5 "targetRevision\|syncStatus\|source:" | head -30
  info "Hint: for full diff, use ArgoCD UI → $APP → Diff tab (http://argocd.lan)"
}

cmd_disable() {
  header "Disabling $APP"
  local deploy_file="$DEPLOY_DIR/deployment.yaml"
  if [[ ! -f "$deploy_file" ]]; then
    err "No deployment.yaml found at $DEPLOY_DIR"; return 1
  fi

  local current
  current=$(grep -E '^\s+replicas:' "$deploy_file" | awk '{print $2}' | head -1)
  if [[ "$current" == "0" ]]; then
    warn "$APP is already disabled (replicas: 0)"; return 0
  fi

  sed -i 's/^\(\s*replicas:\s*\)[0-9]*/\10/' "$deploy_file"
  ok "Set replicas: 0 in deployment.yaml"
  echo ""
  info "Commit & push to apply — ArgoCD will scale down automatically"
  echo ""
}

cmd_enable() {
  header "Enabling $APP"
  local deploy_file="$DEPLOY_DIR/deployment.yaml"
  if [[ ! -f "$deploy_file" ]]; then
    err "No deployment.yaml found at $DEPLOY_DIR"; return 1
  fi

  local replicas="${1:-1}"
  local current
  current=$(grep -E '^\s+replicas:' "$deploy_file" | awk '{print $2}' | head -1)
  if [[ "$current" != "0" ]]; then
    warn "$APP is already enabled (replicas: $current)"; return 0
  fi

  sed -i "s/^\(\s*replicas:\s*\)[0-9]*/\1${replicas}/" "$deploy_file"
  ok "Set replicas: $replicas in deployment.yaml"
  echo ""
  info "Commit & push to apply — ArgoCD will start the pod automatically"
  echo ""
}

cmd_seal() {
  if ! ${HAS_SECRET:-false}; then
    info "$APP has no secret to seal"; return
  fi

  local secret="$DEPLOY_DIR/secret.yaml"
  if [[ ! -f "$secret" ]]; then
    err "Not found: $secret"
    info "Create secret.yaml first, then run: ./setup.sh seal"
    exit 1
  fi

  local scripts_dir; scripts_dir="$(_find_scripts_dir "$DEPLOY_DIR")"
  if [[ -z "$scripts_dir" ]]; then
    err "Cannot find k3s/scripts directory"; exit 1
  fi

  bash "$scripts_dir/seal.sh" "$secret"
  echo ""
  ok "Now apply with: ./setup.sh deploy  (or: kubectl apply -f sealedsecret.yaml)"
}

_show_usage() {
  echo -e "\n${BOLD}${CYAN}$APP${NC} — Kubernetes Service Manager\n"
  echo -e "${BOLD}Usage:${NC} ./setup.sh <command> [options]\n"

  echo -e "${CYAN}Deployment:${NC}"
  echo "  deploy                Apply all manifests in correct order"
  echo "  teardown              Remove all k8s resources (warns if ArgoCD-managed)"
  echo "  teardown --purge      Same + delete PVCs/PVs (destroys data!)"
  echo "  scale <n>             Scale to N replicas (cluster-only, ArgoCD may revert)"
  echo "  disable               Set replicas: 0 in git (ArgoCD-safe pause)"
  echo "  enable                Set replicas: 1 in git (ArgoCD-safe resume)"
  echo ""

  echo -e "${CYAN}Monitoring (k8s-native):${NC}"
  echo "  status                Full k8s status: pod, deploy, svc, pvc, resources, events"
  echo "  logs                  Stream pod logs (Ctrl+C to stop)"
  echo "  logs --previous       Logs from last crashed container"
  echo "  logs --tail <N>       Last N lines only"
  echo "  events                All namespace events sorted by time (warnings in red)"
  echo "  resources             kubectl top + configured requests/limits"
  echo "  describe              Full kubectl describe: deployment + pod"
  echo ""

  echo -e "${CYAN}Operations:${NC}"
  echo "  shell [cmd]           Exec into running pod (default: ${DEFAULT_SHELL:-sh})"
  echo "  restart               rollout restart + watch until ready"
  echo "  rollback              rollout undo + show before/after history"
  echo "  history               rollout revision history"
  echo "  update <image:tag>    Set new image and roll out"
  echo ""

  if ${HAS_PVC:-false} || ${HAS_SECRET:-false}; then
    echo -e "${CYAN}Storage / Secrets:${NC}"
    ${HAS_PVC:-false}    && echo "  pvc                   PVC/PV status with host filesystem paths"
    ${HAS_SECRET:-false} && echo "  seal                  Encrypt secret.yaml → sealedsecret.yaml"
    echo ""
  fi

  echo -e "${CYAN}GitOps (ArgoCD):${NC}"
  echo "  argocd-status         ArgoCD sync/health status + managed resources"
  echo "  sync                  Trigger hard refresh + sync from git"
  echo "  diff                  Show drift between live cluster and git"
  echo ""

  echo -e "${CYAN}Access:${NC}"
  [[ -n "${DOMAIN:-}" ]] && echo "  http://$DOMAIN  (via Traefik DNS)"
  [[ -n "${EXTERNAL_PORT:-}" ]] && echo "  http://${NODE_IP:-192.168.0.108}:$EXTERNAL_PORT  (direct IP)"
  [[ -z "${DOMAIN:-}" && -z "${EXTERNAL_PORT:-}" ]] && dim "  Internal only (ClusterIP or hostNetwork)"
  echo ""
}

# ─── Main entry point (called by each app's setup.sh) ────────────────────────
main() {
  case "${1:-help}" in
    deploy)    cmd_deploy ;;
    teardown)  cmd_teardown "${@:2}" ;;
    status)    cmd_status ;;
    logs)      cmd_logs "${@:2}" ;;
    shell)     cmd_shell "${2:-}" ;;
    restart)   cmd_restart ;;
    rollback)  cmd_rollback ;;
    history)   cmd_history ;;
    update)    cmd_update "${2:-}" ;;
    scale)     cmd_scale "${2:-}" ;;
    disable)   cmd_disable ;;
    enable)    cmd_enable "${2:-}" ;;
    events)    cmd_events ;;
    resources) cmd_resources ;;
    describe)  cmd_describe ;;
    pvc)       cmd_pvc ;;
    seal)          cmd_seal ;;
    argocd-status) cmd_argocd_status ;;
    sync)          cmd_sync ;;
    diff)          cmd_diff ;;
    help|--help|-h) _show_usage ;;
    *)
      err "Unknown command: $1"
      echo ""
      _show_usage
      exit 1
      ;;
  esac
}
