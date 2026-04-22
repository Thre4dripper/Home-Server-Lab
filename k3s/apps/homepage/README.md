---
name: "Homepage"
category: "🏡 Dashboards"
purpose: "Application Dashboard"
description: "YAML-driven, server-rendered application dashboard with live widgets for cluster services. Two ConfigMaps drive layout and custom widgets; every API token is injected from a SealedSecret. The Kubernetes widget reads pod stats via in-cluster RBAC."
icon: "🏠"
namespace: "dashboard-network"
external_port: "8800"
domain: "homepage.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - configmap
  - sealedsecret
  - rbac
features:
  - "GitOps-friendly YAML configuration"
  - "Live widgets for Jellyfin, Pi-hole, ArgoCD, BitComet, Portainer, Finnhub, OpenWeather, calendars, etc."
  - "Kubernetes pod & node stats via in-cluster RBAC"
  - "All API tokens encrypted with SealedSecrets"
  - "Custom widgets ConfigMap mounted into /app/public/widgets"
  - "Stateless — no database, no PVC"
resource_usage: "~128MB RAM"
---

# Homepage — Application Dashboard

The cluster's primary landing page. Where [Homarr](../homarr/) is GUI-first, **Homepage is YAML-first** — every tile, group, widget and bookmark is in a ConfigMap, version-controlled and reviewable in git.

## Why both?

- **Homepage** for the operator (you): GitOps, predictable, fast, stateless
- **Homarr** for guests / family: friendly, drag-and-drop, themed

## Features

- **YAML configuration** — diffable, GitOps-friendly
- **Live widgets** — Jellyfin, Pi-hole, ArgoCD, BitComet (custom), Portainer, Finnhub, OpenWeather, calendar
- **Kubernetes-aware** — reads pod / node stats through an in-cluster ServiceAccount
- **Custom widgets** — extra `*.json` widget definitions mounted from a second ConfigMap
- **Sealed secrets** — every token (`HOMEPAGE_VAR_*`) sealed in this repo
- **Stateless** — restart anytime, no PVC, no DB

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `homepage` | Deployment | Single replica, mounts both ConfigMaps + Secret |
| `homepage` | Service (LoadBalancer) | Web UI on port `8800` |
| `homepage` | Ingress | Hosts `homepage.home.ijlalahmad.dev` |
| `homepage-config` | ConfigMap | Layout: `services.yaml`, `bookmarks.yaml`, `widgets.yaml`, `settings.yaml`, `kubernetes.yaml` |
| `homepage-widgets` | ConfigMap | Custom widget definitions, mounted at `/app/public/widgets` |
| `homepage-env` | SealedSecret → Secret | `HOMEPAGE_VAR_*` env vars (Finnhub, OpenWeather, Portainer, Jellyfin, ArgoCD, BitComet, calendar iCal, FileBrowser …) |
| `homepage` | ServiceAccount + ClusterRole + RoleBinding | Read-only access for the kubernetes widget |

## Prerequisites

- Sealed Secrets controller installed
- Traefik for the friendly hostname
- Cluster RBAC enabled (default in k3s)

## Quick Start

```bash
cd k3s/apps/homepage
./setup.sh deploy
./setup.sh status
```

Open `https://homepage.home.ijlalahmad.dev` (or `http://<node-ip>:8800`).

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | homepage container, both ConfigMaps mounted, all `HOMEPAGE_VAR_*` env from SealedSecret |
| `service.yaml` | LoadBalancer Service on TCP `8800` |
| `ingress.yaml` | Traefik IngressRoute for `homepage.home.ijlalahmad.dev` |
| `configmap.yaml` | Two documents: `homepage-config` (YAML configs) + `homepage-widgets` (custom widget JSON) |
| `sealedsecret.yaml` | All `HOMEPAGE_VAR_*` tokens |
| `rbac.yaml` | ServiceAccount + ClusterRole + RoleBinding for the kubernetes widget |

## Editing Configuration

```bash
# Edit the live ConfigMap
kubectl -n dashboard-network edit configmap homepage-config

# Or commit changes to k3s/apps/homepage/configmap.yaml and let ArgoCD sync
git diff configmap.yaml
git add configmap.yaml && git commit -m "homepage: add new tile"
git push
```

Homepage detects ConfigMap changes via filesystem watch and reloads — no Pod restart needed.

## Secret Workflow

All API tokens are env vars prefixed `HOMEPAGE_VAR_*`. The Homepage container substitutes them into the YAML at request time (`{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}`).

```bash
kubectl create secret generic homepage-env \
  --namespace dashboard-network \
  --from-literal=HOMEPAGE_VAR_JELLYFIN_API_KEY=xxx \
  --from-literal=HOMEPAGE_VAR_OPENWEATHER=yyy \
  ... \
  --dry-run=client -o yaml > /tmp/secret.yaml

../../scripts/seal.sh /tmp/secret.yaml > sealedsecret.yaml
git add sealedsecret.yaml && git commit -m "secret(homepage): rotate tokens"
```

## Kubernetes Widget RBAC

`rbac.yaml` grants the homepage ServiceAccount cluster-wide `get/list/watch` on `pods`, `nodes` and the metrics API. This is **read-only** — homepage cannot mutate cluster state.

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh restart   # rare, only if you change RBAC or env vars
./setup.sh undeploy
```

## Troubleshooting

- **`{{HOMEPAGE_VAR_X}}` shown literally** → env var missing in Secret; check `kubectl describe pod`
- **Kubernetes widget empty** → check ServiceAccount + RBAC, and that `metrics-server` is installed
- **Tile shows "API Error"** → the upstream service is down; click the tile to check
- **Calendar widget empty** → invalid iCal URL; verify `HOMEPAGE_VAR_CALENDAR_ICAL`
- **Custom BitComet widget broken** → re-check the second ConfigMap mount at `/app/public/widgets`

## Links

- [Homepage Docs](https://gethomepage.dev/)
- [Service widgets reference](https://gethomepage.dev/widgets/services/)
- [Kubernetes widget setup](https://gethomepage.dev/widgets/kubernetes/)
- [Custom API widget](https://gethomepage.dev/widgets/services/customapi/)
