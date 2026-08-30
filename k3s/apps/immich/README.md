---
name: "Immich"
category: "🎬 Media & Entertainment"
purpose: "Self-hosted Photo & Video Backup"
description: "Google Photos replacement with mobile auto-backup, ML-powered smart search and face recognition. Originals live on the external pendrive, hot previews on the SD card, all state in the shared Postgres (VectorChord), job queues on a dedicated Valkey. Public access via a Cloudflare tunnel."
icon: "📸"
namespace: "media"
external_port: "9100"
domain: "immich.home.ijlalahmad.dev"
components:
  - deployment
  - service
  - ingress
  - pvc
  - sealedsecret
features:
  - "Mobile auto-backup (iOS/Android) with local/external URL switching"
  - "Smart search + face recognition — separately pausable ML deployment"
  - "Multi-user with fully isolated libraries and per-user quotas"
  - "Originals on pendrive (fail-closed PV), previews on SD card"
  - "Shared Postgres 15 + VectorChord; dedicated Valkey for job queues"
  - "Public photos.ijlalahmad.dev via Cloudflare tunnel"
resource_usage: "~1GB RAM idle, up to ~3GB during ML indexing"
---

# Immich — Photo & Video Backup

The cluster's Google Photos replacement, run as a permanent service: phones auto-back-up 24×7, albums are shareable with friends and family through a public Cloudflare tunnel, and machine learning provides smart search ("beach sunset") and face recognition — all self-hosted.

Four cooperating Deployments in the `media` namespace:

| Workload | Image | Role |
|----------|-------|------|
| `immich` | `immich-server` | API + web UI + background jobs — the one `setup.sh` manages |
| `immich-machine-learning` | `immich-machine-learning` | CLIP smart search + face recognition; pausable independently |
| `immich-valkey` | `valkey` | Job-queue store (`noeviction`); disposable state |
| `immich-cloudflared` | `cloudflared` | Public tunnel `photos.ijlalahmad.dev`; starts at `replicas: 0` until a real token is sealed |

**Bump the two immich images together** — they are versioned as one product. Majors include breaking changes; read the release notes first.

## Kubernetes Architecture

| Resource | Type | Purpose |
|----------|------|---------|
| `immich` | Deployment | Server, `Recreate` (single writer on hostPath) |
| `immich-machine-learning` | Deployment | ML; Service name = the server's default ML URL |
| `immich-valkey` | Deployment + Service | Dedicated job-queue store (`noeviction`); disposable state, no PVC |
| `immich-cloudflared` | Deployment | Remote-managed tunnel, token-only config |
| `immich` | Service (LoadBalancer) | Web on `9100` |
| `immich-machine-learning` | Service (ClusterIP) | ML on `3003`, in-cluster only |
| `immich` | IngressRoute | `immich.home.ijlalahmad.dev` on `websecure`, wildcard TLS |
| `immich-media` | PV + PVC (50Gi) | Originals — pendrive, **`type: Directory`** (fail-closed) |
| `immich-thumbs` | PV + PVC (10Gi) | Previews — SD card, mounted over `/data/thumbs` |
| `immich-ml-cache` | PV + PVC (8Gi) | ML models — SD card |
| `immich-secret` | SealedSecret | `DB_PASSWORD`, `TUNNEL_TOKEN` |

### Measured resource usage (Pi 5, v3.1.0)

| Pod | Idle | Limit | Note |
|-----|------|-------|------|
| `immich` | ~750Mi idle | **2Gi** | 1Gi *and* 1536Mi both OOMKilled during bulk-import processing (thumbnails + ML + large-video frame extraction in parallel). Idle is modest; the limit exists for import bursts |
| `immich-machine-learning` | ~250Mi | 2Gi | drops after `MODEL_TTL`; peaks 1–1.5Gi while indexing |
| `immich-valkey` | ~10Mi | 320Mi | queue data is KBs |
| `postgres` (shared, delta) | — | 640Mi | raised from 384Mi; 512Mi OOMKilled during immich's initial migrations |

