#!/usr/bin/env bash
set -euo pipefail

# qBittorrent setup script
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
mkdir -p config downloads || true

case "${1:-up}" in
  up)
    # Check if .env exists
    if [ ! -f .env ]; then
      echo "⚠️  No .env file found. Creating from .env.example..."
      cp .env.example .env
      echo "✅ Created .env file with default settings"
      echo ""
    fi
    
    docker compose -f "$compose_file" up -d 
    echo ""
    echo "qBittorrent is starting..."
    echo "WebUI: http://$(hostname -I | awk '{print $1}'):${QBT_WEBUI_PORT:-8080}"
    echo ""
    echo "Waiting for qBittorrent to initialize..."
    sleep 5
    
    echo ""
    echo "=== Login Credentials ==="
    
    # Try to extract temporary password from logs (qBittorrent >= 4.6.1)
    TEMP_PASSWORD=$(docker compose -f "$compose_file" logs qbittorrent 2>&1 | grep -i "temporary password is provided" | sed -n 's/.*password is provided for this session: \(.*\)/\1/p' | tail -1)
    
    if [ -n "$TEMP_PASSWORD" ]; then
      echo "Username: admin"
      echo "Temporary Password: $TEMP_PASSWORD"
      echo ""
      echo "⚠️  This is a one-time password. Change it immediately after login!"
    else
      echo "Username: admin"
      echo "Password: adminadmin (for older versions < 4.6.1)"
      echo ""
      echo "OR check logs for temporary password (versions ≥ 4.6.1):"
      echo "  docker compose logs qbittorrent | grep 'temporary password'"
    fi
    echo "========================="
    echo ""
    echo "📥 Downloads location: ${DOWNLOADS_PATH:-./downloads}"
    echo "⚙️  To change password: Tools → Options → Web UI → Authentication"
    ;;
  down)
    docker compose -f "$compose_file" down ;;
  restart)
    docker compose -f "$compose_file" restart qbittorrent ;;
  logs)
    docker compose -f "$compose_file" logs -f qbittorrent ;;
  password)
    echo "Checking for temporary password in logs..."
    docker compose -f "$compose_file" logs qbittorrent 2>&1 | grep -i "password" || echo "No password found in logs"
    ;;
  permissions)
    echo "Checking and fixing download directory permissions..."
    DOWNLOADS_PATH=$(grep DOWNLOADS_PATH .env | cut -d= -f2)
    echo "Downloads path: $DOWNLOADS_PATH"
    echo ""
    
    # Check if path exists
    if [ ! -d "$DOWNLOADS_PATH" ]; then
      echo "⚠️  Directory doesn't exist. Creating it..."
      mkdir -p "$DOWNLOADS_PATH" || sudo mkdir -p "$DOWNLOADS_PATH"
    fi
    
    # Check current ownership
    echo "Current ownership:"
    ls -ld "$DOWNLOADS_PATH"
    echo ""
    
    # Get PUID/PGID from .env
    PUID=$(grep "^PUID=" .env | cut -d= -f2)
    PGID=$(grep "^PGID=" .env | cut -d= -f2)
    
    echo "Attempting to fix ownership to ${PUID}:${PGID}..."
    sudo chown -R ${PUID}:${PGID} "$DOWNLOADS_PATH" 2>/dev/null || {
      echo "⚠️  Could not change ownership. This might be a mounted drive."
      echo ""
      echo "For external drives, try:"
      echo "  1. Add to /etc/fstab with uid=${PUID},gid=${PGID} options"
      echo "  2. Or change PUID/PGID in .env to match the drive's owner"
      echo ""
      echo "Current user ID: $(id -u)"
      echo "Current group ID: $(id -g)"
    }
    
    echo ""
    echo "New ownership:"
    ls -ld "$DOWNLOADS_PATH"
    ;;
  pull)
    docker compose -f "$compose_file" pull && docker compose -f "$compose_file" up -d ;;
  *)
    echo "Usage: $0 [up|down|restart|logs|password|permissions|pull]"
    echo ""
    echo "Commands:"
    echo "  up          - Start qBittorrent"
    echo "  down        - Stop qBittorrent"
    echo "  restart     - Restart qBittorrent"
    echo "  logs        - Show logs"
    echo "  password    - Check for temporary password in logs"
    echo "  permissions - Check and fix download directory permissions"
    echo "  pull        - Update image and restart"
    ;;
esac
