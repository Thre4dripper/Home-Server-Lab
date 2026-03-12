#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="qbittorrent"
CONTAINER_NAME="qbittorrent"
REQUIRED_RAM_MB=500
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
    local host_ip; host_ip=$(get_host_ip)
    for i in $(seq 1 "$max"); do
        if curl -sf -o /dev/null "http://${host_ip}:${port}"; then
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

    local port="${QBT_WEBUI_PORT:-$DEFAULT_PORT}"
    local host_ip; host_ip=$(get_host_ip)

    mkdir -p config downloads
    print_success "Directories ready"

    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d

    sleep 5
    wait_for_service "$port" || true

    # Try to extract temporary password from logs
    local temp_pass
    temp_pass=$(docker compose logs "$CONTAINER_NAME" 2>&1 | grep -i "temporary password is provided" | sed -n 's/.*password is provided for this session: \(.*\)/\1/p' | tail -1 || true)

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  WebUI: http://${host_ip}:${port}"
    echo "  Username: admin"
    if [[ -n "$temp_pass" ]]; then
        echo "  Temporary Password: $temp_pass"
        echo -e "  ${YELLOW}Change this immediately after login!${NC}"
    else
        echo "  Password: adminadmin (or check logs for temp password)"
    fi
    echo
    echo -e "${BLUE}Downloads:${NC} ${DOWNLOADS_PATH:-./downloads}"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start       Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop        Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs        View logs"
    echo "  ./setup.sh password    Show password from logs"
    echo "  ./setup.sh permissions Fix download directory permissions"
    echo "  ./setup.sh status      Show status"
    echo "  ./setup.sh update      Update to latest"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    source .env 2>/dev/null || true
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${QBT_WEBUI_PORT:-$DEFAULT_PORT}"
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

cmd_password() {
    print_status "Checking logs for temporary password..."
    docker compose logs "$CONTAINER_NAME" 2>&1 | grep -i "password" || print_warning "No password found in logs"
}

cmd_permissions() {
    source .env 2>/dev/null || true
    local dl_path="${DOWNLOADS_PATH:-./downloads}"
    local puid="${PUID:-1000}"
    local pgid="${PGID:-1000}"

    print_status "Fixing permissions on ${dl_path}..."

    if [[ ! -d "$dl_path" ]]; then
        mkdir -p "$dl_path"
        print_success "Created downloads directory"
    fi

    echo "Current ownership:"
    ls -ld "$dl_path"
    echo

    sudo chown -R "${puid}:${pgid}" "$dl_path" 2>/dev/null && {
        print_success "Permissions fixed"
    } || {
        print_warning "Could not change ownership. For external drives, use fstab uid/gid options."
    }
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
    echo "  setup       Initial setup and start (default)"
    echo "  start       Start the service"
    echo "  stop        Stop the service"
    echo "  restart     Restart the service"
    echo "  logs        View logs"
    echo "  password    Show password from container logs"
    echo "  permissions Fix download directory permissions"
    echo "  status      Show service status"
    echo "  update      Update to latest version"
    echo "  help        Show this help message"
}

# ─── Main ────────────────────────────────────────────────────────────────────
case "${1:-setup}" in
    setup)       cmd_setup ;;
    start)       cmd_start ;;
    stop)        cmd_stop ;;
    restart)     cmd_restart ;;
    logs)        cmd_logs ;;
    password)    cmd_password ;;
    permissions) cmd_permissions ;;
    status)      cmd_status ;;
    update)      cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
