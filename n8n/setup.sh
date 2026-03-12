#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="n8n"
CONTAINER_NAME="n8n"
REQUIRED_RAM_MB=300
REQUIRED_DISK_GB=2
DEFAULT_PORT="5678"

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
        # Generate encryption key
        local enc_key; enc_key=$(openssl rand -hex 32)
        sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$enc_key/" .env
        print_success "Generated secure encryption key"
    else
        print_status "Using existing .env file"
    fi
    source .env
}

get_host_ip() { hostname -I | awk '{print $1}'; }

wait_for_service() {
    local port="${1:-$DEFAULT_PORT}" max=30
    print_status "Waiting for ${SERVICE_NAME} to start..."
    local host_ip; host_ip=$(get_host_ip)
    for i in $(seq 1 "$max"); do
        if curl -sf -o /dev/null -w "%{http_code}" "http://${host_ip}:${port}" | grep -q "200\|401"; then
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

    mkdir -p n8n_data
    print_success "Directories ready"

    local host_ip; host_ip=$(get_host_ip)

    # Auto-detect and update host IP
    if grep -q "N8N_HOST=localhost" .env; then
        sed -i "s/N8N_HOST=localhost/N8N_HOST=$host_ip/" .env
        sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=http://$host_ip:\${N8N_PORT}|" .env
        print_success "Updated host configuration"
        source .env
    fi

    local port="${N8N_PORT:-$DEFAULT_PORT}"

    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    wait_for_service "$port" || true

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  Web UI:   http://${host_ip}:${port}"
    echo "  Username: ${N8N_BASIC_AUTH_USER:-check .env}"
    echo "  Password: ${N8N_BASIC_AUTH_PASSWORD:-check .env}"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start     Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop      Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs      View logs"
    echo "  ./setup.sh shell     Open container shell"
    echo "  ./setup.sh test      Test tool availability"
    echo "  ./setup.sh backup    Create backup"
    echo "  ./setup.sh rebuild   Rebuild custom image"
    echo "  ./setup.sh status    Show status"
    echo "  ./setup.sh update    Update to latest"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    source .env 2>/dev/null || true
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${N8N_PORT:-$DEFAULT_PORT}"
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

cmd_shell() {
    print_status "Opening shell in ${SERVICE_NAME} container..."
    docker exec -it "$CONTAINER_NAME" bash
}

cmd_test() {
    print_status "Testing tool availability in ${SERVICE_NAME} container..."
    echo
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "${SERVICE_NAME} container is not running"; exit 1
    fi

    local test_cmd
    for test_cmd in docker kubectl terraform aws python3 git curl wget jq yq ssh rsync helm rclone; do
        echo -n "  ${test_cmd}: "
        if docker exec "$CONTAINER_NAME" bash -c "command -v $test_cmd > /dev/null 2>&1"; then
            local version
            version=$(docker exec "$CONTAINER_NAME" bash -c "$test_cmd --version 2>&1 | head -1" 2>/dev/null || echo "installed")
            echo -e "${GREEN}✓${NC} $version"
        else
            echo -e "${RED}✗${NC} Not found"
        fi
    done

    echo
    echo -n "  Docker socket: "
    if docker exec "$CONTAINER_NAME" docker ps &>/dev/null; then
        echo -e "${GREEN}✓${NC} Can access host Docker"
    else
        echo -e "${RED}✗${NC} Cannot access Docker socket"
    fi
}

cmd_backup() {
    local backup_file="n8n-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    print_status "Creating backup: ${backup_file}"
    tar czf "$backup_file" n8n_data/
    print_success "Backup saved to: ${backup_file}"
}

cmd_rebuild() {
    print_status "Rebuilding ${SERVICE_NAME} image..."
    docker compose down
    docker compose build --no-cache
    docker compose up -d
    print_success "Rebuild complete!"
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
    print_status "Updating ${SERVICE_NAME} (rebuilding custom image)..."
    docker compose down
    docker compose build --no-cache
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
    echo "  shell     Open container shell"
    echo "  test      Test tool availability in container"
    echo "  backup    Create backup of n8n data"
    echo "  rebuild   Rebuild custom Docker image"
    echo "  status    Show service status"
    echo "  update    Update to latest version (rebuilds image)"
    echo "  help      Show this help message"
}

# ─── Main ────────────────────────────────────────────────────────────────────
case "${1:-setup}" in
    setup)    cmd_setup ;;
    start)    cmd_start ;;
    stop)     cmd_stop ;;
    restart)  cmd_restart ;;
    logs)     cmd_logs ;;
    shell)    cmd_shell ;;
    test)     cmd_test ;;
    backup)   cmd_backup ;;
    rebuild)  cmd_rebuild ;;
    status)   cmd_status ;;
    update)   cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
