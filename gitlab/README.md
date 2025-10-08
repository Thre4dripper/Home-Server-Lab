# GitLab Community Edition Setup

A complete DevOps platform that enables teams to collaborate on code, deploy applications, and monitor performance - all in one place.

## 🌟 Features

- **Git Repository Management**: Full Git hosting with branches, tags, and merge requests
- **Integrated CI/CD**: Built-in continuous integration and deployment pipelines
- **Issue Tracking**: Advanced issue management with boards, milestones, and labels
- **Container Registry**: Docker image registry integrated with CI/CD
- **Package Registry**: Host packages for multiple languages (npm, Maven, PyPI, etc.)
- **Wiki & Documentation**: Built-in wiki and pages for project documentation
- **Security Scanning**: Vulnerability scanning and security dashboards
- **Project Management**: Agile planning tools with roadmaps and iterations

## 📋 Prerequisites

- Docker and Docker Compose installed
- **Minimum 2GB RAM** (4GB+ recommended for better performance)
- **Minimum 10GB disk space** (more recommended for repositories and CI/CD)
- Port 8929 (web interface) and 2424 (SSH) available
- Network access to pull Docker images

## 🚀 Quick Start

1. **Configure the installation**:
   ```bash
   cd /home/pi/Home-Server-Lab/gitlab
   nano .env  # Edit configuration as needed
   ```

2. **Run the setup script**:
   ```bash
   ./setup.sh
   ```

3. **Wait for initialization** (5-10 minutes on first startup)

