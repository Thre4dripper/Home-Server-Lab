#!/usr/bin/env bash
# _db-ctl.sh — Shared database management library
#
# Sourced by each database's setup.sh under k3s/databases/*/setup.sh.
# It first sources _app-ctl.sh (so every generic command — deploy, status,
# logs, exec, restart, seal, argocd-status, ... — is available unchanged)
# and then layers stateful-DB-only commands on top.
#
# Per-database setup.sh may optionally define hook functions that the
# generic commands here will call:
#
#   _db_connection_string [external|internal]
#       Print a copy/paste-ready URI. Required for `connection-string`.
#
#   _db_dump_cmd  <output_file>
#   _db_restore_cmd <input_file>
#       Backup/restore implementations (pg_dump / mongodump / redis BGSAVE / ...).
#       Optional — `dump`/`restore` will warn if not defined.

# ─── Resolve and source the generic app library ───────────────────────────────
DB_CTL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_app-ctl.sh
source "$DB_CTL_DIR/_app-ctl.sh"

# ─── DB-common commands ───────────────────────────────────────────────────────

cmd_print_ca() {
  if ! kubectl get secret "${APP}-ca" -n "$NAMESPACE" &>/dev/null; then
    err "Secret ${APP}-ca not found in $NAMESPACE — this DB has no private CA"
    exit 1
  fi
  kubectl get secret "${APP}-ca" -n "$NAMESPACE" -o jsonpath='{.data.ca\.crt}' | base64 -d
}

cmd_detach_storage() {
  header "Detach $APP Storage"
  warn "Scales the workload to 0; PVCs/PVs are preserved."
  local kind; kind="$(_detect_workload_kind)"
  [[ -z "$kind" ]] && { err "No workload found for $APP in $NAMESPACE"; exit 1; }

  kubectl scale "$kind/$APP" -n "$NAMESPACE" --replicas=0
  kubectl rollout status "$kind/$APP" -n "$NAMESPACE" --timeout=120s || true

  echo ""
  header "Retained $APP Volumes"
  kubectl get pvc -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.volumeName}{"\n"}{end}' | \
    grep -E "(^|-)${APP}(-|$)" | \
    while IFS=' ' read -r pvc_name pv_name; do
      [[ -z "$pvc_name" ]] && continue
      echo -e "  PVC: ${BOLD}${pvc_name}${NC}"
      kubectl get pv "$pv_name" -o jsonpath='  ├ PV:       {.metadata.name}{"\n"}  ├ Reclaim:  {.spec.persistentVolumeReclaimPolicy}{"\n"}  └ Path:     {.spec.hostPath.path}{"\n"}' 2>/dev/null
      echo ""
    done

  ok "Detached. Reattach with: ./setup.sh attach-storage [replicas]"
}

cmd_attach_storage() {
  local replicas="${1:-1}"
  [[ "$replicas" =~ ^[1-9][0-9]*$ ]] || { err "Usage: ./setup.sh attach-storage [replicas]"; exit 1; }
  header "Attach $APP Storage"
  local kind; kind="$(_detect_workload_kind)"
  [[ -z "$kind" ]] && { err "No workload found for $APP in $NAMESPACE"; exit 1; }
  kubectl scale "$kind/$APP" -n "$NAMESPACE" --replicas="$replicas"
  kubectl rollout status "$kind/$APP" -n "$NAMESPACE" --timeout=300s
  ok "Reattached at ${replicas} replica(s)"
}

cmd_connection_string() {
  local scope="${1:-external}"
  if ! declare -F _db_connection_string >/dev/null; then
    err "This DB's setup.sh has not defined _db_connection_string()"
    exit 1
  fi
  _db_connection_string "$scope"
}

cmd_dump() {
  local out="${1:-${APP}-$(date +%Y%m%d-%H%M%S).dump}"
  if ! declare -F _db_dump_cmd >/dev/null; then
    err "This DB's setup.sh has not defined _db_dump_cmd()"
    exit 1
  fi
  header "Dump $APP → $out"
  _db_dump_cmd "$out"
  ok "Dump complete: $out"
}

cmd_restore() {
  local in="${1:-}"
  [[ -z "$in" || ! -f "$in" ]] && { err "Usage: ./setup.sh restore <dump-file>"; exit 1; }
  if ! declare -F _db_restore_cmd >/dev/null; then
    err "This DB's setup.sh has not defined _db_restore_cmd()"
    exit 1
  fi
  header "Restore $APP ← $in"
  warn "This may overwrite existing data."
  read -r -p "  Type 'yes' to confirm: " confirm
  [[ "$confirm" != "yes" ]] && echo "  Aborted." && return 0
  _db_restore_cmd "$in"
  ok "Restore complete"
}

# ─── Help override that adds the DB section ───────────────────────────────────
_show_db_usage() {
  _show_usage
  echo -e "${CYAN}Database operations:${NC}"
  echo "  connection-string [external|internal]"
  echo "                          Print a copy/paste-ready connection URI"
  echo "  print-ca                Print the private CA cert (for TLS clients)"
  echo "  detach-storage          Scale workload to 0 (PVCs/PVs preserved)"
  echo "  attach-storage [n]      Scale workload back up to n replicas"
  echo "  dump [file]             Logical backup (per-DB hook)"
  echo "  restore <file>          Restore from a logical backup (per-DB hook)"
  echo ""
}

# ─── Single dispatcher used by every DB's setup.sh ────────────────────────────
db_main() {
  case "${1:-help}" in
    connection-string) shift; cmd_connection_string "${1:-external}" ;;
    print-ca)          cmd_print_ca ;;
    detach-storage)    cmd_detach_storage ;;
    attach-storage)    shift; cmd_attach_storage "${1:-1}" ;;
    dump)              shift; cmd_dump "${1:-}" ;;
    restore)           shift; cmd_restore "${1:-}" ;;
    help|--help|-h)    _show_db_usage ;;
    *)                 main "$@" ;;
  esac
}
