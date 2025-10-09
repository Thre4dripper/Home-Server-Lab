#!/bin/bash

# LocalStack Pro Setup Script
# Automated setup for LocalStack Pro with AWS cloud emulation and persistence

set -e

echo "🚀 LocalStack Pro Setup"
echo "======================"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📋 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file and add your LOCALSTACK_AUTH_TOKEN"
    echo "   You can get your token from: https://app.localstack.cloud"
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$LOCALSTACK_AUTH_TOKEN" ] || [ "$LOCALSTACK_AUTH_TOKEN" = "your_auth_token_here" ]; then
    echo "❌ Error: Please set LOCALSTACK_AUTH_TOKEN in .env file"
    echo "   Get your token from: https://app.localstack.cloud"
    exit 1
fi

echo "🔧 Starting LocalStack setup..."
echo ""

# Create required directories
echo "📁 Creating directories..."
mkdir -p volume
sudo chown -R $USER:$USER volume

# Stop any existing containers
echo "🛑 Stopping existing LocalStack containers..."
docker compose -f docker-compose.pro.yml down --remove-orphans 2>/dev/null || true
docker compose -f docker-compose.community.yml down --remove-orphans 2>/dev/null || true

# Pull latest images
echo "📥 Pulling LocalStack Pro image..."
docker compose -f docker-compose.pro.yml pull

# Start LocalStack Pro
echo "🏃 Starting LocalStack Pro..."
docker compose -f docker-compose.pro.yml up -d

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to initialize..."
timeout=120
counter=0

while [ $counter -lt $timeout ]; do
    if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
        echo "✅ LocalStack is ready!"
        break
    fi
    
    if [ $((counter % 10)) -eq 0 ]; then
        echo "   Still waiting... ($counter/$timeout seconds)"
    fi
    
    sleep 2
    counter=$((counter + 2))
done

if [ $counter -ge $timeout ]; then
    echo "❌ LocalStack failed to start within $timeout seconds"
    echo "📋 Container logs:"
    docker compose logs --tail 20
    exit 1
fi

# Display status
echo ""
echo "📊 LocalStack Pro Status:"
echo "========================="
docker compose -f docker-compose.pro.yml ps

echo ""
echo "🎉 LocalStack Pro Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   LocalStack Gateway: http://localhost:4566"
echo "   Cloud Dashboard:    https://app.localstack.cloud"
echo "   Health Check:       http://localhost:4566/_localstack/health"
echo ""
echo "🔧 Management Commands:"
echo "   Start:   docker compose -f docker-compose.pro.yml up -d"
echo "   Stop:    docker compose -f docker-compose.pro.yml down"
echo "   Logs:    docker compose -f docker-compose.pro.yml logs -f"
echo "   Status:  docker compose -f docker-compose.pro.yml ps"
echo ""
echo "📚 Documentation:"
echo "   LocalStack Docs:    https://docs.localstack.cloud"
echo "   AWS CLI Setup:      aws configure --profile localstack"
echo "   Endpoint URL:       --endpoint-url=http://localhost:4566"