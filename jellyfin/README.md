---
name: "Jellyfin"
category: "🎬 Media & Entertainment"
purpose: "Self-hosted Media Server"
description: "Free software media system that puts you in control of managing and streaming your media."
icon: "🎬"
features:
  - "Stream movies, TV, music, and photos"
  - "Multi-user with permissions"
  - "Hardware acceleration support"
resource_usage: "~1GB RAM"
---

# Jellyfin - Docker Setup

Jellyfin is a free software media system that lets you control how and where your media is served. This setup follows the same conventions as other services in this repo.

## Features
- Stream personal media to any device
- User management and parental controls
- Hardware transcoding support where available
- DLNA and auto-discovery support

## Prerequisites
- Docker and Docker Compose installed
- Storage for media files
- Optional hardware acceleration support (e.g., /dev/dri)

## Quick Start

1. Prepare directories
```bash
mkdir -p config cache media/{movies,tv,music,photos}
```

2. (Optional) Configure environment
```bash
# Create .env with custom overrides
cat > .env <<'EOF'
JELLYFIN_TAG=latest
CONTAINER_NAME=jellyfin
RESTART_POLICY=unless-stopped
NETWORK_MODE=bridge
JELLYFIN_HTTP_PORT=8096
JELLYFIN_HTTPS_PORT=8920
TIMEZONE=UTC
PUID=1000
PGID=1000
MEDIA_PATH=./media
PUBLISHED_SERVER_URL=
MEMORY_LIMIT=2G
MEMORY_RESERVATION=256M
EOF
```

3. Launch
```bash
./setup.sh
```

4. Access
- Web: http://<your-server-ip>:8096 (host networking by default)
- HTTPS (if enabled in app): https://<your-server-ip>:8920

## Volumes
- `./config` - Jellyfin configuration and database
- `./cache` - Transcoding and image cache
- `./media` - Your media library

## Hardware Acceleration
If your host supports it, leave the `/dev/dri` mapping enabled. On Raspberry Pi, you may need V4L2 devices:
```yaml
devices:
  - /dev/dri:/dev/dri
  # - /dev/video10:/dev/video10
  # - /dev/video11:/dev/video11
  # - /dev/video12:/dev/video12
```
Enable hardware acceleration in Dashboard > Playback.

## Management Commands
```bash
# Start
docker compose up -d
# Stop
docker compose down
# Logs
docker compose logs -f jellyfin
# Update
docker compose pull && docker compose up -d
# Shell
docker compose exec jellyfin /bin/bash
```

Tip: If you see permission errors accessing media, ensure the media files are owned by PUID:PGID configured (default 1000:1000), or adjust with chown.

## Troubleshooting
- Check container status: `docker compose ps`
- Fix permissions: `sudo chown -R 1000:1000 ./config ./cache ./media`
- Clear cache if issues: `rm -rf ./cache/*`

## Links
- Docs: https://jellyfin.org/docs
- Docker: https://jellyfin.org/downloads/docker
- Image: https://hub.docker.com/r/jellyfin/jellyfin
