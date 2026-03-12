#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="Home Assistant"
CONTAINER_NAME="homeassistant"
REQUIRED_RAM_MB=500
REQUIRED_DISK_GB=2
DEFAULT_PORT="8123"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Helpers ─────────────────────────────────────────────────────────────────
check_docker() {
    if ! command -v docker &>/dev/null; then print_error "Docker is not installed"; exit 1; fi
    if ! docker info &>/dev/null; then print_error "Docker is not running"; exit 1; fi
    if ! docker compose version &>/dev/null; then print_error "Docker Compose V2 is required"; exit 1; fi
    print_success "Docker is running"
}

check_system() {
    local total_ram; total_ram=$(free -m | awk 'NR==2{print $2}')
    if (( total_ram < REQUIRED_RAM_MB )); then
        print_warning "Low memory: ${total_ram}MB available, ${REQUIRED_RAM_MB}MB recommended for ${SERVICE_NAME}"
    else
        print_success "Memory check passed (${total_ram}MB available)"
    fi
    local available_disk; available_disk=$(df -BG . | awk 'NR==2{print int($4)}')
    if (( available_disk < REQUIRED_DISK_GB )); then
        print_warning "Low disk space: ${available_disk}GB available, ${REQUIRED_DISK_GB}GB recommended"
    else
        print_success "Disk space check passed (${available_disk}GB available)"
    fi
}

get_host_ip() { hostname -I | awk '{print $1}'; }

wait_for_service() {
    local port="${1:-$DEFAULT_PORT}" max=60
    print_status "Waiting for ${SERVICE_NAME} to start (this may take 1-2 minutes)..."
    for i in $(seq 1 "$max"); do
        if curl -sf -o /dev/null -w "%{http_code}" "http://localhost:${port}" | grep -q "200\|302"; then
            print_success "${SERVICE_NAME} is ready!"; return 0
        fi
        echo -n "."; sleep 2
    done
    echo; print_warning "${SERVICE_NAME} may still be starting. Check: docker compose logs -f"; return 1
}

# ─── Hardware Detection ─────────────────────────────────────────────────────
declare -a HA_DEVICE_LIST=()
declare -A HA_DEVICE_SEEN=()
declare -a TRUSTED_PROXY_LIST=()
declare -a DEFAULT_TRUSTED_PROXIES=("127.0.0.1" "::1" "172.16.0.0/12")
PYTHON_BIN=""

detect_python() {
    if command -v python3 &>/dev/null; then PYTHON_BIN="python3"
    elif command -v python &>/dev/null; then PYTHON_BIN="python"
    else PYTHON_BIN=""; fi
}

if command -v sudo &>/dev/null && [[ $EUID -ne 0 ]]; then SUDO_BIN="sudo"; else SUDO_BIN=""; fi
run_privileged() { if [[ -n "$SUDO_BIN" ]]; then $SUDO_BIN "$@"; else "$@"; fi; }

record_device_candidate() {
    local dev="$1"
    [[ -e "$dev" ]] || return
    if [[ -z "${HA_DEVICE_SEEN[$dev]:-}" ]]; then
        HA_DEVICE_SEEN["$dev"]=1
        HA_DEVICE_LIST+=("$dev")
    fi
}

trim_string() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

build_trusted_proxy_list() {
    TRUSTED_PROXY_LIST=()
    local -a raw_list=("${DEFAULT_TRUSTED_PROXIES[@]}")
    if [[ -n "${HA_TRUSTED_PROXIES:-}" ]]; then
        IFS=',' read -ra user_list <<< "${HA_TRUSTED_PROXIES}"
        for entry in "${user_list[@]}"; do
            local cleaned; cleaned=$(trim_string "$entry")
            [[ -n "$cleaned" ]] && raw_list+=("$cleaned")
        done
    fi
    local -A seen=()
    for entry in "${raw_list[@]}"; do
        [[ -z "$entry" ]] && continue
        if [[ -z "${seen[$entry]:-}" ]]; then
            seen["$entry"]=1
            TRUSTED_PROXY_LIST+=("$entry")
        fi
    done
}

render_http_snippet() {
    local outfile="$1"
    {
        echo "# --- BEGIN setup.sh managed http block ---"
        echo "http:"
        echo "  use_x_forwarded_for: true"
        echo "  trusted_proxies:"
        for proxy in "${TRUSTED_PROXY_LIST[@]}"; do
            echo "    - $proxy"
        done
        echo "# --- END setup.sh managed http block ---"
    } > "$outfile"
}

ensure_base_configuration() {
    local config_file="./config/configuration.yaml"
    [[ -f "$config_file" ]] && return
    print_status "Creating baseline configuration.yaml"
    cat > "$config_file" << 'EOF'

# Loads default set of integrations. Do not remove.
default_config:

# Load frontend themes from the themes folder
frontend:
  themes: !include_dir_merge_named themes

automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
EOF
}

