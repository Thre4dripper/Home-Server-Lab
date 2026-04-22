---
name: "Portainer"
category: "📊 Monitoring & Stats"
purpose: "Kubernetes Management UI"
description: "Web UI for managing the k3s cluster — workloads, services, configs, events and live shell access — backed by a ServiceAccount with cluster-admin RBAC."
icon: "🐳"
namespace: "monitoring"
external_port: "8500"
domain: "portainer.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - rbac
  - pvc
features:
  - "Visual workload & resource explorer"
  - "Live container logs and exec shell"
  - "Cluster events and metrics"
  - "Helm chart catalog"
  - "Multi-cluster aware (single-cluster here)"
  - "ServiceAccount with cluster-admin RBAC"
resource_usage: "~150MB RAM"
---

# Portainer — Kubernetes UI

Browser-based control plane for the cluster. Useful when `kubectl` isn't ergonomic — graphical exec, log tail, resource graphs, Helm catalog, RBAC visualisation.

> ⚠️ Portainer here runs with **cluster-admin** RBAC (it manages the local cluster via in-cluster ServiceAccount). Treat it like the kubeconfig — protect the admin login.

## Features

- **Resource explorer** for every Kubernetes object
- **Live logs** and **exec** straight from the browser
- **Helm catalog** for one-click chart installs
- **RBAC** visualiser
- **Event stream** for the entire cluster
- **Resource quotas** per namespace

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `portainer` | Deployment | portainer-ce container |
| `portainer` | Service (LoadBalancer) | Web UI on port `8500` |
| `portainer` | Ingress | Hosts `portainer.home.ijlalahmad.dev` |
| `portainer-sa` | ServiceAccount | identity used to talk to the API |
| `portainer-cluster-admin` | ClusterRoleBinding | binds SA → `cluster-admin` |
| `portainer-data` | PVC | users, endpoints, settings |

## Prerequisites

- Sealed Secrets controller running (only if you choose to seal initial admin)
- A StorageClass supporting `ReadWriteOnce`

## Quick Start

```bash
cd k3s/apps/portainer
./setup.sh deploy
./setup.sh status
```

Open `https://portainer.home.ijlalahmad.dev` (or `http://<node-ip>:8500`) and **set the admin password within 5 minutes** of first launch (Portainer locks initial setup after that).

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | portainer-ce container, mounts PVC at `/data` |
| `service.yaml` | LoadBalancer Service on TCP `8500` |
| `ingress.yaml` | Traefik IngressRoute for `portainer.home.ijlalahmad.dev` |
| `rbac.yaml` | ServiceAccount + ClusterRoleBinding to `cluster-admin` |
| `pvc.yaml` | `ReadWriteOnce` PVC for app state |

## Adding the Local Cluster

Portainer auto-discovers the local cluster on first start. To verify:

```
Settings → Environments → "primary" → Active
```

To add a remote cluster, generate a deployment YAML from Portainer and apply it on that cluster.

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

- **"Initial setup expired"** → you took longer than 5 min on first boot; `./setup.sh restart` and rush
- **Cluster shows "Unreachable"** → ServiceAccount missing the ClusterRoleBinding; reapply `rbac.yaml`
- **Pod CrashLoopBackOff** → PVC permissions; ensure `fsGroup` matches Portainer's expected UID
- **Slow workload list** → many resources + SD-card backed PVC; move PVC to SSD

## Links

- [Portainer Docs](https://docs.portainer.io/)
- [Kubernetes deployment reference](https://docs.portainer.io/start/install-ce/server/kubernetes/baremetal)
- [RBAC explained](https://docs.portainer.io/admin/users/teams/roles)
