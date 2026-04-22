#!/usr/bin/env python3
"""
Auto-update dynamic segments in the root README.md.

Scans both docker/<svc>/README.md and k3s/apps/<svc>/README.md frontmatter
to compute service counts, then replaces:

    <!-- AUTOGEN:DOCKER_COUNT -->...<!-- /AUTOGEN:DOCKER_COUNT -->
    <!-- AUTOGEN:K3S_COUNT -->...<!-- /AUTOGEN:K3S_COUNT -->
    <!-- AUTOGEN:CATALOG_TABLE -->...<!-- /AUTOGEN:CATALOG_TABLE -->
    <!-- AUTOGEN:GLOBAL_DIAGRAM -->...<!-- /AUTOGEN:GLOBAL_DIAGRAM -->

The architecture mermaid diagram has a fixed scaffold (users / internet /
edge / stacks / GitOps lane); only the workload tier is derived from
service frontmatter — each topic node lists the union of services across
both Docker and k3s, deduplicated by display name.

The script is idempotent and safe to run repeatedly.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

import yaml


REPO_ROOT = Path(__file__).resolve().parents[2]
README = REPO_ROOT / "README.md"
DOCKER_DIR = REPO_ROOT / "docker"
K3S_APPS_DIR = REPO_ROOT / "k3s" / "apps"


# ─── Unified workload topics ─────────────────────────────────────────────────
# Maps a "global topic" (used in the architecture diagram) to:
#   (banner emoji + label, list of keyword fragments to match against the
#    per-service `category` string from either stack — case-insensitive).
#
# Order here = vertical order of the workload tier in the diagram.

TOPICS: List[Tuple[str, str, List[str]]] = [
    # (topic_id, "<emoji> <bold label>", keyword aliases)
    ("Media",       "🎬 <b>Media</b>",            ["media"]),
    ("Dashboards",  "🏡 <b>Dashboards</b>",       ["dashboard"]),
    ("Automation",  "🤖 <b>Automation</b>",       ["automation", "smart home"]),
    ("Files",       "📁 <b>Files &amp; Sync</b>", ["file", "storage", "collaboration"]),
    ("Downloads",   "🧲 <b>Downloads</b>",        ["download"]),
    ("Monitoring",  "📊 <b>Monitoring</b>",       ["monitor", "stats"]),
    ("Devtools",    "🛠️ <b>Dev tooling</b>",      ["dev", "devops", "gitops"]),
    ("Network",     "🌐 <b>Network &amp; Edge</b>", ["network", "ingress"]),
    ("Databases",   "🗄️ <b>Databases</b>",        ["database"]),
]

# Services to omit from the workload tier of the global diagram because they
# are already represented as core infrastructure nodes (Pi-hole / Twingate /
# ArgoCD all show up explicitly in the "Home edge" / "GitOps" tiers).
WORKLOAD_BLOCKLIST = {"pi-hole", "twingate connector", "argocd", "nginx proxy manager"}


# ─── Frontmatter scanning ────────────────────────────────────────────────────


def parse_frontmatter(path: Path) -> dict | None:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return None
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as exc:
        print(f"⚠️  YAML error in {path}: {exc}")
        return None
    return data if isinstance(data, dict) else None


def scan_stack(root: Path) -> List[dict]:
    services: List[dict] = []
    if not root.is_dir():
        return services
    for child in sorted(root.iterdir()):
        if not child.is_dir() or child.name.startswith("."):
            continue
        readme = child / "README.md"
        if not readme.exists():
            continue
        meta = parse_frontmatter(readme)
        if meta and meta.get("name") and meta.get("category"):
            services.append(meta)
    return services


def classify(category: str) -> str | None:
    """Map a per-stack category string to a global topic id (or None)."""
    cat = category.lower()
    for topic_id, _, aliases in TOPICS:
        for kw in aliases:
            if kw in cat:
                return topic_id
    return None


def topic_services(docker: List[dict], k3s: List[dict]) -> Dict[str, List[str]]:
    """Return ordered topic_id → unique service display names (across stacks)."""
    out: Dict[str, List[str]] = {tid: [] for tid, _, _ in TOPICS}
    seen: Dict[str, set] = {tid: set() for tid, _, _ in TOPICS}
    for svc in docker + k3s:
        tid = classify(svc["category"])
        if not tid:
            continue
        name = str(svc["name"]).strip()
        if name.lower() in WORKLOAD_BLOCKLIST:
            continue
        key = name.lower()
        if key in seen[tid]:
            continue
        seen[tid].add(key)
        out[tid].append(name)
    return out


# ─── Mermaid renderer ────────────────────────────────────────────────────────


DIAGRAM_HEADER = """```mermaid
graph TB
    %% ─── HEADERS (rendered as banner nodes) ─────────────────────────────
    H1>"<b>① WHO USES IT</b>"]
    H2>"<b>② INTERNET SERVICES</b>"]
    H3>"<b>③ HOME EDGE</b>     ·     no inbound port-forward, ever"]
    H4>"<b>④ THE PI</b>     ·     two stacks, one box"]
    H5>"<b>⑤ SELF-HOSTED WORKLOADS</b>"]

    %% ─── TIER 1 · users ─────────────────────────────────────────────────
    Dev[👨‍💻 <b>Developer</b><br/>writes manifests<br/>+ compose files]
    Remote[📱 <b>Remote user</b><br/>phone · laptop<br/>any network]
    LAN[🏠 <b>LAN user</b><br/>desktop · TV · IoT<br/>same Wi-Fi]

    %% ─── TIER 2 · internet services ─────────────────────────────────────
    Repo[(🐙 <b>GitHub repo</b><br/>source of truth)]
    Actions[⚙️ <b>GitHub Actions</b><br/>regenerate READMEs<br/>validate frontmatter]
    CF[(☁️ <b>Cloudflare DNS</b><br/>your-domain.tld<br/>→ Twingate edge)]
    TGEdge[🛡️ <b>Twingate Edge</b><br/>identity-aware proxy<br/>no open inbound port]

    %% ─── TIER 3 · home edge ─────────────────────────────────────────────
    Router[🏠 <b>Home Router</b><br/>NAT · DHCP only]
    TGConn[🛡️ <b>Twingate Connector</b><br/>outbound TCP/443 only<br/>punches no holes]
    Pihole[🛡️ <b>Pi-hole</b><br/>LAN DNS · ad-block<br/>*.lan → 192.168.x.x]

    %% ─── TIER 4 · the Pi ────────────────────────────────────────────────
    Docker[🐳 <b>Docker stack</b><br/>{docker_count} services · prototyping<br/>docker compose + setup.sh<br/>NPM for TLS / reverse-proxy]
    Argo[🚀 <b>ArgoCD</b><br/>GitOps controller<br/>pulls main every 3 min]
    K3s[☸️ <b>k3s cluster</b><br/>{k3s_count} apps · production<br/>Traefik IngressRoute<br/>cert-manager · SealedSecrets]
"""

DIAGRAM_FOOTER_FLOWS = """
    %% ─── HEADER ANCHORS (invisible) ─────────────────────────────────────
    H1 ~~~ Dev
    H2 ~~~ Repo
    H3 ~~~ Router
    H4 ~~~ Docker
    H5 ~~~ {first_workload}

    %% ─── FLOWS · GitOps lane (purple, thick) ────────────────────────────
    Dev      == "git push" ==> Repo
    Repo     -- webhook --> Actions
    Actions -. "auto-commit<br/>regenerated docs" .-> Repo
    Repo     == "pull every 3 min" ==> Argo
    Argo     == "kubectl apply" ==> K3s

    %% ─── FLOWS · manual Docker deploy ───────────────────────────────────
    Dev -. "ssh + ./setup.sh" .-> Docker

    %% ─── FLOWS · remote access lane (orange) ────────────────────────────
    Remote --> CF --> TGEdge
    TGEdge -. "encrypted tunnel" .-> TGConn
    TGConn --> Docker
    TGConn --> K3s

    %% ─── FLOWS · LAN access lane (green) ────────────────────────────────
    LAN --> Router --> Pihole
    Pihole --> Docker
    Pihole --> K3s

    %% ─── FLOWS · stacks → workloads ─────────────────────────────────────
    Docker --> {workload_chain}
    K3s    --> {workload_chain}

    %% ─── STYLES ─────────────────────────────────────────────────────────
    classDef header   fill:#263238,stroke:#263238,color:#ffffff,font-size:18px,font-weight:bold
    classDef user     fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#000
    classDef internet fill:#fff3e0,stroke:#ef6c00,stroke-width:2px,color:#000
    classDef edge     fill:#fce4ec,stroke:#c2185b,stroke-width:2px,color:#000
    classDef stack    fill:#e3f2fd,stroke:#1565c0,stroke-width:3px,color:#000
    classDef gitops   fill:#f3e5f5,stroke:#6a1b9a,stroke-width:3px,color:#000
    classDef workload fill:#fffde7,stroke:#f9a825,stroke-width:2px,color:#000

    class H1,H2,H3,H4,H5 header
    class Dev,Remote,LAN user
    class Repo,Actions,CF,TGEdge internet
    class Router,TGConn,Pihole edge
    class Docker,K3s stack
    class Argo gitops
    class {workload_class_list} workload
```

