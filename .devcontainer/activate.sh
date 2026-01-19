#!/bin/bash
# Activate CloudStack Ansible virtual environment
# Usage: source .devcontainer/activate.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}/.."
VENV_DIR="${WORKSPACE_DIR}/.venv"

if [ -d "${VENV_DIR}" ]; then
    source "${VENV_DIR}/bin/activate"
    echo "Activated virtual environment: ${VENV_DIR}"
    echo "Run 'deactivate' to exit"
else
    echo "Virtual environment not found. Run .devcontainer/setup.sh first."
fi
