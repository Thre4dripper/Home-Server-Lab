#!/usr/bin/env bash
set -euo pipefail

# Nginx Proxy Manager setup script
compose_file=${COMPOSE_FILE:-docker-compose.yml}

if ! command -v docker &>/dev/null; then
  echo "Docker is required" >&2
  exit 1
fi
if ! command -v docker compose &>/dev/null; then
  echo "Docker Compose V2 is required (docker compose)" >&2
  exit 1
fi

# Create necessary directories
mkdir -p data letsencrypt postgres nginx/{custom,proxy_host,redirection_host,stream,dead_host,temp,snippets} || true

case "${1:-up}" in
  up)
    # Check if .env exists
    if [ ! -f .env ]; then
      echo "⚠️  No .env file found. Creating from .env.example..."
      cp .env.example .env
      echo ""
      echo "✅ Using default SQLite database (recommended for home labs)"
      echo "💡 For larger deployments, you can enable PostgreSQL in docker-compose.yml"
      echo ""
      read -p "Press Enter to continue..."
    fi
    
    docker compose -f "$compose_file" up -d 
    echo ""
    echo "Nginx Proxy Manager is starting..."
    echo "Admin UI: http://$(hostname -I | awk '{print $1}'):${ADMIN_PORT:-81}"
    echo ""
    echo "Waiting for services to initialize..."
    sleep 5
    
    echo ""
    echo "=== Default Admin Credentials ==="
    echo "Email:    admin@example.com"
    echo "Password: changeme"
    echo "================================="
    echo ""
    echo "⚠️  You will be forced to change these on first login!"
    echo ""
    echo "📂 Nginx config files are exposed in ./nginx/ directory"
    echo "   - ./nginx/proxy_host/     - Proxy configurations"
    echo "   - ./nginx/custom/         - Custom nginx configs"
    echo "   - ./nginx/snippets/       - Reusable config snippets"
    echo ""
    echo "💾 Database: SQLite (./data/database.sqlite)"
    echo "💡 To use PostgreSQL for larger deployments, uncomment db service in docker-compose.yml"
    ;;
  down)
    docker compose -f "$compose_file" down ;;
  restart)
    docker compose -f "$compose_file" restart nginx-proxy-manager ;;
  logs)
    docker compose -f "$compose_file" logs -f "${2:-nginx-proxy-manager}" ;;
  pull)
    docker compose -f "$compose_file" pull && docker compose -f "$compose_file" up -d ;;
  *)
    echo "Usage: $0 [up|down|restart|logs|pull]"
    echo ""
    echo "Commands:"
    echo "  up      - Start services"
    echo "  down    - Stop services"
    echo "  restart - Restart main service"
    echo "  logs    - Show logs (add 'db' for database logs)"
    echo "  pull    - Update images and restart"
    ;;
esac
