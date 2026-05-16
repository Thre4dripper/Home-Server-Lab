---
name: "Backrest"
category: "📊 Monitoring & Stats"
purpose: "Backup Manager UI (Restic)"
description: "Web UI for managing Restic backups of all k3s volumes, databases, and app state. Backs up to the local pendrive and optionally to S3/B2."
icon: "🗄️"
namespace: "monitoring"
external_port: "9898"
domain: "backrest.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - rbac
  - pvc
features:
  - "Restic v0.18.1 bundled — no separate install"
  - "Snapshot browser and point-in-time restore"
  - "Pre-backup hooks for MongoDB, PostgreSQL, and n8n SQLite logical dumps"
  - "Multi-repo: local pendrive + optional S3 / Backblaze B2"
  - "Retention policy enforcement (daily / weekly / monthly)"
  - "kubectl exec RBAC for in-cluster DB dumps"
resource_usage: "~128MB RAM"
---

# Backrest — Backup Manager

Web UI for [Restic](https://restic.net/) that manages all cluster backups. Backrest ships Restic internally — no separate binary needed. Even if Backrest itself is unavailable, the underlying Restic repo on the pendrive is accessible directly via the `restic` CLI.

## Architecture

| Resource | Type | Purpose |
|---|---|---|
| `backrest` | Deployment | Backrest + Restic container |
| `backrest` | Service (ClusterIP) | Web UI on port `9898` |
| `backrest` | IngressRoute | `backrest.home.ijlalahmad.dev` |
| `backrest` | ServiceAccount | Identity for kubectl exec hooks |
| `backrest-db-exec` | ClusterRole | `pods/exec` on database pods |
| `backrest-data` | PVC | Backrest config + DB dump staging at `/home/pi/k3s-volumes/apps/backrest` |

### Volume mounts

| Container path | Host path | Mode |
|---|---|---|
| `/data` | `/home/pi/k3s-volumes/apps/backrest` (PVC) | RW — config + staging |
| `/k3s-volumes` | `/home/pi/k3s-volumes` | RO — backup source |
| `/pendrive-backups` | `/home/pi/pendrive/backups` | RW — restic repo |
| `/usr/local/bin/kubectl` | `/usr/local/bin/kubectl` | RO — for hook scripts |

## What Gets Backed Up

| Source | Method | Notes |
|---|---|---|
| `/k3s-volumes/apps/*` | Restic filesystem snapshot | App configs, state, jellyfin, pihole, forgejo, etc. |
| MongoDB | `mongodump --archive --gzip` via kubectl exec | Written to `/data/db-dumps/mongo.archive.gz` |
| PostgreSQL | `pg_dumpall` via kubectl exec | Written to `/data/db-dumps/postgres.sql.gz` |
| n8n SQLite | `sqlite3 .backup` via kubectl exec | Written to `/data/db-dumps/n8n.sqlite` |
| Raw DB data dirs | **Excluded** | WiredTiger / WAL not safe to hot-copy |

## Quick Start

```bash
cd k3s/apps/backrest
./setup.sh deploy
./setup.sh status
```

Then open `https://backrest.home.ijlalahmad.dev` and follow the in-script configuration guide in `setup.sh`.

## Manifests

| File | Contents |
|---|---|
| `deployment.yaml` | Backrest container with all hostPath + PVC mounts |
| `pvc.yaml` | 1Gi PVC at `/home/pi/k3s-volumes/apps/backrest` |
| `service.yaml` | ClusterIP on port `9898` |
| `ingress.yaml` | Traefik IngressRoute (HTTPS) |
| `rbac.yaml` | ServiceAccount + ClusterRole for kubectl exec |
| `setup.sh` | UI config guide + restore CLI examples |

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh exec
./setup.sh restart
./setup.sh undeploy   # PVC retained
```

## Restore (CLI — no Backrest required)

```bash
# Install restic on any machine
apt install restic

# List snapshots
restic -r /home/pi/pendrive/backups/restic-repo snapshots

# Restore all app volumes
restic -r /home/pi/pendrive/backups/restic-repo \
  restore latest --target / --path /k3s-volumes

# Restore MongoDB
restic -r /home/pi/pendrive/backups/restic-repo \
  dump latest /data/db-dumps/mongo.archive.gz \
  | mongorestore --uri="mongodb://..." --archive --gzip

# Restore PostgreSQL
restic -r /home/pi/pendrive/backups/restic-repo \
  dump latest /data/db-dumps/postgres.sql.gz \
  | gunzip | psql -U postgres
```

## Links

- [Backrest GitHub](https://github.com/garethgeorge/backrest)
- [Restic Documentation](https://restic.readthedocs.io/)
- [Backblaze B2 pricing](https://www.backblaze.com/cloud-storage/pricing) (~$0.006/GB/month)
