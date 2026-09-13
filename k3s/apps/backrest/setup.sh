#!/usr/bin/env bash
set -euo pipefail

# ─── App Configuration ───────────────────────────────────────────────────────
APP="backrest"
NAMESPACE="monitoring"
CONTAINER_PORT="9898"
EXTERNAL_PORT="9898"
DOMAIN="backrest.home.ijlalahmad.dev"
DEFAULT_SHELL="sh"

# Components this app uses
HAS_PVC=true
HAS_SECRET=true
HAS_INGRESS=true
HAS_CONFIGMAP=false
HAS_RBAC=true

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
# Backrest First-Time Configuration
# =============================================================================
# After deployment, open https://backrest.home.ijlalahmad.dev and:
#
# 1. Settings → Authentication → enable auth, create a user.
#
# 2. Add repo: Local Pendrive
#    URI:       /pendrive-backups/restic-repo
#    Password:  <strong password — store it safely, required for CLI restore>
#    Retention: keep-daily=7, keep-weekly=4, keep-monthly=2
#
# 3. (Optional) Add repo: Backblaze B2 / AWS S3
#    URI:  s3:s3.amazonaws.com/<bucket>  OR  b2:<bucket>:/pi-backup
#    Env:  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY  (or B2_ACCOUNT_ID/KEY)
#
# 4. Add backup plan: k3s-volumes
#    Paths:
#      /k3s-volumes          (all app configs and state)
#      /data/db-dumps        (DB dumps written by the pre-backup hook below)
#    Excludes:
#      /k3s-volumes/databases/mongodb   (raw WiredTiger — dump used instead)
#      /k3s-volumes/databases/postgres  (raw WAL — dump used instead)
#    Schedule:  0 21 * * *  (21:00 UTC = 02:30 IST)
#    Repos: local-pendrive (+ S3/B2 if configured)
#
# 5. Add pre-backup hook (type: command, on-before-backup):
# --------------------------------------------------------------------------
# #!/bin/sh
# set -e
# DUMP_DIR=/data/db-dumps
# mkdir -p "$DUMP_DIR"
#
# echo "[hook] Dumping MongoDB..."
# --numParallelCollections 1: serialize collection reads so WiredTiger's
# small cache (0.25 GB) is never split across concurrent cursors, which
# caused eviction pressure that dropped the connection in the past.
# kubectl -n databases exec mongodb-0 -- \
#   mongodump --archive --gzip --numParallelCollections 1 > "$DUMP_DIR/mongo.archive.gz"
#
# echo "[hook] Dumping PostgreSQL..."
# PG_POD=$(kubectl -n databases get pod -l app=postgres \
#   -o jsonpath='{.items[0].metadata.name}')
# kubectl -n databases exec "$PG_POD" -- \
#   pg_dumpall -U postgres | gzip > "$DUMP_DIR/postgres.sql.gz"
#
# echo "[hook] Snapshotting Vaultwarden SQLite..."
# Vaultwarden's own `backup` subcommand runs VACUUM INTO, which folds in any
# pending WAL — so restic never copies a torn database. No sqlite3 binary
# needed, and the output lands inside the PVC, which /k3s-volumes already
# covers; nothing extra to add to the plan paths.
# VW_POD=$(kubectl -n security get pod -l app=vaultwarden \
#   -o jsonpath='{.items[0].metadata.name}')
# kubectl -n security exec "$VW_POD" -- /vaultwarden backup
# Each run writes a new db_YYYYMMDD_HHMMSS.sqlite3 — prune so they don't pile up.
# kubectl -n security exec "$VW_POD" -- \
#   sh -c 'find /data -name "db_*.sqlite3" -mtime +7 -delete'
#
# NOTE: n8n no longer needs a SQLite stanza here — it moved to Postgres and is
# covered by the pg_dumpall above.
#
# echo "[hook] DB dumps complete."
# --------------------------------------------------------------------------
#
# =============================================================================
# Restore examples (CLI — works even if Backrest/cluster is gone)
# =============================================================================
#
# apt install restic
#
# List snapshots:
#   restic -r /home/pi/pendrive/backups/restic-repo snapshots
#
# Restore all app volumes:
#   restic -r /home/pi/pendrive/backups/restic-repo \
#     restore latest --target / --path /k3s-volumes
#
# Restore MongoDB:
#   restic -r /home/pi/pendrive/backups/restic-repo \
#     dump latest /data/db-dumps/mongo.archive.gz \
#     | mongorestore --uri="mongodb://..." --archive --gzip
#
# Restore PostgreSQL:
#   restic -r /home/pi/pendrive/backups/restic-repo \
#     dump latest /data/db-dumps/postgres.sql.gz \
#     | gunzip | psql -U postgres
#
# Restore Vaultwarden (the vault is the whole data dir, not just the db):
#   restic -r /home/pi/pendrive/backups/restic-repo \
#     restore latest --target / --path /k3s-volumes/apps/vaultwarden
#   # scale vaultwarden to 0 first, then inside that data dir:
#   #   mv db_YYYYMMDD_HHMMSS.sqlite3 db.sqlite3
#   #   rm -f db.sqlite3-wal      # MUST be removed or the db tears
#   # attachments/, sends/ and rsa_key.pem come back with the directory.
