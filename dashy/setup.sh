#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="Dashy"
CONTAINER_NAME="dashy"
REQUIRED_RAM_MB=150
REQUIRED_DISK_GB=1
DEFAULT_PORT="4000"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Helpers ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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

setup_env() {
    if [[ ! -f .env ]]; then
        if [[ -f .env.example ]]; then
            cp .env.example .env
            print_success "Created .env from .env.example"
        else
            print_error ".env.example not found"; exit 1
        fi
    else
        print_status "Using existing .env file"
    fi
    source .env
}

get_host_ip() { hostname -I | awk '{print $1}'; }

wait_for_service() {
    local port="${1:-$DEFAULT_PORT}" max=30
    print_status "Waiting for ${SERVICE_NAME} to start..."
    for i in $(seq 1 "$max"); do
        if docker compose ps --format json 2>/dev/null | grep -q '"healthy"'; then
            print_success "${SERVICE_NAME} is healthy!"; return 0
        elif curl -sf -o /dev/null "http://localhost:${port}"; then
            print_success "${SERVICE_NAME} is ready!"; return 0
        fi
        echo -n "."; sleep 1
    done
    echo; print_warning "${SERVICE_NAME} may still be starting. Check: docker compose logs -f"; return 1
}

# ─── Config Management (absorbed from config.sh) ────────────────────────────
config_validate() {
    print_status "Validating configuration..."
    if [[ ! -f "conf.yml" ]]; then
        print_error "Configuration file conf.yml not found"; exit 1
    fi
    if command -v python3 &>/dev/null; then
        if ! python3 -c "import yaml; yaml.safe_load(open('conf.yml'))" 2>/dev/null; then
            print_error "Invalid YAML syntax in conf.yml"; exit 1
        fi
        print_success "Configuration syntax is valid"
    else
        print_warning "Python3 not available for YAML validation"
    fi
}

config_sync() {
    print_status "Syncing configuration from root to user-data..."
    config_validate
    if [[ -f "user-data/conf.yml" ]]; then
        local timestamp; timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "user-data/conf.yml" "user-data/conf.yml.backup.$timestamp"
        print_status "Backed up existing configuration"
    fi
    mkdir -p user-data
    cp "conf.yml" "user-data/conf.yml"
    print_success "Configuration synced"

    if docker compose ps 2>/dev/null | grep -q "Up\|running"; then
        print_status "Restarting to apply new configuration..."
        docker compose restart "$CONTAINER_NAME"
        local port="${DASHY_PORT:-$DEFAULT_PORT}"
        wait_for_service "$port" || true
    fi
}

config_diff() {
    print_status "Checking configuration differences..."
    if [[ ! -f "conf.yml" ]]; then print_error "Root config not found"; exit 1; fi
    if [[ ! -f "user-data/conf.yml" ]]; then
        print_warning "Runtime config not found — sync needed"
        return
    fi
    if cmp -s "conf.yml" "user-data/conf.yml"; then
        print_success "Configurations are synchronized"
    else
        print_warning "Configurations differ — run: ./setup.sh config-sync"
    fi
}

config_edit() {
    local editor="${EDITOR:-nano}"
    if [[ -f "conf.yml" ]]; then
        local timestamp; timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "conf.yml" "conf.yml.backup.$timestamp"
    fi
    $editor "conf.yml"
    config_validate
    print_status "Run './setup.sh config-sync' to apply changes"
}

config_status() {
    echo -e "${BLUE}=== Configuration Status ===${NC}"
    echo
    if [[ -f "conf.yml" ]]; then
        local root_size; root_size=$(du -h "conf.yml" | cut -f1)
        echo -e "${GREEN}Root Config:${NC} conf.yml (${root_size})"
    else
        echo -e "${RED}Root Config:${NC} conf.yml (missing)"
    fi
    if [[ -f "user-data/conf.yml" ]]; then
        local runtime_size; runtime_size=$(du -h "user-data/conf.yml" | cut -f1)
        echo -e "${GREEN}Runtime Config:${NC} user-data/conf.yml (${runtime_size})"
    else
        echo -e "${RED}Runtime Config:${NC} user-data/conf.yml (missing)"
    fi
    echo
    if [[ -f "conf.yml" ]] && [[ -f "user-data/conf.yml" ]]; then
        if cmp -s "conf.yml" "user-data/conf.yml"; then
            echo -e "${GREEN}Sync Status:${NC} Synchronized ✓"
        else
            echo -e "${YELLOW}Sync Status:${NC} Differ — sync needed ⚠"
        fi
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
    setup_env

    mkdir -p user-data
    print_success "Directories ready"

    # Sync configuration
    if [[ -f "conf.yml" ]]; then
        config_sync
    else
        print_error "Main configuration file conf.yml not found!"; exit 1
    fi

    local host_ip; host_ip=$(get_host_ip)
    local port="${DASHY_PORT:-$DEFAULT_PORT}"

    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    wait_for_service "$port" || true

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  Dashboard: http://${host_ip}:${port}"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start          Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop           Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs           View logs"
    echo "  ./setup.sh config-edit    Edit configuration"
    echo "  ./setup.sh config-sync    Apply config changes"
    echo "  ./setup.sh config-status  Check config status"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    source .env 2>/dev/null || true
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${DASHY_PORT:-$DEFAULT_PORT}"
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

cmd_status() {
    echo -e "${BLUE}=== ${SERVICE_NAME} Status ===${NC}"
    echo
    if docker compose ps | grep -q "Up\|running"; then
        print_success "Container is running"
        docker compose ps
    else
        print_warning "Container is not running"
    fi
    echo
    config_status
}

cmd_update() {
    print_status "Updating ${SERVICE_NAME}..."
    docker compose pull
    docker compose up -d
    wait_for_service "${DASHY_PORT:-$DEFAULT_PORT}" || true
    print_success "${SERVICE_NAME} updated"
}

show_usage() {
    echo "${SERVICE_NAME} Management Script"
    echo
    echo "Usage: ./setup.sh [command]"
    echo
    echo "Commands:"
    echo "  setup          Initial setup and start (default)"
    echo "  start          Start the service"
    echo "  stop           Stop the service"
    echo "  restart        Restart the service"
    echo "  logs           View logs"
    echo "  status         Show service and config status"
    echo "  update         Update to latest version"
    echo "  config-edit    Edit dashboard configuration"
    echo "  config-sync    Sync configuration to runtime"
    echo "  config-diff    Show configuration differences"
    echo "  config-validate Validate configuration syntax"
    echo "  config-status  Show configuration status"
    echo "  help           Show this help message"
}

# ─── Main ────────────────────────────────────────────────────────────────────
case "${1:-setup}" in
    setup)           cmd_setup ;;
    start)           cmd_start ;;
    stop)            cmd_stop ;;
    restart)         cmd_restart ;;
    logs)            cmd_logs ;;
    status)          cmd_status ;;
    update)          cmd_update ;;
    config-edit)     config_edit ;;
    config-sync)     config_sync ;;
    config-diff)     config_diff ;;
    config-validate) config_validate ;;
    config-status)   config_status ;;
    help|--help|-h)  show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
