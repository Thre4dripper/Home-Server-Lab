#!/usr/bin/env bash
set -euo pipefail

# ─── App Configuration ───────────────────────────────────────────────────────
APP="immich"
NAMESPACE="media"
CONTAINER_PORT="2283"
EXTERNAL_PORT="9100"
DOMAIN="immich.home.ijlalahmad.dev"
DEFAULT_SHELL="bash"

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
# 0. Host prep (on the Pi):
#      findmnt /home/pi/pendrive          # pendrive MUST be mounted
#      mkdir -p /home/pi/pendrive/immich  # media PV is type Directory (fail-closed)
#    The SD-side dirs (thumbs, ml-cache) are DirectoryOrCreate — kubelet
#    creates them automatically.
#
# 1. Database (shared cluster Postgres — needs the vchord-enabled image, see
#    k3s/databases/postgres/README.md):
#      k3s/scripts/db-user.sh postgres create immich_user '<STRONG_PASS>' immich
#      kubectl exec -n databases deploy/postgres -- psql -U postgres -d immich -c \
#        "CREATE EXTENSION IF NOT EXISTS vchord CASCADE;
#         CREATE EXTENSION IF NOT EXISTS cube;
#         CREATE EXTENSION IF NOT EXISTS earthdistance;"
#    immich_user is NOT superuser: after any future vchord image bump run
#      kubectl exec -n databases deploy/postgres -- psql -U postgres -d immich \
#        -c "ALTER EXTENSION vchord UPDATE;"
#
# 2. Secrets — put in secret.yaml (gitignored), then ./setup.sh seal:
#      DB_PASSWORD   the immich_user password from step 1
#      TUNNEL_TOKEN  Cloudflare Zero Trust → Networks → Tunnels →
#                    create remote-managed tunnel → copy token.
#                    Use a placeholder until you have it.
#    (Queues use the dedicated in-namespace valkey — no redis password needed.)
#
# 3. Cloudflare tunnel (public access):
#    a. Create the tunnel (step 2) and add a public hostname:
#         photos.ijlalahmad.dev → http://immich.media.svc.cluster.local:9100
#    b. Re-seal with the real TUNNEL_TOKEN, then set replicas: 1 in
#       cloudflared-deployment.yaml (starts at 0 on purpose).
#
# 4. Machine learning pause/resume (RAM guardrail):
#      git-managed:  edit ml-deployment.yaml replicas 0/1  (ArgoCD-safe)
#      transient:    kubectl scale deploy/immich-machine-learning -n media --replicas=0
#                    (ArgoCD selfHeal will revert it on next sync)
#
# 5. NOTE: this setup.sh manages only the `immich` server Deployment.
#    The sibling workloads are managed with kubectl directly:
#      kubectl -n media logs deploy/immich-machine-learning -f
#      kubectl -n media logs deploy/immich-cloudflared -f
#
# 6. After first login (web UI at https://immich.home.ijlalahmad.dev):
#    - Admin → Settings → Job settings: concurrency thumbs 2, metadata 2,
#      smart search 1, face detection 1, transcode 1 (Pi headroom)
#    - Admin → Settings → Server: external domain https://photos.ijlalahmad.dev
#    - Per-user storage quotas (users can't fill the pendrive)
#    - Leave built-in DB dumps OFF — the shared Postgres cluster is already
#      dump-backed by Backrest
