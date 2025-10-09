# Homarr - Modern Dashboard for Self-Hosted Services

Homarr is a sleek, modern dashboard that brings all of your self-hosted services together in one place. With extensive customization options, integrations, and a user-friendly interface, it's the perfect homepage for your homelab.

## Features

- **🖌️ Highly Customizable**: Extensive drag and drop grid system
- **✨ Service Integrations**: Seamless integration with 30+ self-hosted applications
- **📌 Easy Management**: No YAML configuration needed - all through web UI
- **👤 User Management**: Detailed permissions and groups system
- **👥 Single Sign-On**: Support for OIDC/LDAP authentication
- **🔒 Secure**: BCrypt and AES-256-CBC encryption for sensitive data
- **🕔 Real-time Updates**: WebSocket-powered live widgets
- **🔍 Global Search**: Search through thousands of data points
- **🦞 Icon Library**: Over 11,000 icons available
- **🐳 Docker Integration**: Container management and monitoring
- **📱 Mobile Friendly**: Responsive design for all devices

## Supported Integrations

**Media & Entertainment**: Plex, Jellyfin, Emby, Overseerr, Jellyseerr
**Download Clients**: qBittorrent, Transmission, Deluge, SABnzbd, NZBGet
***Arr Suite**: Sonarr, Radarr, Lidarr, Readarr, Prowlarr
**Network & Security**: Pi-hole, AdGuard Home, OPNsense, Proxmox, Unifi
**Storage & Files**: Nextcloud, TrueNAS, OpenMediaVault
**Infrastructure**: Docker Hub, Portainer, Home Assistant, Grafana

## Quick Start

1. **Setup Environment**:
   ```bash
   cp .env.example .env
   # Edit .env file with your configuration
   ```

2. **Generate Encryption Key** (Important!):
   ```bash
   # Generate a secure 64-character hex key
   openssl rand -hex 32
   # Add this to your .env file as SECRET_ENCRYPTION_KEY
   ```

3. **Start Homarr**:
   ```bash
   ./setup.sh
   ```

4. **Access Dashboard**:
   - Local: http://localhost:7575
   - Network: http://192.168.0.108:7575

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOMARR_TAG` | Docker image tag | `latest` |
| `CONTAINER_NAME` | Container name | `homarr` |
| `SECRET_ENCRYPTION_KEY` | 64-char hex encryption key | **REQUIRED** |
| `NODE_ENV` | Environment mode | `production` |
| `TIMEZONE` | Server timezone | `UTC` |
| `HOMARR_PORT` | Web interface port | `7575` |
| `AUTH_PROVIDERS` | Authentication method | `credentials` |
| `ENABLE_DOCKER` | Docker integration | `true` |
| `LOG_LEVEL` | Logging level | `info` |

### Database Options

Homarr supports multiple database backends:

**SQLite (Default)**:
```env
DB_DIALECT=sqlite
DB_DRIVER=better-sqlite3
DB_URL=/appdata/db/db.sqlite
```

**MySQL**:
```env
DB_DIALECT=mysql
DB_DRIVER=mysql2
DB_HOST=mysql-server
DB_PORT=3306
DB_USER=homarr
DB_PASSWORD=your-password
DB_NAME=homarr
```

**PostgreSQL**:
```env
DB_DIALECT=postgresql
DB_DRIVER=node-postgres
DB_HOST=postgres-server
DB_PORT=5432
DB_USER=homarr
DB_PASSWORD=your-password
DB_NAME=homarr
```

### Authentication Options

**Built-in Credentials (Default)**:
```env
AUTH_PROVIDERS=credentials
```

**LDAP Authentication**:
```env
AUTH_PROVIDERS=ldap
AUTH_LDAP_URI=ldap://your-ldap-server:389
AUTH_LDAP_BIND_DN=cn=admin,dc=example,dc=com
AUTH_LDAP_BIND_PASSWORD=your-bind-password
AUTH_LDAP_BASE=dc=example,dc=com
AUTH_LDAP_USERNAME_ATTRIBUTE=uid
AUTH_LDAP_USER_MAIL_ATTRIBUTE=mail
```

**OIDC/OAuth2**:
```env
AUTH_PROVIDERS=oidc
AUTH_OIDC_ISSUER=https://your-oidc-provider.com
AUTH_OIDC_CLIENT_ID=your-client-id
AUTH_OIDC_CLIENT_SECRET=your-client-secret
AUTH_OIDC_CLIENT_NAME=Your Provider
```

## First Time Setup

1. **Initial Access**: Navigate to your Homarr URL
2. **Create Admin Account**: Set up your first administrator user
3. **Configure Board**: Create your first dashboard board
4. **Add Services**: Start adding tiles for your self-hosted services
5. **Customize Layout**: Arrange and style your dashboard

## Docker Integration

Homarr can monitor and manage Docker containers:

1. **Enable Docker Socket**: Already configured in docker-compose.yml
2. **Container Discovery**: Automatic detection of running containers
3. **Status Monitoring**: Real-time container health and stats
4. **Container Controls**: Start, stop, restart containers from dashboard

## Service Integration Setup

### Adding Service Tiles

1. **Add Tile**: Click the "+" button on your board
2. **Choose Type**: Select "App" or "Service" tile
3. **Configure Service**:
   - Name: Display name for the service
   - URL: Service web interface URL
   - Icon: Choose from 11K+ available icons
4. **Enable Integration**: For supported services, enable API integration
5. **API Configuration**: Add API keys/credentials for enhanced features

### Popular Integration Examples

**Plex Media Server**:
- URL: `http://192.168.0.108:32400`
- API Token: Get from Plex settings
- Features: Library stats, recently added, now playing

