---
name: "n8n"
category: "🤖 Automation"
purpose: "Workflow Automation"
description: "Fair-code workflow engine with 400+ integrations, persistent execution history and webhook endpoints. Connects to the shared PostgreSQL StatefulSet in the databases namespace."
icon: "🔄"
namespace: "automation"
external_port: "8400"
domain: "n8n.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - sealedsecret
  - pvc
features:
  - "Visual node-based workflow editor"
  - "400+ integrations + custom Code node"
  - "Webhook + cron + manual triggers"
  - "Persistent execution history (Postgres)"
  - "Encryption key + DB creds sealed in git"
  - "Binary data store on PVC (uploads, attachments)"
resource_usage: "~300MB RAM"
---

# n8n — Workflow Automation

Self-hosted Zapier replacement. Workflows are JSON, exported and version-controlled. Execution history, credentials and binary data are persisted — to PostgreSQL (in the `databases` namespace) and to a dedicated PVC.

## Features

- **Visual editor** with 400+ first-party integrations
- **Code node** for custom JavaScript / Python
- **Webhook + cron + manual** triggers
- **Persistent execution history** in shared PostgreSQL
- **Binary data** (uploads, attachments) stored on PVC
- **Encrypted credentials** at rest (n8n's own encryption key, sealed)

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `n8n` | Deployment | Single replica (community edition) |
| `n8n` | Service (LoadBalancer) | Web UI + webhooks on port `8400` |
| `n8n` | Ingress | Hosts `n8n.home.ijlalahmad.dev` |
| `n8n-secrets` | SealedSecret → Secret | `N8N_ENCRYPTION_KEY` + Postgres password |
| `n8n-data` | PVC | Binary data + custom nodes |

Database connection points at `postgres.databases.svc.cluster.local:5432`.

## Prerequisites

- The shared `databases` namespace deployed (`k3s/databases/`) with a Postgres user `n8n` provisioned
- Sealed Secrets controller installed
- Pi-hole resolving `n8n.home.ijlalahmad.dev`

## Quick Start

```bash
# 1. Provision the n8n DB user from the databases namespace
../../scripts/db-user.sh \
  --engine postgres --db n8n --user n8n \
  --target-namespace automation --target-secret n8n-secrets

# 2. Deploy n8n
cd k3s/apps/n8n
./setup.sh deploy
./setup.sh status
```

Open `https://n8n.home.ijlalahmad.dev` (or `http://<node-ip>:8400`) and create the owner account on first launch.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | n8n container, env from secret, PVC mount at `/home/node/.n8n` |
| `service.yaml` | LoadBalancer Service on TCP `8400` |
| `ingress.yaml` | Traefik IngressRoute, body size limit raised for large workflows |
| `sealedsecret.yaml` | `N8N_ENCRYPTION_KEY` + DB credentials |
| `pvc.yaml` | `ReadWriteOnce` PVC for binary data |

## Custom image

n8n runs from a custom image built out of [`docker/n8n/Dockerfile`](../../../docker/n8n/Dockerfile),
which adds aws, kubectl, helm, terraform, rclone, docker CLI, yq and jq so
workflows can drive the homelab directly.

It is **not built by hand**. `.github/workflows/build-n8n-image.yml` builds it on
GitHub's free native runners — amd64 and arm64 in parallel, merged into one
manifest list — and publishes to `ghcr.io/thre4dripper/n8n-custom`. Building on
the Pi is avoided deliberately: `npm install -g n8n` compiles native addons via
node-gyp and would risk OOM-killing co-tenant workloads.

The image tag **is** the n8n version, pinned by `ARG N8N_VERSION` in the
Dockerfile. The update loop:

1. Renovate spots a new stable n8n → tick its checkbox on the Dependency
   Dashboard → it opens a PR bumping `ARG N8N_VERSION`
2. Review and merge → the workflow builds and pushes `n8n-custom:<version>`
3. Renovate spots the new tag → PR bumping `image:` here
4. Merge → ArgoCD rolls it

Renovate follows n8n's `stable` dist-tag specifically. n8n publishes
`next`/`beta`/`rc` builds *without* a semver prerelease suffix, so the normal
unstable filter cannot catch them — which is how this instance previously ended
up running `2.20.7-exp.0` in production.

`workflow_dispatch` rebuilds the same version on demand, which is how you pick
up new terraform/kubectl/helm/rclone releases (those are still unpinned and
resolve at build time — the `:<version>-<sha>` tag exists to tell such builds
apart).

n8n runs schema migrations on version change. **Dump the database before any
version bump:**

```bash
kubectl -n databases exec deploy/postgres -- pg_dump -U postgres n8n \
  | gzip > n8n-pre-upgrade.sql.gz
```

## Important Environment

| Variable | Purpose |
|----------|---------|
| `DB_TYPE` | `postgresdb` |
| `DB_POSTGRESDB_HOST` | `postgres.databases.svc.cluster.local` |
| `DB_POSTGRESDB_DATABASE` | `n8n` |
| `DB_POSTGRESDB_USER` / `DB_POSTGRESDB_PASSWORD` | from SealedSecret |
| `N8N_ENCRYPTION_KEY` | from SealedSecret — **never rotate without re-encrypting credentials** |
| `WEBHOOK_URL` | `https://n8n.home.ijlalahmad.dev/` |
| `N8N_HOST` / `N8N_PROTOCOL` | match the ingress host |

## Webhook Routing

Triggers like `POST /webhook/<id>` are exposed at `https://n8n.home.ijlalahmad.dev/webhook/<id>`. Inside the cluster, other apps can hit it directly:

```
http://n8n.automation.svc.cluster.local:8400/webhook/<id>
```

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh exec        # shell into the pod (n8n CLI lives here)
./setup.sh restart
./setup.sh undeploy    # PVC retained
```

## Troubleshooting

- **`Encryption key has changed`** → never rotate `N8N_ENCRYPTION_KEY`; restore the previous secret or re-enter all credentials
- **Webhook returns 404** → workflow not active; toggle the Active switch
- **Slow editor** → SD-card I/O; move PVC + Postgres PVC to SSD
- **Out of memory on large workflow** → bump deployment memory limit; consider splitting into sub-workflows

## Links

- [n8n Docs](https://docs.n8n.io/)
- [Self-hosting reference](https://docs.n8n.io/hosting/)
- [Available integrations](https://n8n.io/integrations/)
