# Homelab CloudStack Collection

Ansible collection for deploying and managing Apache CloudStack infrastructure, including KVM hypervisors, management servers, and Kubernetes clusters.

## Requirements

- Ansible >= 2.15
- Python >= 3.9
- Target OS: Ubuntu 22.04/24.04 (Debian-based)

### Required Collections

```yaml
collections:
  - name: ngine_io.cloudstack
  - name: community.general
  - name: ansible.posix
```

## Installation

```bash
# Install dependencies
ansible-galaxy collection install ngine_io.cloudstack community.general ansible.posix

# Install from local path
ansible-galaxy collection install ./collections/ansible_collections/homelab/cloudstack
```

## Roles

| Role                   | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| `api_auth`             | Authenticate with CloudStack API, retrieve or generate API keys    |
| `prepare_management`   | Install and configure CloudStack management server with MySQL      |
| `prepare_kvm`          | Prepare KVM hypervisor hosts with libvirt, networking, and storage |
| `cloudstack_ops`       | Create zones, pods, clusters, storage pools, and add hosts         |
| `configure_kubernetes` | Enable CloudStack Kubernetes Service (CKS) and add versions        |
| `kubernetes_cluster`   | Deploy and manage Kubernetes clusters via CKS                      |
| `cleanup`              | Remove CloudStack components from hosts                            |

## Quick Start

### 1. Prepare Management Server

```yaml
- name: Deploy CloudStack Management
  hosts: management
  become: true
  vars:
    prepare_management_hostname: 'cloudstack-mgmt.local'
    prepare_management_db_password: 'secretpassword'
  roles:
    - homelab.cloudstack.prepare_management
```

### 2. Prepare KVM Hosts

```yaml
- name: Prepare KVM Hypervisors
  hosts: kvm_hosts
  become: true
  vars:
    prepare_kvm_hostname: '{{ inventory_hostname }}'
    prepare_kvm_mgmt_bridge: 'cloudbr0'
    prepare_kvm_guest_bridge: 'cloudbr0'
  roles:
    - homelab.cloudstack.prepare_kvm
```

### 3. Configure CloudStack Infrastructure

```yaml
- name: Configure CloudStack
  hosts: management
  vars:
    cloudstack_api_url: 'http://management:8080/client/api'
    cloudstack_admin_username: 'admin'
    cloudstack_admin_password: 'password'
    cloudstack_ops_zone:
      name: 'Zone1'
      network_type: 'Basic'
      dns1: '8.8.8.8'
      internal_dns1: '10.0.0.1'
    cloudstack_ops_pods:
      - name: 'Pod1'
        gateway: '10.0.0.1'
        netmask: '255.255.255.0'
        start_ip: '10.0.0.100'
        end_ip: '10.0.0.200'
    cloudstack_ops_clusters:
      - name: 'Cluster1'
        pod_name: 'Pod1'
        hypervisor: 'KVM'
    cloudstack_ops_hosts:
      - hostname: 'kvm01.local'
        cluster_name: 'Cluster1'
  roles:
    - homelab.cloudstack.api_auth
    - homelab.cloudstack.cloudstack_ops
```

## Role Variables

### prepare_kvm

| Variable                          | Default                   | Description                            |
| --------------------------------- | ------------------------- | -------------------------------------- |
| `prepare_kvm_hostname`            | `inventory_hostname`      | Host FQDN                              |
| `prepare_kvm_mgmt_bridge`         | `cloudbr0`                | Management network bridge              |
| `prepare_kvm_guest_bridge`        | `cloudbr0`                | Guest network bridge                   |
| `prepare_kvm_vfio_gpu_enabled`    | `false`                   | Enable GPU passthrough                 |
| `prepare_kvm_additional_storage`  | `[]`                      | Additional storage devices for MergeFS |
| `prepare_kvm_mergefs_mount_point` | `/mnt/cloudstack-storage` | MergeFS mount point                    |

### prepare_management

