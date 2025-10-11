#!/usr/bin/env python3
"""
Auto-generate README.md services section and mermaid diagram
from individual service README.md files with metadata.
"""

import os
import re
import yaml
import sys
from pathlib import Path
from typing import Dict, List, Optional

class ServiceParser:
    def __init__(self, repo_root: str):
        self.repo_root = Path(repo_root)
        self.services = []
        
    def extract_metadata(self, readme_path: Path) -> Optional[Dict]:
        """Extract YAML frontmatter from README.md files."""
        try:
            with open(readme_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Check for YAML frontmatter
            frontmatter_pattern = r'^---\s*\n(.*?)\n---\s*\n'
            match = re.match(frontmatter_pattern, content, re.DOTALL)
            
            if not match:
                return None
                
            yaml_content = match.group(1)
            metadata = yaml.safe_load(yaml_content)
            
            # Extract description from first paragraph after frontmatter
            remaining_content = content[match.end():].strip()
            description_match = re.match(r'^#[^#\n]*\n\n([^#\n]+)', remaining_content)
            if description_match:
                metadata['description'] = description_match.group(1).strip()
            
            return metadata
            
        except Exception as e:
            print(f"Error parsing {readme_path}: {e}")
            return None
    
    def scan_services(self) -> List[Dict]:
        """Scan all service directories for metadata."""
        services = []
        
        # Look for all directories with README.md files that contain metadata
        for item in self.repo_root.iterdir():
            if not item.is_dir() or item.name.startswith('.'):
                continue
                
            readme_path = item / 'README.md'
            if not readme_path.exists():
                continue
                
            metadata = self.extract_metadata(readme_path)
            if not metadata:
                # If no metadata, skip this service (not an error)
                continue
                
            # Add service directory name
            metadata['directory'] = item.name
            metadata['path'] = f"./{item.name}/"
            
            services.append(metadata)
        
        return sorted(services, key=lambda x: (x.get('category', 'zzz'), x.get('name', x['directory'])))
    
    def generate_services_table(self, category: str, services: List[Dict]) -> str:
        """Generate markdown table for a service category."""
        if not services:
            return ""
            
        table = f"### {category}\n\n"
        table += "| Service | Purpose | Key Features | Resource Usage |\n"
        table += "|---------|---------|--------------|----------------|\n"
        
        for service in services:
            name = service.get('name', service['directory'].title())
            purpose = service.get('purpose', service.get('description', 'No description'))
            features = service.get('features', ['Feature 1', 'Feature 2', 'Feature 3'])
            resource_usage = service.get('resource_usage', '~200MB RAM')
            
            # Format features as comma-separated list
            if isinstance(features, list):
                features_str = ', '.join(features[:3])  # Limit to 3 features
            else:
                features_str = str(features)
            
            # Truncate long descriptions
            if len(purpose) > 80:
                purpose = purpose[:77] + "..."
            if len(features_str) > 80:
                features_str = features_str[:77] + "..."
                
            table += f"| [**{name}**]({service['path']}) | {purpose} | {features_str} | {resource_usage} |\n"
        
        return table + "\n"
    
    def generate_mermaid_diagram(self, services: List[Dict]) -> str:
        """Generate mermaid architecture diagram with LR layout and 2-column subgraphs."""
        diagram = """```mermaid
graph LR
    Internet[🌐 Internet]
    Router[🏠 Home Router]
    RPI[🍓 Raspberry Pi]
    Docker[🐳 Docker]
    
    Internet --> Router
    Router --> RPI
    RPI --> Docker
    
    %% Core Infrastructure
    subgraph Core["🏗️ Core Infrastructure"]
        direction TB
"""
        
        # Group services by category
        categories = {}
        for service in services:
            category = service.get('category', 'Other Services')
            if category not in categories:
                categories[category] = []
            categories[category].append(service)
        
        # Handle Infrastructure & Monitoring services first (in Core section)
        infra_services = categories.get('📊 Infrastructure & Monitoring', [])
        for service in infra_services:
            name = service.get('name', service['directory'].title())
            icon = service.get('icon', '📊')
            service_id = service['directory'].replace('-', '').replace('_', '').title()
            diagram += f'        {service_id}[{icon}<br/>{name}]\n'
        
        # Create 2-column layout for infrastructure services
        for i in range(0, len(infra_services), 2):
            if i + 1 < len(infra_services):
                service1_id = infra_services[i]['directory'].replace('-', '').replace('_', '').title()
                service2_id = infra_services[i + 1]['directory'].replace('-', '').replace('_', '').title()
                diagram += f'        {service1_id} --- {service2_id}\n'
        
        diagram += '    end\n\n'
        
        # Connect Docker to core infrastructure
        for service in infra_services:
            service_id = service['directory'].replace('-', '').replace('_', '').title()
            diagram += f'    Docker --> {service_id}\n'
        
        # Generate subgraphs for other categories (exclude Infrastructure & Monitoring)
        other_categories = {k: v for k, v in categories.items() if k != '📊 Infrastructure & Monitoring'}
        
        for category, cat_services in other_categories.items():
            # Create clean category ID
            safe_cat = ''.join(c for c in category if c.isalnum())
            if not safe_cat:
                safe_cat = "OtherServices"
            
            diagram += f'\n    %% {category}\n'
            diagram += f'    subgraph {safe_cat}["{category}"]\n'
            diagram += f'        direction TB\n'
            
            # Add services
            for service in cat_services:
                name = service.get('name', service['directory'].title())
                icon = service.get('icon', '🔧')
                service_id = service['directory'].replace('-', '').replace('_', '').title()
                diagram += f'        {service_id}[{icon}<br/>{name}]\n'
            
            # Create 2-column layout by connecting services horizontally in pairs
            for i in range(0, len(cat_services), 2):
                if i + 1 < len(cat_services):
                    service1_id = cat_services[i]['directory'].replace('-', '').replace('_', '').title()
                    service2_id = cat_services[i + 1]['directory'].replace('-', '').replace('_', '').title()
                    diagram += f'        {service1_id} --- {service2_id}\n'
            
            diagram += '    end\n'
            
            # Connect Docker to these services
            for service in cat_services:
                service_id = service['directory'].replace('-', '').replace('_', '').title()
                diagram += f'    Docker -.-> {service_id}\n'
        
        # Add custom styling with proper contrast
        diagram += """
    %% Custom Styling for better visibility and contrast
    classDef coreInfra fill:#ffffff,stroke:#2196f3,stroke-width:2px,color:#000000
    classDef infraNode fill:#e3f2fd,stroke:#1976d2,stroke-width:2px,color:#000000
    classDef devNode fill:#fff3e0,stroke:#f57c00,stroke-width:1px,color:#000000
    classDef mediaNode fill:#fce4ec,stroke:#e91e63,stroke-width:1px,color:#000000
    classDef fileNode fill:#e8f5e8,stroke:#4caf50,stroke-width:1px,color:#000000
    classDef dashNode fill:#f3e5f5,stroke:#9c27b0,stroke-width:1px,color:#000000
    
    class Internet,Router,RPI,Docker coreInfra
    class Netdata,Portainer infraNode
    class Gitlab,Gitea,Localstack,N8N devNode
    class Plex mediaNode
    class Pydio,Seafile,Owncloud fileNode
    class Dashby,Homarr,Pihole dashNode
```"""
        return diagram
    
    def update_readme(self, services: List[Dict]):
        """Update the main README.md file."""
        readme_path = self.repo_root / 'README.md'
        
        with open(readme_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Find the services section
        services_start = content.find('## 🚀 **Available Services**')
        if services_start == -1:
            print("Error: Could not find services section in README.md")
            return False
        
        # Find the next major section (next ## header)
        services_end = content.find('\n## ', services_start + 1)
        if services_end == -1:
            print("Error: Could not find end of services section")
            return False
        
        # Generate new services content
        new_services_content = "\n## 🚀 **Available Services**\n\n"
        new_services_content += "> **📝 Note:** This section is automatically generated from individual service README.md files. "
        new_services_content += "To update service information, edit the respective service's README.md file and the changes will be reflected here automatically.\n\n"
        
        # Group services by category
        categories = {}
        for service in services:
            category = service.get('category', 'Other Services')
            if category not in categories:
                categories[category] = []
            categories[category].append(service)
        
        # Generate tables for each category
        category_order = [
            '📊 Infrastructure & Monitoring',
            '🛠️ Development & DevOps', 
            '📁 File Management & Collaboration',
            '🎬 Media & Entertainment',
            '🏡 Dashboard & Network Services',
            'Other Services'
        ]
        
        for category in category_order:
            if category in categories:
                new_services_content += self.generate_services_table(category, categories[category])
        
        # Handle any remaining categories not in the predefined order
        for category, cat_services in categories.items():
            if category not in category_order:
                new_services_content += self.generate_services_table(category, cat_services)
        
        # Replace the services section
        new_content = content[:services_start] + new_services_content + content[services_end:]
        
        # Update mermaid diagram if present
        mermaid_start = new_content.find('```mermaid')
        if mermaid_start != -1:
            # Look for any existing note before the mermaid diagram
            note_pattern = r'> \*\*📝 Note:\*\*.*?\n\n```mermaid'
            note_match = re.search(note_pattern, new_content[:mermaid_start + 50], re.DOTALL)
            
            if note_match:
                # Note already exists, just update the diagram
                mermaid_end = new_content.find('```', mermaid_start + 10) + 3
                new_diagram = self.generate_mermaid_diagram(services)
                new_content = new_content[:mermaid_start] + new_diagram + new_content[mermaid_end:]
            else:
                # Add note before the mermaid diagram
                mermaid_end = new_content.find('```', mermaid_start + 10) + 3
                new_diagram_with_note = "> **📝 Note:** This architecture diagram is automatically generated from service metadata. Changes will be reflected when services are added or modified.\n\n"
                new_diagram_with_note += self.generate_mermaid_diagram(services)
                new_content = new_content[:mermaid_start] + new_diagram_with_note + new_content[mermaid_end:]
        
        # Write updated content
        with open(readme_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print(f"✅ Updated README.md with {len(services)} services across {len(categories)} categories")
        return True

def main():
    repo_root = os.environ.get('GITHUB_WORKSPACE', '.')
    
    parser = ServiceParser(repo_root)
    services = parser.scan_services()
    
    if not services:
        print("❌ No services found with metadata")
        sys.exit(1)
    
    print(f"📊 Found {len(services)} services:")
    for service in services:
        print(f"  - {service.get('name', service['directory'])} ({service.get('category', 'No category')})")
    
    if parser.update_readme(services):
        print("✅ README.md updated successfully")
    else:
        print("❌ Failed to update README.md")
        sys.exit(1)

if __name__ == '__main__':
    main()