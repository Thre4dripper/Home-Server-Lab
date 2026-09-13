---
name: "FileBrowser Quantum"
category: "📁 Files & Storage"
purpose: "Indexed File Manager"
description: "Rewrite of FileBrowser with a real search index, multi-source mounts and media previews. Read-write access to the Pi home directory and the external USB drive as two independently scoped sources, each with its own permissions and disk usage readout. SQLite index, WebDAV, and optional OnlyOffice document editing."
icon: "🗂️"
namespace: "file-management"
external_port: "8310"
domain: "explorer.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - pvc
  - configmap
  - sealedsecret
features:
  - "Home directory and USB storage as separate read-write sources"
  - "Indexed search across every mounted source"
  - "Video, image, audio and 3D model thumbnails via bundled ffmpeg"
  - "WebDAV at /dav — mountable in Finder, rclone or davfs2"
  - "TOTP and passkey (WebAuthn) two-factor authentication"
  - "Per-source read-only, privacy and permission rules"
  - "Optional OnlyOffice integration for in-browser document editing"
resource_usage: "~210MB RAM (1GB limit during initial index)"
---

# FileBrowser Quantum — Indexed File Manager

A ground-up rewrite of FileBrowser by a different author, sharing the name but
almost none of the code. The features that matter here are **multiple mounted
sources** with independent permissions, and a **real search index** rather than
a filesystem walk on every query.

