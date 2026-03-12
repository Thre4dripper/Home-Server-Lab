#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="rclone"
CONTAINER_NAME="rclone"
REQUIRED_RAM_MB=50
REQUIRED_DISK_GB=1
DEFAULT_PORT="5572"

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
            # Generate random serve password
            local rclone_pass; rclone_pass=$(openssl rand -base64 12)
            sed -i "s/your-password-change-this/${rclone_pass}/" .env
            print_success "Created .env from .env.example (generated serve password)"
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
    local max=30
    print_status "Waiting for ${SERVICE_NAME} container to start..."
    for i in $(seq 1 "$max"); do
        if docker exec "$CONTAINER_NAME" rclone version &>/dev/null; then
            print_success "${SERVICE_NAME} container is ready!"; return 0
        fi
        echo -n "."; sleep 1
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

    local host_ip; host_ip=$(get_host_ip)

    mkdir -p config data
    print_success "Directories ready"

    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    wait_for_service || true

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  HTTP Serve: http://${host_ip}:5572 (if configured)"
    echo "  WebDAV:     http://${host_ip}:5573 (if configured)"
    echo
    echo -e "${BLUE}Getting Started:${NC}"
    echo "  Configure remotes: docker exec -it ${CONTAINER_NAME} rclone config"
    echo "  List remotes:      docker exec ${CONTAINER_NAME} rclone listremotes"
    echo "  Test connection:   docker exec ${CONTAINER_NAME} rclone lsd remote:"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start     Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop      Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs      View logs"
    echo "  ./setup.sh config    Configure cloud remotes"
    echo "  ./setup.sh shell     Open container shell"
    echo "  ./setup.sh status    Show status"
    echo "  ./setup.sh update    Update to latest"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started"
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
    docker exec -it "$CONTAINER_NAME" sh
}

cmd_config() {
    print_status "Opening rclone configuration..."
    docker exec -it "$CONTAINER_NAME" rclone config
}

cmd_status() {
    echo -e "${BLUE}=== ${SERVICE_NAME} Status ===${NC}"
    echo
    if docker compose ps | grep -q "Up\|running"; then
        print_success "Container is running"
        docker compose ps
        echo
        echo -e "${BLUE}Configured Remotes:${NC}"
        docker exec "$CONTAINER_NAME" rclone listremotes 2>/dev/null || echo "  (none)"
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
    echo "  shell     Open container shell"
    echo "  config    Configure cloud remotes interactively"
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
    shell)    cmd_shell ;;
    config)   cmd_config ;;
    status)   cmd_status ;;
    update)   cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
