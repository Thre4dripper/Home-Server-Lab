---
name: "Forgejo"
category: "🛠️ Development & DevOps"
purpose: "Self-hosted Git Service with CI/CD"
description: "Community-managed, self-hosted Git service with web interface and built-in Actions CI/CD"
icon: "🦋"
features:
  - "Git hosting with web interface"
  - "Pull requests and code review"
  - "Issue tracking and project management"
  - "Built-in Actions CI/CD (Forgejo Actions)"
  - "Package registry"
  - "SQLite backend (no separate DB needed)"
resource_usage: "~256MB RAM (server), ~128MB RAM (runner)"
---

# Forgejo Git Service Setup

A community-managed fork of Gitea, providing self-hosted Git service with web interface and built-in Actions CI/CD — no external CI system required.

## Features

- **Git Repository Hosting**: Full Git repository management with web interface
- **User & Organization Management**: Create users, teams, and organizations
- **Issue Tracking**: Built-in issue tracker with labels, milestones, and assignments
- **Pull Requests**: Code review workflow with merge/rebase options
- **Forgejo Actions**: Built-in CI/CD compatible with GitHub Actions workflows
- **Package Registry**: Host container images, npm, PyPI, and more
- **SSH & HTTP(S) Access**: Clone and push via SSH or HTTPS
- **SQLite Backend**: No separate database needed for small-to-medium deployments

## Prerequisites

- Docker and Docker Compose installed
- Port 3000 (web) and 2222 (SSH) available
- At least 512MB RAM and 10GB disk space recommended

## Quick Start

1. **Run the setup script** (auto-generates `.env` and starts Forgejo):
   ```bash
   cd docker/forgejo
   chmod +x setup.sh
   ./setup.sh
   ```

2. **Complete initial setup**:
   - Open: `http://<host-ip>:3000`
   - Finish the setup wizard and create an admin account

3. **Register a runner** (for CI/CD):
   - Go to: Site Admin → Actions → Runners → "Create new runner"
   - Copy the registration token
   - Add to `.env`: `FORGEJO_RUNNER_REGISTRATION_TOKEN=<token>`
   - Start runner: `docker compose up -d forgejo-runner`

## Configuration

### Environment Variables (.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `FORGEJO_DOMAIN` | Server domain or IP | `192.168.0.108` |
| `FORGEJO_PORT` | External web port | `3000` |
| `FORGEJO_HTTP_PORT` | Internal container port | `3000` |
| `FORGEJO_SSH_PORT` | External SSH port | `2222` |
| `USER_UID` | File owner UID | `1000` |
| `USER_GID` | File owner GID | `1000` |
| `FORGEJO_SECRET_KEY` | Signing secret (auto-generated) | — |
| `FORGEJO_INTERNAL_TOKEN` | Internal API token (auto-generated) | — |
| `FORGEJO_DISABLE_REGISTRATION` | Disable open registration | `false` |
| `FORGEJO_RUNNER_REGISTRATION_TOKEN` | Runner registration token | — |
| `FORGEJO_RUNNER_NAME` | Runner display name | `laptop-runner` |

### Runner Config (runner_config.yml)

Edit `runner_config.yml` to adjust:
- `capacity` — max concurrent CI jobs
- `options` — `--cpus` and `--memory` limits per job container

## Management

```bash
./setup.sh start    # Start all services
./setup.sh stop     # Stop all services
./setup.sh restart  # Restart all services
./setup.sh logs     # Tail logs
./setup.sh shell    # Open shell in Forgejo container
./setup.sh backup   # Create data backup
./setup.sh status   # Show container status
./setup.sh update   # Pull latest images and restart
```

## Data Storage

| Path | Contents |
|------|----------|
| `forgejo_data/` | Repositories, SQLite DB, config, avatars |
| `runner_data/` | Runner registration file, job cache |

## CI/CD Labels

The runner registers with these labels (catthehacker images, native ARM64):

| Label | Image |
|-------|-------|
| `ubuntu-latest` | `catthehacker/ubuntu:act-22.04` |
| `ubuntu-22.04` | `catthehacker/ubuntu:act-22.04` |
| `ubuntu-20.04` | `catthehacker/ubuntu:act-20.04` |
| `self-hosted` | native runner host |

## Security Notes

- `FORGEJO_SECRET_KEY` and `FORGEJO_INTERNAL_TOKEN` are auto-generated on first setup
- Keep `.env` out of version control (it's in `.gitignore`)
- After setup, set `FORGEJO_DISABLE_REGISTRATION=true` to prevent unauthorized signups
- The runner uses the host Docker socket — only trusted users should have access to this host
