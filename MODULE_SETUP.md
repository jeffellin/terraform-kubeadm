# Kubeadm Proxmox Module Setup

I've created a reusable Terraform module from the kubeadm/proxmox folder. Here's what was created:

## Directory Structure

```
terraform-kubeadm/
├── modules/
│   └── kubeadm-proxmox/          # Main module
│       ├── main.tf               # Resource definitions
│       ├── variables.tf           # Input variables
│       ├── outputs.tf             # Output values
│       ├── README.md              # Module documentation
│       ├── master-cloud-init.yaml.tftpl
│       ├── worker-cloud-init.yaml.tftpl
│       ├── cluster-ssh-key        # SSH keys (copied from kubeadm/proxmox)
│       └── cluster-ssh-key.pub
├── examples/
│   └── kubeadm-cluster/          # Example usage
│       ├── main.tf               # Module usage example
│       ├── variables.tf           # Variable definitions
│       ├── terraform.tfvars.example
│       └── README.md              # Usage guide
└── kubeadm/
    └── proxmox/                   # Original (still works as-is)
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── ...
```

## Module Parameters

### Required Parameters
These MUST be provided when calling the module:

```hcl
proxmox_host     = "https://your-proxmox-host:8006/api2/json"
proxmox_username = "root@pam"
proxmox_password = var.proxmox_password
proxmox_node     = "pve"
storage_pool     = "local-lvm"
network_bridge   = "vmbr0"
```

### Optional Parameters with Defaults

**VM Credentials & Setup:**
- `vm_password` (default: "Passw0rd")
- `ssh_public_key` (default: "")
- `ubuntu_iso_path` (default: "local:iso/ubuntu-24.04-live-server-amd64.iso")
- `template_id` (default: 9000)
- `template_name` (default: "ubuntu-24.04-cloud-init")
- `snippets_storage` (default: "local")

**Cluster Configuration:**
- `worker_count` (default: 3)
- `master_ip` (default: "192.168.1.200")
- `worker_ip_prefix` (default: "192.168.1")
- `gateway_ip` (default: "192.168.1.1")
- `cluster_name` (default: "k8s-cluster")

**Resource Sizing:**
- `master_cpu_cores` (default: 2)
- `master_memory_mb` (default: 4096)
- `worker_cpu_cores` (default: 2)
- `worker_memory_mb` (default: 8192)
- `worker_disk_size_gb` (default: 50)

## Usage Example

### Basic usage with minimal config:

```hcl
module "kubeadm_cluster" {
  source = "../../modules/kubeadm-proxmox"

  proxmox_host     = "https://proxmox.example.com:8006/api2/json"
  proxmox_username = "root@pam"
  proxmox_password = var.proxmox_password
  proxmox_node     = "pve"
  storage_pool     = "local-lvm"
  network_bridge   = "vmbr0"
}
```

### Advanced usage with customization:

```hcl
module "kubeadm_cluster" {
  source = "../../modules/kubeadm-proxmox"

  # Required
  proxmox_host     = var.proxmox_host
  proxmox_username = var.proxmox_username
  proxmox_password = var.proxmox_password
  proxmox_node     = var.proxmox_node
  storage_pool     = var.storage_pool
  network_bridge   = var.network_bridge

  # Optional - override defaults
  vm_password      = "MySecurePassword123"
  ssh_public_key   = file("~/.ssh/id_ed25519.pub")
  worker_count     = 5
  master_ip        = "10.0.0.100"
  worker_ip_prefix = "10.0.0"
  gateway_ip       = "10.0.0.1"
  cluster_name     = "production-cluster"

  # Resource sizing
  master_cpu_cores    = 4
  master_memory_mb    = 8192
  worker_cpu_cores    = 4
  worker_memory_mb    = 16384
  worker_disk_size_gb = 100
}
```

## Quick Start

1. **Navigate to example directory:**
   ```bash
   cd examples/kubeadm-cluster
   ```

2. **Create terraform.tfvars from template:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars with your Proxmox details:**
   ```hcl
   proxmox_host     = "https://your-proxmox-host:8006/api2/json"
   proxmox_username = "root@pam"
   proxmox_password = "your-password"
   proxmox_node     = "pve"
   storage_pool     = "local-lvm"
   network_bridge   = "vmbr0"
   ```

4. **Deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Outputs

The module provides these outputs:

```hcl
output "master_vm_id"       # Proxmox VM ID of master
output "worker_vm_ids"      # Map of worker VM IDs
output "master_ip"          # Master IP address
output "worker_ips"         # List of worker IPs
output "cluster_name"       # Kubernetes cluster name
output "master_hostname"    # Master hostname
output "worker_hostnames"   # Map of worker hostnames
```

## Key Differences from Original

1. **Parameterized:** All hardcoded values are now variables with sensible defaults
2. **Reusable:** Can be called multiple times to create different clusters
3. **Flexible IP Configuration:** Master and worker IPs are fully customizable
4. **Resource Sizing:** CPU, memory, and disk can be configured per node type
5. **SSH Keys:** Embedded in the module directory (copied from original)
6. **Documentation:** Comprehensive README and examples included

## Original Folder Still Works

The original `kubeadm/proxmox` folder is unchanged and continues to work as before. You can:
- Keep using the original configuration
- Gradually migrate to the module
- Use both in parallel for different clusters

## Common Tasks

### Create a 5-worker cluster:
```bash
terraform apply -var="worker_count=5"
```

### Use different IP range:
```bash
terraform apply \
  -var="master_ip=10.0.0.100" \
  -var="worker_ip_prefix=10.0.0"
```

### Scale up resources:
```bash
terraform apply \
  -var="worker_cpu_cores=4" \
  -var="worker_memory_mb=16384"
```

### Deploy with environment variable:
```bash
export TF_VAR_proxmox_password="your-password"
terraform apply -var="worker_count=2"
```

## Next Steps

1. Copy `examples/kubeadm-cluster` to your own directory
2. Update `terraform.tfvars` with your Proxmox settings
3. Run `terraform init && terraform apply`
4. Access cluster via SSH keys from `modules/kubeadm-proxmox/cluster-ssh-key`

For detailed documentation, see:
- [Module README](modules/kubeadm-proxmox/README.md)
- [Example README](examples/kubeadm-cluster/README.md)
