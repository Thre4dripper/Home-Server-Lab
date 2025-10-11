#!/bin/bash

# LocalStack Community Setup Script
# Automated setup and management for LocalStack Community with basic AWS emulation

set -e

# Show help function
show_help() {
    echo "🚀 LocalStack Community Management"
    echo "=================================="
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup       - Initial setup and start (default)"
    echo "  start       - Start LocalStack Community"
    echo "  stop        - Stop LocalStack Community"
    echo "  restart     - Restart LocalStack Community"
    echo "  status      - Show status and health"
    echo "  logs        - Show logs (real-time)"
    echo "  health      - Check health endpoint"
    echo "  test        - Test AWS connectivity"
    echo "  clean       - Clean up volumes and containers"
    echo ""
    echo "Examples:"
    echo "  $0           # Initial setup"
    echo "  $0 setup     # Initial setup"
    echo "  $0 stop      # Stop services"
    echo "  $0 status    # Check status"
}

# Test AWS services function
test_aws() {
    echo "🧪 Testing AWS Services:"
    echo "========================"
    
    # Load environment variables
    if [ -f .env ]; then
        source .env
    fi
    
    # Test S3
    echo "📦 Testing S3..."
    if aws --profile localstack --endpoint-url=http://localhost:${LOCALSTACK_PORT:-4566} s3 ls >/dev/null 2>&1; then
        echo "   ✅ S3 working"
    else
        echo "   ❌ S3 failed"
    fi
    
    # Test DynamoDB
    echo "🗃️  Testing DynamoDB..."
    if aws --profile localstack --endpoint-url=http://localhost:${LOCALSTACK_PORT:-4566} dynamodb list-tables >/dev/null 2>&1; then
        echo "   ✅ DynamoDB working"
    else
        echo "   ❌ DynamoDB failed"
    fi
    
    # Test Lambda
    echo "⚡ Testing Lambda..."
    if aws --profile localstack --endpoint-url=http://localhost:${LOCALSTACK_PORT:-4566} lambda list-functions >/dev/null 2>&1; then
        echo "   ✅ Lambda working"
    else
        echo "   ❌ Lambda failed"
    fi
    
    echo ""
    echo "💡 Tip: Configure AWS CLI with:"
    echo "   aws configure --profile localstack"
    echo "   AWS Access Key ID: ${AWS_ACCESS_KEY_ID:-test}"
    echo "   AWS Secret Access Key: ${AWS_SECRET_ACCESS_KEY:-test}"
    echo "   Default region: ${AWS_DEFAULT_REGION:-us-east-1}"
}

# Parse command
COMMAND=${1:-setup}

case $COMMAND in
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
    "stop")
        echo "🛑 Stopping LocalStack Community..."
        docker compose -f docker-compose.community.yml down
        echo "✅ LocalStack Community stopped"
        exit 0
        ;;
    "start")
        echo "🚀 Starting LocalStack Community..."
        docker compose -f docker-compose.community.yml up -d
        echo "✅ LocalStack Community started"
        exit 0
        ;;
    "restart")
        echo "🔄 Restarting LocalStack Community..."
        docker compose -f docker-compose.community.yml down
        docker compose -f docker-compose.community.yml up -d
        echo "✅ LocalStack Community restarted"
        exit 0
        ;;
    "status")
        echo "📊 LocalStack Community Status:"
        echo "==============================="
        docker compose -f docker-compose.community.yml ps
        echo ""
        echo "🏥 Health Check:"
        if [ -f .env ]; then
            source .env
        fi
        health_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${LOCALSTACK_PORT:-4566}/_localstack/health 2>/dev/null || echo "000")
        case $health_code in
            "200") echo "   ✅ Healthy" ;;
            "503") echo "   🔄 Starting up" ;;
            "000") echo "   ❌ Not running" ;;
            *) echo "   ⚠️  Unknown status (HTTP: $health_code)" ;;
        esac
        echo ""
        echo "🌐 Web Interface:"
        web_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${LOCALSTACK_PORT:-4566} 2>/dev/null || echo "000")
        case $web_code in
            "200"|"302") echo "   ✅ Accessible at http://localhost:${LOCALSTACK_PORT:-4566}" ;;
            "000") echo "   ❌ Not accessible" ;;
            *) echo "   ⚠️  Status: HTTP $web_code" ;;
        esac
        exit 0
        ;;
    "logs")
        echo "📋 LocalStack Community logs (Ctrl+C to exit):"
        docker compose -f docker-compose.community.yml logs -f
        exit 0
        ;;
    "health")
        echo "🏥 Checking LocalStack health..."
        if [ -f .env ]; then
            source .env
        fi
        curl -s http://localhost:${LOCALSTACK_PORT:-4566}/_localstack/health | jq . 2>/dev/null || curl -s http://localhost:${LOCALSTACK_PORT:-4566}/_localstack/health
        exit 0
        ;;
    "test")
        test_aws
        exit 0
        ;;
    "clean")
        echo "🧹 Cleaning LocalStack Community..."
        docker compose -f docker-compose.community.yml down --volumes --remove-orphans
        sudo rm -rf volume/* 2>/dev/null || true
        echo "✅ LocalStack Community cleaned"
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
echo "   Start:   ./setup-community.sh start"
echo "   Stop:    ./setup-community.sh stop"
echo "   Restart: ./setup-community.sh restart"
echo "   Status:  ./setup-community.sh status"
echo "   Logs:    ./setup-community.sh logs"
echo "   Test:    ./setup-community.sh test"
echo "   Clean:   ./setup-community.sh clean"
echo ""
echo "📚 Documentation:"
echo "   LocalStack Docs:    https://docs.localstack.cloud"
echo "   AWS CLI Setup:      aws configure --profile localstack"
echo "   Endpoint URL:       --endpoint-url=http://localhost:4566"
echo ""
echo "⬆️  Upgrade to Pro:"
echo "   Get auth token:     https://app.localstack.cloud"
echo "   Use setup:          ./setup-pro.sh"