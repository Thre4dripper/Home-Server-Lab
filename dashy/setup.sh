#!/bin/bash

# Dashy Setup Script
# This script handles initial setup and basic service management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
SERVICE_NAME="Dashy Dashboard"
CONTAINER_NAME="dashy"
DEFAULT_PORT="4000"

# Print colored output
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

# Check if Docker is installed and running
check_docker() {
    print_status "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_success "Docker is installed and running"
}

# Check if .env file exists
check_env_file() {
    print_status "Checking environment configuration..."
    
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            print_warning ".env file not found. Creating from .env.example..."
            cp .env.example .env
            print_success ".env file created from template"
            print_warning "Please review and modify .env file if needed"
        else
            print_error ".env.example file not found. Cannot create .env file."
            exit 1
        fi
    else
        print_success ".env file found"
    fi
}

# Create necessary directories
setup_directories() {
    print_status "Setting up directories..."
    
    # Create user-data directory if it doesn't exist
    if [[ ! -d "user-data" ]]; then
        mkdir -p user-data
        print_success "Created user-data directory"
    fi
    
    # Set proper permissions
    if [[ -f ".env" ]]; then
        source .env
        if [[ -n "$PUID" && -n "$PGID" ]]; then
            print_status "Setting directory permissions for UID:$PUID GID:$PGID"
            sudo chown -R "$PUID:$PGID" user-data/ 2>/dev/null || {
                print_warning "Could not set ownership. You may need to run: sudo chown -R $PUID:$PGID user-data/"
            }
        fi
    fi
}

# Check if port is available
check_port() {
    local port=$1
    if [[ -n "$port" ]]; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port is already in use"
            return 1
        fi
    fi
    return 0
}

# Wait for service to be healthy
wait_for_service() {
    local max_attempts=30
    local attempt=1
    local port=${1:-$DEFAULT_PORT}
    
    print_status "Waiting for $SERVICE_NAME to start (max ${max_attempts}s)..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker compose ps --format json | jq -r '.[] | select(.Name == "'$CONTAINER_NAME'") | .Health' 2>/dev/null | grep -q "healthy"; then
            print_success "$SERVICE_NAME is healthy!"
            return 0
        elif curl -sf "http://localhost:$port" &>/dev/null; then
            print_success "$SERVICE_NAME is responding!"
            return 0
        fi
        
        sleep 1
        ((attempt++))
    done
    
    print_error "$SERVICE_NAME failed to start properly"
    print_status "Checking logs..."
    docker compose logs --tail=20 "$CONTAINER_NAME"
    return 1
}

# Initial setup of configuration
setup_initial_config() {
    print_status "Setting up initial configuration..."
    
    # Check if root configuration exists
    if [[ ! -f "conf.yml" ]]; then
        print_error "Main configuration file conf.yml not found!"
        print_status "This appears to be an incomplete installation."
        exit 1
    fi
    
    # Use config script to sync configuration
    if [[ -x "./config.sh" ]]; then
        print_status "Syncing configuration from root to runtime..."
        ./config.sh sync
    else
        print_warning "config.sh not found, manually copying configuration..."
        mkdir -p user-data
        cp "conf.yml" "user-data/conf.yml"
        print_success "Configuration copied manually"
    fi
}

# Display service information
show_service_info() {
    print_success "=== $SERVICE_NAME Setup Complete ==="
    echo
    
    # Get port from .env file
    local port=$DEFAULT_PORT
    if [[ -f ".env" ]]; then
        source .env
        port=${DASHY_PORT:-$DEFAULT_PORT}
    fi
    
    # Get IP address
    local ip=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}Access URLs:${NC}"
    echo -e "  Local:   ${BLUE}http://localhost:$port${NC}"
    echo -e "  Network: ${BLUE}http://$ip:$port${NC}"
    echo
    
    echo -e "${GREEN}Management Commands:${NC}"
    echo -e "  Status:    ${YELLOW}docker compose ps${NC}"
    echo -e "  Logs:      ${YELLOW}docker compose logs -f $CONTAINER_NAME${NC}"
    echo -e "  Restart:   ${YELLOW}docker compose restart $CONTAINER_NAME${NC}"
    echo -e "  Stop:      ${YELLOW}docker compose down${NC}"
    echo -e "  Update:    ${YELLOW}./setup.sh update${NC}"
    echo
    
    echo -e "${GREEN}Configuration Management:${NC}"
    echo -e "  Edit Config:   ${YELLOW}./config.sh edit${NC}"
    echo -e "  Apply Changes: ${YELLOW}./config.sh sync${NC}"
    echo -e "  Check Status:  ${YELLOW}./config.sh status${NC}"
    echo -e "  Validate:      ${YELLOW}./config.sh validate${NC}"
    echo
    
    echo -e "${GREEN}Features:${NC}"
    echo -e "  • Customizable dashboard with 20+ themes"
    echo -e "  • Real-time status monitoring"
    echo -e "  • Advanced search and web integration"
    echo -e "  • Mobile-responsive design"
    echo -e "  • Multi-page support"
    echo -e "  • Authentication options"
    echo -e "  • Cloud sync and backup"
    echo
    
    echo -e "${GREEN}Next Steps:${NC}"
    echo -e "  1. Access the dashboard using the URLs above"
    echo -e "  2. Customize your configuration: ${YELLOW}./config.sh edit${NC}"
    echo -e "  3. Add your services and applications"
    echo -e "  4. Configure themes and layout preferences"
    echo -e "  5. Enable authentication if needed"
    echo
}