**Pi-hole**:
- URL: `http://192.168.0.108:80/admin`
- API Token: Generate in Pi-hole admin
- Features: Query stats, top domains, blocked queries

**Sonarr/Radarr**:
- URL: `http://192.168.0.108:8989`
- API Key: From settings in respective application
- Features: Queue status, calendar, missing episodes/movies

## Customization

### Themes and Styling

- **Color Schemes**: Light and dark themes
- **Custom CSS**: Advanced styling options
- **Background Images**: Custom backgrounds per board
- **Grid Layout**: Flexible responsive grid system

### Widgets and Tiles

- **App Tiles**: Quick access to services
- **Status Widgets**: System monitoring
- **Weather Widget**: Local weather information
- **Calendar Widget**: Events and schedules
- **Clock Widget**: Multiple timezone support
- **Custom HTML**: Embed custom content

## Management Commands

```bash
# Start Homarr
docker compose up -d

# Stop Homarr
docker compose down

# View logs
docker compose logs -f homarr

# Update Homarr
docker compose pull
docker compose up -d

# Restart Homarr
docker compose restart homarr

# Shell access
docker compose exec homarr /bin/bash

# Generate new encryption key
openssl rand -hex 32

# Check container health
docker compose ps
```

## Data Management

### Backup Strategy

**Database Backup**:
```bash
# SQLite backup
cp ./homarr_data/db/db.sqlite ./homarr-backup-$(date +%Y%m%d).sqlite

# Full data backup
tar -czf homarr-backup-$(date +%Y%m%d).tar.gz ./homarr_data/
```

**Configuration Export**:
- Export boards and settings through web interface
- Save configuration as JSON files

### Data Migration

When migrating Homarr installations:
1. Stop old Homarr instance
2. Copy `homarr_data` directory to new location
3. Update `.env` file with new configuration
4. Start new instance

## Performance Optimization

### Resource Management

- **Memory Limit**: Set appropriate limits based on usage
- **Container Resources**: Monitor CPU and memory usage
- **Database Optimization**: Regular SQLite maintenance
- **Cache Management**: Redis for improved performance

### Network Performance

- **Reverse Proxy**: Use Nginx/Traefik for SSL termination
- **CDN**: Cache static assets
- **Compression**: Enable gzip compression

## Troubleshooting

### Common Issues

1. **Service Not Accessible**:
   ```bash
   # Check if container is running
   docker compose ps
   
   # Check logs for errors
   docker compose logs homarr
   
   # Verify port binding
   netstat -tulpn | grep 7575
   ```

2. **Integration Not Working**:
   ```bash
   # Check API connectivity
   curl -I http://service-url/api/endpoint
   
   # Verify API keys in logs
   docker compose logs homarr | grep -i "api\|auth\|error"
   ```

3. **Database Issues**:
   ```bash
   # Check database file permissions
   ls -la ./homarr_data/db/
   
   # Backup and recreate if corrupted
   cp ./homarr_data/db/db.sqlite ./db.backup
   ```

4. **Permission Errors**:
   ```bash
   # Fix data directory permissions
   sudo chown -R $USER:$USER ./homarr_data/
   chmod -R 755 ./homarr_data/
   ```

### Health Monitoring

Monitor Homarr health:
```bash
# Container health check
docker inspect homarr | grep -A 10 Health

# Resource usage
docker stats homarr

# Disk usage
du -sh ./homarr_data/
```

## Security Considerations

### Encryption and Keys

- **Secret Key**: Use strong 64-character hex key
- **Regular Rotation**: Change encryption keys periodically
- **Environment Security**: Protect .env file access

### Network Security

- **Reverse Proxy**: Use HTTPS in production
- **Access Control**: Configure user permissions
- **API Security**: Secure API keys and tokens
- **Docker Socket**: Consider security implications

### Authentication Security

- **Strong Passwords**: Enforce password policies
- **2FA Support**: Enable where available
- **Session Management**: Configure session timeouts
- **LDAP/OIDC**: Use centralized authentication

## Advanced Configuration

### External Redis

For improved performance with multiple users:
```env
REDIS_IS_EXTERNAL=true
REDIS_HOST=redis-server
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password
```

### Custom Nginx Configuration

For SSL termination and advanced routing:
```nginx
server {
    listen 443 ssl;
    server_name homarr.yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:7575;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Links

- [Official Documentation](https://homarr.dev/docs)
- [GitHub Repository](https://github.com/homarr-labs/homarr)
- [Discord Community](https://discord.com/invite/aCsmEV5RgA)
- [Feature Requests](https://github.com/homarr-labs/homarr/issues)
- [Integration Guides](https://homarr.dev/docs/integrations)

## Contributing

- [Translations](https://crowdin.com/project/homarr_labs)
- [Bug Reports](https://github.com/homarr-labs/homarr/issues)
- [Development](https://github.com/homarr-labs/homarr/blob/dev/CONTRIBUTING.md)
- [Sponsor Project](https://opencollective.com/homarr)