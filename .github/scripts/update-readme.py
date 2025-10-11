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
        """Generate mermaid architecture diagram."""
        diagram = '''```mermaid
graph TB
    Internet[🌐 Internet] --> Router[🏠 Home Router]
    Router --> RPI[🍓 Raspberry Pi 4]
    
    subgraph "Core Infrastructure"
        RPI --> Docker[🐳 Docker Engine]
'''
        
        # Group services by category
        categories = {}
        for service in services:
            category = service.get('category', 'Other Services')
            if category not in categories:
                categories[category] = []
            categories[category].append(service)
        
        # Generate subgraphs for each category
        for category, cat_services in categories.items():
            if category == 'Infrastructure & Monitoring':
                # These are already in Core Infrastructure
                for service in cat_services:
                    name = service.get('name', service['directory'].title())
                    icon = service.get('icon', '📊')
                    purpose = service.get('purpose', service.get('description', ''))[:20]
                    diagram += f'        Docker --> {service["directory"].title()}[{icon} {name}<br/>{purpose}]\n'
            else:
                # Create subgraph for other categories
                safe_category = category.replace(' & ', ' and ').replace(' ', '')
                diagram += f'    end\n    \n    subgraph "{category}"\n'
                for service in cat_services:
                    name = service.get('name', service['directory'].title())
                    icon = service.get('icon', '🔧')
                    purpose = service.get('purpose', service.get('description', ''))[:20]
                    diagram += f'        Docker --> {service["directory"].title()}[{icon} {name}<br/>{purpose}]\n'
        
        diagram += '    end\n```'
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
        
        # Group services by category
        categories = {}
        for service in services:
            category = service.get('category', 'Other Services')
            if category not in categories:
                categories[category] = []
            categories[category].append(service)
        
        # Generate tables for each category
        category_order = [
            'Infrastructure & Monitoring',
            'Development & DevOps', 
            'File Management & Collaboration',
            'Media & Entertainment',
            'Dashboard & Network Services',
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
            mermaid_end = new_content.find('```', mermaid_start + 10) + 3
            new_diagram = self.generate_mermaid_diagram(services)
            new_content = new_content[:mermaid_start] + new_diagram + new_content[mermaid_end:]
        
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