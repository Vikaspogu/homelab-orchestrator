# Homelab Orchestrator Development Container
FROM mcr.microsoft.com/devcontainers/python:1-3.11-bookworm

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    coreutils \
    git \
    curl \
    wget \
    vim \
    jq \
    sshpass \
    openssh-client \
    gnupg \
    software-properties-common \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install OpenTofu
RUN curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh \
    && chmod +x install-opentofu.sh \
    && ./install-opentofu.sh --install-method deb \
    && rm install-opentofu.sh

# Install terraform-docs
RUN curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.18.0/terraform-docs-v0.18.0-$(uname)-amd64.tar.gz \
    && tar -xzf terraform-docs.tar.gz \
    && chmod +x terraform-docs \
    && mv terraform-docs /usr/local/bin/ \
    && rm terraform-docs.tar.gz

# Install SOPS for secret management
RUN curl -sSLo /usr/local/bin/sops https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64 \
    && chmod +x /usr/local/bin/sops

# Set working directory
WORKDIR /workspace

# Copy requirements first for better caching
COPY requirements.txt requirements.yaml ./

# Install Python packages and Ansible
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir \
    ansible \
    ansible-lint \
    yamllint \
    && pip install --no-cache-dir -r requirements.txt

# Pre-install Ansible collections from requirements.yaml
RUN ansible-galaxy collection install \
    community.general \
    community.mysql \
    community.libvirt \
    community.sops \
    ansible.utils \
    ansible.posix \
    ngine_io.cloudstack \
    kubernetes.core

# Set environment variables
ENV ANSIBLE_HOST_KEY_CHECKING=False
ENV ANSIBLE_RETRY_FILES_ENABLED=False
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Ensure bash is the default shell
SHELL ["/bin/bash", "-c"]
