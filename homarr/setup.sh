#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="Homarr"
CONTAINER_NAME="homarr"
REQUIRED_RAM_MB=200
REQUIRED_DISK_GB=1
DEFAULT_PORT="7575"

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

    # Generate encryption key if default or invalid
    if [[ "${SECRET_ENCRYPTION_KEY:-}" == "your-64-character-secret-key-change-this-in-production-NOW" ]] || \
       [[ ${#SECRET_ENCRYPTION_KEY:-} -ne 64 ]]; then
        local new_key; new_key=$(openssl rand -hex 32)
        sed -i "s/SECRET_ENCRYPTION_KEY=.*/SECRET_ENCRYPTION_KEY=$new_key/" .env
        print_success "Generated secure encryption key"
        source .env
    fi
}

get_host_ip() { hostname -I | awk '{print $1}'; }

wait_for_service() {
    local port="${1:-$DEFAULT_PORT}" max=30
    print_status "Waiting for ${SERVICE_NAME} to start..."
    for i in $(seq 1 "$max"); do
        if curl -sf -o /dev/null "http://localhost:${port}"; then
            print_success "${SERVICE_NAME} is ready!"; return 0
        fi
        echo -n "."; sleep 1
    done
    echo; print_warning "${SERVICE_NAME} may still be starting. Check: docker compose logs -f"; return 1
}

# ─── Key Management (absorbed from manage-key.sh) ───────────────────────────
cmd_manage_key() {
    source .env

    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}   Homarr Key Management${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo
    echo "Homarr uses a 64-character hex key to encrypt sensitive data."
    echo
    echo "Options:"
    echo "  1. Generate new key (WARNING: existing encrypted data will be unreadable)"
    echo "  2. Display current key for backup"
    echo "  3. Validate current key format"
    echo "  4. Exit"
    echo
    read -rp "Enter your choice (1-4): " choice

    case "$choice" in
        1)
            print_warning "Generating a new key will make ALL existing encrypted data unreadable!"
            read -rp "Are you sure? (yes/no): " confirm
            if [[ "$confirm" == "yes" ]]; then
                local new_key; new_key=$(openssl rand -hex 32)
                cp .env ".env.backup.$(date +%Y%m%d_%H%M%S)"
                sed -i "s/SECRET_ENCRYPTION_KEY=.*/SECRET_ENCRYPTION_KEY=$new_key/" .env
                print_success "New encryption key generated and saved"
                echo "  New key: $new_key"
                print_warning "Restart Homarr: ./setup.sh restart"
            else
                print_status "Operation cancelled"
            fi
            ;;
        2)
            echo
            echo "SECRET_ENCRYPTION_KEY=${SECRET_ENCRYPTION_KEY}"
            echo
            print_warning "Save this key in a secure location!"
            ;;
        3)
            if [[ ${#SECRET_ENCRYPTION_KEY} -eq 64 ]] && [[ $SECRET_ENCRYPTION_KEY =~ ^[0-9a-fA-F]{64}$ ]]; then
                print_success "Encryption key format is valid (64 hex characters)"
            else
                print_error "Key format invalid (length: ${#SECRET_ENCRYPTION_KEY}, required: 64 hex)"
            fi
            ;;
        4) exit 0 ;;
        *) print_error "Invalid choice" ;;
    esac
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

    mkdir -p homarr_data
    print_success "Directories ready"

    local host_ip; host_ip=$(get_host_ip)
    local port="${HOMARR_PORT:-$DEFAULT_PORT}"

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
    echo "  ./setup.sh start       Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop        Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs        View logs"
    echo "  ./setup.sh manage-key  Manage encryption key"
    echo "  ./setup.sh status      Show status"
    echo "  ./setup.sh update      Update to latest"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    source .env 2>/dev/null || true
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${HOMARR_PORT:-$DEFAULT_PORT}"
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
    echo "  manage-key  Manage encryption key"
    echo "  status      Show service status"
    echo "  update      Update to latest version"
    echo "  help        Show this help message"
}

# ─── Main ────────────────────────────────────────────────────────────────────
case "${1:-setup}" in
    setup)      cmd_setup ;;
    start)      cmd_start ;;
    stop)       cmd_stop ;;
    restart)    cmd_restart ;;
    logs)       cmd_logs ;;
    manage-key) cmd_manage_key ;;
    status)     cmd_status ;;
    update)     cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
