---
name: "Rclone"
category: "📁 File Management & Collaboration"
purpose: "Cloud Storage Sync & Management"
description: "Swiss army knife for cloud storage - sync, backup, mount 70+ cloud providers"
icon: "🔄"
features:
  - "70+ cloud storage providers support"
  - "Mount cloud storage as local filesystem"
  - "Serve files via HTTP/WebDAV/FTP"
  - "Sync, backup, and migrate data"
resource_usage: "~50MB RAM"
---

# Rclone - Docker Setup

Rclone is a command-line program to manage files on cloud storage. It's the "Swiss army knife of cloud storage" with support for over 70 cloud storage providers.

## Features
- **Multi-Provider Support** - Google Drive, Dropbox, S3, OneDrive, and 70+ others
- **Mount Support** - Mount cloud storage as local filesystem
- **Serve Capabilities** - HTTP, WebDAV, FTP, SFTP server modes
- **Sync & Backup** - Powerful sync, copy, move, and backup operations
- **Encryption** - Built-in encryption for cloud data
- **Resume Support** - Resume interrupted transfers
- **Bandwidth Control** - Throttling and scheduling

## Prerequisites
- Docker and Docker Compose installed
- Cloud storage account(s) to configure
- Sufficient local storage for caching (optional)

## Quick Start

### Using the Setup Script (Recommended)

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```
   This will automatically configure Rclone, create necessary directories, and start the service.

### Manual Setup

1. **Prepare directories:**
   ```bash
   mkdir -p config data
   ```

2. **Configure environment (optional):**
   ```bash
   cp .env.example .env
   # Edit .env as needed
   ```

3. **Start the service:**
   ```bash
   docker compose up -d
   ```

4. **Configure cloud remotes:**
   ```bash
   docker exec -it rclone rclone config
   ```

## Access Information

- **Container Access**: `docker exec -it rclone sh`
- **HTTP Server**: http://YOUR_HOST_IP:5572 (if enabled)
- **WebDAV Server**: http://YOUR_HOST_IP:5573 (if enabled)

## Configuration

### Environment Variables

Edit the `.env` file to customize:
- `HTTP_PORT` - Port for HTTP serve mode (default: 5572)
- `WEBDAV_PORT` - Port for WebDAV serve mode (default: 5573)
- `FTP_PORT` - Port for FTP serve mode (default: 2121)
- `PUID/PGID` - User/group IDs for file permissions
- `CONFIG_PATH` - Path for rclone configuration
- `DATA_PATH` - Path for local data storage

### Cloud Provider Setup

Configure your cloud storage remotes:
```bash
# Interactive configuration
docker exec -it rclone rclone config

# List configured remotes
docker exec rclone rclone listremotes

# Test a remote connection
docker exec rclone rclone lsd remote:
```

## Common Operations

### File Operations
```bash
# Copy files to cloud
docker exec rclone rclone copy /data/files remote:backup

# Sync directories (one-way)
docker exec rclone rclone sync /data remote:backup

# Two-way sync (bidirectional)
docker exec rclone rclone bisync /data remote:backup

# Move files
docker exec rclone rclone move /data/old remote:archive

# Check file integrity
docker exec rclone rclone check /data remote:backup
```

### Serve Operations
```bash
# Serve files via HTTP
docker exec -d rclone rclone serve http /data --addr :5572

# Serve files via WebDAV
docker exec -d rclone rclone serve webdav /data --addr :5573

# Serve files via FTP
docker exec -d rclone rclone serve ftp /data --addr :2121
```

### Mount Operations
```bash
# Mount cloud storage (requires privileged mode)
docker exec -d rclone rclone mount remote: /mnt/cloud

# Mount with caching
docker exec -d rclone rclone mount remote: /mnt/cloud --vfs-cache-mode writes
```

## Data Persistence

- **Configuration**: Stored in `./config` directory (rclone.conf and tokens)
- **Local Data**: Stored in `./data` directory for local operations

## Useful Commands

```bash
# View logs
docker compose logs -f

# Access shell
docker exec -it rclone sh

# Restart service
docker compose restart

# Update to latest image
docker compose pull && docker compose up -d

# Stop service
docker compose down
```

## Troubleshooting

1. **Permission issues:** Ensure PUID/PGID match your host user
2. **Mount failures:** Check if container has necessary capabilities and devices
3. **Network issues:** Verify DNS settings and cloud provider connectivity
4. **Authentication errors:** Reconfigure remotes with `rclone config`

## Volumes

- `./config` - Rclone configuration and credentials
- `./data` - Local data directory for operations

## Help & Resources

- [Rclone Official Website](https://rclone.org/)
- [Rclone Documentation](https://rclone.org/docs/)
- [Rclone GitHub Repository](https://github.com/rclone/rclone)
- [Docker Image](https://hub.docker.com/r/rclone/rclone)
- [Supported Cloud Providers](https://rclone.org/#providers)