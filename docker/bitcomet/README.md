---
name: "BitComet"
category: "🧲 Download Managers"
purpose: "BitTorrent Client"
description: "BitComet with web UI for managing torrent downloads remotely"
icon: "🌟"
features:
  - "Web-based UI for remote access"
  - "Long-term seeding support"
  - "Intelligent disk caching"
resource_usage: "~256MB RAM"
---

# BitComet - Docker Setup

BitComet is a BitTorrent client with a web-based interface, using the `wxhere/bitcomet-webui` Docker image.

## Features
- **Web UI** - Remote management from any browser
- **Long-term Seeding** - Efficient resource usage for seeding
- **Disk Cache** - Intelligent disk caching for performance
- **Bandwidth Control** - Upload/download speed limits

## Quick Start

```bash
./setup.sh
```

## Access

- **WebUI**: http://192.168.0.108:6080
- **Default Username**: `admin`
- **Default Password**: `admin`

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BITCOMET_VERSION` | Docker image tag | `latest` |
| `CONTAINER_NAME` | Container name | `bitcomet` |
| `BITCOMET_WEBUI_PORT` | WebUI host port | `6080` |
| `BITCOMET_BT_PORT` | BitTorrent port | `6882` |
| `WEBUI_USERNAME` | WebUI username | `admin` |
| `WEBUI_PASSWORD` | WebUI password | `admin` |
| `TIMEZONE` | Timezone | `Asia/Kolkata` |
| `DOWNLOADS_PATH` | Downloads directory | `./downloads` |

### Port Mapping

| Port | Protocol | Purpose |
|------|----------|---------|
| `6080` | TCP | WebUI |
| `6882` | TCP/UDP | BitTorrent traffic |

## Management

```bash
./setup.sh start       # Start BitComet
./setup.sh stop        # Stop BitComet
./setup.sh restart     # Restart BitComet
./setup.sh logs        # View logs
./setup.sh status      # Show status
./setup.sh update      # Update to latest version
```

## Directory Structure

```
bitcomet/
├── .env.example       # Environment template
├── .gitignore         # Git ignore rules
├── docker-compose.yml # Docker Compose config
├── README.md          # This file
├── setup.sh           # Management script
├── config/            # BitComet configuration (auto-created)
└── downloads/         # Downloaded files (auto-created)
```
