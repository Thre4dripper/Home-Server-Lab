#!/bin/bash

set -e

echo "🏠 Pi-hole Local DNS Setup"
echo "=========================="

# Auto-detect network configuration
PI_IP=$(hostname -I | awk '{print $1}')
ROUTER_IP=$(ip route | grep default | awk '{print $3}' | head -1)
NETWORK_BASE=$(echo $PI_IP | cut -d. -f1-3)
NETWORK_CIDR="${NETWORK_BASE}.0/24"

echo "📍 Configuration: $PI_IP | Router: $ROUTER_IP | Network: $NETWORK_CIDR"

# Update .env file
sed -i "s/PIHOLE_IP=.*/PIHOLE_IP=$PI_IP/" .env
sed -i "s/ROUTER_IP=.*/ROUTER_IP=$ROUTER_IP/" .env
sed -i "s|NETWORK_CIDR=.*|NETWORK_CIDR=$NETWORK_CIDR|" .env

echo "✅ Configuration updated"

# Create data directories
mkdir -p pihole-data dnsmasq-data

# Start Pi-hole
echo "🚀 Starting Pi-hole..."
sudo docker compose up -d

# Wait for Pi-hole to start
echo "⏳ Waiting 30 seconds for Pi-hole to start..."
sleep 30

# Configure local DNS entries from existing custom.list
echo "🌐 Adding local DNS entries..."

# Read domains from existing custom.list if it exists
if [ -f "./pihole-data/hosts/custom.list" ]; then
    echo "📋 Using domains from existing custom.list..."
    DOMAINS=$(grep -E "^[0-9]+\." ./pihole-data/hosts/custom.list | awk '{print $2}' | tr '\n' ' ')
    LOCAL_DNS_ARRAY=""
    for domain in $DOMAINS; do
        if [ ! -z "$domain" ]; then
            LOCAL_DNS_ARRAY="$LOCAL_DNS_ARRAY\"$PI_IP $domain\", "
        fi
    done
    # Remove trailing comma and space
    LOCAL_DNS_ARRAY=$(echo "$LOCAL_DNS_ARRAY" | sed 's/, $//')
    LOCAL_DNS="[$LOCAL_DNS_ARRAY]"
else
    # Default domains if no custom.list exists
    LOCAL_DNS='["'$PI_IP' pihole.lan", "'$PI_IP' pihole.internal", "'$PI_IP' home.lan", "'$PI_IP' n8n.lan", "'$PI_IP' grafana.lan", "'$PI_IP' homeassistant.lan", "'$PI_IP' portainer.lan"]'
fi

sudo docker exec pihole sed -i "s|hosts = \[\]|hosts = $LOCAL_DNS|" /etc/pihole/pihole.toml

# Restart to apply changes
echo "🔄 Restarting Pi-hole..."
sudo docker compose restart
sleep 20

# Test setup
echo ""
echo "🧪 Testing..."
echo -n "External DNS: "
nslookup google.com $PI_IP > /dev/null 2>&1 && echo "✅" || echo "❌"
echo -n "Local DNS:    "
nslookup pihole.lan $PI_IP > /dev/null 2>&1 && echo "✅" || echo "❌"

echo ""
echo "🎉 Setup Complete!"
echo "Web Interface: http://$PI_IP/admin (Password: admin123)"
echo "Set device DNS to: $PI_IP"