**Where is the config volume?** There isn't one — Immich keeps *all* configuration and internal state (settings, users, albums, faces, metadata, job state) in Postgres. The server is stateless apart from `/data`. "Immich's config on the SD card" is already true via the shared Postgres PV at `k3s-volumes/databases/postgres`.

## Data layout — what lives where

Everything the container sees is under `/data` (never change `IMMICH_MEDIA_LOCATION`). Sizes below are measured from a real 9.3 GB / 169-asset library, so the ratios are trustworthy.

| Dir | Tier | On-disk shape | What it is | Regenerable? | Back up? |
|-----|------|---------------|------------|--------------|----------|
| `library/` | pendrive | `admin/2026-August-11/IMG_20260811_140121.jpg` — by username, then storage template, **real filenames** | **The originals.** ~100% of the bytes | **NO — the treasure** | **YES** |
| `thumbs/` | **SD card** | `<userUUID>/5c/b2/<assetUUID>_thumbnail.webp` + `_preview.jpeg` | Two derivatives per asset: small webp for grid scrolling, larger jpeg preview for full-screen. **~3.4% of library size** | yes — thumbnail job | no |
| `encoded-video/` | pendrive | `<userUUID>/63/e2/<assetUUID>.mp4` | Transcodes for browser compatibility. Original untouched | yes — transcode job | no |
| `upload/` | pendrive | `<userUUID>/40/67/…` sharded | **Staging only** — files land here, then move to `library/`. Stays near-empty while the storage template is ON; if it were OFF every original would live here permanently | transient | yes (tiny) |
| `profile/` | pendrive | flat | User avatars | no | yes (tiny) |
| `backups/` | pendrive | `immich-db-backup-<ts>-v3.1.0-pg15.sql.gz` | Immich's own DB dumps — **left disabled**, see below | — | n/a (empty) |
| ML `/cache` | SD card | model files | Downloaded CLIP/face models (~1 GB) | yes — auto-redownload | no |

Tiering rationale: previews are the hot path every browse hits → SD ("SSD"); originals are cold bulk → pendrive ("HDD"). Carries forward unchanged to a NAS. `encoded-video/` could move to SD with the same PV pattern in `pvc.yaml`, but is left on the pendrive because transcodes can reach GBs.

### Where is the configuration?

**Not in these folders.** All six are media and derivatives. Immich keeps *every* setting and all internal state — users, albums, faces, EXIF metadata, job state — in **Postgres**. Mapping from a docker-compose setup:

| docker-compose | here |
|---|---|
| `UPLOAD_LOCATION` → `/data` (the six folders) | `immich-media` PV (pendrive) + `immich-thumbs` PV (SD) |
| `DB_DATA_LOCATION` → `/var/lib/postgresql/data` | shared Postgres PV on the SD card |

So "Immich's config on fast storage, and backed up" is already true — via the shared Postgres PV, which Backrest dumps.

### Managed library vs external library

Immich **never scans** `library/`. For managed assets the **database is authoritative** — a file copied into `library/` without a DB row is invisible. Directory scanning is exactly and only what the *external library* feature does.

| | Managed (`upload/` → `library/`) | External library |
|---|---|---|
| Who writes the files | Immich | you / other tools |
| Visible in the phone timeline | yes | yes |
| Thumbnails, EXIF, smart search, faces | yes | **yes** — same processing |
| Phone/browser/CLI can upload into it | **yes** — the default target | **no** |
| Storage template renames/organises | yes | no — your structure is kept |
| Metadata write-back (XMP sidecars) | yes | no |
| Delete from the UI | yes | no — removed on rescan if the file is gone |

External-library assets are **not** feature-degraded; the docs say they *"look and behave like any other asset."* The difference is about who owns the file on disk. Use an external library to index a folder something else manages; use the managed library for anything you want to upload.

Consequently there are exactly two coherent ways to import an existing library: **(a)** upload it through the API (server writes the file, creates the row, rebuilds derivatives), or **(b)** restore a DB dump *and* place files at exactly the paths those rows reference. Copying files in alone is neither.

### Visible ≠ synced

Backup is **one-way: device → server**. The phone pushes new camera-roll photos up; it never pulls server photos down into the camera roll. But the app renders the *server's* timeline, so anything on the server — browser upload, CLI import, another user's contribution to a shared album — appears on your phone, searchable and downloadable on demand. It simply doesn't consume phone storage.

