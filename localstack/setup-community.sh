#!/bin/bash

# LocalStack Community Setup Script
# Automated setup for LocalStack Community with basic AWS emulation

set -e

echo "🚀 LocalStack Community Setup"
echo "============================="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📋 Creating .env file from template..."
    cp .env.example .env
    echo "ℹ️  Community version doesn't require LOCALSTACK_AUTH_TOKEN"
    echo "   Basic configuration applied automatically"
fi

echo "🔧 Starting LocalStack Community setup..."
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
echo "📥 Pulling LocalStack Community image..."
docker compose -f docker-compose.community.yml pull

# Start LocalStack Community
echo "🏃 Starting LocalStack Community..."
docker compose -f docker-compose.community.yml up -d

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to initialize..."
timeout=120
counter=0

while [ $counter -lt $timeout ]; do
    if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
        echo "✅ LocalStack Community is ready!"
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
    docker compose -f docker-compose.community.yml logs --tail 20
    exit 1
fi

# Display status
echo ""
echo "📊 LocalStack Community Status:"
echo "==============================="
docker compose -f docker-compose.community.yml ps

echo ""
echo "🎉 LocalStack Community Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   LocalStack Gateway: http://localhost:4566"
echo "   Health Check:       http://localhost:4566/_localstack/health"
echo "   ⚠️  Cloud Dashboard: Not available (Pro feature)"
echo ""
echo "🔧 Management Commands:"
echo "   Start:   docker compose -f docker-compose.community.yml up -d"
echo "   Stop:    docker compose -f docker-compose.community.yml down"
echo "   Logs:    docker compose -f docker-compose.community.yml logs -f"
echo "   Status:  docker compose -f docker-compose.community.yml ps"
echo ""
echo "📚 Documentation:"
echo "   LocalStack Docs:    https://docs.localstack.cloud"
echo "   AWS CLI Setup:      aws configure --profile localstack"
echo "   Endpoint URL:       --endpoint-url=http://localhost:4566"
echo ""
echo "⬆️  Upgrade to Pro:"
echo "   Get auth token:     https://app.localstack.cloud"
echo "   Use setup:          ./setup-pro.sh"