4. **Access GitLab**:
   - **URL**: http://192.168.0.108:8929
   - **Username**: `root` (GitLab's default admin - this is hardcoded)
   - **Password**: `ABC123xyz@` (as set in .env file)

**Why "root"?** GitLab follows Unix conventions and always creates `root` as the initial administrator account.

## ⚙️ Configuration

### Environment Variables (.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `GITLAB_DOMAIN` | Server domain/IP | `192.168.0.108` |
| `GITLAB_HOSTNAME` | Internal hostname | `gitlab.local` |
| `GITLAB_PORT` | Web interface port | `8929` |
| `GITLAB_SSH_PORT` | SSH port for Git operations | `2424` |
| `GITLAB_ROOT_PASSWORD` | Initial root password | `GitLabAdmin123!` |

### Network Configuration

GitLab runs on its own isolated Docker network for security and performance.

## 📁 Directory Structure

```
gitlab/
├── docker-compose.yml    # Service definition
├── .env                  # Configuration variables
├── .env.example         # Configuration template
├── setup.sh             # Automated setup script
├── README.md            # This documentation
├── .gitignore           # Git ignore rules
├── config/              # GitLab configuration (created on first run)
├── logs/                # GitLab logs (created on first run)
├── data/                # GitLab data (created on first run)
└── backups/             # GitLab backups (created on first run)
```

## 🔧 Management

### Starting Services
```bash
docker compose up -d
```

### Stopping Services
```bash
docker compose down
```

### Viewing Logs
```bash
# All logs
docker compose logs -f

# Specific timeframe
docker compose logs --since="1h" gitlab
```

### Updating GitLab
```bash
# Always backup first!
docker compose exec gitlab gitlab-backup create

# Update GitLab
docker compose pull
docker compose up -d
```

### Creating Backups
```bash
# Manual backup
docker compose exec gitlab gitlab-backup create

# List backups
docker compose exec gitlab gitlab-backup list

# Restore backup (replace TIMESTAMP with actual backup timestamp)
docker compose exec gitlab gitlab-backup restore BACKUP=TIMESTAMP
```

## 🌐 Access Methods

### Web Interface
- **URL**: http://192.168.0.108:8929
- **Initial Login**: Username `root` with password from .env file
- **Features**: Full GitLab web interface with all features

### Git Operations via HTTPS
```bash
# Clone repository
git clone http://192.168.0.108:8929/username/project.git

# Set remote
git remote add origin http://192.168.0.108:8929/username/project.git
```

### Git Operations via SSH
```bash
# Clone repository
git clone ssh://git@192.168.0.108:2424/username/project.git

# Set remote
git remote add origin ssh://git@192.168.0.108:2424/username/project.git
```

### API Access
```bash
# Get project list
curl -H "PRIVATE-TOKEN: your_token" \
     "http://192.168.0.108:8929/api/v4/projects"

# Create project
curl -X POST -H "PRIVATE-TOKEN: your_token" \
     -H "Content-Type: application/json" \
     -d '{"name":"new-project","description":"My new project"}' \
     "http://192.168.0.108:8929/api/v4/projects"
```

## 🛡️ Security Considerations

### Default Security Settings
- Root password required for initial access
- User registration disabled by default
- Group creation restricted to administrators
- Username changes disabled for security

### Production Recommendations
1. **Change Default Passwords**: Update root password immediately
2. **Enable HTTPS**: Configure SSL certificates (use reverse proxy)
3. **Configure SMTP**: Set up email notifications
4. **Set Up Runners**: Configure CI/CD runners on separate machines
5. **Regular Backups**: Implement automated backup strategy
6. **User Management**: Create individual user accounts, disable root for daily use
7. **Two-Factor Authentication**: Enable 2FA for all users

## 🔗 CI/CD Integration

### GitLab Runner Setup
```bash
# Register a runner (run on a separate machine)
docker run --rm -it -v gitlab-runner-config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest register \
  --url http://192.168.0.108:8929 \
  --registration-token YOUR_REGISTRATION_TOKEN
```

### Example .gitlab-ci.yml
```yaml
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - echo "Building application..."
    - docker build -t myapp .

test:
  stage: test
  script:
    - echo "Running tests..."
    - docker run myapp npm test

deploy:
  stage: deploy
  script:
    - echo "Deploying application..."
  only:
    - main
```

## 📊 Health Monitoring

### Service Health Checks
GitLab includes comprehensive health monitoring:
- **Health endpoint**: `http://192.168.0.108:8929/-/health`
- **Readiness check**: `http://192.168.0.108:8929/-/readiness`
- **Metrics**: `http://192.168.0.108:8929/-/metrics`

### Monitoring Commands
```bash
# Check container status
docker compose ps

# Check GitLab health
curl http://192.168.0.108:8929/-/health

# Monitor resource usage
docker stats gitlab-server

# Check GitLab services
docker compose exec gitlab gitlab-ctl status
```

## 🐛 Troubleshooting

### Common Issues

#### GitLab Won't Start
```bash
# Check available RAM
free -h

# Check logs for errors
docker compose logs gitlab

# Common solution: increase shared memory
# Edit docker-compose.yml: shm_size: '512m'
```

#### 502 Bad Gateway Errors
```bash
# This is normal during startup - wait 5-10 minutes
# Check initialization progress
docker compose logs -f gitlab

# Force reconfigure if needed
docker compose exec gitlab gitlab-ctl reconfigure
```

#### Permission Issues
```bash
# Fix GitLab data permissions
sudo chown -R 998:998 config logs data backups
```

#### Out of Memory Issues
```bash
# Reduce GitLab memory usage (add to GITLAB_OMNIBUS_CONFIG)
unicorn['worker_processes'] = 2
sidekiq['max_concurrency'] = 5
postgresql['shared_buffers'] = "128MB"
```

#### SSH Access Issues
```bash
# Check SSH port
netstat -tulpn | grep 2424

# Test SSH connectivity
ssh -T git@192.168.0.108 -p 2424
```

### Reset Installation
```bash
# Stop GitLab
docker compose down

# Remove all data (WARNING: destroys everything)
sudo rm -rf config logs data backups

# Restart setup
./setup.sh
```

## 🎯 Performance Optimization

### For Raspberry Pi / Low-Resource Systems
Add these to your GITLAB_OMNIBUS_CONFIG in docker-compose.yml:

```ruby
# Reduce worker processes
unicorn['worker_processes'] = 2
sidekiq['max_concurrency'] = 5

# Reduce database resources
postgresql['shared_buffers'] = "128MB"
postgresql['effective_cache_size'] = "512MB"

# Disable unused features
gitlab_rails['gitlab_email_enabled'] = false
mattermost['enable'] = false
registry['enable'] = false
```

## 📚 Additional Resources

- [GitLab Official Documentation](https://docs.gitlab.com/)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab API Documentation](https://docs.gitlab.com/ee/api/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [Docker Configuration](https://docs.gitlab.com/ee/install/docker.html)

## 🤝 Support

For issues specific to this setup:
1. Check the troubleshooting section above
2. Review Docker logs: `docker compose logs -f`
3. Verify configuration in `.env` file
4. Ensure system meets minimum requirements (2GB RAM, 10GB disk)

For GitLab-specific issues, consult the [official documentation](https://docs.gitlab.com/) or [community forum](https://forum.gitlab.com/).