---
name: "Twingate Connector"
category: "🔐 Security & Access"
purpose: "Zero-Trust Remote Access"
description: "Lightweight connector that bridges your private network to the Twingate fabric."
icon: "🛡️"
features:
  - "Outbound-only connector for safe remote access"
  - "Automatic labeling for auditing and routing"
  - "Host networking for minimal latency"
  - "Simple setup script with health validation"
resource_usage: "~75MB RAM"
---

# Twingate Connector

Deploy a self-hosted Twingate Connector to link your home lab resources with the Twingate zero-trust network. The connector keeps a persistent outbound tunnel to the Twingate controller so users can securely reach internal services without opening inbound ports on your router.

## Prerequisites

- A Twingate account with an existing Network defined
- Connector service account (access + refresh token pair)
- The network slug (e.g. `mycompany.twingate.com` → `mycompany`)
- Docker Engine + Docker Compose installed on the host

> Generate the access/refresh token pair from **Network > Remote Networks > Select Network > Connectors > + Add Connector** inside the Twingate Admin console. Tokens are shown only once—store them securely.

## Quick Start

1. **Configure environment**
   ```bash
   cd twingate
   cp .env.example .env
   # Fill in TWINGATE_NETWORK / ACCESS_TOKEN / REFRESH_TOKEN
   ```
2. **Bootstrap the connector**
   ```bash
   ./setup.sh
   ```
3. **Verify in the Admin console**
   - Open https://controller.twingate.com/ and check the connector status
   - Assign resources & access policies once the connector is online

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `CONTAINER_NAME` | Docker container name for the connector | No | `twingate-connector` |
| `TWINGATE_NETWORK` | Network slug (e.g. `mycompany`) | **Yes** | — |
| `TWINGATE_ACCESS_TOKEN` | Connector access token from Admin console | **Yes** | — |
| `TWINGATE_REFRESH_TOKEN` | Connector refresh token from Admin console | **Yes** | — |
| `TWINGATE_DNS` | Custom DNS servers (comma separated) | No | empty (connector uses host defaults) |
| `TWINGATE_LABEL_HOSTNAME` | Label used in Twingate UI for this host | No | `home-server` (modify as needed) |
| `TWINGATE_LOG_ANALYTICS` | Log analytics level (`off`, `v1`, `v2`) | No | `v2` |
| `TWINGATE_LABEL_DEPLOYED_BY` | Free-form label describing deployment method | No | `docker` |

All secrets stay inside `.env`, which is ignored by Git.

## Management Commands

```bash
./setup.sh            # validates config and starts/updates the connector
./setup.sh status     # show container status
./setup.sh logs       # stream connector logs
./setup.sh down       # stop and remove the connector
./setup.sh update     # pull latest image and recreate
```

The connector runs in `network_mode: host`, so there are no exposed ports. Connectivity is handled entirely by outbound TLS tunnels initiated by the container.

## Data & Networking

- **State**: The connector is stateless; all credentials come from environment variables. Refresh tokens can be rotated in the Admin console at any time.
- **Networking**: Host networking ensures the connector sees the same routes/DNS as the host OS. Grant access only to networks you intend to publish through Twingate.

## Security Notes

- Treat the access and refresh tokens like passwords; anyone with both can impersonate the connector.
- Rotate tokens regularly via the Admin console and update `.env` before running `./setup.sh update`.
- Keep the host OS patched—compromise of the host compromises your Twingate deployment.

## Troubleshooting

1. **Connector stuck provisioning**  
   - Verify the host clock is in sync (NTP).  
   - Confirm outbound TLS (TCP 443) is allowed.
2. **`setup.sh` refuses to start**  
   - Ensure `.env` values are not empty or placeholder text.  
   - Run `docker info` to confirm Docker is healthy.
3. **Connector offline in admin console**  
   - Run `./setup.sh logs` and look for authentication errors.  
   - Regenerate the access/refresh token pair and update `.env`.

## Useful Links

- [Twingate Documentation](https://www.twingate.com/docs)
- [Connector Container on Docker Hub](https://hub.docker.com/r/twingate/connector)
- [Status Page](https://status.twingate.com/)
