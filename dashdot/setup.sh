#!/bin/bash

# Dashdot Dashboard Setup Script
# This script sets up and starts Dashdot dashboard

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
    else
        print_success "Environment file found"
    fi
}

# Check system requirements
check_system() {
    print_status "Checking system requirements..."
    
    # Check available memory
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$TOTAL_MEM" -lt 512 ]; then
        print_warning "Low memory detected (${TOTAL_MEM}MB). Dashdot should still work but may be slower."
    else
        print_success "Memory check passed (${TOTAL_MEM}MB available)"
    fi
    
    # Check available disk space
    AVAILABLE_SPACE=$(df -h . | awk 'NR==2{print $4}')
    print_status "Available disk space: $AVAILABLE_SPACE"
    
    # Check if privileged mode is available
    if docker info | grep -q "Security Options"; then
        print_success "Docker privileged mode available"
    else
        print_warning "Docker privileged mode may not be available - some features may not work"
    fi
}

# Stop existing container if running
stop_existing() {
    print_status "Checking for existing Dashdot containers..."
    if docker compose ps | grep -q "Up"; then
        print_warning "Stopping existing containers..."
        docker compose down
        print_success "Existing containers stopped"
    fi
}

# Start Dashdot stack
start_dashdot() {
    print_status "Starting Dashdot..."
    docker compose up -d
    print_success "Dashdot started successfully"
}

# Wait for Dashdot to be ready
wait_for_ready() {
    print_status "Waiting for Dashdot to be ready..."
    
    # Load environment variables
    source .env
    
    # Wait for Dashdot
    for i in {1..30}; do
        if curl -s -f "http://localhost:${DASHDOT_PORT:-3001}" > /dev/null 2>&1; then
            print_success "Dashdot is ready!"
            break
        fi
        if [ $((i % 5)) -eq 0 ]; then
            echo -n " (${i}s)"
        else
            echo -n "."
        fi
        sleep 1
    done
    echo
    
    # Check if Dashdot is actually running
    if ! curl -s -f "http://localhost:${DASHDOT_PORT:-3001}" > /dev/null 2>&1; then
        print_warning "Dashdot may still be starting up. Check logs with: docker compose logs -f dashdot"
    fi
}

# Display access information
show_access_info() {
    # Load environment variables
    source .env
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo
    print_success "🚀 Dashdot Dashboard is now running!"
    echo
    echo -e "${BLUE}Access URLs:${NC}"
    echo -e "  Local:   ${GREEN}http://localhost:${DASHDOT_PORT:-3001}${NC}"
    echo -e "  Network: ${GREEN}http://${SERVER_IP}:${DASHDOT_PORT:-3001}${NC}"
    echo
    echo -e "${BLUE}Stack Components:${NC}"
    echo -e "  📊 Dashdot: Server monitoring dashboard"
    echo
    echo -e "${BLUE}First Time Setup:${NC}"
    echo "  1. Visit the URL above in your browser"
    echo "  2. Explore the real-time system metrics"
    echo "  3. Customize widgets as needed"
    echo
    echo -e "${BLUE}Key Features to Explore:${NC}"
    echo "  • CPU, RAM, Storage, and Network monitoring"
    echo "  • Customizable widget layout"
    echo "  • Responsive design for all devices"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  View all logs:     docker compose logs -f"
    echo "  View Dashdot logs: docker compose logs -f dashdot"
    echo "  Stop all:          docker compose down"
    echo "  Restart all:       docker compose restart"
    echo "  Update all:        docker compose pull && docker compose up -d"
    echo "  Shell access:      docker compose exec dashdot /bin/bash"
    echo
    echo -e "${BLUE}Security Reminder:${NC}"
    echo "  • Dashdot runs in privileged mode for system monitoring"
    echo "  • Consider using HTTPS in production"
    echo "  • Monitor resource usage as privileged containers have more access"
    echo
}

# Show integration tips
show_integration_tips() {
    echo -e "${BLUE}🔗 Integration Tips:${NC}"
    echo
    echo "Dashdot provides real-time insights into:"
    echo "  • Operating System information"
    echo "  • CPU usage and temperature"
    echo "  • RAM and swap usage"
    echo "  • Storage device information"
    echo "  • Network interface statistics"
    echo "  • GPU information (if available)"
    echo
    echo "For best results:"
    echo "  • Keep the container privileged"
    echo "  • Mount the host filesystem read-only"
    echo "  • Customize the widget list in your .env file"
    echo
    echo "See README.md for detailed configuration options!"
    echo
}

# Main execution
main() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}   Dashdot Setup                ${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo
    
    check_docker
    check_env
    check_system
    stop_existing
    start_dashdot
    wait_for_ready
    show_access_info
    show_integration_tips
}

# Run main function
main "$@"
