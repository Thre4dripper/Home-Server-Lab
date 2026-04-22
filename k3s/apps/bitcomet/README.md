---
name: "BitComet"
category: "🧲 Downloads"
purpose: "BitTorrent Client (Web Remote)"
description: "BitComet running in a containerized desktop session (noVNC) for remote torrent management, with a JSON task API consumed by the Homepage dashboard widget."
icon: "🧲"
namespace: "dashboard-network"
external_port: "8700"
domain: "bitcomet.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - sealedsecret
  - pvc
features:
  - "Full BitComet desktop UI in the browser via noVNC"
  - "JSON task API for live download stats"
  - "Persistent torrent state, downloads and config"
  - "Token-protected API (sealed in git)"
  - "Powers the BitComet widget on Homepage"
resource_usage: "~250MB RAM"
---

# BitComet — Remote Torrent Client

Runs the BitComet desktop client in a Pod that publishes a noVNC session to the browser. The same container exposes BitComet's JSON task API, which the Homepage dashboard polls for live download stats.

## Features

- **Browser-accessible**: full desktop UI via noVNC, no client install
- **Live stats**: JSON task API consumed by the Homepage widget
- **Persistent**: torrents, downloads and BitComet config live on a PVC
- **Authenticated**: API token stored as a SealedSecret in this repo
- **Resource-friendly**: ~250 MB RAM idle on most servers

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `bitcomet` | Deployment | BitComet + noVNC container |
| `bitcomet` | Service (LoadBalancer) | Web UI + API on port `8700` |
| `bitcomet` | Ingress | Hosts `bitcomet.home.ijlalahmad.dev` |
| `bitcomet-token` | SealedSecret → Secret | API token (`BITCOMET_TOKEN`) |
| `bitcomet-data` | PVC | Torrent state + downloads |

## Prerequisites

- A LoadBalancer-capable cluster (k3s ships with klipper-lb)
- The Sealed Secrets controller installed (`infra/sealed-secrets/`)
- A StorageClass for the PVC (default `local-path` works)

## Quick Start

```bash
cd k3s/apps/bitcomet
./setup.sh deploy
./setup.sh status
```

Open `https://bitcomet.home.ijlalahmad.dev` (or `http://<node-ip>:8700`) and log in with the noVNC password baked into the image.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | BitComet + noVNC container, mounts PVC at `/config` and `/downloads` |
| `service.yaml` | LoadBalancer Service on TCP `8700` |
| `ingress.yaml` | Traefik IngressRoute for `bitcomet.home.ijlalahmad.dev` |
| `sealedsecret.yaml` | `BITCOMET_TOKEN` for API auth |
| `pvc.yaml` | 50Gi `ReadWriteOnce` PVC for downloads + state |

## Secret Workflow

```bash
# Create a normal secret locally
kubectl create secret generic bitcomet-token \
  --namespace dashboard-network \
  --from-literal=BITCOMET_TOKEN=$(openssl rand -hex 16) \
  --dry-run=client -o yaml > /tmp/secret.yaml

# Seal it for this cluster
../../scripts/seal.sh /tmp/secret.yaml > sealedsecret.yaml
git add sealedsecret.yaml && git commit -m "secret(bitcomet): rotate token"
```

## Homepage Integration

The Homepage `customapi` widget reads `https://bitcomet.home.ijlalahmad.dev/api/tasks?token=$BITCOMET_TOKEN`. The token is injected into Homepage from its own SealedSecret as `HOMEPAGE_VAR_BITCOMET_TOKEN`.

## Management Commands

```bash
./setup.sh deploy
./setup.sh status        # pods + svc + ingress
./setup.sh logs          # container logs
./setup.sh exec          # shell into the pod (great for debugging noVNC)
./setup.sh restart
./setup.sh undeploy      # PVC retained
```

## Troubleshooting

- **noVNC blank screen** → resize browser, or restart pod (display server occasionally hangs)
- **Token rejected** → re-seal the secret; verify the same token is also in the Homepage SealedSecret
- **Port 8700 in use** → another LoadBalancer service has it; change `EXTERNAL_PORT` in `setup.sh`
- **Slow downloads** → PVC backed by SD card; move to SSD-backed StorageClass

## Links

- [BitComet](https://www.bitcomet.com/)
- [noVNC](https://novnc.com/)
- [Homepage `customapi` widget docs](https://gethomepage.dev/widgets/services/customapi/)
