# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A dual-stack homelab: **the same services modelled twice**, once for prototyping and once for production, both targeting a single ARM64 Linux box (reference hardware: Raspberry Pi 5, 8 GB).

- `docker/` — 28 self-contained Compose services. Each directory is standalone: `docker-compose.yml`, `.env.example`, its own ~200-line `setup.sh`, `README.md`. There is **no shared library** between Docker services.
- `k3s/` — 16 apps + 4 databases + bootstrap infra, reconciled by ArgoCD. Flat manifests per directory, plus a thin `setup.sh` that sources a shared control library.
- `ansible/` — builds the host itself (base packages, docker, k3s, kubectl, helm, kubeseal). Single host `homelab-pi`.

The intended workflow is to prototype a service in `docker/`, then promote the working configuration to `k3s/`.

## Commands

Python tooling needs `pyyaml`, which is **not** installed system-wide. Use a venv:

```bash
python3 -m venv .venv && .venv/bin/pip install pyyaml
```

### Docs automation (see "Docs are generated" below)

```bash
# Validate one service's README frontmatter (schema depends on path)
python3 .github/scripts/validate-service.py k3s/apps/<svc>
python3 .github/scripts/validate-service.py k3s/databases/<db>
python3 .github/scripts/validate-service.py docker/<svc>

# Regenerate the three aggregate READMEs (run all three; global reads both stacks)
python3 .github/scripts/update-docker-readme.py    # -> docker/README.md
python3 .github/scripts/update-k3s-readme.py       # -> k3s/README.md
python3 .github/scripts/update-global-readme.py    # -> README.md
```

All three are idempotent — a second run must produce no diff. If it does, that's a bug in the generator, not expected churn.

### Lint / validate

```bash
pip install pre-commit && pre-commit install
pre-commit run --all-files

# Renovate config (catches disallowed fields, bad manager schemas)
npx --yes --package renovate renovate-config-validator    # run from repo root, no args
```

`pre-commit` runs gitleaks, yamllint, shellcheck, and `check-yaml`. Note the deliberate exclusions in `.pre-commit-config.yaml`: `check-yaml` and `yamllint` skip `k3s/**` (custom CRD tags), and shellcheck disables a documented list of codes — each has a comment explaining why. Don't "fix" a service `setup.sh` to satisfy a disabled code.

### k3s — per-service control

Every `k3s/**/setup.sh` declares variables then sources a shared library, so they all share one command surface:

```bash
cd k3s/apps/<svc>          # or k3s/databases/<db>
./setup.sh help            # authoritative list — read this, don't guess
./setup.sh deploy | status | logs | shell | restart | events | resources | describe
./setup.sh disable | enable      # replicas 0/1 IN GIT — ArgoCD-safe pause
./setup.sh scale <n>             # cluster-only; ArgoCD WILL revert this
./setup.sh pvc | seal
./setup.sh argocd-status | sync | diff
./setup.sh teardown              # PVCs kept
./setup.sh teardown --purge      # deletes PVCs/PVs — destroys data
```

Databases additionally get (from `_db-ctl.sh`): `connection-string [external|internal]`, `print-ca`, `detach-storage`, `attach-storage [n]`, `dump [file]`, `restore <file>`.

The commands are `shell` and `teardown` — **not** `exec` or `undeploy`. Some older per-service READMEs document the wrong names.

### k3s — repo-wide scripts

```bash
k3s/scripts/new-service.sh              # scaffold a new app (interactive)
k3s/scripts/seal.sh <path/secret.yaml>  # seal one
k3s/scripts/seal.sh --all               # NOTE: only walks k3s/apps/, not databases/ or infra/
k3s/scripts/db-user.sh <postgres|mongodb|mysql|redis> create <user> <pass> [db1,db2]
k3s/scripts/db-user.sh <engine> list | delete <user>
k3s/scripts/cluster-restore.sh          # rebuild after a wipe
k3s/scripts/pi-observe.sh --mode full   # host + k8s observability
```

### Docker stack

```bash
cd docker/<svc>
cp .env.example .env      # then edit
./setup.sh                # defaults to `setup`
./setup.sh start | stop | restart | logs | shell | status | update
```

### Ansible

```bash
cd ansible
ansible-playbook site.yml
ansible-playbook site.yml --check --diff              # dry run
ansible-playbook site.yml --tags docker
ansible-playbook site.yml --skip-tags k3s,kubectl,kubeseal,helm
ansible-vault edit group_vars/vault.yml               # re-encrypts on save
```

## Docs are generated — frontmatter is the source of truth

This is the single most important convention in the repo. `README.md`, `docker/README.md` and `k3s/README.md` are **built from YAML frontmatter** in each per-service README by the `.github/scripts/*.py` generators, and rewritten by CI on push to `main`.

