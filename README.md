# Kubernetes on Proxmox with Kubeadm

A complete Terraform-based solution for deploying a production-ready Kubernetes cluster on Proxmox with comprehensive infrastructure, applications, and security configurations.

## Quick Links

- **New to this project?** → [Getting Started](docs/GETTING_STARTED.md)
- **Ready to deploy?** → [Installation Guide](docs/INSTALLATION.md)
- **Want to use the module?** → [Terraform Module Setup](docs/terraform/MODULE_SETUP.md)
- **Looking for examples?** → [Terraform Examples](docs/terraform/EXAMPLES.md)

## Project Overview

This project provides:

- **Automated Cluster Provisioning**: Deploy a Kubernetes cluster on Proxmox using Terraform and kubeadm
- **Infrastructure Components**: Longhorn storage, MetalLB load balancer, Contour ingress controller, cert-manager, and more
- **Application Stack**: WordPress, MySQL database, and a WordPress statistics API
- **Security & RBAC**: Comprehensive role-based access control configurations
- **Reusable Terraform Module**: Deploy multiple clusters with customizable parameters

## Documentation Structure

### Getting Started
- [Quick Start Guide](docs/GETTING_STARTED.md) - 5-minute setup to get your first cluster running
- [Complete Installation Guide](docs/INSTALLATION.md) - Detailed step-by-step installation for all components

### Terraform & Infrastructure as Code
- [Module Setup Guide](docs/terraform/MODULE_SETUP.md) - How to use the reusable kubeadm-proxmox module
- [Worker IP Calculation](docs/terraform/WORKER_IP_CALCULATION.md) - Understanding automatic IP assignment
- [Examples](docs/terraform/EXAMPLES.md) - Practical usage examples

### Infrastructure Components
- [Longhorn Storage](docs/infrastructure/LONGHORN.md) - Distributed storage configuration

### Applications
- [WordPress Stats API](docs/applications/API.md) - Go-based REST API for WordPress statistics

### Security & Access Control
- [RBAC Guide](docs/security/RBAC_GUIDE.md) - Role-based access control configurations
- [Client Certificate Authentication](docs/security/CLIENT_CERTS.md) - Namespace-scoped user access

## Key Features

✅ **Infrastructure as Code** - Entire cluster defined in Terraform
✅ **Production-Ready** - HA storage, load balancing, TLS certificates
✅ **Reusable Module** - Deploy multiple clusters with different configurations
✅ **Flexible Networking** - Auto-calculated IP assignments, custom network support
✅ **Security First** - RBAC, least-privilege access, client certificates
✅ **Applications Included** - WordPress, MySQL, monitoring, and more
✅ **Well Documented** - Comprehensive guides and examples

## Architecture

```
Proxmox VE (Host)
│
├── Master Node (k8s-master-1)
│   ├── Kubernetes Control Plane
│   ├── Helm & FluxCD
│   └── Cloud-init initialization
│
├── Worker Node 1 (k8s-worker-1)
│   ├── Kubernetes Worker
│   └── Cloud-init initialization
│
└── Worker Node 2+ (k8s-worker-N)
    ├── Kubernetes Worker
    └── Cloud-init initialization
```

## Component Stack

### Infrastructure Components
- **Longhorn**: Distributed block storage for persistent volumes
- **MetalLB**: Load balancer for bare metal clusters
- **Contour**: Ingress controller with load balancing
- **Cert-Manager**: TLS certificate automation
- **External-DNS**: Automatic DNS record management
- **Kubernetes Dashboard**: Web-based cluster management

### Applications
- **MySQL**: Database with SecretGen password management
- **WordPress**: CMS application with Helm deployment
- **WordPress Stats API**: Go-based REST API for user statistics

### Security
- **RBAC**: Role-based access control for different user types
- **Service Accounts**: Limited privilege deployments
- **Client Certificates**: User identity and namespace isolation
- **Secrets Management**: SecretGen for password generation

## Quickstart

### 1. Get the Code
```bash
cd ~/dev
git clone <repository-url> terraform-kubeadm
cd terraform-kubeadm
```

### 2. Configure Your Environment
```bash
cd examples/kubeadm-cluster
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox details
```

### 3. Deploy the Cluster
```bash
terraform init
terraform plan
terraform apply
```

### 4. Access Your Cluster
```bash
ssh -i ../../modules/kubeadm-proxmox/cluster-ssh-key ubuntu@192.168.1.200
kubectl get nodes
```

