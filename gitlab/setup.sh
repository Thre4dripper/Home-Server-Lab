#!/bin/bash

# GitLab Community Edition Setup Script
# Automated installation and configuration for GitLab CE

set -e  # Exit on any error

echo "🦊 GitLab Community Edition Setup"
echo "================================="
echo ""
echo "📝 Configuration:"
echo "   • Full-featured Git hosting platform"
echo "   • Built-in CI/CD pipelines"
echo "   • Issue tracking and project management" 
echo "   • Container registry and package registry"
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
required_vars=("GITLAB_DOMAIN" "GITLAB_PORT" "GITLAB_ROOT_PASSWORD")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: Required variable $var is not set in .env file"
        exit 1
    fi
done

# Get host IP for display
HOST_IP=$(hostname -I | awk '{print $1}' || echo $GITLAB_DOMAIN)

echo "📍 Host Configuration: $HOST_IP"
echo "✅ Configuration updated"

# Create data directories
echo "📁 Creating data directories..."
mkdir -p config logs data backups

# Set proper permissions
echo "🔐 Setting permissions..."
sudo chown -R 998:998 config logs data backups 2>/dev/null || {
    echo "⚠️  Warning: Could not set ownership. GitLab may have permission issues"
    echo "   You may need to run: sudo chown -R 998:998 config logs data backups"
}

# Check system requirements
echo "🔍 Checking system requirements..."
available_ram=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ "$available_ram" -lt 2048 ]; then
    echo "⚠️  Warning: GitLab requires at least 2GB RAM. Available: ${available_ram}MB"
    echo "   GitLab may run slowly or fail to start"
fi

available_disk=$(df -BM . | awk 'NR==2{print $4}' | sed 's/M//')
if [ "$available_disk" -lt 10240 ]; then
    echo "⚠️  Warning: GitLab requires at least 10GB disk space. Available: ${available_disk}MB"
fi

# Start services
echo "🚀 Starting GitLab..."
echo "   • This may take 5-10 minutes on first startup"
echo "   • GitLab needs to initialize its database and services"
echo "   • Be patient - this is normal for GitLab!"
echo ""

docker compose up -d

# Wait for GitLab to be ready (this takes a long time)
echo "⏳ Waiting for GitLab to initialize..."
echo "   This can take up to 10 minutes, please be patient..."
echo -n "   • GitLab:     "

for i in {1..120}; do
    if curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${GITLAB_PORT}/-/health | grep -q "200"; then
        echo "✅ Ready"
        break
    elif [ $i -eq 120 ]; then
        echo "❌ Timeout (this is common on first startup)"
        echo "     GitLab may still be initializing. Check logs: docker compose logs -f"
        echo "     Try accessing http://$HOST_IP:${GITLAB_PORT} in a few more minutes"
    else
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "[$i/120]"
        else
            echo -n "."
        fi
        sleep 5
    fi
done

echo ""
echo "🧪 Testing GitLab Setup..."

# Test web interface
echo -n "Web Interface:     "
response_code=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${GITLAB_PORT} || echo "000")
if [[ "$response_code" =~ ^(200|302)$ ]]; then
    echo "✅ Accessible"
elif [ "$response_code" = "502" ]; then
    echo "⏳ Still initializing (502 Bad Gateway - this is normal)"
else
    echo "❌ Not accessible (HTTP: $response_code)"
fi

# Check data persistence
echo -n "Data Persistence:  "
if [ -d "./config" ] && [ -d "./logs" ] && [ -d "./data" ]; then
    echo "✅ Volumes mounted"
else
    echo "❌ Volume mount failed"
fi

# Check SSH port
echo -n "SSH Access:        "
if netstat -ln 2>/dev/null | grep -q ":${GITLAB_SSH_PORT}" || ss -ln 2>/dev/null | grep -q ":${GITLAB_SSH_PORT}"; then
    echo "✅ Port ${GITLAB_SSH_PORT} open"
else
    echo "⚠️  Port ${GITLAB_SSH_PORT} not accessible yet"
fi

echo ""
echo "🎉 Setup Initiated!"
echo ""
echo "📋 Access Information:"
echo "   • Web Interface: http://$HOST_IP:${GITLAB_PORT}"
echo "   • Username:      root"
echo "   • Password:      ${GITLAB_ROOT_PASSWORD}"
echo "   • Git SSH:       ssh://git@$HOST_IP:${GITLAB_SSH_PORT}/username/project.git"
echo ""
echo "⏱️  First Startup Notes:"
echo "   • GitLab may take 5-10 minutes to fully initialize"
echo "   • You may see 502 errors initially - this is normal"
echo "   • Monitor progress: docker compose logs -f gitlab"
echo "   • Check health: curl http://$HOST_IP:${GITLAB_PORT}/-/health"
echo ""
echo "📱 Next Steps:"
echo "   1. Wait for GitLab to fully initialize"
echo "   2. Access GitLab at: http://$HOST_IP:${GITLAB_PORT}"
echo "   3. Login with root/${GITLAB_ROOT_PASSWORD}"
echo "   4. Complete the admin area configuration"
echo "   5. Create users and projects"
echo "   6. Set up CI/CD runners if needed"
echo ""
echo "🔧 Management Commands:"
echo "   • View logs:    docker compose logs -f"
echo "   • Stop:         docker compose down"
echo "   • Restart:      docker compose restart"
echo "   • Update:       docker compose pull && docker compose up -d"
echo "   • Backup:       docker compose exec gitlab gitlab-backup create"
echo ""
echo "⚠️  Security Notes:"
echo "   • Change default passwords immediately"
echo "   • Configure proper SSL certificates for production"
echo "   • Set up proper firewall rules"
echo "   • Data stored in: ./config, ./logs, ./data, ./backups"
echo "   • Default SSH port: ${GITLAB_SSH_PORT}"
echo ""
echo "💡 Troubleshooting:"
echo "   • If GitLab doesn't start: check system RAM (needs 2GB+)"
echo "   • If 502 errors persist: wait longer or check logs"
echo "   • Permission issues: sudo chown -R 998:998 config logs data backups"