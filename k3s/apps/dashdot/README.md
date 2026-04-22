---
name: "Dashdot"
category: "📊 Monitoring & Stats"
purpose: "Host Resource Dashboard"
description: "Real-time CPU, RAM, storage, network and GPU dashboard for the underlying host server, exposed as a stateless Deployment that mounts /proc and /sys read-only."
icon: "📊"
namespace: "monitoring"
external_port: "8120"
domain: "dashdot.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
features:
  - "Live host metrics with 1-second granularity"
  - "CPU, RAM, storage, network and GPU widgets"
  - "Read-only host mounts (/proc, /sys)"
  - "Stateless — no PVC, no database"
  - "Embeddable in Homepage / Homarr"
resource_usage: "~50MB RAM"
---

# Dashdot — Host Resource Dashboard

Dashdot reads `/proc` and `/sys` from the Pi host and renders a clean live dashboard. Because everything it needs is on the host, the Pod itself is stateless — no PVC, no DB, just a Deployment.

## Features

- **Live**: 1 s refresh on CPU, RAM, network, storage
- **Multi-widget**: CPU, RAM, storage, network, OS, optional GPU
- **Embeddable**: iframe-friendly for Homepage / Homarr tiles
- **Themeable**: dark / light, accent colour, widget toggles via env
- **Tiny**: ~50 MB RAM, single Pod

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `dashdot` | Deployment | Single replica, hostPath mounts |
| `dashdot` | Service (LoadBalancer) | Web UI on port `8120` |
| `dashdot` | Ingress | Hosts `dashdot.home.ijlalahmad.dev` |

The Deployment mounts `/etc/os-release`, `/proc` and `/sys` from the host as read-only volumes.

## Prerequisites

- k3s cluster (any storage class — none needed)
- Traefik for the friendly hostname (optional)

## Quick Start

```bash
cd k3s/apps/dashdot
./setup.sh deploy
./setup.sh status
```

Open `http://<node-ip>:8120` or `https://dashdot.home.ijlalahmad.dev`.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | dashdot container with `hostPath` mounts and `DASHDOT_*` env tuning |
| `service.yaml` | LoadBalancer Service on TCP `8120` |
| `ingress.yaml` | Traefik IngressRoute for `dashdot.home.ijlalahmad.dev` |

## Configuration

Configurable via env in `deployment.yaml`:

| Variable | Purpose |
|----------|---------|
| `DASHDOT_ENABLE_CPU_TEMPS` | Show CPU temps (Pi-friendly) |
| `DASHDOT_USE_IMPERIAL` | °F instead of °C |
| `DASHDOT_WIDGET_LIST` | Comma list of widgets to render |
| `DASHDOT_PAGE_THEME` | `dark` / `light` |
| `DASHDOT_ACCENT_COLOR` | Hex accent |

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh restart
./setup.sh undeploy
```

## Troubleshooting

- **Storage widget shows 0** → hostPath mount of `/mnt/host_root` missing in `deployment.yaml`
- **CPU temp missing** → `/sys/class/thermal/thermal_zone0/temp` not readable; the Pod needs `securityContext.privileged: true` on some kernels
- **GPU widget missing** → not supported on Pi; remove from `DASHDOT_WIDGET_LIST`

## Links

- [dashdot GitHub](https://github.com/MauriceNino/dashdot)
- [Configuration reference](https://getdashdot.com/docs/install/configuration)