Ingest is deduplicated by **file checksum**: the app calls `/api/assets/bulk-upload-check` with hashes *before* transferring bytes, so photos already on the server (however they got there) are marked backed-up without re-uploading.

### Originals are never modified

Transcoding and thumbnailing only ever *add* files. Immich docs on `encoded-video/`: *"the original is not removed."* `library/` holds the uploaded file byte-for-byte, browser playback may stream a transcode, but **Download always returns the original**. `ffmpeg.targetResolution` is set to `original` here, and the default policy only transcodes formats browsers can't play — so h264 phone video is passed through untouched. Freeing space on your phone is safe.

## Multi-user model (trips with friends)

Every path above is namespaced by user ID — Immich is multi-user by design:

- Each person gets an account. **Users can never see each other's libraries** — there is no global feed, no admin bypass in the UI.
- Set **per-user storage quotas** (Admin → Users), e.g. yourself 35G, friends 2–5G — nobody can fill the pendrive.
- **Trip flow**: create an album → share it with their accounts as **editor** (vs viewer = read-only) → they upload however they like, browser included, and add their own photos into the shared album next to your phone-synced ones.
- Assets stay **owned by whoever uploaded them**. An editor can remove only the photos they added, not the owner's; revoking sharing removes album access, never their photos.
- **Sharing with non-users**: album → Share → public link, with optional password, expiry and download toggle. Viewers need no account. That link is the only unauthenticated surface — the tunnel exposes the login page so friends can upload remotely, but every library stays behind auth.
- Partner sharing (full-library grant to one trusted user) exists — off by default.

## Prerequisites

1. **Pendrive mounted** with the media dir present (`type: Directory` PV fails closed otherwise):
   ```bash
   findmnt /home/pi/pendrive && mkdir -p /home/pi/pendrive/immich
   ```
2. **Shared Postgres runs the vchord-enabled image** (`tensorchord/vchord-postgres` — see [postgres README](../../databases/postgres/README.md)) and the immich DB exists:
   ```bash
   k3s/scripts/db-user.sh postgres create immich_user '<STRONG_PASS>' immich
   kubectl exec -n databases deploy/postgres -- psql -U postgres -d immich -c \
     "CREATE EXTENSION IF NOT EXISTS vchord CASCADE;
      CREATE EXTENSION IF NOT EXISTS cube;
      CREATE EXTENSION IF NOT EXISTS earthdistance;"
   ```
3. **Job queues** use the dedicated in-namespace Valkey (`valkey-deployment.yaml`) — BullMQ requires `noeviction`, which is instance-global, so the shared redis stays a pure LRU cache for other apps.
4. **Secrets** in `secret.yaml` (gitignored), then `./setup.sh seal`:
   - `DB_PASSWORD` — from step 2
   - `TUNNEL_TOKEN` — Cloudflare tunnel token (placeholder OK until step "Public access")

## Quick Start

```bash
cd k3s/apps/immich
./setup.sh seal      # after filling secret.yaml
./setup.sh deploy
./setup.sh status
./setup.sh logs      # watch DB migrations on first boot
```

Open `https://immich.home.ijlalahmad.dev` (or `http://<node-ip>:9100`), create the admin account, then immediately:

- **Admin → Settings → Job settings** — Pi-sized concurrency: thumbnails 2, metadata 2, smart search 1, face detection 1, transcode 1.
- **Admin → Settings → Server** — external domain `https://photos.ijlalahmad.dev`.
- **Admin → Users** — accounts + storage quotas.
- Leave **built-in database dumps OFF** — the shared cluster is already dump-backed by Backrest.

Mobile app: server `https://photos.ijlalahmad.dev`; in the app's network settings also set the local URL `https://immich.home.ijlalahmad.dev` — on home Wi-Fi it switches automatically, which bypasses Cloudflare's 100MB upload cap for large videos.

## Public access (Cloudflare tunnel)

