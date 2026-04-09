---
name: "Deluge"
category: "🧲 Download Managers"
purpose: "BitTorrent Client"
description: "Feature-rich BitTorrent client with web UI for downloading torrents"
icon: "🧲"
features:
  - "Web-based user interface"
  - "Torrent management and monitoring"
  - "Bandwidth limiting and scheduling"
  - "Plugin support for extended functionality"
resource_usage: "~200MB RAM"
---

# Deluge BitTorrent Client Docker Setup

This Docker Compose setup provides Deluge, a powerful and feature-rich BitTorrent client with a web-based user interface, perfect for your home server torrenting needs.

## Quick Start

### Using the Setup Script (Recommended)

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```
   This will automatically configure Deluge, create necessary directories, and start the service.

### Manual Setup

1. **Start the service:**
   ```bash
   docker compose up -d
   ```

2. **Access the web interface:**
   - Open your browser and navigate to `http://YOUR_HOST_IP:8112`
   - Set up your username and password on first access

## Access Information

- **Web Interface**: http://YOUR_HOST_IP:8112
- **Default Password**: `deluge` (no username required initially)
- **Torrent Ports**: 6881 (TCP/UDP)

## Configuration

### Environment Variables

Edit the `.env` file to customize:
- `DELUGE_WEBUI_PORT` - Port for web interface (default: 8112)
- `DELUGE_TORRENT_PORT` - Port for torrent connections (default: 6881)
- `DELUGE_PASSWORD` - Default password reference (default: deluge) - *Note: Authentication is configured in web UI*
- `DOWNLOADS_PATH` - Path to downloads directory (default: ./downloads)
- `PUID` - User ID for file permissions (default: 1000)
- `PGID` - Group ID for file permissions (default: 1000)
- `TZ` - Timezone setting (default: Etc/UTC)
- `DELUGE_LOGLEVEL` - Logging level (default: error)

### Data Persistence

Data is stored in local directories:
- `./config/` - Deluge configuration, settings, and plugins
- `${DOWNLOADS_PATH:-./downloads}/` - Downloaded files and torrents (configurable via .env)

## First Time Setup

1. Open your browser and navigate to the Deluge web UI
2. **Enter the default password**: `deluge` (no username required)
3. **Change the default password** immediately for security
4. Configure download directories in Preferences → Downloads
5. Set up bandwidth limits in Preferences → Bandwidth
6. Configure network settings and port forwarding if needed

## Useful Commands

```bash
# View logs
docker compose logs -f

# View Deluge logs specifically
docker compose logs -f deluge

# Restart Deluge
docker compose restart

# Update to latest Deluge image
docker compose pull
docker compose up -d

# Access Deluge CLI (if needed)
docker exec deluge deluge-console

# View running containers
docker compose ps
```

## Security Notes

**Important for Production:**
1. Change default credentials after first login
2. Configure proper authentication and user accounts
3. Use strong passwords for web interface
4. Consider enabling SSL/TLS for web access
5. Review firewall settings for torrent ports
6. Monitor disk usage for downloads

## Troubleshooting

### Common Issues

1. **Web interface not accessible**
   - Check if port 8112 is available
   - Verify container is running: `docker compose ps`
   - Check logs: `docker compose logs deluge`

2. **Download issues**
   - Ensure proper permissions on download directory
   - Check available disk space
   - Verify torrent port (6881) is open and forwarded
   - Check if port is blocked by ISP

3. **Permission issues**
   - Verify PUID/PGID match your user
   - Check file permissions on config and downloads directories
   - Ensure Docker can write to volume directories

4. **Container won't start**
   - Check for port conflicts: `netstat -ln | grep :8112`
   - Verify environment file: `cat .env`
   - Try manual start: `docker compose up` (without -d flag)

### Port Forwarding

For optimal torrent performance, ensure port 6881 is forwarded in your router:
- Protocol: TCP and UDP
- External Port: 6881
- Internal IP: Your server's IP
- Internal Port: 6881

### Reset Configuration

To completely reset Deluge:
```bash
docker compose down
sudo rm -rf config downloads
./setup.sh
```

## Advanced Configuration

### Plugins

Deluge supports various plugins for extended functionality:
- **AutoAdd**: Automatically add torrents from watched directories
- **Label**: Organize torrents with labels and categories
- **Scheduler**: Schedule bandwidth limits by time/day
- **Execute**: Run scripts on torrent completion

### Bandwidth Management

Configure bandwidth limits in Preferences → Bandwidth:
- Global download/upload limits
- Per-torrent limits
- Alternative speed limits for specific times

### Watch Directories

Set up automatic torrent adding:
1. Create watch directories on your host
2. Configure in Deluge Preferences → Downloads → Watch Directory
3. Optionally install the AutoAdd plugin for more control

## Monitoring

### Key Metrics to Monitor
- Download/upload speeds
- Active torrent count
- Disk space usage
- Network connectivity

### Log Files
- Deluge logs: Available in web interface or `docker compose logs`
- Configuration: Stored in `./config/`

## Backup and Restore

### Backup Configuration
```bash
# Backup Deluge settings
tar -czf deluge-backup.tar.gz config
```

### Restore Configuration
```bash
# Stop Deluge
docker compose down

# Restore configuration
tar -xzf deluge-backup.tar.gz

# Restart Deluge
docker compose up -d
```

## Integration

### With Other Services
- **File Managers**: Access downloads through file browser services
- **Media Servers**: Automatic organization with Plex/Jellyfin
- **Download Managers**: Integration with tools like Sonarr/Radarr

### API Usage
Deluge provides a JSON-RPC API for automation and third-party tools.

## Performance Tuning

### For High-Speed Downloads
- Ensure sufficient RAM (minimum 1GB recommended)
- Use SSD storage for better I/O performance
- Configure appropriate bandwidth limits
- Monitor CPU usage during downloads

### Storage Optimization
- Use fast storage for downloads directory
- Consider separate disks for config vs downloads
- Regular cleanup of completed torrents