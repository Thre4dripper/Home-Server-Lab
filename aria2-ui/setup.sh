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

# Check and setup .env file
if [ ! -f .env ]; then
    cp .env.example .env
    echo "✅ Created .env from .env.example"
    
    # Generate RPC secret only for new setup
    RPC_SECRET=$(openssl rand -hex 16)
    sed -i "s/your-secret-change-this/$RPC_SECRET/" .env
    echo "✅ Generated RPC secret: $RPC_SECRET"
else
    echo "ℹ️  Using existing .env file"
    # Extract existing RPC_SECRET from .env
    RPC_SECRET=$(grep "^RPC_SECRET=" .env | cut -d'=' -f2)
    echo "ℹ️  Using existing RPC secret: $RPC_SECRET"
fi

# Create directories if they don't exist
mkdir -p downloads config
echo "✅ Ensured directories exist"

# Initialize or update aria2.conf with proper RPC secret
if [ ! -f ./config/aria2.conf ]; then
    # First time setup - copy template
    if [ -f ./aria2.conf.template ]; then
        cp ./aria2.conf.template ./config/aria2.conf
        echo "✅ Created aria2.conf from template"
    else
        echo "⚠️  Template not found, creating basic config"
        cat > ./config/aria2.conf << 'EOF'
enable-rpc=true
rpc-allow-origin-all=true
rpc-listen-all=true
disable-ipv6=true
max-concurrent-downloads=5
continue=true
max-connection-per-server=5
min-split-size=10M
split=10
max-overall-download-limit=0
max-download-limit=0
max-overall-upload-limit=0
max-upload-limit=0
dir=/aria2/data
file-allocation=prealloc
console-log-level=notice
input-file=/aria2/conf/aria2.session
save-session=/aria2/conf/aria2.session
save-session-interval=10
EOF
    fi
fi

# Always ensure no hardcoded RPC secret in aria2.conf (it comes from env)
sed -i '/^rpc-secret=/d' ./config/aria2.conf
echo "✅ aria2.conf ready (RPC secret will be injected from environment)"

# Initialize session file if it doesn't exist
if [ ! -f ./config/aria2.session ]; then
    touch ./config/aria2.session
    chmod 644 ./config/aria2.session
    echo "✅ Initialized aria2.session file"
fi

# Set proper permissions
chmod 644 ./config/aria2.conf 2>/dev/null || true
chmod 644 ./config/aria2.session 2>/dev/null || true

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

# Get configuration from .env
ARIA2RPCPORT=$(grep "^ARIA2RPCPORT=" .env | cut -d'=' -f2)
WEBUI_PORT=$(grep "^WEBUI_PORT=" .env | cut -d'=' -f2)
EMBED_RPC_SECRET=$(grep "^EMBED_RPC_SECRET=" .env | cut -d'=' -f2 2>/dev/null || echo "false")

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   • Web UI: http://$HOST_IP:$WEBUI_PORT"
echo "   • RPC Secret: $RPC_SECRET"
echo "   • RPC Port Setting: $ARIA2RPCPORT"
if [ "$EMBED_RPC_SECRET" = "true" ]; then
    echo "   • Auto-configured: YES (secret embedded in UI)"
else
    echo "   • Auto-configured: NO (manual setup required)"
fi
echo ""

if [ "$ARIA2RPCPORT" = "443" ] || [ "$ARIA2RPCPORT" = "80" ]; then
    echo "🔒 Reverse Proxy Mode Detected (ARIA2RPCPORT=$ARIA2RPCPORT)"
    echo ""
    echo "📍 Your Setup:"
    echo "   • Aria2 runs inside container on internal port 6800"
    echo "   • Your reverse proxy forwards HTTPS/HTTP to aria2"
    echo "   • AriaNg connects via your domain on port $ARIA2RPCPORT"
    echo ""
    if [ "$EMBED_RPC_SECRET" = "true" ]; then
        echo "✅ AriaNg is auto-configured with your RPC secret"
        echo "   Just access the Web UI - no manual setup needed!"
    else
        echo "🔗 AriaNg Connection Setup (one-time):"
        echo "   1. Open Web UI: http://$HOST_IP:$WEBUI_PORT"
        echo "   2. Go to: AriaNg Settings → RPC"
        echo "   3. Set these values:"
        echo "      - Aria2 RPC Address: https://your-domain.com:$ARIA2RPCPORT/jsonrpc"
        echo "      - Aria2 RPC Secret Token: $RPC_SECRET"
        echo "   4. Click 'Reload AriaNg'"
    fi
    echo ""
    echo "⚙️  Reverse Proxy Requirements:"
    echo "   Your reverse proxy should:"
    echo "   • Forward Web UI to: http://$HOST_IP:8080"
    echo "   • Forward RPC to: ws://$HOST_IP:6800 (for aria2 WebSocket)"
    echo "   • Pass through /jsonrpc endpoint"
else
    echo "🌐 Direct Access Mode (ARIA2RPCPORT=$ARIA2RPCPORT)"
    echo ""
    echo "📍 Your Setup:"
    echo "   • Aria2 RPC accessible directly on port $ARIA2RPCPORT"
    echo "   • No reverse proxy in between"
    echo ""
    if [ "$EMBED_RPC_SECRET" = "true" ]; then
        echo "✅ AriaNg is auto-configured with your RPC secret"
        echo "   Just access the Web UI - no manual setup needed!"
    else
        echo "🔗 AriaNg Connection Setup (one-time):"
        echo "   1. Open Web UI: http://$HOST_IP:$WEBUI_PORT"
        echo "   2. Go to: AriaNg Settings → RPC"
        echo "   3. Set these values:"
        echo "      - Aria2 RPC Address: http://localhost:$ARIA2RPCPORT/jsonrpc"
        echo "      - Aria2 RPC Secret Token: $RPC_SECRET"
        echo "   4. Click 'Reload AriaNg'"
    fi
fi

echo ""
echo "💡 Important Notes:"
echo "   • Configuration persists across restarts"
echo "   • RPC secret stored in .env file - keep it secure"
echo "   • aria2 config in ./config/aria2.conf (no hardcoded secrets)"
echo "   • To auto-configure AriaNg, set EMBED_RPC_SECRET=true in .env"
echo "     (only use with authentication like basic auth)"
echo ""
echo "🔧 Management Commands:"
echo "   • View logs:    docker compose logs -f"
echo "   • Restart:      docker compose restart"
echo "   • Stop:         docker compose down"
echo "   • Update:       docker compose pull && docker compose up -d"