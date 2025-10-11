#!/bin/bash

# ownCloud Setup Script
# Automated setup and management for ownCloud file sharing platform

set -e

# Show help function
show_help() {
    echo "☁️  ownCloud Management"
    echo "====================="
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup       - Initial setup and start (default)"
    echo "  start       - Start ownCloud services"
    echo "  stop        - Stop ownCloud services"
    echo "  restart     - Restart ownCloud services"
    echo "  status      - Show status and health"
    echo "  logs        - Show logs (real-time)"
    echo "  clean       - Clean up volumes and containers"
    echo ""
    echo "Examples:"
    echo "  $0           # Initial setup"
    echo "  $0 setup     # Initial setup"
    echo "  $0 stop      # Stop services"
    echo "  $0 status    # Check status"
}

# Parse command
COMMAND=${1:-setup}

case $COMMAND in
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
    "stop")
        echo "🛑 Stopping ownCloud services..."
        docker compose down
        echo "✅ ownCloud services stopped"
        exit 0
        ;;
    "start")
        echo "☁️  Starting ownCloud services..."
        if [ ! -f .env ]; then
            echo "❌ Error: .env file not found. Run '$0 setup' first."
            exit 1
        fi
        docker compose up -d
        echo "✅ ownCloud services started"
        exit 0
        ;;
    "restart")
        echo "🔄 Restarting ownCloud services..."
        docker compose down
        docker compose up -d
        echo "✅ ownCloud services restarted"
        exit 0
        ;;
    "status")
        echo "📊 ownCloud Status:"
        echo "=================="
        docker compose ps
        echo ""
        echo "🏥 Health Check:"
        if [ -f .env ]; then
            source .env
        fi
        health_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${HTTP_PORT:-8080}/status.php 2>/dev/null || echo "000")
        case $health_code in
            "200") echo "   ✅ Healthy" ;;
            "503") echo "   🔄 Starting up" ;;
            "000") echo "   ❌ Not running" ;;
            *) echo "   ⚠️  Unknown status (HTTP: $health_code)" ;;
        esac
        exit 0
        ;;
    "logs")
        echo "📋 ownCloud logs (Ctrl+C to exit):"
        docker compose logs -f
        exit 0
        ;;
    "clean")
        echo "🧹 Cleaning ownCloud..."
        docker compose down --volumes --remove-orphans
        sudo rm -rf files/* mysql/* redis/* 2>/dev/null || true
        echo "✅ ownCloud cleaned"
        exit 0
        ;;
    "setup")
        # Continue with setup process
        ;;
    *)
        echo "❌ Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac

echo "☁️  ownCloud Setup"
echo "=================="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📋 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your configuration:"
    echo "   - Update OWNCLOUD_DOMAIN with your server IP"
    echo "   - Update OWNCLOUD_TRUSTED_DOMAINS with your network details"
    echo "   - Change default passwords"
    echo ""
    echo "Edit with: nano .env"
    echo "Then run: $0 setup"
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
if grep -q "your-server-ip\|secure_admin_password\|secure_db_password" .env; then
    echo "⚠️  WARNING: Please edit the .env file with your actual configuration!"
    echo "You need to set:"
    echo "  - OWNCLOUD_DOMAIN (your server IP:port)"
    echo "  - OWNCLOUD_TRUSTED_DOMAINS (network access configuration)"
    echo "  - ADMIN_PASSWORD (secure admin password)"
    echo "  - DB_PASSWORD (secure database password)"
    echo "  - DB_ROOT_PASSWORD (secure root password)"
    echo ""
    echo "Run: nano .env"
    echo "Then run this script again."
    exit 1
fi

echo "🔧 Starting ownCloud setup..."
echo ""

# Create required directories
echo "📁 Creating directories..."
mkdir -p files mysql redis
chown -R $USER:$USER files mysql redis

# Pull the latest images
echo "📦 Pulling Docker images..."
docker compose pull

# Start the services
echo "🚀 Starting ownCloud services..."
docker compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to initialize..."
sleep 30

# Check service status
echo "🔍 Checking service status..."
docker compose ps

# Get server info
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "🎉 ownCloud Setup Complete!"
echo "=========================="
echo "📱 Web Interface: http://${SERVER_IP}:${HTTP_PORT:-8080}"
echo "👤 Admin Login:"
echo "   Username: ${ADMIN_USERNAME}"
echo "   Password: Check .env file"
echo ""
echo "🔧 Features Available:"
echo "  • File synchronization across devices"
echo "  • Web-based file management"
echo "  • Desktop and mobile clients"
echo "  • User and group management"
echo "  • File sharing and collaboration"
echo "  • Calendar and contacts sync"
echo ""
echo "📊 Services Running:"
echo "  • ownCloud Server: http://${SERVER_IP}:${HTTP_PORT:-8080}"
echo "  • MariaDB: Internal database"
echo "  • Redis: Performance cache"
echo ""
echo "📝 Next Steps:"
echo "  1. Open http://${SERVER_IP}:${HTTP_PORT:-8080} in your browser"
echo "  2. Login with admin credentials"
echo "  3. Download desktop/mobile clients"
echo "  4. Create users and start sharing files"
echo ""
echo "🔧 Management Commands:"
echo "   Start:   ./setup.sh start"
echo "   Stop:    ./setup.sh stop"
echo "   Restart: ./setup.sh restart"
echo "   Status:  ./setup.sh status"
echo "   Logs:    ./setup.sh logs"
echo "   Clean:   ./setup.sh clean"
echo ""
echo "🌐 Trusted Domains Configured:"
echo "   ${OWNCLOUD_TRUSTED_DOMAINS}"
echo ""
echo "💡 Client Downloads:"
echo "   Desktop: https://owncloud.com/desktop-app/"
echo "   Mobile:  https://owncloud.com/mobile-apps/"