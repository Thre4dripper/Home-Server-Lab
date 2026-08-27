---
name: "MongoDB"
category: "🗄️ Databases"
purpose: "Document Database"
description: "MongoDB 8 as a single-member replica set (rs0) so drivers get transactions and change streams. Public Let's Encrypt TLS via cert-manager, exposed to the LAN through Traefik SNI passthrough — no custom CA for clients to trust."
icon: "🍃"
namespace: "databases"
external_port: "27017"
domain: "mongo-0.home.ijlalahmad.dev"
components:
  - statefulset
  - service
  - pvc
  - sealedsecret
  - configmap
features:
  - "Single-member replica set (rs0) — transactions + change streams"
  - "Let's Encrypt TLS, no private CA for clients to install"
  - "keyFile internal auth + root credentials from a SealedSecret"
  - "Traefik SNI passthrough — mongod terminates its own TLS"
  - "Self-bootstrapping rs.initiate() on pod-0"
  - "mongodump / mongorestore wired into setup.sh"
resource_usage: "~400MB RAM"
---

# MongoDB — Document Database

MongoDB 8 running as a **StatefulSet with one replica**, initialised as a **single-member replica set** named `rs0`. One member on one physical host adds no availability, but it does unlock the features drivers expect from a replica set: multi-document transactions, change streams and retryable writes. Durability comes from logical backups (`mongodump`) plus the retained hostPath PV, not from replication.

## Features

- **Replica set `rs0`**, bootstrapped automatically by a `postStart` hook on `mongodb-0` (exit code 23 = "already initialised" is treated as success, so restarts are safe)
- **Public TLS** — a cert-manager `Certificate` issued by Let's Encrypt (DNS-01 via Cloudflare) in `CombinedPEM` format, which is what mongod's `certificateKeyFile` expects. Compass, DataGrip and every driver trust it out of the box
- **`allowTLS` mode** — accepts both TLS and plaintext, and *initiates* plaintext. Necessary because the LE cert can only cover publicly-resolvable names, not `*.svc.cluster.local` used for member-to-member traffic
- **keyFile internal auth** — copied out of the Secret and `chmod 400` by an init container (mongod refuses a group/world-readable keyfile)
- **Pi-sized** — WiredTiger cache pinned to `0.25GB`, `maxIncomingConnections: 50`

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `mongodb` | StatefulSet | 1 replica, `serviceName: mongodb-headless`, 60s grace |
| `mongodb` | Service (ClusterIP) | In-cluster access on `27017` |
| `mongodb-headless` | Service (headless) | Stable per-pod DNS; `publishNotReadyAddresses` so rs bootstrap can reach itself |
| `mongodb-0` | Service (ClusterIP) | Per-pod target for the Traefik TCP route |
| `mongodb-0` | IngressRouteTCP (`traefik` ns) | `HostSNI(mongo-0.home.ijlalahmad.dev)`, **TLS passthrough** |
| `mongodb-server` | Certificate | LE cert → `mongodb-server-tls` secret (CombinedPEM) |
| `mongodb-pv-0` | PV (20Gi, `Retain`) | Pre-bound to `data-mongodb-0` |
| `mongodb-config` | ConfigMap (generated) | `mongod.conf` + `init.js` |
| `mongodb-secret` | SealedSecret | Root user, root password, replica-set keyfile |

This app is assembled with **kustomize** — `kustomization.yaml` generates `mongodb-config` from the `config/` directory (with `disableNameSuffixHash`) so each file keeps its native syntax and editor tooling.

### How an external connection works

1. Client opens TLS to `mongo-0.home.ijlalahmad.dev:27017`; DNS resolves to the Traefik LoadBalancer.
2. Traefik reads the SNI from the ClientHello and forwards the **still-encrypted** stream — it never decrypts.
3. `mongod` terminates TLS with the Let's Encrypt certificate.
4. The replica-set `hello` advertises the external hostname, so the driver can keep reaching the member the same way.

## Connecting

```bash
cd k3s/databases/mongodb
./setup.sh connection-string            # external, TLS
./setup.sh connection-string internal   # in-cluster, plaintext
```

External URIs look like:

```
mongodb://<user>:<pass>@mongo-0.home.ijlalahmad.dev:27017/?replicaSet=rs0&tls=true&authSource=admin
```

In-cluster:

```
mongodb://<user>:<pass>@mongodb.databases.svc.cluster.local:27017/?replicaSet=rs0&authSource=admin
```

