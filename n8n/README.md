# n8n with PostgreSQL Docker Setup

This Docker Compose setup provides n8n with PostgreSQL database backend.

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
- Database credentials
- n8n authentication
- Port settings
- Timezone

### Data Persistence

Data is stored in local directories:
- `./postgres_data/` - PostgreSQL database files
- `./n8n_data/` - n8n workflows, credentials, and settings

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
docker-compose logs -f postgres

# Restart services
docker-compose restart

# Update to latest images
docker-compose pull
docker-compose up -d

# Backup database
docker-compose exec postgres pg_dump -U n8n n8n > backup.sql

# Restore database
docker-compose exec -T postgres psql -U n8n n8n < backup.sql
```

## Troubleshooting

1. **Permission issues:** Ensure Docker has access to the volume directories
2. **Port conflicts:** Change ports in `.env` if 5678 or 5432 are in use
3. **Database connection:** Check PostgreSQL health with `docker-compose ps`

## Volumes

- PostgreSQL data: `./postgres_data`
- n8n data: `./n8n_data`

Both directories are created automatically and use the current directory structure.