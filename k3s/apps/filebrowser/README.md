---
name: "FileBrowser"
category: "📁 Files & Storage"
purpose: "Web-based File Manager"
description: "Lightweight web UI for browsing, uploading, editing and sharing files on a shared PVC. Multi-user accounts, per-folder permissions, in-browser editor and shareable public links."
icon: "📂"
namespace: "file-management"
external_port: "8300"
domain: "files.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - pvc
features:
  - "Browser-based file management"
  - "Multi-user with per-folder ACLs"
  - "In-browser code / markdown editor"
  - "Shareable public links with optional expiry"
  - "Persistent storage on PVC"
resource_usage: "~100MB RAM"
---

# FileBrowser — Web File Manager

A single-binary, batteries-included file manager backed by a `PersistentVolumeClaim`. Used as the **primary GUI for the cluster's shared storage** — easier than `kubectl exec` for casual uploads, edits and shares.

## Features

- **Browse / upload / download** any file on the mounted PVC
- **Multi-user** with per-folder read / write / share permissions
- **In-browser editor** for text files (Markdown, code, configs)
- **Public share links** with optional password + expiry
- **Search** across the entire mounted tree

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `filebrowser` | Deployment | Single replica binary |
| `filebrowser` | Service (LoadBalancer) | Web UI on port `8300` |
| `filebrowser` | Ingress | Hosts `files.home.ijlalahmad.dev` |
| `filebrowser-data` | PVC | The files themselves |

## Prerequisites

- A StorageClass that supports `ReadWriteOnce` PVCs
- The desired root volume sized appropriately (see `pvc.yaml`)

## Quick Start

```bash
cd k3s/apps/filebrowser
./setup.sh deploy
./setup.sh status
```

Open `http://<node-ip>:8300` or `https://files.home.ijlalahmad.dev`. Default credentials are `admin / admin` — **change them immediately** from the UI.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | filebrowser container, mounts PVC at `/srv` |
| `service.yaml` | LoadBalancer Service on TCP `8300` |
| `ingress.yaml` | Traefik IngressRoute for `files.home.ijlalahmad.dev` |
| `pvc.yaml` | `ReadWriteOnce` PVC for the file root |

## Sharing the PVC with Other Apps

Because this PVC is `ReadWriteOnce`, only one Pod at a time can mount it read-write. To expose the same files to other workloads (e.g. Samba), either:

- mount the PVC `ReadOnlyMany` from the second app, **or**
- use a `ReadWriteMany` StorageClass (Longhorn / NFS) and mount it from both

## Initial Setup

```bash
# Login → change admin password from the UI
# Then create users:
./setup.sh exec
filebrowser users add alice "$(pwgen 16 1)" --perm.admin=false --scope=/alice
```

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs
./setup.sh exec        # shell into the pod (handy for `filebrowser users`)
./setup.sh restart
./setup.sh undeploy    # PVC is RETAINED
```

## Troubleshooting

- **403 / no files visible** → the user's scope doesn't include the path; check user's *Scope* setting
- **Uploads hang** → Traefik request size limit; bump `traefik.http.middlewares.large-uploads.buffering.maxRequestBodyBytes`
- **PVC full** → expand it via `kubectl patch pvc` (CSI-aware StorageClass required) or clean up with the UI
- **`forbidden` writing files** → mount `securityContext.fsGroup` matches the binary's expected uid/gid

## Links

- [FileBrowser Docs](https://filebrowser.org/)
- [CLI reference](https://filebrowser.org/cli/filebrowser-users)
- [Traefik Buffering middleware](https://doc.traefik.io/traefik/middlewares/http/buffering/)
