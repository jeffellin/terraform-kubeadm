# Kubeadm Proxmox Module

This Terraform module deploys a Kubernetes cluster on Proxmox using kubeadm. It creates:
- 1 Kubernetes master node
- Configurable number of worker nodes (default: 3)

## Requirements

- Terraform >= 1.0
- Proxmox VE >= 7.0
- Proxmox provider >= 0.40.0
- An Ubuntu cloud-init template in Proxmox (VM ID 9000 by default)
- SSH keys configured in `cluster-ssh-key` and `cluster-ssh-key.pub` files

## Module Usage

```hcl
module "kubeadm_cluster" {
  source = "../../modules/kubeadm-proxmox"

  # Required
  proxmox_host     = "https://proxmox.example.com:8006/api2/json"
  proxmox_username = "root@pam"
  proxmox_password = var.proxmox_password
  proxmox_node     = "pve"
  storage_pool     = "local-lvm"
  network_bridge   = "vmbr0"

  # Optional (defaults provided)
  vm_password      = "SecurePassword123"
  ssh_public_key   = file("~/.ssh/id_ed25519.pub")
  worker_count     = 3
  master_ip        = "192.168.1.200"
  cluster_name     = "my-k8s-cluster"
}
```

## Required Variables

| Variable | Description | Type | Example |
|----------|-------------|------|---------|
| `proxmox_host` | Proxmox API endpoint | string | `https://proxmox.example.com:8006/api2/json` |
| `proxmox_username` | Proxmox username | string | `root@pam` |
| `proxmox_password` | Proxmox password | string | N/A (sensitive) |
| `proxmox_node` | Proxmox node name | string | `pve` |
| `storage_pool` | Storage pool for VM disks | string | `local-lvm` |
| `network_bridge` | Network bridge for VMs | string | `vmbr0` |

## Optional Variables with Defaults

| Variable | Default | Description |
|----------|---------|-------------|
| `vm_password` | `Passw0rd` | Ubuntu user password |
| `ssh_public_key` | `""` | SSH public key for access |
| `ubuntu_iso_path` | `local:iso/ubuntu-24.04-live-server-amd64.iso` | Ubuntu ISO path |
| `template_id` | `9000` | VM ID of cloud-init template |
| `template_name` | `ubuntu-24.04-cloud-init` | Template name |
| `snippets_storage` | `local` | Storage for cloud-init snippets |
| `worker_count` | `3` | Number of worker nodes |
| `master_ip` | `192.168.1.200` | Master node IP |
| `worker_ip_prefix` | `192.168.1` | IP prefix for workers |
| `gateway_ip` | `192.168.1.1` | Network gateway |
| `cluster_name` | `k8s-cluster` | Kubernetes cluster name |
| `master_cpu_cores` | `2` | Master CPU cores |
| `master_memory_mb` | `4096` | Master memory in MB |
| `worker_cpu_cores` | `2` | Worker CPU cores |
| `worker_memory_mb` | `8192` | Worker memory in MB |
| `worker_disk_size_gb` | `50` | Worker disk size in GB |

## Outputs

| Output | Description |
|--------|-------------|
| `master_vm_id` | Proxmox VM ID of the master node |
| `worker_vm_ids` | Map of worker node VM IDs |
| `master_ip` | Master node IP address |
| `worker_ips` | List of worker node IP addresses |
| `cluster_name` | Kubernetes cluster name |
| `master_hostname` | Master node hostname |
| `worker_hostnames` | Map of worker node hostnames |

## Example

See the `examples/kubeadm-cluster` directory for a complete working example.

### Quick Start

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Update with your Proxmox settings
3. Run:
```bash
terraform init
terraform plan
terraform apply
```

### SSH Access

After deployment, access the cluster nodes via:

```bash
# Master node
ssh -i /path/to/cluster-ssh-key ubuntu@192.168.1.200

# Worker nodes
ssh -i /path/to/cluster-ssh-key ubuntu@192.168.1.201
ssh -i /path/to/cluster-ssh-key ubuntu@192.168.1.202
ssh -i /path/to/cluster-ssh-key ubuntu@192.168.1.203
```

### Accessing Kubernetes

Once the cluster is deployed, you can access kubectl from the master node:

```bash
ssh -i /path/to/cluster-ssh-key ubuntu@192.168.1.200 kubectl get nodes
```

## Pre-requisites

### Ubuntu Cloud-Init Template in Proxmox

You need an Ubuntu cloud-init template. To create one:

1. Create a new VM with Ubuntu 24.04 server ISO
2. Configure network, storage, and resources as needed
3. Set VM ID to 9000 (or override `template_id`)
4. Convert to template: `qm template <vm-id>`

### SSH Keys

Generate SSH keys for the cluster:

```bash
ssh-keygen -t ed25519 -f cluster-ssh-key -N ""
# This creates:
# - cluster-ssh-key (private key)
# - cluster-ssh-key.pub (public key)
```

## Cluster Initialization

The module automatically:
1. Deploys the master node with kubeadm initialization
2. Deploys worker nodes
3. Configures networking with Calico
4. Installs Helm and FluxCD on the master

Worker nodes will automatically join the cluster and become Ready within 5-10 minutes.

## Customization

You can customize cluster sizing per node type:

```hcl
module "kubeadm_cluster" {
  source = "../../modules/kubeadm-proxmox"

  # ... required variables ...

  # Sizing customization
  master_cpu_cores    = 4
  master_memory_mb    = 8192
  worker_cpu_cores    = 8
  worker_memory_mb    = 16384
  worker_disk_size_gb = 100
}
```

## Troubleshooting

### Workers not joining cluster
- Check master node cloud-init logs: `tail -f /var/log/cloud-init-output.log`
- Verify master has completed initialization before workers try to join
- Check DNS resolution: `ssh ubuntu@192.168.1.20X nslookup 192.168.1.200`

### Network issues
- Verify network bridge is configured in Proxmox
- Check IP routing: `ssh ubuntu@192.168.1.200 ip route`
- Verify gateway connectivity: `ssh ubuntu@192.168.1.200 ping 192.168.1.1`

## License

This module is provided as-is for managing Kubernetes clusters on Proxmox.
