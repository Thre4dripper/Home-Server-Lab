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
