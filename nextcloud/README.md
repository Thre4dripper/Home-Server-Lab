---
name: "Nextcloud"
category: "☁️ Cloud Storage & Collaboration"
purpose: "Self-hosted file sync and share"
description: "Complete self-hosted cloud storage solution with file sharing, collaboration, and productivity apps"
icon: "☁️"
features:
  - "File sync and sharing"
  - "Calendar and contacts"
  - "Office document editing"
  - "Photo gallery"
  - "Video streaming"
  - "End-to-end encryption"
resource_usage: "~1-2GB RAM (scales with usage)"
---

# Nextcloud All-in-One Docker Setup

This Docker Compose setup provides Nextcloud All-in-One (AIO), a complete self-hosted cloud storage solution with all components pre-configured and orchestrated automatically.

## Quick Start

### Prerequisites

**Domain Name Required** ⚠️
Nextcloud AIO requires a domain name for SSL certificates and proper functionality.

1. **Choose a domain** (e.g., `nextcloud.yourdomain.com`)
2. **Configure DNS** to point to your server IP
3. **Update Pi-hole** with the domain entry
4. **Set up nginx** reverse proxy (optional for external access)

### Using the Setup Script (Recommended)

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the `.env` file:**
   ```bash
   nano .env
   ```
   Set your domain and external storage path.

3. **Run the setup script:**
   ```bash
   ./setup.sh
   ```

### Manual Setup

1. **Edit the `.env` file:**
   ```bash
   NEXTCLOUD_DOMAIN=nextcloud.yourdomain.com
   ```

2. **Start the service:**
   ```bash
   docker compose up -d
   ```

## Access Information

- **AIO Management Interface**: https://YOUR_HOST_IP:8443
- **Nextcloud Application**: https://YOUR_DOMAIN (after initial setup)
- **Admin Interface**: https://YOUR_DOMAIN/login

## Configuration

### File Structure

- **`docker-compose.yml`** - Docker Compose configuration with bind mounts
- **`.env`** - Environment variables (copy from `.env.example`)
- **`.env.example`** - Template with placeholder values
- **`.gitignore`** - Git ignore rules for sensitive data
- **`setup.sh`** - Automated setup and configuration script
- **`README.md`** - This documentation file

### Environment Variables

Edit the `.env` file to customize:

- `NEXTCLOUD_DOMAIN` - **Required**: Your domain name for SSL certificates
- `PI_IP` - Server IP (auto-detected by setup script)
- `TZ` - Timezone setting
- `EXTERNAL_STORAGE_PATH` - Path to external storage (e.g., `/home/pi/pendrive`)
- `NEXTCLOUD_UPLOAD_LIMIT` - Maximum upload size (default: 16G)
- `NEXTCLOUD_MEMORY_LIMIT` - PHP memory limit (default: 512M)
- `NEXTCLOUD_MAX_TIME` - PHP max execution time (default: 3600)

### Domain Setup

Nextcloud AIO requires a domain for SSL certificates. Here's how to set it up:

#### 1. DNS Configuration
Add your domain to Pi-hole's local DNS:
```bash
# Edit dns-entries.conf in pihole directory
nextcloud.yourdomain.com=YOUR_SERVER_IP
```

#### 2. Nginx Reverse Proxy (Optional)
For external access with SSL termination, configure nginx:

```nginx
server {
    listen 80;
    server_name nextcloud.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name nextcloud.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass https://127.0.0.1:443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Initial Setup Process

1. **Access AIO Interface**: Open https://YOUR_IP:8443
2. **Accept Security Warning**: Click "Advanced" → "Accept the risk"
3. **Enter Domain**: Input your configured domain
4. **Create Admin Account**: Set username and password
5. **Wait for Setup**: AIO will create all required containers (takes 5-10 minutes)
6. **Access Nextcloud**: Use https://YOUR_DOMAIN

## Data Persistence

Data is stored using a combination of named volumes and bind mounts:
- `nextcloud_aio_mastercontainer` - **Named Docker volume** (required for AIO backup functionality)
- `${EXTERNAL_STORAGE_PATH}` - External storage mount for additional data
- Additional containers created by AIO use their own volumes

## Security Notes

**Important for Production:**
1. Use a strong admin password
2. Enable 2FA for admin accounts
3. Regularly update Nextcloud: `docker compose pull && docker compose up -d`
4. Configure firewall rules (only allow HTTPS access)
5. Enable brute force protection
6. Use end-to-end encryption for sensitive files

## Useful Commands

```bash
# View all AIO logs
docker compose logs -f

# View specific container logs
docker logs nextcloud-aio-nextcloud

# Restart AIO mastercontainer
docker compose restart

# Update to latest AIO image
docker compose pull
docker compose up -d

# Stop all Nextcloud services
docker compose down

# Access AIO mastercontainer CLI
docker exec -it nextcloud-aio-mastercontainer bash

