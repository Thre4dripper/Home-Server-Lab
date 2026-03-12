#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="GitLab"
CONTAINER_NAME="gitlab-server"
REQUIRED_RAM_MB=2048
REQUIRED_DISK_GB=10
DEFAULT_PORT="8929"

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
    set -a; source .env; set +a
}

get_host_ip() { hostname -I | awk '{print $1}'; }

wait_for_service() {
    local port="${1:-$DEFAULT_PORT}" max=120
    print_status "Waiting for ${SERVICE_NAME} to initialize (this can take 5-10 minutes)..."
    for i in $(seq 1 "$max"); do
        if curl -sf -o /dev/null "http://localhost:${port}/-/health"; then
            print_success "${SERVICE_NAME} is ready!"; return 0
        fi
        if (( i % 10 == 0 )); then echo -n " [${i}/${max}]"; else echo -n "."; fi
        sleep 5
    done
    echo; print_warning "${SERVICE_NAME} may still be initializing. Check: docker compose logs -f"; return 1
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

    mkdir -p config logs data backups
    sudo chown -R 998:998 config logs data backups 2>/dev/null || \
        print_warning "Could not set ownership. Run: sudo chown -R 998:998 config logs data backups"

    local host_ip; host_ip=$(get_host_ip)
    local port="${GITLAB_PORT:-$DEFAULT_PORT}"

    print_status "Starting ${SERVICE_NAME}..."
    print_status "First startup may take 5-10 minutes..."
    docker compose up -d
    wait_for_service "$port" || true

    echo
    print_success "Setup initiated!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  Web UI:   http://${host_ip}:${port}"
    echo "  Username: root"
    echo "  Password: ${GITLAB_ROOT_PASSWORD:-check .env}"
    echo "  Git SSH:  ssh://git@${host_ip}:${GITLAB_SSH_PORT:-2424}/user/project.git"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start       Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop        Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs        View logs"
    echo "  ./setup.sh shell       Open container shell"
    echo "  ./setup.sh console     Open Rails console"
    echo "  ./setup.sh backup      Create backup"
    echo "  ./setup.sh restore     Restore from backup"
    echo "  ./setup.sh reset-root  Reset root password"
    echo "  ./setup.sh status      Show status"
    echo "  ./setup.sh update      Update to latest"
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
    docker compose logs -f gitlab
}

cmd_shell() {
    print_status "Opening shell in ${SERVICE_NAME} container..."
    docker compose exec gitlab bash
}

cmd_console() {
    print_status "Opening ${SERVICE_NAME} Rails console (type 'exit' to return)..."
    docker compose exec gitlab gitlab-rails console
}

cmd_backup() {
    print_status "Creating ${SERVICE_NAME} backup..."
    docker compose exec gitlab gitlab-backup create
    echo
    print_success "Backup completed!"
    print_status "Available backups:"
    docker compose exec gitlab ls -la /var/opt/gitlab/backups/
}

cmd_restore() {
    print_status "Available backups:"
    docker compose exec gitlab ls -la /var/opt/gitlab/backups/
    echo
    read -rp "Enter backup timestamp (format: YYYYMMDD_HHmmss): " backup_timestamp
    if [[ -z "$backup_timestamp" ]]; then print_error "No timestamp provided"; exit 1; fi

    echo
    print_warning "This will replace ALL current data!"
    read -rp "Are you sure? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then print_status "Restore cancelled"; exit 0; fi

    print_status "Stopping services..."
    docker compose exec gitlab gitlab-ctl stop puma
    docker compose exec gitlab gitlab-ctl stop sidekiq

    print_status "Restoring backup..."
    docker compose exec gitlab gitlab-backup restore BACKUP="$backup_timestamp"

    print_status "Restarting ${SERVICE_NAME}..."
    docker compose restart
    print_success "Restore completed!"
}

cmd_reset_root() {
    read -rsp "Enter new root password: " new_password; echo
    read -rsp "Confirm new password: " confirm_password; echo
    if [[ "$new_password" != "$confirm_password" ]]; then
        print_error "Passwords don't match"; exit 1
    fi
    print_status "Resetting root password..."
    docker compose exec gitlab gitlab-rails runner \
        "user = User.where(id: 1).first; user.password = '$new_password'; user.password_confirmation = '$new_password'; user.save!"
    print_success "Root password reset successfully!"
}

cmd_status() {
    echo -e "${BLUE}=== ${SERVICE_NAME} Status ===${NC}"
    echo
    if docker compose ps | grep -q "Up\|running"; then
        print_success "Container is running"
        docker compose ps
        echo
        source .env 2>/dev/null || true
        local host_ip; host_ip=$(get_host_ip)
        local port="${GITLAB_PORT:-$DEFAULT_PORT}"
        local health_code
        health_code=$(curl -sf -o /dev/null -w "%{http_code}" "http://${host_ip}:${port}/-/health" 2>/dev/null || echo "000")
        case "$health_code" in
            200|302) print_success "Health: Healthy" ;;
            503)     print_warning "Health: Starting up" ;;
            *)       print_warning "Health: HTTP ${health_code}" ;;
        esac
        echo
        docker stats "${CONTAINER_NAME}" --no-stream --format "  CPU: {{.CPUPerc}} | RAM: {{.MemUsage}} | NET: {{.NetIO}}" 2>/dev/null || true
    else
        print_warning "Container is not running"
    fi
}

cmd_update() {
    print_warning "Always backup before updating!"
    read -rp "Have you created a recent backup? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        print_status "Please create a backup first: ./setup.sh backup"; exit 0
    fi
    print_status "Updating ${SERVICE_NAME}..."
    docker compose pull
    docker compose up -d
    print_success "${SERVICE_NAME} updated. May take a few minutes to reconfigure."
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
    echo "  shell       Open container shell"
    echo "  console     Open GitLab Rails console"
    echo "  backup      Create a backup"
    echo "  restore     Restore from backup"
    echo "  reset-root  Reset root password"
    echo "  status      Show service status and health"
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
    shell)      cmd_shell ;;
    console)    cmd_console ;;
    backup)     cmd_backup ;;
    restore)    cmd_restore ;;
    reset-root) cmd_reset_root ;;
    status)     cmd_status ;;
    update)     cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
