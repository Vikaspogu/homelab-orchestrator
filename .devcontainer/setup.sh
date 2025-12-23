#!/bin/bash
# CloudStack Ansible Setup Script
# Creates virtual environment and installs all dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}/.."
VENV_DIR="${WORKSPACE_DIR}/.venv"

echo "=== CloudStack Ansible Setup ==="
echo ""

# Check Python version
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 is required but not installed."
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1)
echo "Using: ${PYTHON_VERSION}"

# Create virtual environment
# Use FORCE_RECREATE=1 to force recreation of existing venv
if [ -d "${VENV_DIR}" ]; then
    if [ "${FORCE_RECREATE:-0}" = "1" ]; then
        echo "Recreating virtual environment at ${VENV_DIR}..."
        rm -rf "${VENV_DIR}"
        python3 -m venv "${VENV_DIR}"
    else
        echo "Virtual environment already exists at ${VENV_DIR}, reusing it."
        echo "Set FORCE_RECREATE=1 to recreate it."
    fi
else
    echo "Creating virtual environment at ${VENV_DIR}..."
    python3 -m venv "${VENV_DIR}"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source "${VENV_DIR}/bin/activate"

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip --quiet

# Install Python requirements
echo "Installing Python requirements..."
pip install -r "${WORKSPACE_DIR}/requirements.txt" --quiet

# Install Ansible if not present
if ! command -v ansible &> /dev/null; then
    echo "Installing Ansible..."
    pip install ansible --quiet
fi

# Install Ansible collections
echo "Installing Ansible collections..."
ansible-galaxy collection install -r "${WORKSPACE_DIR}/requirements.yml" --force

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To activate the virtual environment, run:"
echo "  source ${VENV_DIR}/bin/activate"
echo ""
echo "Or use the helper script:"
echo "  source .devcontainer/activate.sh"
echo ""
echo "Then run playbooks:"
echo "  ansible-playbook playbooks/mgmt-host.yml"
echo "  ansible-playbook playbooks/kvm-hosts.yml"
echo "  ansible-playbook playbooks/cloudstack-setup.yml"

