#!/bin/bash

# GitLab Management Script
# Common operations for GitLab administration

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ Error: .env file not found"
    exit 1
fi

HOST_IP=$(hostname -I | awk '{print $1}' || echo $GITLAB_DOMAIN)

show_help() {
    echo "🦊 GitLab Management Script"
    echo "==========================="
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status     - Show GitLab status and health"
    echo "  logs       - Show GitLab logs (real-time)"
    echo "  backup     - Create a backup"
    echo "  restore    - List and restore backups"
    echo "  restart    - Restart GitLab"
    echo "  stop       - Stop GitLab"
    echo "  start      - Start GitLab"
    echo "  update     - Update GitLab to latest version"
    echo "  console    - Open GitLab Rails console"
    echo "  shell      - Open shell in GitLab container"
    echo "  reset-root - Reset root password"
    echo "  help       - Show this help"
    echo ""
}

check_status() {
    echo "🔍 GitLab Status Check"
    echo "====================="
    echo ""
    
    # Container status
    echo "📦 Container Status:"
    docker compose ps
    echo ""
    
    # Health check
    echo "🏥 Health Status:"
    health_code=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${GITLAB_PORT}/health 2>/dev/null || echo "000")
    case $health_code in
        "200"|"302") echo "   ✅ Healthy" ;;
        "503") echo "   🔄 Starting up" ;;
        *) echo "   ❌ Unhealthy (HTTP: $health_code)" ;;
    esac
    
    # Web interface
    echo "🌐 Web Interface:"
    web_code=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST_IP:${GITLAB_PORT} 2>/dev/null || echo "000")
    case $web_code in
        "200"|"302") echo "   ✅ Accessible at http://$HOST_IP:${GITLAB_PORT}" ;;
        "502") echo "   🔄 Still initializing (502 - this is normal during startup)" ;;
        *) echo "   ❌ Not accessible (HTTP: $web_code)" ;;
    esac
    
    # Resource usage
    echo "📊 Resource Usage:"
    docker stats gitlab-server --no-stream --format "   CPU: {{.CPUPerc}} | RAM: {{.MemUsage}} | NET: {{.NetIO}}"
}

create_backup() {
    echo "💾 Creating GitLab Backup"
    echo "========================="
    echo ""
    
    echo "🔄 Starting backup process..."
    docker compose exec gitlab gitlab-backup create
    
    echo ""
    echo "✅ Backup completed!"
    echo "📁 Backups are stored in: ./backups/"
    
    echo ""
    echo "📋 Available backups:"
    docker compose exec gitlab ls -la /var/opt/gitlab/backups/
}

restore_backup() {
    echo "🔄 GitLab Backup Restore"
    echo "======================="
    echo ""
    
    echo "📋 Available backups:"
    docker compose exec gitlab ls -la /var/opt/gitlab/backups/
    
    echo ""
    read -p "Enter backup timestamp (format: YYYYMMDD_HHmmss): " backup_timestamp
    
    if [ -z "$backup_timestamp" ]; then
        echo "❌ No backup timestamp provided"
        exit 1
    fi
    
    echo ""
    echo "⚠️  WARNING: This will restore GitLab from backup."
    echo "   All current data will be replaced!"
    echo ""
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "❌ Restore cancelled"
        exit 1
    fi
    
    echo ""
    echo "🔄 Stopping GitLab services..."
    docker compose exec gitlab gitlab-ctl stop unicorn
    docker compose exec gitlab gitlab-ctl stop puma
    docker compose exec gitlab gitlab-ctl stop sidekiq
    
    echo "🔄 Restoring backup..."
    docker compose exec gitlab gitlab-backup restore BACKUP=$backup_timestamp
    
    echo "🔄 Restarting GitLab..."
    docker compose restart
    
    echo "✅ Restore completed!"
}

update_gitlab() {
    echo "🔄 GitLab Update"
    echo "==============="
    echo ""
    
    echo "⚠️  WARNING: Always backup before updating!"
    read -p "Have you created a recent backup? (yes/no): " backup_confirm
    
    if [ "$backup_confirm" != "yes" ]; then
        echo "❌ Please create a backup first: $0 backup"
        exit 1
    fi
    
    echo ""
    echo "🔄 Pulling latest GitLab image..."
    docker compose pull
    
    echo "🔄 Updating GitLab..."
    docker compose up -d
    
    echo "✅ Update completed!"
    echo "⏳ GitLab may take a few minutes to reconfigure after update"
}

reset_root_password() {
    echo "🔑 Reset Root Password"
    echo "====================="
    echo ""
    
    read -s -p "Enter new root password: " new_password
    echo ""
    read -s -p "Confirm new password: " confirm_password
    echo ""
    
    if [ "$new_password" != "$confirm_password" ]; then
        echo "❌ Passwords don't match"
        exit 1
    fi
    
    echo "🔄 Resetting root password..."
    docker compose exec gitlab gitlab-rails runner "user = User.where(id: 1).first; user.password = '$new_password'; user.password_confirmation = '$new_password'; user.save!"
    
    echo "✅ Root password reset successfully!"
}

# Main script logic
case ${1:-help} in
    "status")
        check_status
        ;;
    "logs")
        echo "📜 GitLab Logs (Press Ctrl+C to exit)"
        echo "====================================="
        docker compose logs -f gitlab
        ;;
    "backup")
        create_backup
        ;;
    "restore")
        restore_backup
        ;;
    "restart")
        echo "🔄 Restarting GitLab..."
        docker compose restart
        echo "✅ GitLab restarted"
        ;;
    "stop")
        echo "🛑 Stopping GitLab..."
        docker compose down
        echo "✅ GitLab stopped"
        ;;
    "start")
        echo "🚀 Starting GitLab..."
        docker compose up -d
        echo "✅ GitLab started"
        ;;
    "update")
        update_gitlab
        ;;
    "console")
        echo "🔧 Opening GitLab Rails Console..."
        echo "   Type 'exit' to return"
        docker compose exec gitlab gitlab-rails console
        ;;
    "shell")
        echo "🐚 Opening GitLab Container Shell..."
        echo "   Type 'exit' to return"
        docker compose exec gitlab bash
        ;;
    "reset-root")
        reset_root_password
        ;;
    "help"|*)
        show_help
        ;;
esac