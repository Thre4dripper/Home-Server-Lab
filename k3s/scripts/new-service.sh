#!/usr/bin/env bash
set -euo pipefail
# new-service.sh — Interactive scaffolder for new k3s services.
#
# Generates: deployment.yaml, service.yaml, ingress.yaml, pvc.yaml,
#            secret.yaml (template), and setup.sh — all matching the
#            conventions used in this repo.
#
# Usage: ./new-service.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APPS_DIR="$REPO_ROOT/apps"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}  >${NC} $*"; }
ok()      { echo -e "${GREEN}  ✓${NC} $*"; }
warn()    { echo -e "${YELLOW}  !${NC} $*"; }
prompt()  { echo -en "${CYAN}  $1${NC} "; }
section() { echo -e "\n${BOLD}$*${NC}"; }

# ─── Input helpers ─────────────────────────────────────────────────────────────

ask() {
  # ask <variable_name> <prompt> [default]
  local varname="$1" msg="$2" default="${3:-}"
  if [[ -n "$default" ]]; then
    prompt "$msg [${default}]: "
  else
    prompt "$msg: "
  fi
  local val
  IFS= read -r val
  val="${val:-$default}"
  if [[ -z "$val" ]]; then
    echo -e "  ${RED}Required.${NC}" && ask "$varname" "$msg" "$default"
    return
  fi
  printf -v "$varname" '%s' "$val"
}

ask_yn() {
  # ask_yn <prompt> — returns exit code 0=yes 1=no
  local msg="$1" default="${2:-y}"
  prompt "$msg [${default}]: "
  local val; IFS= read -r val
  val="${val:-$default}"
  [[ "$val" =~ ^[Yy] ]]
}

