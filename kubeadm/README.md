# Kubernetes Cluster on Proxmox with Terraform

This Terraform configuration creates a 3-node Kubernetes cluster on Proxmox using kubeadm.

## Prerequisites

1. **Proxmox VE** server with API access
2. **Ubuntu cloud-init template** prepared in Proxmox
3. **Terraform** installed locally
4. **SSH key pair** for accessing VMs

## Setup

1. Clone or download this configuration
2. Copy `terraform.tfvars.example` to `terraform.tfvars`
3. Edit `terraform.tfvars` with your specific values
4. Initialize and apply Terraform

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

## Configuration Parameters

### Required Variables

- `proxmox_host`: Proxmox API URL (e.g., https://192.168.1.100:8006/api2/json)
- `proxmox_username`: Proxmox username (e.g., root@pam)
- `proxmox_password`: Proxmox password
- `ubuntu_iso_path`: Path to Ubuntu ISO in Proxmox storage
- `template_name`: Name of Ubuntu cloud-init template
- `vm_password`: Password for ubuntu user on VMs
- `ssh_public_key`: Your SSH public key
- `master_ip`: Static IP for master node
- `worker_ips`: List of static IPs for worker nodes
- `gateway`: Network gateway IP

### Optional Variables

- `proxmox_node`: Proxmox node name (default: "pve")
- `storage_pool`: Storage pool name (default: "local-lvm")
- `network_bridge`: Network bridge (default: "vmbr0")
- `dns_servers`: DNS servers (default: ["8.8.8.8", "8.8.4.4"])

## What Gets Created

- 1 Kubernetes master node (2 CPU, 4GB RAM, 20GB disk)
- 2 Kubernetes worker nodes (2 CPU, 2GB RAM, 20GB disk each)
- Fully configured Kubernetes cluster with Flannel CNI
- SSH access configured for all nodes

## Post-Deployment

After successful deployment:

1. SSH to the master node:
   ```bash
   ssh ubuntu@<master_ip>
   ```

2. Verify cluster status:
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

3. Access kubeconfig:
   ```bash
   cat ~/.kube/config
   ```

## Cleanup

To destroy the cluster:

```bash
terraform destroy
```

## Notes

- The cluster uses Flannel as the CNI plugin
- Docker is used as the container runtime
- All nodes are configured with cloud-init
- SSH keys are automatically configured for password-less access