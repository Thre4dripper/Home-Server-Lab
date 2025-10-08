# Gitea Integration Guide

## Home Server Lab Services Integration

This Gitea setup is designed to work seamlessly with other services in your Home Server Lab:

### Current Services
1. **Pi-hole DNS** (Port 5300) - DNS filtering and resolution
2. **n8n Workflows** (Port 5678) - Automation and workflows  
3. **Pydio Cells** (Port 8081) - File sharing and collaboration
4. **Gitea Git Service** (Port 3000) - Git repository hosting ← **You are here**

### Network Architecture
All services share the `pi-services` Docker network for:
- Internal communication between services
- Shared network namespace
- Simplified reverse proxy configuration

### Integration Examples

#### 1. DNS Resolution (Pi-hole)
Configure custom DNS entries in Pi-hole for clean URLs:
```
192.168.0.108  git.homelab.local
192.168.0.108  files.homelab.local  
192.168.0.108  automation.homelab.local
```

#### 2. Automation Workflows (n8n)
Create n8n workflows that respond to Gitea webhooks:
- Automatic deployments on git push
- Notification systems for new issues/PRs
- Backup automation for repositories

#### 3. File Integration (Pydio)
Share build artifacts and documentation:
- Store repository archives in Pydio
- Share large files that can't go in Git
- Collaborative documentation editing

#### 4. Reverse Proxy Setup
Configure Nginx to serve all services under one domain:
```nginx
# Gitea
server {
    listen 443 ssl;
    server_name git.yourdomain.com;
    location / {
        proxy_pass http://127.0.0.1:3000;
        # ... SSL and proxy headers
    }
}

# n8n
server {
    listen 443 ssl;
    server_name automation.yourdomain.com;
    location / {
        proxy_pass http://127.0.0.1:5678;
        # ... SSL and proxy headers
    }
}

# Pydio
server {
    listen 443 ssl;
    server_name files.yourdomain.com;
    location / {
        proxy_pass http://127.0.0.1:8081;
        # ... SSL and proxy headers
    }
}
```

### Port Summary
- **Pi-hole**: 5300 (HTTP admin)
- **n8n**: 5678 (HTTP interface)
- **Pydio**: 8081 (HTTP interface)
- **Gitea**: 3000 (HTTP), 222 (SSH)

### Next Steps
After setting up Gitea, consider:
1. Configuring automated backups to Pydio
2. Setting up n8n workflows for CI/CD
3. Creating a unified reverse proxy with Let's Encrypt SSL
4. Implementing monitoring and alerting across all services