---
name: "Homarr"
category: "🏡 Dashboards"
purpose: "Modern Service Dashboard"
description: "Drag-and-drop, GUI-first dashboard with widgets for Pi-hole, Jellyfin, qBittorrent, Docker, calendars and more. Configured entirely from its UI; state persisted on a PVC."
icon: "🏡"
namespace: "dashboard-network"
external_port: "8100"
domain: "homarr.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - sealedsecret
  - pvc
features:
  - "Drag-and-drop tile editor"
  - "Live integrations with cluster services"
  - "Multiple dashboards & themes"
  - "Persistent state on PVC"
  - "Encrypted app credentials via SealedSecret"
resource_usage: "~200MB RAM"
---

# Homarr — Service Dashboard

A polished, GUI-first dashboard. Where [Homepage](../homepage/) is YAML-driven and GitOps-friendly, **Homarr is for users who prefer to drag, drop and configure tiles in a browser**. Both run side-by-side; pick the one that suits the audience.

## Features

- **Drag-and-drop** tiles, no YAML required
- **Live widgets** for downloaders, media servers, DNS and more
- **Multiple dashboards** with separate layouts and themes
- **Persistent state** — tile positions, icons and credentials live on a PVC
- **Encrypted secrets** — app tokens / passwords stored in a SealedSecret

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `homarr` | Deployment | Single replica |
| `homarr` | Service (LoadBalancer) | Web UI on port `8100` |
| `homarr` | Ingress | Hosts `homarr.home.ijlalahmad.dev` |
| `homarr-secrets` | SealedSecret → Secret | `HOMARR_ENCRYPTION_KEY` and integration tokens |
| `homarr-data` | PVC | App database + uploaded icons |

## Prerequisites

- Sealed Secrets controller running
- A StorageClass supporting `ReadWriteOnce`

## Quick Start

```bash
cd k3s/apps/homarr
./setup.sh deploy
./setup.sh status
```

Open `https://homarr.home.ijlalahmad.dev` (or `http://<node-ip>:8100`) and complete the onboarding wizard.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | homarr container, mounts PVC at `/app/data/configs` and the secret as env |
| `service.yaml` | LoadBalancer Service on TCP `8100` |
| `ingress.yaml` | Traefik IngressRoute for `homarr.home.ijlalahmad.dev` |
| `sealedsecret.yaml` | `HOMARR_ENCRYPTION_KEY` + optional integration tokens |
| `pvc.yaml` | `ReadWriteOnce` PVC for app state |

## Configuration

Initial config from the UI: **Settings → Common Settings**. To pre-seed a config:

```bash
kubectl cp my-config.json file-management/homarr-xxx:/app/data/configs/default.json
./setup.sh restart
```

## Secret Workflow

```bash
kubectl create secret generic homarr-secrets \
  --namespace dashboard-network \
  --from-literal=HOMARR_ENCRYPTION_KEY=$(openssl rand -hex 32) \
  --dry-run=client -o yaml > /tmp/secret.yaml

../../scripts/seal.sh /tmp/secret.yaml > sealedsecret.yaml
git add sealedsecret.yaml && git commit -m "secret(homarr): rotate encryption key"
```

> ⚠️ **Rotating `HOMARR_ENCRYPTION_KEY` invalidates existing integration credentials.** Re-enter them in the UI afterwards.

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh exec
./setup.sh restart
./setup.sh undeploy   # PVC retained
```

## Troubleshooting

- **Blank page after deploy** → wait ~30s on first start; SQLite migrations can be slow on SD card
- **Integrations show "unauthorized"** → encryption key mismatch; re-enter the credentials in the UI
- **Can't upload icons** → PVC full or read-only mount; check `kubectl describe pvc homarr-data`
- **EXTERNAL-IP `<pending>`** → port collision; change `EXTERNAL_PORT` in `setup.sh`

## Links

- [Homarr Docs](https://homarr.dev/)
- [Available widgets](https://homarr.dev/docs/widgets/)
- [Integrations reference](https://homarr.dev/docs/integrations/)
