# Kubeadm Cluster Example

This example demonstrates how to use the `kubeadm-proxmox` module to deploy a Kubernetes cluster.

## Quick Start

### 1. Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

Update with your Proxmox settings:

```hcl
proxmox_host     = "https://your-proxmox-host:8006/api2/json"
proxmox_username = "root@pam"
proxmox_password = "your-password"
proxmox_node     = "pve"
storage_pool     = "local-lvm"
network_bridge   = "vmbr0"
```

### 3. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the cluster
terraform apply
```

## Customizing the Deployment

### Change cluster size

```bash
terraform apply -var="worker_count=5"
```

### Customize resource allocation

```bash
terraform apply \
  -var="master_cpu_cores=4" \
  -var="master_memory_mb=8192" \
  -var="worker_cpu_cores=4" \
  -var="worker_memory_mb=16384"
```

### Use custom IP range

```bash
terraform apply \
  -var="master_ip=10.0.0.100" \
  -var="worker_ip_prefix=10.0.0" \
  -var="gateway_ip=10.0.0.1"
```

## Accessing the Cluster

### SSH to nodes

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200
```

### Check cluster status

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200 kubectl get nodes
```

### Watch pods startup

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200 \
  kubectl get pods -A --watch
```

## Managing the Cluster

### Scale worker nodes

To add more worker nodes, change `worker_count`:

```bash
terraform apply -var="worker_count=5"
```

To remove worker nodes:

```bash
# First drain the node
kubectl drain k8s-worker-5 --ignore-daemonsets --delete-emptydir-data

# Then scale down
terraform apply -var="worker_count=4"
```

### Destroy the cluster

```bash
terraform destroy
```

## Common Tasks

### Get kubeconfig

From the master node:

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200 \
  sudo cat /etc/kubernetes/admin.conf
```

### Install additional tools

Example: Install MetalLB for load balancing

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200 <<'EOF'
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
EOF
```

### Check cluster events

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200 \
  kubectl get events -A
```

## Troubleshooting

### Cluster creation stuck

Check the master node logs:

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200 \
  sudo tail -f /var/log/cloud-init-output.log
```

### Workers not joining

Check worker logs:

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.201 \
  sudo tail -f /var/log/cloud-init-output.log
```

Manually regenerate join command on master:

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200 \
  sudo kubeadm token create --print-join-command
```

### Network issues

Verify master can reach workers:

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200 \
  ping 192.168.1.201
```

Check DNS on worker:

```bash
ssh -i ../../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.201 \
  nslookup kubernetes.default
```

## Module Variables

See `variables.tf` for all available options. Key customizable parameters:

- `worker_count`: Number of worker nodes (default: 3)
- `master_ip`: Master node IP address (default: 192.168.1.200)
- `worker_ip_prefix`: IP prefix for worker nodes (default: 192.168.1)
- `master_cpu_cores`: Master CPU cores (default: 2)
- `master_memory_mb`: Master memory (default: 4096)
- `worker_cpu_cores`: Worker CPU cores (default: 2)
- `worker_memory_mb`: Worker memory (default: 8192)
- `worker_disk_size_gb`: Worker disk size (default: 50)

## Tips

1. **Use environment variables for sensitive values**:
   ```bash
   export TF_VAR_proxmox_password="your-password"
   terraform plan
   ```

2. **Keep terraform state secure**:
   ```bash
   # Add to .gitignore
   echo "terraform.tfstate*" >> .gitignore
   ```

3. **Use a backend for team collaboration**:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "your-bucket"
       key    = "kubeadm/terraform.tfstate"
     }
   }
   ```

4. **Monitor cluster health**:
   ```bash
   # Get all resources
   kubectl get all -A

   # Check pod status
   kubectl get pods -A

   # View cluster info
   kubectl cluster-info
   ```