**How to read this diagram:**

| Path | Color | What flows |
|------|-------|------------|
| **🟣 GitOps** (purple, thick) | `Dev → GitHub → ArgoCD → k3s` | A `git push` reconciles into the cluster automatically — no SSH, no `kubectl` |
| **🟠 Remote access** (orange) | `Remote → Cloudflare → Twingate edge ⇢ Twingate connector → stack` | Identity-aware, outbound-only, works behind CGNAT |
| **🟢 LAN access** (green) | `LAN → Pi-hole → stack` | Pure-DNS routing — no router config, no certs needed for `*.lan` |
| **🔵 The Pi** (blue) | hosts both stacks side-by-side | Docker for tinkering, k3s for production — same workloads, different lifecycles |
"""


def render_diagram(docker: List[dict], k3s: List[dict]) -> str:
    by_topic = topic_services(docker, k3s)
    # Keep only topics that actually have services
    active = [(tid, label) for (tid, label, _) in TOPICS if by_topic.get(tid)]
    if not active:
        active = [("Workloads", "📦 <b>Workloads</b>")]
        by_topic = {"Workloads": []}

    lines = [DIAGRAM_HEADER.format(
        docker_count=len(docker),
        k3s_count=len(k3s),
    )]
    lines.append("")
    lines.append("    %% ─── TIER 5 · self-hosted workloads (auto-generated) ────────────────")

    workload_ids: List[str] = []
    for idx, (tid, label) in enumerate(active, start=1):
        node_id = f"W{idx}"
        workload_ids.append(node_id)
        names = by_topic[tid]
        if names:
            shown = " · ".join(names[:5])
            if len(names) > 5:
                shown += f" · +{len(names) - 5} more"
            lines.append(f'    {node_id}[{label}<br/>{shown}]')
        else:
            lines.append(f'    {node_id}[{label}]')

    chain = " & ".join(workload_ids)
    class_list = ",".join(workload_ids)
    lines.append(DIAGRAM_FOOTER_FLOWS.format(
        first_workload=workload_ids[0],
        workload_chain=chain,
        workload_class_list=class_list,
    ))
    return "\n".join(lines)


# ─── Marker replacement ──────────────────────────────────────────────────────


def replace_block(content: str, marker: str, new_inner: str) -> str:
    pattern = re.compile(
        rf"(<!--\s*AUTOGEN:{re.escape(marker)}\s*-->)(.*?)(<!--\s*/AUTOGEN:{re.escape(marker)}\s*-->)",
        re.DOTALL,
    )
    if not pattern.search(content):
        print(f"⚠️  Marker AUTOGEN:{marker} not found in README.md")
        return content
    return pattern.sub(lambda m: f"{m.group(1)}{new_inner}{m.group(3)}", content)


def main() -> int:
    if not README.exists():
        print(f"❌ {README} not found", file=sys.stderr)
        return 1

    docker_services = scan_stack(DOCKER_DIR)
    k3s_services = scan_stack(K3S_APPS_DIR)

    docker_count = len(docker_services)
    k3s_count = len(k3s_services)
    docker_categories = sorted({s["category"] for s in docker_services})
    k3s_categories = sorted({s["category"] for s in k3s_services})

    catalog_table = (
        "\n"
        "| Stack | Catalog | Services | Categories |\n"
        "|-------|---------|----------|------------|\n"
        f"| 🐳 Docker | **[docker/README.md →](./docker/README.md)** | "
        f"{docker_count} ready-to-run Compose stacks | {len(docker_categories)} |\n"
        f"| ☸️ k3s | **[k3s/README.md →](./k3s/README.md)** | "
        f"{k3s_count} GitOps-managed Kubernetes apps | {len(k3s_categories)} |\n"
    )

    diagram_block = "\n" + render_diagram(docker_services, k3s_services) + "\n"

    content = README.read_text(encoding="utf-8")
    original = content

    content = replace_block(content, "DOCKER_COUNT", str(docker_count))
    content = replace_block(content, "K3S_COUNT", str(k3s_count))
    content = replace_block(content, "CATALOG_TABLE", catalog_table)
    content = replace_block(content, "GLOBAL_DIAGRAM", diagram_block)

    if content == original:
        print(f"✅ README.md already up to date (docker={docker_count}, k3s={k3s_count})")
        return 0

    README.write_text(content, encoding="utf-8")
    print(
        f"✅ Updated README.md "
        f"(docker={docker_count} services / {len(docker_categories)} categories, "
        f"k3s={k3s_count} services / {len(k3s_categories)} categories)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
