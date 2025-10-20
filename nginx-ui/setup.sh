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
  backup)
    DATE=$(date +%Y%m%d_%H%M%S)
    echo "Creating SQLite database backup: backups/database_${DATE}.sqlite"
    sudo cp ./data/database.sqlite "backups/database_${DATE}.sqlite" 2>/dev/null && sudo chown $(whoami):$(whoami) "backups/database_${DATE}.sqlite" || echo "⚠️  Database file not found yet"
    echo "Creating data backup: backups/npm_data_${DATE}.tar.gz"
    sudo tar -czf "backups/npm_data_${DATE}.tar.gz" ./data ./letsencrypt ./nginx 2>/dev/null && sudo chown $(whoami):$(whoami) "backups/npm_data_${DATE}.tar.gz" || true
    echo "✅ Backup complete!"
    echo ""
    echo "💡 If using PostgreSQL, use: docker compose exec db pg_dump -U npm npm > backup.sql"
    ;;
  restore)
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 restore <backup.sqlite>"
      echo "Example: $0 restore backups/database_20251020.sqlite"
      echo ""
      echo "Available backups:"
      ls -lh backups/*.sqlite 2>/dev/null || echo "  No backups found"
      exit 1
    fi
    
    # Check if file exists, if not try backups/ directory
    BACKUP_FILE="$2"
    if [ ! -f "$BACKUP_FILE" ]; then
      # Try looking in backups/ directory
      if [ -f "backups/$2" ]; then
        BACKUP_FILE="backups/$2"
      else
        echo "❌ Error: Backup file not found: $2"
        echo ""
        echo "Available backups:"
        ls -lh backups/*.sqlite 2>/dev/null || echo "  No backups found"
        exit 1
      fi
    fi
    
    echo "Stopping container..."
    docker compose -f "$compose_file" down
    echo "Restoring SQLite database from $BACKUP_FILE..."
    sudo cp "$BACKUP_FILE" ./data/database.sqlite
    sudo chown root:root ./data/database.sqlite
    echo "Starting container..."
    docker compose -f "$compose_file" up -d
    echo "✅ Restore complete!"
    echo ""
    echo "💡 For PostgreSQL restore: docker compose exec -T db psql -U npm npm < backup.sql"
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
