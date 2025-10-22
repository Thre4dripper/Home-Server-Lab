#!/bin/bash

# Dashy Configuration Management Script
# This script handles configuration validation, syncing, and management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
SERVICE_NAME="Dashy Dashboard"
CONTAINER_NAME="dashy"
DEFAULT_PORT="4000"

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate root configuration file
validate_root_config() {
    print_status "Validating root configuration..."
    
    # Check if root configuration file exists
    if [[ ! -f "conf.yml" ]]; then
        print_error "Configuration file conf.yml not found in project root"
        print_status "Please ensure the main configuration file exists at: ./conf.yml"
        exit 1
    fi
    
    # Basic YAML syntax check on root config
    if command -v python3 &> /dev/null; then
        if ! python3 -c "import yaml; yaml.safe_load(open('conf.yml'))" 2>/dev/null; then
            print_error "Invalid YAML syntax in conf.yml"
            exit 1
        fi
        print_success "Root configuration file syntax is valid"
    else
        print_warning "Python3 not available for YAML validation"
    fi
}

# Validate runtime configuration file
validate_runtime_config() {
    print_status "Validating runtime configuration..."
    
    if [[ ! -f "user-data/conf.yml" ]]; then
        print_error "Runtime configuration file user-data/conf.yml not found"
        print_status "Run 'sync' command to copy from root configuration"
        exit 1
    fi
    
    # Basic YAML syntax check on runtime config
    if command -v python3 &> /dev/null; then
        if ! python3 -c "import yaml; yaml.safe_load(open('user-data/conf.yml'))" 2>/dev/null; then
            print_error "Invalid YAML syntax in user-data/conf.yml"
            exit 1
        fi
        print_success "Runtime configuration file syntax is valid"
    else
        print_warning "Python3 not available for YAML validation"
    fi
}

# Compare configurations
compare_configs() {
    if [[ ! -f "conf.yml" ]]; then
        print_error "Root configuration file not found"
        return 1
    fi
    
    if [[ ! -f "user-data/conf.yml" ]]; then
        print_warning "Runtime configuration file not found"
        return 1
    fi
    
    if cmp -s "conf.yml" "user-data/conf.yml" 2>/dev/null; then
        return 0  # Files are identical
    else
        return 1  # Files differ
    fi
}

# Copy configuration from root to user-data
sync_config() {
    print_status "Syncing configuration from root to user-data..."
    
    # Validate root config first
    validate_root_config
    
    # Backup existing user-data config if it exists
    if [[ -f "user-data/conf.yml" ]]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "user-data/conf.yml" "user-data/conf.yml.backup.$timestamp"
        print_status "Backed up existing configuration to conf.yml.backup.$timestamp"
    fi
    
    # Ensure user-data directory exists
    mkdir -p user-data
    
    # Copy configuration
    cp "conf.yml" "user-data/conf.yml"
    print_success "Configuration synced successfully"
    
    # Check if service is running and restart if needed
    if docker compose ps --format json | jq -r '.[] | select(.Name == "'$CONTAINER_NAME'") | .State' 2>/dev/null | grep -q "running"; then
        print_status "Restarting service to apply new configuration..."
        docker compose restart "$CONTAINER_NAME"
        
        # Wait for service to be healthy
        local port=$DEFAULT_PORT
        if [[ -f ".env" ]]; then
            source .env
            port=${DASHY_PORT:-$DEFAULT_PORT}
        fi
        
        if wait_for_service "$port"; then
            print_success "Configuration applied and service restarted successfully"
        else
            print_error "Service failed to restart properly"
            exit 1
        fi
    else
        print_status "Service is not running. Configuration will be applied on next start."
    fi
}

# Wait for service to be healthy
wait_for_service() {
    local max_attempts=30
    local attempt=1
    local port=${1:-$DEFAULT_PORT}
    
    print_status "Waiting for $SERVICE_NAME to start (max ${max_attempts}s)..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker compose ps --format json | jq -r '.[] | select(.Name == "'$CONTAINER_NAME'") | .Health' 2>/dev/null | grep -q "healthy"; then
            print_success "$SERVICE_NAME is healthy!"
            return 0
        elif curl -sf "http://localhost:$port" &>/dev/null; then
            print_success "$SERVICE_NAME is responding!"
            return 0
        fi
        
        sleep 1
        ((attempt++))
    done
    
    print_error "$SERVICE_NAME failed to start properly"
    return 1
}

# Check configuration differences
check_diff() {
    print_status "Checking configuration differences..."
    
    if [[ ! -f "conf.yml" ]]; then
        print_error "Root configuration file not found"
        exit 1
    fi
    
    if [[ ! -f "user-data/conf.yml" ]]; then
        print_warning "Runtime configuration file not found"
        print_status "Runtime config needs to be created from root config"
        return
    fi
    
    if compare_configs; then
        print_success "Configurations are synchronized"
    else
        print_warning "Configurations differ - sync needed"
        echo
        print_status "To see detailed differences:"
        echo -e "  ${YELLOW}diff conf.yml user-data/conf.yml${NC}"
        echo
        print_status "To apply changes:"
        echo -e "  ${YELLOW}./config.sh sync${NC}"
    fi
}

# Validate all configurations
validate_all() {
    print_status "Validating all configurations..."
    
    # Validate root config
    validate_root_config
    
    # Validate runtime config if it exists
    if [[ -f "user-data/conf.yml" ]]; then
        validate_runtime_config
    else
        print_warning "Runtime configuration not found - needs sync"
    fi
    
    # Check if configurations are in sync
    check_diff
    
    print_success "Configuration validation complete"
}

