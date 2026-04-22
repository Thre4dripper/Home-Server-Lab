---
name: "Jellyfin"
category: "🎬 Media & Entertainment"
purpose: "Self-hosted Media Server"
description: "Free media system for movies, shows, music and photos with hardware-accelerated transcoding on the Pi's VideoCore VI GPU. Library and metadata persist on a PVC."
icon: "🎬"
namespace: "media"
external_port: "8200"
domain: "jellyfin.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - pvc
features:
  - "Movies, TV, music, photos"
  - "Hardware transcoding (GPU support where available)"
  - "Multi-user with per-library access"
  - "Live TV / DVR support"
  - "Sync clients for iOS, Android, web, TV"
  - "Persistent metadata, library and cache on PVC"
resource_usage: "~1GB RAM"
---

# Jellyfin — Media Server

The cluster's free, self-hosted alternative to Plex / Emby. Library, metadata and cache live on a `PersistentVolumeClaim`. The Pod accesses Pi GPU device nodes (`/dev/video10-12`) for hardware-accelerated transcoding.

## Features

- **All media**: movies, TV, music, photos, books, audiobooks
- **Hardware transcoding** via GPU acceleration (where supported: Intel Quick Sync, NVIDIA NVENC, AMD AMF, V4L2 on SBCs)
- **Multi-user** with parental controls and per-library permissions
- **Live TV / DVR** with HDHomeRun, Xteve, etc.
- **Native clients** for every OS + browser
- **Metadata** auto-fetched from TMDB, TVDB, MusicBrainz

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `jellyfin` | Deployment | Single replica, mounts video devices |
| `jellyfin` | Service (LoadBalancer) | Web UI on port `8200` |
| `jellyfin` | Ingress | Hosts `jellyfin.home.ijlalahmad.dev` |
| `jellyfin-config` | PVC | App config + metadata DB |
| `jellyfin-media` | PVC | The actual media files |

## Hardware Transcoding

To enable VideoCore VI transcoding, the Deployment exposes:

```yaml
securityContext:
  privileged: true   # required for /dev/video1x access
volumeMounts:
  - { name: dri,     mountPath: /dev/dri }
  - { name: video10, mountPath: /dev/video10 }
  - { name: video11, mountPath: /dev/video11 }
  - { name: video12, mountPath: /dev/video12 }
volumes:
  - { name: dri,     hostPath: { path: /dev/dri,     type: Directory }  }
  - { name: video10, hostPath: { path: /dev/video10, type: CharDevice } }
  - { name: video11, hostPath: { path: /dev/video11, type: CharDevice } }
  - { name: video12, hostPath: { path: /dev/video12, type: CharDevice } }
```

Then enable **Dashboard → Playback → V4L2** in the Jellyfin UI.

## Prerequisites

- A StorageClass that supports `ReadWriteOnce` PVCs
- Sufficient disk for media (recommend external SSD bind-mounted via hostPath PV)
- Pi user (uid `1000`) owns the media files

## Quick Start

```bash
cd k3s/apps/jellyfin
./setup.sh deploy
./setup.sh status
```

Open `https://jellyfin.home.ijlalahmad.dev` (or `http://<node-ip>:8200`) and run the first-time setup wizard.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | jellyfin container, hardware device mounts, PUID/PGID env |
| `service.yaml` | LoadBalancer Service on TCP `8200` |
| `ingress.yaml` | Traefik IngressRoute with WebSocket support |
| `pvc.yaml` | Two PVCs: `jellyfin-config` (10Gi) and `jellyfin-media` (large) |

## Storage Layout

| Path in container | PVC | Purpose |
|-------------------|-----|---------|
| `/config` | `jellyfin-config` | metadata DB, plugins, transcoding config |
| `/cache` | `emptyDir` (memory-backed) | transcoding cache, regenerable |
| `/media` | `jellyfin-media` | library files (movies, tv, music, …) |

For very large libraries, prefer mounting an external SSD via a `hostPath` PV instead of a CSI-provisioned PVC.

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs            # tail jellyfin logs
./setup.sh exec            # bash inside the pod
./setup.sh restart
./setup.sh undeploy        # PVCs RETAINED
```

## Troubleshooting

- **Transcoding fails / "no hardware acceleration"** → check `/dev/video1x` permissions; pod may need `privileged: true`
- **Permission denied on media** → `chown -R 1000:1000 /path/to/media` on the host (or set PUID/PGID to match)
- **Slow library scan** → SD card I/O bottleneck; move PVC to SSD
- **WebSocket disconnects** → ensure Traefik IngressRoute keeps `Connection: Upgrade` headers
- **OOMKilled while transcoding** → bump memory limit; or transcode lower-bitrate variants

## Links

- [Jellyfin Docs](https://jellyfin.org/docs/)
- [Hardware acceleration on Pi](https://jellyfin.org/docs/general/administration/hardware-acceleration/raspberry-pi/)
- [Reverse proxy setup](https://jellyfin.org/docs/general/networking/traefik2/)
