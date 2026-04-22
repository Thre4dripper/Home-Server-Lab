# 🔐 Security Policy

> **TL;DR** — Don't commit `.env`, `*.key`, `*.pem`, or kubeconfig. If you do, **rotate first, rewrite history second**. Automated scanners (gitleaks + trufflehog + Trivy) run on every push.

---

## Reporting a Vulnerability

If you discover a security issue, **please do not open a public GitHub issue**. Instead:

- Open a [private security advisory](https://github.com/Thre4dripper/Home-Server-Lab/security/advisories/new), **or**
- Email the maintainer (see GitHub profile)

Expect an acknowledgement within 7 days.

---

## 🤖 Automated Defenses

This repo runs **three layers** of automated scanning:

| Layer | Tool | When | What it catches |
|-------|------|------|-----------------|
| **1. Local (pre-commit)** | [`gitleaks`](https://github.com/gitleaks/gitleaks) | Before every commit on your machine | API keys, tokens, private keys *before* they hit git |
| **2. CI (every push/PR)** | [`gitleaks-action`](https://github.com/gitleaks/gitleaks-action) + [Trivy](https://github.com/aquasecurity/trivy) | GitHub Actions on push + PR | Secrets that slipped past pre-commit + IaC misconfigurations + CVEs |
| **3. Deep (weekly)** | [`trufflehog`](https://github.com/trufflesecurity/trufflehog) `--only-verified` | Sundays 03:00 UTC + manual | **Live, working** credentials anywhere in git history |

Plus dependency hygiene:

| Tool | What it updates | Auto-merge? |
|------|-----------------|-------------|
| **Dependabot** | GitHub Actions, pip packages, n8n Dockerfile | Patch only |
| **Renovate** | Docker image tags, Helm charts, k8s manifests, Ansible tool versions | Minor + patch (after CI passes) |

---

## 🛠️ Setting Up Local Pre-Commit Hooks

**One-time setup** (do this after cloning the repo):

```bash
# 1. Install pre-commit
pip install pre-commit
# or: brew install pre-commit
# or: sudo apt install pre-commit

# 2. Install the git hooks defined in .pre-commit-config.yaml
cd Home-Server-Lab
pre-commit install

# 3. (Optional) Run against the entire repo to baseline
pre-commit run --all-files
```

Now every `git commit` will run gitleaks + yamllint + shellcheck + hadolint locally. If a secret is detected, **the commit is blocked** before it ever reaches your branch.

To bypass in an emergency (you should almost never need this):

```bash
git commit --no-verify
```

---

## 🚨 "I just committed a secret" — Incident Response

**Order matters. Read all of this before acting.**

### Step 1 — Rotate the secret IMMEDIATELY

Even if the commit is only on your local branch, **assume it is compromised** the moment it touches `git push`. Rewriting history doesn't help if the secret was already scraped.

| Secret type | How to rotate |
|-------------|---------------|
| Cloudflare API token | Cloudflare dashboard → My Profile → API Tokens → revoke + recreate |
| GitHub PAT | github.com/settings/tokens → revoke + create new |
| AWS access key | IAM console → users → security credentials → deactivate + create new |
| Twingate / Tailscale auth key | Their admin console → revoke key |
| Database password | Connect, `ALTER USER`, restart dependent services |
| TLS private key | Re-issue cert (Let's Encrypt: `cert-manager` will rotate automatically) |
| SSH key | `ssh-keygen` new key, update `~/.ssh/authorized_keys` everywhere, remove old |
| k3s kubeconfig | `sudo cat /var/lib/rancher/k3s/server/node-token` is the cluster join token — rotating means reinstalling k3s |

### Step 2 — Remove the file from the working tree

```bash
git rm --cached path/to/leaked-file
echo "path/to/leaked-file" >> .gitignore
git add .gitignore
git commit -m "security: remove leaked file, rotate credentials"
```

### Step 3 — Purge from history

For a single file, use [`git-filter-repo`](https://github.com/newren/git-filter-repo) (the modern replacement for `git-filter-branch` and BFG):

```bash
# Install (one-time)
pip install git-filter-repo

# Make a fresh clone (filter-repo refuses to touch a non-fresh clone)
cd /tmp
git clone --mirror git@github.com:Thre4dripper/Home-Server-Lab.git
cd Home-Server-Lab.git

# Purge the file from ALL history
git filter-repo --path path/to/leaked-file --invert-paths

# Or purge a specific string (e.g. an API key) from ALL files in ALL commits
git filter-repo --replace-text <(echo 'glpat-xxxxxxxxxxxxxxxxxxxx==>***REMOVED***')

# Force-push the rewritten history
git push --force --all
git push --force --tags
```

### Step 4 — Tell collaborators to re-clone

Force-pushing rewrites SHAs. Anyone with an existing clone needs to:

```bash
cd Home-Server-Lab
cd ..
rm -rf Home-Server-Lab
git clone git@github.com:Thre4dripper/Home-Server-Lab.git
```

(You can also do `git fetch && git reset --hard origin/main`, but a fresh clone is foolproof.)

### Step 5 — Confirm the secret is gone

```bash
# Re-run trufflehog against the full history
docker run --rm -v "$(pwd):/repo" trufflesecurity/trufflehog:latest \
    git file:///repo --only-verified

# Or trigger the weekly workflow on demand
gh workflow run security-scan.yml
```

### Step 6 — Open a GitHub Support request (optional but recommended)

GitHub caches old commits for ~90 days even after force-push. To purge them faster, file a support ticket: <https://support.github.com/contact>.

---

## 🎯 Secret Storage — Do This Instead

| Stack | Where secrets go | Tool |
|-------|------------------|------|
| **Docker** | `.env` files (git-ignored) | `setup.sh` generates them per service |
| **k3s** | [`SealedSecret`](k3s/scripts/seal.sh) CRDs (encrypted, safe to commit) | [`kubeseal`](https://github.com/bitnami-labs/sealed-secrets) |
| **Ansible** | [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) (encrypted YAML) | `ansible-vault encrypt_string` |
| **Local dev** | Password manager (1Password, Bitwarden, etc.) | Personal preference |

**Never commit:**
- `.env` (any service)
- `kubeconfig`, `~/.kube/config`
- `*.key`, `*.pem`, `id_rsa`, `id_ed25519`
- Service account JSON keys
- Any file containing `BEGIN PRIVATE KEY`

The repo's [`.gitignore`](./.gitignore) already covers these patterns. Pre-commit + CI scans are belt-and-suspenders.

---

## 🔗 References

- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub: removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [git-filter-repo manual](https://htmlpreview.github.io/?https://github.com/newren/git-filter-repo/blob/docs/html/git-filter-repo.html)
- [Sealed Secrets — how it works](https://github.com/bitnami-labs/sealed-secrets#overview)
