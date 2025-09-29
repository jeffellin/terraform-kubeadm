# Kubernetes Cluster Deployment

This repository provides Terraform configurations to deploy Kubernetes clusters on both Proxmox and AWS environments.

## Directory Structure

```
kubeadm/
├── deploy.sh                 # Deployment script
├── DEPLOY.md                 # This documentation
├── shared/                   # Shared scripts for both environments
│   ├── install-k8s-common.sh # Common Kubernetes installation
│   ├── init-k8s-master.sh    # Master node initialization
│   └── join-k8s-worker.sh    # Worker node join logic
├── proxmox/                  # Proxmox-specific configuration
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── aws/                      # AWS-specific configuration
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    ├── user-data-master.sh
    └── user-data-worker.sh
```

## Quick Start

### 1. Choose Your Environment

Copy the example variables file and customize it:

```bash
# For Proxmox
cp proxmox/terraform.tfvars.example proxmox/terraform.tfvars
# Edit proxmox/terraform.tfvars with your values

# For AWS
cp aws/terraform.tfvars.example aws/terraform.tfvars
# Edit aws/terraform.tfvars with your values
```

### 2. Deploy

```bash
# Deploy to Proxmox
./deploy.sh proxmox apply

# Deploy to AWS
./deploy.sh aws apply
```

## Usage Examples

### Basic Operations

```bash
# Initialize and plan
./deploy.sh proxmox          # Same as: ./deploy.sh proxmox init
./deploy.sh aws

# Plan only
./deploy.sh proxmox plan
./deploy.sh aws plan

# Apply (deploy)
./deploy.sh proxmox apply
./deploy.sh aws apply

# Show outputs
./deploy.sh proxmox output
./deploy.sh aws output

# Destroy
./deploy.sh proxmox destroy
./deploy.sh aws destroy
```

### Advanced Options

```bash
# Auto-approve (skip confirmation)
./deploy.sh aws apply -auto-approve

# Custom variables file
./deploy.sh proxmox apply -var-file=production.tfvars

# Clean terraform state
./deploy.sh proxmox clean
```

## Environment-Specific Configuration

### Proxmox Requirements

- Proxmox server with API access
- Ubuntu cloud-init template created
- Network bridge configured
- SSH access to Proxmox host

### AWS Requirements

- AWS CLI configured with appropriate permissions
- VPC and subnet already created
- SSH key pair for EC2 access

## Customization

### Shared Scripts

The `shared/` directory contains scripts used by both environments:

- `install-k8s-common.sh`: Installs Docker and Kubernetes components
- `init-k8s-master.sh`: Initializes the Kubernetes master node
- `join-k8s-worker.sh`: Joins worker nodes to the cluster

### Environment Variables

You can override variables using environment variables:

```bash
export TF_VAR_cluster_name="my-production-cluster"
export TF_VAR_worker_count=5
./deploy.sh aws apply
```

## Troubleshooting

### Common Issues

1. **Missing terraform.tfvars**: Copy from `.example` file and customize
2. **SSH connection failures**: Check network configuration and SSH keys
3. **Kubernetes join failures**: Ensure master node is fully initialized before workers

### Debugging

```bash
# Enable Terraform debug logging
export TF_LOG=DEBUG
./deploy.sh proxmox plan

# Check cluster status (after deployment)
./deploy.sh proxmox output
ssh ubuntu@<master-ip> 'kubectl get nodes'
```

## Security Considerations

- Store `terraform.tfvars` files securely (they contain sensitive data)
- Use strong passwords and SSH keys
- Restrict network access with security groups/firewalls
- Consider using Terraform Cloud or backend for state management

## Next Steps

After deployment, you can:

1. Install additional Kubernetes addons (ingress, monitoring, etc.)
2. Configure persistent storage
3. Set up CI/CD pipelines
4. Implement backup strategies