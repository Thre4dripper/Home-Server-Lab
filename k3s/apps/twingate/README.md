---
name: "Twingate Connector"
category: "🌐 Network & Ingress"
purpose: "Zero-Trust Remote Access"
description: "Outbound-only Twingate connector that exposes selected cluster services to authenticated users without opening any inbound port on the home router. No port forwarding, no public DNS, no VPN client config."
icon: "🛡️"
namespace: "dashboard-network"
external_port: "—"
domain: "—"
components:
  - deployment
  - sealedsecret
features:
  - "Zero-trust remote access (no port forwarding)"
  - "Outbound-only connection to Twingate edge"
  - "Per-user / per-resource access policies"
  - "Connector tokens sealed in git"
  - "Cluster-DNS aware routing"
  - "Works through CGNAT and behind any firewall"
resource_usage: "~60MB RAM"
---

# Twingate — Zero-Trust Remote Access

A Twingate connector Pod establishes an **outbound** tunnel to the Twingate control plane. Authorised devices reach internal services (ArgoCD, Homepage, Pi-hole admin, …) by hostname, with no router config required and **no inbound ports opened** on the home network.

## Why this matters

- **No port forwarding** — works behind CGNAT, double-NAT, restrictive ISP routers
- **No public DNS exposure** — services stay on internal `*.home.ijlalahmad.dev`
- **Identity-aware** — every connection authenticated against Twingate (Google, GitHub, OIDC, etc.)
- **Per-resource ACLs** — alice can reach Jellyfin, bob can also reach ArgoCD, only you reach Pi-hole admin

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `twingate-connector` | Deployment | Outbound tunnel pod |
| `twingate-tokens` | SealedSecret → Secret | `TWINGATE_ACCESS_TOKEN` + `TWINGATE_REFRESH_TOKEN` |

There is **no Service and no Ingress** — the connector dials out, traffic returns through the tunnel.

## Prerequisites

- A free Twingate network at [twingate.com](https://www.twingate.com/)
- A connector created in the Twingate admin UI → access + refresh tokens
- The Sealed Secrets controller installed
- Outbound HTTPS allowed on the Pi (almost always true)

## Quick Start

```bash
# 1. Create the connector in Twingate admin → copy access + refresh tokens

# 2. Seal the tokens
kubectl create secret generic twingate-tokens \
  --namespace dashboard-network \
  --from-literal=TWINGATE_ACCESS_TOKEN=eyJ... \
  --from-literal=TWINGATE_REFRESH_TOKEN=eyJ... \
  --dry-run=client -o yaml > /tmp/secret.yaml

../../scripts/seal.sh /tmp/secret.yaml > sealedsecret.yaml

# 3. Deploy
cd k3s/apps/twingate
./setup.sh deploy
./setup.sh status
```

Then in the Twingate admin, **add Resources** that point at internal hostnames (e.g. `homepage.home.ijlalahmad.dev`), and grant access to the right users / groups.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | Twingate connector container, env from secret |
| `sealedsecret.yaml` | Access + refresh tokens |

## Adding Resources

1. **Twingate admin → Resources → Add Resource**
2. Address: `homepage.home.ijlalahmad.dev` (or `*.home.ijlalahmad.dev` for wildcards)
3. Assign to a Group (e.g. `Family`)
4. Done — that group's devices can now reach the resource through the connector

## Management Commands

```bash
./setup.sh deploy
./setup.sh status      # check connector heartbeat
./setup.sh logs        # confirm tunnel established
./setup.sh restart
./setup.sh undeploy
```

## Rotating Tokens

```bash
# In Twingate admin: regenerate connector tokens
# Then reseal:
kubectl create secret generic twingate-tokens ... --dry-run=client -o yaml > /tmp/secret.yaml
../../scripts/seal.sh /tmp/secret.yaml > sealedsecret.yaml
git add sealedsecret.yaml && git commit -m "secret(twingate): rotate connector tokens"
./setup.sh restart
```

## Troubleshooting

- **Connector "offline" in admin** → check pod logs; usually a wrong / expired token
- **Resource unreachable** → DNS for the internal hostname not resolving inside the cluster (Pi-hole down or wrong record)
- **Connector restarts loop** → outbound 443 blocked by ISP-level firewall (rare)
- **High latency** → choose a Twingate edge POP closer to your region in the admin

## Links

- [Twingate Docs](https://www.twingate.com/docs/)
- [Connector deployment reference](https://www.twingate.com/docs/connectors-deploy-on-linux)
- [Resource ACLs](https://www.twingate.com/docs/resources-and-policies)
