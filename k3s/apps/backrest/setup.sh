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
#      /k3s-volumes/apps/filebrowser-quantum/data/cache
#                                       (search index + thumbnails, ~140MB and
#                                        rewritten constantly; regenerated on
#                                        first scan, so backing it up would add
#                                        a new pack of churn to every snapshot
#                                        for nothing. The 190KB database beside
#                                        it is what matters — see hook below.)
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
# echo "[hook] Snapshotting FileBrowser Quantum SQLite..."
# Unlike Vaultwarden this app has no `backup` subcommand, and neither image
# ships sqlite3 — but Backrest's is Alpine, so the hook can pull it in (~1MB,
# needs the same egress the S3 repo already uses). VACUUM INTO takes a read
# snapshot of a live WAL database, so the copy is never torn; a plain cp of
# filebrowser.sqlite would miss whatever is still sitting in the -wal file.
# The db is reachable read-write at the /k3s-volumes mount.
# command -v sqlite3 >/dev/null || apk add --no-cache sqlite
# rm -f "$DUMP_DIR/filebrowser-quantum.sqlite"
# sqlite3 /k3s-volumes/apps/filebrowser-quantum/data/filebrowser.sqlite \
#   "VACUUM INTO '$DUMP_DIR/filebrowser-quantum.sqlite'"
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
# Restore FileBrowser Quantum (users, shares, settings, activity log):
#   restic -r /home/pi/pendrive/backups/restic-repo \
#     dump latest /data/db-dumps/filebrowser-quantum.sqlite \
#     > /home/pi/k3s-volumes/apps/filebrowser-quantum/data/filebrowser.sqlite
#   # ./setup.sh disable first (ArgoCD-safe), restore, then enable.
#   # rm -f filebrowser.sqlite-wal filebrowser.sqlite-shm in that directory —
#   # a leftover WAL from the old database would be replayed over the restored
#   # one. The cache/ directory is deliberately NOT in the backup; the app
#   # rebuilds the search index and thumbnails on first start.
#   # config.yaml is not in here either — it is a ConfigMap built from git.
#
# Restore Vaultwarden (the vault is the whole data dir, not just the db):
#   restic -r /home/pi/pendrive/backups/restic-repo \
#     restore latest --target / --path /k3s-volumes/apps/vaultwarden
#   # scale vaultwarden to 0 first, then inside that data dir:
#   #   mv db_YYYYMMDD_HHMMSS.sqlite3 db.sqlite3
#   #   rm -f db.sqlite3-wal      # MUST be removed or the db tears
#   # attachments/, sends/ and rsa_key.pem come back with the directory.
