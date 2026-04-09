#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="nextcloud"
CONTAINER_NAME="nextcloud-aio-mastercontainer"
REQUIRED_RAM_MB=1536
REQUIRED_DISK_GB=10
DEFAULT_PORT="8081"

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
    local router_ip; router_ip=$(ip route | grep default | awk '{print $3}' | head -1)

    if [[ ! -f .env ]]; then
        if [[ -f .env.example ]]; then
            export PI_IP="$host_ip"
            export ROUTER_IP="$router_ip"
            envsubst < .env.example > .env
            print_success "Created .env from .env.example (IP: ${host_ip})"
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
    print_status "Waiting for ${SERVICE_NAME} AIO to start..."
    local host_ip; host_ip=$(get_host_ip)
    for i in $(seq 1 "$max"); do
        if sudo docker ps | grep -q "$CONTAINER_NAME"; then
            print_success "${SERVICE_NAME} AIO mastercontainer is running!"; return 0
        fi
        echo -n "."; sleep 2
    done
    echo; print_warning "${SERVICE_NAME} may still be starting. Check: sudo docker compose logs -f"; return 1
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

    # Validate domain
    if [[ -z "${NEXTCLOUD_DOMAIN:-}" ]]; then
        print_error "NEXTCLOUD_DOMAIN is not set in .env"
        print_status "Please set your domain: edit .env and add NEXTCLOUD_DOMAIN=nextcloud.yourdomain.com"
        exit 1
    fi

    # Create data directories
    if [[ -n "${EXTERNAL_STORAGE_PATH:-}" ]] && [[ ! -d "$EXTERNAL_STORAGE_PATH" ]]; then
        mkdir -p "$EXTERNAL_STORAGE_PATH"
        print_success "Created external storage: $EXTERNAL_STORAGE_PATH"
    fi

    print_status "Starting ${SERVICE_NAME} AIO..."
    sudo docker compose up -d

    echo -e "\n${BLUE}Waiting for AIO to initialize...${NC}"
    sleep 30
    wait_for_service || true

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  AIO Interface: http://${host_ip}:${DEFAULT_PORT}"
    echo "  Domain:        https://${NEXTCLOUD_DOMAIN}"
    echo
    echo -e "${BLUE}Initial Setup Steps:${NC}"
    echo "  1. Open http://${host_ip}:${DEFAULT_PORT} in your browser"
    echo "  2. Enter your domain: ${NEXTCLOUD_DOMAIN}"
    echo "  3. Create admin account and configure"
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
    sudo docker compose up -d
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${DEFAULT_PORT}"
}

cmd_stop() {
    print_status "Stopping ${SERVICE_NAME}..."
    sudo docker compose down
    print_success "${SERVICE_NAME} stopped"
}

cmd_restart() {
    print_status "Restarting ${SERVICE_NAME}..."
    sudo docker compose restart
    print_success "${SERVICE_NAME} restarted"
}

cmd_logs() {
    print_status "Showing ${SERVICE_NAME} logs (Ctrl+C to exit)..."
    sudo docker compose logs -f
}

cmd_status() {
    echo -e "${BLUE}=== ${SERVICE_NAME} Status ===${NC}"
    echo
    if sudo docker compose ps | grep -q "Up\|running"; then
        print_success "Container is running"
        sudo docker compose ps
    else
        print_warning "Container is not running"
    fi
}

cmd_update() {
    print_status "Updating ${SERVICE_NAME}..."
    sudo docker compose pull
    sudo docker compose up -d
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
    echo
    echo "Note: This service uses 'sudo docker compose' as required by Nextcloud AIO."
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
