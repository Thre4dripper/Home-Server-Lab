#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SERVICE_NAME="Forgejo"
DEFAULT_PORT=3000
DEFAULT_SSH_PORT=2222
NETWORK_NAME="pi-services"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
print_status()  { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error()   { echo -e "${RED}[✗]${NC} $1" >&2; }

get_host_ip() {
    hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost"
}

# ─── Checks ───────────────────────────────────────────────────────────────────
check_docker() {
    if ! command -v docker &>/dev/null; then
        print_error "Docker is not installed. Visit https://docs.docker.com/get-docker/"
        exit 1
    fi
    if ! docker info &>/dev/null; then
        print_error "Docker daemon is not running or you lack permission."
        exit 1
    fi
}

check_system() {
    print_status "Checking system resources..."
    local mem_mb; mem_mb=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
    if [[ $mem_mb -lt 512 ]]; then
        print_warning "Low available memory: ${mem_mb}MB. Forgejo recommends at least 512MB free."
    else
        print_success "Available memory: ${mem_mb}MB"
    fi
}

# ─── Setup helpers ────────────────────────────────────────────────────────────
setup_env() {
    if [[ ! -f .env ]]; then
        print_status "Creating .env from .env.example..."
        cp .env.example .env

        # Generate random keys
        local secret_key; secret_key=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | base64 | tr -d '=+/')
        local internal_token; internal_token=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | base64 | tr -d '=+/')
        sed -i "s/generate_random_key_here/${secret_key}/" .env
        sed -i "s/generate_random_token_here/${internal_token}/" .env

        print_success ".env created with random security keys"
        print_warning "Review .env and update FORGEJO_DOMAIN before first run"
        print_warning "Set FORGEJO_RUNNER_REGISTRATION_TOKEN after Forgejo is running"
    else
        print_success ".env already exists — skipping"
    fi
}

setup_dirs() {
    print_status "Creating data directories..."
    mkdir -p forgejo_data runner_data
    print_success "Directories ready"
}

setup_network() {
    if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
        print_status "Creating Docker network: ${NETWORK_NAME}..."
        docker network create "${NETWORK_NAME}"
        print_success "Network created: ${NETWORK_NAME}"
    else
        print_success "Network already exists: ${NETWORK_NAME}"
    fi
}

wait_for_service() {
    local url=$1
    local timeout=${2:-60}
    local elapsed=0

    print_status "Waiting for ${SERVICE_NAME} to be ready at ${url}..."
    while ! curl -sf "${url}/api/healthz" &>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            print_warning "${SERVICE_NAME} not ready after ${timeout}s — check logs with: ./setup.sh logs"
            return 1
        fi
        sleep 3
        elapsed=$((elapsed + 3))
        echo -n "."
    done
    echo
    print_success "${SERVICE_NAME} is ready!"
}

# ─── Commands ─────────────────────────────────────────────────────────────────
cmd_setup() {
    echo
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       ${SERVICE_NAME} Setup                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo

    check_docker
    check_system
    setup_env
    setup_dirs
    setup_network

    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d forgejo

    source .env 2>/dev/null || true
    local host_ip; host_ip=$(get_host_ip)
    local port="${FORGEJO_PORT:-$DEFAULT_PORT}"
    local ssh_port="${FORGEJO_SSH_PORT:-$DEFAULT_SSH_PORT}"

    wait_for_service "http://${host_ip}:${port}" 120 || true

    echo
    print_success "${SERVICE_NAME} is up!"
    echo -e "${BLUE}Web UI:${NC}  http://${host_ip}:${port}"
    echo -e "${BLUE}SSH:${NC}     ${host_ip}:${ssh_port}"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Open the web UI and complete initial setup"
    echo "  2. Get a runner token: Site Admin → Actions → Runners"
    echo "  3. Add token to .env: FORGEJO_RUNNER_REGISTRATION_TOKEN=..."
    echo "  4. Start runner: docker compose up -d forgejo-runner"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start     Start all services"
    echo "  ./setup.sh stop      Stop all services"
    echo "  ./setup.sh logs      View logs"
    echo "  ./setup.sh status    Show status"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    source .env 2>/dev/null || true
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${FORGEJO_PORT:-$DEFAULT_PORT}"
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
    print_status "Opening shell in Forgejo container..."
    docker compose exec forgejo-server bash || docker compose exec forgejo-server sh
}

cmd_backup() {
    local backup_file="forgejo-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    print_status "Creating backup: ${backup_file}"
    docker compose exec forgejo-server forgejo admin dump --file /tmp/forgejo-dump.zip 2>/dev/null || true
    tar czf "$backup_file" forgejo_data/
    print_success "Backup saved to: ${backup_file}"
}

cmd_status() {
    echo -e "${BLUE}=== ${SERVICE_NAME} Status ===${NC}"
    echo
    if docker compose ps | grep -q "Up\|running"; then
        print_success "Services are running"
        docker compose ps
    else
        print_warning "Services are not running"
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
    echo "  start     Start all services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  logs      View logs"
    echo "  shell     Open Forgejo container shell"
    echo "  backup    Create backup of data"
    echo "  status    Show service status"
    echo "  update    Update to latest version"
    echo "  help      Show this help message"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
case "${1:-setup}" in
    setup)   cmd_setup ;;
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    restart) cmd_restart ;;
    logs)    cmd_logs ;;
    shell)   cmd_shell ;;
    backup)  cmd_backup ;;
    status)  cmd_status ;;
    update)  cmd_update ;;
    help|--help|-h) show_usage ;;
    *) print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
