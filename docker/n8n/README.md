---
name: "n8n"
category: "🏠 Smart Home Automation & Workflow"
purpose: "Workflow Automation"
description: "Fair-code licensed workflow automation tool with visual workflow builder"
icon: "🔄"
features:
  - "Visual workflow builder"
  - "300+ integrations"
  - "API and webhook support"
resource_usage: "~300MB RAM"
---

# n8n Docker Setup (Custom Image with DevOps Tools)

This Docker Compose setup provides n8n with a **custom Docker image** that includes a comprehensive set of DevOps tools and utilities. The setup uses SQLite database backend for small home lab installations. For production environments requiring better performance and concurrent access, PostgreSQL can be enabled.

## Custom Docker Image

The n8n instance runs on a custom-built Docker image based on `node:20-bookworm-slim` that includes:

### Pre-installed Tools
- **Container & Orchestration**: Docker CLI, Docker Compose, kubectl, Helm
- **Infrastructure as Code**: Terraform
- **Cloud Tools**: AWS CLI, rclone
- **Programming**: Python 3 (with pip and venv), Node.js
- **Data Processing**: jq (JSON), yq (YAML)
- **Archive Tools**: zip, unzip, tar, gzip, bzip2, xz-utils, p7zip
- **Network Utilities**: curl, wget, openssh-client, rsync, netcat, dig, ping
- **Text Editors**: vim, nano
- **System Tools**: htop, procps, git, bash, zsh

### Host Integration
The container has access to:
- **Docker Socket**: Full Docker control on the host system
- **Host Binaries**: Read-only access to `/bin`, `/usr/bin`, `/usr/local/bin`
- **Configuration Files**: SSH keys, kubeconfig, AWS credentials (read-only)
- **External Storage**: Mounted pendrive at `/home/node/pendrive`

This allows n8n workflows to execute complex automation tasks, manage containers, deploy to Kubernetes, provision infrastructure, and interact with cloud services.

## Database Options

### Default: SQLite (Recommended for Home Lab)
- **Pros**: Simple, lightweight, no additional services needed
- **Cons**: Limited concurrent access, not suitable for heavy production use
- **Use case**: Small home lab, personal automation, learning/testing

### Optional: PostgreSQL (For Production/Heavy Usage)
- **Pros**: Better performance, concurrent access, production-grade reliability
- **Cons**: More complex setup, additional resource usage
- **Use case**: Production deployments, team usage, high-throughput workflows

## Quick Start

### Using the Setup Script (Recommended)

The `setup.sh` script is a unified tool for both initial setup and ongoing management of n8n.

1. **Initial setup (first time):**
   ```bash
   ./setup.sh
   # or explicitly:
   ./setup.sh setup
   ```
   This will automatically configure and start n8n with health checks and status verification.

2. **Management commands:**
   ```bash
   ./setup.sh start      # Start n8n
   ./setup.sh stop       # Stop n8n
   ./setup.sh restart    # Restart n8n
   ./setup.sh logs       # View logs
   ./setup.sh shell      # Open shell in container
   ./setup.sh test       # Test tool availability
   ./setup.sh status     # Show container status
   ./setup.sh backup     # Backup n8n data
   ./setup.sh update     # Update n8n (rebuilds custom image)
   ./setup.sh rebuild    # Rebuild image from scratch
   ```

### Manual Setup

1. **Start the services:**
   ```bash
   docker compose up -d
   ```

2. **Access n8n:**
   - URL: http://YOUR_HOST_IP:5678 (setup script will show the exact URL)
   - Username: admin
   - Password: admin123

3. **Stop the services:**
   ```bash
   docker compose down
   ```

## Configuration

### Environment Variables

Edit the `.env` file to customize:
- n8n authentication
- Port settings
- Timezone
- Optional PostgreSQL settings (if upgrading to PostgreSQL)

### Switching to PostgreSQL (Optional)

If you need PostgreSQL for production use:

1. **Uncomment the PostgreSQL service** in `docker-compose.yml`
2. **Uncomment PostgreSQL environment variables** in `docker-compose.yml`
3. **Uncomment PostgreSQL variables** in `.env.example` and configure them in `.env`
4. **Uncomment the depends_on section** in the n8n service
5. **Restart the services**

### Data Persistence

Data is stored in local directories:
- `./n8n_data/` - n8n workflows, credentials, and settings (always used)
- `./postgres_data/` - PostgreSQL database files (only if using PostgreSQL)

### Security Notes

**Important for Production:**
1. Change default passwords in `.env`
2. Set a strong `N8N_ENCRYPTION_KEY`
3. Consider using HTTPS (set `N8N_PROTOCOL=https`)
4. Use proper firewall rules

## Useful Commands

### Using setup.sh (Recommended)
```bash
# View logs
./setup.sh logs

# Restart services
./setup.sh restart

# Update n8n (rebuilds custom image with latest n8n)
./setup.sh update

# Test installed tools
./setup.sh test

# Backup data
./setup.sh backup

# Open shell in container
./setup.sh shell
```

### Using Docker Compose Directly
```bash
# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f n8n
# docker compose logs -f postgres  # Only if using PostgreSQL

# Restart services
docker compose restart

# Rebuild custom image
docker compose build --no-cache
docker compose up -d

# Backup data (SQLite - default)
# n8n data is automatically backed up in ./n8n_data/
tar czf n8n-backup.tar.gz n8n_data/

# Backup database (only if using PostgreSQL)
# docker compose exec postgres pg_dump -U n8n n8n > backup.sql

# Restore database (only if using PostgreSQL)
# docker compose exec -T postgres psql -U n8n n8n < backup.sql
```

## Troubleshooting

1. **Permission issues:** Ensure Docker has access to the volume directories
2. **Port conflicts:** Change ports in `.env` if 5678 is in use
3. **Database connection:** If using PostgreSQL, check PostgreSQL health with `docker-compose ps`

## Volumes

- n8n data: `./n8n_data` (always used - contains workflows, credentials, SQLite database)
- PostgreSQL data: `./postgres_data` (only if using PostgreSQL)

Both directories are created automatically and use the current directory structure.