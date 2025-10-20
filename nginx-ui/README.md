---
name: "Nginx Proxy Manager"
category: "🏡 Dashboard & Network Services"
purpose: "Reverse Proxy Management UI"
description: "Easy-to-use reverse proxy management powered by Nginx with SSL certificate automation"
icon: "🔀"
features:
  - "Web UI for reverse proxy setup"
  - "Free SSL with Let's Encrypt"
  - "Access lists and authentication"
resource_usage: "~400MB RAM"
---

# Nginx Proxy Manager - Docker Setup

Nginx Proxy Manager is a user-friendly web interface for managing Nginx reverse proxy configurations with automatic SSL certificate generation via Let's Encrypt. Perfect for exposing your self-hosted services securely.

## Features
- **Web-based UI** - No nginx config file editing required
- **SSL Automation** - Free SSL certificates with Let's Encrypt
- **Reverse Proxy** - Route domains/subdomains to your services
- **Access Lists** - Password protection for services
- **Stream Support** - TCP/UDP forwarding
- **Custom Configurations** - Advanced nginx configs available

## Architecture
- **SQLite Database** - Lightweight built-in database (default, perfect for home labs)
- **PostgreSQL (Optional)** - For larger deployments or better performance under heavy load
- **Exposed Config Files** - Nginx configs available as bind mounts for programmatic access

## Prerequisites
- Docker and Docker Compose installed
- Domain name(s) pointed to your server IP (for SSL)
- Ports 80 and 443 available (or customize)

## Quick Start

1. Prepare directories
```bash
mkdir -p data letsencrypt postgres nginx/{custom,proxy_host,redirection_host,stream,dead_host,temp,snippets}
```

2. Configure environment (optional)
```bash
cat > .env <<'EOF'
NPM_TAG=latest
POSTGRES_TAG=15-alpine
CONTAINER_NAME=nginx-proxy-manager
DB_CONTAINER_NAME=nginx-proxy-manager-db
RESTART_POLICY=unless-stopped

# Ports
HTTP_PORT=80
HTTPS_PORT=443
ADMIN_PORT=81

# Database credentials (CHANGE THESE!)
DB_HOST=db
DB_PORT=5432
DB_USER=npm
DB_PASSWORD=npm_secure_password_change_me
DB_NAME=npm

# Resource limits
MEMORY_LIMIT=512M
MEMORY_RESERVATION=128M
DB_MEMORY_LIMIT=256M
DB_MEMORY_RESERVATION=64M
EOF
```

3. Launch
```bash
./setup.sh up
```

4. Access Admin UI
- Web: http://<your-server-ip>:81
- **Default credentials:**
  - Email: `admin@example.com`
  - Password: `changeme`
  - ⚠️ **You will be forced to change these on first login**

## Configuration

### Exposed Nginx Config Files
All nginx configurations are exposed via bind mounts in `./nginx/` directory:

```
nginx/
├── custom/              # Custom nginx configs
├── proxy_host/          # Proxy host configurations
├── redirection_host/    # HTTP redirections
├── stream/              # TCP/UDP stream configs
├── dead_host/           # Disabled/dead hosts
├── temp/                # Temporary files
└── snippets/            # Reusable config snippets
```

You can edit these files directly for programmatic configuration!

### Programmatic Configuration Example
```bash
# Create a custom nginx snippet
cat > ./nginx/snippets/security-headers.conf <<'EOF'
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
EOF

# Then reference it in your proxy host configs
```

### Database Configuration
By default, NPM uses **SQLite** for storing all configurations:
- Database file: `./data/database.sqlite`
- Automatic initialization on first run
- Perfect for home lab usage - simple and reliable
- No additional containers needed

**For larger deployments or production use**, you can optionally use PostgreSQL:
1. Uncomment the `db` service in `docker-compose.yml`
2. Uncomment the `environment` and `depends_on` sections in the `nginx-proxy-manager` service
3. Update `DB_PASSWORD` in `.env` file
4. Restart: `docker compose up -d`

## Common Use Cases

### 1. Reverse Proxy for Local Services
Forward `service.yourdomain.com` → `http://192.168.0.108:8080`

