---
name: "Vaultwarden"
category: "🔐 Security & Secrets"
purpose: "Self-Hosted Password Manager"
description: "Bitwarden-compatible vault server in Rust, backing the official Bitwarden browser extensions and mobile apps. Vault contents are end-to-end encrypted client-side, so the Pi only ever stores ciphertext. SQLite on its own PVC rather than the shared Postgres, so the entire vault restores as a single directory."
icon: "🔐"
namespace: "security"
external_port: "9200"
domain: "vault.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - pvc
  - sealedsecret
features:
  - "Works with official Bitwarden extensions, mobile and desktop apps"
  - "Zero-knowledge: items encrypted client-side, server sees only ciphertext"
  - "SQLite vault on a Retain PVC — one directory to back up and restore"
  - "Consistent hot snapshots via built-in VACUUM INTO backup"
  - "TOTP and WebAuthn two-factor, Argon2id key derivation"
  - "Signups closed after enrollment; login rate limiting on by default"
  - "Mobile push for sync and log-in-with-device approvals"
resource_usage: "~80MB RAM"
---

# Vaultwarden — Self-Hosted Password Manager

An unofficial, lightweight Bitwarden server written in Rust. The official
Bitwarden clients — browser extension, iOS, Android, desktop, CLI — point at it
instead of Bitwarden's cloud, so credentials live on the Pi.

Vault items are encrypted **on the client** with a key derived from the master
password. The server stores ciphertext and never sees the master password, so a
stolen database is not a stolen vault.

## Features

- Drop-in backend for every official Bitwarden client
- End-to-end encrypted vault; Argon2id key derivation
- TOTP and WebAuthn/passkey two-factor authentication
- Attachments, Sends, folders and organisations
- Built-in `VACUUM INTO` backup for consistent hot snapshots
- Login rate limiting and closed registration

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `vaultwarden` | Deployment | Single replica, `Recreate` (single-writer SQLite) |
| `vaultwarden` | Service | LoadBalancer `9200` → container `8080` |
| `vaultwarden` | IngressRoute | Hosts `vault.home.ijlalahmad.dev` on `websecure` |
| `vaultwarden-data` | PV + PVC | 2Gi, `Retain`, the entire vault |
| `fix-perms` | initContainer | Chowns `/data` to 1000:1000, `chmod 700` |

Runs as uid/gid 1000 on port 8080 rather than the image's root-on-80 default.

The initContainer is not optional. Kubelet applies `fsGroup` ownership management
to most volume types but **not** to `hostPath`, so a fresh `DirectoryOrCreate`
volume arrives as `root:root 0755` and the non-root container exits immediately
with `PermissionDenied`. The other apps on this node were fixed by chowning on
the host — invisible to git, and not replayed by `cluster-restore.sh`. Doing it
in an initContainer means a cluster rebuild reproduces it, and lets the vault sit
at `0700` rather than the `0777` the older app volumes ended up with.

## Manifests

| File | What's inside |
|------|---------------|
| `deployment.yaml` | Container, full env configuration, probes, resources |
| `service.yaml` | LoadBalancer on port 9200 |
| `ingress.yaml` | Traefik IngressRoute + wildcard TLS |
| `pvc.yaml` | PV + PVC for `/data` |
| `sealedsecret.yaml` | Push installation ID + key (safe to commit) |
| `secret.yaml` | Plaintext source for the above — **gitignored** |
| `setup.sh` | Control script + first-time setup notes |

The only secrets here are the Bitwarden push credentials. SQLite needs none and
the admin panel is disabled, so nothing else is sealed — everything that
actually matters lives inside the encrypted vault itself.

## Why SQLite, not the shared Postgres

Upstream recommends SQLite for single-user instances, but the deciding factors
here are specific to this cluster:

- **Restore is one directory.** `db.sqlite3`, `attachments/`, `sends/` and
  `rsa_key.pem` all sit under `/k3s-volumes/apps/vaultwarden/data`, which
  Backrest's existing plan path already covers. On Postgres the vault would be
  split across a `pg_dumpall` and a PVC captured at two different points in
  time — Backrest deliberately excludes the live Postgres data dir.
- **No sqlite3 binary needed.** `/vaultwarden backup` does `VACUUM INTO`,
  folding in pending WAL.
- **Gentler on the SD card.** Postgres checkpoints, autovacuums and writes WAL
  continuously even at idle. Vaultwarden writes only when the vault changes.

It also keeps the vault independent of a Postgres instance that gets re-imaged
for unrelated apps, and off its tuned `max_connections = 50`.

## Quick Start

```bash
cd k3s/apps/vaultwarden
./setup.sh deploy         # or just push — ArgoCD reconciles it
./setup.sh status
```

Then:

1. Open `https://vault.home.ijlalahmad.dev` and **create your account**. In
   Settings → Security → Keys, switch the KDF to **Argon2id**.
2. **Flip `SIGNUPS_ALLOWED` to `"false"`** in `deployment.yaml`, commit, push.
   This is required, not optional — until then anyone on the LAN can register.
3. Turn on TOTP two-factor in account settings.
4. Store the master password somewhere physical. Nobody can reset it for you.

## Client setup

The server URL must be set **before** logging in — it can't be changed on an
already-signed-in client.

| Client | Steps |
|--------|-------|
| Browser extension | Login screen → "Logging in on" dropdown → *Self-hosted* → `https://vault.home.ijlalahmad.dev` |
| iOS / Android | Same dropdown on the app login screen, then enable biometric unlock and register Bitwarden as the system autofill provider |
| Desktop | Login screen → "Accessing" dropdown → *Self-hosted* |
| CLI | `bw logout && bw config server https://vault.home.ijlalahmad.dev` |

