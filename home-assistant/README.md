---
name: "Home Assistant"
category: "🏠 Smart Home"
purpose: "Home Automation Platform"
description: "Open source home automation that puts local control and privacy first"
icon: "🏠"
features:
  - "Local control and privacy"
  - "1000+ integrations"
  - "Automation engine"
  - "Energy monitoring"
resource_usage: "~500MB RAM"
---

# Home Assistant Docker Setup

This Docker Compose setup provides Home Assistant for home automation in your home lab environment.

## Quick Start

### Using the Setup Script (Recommended)

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```
   This will automatically configure and start Home Assistant with health checks and status verification.

### Manual Setup

1. **Start the services:**
   ```bash
   docker-compose up -d
   ```

2. **Access Home Assistant:**
   - URL: http://YOUR_HOST_IP:8123 (setup script will show the exact URL)
   - Follow the on-screen setup wizard for initial configuration

3. **Stop the services:**
   ```bash
   docker-compose down
   ```

## Configuration

Home Assistant configuration is stored in the `./config` directory. The configuration files are created automatically during first run.

### Initial Setup
- On first access, you'll be guided through the initial setup
- Create a user account
- Configure your location and other basic settings
- Add integrations for your smart home devices

### Advanced Configuration
Edit files in `./config` for advanced customization:
- `configuration.yaml` - Main configuration file
- `automations.yaml` - Automation rules
- `scenes.yaml` - Scene definitions
- `scripts.yaml` - Script definitions

## Data Persistence

Configuration and data are stored in the local `./config` directory, which is automatically created and mounted as a Docker volume.

## Security Notes

**Important:**
1. Change default access credentials during initial setup
2. Consider enabling HTTPS for secure access
3. Use proper firewall rules to restrict access
4. Keep Home Assistant updated for security patches

## Useful Commands

```bash
# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f homeassistant

# Restart services
docker-compose restart

# Update to latest images
docker-compose pull
docker-compose up -d

# Backup configuration
# Copy ./config directory to safe location

# Restore configuration
# Copy backed up config files back to ./config
```

## Troubleshooting

1. **Permission issues:** Ensure Docker has access to the config directory
2. **Port conflicts:** Home Assistant uses network host mode, ensure port 8123 is available
3. **Hardware access:** For certain integrations (Zigbee, Z-Wave), additional USB device mounting may be needed

## Volumes

- Configuration: `./config` (contains all Home Assistant configuration and data)

The directory is created automatically and uses the current directory structure.

## Integrations

Home Assistant supports 1000+ integrations including:
- Smart lights and switches
- Climate control
- Security cameras
- Voice assistants
- Energy monitoring
- And much more

Add integrations through the web interface under Settings > Devices & Services.