- **Never hand-edit** content between `<!-- AUTOGEN:* -->` markers, the service tables, the category tables, or the mermaid diagrams in those three files. Edit the per-service `README.md` frontmatter instead, then run the generators.
- A service directory **with no `README.md` is invisible** to the generators — it silently drops out of counts, tables and diagrams even if it's deployed and in the ApplicationSet.
- Required frontmatter keys differ by path. `k3s/apps/*` and `k3s/databases/*` use the k3s schema (`name`, `category`, `purpose`, `description`, `icon`, `namespace`, `components`, `features`, `resource_usage`); `docker/*` uses the docker schema (no `namespace`/`components`). `category` must come from the hardcoded list in `.github/scripts/validate-service.py`, and `components` from the existing vocabulary (`deployment`, `statefulset`, `service`, `ingress`, `pvc`, `configmap`, `sealedsecret`, `rbac`).
- `category` also drives diagram placement via keyword matching in `update-global-readme.py` (`TOPICS`) — picking an off-list category silently drops the service from the architecture diagram.
- The generators only scan `docker/*` and `k3s/apps/*`. `k3s/databases/*` READMEs are validated by CI but do **not** feed the aggregate READMEs.

CI: `validate-metadata.yml` validates changed service READMEs on PRs; `update-readme.yml` regenerates and auto-commits on push to `main`; `security-scan.yml` runs gitleaks/trufflehog.

## GitOps: the ApplicationSet is a manual list

`k3s/infra/argocd/applicationset.yaml` uses a **hardcoded list generator**. Adding a directory under `k3s/apps/` or `k3s/databases/` does *not* put it under ArgoCD — you must add an entry (`name`, `namespace`, `category`, `path`). Conversely, a directory absent from that list is deliberately unmanaged.

Sync policy is `automated` with `prune: true` and `selfHeal: true`. Consequences:

- Live cluster edits get reverted. To pause a workload, use `./setup.sh disable` (writes `replicas: 0` to git), not `kubectl scale` / `./setup.sh scale`.
- Bootstrap infra (`traefik`, `cert-manager`, `sealed-secrets`, ArgoCD itself) is installed by Helm/Ansible and is intentionally **not** in the ApplicationSet. `k3s/infra/argocd/values.yaml` changes require a `helm upgrade`, not a git push.
- `mysql` is intentionally parked: `paused: true`, no PVC, and a commented-out ApplicationSet entry. Leave it that way unless asked.

## Secrets

Three mechanisms, do not mix them up:

| Stack | Plaintext (gitignored) | Committed |
|---|---|---|
| Docker | `docker/*/.env` | `.env.example` |
| k3s | `k3s/**/secret.yaml` | `k3s/**/sealedsecret.yaml` |
| Ansible | `group_vars/vault.yml.plaintext` | `group_vars/vault.yml` (vault-encrypted) |

Keep `secret.yaml` locally for re-sealing; seal with `./setup.sh seal` or `k3s/scripts/seal.sh`. The only committed `.pem` is the sealed-secrets **public** cert, whitelisted by a `!` rule in `.gitignore`.

## Conventions worth knowing before editing manifests

- **Domains**: every externally-reachable service is `<name>.home.ijlalahmad.dev`, routed by a Traefik `IngressRoute` on the `websecure` entrypoint with the shared `wildcard-home-ijlalahmad-dev-tls` secret. `ingress.yaml` is the source of truth; the `DOMAIN` variable in `setup.sh` is **display-only** (used in terminal output), as is `EXTERNAL_PORT`. Keep them in sync with the manifest anyway — drift here is what stale `.lan` values were.
- **Non-HTTP services** (MongoDB, Redis) use `IngressRouteTCP` in the `traefik` namespace with dedicated entrypoints declared in `k3s/infra/traefik/values.yaml`. Cross-namespace refs work because Traefik runs with `allowCrossNamespace: true`.
- **Storage**: hostPath PVs under `/home/pi/k3s-volumes/{apps,databases}/<name>`, `persistentVolumeReclaimPolicy: Retain`, `storageClassName: ""`, usually pre-bound with an explicit `claimRef`. Not dynamic provisioning.
- **Namespaces** are pre-created in `k3s/base/namespaces`: `automation`, `dashboard-network`, `databases`, `downloads`, `file-management`, `git`, `media`, `monitoring`.
- **Pi budget**: 8 GB total. Every container should carry `resources.requests`/`limits`, and database configs are hand-tuned for the box (Postgres `shared_buffers 64MB`, MySQL `innodb_buffer_pool_size 128M`, Redis `maxmemory 256mb`, Mongo WiredTiger cache `0.25GB`, all `max_connections 50`). Infra workloads use `priorityClassName: homelab-infra`. Don't raise a limit without accounting for what it displaces.
- **ARM64 only.** Any new image must have a native arm64 tag — QEMU emulation is not acceptable here.
- Most workloads use `strategy: Recreate` deliberately: single-writer hostPath volumes can't support a rolling update.

## Renovate

`renovate.json` drives image/chart/tool updates. `customManagers` (regex) pick tool versions out of Ansible files — note `k3s_version` lives in `ansible/inventory.yml`, while `kubeseal_version` and `helm_version` live in `ansible/group_vars/all.yml`. Each custom manager needs its own correct `depNameTemplate`; one manager cannot cover several tools. Use `managerFilePatterns` (regexes wrapped in `/.../`), not the removed `fileMatch`.
