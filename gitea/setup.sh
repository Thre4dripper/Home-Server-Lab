#!/bin/bash

# Gitea Git Service Setup Script
# Automated installation and configuration for Gitea with PostgreSQL

set -e  # Exit on any error

echo "🔧 Gitea Git Service Setup"
echo "=========================="
echo ""
echo "📝 Configuration:"
echo "   • Git hosting platform with web interface"
echo "   • PostgreSQL database with persistent storage" 
echo "   • SSH access for Git operations"
echo "   • Edit '.env' to customize configuration"
echo ""

# Load environment variables
if [ -f .env ]; then
    set -a  # Export all variables
    source .env
    set +a  # Stop exporting
else
    echo "❌ Error: .env file not found"
    echo "   Please copy .env.example to .env and configure it"
    exit 1
fi

# Validate required variables
required_vars=("GITEA_DOMAIN" "GITEA_PORT" "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_DB")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: Required variable $var is not set in .env file"
        exit 1
    fi
done

# Get host IP for display
HOST_IP=$(hostname -I | awk '{print $1}' || echo $GITEA_DOMAIN)

echo "📍 Host Configuration: $HOST_IP"
echo "✅ Configuration updated"

# Create data directories
echo "📁 Creating data directories..."
mkdir -p gitea postgres

# Set proper permissions for Gitea data directory
echo "🔐 Setting permissions..."
sudo chown -R ${USER_UID}:${USER_GID} gitea 2>/dev/null || {
    echo "⚠️  Warning: Could not set ownership. Run 'sudo chown -R ${USER_UID}:${USER_GID} gitea' manually if needed"
}

# Create network if it doesn't exist
echo "🌐 Setting up network..."
if ! docker network ls | grep -q "pi-services"; then
    echo "   • Creating pi-services network..."
    docker network create pi-services
else
    echo "   ✅ pi-services network already exists"
fi

# Start services
echo "🚀 Starting Gitea and PostgreSQL..."
echo "   • PostgreSQL will start first and run health checks"
echo "   • Gitea will wait for PostgreSQL to be ready"
echo "   • Initial setup may take 2-3 minutes..."
echo ""

docker compose up -d

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for services to start..."
echo -n "   • PostgreSQL: "
for i in {1..30}; do
    if docker compose exec -T db pg_isready -U $POSTGRES_USER -d $POSTGRES_DB >/dev/null 2>&1; then
        echo "✅ Ready"
        break
    elif [ $i -eq 30 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs db"
        exit 1
    else
        echo -n "."
        sleep 2
    fi
done

# Wait for Gitea to be ready
echo -n "   • Gitea:      "
for i in {1..60}; do
    if curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${GITEA_PORT} | grep -q "200\|302\|401"; then
        echo "✅ Ready"
        break
    elif [ $i -eq 60 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs gitea"
        exit 1
    else
        echo -n "."
        sleep 3
    fi
done

# Test setup
echo ""
echo "🧪 Testing Gitea Setup..."

# Test web interface
echo -n "Web Interface:     "
if curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${GITEA_PORT} | grep -q "200\|302\|401"; then
    echo "✅ Accessible"
else
    echo "❌ Not accessible"
    exit 1
fi

# Test database connectivity
echo -n "Database:          "
if docker compose exec -T db pg_isready -U $POSTGRES_USER -d $POSTGRES_DB >/dev/null 2>&1; then
    echo "✅ Connected"
else
    echo "❌ Connection failed"
    exit 1
fi

# Check data persistence
echo -n "Data Persistence:  "
if [ -d "./gitea" ] && [ -d "./postgres" ]; then
    echo "✅ Volumes mounted"
else
    echo "❌ Volume mount failed"
    exit 1
fi

# Check SSH port
echo -n "SSH Access:        "
if netstat -ln | grep -q ":${GITEA_SSH_PORT}"; then
    echo "✅ Port ${GITEA_SSH_PORT} open"
else
    echo "⚠️  Port ${GITEA_SSH_PORT} not accessible"
fi

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   • Web Interface: http://$HOST_IP:${GITEA_PORT}"
echo "   • Git SSH:       ssh://git@$HOST_IP:${GITEA_SSH_PORT}/user/repo.git"
echo "   • Database:      PostgreSQL on internal network"
echo ""
echo "📱 Next Steps:"
echo "   1. Access Gitea at: http://$HOST_IP:${GITEA_PORT}"
echo "   2. Complete the initial setup wizard"
echo "   3. Create your first admin user"
echo "   4. Set up repositories and organizations"
echo "   5. Configure SSH keys for Git operations"
echo ""
echo "🔧 Management Commands:"
echo "   • View logs:    docker compose logs -f"
echo "   • Stop:         docker compose down"
echo "   • Restart:      docker compose restart"
echo "   • Update:       docker compose pull && docker compose up -d"
echo ""
echo "⚠️  Security Notes:"
echo "   • Change default passwords in production"
echo "   • Configure proper SSL certificates"
echo "   • Set up proper firewall rules"
echo "   • Data stored in: ./gitea and ./postgres"
echo "   • Default SSH port changed to ${GITEA_SSH_PORT} to avoid conflicts"