ensure_reverse_proxy_whitelist() {
    local config_file="./config/configuration.yaml"
    [[ -f "$config_file" ]] || return
    [[ -z "$PYTHON_BIN" ]] && return
    local snippet_file; snippet_file=$(mktemp)
    render_http_snippet "$snippet_file"
    local result
    if result=$(run_privileged "$PYTHON_BIN" - "$config_file" "$snippet_file" <<'PY'
import sys, pathlib
cfg = pathlib.Path(sys.argv[1])
snippet = pathlib.Path(sys.argv[2]).read_text().strip() + "\n"
start = "# --- BEGIN setup.sh managed http block ---"
end = "# --- END setup.sh managed http block ---"
text = cfg.read_text()
updated = False
if start in text and end in text:
    before, rest = text.split(start, 1)
    body, after = rest.split(end, 1)
    existing = (start + body + end).strip() + "\n"
    if existing != snippet:
        new_text = before.rstrip() + "\n" + snippet + "\n" + after.lstrip()
        updated = True
    else:
        new_text = text
else:
    new_text = snippet + "\n\n" + text.lstrip()
    updated = True
if updated:
    cfg.write_text(new_text)
print("UPDATED" if updated else "NOCHANGE")
PY
    ); then
        if [[ "$result" == *"UPDATED"* ]]; then
            print_success "Updated reverse proxy whitelist"
        else
            print_status "Reverse proxy whitelist already up to date"
        fi
    fi
    rm -f "$snippet_file"
}

print_hardware_snapshot() {
    echo -e "${BLUE}Hardware Snapshot:${NC}"
    # Serial devices
    echo "  Serial / TTY devices:"
    local found=false
    for dev in /dev/ttyAMA* /dev/ttyUSB* /dev/ttyACM*; do
        [[ -e "$dev" ]] || continue
        found=true; echo "    - $dev"
        record_device_candidate "$dev"
    done
    [[ "$found" == false ]] && echo "    - None detected"

    # Bluetooth
    echo "  Bluetooth adapters:"
    found=false
    if [[ -d /sys/class/bluetooth ]]; then
        for adapter_path in /sys/class/bluetooth/*; do
            [[ -e "$adapter_path" ]] || continue
            found=true; echo "    - $(basename "$adapter_path")"
        done
    fi
    [[ "$found" == false ]] && echo "    - None detected"

    if (( ${#HA_DEVICE_LIST[@]} > 0 )); then
        echo
        echo "  Device mapping suggestions for docker-compose:"
        for dev in "${HA_DEVICE_LIST[@]}"; do
            echo "    - $dev:$dev"
        done
    fi
}

# ─── Commands ────────────────────────────────────────────────────────────────
cmd_setup() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}   ${SERVICE_NAME} Setup${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo

    check_docker
    check_system
    detect_python
    build_trusted_proxy_list

    mkdir -p config
    print_success "Directories ready"

    ensure_base_configuration
    ensure_reverse_proxy_whitelist

    print_hardware_snapshot
    echo

    local host_ip; host_ip=$(get_host_ip)

    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    wait_for_service "$DEFAULT_PORT" || true

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  Web UI: http://${host_ip}:${DEFAULT_PORT}"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start     Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop      Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs      View logs"
    echo "  ./setup.sh hardware  Show hardware snapshot"
    echo "  ./setup.sh status    Show status"
    echo "  ./setup.sh update    Update to latest"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${DEFAULT_PORT}"
}

cmd_stop() {
    print_status "Stopping ${SERVICE_NAME}..."
    docker compose down
    print_success "${SERVICE_NAME} stopped"
}

cmd_restart() {
    print_status "Restarting ${SERVICE_NAME}..."
    docker compose restart
    print_success "${SERVICE_NAME} restarted"
}

cmd_logs() {
    print_status "Showing ${SERVICE_NAME} logs (Ctrl+C to exit)..."
    docker compose logs -f
}

cmd_hardware() {
    detect_python
    build_trusted_proxy_list
    print_hardware_snapshot
    echo
    echo -e "${BLUE}Trusted Proxies:${NC}"
    for proxy in "${TRUSTED_PROXY_LIST[@]}"; do
        echo "  - $proxy"
    done
}

cmd_status() {
    echo -e "${BLUE}=== ${SERVICE_NAME} Status ===${NC}"
    echo
    if docker compose ps | grep -q "Up\|running"; then
        print_success "Container is running"
        docker compose ps
    else
        print_warning "Container is not running"
    fi
}

cmd_update() {
    print_status "Updating ${SERVICE_NAME}..."
    docker compose pull
    docker compose up -d
    print_success "${SERVICE_NAME} updated"
}

show_usage() {
    echo "${SERVICE_NAME} Management Script"
    echo
    echo "Usage: ./setup.sh [command]"
    echo
    echo "Commands:"
    echo "  setup     Initial setup and start (default)"
    echo "  start     Start the service"
    echo "  stop      Stop the service"
    echo "  restart   Restart the service"
    echo "  logs      View logs"
    echo "  hardware  Show hardware snapshot and device mapping"
    echo "  status    Show service status"
    echo "  update    Update to latest version"
    echo "  help      Show this help message"
}

# ─── Main ────────────────────────────────────────────────────────────────────
case "${1:-setup}" in
    setup)    cmd_setup ;;
    start)    cmd_start ;;
    stop)     cmd_stop ;;
    restart)  cmd_restart ;;
    logs)     cmd_logs ;;
    hardware) cmd_hardware ;;
    status)   cmd_status ;;
    update)   cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
