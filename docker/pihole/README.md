---
name: "Pi-hole"
category: "🏡 Dashboard & Network Services"
purpose: "Network Ad Blocker"
description: "DNS-level ad blocking for network-wide protection and enhanced privacy"
icon: "🛡️"
features:
  - "Network-wide ad blocking"
  - "DNS-level filtering"
  - "Detailed query analytics"
resource_usage: "~100MB RAM"
---

# Pi-hole DNS Server Docker Setup

This Docker Compose setup provides Pi-hole DNS server with local DNS management and ad-blocking capabilities.

## Quick Start

### Using the Setup Script (Recommended)

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```
   This will automatically configure Pi-hole, set up local DNS entries, and verify the installation.

### Manual Setup

1. **Start the service:**
   ```bash
   docker compose up -d
   ```

2. **Set admin password:**
   ```bash
   docker exec pihole pihole setpassword 'your-password'
   ```

## Access Information

- **Web Interface**: http://YOUR_HOST_IP:8080/admin/
- **Admin Password**: admin123 (configurable in `.env`)
- **DNS Server**: YOUR_HOST_IP:5300 (UDP/TCP)

## Configuration

### Environment Variables

Edit the `.env` file to customize:
- `PIHOLE_IP` - Pi-hole server IP (auto-detected)
- `ROUTER_IP` - Your router IP (auto-detected)
- `NETWORK_CIDR` - Your network range (auto-detected)
- `WEBPASSWORD` - Admin interface password
- `TZ` - Timezone setting
- `DNS1` & `DNS2` - Upstream DNS servers

### Local DNS Entries

Edit the `dns-entries.conf` file to add custom local DNS mappings:

```bash
# Format: domain=ip_address
pihole.lan=192.168.0.108
n8n.lan=192.168.0.108
homeassistant.lan=192.168.0.109
nas.lan=192.168.0.110
```

**Features:**
- Domain-to-IP mapping with flexible configuration
- Comments supported (lines starting with #)
- Easy to version control and backup
- Apply changes by re-running `./setup.sh`

### Network Configuration

Pi-hole runs on **port 5300** instead of the standard port 53 to avoid conflicts with system DNS.

**To use Pi-hole as your DNS server:**
1. Set your device's DNS to your Pi-hole IP
2. Or configure your router's DHCP to use Pi-hole as DNS server

## Data Persistence

Data is stored in local directories:
- `./pihole-data/` - Pi-hole configuration, logs, and blocklists
- `./dnsmasq-data/` - DNS configuration files

## Security Notes

**Important for Production:**
1. Change the default password in `.env`
2. Use proper firewall rules (only allow DNS from local network)
3. Regularly update Pi-hole: `docker compose pull && docker compose up -d`
4. Monitor access logs for suspicious activity

## Useful Commands

```bash
# View logs
docker compose logs -f

# View Pi-hole logs specifically
docker compose logs -f pihole

# Restart Pi-hole
docker compose restart

# Update to latest Pi-hole image
docker compose pull
docker compose up -d

# Access Pi-hole CLI
docker exec pihole pihole

# Update blocklists manually
docker exec pihole pihole -g

# View current DNS queries
docker exec pihole pihole -t

# Add domain to whitelist
docker exec pihole pihole -w example.com

# Add domain to blacklist  
docker exec pihole pihole -b example.com
```

## DNS Testing

Test your Pi-hole installation:

```bash
# Test external DNS resolution
dig @YOUR_PIHOLE_IP -p 5300 google.com

# Test local DNS resolution
dig @YOUR_PIHOLE_IP -p 5300 pihole.lan

# Test from another device
nslookup google.com YOUR_PIHOLE_IP
```

## Troubleshooting

### Common Issues

1. **Web interface not accessible**
   - Check if port 8080 is available
   - Verify container is running: `docker compose ps`
   - Check logs: `docker compose logs pihole`

2. **DNS not resolving**
   - Ensure UDP port 5300 is open
   - Check if Pi-hole DNS service is running: `docker exec pihole netstat -ln | grep :53`
   - Verify your device is using Pi-hole as DNS

3. **Local domains not resolving**
   - Check `dns-entries.conf` format
   - Re-run `./setup.sh` to apply changes
   - Verify domains were added: `docker exec pihole cat /etc/pihole/pihole.toml | grep hosts`

4. **Permission issues**
   - Ensure Docker can access the volume directories
   - Check directory ownership: `ls -la pihole-data dnsmasq-data`

5. **Container won't start**
   - Check for port conflicts: `netstat -ln | grep :8080`
   - Verify environment file: `cat .env`
   - Try manual start: `docker compose up` (without -d flag)

### Port Conflicts

If you need to change ports, edit `docker-compose.yml`:
```yaml
ports:
  - "5353:53/tcp"      # Change DNS port
  - "5353:53/udp"      # Change DNS port  
  - "8081:80/tcp"      # Change web interface port
```

### Reset Configuration

To completely reset Pi-hole:
```bash
docker compose down
sudo rm -rf pihole-data dnsmasq-data
./setup.sh
```

## Advanced Configuration

### Custom Blocklists

Add custom blocklists via the web interface:
1. Go to **Group Management** → **Adlists**
2. Add your blocklist URLs
3. Update gravity: **Tools** → **Update Gravity**

### DHCP Server

Pi-hole can act as a DHCP server:
1. Disable DHCP on your router
2. Enable DHCP in Pi-hole web interface
3. Configure DHCP range and gateway

### Conditional Forwarding

For better local name resolution:
1. Go to **Settings** → **DNS**
2. Enable "Conditional forwarding"
3. Set local network details

## Monitoring

### Key Metrics to Monitor
- Query volume and blocked percentage
- Response times
- Top blocked domains
- Client activity

### Log Files
- Query log: Available in web interface
- FTL log: `docker exec pihole tail -f /var/log/pihole/FTL.log`
- Dnsmasq log: Available if logging is enabled

## Backup and Restore

### Backup Configuration
```bash
# Backup Pi-hole settings
docker exec pihole pihole -a -t

# Backup entire configuration
tar -czf pihole-backup.tar.gz pihole-data dnsmasq-data dns-entries.conf .env
```

### Restore Configuration
```bash
# Extract backup
tar -xzf pihole-backup.tar.gz

# Restart Pi-hole
docker compose down && docker compose up -d
```

## Integration

### With Other Services
- **Router**: Set Pi-hole as primary DNS in DHCP settings
- **Home Assistant**: Use local DNS entries for internal communication
- **Docker containers**: Add `dns: [YOUR_PIHOLE_IP]` to docker-compose files

### API Usage
Pi-hole provides a REST API for automation:
```bash
# Get statistics
curl "http://YOUR_PIHOLE_IP:8080/admin/api.php"

# Get query log
curl "http://YOUR_PIHOLE_IP:8080/admin/api.php?queryLog"
```

## Performance Tuning

### For High Query Volume
- Increase cache size in dnsmasq configuration
- Use SSD storage for better I/O performance
- Monitor memory usage and adjust if needed

### Network Optimization
- Place Pi-hole close to your router
- Use wired connection instead of Wi-Fi when possible
- Consider multiple Pi-hole instances for redundancy