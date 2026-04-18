#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="dashboard-network"
APP_NAME="homepage"

echo "╔══════════════════════════════════════════════╗"
echo "║         Homepage Dashboard - k3s Setup       ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Check prerequisites ──────────────────────────────────────────────────────
if ! command -v kubectl &>/dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v kubeseal &>/dev/null; then
    echo "⚠️  kubeseal not found — you'll need it to seal secrets."
    echo "   Install: https://github.com/bitnami-labs/sealed-secrets#kubeseal"
fi

# ── Create namespace (if needed) ─────────────────────────────────────────────
echo "📦 Ensuring namespace '${NAMESPACE}' exists..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# ── Seal secrets ─────────────────────────────────────────────────────────────
echo ""
echo "🔐 Sealing API key secrets..."
echo "   You need to provide API keys for optional widgets."
echo ""

read -rp "   Finnhub API key (stocks widget, get free key at https://finnhub.io/): " FINNHUB_KEY
read -rp "   Portainer API key (optional, press Enter to skip): " PORTAINER_KEY
read -rp "   Jellyfin API key (optional, press Enter to skip): " JELLYFIN_KEY

FINNHUB_KEY="${FINNHUB_KEY:-placeholder}"
PORTAINER_KEY="${PORTAINER_KEY:-placeholder}"
JELLYFIN_KEY="${JELLYFIN_KEY:-placeholder}"

echo ""
echo "   Generating SealedSecret..."

kubectl create secret generic homepage-secret \
    --namespace="${NAMESPACE}" \
    --from-literal=HOMEPAGE_VAR_FINNHUB_KEY="${FINNHUB_KEY}" \
    --from-literal=HOMEPAGE_VAR_PORTAINER_KEY="${PORTAINER_KEY}" \
    --from-literal=HOMEPAGE_VAR_JELLYFIN_KEY="${JELLYFIN_KEY}" \
    --dry-run=client -o yaml | kubeseal --format yaml > "${SCRIPT_DIR}/secret.yaml"

echo "   ✅ SealedSecret written to secret.yaml"

# ── Apply manifests ──────────────────────────────────────────────────────────
echo ""
echo "🚀 Applying manifests..."
kubectl apply -f "${SCRIPT_DIR}/rbac.yaml"
kubectl apply -f "${SCRIPT_DIR}/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/secret.yaml"
kubectl apply -f "${SCRIPT_DIR}/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/service.yaml"
kubectl apply -f "${SCRIPT_DIR}/ingress.yaml"

# ── Wait for rollout ─────────────────────────────────────────────────────────
echo ""
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=120s

# ── Print access info ────────────────────────────────────────────────────────
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
LB_PORT=$(kubectl get svc ${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].port}')

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║          ✅ Homepage is running!             ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  HTTPS: https://homepage.home.ijlalahmad.dev║"
echo "║  LB:    http://${NODE_IP}:${LB_PORT}        ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "💡 Tip: If using ArgoCD, push to git instead of manual apply."
echo "   The ApplicationSet will auto-sync the homepage app."
