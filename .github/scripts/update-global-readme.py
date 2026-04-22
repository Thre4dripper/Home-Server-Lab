#!/usr/bin/env python3
"""
Auto-update dynamic segments in the root README.md.

Scans both docker/<svc>/README.md and k3s/apps/<svc>/README.md frontmatter
to compute service counts + category counts per stack, then replaces the
content between AUTOGEN markers in the root README.

Markers used:
    <!-- AUTOGEN:DOCKER_COUNT -->...<!-- /AUTOGEN:DOCKER_COUNT -->
    <!-- AUTOGEN:K3S_COUNT -->...<!-- /AUTOGEN:K3S_COUNT -->
    <!-- AUTOGEN:DOCKER_CATEGORIES -->...<!-- /AUTOGEN:DOCKER_CATEGORIES -->
    <!-- AUTOGEN:K3S_CATEGORIES -->...<!-- /AUTOGEN:K3S_CATEGORIES -->
    <!-- AUTOGEN:CATALOG_TABLE -->...<!-- /AUTOGEN:CATALOG_TABLE -->

The script is idempotent and safe to run repeatedly.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Dict, List

import yaml


REPO_ROOT = Path(__file__).resolve().parents[2]
README = REPO_ROOT / "README.md"
DOCKER_DIR = REPO_ROOT / "docker"
K3S_APPS_DIR = REPO_ROOT / "k3s" / "apps"


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


def replace_block(content: str, marker: str, new_inner: str) -> str:
    """Replace text between <!-- AUTOGEN:MARKER --> and <!-- /AUTOGEN:MARKER -->."""
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

    content = README.read_text(encoding="utf-8")
    original = content

    content = replace_block(content, "DOCKER_COUNT", str(docker_count))
    content = replace_block(content, "K3S_COUNT", str(k3s_count))
    content = replace_block(content, "CATALOG_TABLE", catalog_table)

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