For detailed instructions, see [Getting Started](docs/GETTING_STARTED.md).

## Directory Structure

```
terraform-kubeadm/
├── README.md                          # This file
├── docs/                              # Documentation
│   ├── GETTING_STARTED.md             # Quick start guide
│   ├── INSTALLATION.md                # Complete installation guide
│   ├── terraform/                     # Terraform documentation
│   │   ├── MODULE_SETUP.md
│   │   ├── WORKER_IP_CALCULATION.md
│   │   └── EXAMPLES.md
│   ├── infrastructure/                # Infrastructure docs
│   │   └── LONGHORN.md
│   ├── applications/                  # Application docs
│   │   └── API.md
│   └── security/                      # Security docs
│       ├── RBAC_GUIDE.md
│       └── CLIENT_CERTS.md
│
├── modules/                           # Terraform modules
│   └── kubeadm-proxmox/               # Main reusable module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
│
├── examples/                          # Example configurations
│   └── kubeadm-cluster/               # Basic cluster example
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars.example
│
├── kubeadm/                           # Original kubeadm config
│   └── proxmox/
│
├── app/                               # Applications
│   ├── wordpress/                     # WordPress Helm chart
│   ├── mysql/                         # MySQL deployment
│   └── api/                           # WordPress Stats API
│
├── infra/                             # Infrastructure components
│   ├── longhorn/
│   ├── metallb/
│   ├── contour/
│   ├── cert-manager/
│   ├── dashboard/
│   └── secrets/
│
└── rbac/                              # RBAC configurations
    ├── wordpress-rbac.yaml
    └── ...
```

## Prerequisites

### For Proxmox
- Proxmox VE 7.0 or later
- Network access to Proxmox API
- Ubuntu cloud-init template prepared

### For Terraform
- Terraform 1.0 or later
- Proxmox provider 0.40.0 or later
- SSH access to your local machine

### For Kubernetes Administration
- kubectl configured with cluster access
- Helm 3.x for application deployments
- AWS credentials (for Route53 DNS with cert-manager and external-dns)

## Common Tasks

### Deploy a 5-Node Cluster
```bash
cd examples/kubeadm-cluster
terraform apply -var="worker_count=5"
```

### Use Custom Network
```bash
terraform apply \
  -var="master_ip=10.0.0.100" \
  -var="worker_ip_prefix=10.0.0" \
  -var="gateway_ip=10.0.0.1"
```

### Increase Resource Allocation
```bash
terraform apply \
  -var="master_cpu_cores=4" \
  -var="worker_memory_mb=16384"
```

### Access via Port-Forward
```bash
kubectl port-forward -n wordpress svc/wordpress 8080:80
# Then visit http://localhost:8080
```

## Troubleshooting

Check the appropriate documentation section:
- **Cluster deployment issues** → [Installation Guide - Troubleshooting](docs/INSTALLATION.md#troubleshooting)
- **Terraform/module problems** → [Module Setup - Troubleshooting](docs/terraform/MODULE_SETUP.md#troubleshooting)
- **RBAC permission issues** → [RBAC Guide](docs/security/RBAC_GUIDE.md)
- **Application deployment issues** → [Installation Guide - Applications](docs/INSTALLATION.md#application-deployment)

## Key Documentation Files

| Document | Purpose |
|----------|---------|
| [Getting Started](docs/GETTING_STARTED.md) | 5-minute quickstart for first deployment |
| [Installation Guide](docs/INSTALLATION.md) | Complete step-by-step installation of all components |
| [Module Setup](docs/terraform/MODULE_SETUP.md) | Understanding the Terraform module structure |
| [Worker IP Calculation](docs/terraform/WORKER_IP_CALCULATION.md) | How IP assignment works |
| [Examples](docs/terraform/EXAMPLES.md) | Practical usage patterns |
| [RBAC Guide](docs/security/RBAC_GUIDE.md) | User access control configurations |

## Support

For issues or questions:
1. Check the relevant documentation section above
2. Review the troubleshooting sections in specific guides
3. Check cloud-init logs on cluster nodes for deployment issues
4. Verify Terraform state and plan output for infrastructure issues

## License

This project is provided as-is for educational and production use.

---

**Ready to get started?** → [Go to Quick Start Guide](docs/GETTING_STARTED.md)
