#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICE_NAME="pihole"
CONTAINER_NAME="pihole"
REQUIRED_RAM_MB=100
REQUIRED_DISK_GB=2
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
    local host_ip; host_ip=$(get_host_ip)
    local router_ip; router_ip=$(ip route | grep default | awk '{print $3}' | head -1)
    local network_base; network_base=$(echo "$host_ip" | cut -d. -f1-3)
    local network_cidr="${network_base}.0/24"

    if [[ ! -f .env ]]; then
        if [[ -f .env.example ]]; then
            export PIHOLE_IP="$host_ip"
            export ROUTER_IP="$router_ip"
            export NETWORK_CIDR="$network_cidr"
            envsubst < .env.example > .env
            print_success "Created .env from .env.example (IP: ${host_ip})"
        else
            print_error ".env.example not found"; exit 1
        fi
    else
        print_status "Using existing .env file"
    fi

    # Update network settings in .env
    sed -i "s/PIHOLE_IP=.*/PIHOLE_IP=$host_ip/" .env
    sed -i "s/ROUTER_IP=.*/ROUTER_IP=$router_ip/" .env
    sed -i "s|NETWORK_CIDR=.*|NETWORK_CIDR=$network_cidr|" .env

    source .env
}

get_host_ip() { hostname -I | awk '{print $1}'; }

wait_for_service() {
    local port="${1:-$DEFAULT_PORT}" max=30
    print_status "Waiting for ${SERVICE_NAME} to start..."
    local host_ip; host_ip=$(get_host_ip)
    for i in $(seq 1 "$max"); do
        local code; code=$(curl -sf -o /dev/null -w "%{http_code}" "http://${host_ip}:${port}/admin/" 2>/dev/null || echo "000")
        if [[ "$code" == "200" || "$code" == "302" ]]; then
            print_success "${SERVICE_NAME} is ready!"; return 0
        fi
        echo -n "."; sleep 2
    done
    echo; print_warning "${SERVICE_NAME} may still be starting. Check: sudo docker compose logs -f"; return 1
}

configure_dns() {
    local host_ip; host_ip=$(get_host_ip)

    print_status "Configuring local DNS entries..."

    if [[ -f "./dns-entries.conf" ]]; then
        local dns_array=""
        while IFS='=' read -r domain ip || [[ -n "$domain" ]]; do
            # Skip empty lines and comments
            [[ -z "$domain" || "$domain" =~ ^[[:space:]]*# ]] && continue
            domain=$(echo "$domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            ip=$(echo "$ip" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -n "$domain" && -n "$ip" ]] && dns_array="${dns_array}\"${ip} ${domain}\", "
        done < "./dns-entries.conf"

        dns_array=$(echo "$dns_array" | sed 's/, $//')
        sudo docker exec "$CONTAINER_NAME" sed -i "s|hosts = \[\]|hosts = [${dns_array}]|" /etc/pihole/pihole.toml
        print_success "DNS entries configured from dns-entries.conf"
    else
        print_warning "dns-entries.conf not found, using defaults"
        local default_dns="\"${host_ip} pihole.lan\", \"${host_ip} home.lan\""
        sudo docker exec "$CONTAINER_NAME" sed -i "s|hosts = \[\]|hosts = [${default_dns}]|" /etc/pihole/pihole.toml
    fi
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
    local port="${WEBPORT:-$DEFAULT_PORT}"

    mkdir -p pihole-data dnsmasq-data
    print_success "Directories ready"

    # Disable systemd-resolved to free port 53
    print_status "Freeing port 53 (disabling systemd-resolved)..."
    sudo systemctl stop systemd-resolved 2>/dev/null || true
    sudo systemctl disable systemd-resolved 2>/dev/null || true
    sudo cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
    print_success "Port 53 freed"

    print_status "Starting ${SERVICE_NAME}..."
    sudo docker compose up -d

    echo -e "\n${BLUE}Waiting for Pi-hole to initialize...${NC}"
    sleep 30

    # Set admin password
    print_status "Setting admin password..."
    sudo docker exec "$CONTAINER_NAME" pihole setpassword "${WEBPASSWORD:-admin123}"
    print_success "Admin password set"

    # Configure DNS entries
    configure_dns

    # Restart to apply changes
    print_status "Restarting to apply DNS configuration..."
    sudo docker compose restart
    sleep 20

    # Update host DNS to use Pi-hole
    print_status "Updating host DNS to use Pi-hole..."
    echo "nameserver ${host_ip}" | sudo tee /etc/resolv.conf > /dev/null
    print_success "Host DNS updated"

    echo
    print_success "Setup complete!"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "  Admin UI:       http://${host_ip}:${port}/admin/"
    echo "  Admin Password: ${WEBPASSWORD:-admin123}"
    echo "  DNS Server:     ${host_ip}:53"
    echo
    echo -e "${BLUE}Testing:${NC}"
    echo "  dig @${host_ip} -p 53 google.com"
    echo "  dig @${host_ip} -p 53 pihole.lan"
    echo
    echo -e "${BLUE}Management:${NC}"
    echo "  ./setup.sh start     Start ${SERVICE_NAME}"
    echo "  ./setup.sh stop      Stop ${SERVICE_NAME}"
    echo "  ./setup.sh logs      View logs"
    echo "  ./setup.sh dns       Reconfigure DNS entries"
    echo "  ./setup.sh test      Test DNS resolution"
    echo "  ./setup.sh status    Show status"
    echo "  ./setup.sh update    Update to latest"
}

cmd_start() {
    print_status "Starting ${SERVICE_NAME}..."
    sudo docker compose up -d
    local host_ip; host_ip=$(get_host_ip)
    print_success "${SERVICE_NAME} started at http://${host_ip}:${WEBPORT:-$DEFAULT_PORT}/admin/"
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

cmd_dns() {
    print_status "Reconfiguring DNS entries..."
    configure_dns
    sudo docker compose restart
    sleep 10
    print_success "DNS entries reconfigured and service restarted"
}

cmd_test() {
    local host_ip; host_ip=$(get_host_ip)
    echo -e "${BLUE}=== DNS Resolution Test ===${NC}"
    echo

    echo -n "  External DNS (google.com): "
    if dig "@${host_ip}" -p 53 google.com +short &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi

    echo -n "  Local DNS (pihole.lan):    "
    if dig "@${host_ip}" -p 53 pihole.lan +short 2>/dev/null | grep -q "${host_ip}"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi

    echo -n "  Web Interface:             "
    local code; code=$(curl -sf -o /dev/null -w "%{http_code}" "http://${host_ip}:${WEBPORT:-$DEFAULT_PORT}/admin/" 2>/dev/null || echo "000")
    if [[ "$code" == "200" || "$code" == "302" ]]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED (HTTP $code)${NC}"
    fi
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
    echo "  dns       Reconfigure DNS entries from dns-entries.conf"
    echo "  test      Test DNS resolution"
    echo "  status    Show service status"
    echo "  update    Update to latest version"
    echo "  help      Show this help message"
    echo
    echo "Note: This service uses 'sudo docker compose' for port 53 access."
}

# ─── Main ────────────────────────────────────────────────────────────────────
case "${1:-setup}" in
    setup)    cmd_setup ;;
    start)    cmd_start ;;
    stop)     cmd_stop ;;
    restart)  cmd_restart ;;
    logs)     cmd_logs ;;
    dns)      cmd_dns ;;
    test)     cmd_test ;;
    status)   cmd_status ;;
    update)   cmd_update ;;
    help|--help|-h) show_usage ;;
    *)  print_error "Unknown command: $1"; echo; show_usage; exit 1 ;;
esac
