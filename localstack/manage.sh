#!/bin/bash

# LocalStack Management Script
# Manage LocalStack Pro and Community versions

set -e

# Load environment variables if available
if [ -f .env ]; then
    source .env
fi

show_help() {
    echo "🦊 LocalStack Management Script"
    echo "==============================="
    echo ""
    echo "Usage: $0 [version] [command]"
    echo ""
    echo "Versions:"
    echo "  pro         - Use LocalStack Pro"
    echo "  community   - Use LocalStack Community"
    echo ""
    echo "Commands:"
    echo "  start       - Start LocalStack"
    echo "  stop        - Stop LocalStack"
    echo "  restart     - Restart LocalStack"
    echo "  status      - Show status and health"
    echo "  logs        - Show logs (real-time)"
    echo "  health      - Check health endpoint"
    echo "  test        - Test AWS connectivity"
    echo "  clean       - Clean up volumes and containers"
    echo ""
    echo "Examples:"
    echo "  $0 pro start         # Start Pro version"
    echo "  $0 community status  # Check Community status"
    echo "  $0 pro test         # Test Pro AWS services"
}

get_compose_file() {
    case $1 in
        "pro") echo "docker-compose.pro.yml" ;;
        "community") echo "docker-compose.community.yml" ;;
        *) echo "❌ Invalid version. Use 'pro' or 'community'"; exit 1 ;;
    esac
}

show_status() {
    local compose_file=$(get_compose_file $1)
    echo "📊 LocalStack $1 Status:"
    echo "========================"
    docker compose -f $compose_file ps
    echo ""
    
    echo "🏥 Health Check:"
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
}

test_aws() {
    echo "🧪 Testing AWS Services:"
    echo "========================"
    
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

# Check arguments
if [ $# -lt 2 ]; then
    show_help
    exit 1
fi

VERSION=$1
COMMAND=$2
COMPOSE_FILE=$(get_compose_file $VERSION)

case $COMMAND in
    "start")
        echo "🚀 Starting LocalStack $VERSION..."
        docker compose -f $COMPOSE_FILE up -d
        echo "✅ LocalStack $VERSION started"
        ;;
    "stop")
        echo "🛑 Stopping LocalStack $VERSION..."
        docker compose -f $COMPOSE_FILE down
        echo "✅ LocalStack $VERSION stopped"
        ;;
    "restart")
        echo "🔄 Restarting LocalStack $VERSION..."
        docker compose -f $COMPOSE_FILE down
        docker compose -f $COMPOSE_FILE up -d
        echo "✅ LocalStack $VERSION restarted"
        ;;
    "status")
        show_status $VERSION
        ;;
    "logs")
        echo "📋 LocalStack $VERSION logs (Ctrl+C to exit):"
        docker compose -f $COMPOSE_FILE logs -f
        ;;
    "health")
        echo "🏥 Checking LocalStack health..."
        curl -s http://localhost:${LOCALSTACK_PORT:-4566}/_localstack/health | jq . 2>/dev/null || curl -s http://localhost:${LOCALSTACK_PORT:-4566}/_localstack/health
        ;;
    "test")
        test_aws
        ;;
    "clean")
        echo "🧹 Cleaning LocalStack $VERSION..."
        docker compose -f $COMPOSE_FILE down --volumes --remove-orphans
        sudo rm -rf volume/*
        echo "✅ LocalStack $VERSION cleaned"
        ;;
    *)
        echo "❌ Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac