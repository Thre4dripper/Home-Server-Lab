---
name: "Aria2"
category: "🧲 Download Managers"
purpose: "Multi-Protocol Download Manager"
description: "Lightweight, multi-protocol download utility with web UI"
icon: "⬇️"
features:
  - "HTTP/HTTPS/FTP/BitTorrent/Metalink support"
  - "Web UI (AriaNg)"
  - "RPC interface for automation"
resource_usage: "~100MB RAM"
---

# Aria2 Multi-Protocol Download Manager Docker Setup

This Docker Compose setup provides Aria2, a lightweight and powerful multi-protocol download utility with AriaNg web interface, perfect for your home server downloading needs.

## Features
- **Multi-Protocol Support** - HTTP, HTTPS, FTP, BitTorrent, Metalink
- **Web UI** - AriaNg interface for easy management
- **RPC Interface** - For external tools and automation
- **Resume Downloads** - Continue interrupted downloads
- **High Speed** - Optimized for performance
- **Lightweight** - Low resource usage

## Prerequisites
- Docker and Docker Compose installed
- Sufficient storage for downloads
- Optional: VPN for privacy

## Quick Start

### Using the Setup Script (Recommended)

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```
   This will automatically configure Aria2, create necessary directories, and start the service with health checks.

### Manual Setup

1. **Prepare directories:**
   ```bash
   mkdir -p config downloads
   ```

2. **Configure environment (optional):**
   ```bash
   cp .env.example .env
   # Edit .env as needed
   ```

3. **Start the service:**
   ```bash
   docker compose up -d
   ```

4. **Access the web interface:**
   - Open your browser and navigate to `http://YOUR_HOST_IP:8080`

## Access Information

- **Web Interface**: http://YOUR_HOST_IP:8080
- **RPC Interface**: localhost:6800 (for external tools)
- **No authentication by default** (set RPC_SECRET for security)

## Configuration

### Environment Variables

Edit the `.env` file to customize:
- `WEBUI_PORT` - Port for web interface (default: 8080)
- `RPC_SECRET` - Secret for RPC authentication
- `PUID/PGID` - User/group IDs for file permissions
- `DOWNLOADS_PATH` - Path for downloaded files
- `CONFIG_PATH` - Path for configuration files

### Security Notes

**Important:**
1. Set a strong `RPC_SECRET` in `.env` for RPC access
2. Consider restricting access to the web UI port
3. Use proper firewall rules

## Data Persistence

- **Downloads**: Stored in `./downloads` directory
- **Configuration**: Stored in `./config` directory

## Useful Commands

```bash
# View logs
docker compose logs -f

# Restart service
docker compose restart

# Update to latest image
docker compose pull && docker compose up -d

# Stop service
docker compose down
```

## Troubleshooting

### AriaNg Connection Issues

If AriaNg disconnects from aria2 or you see "Aria2 RPC server error":

**The setup script now handles this automatically!** Just run:
```bash
./setup.sh
```

The script will:
- Preserve your existing .env and RPC secret
- Initialize config files properly without deleting them
- Ensure aria2.conf doesn't have hardcoded secrets
- Set up proper session file permissions
- Configure AriaNg based on your ARIA2RPCPORT setting