1. Add Proxy Host in UI
2. Domain: `service.yourdomain.com`
3. Forward to: `192.168.0.108:8080`
4. Enable SSL (auto Let's Encrypt)

### 2. Subdomain for Each Service
```
jellyfin.yourdomain.com → http://192.168.0.108:8096
filebrowser.yourdomain.com → http://192.168.0.108:8080
portainer.yourdomain.com → http://192.168.0.108:9000
```

### 3. Password Protection
Add Access List with username/password for sensitive services.

## SSL Certificates

### Let's Encrypt (Automatic)
1. Ensure domain points to your server
2. Enable "Force SSL" in proxy host
3. NPM handles certificate generation and renewal

### Custom SSL
Upload your own certificates in the SSL Certificates section.

## Management Commands

```bash
# Start service
docker compose up -d

# Stop service
docker compose down

# View logs
docker compose logs -f nginx-proxy-manager

# Update
docker compose pull && docker compose up -d

# Restart
docker compose restart nginx-proxy-manager

# Shell access
docker compose exec nginx-proxy-manager /bin/sh

# Backup SQLite database
cp ./data/database.sqlite ./backups/database_$(date +%Y%m%d).sqlite

# Access SQLite database directly
docker compose exec nginx-proxy-manager sqlite3 /data/database.sqlite

# If using PostgreSQL (optional):
# docker compose logs -f db
# docker compose exec db psql -U npm
# docker compose exec db pg_dump -U npm npm > backup.sql
```

## Data Persistence
- `./data/` - Application data and SQLite database
- `./letsencrypt/` - SSL certificates
- `./nginx/` - Nginx configuration files (editable)
- `./postgres/` - PostgreSQL data (only if using PostgreSQL option)

## Port Configuration

### Default Ports
- **80** - HTTP traffic (required for Let's Encrypt)
- **443** - HTTPS traffic
- **81** - Admin Web UI

### Custom Ports
If ports 80/443 are in use, modify in `.env`:
```bash
HTTP_PORT=8080
HTTPS_PORT=8443
ADMIN_PORT=8181
```

**Note:** For Let's Encrypt to work, you need port 80 or set up DNS validation.

## Security Considerations

### Change Default Credentials
On first login, you'll be forced to change:
- Admin email
- Admin password

### Database Security (PostgreSQL only)
If you enable PostgreSQL, update `DB_PASSWORD` in `.env` before first run:
```bash
DB_PASSWORD=$(openssl rand -base64 32)
```

### Access Control
- Use Access Lists for password protection
- Enable 2FA in user settings
- Restrict admin UI to local network only

### Firewall Rules
```bash
# Allow only necessary ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 81/tcp  # Or restrict to local network
```

## Troubleshooting

### Cannot Access Admin UI
```bash
# Check if container is running
docker compose ps

# Check logs
docker compose logs nginx-proxy-manager

# Verify port is not in use
sudo netstat -tulpn | grep :81
```

### Database Connection Failed
```bash
# Check database is healthy
docker compose ps db

# Check database logs
docker compose logs db

# Test connection
docker compose exec db pg_isready -U npm
```

### SSL Certificate Issues
```bash
# Check Let's Encrypt rate limits
# Verify DNS points to your server
dig yourdomain.com

# Check nginx error logs
docker compose exec nginx-proxy-manager cat /data/logs/fallback_error.log
```

### Configuration File Changes Not Applied
```bash
# Reload nginx without restart
docker compose exec nginx-proxy-manager nginx -s reload

# Or restart the container
docker compose restart nginx-proxy-manager
```

## Advanced Configuration

### Custom Nginx Configs
Edit files in `./nginx/custom/` for global nginx directives.

### Stream (TCP/UDP) Forwarding
Use the Streams section in UI or edit `./nginx/stream/` configs.

### Rate Limiting
Add to custom config or snippet:
```nginx
limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s;
limit_req zone=mylimit burst=20 nodelay;
```

### Backup Strategy
```bash
#!/bin/bash
# Automated backup script
DATE=$(date +%Y%m%d_%H%M%S)
docker compose exec db pg_dump -U npm npm > "backups/npm_db_${DATE}.sql"
tar -czf "backups/npm_data_${DATE}.tar.gz" ./data ./letsencrypt ./nginx
```

## Migration from SQLite
If you have an existing NPM installation using SQLite:
1. Export data from old installation
2. Use PostgreSQL from the start
3. Import proxy hosts manually via UI

## Links
- Docs: https://nginxproxymanager.com/
- GitHub: https://github.com/NginxProxyManager/nginx-proxy-manager
- Docker Hub: https://hub.docker.com/r/jc21/nginx-proxy-manager
- Guide: https://nginxproxymanager.com/guide/
