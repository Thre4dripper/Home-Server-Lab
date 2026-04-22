#!/usr/bin/env python3
"""
Validate service README metadata before committing.

Usage:
  python3 .github/scripts/validate-service.py <service-directory>

The stack is auto-detected from the path:
  - docker/<svc>/  → docker schema
  - k3s/apps/<svc>/ → k3s schema
"""

import sys
import re
import yaml
from pathlib import Path

DOCKER_REQUIRED = ['name', 'category', 'purpose', 'description', 'icon', 'features', 'resource_usage']
K3S_REQUIRED = ['name', 'category', 'purpose', 'description', 'icon', 'namespace', 'components', 'features', 'resource_usage']

DOCKER_CATEGORIES = [
    '📊 Monitoring & Stats',
    '🧲 Download Managers',
    '🎬 Media & Entertainment',
    '📁 File Management & Collaboration',
    '🏠 Smart Home Automation & Workflow',
    '🛠️ Development & DevOps',
    '🏡 Dashboard & Network Services',
    '🚀 Backend Services',
]

K3S_CATEGORIES = [
    '🛠️ Infra & GitOps',
    '🌐 Network & Ingress',
    '📊 Monitoring & Stats',
    '🏡 Dashboards',
    '🤖 Automation',
    '🎬 Media & Entertainment',
    '📁 Files & Storage',
    '🧲 Downloads',
    '🗄️ Databases',
]


def detect_stack(service_dir: Path) -> str:
    parts = service_dir.resolve().parts
    if 'k3s' in parts and 'apps' in parts:
        return 'k3s'
    return 'docker'


def validate_service_metadata(service_dir: str) -> bool:
    """Validate a single service's README metadata."""
    service_path = Path(service_dir)
    readme_path = service_path / 'README.md'
    stack = detect_stack(service_path)
    required_fields = K3S_REQUIRED if stack == 'k3s' else DOCKER_REQUIRED
    valid_categories = K3S_CATEGORIES if stack == 'k3s' else DOCKER_CATEGORIES

    if not readme_path.exists():
        print(f"❌ No README.md found in {service_dir}")
        return False
    
    try:
        with open(readme_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"❌ Error reading {readme_path}: {e}")
        return False
    
    # Check for YAML frontmatter
    frontmatter_pattern = r'^---\s*\n(.*?)\n---\s*\n'
    match = re.match(frontmatter_pattern, content, re.DOTALL)
    
    if not match:
        print(f"❌ No YAML frontmatter found in {readme_path}")
        print("   Add metadata like this to the top of your README:")
        print("   ---")
        print("   name: \"Service Name\"")
        print("   category: \"📊 Infrastructure & Monitoring\"")
        print("   purpose: \"Brief purpose\"")
        print("   # ... other fields")
        print("   ---")
        return False
    
    try:
        yaml_content = match.group(1)
        metadata = yaml.safe_load(yaml_content)
    except yaml.YAMLError as e:
        print(f"❌ Invalid YAML in {readme_path}: {e}")
        return False
    
    # Required fields
    missing_fields = [f for f in required_fields if f not in metadata]
    
    if missing_fields:
        print(f"❌ Missing required fields in {readme_path} ({stack} schema): {', '.join(missing_fields)}")
        return False
    
    # Validate categories
    
    if metadata['category'] not in valid_categories:
        print(f"⚠️  Unknown category '{metadata['category']}' in {readme_path}")
        print(f"   Consider using one of: {', '.join(valid_categories)}")
    
    # Validate features is a list
    if not isinstance(metadata['features'], list):
        print(f"❌ 'features' should be a list in {readme_path}")
        return False
    
    if len(metadata['features']) < 2:
        print(f"⚠️  Consider adding more features (current: {len(metadata['features'])}) in {readme_path}")
    
    print(f"✅ {service_dir} metadata is valid ({stack})")
    print(f"   Name: {metadata['name']}")
    print(f"   Category: {metadata['category']}")
    print(f"   Purpose: {metadata['purpose']}")
    if stack == 'k3s':
        print(f"   Namespace: {metadata['namespace']}")
        print(f"   Components: {len(metadata.get('components') or [])} listed")
    print(f"   Features: {len(metadata['features'])} listed")
    print(f"   Resource Usage: {metadata['resource_usage']}")
    
    return True

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 .github/scripts/validate-service.py <service-directory>")
        print("Example: python3 .github/scripts/validate-service.py ./netdata")
        sys.exit(1)
    
    service_dir = sys.argv[1].rstrip('/')
    
    if not Path(service_dir).exists():
        print(f"❌ Directory {service_dir} does not exist")
        sys.exit(1)
    
    if validate_service_metadata(service_dir):
        print(f"\n🎉 Service {service_dir} is ready for the automated README!")
        sys.exit(0)
    else:
        print(f"\n💡 Fix the issues above and try again")
        sys.exit(1)

if __name__ == '__main__':
    main()