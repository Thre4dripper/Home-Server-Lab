# Netdata - Real-time System Monitoring

Netdata is a real-time performance and health monitoring system for systems and applications. It provides unparalleled insights, in real-time, of everything happening on your system and applications with stunning, interactive web dashboards and powerful performance and health alarms.

## Features

- **🔄 Real-time Monitoring**: 1-second granularity metrics
- **🚀 Zero Configuration**: Works out of the box
- **📊 Interactive Dashboards**: Beautiful web-based interface
- **🔔 Smart Alerting**: Built-in notification system
- **🐳 Container Monitoring**: Docker and Kubernetes support
- **⚡ Lightweight**: Minimal resource footprint
- **🌐 Cloud Integration**: Optional Netdata Cloud connectivity

## Quick Start

1. **Setup Environment**:
   ```bash
   cp .env.example .env
   # Edit .env file with your configuration
   ```

2. **Start Netdata**:
   ```bash
   ./setup.sh
   ```

3. **Access Dashboard**:
   - Local: http://localhost:19999
   - Network: http://192.168.0.108:19999

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NETDATA_TAG` | Docker image tag | `stable` |
| `CONTAINER_NAME` | Container name | `netdata` |
| `NETDATA_PORT` | Web interface port | `19999` |
| `PUID` | User ID for file permissions | `1000` |
| `PGID` | Group ID for file permissions | `1000` |
| `TIMEZONE` | Server timezone | `UTC` |
| `MEMORY_LIMIT` | Container memory limit | `256M` |

### Netdata Cloud Integration (Optional)

To connect your Netdata instance to Netdata Cloud for remote access:

1. Sign up at [Netdata Cloud](https://app.netdata.cloud)
2. Get your claim token from the cloud interface
3. Add it to your `.env` file:
   ```env
   NETDATA_CLAIM_TOKEN=your_claim_token_here
   NETDATA_CLAIM_ROOMS=your_room_id
   ```

## Security & Bind Mounts

### Optimized Mount Strategy

This configuration uses **minimal, security-focused** bind mounts:

#### ✅ **Essential Mounts (Read-Only)**:
```yaml
# System monitoring (required)
- /proc:/host/proc:ro              # Process information
- /sys:/host/sys:ro                # System information
- /var/run/docker.sock:/var/run/docker.sock:ro  # Docker monitoring

# System identification (minimal)
- /etc/passwd:/host/etc/passwd:ro  # User information
- /etc/group:/host/etc/group:ro    # Group information
- /etc/os-release:/host/etc/os-release:ro  # OS version
- /etc/localtime:/etc/localtime:ro # Timezone
```

#### ⚠️ **Optional Mounts**:
```yaml
# Log monitoring (can be removed if not needed)
- /var/log:/host/var/log:ro        # System logs
```

#### ❌ **Removed Dangerous Mounts**:
- `❌ /:/host/root:ro,rslave` - **REMOVED**: Full filesystem access
- `❌ /run/dbus:/run/dbus:ro` - **REMOVED**: D-Bus access (not needed)

### vs. Original Configuration

**Original Issues**:
- ❌ Full filesystem access (`/:/host/root`)
- ❌ Excessive privileges
- ❌ Unnecessary D-Bus access
- ❌ Network host mode (security risk)

**Our Improvements**:
- ✅ Isolated network with port mapping
- ✅ Minimal read-only mounts
- ✅ Only essential system access
- ✅ Proper resource limits

## Netdata vs Grafana

### When to Use Netdata
- ✅ **Real-time troubleshooting** and system monitoring
- ✅ **Immediate alerts** for system issues
- ✅ **Zero-configuration** monitoring setup
- ✅ **Lightweight** resource usage
- ✅ **Single-host** detailed monitoring

### When to Use Grafana
- ✅ **Historical data analysis** and trends
- ✅ **Custom dashboards** with multiple data sources
- ✅ **Complex visualizations** and correlations
- ✅ **Multi-service** monitoring ecosystem
- ✅ **Long-term data retention**

### Comparison Table

| Feature | Netdata | Grafana |
|---------|---------|---------|
| **Setup Complexity** | Zero-config | Requires data sources |
| **Data Granularity** | 1-second real-time | Depends on source |
| **Resource Usage** | ~50-100MB RAM | ~200-500MB RAM |
| **Dashboard Customization** | Limited | Highly customizable |
| **Data Sources** | Single host | Multiple sources |
| **Alerting** | Built-in | Requires configuration |
| **Data Retention** | Memory-based | Persistent storage |

## Management Commands

```bash
# Service management
./setup.sh                # Setup and start Netdata
./setup.sh start           # Start the service
./setup.sh stop            # Stop the service
./setup.sh restart         # Restart the service
./setup.sh status          # Show service status
./setup.sh logs            # View service logs
./setup.sh update          # Update to latest version
```

## Monitoring Capabilities

### System Metrics
- **CPU**: Per-core usage, load average, interrupts
- **Memory**: RAM usage, swap, buffers, cache
- **Storage**: Disk I/O, space usage, IOPS
- **Network**: Bandwidth, packets, errors, connections
- **Processes**: Top processes, zombies, forks

### Container Metrics
- **Docker**: Container CPU, memory, network, block I/O
- **Resource Usage**: Limits vs actual usage
- **Container Health**: Status and lifecycle events

### Application Metrics
- **Web Servers**: Apache, Nginx metrics
- **Databases**: MySQL, PostgreSQL, Redis
- **System Services**: SSH, DNS, DHCP
- **Custom Applications**: Via plugins

## Alerting and Notifications

### Built-in Alerts
Netdata comes with hundreds of pre-configured alerts:
- High CPU usage
- Memory exhaustion
- Disk space warnings
- Network anomalies
- Service failures

### Notification Methods
- **Email**: SMTP notifications
- **Slack**: Team chat integration
- **Discord**: Community notifications
- **Webhooks**: Custom integrations
- **Netdata Cloud**: Mobile app notifications

### Configuration
Edit `config/health.d/` files to customize alerts:
```bash
# View current alerts
curl -s http://localhost:19999/api/v1/alarms

