---
name: "Samba"
category: "📁 Files & Storage"
purpose: "SMB / CIFS File Share"
description: "Samba server exposing a PVC over SMB on the LAN for native macOS, Windows and Linux file-sharing — pure L4, no ingress, just a LoadBalancer on TCP 445."
icon: "🗂️"
namespace: "file-management"
external_port: "445"
domain: "—"
components:
  - deployment
  - service
  - configmap
  - sealedsecret
  - pvc
features:
  - "SMB / CIFS share on LAN port 445"
  - "Multi-user with per-share ACLs"
  - "Configuration via ConfigMap (smb.conf)"
  - "Credentials sealed in git"
  - "Backed by a single PVC"
  - "macOS Finder + Windows Explorer + Linux smbclient compatible"
resource_usage: "~80MB RAM"
---

# Samba — LAN File Share

Native SMB share for the homelab. Pure L4 service — no Traefik ingress involved (SMB is not HTTP). The LoadBalancer publishes TCP `445` directly on the node IP, so any LAN device can mount the share.

## Features

- **Native protocol**: macOS Finder ⌘K, Windows `\\<ip>\share`, Linux `mount -t cifs`
- **Multi-user**: per-share ACLs, guest mode optional
- **Config in git**: `smb.conf` is a ConfigMap, version-controlled
- **Sealed credentials**: SMB user passwords in a SealedSecret
- **Single source of truth**: one PVC, exposed to many clients

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `samba` | Deployment | samba container |
| `samba` | Service (LoadBalancer) | TCP `445` on the node IP |
| `samba-config` | ConfigMap | `smb.conf` — share definitions |
| `samba-users` | SealedSecret → Secret | SMB user passwords |
| `samba-data` | PVC | The share root |

## Prerequisites

- LAN port 445 not used by the host's native Samba (`systemctl disable --now smbd nmbd`)
- A StorageClass supporting `ReadWriteOnce`
- The Sealed Secrets controller installed

## Quick Start

```bash
cd k3s/apps/samba
./setup.sh deploy
./setup.sh status
```

Then mount from any LAN device:

```bash
# macOS Finder: ⌘K → smb://<node-ip>/files
# Linux:
sudo mount -t cifs //<node-ip>/files /mnt/files \
  -o user=alice,uid=$(id -u),gid=$(id -g)
# Windows: File Explorer → \\<node-ip>\files
```

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | samba container, mounts PVC + ConfigMap + Secret |
| `service.yaml` | LoadBalancer Service on TCP `445` |
| `configmap.yaml` | Full `smb.conf` with `[global]` + `[files]` (and any other shares) |
| `sealedsecret.yaml` | SMB user passwords |
| `pvc.yaml` | `ReadWriteOnce` PVC mounted at the share root |

## Adding a User

```bash
# 1. Generate the SMB password file locally
( echo "alice:$(openssl rand -base64 12):..." ) > /tmp/smbusers

# 2. Or, easier: use smbpasswd inside the running pod
./setup.sh exec
smbpasswd -a alice
```

If you go the secret route, reseal it after each change.

## Editing Shares

Edit `configmap.yaml` and add a `[shareName]` section:

```ini
[backups]
  path = /share/backups
  browseable = yes
  read only = no
  valid users = alice bob
  create mask = 0660
  directory mask = 0770
```

Commit, push, ArgoCD applies, then:

```bash
./setup.sh restart
```

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs        # smbd + nmbd
./setup.sh exec
./setup.sh restart
./setup.sh undeploy    # PVC retained
```

## Troubleshooting

- **macOS Finder says "operation could not be completed"** → host's `smbd` is bound to 445; disable it
- **EXTERNAL-IP `<pending>`** → another LoadBalancer claimed `:445`; only one allowed per node
- **`NT_STATUS_LOGON_FAILURE`** → password mismatch; reseal credentials
- **Permission denied writing files** → check `force user` / `create mask` in `smb.conf`
- **mDNS / autodiscovery missing** → SMB itself doesn't need it; if you want shares to appear in Finder sidebar, add an Avahi sidecar Pod

## Links

- [Samba Wiki](https://wiki.samba.org/)
- [smb.conf manual](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html)
- [SMB on Kubernetes patterns](https://github.com/dperson/samba)