No certificate needs installing on any device — the Let's Encrypt wildcard for
`*.home.ijlalahmad.dev` is publicly trusted.

### Push notifications

Push wakes mobile clients for vault sync and for approving **log in with
device**. Without it the server still creates the login request — you just have
to find it manually under *Settings → Account security → Pending login requests*.

Setup:

1. Get `PUSH_INSTALLATION_ID` and `PUSH_INSTALLATION_KEY` from
   [bitwarden.com/host](https://bitwarden.com/host) (free).
2. Put both in `secret.yaml`, then `./setup.sh seal`.
3. Deploy, then **log out and back in on every client** — that is the only way
   push tokens get registered. Pre-existing sessions never receive push.

> Seal **before** deploying or pushing. `deployment.yaml` ships with
> `PUSH_ENABLED=true` and a `secretKeyRef`, so the pod stays in
> `CreateContainerConfigError` until the SealedSecret exists.

Requires an app-store build of the Bitwarden app — F-Droid and other alternative
stores ship without Firebase Messaging and cannot receive push at all.

Delivery routes **Pi → Bitwarden relay → APNs/Firebase → phone**, entirely
outbound, so push needs no inbound exposure and works fine on a LAN-only server.
The relay carries sync signals and device identifiers, never vault contents.

### Off the home network

The hostname resolves publicly to the Pi's **private** address, which is
unroutable from outside — so away from home, clients simply can't connect.
Bitwarden caches the vault locally, so you can still *read* passwords; you just
won't sync, and can't sign in on a new device.

**Twingate lifts this**, and the setup here is unusually clean for it:

- Define `vault.home.ijlalahmad.dev` as a Twingate Resource (or rely on an
  existing one covering the Pi's address — public DNS already hands clients
  `192.168.0.108`, so an address-based Resource catches it too).
- **Nothing about this app changes.** Same hostname, so `DOMAIN` stays correct,
  the wildcard certificate still validates, and no client needs reconfiguring —
  WebAuthn registrations and push tokens are bound to `DOMAIN` and survive.
- The Twingate client must be **connected at the moment you sync or approve a
  login**. Push itself still arrives over normal internet, so the notification
  lands either way — tapping it just fails if the tunnel is down. Enable
  always-on VPN on the phone if that gets annoying.
- Only one VPN profile runs at a time on iOS, so Twingate will conflict with
  another active VPN.

Worth scoping the Resource narrowly — a policy requiring MFA on the vault
specifically, rather than folding it into a broad `192.168.0.0/24` Resource that
grants the whole LAN. It's the one service where that distinction is worth the
extra minute.

## Backups

The nightly Backrest run covers `/k3s-volumes`, which includes this PVC. Its
pre-backup hook additionally runs Vaultwarden's own backup so restic never
copies a SQLite file mid-write.

Manually:

```bash
./setup.sh shell
/vaultwarden backup        # → /data/db_YYYYMMDD_HHMMSS.sqlite3
```

To restore:

```bash
./setup.sh disable                    # stop the writer first
# restore the data dir from restic, then inside it:
#   mv db_YYYYMMDD_HHMMSS.sqlite3 db.sqlite3
#   rm -f db.sqlite3-wal              # MUST be removed or the db tears
./setup.sh enable
```

Deleting `rsa_key.pem` is survivable — it only signs session tokens, so every
client is logged out and signs back in. Losing `db.sqlite3` is not.

Keep an offline encrypted export as well. For a password manager the realistic
failure is **loss**, not theft.

## Security notes

- **The web vault is the sharp edge.** The server ships the JavaScript that
  handles your master password, so a compromised server could serve malicious
  JS and capture it. Extensions and mobile apps install from app stores and
  never fetch code from here, so they aren't exposed to that. Setting
  `WEB_VAULT_ENABLED=false` leaves every app fully working — worth doing if
  this is ever reachable from the internet.
- **The admin panel is disabled** (no `ADMIN_TOKEN`). Beyond attack surface,
  `/admin` writes `config.json` whose values *override* the env vars in
  `deployment.yaml`, which would silently decouple the cluster from git. See
  `setup.sh` for how to enable it temporarily.
- **`ICON_SERVICE` stays `internal`.** Pointing it at bitwarden/google/
  duckduckgo would disclose every domain in your vault to that third party.
- **Vaultwarden is not Bitwarden.** It's an unofficial reimplementation with no
  professional audit or bug bounty, and a real CVE history — 1.37.0 alone fixed
  SSRF, cross-organisation cipher access, policy bypass and websocket flooding.
  Keep it pinned, keep Renovate watching it, and read release notes on bumps.

## Troubleshooting

**Pod exits with `PermissionDenied` on `/data`** — the `fix-perms`
initContainer didn't run or didn't take. Check it:

```bash
kubectl -n security logs -l app=vaultwarden -c fix-perms
kubectl -n security exec deploy/vaultwarden -- ls -land /data   # want 1000:1000, drwx------
```

**Pod exits with a `DATABASE_URL` scheme error** — the `sqlite://` scheme is
required to *create* a database. A bare path only works when the file already
exists, so it fails on a fresh PVC but looks fine on an existing one.

**Clients can't reach the server** — confirm DNS resolves and TLS is valid:

```bash
curl -sS https://vault.home.ijlalahmad.dev/alive     # expect a timestamp
```

**Changes don't stick** — ArgoCD runs `selfHeal: true`, so live edits get
reverted. Use `./setup.sh disable` (writes `replicas: 0` to git), never
`kubectl scale` or `./setup.sh scale`.
