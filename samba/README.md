---
name: "Samba"
category: "📁 File Management & Collaboration"
purpose: "Network File Sharing"
description: "SMB/CIFS file sharing server for Windows, macOS, and Linux network access"
icon: "🗂️"
features:
  - "Windows/Mac/Linux file sharing"
  - "Guest and authenticated access"
  - "Configurable shares via smb.conf"
resource_usage: "~50MB RAM"
---

# Samba Server - Docker Setup

Samba provides SMB/CIFS file sharing, allowing you to access files on your Raspberry Pi from Windows, macOS, and Linux devices on your network. This setup uses a configuration file-driven approach for easy customization.

## Features
- **Cross-platform** - Works with Windows, macOS, and Linux
- **Config-driven shares** - Define shares in `smb.conf`
- **Guest access** - Optional public shares without authentication
- **User management** - Add/remove Samba users via script
- **Apple compatibility** - Optimized for macOS with Fruit VFS

## Prerequisites
- Docker and Docker Compose installed
- Ports 445 and 139 available (not used by host Samba)

## Quick Start

1. **Run setup:**
   ```bash
   ./setup.sh
   ```

2. **Add a user:**
   ```bash
   ./setup.sh adduser pi
   ```

3. **Connect from your device:**
   - **Windows**: Open File Explorer, type `\\YOUR_PI_IP\`
   - **macOS**: Finder → Go → Connect to Server → `smb://YOUR_PI_IP/`
   - **Linux**: File manager → Connect to Server → `smb://YOUR_PI_IP/`

## Default Shares

| Share | Path | Access |
|-------|------|--------|
| Public | `/home/pi/shared` | Guest read/write |
| Media | `/home/pi/media` | Guest read, users write |
| Documents | `/home/pi/documents` | Authenticated only |

## Configuration

### Customizing Shares

Edit `smb.conf` to add or modify shares:

```ini
[MyShare]
    comment = My Custom Share
    path = /shares/myshare
    browseable = yes
    read only = no
    guest ok = no
    valid users = @users
```

Then add the volume mount in `docker-compose.yml`:
```yaml
volumes:
  - /home/pi/myshare:/shares/myshare
```

Restart to apply:
```bash
./setup.sh restart
```

### Environment Variables

Edit `.env` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `CONTAINER_NAME` | samba | Container name |
| `SMB_PORT` | 445 | SMB port |
| `SHARE_PATH_1` | /home/pi/shared | Public share path |
| `SHARE_PATH_2` | /home/pi/media | Media share path |
| `SHARE_PATH_3` | /home/pi/documents | Documents share path |
| `PUID/PGID` | 1000 | User/Group ID |

## User Management

```bash
# Add a new Samba user
./setup.sh adduser username

# Change user password
./setup.sh passwd username

# List all Samba users
./setup.sh listusers
```

## Management Commands

```bash
./setup.sh start      # Start server
./setup.sh stop       # Stop server
./setup.sh restart    # Restart server
./setup.sh logs       # View logs
./setup.sh status     # Check status
./setup.sh test       # Test connectivity
```

## Connecting from Clients

### Windows
1. Open File Explorer
2. Type `\\YOUR_PI_IP\` in address bar
3. Enter credentials if prompted

### macOS
1. Open Finder
2. Press `Cmd+K`
3. Enter `smb://YOUR_PI_IP/`
4. Select share and enter credentials

### Linux (GUI)
1. Open file manager
2. Connect to Server: `smb://YOUR_PI_IP/`

### Linux (CLI)
```bash
# Mount a share
sudo mount -t cifs //YOUR_PI_IP/Public /mnt/samba -o guest

# With credentials
sudo mount -t cifs //YOUR_PI_IP/Documents /mnt/samba -o username=pi,password=yourpass
```

## Security Notes

1. **Change default workgroup** if needed in `smb.conf`
2. **Use strong passwords** for Samba users
3. **Limit guest access** to non-sensitive directories
4. **Use firewall** to restrict access to trusted networks

## Troubleshooting

### Cannot connect from Windows
```bash
# Check if SMB1 is needed (older Windows)
# In smb.conf, add under [global]:
server min protocol = NT1
```

### Permission denied
```bash
# Ensure share directory permissions
chmod 775 /home/pi/shared
chown pi:pi /home/pi/shared
```

### Port already in use
```bash
# Check if host Samba is running
sudo systemctl stop smbd
sudo systemctl disable smbd
```

### Test connectivity
```bash
./setup.sh test
```

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Container configuration |
| `smb.conf` | **Main Samba configuration** |
| `.env` | Environment variables |
| `setup.sh` | Management script |

## Links
- [Samba Documentation](https://www.samba.org/samba/docs/)
- [Docker Image](https://hub.docker.com/r/dperson/samba)
- [SMB Protocol](https://docs.microsoft.com/en-us/windows/win32/fileio/microsoft-smb-protocol-and-cifs-protocol-overview)
