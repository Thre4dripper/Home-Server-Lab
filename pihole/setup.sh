#!/bin/bash

set -e

echo "🏠 Pi-hole Local DNS Setup"
echo "=========================="
echo ""
echo "📝 DNS Configuration:"
echo "   • Edit 'dns-entries.conf' to customize local DNS entries"
echo "   • Format: domain=ip_address (one per line)"
echo "   • Comments start with # and are ignored"
echo "   • Example: n8n.lan=192.168.0.108"
echo ""

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

# Set password using Pi-hole's built-in command
echo "🔑 Setting admin password..."
sudo docker exec pihole pihole setpassword ${WEBPASSWORD:-admin123}

# Configure local DNS entries from dns-entries.conf
echo "🌐 Adding local DNS entries..."

# Read DNS entries from dns-entries.conf file
if [ -f "./dns-entries.conf" ]; then
    echo "📋 Using domains from dns-entries.conf..."
    LOCAL_DNS_ARRAY=""
    while IFS='=' read -r domain ip || [ -n "$domain" ]; do
        # Skip empty lines and comments
        if [[ -z "$domain" || "$domain" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        # Trim whitespace
        domain=$(echo "$domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        ip=$(echo "$ip" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ ! -z "$domain" ] && [ ! -z "$ip" ]; then
            LOCAL_DNS_ARRAY="$LOCAL_DNS_ARRAY\"$ip $domain\", "
        fi
    done < "./dns-entries.conf"
    
    # Remove trailing comma and space
    LOCAL_DNS_ARRAY=$(echo "$LOCAL_DNS_ARRAY" | sed 's/, $//')
    LOCAL_DNS="[$LOCAL_DNS_ARRAY]"
else
    # Fallback to default domains if dns-entries.conf doesn't exist
    echo "📋 dns-entries.conf not found, using default domains..."
    LOCAL_DNS='["'$PI_IP' pihole.lan", "'$PI_IP' pihole.internal", "'$PI_IP' home.lan", "'$PI_IP' n8n.lan", "'$PI_IP' grafana.lan", "'$PI_IP' homeassistant.lan", "'$PI_IP' portainer.lan"]'
fi

sudo docker exec pihole sed -i "s|hosts = \[\]|hosts = $LOCAL_DNS|" /etc/pihole/pihole.toml

# Restart to apply changes
echo "🔄 Restarting Pi-hole..."
sudo docker compose restart
sleep 20

# Test setup
echo ""
echo "🧪 Testing Pi-hole Configuration..."

# Test external DNS resolution
echo -n "External DNS (google.com): "
if dig @$PI_IP -p 5300 google.com +short > /dev/null 2>&1; then
    echo "✅ Working"
else
    echo "❌ Failed"
    echo "   Note: Pi-hole DNS is running on port 5300"
fi

# Test local DNS resolution
echo -n "Local DNS (pihole.lan):    "
if dig @$PI_IP -p 5300 pihole.lan +short | grep -q "$PI_IP"; then
    echo "✅ Working"
else
    echo "❌ Failed"
    echo "   Try: dig @$PI_IP -p 5300 pihole.lan"
fi

# Test web interface
echo -n "Web Interface:             "
if curl -s -o /dev/null -w "%{http_code}" http://$PI_IP:8080/admin/ | grep -q "200\|302"; then
    echo "✅ Accessible"
else
    echo "❌ Not accessible"
fi

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Configuration Details:"
echo "   • Web Interface: http://$PI_IP:8080/admin/"
echo "   • Admin Password: ${WEBPASSWORD:-admin123}"
echo "   • DNS Server: $PI_IP:5300"
echo ""
echo "📱 Next Steps:"
echo "   1. Set device DNS to: $PI_IP"
echo "   2. Test with: dig @$PI_IP -p 5300 google.com"
echo "   3. Edit 'dns-entries.conf' to add more local domains"
echo "   4. Re-run './setup.sh' to apply DNS changes"
echo ""
echo "⚠️  Note: Pi-hole DNS runs on port 5300 (not standard port 53)"
echo "   This avoids conflicts with system DNS on port 53"