# Backup AIO (built-in feature)
# Access via AIO interface: https://YOUR_IP:8443
```

## Apps and Features

Nextcloud AIO includes many pre-configured apps:

### Core Features
- **Files**: File storage and synchronization
- **Calendar**: Personal and shared calendars
- **Contacts**: Address book management
- **Notes**: Simple note-taking
- **Tasks**: Todo list management
- **Deck**: Kanban-style project management

### Office Suite
- **Collabora Online**: Office document editing
- **OnlyOffice**: Alternative office suite integration

### Communication
- **Talk**: Video conferencing and chat
- **Mail**: Email client integration

### Media
- **Photos**: Gallery and photo management
- **Music**: Audio streaming
- **Memories**: Advanced photo features

### Productivity
- **Forms**: Survey and form creation
- **Polls**: Voting and decision making
- **Bookmarks**: Link collection and sharing

## Performance Tuning

### For Raspberry Pi Optimization
- Start with minimal apps enabled
- Monitor memory usage
- Use external storage for large file libraries
- Consider SSD storage for better performance

### Memory Configuration
Adjust PHP memory limits in `.env`:
```bash
NEXTCLOUD_MEMORY_LIMIT=1G    # Increase for better performance
NEXTCLOUD_UPLOAD_LIMIT=10G   # Adjust based on your needs
```

### Background Jobs
Configure cron jobs for better performance:
```bash
# Add to crontab (run as www-data user)
*/5 * * * * docker exec -u www-data nextcloud-aio-nextcloud php cron.php
```

## Backup and Restore

Nextcloud AIO includes built-in backup functionality:

1. **Access AIO Interface**: https://YOUR_IP:8443
2. **Go to Backup Section**: Configure backup settings
3. **Choose Storage**: Local, SMB, or cloud storage
4. **Schedule Backups**: Set automatic backup intervals

### Manual Backup
```bash
# Stop containers before backup
docker compose down

# Backup named volume (mastercontainer config)
docker run --rm -v nextcloud_aio_mastercontainer:/source -v $(pwd):/backup alpine tar czf /backup/mastercontainer-backup-$(date +%Y%m%d).tar.gz -C /source .

# Backup external storage if needed
# tar -czf external-storage-backup-$(date +%Y%m%d).tar.gz $EXTERNAL_STORAGE_PATH/

# Restart containers
docker compose up -d
```

## Troubleshooting

### Common Issues

1. **AIO Interface Not Accessible**
   - Check if port 8443 is available
   - Verify container is running: `docker compose ps`
   - Check logs: `docker compose logs nextcloud-aio-mastercontainer`

2. **SSL Certificate Issues**
   - Ensure domain resolves correctly
   - Wait for Let's Encrypt certificate generation (can take time)
   - Check domain validation in AIO logs

3. **Slow Performance**
   - Check Raspberry Pi resource usage
   - Reduce enabled apps
   - Use external storage for large files
   - Enable caching and optimization

4. **Container Creation Fails**
   - Check Docker resource limits
   - Ensure sufficient disk space
   - Verify Docker socket permissions

5. **Domain Validation Errors**
   - Confirm DNS points to correct IP
   - Check firewall settings
   - Ensure ports 80/443 are accessible

### Port Conflicts

If you need to change ports, edit `compose.yaml`:
```yaml
ports:
  - "8080:80"      # HTTP port
  - "8443:8080"    # AIO interface port
  - "8444:8443"    # HTTPS port
```

### Reset AIO Setup

To completely reset Nextcloud AIO:
```bash
# Stop and remove all containers
docker compose down

# Remove named volume (WARNING: This deletes all AIO configuration!)
docker volume rm nextcloud_aio_mastercontainer

# Clean up any remaining containers
docker system prune

# Restart setup
./setup.sh
```

## Monitoring

### Key Metrics to Monitor
- Container resource usage (CPU, memory, disk)
- Nextcloud log files for errors
- SSL certificate expiration
- Backup status and success

### Log Files
- AIO logs: `docker compose logs nextcloud-aio-mastercontainer`
- Nextcloud logs: Available in Nextcloud admin interface
- Apache logs: `docker logs nextcloud-aio-apache`

## Integration

### With Other Services
- **Pi-hole**: Local DNS resolution for domain access
- **Nginx**: Reverse proxy for external access
- **Portainer**: Container management interface
- **Netdata**: System monitoring and alerts

### API Usage
Nextcloud provides REST APIs for automation:
```bash
# List users (requires admin auth)
curl -u admin:password https://YOUR_DOMAIN/ocs/v1.php/cloud/users

# Upload file via API
curl -u username:password -T file.txt https://YOUR_DOMAIN/remote.php/dav/files/username/
```

## Advanced Configuration

### Custom Apps Installation
Additional apps can be installed via the Nextcloud interface or manually:

1. **Via Web Interface**: Apps → Browse apps
2. **Manual Installation**: Upload .tar.gz files to `/var/www/html/custom_apps/`

### External Storage
Configure external storage in Nextcloud settings:
- Local directories
- SMB/CIFS shares
- FTP/SFTP servers
- S3-compatible storage
- WebDAV servers

### LDAP Integration
Connect Nextcloud to LDAP/AD for user management:
1. Install "LDAP user and group backend" app
2. Configure LDAP server settings
3. Map user attributes
4. Test authentication

## Updates

Nextcloud AIO handles updates automatically:

1. **Check for Updates**: AIO interface shows available updates
2. **Backup First**: Always backup before updating
3. **Apply Updates**: Click update in AIO interface
4. **Monitor Process**: Updates can take several minutes

### Manual Updates
```bash
# Update AIO image
docker compose pull

# Restart with new image
docker compose up -d
```

## Support

- **Official Documentation**: https://github.com/nextcloud/all-in-one
- **Community Forum**: https://help.nextcloud.com
- **GitHub Issues**: https://github.com/nextcloud/all-in-one/issues
- **Configuration Help**: Check AIO interface logs and documentation

## Raspberry Pi Specific Notes

- **Memory**: Monitor RAM usage, especially with many users
- **Storage**: Use external USB drives for large file storage
- **Cooling**: Ensure proper ventilation for sustained performance
- **Power Supply**: Use adequate power supply to prevent crashes
- **Network**: Gigabit Ethernet recommended for file transfers</content>
<parameter name="filePath">/home/pi/Home-Server-Lab/nextcloud/README.md