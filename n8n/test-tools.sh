#!/bin/bash

# Test script to verify all tools are accessible in n8n container
# Run this after starting the container with: ./test-tools.sh

set -e

CONTAINER_NAME="n8n"

echo "=== Testing Tool Accessibility in n8n Container ==="
echo ""

# Check if container is running
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo "❌ Error: n8n container is not running"
    echo "Start it with: docker-compose up -d"
    exit 1
fi

echo "✓ Container is running"
echo ""

# Function to test a command
test_command() {
    local cmd=$1
    local description=$2
    
    echo -n "Testing $description... "
    if docker exec $CONTAINER_NAME bash -c "command -v $cmd > /dev/null 2>&1"; then
        local version=$(docker exec $CONTAINER_NAME bash -c "$cmd --version 2>&1 | head -1" || echo "installed")
        echo "✓ $version"
        return 0
    else
        echo "❌ Not found"
        return 1
    fi
}

# Test container-installed tools
echo "=== Tools Installed in Container ==="
test_command "docker" "Docker CLI"
test_command "docker-compose" "Docker Compose"
test_command "aws" "AWS CLI"
test_command "az" "Azure CLI"
test_command "kubectl" "kubectl"
test_command "terraform" "Terraform"
test_command "helm" "Helm"
test_command "rclone" "rclone"
test_command "python3" "Python 3"
test_command "pip3" "pip"
test_command "git" "Git"
test_command "curl" "curl"
test_command "wget" "wget"
test_command "jq" "jq"
test_command "yq" "yq"
test_command "ssh" "SSH client"
test_command "rsync" "rsync"

echo ""
echo "=== Testing Docker Socket Access ==="
echo -n "Checking Docker socket... "
if docker exec $CONTAINER_NAME docker ps > /dev/null 2>&1; then
    echo "✓ Can access host Docker"
    echo "Running containers visible from n8n:"
    docker exec $CONTAINER_NAME docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
else
    echo "❌ Cannot access Docker socket"
    echo "Check group_add configuration in docker-compose.yml"
fi

echo ""
echo "=== Testing Host Binary Access ==="
echo -n "Checking host binaries... "
host_bin_count=$(docker exec $CONTAINER_NAME ls /host-bin 2>/dev/null | wc -l)
host_usr_bin_count=$(docker exec $CONTAINER_NAME ls /host-usr-bin 2>/dev/null | wc -l)
host_usr_local_bin_count=$(docker exec $CONTAINER_NAME ls /host-usr-local-bin 2>/dev/null | wc -l)

echo "✓"
echo "  /host-bin: $host_bin_count binaries"
echo "  /host-usr-bin: $host_usr_bin_count binaries"
echo "  /host-usr-local-bin: $host_usr_local_bin_count binaries"

echo ""
echo "=== Testing Configuration Access ==="
for config_dir in .ssh .kube .aws .config; do
    echo -n "Checking ~/$config_dir... "
    if docker exec $CONTAINER_NAME test -d "/home/node/$config_dir" 2>/dev/null; then
        file_count=$(docker exec $CONTAINER_NAME find "/home/node/$config_dir" -type f 2>/dev/null | wc -l)
        echo "✓ ($file_count files)"
    else
        echo "⚠ Not mounted (this is OK if you don't use it)"
    fi
done

echo ""
echo "=== Testing Cloud CLI Tools ==="

# Test AWS CLI
echo -n "AWS CLI configuration... "
if docker exec $CONTAINER_NAME test -f "/home/node/.aws/credentials" 2>/dev/null; then
    echo "✓ Credentials file found"
    if docker exec $CONTAINER_NAME aws sts get-caller-identity > /dev/null 2>&1; then
        echo "  ✓ AWS credentials are valid"
    else
        echo "  ⚠ Credentials file exists but may not be configured"
    fi
else
    echo "⚠ No credentials file (configure via environment or n8n credentials)"
fi

# Test kubectl
echo -n "kubectl configuration... "
if docker exec $CONTAINER_NAME test -f "/home/node/.kube/config" 2>/dev/null; then
    echo "✓ Config file found"
    if docker exec $CONTAINER_NAME kubectl cluster-info > /dev/null 2>&1; then
        echo "  ✓ Can connect to cluster"
    else
        echo "  ⚠ Config exists but cluster may not be reachable"
    fi
else
    echo "⚠ No config file"
fi

echo ""
echo "=== PATH Configuration ==="
echo "Current PATH in container:"
docker exec $CONTAINER_NAME bash -c 'echo $PATH' | tr ':' '\n' | while read -r path; do
    echo "  - $path"
done

echo ""
echo "=== Sample Commands You Can Run in n8n ==="
echo ""
echo "Docker commands:"
echo "  docker ps"
echo "  docker images"
echo "  docker run hello-world"
echo ""
echo "AWS commands:"
echo "  aws s3 ls"
echo "  aws ec2 describe-instances"
echo ""
echo "Kubernetes commands:"
echo "  kubectl get pods"
echo "  kubectl get nodes"
echo ""
echo "File operations:"
echo "  curl -O https://example.com/file.txt"
echo "  rclone copy /data remote:bucket"
echo ""
echo "=== Test Complete ==="
echo ""
echo "Access n8n at: http://localhost:5678"
