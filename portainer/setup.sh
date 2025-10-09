#!/bin/bash

# Portainer Setup Script
# This script sets up and starts Portainer CE

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
        print_warning "Please review and update .env file with your settings"
    else
        print_success "Environment file found"
    fi
}

# Create data directory
create_directories() {
    print_status "Creating data directories..."
    mkdir -p portainer_data
    print_success "Data directories created"
}

# Stop existing container if running
stop_existing() {
    print_status "Checking for existing Portainer containers..."
    if docker ps -q -f name=portainer > /dev/null 2>&1; then
        print_warning "Stopping existing Portainer container..."
        docker compose down
        print_success "Existing container stopped"
    fi
}

# Start Portainer
start_portainer() {
    print_status "Starting Portainer..."
    docker compose up -d
    print_success "Portainer started successfully"
}

# Wait for Portainer to be ready
wait_for_ready() {
    print_status "Waiting for Portainer to be ready..."
    
    # Load environment variables
    source .env
    
    # Wait up to 30 seconds for Portainer to be ready
    for i in {1..30}; do
        if curl -s -f "http://localhost:${PORTAINER_PORT}" > /dev/null 2>&1; then
            print_success "Portainer is ready!"
            break
        fi
        echo -n "."
        sleep 1
    done
    echo
}

# Display access information
show_access_info() {
    # Load environment variables
    source .env
    
    echo
    print_success "🚀 Portainer is now running!"
    echo
    echo -e "${BLUE}Access URLs:${NC}"
    echo -e "  Local:   ${GREEN}http://localhost:${PORTAINER_PORT}${NC}"
    echo -e "  Network: ${GREEN}http://${PORTAINER_HOST}:${PORTAINER_PORT}${NC}"
    echo
    echo -e "${BLUE}First time setup:${NC}"
    echo "  1. Open the URL above in your browser"
    echo "  2. Create an admin user account"
    echo "  3. Select 'Docker' environment"
    echo "  4. Start managing your containers!"
    echo
    echo -e "${BLUE}Useful commands:${NC}"
    echo "  View logs:    docker compose logs -f"
    echo "  Stop:         docker compose down"
    echo "  Restart:      docker compose restart"
    echo "  Update:       docker compose pull && docker compose up -d"
    echo
}

# Main execution
main() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   Portainer CE Setup Script    ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    
    check_docker
    check_env
    create_directories
    stop_existing
    start_portainer
    wait_for_ready
    show_access_info
}

# Run main function
main "$@"