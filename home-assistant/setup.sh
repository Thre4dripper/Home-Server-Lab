#!/bin/bash

set -e

echo "🏠 Home Assistant Setup"
echo "======================="
echo ""
echo "📝 Configuration:"
echo "   • Config: Persistent volume for configuration"
echo "   • Network: Host mode for full access to hardware"
echo "   • Access: Web interface on port 8123"
echo ""

# Create config directory if it doesn't exist
if [ ! -d "./config" ]; then
    mkdir -p config
    echo "✅ Created config directory"
fi

# Auto-detect network configuration
HOST_IP=$(hostname -I | awk '{print $1}')

echo "📍 Host Configuration: $HOST_IP"

# Start Home Assistant
echo "🚀 Starting Home Assistant..."
echo "   • Home Assistant will be ready in 1-2 minutes on first run"
echo ""

docker compose up -d

# Wait for services to start
echo "⏳ Waiting for Home Assistant to start..."
echo "   • This may take 1-2 minutes on first run..."

# Wait for Home Assistant to be ready
echo -n "   • Home Assistant: "
for i in {1..60}; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8123 | grep -q "200\|302"; then
        echo "✅ Ready"
        break
    elif [ $i -eq 60 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs homeassistant"
        exit 1
    else
        echo -n "."
        sleep 2
    fi
done

# Test setup
echo ""
echo "🧪 Testing Home Assistant Setup..."

# Test web interface
echo -n "Web Interface:     "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8123 | grep -q "200\|302"; then
    echo "✅ Accessible"
else
    echo "❌ Not accessible"
fi

# Test data persistence
echo -n "Config Persistence:"
if [ -d "./config" ]; then
    echo "✅ Volume mounted"
else
    echo "❌ Volume issues"
fi

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   • Web Interface: http://$HOST_IP:8123"
echo "   • First time setup: Follow the on-screen instructions"
echo ""
echo "📱 Next Steps:"
echo "   1. Access Home Assistant at: http://$HOST_IP:8123"
echo "   2. Complete the initial setup wizard"
echo "   3. Add your smart home devices and integrations"
echo ""
echo "🔧 Management Commands:"
echo "   • View logs:    docker compose logs -f"
echo "   • Stop:         docker compose down"
echo "   • Restart:      docker compose restart"
echo "   • Update:       docker compose pull && docker compose up -d"
echo ""
echo "⚠️  Note: Configuration is persistent in ./config"
echo "💡 For advanced configuration, edit files in ./config"