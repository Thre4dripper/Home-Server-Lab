---
name: "Forgejo"
category: "🛠️ Infra & GitOps"
purpose: "Self-hosted Git Forge & CI"
description: "Lightweight Git forge with pull requests, issues, a container registry and Forgejo Actions CI. Backed by the cluster Postgres instead of SQLite, with a sibling runner that executes CI jobs on the host Docker daemon."
icon: "🔨"
namespace: "git"
external_port: "8900"
domain: "forgejo.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - pvc
  - sealedsecret
  - configmap
features:
  - "Pull requests, issues, wikis, releases"
  - "Forgejo Actions CI (GitHub Actions-compatible workflows)"
  - "Built-in container / package registry"
  - "SSH clone over a dedicated LoadBalancer port"
  - "Postgres-backed for real concurrency"
  - "Self-registering ARM64 runner on host Docker"
resource_usage: "~400MB RAM"
---

# Forgejo — Git Forge & CI

The cluster's own GitHub. Repos, issues, PRs, releases and a container registry, plus **Forgejo Actions** for CI. Unlike the Docker-stack Gitea, this deployment uses the shared **Postgres** in the `databases` namespace rather than SQLite, so concurrent CI jobs and web traffic don't lock the database.

CI runs on a **separate runner Deployment** that talks to the *host* Docker daemon via a mounted socket. Job containers are therefore siblings of k3s — no DinD, no privileged pods.

## Features

- **Full forge**: pull requests, issues, labels, milestones, wikis, releases
- **Forgejo Actions** — GitHub Actions-compatible workflow syntax
- **Package registry** enabled (`FORGEJO__packages__ENABLED=true`) — OCI images, npm, PyPI, …
- **SSH clone** on port `2222` alongside HTTPS
- **Postgres backend** — `postgres.databases.svc.cluster.local:5432`, database `forgejo`, user `forgejo_user`
- **ARM64-native CI** via `catthehacker/ubuntu:act-*` images — no QEMU emulation

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `forgejo` | Deployment | Forgejo server, `Recreate` strategy (single writer) |
| `forgejo` | Service (LoadBalancer) | Web on `8900`, SSH on `2222` |
| `forgejo` | IngressRoute | Hosts `forgejo.home.ijlalahmad.dev` on `websecure` |
| `forgejo-data-pvc` | PV + PVC (20Gi) | Repos, LFS, avatars, config — `Retain` |
| `forgejo-secret` | SealedSecret | DB password, `SECRET_KEY`, `INTERNAL_TOKEN` |
| `forgejo-runner` | Deployment | CI runner — **`replicas: 0` by default** |
| `forgejo-runner-config` | ConfigMap | Runner `config.yml` (capacity, job limits) |
| `forgejo-runner-data-pvc` | PV + PVC (1Gi) | `.runner` registration file + workspace |
| `forgejo-runner-secret` | SealedSecret | One-time runner registration token |

Storage is a `Retain` hostPath PV at `/home/pi/k3s-volumes/apps/forgejo`.

## Prerequisites

- **Postgres running** in the `databases` namespace with a `forgejo` database and `forgejo_user` role:
  ```bash
  cd k3s/scripts
  ./db-user.sh postgres create forgejo_user 'SecurePass123!' forgejo
  ```
- Generate the server secrets before sealing:
  ```bash
  openssl rand -hex 32   # → FORGEJO_SECRET_KEY
  openssl rand -hex 32   # → FORGEJO_INTERNAL_TOKEN
  ```
  Put these (plus `FORGEJO_DB_PASSWORD`) in `secret.yaml`, then `./setup.sh seal`.

## Quick Start

```bash
cd k3s/apps/forgejo
./setup.sh deploy
./setup.sh status
```

Open `https://forgejo.home.ijlalahmad.dev` (or `http://<node-ip>:8900`) and create the admin account.

**Immediately after first login**, close registration — either in the UI (*Site Admin → Management → Disable self-registration*) or by setting `FORGEJO__service__DISABLE_REGISTRATION=true` in `deployment.yaml` and redeploying.

Clone URLs:

```bash
git clone https://forgejo.home.ijlalahmad.dev/<user>/<repo>.git
git clone ssh://git@forgejo.home.ijlalahmad.dev:2222/<user>/<repo>.git
```

## Enabling CI (the runner)

