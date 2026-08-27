---
name: "PostgreSQL"
category: "🗄️ Databases"
purpose: "Relational Database"
description: "Shared Postgres 15 instance for cluster apps, tuned for the Pi's memory budget. Exposed on the LAN via LoadBalancer and provisioned per-app with isolated roles and databases."
icon: "🐘"
namespace: "databases"
external_port: "5432"
components:
  - deployment
  - service
  - pvc
  - sealedsecret
  - configmap
features:
  - "Postgres 15 with Pi-tuned postgresql.conf"
  - "Per-app isolated roles + databases via db-user.sh"
  - "PUBLIC connect revoked on template1 by default"
  - "LoadBalancer access from the LAN on 5432"
  - "pg_isready liveness + readiness probes"
  - "Retained hostPath PV — survives cluster rebuilds"
resource_usage: "~150MB RAM"
---

# PostgreSQL — Relational Database

The cluster's primary SQL database. Runs as a single-replica `Deployment` with a **retained** hostPath PV, so a `k3s` rebuild or `teardown` never destroys the data directory.

Currently backs **Forgejo**; new apps get their own role + database rather than sharing one.

## Features

- **Postgres 15**, config file mounted from a ConfigMap and passed via `-c config_file=`
- **Pi-tuned memory**: `shared_buffers 64MB`, `effective_cache_size 256MB`, `work_mem 4MB`, `max_connections 50`
- **Slow-query logging** at `log_min_duration_statement = 1000` (1s)
- **Locked-down defaults**: `REVOKE CONNECT ON DATABASE template1 FROM PUBLIC` — new roles can't reach other apps' databases
- **Runs unprivileged** as uid/gid `999` with `fsGroup: 999`
- **`homelab-infra` priority class** — evicted after ordinary apps, not before

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `postgres` | Deployment | Single replica, `Recreate` strategy |
| `postgres` | Service (LoadBalancer) | TCP `5432`, reachable on the LAN |
| `postgres-pv` / `postgres-pvc` | PV + PVC (20Gi) | `PGDATA` at `/var/lib/postgresql/data/pgdata` |
| `postgres-init` | ConfigMap | `postgresql.conf` + `01-init.sql` bootstrap |
| `postgres-secret` | SealedSecret | `POSTGRES_PASSWORD` (superuser) |

The PV is `Retain` with hostPath `/home/pi/k3s-volumes/databases/postgres`.

## Connecting

```bash
cd k3s/databases/postgres
./setup.sh connection-string            # LAN / external
./setup.sh connection-string internal   # in-cluster
```

In-cluster apps should use the cluster DNS name:

```
postgres.databases.svc.cluster.local:5432
```

## Provisioning an app

Never hand an app the superuser password. Create a scoped role instead:

```bash
cd k3s/scripts
./db-user.sh postgres create myapp 'SecurePass123!' myapp_dev,myapp_staging
./db-user.sh postgres list
./db-user.sh postgres delete myapp
```

This creates the role, creates each named database, and revokes public connect on them.

## Quick Start

```bash
cd k3s/databases/postgres
# put POSTGRES_PASSWORD in secret.yaml first, then:
./setup.sh seal
./setup.sh deploy
./setup.sh status
```

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | postgres:15, uid 999, custom config file, `pg_isready` probes |
| `service.yaml` | LoadBalancer on TCP `5432` |
| `pvc.yaml` | `Retain` hostPath PV + 20Gi PVC |
| `configmap.yaml` | `postgresql.conf` (Pi tuning) and `01-init.sql` |
| `sealedsecret.yaml` | Sealed `POSTGRES_PASSWORD` |

> `secret.yaml` is git-ignored — keep it locally for re-sealing, never commit it.

## Backup & Restore

```bash
./setup.sh dump backup.sql.gz        # logical backup
./setup.sh restore backup.sql.gz     # restore from one
./setup.sh detach-storage            # scale to 0, PVC/PV preserved
./setup.sh attach-storage            # scale back up
```

Physical backups of the hostPath directory are handled by **Backrest**; take a logical dump before any Postgres major-version bump, since `PGDATA` is not forward-compatible.

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh shell                # sh inside the pod (then: psql -U postgres)
./setup.sh restart
./setup.sh pvc
./setup.sh resources            # kubectl top + configured limits
./setup.sh seal
./setup.sh teardown             # PVC/PV retained
./setup.sh teardown --purge     # DESTROYS the data directory
```

## Troubleshooting

- **`FATAL: password authentication failed`** → the SealedSecret was re-sealed with a new key but `PGDATA` still holds the old password. Postgres only reads `POSTGRES_PASSWORD` on *first* init; change it with `ALTER USER postgres PASSWORD '…';` instead.
- **Pod `Pending`** → the PV is `Retain` and bound to a previous claim. Check `kubectl get pv postgres-pv` and clear a stale `claimRef` if needed.
- **`too many connections`** → `max_connections` is 50 by design on the Pi. Add pooling in the app rather than raising it.
- **`OOMKilled`** → the 384Mi limit is tight for large joins; lower `work_mem` or raise the limit in `deployment.yaml`.
- **Slow queries after a restore** → run `ANALYZE;` — statistics aren't included in a logical dump.

## Links

- [PostgreSQL 15 Docs](https://www.postgresql.org/docs/15/index.html)
- [Server configuration reference](https://www.postgresql.org/docs/15/runtime-config.html)
- [Official Docker image](https://hub.docker.com/_/postgres)
