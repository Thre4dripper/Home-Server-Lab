---
name: "Redis"
category: "🗄️ Databases"
purpose: "In-Memory Cache"
description: "Redis 7 running as a pure cache — persistence deliberately disabled, capped at 256MB with LRU eviction. Reachable in-cluster over ClusterIP and from the LAN through a dedicated Traefik TCP entrypoint."
icon: "⚡"
namespace: "databases"
components:
  - deployment
  - service
  - configmap
  - sealedsecret
features:
  - "Cache-only: no AOF, no RDB snapshots, no PVC"
  - "256MB cap with allkeys-lru eviction"
  - "16 logical databases (SELECT 0-15)"
  - "Password auth injected at runtime from a SealedSecret"
  - "LAN access via Traefik IngressRouteTCP on 6379"
  - "ACL users per app via db-user.sh"
resource_usage: "~50MB RAM"
---

# Redis — In-Memory Cache

Redis 7 (Alpine) used **strictly as a cache**. Persistence is off on purpose: a restart loses everything, which is correct cache semantics and spares the Pi's SD card from write amplification. There is **no PVC**.

## Features

- **Cache-only configuration** — `appendonly no`, `save ""`
- **Bounded memory** — `maxmemory 256mb` with `allkeys-lru` eviction
- **16 logical databases** so several apps can share one instance
- **Password never in git** — `redis.conf` is committed without `requirepass`; the password is appended at runtime from the SealedSecret
- **Pi tuning** — `hz 10`, `dynamic-hz yes`, lazy-free eviction and expiry

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `redis` | Deployment | Single replica, `Recreate` strategy |
| `redis` | Service (ClusterIP) | TCP `6379` in-cluster |
| `redis` | IngressRouteTCP (`traefik` ns) | LAN access on the `redis` entrypoint |
| `redis-config` | ConfigMap | `redis.conf` |
| `redis-secret` | SealedSecret | `REDIS_PASSWORD` |

### How the password stays out of git

```yaml
command:
  - sh
  - -c
  - exec redis-server /etc/redis/redis.conf --requirepass "$REDIS_PASSWORD"
```

`redis.conf` is committed and contains no credential; the CLI flag overrides it at startup.

### LAN exposure

Redis speaks a plaintext protocol, so Traefik cannot route it by SNI. `ingressroute-tcp.yaml` therefore matches `HostSNI("*")` — **every** connection arriving on the dedicated `redis` entrypoint (port `6379`, defined in `k3s/infra/traefik/values.yaml`) is forwarded to this Service. Access control is the Redis password, not the route.

## Connecting

```bash
cd k3s/databases/redis
./setup.sh connection-string            # LAN / external
./setup.sh connection-string internal   # in-cluster
```

In-cluster: `redis.databases.svc.cluster.local:6379`

## Provisioning an app

```bash
cd k3s/scripts
./db-user.sh redis create myapp 'SecurePass123!'
./db-user.sh redis list
./db-user.sh redis delete myapp
```

This creates a Redis **ACL user** rather than sharing the master password.

## Quick Start

```bash
cd k3s/databases/redis
# put REDIS_PASSWORD in secret.yaml first, then:
./setup.sh seal
./setup.sh deploy
./setup.sh status
```

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | redis:7-alpine, runtime `--requirepass`, `redis-cli ping` probes |
| `service.yaml` | ClusterIP on TCP `6379` |
| `configmap.yaml` | `redis.conf` — memory cap, eviction, persistence off |
| `ingressroute-tcp.yaml` | Traefik IngressRouteTCP, `HostSNI("*")` on the `redis` entrypoint |
| `sealedsecret.yaml` | Sealed `REDIS_PASSWORD` |

> `secret.yaml` is git-ignored — keep it locally for re-sealing, never commit it.

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh shell                # then: redis-cli -a "$REDIS_PASSWORD"
./setup.sh restart
./setup.sh resources
./setup.sh seal
./setup.sh teardown
```

`dump` / `restore` are intentionally not meaningful here — there is nothing durable to back up.

## Troubleshooting

- **`NOAUTH Authentication required`** → pass the password: `redis-cli -a "$REDIS_PASSWORD"`.
- **Keys vanish unexpectedly** → working as designed. `allkeys-lru` evicts at 256MB, and a pod restart clears everything. Don't store anything you need to keep.
- **`OOM command not allowed`** → the cap was hit with a non-evictable policy in play; confirm `maxmemory-policy` is still `allkeys-lru`.
- **LAN clients can't connect** → the `redis` entrypoint must exist in `k3s/infra/traefik/values.yaml` and `redis.home.ijlalahmad.dev` must resolve to the node IP.
- **Password change has no effect** → the flag is read at startup only; `./setup.sh restart` after re-sealing.

## Links

- [Redis Docs](https://redis.io/docs/latest/)
- [Eviction policies](https://redis.io/docs/latest/develop/reference/eviction/)
- [Redis ACL](https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/)
