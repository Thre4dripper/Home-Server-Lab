# ownCloud

Open-source file synchronization and sharing platform with enterprise features.

## ☁️ Overview

ownCloud provides a secure, self-hosted file sync and share solution. Access your files from anywhere while maintaining complete control over your data. Perfect for teams, families, or personal file management.

## 🏗️ Architecture

- **ownCloud Server**: Core file sync and web interface
- **MariaDB**: Database for metadata and user management
- **Redis**: Performance caching layer

## 🚀 Quick Start

1. **Configure Environment**:
   ```bash
   cd /home/pi/Home-Server-Lab/owncloud
   cp .env.example .env
   nano .env
   ```
   
   **Required Settings:**
   - `OWNCLOUD_DOMAIN`: Your server IP with port (e.g., 192.168.0.108:8080)
   - `OWNCLOUD_TRUSTED_DOMAINS`: Network access configuration
   - `ADMIN_PASSWORD`: Secure admin password
   - `DB_PASSWORD`: Database password
   - `DB_ROOT_PASSWORD`: Database root password

2. **Deploy ownCloud**:
   ```bash
   ./setup.sh
   ```

3. **Access Web Interface**:
   - URL: http://your-server-ip:8080
   - Login with admin credentials from .env

## 📋 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OWNCLOUD_VERSION` | ownCloud version | `10.15` |
| `OWNCLOUD_DOMAIN` | Main domain/IP with port | `your-server-ip:8080` |
| `OWNCLOUD_TRUSTED_DOMAINS` | Allowed access domains/IPs | Multiple domains |
| `HTTP_PORT` | Web interface port | `8080` |
| `ADMIN_USERNAME` | Admin username | `admin` |
| `ADMIN_PASSWORD` | Admin password | `secure_admin_password` |
| `DB_PASSWORD` | Database password | `secure_db_password` |
| `DB_ROOT_PASSWORD` | Database root password | `secure_root_password` |

### Trusted Domains Fix

The key to network access is properly configuring `OWNCLOUD_TRUSTED_DOMAINS`:

```bash
# Example for IP 192.168.0.108
OWNCLOUD_TRUSTED_DOMAINS=192.168.0.108:8080,192.168.0.108,localhost:8080,localhost
```

This allows access from:
- `192.168.0.108:8080` (with port)
- `192.168.0.108` (without port)
- `localhost:8080` (local with port)
- `localhost` (local without port)

Add additional IPs/domains as needed, separated by commas.

## 🌟 Features

### File Management
- **Web Interface**: Full-featured file browser
- **Drag & Drop**: Easy file uploads
- **File Versioning**: Automatic version history
- **File Locking**: Prevent editing conflicts
- **Trash Bin**: Recover deleted files

### Synchronization
- **Desktop Clients**: Windows, macOS, Linux
- **Mobile Apps**: iOS and Android
- **Selective Sync**: Choose folders to sync
- **Offline Access**: Files available without internet

### Collaboration
- **File Sharing**: Internal and external sharing
- **Public Links**: Share files with anyone
- **Password Protection**: Secure shared links
- **Expiration Dates**: Time-limited access
- **User Groups**: Organize users and permissions

### Enterprise Features
- **Calendar**: CalDAV calendar sync
- **Contacts**: CardDAV contact sync
- **External Storage**: Connect to FTP, SMB, S3
- **LDAP Integration**: Enterprise authentication
- **Activity Stream**: Track all file activities

## 🔧 Management

### Daily Operations
```bash
# View service status
./setup.sh status

# View logs
./setup.sh logs

# Restart services
./setup.sh restart

# Stop services
./setup.sh stop
```

### Data Backup
```bash
# Backup user files
tar -czf owncloud-files-backup-$(date +%Y%m%d).tar.gz files/

# Backup database
docker compose exec mariadb mysqldump -u root -p owncloud > backup.sql

# Full backup (files + database)
./setup.sh stop
tar -czf owncloud-full-backup-$(date +%Y%m%d).tar.gz files/ mysql/ redis/
./setup.sh start
```

### User Management
- **Web Interface**: Admin settings → Users
- **Add Users**: Create accounts with quotas
- **Groups**: Organize users by department/function
- **Permissions**: Fine-grained access control

