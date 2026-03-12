#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="pydio"
CONTAINER_NAME="pydio-cells"
REQUIRED_RAM_MB=400
REQUIRED_DISK_GB=5
DEFAULT_PORT="8080"

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
    local host_ip; host_ip=$(get_host_ip)

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

    # Update host IP if set to localhost
    if grep -q "PYDIO_HOST=localhost" .env; then
        sed -i "s/PYDIO_HOST=localhost/PYDIO_HOST=$host_ip/" .env
        print_success "Updated host configuration to ${host_ip}"
    fi

    source .env
}

get_host_ip() { hostname -I | awk '{print $1}'; }

wait_for_service() {
    local port="${1:-$DEFAULT_PORT}" max=60
    print_status "Waiting for ${SERVICE_NAME} to start..."
    local host_ip; host_ip=$(get_host_ip)
    for i in $(seq 1 "$max"); do
        local code; code=$(curl -sf -o /dev/null -w "%{http_code}" "http://${host_ip}:${port}" 2>/dev/null || echo "000")
        if [[ "$code" == "200" || "$code" == "302" || "$code" == "401" ]]; then
            print_success "${SERVICE_NAME} is ready!"; return 0
        fi
        echo -n "."; sleep 3
    done
    echo; print_warning "${SERVICE_NAME} may still be starting. Check: docker compose logs -f"; return 1
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

    local port="${PYDIO_PORT:-$DEFAULT_PORT}"
    local host_ip; host_ip=$(get_host_ip)

    mkdir -p cellsdir mysqldir
    print_success "Data directories ready"

    # Check external storage
    if [[ -n "${EXTERNAL_STORAGE_PATH:-}" ]]; then
        if [[ ! -d "$EXTERNAL_STORAGE_PATH" ]]; then
            sudo mkdir -p "$EXTERNAL_STORAGE_PATH"
            sudo chown "$(id -u):$(id -g)" "$EXTERNAL_STORAGE_PATH"
            print_success "Created external storage: $EXTERNAL_STORAGE_PATH"
        else
            print_success "External storage available: $EXTERNAL_STORAGE_PATH"
        fi
    fi

    # Generate install.yml from template
    if [[ -f install.yml.template ]]; then
        set -a && source .env && set +a
        envsubst < install.yml.template > install.yml
        print_success "Generated install configuration"
    fi

    # Create external network
    if ! docker network inspect pi-services &>/dev/null; then
        docker network create pi-services
        print_success "Created pi-services network"
    fi

    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d

    echo -e "\n${BLUE}Waiting for MySQL to be healthy...${NC}"
    for i in $(seq 1 60); do
        if docker compose ps mysql 2>/dev/null | grep -q "healthy"; then
            print_success "MySQL is ready"; break
        fi
        if (( i == 60 )); then print_error "MySQL timeout"; exit 1; fi
        echo -n "."; sleep 2
    done

    wait_for_service "$port" || true

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  Web UI:   http://${host_ip}:${port}"
    echo "  Username: ${FRONTEND_LOGIN:-admin}"
    echo "  Password: check .env file"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start     Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop      Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs      View logs"
    echo "  ./setup.sh status    Show status"
    echo "  ./setup.sh update    Update to latest"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    source .env 2>/dev/null || true
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${PYDIO_PORT:-$DEFAULT_PORT}"
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
        print_success "Containers are running"
        docker compose ps
    else
        print_warning "Containers are not running"
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
    status)   cmd_status ;;
    update)   cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
