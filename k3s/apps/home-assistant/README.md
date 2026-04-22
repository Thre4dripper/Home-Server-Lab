---
name: "Home Assistant"
category: "🤖 Automation"
purpose: "Smart Home Hub"
description: "Open-source home automation platform running with hostNetwork so it can speak mDNS / Zeroconf / SSDP to LAN devices (Chromecast, HomeKit, ESPHome, etc.) while still being reachable through Traefik ingress."
icon: "🏠"
namespace: "automation"
external_port: "8123"
domain: "ha.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - configmap
  - pvc
features:
  - "2,000+ device & service integrations"
  - "Visual + YAML automation builder"
  - "hostNetwork for native LAN discovery"
  - "Persistent config & history on PVC"
  - "TLS-terminated ingress via Traefik"
  - "Add-ons NOT supported (use sidecar Pods instead)"
resource_usage: "~500MB RAM"
---

# Home Assistant — Smart Home Hub

The cluster's smart-home brain. Runs with `hostNetwork: true` so it can speak the broadcast / multicast protocols (mDNS, SSDP, Zeroconf, IP multicast) that smart-home devices use for auto-discovery — something a normal Pod can't do because it lives behind a CNI overlay.

> ⚠️ **No Add-ons** — this is the *Container* image of Home Assistant, not Home Assistant OS. Add-ons (which are Docker containers) are not available; deploy them as sidecar Pods or separate workloads instead.

## Features

- **2,000+ integrations**: Zigbee, Z-Wave, Matter, ESPHome, MQTT, HomeKit, Chromecast, …
- **Visual automations** + the full YAML escape hatch
- **Lovelace dashboards** for any UI you want
- **Voice assistants** (local + cloud)
- **Long-term statistics** on a PVC

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `home-assistant` | Deployment | `hostNetwork: true`, `hostPort: 8123` |
| `home-assistant` | Service (ClusterIP) | Used only by the Ingress |
| `home-assistant` | Ingress | Hosts `ha.home.ijlalahmad.dev` |
| `home-assistant-config` | ConfigMap | Base `configuration.yaml` snippets |
| `home-assistant-data` | PVC | `/config` (state, history, integrations) |

## Why `hostNetwork`

Smart-home discovery uses mDNS (`224.0.0.251:5353`) and SSDP (`239.255.255.250:1900`). Both need the Pod to share the host's network namespace, otherwise multicast packets never reach Chromecast / HomeKit / Sonos / etc.

The trade-off: only one Home Assistant Pod can run on the host (it owns port `8123` directly).

## Prerequisites

- Pi connected via Ethernet (Wi-Fi often drops multicast)
- A StorageClass for the `/config` PVC
- (Optional) USB Zigbee / Z-Wave dongle passed through via `volumeMounts`

## Quick Start

```bash
cd k3s/apps/home-assistant
./setup.sh deploy
./setup.sh status
```

Then either:

- `http://<node-ip>:8123` (direct, host port)
- `https://ha.home.ijlalahmad.dev` (via Traefik)

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | hostNetwork pod, mounts PVC at `/config` and ConfigMap fragments |
| `service.yaml` | ClusterIP for Ingress only |
| `ingress.yaml` | Traefik IngressRoute for `ha.home.ijlalahmad.dev` |
| `configmap.yaml` | Base `configuration.yaml` (proxy headers, logger level, …) |
| `pvc.yaml` | `ReadWriteOnce` PVC, ≥ 5Gi recommended |

## Trusted Proxies

Because Traefik fronts Home Assistant, the `configuration.yaml` ConfigMap sets:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.42.0.0/16   # k3s pod CIDR (Traefik runs here)
```

## USB Device Passthrough

To attach a Zigbee / Z-Wave stick:

```yaml
# deployment.yaml
volumeMounts:
  - name: zigbee
    mountPath: /dev/ttyUSB0
volumes:
  - name: zigbee
    hostPath:
      path: /dev/serial/by-id/usb-..._-if00-port0
      type: CharDevice
securityContext:
  privileged: true
```

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs        # tail HA logs
./setup.sh exec        # shell into /config
./setup.sh restart
./setup.sh undeploy    # PVC retained
```

## Troubleshooting

- **Devices not discovered** → confirm `hostNetwork: true`, Pi on Ethernet, multicast routing enabled on the switch
- **`Loading data` forever** → first boot can take 5–10 min on SD card; move PVC to SSD
- **`Forbidden: 401`** through ingress → `trusted_proxies` not set (see above)
- **Integration crashes after upgrade** → check `home-assistant.log` on the PVC; rollback via Deployment image tag

## Links

- [Home Assistant Container Docs](https://www.home-assistant.io/installation/linux#docker-compose)
- [Trusted Proxies setup](https://www.home-assistant.io/integrations/http/#reverse-proxies)
- [Backup / restore](https://www.home-assistant.io/common-tasks/general/#backups)
