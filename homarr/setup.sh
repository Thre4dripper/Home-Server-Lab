#!/bin/bash

# Homarr Dashboard Setup Script
# This script sets up and starts Homarr dashboard

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
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

print_important() {
    echo -e "${PURPLE}[IMPORTANT]${NC} $1"
}

# Check if Docker is running
check_docker() {
    print_status "Checking Docker..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running"
}

# Check if .env file exists
check_env() {
    print_status "Checking environment configuration..."
    if [ ! -f .env ]; then
        print_warning ".env file not found. Creating from .env.example..."
        cp .env.example .env
        print_success "Created .env file from template"
        print_important "Please review and update .env file with your settings"
        check_encryption_key
    else
        print_success "Environment file found"
        check_encryption_key
    fi
}

# Check and generate encryption key if needed
check_encryption_key() {
    # Load environment variables
    source .env
    
    if [[ "$SECRET_ENCRYPTION_KEY" == "your-64-character-secret-key-change-this-in-production-NOW" ]] || [[ ${#SECRET_ENCRYPTION_KEY} -ne 64 ]]; then
        print_warning "Default or invalid encryption key detected. Generating new secure key..."
        
        # Generate new encryption key
        NEW_KEY=$(openssl rand -hex 32)
        
        # Update .env file
        if grep -q "SECRET_ENCRYPTION_KEY=" .env; then
            sed -i "s/SECRET_ENCRYPTION_KEY=.*/SECRET_ENCRYPTION_KEY=$NEW_KEY/" .env
        else
            echo "SECRET_ENCRYPTION_KEY=$NEW_KEY" >> .env
        fi
        
        print_success "Generated new encryption key and updated .env file"
        print_important "Your new encryption key: $NEW_KEY"
        print_important "Please backup this key - it's required to decrypt your data!"
    else
        print_success "Valid encryption key found"
    fi
    
    # Check database passwords
    if [[ "$POSTGRES_PASSWORD" == "secure_postgres_password_change_this" ]] || [[ "$POSTGRES_PASSWORD" == "your-secure-postgres-password-change-this" ]]; then
        print_warning "Default PostgreSQL password detected. Please update POSTGRES_PASSWORD in .env file"
    fi
    
    if [[ "$REDIS_PASSWORD" == "secure_redis_password_change_this" ]] || [[ "$REDIS_PASSWORD" == "your-secure-redis-password-change-this" ]]; then
        print_warning "Default Redis password detected. Please update REDIS_PASSWORD in .env file"
    fi
}

# Create necessary directories
create_directories() {
    print_status "Creating data directories..."
    mkdir -p homarr_data
    mkdir -p postgres_data
    mkdir -p redis_data
    print_success "Data directories created (homarr_data, postgres_data, redis_data)"
}

# Check system requirements
check_system() {
    print_status "Checking system requirements..."
    
    # Check available memory
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$TOTAL_MEM" -lt 1024 ]; then
        print_warning "Low memory detected (${TOTAL_MEM}MB). Consider reducing memory limits for containers."
    else
        print_success "Memory check passed (${TOTAL_MEM}MB available)"
    fi
    
    # Check available disk space
    AVAILABLE_SPACE=$(df -h . | awk 'NR==2{print $4}')
    print_status "Available disk space: $AVAILABLE_SPACE"
    
    # Check Docker socket access
    if [ -S "/var/run/docker.sock" ]; then
        print_success "Docker socket accessible for container integration"
    else
        print_warning "Docker socket not found - container integration will be limited"
    fi
    
    # Check if required ports are available
    check_port_availability
}

# Check port availability
check_port_availability() {
    source .env
    
    if netstat -tuln | grep -q ":${HOMARR_PORT:-7575} "; then
        print_warning "Port ${HOMARR_PORT:-7575} is already in use - Homarr may not start properly"
    else
        print_success "Port ${HOMARR_PORT:-7575} is available for Homarr"
    fi
}

# Stop existing container if running
stop_existing() {
    print_status "Checking for existing Homarr containers..."
    if docker compose ps | grep -q "Up"; then
        print_warning "Stopping existing containers..."
        docker compose down
        print_success "Existing containers stopped"
    fi
}

# Start Homarr stack
start_homarr() {
    print_status "Starting Homarr stack (PostgreSQL + Redis + Homarr)..."
    docker compose up -d
    print_success "Homarr stack started successfully"
}

# Wait for all services to be ready
wait_for_ready() {
    print_status "Waiting for all services to be ready..."
    
    # Load environment variables
    source .env
    
    # Wait for PostgreSQL
    print_status "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if docker compose exec postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" > /dev/null 2>&1; then
            print_success "PostgreSQL is ready!"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Wait for Redis
    print_status "Waiting for Redis to be ready..."
    for i in {1..30}; do
        if docker compose exec redis redis-cli --no-auth-warning -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
            print_success "Redis is ready!"
            break
        fi
        echo -n "."
        sleep 1
    done
    
    # Wait for Homarr
    print_status "Waiting for Homarr to be ready..."
    for i in {1..60}; do
        if curl -s -f "http://localhost:${HOMARR_PORT:-7575}" > /dev/null 2>&1; then
            print_success "Homarr is ready!"
            break
        fi
        if [ $((i % 10)) -eq 0 ]; then
            echo -n " (${i}s)"
        else
            echo -n "."
        fi
        sleep 1
    done
    echo
    
    # Check if Homarr is actually running
    if ! curl -s -f "http://localhost:${HOMARR_PORT:-7575}" > /dev/null 2>&1; then
        print_warning "Homarr may still be starting up. Check logs with: docker compose logs -f homarr"
    fi
}

# Display access information
show_access_info() {
    # Load environment variables
    source .env
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo
    print_success "🚀 Homarr Dashboard Stack is now running!"
    echo
    echo -e "${BLUE}Access URLs:${NC}"
    echo -e "  Local:   ${GREEN}http://localhost:${HOMARR_PORT:-7575}${NC}"
    echo -e "  Network: ${GREEN}http://${SERVER_IP}:${HOMARR_PORT:-7575}${NC}"
    echo
    echo -e "${BLUE}Stack Components:${NC}"
    echo -e "  🗄️  PostgreSQL 16: Database backend"
    echo -e "  🚀 Redis 7: Caching and session storage"
    echo -e "  🎛️  Homarr: Dashboard frontend"
    echo
    echo -e "${BLUE}First Time Setup:${NC}"
    echo "  1. Visit the URL above in your browser"
    echo "  2. Complete the onboarding process"
    echo "  3. Create your admin account"
    echo "  4. Set up your first dashboard board"
    echo "  5. Add tiles for your self-hosted services"
    echo
    echo -e "${BLUE}Key Features to Explore:${NC}"
    echo "  • Add service tiles with integrations"
    echo "  • Customize layout with drag & drop"
    echo "  • Configure Docker container monitoring"
    echo "  • Set up user accounts and permissions"
    echo "  • Explore 30+ service integrations"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  View all logs:     docker compose logs -f"
    echo "  View Homarr logs:  docker compose logs -f homarr"
    echo "  View DB logs:      docker compose logs -f postgres"
    echo "  View Redis logs:   docker compose logs -f redis"
    echo "  Stop all:          docker compose down"
    echo "  Restart all:       docker compose restart"
    echo "  Update all:        docker compose pull && docker compose up -d"
    echo "  Shell access:      docker compose exec homarr /bin/bash"
    echo
    echo -e "${BLUE}Database Information:${NC}"
    echo "  • PostgreSQL 16 running on internal network"
    echo "  • Redis 7 with password authentication"
    echo "  • All data persisted in local volumes"
    echo "  • Production-ready configuration"
    echo
    echo -e "${BLUE}Security Reminder:${NC}"
    echo "  • Your encryption key is stored in .env file"
    echo "  • Database passwords are in .env file"
    echo "  • Backup this configuration regularly"
    echo "  • Consider using HTTPS in production"
    echo "  • Set up strong passwords for user accounts"
    echo
}

# Show integration tips
show_integration_tips() {
    echo -e "${BLUE}🔗 Integration Tips:${NC}"
    echo
    echo "Popular services you can integrate:"
    echo "  • Plex/Jellyfin - Media servers"
    echo "  • Sonarr/Radarr - Media management"
    echo "  • Pi-hole - Network-wide ad blocking"
    echo "  • Portainer - Docker management"
    echo "  • Home Assistant - Home automation"
    echo "  • qBittorrent - Download client"
    echo
    echo "For each service:"
    echo "  1. Add an 'App' tile on your board"
    echo "  2. Configure the service URL and icon"
    echo "  3. Enable API integration if supported"
    echo "  4. Add API keys for enhanced features"
    echo
    echo -e "${BLUE}Performance Benefits:${NC}"
    echo "  • PostgreSQL: Robust database with ACID compliance"
    echo "  • Redis: Fast caching reduces page load times"
    echo "  • Separate containers: Easy scaling and maintenance"
    echo "  • Health checks: Automatic recovery from failures"
    echo
    echo "See README.md for detailed integration guides!"
    echo
}

# Main execution
main() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}   Homarr Stack Setup           ${NC}"
    echo -e "${PURPLE}   PostgreSQL + Redis + Homarr  ${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo
    
    check_docker
    check_env
    check_system
    create_directories
    stop_existing
    start_homarr
    wait_for_ready
    show_access_info
    show_integration_tips
}

# Run main function
main "$@"