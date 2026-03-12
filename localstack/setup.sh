#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="LocalStack"
CONTAINER_NAME="localstack-main"
REQUIRED_RAM_MB=500
REQUIRED_DISK_GB=2
DEFAULT_PORT="4566"

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

get_edition() {
    local edition="${LOCALSTACK_EDITION:-community}"
    echo "${edition,,}"  # lowercase
}

get_compose_file() {
    local edition; edition=$(get_edition)
    case "$edition" in
        pro) echo "docker-compose.pro.yml" ;;
        *)   echo "docker-compose.community.yml" ;;
    esac
}

wait_for_service() {
    local port="${1:-$DEFAULT_PORT}" max=30
    print_status "Waiting for ${SERVICE_NAME} to start..."
    for i in $(seq 1 "$max"); do
        if curl -sf -o /dev/null "http://localhost:${port}/_localstack/health"; then
            print_success "${SERVICE_NAME} is ready!"; return 0
        fi
        echo -n "."; sleep 2
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

    local edition; edition=$(get_edition)
    local compose_file; compose_file=$(get_compose_file)
    print_status "Edition: ${edition}"

    if [[ ! -f "$compose_file" ]]; then
        print_error "Compose file not found: ${compose_file}"; exit 1
    fi

    if [[ "$edition" == "pro" ]]; then
        if [[ "${LOCALSTACK_AUTH_TOKEN:-your_auth_token_here}" == "your_auth_token_here" ]]; then
            print_warning "Pro edition requires a valid LOCALSTACK_AUTH_TOKEN in .env"
        fi
    fi

    mkdir -p volume
    print_success "Directories ready"

    local host_ip; host_ip=$(get_host_ip)
    local port="${LOCALSTACK_PORT:-$DEFAULT_PORT}"

    print_status "Starting ${SERVICE_NAME} (${edition})..."
    docker compose -f "$compose_file" up -d
    wait_for_service "$port" || true

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  API Endpoint: http://${host_ip}:${port}"
    echo "  Health Check: http://${host_ip}:${port}/_localstack/health"
    echo "  Edition:      ${edition}"
    echo
    echo -e "${BLUE}AWS CLI Configuration:${NC}"
    echo "  export AWS_ACCESS_KEY_ID=test"
    echo "  export AWS_SECRET_ACCESS_KEY=test"
    echo "  export AWS_ENDPOINT_URL=http://${host_ip}:${port}"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start     Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop      Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs      View logs"
    echo "  ./setup.sh health    Check service health"
    echo "  ./setup.sh status    Show status"
    echo "  ./setup.sh update    Update to latest"
}

cmd_start() {
    setup_env
    local compose_file; compose_file=$(get_compose_file)
    print_status "Starting ${SERVICE_NAME} ($(get_edition))..."
    docker compose -f "$compose_file" up -d
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${LOCALSTACK_PORT:-$DEFAULT_PORT}"
}

cmd_stop() {
    setup_env
    local compose_file; compose_file=$(get_compose_file)
    print_status "Stopping ${SERVICE_NAME}..."
    docker compose -f "$compose_file" down
    print_success "${SERVICE_NAME} stopped"
}

cmd_restart() {
    setup_env
    local compose_file; compose_file=$(get_compose_file)
    print_status "Restarting ${SERVICE_NAME}..."
    docker compose -f "$compose_file" restart
    print_success "${SERVICE_NAME} restarted"
}

cmd_logs() {
    setup_env
    local compose_file; compose_file=$(get_compose_file)
    print_status "Showing ${SERVICE_NAME} logs (Ctrl+C to exit)..."
    docker compose -f "$compose_file" logs -f
}

cmd_health() {
    source .env 2>/dev/null || true
    local port="${LOCALSTACK_PORT:-$DEFAULT_PORT}"
    print_status "Checking ${SERVICE_NAME} health..."
    local response
    response=$(curl -sf "http://localhost:${port}/_localstack/health" 2>/dev/null) || {
        print_error "${SERVICE_NAME} is not responding"; exit 1
    }
    print_success "Health response:"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
}

cmd_status() {
    setup_env
    local compose_file; compose_file=$(get_compose_file)
    echo -e "${BLUE}=== ${SERVICE_NAME} Status ($(get_edition)) ===${NC}"
    echo
    if docker compose -f "$compose_file" ps | grep -q "Up\|running"; then
        print_success "Container is running"
        docker compose -f "$compose_file" ps
    else
        print_warning "Container is not running"
    fi
}

cmd_update() {
    setup_env
    local compose_file; compose_file=$(get_compose_file)
    print_status "Updating ${SERVICE_NAME}..."
    docker compose -f "$compose_file" pull
    docker compose -f "$compose_file" up -d
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
    echo "  health    Check service health"
    echo "  status    Show service status"
    echo "  update    Update to latest version"
    echo "  help      Show this help message"
    echo
    echo "Edition is controlled by LOCALSTACK_EDITION in .env (community/pro)"
}

# ─── Main ────────────────────────────────────────────────────────────────────
case "${1:-setup}" in
    setup)    cmd_setup ;;
    start)    cmd_start ;;
    stop)     cmd_stop ;;
    restart)  cmd_restart ;;
    logs)     cmd_logs ;;
    health)   cmd_health ;;
    status)   cmd_status ;;
    update)   cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
