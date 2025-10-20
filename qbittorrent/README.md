---
name: "qBittorrent"
category: "🎬 Media & Entertainment"
purpose: "BitTorrent Client"
description: "Lightweight and powerful BitTorrent client with web interface for downloading torrents"
icon: "📥"
features:
  - "Web-based UI for remote access"
  - "Sequential downloading support"
  - "RSS feed support and automation"
resource_usage: "~500MB RAM"
---

# qBittorrent - Docker Setup

qBittorrent is a free and open-source BitTorrent client with a feature-rich web interface. Perfect for managing torrent downloads remotely on your Raspberry Pi.

## Features
- **Web UI** - Access from any device on your network
- **Sequential Download** - Download files in order (useful for media)
- **RSS Automation** - Auto-download from RSS feeds
- **Search Integration** - Built-in torrent search
- **Bandwidth Control** - Speed limits and scheduling
- **Categories & Tags** - Organize your downloads
- **IP Filtering** - Block unwanted peers

## Prerequisites
- Docker and Docker Compose installed
- Sufficient storage for downloads
- Optional: VPN for privacy

## Quick Start

1. Prepare directories
```bash
mkdir -p config downloads
```

2. Configure environment (optional)
```bash
cat > .env <<'EOF'
QBT_VERSION=latest
CONTAINER_NAME=qbittorrent
RESTART_POLICY=unless-stopped

# Ports
QBT_WEBUI_PORT=8080
QBT_TORRENTING_PORT=6881

# User configuration
PUID=1000
PGID=1000
TIMEZONE=UTC
UMASK=022

# Legal notice (required)
QBT_LEGAL_NOTICE=confirm

# Paths
DOWNLOADS_PATH=./downloads

# Resource limits
MEMORY_LIMIT=1G
MEMORY_RESERVATION=256M
EOF
```

3. Launch
```bash
./setup.sh up
```

4. Access & Login
- Web: http://<your-server-ip>:8080
- **Default credentials (qBittorrent < 4.6.1):**
  - Username: `admin`
  - Password: `adminadmin`
- **For qBittorrent ≥ 4.6.1:**
  - Username: `admin`
  - Password: **Temporary password printed in logs**
  - Check logs: `docker compose logs qbittorrent | grep "temporary password"`

⚠️ **Change the password immediately after first login!**

## Configuration

### Legal Notice
You MUST set `QBT_LEGAL_NOTICE=confirm` to acknowledge qBittorrent's legal notice about using the software responsibly and not for illegal purposes.

### Downloads Directory
By default, downloads go to `./downloads`. You can change this:
```bash
# In .env
DOWNLOADS_PATH=/mnt/external/downloads
```

### Port Configuration
- **WebUI Port (8080)** - Access the web interface
- **Torrenting Port (6881)** - BitTorrent traffic (TCP & UDP)

### User Permissions
qBittorrent runs as PUID/PGID (default 1000:1000). Ensure downloads directory is writable:
```bash
sudo chown -R 1000:1000 ./downloads
```

## First-Time Setup

### 1. Get Initial Password (qBittorrent ≥ 4.6.1)
```bash
# Check logs for temporary password
docker compose logs qbittorrent | grep "temporary password"

# Or watch logs as it starts
docker compose logs -f qbittorrent
```

### 2. Change Password
1. Login to WebUI: http://<server-ip>:8080
2. Go to: Tools → Options → Web UI tab
3. Change password under Authentication section
4. Click Save

### 3. Configure Downloads
1. Go to: Tools → Options → Downloads tab
2. Set default save path: `/downloads`
3. Configure download limits if needed
4. Enable "Pre-allocate disk space" for better performance

### 4. Set Connection Limits
1. Go to: Tools → Options → Connection tab
2. Listening Port: Should match `QBT_TORRENTING_PORT` (6881)
3. Adjust connection limits based on your needs

## Usage Tips

### Sequential Downloading (for media)
- Right-click torrent → "Download in sequential order"
- Useful for streaming while downloading

### RSS Automation
1. View → RSS Reader
2. Add RSS feed
3. Set up download rules
4. Auto-download matching torrents

