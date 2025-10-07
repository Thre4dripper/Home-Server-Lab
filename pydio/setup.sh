#!/bin/bash

set -e

echo "📁 Pydio Cells File Sharing Setup"
echo "=================================="
echo ""
echo "📝 Configuration:"
echo "   • File sharing platform with web interface"
echo "   • MySQL database with persistent storage"
echo "   • External storage mount support"
echo "   • Edit '.env' to customize configuration"
echo ""

# Auto-detect network configuration
HOST_IP=$(hostname -I | awk '{print $1}')

echo "📍 Host Configuration: $HOST_IP"

# Update .env file with host IP if it's set to localhost
if grep -q "PYDIO_HOST=localhost" .env; then
    echo "🔧 Updating Pydio host configuration..."
    sed -i "s/PYDIO_HOST=localhost/PYDIO_HOST=$HOST_IP/" .env
fi

echo "✅ Configuration updated"

# Source environment variables
source .env

# Create data directories
echo "📁 Creating data directories..."
mkdir -p cellsdir mysqldir

# Check external storage path
echo "🔍 Checking external storage..."
if [ -d "$EXTERNAL_STORAGE_PATH" ]; then
    echo "   ✅ External storage found: $EXTERNAL_STORAGE_PATH"
else
    echo "   ⚠️  External storage not found: $EXTERNAL_STORAGE_PATH"
    echo "   📝 Creating directory (you may want to mount actual storage here)"
    sudo mkdir -p "$EXTERNAL_STORAGE_PATH"
    sudo chown $(id -u):$(id -g) "$EXTERNAL_STORAGE_PATH"
fi

# Generate install.yml from template for automatic setup
echo "🔧 Generating install configuration..."
set -a && source .env && set +a && envsubst < install.yml.template > install.yml

# Create external network if it doesn't exist
echo "🌐 Setting up network..."
if ! docker network inspect pi-services >/dev/null 2>&1; then
    echo "   Creating pi-services network..."
    docker network create pi-services
else
    echo "   ✅ pi-services network already exists"
fi

# Start Pydio and MySQL
echo "🚀 Starting Pydio Cells and MySQL..."
echo "   • MySQL will start first and run health checks"
echo "   • Pydio will wait for MySQL to be ready"
echo "   • Initial setup may take 2-3 minutes..."
echo ""

docker compose up -d

# Wait for services to start
echo "⏳ Waiting for services to start..."

# Wait for MySQL to be healthy
echo -n "   • MySQL:      "
for i in {1..60}; do
    if docker compose ps mysql | grep -q "healthy"; then
        echo "✅ Ready"
        break
    elif [ $i -eq 60 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs mysql"
        exit 1
    else
        echo -n "."
        sleep 2
    fi
done

# Wait for Pydio to be ready
echo -n "   • Pydio:      "
for i in {1..60}; do
    if curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${PYDIO_PORT} | grep -q "200\|302\|401"; then
        echo "✅ Ready"
        break
    elif [ $i -eq 60 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs cells"
        exit 1
    else
        echo -n "."
        sleep 3
    fi
done

# Test setup
echo ""
echo "🧪 Testing Pydio Setup..."

# Test web interface
echo -n "Web Interface:     "
if curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${PYDIO_PORT} | grep -q "200\|302\|401"; then
    echo "✅ Accessible"
else
    echo "❌ Not accessible"
fi

# Test database connection
echo -n "Database:          "
if docker exec pydio-mysql mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD} > /dev/null 2>&1; then
    echo "✅ Connected"
else
    echo "❌ Connection failed"
fi

# Test data persistence
echo -n "Data Persistence:  "
if [ -d "./cellsdir" ] && [ -d "./mysqldir" ]; then
    echo "✅ Volumes mounted"
else
    echo "❌ Volume issues"
fi

# Test external storage
echo -n "External Storage:  "
if [ -d "$EXTERNAL_STORAGE_PATH" ]; then
    echo "✅ Available"
else
    echo "❌ Not found"
fi

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   • Web Interface: http://$HOST_IP:${PYDIO_PORT}"
echo "   • Username: ${FRONTEND_LOGIN}"
echo "   • Password: ${FRONTEND_PASSWORD}"
echo "   • Database: MySQL on internal network"
echo "   • External Storage: ${EXTERNAL_STORAGE_PATH}"
echo ""
echo "📱 Next Steps:"
echo "   1. Access Pydio at: http://$HOST_IP:${PYDIO_PORT}"
echo "   2. Login with the credentials above"
echo "   3. Configure additional storage if needed"
echo "   4. Set up user accounts and workspaces"
echo "   5. Configure HTTPS with Nginx and Let's Encrypt if needed"
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
echo "   • Data stored in: ./cellsdir and ./mysqldir"