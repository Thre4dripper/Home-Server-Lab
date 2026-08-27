---
name: "MySQL"
category: "🗄️ Databases"
purpose: "Relational Database (parked)"
description: "MySQL 8.0 manifests kept ready but deliberately not running — Postgres is the cluster's SQL database. The Deployment is paused, has no PVC, and is intentionally left out of the ArgoCD ApplicationSet."
icon: "🐬"
namespace: "databases"
components:
  - deployment
  - service
  - configmap
  - sealedsecret
features:
  - "PARKED — not deployed, not GitOps-managed"
  - "MySQL 8.0 with Pi-tuned innodb settings"
  - "Per-app users + databases via db-user.sh"
  - "ClusterIP only — no LAN exposure"
  - "mysqladmin ping liveness + SELECT 1 readiness"
  - "Ready to activate if a MySQL-only app appears"
resource_usage: "~250MB RAM (when running)"
---

# MySQL — Relational Database *(parked)*

> [!IMPORTANT]
> **This database is intentionally not running.** [PostgreSQL](../postgres/) is the cluster's SQL engine; MySQL is kept here only so a MySQL-only app can be brought up without starting from scratch. Nothing in the homelab depends on it today.

Three things deliberately keep it dormant:

| Guard | Where | Effect |
|-------|-------|--------|
| `paused: true` | `deployment.yaml` | The Deployment controller creates no ReplicaSet — no pod is scheduled |
| No `pvc.yaml` | this directory | `deployment.yaml` references `mysql-pvc`, which does not exist |
| Absent from the ApplicationSet | `k3s/infra/argocd/applicationset.yaml` | ArgoCD does not manage or sync this path (a commented-out entry marks the spot) |

Leave all three in place unless you actually intend to run MySQL.

## Features

- **MySQL 8.0**, unprivileged as uid/gid `999`
- **Pi-tuned** — `innodb_buffer_pool_size 128M`, `innodb_redo_log_capacity 64M`, `max_connections 50`, `performance_schema OFF`
- **`skip-name-resolve`** and `skip_ssl` — no reverse DNS, no in-cluster TLS overhead
- **ClusterIP only** — never published to the LAN
- **Health probes** — `mysqladmin ping` liveness, `SELECT 1` readiness

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `mysql` | Deployment | **Paused**, single replica, `Recreate` strategy |
| `mysql` | Service (ClusterIP) | TCP `3306`, in-cluster only |
| `mysql-init` | ConfigMap | `03-mysql-tuning.cnf`, mounted into `/etc/mysql/conf.d/` |
| `mysql-secret` | SealedSecret | `MYSQL_ROOT_PASSWORD` |
| `mysql-pvc` | **missing** | Referenced by the Deployment; must be created to activate |

## Activating it

Only if you genuinely need MySQL:

1. **Create a PVC** — copy `../postgres/pvc.yaml`, rename to `mysql-pv` / `mysql-pvc`, and point the hostPath at `/home/pi/k3s-volumes/databases/mysql`.
2. **Seal the root password**:
   ```bash
   cd k3s/databases/mysql
   # set MYSQL_ROOT_PASSWORD in secret.yaml, then:
   ./setup.sh seal
   ```
3. **Unpause** — remove `paused: true` from `deployment.yaml`.
4. **Deploy**:
   ```bash
   kubectl apply -f pvc.yaml
   ./setup.sh deploy
   ./setup.sh status
   ```
5. **Optionally** uncomment the `mysql` entry in `k3s/infra/argocd/applicationset.yaml` to hand it to GitOps.

Budget for it first: ~250MB of an 8GB box already running Postgres, Mongo and Redis.

## Provisioning an app

```bash
cd k3s/scripts
./db-user.sh mysql create myapp 'SecurePass123!' myapp_dev,myapp_staging
./db-user.sh mysql list
./db-user.sh mysql delete myapp
```

Creates the user plus each named database and grants per-database privileges.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | mysql:8.0, uid 999, tuning mount, probes — **`paused: true`** |
| `service.yaml` | ClusterIP on TCP `3306` |
| `configmap.yaml` | `03-mysql-tuning.cnf` — innodb + connection tuning |
| `sealedsecret.yaml` | Sealed `MYSQL_ROOT_PASSWORD` |

> `secret.yaml` is git-ignored — keep it locally for re-sealing, never commit it.

## Management Commands

Once activated, the standard surface applies:

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh shell                # then: mysql -u root -p
./setup.sh restart
./setup.sh resources
./setup.sh dump backup.sql.gz
./setup.sh restore backup.sql.gz
./setup.sh detach-storage
./setup.sh teardown
```

## Troubleshooting

- **`./setup.sh deploy` reports success but no pod appears** → `paused: true` is still set. That is the intended default.
- **Pod stuck `Pending` with `persistentvolumeclaim "mysql-pvc" not found`** → step 1 of *Activating it* was skipped.
- **`Access denied for user 'root'`** → `MYSQL_ROOT_PASSWORD` is only read on first init. Change it with `ALTER USER` instead of re-sealing.
- **`OOMKilled`** → the 384Mi limit is tight for MySQL 8; drop `innodb_buffer_pool_size` or raise the limit.
- **ArgoCD shows nothing for MySQL** → correct. It is not in the ApplicationSet by design.

## Links

- [MySQL 8.0 Reference Manual](https://dev.mysql.com/doc/refman/8.0/en/)
- [InnoDB buffer pool sizing](https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool-resize.html)
- [Official Docker image](https://hub.docker.com/_/mysql)
