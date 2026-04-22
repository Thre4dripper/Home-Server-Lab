#!/usr/bin/env python3
"""
Auto-generate k3s/README.md from each k3s/apps/<svc>/README.md frontmatter.

Each app's README must start with YAML frontmatter using this schema:

    ---
    name: "Homepage"                  # display name
    category: "🏡 Dashboards"         # group heading
    purpose: "Application Dashboard"  # short tagline
    description: "..."                # one-paragraph description
    icon: "🏠"                        # emoji
    namespace: "dashboard-network"    # k8s namespace
    external_port: "8800"             # LoadBalancer port (or "—")
    domain: "homepage.lan"            # ingress host (or "—")
    components:                       # k8s resources used
      - deployment
      - service
      - ingress
      - configmap
      - sealedsecret
      - rbac
    features:
      - "..."
    resource_usage: "~128MB RAM"
    ---
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List

import yaml


REQUIRED = ("name", "category", "purpose", "namespace", "icon")

CATEGORY_DESCRIPTIONS = {
    "🛠️ Infra & GitOps":      "Cluster control plane, GitOps, secrets",
    "🌐 Network & Ingress":   "DNS, VPN, ingress and remote access",
    "📊 Monitoring & Stats":  "Cluster + host observability",
    "🏡 Dashboards":          "Landing pages and service catalogs",
    "🤖 Automation":          "Workflow and smart-home automation",
    "🎬 Media & Entertainment": "Streaming and media servers",
    "📁 Files & Storage":     "Persistent file storage and sharing",
    "🧲 Downloads":            "Torrents, downloaders and grabbers",
    "🗄️ Databases":            "Stateful data stores",
}

CATEGORY_ORDER = list(CATEGORY_DESCRIPTIONS.keys())


# ─── Parsing ─────────────────────────────────────────────────────────────────


def parse_frontmatter(path: Path) -> Dict[str, Any] | None:
    text = path.read_text(encoding="utf-8", errors="ignore")
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return None
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as exc:
        print(f"⚠️  YAML error in {path}: {exc}")
        return None
    if not isinstance(data, dict):
        return None
    missing = [k for k in REQUIRED if k not in data]
    if missing:
        print(f"⚠️  {path.parent.name}: missing required fields {missing}")
        return None
    return data


def scan_apps(apps_dir: Path) -> List[Dict[str, Any]]:
    services: List[Dict[str, Any]] = []
    for item in sorted(apps_dir.iterdir()):
        if not item.is_dir() or item.name.startswith("."):
            continue
        readme = item / "README.md"
        if not readme.exists():
            print(f"⏭️  {item.name}: no README.md, skipping")
            continue
        meta = parse_frontmatter(readme)
        if meta is None:
            continue
        meta["directory"] = item.name
        meta["path"] = f"./apps/{item.name}/"
        meta.setdefault("external_port", "—")
        meta.setdefault("domain", "—")
        meta.setdefault("components", [])
        services.append(meta)
    return services


# ─── Renderers ───────────────────────────────────────────────────────────────


def _ordered_categories(by_cat: Dict[str, List[Dict]]) -> List[str]:
    seen: List[str] = []
    for cat in CATEGORY_ORDER:
        if cat in by_cat:
            seen.append(cat)
    for cat in sorted(by_cat):
        if cat not in seen:
            seen.append(cat)
    return seen


def render_categories_table(services: List[Dict[str, Any]]) -> str:
    by_cat: Dict[str, List[Dict[str, Any]]] = {}
    for s in services:
        by_cat.setdefault(s["category"], []).append(s)

    out = "## 🏷️ **Service Categories**\n\n"
    out += "| Category | Description | Services |\n"
    out += "|----------|-------------|----------|\n"
    for cat in _ordered_categories(by_cat):
        names = [s["name"] for s in by_cat[cat]]
        names_str = ", ".join(names[:5]) + (f", +{len(names) - 5} more" if len(names) > 5 else "")
        desc = CATEGORY_DESCRIPTIONS.get(cat, "")
        out += f"| {cat} | {desc} | {names_str} |\n"
    return out + "\n"


def render_service_tables(services: List[Dict[str, Any]]) -> str:
    by_cat: Dict[str, List[Dict[str, Any]]] = {}
    for s in services:
        by_cat.setdefault(s["category"], []).append(s)

    out = ""
    for cat in _ordered_categories(by_cat):
        out += f"### {cat}\n\n"
        out += "| Service | Namespace | Port | Domain | Components |\n"
        out += "|---------|-----------|------|--------|------------|\n"
        for s in sorted(by_cat[cat], key=lambda x: x["name"].lower()):
            comps = ", ".join(f"`{c}`" for c in s.get("components", [])) or "—"
            port = s.get("external_port") or "—"
            domain = s.get("domain") or "—"
            out += (
                f"| [**{s['icon']} {s['name']}**]({s['path']}) "
                f"| `{s['namespace']}` "
                f"| `{port}` "
                f"| `{domain}` "
                f"| {comps} |\n"
            )
        out += "\n"
    return out


def render_mermaid(services: List[Dict[str, Any]]) -> str:
    by_cat: Dict[str, List[Dict[str, Any]]] = {}
    for s in services:
        by_cat.setdefault(s["category"], []).append(s)

    used_ids: Dict[str, str] = {}

    def safe_id(text: str) -> str:
        base = re.sub(r"[^A-Za-z0-9]", "", text) or "Node"
        if base[0].isdigit():
            base = "N" + base
        candidate = base
        i = 2
        while candidate in used_ids and used_ids[candidate] != text:
            candidate = f"{base}{i}"
            i += 1
        used_ids[candidate] = text
        return candidate

    lines: List[str] = ["```mermaid", "graph LR"]
    lines += [
        "    %% ── Access path (user → service) ───────────────────────────",
        "    Internet[🌐 Internet]",
        "    Twingate[🛡️ Twingate Edge]",
        "    Router[🏠 Home Router]",
        "    Pi[🍓 Raspberry Pi 5]",
        "    K3s[☸️ k3s Cluster]",
        "",
        "    Internet --> Twingate --> Router",
        "    Internet --> Router",
        "    Router --> Pi --> K3s",
        "",
        "    %% ── GitOps deployment branch (parallel to access path) ────",
        "    GitHub[🐙 GitHub<br/>repo]",
        "    ArgoCD[🚀 ArgoCD<br/>GitOps]",
        "    GitHub ==> ArgoCD ==> K3s",
        "",
    ]

    for cat in _ordered_categories(by_cat):
        cat_id = safe_id(cat)
        lines.append(f'    subgraph {cat_id}["{cat}"]')
        lines.append("        direction TB")
        ids: List[str] = []
        for s in by_cat[cat]:
            sid = safe_id(s["directory"])
            ids.append(sid)
            lines.append(f'        {sid}[{s["icon"]}<br/>{s["name"]}]')
        for i in range(0, len(ids) - 1, 2):
            lines.append(f"        {ids[i]} --- {ids[i + 1]}")
        lines.append("    end")
        for sid in ids:
            lines.append(f"    K3s --> {sid}")
        lines.append("")

    lines += [
        "    classDef coreInfra fill:#ffffff,stroke:#2196f3,stroke-width:2px,color:#000000",
        "    classDef gitops fill:#fff3e0,stroke:#ef6c00,stroke-width:2px,color:#000000",
        "    class Internet,Twingate,Router,Pi,K3s coreInfra",
        "    class GitHub,ArgoCD gitops",
        "    linkStyle 4 stroke:#ef6c00,stroke-width:3px",
        "    linkStyle 5 stroke:#ef6c00,stroke-width:3px",
        "```",
    ]
    return "\n".join(lines)


# ─── README rewriter ─────────────────────────────────────────────────────────

START_SVC = "<!-- AUTOGEN:SERVICES:START -->"
END_SVC = "<!-- AUTOGEN:SERVICES:END -->"
START_DIA = "<!-- AUTOGEN:DIAGRAM:START -->"
END_DIA = "<!-- AUTOGEN:DIAGRAM:END -->"
START_CAT = "<!-- AUTOGEN:CATEGORIES:START -->"
END_CAT = "<!-- AUTOGEN:CATEGORIES:END -->"


def replace_block(content: str, start: str, end: str, body: str) -> str:
    pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.DOTALL)
    block = f"{start}\n{body.rstrip()}\n{end}"
    if pattern.search(content):
        return pattern.sub(block, content)
    return content.rstrip() + "\n\n" + block + "\n"


def update_readme(repo_root: Path, services: List[Dict[str, Any]]) -> bool:
    readme = repo_root / "k3s" / "README.md"
    if not readme.exists():
        print(f"❌ Not found: {readme}")
        return False

    content = readme.read_text(encoding="utf-8")

    note = (
        "> **📝 Note:** This section is auto-generated from each "
        "`k3s/apps/<svc>/README.md` frontmatter. Edit those files; this "
        "section regenerates on push.\n\n"
    )

    services_body = note + render_service_tables(services)
    categories_body = render_categories_table(services)
    diagram_body = (
        "> **📝 Note:** This diagram is auto-generated from service metadata.\n\n"
        + render_mermaid(services)
    )

    content = replace_block(content, START_CAT, END_CAT, categories_body)
    content = replace_block(content, START_DIA, END_DIA, diagram_body)
    content = replace_block(content, START_SVC, END_SVC, services_body)

    readme.write_text(content, encoding="utf-8")
    print(f"✅ Updated {readme.relative_to(repo_root)} with {len(services)} services")
    return True


def main() -> None:
    repo_root = Path(os.environ.get("GITHUB_WORKSPACE", ".")).resolve()
    apps_dir = repo_root / "k3s" / "apps"
    if not apps_dir.is_dir():
        print(f"❌ Not found: {apps_dir}")
        sys.exit(1)

    services = scan_apps(apps_dir)
    if not services:
        print("❌ No k3s services with frontmatter discovered")
        sys.exit(1)

    print(f"📊 Discovered {len(services)} k3s apps:")
    for s in services:
        print(f"  - {s['icon']} {s['name']:<20} ns={s['namespace']:<20} port={s.get('external_port', '—')}")

    if not update_readme(repo_root, services):
        sys.exit(1)


if __name__ == "__main__":
    main()
