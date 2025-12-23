# Homelab CloudStack Collection

Ansible collection for managing CloudStack infrastructure.

## Roles

| Role | Description |
|------|-------------|
| `homelab.cloudstack.api_auth` | Authenticate with CloudStack API |
| `homelab.cloudstack.cleanup` | Cleanup CloudStack resources |
| `homelab.cloudstack.cloudstack_ops` | CloudStack operations (zones, pods, clusters, storage) |
| `homelab.cloudstack.configure_kubernetes` | Configure Kubernetes for CloudStack |
| `homelab.cloudstack.instance` | Manage CloudStack instances |
| `homelab.cloudstack.kubernetes_cluster` | Manage Kubernetes clusters on CloudStack |
| `homelab.cloudstack.prepare_kvm` | Prepare KVM hosts for CloudStack |
| `homelab.cloudstack.prepare_management` | Prepare CloudStack management server |

## Installation

```bash
# From Galaxy (when published)
ansible-galaxy collection install homelab.cloudstack

# From local build
ansible-galaxy collection install homelab-cloudstack-1.0.0.tar.gz
```

## Usage

```yaml
---
- name: Deploy CloudStack infrastructure
  hosts: management
  roles:
    - homelab.cloudstack.prepare_management
    - homelab.cloudstack.cloudstack_ops
```

## Requirements

- Ansible >= 2.15
- Python >= 3.9

## License

MIT
