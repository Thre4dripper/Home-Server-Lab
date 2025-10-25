---
name: "n8n"
category: "🔄 Automation & Workflow"
purpose: "Workflow Automation"
description: "Fair-code licensed workflow automation tool with visual workflow builder"
icon: "🔄"
features:
  - "Visual workflow builder"
  - "300+ integrations"
  - "API and webhook support"
resource_usage: "~300MB RAM"
---

# n8n Docker Setup (SQLite for Home Lab, PostgreSQL for Production)

This Docker Compose setup provides n8n with SQLite database backend for small home lab installations. For production environments requiring better performance and concurrent access, PostgreSQL can be enabled.

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

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```
   This will automatically configure and start n8n with health checks and status verification.

### Manual Setup

1. **Start the services:**
   ```bash
   docker-compose up -d
   ```

2. **Access n8n:**
   - URL: http://YOUR_HOST_IP:5678 (setup script will show the exact URL)
   - Username: admin
   - Password: admin123

3. **Stop the services:**
   ```bash
   docker-compose down
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

```bash
# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f n8n
# docker-compose logs -f postgres  # Only if using PostgreSQL

# Restart services
docker-compose restart

# Update to latest images
docker-compose pull
docker-compose up -d

# Backup data (SQLite - default)
# n8n data is automatically backed up in ./n8n_data/

# Backup database (only if using PostgreSQL)
# docker-compose exec postgres pg_dump -U n8n n8n > backup.sql

# Restore database (only if using PostgreSQL)
# docker-compose exec -T postgres psql -U n8n n8n < backup.sql
```

## Troubleshooting

1. **Permission issues:** Ensure Docker has access to the volume directories
2. **Port conflicts:** Change ports in `.env` if 5678 is in use
3. **Database connection:** If using PostgreSQL, check PostgreSQL health with `docker-compose ps`

## Volumes

- n8n data: `./n8n_data` (always used - contains workflows, credentials, SQLite database)
- PostgreSQL data: `./postgres_data` (only if using PostgreSQL)

Both directories are created automatically and use the current directory structure.