#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="plex"
CONTAINER_NAME="plex"
REQUIRED_RAM_MB=1024
REQUIRED_DISK_GB=5
DEFAULT_PORT="32400"

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

    # Check for hardware transcoding
    if [[ -d "/dev/dri" ]]; then
        print_success "Hardware transcoding device detected (/dev/dri)"
    else
        print_warning "No hardware transcoding device found"
    fi
}

setup_env() {
    if [[ ! -f .env ]]; then
        if [[ -f .env.example ]]; then
            cp .env.example .env
            print_success "Created .env from .env.example"
            print_warning "Set PLEX_CLAIM_TOKEN from https://www.plex.tv/claim"
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
    local port="${1:-$DEFAULT_PORT}" max=60
    print_status "Waiting for ${SERVICE_NAME} to start..."
    local host_ip; host_ip=$(get_host_ip)
    for i in $(seq 1 "$max"); do
        if curl -sf "http://${host_ip}:${port}/identity" &>/dev/null; then
            print_success "${SERVICE_NAME} is ready!"; return 0
        fi
        if (( i % 10 == 0 )); then echo -n " (${i}s)"; else echo -n "."; fi
        sleep 1
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

    mkdir -p config transcode media/{movies,tv,music,photos}
    print_success "Directories ready"

    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    wait_for_service || true

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  Web UI: http://${host_ip}:${DEFAULT_PORT}/web"
    echo
    if [[ -z "${PLEX_CLAIM_TOKEN:-}" ]]; then
        echo -e "${YELLOW}Claim token not set. Run: ./setup.sh claim${NC}"
    else
        echo -e "${GREEN}Server will auto-claim to your Plex account${NC}"
    fi
    echo
    echo -e "${BLUE}Media Directories:${NC}"
    echo "  Movies:  $(realpath media/movies)"
    echo "  TV:      $(realpath media/tv)"
    echo "  Music:   $(realpath media/music)"
    echo "  Photos:  $(realpath media/photos)"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start     Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop      Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs      View logs"
    echo "  ./setup.sh claim     Set Plex claim token"
    echo "  ./setup.sh shell     Open container shell"
    echo "  ./setup.sh status    Show status"
    echo "  ./setup.sh update    Update to latest"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    docker compose up -d
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${DEFAULT_PORT}/web"
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
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

cmd_claim() {
    echo -e "${PURPLE}=== Plex Claim Token Helper ===${NC}"
    echo
    echo -e "${BLUE}What is a Plex Claim Token?${NC}"
    echo "A claim token links your Plex server to your Plex account automatically."
    echo
    echo -e "${BLUE}How to get your claim token:${NC}"
    echo "  1. Open https://www.plex.tv/claim in your browser"
    echo "  2. Sign in to your Plex account"
    echo "  3. Copy the claim token (starts with 'claim-')"
    echo
    echo -n "Enter your claim token (or press Enter to skip): "
    read -r claim_token

    if [[ -n "$claim_token" ]]; then
        if grep -q "PLEX_CLAIM_TOKEN=" .env 2>/dev/null; then
            sed -i "s/PLEX_CLAIM_TOKEN=.*/PLEX_CLAIM_TOKEN=$claim_token/" .env
        else
            echo "PLEX_CLAIM_TOKEN=$claim_token" >> .env
        fi
        print_success "Claim token saved to .env"

        if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
            print_status "Restarting Plex to apply claim token..."
            docker compose restart
            print_success "Plex restarted"
        fi
    else
        print_warning "Skipped. Set manually in .env or visit http://localhost:${DEFAULT_PORT}/web"
    fi
}

cmd_status() {
    echo -e "${BLUE}=== ${SERVICE_NAME} Status ===${NC}"
    echo
    if docker compose ps | grep -q "Up\|running"; then
        print_success "Container is running"
        docker compose ps
        echo
        local host_ip; host_ip=$(get_host_ip)
        if curl -sf "http://${host_ip}:${DEFAULT_PORT}/identity" &>/dev/null; then
            print_success "Plex is responding"
        else
            print_warning "Plex is not responding yet"
        fi
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
    echo "  claim     Set Plex claim token interactively"
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
    claim)    cmd_claim ;;
    status)   cmd_status ;;
    update)   cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
