#!/bin/bash

# Deluge Setup Script
# This script sets up Deluge for your home server

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

echo "=================================="
echo "     Deluge Setup"
echo "=================================="

# Check Docker installation and version
print_status "Checking Docker..."
if ! docker --version >/dev/null 2>&1; then
    print_error "Docker is not installed or not running"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    print_error "Docker Compose is not installed"
    exit 1
fi

print_success "Docker is available"

# Check environment configuration file
print_status "Checking environment configuration..."
if [ ! -f ".env" ]; then
    print_error "Environment file .env not found"
    print_status "Copying from .env.example..."
    cp .env.example .env
    print_warning "Please edit .env file with your configuration before running setup again"
    exit 1
fi

print_success "Environment file found"

# System requirements check
print_status "Checking system requirements..."
AVAILABLE_MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $2}')
if [ "$AVAILABLE_MEMORY" -lt 1024 ]; then
    print_warning "Available memory: ${AVAILABLE_MEMORY}MB. Deluge recommends at least 1GB RAM"
else
    print_success "Memory check passed (${AVAILABLE_MEMORY}MB available)"
fi

# Check available disk space for downloads
AVAILABLE_DISK=$(df . | tail -1 | awk '{print int($4/1024/1024)}')
if [ "$AVAILABLE_DISK" -lt 5 ]; then
    print_warning "Available disk space: ${AVAILABLE_DISK}GB. Deluge needs adequate storage for downloads"
else
    print_success "Disk space check passed (${AVAILABLE_DISK}GB available)"
fi

# Create required directories with proper structure
print_status "Creating bind mount directories..."
mkdir -p config
mkdir -p downloads
print_success "Bind mount directories created"

# Start Deluge container
print_status "Starting Deluge..."
docker compose up -d

# Wait for container initialization
print_status "Waiting for Deluge to be ready..."
sleep 5

# Verify container is running successfully
if docker compose ps | grep -q "Up"; then
    print_success "Deluge started successfully"
else
    print_error "Failed to start Deluge"
    print_status "Check logs with: docker compose logs"
    exit 1
fi

# Display access information
# Get the configured web UI port from environment
DELUGE_WEBUI_PORT=$(grep "^DELUGE_WEBUI_PORT=" .env | cut -d '=' -f2)
if [ -z "$DELUGE_WEBUI_PORT" ]; then
    DELUGE_WEBUI_PORT=8112
fi

print_success "🚀 Deluge is now running!"

echo ""
echo "Access URLs:"
echo "  Local:   http://localhost:$DELUGE_WEBUI_PORT"
echo "  Network: http://your-server-ip:$DELUGE_WEBUI_PORT"
echo ""
echo "Stack Components:"
echo "  🧲 Deluge: BitTorrent client with web UI"
echo ""
# Show the actual downloads path from environment variable
echo "📥 Downloads location: ${DOWNLOADS_PATH:-./downloads}"
echo ""
echo "First Time Setup:"
echo "  1. Visit the URL above in your browser"
echo "  2. Enter the default password: deluge (no username required)"
echo "  3. Create your admin username and password"
echo "  4. Configure download directories and preferences"
echo ""
echo "Useful Commands:"
echo "  View logs:         docker compose logs -f"
echo "  Stop all:          docker compose down"
echo "  Restart all:       docker compose restart"
echo "  Update all:        docker compose pull && docker compose up -d"
echo ""
echo "Security Notes:"
echo "  • Change default credentials after first login"
echo "  • Configure proper authentication"
echo "  • Review Deluge security documentation"
echo ""
echo "See README.md for detailed configuration options!"