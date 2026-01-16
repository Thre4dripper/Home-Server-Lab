#!/bin/bash

set -e

# Function to show usage
show_usage() {
    echo "Samba Server Management Script"
    echo ""
    echo "Usage: ./setup.sh [command]"
    echo ""
    echo "Commands:"
    echo "  setup      - Initial setup and start Samba (default)"
    echo "  start      - Start Samba container"
    echo "  stop       - Stop Samba container"
    echo "  restart    - Restart Samba container"
    echo "  logs       - View Samba logs"
    echo "  status     - Show container status"
    echo "  adduser    - Add a Samba user"
    echo "  passwd     - Change user password"
    echo "  listusers  - List Samba users"
    echo "  test       - Test Samba connectivity"
    echo ""
    echo "Examples:"
    echo "  ./setup.sh              # Run initial setup"
    echo "  ./setup.sh adduser pi   # Add user 'pi'"
    echo "  ./setup.sh test         # Test connection"
}

# Function to run initial setup
run_setup() {
    echo "📁 Samba Server Setup"
    echo "====================="
    echo ""
    echo "📝 Configuration:"
    echo "   • Shares defined in: smb.conf"
    echo "   • Network settings in: .env"
    echo "   • Default workgroup: WORKGROUP"
    echo ""

    # Create .env file from .env.example if it doesn't exist
    if [ ! -f .env ]; then
        cp .env.example .env
        echo "✅ Created .env from .env.example"
    fi

    # Source environment variables
    source .env

    # Create shared directories if they don't exist
    echo "📁 Creating shared directories..."
    mkdir -p "${SHARE_PATH_1:-/home/pi/shared}"
    mkdir -p "${SHARE_PATH_2:-/home/pi/media}"
    mkdir -p "${SHARE_PATH_3:-/home/pi/documents}"
    
    # Create persistent Samba data directories
    mkdir -p samba_private
    
    # Set permissions
    chmod 775 "${SHARE_PATH_1:-/home/pi/shared}"
    chmod 775 "${SHARE_PATH_2:-/home/pi/media}"
    chmod 770 "${SHARE_PATH_3:-/home/pi/documents}"
    
    echo "✅ Directories created"

    # Auto-detect network configuration
    HOST_IP=$(hostname -I | awk '{print $1}')
    echo "📍 Host IP: $HOST_IP"

    # Start Samba
    echo ""
    echo "🚀 Starting Samba server..."
    docker compose up -d

    # Wait for container to start
    echo "⏳ Waiting for Samba to start..."
    sleep 5

    # Check if container is running
    if docker ps | grep -q "${CONTAINER_NAME:-samba}"; then
        echo "✅ Samba is running"
    else
        echo "❌ Samba failed to start"
        echo "   Check logs: docker compose logs"
        exit 1
    fi

    echo ""
    echo "🎉 Setup Complete!"
    echo ""
    echo "📋 Connection Information:"
    echo "   • Server: \\\\${HOST_IP}\\ or smb://${HOST_IP}/"
    echo "   • Workgroup: WORKGROUP"
    echo ""
    echo "📁 Available Shares:"
    echo "   • \\\\${HOST_IP}\\Public     - Guest access (read/write)"
    echo "   • \\\\${HOST_IP}\\Media      - Guest read, users write"
    echo "   • \\\\${HOST_IP}\\Documents  - Authenticated users only"
    echo ""
    echo "👤 Add Users:"
    echo "   ./setup.sh adduser <username>"
    echo ""
    echo "🔧 Management:"
    echo "   • View logs:    ./setup.sh logs"
    echo "   • Stop:         ./setup.sh stop"
    echo "   • Restart:      ./setup.sh restart"
    echo ""
    echo "📖 Edit smb.conf to customize shares"
}

# Function to add Samba user
add_user() {
    if [ -z "$1" ]; then
        echo "Usage: ./setup.sh adduser <username>"
        exit 1
    fi
    
    USERNAME=$1
    echo "Adding Samba user: $USERNAME"
    echo "You will be prompted to set a password..."
    
    # Create system user in container and add to Samba
    docker exec -it samba bash -c "
        adduser -D -H $USERNAME 2>/dev/null || true
        smbpasswd -a $USERNAME
    "
    
    echo "✅ User $USERNAME added to Samba"
}

# Function to change user password
change_passwd() {
    if [ -z "$1" ]; then
        echo "Usage: ./setup.sh passwd <username>"
        exit 1
    fi
    
    USERNAME=$1
    echo "Changing password for Samba user: $USERNAME"
    docker exec -it samba smbpasswd $USERNAME
}

# Function to list Samba users
list_users() {
    echo "=== Samba Users ==="
    docker exec samba pdbedit -L 2>/dev/null || echo "No users configured"
}

# Function to test Samba connectivity
test_samba() {
    source .env 2>/dev/null || true
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    echo "=== Testing Samba Server ==="
    echo ""
    
    # Test if container is running
    echo -n "Container Status: "
    if docker ps | grep -q "${CONTAINER_NAME:-samba}"; then
        echo "✅ Running"
    else
        echo "❌ Not running"
        exit 1
    fi
    
    # Test SMB port
    echo -n "SMB Port (445):   "
    if nc -z localhost ${SMB_PORT:-445} 2>/dev/null; then
        echo "✅ Open"
    else
        echo "❌ Closed"
    fi
    
    # List shares
    echo ""
    echo "Available Shares:"
    docker exec samba smbclient -L localhost -U % -N 2>/dev/null | grep -E "^\s+\w+" || echo "Unable to list shares"
    
    echo ""
    echo "Connection URLs:"
    echo "  Windows: \\\\${HOST_IP}\\"
    echo "  macOS:   smb://${HOST_IP}/"
    echo "  Linux:   smb://${HOST_IP}/"
}

# Main command handling
case "${1:-setup}" in
    setup)
        run_setup
        ;;
    
    start)
        echo "Starting Samba..."
        docker compose up -d
        echo "✅ Samba started"
        ;;
    
    stop)
        echo "Stopping Samba..."
        docker compose down
        echo "✅ Samba stopped"
        ;;
    
    restart)
        echo "Restarting Samba..."
        docker compose restart
        echo "✅ Samba restarted"
        ;;
    
    logs)
        echo "Showing Samba logs (Ctrl+C to exit)..."
        docker compose logs -f
        ;;
    
    status)
        echo "=== Samba Status ==="
        if docker ps | grep -q "${CONTAINER_NAME:-samba}"; then
            echo "✓ Container is running"
            docker ps --filter name=samba --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            echo "❌ Container is not running"
        fi
        ;;
    
    adduser)
        add_user "$2"
        ;;
    
    passwd)
        change_passwd "$2"
        ;;
    
    listusers)
        list_users
        ;;
    
    test)
        test_samba
        ;;
    
    help|--help|-h)
        show_usage
        ;;
    
    *)
        echo "Error: Unknown command '$1'"
        echo ""
        show_usage
        exit 1
        ;;
esac
