#!/bin/bash

# Seafile Pro Edition Setup Script
# Official Docker setup with direct HTTP access (no reverse proxy)

echo "🌊 Setting up Seafile Pro Edition (Official Configuration)"
echo "=================================================="

# Check if we're in the correct directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found. Please run this script from the seafile directory."
    exit 1
fi

# Check if .env file exists and has been configured
if [ ! -f ".env" ]; then
    echo "⚠️  No .env file found. Creating from template..."
    cp .env.example .env
    echo "📝 Please edit .env with your configuration:"
    echo "  nano .env"
    echo "Then run this script again."
    exit 1
fi

# Check for placeholder values
if grep -q "your_secure_db_password\|your_mysql_root_password\|your_admin_password\|your_jwt_private_key_here\|your-server-ip" .env; then
    echo "⚠️  WARNING: Please edit the .env file with your actual configuration!"
    echo "You need to set:"
    echo "  - SEAFILE_MYSQL_DB_PASSWORD"
    echo "  - INIT_SEAFILE_MYSQL_ROOT_PASSWORD" 
    echo "  - INIT_SEAFILE_ADMIN_PASSWORD"
    echo "  - JWT_PRIVATE_KEY"
    echo "  - SEAFILE_SERVER_HOSTNAME"
    echo ""
    echo "Run: nano .env"
    echo "Then run this script again."
    exit 1
fi

# Create data directories
echo "📁 Creating data directories..."
mkdir -p data/{seafile,mysql,elasticsearch,seadoc,notification,seasearch}
chown -R $USER:$USER data/

# Check Docker Compose
if ! command -v "docker" &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Pull the latest images
echo "📦 Pulling Docker images..."
docker compose pull

# Start the services
echo "🚀 Starting Seafile Pro services..."
docker compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to initialize (this may take a few minutes)..."
sleep 60

# Check service status
echo "🔍 Checking service status..."
docker compose ps

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "🎉 Seafile Pro Edition setup complete!"
echo "=================================================="
echo "📱 Web Interface: http://${SERVER_IP}:8000"
echo "👤 Admin Login: Check .env file for credentials"
echo ""
echo "🔧 Pro Features Available:"
echo "  • Enterprise admin panel"
echo "  • Online document editing (SeaDoc)"
echo "  • Full-text search with Elasticsearch"
echo "  • File locking and versioning"
echo "  • Advanced user management"
echo "  • Audit logs and compliance"
echo ""
echo "📊 Services Running:"
echo "  • Seafile Pro: http://${SERVER_IP}:8000"
echo "  • MariaDB: Internal database"
echo "  • Elasticsearch: Search engine"
echo "  • Memcached: Performance cache"
echo "  • SeaDoc: Document editor"
echo ""
echo "📝 Next Steps:"
echo "  1. Open http://${SERVER_IP}:8000 in your browser"
echo "  2. Login with admin credentials from .env"
echo "  3. Create libraries and start uploading files"
echo "  4. Add up to 3 users (free tier limit)"
echo "  5. Explore Pro features like document editing"
echo ""
echo "📋 Management Commands:"
echo "  • View logs: docker compose logs -f"
echo "  • Stop services: docker compose down"
echo "  • Restart: docker compose restart"
echo "  • Update: docker compose pull && docker compose up -d"
echo ""
echo "🔐 Security Notes:"
echo "  • Direct HTTP access enabled on port 8000"
echo "  • Add reverse proxy later if needed (nginx/traefik)"
echo "  • All data stored in ./data/ for easy backup"
echo "  • Consider enabling HTTPS for production use"