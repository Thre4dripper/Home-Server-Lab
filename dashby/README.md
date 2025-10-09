# Dashy - Self-Hosted Dashboard

Dashy is a highly customizable, self-hosted dashboard for organizing your homelab services and applications. It provides a clean, modern interface with extensive theming options and powerful features like status monitoring, search functionality, and multi-page support.

## Features

- **🎨 Highly Customizable**: 20+ built-in themes and custom CSS support
- **📊 Status Monitoring**: Real-time health checks for all your services
- **🔍 Advanced Search**: Web search integration with custom search bangs
- **📱 Mobile Responsive**: Optimized for desktop, tablet, and mobile devices
- **⚡ Fast & Lightweight**: Minimal resource usage with excellent performance
- **🔒 Security Options**: Optional authentication and access controls
- **🌐 Multi-Language**: Support for 30+ languages
- **📑 Multi-Page Support**: Organize services across multiple pages
- **🎯 Quick Actions**: Keyboard shortcuts and instant filtering
- **☁️ Cloud Sync**: Backup and restore configurations

## Quick Start

1. **Setup Environment**:
   ```bash
   cp .env.example .env
   # Edit .env file with your configuration
   ```

2. **Start Dashy**:
   ```bash
   ./setup.sh
   ```

3. **Configure Dashboard**:
   ```bash
   ./config.sh edit
   ```

4. **Access Dashboard**:
   - Local: http://localhost:4000
   - Network: http://192.168.0.108:4000

## Configuration

### Configuration Management

Dashy uses a **two-tier configuration system** for safety and flexibility:

1. **Main Configuration** (`./conf.yml`): Your master configuration file
   - Edit this file to make changes to your dashboard
   - Safe from accidental deletion during Docker operations
   - Version controlled and backed up with your project

2. **Runtime Configuration** (`./user-data/conf.yml`): Automatically managed
   - Generated from the main configuration file
   - Used by the Dashy container
   - Automatically updated when you run setup commands

### Making Configuration Changes

```bash
# 1. Edit the main configuration file
./config.sh edit

# 2. Or manually edit and then sync
nano ./conf.yml
./config.sh sync

# 3. Validate configuration
./config.sh validate

# 4. Check status
./config.sh status
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DASHY_TAG` | Docker image tag | `latest` |
| `CONTAINER_NAME` | Container name | `dashby` |
| `NODE_ENV` | Environment mode | `production` |
| `PUID` | User ID for file permissions | `1000` |
| `PGID` | Group ID for file permissions | `1000` |
| `TIMEZONE` | Server timezone | `UTC` |
| `DASHY_PORT` | Web interface port | `4000` |
| `MEMORY_LIMIT` | Container memory limit | `512M` |

### Configuration File Structure

The main configuration file (`./conf.yml`) defines your dashboard layout and behavior:

- **pageInfo**: Dashboard metadata (title, description, nav links)
- **appConfig**: Application settings (theme, layout, search options)
- **sections**: Organized groups of service links and applications

**Important**: Always edit `./conf.yml` (in the project root), not `./user-data/conf.yml`

### Sample Configuration Structure

```yaml
pageInfo:
  title: 'My Dashboard'
  description: 'Homelab services dashboard'

appConfig:
  theme: colorful
  layout: auto
  statusCheck: true

sections:
  - name: Core Services
    items:
      - title: Service Name
        description: Service description
        icon: service-icon
        url: http://service-url
        statusCheck: true
```

## Themes

Dashy includes 20+ built-in themes:

- **Light Themes**: `default`, `material`, `minimal-light`
- **Dark Themes**: `oblivion`, `dracula`, `colorful-dark`
- **Colorful Themes**: `colorful`, `rainbow`, `bee`
- **High Contrast**: `high-contrast-light`, `high-contrast-dark`
- **Custom**: Create your own with CSS

Change theme in the UI or set in config:
```yaml
appConfig:
  theme: colorful
```

## Status Monitoring

Enable real-time health checks for your services:

```yaml
appConfig:
  statusCheck: true
  statusCheckInterval: 300  # 5 minutes

sections:
  - name: Services
    items:
      - title: My Service
        url: http://service-url
        statusCheck: true  # Enable for this item
```

