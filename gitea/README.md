# Gitea Git Service Setup

A lightweight, self-hosted Git service with web interface, similar to GitHub but running on your own infrastructure.

## 🌟 Features

- **Git Repository Hosting**: Full Git repository management with web interface
- **User & Organization Management**: Create users, teams, and organizations
- **Issue Tracking**: Built-in issue tracker with labels, milestones, and assignments
- **Pull Requests**: Code review workflow with merge/rebase options
- **Wiki & Pages**: Documentation and static pages for repositories
- **SSH & HTTP(S) Access**: Clone and push via SSH or HTTPS
- **API Access**: REST API for integration and automation
- **PostgreSQL Database**: Reliable, high-performance database backend

## 📋 Prerequisites

- Docker and Docker Compose installed
- Port 3000 (web interface) and 222 (SSH) available
- At least 1GB RAM and 10GB disk space recommended
- Network access to pull Docker images

## 🚀 Quick Start

1. **Configure the installation**:
   ```bash
   cd /home/pi/Home-Server-Lab/gitea
   nano .env  # Edit configuration as needed
   ```

2. **Run the setup script**:
   ```bash
   ./setup.sh
   ```

3. **Access Gitea**:
   - Open: http://192.168.0.108:3000
   - Complete the initial setup wizard
   - Create your admin account

## ⚙️ Configuration

### Environment Variables (.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `GITEA_DOMAIN` | Server domain/IP | `192.168.0.108` |
| `GITEA_PORT` | Web interface port | `3000` |
| `GITEA_SSH_PORT` | SSH port for Git operations | `222` |
| `USER_UID/USER_GID` | User/Group ID for file permissions | `1000` |
| `POSTGRES_USER` | PostgreSQL username | `gitea` |
| `POSTGRES_PASSWORD` | PostgreSQL password | `gitea_secure_2024` |
| `POSTGRES_DB` | PostgreSQL database name | `gitea` |

### Network Configuration

Gitea connects to the shared `pi-services` network, allowing integration with other services in your home lab.

## 📁 Directory Structure

```
gitea/
├── docker-compose.yml    # Service definitions
├── .env                  # Configuration variables
├── setup.sh             # Automated setup script
├── README.md            # This documentation
├── gitea/               # Gitea application data (created on first run)
└── postgres/            # PostgreSQL database data (created on first run)
```

## 🔧 Management

### Starting Services
```bash
docker compose up -d
```

### Stopping Services
```bash
docker compose down
```

### Viewing Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f gitea
docker compose logs -f db
```

### Updating Gitea
```bash
docker compose pull
docker compose up -d
```

### Backup Data
```bash
# Stop services
docker compose down

# Backup data directories
tar -czf gitea-backup-$(date +%Y%m%d).tar.gz gitea/ postgres/

# Restart services
docker compose up -d
```

## 🌐 Access Methods

### Web Interface
- **URL**: http://192.168.0.108:3000
- **Initial Setup**: Complete setup wizard on first visit
- **Features**: Repository management, issue tracking, user management

### Git Operations via HTTPS
```bash
# Clone repository
git clone http://192.168.0.108:3000/username/repository.git

# Set remote
git remote add origin http://192.168.0.108:3000/username/repository.git
```

### Git Operations via SSH
```bash
# Clone repository
git clone ssh://git@192.168.0.108:222/username/repository.git

# Set remote
git remote add origin ssh://git@192.168.0.108:222/username/repository.git
```

### API Access
```bash
# List repositories
curl -H "Authorization: token YOUR_TOKEN" \
     http://192.168.0.108:3000/api/v1/user/repos

# Create repository
curl -X POST -H "Authorization: token YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"name":"new-repo","description":"My new repository"}' \
     http://192.168.0.108:3000/api/v1/user/repos
```

## 🛡️ Security Considerations

### Default Security Settings
- PostgreSQL database is isolated on internal network
- SSH port changed to 222 to avoid conflicts with system SSH
- File permissions properly configured for container security

### Production Recommendations
1. **Change Default Passwords**: Update database and admin passwords
2. **Enable HTTPS**: Configure SSL certificates (use reverse proxy)
3. **Firewall Configuration**: Limit access to necessary ports only
4. **Regular Backups**: Implement automated backup strategy
5. **SSH Key Authentication**: Use SSH keys instead of passwords
6. **Two-Factor Authentication**: Enable 2FA for admin accounts

## 🔗 Integration

### Reverse Proxy Setup
For HTTPS and custom domains, configure Nginx:

```nginx
server {
    listen 443 ssl;
    server_name git.yourdomain.com;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Home Lab Integration
Works seamlessly with other services in the pi-services network:
- **Pi-hole**: DNS resolution for custom domains
- **n8n**: Automation workflows for Git webhooks
- **Pydio**: File sharing for repository artifacts

## 📊 Health Monitoring

### Service Health Checks
Both services include health checks:
- **PostgreSQL**: Database connectivity check
- **Gitea**: HTTP endpoint health check

### Monitoring Commands
```bash
# Check container status
docker compose ps

# Check service health
docker compose exec gitea curl -f http://localhost:3000/api/healthz
docker compose exec db pg_isready -U gitea -d gitea

# Monitor resource usage
docker stats gitea-server gitea-db
```

## 🐛 Troubleshooting

### Common Issues

#### Gitea Won't Start
```bash
# Check logs
docker compose logs gitea

# Common solutions
docker compose down && docker compose up -d
```

#### Database Connection Issues
```bash
# Check PostgreSQL status
docker compose logs db
docker compose exec db pg_isready -U gitea -d gitea

# Reset database (WARNING: destroys data)
docker compose down
docker volume rm gitea_postgres_data
docker compose up -d
```

#### Permission Issues
```bash
# Fix Gitea data permissions
sudo chown -R 1000:1000 gitea/
```

#### Port Conflicts
```bash
# Check port usage
netstat -tulpn | grep -E ":(3000|222)"

# Change ports in .env file if needed
```

### Reset Installation
```bash
# Stop and remove containers
docker compose down

# Remove data (WARNING: destroys all data)
sudo rm -rf gitea/ postgres/

# Restart setup
./setup.sh
```

## 📚 Additional Resources

- [Gitea Official Documentation](https://docs.gitea.com/)
- [Gitea Configuration Options](https://docs.gitea.com/administration/config-cheat-sheet)
- [Git Documentation](https://git-scm.com/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## 🤝 Support

For issues specific to this setup:
1. Check the troubleshooting section above
2. Review Docker logs: `docker compose logs -f`
3. Verify configuration in `.env` file
4. Ensure all prerequisites are met

For Gitea-specific issues, consult the [official documentation](https://docs.gitea.com/) or [community forum](https://discourse.gitea.com/).