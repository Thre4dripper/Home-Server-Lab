#!/usr/bin/env bash
# ArgoCD management script
# Usage: ./setup.sh <command>
# Commands: status | logs | restart | update | resources | events | password | help
set -euo pipefail

NAMESPACE="argocd"
DOMAIN="argocd.lan"
NODE_IP="${K3S_NODE_IP:-$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | tr ' ' '\n' | grep -v ':' | head -1 || echo '192.168.0.108')}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
header() { echo -e "\n${CYAN}${BOLD}━━━ $* ${NC}"; }
ok()     { echo -e "${GREEN}[OK]${NC}    $*"; }
info()   { echo -e "${BLUE}[INFO]${NC}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# All ArgoCD core deployments/statefulsets
COMPONENTS=(argocd-server argocd-repo-server argocd-application-controller argocd-applicationset-controller argocd-redis)

cmd_status() {
  header "Pods — argocd"
  kubectl get pods -n "$NAMESPACE" \
    -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp' \
    2>/dev/null || echo "  No pods found"

  header "Services"
  kubectl get svc -n "$NAMESPACE" 2>/dev/null

  header "IngressRoute"
  kubectl get ingressroute -n "$NAMESPACE" 2>/dev/null || echo "  None"

  header "Resource Usage (live)"
  kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "  (metrics-server unavailable)"

  header "Access"
  echo "  Domain  : http://$DOMAIN"
  echo "  User    : admin"
  echo "  Pass    : run './setup.sh password' to retrieve"
}

cmd_logs() {
  local component="${1:-argocd-server}"
  local args=("${@:2}")
  local pod
  pod=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$component" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [[ -z "$pod" ]]; then
    warn "No pod found for component: $component"
    echo "  Available: argocd-server | argocd-repo-server | argocd-application-controller | argocd-redis"
    exit 1
  fi
  info "Logs for $pod"
  kubectl logs -n "$NAMESPACE" "$pod" "${args[@]}"
}

cmd_restart() {
  info "Restarting ArgoCD components..."
  for c in argocd-server argocd-repo-server argocd-applicationset-controller; do
    kubectl rollout restart deployment/"$c" -n "$NAMESPACE"
  done
  kubectl rollout restart statefulset/argocd-application-controller -n "$NAMESPACE"
  echo ""
  info "Waiting for rollouts..."
  for c in argocd-server argocd-repo-server argocd-applicationset-controller; do
    kubectl rollout status deployment/"$c" -n "$NAMESPACE" --timeout=120s
  done
  ok "All components restarted"
}

cmd_update() {
  local version="${1:-}"
  if [[ -z "$version" ]]; then
    warn "Usage: ./setup.sh update <helm-chart-version>"
    echo "  Check versions: helm search repo argo/argo-cd --versions | head -5"
    exit 1
  fi
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  info "Upgrading ArgoCD to chart version $version..."
  helm upgrade argocd argo/argo-cd \
    -n "$NAMESPACE" \
    --version "$version" \
    -f "$SCRIPT_DIR/../../infra/argocd/values.yaml"
  ok "Upgrade complete"
}

cmd_resources() {
  header "Live Resource Usage — argocd"
  kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "  (metrics-server unavailable)"

  header "Configured Requests & Limits"
  for c in argocd-server argocd-repo-server argocd-applicationset-controller argocd-redis; do
    echo "  $c:"
    kubectl get deployment "$c" -n "$NAMESPACE" -o jsonpath='    requests: cpu={.spec.template.spec.containers[0].resources.requests.cpu}  memory={.spec.template.spec.containers[0].resources.requests.memory}{"\n"}    limits:   cpu={.spec.template.spec.containers[0].resources.limits.cpu}  memory={.spec.template.spec.containers[0].resources.limits.memory}{"\n"}' 2>/dev/null || echo "    (not found)"
  done
}

cmd_events() {
  header "Events — argocd (latest 20)"
  kubectl get events -n "$NAMESPACE" \
    --sort-by='.lastTimestamp' 2>/dev/null | tail -20 | \
    awk '{
      if ($5 == "Warning") printf "\033[0;31m%s\033[0m\n", $0
      else print
    }'
}

cmd_password() {
  header "ArgoCD Admin Password"
  local pass
  pass=$(kubectl get secret argocd-initial-admin-secret -n "$NAMESPACE" \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
  if [[ -n "$pass" ]]; then
    echo "  User: admin"
    echo "  Pass: $pass"
    echo ""
    warn "Change this password after first login:"
    echo "  ArgoCD UI → User Info → Update Password"
    echo "  (Once changed, the initial-admin-secret can be deleted)"
  else
    info "Initial secret already deleted — password was changed via UI"
  fi
}

cmd_apps() {
  header "ArgoCD Applications"
  kubectl get applications -n "$NAMESPACE" 2>/dev/null || echo "  No applications deployed yet"
  echo ""
  kubectl get appprojects -n "$NAMESPACE" 2>/dev/null | grep -v "^default" || true
}

cmd_help() {
  echo -e "\n${BOLD}ArgoCD — management script${NC}\n"
  echo -e "  ${CYAN}./setup.sh status${NC}          All pods, services, resource usage"
  echo -e "  ${CYAN}./setup.sh logs${NC} [component] Logs for a component (default: argocd-server)"
  echo -e "  ${CYAN}./setup.sh restart${NC}          Rolling restart of all ArgoCD components"
  echo -e "  ${CYAN}./setup.sh update${NC} <version>  Helm upgrade to a specific chart version"
  echo -e "  ${CYAN}./setup.sh resources${NC}         CPU/memory usage + configured limits"
  echo -e "  ${CYAN}./setup.sh events${NC}            Namespace events (warnings in red)"
  echo -e "  ${CYAN}./setup.sh password${NC}          Print initial admin password"
  echo -e "  ${CYAN}./setup.sh apps${NC}              List ArgoCD applications and projects"
  echo ""
  echo -e "  Components: argocd-server | argocd-repo-server | argocd-application-controller | argocd-redis"
  echo ""
  echo -e "  ${BOLD}Access:${NC}  http://$DOMAIN   (user: admin)"
}

case "${1:-help}" in
  status)    cmd_status ;;
  logs)      cmd_logs "${@:2}" ;;
  restart)   cmd_restart ;;
  update)    cmd_update "${@:2}" ;;
  resources) cmd_resources ;;
  events)    cmd_events ;;
  password)  cmd_password ;;
  apps)      cmd_apps ;;
  help|--help|-h) cmd_help ;;
  *)
    warn "Unknown command: $1"
    cmd_help
    exit 1
    ;;
esac
