#!/bin/bash

# Plex Claim Token Helper Script
# This script helps you set up your Plex claim token

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}   Plex Claim Token Helper      ${NC}"
echo -e "${PURPLE}================================${NC}"
echo

echo -e "${BLUE}What is a Plex Claim Token?${NC}"
echo "A claim token links your Plex server to your Plex account automatically."
echo "Without it, you'll need to manually set up the server through the web interface."
echo

echo -e "${BLUE}How to get your claim token:${NC}"
printf "1. Open this URL in your browser: ${GREEN}https://www.plex.tv/claim${NC}\n"
echo "2. Sign in to your Plex account (or create one if needed)"
echo "3. Copy the claim token that appears (starts with 'claim-')"
echo

echo -e "${YELLOW}Please enter your claim token (or press Enter to skip):${NC}"
read -r CLAIM_TOKEN

if [ -n "$CLAIM_TOKEN" ]; then
    # Update the .env file
    if [ -f .env ]; then
        # Replace existing token or add new one
        if grep -q "PLEX_CLAIM_TOKEN=" .env; then
            sed -i "s/PLEX_CLAIM_TOKEN=.*/PLEX_CLAIM_TOKEN=$CLAIM_TOKEN/" .env
        else
            echo "PLEX_CLAIM_TOKEN=$CLAIM_TOKEN" >> .env
        fi
        echo -e "${GREEN}✓ Claim token added to .env file${NC}"
        
        # Restart Plex if it's running
        if docker ps -q -f name=plex > /dev/null 2>&1; then
            echo -e "${YELLOW}Restarting Plex to apply new claim token...${NC}"
            docker compose restart plex
            echo -e "${GREEN}✓ Plex restarted${NC}"
        fi
    else
        echo -e "${YELLOW}No .env file found. Run setup.sh first.${NC}"
    fi
else
    echo -e "${YELLOW}Skipping claim token setup.${NC}"
    printf "You can manually set up Plex by visiting: ${GREEN}http://localhost:32400/web${NC}\n"
fi

echo
echo -e "${BLUE}Next steps:${NC}"
printf "1. Access Plex at: ${GREEN}http://localhost:32400/web${NC}\n"
echo "2. Add your media libraries"
echo "3. Start enjoying your media!"
echo