# Show configuration status
show_config_status() {
    echo -e "${BLUE}=== Configuration Status ===${NC}"
    echo
    
    # Root config status
    if [[ -f "conf.yml" ]]; then
        local root_size=$(du -h "conf.yml" | cut -f1)
        local root_modified=$(stat -c %y "conf.yml" 2>/dev/null | cut -d' ' -f1,2 | cut -c1-16)
        echo -e "${GREEN}Root Config:${NC} conf.yml (${root_size}, modified: ${root_modified})"
    else
        echo -e "${RED}Root Config:${NC} conf.yml (missing)"
    fi
    
    # Runtime config status
    if [[ -f "user-data/conf.yml" ]]; then
        local runtime_size=$(du -h "user-data/conf.yml" | cut -f1)
        local runtime_modified=$(stat -c %y "user-data/conf.yml" 2>/dev/null | cut -d' ' -f1,2 | cut -c1-16)
        echo -e "${GREEN}Runtime Config:${NC} user-data/conf.yml (${runtime_size}, modified: ${runtime_modified})"
    else
        echo -e "${RED}Runtime Config:${NC} user-data/conf.yml (missing)"
    fi
    
    echo
    
    # Sync status
    if compare_configs &>/dev/null; then
        echo -e "${GREEN}Sync Status:${NC} Configurations are synchronized ✓"
    else
        echo -e "${YELLOW}Sync Status:${NC} Configurations differ - sync needed ⚠"
    fi
    
    # Service status
    if docker compose ps --format json | jq -r '.[] | select(.Name == "'$CONTAINER_NAME'") | .State' 2>/dev/null | grep -q "running"; then
        echo -e "${GREEN}Service Status:${NC} Running ✓"
    else
        echo -e "${RED}Service Status:${NC} Stopped ✗"
    fi
    
    echo
}

# Edit configuration with validation
edit_config() {
    local editor=${EDITOR:-nano}
    
    print_status "Opening configuration file with $editor..."
    
    # Backup current config
    if [[ -f "conf.yml" ]]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "conf.yml" "conf.yml.backup.$timestamp"
        print_status "Created backup: conf.yml.backup.$timestamp"
    fi
    
    # Open editor
    $editor "conf.yml"
    
    # Validate after editing
    print_status "Validating edited configuration..."
    if validate_root_config &>/dev/null; then
        print_success "Configuration is valid"
        
        # Ask if user wants to sync
        echo
        read -p "Apply changes to running service? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sync_config
        else
            print_status "Changes saved but not applied. Run 'sync' to apply later."
        fi
    else
        print_error "Configuration has syntax errors!"
        read -p "Edit again? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            edit_config
        fi
    fi
}

# Reset configuration to default
reset_config() {
    print_warning "This will reset configuration to default template!"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Reset cancelled"
        return
    fi
    
    # Backup current configs
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    [[ -f "conf.yml" ]] && cp "conf.yml" "conf.yml.reset-backup.$timestamp"
    [[ -f "user-data/conf.yml" ]] && cp "user-data/conf.yml" "user-data/conf.yml.reset-backup.$timestamp"
    
    # Create basic template
    cat > "conf.yml" << 'EOF'
---
# Dashy Dashboard Configuration
# This is the MAIN configuration file - edit this file to make changes
# After editing, run: ./config.sh sync to apply changes to the running service

pageInfo:
  title: 'My Dashboard'
  description: 'Personal dashboard for homelab services'

appConfig:
  theme: colorful
  layout: auto
  iconSize: medium
  statusCheck: true
  statusCheckInterval: 300

sections:
  - name: Getting Started
    items:
      - title: Edit Configuration
        description: Customize this dashboard
        icon: fas fa-edit
        url: #
        statusCheck: false
EOF
    
    print_success "Configuration reset to default template"
    print_status "Edit conf.yml to customize your dashboard"
    print_status "Run 'sync' to apply changes to the service"
}

# Usage information
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Configuration Management Commands:"
    echo "  validate           Validate configuration files"
    echo "  sync               Sync root config to runtime (applies changes)"
    echo "  status             Show configuration and service status"
    echo "  diff               Check differences between configurations"
    echo "  edit               Edit configuration with validation"
    echo "  reset              Reset configuration to default template"
    echo "  help               Show this help message"
    echo
    echo "Configuration Files:"
    echo "  ./conf.yml         Main configuration (edit this)"
    echo "  ./user-data/conf.yml  Runtime configuration (auto-managed)"
    echo
    echo "Workflow:"
    echo "  1. Edit ./conf.yml with your changes"
    echo "  2. Run './config.sh validate' to check syntax"
    echo "  3. Run './config.sh sync' to apply changes"
    echo "  4. Run './config.sh status' to verify"
    echo
    echo "Examples:"
    echo "  $0 edit               # Edit configuration with built-in validation"
    echo "  $0 validate           # Check configuration syntax"
    echo "  $0 sync               # Apply changes to running service"
    echo "  $0 status             # Show configuration status"
    echo "  $0 diff               # Check if sync is needed"
}

# Main script logic
main() {
    case "${1:-status}" in
        "validate")
            validate_all
            ;;
        "sync")
            sync_config
            ;;
        "status")
            show_config_status
            ;;
        "diff")
            check_diff
            ;;
        "edit")
            edit_config
            ;;
        "reset")
            reset_config
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"