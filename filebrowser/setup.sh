#!/usr/bin/env bash
set -euo pipefail

# FileBrowser setup script
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
mkdir -p config database || true

case "${1:-up}" in
  up)
    docker compose -f "$compose_file" up -d 
    echo ""
    echo "FileBrowser is starting..."
    echo "Access: http://$(hostname -I | awk '{print $1}'):${FILEBROWSER_PORT:-8080}"
    echo ""
    echo "Waiting for FileBrowser to initialize..."
    sleep 3
    
    # Extract credentials from logs
    echo ""
    echo "=== Login Credentials ==="
    
    # Try to extract the password from logs
    PASSWORD=$(docker compose -f "$compose_file" logs filebrowser 2>/dev/null | grep "randomly generated password" | sed -n "s/.*password: \(.*\)/\1/p" | tail -1)
    
    if [ -n "$PASSWORD" ]; then
      echo "Username: admin"
      echo "Password: $PASSWORD"
    else
      echo "Username: admin"
      echo "Password: (check logs below)"
      echo ""
      docker compose -f "$compose_file" logs filebrowser 2>/dev/null | grep -E "(User '.*' initialized|password:)" || echo "No password found in logs yet. Try: ./setup.sh logs"
    fi
    
    echo "========================="
    echo ""
    echo "⚠️  IMPORTANT: The password is only shown once. Change it immediately after login!"
    echo "If you need to see it again, run: docker compose logs filebrowser | grep password"
    ;;
  down)
    docker compose -f "$compose_file" down ;;
  restart)
    docker compose -f "$compose_file" restart filebrowser ;;
  logs)
    docker compose -f "$compose_file" logs -f filebrowser ;;
  pull)
    docker compose -f "$compose_file" pull && docker compose -f "$compose_file" up -d ;;
  *)
    echo "Usage: $0 [up|down|restart|logs|pull]" ;;
esac
