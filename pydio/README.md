---
name: "Pydio"
category: "📁 File Management & Collaboration"
purpose: "File Management Platform"
description: "Modern file sharing platform with team collaboration and external storage support"
icon: "📁"
features:
  - "Web-based file management"
  - "Team collaboration tools"
  - "External storage integration"
resource_usage: "~400MB RAM"
---

# Pydio Cells File Sharing Docker Setup

This Docker Compose setup provides Pydio Cells file sharing platform with MySQL database backend and external storage support. Configuration is managed entirely through environment variables.

## Quick Start

### Using the Setup Script (Recommended)

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```
   This will automatically configure Pydio Cells, set up the database, and verify the installation.

### Manual Setup

1. **Start the services:**
   ```bash
   docker compose up -d
   ```

2. **Access Pydio:**
   - URL: https://YOUR_HOST_IP:8080
   - Accept the self-signed certificate
   - Login with configured credentials

## 🌐 Access Information

Once setup is complete, Pydio Cells will be available at:
- **Web Interface**: http://your-ip:8081
- **Username**: admin
- **Password**: admin123

**Note**: This configuration uses HTTP only. For production use, configure HTTPS with Nginx and Let's Encrypt as needed.
- **Database**: MySQL on internal Docker network

## Configuration

All configuration is managed through environment variables in the `.env` file. No separate configuration files are needed.

### Environment Variables

Edit the `.env` file to customize:
- `FRONTEND_LOGIN` & `FRONTEND_PASSWORD` - Admin credentials
- `MYSQL_ROOT_PASSWORD` - MySQL root password
- `DB_TCP_USER` & `DB_TCP_PASSWORD` - Database user credentials
- `PYDIO_HOST` - Server hostname/IP (auto-detected)
- `PYDIO_PORT` - Web interface port
- `EXTERNAL_STORAGE_PATH` - Path to external storage mount

### External Storage

Configure external storage mounting:
```bash
# Edit .env file
EXTERNAL_STORAGE_PATH=/path/to/your/storage

# Or mount a USB drive/NAS
EXTERNAL_STORAGE_PATH=/mnt/usb-drive
```

The external storage will be available in Pydio as a workspace.

### SSL Certificates

By default, Pydio uses self-signed certificates. For production:

1. **Replace with proper certificates:**
   ```bash
   # Place your certificates in cellsdir/certs/
   docker compose restart cells
   ```

2. **Or use a reverse proxy** (recommended for production)

## Data Persistence

Data is stored in local directories:
- `./cellsdir/` - Pydio configuration, logs, and internal storage
- `./mysqldir/` - MySQL database files
- External storage path - User files and documents

## Security Notes

**Important for Production:**
1. Change default passwords in `.env`
2. Use proper SSL certificates
3. Configure firewall rules (only allow HTTPS access)
4. Set up proper backup strategy
5. Consider using external authentication (LDAP/Active Directory)

## Useful Commands

```bash
# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f cells
docker compose logs -f mysql

# Restart services
docker compose restart

# Update to latest images
docker compose pull
docker compose up -d

# Backup data
tar -czf pydio-backup-$(date +%Y%m%d).tar.gz cellsdir mysqldir

# Backup database only
docker compose exec mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} --all-databases > backup.sql
```

## Troubleshooting

### Common Issues

1. **Web interface not accessible**
   - Check if port 8080 is available
   - Verify container is running: `docker compose ps`
   - Check logs: `docker compose logs cells`
   - Try accessing via HTTP first: `http://YOUR_IP:8080`

2. **Database connection issues**
   - Verify MySQL is healthy: `docker compose ps mysql`
   - Check database logs: `docker compose logs mysql`
   - Ensure passwords match in `.env` file

3. **External storage not accessible**
   - Verify path exists and has proper permissions
   - Check mount permissions: `ls -la /path/to/storage`
   - Ensure Docker can access the path

4. **Certificate issues**
   - Accept self-signed certificate in browser
   - Or configure proper SSL certificates
   - Check browser console for certificate errors

5. **Performance issues**
   - Increase MySQL memory limits
   - Check available disk space
   - Monitor resource usage: `docker stats`

### Reset Configuration

To completely reset Pydio:
```bash
docker compose down
sudo rm -rf cellsdir mysqldir
rm install-conf.yml
./setup.sh
```

### Logs and Debugging

```bash
# Real-time logs
docker compose logs -f

# Cell-specific logs
docker exec pydio-cells tail -f /var/cells/logs/pydio.log

# MySQL logs
docker compose logs mysql

# Check container status
docker compose ps
```

## Advanced Configuration

### Custom Workspaces

1. Access Pydio web interface
2. Go to **Settings** → **Workspaces**
3. Create new workspace pointing to external storage
4. Configure user permissions

### User Management

1. **Local Users**: Create via web interface
2. **LDAP Integration**: Configure in advanced settings
3. **External Auth**: Set up OAuth or SAML

### Performance Tuning

For high-load environments:

```yaml
# In docker-compose.yml, add resource limits
services:
  cells:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
```

### Backup Strategy

#### Automated Backup Script
```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/path/to/backups"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database
docker compose exec -T mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} --all-databases > "$BACKUP_DIR/mysql_$DATE.sql"

# Backup cells data
tar -czf "$BACKUP_DIR/cellsdir_$DATE.tar.gz" cellsdir

# Clean old backups (keep last 7 days)
find "$BACKUP_DIR" -name "*.sql" -o -name "*.tar.gz" | head -n -14 | xargs rm -f
```

## Integration

### With Other Services
- **Reverse Proxy**: Use Nginx or Traefik for SSL termination
- **Monitoring**: Integrate with Prometheus/Grafana
- **Backup**: Automated backup to cloud storage

### API Usage
Pydio provides REST APIs for automation:
```bash
# Get server info
curl -k "https://YOUR_HOST:8080/a/frontend/state"

# API documentation available in web interface
```

## Network Configuration

### External Network
The setup creates/uses a `pi-services` network for integration with other services:

```bash
# Connect other services to the same network
docker network connect pi-services other-container
```

### Port Configuration
- **8080**: Pydio web interface (HTTPS)
- **3306**: MySQL (internal only)

## Migration

### From Other Platforms
1. Export data from existing platform
2. Import into Pydio workspaces
3. Configure user accounts and permissions
4. Test file access and sharing

### Upgrading
```bash
# Backup first
./backup.sh

# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d
```