1. Cloudflare Zero Trust → Networks → Tunnels → **Create tunnel** (remote-managed) → copy the token.
2. Add public hostname: `photos.ijlalahmad.dev` → `http://immich.media.svc.cluster.local:9100`.
3. Put the token in `secret.yaml` as `TUNNEL_TOKEN`, `./setup.sh seal`, redeploy the secret.
4. Set `replicas: 1` in `cloudflared-deployment.yaml` (ships at 0 so a placeholder token can't crashloop).
5. Verify: `kubectl -n media logs deploy/immich-cloudflared | grep -i "registered tunnel connection"`, then hit `https://photos.ijlalahmad.dev/api/server/ping` from mobile data.

Constraint: Cloudflare caps request bodies at **100MB** — remote uploads of large videos fail through the tunnel (LAN URL bypasses; Twingate is the fallback for full-size remote access). Very large single-file album downloads can hit the same ceiling.

## Machine learning on a Pi

- Guardrails baked in: `MACHINE_LEARNING_MODEL_TTL=300` (models unload from RAM after 5 min idle → ~50Mi footprint), 1 worker, 2Gi limit.
- First indexing of a large library takes **days** on Pi CPU — run it overnight; it's a one-time cost, new photos index incrementally.
- Pause ML anytime: `replicas: 0` in `ml-deployment.yaml` (git, ArgoCD-safe). Uploads keep working; ML jobs wait and drain when it returns.
- If ML seems dead on first use: it's downloading ~1GB of models — watch `kubectl -n media logs deploy/immich-machine-learning -f`.

## Backup (Backrest runbook — configure in the UI)

1. **Mount**: give the Backrest pod visibility of the media tree — add a read-only hostPath volume for `/home/pi/pendrive/immich` (e.g. at `/pendrive-immich`) to `k3s/apps/backrest/deployment.yaml`, mirroring its existing `pendrive-backups` entry. Use `type: Directory` so it fails closed when the pendrive is unmounted.
2. **Repo**: `s3:s3.ap-south-1.amazonaws.com/ijlalahmad-storage-bucket/immich-media` — reuses the AWS credentials already configured in Backrest.
3. **Plan**: path `/pendrive-immich`, **excludes** `thumbs/` (on SD anyway) and `encoded-video/` — both regenerable. What ships: `library/`, `upload/`, `profile/`.
4. **DB**: nothing extra. Backrest's pre-snapshot hook runs `pg_dumpall -U postgres`, which dumps **every database in the cluster** — `immich` was included automatically the moment it was created.
5. Schedule nightly; retention suggestion 7d / 4w / 6m.
6. Cost levers: S3 lifecycle → Intelligent-Tiering on the `immich-media/` prefix is safe; **never Glacier/Deep Archive** (restic needs random access to repo objects). Cloudflare R2 (zero egress) is worth revisiting when the library is much larger.

Restore path: restore `library/` from restic → restore the DB dump → run thumbnail + metadata jobs to regenerate the rest.

### Immich's built-in DB backup is deliberately OFF

Admin → Settings → Backup stays disabled. That feature exists for docker-compose users who back up only `UPLOAD_LOCATION`, so putting a dump inside the media folder makes one folder backup capture both. Here it would be redundant *and* worse-placed: `pg_dumpall` already covers the immich DB, Backrest's dump lands on the SD card and ships to S3, whereas Immich's dumps would sit on the pendrive beside the photos — same disk, so no protection if that disk dies — while adding a few hundred MB of duplicate data to the S3 bill.

## Importing an existing library

Because the managed library is database-authoritative (see above), you cannot copy files into `library/`. Upload them through the API instead — the server writes each file, creates its row, and rebuilds all derivatives.

Use **immich-go** (`immich-go_Linux_arm64.tar.gz`, single static binary, native arm64) and run it **on the Pi** so the bytes never cross the network:

1. Immich UI → Account Settings → **API Keys** → generate one.
2. Dry-run first against `http://localhost:9100`, pointing at the source folder.
3. Real run. If the source files are root-owned, run with sudo or fix read permissions first.
   - Don't pass `--folder-as-album` when the folders are storage-template dates (`2026-August-11`) — you'd get dozens of junk date albums.
4. Watch `kubectl top node`. If memory tightens, pause ML (`replicas: 0` in `ml-deployment.yaml`), let the upload finish, then re-enable and let indexing drain.
5. Verify the asset count in the UI before deleting the source, and spot-check that a video plays and thumbnails render.

Videos are cheap to import here: `targetResolution: original` plus the default "transcode only unsupported formats" policy means h264 phone video is passed through, needing only a hash and one thumbnail frame.

**Pause the queues during the transfer.** Uploading and processing compete for the same Pi. With `metadataExtraction`/`thumbnailGeneration` paused the transfer gets the box to itself; resume them afterwards and the second phase (metadata → files relocate into `library/` → thumbnails → ML) runs cleanly. Expect the processing phase to be the CPU/RAM-heavy one — this is where the server can OOM if its limit is too low.

**If jobs fail mid-import**, a `force: false` ("missing only") re-run does not always re-queue them — BullMQ keeps the failed job records. Re-running the job as **"All"** from Admin → Jobs in the web UI is the reliable fix; per-asset retries work too (`POST /api/assets/jobs` with `regenerate-thumbnail`).

**The phone then catches up by itself.** Its next scan sends checksums to `/api/assets/bulk-upload-check`, gets "already exists" for everything you imported, and marks those assets backed up — no multi-GB re-upload over Wi-Fi.

## Management Commands

```bash
./setup.sh deploy
./setup.sh status
./setup.sh logs                # server logs
./setup.sh shell               # bash inside the server pod
./setup.sh restart
./setup.sh pvc                 # PV/PVC status + host paths
./setup.sh seal                # secret.yaml → sealedsecret.yaml
./setup.sh argocd-status | sync | diff
./setup.sh teardown            # PVCs retained
./setup.sh teardown --purge    # deletes PVCs/PVs — media dir on disk survives (Retain + hostPath)

# sibling workloads (not covered by setup.sh):
kubectl -n media logs deploy/immich-machine-learning -f
kubectl -n media logs deploy/immich-valkey -f
kubectl -n media logs deploy/immich-cloudflared -f
```

## exFAT caveats (current pendrive)

- No chown/chmod — the fstab mount (`uid=1000,gid=1004,umask=000`) makes everything world-rwx; containers run as image default (root) and file ownership is forced by the mount. Don't add `fsGroup` expecting it to do anything.
- **No hardlinks** — Immich's storage-template migration falls back to copy+delete: slower and needs transient free space ≈ the largest batch being migrated.
- No symlinks — avoid external-library tricks that rely on links.
- Long-term fix is ext4/ZFS at the NAS upgrade; the PV path swap is one line.

## Troubleshooting

- **Pod stuck `CreateContainerError` / FailedMount on `immich-media`** → the pendrive isn't mounted (or `/home/pi/pendrive/immich` missing). This is the fail-closed design working. `findmnt /home/pi/pendrive`, fix, pod recovers.
- **CrashLoop on first boot, logs mention `vchord` or `vector`** → extensions not created in the immich DB, or postgres still on the vanilla image. See Prerequisites 2.
- **Queue errors / jobs stuck** → check the queue store: `kubectl -n media exec deploy/immich-valkey -- valkey-cli info memory | grep maxmemory` — at the 256mb cap writes error (bump `--maxmemory` in `valkey-deployment.yaml` if the library has grown huge).
- **Uploads fail from remote exactly at ~100MB** → Cloudflare cap; use the LAN URL (auto-switch) or Twingate.
- **Smart search returns nothing** → indexing hasn't run/finished — Admin → Jobs shows queue depth; verify ML: `kubectl -n media exec deploy/immich -- curl -s http://immich-machine-learning:3003/ping`.
- **Node memory pressure during bulk import** → pause ML (`replicas: 0`), finish uploads, resume; keep job concurrency at the Pi-sized values.
- **After a vchord image bump, migrations fail** → superuser step: `psql -U postgres -d immich -c "ALTER EXTENSION vchord UPDATE;"`.

## Links

- [Immich Docs](https://docs.immich.app/)
- [Environment variables](https://docs.immich.app/install/environment-variables)
- [Standalone Postgres requirements](https://docs.immich.app/administration/postgres-standalone/)
- [Cloudflare Tunnel docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
