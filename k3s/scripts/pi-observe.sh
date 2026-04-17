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
CLEAR_SCREEN=false
RENDER_MODE="inplace"
TICK=0

# Colors (match the style used in other k3s scripts)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  CYAN=''
  BOLD=''
  DIM=''
  NC=''
fi

header() { echo -e "\n${CYAN}${BOLD}━━━ $* ${NC}"; }
info()   { echo -e "${BLUE}[INFO]${NC}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()  { echo -e "${RED}[ERR]${NC}   $*"; }
meta()   { echo -e "${DIM}$*${NC}"; }

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
  -r, --render <mode>       Render mode: inplace|redraw (default: inplace)
      --once                Print one snapshot and exit
      --watch               Force continuous watch mode (default behavior)
      --clear               Alias for --render redraw
      --no-clear            Do not clear screen between refreshes
  -h, --help                Show this help

Examples:
  ./pi-observe.sh --mode k8s --interval 15
  ./pi-observe.sh --sections k8s-nodes,k8s-pods --pods 30
  ./pi-observe.sh --mode zram --once
  ./pi-observe.sh host 2
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "missing required command: $cmd" >&2
    exit 1
  fi
}

parse_args() {
  local positional=()

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
      -r|--render)
        RENDER_MODE="${2:-}"
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
      --clear)
        RENDER_MODE="redraw"
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
        positional+=("$1")
        shift
        ;;
    esac
  done

  # Positional compatibility:
  #   ./pi-observe.sh <mode> [interval]
  #   ./pi-observe.sh <interval>
  if [[ ${#positional[@]} -gt 0 ]]; then
    local idx=0

    if [[ "${positional[$idx]}" =~ ^(full|host|k8s|zram)$ ]]; then
      MODE="${positional[$idx]}"
      ((idx+=1))
    fi

    if [[ $idx -lt ${#positional[@]} ]] && [[ "${positional[$idx]}" =~ ^[0-9]+$ ]]; then
      INTERVAL="${positional[$idx]}"
      ((idx+=1))
    fi

    if [[ $idx -lt ${#positional[@]} ]]; then
      error "unknown argument: ${positional[$idx]}" >&2
      print_help
      exit 1
    fi
  fi
}

validate_args() {
  if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]]; then
    error "--interval must be a positive integer" >&2
    exit 1
  fi

  if ! [[ "$PODS_LIMIT" =~ ^[0-9]+$ ]] || [[ "$PODS_LIMIT" -lt 1 ]]; then
    error "--pods must be a positive integer" >&2
    exit 1
  fi

  case "$MODE" in
    full|host|k8s|zram) ;;
    *)
      error "invalid --mode: $MODE (expected full|host|k8s|zram)" >&2
      exit 1
      ;;
  esac

  case "$RENDER_MODE" in
    inplace|redraw) ;;
    *)
      error "invalid --render: $RENDER_MODE (expected inplace|redraw)" >&2
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
  TICK=$((TICK + 1))
  echo -e "${BOLD}${GREEN}Pi Observe${NC}"
  meta "$(date)"
  meta "tick=$TICK  mode=$MODE  interval=${INTERVAL}s  pods=$PODS_LIMIT  once=$ONCE  render=$RENDER_MODE"
  if [[ -n "$SECTIONS" ]]; then
    meta "sections=$ACTIVE_SECTIONS"
  fi
  echo
}

print_host() {
  header "Host Memory"
  free -h || true
  echo
}

print_zram() {
  header "Swap and ZRAM"
  swapon --show || true
  echo
  zramctl || true
  echo
}

print_psi() {
  header "Memory Pressure (PSI)"
  cat /proc/pressure/memory || true
  echo
}

print_top_procs() {
  header "Top Host Processes by RSS"
  ps -eo pid,ppid,cmd,%mem,%cpu,rss --sort=-rss | head -n 15 || true
  echo
}

print_k8s_nodes() {
  header "Kubernetes Node Usage"
  kubectl top nodes || true
  echo
}

print_k8s_pods() {
  header "Top Pods by Memory"
  kubectl top pods -A --sort-by=memory | head -n "$PODS_LIMIT" || true
  echo
}

print_k8s_alloc() {
  local node
  node="$(default_node_name)"
  if [[ -z "$node" ]]; then
    header "Node Allocated Commitments"
    warn "unable to detect node name"
    echo
    return
  fi

  header "Node Allocated Commitments ($node)"
  kubectl describe node "$node" | sed -n '/Allocated resources:/,/Events:/p' || true
  echo
}

print_snapshot() {
  print_header

  section_enabled "host" && print_host
  section_enabled "zram" && print_zram
  section_enabled "psi" && print_psi
  section_enabled "top-procs" && print_top_procs
  section_enabled "k8s-nodes" && print_k8s_nodes
  section_enabled "k8s-pods" && print_k8s_pods
  section_enabled "k8s-alloc" && print_k8s_alloc

  # Ensure the function exits successfully even when trailing sections are disabled.
  return 0
}

main() {
  parse_args "$@"
  validate_args
  set_active_sections

  if section_enabled "k8s-nodes" || section_enabled "k8s-pods" || section_enabled "k8s-alloc"; then
    require_cmd kubectl
  fi

  if $ONCE; then
    $CLEAR_SCREEN && clear
    print_snapshot
    exit 0
  fi

  if [[ "$RENDER_MODE" == "inplace" ]]; then
    # Hide cursor during live updates and restore on exit.
    printf '\033[?25l'
    trap 'printf "\033[?25h"' EXIT
  fi

  local first=true
  while true; do
    if [[ "$RENDER_MODE" == "redraw" ]]; then
      $CLEAR_SCREEN && clear
      print_snapshot
    else
      if $first; then
        print_snapshot
        first=false
      else
        # Redraw in place from top-left and clear stale trailing lines.
        printf '\033[H'
        print_snapshot
        printf '\033[J'
      fi
    fi
    meta "refresh every ${INTERVAL}s (Ctrl+C to exit)"
    sleep "$INTERVAL"
  done
}

main "$@"