### Categories
- Right-click in torrent list → Categories → Add category
- Organize downloads by type (Movies, TV, Music, etc.)
- Set different save paths per category

### Speed Limits
1. Tools → Options → Speed tab
2. Set global download/upload limits
3. Or use Alternative Speed Limits (tortoise icon)
4. Schedule automatic speed changes

## Management Commands

```bash
# Start qBittorrent
docker compose up -d

# Stop qBittorrent
docker compose down

# View logs (including temporary password)
docker compose logs -f qbittorrent

# Update to latest version
docker compose pull && docker compose up -d

# Restart
docker compose restart qbittorrent

# Shell access
docker compose exec qbittorrent /bin/sh

# Check temporary password
docker compose logs qbittorrent 2>&1 | grep -i "password"
```

## Data Persistence
- `./config/` - qBittorrent configuration and state
- `./downloads/` - Downloaded files
- Configuration file: `./config/qBittorrent/qBittorrent.conf`

## Advanced Configuration

### Custom Configuration File
Edit `./config/qBittorrent/qBittorrent.conf` directly for advanced settings.

Example useful settings:
```ini
[BitTorrent]
Session\DefaultSavePath=/downloads
Session\Port=6881
Session\QueueingSystemEnabled=true
Session\MaxActiveDownloads=3
Session\MaxActiveTorrents=5

[Preferences]
WebUI\Port=8080
WebUI\Username=admin
Downloads\PreAllocation=true
```

### VPN Integration
To route qBittorrent through VPN:

1. Use a VPN container (like gluetun)
2. Set qBittorrent to use VPN's network:
```yaml
services:
  qbittorrent:
    network_mode: "container:vpn"
```

### IP Filtering
1. Download IP filter list (e.g., from iblocklist.com)
2. Tools → Options → Connection tab
3. Enable IP Filtering
4. Load filter file

## Troubleshooting

### Cannot Access WebUI
```bash
# Check if container is running
docker compose ps

# Check logs
docker compose logs qbittorrent

# Verify port
curl http://localhost:8080
```

### Forgot Password
```bash
# Stop container
docker compose down

# Edit config file
nano ./config/qBittorrent/qBittorrent.conf

# Remove or reset these lines:
# WebUI\Password_PBKDF2=...
# Or set a known hash

# Restart
docker compose up -d
```

### Permission Denied on Downloads
```bash
# Fix ownership
sudo chown -R 1000:1000 ./downloads

# Or change PUID/PGID in .env to match your user
id  # Shows your UID/GID
```

### Slow Download Speeds
1. Check global speed limits: Tools → Options → Speed
2. Disable alternative speed limits (tortoise icon)
3. Increase connection limits: Tools → Options → Connection
4. Forward torrenting port in router (port 6881)

### Port Forwarding
For better connectivity, forward port 6881 (TCP & UDP) in your router to your Pi's IP address.

## Security Considerations

### Change Default Password
Always change the default password immediately after first login!

### Use VPN
Consider using a VPN for privacy when torrenting.

### IP Filtering
Enable IP filtering to block known malicious peers.

### WebUI Access
- Restrict WebUI to local network only
- Or use authentication + HTTPS
- Consider using behind nginx reverse proxy

### Firewall Rules
```bash
# Allow WebUI (local network only)
sudo ufw allow from 192.168.0.0/24 to any port 8080

# Allow torrenting port
sudo ufw allow 6881/tcp
sudo ufw allow 6881/udp
```

## Backup & Restore

### Backup Configuration
```bash
# Backup config directory
tar -czf qbittorrent-config-backup.tar.gz ./config

# Or use setup script
./setup.sh backup
```

### Restore Configuration
```bash
# Stop container
docker compose down

# Restore config
tar -xzf qbittorrent-config-backup.tar.gz

# Restart
docker compose up -d
```

## Links
- Official Site: https://www.qbittorrent.org/
- GitHub: https://github.com/qbittorrent/qBittorrent
- Docker Image: https://github.com/qbittorrent/docker-qbittorrent-nox
- Wiki: https://github.com/qbittorrent/qBittorrent/wiki
- Forum: https://qbforums.shiki.hu/