# Edit alert configuration
nano config/health.d/cpu.conf
```

## Performance Optimization

### Resource Usage
- **CPU**: Typically 1-5% on idle systems
- **Memory**: 50-100MB baseline usage
- **Disk**: Minimal I/O for metrics collection
- **Network**: Low bandwidth for data collection

### Tuning Options
```yaml
# In docker-compose.yml
environment:
  # Reduce memory usage
  - NETDATA_EXTRA_DEB_PACKAGES=
  
  # Disable features if not needed
  - NETDATA_DISABLE_CLOUD=1
  
  # Adjust update frequency
  - NETDATA_UPDATE_EVERY=2  # 2-second intervals
```

## Troubleshooting

### Common Issues

1. **Permission Denied**:
   ```bash
   # Fix directory permissions
   sudo chown -R 1000:1000 config/ data/ cache/
   ```

2. **Port Conflicts**:
   ```bash
   # Check what's using port 19999
   netstat -tulpn | grep 19999
   
   # Change port in .env file
   NETDATA_PORT=20000
   ```

3. **High Memory Usage**:
   ```bash
   # Reduce memory limit
   MEMORY_LIMIT=128M
   
   # Disable some collectors
   echo "python.d = no" > config/python.d.conf
   ```

4. **Container Won't Start**:
   ```bash
   # Check logs
   ./setup.sh logs
   
   # Verify Docker permissions
   docker info
   ```

### Log Analysis
```bash
# View real-time logs
./setup.sh logs

# Check specific component logs
docker exec netdata cat /var/log/netdata/error.log

# Debug mode
docker exec netdata netdata -D
```

## Security Considerations

### Container Security
- **Non-root User**: Runs as specified PUID/PGID
- **Read-only Mounts**: All host mounts are read-only
- **Minimal Privileges**: Only required capabilities
- **Network Isolation**: Uses bridge network, not host

### Access Control
```bash
# Restrict access by IP (nginx proxy example)
# Allow only local network
allow 192.168.0.0/24;
deny all;
```

### Data Privacy
- **No Data Collection**: Metrics stay local by default
- **Optional Cloud**: Netdata Cloud is opt-in
- **Local Processing**: All analysis done locally

## Integration Examples

### With Reverse Proxy (Nginx)
```nginx
location /netdata/ {
    proxy_pass http://localhost:19999/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

### With Dashboard Integration
Add to your Dashy/Homarr configuration:
```yaml
- title: Netdata
  description: Real-time system monitoring
  icon: si-netdata
  url: http://192.168.0.108:19999
  statusCheck: true
```

### With Alertmanager
Export alerts to external systems:
```bash
# Configure webhook
echo "SEND_SLACK=\"YES\"" >> config/health_alarm_notify.conf
echo "SLACK_WEBHOOK_URL=\"your_webhook\"" >> config/health_alarm_notify.conf
```

## Links

- [Official Documentation](https://learn.netdata.cloud/)
- [GitHub Repository](https://github.com/netdata/netdata)
- [Netdata Cloud](https://app.netdata.cloud/)
- [Community Forum](https://community.netdata.cloud/)
- [Configuration Guide](https://learn.netdata.cloud/docs/configure/nodes)
- [Alert Configuration](https://learn.netdata.cloud/docs/monitor/configure-alarms)