# Display current status
show_status() {
    echo -e "${BLUE}=== $SERVICE_NAME Status ===${NC}"
    echo
    
    if docker compose ps --format table; then
        echo
        
        # Check if service is responding
        local port=$DEFAULT_PORT
        if [[ -f ".env" ]]; then
            source .env
            port=${DASHY_PORT:-$DEFAULT_PORT}
        fi
        
        if curl -sf "http://localhost:$port" &>/dev/null; then
            print_success "Service is responding on port $port"
        else
            print_warning "Service is not responding on port $port"
        fi
        
        # Show resource usage if available
        if command -v docker &> /dev/null; then
            echo
            echo -e "${BLUE}Resource Usage:${NC}"
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.PIDs}}" "$CONTAINER_NAME" 2>/dev/null || {
                print_warning "Could not get resource usage stats"
            }
        fi
    else
        print_warning "Service is not running"
    fi
    
    echo
    echo -e "${BLUE}Configuration Status:${NC}"
    if [[ -x "./config.sh" ]]; then
        ./config.sh status
    else
        print_warning "config.sh not available"
    fi
}

# Update service
update_service() {
    print_status "Updating $SERVICE_NAME..."
    
    print_status "Pulling latest image..."
    docker compose pull
    
    print_status "Recreating container..."
    docker compose up -d
    
    if wait_for_service; then
        print_success "$SERVICE_NAME updated successfully"
    else
        print_error "Update failed. Check logs for details"
        exit 1
    fi
}

# Main setup function
setup_dashy() {
    echo -e "${BLUE}=== $SERVICE_NAME Setup ===${NC}"
    echo
    
    check_docker
    check_env_file
    setup_directories
    setup_initial_config
    
    # Check if port is available
    source .env
    local port=${DASHY_PORT:-$DEFAULT_PORT}
    if ! check_port "$port"; then
        print_warning "Port $port is in use. Service may conflict."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Setup cancelled"
            exit 0
        fi
    fi
    
    print_status "Starting $SERVICE_NAME..."
    docker compose up -d
    
    if wait_for_service "$port"; then
        show_service_info
    else
        print_error "Failed to start $SERVICE_NAME"
        exit 1
    fi
}

# Usage information
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Service Management Commands:"
    echo "  setup              Set up and start Dashy (default)"
    echo "  start              Start the service"
    echo "  stop               Stop the service"
    echo "  restart            Restart the service"
    echo "  status             Show service status"
    echo "  logs               Show service logs"
    echo "  update             Update to latest version"
    echo "  help               Show this help message"
    echo
    echo "Configuration Management:"
    echo "  Use ./config.sh for all configuration-related tasks:"
    echo "  ./config.sh edit      # Edit configuration"
    echo "  ./config.sh sync      # Apply changes"
    echo "  ./config.sh status    # Check config status"
    echo "  ./config.sh validate  # Validate syntax"
    echo
    echo "Examples:"
    echo "  $0                    # Setup and start Dashy"
    echo "  $0 status             # Check service status"
    echo "  $0 logs               # View recent logs"
    echo "  $0 update             # Update service"
    echo "  ./config.sh edit      # Edit configuration"
}

# Main script logic
main() {
    case "${1:-setup}" in
        "setup"|"install")
            setup_dashy
            ;;
        "start")
            print_status "Starting $SERVICE_NAME..."
            docker compose up -d
            wait_for_service
            ;;
        "stop")
            print_status "Stopping $SERVICE_NAME..."
            docker compose down
            print_success "Service stopped"
            ;;
        "restart")
            print_status "Restarting $SERVICE_NAME..."
            docker compose restart
            wait_for_service
            ;;
        "status")
            show_status
            ;;
        "logs")
            print_status "Showing logs for $SERVICE_NAME..."
            docker compose logs -f --tail=50 "$CONTAINER_NAME"
            ;;
        "update")
            update_service
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo
            print_status "For configuration management, use: ${YELLOW}./config.sh${NC}"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"