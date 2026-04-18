---
name: "Homepage"
category: "🏡 Dashboard & Network Services"
purpose: "Homepage Dashboard"
description: "A modern, fully static, fast, secure fully proxied, highly customizable application dashboard"
icon: "🏠"
features:
  - "YAML-based configuration"
  - "Docker integration with container stats"
  - "Service health monitoring"
  - "Weather, search, and system resource widgets"
  - "50+ service integrations with live data"
resource_usage: "~128MB RAM"
---

# Homepage - Application Dashboard

A modern, fully static, fast, secure, fully proxied, highly customizable application dashboard with integrations for over 100 services and widgets for various information.

## Architecture

- **📊 Homepage**: Lightweight dashboard with YAML configuration, Docker socket integration, and live service widgets

## Features

- **🎨 Clean & Fast**: Fully static, server-rendered dashboard
- **🐳 Docker Integration**: Auto-discovers containers, shows stats
- **📡 100+ Integrations**: Jellyfin, Plex, Pi-hole, Portainer, and more
- **🌤️ Widgets**: Weather, search, system resources, calendar
- **📱 Responsive**: Works on desktop, tablet, and mobile
- **🔖 Bookmarks**: Quick-access links organized by category
- **🔒 Secure**: No database, no JS frameworks, minimal attack surface
- **⚡ Live Reload**: Config changes apply instantly without restart

## Quick Start

1. **Setup**:
   ```bash
   ./setup.sh
   ```

2. **Access Dashboard**:
   - Local: http://localhost:3000
   - Network: http://192.168.0.108:3000

## Configuration

All configuration files are in `./config/`:

| File | Purpose |
|------|---------|
| `services.yaml` | Service tiles with icons, links, and Docker integration |
| `widgets.yaml` | Top bar widgets (weather, search, resources) |
| `bookmarks.yaml` | Quick-access bookmark links |
| `settings.yaml` | Theme, layout, and provider configuration |
| `docker.yaml` | Docker socket connection settings |
| `custom.css` | Custom CSS overrides |
| `custom.js` | Custom JavaScript |

Changes to config files are picked up automatically - no restart needed.

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOMEPAGE_TAG` | Docker image tag | `latest` |
| `CONTAINER_NAME` | Container name | `homepage` |
| `HOMEPAGE_PORT` | Web UI port | `3000` |
| `TIMEZONE` | Timezone | `Asia/Kolkata` |
| `HOMEPAGE_ALLOWED_HOSTS` | Allowed hostnames | `*` |

## Service Groups

The dashboard is organized into four groups:

- **Infrastructure**: Portainer, Pi-hole, Nginx, Netdata, Home Assistant, Dashdot, Homarr
- **Media & Downloads**: Jellyfin, Plex, qBittorrent, Deluge, Aria2
- **Cloud & Files**: Nextcloud, File Browser, Seafile, Samba, Rclone
- **Development & Tools**: Gitea, n8n, LocalStack, GitLab

## Management

```bash
./setup.sh start       # Start Homepage
./setup.sh stop        # Stop Homepage
./setup.sh restart     # Restart Homepage
./setup.sh logs        # View logs
./setup.sh status      # Show status
./setup.sh update      # Update to latest version
```

## Adding New Services

Edit `config/services.yaml` and add entries under the appropriate group:

```yaml
- Infrastructure:
    - My Service:
        icon: service-icon
        href: http://192.168.0.108:PORT
        description: Service description
        server: local
        container: container-name
```

## Resources

- [Homepage Docs](https://gethomepage.dev/)
- [Service Widgets](https://gethomepage.dev/widgets/services/)
- [Dashboard Icons](https://github.com/walkxcode/dashboard-icons)