`setup.sh` URL-encodes the password for you — worth using, since `@`, `:` and `/` in a password otherwise break the URI.

## Provisioning an app

```bash
cd k3s/scripts
./db-user.sh mongodb create myapp 'SecurePass123!' orders,inventory,users
./db-user.sh mongodb list
./db-user.sh mongodb delete myapp
```

Creates the user with `readWrite` on each named database instead of handing out root.

## Quick Start

```bash
cd k3s/databases/mongodb
# secret.yaml needs MONGO_INITDB_ROOT_USERNAME / _PASSWORD and a keyfile:
#   openssl rand -base64 756   # → MONGO_REPLICA_SET_KEY_FILE
./setup.sh seal
kubectl apply -f pv.yaml          # PV is cluster-scoped, applied once
./setup.sh deploy
./setup.sh status
```

## Manifests

| File | What's inside |
|------|---------------|
| `statefulset.yaml` | mongod 8.2, keyfile/TLS init container, `rs.initiate` postStart hook |
| `service.yaml` | ClusterIP for in-cluster clients |
| `service-headless.yaml` | Headless service backing stable pod DNS |
| `service-per-pod.yaml` | Per-pod ClusterIP targeted by the Traefik route |
| `ingressroute-tcp.yaml` | SNI-passthrough TCP route on the `mongodb` entrypoint |
| `certificate.yaml` | cert-manager Certificate (LE, CombinedPEM) |
| `pv.yaml` | 20Gi `Retain` hostPath PV pre-bound to `data-mongodb-0` |
| `kustomization.yaml` | Resource list + ConfigMap generation from `config/` |
| `config/mongod.conf` | WiredTiger cache, TLS `allowTLS`, `replSetName: rs0`, keyFile |
| `config/init.js` | First-run initialisation script |
| `sealedsecret.yaml` | Sealed root credentials + replica-set keyfile |

> `secret.yaml` is git-ignored — keep it locally for re-sealing, never commit it.

## Backup & Restore

```bash
./setup.sh dump mongo-backup.archive.gz     # mongodump --archive --gzip
./setup.sh restore mongo-backup.archive.gz  # mongorestore --drop
./setup.sh detach-storage                   # scale to 0, PV/PVC preserved
./setup.sh attach-storage                   # scale back up
```

Logical dumps are the real durability story here — take one before any major-version bump.

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh shell                # bash inside the pod (then: mongosh)
./setup.sh restart
./setup.sh pvc
./setup.sh resources
./setup.sh seal
./setup.sh teardown             # PV/PVC retained
./setup.sh teardown --purge     # DESTROYS the data directory
```

## Notes & Caveats

- The StatefulSet declares **no CPU/memory limits**. It is bounded in practice by the WiredTiger cache setting (`0.25GB`) and carries `priorityClassName: homelab-infra`, so it is evicted only after ordinary apps. Add a `resources` block if you want a hard ceiling.
- Scaling past 1 replica needs a matching PV per pod (`mongodb-pv-1`, …), an added `rs.add()` member, and per-pod Services + TCP routes for each new member.

## Troubleshooting

- **`Permission denied` on the keyfile at startup** → the init container must `chmod 400` and `chown 999:999`; mongod rejects anything more permissive.
- **`NotYetInitialized` / `no replset config`** → the `postStart` bootstrap didn't complete. Check `./setup.sh logs`, then run `rs.initiate(...)` manually in `mongosh`.
- **TLS handshake failure from a LAN client** → the cert only covers `mongo-0.home.ijlalahmad.dev`. Connecting by IP or cluster DNS with `tls=true` will always fail — use the hostname, or drop to `tls=false` internally.
- **Cert renewal didn't reach mongod** → mongod loads `tls-combined.pem` at startup; restart the pod after cert-manager renews.
- **Pod `Pending`** → `pv.yaml` isn't applied, or the PV's `claimRef` is stale. `kubectl get pv mongodb-pv-0`.
- **Driver can't find the primary** → the URI must include `replicaSet=rs0`; without it the driver treats the node as standalone and rejects transactions.

## Links

- [MongoDB Manual](https://www.mongodb.com/docs/manual/)
- [Replica set deployment](https://www.mongodb.com/docs/manual/administration/replica-set-deployment/)
- [TLS/SSL configuration](https://www.mongodb.com/docs/manual/tutorial/configure-ssl/)
- [Traefik TCP SNI routing](https://doc.traefik.io/traefik/routing/routers/#rule_1)
