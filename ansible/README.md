# ⚙️ Ansible — Bare-Metal Provisioning

[![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white)](https://www.ansible.com/)

> **Provision a homelab server from scratch — OS hardening, Docker, k3s, kubectl, kubeseal, Helm — everything needed to run this repo's Docker and k3s stacks, in one idempotent playbook.**

This is the answer to *"my server died and I had to reinstall everything from scratch."* Run this once on a fresh server, and you're ready to deploy any service in this repo.

---

## 🎯 What This Does

One playbook (`site.yml`) that installs and configures:

| Role | What it installs | Why |
|------|------------------|-----|
| **base** | Essential packages (git, curl, jq, vim, htop, btop, etc.), timezone, locale, SSH hardening, firewall (UFW/firewalld) | Foundation for any server |
| **docker** | Docker Engine + Docker Compose v2 via official script, user added to `docker` group | Required for all `docker/` services |
| **kubectl** | kubectl binary (matching k3s version) | Manage k3s cluster |
| **k3s** | k3s single-node cluster, kubeconfig copied to user's `~/.kube/config` | Required for all `k3s/apps/` services |
| **kubeseal** | kubeseal CLI for Sealed Secrets | Encrypt secrets into git-safe SealedSecrets |
| **helm** | Helm 3 + common repos (stable, bitnami, argo) | Deploy Helm charts (ArgoCD, etc.) |
| **homelab** | Clone this repository to the server, set ownership, create data directories | Ready-to-use homelab repo |

**Idempotent** — safe to run repeatedly. If Docker is already installed, it skips the install step. If k3s is running, it verifies and moves on.

**Generic** — works on Debian/Ubuntu and RHEL/Fedora/CentOS. Auto-detects architecture (`amd64` / `arm64`) and downloads the right binaries.

---

## 🚀 Quick Start

### Prerequisites

- A fresh Linux server (Debian/Ubuntu/RHEL/Fedora) with SSH access
- Ansible installed on your **local machine** (not the target server)
- SSH key-based authentication to the target server
- `sudo` access on the target server

```bash
# On your local machine (macOS / Linux / WSL)
# Install Ansible
pip install ansible

# Or via package manager:
# macOS:    brew install ansible
# Ubuntu:   sudo apt install ansible
# Fedora:   sudo dnf install ansible
```

### Step 1 — Configure inventory

Edit [`inventory.yml`](./inventory.yml) to point at your server:

```yaml
all:
  children:
    homelab_servers:
      hosts:
        homelab-01:
          ansible_host: 192.168.1.42  # Your server's IP or hostname
          ansible_user: youruser       # SSH user
```

If you're running this on the target server itself (not recommended for initial setup, but works):

```yaml
hosts:
  localhost:
    ansible_connection: local
```

### Step 2 — Test connectivity

```bash
ansible homelab_servers -i inventory.yml -m ping
```

Expected output:

```
homelab-01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Step 3 — Run the playbook

**Full provisioning** (all roles, ~10–15 minutes):

```bash
ansible-playbook site.yml
```

**Dry run** (check what would change without making changes):

```bash
ansible-playbook site.yml --check --diff
```

**Skip k3s** (Docker-only setup):

```bash
ansible-playbook site.yml --skip-tags k3s,kubectl,kubeseal,helm
```

**Install only Docker**:

```bash
ansible-playbook site.yml --tags docker
```

---

## 📁 Structure

```
ansible/
├── ansible.cfg           # Ansible configuration (inventory path, SSH settings)
├── inventory.yml         # Host definitions (your server IPs/hostnames)
├── group_vars/
│   └── all.yml           # Global variables (timezone, packages, versions)
├── site.yml              # Main playbook (orchestrates all roles)
└── roles/
    ├── base/             # Base system setup
    │   ├── tasks/main.yml
    │   └── handlers/main.yml
    ├── docker/           # Docker + Compose install
    │   ├── tasks/main.yml
    │   └── handlers/main.yml
    ├── k3s/              # k3s cluster install
    │   └── tasks/main.yml
    ├── kubectl/          # kubectl binary install
    │   └── tasks/main.yml
    ├── kubeseal/         # kubeseal CLI install
    │   └── tasks/main.yml
    ├── helm/             # Helm 3 install + repos
    │   └── tasks/main.yml
    └── homelab/          # Clone this repo, set up directories
        └── tasks/main.yml
```

---

## ⚙️ Configuration

All configurable variables are in [`group_vars/all.yml`](./group_vars/all.yml). Key ones:

```yaml
# System
timezone: "UTC"
locale: "en_US.UTF-8"

# SSH hardening
ssh_port: 22
ssh_permit_root_login: "no"
ssh_password_authentication: "no"

# Firewall ports
firewall_allowed_ports:
  - { port: "22", proto: "tcp", comment: "SSH" }
  - { port: "80", proto: "tcp", comment: "HTTP" }
  - { port: "443", proto: "tcp", comment: "HTTPS" }
  - { port: "6443", proto: "tcp", comment: "k3s API" }
  - { port: "8080:8900", proto: "tcp", comment: "Homelab services" }

# Storage paths (override for external SSD, NFS, etc.)
docker_data_root: "/var/lib/docker"        # Default
k3s_data_dir: "/var/lib/rancher/k3s"       # Default
# docker_data_root: "/mnt/ssd/docker"      # Example: external SSD
# k3s_data_dir: "/mnt/ssd/k3s"

# Tool versions
k3s_version: "v1.34.6+k3s1"
kubectl_version: "{{ k3s_version | regex_replace('\\+k3s.*', '') }}"
kubeseal_version: "0.27.2"
helm_version: "3.16.4"

# Homelab repo
homelab_repo_url: "https://github.com/Thre4dripper/Home-Server-Lab.git"
homelab_repo_dest: "/home/{{ homelab_user }}/Home-Server-Lab"
homelab_clone_repo: true
```

### Per-host overrides

Create `host_vars/<hostname>.yml` to override for a specific server:

```bash
mkdir -p host_vars
cat > host_vars/homelab-01.yml <<EOF
timezone: "America/New_York"
docker_data_root: "/mnt/ssd/docker"
k3s_data_dir: "/mnt/ssd/k3s"
EOF
```

---

## 🔒 Security Notes

### SSH Hardening

The `base` role applies SSH hardening by default:

- Disables root login
- Disables password authentication (SSH keys only)
- Validates changes before restarting SSH (so you don't lock yourself out)

**Before running:** make sure your SSH key is in `~/.ssh/authorized_keys` on the target server.

### Firewall

UFW (Debian/Ubuntu) or firewalld (RHEL/Fedora) is enabled with the ports listed in `firewall_allowed_ports`. If you need additional ports (e.g., for a specific service), add them to `group_vars/all.yml`:

```yaml
firewall_allowed_ports:
  - { port: "22", proto: "tcp", comment: "SSH" }
  - { port: "8096", proto: "tcp", comment: "Jellyfin" }
  - { port: "9000", proto: "tcp", comment: "Portainer" }
```

### Secrets

This playbook does **not** handle secrets for individual services — it only sets up the infrastructure. Secrets for k3s apps are managed via SealedSecrets (see [`k3s/scripts/seal.sh`](../k3s/scripts/seal.sh)). Secrets for Docker services are in per-service `.env` files (git-ignored).

---

## 🎓 Usage Examples

### Scenario 1 — Fresh server / mini-PC

```bash
# 1. Flash OS (Debian/Ubuntu Server) to SSD / disk
# 2. SSH in, set up SSH key
ssh-copy-id youruser@192.168.1.42

# 3. Edit inventory.yml
# 4. Run playbook
ansible-playbook site.yml

# 5. SSH back in and verify
ssh youruser@192.168.1.42
docker --version
kubectl version --client
k3s kubectl get nodes
```

### Scenario 2 — Disaster recovery (server died, reflashed)

```bash
# 1. Reflash server, SSH back in
# 2. Re-run playbook (uses the same inventory.yml you already have)
ansible-playbook site.yml

# 3. Restore data
#    - Docker: restore bind-mounted volumes from backup
#    - k3s: restore PVCs from backup, re-run sealed-secrets controller install

# 4. Deploy services
cd ~/Home-Server-Lab
# Docker:
cd docker/jellyfin && ./setup.sh
# k3s:
cd k3s && kubectl apply -f infra/ && kubectl apply -f apps/
```

### Scenario 3 — Multiple servers

```yaml
# inventory.yml
all:
  children:
    homelab_servers:
      hosts:
        homelab-01:
          ansible_host: 192.168.1.42
          ansible_user: user1
        homelab-02:
          ansible_host: 192.168.1.43
          ansible_user: ubuntu
```

```bash
# Provision both servers
ansible-playbook site.yml

# Provision only homelab-02
ansible-playbook site.yml --limit homelab-02
```

---

## 🛠️ Advanced

### Custom k3s install flags

The k3s role uses the official k3s install script. To pass additional flags (e.g., disable Traefik, use a different data dir), override in `group_vars/all.yml` or create a custom role task.

Example (disable built-in Traefik):

```yaml
# In group_vars/all.yml
k3s_install_flags: "--disable traefik"
```

Then modify `roles/k3s/tasks/main.yml`:

```yaml
- name: Download and install k3s
  shell: |
    curl -sfL {{ k3s_install_script_url }} | \
    INSTALL_K3S_VERSION="{{ k3s_version }}" \
    INSTALL_K3S_EXEC="{{ k3s_install_flags | default('') }}" \
    sh -
```

### External storage (SSD / NFS)

To move Docker and k3s data to an external SSD mounted at `/mnt/ssd`:

```yaml
# group_vars/all.yml
docker_data_root: "/mnt/ssd/docker"
k3s_data_dir: "/mnt/ssd/k3s"
```

The playbook will create the directories and configure `docker daemon.json` accordingly. Make sure the SSD is mounted before running the playbook.

---

## 🔍 Troubleshooting

| Issue | Solution |
|-------|----------|
| **SSH connection refused** | Check `ansible_host` in `inventory.yml`, verify SSH is running on target |
| **Permission denied (publickey)** | Run `ssh-copy-id <user>@<host>` to copy your SSH key |
| **Docker install fails** | Check internet connection on target server; the official script downloads from `get.docker.com` |
| **k3s times out during install** | Increase `retries` in `roles/k3s/tasks/main.yml` → `Wait for k3s to be ready` task |
| **kubectl: command not found (on target)** | kubectl is in `/usr/local/bin` — make sure that's in your `$PATH`, or use absolute path |
| **Firewall blocks service ports** | Add the port to `firewall_allowed_ports` in `group_vars/all.yml` and re-run the `base` role |

### Debugging a failed role

```bash
# Run with verbose output
ansible-playbook site.yml -vvv

# Run only the failing role
ansible-playbook site.yml --tags docker -vvv

# Check mode (dry run)
ansible-playbook site.yml --check
```

---

## 🔗 References

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy (community roles)](https://galaxy.ansible.com/)
- [Docker installation script](https://get.docker.com/)
- [k3s installation docs](https://docs.k3s.io/installation)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Helm docs](https://helm.sh/docs/)

---

<div align="center">

**[⬅️ Back to main README](../README.md)** ⋅ **[🐳 Docker stack →](../docker/README.md)** ⋅ **[☸️ k3s stack →](../k3s/README.md)**

</div>
# Ansible Playbooks

Ansible roles for provisioning any Linux homelab server from scratch after a reflash or fresh install.

## Structure

```
ansible/
├── inventory/      # Host definitions
├── group_vars/     # Shared variables
└── roles/          # Playbook roles
    ├── base/           # Packages, locale, timezone, SSH hardening
    ├── docker/         # Docker CE install + compose plugin
    ├── k3s/            # k3s install with custom config
    ├── ufw/            # Firewall rules
    └── storage/        # Mount points, Longhorn prereqs
```
