#!/usr/bin/env bash
set -euo pipefail

# ─── App Configuration ───────────────────────────────────────────────────────
APP="filebrowser-quantum"
NAMESPACE="file-management"
CONTAINER_PORT="80"
EXTERNAL_PORT="8300"
DOMAIN="files.home.ijlalahmad.dev"
DEFAULT_SHELL="sh"

# Components this app uses
HAS_PVC=true
HAS_SECRET=true
HAS_INGRESS=true
HAS_CONFIGMAP=true
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

# =============================================================================
# First-time setup notes
# =============================================================================
#
# 1. Secrets. The pod will not start until the SealedSecret exists, because
#    every FILEBROWSER_* env var is a required secretKeyRef:
#
#      cp secret.yaml.example secret.yaml
#      # fill in real values — openssl rand -base64 32 for the three random ones
#      ./setup.sh seal            # -> sealedsecret.yaml (commit this)
#
#    Seal BEFORE the first deploy or push, or the pod sits in
#    CreateContainerConfigError.
#
# 2. Deploy, then log in at https://files.home.ijlalahmad.dev as `admin`
#    with FILEBROWSER_ADMIN_PASSWORD. Do NOT change that password in the UI: the
#    backend re-applies it to the admin account on every start while
#    auth.adminPassword is set. Rotate it by resealing the secret instead.
#
# 3. Expect the FIRST START TO BE SLOW. The initial index walks /home/pi and the
#    external drive. A few minutes is normal on a Pi 5 and the UI is usable
#    (just incomplete) while it runs.
#    Watch it with:  ./setup.sh logs
#
#    Subsequent restarts reuse the on-disk index
#    (server.indexSqlConfig.disableReuse: false) and come up in seconds.
#
# -----------------------------------------------------------------------------
# What is actually mounted
# -----------------------------------------------------------------------------
#   Source     Container path      Host path           Mode
#   ------     --------------      ---------           ----
#   Home       /mnt/pi/home        /home/pi            read-write
#   Storage    /mnt/pi/storage     /home/pi/pendrive   read-write
#
# There is deliberately no source for the host root; an earlier revision mounted
# / read-only and it was removed. See the README.
#
# Both mounts use mountPropagation: HostToContainer, so the pendrive being
# remounted on the host AFTER the pod started still shows up inside the pod.
# Without it the pod keeps reading the empty directory under the mountpoint.
#
# Storage is a subtree of Home on disk and stays a separate source on purpose:
# separate disk-usage readout, search scope, permissions and index. It is
# excluded from the Home index with `viewable: true`, which keeps ~/pendrive
# visible in the Home listing while only indexing it once.
#
# -----------------------------------------------------------------------------
# WebDAV
# -----------------------------------------------------------------------------
# Served on the same host at /dav/<source>/<path>, e.g.
#   https://files.home.ijlalahmad.dev/dav/Home/
#
# Basic auth, where the PASSWORD IS AN API TOKEN, not your login password.
# Generate one in the UI: Settings -> Profile -> API tokens. Mount it in Finder
# with Go -> Connect to Server, or in Linux with rclone/davfs2.
#
# Turn it off entirely with http.disableWebDAV: true in config/config.yaml.
#
# -----------------------------------------------------------------------------
# OnlyOffice (in-browser document editing)
# -----------------------------------------------------------------------------
# Ships complete but parked at replicas: 0 — it wants ~2GB RAM, which is a lot
# on an 8GB box. To turn it on:
#
#   1. onlyoffice.yaml:      replicas: 0 -> 1
#   2. config/config.yaml:   userDefaults.preview.office -> true
#   3. commit + push, or ./setup.sh deploy
#
# Give it 1-2 minutes to pass its readiness probe on first boot. It is reachable
# at https://office.home.ijlalahmad.dev, which must stay in sync with
# integrations.office.url in config.yaml.
#
# Note ./setup.sh disable / enable only edit deployment.yaml, so they affect
# FileBrowser alone and leave OnlyOffice untouched.
#
# -----------------------------------------------------------------------------
# Editing the configuration
# -----------------------------------------------------------------------------
# config/config.yaml is rendered into a ConfigMap by kustomize WITH a name
# suffix hash. Editing it changes the ConfigMap name, which changes the pod
# template, which makes ArgoCD roll the pod automatically. Quantum only reads
# its config at startup, so this is the mechanism that makes a pushed config
# change actually take effect.
#
# Preview a change without applying it:
#   kubectl kustomize .
#
# -----------------------------------------------------------------------------
# Migrating from the old filebrowser
# -----------------------------------------------------------------------------
# k3s/apps/filebrowser stores its v1 database at
# /home/pi/k3s-volumes/apps/filebrowser/database/filebrowser.db
#
# To import its users and shares, point server.database.migrateFrom at a COPY of
# that file placed on this app's data volume, then restart once:
#
#   sudo cp /home/pi/k3s-volumes/apps/filebrowser/database/filebrowser.db \
#           /home/pi/k3s-volumes/apps/filebrowser-quantum/data/legacy.db
#   # config/config.yaml: server.database.migrateFrom: "/home/filebrowser/data/legacy.db"
#   ./setup.sh deploy
#
# Clear migrateFrom again afterwards. Verify the users landed before deleting
# anything from the old app — and note that the two use different source
# layouts, so per-user scopes will need revisiting by hand.
#
# -----------------------------------------------------------------------------
# Rebuilding the index from scratch
# -----------------------------------------------------------------------------
# If search results go stale or the index is corrupted:
#
#   ./setup.sh disable          # stop the writer, commit + push
#   sudo rm -rf /home/pi/k3s-volumes/apps/filebrowser-quantum/data/cache/sql
#   ./setup.sh enable
#
# Leave data/filebrowser.sqlite alone — that holds users, shares and settings.
# The cache/sql directory is only the search index and is safe to regenerate.
