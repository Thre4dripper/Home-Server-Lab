#!/bin/bash

set -e

echo "☁️ Nextcloud All-in-One Setup"
echo "============================="
echo ""
echo "⚠️  IMPORTANT: SSL and domain validation are handled externally"
echo "   Make sure you have:"
echo "   • A domain pointing to this server (e.g., nextcloud.yourdomain.com)"
echo "   • Pi-hole configured with the domain entry"
echo "   • Nginx reverse proxy setup with SSL certificates"
echo "   • Domain validation is skipped in this configuration"
echo ""

# Auto-detect network configuration
PI_IP=$(hostname -I | awk '{print $1}')
ROUTER_IP=$(ip route | grep default | awk '{print $3}' | head -1)

echo "📍 Server IP: $PI_IP | Router: $ROUTER_IP"

# Source environment variables from .env file
source .env

# Check if domain is configured
if [ -z "$NEXTCLOUD_DOMAIN" ]; then
    echo ""
    echo "❓ Nextcloud Domain Configuration:"
    echo "   Please set your domain by running:"
    echo "   export NEXTCLOUD_DOMAIN=nextcloud.yourdomain.com"
    echo "   Then re-run this script"
    echo ""
    echo "   Or edit the domain in the .env file"
    exit 1
fi

echo "🌐 Domain: $NEXTCLOUD_DOMAIN"

# Create data directories (named volume is handled by Docker)
# Note: nextcloud_aio_mastercontainer is a named Docker volume, not a directory

# Check if external storage path exists
if [ ! -d "$EXTERNAL_STORAGE_PATH" ]; then
    echo "⚠️  External storage path does not exist: $EXTERNAL_STORAGE_PATH"
    echo "   Creating directory..."
    mkdir -p "$EXTERNAL_STORAGE_PATH"
    echo "   Please ensure this path has sufficient storage space"
fi

# Check Docker socket access
if [ ! -w /var/run/docker.sock ]; then
    echo "⚠️  Docker socket not writable. Adding user to docker group..."
    sudo usermod -aG docker $USER
    echo "   Please log out and back in, then re-run this script"
    exit 1
fi

# Start Nextcloud AIO
echo "🚀 Starting Nextcloud AIO..."
sudo docker compose up -d

# Wait for AIO mastercontainer to start
echo "⏳ Waiting for Nextcloud AIO to initialize..."
sleep 30

# Check if AIO is running
if ! sudo docker ps | grep -q nextcloud-aio-mastercontainer; then
    echo "❌ Nextcloud AIO failed to start"
    echo "   Check logs: sudo docker compose logs"
    exit 1
fi

echo ""
echo "🎉 Nextcloud AIO Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   • AIO Interface: http://$PI_IP:8081"
echo "   • Nextcloud will be available at: https://$NEXTCLOUD_DOMAIN (via reverse proxy)"
echo ""
echo "📱 Initial Setup Steps:"
echo "   1. Open http://$PI_IP:8081 in your browser"
echo "   2. Enter your domain: $NEXTCLOUD_DOMAIN (validation skipped)"
echo "   3. Create admin account and configure"
echo "   4. AIO will automatically create all required containers"
echo "   5. Set up reverse proxy for SSL access at https://$NEXTCLOUD_DOMAIN"
echo ""
echo "⚠️  Domain Requirements:"
echo "   • Ensure $NEXTCLOUD_DOMAIN resolves to $PI_IP"
echo "   • Add to Pi-hole: $NEXTCLOUD_DOMAIN=$PI_IP"
echo "   • Configure nginx reverse proxy with SSL certificates for https://$NEXTCLOUD_DOMAIN"
echo ""
echo "🔧 Management:"
echo "   • View logs: sudo docker compose logs -f"
echo "   • Stop: sudo docker compose down"
echo "   • Update: sudo docker compose pull && sudo docker compose up -d"
echo ""
echo "📚 Documentation: https://github.com/nextcloud/all-in-one"