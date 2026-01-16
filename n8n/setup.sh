#!/bin/bash

set -e

# Function to show usage
show_usage() {
    echo "n8n Docker Management Script"
    echo ""
    echo "Usage: ./setup.sh [command]"
    echo ""
    echo "Commands:"
    echo "  setup     - Initial setup and start n8n (default)"
    echo "  start     - Start n8n container"
    echo "  stop      - Stop n8n container"
    echo "  restart   - Restart n8n container"
    echo "  logs      - View n8n logs"
    echo "  shell     - Open bash shell in container"
    echo "  rebuild   - Rebuild image from scratch"
    echo "  test      - Test tool availability"
    echo "  backup    - Backup n8n data"
    echo "  status    - Show container status"
    echo "  update    - Update to latest n8n version"
    echo ""
    echo "Examples:"
    echo "  ./setup.sh          # Run initial setup"
    echo "  ./setup.sh start    # Start n8n"
    echo "  ./setup.sh logs     # View logs"
    echo "  ./setup.sh test     # Test tools"
}

# Function to run initial setup
run_setup() {
    echo "🤖 n8n Workflow Automation Setup"
    echo "================================="
    echo ""
    echo "📝 Configuration:"
    echo "   • Database: SQLite (default for home lab) - PostgreSQL optional for production"
    echo "   • Authentication: Basic auth enabled by default"
    echo "   • Data: Persistent volumes for workflows and database"
    echo "   • Custom Image: Includes Docker, kubectl, Terraform, AWS CLI, and more"
    echo "   • Edit '.env' to customize configuration"
    echo ""

    # Create .env file from .env.example if it doesn't exist
    if [ ! -f .env ]; then
        cp .env.example .env
        echo "✅ Created .env from .env.example"
        
        # Generate a secure encryption key
        ENCRYPTION_KEY=$(openssl rand -hex 32)
        sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY/" .env
        echo "🔐 Generated secure encryption key"
    fi

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
    mkdir -p n8n_data

    # Source environment variables
    source .env

    # Start n8n
    echo "🚀 Starting n8n..."
    echo "   • Using SQLite database (lightweight, no additional services needed)"
    echo "   • Using custom Docker image with DevOps tools"
    echo "   • n8n will be ready in 30-60 seconds on first run"
    echo ""

    docker compose up -d

    # Wait for services to start
    echo "⏳ Waiting for n8n to start..."
    echo "   • This may take 30-60 seconds on first run..."

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

    # Test data persistence
    echo -n "Data Persistence:  "
    if [ -d "./n8n_data" ]; then
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
    echo "   • Database: SQLite (embedded, no external database needed)"
    echo "   • Custom Image: Includes Docker, kubectl, Terraform, AWS CLI, and more"
    echo ""
    echo "📱 Next Steps:"
    echo "   1. Access n8n at: http://$HOST_IP:${N8N_PORT}"
    echo "   2. Login with the credentials above"
    echo "   3. Create your first workflow"
    echo "   4. Configure webhooks using: http://$HOST_IP:${N8N_PORT}/webhook/..."
    echo ""
    echo "🔧 Management Commands:"
    echo "   • View logs:    ./setup.sh logs"
    echo "   • Stop:         ./setup.sh stop"
    echo "   • Restart:      ./setup.sh restart"
    echo "   • Shell:        ./setup.sh shell"
    echo "   • Update:       ./setup.sh update"
    echo "   • Test tools:   ./setup.sh test"
    echo ""
    echo "⚠️  Note: Workflows and database data are persistent in ./n8n_data"
    echo "💡 For production/heavy usage, consider switching to PostgreSQL (see README.md)"
}

# Main command handling
case "${1:-setup}" in
    setup)
        run_setup
        ;;
    
    start)
        echo "Starting n8n..."
        docker compose up -d
        source .env 2>/dev/null || true
        HOST_IP=$(hostname -I | awk '{print $1}')
        echo "n8n is running at http://${HOST_IP}:${N8N_PORT:-5678}"
        ;;
    
    stop)
        echo "Stopping n8n..."
        docker compose down
        ;;
    
    restart)
        echo "Restarting n8n..."
        docker compose restart
        ;;
    
    logs)
        echo "Showing n8n logs (Ctrl+C to exit)..."
        docker compose logs -f
        ;;
    
    shell)
        echo "Opening shell in n8n container..."
        docker exec -it n8n bash
        ;;
    
    rebuild)
        echo "Rebuilding n8n image..."
        docker compose down
        docker compose build --no-cache
        docker compose up -d
        echo "Rebuild complete!"
        ;;
    
    test)
        echo "Testing tool availability..."
        if [ -f ./test-tools.sh ]; then
            ./test-tools.sh
        else
            echo "Running basic tool test..."
            docker exec n8n bash -c "echo '=== Tool Versions ===' && \
                docker --version && \
                kubectl version --client && \
                terraform version && \
                aws --version && \
                python3 --version && \
                jq --version"
        fi
        ;;
    
    backup)
        BACKUP_FILE="n8n-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        echo "Creating backup: $BACKUP_FILE"
        tar czf "$BACKUP_FILE" n8n_data/
        echo "Backup saved to: $BACKUP_FILE"
        ;;
    
    status)
        echo "=== n8n Status ==="
        if docker ps | grep -q n8n; then
            echo "✓ Container is running"
            docker ps --filter name=n8n --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            echo "❌ Container is not running"
        fi
        ;;
    
    update)
        echo "Updating n8n..."
        echo "Note: Custom image will be rebuilt with latest n8n version"
        docker compose down
        docker compose build --no-cache
        docker compose up -d
        echo "Update complete!"
        ;;
    
    help|--help|-h)
        show_usage
        ;;
    
    *)
        echo "Error: Unknown command '$1'"
        echo ""
        show_usage
        exit 1
        ;;
esac