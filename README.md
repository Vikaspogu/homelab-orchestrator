# HomeLab Orchestrator

Infrastructure automation platform for managing homelab environments using Ansible and OpenTofu. This repository provides automation for CloudStack private cloud deployment, Proxmox virtualization, and identity management.

## Architecture

This project orchestrates multiple components of a modern homelab:

- **Private Cloud**: Apache CloudStack deployment with KVM hypervisors
- **Virtualization**: Proxmox VE management
- **Identity Management**: Authentik SSO configuration via OpenTofu
- **Kubernetes**: CloudStack Kubernetes Service (CKS) cluster management

## Project Structure

```
homelab-orchestrator/
├── ansible/
│   ├── collections/
│   │   └── ansible_collections/
│   │       └── homelab/
│   │           └── cloudstack/     # CloudStack automation collection
│   ├── inventory/
│   │   └── hosts.yaml              # Ansible inventory
│   ├── playbooks/
│   │   ├── cloudstack/             # CloudStack deployment playbooks
│   │   ├── proxmox/                # Proxmox host preparation
│   │   ├── misc/                   # Utility playbooks
│   │   └── vms/                    # VM-specific configurations
│   ├── roles/
│   │   └── proxmox/                # Proxmox management role
│   └── vars/
│       └── common.vault.yaml       # Encrypted variables
└── terraform/
    └── authentik/                  # Authentik SSO configuration
```

## Features

### CloudStack Private Cloud

- Management server deployment with MySQL
- KVM hypervisor preparation with libvirt
- Zone, pod, and cluster configuration
- Primary and secondary storage setup
- GPU passthrough with VFIO
- MergeFS storage pooling
- Kubernetes cluster deployment via CKS
- Proxmox Orchestrator Extension (CloudStack 4.19+)

### Proxmox Integration

Two integration options:

**Option 1: Standalone Proxmox**
- VM creation and management
- Template creation from cloud images
- ISO upload and mounting

**Option 2: CloudStack Proxmox Extension**
- Manage Proxmox VMs through CloudStack
- Unified API for hybrid environments
- Requires CloudStack 4.19+ with Orchestrator Extensions

### Identity Management

- Authentik SSO via OpenTofu
- Application and provider configuration
- Directory integration
- Flow customization

## Prerequisites

### Required Software

- Python 3.9+
- Ansible 2.15+
- OpenTofu or Terraform 1.0+

### Ansible Collections

```bash
ansible-galaxy collection install -r requirements.yaml
```

## Configuration

### 1. Inventory Setup

Edit `ansible/inventory/hosts.yaml`:

```yaml
all:
  children:
    cloudstack_management:
      hosts:
        mgmt01:
          ansible_host: 10.0.0.10
    cloudstack_kvm:
      hosts:
        kvm01:
          ansible_host: 10.0.0.11
        kvm02:
          ansible_host: 10.0.0.12
    proxmox:
      hosts:
        pve01:
          ansible_host: 10.0.0.5
```

### 2. Variables Configuration

Update `ansible/vars/common.vault.yaml` with:

- API credentials
- Network configurations
- Storage paths
- Domain settings

### 3. Vault Encryption

```bash
ansible-vault encrypt ansible/vars/common.vault.yaml
```

## Usage

### CloudStack Deployment

```bash
# Prepare management server
ansible-playbook ansible/playbooks/cloudstack/01-prepare-management.yaml

# Prepare KVM hypervisors
ansible-playbook ansible/playbooks/cloudstack/02-prepare-kvm.yaml

# Configure CloudStack infrastructure
ansible-playbook ansible/playbooks/cloudstack/03-configure.yaml

# Configure Kubernetes service
ansible-playbook ansible/playbooks/cloudstack/04-kubernetes-configure.yaml

# Deploy Kubernetes cluster
ansible-playbook ansible/playbooks/cloudstack/05-kubernetes-cluster.yaml
```

### Proxmox Management

```bash
ansible-playbook ansible/playbooks/proxmox/prepare_host.yaml
```

### Authentik Configuration

```bash
cd terraform/authentik
tofu init
tofu plan
tofu apply
```

## Available Playbooks

### CloudStack

| Playbook | Description |
|----------|-------------|
| `01-prepare-management.yaml` | Install CloudStack management server |
| `02-prepare-kvm.yaml` | Prepare KVM hypervisor hosts |
| `03-configure.yaml` | Configure zones, pods, clusters, storage |
| `04-kubernetes-configure.yaml` | Enable CKS and add Kubernetes versions |
| `05-kubernetes-cluster.yaml` | Deploy Kubernetes clusters |
| `99-cleanup.yaml` | Remove CloudStack components |

### Utility

| Playbook | Description |
|----------|-------------|
| `misc/shutdown.yaml` | Controlled infrastructure shutdown |
| `misc/update_passwords.yaml` | Update service passwords |

### Proxmox

| Playbook | Description |
|----------|-------------|
| `proxmox/prepare_host.yaml` | Proxmox host configuration |

## CloudStack Collection

See `ansible/collections/ansible_collections/homelab/cloudstack/README.md` for detailed documentation on:

- Role variables and defaults
- GPU passthrough configuration
- MergeFS storage setup
- Kubernetes cluster management
- Proxmox Orchestrator Extension

## Security

- Sensitive data encrypted with Ansible Vault
- SSH key-based authentication
- Secure credential management

## License

MIT
