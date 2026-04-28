---
name: "Databases"
category: "🗄️ Databases"
purpose: "Shared Stateful Data Stores"
description: "Bundle of PostgreSQL, MySQL, MongoDB and Redis StatefulSets shared by every other workload in the cluster (n8n, Home Assistant, Homarr, BitComet, etc) — exposed only via in-cluster DNS."
icon: "🗄️"
namespace: "databases"
external_port: "—"
domain: "—"
components:
  - statefulset
  - service
  - sealedsecret
  - pvc
features:
  - "PostgreSQL, MySQL, MongoDB, Redis in one namespace"
  - "StatefulSets with stable network identities"
  - "Per-engine PVCs for durability"
  - "Credentials managed via SealedSecrets"
  - "ClusterIP-only — never exposed to the LAN"
  - "Provisioning helper: `scripts/db-user.sh`"
resource_usage: "~600MB RAM combined"
---

# Databases — Shared Data Tier

A single `databases` namespace hosts every stateful backend other apps depend on. Workloads connect via in-cluster DNS, never via host network.

## Why one namespace

- **One backup story** — one PVC class, one snapshot policy, one restore runbook
- **One credentials store** — every engine's root password sealed alongside its manifest
- **Lifecycle isolation** — restarting `n8n` should never touch its database
- **Resource sharing** — the Pi has finite RAM; bundling avoids redundant data planes

## Kubernetes Architecture

| Engine | Workload | PVC | Service | DNS name |
|--------|----------|-----|---------|----------|
| PostgreSQL | StatefulSet `postgres` | `postgres-data` | `ClusterIP` | `postgres.databases.svc.cluster.local:5432` |
| MySQL | StatefulSet `mysql` | `mysql-data` | `ClusterIP` | `mysql.databases.svc.cluster.local:3306` |
| MongoDB | StatefulSet `mongodb` | `mongodb-data` | `ClusterIP` | `mongodb.databases.svc.cluster.local:27017` |
| Redis | StatefulSet `redis` | `redis-data` | `ClusterIP` | `redis.databases.svc.cluster.local:6379` |

Each engine gets a headless Service for stable DNS, a regular Service for clients, a SealedSecret with root credentials, and a PVC sized for the workload. MongoDB uses one retained volume per replica member so each member keeps its own data copy.

## Prerequisites

- A StorageClass that supports `ReadWriteOnce` PVCs for apps that use dynamic provisioning
- For MongoDB in this repo, fixed hostPath PVs under `/home/pi/db-data/mongodb-rs0/` are used so each member's volume is retained explicitly
- The Sealed Secrets controller installed
- Sufficient host disk (recommend SSD, not SD card)

## Quick Start

```bash
cd k3s/databases
./setup.sh deploy        # applies all four engines
./setup.sh status        # pods, PVCs, services
```

## Provisioning a User for an App

The shared helper `scripts/db-user.sh` creates a database, a user and a SealedSecret in the consuming app's namespace:

```bash
# Create n8n's DB + user, sealing the credentials into k3s/apps/n8n/sealedsecret.yaml
../../scripts/db-user.sh \
  --engine postgres \
  --db n8n \
  --user n8n \
  --target-namespace automation \
  --target-secret n8n-db
```

## Manifests

```
databases/
├── postgres/   # StatefulSet, Service, SealedSecret, PVC
├── mysql/
├── mongodb/
└── redis/
```

Each subdirectory follows the same shape so the deploy/undeploy logic can iterate over them.

## Connecting from Another App

In another app's `deployment.yaml`:

```yaml
env:
  - name: DB_HOST
    value: postgres.databases.svc.cluster.local
  - name: DB_PORT
    value: "5432"
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: n8n-db   # decrypted from sealedsecret.yaml
        key: password
```

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs postgres        # tail one engine
./setup.sh exec postgres        # psql shell
./setup.sh restart redis
./setup.sh undeploy             # PVCs are RETAINED by default
```

## Backup & Restore

PVCs use reclaim-policy `Retain`. For logical backups:

```bash
# Postgres
kubectl -n databases exec sts/postgres -- \
  pg_dumpall -U postgres > postgres-$(date +%F).sql

# MySQL
kubectl -n databases exec sts/mysql -- \
  mysqldump -uroot -p"$ROOT_PW" --all-databases > mysql-$(date +%F).sql
```

## Troubleshooting

- **Pod CrashLoopBackOff on first start** → check `kubectl logs`; usually the SealedSecret hasn't decrypted yet (controller not running)
- **PVC stuck Pending** → no StorageClass / wrong access mode
- **Connection refused from another namespace** → verify the Service name + that the consuming Pod has DNS access (NetworkPolicy)
- **OOMKilled MySQL** → bump `innodb_buffer_pool_size` or the StatefulSet memory limit

## MongoDB Storage Notes

- A MongoDB replica set does not share one disk. Each member stores its own full copy of the data on its own PVC/PV.
- Losing one member volume does not delete the replica set, but that member must resync from another member.
- For planned maintenance, the safe detach pattern is to stop the StatefulSet and keep the PVCs/PVs bound, not to delete them.
- The MongoDB helper supports `./setup.sh detach-storage` and `./setup.sh attach-storage` for that workflow.

## Links

- [PostgreSQL on Kubernetes](https://www.postgresql.org/docs/current/admin.html)
- [MySQL StatefulSet on Kubernetes](https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/)
- [MongoDB Operator alternative](https://www.mongodb.com/docs/kubernetes-operator/)
- [Redis on Kubernetes](https://redis.io/docs/management/kubernetes/)
