#!/usr/bin/env bash
set -euo pipefail

# Simple runner to mirror other services
compose_file=${COMPOSE_FILE:-docker-compose.yml}

if ! command -v docker &>/dev/null; then
  echo "Docker is required" >&2
  exit 1
fi
if ! command -v docker compose &>/dev/null; then
  echo "Docker Compose V2 is required (docker compose)" >&2
  exit 1
fi

mkdir -p config cache media || true

case "${1:-up}" in
  up)
    docker compose -f "$compose_file" up -d ;;
  down)
    docker compose -f "$compose_file" down ;;
  restart)
    docker compose -f "$compose_file" restart jellyfin ;;
  logs)
    docker compose -f "$compose_file" logs -f jellyfin ;;
  pull)
    docker compose -f "$compose_file" pull && docker compose -f "$compose_file" up -d ;;
  *)
    echo "Usage: $0 [up|down|restart|logs|pull]" ;;
 esac
