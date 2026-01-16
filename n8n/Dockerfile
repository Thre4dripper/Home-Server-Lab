# Start from official Node.js image (already has Debian base)
FROM node:20-bookworm-slim

# Switch to root for installations
USER root

# Install n8n globally
RUN npm install -g n8n

# Install all tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
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
        # Python and pip
        python3 \
        python3-pip \
        python3-venv \
        # System utilities
        htop \
        procps \
        less \
        man-db \
        sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Docker CLI (needed to communicate with Docker socket)
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install yq (YAML processor)
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64 && \
    chmod +x /usr/local/bin/yq

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install Terraform
RUN TERRAFORM_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version) && \
    curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_arm64.zip" && \
    unzip "terraform_${TERRAFORM_VERSION}_linux_arm64.zip" && \
    mv terraform /usr/local/bin/ && \
    rm "terraform_${TERRAFORM_VERSION}_linux_arm64.zip"

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install rclone
RUN curl -O https://downloads.rclone.org/rclone-current-linux-arm64.zip && \
    unzip rclone-current-linux-arm64.zip && \
    cp rclone-*-linux-arm64/rclone /usr/local/bin/ && \
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