**Status Indicators**:
- 🟢 Green: Service is healthy (2xx response)
- 🟡 Yellow: Service has issues (4xx/5xx response)
- 🔴 Red: Service is unreachable
- ⚪ Gray: Status check disabled

## Search & Navigation

### Web Search Integration

```yaml
appConfig:
  webSearch:
    searchEngine: duckduckgo
    searchBangs:
      /g: google
      /gh: github
      /r: reddit
```

### Keyboard Shortcuts

- **Ctrl + K**: Open search
- **Esc**: Close search/modals
- **Tab**: Navigate between items
- **Enter**: Open selected item
- **Alt + T**: Toggle theme

### Quick Filter

Type to instantly filter visible items by name or description.

## Icons

Dashy supports multiple icon sources:

### Font Awesome Icons
```yaml
icon: fas fa-server        # Solid
icon: fab fa-github        # Brands
icon: far fa-heart         # Regular
```

### Simple Icons
```yaml
icon: si-docker           # Simple Icons
icon: si-kubernetes
icon: si-nginx
```

### Home Lab Icons
```yaml
icon: hl-plex            # Home Lab specific
icon: hl-sonarr
icon: hl-radarr
```

### Custom Icons
```yaml
icon: https://example.com/icon.png  # Remote URL
icon: favicon                       # Auto-fetch favicon
icon: /item-icons/my-icon.png       # Local file
```

## Authentication

Protect your dashboard with authentication:

### Simple Authentication
```yaml
appConfig:
  auth:
    users:
      - user: admin
        hash: your-password-hash
```

### Keycloak Integration
```yaml
appConfig:
  auth:
    keycloak:
      serverUrl: https://keycloak.example.com
      realm: dashy
      clientId: dashy-client
```

### LDAP Authentication
```yaml
appConfig:
  auth:
    ldap:
      server: ldap://ldap.example.com
      bindDN: cn=admin,dc=example,dc=com
      searchBase: ou=users,dc=example,dc=com
```

## Multi-Page Support

Create multiple pages for different categories:

```yaml
pages:
  - name: home
    path: /
  - name: work
    path: /work
  - name: games
    path: /games
```

Each page can have its own configuration file:
- `conf.yml` - Main page
- `work.yml` - Work page
- `games.yml` - Games page

## Cloud Sync & Backup

### Built-in Cloud Sync

Dashy can backup/restore configurations to cloud providers:

1. **Enable Cloud Sync**: Settings → Config → Cloud Backup
2. **Choose Provider**: GitHub Gist, GitLab Snippet, or generic
3. **Authenticate**: Provide API token
4. **Backup/Restore**: Use the interface or API

### Manual Backup

```bash
# Backup configuration
cp ./user-data/conf.yml ./backup-$(date +%Y%m%d).yml

# Full data backup
tar -czf dashy-backup-$(date +%Y%m%d).tar.gz ./user-data/
```

## Customization

### Custom CSS

Add custom styles in `user-data/custom.css`:

```css
/* Custom theme modifications */
html[data-theme="my-theme"] {
  --primary: #ff6b6b;
  --background: #2d3748;
}

/* Custom item styling */
.item-wrapper {
  border-radius: 10px;
}
```

### Custom Fonts

Place fonts in `user-data/fonts/` and reference in CSS:

```css
@font-face {
  font-family: 'MyFont';
  src: url('/fonts/my-font.woff2');
}

body {
  font-family: 'MyFont', sans-serif;
}
```

### Custom Scripts

Add JavaScript in `user-data/custom.js`:

```javascript
// Custom functionality
document.addEventListener('DOMContentLoaded', function() {
  console.log('Dashboard loaded!');
});
```

## Management Commands

### Service Management (setup.sh)

```bash
# Setup and service management
./setup.sh                # Setup and start Dashy
./setup.sh start           # Start the service
./setup.sh stop            # Stop the service
./setup.sh restart         # Restart the service
./setup.sh status          # Show service status
./setup.sh logs            # View service logs
./setup.sh update          # Update to latest version
```

### Configuration Management (config.sh)

```bash
# Configuration management
./config.sh edit           # Edit configuration with validation
./config.sh sync           # Apply changes to running service
./config.sh validate       # Validate configuration syntax
./config.sh status         # Show configuration status
./config.sh diff           # Check if sync is needed
./config.sh reset          # Reset to default template
```

