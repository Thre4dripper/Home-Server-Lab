#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_BIN=()
REQUIRED_ENV_VARS=(TWINGATE_NETWORK TWINGATE_ACCESS_TOKEN TWINGATE_REFRESH_TOKEN)

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat <<EOF
Usage: ./setup.sh [command]

Commands:
  up|start       Create/update the connector (default)
  down|stop      Stop and remove the connector container
  restart        Restart the connector
  status         Show connector container status
  logs           Tail connector logs
  update         Pull latest image and recreate the connector

Examples:
  ./setup.sh
  ./setup.sh logs
  ./setup.sh update
EOF
}

check_docker() {
    print_status "Checking Docker..."
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed or not in PATH."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running"
}

detect_compose() {
    print_status "Detecting Docker Compose..."
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_BIN=(docker compose)
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_BIN=(docker-compose)
    else
        print_error "Docker Compose v2 or v1 not found. Please install Docker Compose."
        exit 1
    fi
    print_success "Using '${COMPOSE_BIN[*]}'"
}

run_compose() {
    "${COMPOSE_BIN[@]}" "$@"
}

ensure_env_file() {
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            print_warning ".env file not found. Creating one from .env.example..."
            cp .env.example .env
            print_success ".env created. Please edit it with your connector tokens."
        else
            print_error ".env file is missing and .env.example was not found."
            exit 1
        fi
    fi
}

load_env_file() {
    if [[ -f ".env" ]]; then
        set -a
        source .env
        set +a
    fi
}

validate_required_env() {
    local invalid=0
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        local value="${!var:-}"
        if [[ -z "$value" ]]; then
            print_error "Environment variable '$var' is not set."
            invalid=1
            continue
        fi
        if [[ "$value" == "your-"* || "$value" == "replace-"* ]]; then
            print_error "Environment variable '$var' still has a placeholder value ('$value')."
            invalid=1
        fi
    done

    if (( invalid )); then
        print_warning "Update the .env file with real values from the Twingate Admin console."
        exit 1
    fi
}

wait_for_container() {
    local name="${CONTAINER_NAME:-twingate-diligent-binturong}"
    print_status "Waiting for container '$name' to report as running..."
    for _ in {1..15}; do
        if docker ps --filter "name=$name" --filter "status=running" --format '{{.Names}}' | grep -q "^$name$"; then
            print_success "Connector container is running."
            return 0
        fi
        sleep 1
    done
    print_warning "Container '$name' did not report running status yet. Check logs if needed."
}

show_post_setup_info() {
    local host_ip
    host_ip=$(hostname -I | awk '{print $1}')

    echo
    print_success "Twingate Connector is up!"
    echo "Network Name : ${TWINGATE_NETWORK:-not-set}"
    echo "Connector ID : ${CONTAINER_NAME:-twingate-connector}"
    echo "Host Network : Enabled (no local port mapping)"
    echo "Host IP      : ${host_ip:-127.0.0.1}"
    echo
    echo "Manage routing, resources, and users from https://controller.twingate.com/"
    echo "Logs: ./setup.sh logs"
    echo "Stop: ./setup.sh down"
    echo "Update Image: ./setup.sh update"
    echo
}

command_up() {
    ensure_env_file
    load_env_file
    validate_required_env
    check_docker
    detect_compose

    print_status "Starting (or updating) the Twingate connector..."
    run_compose up -d
    wait_for_container
    show_post_setup_info
}

command_down() {
    check_docker
    detect_compose
    print_status "Stopping the Twingate connector..."
    run_compose down
    print_success "Connector stopped."
}

command_status() {
    check_docker
    detect_compose
    print_status "Connector status:"
    run_compose ps
}

command_logs() {
    check_docker
    detect_compose
    print_status "Tailing logs (Ctrl+C to exit)..."
    run_compose logs -f || true
}

command_update() {
    ensure_env_file
    load_env_file
    validate_required_env
    check_docker
    detect_compose

    print_status "Pulling latest connector image..."
    run_compose pull
    print_status "Recreating connector with latest image..."
    run_compose up -d
    wait_for_container
    show_post_setup_info
}

command_restart() {
    command_down
    command_up
}

main() {
    local action=${1:-up}
    case "$action" in
        up|start)
            command_up
            ;;
        down|stop)
            command_down
            ;;
        restart)
            command_restart
            ;;
        status)
            command_status
            ;;
        logs)
            command_logs
            ;;
        update)
            command_update
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
