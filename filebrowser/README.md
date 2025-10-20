---
name: "FileBrowser"
category: "📁 File Management & Collaboration"
purpose: "Web-based File Manager"
description: "Web file browser with a simple and intuitive interface to manage files on your server"
icon: "📂"
features:
  - "Browse and manage server files"
  - "Upload/download files via web"
  - "Create, edit, and delete files"
resource_usage: "~100MB RAM"
---

# FileBrowser - Docker Setup

FileBrowser provides a web-based interface to browse, upload, download, and manage files on your Raspberry Pi server. Perfect for accessing your server files from any device on your network.

## Features
- **Web-based interface** - Access files from any browser
- **User management** - Multiple users with permissions
- **File operations** - Upload, download, create, edit, delete
- **Sharing** - Generate shareable links for files
- **Search** - Quick file search functionality
- **Cross-platform** - Works on any device with a browser

## Prerequisites
- Docker and Docker Compose installed
- Proper file permissions on directories you want to browse

## Quick Start

1. Prepare directories
```bash
mkdir -p config database
```

2. Configure environment (optional)
```bash
cat > .env <<'EOF'
FILEBROWSER_TAG=s6
CONTAINER_NAME=filebrowser
RESTART_POLICY=unless-stopped
FILEBROWSER_PORT=8080
TIMEZONE=UTC
PUID=1000
PGID=1000
# Root directory to browse (default: /home/pi)
SRV_PATH=/home/pi
MEMORY_LIMIT=256M
MEMORY_RESERVATION=64M
EOF
```

3. Launch
```bash
./setup.sh up
```

4. Access & Login
- Web: http://<your-server-ip>:8080
- **First-time credentials:**
  - Username: `admin`
  - Password: **Randomly generated** (shown in setup script output and container logs)
  - Check logs: `docker compose logs filebrowser | grep "randomly generated password"`
  - ⚠️ **Password is only shown once - change immediately after login!**

## Configuration

### Browsing Different Directories
By default, FileBrowser browses `/home/pi`. To change this:

1. Edit `.env`:
```bash
SRV_PATH=/path/to/browse
```

2. Restart:
```bash
./setup.sh restart
```

### Adding Additional Directories
Edit `docker-compose.yml` to mount additional paths:
```yaml
volumes:
  - /mnt/external:/mnt/external:ro  # Read-only external drive
  - /var/log:/logs:ro  # System logs (read-only)
```

### File Permissions
FileBrowser runs as PUID/PGID (default 1000:1000). Ensure files are accessible:
```bash
# Check ownership
ls -la /home/pi

# Fix if needed
sudo chown -R 1000:1000 /home/pi/your-directory
```

## Security Recommendations

### Change Default Password
1. Login with `admin`/`admin`
2. Go to **Settings** > **User Management**
3. Edit admin user and change password

### Create Additional Users
1. Go to **Settings** > **User Management**
2. Click **New User**
3. Set username, password, and permissions
4. Assign scope (directory access)

### Use Read-Only Mounts
For sensitive directories, mount as read-only:
```yaml
- /etc:/etc:ro
- /var/log:/logs:ro
```

## Management Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Logs
docker compose logs -f filebrowser

# Update
docker compose pull && docker compose up -d

# Restart
docker compose restart filebrowser

# Shell access
docker compose exec filebrowser /bin/sh
```

## Common Use Cases

### Media Library Access
Browse your media files:
```bash
SRV_PATH=/home/pi/media
```

### Server Administration
Access entire filesystem (use with caution):
```bash
SRV_PATH=/
```

### Project Files Only
Limit to specific project:
```bash
SRV_PATH=/home/pi/projects
```

## Data Persistence
- `./config/` - FileBrowser configuration (settings.json)
- `./database/` - User database (filebrowser.db)

## Volumes
All file operations happen on the mounted `/srv` directory, which maps to `SRV_PATH` from your `.env` file.

## Troubleshooting

### Cannot Access Files
```bash
# Check container is running
docker compose ps

# Check logs
docker compose logs filebrowser

# Verify permissions
ls -la $(grep SRV_PATH .env | cut -d= -f2)
```

### Permission Denied Errors
```bash
# Fix ownership
sudo chown -R 1000:1000 /path/to/directory

# Or add user to specific group
sudo usermod -aG docker pi
```

### Forgot Admin Password
```bash
# Stop container
docker compose down

# Remove database (resets to default admin with NEW random password)
rm -f ./database/filebrowser.db

# Start again and check logs for new password
docker compose up -d
docker compose logs filebrowser | grep "randomly generated password"
```

## Advanced Configuration

### Custom Settings
FileBrowser settings are stored in `./config/settings.json`. You can customize:
- Branding
- Authentication method
- Command execution permissions
- File preview settings

Edit manually or use the web interface Settings page.

### Reverse Proxy
For external access, use nginx or Traefik:
```nginx
location /files/ {
    proxy_pass http://localhost:8080/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

## Links
- Docs: https://filebrowser.org
- GitHub: https://github.com/filebrowser/filebrowser
- Docker Hub: https://hub.docker.com/r/filebrowser/filebrowser
- Configuration: https://filebrowser.org/configuration
