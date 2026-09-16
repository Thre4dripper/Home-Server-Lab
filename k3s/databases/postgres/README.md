---
name: "PostgreSQL"
category: "🗄️ Databases"
purpose: "Relational Database"
description: "Shared Postgres 18 instance for cluster apps, tuned for the Pi's memory budget. Runs VectorChord's build of postgres:18 (vchord + pgvector available). Exposed on the LAN via LoadBalancer and provisioned per-app with isolated roles and databases."
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
  - "Postgres 18 with Pi-tuned postgresql.conf"
  - "Vector search: VectorChord + pgvector extensions available"
  - "Per-app isolated roles + databases via db-user.sh"
  - "PUBLIC connect revoked on template1 by default"
  - "LoadBalancer access from the LAN on 5432"
  - "pg_isready liveness + readiness probes"
  - "Retained hostPath PV — survives cluster rebuilds"
resource_usage: "~150MB RAM"
---

# PostgreSQL — Relational Database

The cluster's primary SQL database. Runs as a single-replica `Deployment` with a **retained** hostPath PV, so a `k3s` rebuild or `teardown` never destroys the data directory.

Currently backs **Forgejo**, **n8n** and **Immich**; new apps get their own role + database rather than sharing one.

## Features

- **Postgres 18** (`tensorchord/vchord-postgres` — VectorChord's build of the official postgres:18 base), config file mounted from a ConfigMap and passed via `-c config_file=`
- **Vector search**: `vchord` + `pgvector` available; preloaded via `shared_preload_libraries = 'vchord.so'`. After a vchord image bump, run `ALTER EXTENSION vchord UPDATE;` as superuser in each DB using it (immich)
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
| `deployment.yaml` | tensorchord/vchord-postgres (postgres:18 + vchord), uid 999, custom config file, `pg_isready` probes |
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

### Major upgrades (how 15 → 18 was done, 2026-09-16)

A Postgres major is **never an image bump**: the on-disk format changes and the
new binary refuses to open the old directory. It is a dump into a fresh cluster,
with the old cluster kept on disk as the rollback. `PGDATA` is a *subdirectory*
of the volume (`pgdata-<major>`), which is what makes this cheap — the old and
new directories sit side by side on the same PV.

Before starting, read every consumer's own version gate (not the docs page —
the code): n8n `postgres-version-policy.ts`, Immich `server/src/constants.ts`
(`POSTGRES_VERSION_RANGE`, `VECTORCHORD_VERSION_RANGE`), Forgejo docs. The
pickiest one sets the ceiling. Pick an image tag carrying the **same** VectorChord
version currently installed, so the extension is not a second variable.

1. Pause ArgoCD auto-sync on `postgres` and every consumer (`kubectl -n argocd
   patch application <app> --type=json -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]'`
   — the ApplicationSet ignores this field on purpose). Scale consumers to 0.
   Confirm `pg_stat_activity` shows no client backends.
2. Baseline: exact `count(*)` of every table in every database, saved to a file.
3. `pg_dumpall --clean --if-exists` **from the running pod** (`kubectl exec`,
   not `kubectl run -i`: an attached throwaway pod silently lost an entire
   database from its stream once). Verify the dump against the baseline —
   `COPY` blocks = table count, data lines = row total — and keep two copies on
   two devices.
4. In git: `image:` → new major, `PGDATA` → `…/pgdata-<major>`. Commit, push,
   `kubectl apply`. The entrypoint runs `initdb` into the empty directory.
5. `gzip -dc dump | kubectl exec -i … psql -U postgres -v ON_ERROR_STOP=0 -f -`.
   Expected errors, and only these: `current user cannot be dropped`,
   `role "postgres" already exists`. Health probes may log two FATAL
   `database "postgres" does not exist` in the second `--clean` recreates it.
6. Verify: re-run the row counts and `diff` against the baseline (must be
   empty); extensions per DB at the expected versions; VectorChord indexes
   present (`pg_indexes … vchordrq`) and used (`set vchordrq.probes = 1;
   explain …` shows `Index Scan using clip_index`); roles have password hashes.
   Then `vacuumdb --all --analyze-in-stages` — a restore carries no statistics.
7. Consumers back one at a time, Immich last (its startup refuses out-of-range
   Postgres/VectorChord). Check each log, then re-enable auto-sync.
8. Leave the old `pgdata-<old>/` and the dumps in place until the new major has
   run for a while. Prune deliberately, later, by hand.

Rollback at any point before step 8: revert the two lines from step 4 and
re-apply — the old directory was never opened by the new binary.

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
- **`OOMKilled`** → the 512Mi limit is tight for large joins; lower `work_mem` or raise the limit in `deployment.yaml`.
- **Slow queries after a restore** → run `ANALYZE;` — statistics aren't included in a logical dump.

## Links

- [PostgreSQL 18 Docs](https://www.postgresql.org/docs/18/index.html)
- [Server configuration reference](https://www.postgresql.org/docs/15/runtime-config.html)
- [Official Docker image](https://hub.docker.com/_/postgres)
