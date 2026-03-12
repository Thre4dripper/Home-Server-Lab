#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="samba"
CONTAINER_NAME="samba"
REQUIRED_RAM_MB=50
REQUIRED_DISK_GB=1
DEFAULT_PORT="445"

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

    # Create shared directories
    mkdir -p "${SHARE_PATH_1:-/home/pi/shared}"
    mkdir -p "${SHARE_PATH_2:-/home/pi/media}"
    mkdir -p "${SHARE_PATH_3:-/home/pi/documents}"
    mkdir -p samba_private

    chmod 775 "${SHARE_PATH_1:-/home/pi/shared}"
    chmod 775 "${SHARE_PATH_2:-/home/pi/media}"
    chmod 770 "${SHARE_PATH_3:-/home/pi/documents}"
    print_success "Shared directories ready"

    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d

    sleep 5
    if docker ps | grep -q "${CONTAINER_NAME}"; then
        print_success "${SERVICE_NAME} is running"
    else
        print_error "${SERVICE_NAME} failed to start"; exit 1
    fi

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Connection Information:${NC}"
    echo "  Windows: \\\\${host_ip}\\"
    echo "  macOS:   smb://${host_ip}/"
    echo "  Linux:   smb://${host_ip}/"
    echo
    echo -e "${BLUE}Shares:${NC}"
    echo "  \\\\${host_ip}\\Public     - Guest access (read/write)"
    echo "  \\\\${host_ip}\\Media      - Guest read, users write"
    echo "  \\\\${host_ip}\\Documents  - Authenticated users only"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh adduser <user>  Add a Samba user"
    echo "  ./setup.sh passwd <user>   Change user password"
    echo "  ./setup.sh listusers       List Samba users"
    echo "  ./setup.sh test            Test connectivity"
    echo "  ./setup.sh status          Show status"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
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

cmd_adduser() {
    local username="${2:-}"
    if [[ -z "$username" ]]; then
        print_error "Usage: ./setup.sh adduser <username>"; exit 1
    fi
    print_status "Adding Samba user: $username"
    docker exec -it "$CONTAINER_NAME" bash -c "adduser -D -H $username 2>/dev/null || true; smbpasswd -a $username"
    print_success "User $username added"
}

cmd_passwd() {
    local username="${2:-}"
    if [[ -z "$username" ]]; then
        print_error "Usage: ./setup.sh passwd <username>"; exit 1
    fi
    print_status "Changing password for: $username"
    docker exec -it "$CONTAINER_NAME" smbpasswd "$username"
}

cmd_listusers() {
    echo -e "${BLUE}=== Samba Users ===${NC}"
    docker exec "$CONTAINER_NAME" pdbedit -L 2>/dev/null || print_warning "No users configured"
}

cmd_test() {
    source .env 2>/dev/null || true
    local host_ip; host_ip=$(get_host_ip)

    echo -e "${BLUE}=== Samba Connectivity Test ===${NC}"
    echo

    echo -n "  Container Status: "
    if docker ps | grep -q "${CONTAINER_NAME}"; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Not running${NC}"; return 1
    fi

    echo -n "  SMB Port (${SMB_PORT:-445}):  "
    if nc -z localhost "${SMB_PORT:-445}" 2>/dev/null; then
        echo -e "${GREEN}Open${NC}"
    else
        echo -e "${RED}Closed${NC}"
    fi

    echo
    echo "Available Shares:"
    docker exec "$CONTAINER_NAME" smbclient -L localhost -U % -N 2>/dev/null | grep -E "^\s+\w+" || print_warning "Unable to list shares"

    echo
    echo "Connection URLs:"
    echo "  Windows: \\\\${host_ip}\\"
    echo "  macOS:   smb://${host_ip}/"
    echo "  Linux:   smb://${host_ip}/"
}

cmd_status() {
    echo -e "${BLUE}=== ${SERVICE_NAME} Status ===${NC}"
    echo
    if docker ps | grep -q "${CONTAINER_NAME}"; then
        print_success "Container is running"
        docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
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
    echo "  setup           Initial setup and start (default)"
    echo "  start           Start the service"
    echo "  stop            Stop the service"
    echo "  restart         Restart the service"
    echo "  logs            View logs"
    echo "  adduser <user>  Add a Samba user"
    echo "  passwd <user>   Change user password"
    echo "  listusers       List Samba users"
    echo "  test            Test Samba connectivity"
    echo "  status          Show service status"
    echo "  update          Update to latest version"
    echo "  help            Show this help message"
}

# ─── Main ────────────────────────────────────────────────────────────────────
case "${1:-setup}" in
    setup)     cmd_setup ;;
    start)     cmd_start ;;
    stop)      cmd_stop ;;
    restart)   cmd_restart ;;
    logs)      cmd_logs ;;
    adduser)   cmd_adduser "$@" ;;
    passwd)    cmd_passwd "$@" ;;
    listusers) cmd_listusers ;;
    test)      cmd_test ;;
    status)    cmd_status ;;
    update)    cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
