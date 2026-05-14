# Start from official Node.js image (already has Debian base)
FROM node:25-bookworm-slim

# Use bash with pipefail for all RUN commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Switch to root for installations
USER root

# Install system tools FIRST — python3 + build-essential are required by node-gyp
# (used by n8n's native addon 'isolated-vm') before npm install -g n8n runs.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Build tools (required for node-gyp / isolated-vm native addon)
        python3 \
        python3-pip \
        python3-venv \
        build-essential \
        # Basic utilities
        ca-certificates \
        curl \
        wget \
        git \
        vim \
        nano \
        bash \
        zsh \
        gnupg \
        # Archive tools
        unzip \
        zip \
        tar \
        gzip \
        bzip2 \
        xz-utils \
        p7zip-full \
        # JSON/YAML processors
        jq \
        # Network tools
        openssh-client \
        rsync \
        netcat-openbsd \
        dnsutils \
        iputils-ping \
        # System utilities
        htop \
        procps \
        less \
        man-db \
        sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install n8n globally (after python3 + build-essential are available for node-gyp)
RUN npm install -g n8n

# Install Docker CLI (needed to communicate with Docker socket)
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install yq (YAML processor) — wget is used here intentionally (smaller than curl for single file)
# hadolint ignore=DL4001
RUN ARCH=$(dpkg --print-architecture) && \
    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" && \
    chmod +x /usr/local/bin/yq

# Install AWS CLI
# uname -m gives aarch64/x86_64 which matches AWS CLI download naming exactly
RUN ARCH=$(uname -m) && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install kubectl
RUN ARCH=$(dpkg --print-architecture) && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install Terraform
RUN ARCH=$(dpkg --print-architecture) && \
    TERRAFORM_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version) && \
    curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
    unzip "terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
    mv terraform /usr/local/bin/ && \
    rm "terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip"

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install rclone
RUN ARCH=$(dpkg --print-architecture) && \
    curl -O "https://downloads.rclone.org/rclone-current-linux-${ARCH}.zip" && \
    unzip "rclone-current-linux-${ARCH}.zip" && \
    cp rclone-*-linux-${ARCH}/rclone /usr/local/bin/ && \
    chmod +x /usr/local/bin/rclone && \
    rm -rf rclone-*

# Create directories for host binary mounts
RUN mkdir -p /host-bin /host-usr-bin /host-usr-local-bin

# Add host binary directories to PATH
# Docker will be accessed via /host-bin/docker (from host)
ENV PATH="/host-bin:/host-usr-bin:/host-usr-local-bin:${PATH}"

# Set up n8n environment
ENV N8N_USER_FOLDER="/home/node/.n8n"
ENV HOME="/home/node"

# --- n8n advanced node & community access ---
ENV NODE_FUNCTION_ALLOW_BUILTIN="*"
ENV NODE_FUNCTION_ALLOW_EXTERNAL="*"
ENV N8N_BLOCK_ENV_ACCESS_IN_NODE="false"
ENV N8N_COMMUNITY_PACKAGES_ENABLED="true"
ENV N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE="true"

# --- Telemetry / nags off ---
ENV N8N_DIAGNOSTICS_ENABLED="false"
ENV N8N_VERSION_NOTIFICATIONS_ENABLED="false"
ENV N8N_PERSONALIZATION_ENABLED="false"
ENV N8N_HIRING_BANNER_ENABLED="false"

# --- Hardening ---
ENV N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS="true"
ENV N8N_GIT_NODE_DISABLE_BARE_REPOS="true"

# --- Logging ---
ENV N8N_LOG_LEVEL="info"
ENV N8N_LOG_OUTPUT="console"

# --- Node.js ---
ENV NODE_OPTIONS="--max-old-space-size=768"

# Verify installations
RUN echo "=== Verifying installations ===" && \
    node --version && \
    npm --version && \
    n8n --version && \
    docker --version && \
    aws --version && \
    kubectl version --client && \
    terraform version && \
    helm version && \
    rclone version && \
    python3 --version && \
    jq --version && \
    echo "=== All tools installed successfully ==="

# Switch to node user
USER node

# Set working directory
WORKDIR /home/node

# Expose n8n port
EXPOSE 5678

# Start n8n
CMD ["n8n"]