**Understanding ARIA2RPCPORT:**
- This tells AriaNg what port to use when connecting to aria2 RPC
- For **reverse proxy with HTTPS**: set to `443` (or your proxy port)
- For **reverse proxy with HTTP**: set to `80` (or your proxy port)
- For **direct access**: set to `6800` (aria2's default port)
- **Note**: aria2 inside the container always runs on port 6800

**Manual Connection Setup (if needed):**

For **Reverse Proxy** (ARIA2RPCPORT=443):
1. Open AriaNg Web UI
2. Go to: **AriaNg Settings → RPC**
3. Set:
   - **Aria2 RPC Address**: `https://your-domain.com:443/jsonrpc`
   - **Aria2 RPC Secret Token**: Check your `.env` file for `RPC_SECRET` value
4. Click "Reload AriaNg"

For **Direct Access** (ARIA2RPCPORT=6800):
1. Open AriaNg Web UI
2. Go to: **AriaNg Settings → RPC**
3. Set:
   - **Aria2 RPC Address**: `http://localhost:6800/jsonrpc`
   - **Aria2 RPC Secret Token**: Check your `.env` file for `RPC_SECRET` value
4. Click "Reload AriaNg"

**Auto-Configuration Option:**
Set `EMBED_RPC_SECRET=true` in `.env` to automatically configure AriaNg with your RPC secret (only use with proper authentication like basic auth, as the secret will be visible in the web UI code).

**Common Issues:**
- **"Connection failed"**: Make sure RPC secret in AriaNg matches the one in `.env`
- **After restart, connection lost**: The RPC secret must match between `.env` and AriaNg settings
- **Permission issues**: Ensure PUID/PGID match your host user
- **Port conflicts**: Change WEBUI_PORT if 8080 is in use
- **Behind reverse proxy not working**: Ensure your proxy forwards WebSocket connections to port 6800

## RPC Integration

Aria2 provides an RPC interface for automation:
- Use tools like `aria2c` command-line client
- Integrate with scripts or other applications
- Access via HTTP JSON-RPC on port 6800

## Volumes

- `./downloads` - Download directory
- `./config` - Configuration and session data

# Aria2 Docker Setup

This Docker Compose setup provides Aria2 with AriaNg web interface for managing downloads in your home lab environment.

## Features

Aria2 supports downloading from multiple protocols:
- HTTP/HTTPS
- FTP
- BitTorrent
- Metalink
- And more

## Quick Start

### Using the Setup Script (Recommended)

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```
   This will automatically configure and start Aria2 with health checks and status verification.

### Manual Setup

1. **Start the services:**
   ```bash
   docker-compose up -d
   ```

2. **Access AriaNg:**
   - URL: http://YOUR_HOST_IP:8080 (setup script will show the exact URL)
   - No authentication by default (configure RPC_SECRET for security)

3. **Stop the services:**
   ```bash
   docker-compose down
   ```

## Configuration

### Environment Variables

Edit the `.env` file to customize:
- Web UI port
- RPC secret for security
- User/group IDs for permissions
- Download and config paths

### Security Notes

**Important for Security:**
1. Set a strong `RPC_SECRET` in `.env`
2. Consider restricting access to the web UI port
3. Use proper firewall rules

## Data Persistence

Downloads are stored in the local `./downloads` directory, and configuration in `./config`.

## Useful Commands

```bash
# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f ariang

# Restart services
docker-compose restart

# Update to latest images
docker-compose pull
docker-compose up -d

# Backup data
# Copy ./downloads and ./config directories to safe location

# Restore data
# Copy backed up directories back
```

## Troubleshooting

1. **Permission issues:** Ensure PUID/PGID match your host user
2. **Port conflicts:** Change WEBUI_PORT if 8080 is in use
3. **Download failures:** Check network connectivity and firewall settings

## Volumes

- Downloads: `./downloads` (contains all downloaded files)
- Config: `./config` (contains Aria2 configuration and session data)

Both directories are created automatically and use the current directory structure.

## RPC Interface

Aria2 provides an RPC interface on port 6800 for external tools and automation. Use the RPC_SECRET for authentication.

## Integration

Aria2 can be integrated with other tools via RPC:
- Web UIs like AriaNg
- Command-line tools
- Custom scripts
- Other download managers

## Help & Resources

- [Aria2 Official Website](https://aria2.github.io/)
- [Aria2 GitHub Repository](https://github.com/aria2/aria2)
- [AriaNg Web UI](https://github.com/mayswind/AriaNg)
- [Docker Image](https://hub.docker.com/r/hurlenko/aria2-ariang)