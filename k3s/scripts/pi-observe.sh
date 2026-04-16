#!/usr/bin/env bash
set -euo pipefail

# pi-observe.sh - Option-centric host + k8s observability helper.
#
# Examples:
#   ./pi-observe.sh --mode full
#   ./pi-observe.sh --mode k8s --interval 10
#   ./pi-observe.sh --mode zram --once
#   ./pi-observe.sh --sections host,zram,psi,top-procs --once

INTERVAL=5
MODE="full"
SECTIONS=""
PODS_LIMIT=20
NODE_NAME=""
ONCE=false
CLEAR_SCREEN=true

print_help() {
  cat <<'EOF'
Usage: pi-observe.sh [options]

Modes (preset section sets):
  full      host + zram + psi + top processes + k8s views (default)
  host      host memory + zram + psi + top processes
  k8s       node usage + top pods + allocated commitments
  zram      zram + swap + memory + psi

Options:
  -m, --mode <name>         Preset mode: full|host|k8s|zram
  -s, --sections <list>     Comma-separated explicit sections:
                            host,zram,psi,top-procs,k8s-nodes,k8s-pods,k8s-alloc
  -i, --interval <seconds>  Refresh interval in watch mode (default: 5)
  -p, --pods <count>        Top pod rows for k8s-pods section (default: 20)
  -n, --node <name>         Node name for k8s-alloc (default: first node)
      --once                Print one snapshot and exit
      --watch               Force continuous watch mode (default behavior)
      --no-clear            Do not clear screen between refreshes
  -h, --help                Show this help

Examples:
  ./pi-observe.sh --mode k8s --interval 15
  ./pi-observe.sh --sections k8s-nodes,k8s-pods --pods 30
  ./pi-observe.sh --mode zram --once
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--mode)
        MODE="${2:-}"
        shift 2
        ;;
      -s|--sections)
        SECTIONS="${2:-}"
        shift 2
        ;;
      -i|--interval)
        INTERVAL="${2:-}"
        shift 2
        ;;
      -p|--pods)
        PODS_LIMIT="${2:-}"
        shift 2
        ;;
      -n|--node)
        NODE_NAME="${2:-}"
        shift 2
        ;;
      --once)
        ONCE=true
        shift
        ;;
      --watch)
        ONCE=false
        shift
        ;;
      --no-clear)
        CLEAR_SCREEN=false
        shift
        ;;
      -h|--help)
        print_help
        exit 0
        ;;
      *)
        echo "unknown option: $1" >&2
        print_help
        exit 1
        ;;
    esac
  done
}

validate_args() {
  if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]]; then
    echo "--interval must be a positive integer" >&2
    exit 1
  fi

  if ! [[ "$PODS_LIMIT" =~ ^[0-9]+$ ]] || [[ "$PODS_LIMIT" -lt 1 ]]; then
    echo "--pods must be a positive integer" >&2
    exit 1
  fi

  case "$MODE" in
    full|host|k8s|zram) ;;
    *)
      echo "invalid --mode: $MODE (expected full|host|k8s|zram)" >&2
      exit 1
      ;;
  esac
}

default_node_name() {
  if [[ -n "$NODE_NAME" ]]; then
    echo "$NODE_NAME"
    return
  fi
  kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

section_enabled() {
  local needle="$1"
  local haystack=",$ACTIVE_SECTIONS,"
  [[ "$haystack" == *",$needle,"* ]]
}

set_active_sections() {
  if [[ -n "$SECTIONS" ]]; then
    ACTIVE_SECTIONS="$SECTIONS"
    return
  fi

  case "$MODE" in
    full)
      ACTIVE_SECTIONS="host,zram,psi,top-procs,k8s-nodes,k8s-pods,k8s-alloc"
      ;;
    host)
      ACTIVE_SECTIONS="host,zram,psi,top-procs"
      ;;
    k8s)
      ACTIVE_SECTIONS="k8s-nodes,k8s-pods,k8s-alloc"
      ;;
    zram)
      ACTIVE_SECTIONS="host,zram,psi"
      ;;
  esac
}

print_header() {
  echo "=== Pi Observe ==="
  date
  echo "mode=$MODE interval=${INTERVAL}s pods=$PODS_LIMIT once=$ONCE"
  echo
}

print_host() {
  echo "=== Host Memory ==="
  free -h || true
  echo
}

print_zram() {
  echo "=== Swap and ZRAM ==="
  swapon --show || true
  echo
  zramctl || true
  echo
}

print_psi() {
  echo "=== Memory Pressure (PSI) ==="
  cat /proc/pressure/memory || true
  echo
}

print_top_procs() {
  echo "=== Top Host Processes by RSS ==="
  ps -eo pid,ppid,cmd,%mem,%cpu,rss --sort=-rss | head -n 15 || true
  echo
}

print_k8s_nodes() {
  echo "=== Kubernetes Node Usage ==="
  kubectl top nodes || true
  echo
}

print_k8s_pods() {
  echo "=== Top Pods by Memory ==="
  kubectl top pods -A --sort-by=memory | head -n "$PODS_LIMIT" || true
  echo
}

print_k8s_alloc() {
  local node
  node="$(default_node_name)"
  if [[ -z "$node" ]]; then
    echo "=== Node Allocated Commitments ==="
    echo "unable to detect node name"
    echo
    return
  fi

  echo "=== Node Allocated Commitments ($node) ==="
  kubectl describe node "$node" | sed -n '/Allocated resources:/,/Events:/p' || true
  echo
}

print_snapshot() {
  $CLEAR_SCREEN && clear
  print_header

  section_enabled "host" && print_host
  section_enabled "zram" && print_zram
  section_enabled "psi" && print_psi
  section_enabled "top-procs" && print_top_procs
  section_enabled "k8s-nodes" && print_k8s_nodes
  section_enabled "k8s-pods" && print_k8s_pods
  section_enabled "k8s-alloc" && print_k8s_alloc
}

main() {
  parse_args "$@"
  validate_args

  require_cmd kubectl
  set_active_sections

  if $ONCE; then
    print_snapshot
    exit 0
  fi

  while true; do
    print_snapshot
    echo "refresh every ${INTERVAL}s (Ctrl+C to exit)"
    sleep "$INTERVAL"
  done
}

main "$@"