Deployed as the successor to [`filebrowser`](../filebrowser/), which is now
decommissioned — its ApplicationSet entry is commented out and its Deployment
pinned to `replicas: 0`. See [Decommissioning the old
FileBrowser](#decommissioning-the-old-filebrowser).

## What is mounted

| Source | Container path | Host path | Mode |
|---|---|---|---|
| **Home** | `/mnt/pi/home` | `/home/pi` | read-write |
| **Storage** | `/mnt/pi/storage` | `/home/pi/pendrive` | read-write |

There is deliberately **no source for the host root**. An earlier revision
mounted `/` read-only as a "System" source; it was dropped. Upstream advises
against rooting a source at `/` or at anything containing `/var`, and the
exclusion list needed to make it survivable — `proc`, `sys`, `dev`, `run`,
`var/lib/{docker,containerd,rancher,kubelet}`, `tmp`, `cache`, `spool` — was
most of the config file. Reading `/etc` or `/var/log` from a browser is not
worth an index that large or a pod that can see every secret on the box; use
`kubectl` or ssh for that.

### Why Storage is a separate source

It is a subtree of Home on disk, so this looks redundant — `/mnt/pi/home` alone
would already reach the pendrive. It is kept separate because a source, not a
folder, is Quantum's unit of everything that matters:

- **Its own used-percentage readout.** One source spanning both disks would
  report the SD card's free space for pendrive files.
- **Its own search scope**, so "search Storage" doesn't walk `~/.cache`.
- **Its own permission surface** (`defaultPermissions`, `readOnly`, `private`),
  which is what makes a future family user scoped to the drive and nothing else
  a config change rather than a redesign.
- **Its own index**, so unplugging the drive doesn't invalidate the home index.

Sources can only be declared in `config.yaml` — there is no way to add one from
the UI. What the UI *does* offer is **pinned items**: any folder inside a source
can be pinned to the sidebar per user (Settings → the pin action on a folder),
which is the right tool for shortcuts to `~/k3s-volumes` or a downloads folder.

### Why the pendrive looked missing from Home

Because `config.yaml` excluded it. The Home source carries a
`folderPath: "/pendrive"` rule to stop the drive being indexed twice, and an
exclusion rule in Quantum hides the folder from listings as well as from the
index — so `~/pendrive` was present on disk, mounted, and readable by the pod,
yet absent from the Home view.

The fix is `viewable: true` on that rule: browsable, still not indexed. Same
treatment as `~/k3s-volumes` and `/var/log`.

### Mount propagation

Both hostPath mounts use `mountPropagation: HostToContainer`. The pendrive is a
separate filesystem the host mounts at `/home/pi/pendrive`; without propagation
a pod that outlives an unplug/replug keeps reading the empty directory
*underneath* the mountpoint rather than the drive. This was previously set only
on the root mount, which is the mount that got removed.

`host-storage` stays `type: DirectoryOrCreate` rather than Immich's fail-closed
`Directory`: if the drive is unplugged the file manager should still start so
Home is reachable. The trade-off is that writes to Storage while the drive is
absent land on the SD card.

## Kubernetes Architecture

| Resource | Type | Purpose |
|---|---|---|
| `filebrowser-quantum` | Deployment | Single replica, runs as root to read host files |
| `filebrowser-quantum-onlyoffice` | Deployment | Document server, **parked at `replicas: 0`** |
| `filebrowser-quantum` | Service | LoadBalancer on `8310` → container `80` |
| `filebrowser-quantum-onlyoffice` | Service | ClusterIP on `80` |
| `filebrowser-quantum` | IngressRoute | `explorer.home.ijlalahmad.dev` |
| `filebrowser-quantum-onlyoffice` | IngressRoute | `office.home.ijlalahmad.dev` |
| `filebrowser-quantum-data` | PV + PVC | 5Gi, `Retain` — index, activity log, thumbnails |
| `filebrowser-quantum-config` | ConfigMap | Generated from `config/config.yaml` by kustomize |
| `filebrowser-quantum-secret` | SealedSecret | Admin password, JWT, TOTP and OnlyOffice keys |

Note the Service port is **8310**, not 8300 — 8300 belonged to the old
`filebrowser`, and is free again now that it is decommissioned.

### Why this app has a `kustomization.yaml`

`config/config.yaml` is 380 lines. Inlining it into a `configmap.yaml` as a
YAML string would make it unreadable and unlintable, so it is rendered by a
`configMapGenerator` instead — the same approach as
[`homepage`](../homepage/).

Unlike homepage, the **name suffix hash is left enabled**. Quantum parses its
config exactly once at startup and has no hot reload, so without the hash a
pushed config change would sit in the cluster doing nothing until something
else happened to restart the pod. With it, editing the config changes the
ConfigMap name, which changes the pod template, which makes ArgoCD roll the pod
by itself. Stale ConfigMaps are cleaned up by the ApplicationSet's `prune`.

Preview what will be applied:

```bash
kubectl kustomize .
```

## Setup

The pod will not start until the SealedSecret exists — every `FILEBROWSER_*`
variable is a required `secretKeyRef`, so a missing secret means
`CreateContainerConfigError`.

```bash
cp secret.yaml.example secret.yaml
# fill in real values; openssl rand -base64 32 for the three random ones
./setup.sh seal          # -> sealedsecret.yaml (safe to commit)
./setup.sh deploy
```

Then log in at `https://explorer.home.ijlalahmad.dev` as `admin` with
`FILEBROWSER_ADMIN_PASSWORD`.

**Do not change the admin password in the UI** — it will not stick. While
`auth.adminPassword` is non-empty the backend resets the admin account's
password *and* permissions to that value on **every start**
(`Resetting admin user to default username and password.` in the log). The
SealedSecret is the source of truth: rotate the password by resealing it, or
clear `FILEBROWSER_ADMIN_PASSWORD` from the secret once the account exists if
you would rather manage it in the UI. Other users are unaffected.

### The first start is slow

The initial index walks `/home/pi` and the pendrive. A few minutes is normal on
a Pi 5 — it was ten before the root filesystem source was dropped. The UI works
throughout, it is just missing search results for paths not yet reached. Watch
progress with `./setup.sh logs`.

Restarts after that reuse the on-disk index and come up in seconds.

## Secrets

| Key | Backs | Rotation impact |
|---|---|---|
| `FILEBROWSER_ADMIN_PASSWORD` | `auth.adminPassword` | Re-applied to the admin account on **every** pod start, not just the first |
| `FILEBROWSER_JWT_TOKEN_SECRET` | `auth.key` | Logs everyone out, invalidates API tokens |
| `FILEBROWSER_TOTP_SECRET` | `auth.totpSecret` | **Every enrolled authenticator breaks** — back this up |
| `FILEBROWSER_ONLYOFFICE_SECRET` | `integrations.office.secret` | Must match `JWT_SECRET` on the OnlyOffice pod |

Both pods read the OnlyOffice secret from the same SealedSecret key, so they
cannot drift out of sync. It is required even while OnlyOffice is scaled to
zero.

Every secret is blank in `config.yaml` on purpose. The backend's
`loadEnvConfig()` runs *after* the YAML is parsed, so the environment always
wins — which is what keeps the committed config file safe.

## WebDAV

Served on the same hostname at `/dav/<source>/<path>`:

```
https://explorer.home.ijlalahmad.dev/dav/Home/
```

Basic auth, but **the password is an API token, not your login password**.
Generate one under Settings → Profile → API tokens. Disable the whole endpoint
with `http.disableWebDAV: true`.

## OnlyOffice

Ships complete but at `replicas: 0`. It wants ~2GB of RAM and 1–2 minutes to
become healthy, which is a lot to spend permanently on an 8GB box already
running immich, bitcomet, jellyfin and n8n. To enable:

1. `onlyoffice.yaml`: `replicas: 0` → `1`
2. `config/config.yaml`: `userDefaults.preview.office` → `true`
3. Commit and push, or `./setup.sh deploy`

Its storage is `emptyDir` rather than a PVC because everything it holds is a
regenerable cache — the authoritative documents live in the source volumes and
are re-fetched from FileBrowser over `http.internalUrl` on each open.

`./setup.sh disable` and `enable` only edit `deployment.yaml`, so they control
FileBrowser alone and leave OnlyOffice as it is.

## Indexing

Exclusion rules earn their keep in two ways, and the difference matters:

| Rule | Indexed | Listed in the UI |
|---|---|---|
| `- folderPath: "/x"` | no | **no** |
| `- folderPath: "/x"` + `viewable: true` | no | yes |

Everything kept out of the index but still browsable uses the second form:
`~/pendrive` (indexed by the Storage source instead), `~/k3s-volumes` (large,
constantly churning, and a search hit inside another app's PV is never what you
wanted), and `~/.ssh`, `~/.aws`, `~/.kube`, `~/.config/rclone` — reachable for
an admin who needs them, but never surfacing in an autocomplete or a shared
search result. `.Trash-1000`, `lost+found` and the restic repo under
`Storage/backups` (≈100k opaque content-addressed blobs) use the first form.

Each rule field takes a **single string**, so excluding five folders means five
separate list entries.

### Rebuilding the index

```bash
./setup.sh disable          # stop the writer, then commit + push
sudo rm -rf /home/pi/k3s-volumes/apps/filebrowser-quantum/data/cache/sql
./setup.sh enable
```

Leave `data/filebrowser.sqlite` alone — that holds users, shares and settings.
Only `cache/sql` is the regenerable search index.

### `cacheDirCleanup` must stay false

It reads like a housekeeping toggle. It is not: the backend calls
`ClearCacheDir()` on **both startup and shutdown**, and that is `os.RemoveAll`
over every entry in `cacheDir` — thumbnails, the HEIC cache, generated icons
and `sql/`, the search index itself.

It was `true` here, which meant every pod roll silently threw away the whole
cache and re-indexed from scratch, made `indexSqlConfig.disableReuse: false`
a no-op, and left the 5Gi PVC caching nothing across restarts. The visible
symptom is thumbnails disappearing after any restart. Upstream defaults it to
`false` and documents it for deployments with no persistent volume — the
opposite of this one.

### Thumbnails are cached per real path, not per file

The preview cache key is `md5(RealPath + size + modtime)`. `RealPath` is the
path *inside the container*, so the same pendrive file reached through the
Storage source (`/mnt/pi/storage/…`) and through `Home/pendrive/…`
(`/mnt/pi/home/pendrive/…`) hashes differently and is thumbnailed twice.

Nothing breaks, but browsing the drive through Home means regenerating every
thumbnail the Storage source already has. Use the Storage source — or a pinned
shortcut to it — as the entry point for the drive; `Home/pendrive` is there so
the directory isn't invisible, not as the fast path.

## State, backup and restore

Everything the app owns lives on one 5Gi PVC at
`/home/pi/k3s-volumes/apps/filebrowser-quantum/data`:

| Path | Size | What it is | Precious? |
|---|---|---|---|
| `filebrowser.sqlite` | ~190KB | Users, passkeys, TOTP enrolments, share links, per-user settings, activity log | **Yes — the only thing** |
| `cache/sql/` | ~100MB | The search index | No — rebuilt by rescanning |
| `cache/` (rest) | ~40MB | Thumbnails, previews, ffmpeg output | No — regenerated on demand |

Config is **not** in here. `config.yaml` is a ConfigMap built from git by
kustomize, so the repo is its backup.

### There is no Postgres option

Quantum is SQLite-only — `server.database` takes a file path and nothing else,
and `indexSqlConfig` is SQLite tuning (`walMode`, `cacheSizeMB`,
`startupIntegrityCheck`). There is no driver, DSN or connection-string field
anywhere in the schema, so the cluster's Postgres cannot be pointed at it. v2
replaced v1's BoltDB with SQLite; that migration is the only backend change
upstream has made.

That is also why the Deployment is `strategy: Recreate` and `replicas: 1` — a
single-writer database on a hostPath volume. A rolling update would put two
writers on the same WAL.

### Backing it up

The volume is already inside Backrest's read-only `/k3s-volumes` mount, so it
ships with every snapshot — but the naive version of that is wrong in both
directions, and `k3s/apps/backrest/setup.sh` carries the runbook for the fix:

- **Exclude `data/cache/`.** ~140MB rewritten constantly, regenerable in
  minutes. Left in, it adds a fresh pack of pure churn to every single snapshot
  for no restore value.
- **Snapshot the database rather than copying it.** The main DB opens with
  `_journal_mode=WAL`, so a live restic read of `filebrowser.sqlite` can miss
  commits still sitting in the `-wal` file, or catch a checkpoint mid-flight.
  The pre-backup hook runs `VACUUM INTO` against the live database — a read
  snapshot, no downtime — and writes the result into `/data/db-dumps`, which
  the plan already covers. This mirrors what the Vaultwarden stanza does with
  its `backup` subcommand.

Unlike Vaultwarden, Quantum has no `backup` CLI command (`filebrowser --help`
lists `version`, `setup`, `set rule`, `user set`, `user promote`) and neither
image ships `sqlite3`. Backrest's image is Alpine, so the hook installs it with
`apk add --no-cache sqlite` — about 1MB, over the same egress the S3 repo
already uses.

### Restoring

```bash
./setup.sh disable          # commit + push — ArgoCD-safe way to stop the writer
restic -r /home/pi/pendrive/backups/restic-repo \
  dump latest /data/db-dumps/filebrowser-quantum.sqlite \
  > /home/pi/k3s-volumes/apps/filebrowser-quantum/data/filebrowser.sqlite
rm -f /home/pi/k3s-volumes/apps/filebrowser-quantum/data/filebrowser.sqlite-wal \
      /home/pi/k3s-volumes/apps/filebrowser-quantum/data/filebrowser.sqlite-shm
./setup.sh enable
```

Deleting the leftover `-wal`/`-shm` is not optional: SQLite would replay the
old write-ahead log over the restored database. The index rebuilds itself on
first start, so nothing else needs restoring — a bare-metal rebuild is this
repo plus that one file.

## Media previews and subtitles

The image bundles `ffmpeg` and `ffprobe` at `/usr/local/bin`, used for video
thumbnails, HEIC conversion and subtitle extraction. Two things about it are
worth knowing before touching the config.

### `numImageProcessors` also sizes the ffmpeg pool

The backend derives ffmpeg concurrency from it as `(n + 1) / 2`. Set to `2`
— which reads like a sane two-worker setting — it produces exactly **one**
ffmpeg worker for the entire server, and everything media-related serialises
behind it: a single cold 1080p x265 thumbnail (≈15s on this box) stalls every
other preview and every subtitle request until they hit the 30s and 60s request
timeouts and return 408. It is set to `4` here: two ffmpeg workers, two cores
left for the indexer.

Thumbnails are cached after the first generation, so the stall is a
first-browse-of-a-new-folder effect, not a steady-state one.

### Embedded subtitles are off

`integrations.media.extractEmbeddedSubtitles: false`, and this one is an
upstream limitation rather than a tuning choice.

Opening a video makes the frontend request **every** subtitle stream the file
declares, one after another. Blu-ray and DVD rips carry bitmap subtitle tracks
(`hdmv_pgs_subtitle`, `dvd_subtitle`) alongside the text ones, and ffmpeg
cannot convert a bitmap track to WebVTT — *"subtitle encoding currently only
possible from text to text or bitmap to bitmap"*. Each one returns 500 and the
UI raises a full-screen error toast containing the entire ffmpeg banner, so a
two-PGS-track film produces two walls of red text on every open.

The backend records each track's `Codec` when it enumerates them but never
filters on it, and there is no per-codec config knob, so the only available
lever is the global toggle. Turning it off costs embedded *text* tracks in
FileBrowser's own player; sidecar files (`movie.srt` beside `movie.mkv`) still
work, and Jellyfin — which handles PGS correctly by burning it in during
transcode — is the right place to actually watch a film. Flip back to `true`
once upstream filters non-text codecs.

### "Failed to connect to the server, is it still running?"

This toast is not a server error and never appears in the pod log. The frontend
raises it from `fetchURL` when the browser's `fetch` itself throws
`TypeError: Failed to fetch` — the request never completed at the network
layer. Aborted-by-timeout is a *different* message (`requestTimedOut`), and an
HTTP error status is shown as the response body.

So it means the browser lost the connection, not that the app fell over. Usual
causes here, in order: the LAN dropped or Twingate reconnected mid-request
(`explorer.home.ijlalahmad.dev` resolves to a LAN address); a burst of requests
was still in flight when the tab navigated away; or the server was wedged
behind the single-ffmpeg-worker problem above long enough for the browser to
give up on the connection. Traefik is not the culprit —
`k3s/infra/traefik/values.yaml` sets 30m responding timeouts.

Check `./setup.sh status` and `restartCount` before chasing it; if the pod
hasn't restarted, nothing on the cluster side went wrong.

### `401: invalid token: signature is invalid` after a restart

Session-JWT verification failed: the browser presented a token that was not
signed with the current `FILEBROWSER_JWT_TOKEN_SECRET`. It is specifically
*not* an expiry — an expired token reports `token is expired`, and a revoked
one `token is expired or revoked`. Log in again and it clears; if it recurs
without a restart in between, the secret itself is drifting and that is worth
investigating.

A restart also invalidates **view grants** — the `viewToken` in media URLs is a
random hex string held only in memory (`utils.ViewGrantsCache`), never
persisted. A tab that was streaming across a pod roll gets `403` on
`/api/resources/view-token` until it re-requests one. Both are cosmetic and
both are expected after any roll.

## Decommissioning the old FileBrowser

Done — `k3s/apps/filebrowser/` is still in the repo for reference, but its
ApplicationSet entry is commented out and its Deployment pinned to
`replicas: 0`.

Removing the entry deletes the ArgoCD Application, and the
`resources-finalizer` on the ApplicationSet template cascades that into
deleting the Deployment, Service, IngressRoute and both PVCs. **The data
survives**: both PVs are `Retain`, so
`/home/pi/k3s-volumes/apps/filebrowser/` stays on disk with
`config/settings.json` and `database/filebrowser.db` — 76KB holding the v1
users and share links. The PVs are left `Released`; delete them by hand if you
want them out of `kubectl get pv`.

That directory is worth keeping until you are sure nothing was missed, because
it is the only copy of the v1 accounts. If you ever want them in Quantum, point
`server.database.migrateFrom` at a **copy** on this app's data volume and
restart once:

```bash
sudo cp /home/pi/k3s-volumes/apps/filebrowser/database/filebrowser.db \
        /home/pi/k3s-volumes/apps/filebrowser-quantum/data/legacy.db
# config/config.yaml: server.database.migrateFrom: "/home/filebrowser/data/legacy.db"
./setup.sh deploy
```

Clear `migrateFrom` afterwards. The two use completely different source
layouts, so per-user scopes need revisiting by hand regardless.

`explorer.home.ijlalahmad.dev` stays as the hostname. Moving to
`files.home.ijlalahmad.dev` now that it is free would invalidate every enrolled
passkey — `auth.methods.passkey.rpId` is bound to the hostname.

## Management

```bash
./setup.sh help                 # authoritative command list
./setup.sh deploy | status | logs | shell
./setup.sh disable | enable     # replicas 0/1 in git — ArgoCD-safe pause
./setup.sh pvc | seal
./setup.sh argocd-status | sync | diff
./setup.sh teardown             # PVC kept
./setup.sh teardown --purge     # deletes the index and thumbnails
```

## Notes

- **Runs as root** (`runAsUser: 0`). `/home/pi` and the exFAT pendrive hold
  files owned by several UIDs, and the app has to write all of them. What
  constrains it is the mount list, not the UID — since the root mount was
  removed there is nothing outside those two trees to reach.
- **`strategy: Recreate`** — the SQLite database and index sit on a
  single-writer hostPath volume, and a rolling update would briefly run two
  writers against the same WAL.
- **`trustProxyHeaders: true`** because Traefik is the only path in; this is
  what makes rate limiting and the activity log record real client IPs rather
  than the ingress pod's.
- **Image is `2.0.6-beta`, and that is the newest release.** The tags are
  confusing: `stable` and `latest` track the **older** 1.5.x line, not a
  hardened build of v2. Downgrading to `1.5.6-stable` would mean a config
  rewrite (v2 moved the `http.*` keys, the rule fields, the `userDefaults`
  shape and per-source permissions) and an undocumented SQLite→BoltDB
  downgrade — and it would not fix anything above: the subtitle behaviour has
  been the same since embedded extraction landed in the 0.8.x line. Stay on
  the beta. arm64 is published for this tag.
- **`[WARN] cacheDir slow write speed detected: 11.82 MB/s`** at startup is the
  SD card, and is expected. The thumbnail cache lives there by design; moving
  it to the pendrive would trade latency for wear on the drive that holds the
  media.
