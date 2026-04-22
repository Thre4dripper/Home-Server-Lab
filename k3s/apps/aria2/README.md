---
name: "Aria2"
category: "🧲 Downloads"
purpose: "Lightweight Multi-Protocol Downloader"
description: "Headless aria2c daemon paired with the AriaNg WebUI for HTTP, FTP, SFTP, BitTorrent and Metalink downloads, exposed through a Service + Ingress and persisted on a PVC."
icon: "⬇️"
namespace: "downloads"
external_port: "8080"
domain: "aria2.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - pvc
features:
  - "HTTP, FTP, SFTP, BitTorrent and Metalink"
  - "AriaNg single-page WebUI"
  - "JSON-RPC API for automation and dashboards"
  - "Persistent downloads via PVC"
  - "Resume on container restart / reschedule"
resource_usage: "~80MB RAM"
---

# Aria2 — Multi-Protocol Downloader

A pragmatic combination of the `aria2c` daemon and the [AriaNg](https://github.com/mayswind/AriaNg) WebUI in a single Pod, backed by a `PersistentVolumeClaim` so downloads survive Pod restarts and reschedules.

## Features

- **Multi-protocol**: HTTP(S), FTP, SFTP, BitTorrent, Magnet, Metalink
- **Browser UI**: AriaNg served alongside the daemon
- **JSON-RPC API**: scripted from Homepage, n8n, etc.
- **Resumeable**: state lives on the PVC, including in-flight torrents
- **Throttle-friendly**: per-task and global speed limits configurable from the UI

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `aria2` | Deployment | aria2c daemon + AriaNg WebUI |
| `aria2` | Service (LoadBalancer) | Exposes UI + RPC on port `8080` |
| `aria2` | Ingress | Hosts `aria2.home.ijlalahmad.dev` |
| `aria2-data` | PVC | Downloads + session state |

## Prerequisites

- k3s with Traefik + klipper-lb (default)
- A StorageClass that provisions PVCs (default `local-path` works)
- Pi-hole resolving `aria2.home.ijlalahmad.dev` (or edit `/etc/hosts`)

## Quick Start

```bash
cd k3s/apps/aria2
./setup.sh deploy
./setup.sh status
```

Then open:

- **WebUI**: `http://<node-ip>:8080` or `https://aria2.home.ijlalahmad.dev`
- **JSON-RPC**: `http://<node-ip>:8080/jsonrpc`

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | aria2 + AriaNg container, with `RPC_SECRET` env from sealed secret if enabled |
| `service.yaml` | LoadBalancer Service on TCP `8080` |
| `ingress.yaml` | Traefik IngressRoute for `aria2.home.ijlalahmad.dev` |
| `pvc.yaml` | `ReadWriteOnce` 20Gi PVC for downloads + session |

## Persistent Storage

The PVC mounts at `/downloads` inside the container:

```bash
kubectl -n downloads exec -it deploy/aria2 -- ls /downloads
```

Resize on the fly (with a CSI-aware StorageClass):

```bash
kubectl -n downloads patch pvc aria2-data -p \
  '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

## Networking

- LoadBalancer publishes port `8080` on the node IP via klipper-lb
- Ingress routes the friendly hostname through Traefik
- BitTorrent peer port (default `6881`) is **inside the pod**; expose it explicitly if you need active inbound peers (add a second Service of type `LoadBalancer`)

## Management Commands

```bash
./setup.sh deploy        # apply all manifests
./setup.sh status        # pods, services, ingress, PVCs
./setup.sh logs          # follow aria2 logs
./setup.sh exec          # shell into the pod
./setup.sh restart       # rollout restart
./setup.sh undeploy      # delete the workload (PVC retained)
```

## Troubleshooting

- **PVC stuck Pending** → no default StorageClass, set one or specify `storageClassName`
- **EXTERNAL-IP `<pending>`** → another LoadBalancer is already bound to port 8080; change `EXTERNAL_PORT` in `setup.sh`
- **403 from RPC** → wrong or missing `--rpc-secret`; reseal the secret
- **Downloads disappear on restart** → the PVC didn't bind; check `kubectl -n downloads describe pvc`

## Links

- [aria2 Manual](https://aria2.github.io/manual/en/html/)
- [AriaNg](https://github.com/mayswind/AriaNg)
- [JSON-RPC Reference](https://aria2.github.io/manual/en/html/aria2c.html#rpc-interface)