| Variable                                | Default              | Description                |
| --------------------------------------- | -------------------- | -------------------------- |
| `prepare_management_hostname`           | `inventory_hostname` | Server FQDN                |
| `prepare_management_db_host`            | `localhost`          | MySQL host                 |
| `prepare_management_db_user`            | `cloud`              | Database user              |
| `prepare_management_db_password`        | required             | Database password          |
| `prepare_management_nfs_primary_path`   | `/export/primary`    | NFS primary storage path   |
| `prepare_management_nfs_secondary_path` | `/export/secondary`  | NFS secondary storage path |

### cloudstack_ops

| Variable                            | Default  | Description                    |
| ----------------------------------- | -------- | ------------------------------ |
| `cloudstack_ops_zone`               | required | Zone configuration dict        |
| `cloudstack_ops_pods`               | `[]`     | List of pod configurations     |
| `cloudstack_ops_clusters`           | `[]`     | List of cluster configurations |
| `cloudstack_ops_hosts`              | `[]`     | List of hosts to add           |
| `cloudstack_ops_primary_storages`   | `[]`     | Primary storage pools          |
| `cloudstack_ops_secondary_storages` | `[]`     | Secondary storage pools        |

### kubernetes_cluster

| Variable                              | Default | Description            |
| ------------------------------------- | ------- | ---------------------- |
| `kubernetes_cluster_list`             | `[]`    | Clusters to create     |
| `kubernetes_cluster_wait_for_cluster` | `true`  | Wait for cluster ready |
| `kubernetes_cluster_wait_timeout`     | `1800`  | Timeout in seconds     |

## Features

### GPU Passthrough

Enable VFIO GPU passthrough on KVM hosts:

```yaml
prepare_kvm_vfio_gpu_enabled: true
prepare_kvm_vfio_reboot: true
```

This configures IOMMU, VFIO modules, and blacklists GPU drivers.

### MergeFS Storage

Combine multiple disks into a single storage pool:

```yaml
prepare_kvm_additional_storage:
  - device: '/dev/nvme0n1'
    filesystem: 'xfs'
    label: 'nvme-disk0'
  - device: '/dev/nvme1n1'
    filesystem: 'xfs'
    label: 'nvme-disk1'

prepare_kvm_mergefs_mount_point: '/mnt/cloudstack-storage'
```

### Local Storage

Add host-scoped local storage:

```yaml
cloudstack_ops_primary_storages:
  - name: 'Local-Storage-Host1'
    cluster_name: 'Cluster1'
    host: '10.0.0.10'
    url: 'file:///mnt/cloudstack-storage'
    scope: 'host'
```

### Kubernetes Clusters

Deploy CKS-managed Kubernetes:

```yaml
kubernetes_cluster_list:
  - name: 'k8s-prod'
    zone: 'Zone1'
    kubernetes_version: 'v1.28.0'
    service_offering: 'Medium Instance'
    size: 3
    control_nodes: 1
```

### Proxmox Orchestrator Extension

CloudStack 4.19+ includes built-in Orchestrator Extensions for Proxmox. Enable and configure Proxmox hosts:

```yaml
cloudstack_ops_proxmox_extension:
  enabled: true
  hosts:
    - name: 'pve01'
      url: 'https://10.0.0.5:8006'
      username: 'root@pam'
      token_id: 'cloudstack'
      token_secret: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
      verify_ssl: false
      node: 'pve01'
    - name: 'pve02'
      url: 'https://10.0.0.6:8006'
      username: 'root@pam'
      token_id: 'cloudstack'
      token_secret: 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy'
      node: 'pve02'
```

Create a Proxmox API token:

```bash
# On Proxmox host
pveum user token add root@pam cloudstack --privsep=0
```

The extension supports VM operations: deploy, start, stop, reboot, status, and delete.

## Directory Structure

```
roles/
  api_auth/          - API authentication
  cleanup/           - Resource cleanup
  cloudstack_ops/    - Infrastructure operations
  configure_kubernetes/ - CKS configuration
  kubernetes_cluster/   - Kubernetes management
  prepare_kvm/       - KVM host preparation
  prepare_management/ - Management server setup
```

## License

MIT
