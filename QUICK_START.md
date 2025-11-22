# Quick Start: Using the Kubeadm Proxmox Module

## Summary

I've converted your `kubeadm/proxmox` folder into a reusable Terraform module.

**What this means:**
- ✅ One module, infinite clusters
- ✅ Customizable via simple parameters
- ✅ Backward compatible with your original setup
- ✅ Fully documented with examples

## 5-Minute Setup

### Step 1: Navigate to the example directory
```bash
cd examples/kubeadm-cluster
```

### Step 2: Copy the example config
```bash
cp terraform.tfvars.example terraform.tfvars
```

### Step 3: Edit with your Proxmox details
```bash
vi terraform.tfvars
```

Update these 6 required fields:
```hcl
proxmox_host     = "https://your-proxmox-host:8006/api2/json"
proxmox_username = "root@pam"
proxmox_password = "your-password"
proxmox_node     = "pve"
storage_pool     = "local-lvm"
network_bridge   = "vmbr0"
```

### Step 4: Deploy
```bash
terraform init
terraform apply
```

## What You Get

✅ 1 Kubernetes Master + 3 Workers (default)  
✅ Fully functional cluster with Calico networking  
✅ SSH access via cluster-ssh-key  
✅ Helm and FluxCD pre-installed  

## SSH Access

```bash
# To master node
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200

# Check cluster status
kubectl get nodes
```

## Customization Examples

### 5-Worker Cluster
```bash
terraform apply -var="worker_count=5"
```

### Different Network
```bash
terraform apply \
  -var="master_ip=10.0.0.100" \
  -var="worker_ip_prefix=10.0.0" \
  -var="gateway_ip=10.0.0.1"
```

### More Resources
```bash
terraform apply \
  -var="master_memory_mb=8192" \
  -var="worker_memory_mb=16384" \
  -var="worker_cpu_cores=4"
```

### Using SSH Keys
```bash
terraform apply -var='ssh_public_key='"$(cat ~/.ssh/id_ed25519.pub)"
```

## Module Parameters

### Required (Must provide)
| Parameter | Purpose | Example |
|-----------|---------|---------|
| `proxmox_host` | API endpoint | `https://proxmox:8006/api2/json` |
| `proxmox_username` | Username | `root@pam` |
| `proxmox_password` | Password | `your-secret` |
| `proxmox_node` | Node name | `pve` |
| `storage_pool` | Storage pool | `local-lvm` |
| `network_bridge` | Network bridge | `vmbr0` |

### Optional (Sensible defaults)
| Parameter | Default | Purpose |
|-----------|---------|---------|
| `worker_count` | `3` | Number of workers |
| `master_ip` | `192.168.1.200` | Master IP |
| `worker_ip_prefix` | `192.168.1` | Worker IP base |
| `gateway_ip` | `192.168.1.1` | Network gateway |
| `vm_password` | `Passw0rd` | Ubuntu password |
| `ssh_public_key` | `""` | SSH key (optional) |
| `master_cpu_cores` | `2` | Master CPUs |
| `master_memory_mb` | `4096` | Master RAM |
| `worker_cpu_cores` | `2` | Worker CPUs |
| `worker_memory_mb` | `8192` | Worker RAM |
| `worker_disk_size_gb` | `50` | Worker disk |
| `cluster_name` | `k8s-cluster` | Cluster name |

## File Locations

```
terraform-kubeadm/
├── modules/kubeadm-proxmox/          ← The reusable module
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── master-cloud-init.yaml.tftpl
│   ├── worker-cloud-init.yaml.tftpl
│   ├── cluster-ssh-key               ← SSH private key
│   ├── cluster-ssh-key.pub
│   └── README.md
│
├── examples/kubeadm-cluster/         ← Usage example
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example      ← Copy this
│   └── README.md
│
├── kubeadm/proxmox/                  ← Original (still works)
│
├── MODULE_SETUP.md                   ← Detailed guide
├── MODULES_DIAGRAM.txt               ← Visual diagram
└── QUICK_START.md                    ← This file
```

## Common Tasks

### Check cluster status
```bash
# SSH to master
ssh ubuntu@192.168.1.200

# Get nodes
kubectl get nodes

# Get pods
kubectl get pods -A
```

### Increase worker count
```bash
terraform apply -var="worker_count=5"
```

### Destroy cluster
```bash
terraform destroy
```

### Use environment variables
```bash
export TF_VAR_proxmox_password="my-password"
terraform apply -var="worker_count=2"
```

## Troubleshooting

### Check master initialization
```bash
ssh ubuntu@192.168.1.200 sudo tail -f /var/log/cloud-init-output.log
```

### Check worker initialization
```bash
ssh ubuntu@192.168.1.201 sudo tail -f /var/log/cloud-init-output.log
```

### SSH key authentication
```bash
# Ensure key has correct permissions
chmod 600 modules/kubeadm-proxmox/cluster-ssh-key

# Test SSH
ssh -i modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200
```

## Documentation

- **[Module README](modules/kubeadm-proxmox/README.md)** - Full module documentation
- **[Module Setup Guide](MODULE_SETUP.md)** - Detailed explanation
- **[Example README](examples/kubeadm-cluster/README.md)** - Example usage patterns
- **[Module Diagram](MODULES_DIAGRAM.txt)** - Visual overview

## Next Steps

1. ✅ Copy `terraform.tfvars.example` → `terraform.tfvars`
2. ✅ Edit with your Proxmox settings
3. ✅ Run `terraform apply`
4. ✅ SSH to nodes and enjoy!

## Support

For more details:
- Module documentation: See `modules/kubeadm-proxmox/README.md`
- Example patterns: See `examples/kubeadm-cluster/README.md`
- Architecture: See `MODULES_DIAGRAM.txt`

Happy clustering! 🚀