### Configuration Workflow

```bash
# 1. Edit configuration
./config.sh edit

# 2. Validate changes
./config.sh validate

# 3. Apply to running service
./config.sh sync

# 4. Check service status
./setup.sh status
```

## Widgets

Dashy supports various widgets for enhanced functionality:

### System Info Widget
```yaml
widgets:
  - type: gl-system-info
    options:
      hostname: true
      uptime: true
      memory: true
```

### Weather Widget
```yaml
widgets:
  - type: weather
    options:
      apiKey: your-api-key
      city: London
      units: metric
```

### Clock Widget
```yaml
widgets:
  - type: clock
    options:
      timeZone: America/New_York
      format: 12hour
```

## Performance Optimization

### Resource Management

- **Memory Limit**: Set appropriate limits based on usage
- **Image Optimization**: Use compressed icons when possible
- **Caching**: Enable browser caching for static assets

### Status Check Optimization

```yaml
appConfig:
  statusCheck: true
  statusCheckInterval: 300  # Increase interval for better performance
  
# Disable for external services to reduce load
items:
  - title: External Service
    url: https://external-service.com
    statusCheck: false
```

## Troubleshooting

### Common Issues

1. **Configuration Not Loading**:
   ```bash
   # Check configuration syntax
   docker compose exec dashy yarn validate-config
   
   # Check file permissions
   ls -la ./user-data/
   ```

2. **Status Checks Failing**:
   ```bash
   # Test connectivity from container
   docker compose exec dashy wget -qO- http://service-url
   
   # Check network connectivity
   docker compose exec dashy nslookup service-hostname
   ```

3. **Icons Not Loading**:
   ```bash
   # Check icon cache
   docker compose exec dashy ls -la /app/public/item-icons/
   
   # Clear icon cache
   docker compose exec dashy rm -rf /app/public/item-icons/cache
   ```

4. **Performance Issues**:
   ```bash
   # Monitor resource usage
   docker stats dashy
   
   # Check container logs
   docker compose logs dashy | grep -i error
   ```

### Reset Configuration

```bash
# Backup current config
cp ./user-data/conf.yml ./conf.yml.backup

# Reset to default
docker compose down
rm ./user-data/conf.yml
docker compose up -d
```

## Security Considerations

### Network Security

- **Reverse Proxy**: Use Nginx/Traefik for SSL termination
- **Authentication**: Enable auth for public-facing instances
- **Network Isolation**: Use Docker networks for service isolation

### Configuration Security

- **Sensitive Data**: Don't store secrets in configuration
- **Access Control**: Limit file system access
- **Regular Updates**: Keep Dashy updated for security patches

## Advanced Features

### API Access

Dashy provides REST API endpoints:

```bash
# Get current config
curl http://localhost:4000/config-manager/config

# Update config
curl -X POST http://localhost:4000/config-manager/save \
  -H "Content-Type: application/json" \
  -d @new-config.json

# Rebuild app
curl -X POST http://localhost:4000/config-manager/rebuild
```

### Custom Layouts

```yaml
appConfig:
  layout: auto        # auto, horizontal, vertical, grid
  iconSize: large     # small, medium, large
  colCount: 4         # Number of columns (grid layout)
```

## Links

- [Official Documentation](https://dashy.to/docs)
- [GitHub Repository](https://github.com/Lissy93/dashy)
- [Live Demo](https://demo.dashy.to/)
- [Configuration Examples](https://gist.github.com/Lissy93/000f712a5ce98f212817d20bc16bab10)
- [Community Discussions](https://github.com/Lissy93/dashy/discussions)
- [Icon Library](https://github.com/walkxcode/dashboard-icons)

## Contributing

- [Bug Reports](https://github.com/Lissy93/dashy/issues/new?template=bug-report.yml)
- [Feature Requests](https://github.com/Lissy93/dashy/issues/new?template=feature-request.yml)
- [Contributing Guide](https://github.com/Lissy93/dashy/blob/master/docs/contributing.md)
- [Development Setup](https://github.com/Lissy93/dashy/blob/master/docs/developing.md)