## 🌐 Network Configuration

### Port Information
- **Web Interface**: 8080 (configurable)
- **Database**: 3306 (internal only)
- **Redis**: 6379 (internal only)

### Client Setup
1. **Download Clients**: https://owncloud.com/desktop-app/
2. **Server URL**: http://your-server-ip:8080
3. **Credentials**: Use your ownCloud username/password
4. **Sync Folders**: Choose local and remote folders

### Mobile Apps
- **Android**: https://play.google.com/store/apps/details?id=com.owncloud.android
- **iOS**: https://apps.apple.com/app/owncloud/id543672169

## 🛡️ Security

### Access Control
- **Trusted Domains**: Restricts access to configured IPs/domains
- **User Authentication**: Individual user accounts
- **Two-Factor Auth**: TOTP support via apps
- **Session Management**: Configurable timeout

### Data Protection
- **Server-Side Encryption**: Encrypt files at rest
- **Client-Side Encryption**: End-to-end encryption option
- **File Checksums**: Verify file integrity
- **Access Logs**: Monitor all file access

### Network Security
- **Internal Communication**: Database and Redis not exposed
- **HTTPS Ready**: Add reverse proxy for SSL termination
- **Firewall**: Only port 8080 needs external access

## 📊 Resource Usage

### System Requirements
- **RAM**: 1GB minimum, 2GB+ recommended
- **CPU**: 1 core minimum, 2+ cores recommended
- **Storage**: 10GB+ for system, unlimited for user files
- **Network**: Ethernet recommended for performance

### Performance Optimization
- **Redis Caching**: Enabled for better performance
- **Database Tuning**: Optimized MariaDB configuration
- **File Chunking**: Efficient large file uploads
- **Background Jobs**: Async processing via cron

## 🔍 Troubleshooting

### Common Issues

1. **Trusted Domain Error**
   ```bash
   # Update .env with correct trusted domains
   OWNCLOUD_TRUSTED_DOMAINS=your-ip:8080,your-ip,localhost:8080
   ./setup.sh restart
   ```

2. **Can't Access from Network**
   ```bash
   # Check firewall
   sudo ufw allow 8080
   
   # Verify service is running
   ./setup.sh status
   ```

3. **Database Connection Error**
   ```bash
   # Check database logs
   docker compose logs mariadb
   
   # Restart services
   ./setup.sh restart
   ```

4. **File Upload Issues**
   ```bash
   # Check disk space
   df -h
   
   # Check upload limits in admin settings
   ```

### Log Analysis
```bash
# ownCloud application logs
./setup.sh logs owncloud

# Database logs
./setup.sh logs mariadb

# All services
./setup.sh logs
```

## 🆚 vs. Other Solutions

### vs. Nextcloud
- **Stability**: More stable, enterprise-focused
- **Simplicity**: Cleaner interface, fewer features
- **Performance**: Generally faster file operations
- **Apps**: Smaller app ecosystem

### vs. Seafile
- **Licensing**: Open source vs. Pro features
- **Interface**: More traditional file manager feel
- **Clients**: Mature desktop/mobile applications
- **Collaboration**: Built-in calendar and contacts

### vs. Dropbox/Google Drive
- **Privacy**: Complete data control
- **Cost**: No subscription fees
- **Features**: More enterprise features
- **Integration**: Calendar, contacts, external storage

## 🔗 Resources

### Official Links
- [ownCloud Website](https://owncloud.com/)
- [Documentation](https://doc.owncloud.com/)
- [Desktop Clients](https://owncloud.com/desktop-app/)
- [Mobile Apps](https://owncloud.com/mobile-apps/)

### Community
- [Community Forum](https://central.owncloud.org/)
- [GitHub Repository](https://github.com/owncloud/core)
- [Docker Hub](https://hub.docker.com/r/owncloud/server)

### Enterprise
- [ownCloud Enterprise](https://owncloud.com/enterprise/)
- [Support Plans](https://owncloud.com/support/)
- [Migration Services](https://owncloud.com/migration/)

This setup provides a production-ready ownCloud installation with proper network access configuration and all standard management features.