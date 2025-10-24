---
name: "Dashdot"
category: "📊 Monitoring & Stats"
purpose: "Server Resource Monitoring"
description: "A modern server dashboard, providing real-time insights into your system's performance."
icon: "📊"
features:
  - "Real-time CPU, RAM, Storage, Network, and GPU monitoring"
  - "CPU temperature monitoring with customizable display modes"
  - "Comprehensive OS information including architecture and uptime"
  - "Network speed testing with Ookla integration"
  - "Highly customizable widgets with extensive configuration options"
  - "Lightweight and modern UI with responsive design"
resource_usage: "~50MB RAM"
---

# Dashdot - Modern Server Dashboard

Dashdot is a highly customizable, lightweight, and modern server dashboard that provides real-time insights into your system's performance, including CPU, RAM, storage, and network usage.

## Architecture

This deployment consists of a single container:
- **📊 Dashdot**: The dashboard frontend and backend for collecting system metrics.

## Features

- **✨ Real-time Monitoring**: Get live updates on your server's vital statistics.
- **🖌️ Customizable Widgets**: Arrange and configure widgets to display the information most important to you.
- **🚀 Lightweight**: Designed to be resource-efficient, perfect for home servers and Raspberry Pis.
- **📱 Responsive Design**: Access your dashboard from any device.

## Quick Start

1. **Setup Environment**:
   ```bash
   cp .env.example .env
   # Edit .env file with your configuration
   ```

2. **Start Dashdot**:
   ```bash
   ./setup.sh
   ```

3. **Access Dashboard**:
   - Local: http://localhost:8002
   - Network: http://your-server-ip:8002

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DASHDOT_PORT` | Web interface port | `3001` |
| `TIMEZONE` | Server timezone | `UTC` |
| `DASHDOT_WIDGET_LIST` | Comma-separated list of widgets to display | `os,cpu,storage,ram,network,gpu` |
| `DASHDOT_ALWAYS_SHOW_PERCENTAGES` | Always show percentages in widgets | `true` |
| `DASHDOT_OS_LABEL_LIST` | OS widget labels to display | `os,arch,up_since,dash_version` |
| `DASHDOT_SHOW_DASH_VERSION` | Show Dashdot version in OS widget | `true` |
| `DASHDOT_USE_IMPERIAL` | Use imperial units instead of metric | `false` |
| `DASHDOT_CPU_LABEL_LIST` | CPU widget labels to display | `brand,model,cores,threads,frequency` |
| `DASHDOT_ENABLE_CPU_TEMPS` | Enable CPU temperature monitoring | `true` |
| `DASHDOT_CPU_TEMPS_MODE` | CPU temperature mode (avg/max) | `avg` |
| `DASHDOT_CPU_CORES_TOGGLE_MODE` | CPU cores display mode | `toggle` |
| `DASHDOT_CPU_WIDGET_GROW` | CPU widget relative size | `4` |
| `DASHDOT_CPU_WIDGET_MIN_WIDTH` | CPU widget minimum width (px) | `500` |
| `DASHDOT_CPU_SHOWN_DATAPOINTS` | CPU graph datapoints | `20` |
| `DASHDOT_CPU_POLL_INTERVAL` | CPU polling interval (ms) | `1000` |
| `DASHDOT_STORAGE_LABEL_LIST` | Storage widget labels to display | `brand,size,type` |
| `DASHDOT_STORAGE_WIDGET_ITEMS_PER_PAGE` | Storage items per page | `3` |
| `DASHDOT_STORAGE_WIDGET_GROW` | Storage widget relative size | `3.5` |
| `DASHDOT_STORAGE_WIDGET_MIN_WIDTH` | Storage widget minimum width (px) | `500` |
| `DASHDOT_STORAGE_POLL_INTERVAL` | Storage polling interval (ms) | `60000` |
| `DASHDOT_RAM_LABEL_LIST` | RAM widget labels to display | `brand,size,type,frequency` |
| `DASHDOT_RAM_WIDGET_GROW` | RAM widget relative size | `4` |
| `DASHDOT_RAM_WIDGET_MIN_WIDTH` | RAM widget minimum width (px) | `500` |
| `DASHDOT_RAM_SHOWN_DATAPOINTS` | RAM graph datapoints | `20` |
| `DASHDOT_RAM_POLL_INTERVAL` | RAM polling interval (ms) | `1000` |
| `DASHDOT_NETWORK_LABEL_LIST` | Network widget labels to display | `type,speed_up,speed_down,interface_speed,public_ip` |
| `DASHDOT_ACCEPT_OOKLA_EULA` | Accept Ookla EULA for speed tests | `true` |
| `DASHDOT_NETWORK_SPEED_AS_BYTES` | Show network speed in bytes | `false` |
| `DASHDOT_SPEED_TEST_INTERVAL` | Speed test interval (minutes) | `240` |
| `DASHDOT_NETWORK_WIDGET_GROW` | Network widget relative size | `6` |
| `DASHDOT_NETWORK_WIDGET_MIN_WIDTH` | Network widget minimum width (px) | `500` |
| `DASHDOT_NETWORK_SHOWN_DATAPOINTS` | Network graph datapoints | `20` |
| `DASHDOT_NETWORK_POLL_INTERVAL` | Network polling interval (ms) | `1000` |
| `DASHDOT_GPU_LABEL_LIST` | GPU widget labels to display | `brand,model,memory` |
| `DASHDOT_GPU_WIDGET_GROW` | GPU widget relative size | `6` |
| `DASHDOT_GPU_WIDGET_MIN_WIDTH` | GPU widget minimum width (px) | `700` |
| `DASHDOT_GPU_SHOWN_DATAPOINTS` | GPU graph datapoints | `20` |
| `DASHDOT_GPU_POLL_INTERVAL` | GPU polling interval (ms) | `1000` |
| `MEMORY_LIMIT` | Docker memory limit for Dashdot | `128M` |
| `MEMORY_RESERVATION` | Docker memory reservation for Dashdot | `64M` |

### GPU Support

For systems with NVIDIA GPUs, you can enable GPU monitoring by using the `mauricenino/dashdot:nvidia` image and adding specific `deploy` and `environment` configurations to your `docker-compose.yml`.

Example `docker-compose.yml` snippet for GPU support:

```yaml
services:
  dashdot:
    image: mauricenino/dashdot:nvidia
    privileged: true
    deploy:
      resources:
        reservations:
          devices:
            - capabilities:
                - gpu
    environment:
      DASHDOT_WIDGET_LIST: 'os,cpu,storage,ram,network,gpu'
```

## Management Commands

```bash
# Start Dashdot
docker compose up -d

# Stop Dashdot
docker compose down

# View logs
docker compose logs -f dashdot

# Update Dashdot
docker compose pull
docker compose up -d

# Restart Dashdot
docker compose restart dashdot

# Shell access
docker compose exec dashdot /bin/bash

# Check container health
docker compose ps
```

## Troubleshooting

### Common Issues

1. **Dashboard Not Accessible**:
   ```bash
   # Check if container is running
   docker compose ps
   
   # Check logs for errors
   docker compose logs dashdot
   
   # Verify port binding
   netstat -tulpn | grep 3001
   ```

2. **Widgets Not Displaying Data**:
   - Ensure `privileged: true` is set in `docker-compose.yml`.
   - Verify the `/:/mnt/host:ro` volume mount is correct.
   - Check container logs for any permission errors.

## Links

- [Official Documentation](https://getdashdot.com/docs/installation/docker-compose)
- [GitHub Repository](https://github.com/MauriceNino/dashdot)
- [Discord Community](https://discord.gg/3teHFBNQ9W)
````