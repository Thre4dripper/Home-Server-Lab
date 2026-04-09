# k3s Kubernetes Manifests

Kubernetes manifests for the Home Server Lab cluster.

## Structure

```
k3s/
├── base/           # Cluster-wide resources
│   ├── namespaces/     # Namespace definitions
│   └── sealed-secrets/ # Encrypted secrets (safe for git)
├── infra/          # Infrastructure components
│   ├── traefik/        # Ingress controller + dashboard
│   ├── longhorn/       # Distributed storage
│   └── argocd/         # GitOps controller
└── apps/           # Application workloads
    ├── dns/            # Pi-hole
    ├── dashboards/     # Dashy, Homarr, Dashdot
    ├── media/          # Jellyfin, Plex
    ├── storage/        # Filebrowser, Nextcloud, Samba, Rclone
    ├── automation/     # Home Assistant, n8n
    ├── network/        # Nginx-UI, Twingate
    ├── dev/            # Gitea, GitLab, Portainer, LocalStack
    └── downloads/      # Aria2, Deluge, qBittorrent
```

## Deployment Order

1. Namespaces
2. Sealed Secrets controller
3. Longhorn storage
4. Traefik ingress
5. Pi-hole (DNS)
6. All other apps
7. ArgoCD (manages everything after bootstrap)