The runner ships **scaled to zero** so a fresh cluster doesn't burn Pi CPU. To turn it on:

1. In Forgejo: *Site Administration → Actions → Runners → Create new runner*, copy the token.
2. Paste it into `runner-secret.yaml` as `FORGEJO_RUNNER_REGISTRATION_TOKEN`.
3. Seal and apply:
   ```bash
   kubeseal --format yaml < runner-secret.yaml > runner-sealedsecret.yaml
   kubectl apply -f runner-pvc.yaml -f runner-configmap.yaml \
                 -f runner-sealedsecret.yaml -f runner-deployment.yaml
   kubectl scale deploy/forgejo-runner -n git --replicas=1
   ```

The runner registers itself on first boot and persists `.runner` to its PVC — the token is used exactly once.

### Runner design notes

- `FORGEJO_INSTANCE_URL` is the **LAN IP + LoadBalancer port** (`http://192.168.0.108:8900`), not the cluster DNS name. Job containers are spawned on host Docker and cannot resolve k3s CoreDNS, so `actions/checkout` would fail against an in-cluster name.
- `supplementalGroups: [988]` grants access to the host `docker` group for `/var/run/docker.sock`.
- Job containers are capped at `--cpus=2 --memory=1g` (`runner-configmap.yaml`) so CI can't starve Forgejo or the rest of the cluster. Runner `capacity: 2`.
- `FORGEJO__actions__DEFAULT_ACTIONS_URL=https://github.com` — `data.forgejo.org` only mirrors a subset of actions.
- Runner labels advertise `ubuntu-latest`, `ubuntu-22.04`, `ubuntu-20.04`, `self-hosted`, `linux`, `arm64`.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | Forgejo server, Postgres + server + security env, health probes |
| `service.yaml` | LoadBalancer — web `8900`, SSH `2222` |
| `ingress.yaml` | Traefik IngressRoute on `websecure` with wildcard TLS |
| `pvc.yaml` | `Retain` hostPath PV + 20Gi PVC for `/data` |
| `sealedsecret.yaml` | Sealed DB password, secret key, internal token |
| `runner-deployment.yaml` | Runner (replicas `0`), host docker socket, self-registration |
| `runner-configmap.yaml` | Runner `config.yml` — capacity, timeouts, job container limits |
| `runner-pvc.yaml` | `Retain` hostPath PV + 1Gi PVC for the runner |
| `runner-sealedsecret.yaml` | Sealed runner registration token |

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs                # stream server logs
./setup.sh shell               # sh inside the pod
./setup.sh restart
./setup.sh pvc                 # PV/PVC status + host paths
./setup.sh seal                # secret.yaml → sealedsecret.yaml
./setup.sh argocd-status       # ArgoCD sync/health
./setup.sh diff                # drift between cluster and git
./setup.sh teardown            # remove resources (PVCs kept)
./setup.sh teardown --purge    # ALSO deletes PVCs/PVs — destroys all repos
```

## Troubleshooting

- **Pod `CrashLoopBackOff` on first deploy** → Postgres unreachable or the `forgejo` database / `forgejo_user` role doesn't exist yet. Create them with `db-user.sh`, then `./setup.sh restart`.
- **`liveness probe failed` during heavy CI** → expected headroom is already generous (15s timeout × 5 failures = 5 minutes). If it still fires, lower runner `capacity` or the job container CPU cap.
- **`actions/checkout` fails with a DNS error** → `FORGEJO_INSTANCE_URL` must be the LAN IP, not a `*.svc.cluster.local` name.
- **Runner never appears in the UI** → the registration token is single-use. Generate a fresh one, re-seal, delete the `.runner` file on the PVC, and restart the runner pod.
- **`git push` over SSH refused** → confirm the LoadBalancer is publishing `2222`: `kubectl get svc forgejo -n git`.
- **Registry pushes rejected** → tag against the external host, e.g. `forgejo.home.ijlalahmad.dev/<user>/<image>:<tag>`.

## Links

- [Forgejo Docs](https://forgejo.org/docs/latest/)
- [Forgejo Actions](https://forgejo.org/docs/latest/user/actions/)
- [Runner configuration reference](https://forgejo.org/docs/latest/admin/actions/)
- [Config cheat sheet (`FORGEJO__section__KEY`)](https://forgejo.org/docs/latest/admin/config-cheat-sheet/)
