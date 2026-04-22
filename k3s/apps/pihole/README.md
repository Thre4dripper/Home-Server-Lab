---
name: "Pi-hole"
category: "🌐 Network & Ingress"
purpose: "Network-wide Ad Blocker & DNS"
description: "DNS sinkhole that blocks ads and trackers for every device on the LAN. Runs with hostNetwork to claim port 53 directly on the Pi. Custom local DNS records (e.g. *.home.ijlalahmad.dev) are projected from a ConfigMap."
icon: "🛡️"
namespace: "dashboard-network"
external_port: "8110"
domain: "pihole.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - configmap
  - sealedsecret
  - pvc
features:
  - "Network-wide DNS-level ad and tracker blocking"
  - "Local DNS records via ConfigMap (custom dnsmasq.d snippet)"
  - "Detailed query analytics dashboard"
  - "hostNetwork for native port 53 (UDP/TCP)"
  - "Admin password sealed in git"
  - "Persistent gravity DB and query logs on PVC"
resource_usage: "~150MB RAM"
---

# Pi-hole — DNS Sinkhole & Local DNS

Cluster + LAN DNS authority. Blocks ads / trackers via aggregated blocklists, **and** serves the internal `*.home.ijlalahmad.dev` and `*.lan` zones for the homelab. Bound to host port 53 via `hostNetwork: true` — only one Pi-hole Pod can run on the host.

## Features

- **Block lists**: tens of thousands of trackers, malware, ads
- **Local DNS**: `pihole.home.ijlalahmad.dev`, `homepage.home.ijlalahmad.dev`, … all resolved locally
- **Analytics**: per-client query timeline, top blocked, top permitted
- **Allow / Block lists** managed via the web admin
- **DHCP** capability (disabled in this setup; router runs DHCP)
- **Persistent**: query logs + gravity DB live on the PVC

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `pihole` | Deployment | `hostNetwork: true`, owns ports 53/UDP, 53/TCP |
| `pihole` | Service (LoadBalancer) | Admin web UI on port `8110` |
| `pihole` | Ingress | Hosts `pihole.home.ijlalahmad.dev` |
| `pihole-custom-dns` | ConfigMap | Mounted as `/etc/dnsmasq.d/02-custom.conf` |
| `pihole-secrets` | SealedSecret → Secret | `WEBPASSWORD` for admin login |
| `pihole-data` | PVC | etc-pihole + etc-dnsmasq.d state |

## Why `hostNetwork`

- Port 53 is privileged and broadcast-heavy
- `hostNetwork: true` lets Pi-hole own port 53 on the node IP without translation
- Trade-off: only one Pi-hole per node (fine — there's only one Pi)

## Prerequisites

- The Pi's port 53 is free (don't run `systemd-resolved`'s stub listener — disable it)
- Sealed Secrets controller installed
- A StorageClass for the PVC

## Quick Start

```bash
cd k3s/apps/pihole
./setup.sh deploy
./setup.sh status
```

Open `https://pihole.home.ijlalahmad.dev/admin` (or `http://<node-ip>:8110/admin`).

Then point your **router's DNS** at the Pi's IP — every device on the LAN now uses Pi-hole.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | hostNetwork pod, mounts PVC + ConfigMap + Secret |
| `service.yaml` | LoadBalancer Service on TCP `8110` (web UI) |
| `ingress.yaml` | Traefik IngressRoute for `pihole.home.ijlalahmad.dev` |
| `configmap.yaml` | `02-custom.conf` with all `*.home.ijlalahmad.dev` records |
| `sealedsecret.yaml` | `WEBPASSWORD` for the admin UI |
| `pvc.yaml` | `ReadWriteOnce` PVC for `/etc/pihole` + `/etc/dnsmasq.d` |

## Local DNS Records

Edit `configmap.yaml` to add a record:

```ini
# /etc/dnsmasq.d/02-custom.conf
address=/homepage.home.ijlalahmad.dev/192.168.0.108
address=/jellyfin.home.ijlalahmad.dev/192.168.0.108
address=/argocd.home.ijlalahmad.dev/192.168.0.108
```

Apply and restart Pi-hole:

```bash
git add configmap.yaml && git commit -m "pihole: add new local record"
git push
# ArgoCD picks it up; or apply manually:
kubectl apply -f configmap.yaml
./setup.sh restart
```

## Secret Workflow

```bash
kubectl create secret generic pihole-secrets \
  --namespace dashboard-network \
  --from-literal=WEBPASSWORD=$(pwgen 24 1) \
  --dry-run=client -o yaml > /tmp/secret.yaml

../../scripts/seal.sh /tmp/secret.yaml > sealedsecret.yaml
```

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs        # tail dnsmasq + lighttpd
./setup.sh exec        # shell inside the pod
./setup.sh restart
./setup.sh undeploy    # PVC retained
```

## Troubleshooting

- **Port 53 already in use** → disable `systemd-resolved` stub on the host (`DNSStubListener=no`)
- **Web admin loops on login** → reseal `WEBPASSWORD`; restart pod
- **Records not resolving** → ConfigMap not mounted at `/etc/dnsmasq.d/`; check pod spec
- **No analytics after restart** → PVC didn't bind; check `kubectl describe pvc`
- **Other devices still see ads** → router DNS not pointed at Pi, or device hardcoded to 8.8.8.8

## Links

- [Pi-hole Docs](https://docs.pi-hole.net/)
- [Local DNS records guide](https://docs.pi-hole.net/guides/dns/custom-dns/)
- [`pihole` CLI reference](https://docs.pi-hole.net/main/post-install/)
