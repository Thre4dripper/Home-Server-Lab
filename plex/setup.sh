#!/bin/bash

# Plex Media Server Setup Script
# This script sets up and starts Plex Media Server on Raspberry Pi

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
        print_important "Especially set PLEX_CLAIM_TOKEN from https://www.plex.tv/claim"
    else
        print_success "Environment file found"
    fi
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    mkdir -p config
    mkdir -p transcode
    mkdir -p media/{movies,tv,music,photos}
    
    # Set proper permissions
    if [ "$(id -u)" -eq 0 ]; then
        chown -R 1000:1003 config transcode media
    fi
    
    print_success "Directories created with proper permissions"
}

# Check system requirements
check_system() {
    print_status "Checking system requirements..."
    
    # Check available memory
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$TOTAL_MEM" -lt 1024 ]; then
        print_warning "Low memory detected (${TOTAL_MEM}MB). Consider reducing memory limits."
    else
        print_success "Memory check passed (${TOTAL_MEM}MB available)"
    fi
    
    # Check available disk space
    AVAILABLE_SPACE=$(df -h . | awk 'NR==2{print $4}')
    print_status "Available disk space: $AVAILABLE_SPACE"
    
    # Check for hardware transcoding support
    if [ -d "/dev/dri" ]; then
        print_success "Hardware transcoding device detected (/dev/dri)"
    else
        print_warning "No hardware transcoding device found"
    fi
}

# Stop existing container if running
stop_existing() {
    print_status "Checking for existing Plex containers..."
    if docker ps -q -f name=plex > /dev/null 2>&1; then
        print_warning "Stopping existing Plex container..."
        docker compose down
        print_success "Existing container stopped"
    fi
}

# Start Plex
start_plex() {
    print_status "Starting Plex Media Server..."
    docker compose up -d
    print_success "Plex started successfully"
}

# Wait for Plex to be ready
wait_for_ready() {
    print_status "Waiting for Plex to be ready..."
    
    # Wait up to 120 seconds for Plex to be ready
    for i in {1..120}; do
        if curl -s -f "http://localhost:32400/identity" > /dev/null 2>&1; then
            print_success "Plex is ready!"
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
    
    # Check if Plex is actually running
    if ! curl -s -f "http://localhost:32400/identity" > /dev/null 2>&1; then
        print_warning "Plex may still be starting up. Check logs with: docker compose logs -f plex"
    fi
}

# Get Plex claim token info
get_claim_token_info() {
    # Load environment variables
    source .env
    
    if [ -z "$PLEX_CLAIM_TOKEN" ]; then
        echo
        print_important "🔑 Plex Claim Token Setup"
        echo "For automatic server setup, you need a claim token:"
        echo "1. Visit: https://www.plex.tv/claim"
        echo "2. Sign in to your Plex account"
        echo "3. Copy the claim token"
        echo "4. Add it to your .env file: PLEX_CLAIM_TOKEN=claim-xxxxxxxxxxxx"
        echo "5. Restart the container: docker compose restart plex"
        echo
    fi
}

# Display access information
show_access_info() {
    # Load environment variables
    source .env
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo
    print_success "🚀 Plex Media Server is now running!"
    echo
    echo -e "${BLUE}Access URLs:${NC}"
    echo -e "  Local:   ${GREEN}http://localhost:32400/web${NC}"
    echo -e "  Network: ${GREEN}http://${SERVER_IP}:32400/web${NC}"
    echo
    echo -e "${BLUE}Initial Setup:${NC}"
    if [ -z "$PLEX_CLAIM_TOKEN" ]; then
        echo "  1. Visit the local URL above in your browser"
        echo "  2. Sign in to your Plex account or create one"
        echo "  3. Name your server (e.g., 'Pi Plex Server')"
        echo "  4. Add media libraries:"
        echo "     • Movies: /media/movies"
        echo "     • TV Shows: /media/tv"
        echo "     • Music: /media/music"
        echo "     • Photos: /media/photos"
    else
        echo "  1. Server should be automatically claimed to your account"
        echo "  2. Visit Plex web interface to add media libraries"
        echo "  3. Add your media to the directories:"
    fi
    echo
    echo -e "${BLUE}Media Directories:${NC}"
    echo "  Movies:    $(realpath media/movies)"
    echo "  TV Shows:  $(realpath media/tv)"
    echo "  Music:     $(realpath media/music)"
    echo "  Photos:    $(realpath media/photos)"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  View logs:     docker compose logs -f plex"
    echo "  Stop:          docker compose down"
    echo "  Restart:       docker compose restart plex"
    echo "  Update:        docker compose pull && docker compose up -d"
    echo "  Shell access:  docker compose exec plex /bin/bash"
    echo
    echo -e "${BLUE}Performance Tips:${NC}"
    echo "  • Use Direct Play when possible (no transcoding)"
    echo "  • Place media on fast storage (SSD preferred)"
    echo "  • Monitor CPU usage during transcoding"
    echo "  • Limit concurrent transcoding streams"
    echo
}

# Show media organization tips
show_media_tips() {
    echo -e "${BLUE}📁 Media Organization Tips:${NC}"
    echo
    echo "For best results, organize your media like this:"
    echo
    echo "Movies:"
    echo "  media/movies/Movie Name (Year)/Movie Name (Year).mp4"
    echo
    echo "TV Shows:"
    echo "  media/tv/Show Name/Season 01/S01E01 - Episode Name.mp4"
    echo
    echo "Music:"
    echo "  media/music/Artist Name/Album Name/01 - Track Name.mp3"
    echo
    echo "For more details, see: https://support.plex.tv/articles/naming-and-organizing-your-media-files/"
    echo
}

# Main execution
main() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}   Plex Media Server Setup      ${NC}"
    echo -e "${PURPLE}   Raspberry Pi Docker Edition  ${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo
    
    check_docker
    check_env
    check_system
    create_directories
    stop_existing
    start_plex
    wait_for_ready
    get_claim_token_info
    show_access_info
    show_media_tips
}

# Run main function
main "$@"