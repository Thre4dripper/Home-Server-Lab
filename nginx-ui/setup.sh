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
mkdir -p data letsencrypt postgres nginx/{custom,proxy_host,redirection_host,stream,dead_host,temp,snippets} backups || true

case "${1:-up}" in
  up)
    # Check if .env exists
    if [ ! -f .env ]; then
      echo "⚠️  No .env file found. Creating from .env.example..."
      cp .env.example .env
      echo ""
      echo "⚠️  IMPORTANT: Edit .env and change DB_PASSWORD before starting!"
      echo "Run: nano .env"
      echo ""
      read -p "Press Enter to continue or Ctrl+C to abort..."
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
    ;;
  down)
    docker compose -f "$compose_file" down ;;
  restart)
    docker compose -f "$compose_file" restart nginx-proxy-manager ;;
  logs)
    docker compose -f "$compose_file" logs -f "${2:-nginx-proxy-manager}" ;;
  backup)
    DATE=$(date +%Y%m%d_%H%M%S)
    echo "Creating backup: backups/npm_db_${DATE}.sql"
    docker compose -f "$compose_file" exec -T db pg_dump -U npm npm > "backups/npm_db_${DATE}.sql"
    echo "Creating backup: backups/npm_data_${DATE}.tar.gz"
    tar -czf "backups/npm_data_${DATE}.tar.gz" ./data ./letsencrypt ./nginx 2>/dev/null || true
    echo "✅ Backup complete!"
    ;;
  restore)
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 restore <backup.sql>"
      exit 1
    fi
    echo "Restoring database from $2..."
    docker compose -f "$compose_file" exec -T db psql -U npm npm < "$2"
    echo "✅ Restore complete!"
    ;;
  pull)
    docker compose -f "$compose_file" pull && docker compose -f "$compose_file" up -d ;;
  *)
    echo "Usage: $0 [up|down|restart|logs|backup|restore|pull]"
    echo ""
    echo "Commands:"
    echo "  up       - Start services"
    echo "  down     - Stop services"
    echo "  restart  - Restart main service"
    echo "  logs     - Show logs (add 'db' for database logs)"
    echo "  backup   - Backup database and data"
    echo "  restore  - Restore from backup file"
    echo "  pull     - Update images and restart"
    ;;
esac
