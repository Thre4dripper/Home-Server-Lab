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
   This will:
   - Collect a hardware snapshot (network, Bluetooth, serial, USB) and suggest `/dev` mappings
   - Ensure `configuration.yaml` exists and contains a managed `http:` block for reverse proxies
   - Start Home Assistant and run the usual health checks

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

## Reverse Proxy Support

`setup.sh` keeps a managed block in `config/configuration.yaml` between the markers:

```
# --- BEGIN setup.sh managed http block ---
...
# --- END setup.sh managed http block ---
```

The block turns on `use_x_forwarded_for` and populates `trusted_proxies` with sane defaults (`127.0.0.1`, `::1`, `172.16.0.0/12`). Set the `HA_TRUSTED_PROXIES` environment variable with a comma-separated list to override or extend the defaults:

```bash
export HA_TRUSTED_PROXIES="127.0.0.1,::1,172.20.0.0/16,192.168.0.0/24"
./setup.sh
```

Every time the script runs it refreshes the managed block so your reverse proxies stay whitelisted.

## Hardware & Device Discovery

Before bringing the container up, the setup script scans the host for:

- Network interfaces (including Docker bridges)
- Bluetooth adapters and their backing drivers
- Serial / USB devices (e.g., `/dev/ttyAMA0`, `/dev/ttyUSB0`)
- Full `lsusb` output (falls back to `sudo` if required)

Detected device paths are echoed back as ready-to-copy entries for the `devices:` section in `docker-compose.yml`, making it easier to expose Zigbee/Z-Wave sticks, Bluetooth controllers, or other peripherals to Home Assistant.

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
