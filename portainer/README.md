---
name: "Portainer"
category: "📊 Monitoring & Stats"
purpose: "Container Management"
description: "Lightweight service delivery platform for containerized applications"
icon: "📊"
features:
  - "Complete Docker management interface"
  - "Multi-user support with RBAC"
  - "Application templates for quick deployment"
resource_usage: "~100MB RAM"
---

# Portainer - Docker Management UI

Portainer Community Edition (CE) is a lightweight service delivery platform for containerized applications that can be used to manage Docker, Swarm, Kubernetes and ACI environments.

## Features

- **Docker Management**: Complete Docker container, image, network, and volume management
- **User Management**: Multi-user support with role-based access control
- **Templates**: Application templates for quick deployment
- **Monitoring**: Real-time container stats and logs
- **Web Interface**: Intuitive web-based UI accessible via browser

## Quick Start

1. **Setup Environment**:
   ```bash
   cp .env.example .env
   # Edit .env file with your configuration
   ```

2. **Start Portainer**:
   ```bash
   ./setup.sh
   ```

3. **Access Portainer**:
   - Open your browser and navigate to `http://localhost:9000`
   - Or from network: `http://192.168.0.108:9000`

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORTAINER_PORT` | HTTP port for web interface | `9000` |
| `PORTAINER_HOST` | Host IP address | `localhost` |
| `CONTAINER_NAME` | Container name | `portainer` |
| `IMAGE_TAG` | Docker image tag | `latest` |
| `RESTART_POLICY` | Container restart policy | `unless-stopped` |

### First Time Setup

When you first access Portainer, you'll need to:

1. Create an admin user account
2. Choose your Docker environment (local Docker socket)
3. Start managing your containers!

## Management Commands

```bash
# Start Portainer
docker compose up -d

# Stop Portainer
docker compose down

# View logs
docker compose logs -f

# Update Portainer
docker compose pull
docker compose up -d
```

## Data Persistence

Portainer data is stored in:
- `./portainer_data/` - Portainer configuration and database

## Network Access

- **Local Access**: http://localhost:9000
- **Network Access**: http://192.168.0.108:9000
- **Mobile Friendly**: Responsive web interface

## Security Notes

- Portainer runs with Docker socket access for container management
- Uses `no-new-privileges` security option
- Access control through Portainer's built-in user management
- Consider using reverse proxy with SSL in production

## Troubleshooting

### Common Issues

1. **Port already in use**:
   ```bash
   # Check what's using port 9000
   sudo netstat -tulpn | grep :9000
   ```

2. **Permission issues**:
   ```bash
   # Ensure Docker socket permissions
   sudo chmod 666 /var/run/docker.sock
   ```

3. **Container won't start**:
   ```bash
   # Check logs
   docker compose logs portainer
   ```

## Links

- [Official Documentation](https://docs.portainer.io/)
- [GitHub Repository](https://github.com/portainer/portainer)
- [Docker Hub](https://hub.docker.com/r/portainer/portainer-ce)