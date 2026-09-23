# Stay on node 24. n8n 2.38.x pulls @confluentinc/kafka-javascript, which has
# prebuilt binaries only up to ABI 137 (node 24); on node 26 npm compiles
# librdkafka from source for ~12min per arch and then fails anyway. n8n itself
# only requires node >=24. Renovate is capped at <25 for this file, so nothing
# will bump this by itself - when you do, check that package's release assets
# for a node-v147 tarball first.
FROM node:24.21.0-bookworm-slim

# Pinned so the image is reproducible and Renovate can track it. Must be
# declared after FROM to be visible in this stage. The published image is
# tagged with this exact value — see .github/workflows/build-n8n-image.yml.
# renovate: datasource=npm depName=n8n
ARG N8N_VERSION=2.40.5

# Tool versions. These were previously resolved as "latest" at build time, which
# made the image unreproducible and silently installed kubectl v1.37 against a
# v1.34 cluster — three minors past the supported +/-1 skew. Renovate tracks each
# of these now, so an upgrade is a reviewable PR rather than a surprise.
#
# KUBECTL must stay within one minor of the cluster: see k3s_version in
# ansible/inventory.yml. Renovate will offer newer ones — do not take them ahead
# of the cluster.
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=v1.37.0
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=v4.3.0
# renovate: datasource=github-releases depName=hashicorp/terraform extractVersion=^v?(?<version>.+)$
ARG TERRAFORM_VERSION=1.16.3
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.53.6
# NOT named RCLONE_VERSION: rclone reads every RCLONE_* env var as one of its
# own flags, and docker exposes build ARGs to RUN as env vars — so that name
# became `--version=v1.75.1` and rclone died parsing it as a boolean. Do not
# "tidy" this back into the naming pattern the other tools use.
# renovate: datasource=github-releases depName=rclone/rclone
ARG VERSION_RCLONE=v1.75.1
# aws/aws-cli publishes tags but no GitHub releases, hence github-tags.
# renovate: datasource=github-tags depName=aws/aws-cli extractVersion=^v?(?<version>.+)$
ARG AWSCLI_VERSION=2.37.0

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

# Install n8n globally (after python3 + build-essential are available for node-gyp).
# Pinned: an unpinned `npm install -g n8n` once resolved to a 2.20.7-exp.0
# prerelease, which then ran in production unnoticed.
#
# No engines guard here on purpose: n8n declares `>=22.16`, a minimum, which a
# too-NEW Node still satisfies — so it would not have caught node 26 breaking
# isolated-vm. The FROM comment above is the real control.
RUN npm install -g "n8n@${N8N_VERSION}"

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
    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" && \
    chmod +x /usr/local/bin/yq

# Install AWS CLI
# uname -m gives aarch64/x86_64 which matches AWS CLI download naming exactly
RUN ARCH=$(uname -m) && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}-${AWSCLI_VERSION}.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install kubectl
RUN ARCH=$(dpkg --print-architecture) && \
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install Terraform
RUN ARCH=$(dpkg --print-architecture) && \
    curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
    unzip "terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
    mv terraform /usr/local/bin/ && \
    rm "terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip"

# Install Helm — the get-helm-3 script always fetches latest, so pull the
# pinned tarball directly instead.
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
      | tar -xz -C /tmp && \
    mv "/tmp/linux-${ARCH}/helm" /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm && \
    rm -rf "/tmp/linux-${ARCH}"

# Install rclone
RUN ARCH=$(dpkg --print-architecture) && \
    curl -O "https://downloads.rclone.org/${VERSION_RCLONE}/rclone-${VERSION_RCLONE}-linux-${ARCH}.zip" && \
    unzip "rclone-${VERSION_RCLONE}-linux-${ARCH}.zip" && \
    cp "rclone-${VERSION_RCLONE}-linux-${ARCH}/rclone" /usr/local/bin/ && \
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
