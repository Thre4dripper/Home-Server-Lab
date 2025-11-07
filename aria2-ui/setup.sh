#!/bin/bash

set -e

echo "⚡ Aria2 Download Manager Setup"
echo "================================"
echo ""
echo "📝 Configuration:"
echo "   • Web UI: AriaNg interface"
echo "   • Downloads: Persistent volume for files"
echo "   • Config: Persistent volume for settings"
echo "   • RPC: For external control"
echo ""

# Clean up existing files and volumes
if [ -f .env ]; then
    rm .env
    echo "🧹 Removed existing .env"
fi

if [ -d "./downloads" ]; then
    rm -rf ./downloads
    echo "🧹 Cleaned downloads directory"
fi

if [ -d "./config" ]; then
    rm -rf ./config
    echo "🧹 Cleaned config directory"
fi

# Create .env file from .env.example
cp .env.example .env
echo "✅ Created .env from .env.example"

# Generate RPC secret
RPC_SECRET=$(openssl rand -hex 16)
sed -i "s/your-secret-change-this/$RPC_SECRET/" .env
echo "✅ Generated RPC secret: $RPC_SECRET"

# Create directories
mkdir -p downloads config
echo "✅ Created fresh directories"

# Auto-detect network configuration
HOST_IP=$(hostname -I | awk '{print $1}')

echo "📍 Host Configuration: $HOST_IP"

# Start Aria2
echo "🚀 Starting Aria2..."
echo "   • Web UI will be ready shortly"
echo ""

docker compose up -d

# Wait for services to start
echo "⏳ Waiting for Aria2 to start..."
echo "   • This may take a few seconds..."

# Wait for Aria2 to be ready
echo -n "   • Aria2 Web UI: "
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302"; then
        echo "✅ Ready"
        break
    elif [ $i -eq 30 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs ariang"
        exit 1
    else
        echo -n "."
        sleep 1
    fi
done

# Test setup
echo ""
echo "🧪 Testing Aria2 Setup..."

# Test web interface
echo -n "Web Interface:     "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302"; then
    echo "✅ Accessible"
else
    echo "❌ Not accessible"
fi

# Test data persistence
echo -n "Downloads Volume:  "
if [ -d "./downloads" ]; then
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
echo "   • Web UI: http://$HOST_IP:8080"
echo "   • RPC Port: 6800 (for external tools)"
echo ""
echo "📱 Next Steps:"
echo "   1. Access AriaNg at: http://$HOST_IP:8080"
echo "   2. Configure download settings in the web interface"
echo "   3. Add download tasks (torrents, HTTP/FTP links, etc.)"
echo ""
echo "🔧 Management Commands:"
echo "   • View logs:    docker compose logs -f"
echo "   • Stop:         docker compose down"
echo "   • Restart:      docker compose restart"
echo "   • Update:       docker compose pull && docker compose up -d"
echo ""
echo "⚠️  Note: Downloads are stored in ./downloads"
echo "💡 For advanced configuration, edit files in ./config"