pick_namespace() {
  # List existing namespaces and offer to create a new one
  local existing
  existing=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null \
    | tr ' ' '\n' \
    | grep -vE '^kube-|^traefik$|^default$' \
    | sort || echo "dashboard-network monitoring downloads media file-management automation databases")

  echo -e "\n  ${CYAN}Available namespaces:${NC}"
  local i=1 ns_list=()
  while IFS= read -r ns; do
    echo "    $i) $ns"
    ns_list+=("$ns")
    (( i++ ))
  done <<< "$existing"
  echo "    $i) [create new namespace]"

  prompt "Pick number or type a name: "
  local choice; IFS= read -r choice

  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    local idx=$(( choice - 1 ))
    if [[ $idx -lt ${#ns_list[@]} ]]; then
      NAMESPACE="${ns_list[$idx]}"
    else
      ask NAMESPACE "New namespace name"
      NAMESPACE_IS_NEW=true
    fi
  else
    NAMESPACE="$choice"
  fi
}

# ─── File generators ──────────────────────────────────────────────────────────

gen_deployment() {
  local has_pvc="$1" has_secret="$2"
  local vol_block="" mount_block="" secret_block="" env_block=""

  if [[ "$has_pvc" == "true" ]]; then
    mount_block="          volumeMounts:
            - name: data
              mountPath: /data"
    vol_block="      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${APP}-data"
  fi

  if [[ "$has_secret" == "true" ]]; then
    secret_block="          envFrom:
            - secretRef:
                name: ${APP}-secret"
  fi

  cat > "$OUT_DIR/deployment.yaml" << YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP}
  namespace: ${NAMESPACE}
  labels:
    app: ${APP}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: ${APP}
  template:
    metadata:
      labels:
        app: ${APP}
    spec:
      containers:
        - name: ${APP}
          image: ${IMAGE}
          ports:
            - containerPort: ${CONTAINER_PORT}
              name: web
          env:
            - name: TZ
              value: "UTC"
${secret_block}
${mount_block}
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              memory: 512Mi
${vol_block}
YAML
  # Clean up blank lines left by empty blocks
  sed -i '/^$/N;/^\n$/d' "$OUT_DIR/deployment.yaml"
  ok "deployment.yaml"
}

gen_service() {
  cat > "$OUT_DIR/service.yaml" << YAML
apiVersion: v1
kind: Service
metadata:
  name: ${APP}
  namespace: ${NAMESPACE}
spec:
  type: LoadBalancer
  selector:
    app: ${APP}
  ports:
    - name: web
      port: ${EXTERNAL_PORT}
      targetPort: ${CONTAINER_PORT}
      protocol: TCP
YAML
  ok "service.yaml  (LoadBalancer → :${EXTERNAL_PORT})"
}

gen_ingress() {
  cat > "$OUT_DIR/ingress.yaml" << YAML
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ${APP}
  namespace: ${NAMESPACE}
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`${DOMAIN}\`)
      kind: Rule
      services:
        - name: ${APP}
          port: ${EXTERNAL_PORT}
YAML
  ok "ingress.yaml  (http://${DOMAIN})"
}

gen_pvc() {
  cat > "$OUT_DIR/pvc.yaml" << YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${APP}-data
spec:
  capacity:
    storage: ${STORAGE_SIZE}
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: ${STORAGE_PATH}/${APP}/data
    type: DirectoryOrCreate
  claimRef:
    name: ${APP}-data
    namespace: ${NAMESPACE}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${APP}-data
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ""
  volumeName: ${APP}-data
  resources:
    requests:
      storage: ${STORAGE_SIZE}
YAML
  ok "pvc.yaml  (${STORAGE_PATH}/${APP}/data, ${STORAGE_SIZE})"
}

gen_secret_template() {
  cat > "$OUT_DIR/secret.yaml" << YAML
apiVersion: v1
kind: Secret
metadata:
  name: ${APP}-secret
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  # Add your secret key-value pairs below, then run: ./setup.sh seal
  # Example:
  #   ADMIN_PASSWORD: "changeme"
  #   API_KEY: "changeme"
YAML
  ok "secret.yaml  (⚠ edit this, then run: ./setup.sh seal)"
}

gen_namespace() {
  cat > "$OUT_DIR/../../../base/namespaces/namespaces.yaml.patch" << YAML
# Add this to k3s/base/namespaces/namespaces.yaml:
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    category: ${NAMESPACE}
YAML
  warn "New namespace — add to k3s/base/namespaces/namespaces.yaml (see patch file)"
}

gen_setup_sh() {
  local has_pvc="$1" has_secret="$2" has_ingress="$3" has_cm="$4" has_rbac="$5"
  # Depth from APPS_DIR determines relative path to scripts/
  local depth; depth=$(echo "$OUT_DIR" | sed "s|$APPS_DIR||" | tr -dc '/' | wc -c)
  local scripts_rel=""
  for (( i=0; i<depth; i++ )); do scripts_rel="../$scripts_rel"; done
  scripts_rel="${scripts_rel}../scripts"   # one more up from apps/ to k3s/

  cat > "$OUT_DIR/setup.sh" << BASH
#!/usr/bin/env bash
set -euo pipefail

# ─── App Configuration ───────────────────────────────────────────────────────
APP="${APP}"
NAMESPACE="${NAMESPACE}"
CONTAINER_PORT="${CONTAINER_PORT}"
EXTERNAL_PORT="${EXTERNAL_PORT}"
DOMAIN="${DOMAIN}"
DEFAULT_SHELL="sh"

# Components this app uses
HAS_PVC=${has_pvc}
HAS_SECRET=${has_secret}
HAS_INGRESS=${has_ingress}
HAS_CONFIGMAP=${has_cm}
HAS_RBAC=${has_rbac}

# ─────────────────────────────────────────────────────────────────────────────
DEPLOY_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
NODE_IP="\${K3S_NODE_IP:-\$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo '192.168.0.108')}"

_find_scripts() {
  local d="\$1"
  while [[ "\$d" != "/" ]]; do
    [[ -d "\$d/scripts" && -f "\$d/scripts/_app-ctl.sh" ]] && echo "\$d/scripts" && return
    d="\$(dirname "\$d")"
  done
}
SCRIPTS_DIR="\$(_find_scripts "\$DEPLOY_DIR")"
[[ -z "\$SCRIPTS_DIR" ]] && { echo "ERROR: k3s/scripts/_app-ctl.sh not found"; exit 1; }

# shellcheck source=../../scripts/_app-ctl.sh
source "\$SCRIPTS_DIR/_app-ctl.sh"
main "\$@"
BASH
  chmod +x "$OUT_DIR/setup.sh"
  ok "setup.sh"
}

# ─── Main flow ────────────────────────────────────────────────────────────────

clear
echo -e "${BOLD}${CYAN}"
echo "  ┌──────────────────────────────────────────────┐"
echo "  │  New k3s Service Scaffolder                  │"
echo "  │  Home Server Lab                             │"
echo "  └──────────────────────────────────────────────┘"
echo -e "${NC}"

# ── Basic info ────────────────────────────────────────────────────────────────
section "1. Basic Info"
ask APP      "App name (lowercase, hyphens ok)"
ask IMAGE    "Docker image (e.g. nginx:latest)"
ask CONTAINER_PORT "Container port"

# ── Namespace ──────────────────────────────────────────────────────────────────
section "2. Namespace"
NAMESPACE_IS_NEW=false
pick_namespace
echo -e "  ${GREEN}Using namespace:${NC} $NAMESPACE"

# ── External access ────────────────────────────────────────────────────────────
section "3. External Access"
EXTERNAL_PORT=""
DOMAIN=""

if ask_yn "Expose via LoadBalancer (direct IP:port access)?" "y"; then
  ask EXTERNAL_PORT "External port (e.g. 8600)"

  if ask_yn "Route via Traefik domain (e.g. myapp.lan)?" "y"; then
    ask DOMAIN "Domain name"
  fi
else
  info "No external access — ClusterIP only (internal services, databases)"
fi

# ── Persistent storage ────────────────────────────────────────────────────────
section "4. Persistent Storage"
HAS_PVC=false
STORAGE_PATH=""
STORAGE_SIZE=""

if ask_yn "Does this app need persistent storage?" "y"; then
  HAS_PVC=true
  echo -e "  Storage backends:"
  echo "    1) pendrive  — /home/pi/pendrive/k3s-data  (exFAT, 234GB)"
  echo "    2) ext4      — /home/pi/db-data            (ext4, for databases only)"
  prompt "Pick [1/2]: "
  local choice; IFS= read -r choice
  case "$choice" in
    2) STORAGE_PATH="/home/pi/db-data" ;;
    *) STORAGE_PATH="/home/pi/pendrive/k3s-data" ;;
  esac
  ask STORAGE_SIZE "Storage size (e.g. 2Gi)" "2Gi"
fi

# ── Secret ────────────────────────────────────────────────────────────────────
section "5. Secrets"
HAS_SECRET=false
if ask_yn "Does this app need a secret (passwords, API keys, tokens)?" "n"; then
  HAS_SECRET=true
fi

# ── Confirm ───────────────────────────────────────────────────────────────────
section "Summary"
echo -e "  App:        ${BOLD}$APP${NC}"
echo   "  Namespace:  $NAMESPACE"
echo   "  Image:      $IMAGE  (port $CONTAINER_PORT)"
[[ -n "$EXTERNAL_PORT" ]] && echo "  Service:    LoadBalancer :$EXTERNAL_PORT"
[[ -n "$DOMAIN" ]]         && echo "  Ingress:    http://$DOMAIN"
$HAS_PVC    && echo "  Storage:    $STORAGE_PATH/$APP/data ($STORAGE_SIZE)"
$HAS_SECRET && echo "  Secret:     yes (template generated)"
echo ""

if ! ask_yn "Generate files?" "y"; then
  echo "Aborted."; exit 0
fi

# ── Generate ──────────────────────────────────────────────────────────────────
OUT_DIR="$APPS_DIR/$APP"
if [[ -d "$OUT_DIR" ]]; then
  warn "Directory already exists: $OUT_DIR"
  if ! ask_yn "Overwrite?" "n"; then
    echo "Aborted."; exit 0
  fi
fi
mkdir -p "$OUT_DIR"

section "Generating files in k3s/apps/$APP/"

gen_deployment "$HAS_PVC" "$HAS_SECRET"
[[ -n "$EXTERNAL_PORT" ]] && gen_service
[[ -n "$DOMAIN" ]]         && gen_ingress
$HAS_PVC    && gen_pvc
$HAS_SECRET && gen_secret_template
$NAMESPACE_IS_NEW && gen_namespace
gen_setup_sh "$HAS_PVC" "$HAS_SECRET" \
  "$([[ -n "$DOMAIN" ]] && echo true || echo false)" \
  "false" "false"

chmod +x "$OUT_DIR/setup.sh"

# ── Next steps ────────────────────────────────────────────────────────────────
section "Next Steps"
echo ""
echo -e "  ${CYAN}cd k3s/apps/$APP${NC}"
echo ""

if $HAS_SECRET; then
  echo "  1. Edit secret.yaml with your actual values:"
  echo "     nano secret.yaml"
  echo ""
  echo "  2. Seal it (encrypts for git):"
  echo "     ./setup.sh seal"
  echo ""
  echo "  3. Deploy:"
  echo "     ./setup.sh deploy"
else
  echo "  1. Deploy:"
  echo "     ./setup.sh deploy"
fi

if [[ -n "$DOMAIN" ]]; then
  echo ""
  echo "  + Add DNS in Pi-hole admin → Local DNS:"
  echo "    IP: 192.168.0.108   Domain: $DOMAIN"
fi

if $NAMESPACE_IS_NEW; then
  echo ""
  warn "New namespace '$NAMESPACE' — add it to k3s/base/namespaces/namespaces.yaml"
  echo "    kubectl apply -f k3s/base/namespaces/namespaces.yaml  (after editing)"
fi

echo ""
ok "Done — $APP scaffolded at k3s/apps/$APP/"
echo ""
