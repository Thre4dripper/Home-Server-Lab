---
name: "ArgoCD"
category: "🛠️ Infra & GitOps"
purpose: "GitOps Continuous Delivery"
description: "Declarative, pull-based GitOps controller that watches this repository and continuously reconciles every k3s/apps/* manifest into the running cluster."
icon: "🚀"
namespace: "argocd"
external_port: "—"
domain: "argocd.home.ijlalahmad.dev"
components:
  - deployment
  - statefulset
  - service
  - ingress
features:
  - "Pull-based GitOps from this repository"
  - "Application + ApplicationSet CRDs"
  - "Self-healing & automatic pruning"
  - "Web UI, CLI, REST and gRPC APIs"
  - "RBAC + SSO ready (Dex / OIDC)"
resource_usage: "~600MB RAM"
---

# ArgoCD — GitOps Continuous Delivery

ArgoCD is the **single deployment surface** for this cluster. After bootstrap, you never `kubectl apply` an app again — you `git push` and ArgoCD reconciles the difference between git and the live cluster, healing drift and pruning anything that no longer belongs.

## Why ArgoCD here

- **Declarative**: every workload is a YAML file in this repo, version-controlled and reviewable
- **Pull-based**: the cluster pulls from git, no CI needs cluster credentials
- **Visual**: every Application's sync status and resource tree is visible in the web UI
- **Auditable**: every change is a git commit; rollbacks are `git revert`

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `argocd-server` | Deployment | Web UI + API server |
| `argocd-repo-server` | Deployment | Clones git, renders manifests (Kustomize/Helm) |
| `argocd-application-controller` | StatefulSet | Reconciles Applications against the cluster |
| `argocd-applicationset-controller` | Deployment | Generates Applications dynamically |
| `argocd-redis` | Deployment | Cache for repo-server and controller |
| `argocd-server` Service | ClusterIP | Routed by the ingress |
| `argocd-server` Ingress | Traefik | Hosts `argocd.home.ijlalahmad.dev` |

## Prerequisites

- k3s cluster up and running
- Traefik ingress controller installed (`infra/traefik/`)
- `kubectl` configured against the cluster

## Quick Start

```bash
# Bootstrap (run once from k3s/)
kubectl apply -k infra/argocd/

# Watch it come up
kubectl get pods -n argocd -w

# Use the wrapper for everyday operations
cd apps/argocd
./setup.sh status
./setup.sh password   # initial admin password
./setup.sh logs server
```

## Bootstrap the Root Application

After ArgoCD is running, point it at this repo so it manages everything else:

```bash
kubectl apply -f infra/argocd/root-app.yaml
# This is an ApplicationSet that creates one Application per k3s/apps/* folder.
```

From this moment on, every commit touching `k3s/apps/**` triggers a sync.

## Configuration

| Concern | Where |
|---------|-------|
| Server TLS | Terminated at Traefik via cert-manager |
| RBAC | `infra/argocd/argocd-rbac-cm.yaml` ConfigMap |
| Repo credentials | SealedSecret in `infra/argocd/` (only needed for private repos) |
| Notifications | Optional `argocd-notifications-cm` ConfigMap |

## Accessing the UI

- **Web**: `https://argocd.home.ijlalahmad.dev`
- **CLI**: `argocd login argocd.home.ijlalahmad.dev --grpc-web`
- **Initial password**: `./setup.sh password`

## Management Commands

```bash
./setup.sh status        # pods + recent events
./setup.sh logs <component>   # tail logs (server, controller, repo, …)
./setup.sh restart <component>
./setup.sh password      # print bootstrap admin password
./setup.sh resources     # CPU / memory usage of argocd pods
```

Or use `kubectl` directly:

```bash
kubectl -n argocd get applications
kubectl -n argocd describe application homepage
argocd app sync homepage
argocd app rollback homepage 3
```

## Troubleshooting

- **Out of sync forever** → check `argocd app diff <app>` and the `repo-server` logs
- **ComparisonError: connection timeout** → repo-server can't reach git; verify SealedSecret + DNS
- **Application stuck in Progressing** → check the underlying pod (`kubectl describe pod -n <ns>`)
- **OOMKilled `application-controller`** → bump the controller's memory limit in `infra/argocd/`

## Links

- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [Application CRD](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
- [ApplicationSet Generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
