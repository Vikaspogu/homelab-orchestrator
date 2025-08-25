# HomeLab Orchestrator

A comprehensive infrastructure automation platform for managing homelab environments using Ansible, AWX, and OpenTofu. This repository provides end-to-end automation for virtualization platforms, container orchestration, and identity management.

## 🏗️ Architecture

This project orchestrates multiple components of a modern homelab:

- **Virtualization**: Proxmox VE and VMware vSphere management
- **Container Orchestration**: OpenShift cluster deployment and configuration
- **Identity Management**: Authentik SSO configuration via OpenTofu
- **Automation Platform**: AWX for job orchestration and workflow management
- **GitOps**: Automated cluster bootstrapping with ArgoCD

## 📁 Project Structure

```text
homelab-orchestrator/
├── ansible/                    # Ansible automation content
│   ├── awx/                   # AWX configuration
│   │   ├── job_templates/     # AWX job template definitions
│   │   ├── surveys/          # Interactive job surveys
│   │   └── workflows/        # Multi-job workflows
│   ├── inventory/            # Ansible inventory files
│   ├── playbooks/           # Ansible playbooks
│   │   ├── awx/            # AWX management playbooks
│   │   ├── openshift/      # OpenShift automation
│   │   ├── proxmox/        # Proxmox host preparation
│   │   ├── vms/            # VM-specific configurations
│   │   └── vmware/         # VMware automation
│   ├── roles/              # Ansible roles
│   │   ├── provision-vm/   # VM provisioning role
│   │   └── proxmox/        # Proxmox management role
│   └── templates/          # Jinja2 templates
└── terraform/              # OpenTofu/Terraform configurations
    └── authentik/          # Authentik SSO configuration
```

## 🚀 Features

### Virtualization Management

- **Proxmox VE Integration**

  - VM creation and management
  - Template creation from cloud images
  - ISO upload and mounting
  - Storage management

- **VMware vSphere Support**
  - VM provisioning with cloud-init
  - Template management
  - Resource allocation

### Container Platform

- **OpenShift Cluster Management**
  - Automated cluster preparation
  - GitOps bootstrap with ArgoCD
  - Multi-node cluster configuration

### Automation Platform

- **AWX Integration**
  - Pre-configured job templates
  - Interactive surveys for dynamic input
  - Workflow orchestration
  - Backup and configuration management

### Identity Management

- **Authentik SSO**
  - Application and provider configuration
  - Directory integration
  - Flow customization
  - Scope management

## 📋 Prerequisites

### Required Software

- Python 3.8+
- Ansible 4.0+
- OpenTofu or Terraform 1.0+
- Access to target infrastructure:
  - Proxmox VE cluster
  - VMware vCenter (optional)
  - OpenShift cluster or installation target

### Python Dependencies

```bash
pip install -r requirements.txt
```

### Ansible Collections

```bash
ansible-galaxy install -r requirements.yaml
```

## ⚙️ Configuration

### 1. Inventory Setup

Edit `ansible/inventory/hosts.yaml` to match your environment:

```yaml
all:
  children:
    proxmox:
      hosts:
        pve-node1:
          ansible_host: 192.168.1.100
    openshift:
      hosts:
        bootstrap:
          ansible_host: 192.168.1.110
```

### 2. Variables Configuration

Update `ansible/vars/common.vault.yaml` with your environment-specific values:

- API credentials
- Network configurations
- Storage paths
- Domain settings

### 3. Vault Encryption

Encrypt sensitive variables:

```bash
ansible-vault encrypt ansible/vars/common.vault.yaml
```

## 🎯 Usage

### VM Provisioning

```bash
# Provision a new VM on Proxmox
ansible-playbook ansible/playbooks/proxmox/prepare_host.yaml -i ansible/inventory/hosts.yaml

# Provision VM on VMware
ansible-playbook ansible/playbooks/vmware/provision-vm.yaml -i ansible/inventory/hosts.yaml
```

### OpenShift Management

```bash
# Prepare OpenShift cluster nodes
ansible-playbook ansible/playbooks/openshift/cluster-prep.yaml -i ansible/inventory/hosts.yaml

# Bootstrap GitOps
ansible-playbook ansible/playbooks/openshift/gitops-bootstrap.yaml -i ansible/inventory/hosts.yaml
```

### AWX Setup

```bash
# Deploy and configure AWX
ansible-playbook ansible/playbooks/awx/create.yaml -i ansible/inventory/hosts.yaml

# Configure AWX with job templates
ansible-playbook ansible/playbooks/awx/config.yaml -i ansible/inventory/hosts.yaml
```

### Authentik Configuration

```bash
cd terraform/authentik
terraform init
terraform plan
terraform apply
```

## 🔧 AWX Integration

This project includes comprehensive AWX integration with:

### Job Templates

- **VM Management**: Create, delete, start VMs
- **OpenShift Operations**: Cluster preparation, GitOps bootstrap
- **Utility Operations**: ISO management, disk operations

### Interactive Surveys

Pre-configured surveys for dynamic job execution:

- VM specifications (CPU, memory, disk)
- Network configuration
- Cluster parameters

### Workflows

Multi-step automation workflows:

- Complete OpenShift cluster deployment
- End-to-end VM provisioning pipeline

## 📚 Available Playbooks

### Infrastructure Management

- `ansible/playbooks/proxmox/prepare_host.yaml` - Proxmox host configuration
- `ansible/playbooks/misc/shutdown.yaml` - Controlled infrastructure shutdown

### VM Operations

- `ansible/playbooks/vms/docker.yaml` - Docker host setup
- `ansible/playbooks/vms/omv.yaml` - OpenMediaVault configuration

### Container Operations

- `ansible/playbooks/openshift/cluster-prep.yaml` - Node preparation
- `ansible/playbooks/openshift/gitops-bootstrap.yaml` - ArgoCD setup

### AWX Management

- `ansible/playbooks/awx/create.yaml` - AWX deployment
- `ansible/playbooks/awx/config.yaml` - AWX configuration
- `ansible/playbooks/awx/backup.yaml` - AWX backup

## 🛡️ Security Considerations

- All sensitive data is encrypted using Ansible Vault
- SSH key-based authentication for all connections
- Role-based access control in AWX
- Secure credential management

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly in your environment
5. Submit a pull request

## 📄 License

This project is licensed under the terms specified in the LICENSE file.

## 🔍 Troubleshooting

### Common Issues

- **Connection failures**: Verify SSH connectivity and credentials
- **Permission errors**: Check Ansible user privileges on target hosts
- **AWX job failures**: Review job logs and survey parameters

### Support

For issues and questions, please check the documentation in individual role README files or open an issue in this repository.
