#!/usr/bin/env bash
set -euo pipefail

# ─── App Configuration ───────────────────────────────────────────────────────
APP="vaultwarden"
NAMESPACE="security"
CONTAINER_PORT="8080"
EXTERNAL_PORT="9200"
DOMAIN="vault.home.ijlalahmad.dev"
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

# =============================================================================
# First-time setup notes
# =============================================================================
#
# 1. Deploy, then open https://vault.home.ijlalahmad.dev and create the account.
#    Pick Argon2id as the KDF (Settings → Security → Keys), not the PBKDF2
#    default.
#
# 2. REQUIRED: flip SIGNUPS_ALLOWED to "false" in deployment.yaml and commit.
#    Until you do, anyone on the LAN can register on your vault.
#
# 3. Point clients at the server BEFORE logging in — the server URL cannot be
#    changed on an already-signed-in client:
#      Browser extension / mobile app → login screen → "Logging in on" dropdown
#      → Self-hosted → https://vault.home.ijlalahmad.dev
#    No cert install needed; the Let's Encrypt wildcard is publicly trusted.
#
# 4. Mobile push (vault sync + "log in with device" approvals):
#    a. Get PUSH_INSTALLATION_ID / _KEY from https://bitwarden.com/host
#    b. Put them in secret.yaml, then:  ./setup.sh seal
#    c. Deploy, then LOG OUT AND BACK IN on every client — that is how push
#       tokens get registered. Existing sessions will never receive push.
#    Order matters: seal BEFORE deploying or pushing. deployment.yaml has
#    PUSH_ENABLED=true and references vaultwarden-secret, so the pod will sit
#    in CreateContainerConfigError until the SealedSecret exists.
#    Note: push needs an app-store build — F-Droid has no Firebase Messaging.
#
# -----------------------------------------------------------------------------
# Taking a consistent backup by hand
# -----------------------------------------------------------------------------
#   ./setup.sh shell
#   /vaultwarden backup          # VACUUM INTO → /data/db_YYYYMMDD_HHMMSS.sqlite3
#
# Backrest runs this nightly via its pre-backup hook; see k3s/apps/backrest.
#
# -----------------------------------------------------------------------------
# Restoring
# -----------------------------------------------------------------------------
#   ./setup.sh disable                   # stop the writer first
#   # restore the data dir from restic, then inside it:
#   #   mv db_YYYYMMDD_HHMMSS.sqlite3 db.sqlite3
#   #   rm -f db.sqlite3-wal             # MUST go, or you get a torn db
#   ./setup.sh enable
#
# Attachments, sends/ and rsa_key.pem are plain files in the same directory and
# come back with it. Deleting rsa_key.pem only logs every client out.
#
# -----------------------------------------------------------------------------
# Enabling the admin panel (temporarily)
# -----------------------------------------------------------------------------
# Deliberately off: /admin writes config.json, whose values then override the
# env vars in deployment.yaml — so the cluster stops matching git. If you need
# it, prefer doing so briefly and removing it afterwards:
#
#   docker run --rm -it vaultwarden/server /vaultwarden hash   # Argon2 PHC
#   # add the $argon2id$... string to secret.yaml as ADMIN_TOKEN, re-seal,
#   # then reference it from deployment.yaml with a secretKeyRef
#   ./setup.sh seal
#
# Never store ADMIN_TOKEN as plaintext. Afterwards, delete /data/config.json so
# the env vars regain authority.
