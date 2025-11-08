#!/bin/bash

set -e

echo "☁️  Rclone Cloud Storage Manager Setup"
echo "====================================="
echo ""
echo "📝 Configuration:"
echo "   • Cloud Storage: 70+ providers supported"
echo "   • Data: Persistent volume for local files"
echo "   • Config: Persistent volume for rclone settings"
echo "   • Serve: HTTP/WebDAV/FTP capabilities"
echo ""

# Clean up existing files and volumes
if [ -f .env ]; then
    rm .env
    echo "🧹 Removed existing .env"
fi

if [ -d "./data" ]; then
    rm -rf ./data
    echo "🧹 Cleaned data directory"
fi

if [ -d "./config" ]; then
    rm -rf ./config
    echo "🧹 Cleaned config directory"
fi

# Create .env file from .env.example
cp .env.example .env
echo "✅ Created .env from .env.example"

# Generate random password for serve authentication
RCLONE_PASS=$(openssl rand -base64 12)
# Escape special characters for sed
ESCAPED_PASS=$(echo "$RCLONE_PASS" | sed 's/[[\.*^$()+?{|]/\\&/g')
sed -i "s/your-password-change-this/$ESCAPED_PASS/" .env
echo "✅ Generated serve password: $RCLONE_PASS"

# Create directories
mkdir -p config data
echo "✅ Created fresh directories"

# Auto-detect network configuration
HOST_IP=$(hostname -I | awk '{print $1}')

echo "📍 Host Configuration: $HOST_IP"

# Start Rclone
echo "🚀 Starting Rclone..."
echo "   • Container will be ready shortly"
echo ""

docker compose up -d

# Wait for services to start
echo "⏳ Waiting for Rclone to start..."
echo "   • This may take a few seconds..."

# Wait for Rclone to be ready
echo -n "   • Rclone Container: "
for i in {1..30}; do
    if docker exec rclone rclone version >/dev/null 2>&1; then
        echo "✅ Ready"
        break
    elif [ $i -eq 30 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs rclone"
        exit 1
    else
        echo -n "."
        sleep 1
    fi
done

# Test setup
echo ""
echo "🧪 Testing Rclone Setup..."

# Test container
echo -n "Container Status:  "
if docker compose ps rclone | grep -q "Up"; then
    echo "✅ Running"
else
    echo "❌ Not running"
fi

# Test data persistence
echo -n "Data Volume:       "
if [ -d "./data" ]; then
    echo "✅ Mounted"
else
    echo "❌ Missing"
fi

echo -n "Config Volume:     "
if [ -d "./config" ]; then
    echo "✅ Mounted"
else
    echo "❌ Missing"
fi

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   • Rclone is running as a service container"
echo "   • HTTP Serve: http://$HOST_IP:5572 (if configured)"
echo "   • WebDAV Serve: http://$HOST_IP:5573 (if configured)"
echo ""
echo "📱 Next Steps:"
echo "   1. Configure cloud remotes: docker exec -it rclone rclone config"
echo "   2. Test connection: docker exec rclone rclone lsd remote:"
echo "   3. Sync files: docker exec rclone rclone sync /data remote:backup"
echo ""
echo "🔧 Management Commands:"
echo "   • View logs:        docker compose logs -f"
echo "   • Access shell:     docker exec -it rclone sh"
echo "   • Stop:             docker compose down"
echo "   • Restart:          docker compose restart"
echo "   • Update:           docker compose pull && docker compose up -d"
echo ""
echo "☁️  Common rclone commands:"
echo "   • List remotes:     docker exec rclone rclone listremotes"
echo "   • Copy files:       docker exec rclone rclone copy /data remote:path"
echo "   • Mount storage:    docker exec rclone rclone mount remote: /mnt/remote"
echo "   • Serve HTTP:       docker exec rclone rclone serve http /data --addr :5572"
echo ""
echo "⚠️  Note: Data is stored in ./data, config in ./config"
echo "💡 For cloud setup: https://rclone.org/docs/"