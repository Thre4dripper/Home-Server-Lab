---
name: "Plex"
category: "🎬 Media & Entertainment"
purpose: "Media Server"
description: "Organizes your video, music, and photo collections and streams them to all devices"
icon: "🎬"
features:
  - "Stream personal media anywhere"
  - "Cross-platform device support"
  - "Hardware transcoding support"
resource_usage: "~1GB RAM"
---

# Plex Media Server - Raspberry Pi Docker Setup

Plex Media Server organizes your video, music, and photo collections and streams them to all of your devices. This setup is optimized for Raspberry Pi with Docker.

## Features

- **Media Streaming**: Stream your personal media collection anywhere
- **Cross-Platform**: Access from any device (phones, tablets, smart TVs, etc.)
- **Hardware Optimized**: Configured for Raspberry Pi ARM architecture
- **Auto-Discovery**: Automatic media library scanning and metadata fetching
- **Remote Access**: Access your media from anywhere (with Plex Pass)
- **Transcoding**: Real-time media transcoding for optimal playback
- **User Management**: Multiple user accounts and parental controls

## Prerequisites

- Docker and Docker Compose installed
- Sufficient storage for media files
- (Optional) Plex Pass for premium features
- Network access for initial setup

## Quick Start

1. **Setup Environment**:
   ```bash
   cp .env.example .env
   # Edit .env file with your configuration
   ```

2. **Get Plex Claim Token** (for automatic setup):
   - Visit: https://www.plex.tv/claim
   - Copy the claim token and add it to `.env` file

3. **Prepare Media Directories**:
   ```bash
   mkdir -p media/{movies,tv,music,photos}
   # Copy your media files to these directories
   ```

4. **Start Plex**:
   ```bash
   ./setup.sh
   ```

5. **Access Plex**:
   - Local: http://localhost:32400/web
   - Network: http://192.168.0.108:32400/web

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PLEX_TAG` | Docker image tag | `latest` |
| `CONTAINER_NAME` | Container name | `plex` |
| `TIMEZONE` | Server timezone | `UTC` |
| `PLEX_CLAIM_TOKEN` | Claim token from plex.tv/claim | (empty) |
| `PLEX_UID` | User ID for file permissions | `1000` |
| `PLEX_GID` | Group ID for file permissions | `1003` |
| `ADVERTISE_IP` | IP to advertise for remote access | Auto-detected |
| `ALLOWED_NETWORKS` | Networks allowed without auth | LAN ranges |
| `MEDIA_PATH` | Path to your media files | `./media` |
| `MEMORY_LIMIT` | Container memory limit | `2G` |

### Media Organization

Organize your media in the following structure:
```
media/
├── movies/
│   ├── Movie Name (Year)/
│   │   └── Movie Name (Year).mp4
├── tv/
│   ├── TV Show Name/
│   │   ├── Season 01/
│   │   │   ├── S01E01 - Episode Name.mp4
├── music/
│   ├── Artist Name/
│   │   ├── Album Name/
│   │   │   ├── 01 - Track Name.mp3
└── photos/
    ├── 2024/
    │   ├── Event Name/
```

### First Time Setup

1. **Initial Configuration**:
   - Access Plex web interface
   - Create or sign into your Plex account
   - Name your server
   - Add media libraries

2. **Library Setup**:
   - Movies: `/data/movies`
   - TV Shows: `/data/tv`
   - Music: `/data/music`
   - Photos: `/data/photos`

3. **Remote Access** (Plex Pass required):
   - Enable in Settings > Remote Access
   - Configure port forwarding if needed

## Hardware Transcoding (Plex Pass)

For Raspberry Pi 4 with hardware acceleration:

1. **Check GPU Support**:
   ```bash
   # Check if GPU is available
   ls -la /dev/dri/
   ```

2. **Enable in Plex**:
   - Settings > Server > Transcoder
   - Enable "Use hardware acceleration when available"

## Management Commands

```bash
# Start Plex
docker compose up -d

# Stop Plex
docker compose down

# View logs
docker compose logs -f plex

# Update Plex
docker compose pull
docker compose up -d

# Restart Plex
docker compose restart plex

# Shell access
docker compose exec plex /bin/bash

# Check Plex status
curl -I http://localhost:32400/identity
```

## Data Persistence

Plex data is stored in:
- `./config/` - Plex configuration and database
- `./transcode/` - Temporary transcoding files
- `./media/` - Your media files

## Network Configuration

### Host Networking
This setup uses host networking for optimal performance and easier configuration. Plex will use the following ports:

- `32400/tcp` - Main Plex port
- `8324/tcp` - Roku companion
- `32469/tcp` - DLNA discovery
- `1900/udp` - DLNA discovery
- `32410-32414/udp` - GDM network discovery

### Remote Access
For external access outside your home network:
1. Forward port 32400 in your router
2. Enable Remote Access in Plex settings
3. Use dynamic DNS if your IP changes

## Performance Optimization

### Raspberry Pi Specific
- **Memory**: Limit container memory to prevent system instability
- **Storage**: Use fast storage (SSD) for Plex database
- **Network**: Use wired connection for better streaming performance
- **Cooling**: Ensure adequate cooling for sustained transcoding

### Transcoding Settings
- Direct Play: No CPU usage (preferred)
- Direct Stream: Minimal CPU usage
- Transcode: High CPU usage (limit concurrent streams)

## Troubleshooting

### Common Issues

1. **Plex not accessible**:
   ```bash
   # Check if container is running
   docker compose ps
   
   # Check logs
   docker compose logs plex
   ```

2. **Permission issues**:
   ```bash
   # Fix ownership
   sudo chown -R 1000:1003 ./config ./media
   ```

3. **Transcoding fails**:
   ```bash
   # Check transcoding directory permissions
   ls -la ./transcode/
   ```

4. **Database corruption**:
   ```bash
   # Stop Plex
   docker compose down
   
   # Backup database
   cp -r ./config ./config.backup
   
   # Start Plex (it will rebuild if needed)
   docker compose up -d
   ```

### Health Checks

The container includes health checks to monitor Plex status:
```bash
# Check container health
docker compose ps
docker inspect plex | grep -A 10 Health
```

## Security Considerations

- **Local Network**: Configured to allow local network access
- **File Permissions**: Runs as specified user/group
- **Updates**: Regular updates recommended for security patches
- **Remote Access**: Use strong passwords and 2FA

## Performance Monitoring

Monitor Plex performance:
```bash
# Container stats
docker stats plex

# Disk usage
du -sh ./config/
du -sh ./media/

# System resources
htop
```

## Backup Strategy

### Database Backup
```bash
#!/bin/bash
# Create backup script
docker compose down
tar -czf "plex-backup-$(date +%Y%m%d).tar.gz" ./config/
docker compose up -d
```

### Media Backup
- Use external storage or cloud backup for media files
- Consider RAID for redundancy

## Upgrading

### Plex Version
```bash
# Update to latest version
docker compose pull
docker compose up -d
```

### Configuration Migration
When migrating from existing Plex installation:
1. Stop old Plex service
2. Copy existing database to `./config/`
3. Update ownership: `chown -R 1000:1003 ./config/`
4. Start Docker container

## Links

- [Official Plex Documentation](https://support.plex.tv/)
- [Plex Docker Repository](https://github.com/plexinc/pms-docker)
- [Plex Pass Features](https://www.plex.tv/plex-pass/)
- [Media Naming Guide](https://support.plex.tv/articles/naming-and-organizing-your-media-files/)

## Support

- **Plex Forums**: https://forums.plex.tv/
- **Reddit**: r/PleX
- **Discord**: Official Plex Discord server