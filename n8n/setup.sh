#!/bin/bash

set -e

echo "🤖 n8n Workflow Automation Setup"
echo "================================="
echo ""
echo "📝 Configuration:"
echo "   • Database: PostgreSQL with persistent storage"
echo "   • Authentication: Basic auth enabled by default"
echo "   • Data: Persistent volumes for workflows and database"
echo "   • Edit '.env' to customize configuration"
echo ""

# Auto-detect network configuration
HOST_IP=$(hostname -I | awk '{print $1}')

echo "📍 Host Configuration: $HOST_IP"

# Update .env file with host IP if it's set to localhost
if grep -q "N8N_HOST=localhost" .env; then
    echo "🔧 Updating n8n host configuration..."
    sed -i "s/N8N_HOST=localhost/N8N_HOST=$HOST_IP/" .env
    sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=http://$HOST_IP:\${N8N_PORT}|" .env
fi

echo "✅ Configuration updated"

# Create data directories
echo "📁 Creating data directories..."
mkdir -p postgres_data n8n_data

# Source environment variables
source .env

# Start n8n and PostgreSQL
echo "🚀 Starting n8n and PostgreSQL..."
echo "   • PostgreSQL will start first and run health checks"
echo "   • n8n will wait for PostgreSQL to be ready"
echo ""

docker compose up -d

# Wait for services to start
echo "⏳ Waiting for services to start..."
echo "   • This may take 30-60 seconds on first run..."

# Wait for PostgreSQL to be healthy
echo -n "   • PostgreSQL: "
for i in {1..30}; do
    if docker compose ps postgres | grep -q "healthy"; then
        echo "✅ Ready"
        break
    elif [ $i -eq 30 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs postgres"
        exit 1
    else
        echo -n "."
        sleep 2
    fi
done

# Wait for n8n to be ready
echo -n "   • n8n:        "
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${N8N_PORT} | grep -q "200\|401"; then
        echo "✅ Ready"
        break
    elif [ $i -eq 30 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs n8n"
        exit 1
    else
        echo -n "."
        sleep 2
    fi
done

# Test setup
echo ""
echo "🧪 Testing n8n Setup..."

# Test web interface
echo -n "Web Interface:     "
if curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${N8N_PORT} | grep -q "200\|401"; then
    echo "✅ Accessible"
else
    echo "❌ Not accessible"
fi

# Test database connection
echo -n "Database:          "
if docker exec n8n_postgres pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} > /dev/null 2>&1; then
    echo "✅ Connected"
else
    echo "❌ Connection failed"
fi

# Test data persistence
echo -n "Data Persistence:  "
if [ -d "./postgres_data" ] && [ -d "./n8n_data" ]; then
    echo "✅ Volumes mounted"
else
    echo "❌ Volume issues"
fi

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   • Web Interface: http://$HOST_IP:${N8N_PORT}"
echo "   • Username: ${N8N_BASIC_AUTH_USER}"
echo "   • Password: ${N8N_BASIC_AUTH_PASSWORD}"
echo "   • Database: PostgreSQL on port 5432"
echo ""
echo "📱 Next Steps:"
echo "   1. Access n8n at: http://$HOST_IP:${N8N_PORT}"
echo "   2. Login with the credentials above"
echo "   3. Create your first workflow"
echo "   4. Configure webhooks using: http://$HOST_IP:${N8N_PORT}/webhook/..."
echo ""
echo "🔧 Management Commands:"
echo "   • View logs:    docker compose logs -f"
echo "   • Stop:         docker compose down"
echo "   • Restart:      docker compose restart"
echo "   • Update:       docker compose pull && docker compose up -d"
echo ""
echo "⚠️  Note: Workflows and database data are persistent in ./n8n_data and ./postgres_data"