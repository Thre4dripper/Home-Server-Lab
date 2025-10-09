#!/bin/bash

# Homarr Encryption Key Management Script
# This script helps manage Homarr's encryption key

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}   Homarr Key Management        ${NC}"
echo -e "${PURPLE}================================${NC}"
echo

echo -e "${BLUE}What is the encryption key?${NC}"
echo "Homarr uses a 64-character hex key to encrypt sensitive data like API keys."
echo "This key is critical - without it, your encrypted data cannot be decrypted."
echo

if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found. Run setup.sh first.${NC}"
    exit 1
fi

# Load current environment
source .env

echo -e "${BLUE}Current encryption key:${NC}"
echo "${SECRET_ENCRYPTION_KEY}"
echo

echo -e "${YELLOW}Choose an option:${NC}"
echo "1. Generate new encryption key (WARNING: Will make existing data unreadable)"
echo "2. Display current key for backup"
echo "3. Validate current key format"
echo "4. Exit"
echo

read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo -e "${RED}WARNING: Generating a new key will make ALL existing encrypted data unreadable!${NC}"
        echo "This includes API keys, passwords, and other sensitive configuration."
        echo
        read -p "Are you sure you want to continue? (yes/no): " confirm
        
        if [[ "$confirm" == "yes" ]]; then
            # Generate new encryption key
            NEW_KEY=$(openssl rand -hex 32)
            
            # Backup current .env
            cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
            
            # Update .env file
            sed -i "s/SECRET_ENCRYPTION_KEY=.*/SECRET_ENCRYPTION_KEY=$NEW_KEY/" .env
            
            echo -e "${GREEN}✓ New encryption key generated and saved${NC}"
            echo -e "${GREEN}✓ Previous .env backed up${NC}"
            echo
            echo -e "${BLUE}New key:${NC} $NEW_KEY"
            echo
            echo -e "${YELLOW}IMPORTANT:${NC}"
            echo "• Backup this key in a secure location"
            echo "• Restart Homarr: docker compose restart homarr"
            echo "• You'll need to reconfigure all service integrations"
        else
            echo "Operation cancelled."
        fi
        ;;
    2)
        echo -e "${BLUE}Current encryption key for backup:${NC}"
        echo
        echo "SECRET_ENCRYPTION_KEY=${SECRET_ENCRYPTION_KEY}"
        echo
        echo -e "${YELLOW}Save this key in a secure location!${NC}"
        echo "You'll need it if you ever migrate or restore your Homarr installation."
        ;;
    3)
        if [[ ${#SECRET_ENCRYPTION_KEY} -eq 64 ]] && [[ $SECRET_ENCRYPTION_KEY =~ ^[0-9a-fA-F]{64}$ ]]; then
            echo -e "${GREEN}✓ Encryption key format is valid${NC}"
            echo "  • Length: 64 characters"
            echo "  • Format: Hexadecimal"
        else
            echo -e "${RED}✗ Encryption key format is invalid${NC}"
            echo "  • Current length: ${#SECRET_ENCRYPTION_KEY} characters"
            echo "  • Required: 64 hexadecimal characters"
            echo
            echo "Run option 1 to generate a new valid key."
        fi
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Please select 1-4.${NC}"
        exit 1
        ;;
esac

echo
echo -e "${BLUE}Useful commands:${NC}"
echo "  Restart Homarr:    docker compose restart homarr"
echo "  View logs:         docker compose logs -f homarr"
echo "  Backup database:   cp -r homarr_data homarr_backup_\$(date +%Y%m%d)"
echo