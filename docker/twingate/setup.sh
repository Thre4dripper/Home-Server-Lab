#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="twingate"
CONTAINER_NAME="twingate-connector"
REQUIRED_RAM_MB=75
REQUIRED_DISK_GB=1
DEFAULT_PORT=""  # No web UI - host network mode

REQUIRED_ENV_VARS=(TWINGATE_NETWORK TWINGATE_ACCESS_TOKEN TWINGATE_REFRESH_TOKEN)

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
            print_warning "Please edit .env with your Twingate connector tokens"
        else
            print_error ".env.example not found"; exit 1
        fi
    else
        print_status "Using existing .env file"
    fi

    set -a; source .env; set +a

    # Validate required environment variables
    local invalid=0
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        local value="${!var:-}"
        if [[ -z "$value" ]]; then
            print_error "Environment variable '$var' is not set"; invalid=1
        elif [[ "$value" == "your-"* || "$value" == "replace-"* ]]; then
            print_error "Environment variable '$var' still has a placeholder value"; invalid=1
        fi
    done

    if (( invalid )); then
        print_warning "Update .env with real values from the Twingate Admin console"
        exit 1
    fi
}

get_host_ip() { hostname -I | awk '{print $1}'; }

wait_for_service() {
    local name="${CONTAINER_NAME}"
    print_status "Waiting for connector container to start..."
    for _ in $(seq 1 15); do
        if docker ps --filter "name=$name" --filter "status=running" --format '{{.Names}}' | grep -q "^$name"; then
            print_success "Connector container is running"; return 0
        fi
        sleep 1
    done
    print_warning "Container may still be starting. Check: docker compose logs -f"; return 1
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

    local host_ip; host_ip=$(get_host_ip)

    print_status "Starting ${SERVICE_NAME} connector..."
    docker compose up -d
    wait_for_service || true

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Connector Information:${NC}"
    echo "  Network:      ${TWINGATE_NETWORK:-not-set}"
    echo "  Host Network: Enabled (no port mapping)"
    echo "  Host IP:      ${host_ip}"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  Admin Console: https://controller.twingate.com/"
    echo "  ./setup.sh start     Start connector"
    echo "  ./setup.sh stop      Stop connector"
    echo "  ./setup.sh logs      View logs"
    echo "  ./setup.sh status    Show status"
    echo "  ./setup.sh update    Update to latest"
}

cmd_start() {
    setup_env
    print_status "Starting ${SERVICE_NAME} connector..."
    docker compose up -d
    wait_for_service || true
    print_success "${SERVICE_NAME} started"
}

cmd_stop() {
    print_status "Stopping ${SERVICE_NAME} connector..."
    docker compose down
    print_success "${SERVICE_NAME} stopped"
}

cmd_restart() {
    print_status "Restarting ${SERVICE_NAME} connector..."
    docker compose down
    setup_env
    docker compose up -d
    wait_for_service || true
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
        print_success "Connector is running"
        docker compose ps
    else
        print_warning "Connector is not running"
    fi
}

cmd_update() {
    print_status "Updating ${SERVICE_NAME}..."
    docker compose pull
    docker compose up -d
    wait_for_service || true
    print_success "${SERVICE_NAME} updated"
}

show_usage() {
    echo "${SERVICE_NAME} Management Script"
    echo
    echo "Usage: ./setup.sh [command]"
    echo
    echo "Commands:"
    echo "  setup     Initial setup and start (default)"
    echo "  start     Start the connector"
    echo "  stop      Stop the connector"
    echo "  restart   Restart the connector"
    echo "  logs      View logs"
    echo "  status    Show connector status"
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
    status)   cmd_status ;;
    update)   cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
