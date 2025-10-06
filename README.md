# Kubernetes WordPress Platform - Design Document

## Overview

This project implements a production-ready WordPress hosting platform on bare-metal Kubernetes using Infrastructure as Code (IaC) principles. The platform is provisioned using Terraform on Proxmox and demonstrates a complete CI/CD-ready architecture with security best practices, automated certificate management, and observability.

## Architecture

### Infrastructure Layer

**Technology Choice: Terraform + Proxmox**

The cluster is provisioned using Terraform on Proxmox hypervisor with cloud-init automation:

- **1 Master Node** (k8s-master-1): 192.168.1.200
- **2 Worker Nodes** (k8s-worker-1, k8s-worker-2): 192.168.1.201-202
- **CNI**: Calico (configured via cloud-init)
- **Container Runtime**: containerd

**Tradeoffs:**
- ✅ **Pros**: Full infrastructure automation, repeatable deployments, version-controlled infrastructure
- ⚠️ **Cons**: Requires Proxmox environment, more complex initial setup than cloud providers
- **Alternative Considered**: Managed Kubernetes (EKS/GKE/AKS) - rejected due to cost and learning objectives

### Storage Layer

**Technology Choice: Longhorn**

Longhorn provides distributed block storage with replication across worker nodes.

**Key Design Decisions:**
- **Replication Factor**: 2 (balanced redundancy for 2-node worker setup)
- **Storage Class**: `longhorn` (default)
- **Use Cases**: MySQL persistent volumes, WordPress file storage

**Tradeoffs:**
- ✅ **Pros**: Cloud-native, snapshot support, built-in backup/recovery, web UI
- ⚠️ **Cons**: Requires multiple worker nodes, performance overhead vs. local storage
- **Alternatives Considered**:
  - NFS: Simpler but single point of failure
  - Local PVs: Faster but no replication/mobility

### Networking Layer

**Load Balancing: MetalLB (Layer 2 Mode)**

MetalLB provides LoadBalancer services on bare metal using Layer 2 ARP.

**Configuration:**
- **IP Pool**: 192.168.1.220-225 (6 IPs for services)
- **Mode**: Layer 2 (simpler than BGP for home/lab environments)

**Tradeoffs:**
- ✅ **Pros**: Simple setup, works on any L2 network, no router configuration needed
- ⚠️ **Cons**: Active/passive (no true load balancing), requires free IPs on network
- **Alternative Considered**: BGP mode - rejected due to home router limitations

**Ingress: Contour (Envoy)**

Contour provides HTTP/HTTPS ingress with advanced routing and observability.

**Key Features:**
- HTTP/2 and gRPC support
- Dynamic configuration via HTTPProxy CRDs
- Integration with cert-manager for TLS

**Tradeoffs:**
- ✅ **Pros**: High performance, excellent observability, production-grade
- ⚠️ **Cons**: More complex than nginx-ingress
- **Alternative Considered**: nginx-ingress - Contour chosen for better Envoy integration

**DNS: External-DNS + Route53**

Automated DNS record management for Kubernetes resources.

**Configuration:**
- **Provider**: AWS Route53
- **Zone**: ellin.net
- **Automation**: Watches Ingress resources and creates/updates A records

**Tradeoffs:**
- ✅ **Pros**: Fully automated DNS, supports multiple providers, declarative
- ⚠️ **Cons**: Requires cloud DNS provider, IAM credential management
- **Alternative Considered**: Manual DNS - rejected for automation goals

### Security Layer

**Certificate Management: cert-manager + Let's Encrypt**

Automated TLS certificate provisioning and renewal using ACME protocol.

**Configuration:**
- **Issuer**: Let's Encrypt (staging and production)
- **Challenge Type**: DNS-01 via Route53
- **Certificate Storage**: Kubernetes TLS secrets
- **Renewal**: Automatic (30 days before expiry)

**Key Design Decisions:**
- DNS-01 challenges chosen over HTTP-01 for wildcard certificate support
- Separate staging issuer for testing to avoid rate limits

**Tradeoffs:**
- ✅ **Pros**: Free certificates, automatic renewal, industry standard
- ⚠️ **Cons**: Requires public DNS, Route53 API access, DNS propagation delays
- **Alternative Considered**: Self-signed certs - rejected for production-readiness

**Secret Management: SecretGen Controller**

Carvel SecretGen manages password generation and cross-namespace secret sharing.

**Use Cases:**
- MySQL password generation (in `secrets` namespace)
- Secret import to `mysql` and `wordpress` namespaces

**Tradeoffs:**
- ✅ **Pros**: Declarative secret management, automatic generation, cross-namespace sharing
- ⚠️ **Cons**: Additional CRD dependency
- **Alternative Considered**: Manual secrets - rejected for automation and rotation capabilities

**RBAC Architecture**

Principle of Least Privilege implemented through dedicated service accounts:

**1. wordpress-deployer**
- **Scope**: wordpress namespace
- **Permissions**: Full CRUD on deployments, services, PVCs, configmaps, secrets, service accounts, ingresses, SecretImports
- **Use Case**: Helm deployments, CI/CD pipelines
- **Generated Kubeconfig**: Used for automated deployments

**2. wordpress-portforward**
- **Scope**: wordpress namespace
- **Permissions**: Read pods/services, port-forward access
- **Use Case**: Developer access without deployment rights

**Key Design Decisions:**
- Service accounts scoped to single namespace (blast radius limitation)
- Separate deploy vs. access roles (separation of duties)
- Generated kubeconfigs for CI/CD integration
- No cluster-admin usage in application workflows

**Tradeoffs:**
- ✅ **Pros**: Security boundaries, audit trail, prevents accidental changes
- ⚠️ **Cons**: More complex permission management, multiple kubeconfigs
- **Alternative Considered**: Shared admin access - rejected for security

### Application Layer

**Database: MySQL**

Single-instance MySQL deployment with persistent storage.

**Configuration:**
- **Namespace**: `mysql` (isolated from wordpress)
- **Storage**: Longhorn PVC (1Gi)
- **Password Management**: SecretGen-generated, imported to consuming namespaces
- **Initialization**: ConfigMap with WordPress schema setup

**Tradeoffs:**
- ✅ **Pros**: Namespace isolation, automated secret management
- ⚠️ **Cons**: Single instance (no HA), shared for all WordPress instances
- **Alternative Considered**: Cloud RDS - rejected for cost and learning objectives

**WordPress: Helm Chart**

Custom Helm chart for WordPress deployment with production best practices.

**Key Features:**
- Persistent storage for WordPress files (Longhorn)
- SecretImport for MySQL credentials
- Configurable replica count
- Service account with minimal permissions (`automountServiceAccountToken: false`)
- Ingress with TLS support
- External-DNS integration

**Configuration Management:**
- **values.yaml**: Default configuration (wordpress.ellin.net, TLS enabled)
- **Helm CLI overrides**: Runtime customization
- **Site URLs**: Managed in MySQL (wp_options table)

**Tradeoffs:**
- ✅ **Pros**: Reproducible deployments, easy upgrades, GitOps-ready
- ⚠️ **Cons**: WordPress stateful nature limits horizontal scaling
- **Alternative Considered**: StatefulSet - rejected in favor of Deployment with Recreate strategy

**WordPress Stats API (Optional)**

Go-based REST API providing WordPress statistics by querying MySQL directly.

**Features:**
- `/api/userinfo` endpoint for post statistics
- Containerized Go application
- LoadBalancer or Ingress exposure
- Optional TLS certificate

**Design Rationale:**
- Demonstrates multi-tier application architecture
- Shows cross-namespace database access patterns
- Example of API-first approach to WordPress data

## Key Design Patterns

### 1. Infrastructure as Code (IaC)
- All infrastructure defined in Terraform
- All Kubernetes resources in YAML/Helm
- Version-controlled, reviewable, repeatable

### 2. GitOps-Ready Architecture
- Declarative configuration
- RBAC for automated deployments
- Namespace isolation
- No manual kubectl commands in production workflow

### 3. Security-First Design
- Least privilege RBAC
- Network policies (namespace isolation)
- Automated certificate management
- Secret rotation via SecretGen
- No service account tokens mounted by default

### 4. Observability & Operations
- Kubernetes Dashboard for cluster management
- Longhorn UI for storage management
- Envoy metrics via Contour
- Structured logging (container stdout/stderr)

### 5. Separation of Concerns
- Infrastructure vs. Application namespaces
- Shared services (`secrets`, `mysql`) vs. application (`wordpress`)
- Platform components (longhorn, metallb, etc.) vs. workloads

## Installation Order & Dependencies

The strict installation order is driven by dependencies:

```
Terraform (Cluster) → Longhorn → MetalLB → Contour → Secrets NS →
SecretGen → AWS Secrets → Cert-Manager → Dashboard → Let's Encrypt Issuers →
External-DNS → MySQL → WordPress → API → RBAC
```

**Critical Path:**
- Storage must precede any PVC-using applications
- MetalLB must precede Contour (LoadBalancer dependency)
- SecretGen must precede MySQL (password generation)
- MySQL must precede WordPress (database dependency)

## Deployment Workflow (RBAC-Enabled)

1. **Namespace Creation**: `kubectl create namespace wordpress`
2. **RBAC Setup**: `kubectl apply -f rbac/wordpress-rbac.yaml`
3. **Kubeconfig Generation**: `./rbac/create-sa-kubeconfig.sh wordpress wordpress-deployer`
4. **Switch Context**: `export KUBECONFIG=./rbac/wordpress-deployer.kubeconfig`
5. **Verify Identity**: `kubectl auth whoami`
6. **Deploy**: `helm install wordpress ./app/wordpress -n wordpress`
7. **Access Setup**: Create `wordpress-portforward` kubeconfig for port-forward access

## Production Considerations

### Current Limitations

1. **Single Points of Failure:**
   - Single master node (control plane HA not implemented)
   - Single MySQL instance (no replication)

2. **Scaling Constraints:**
   - WordPress uses Recreate strategy (ReadWriteOnce PVC limitation)
   - Session affinity required for multi-replica deployments

3. **Backup/Recovery:**
   - Longhorn provides snapshot capabilities (not automated)
   - MySQL backups via manual mysqldump (no automated schedule)

### Production Enhancements

**For Production Deployment:**

1. **High Availability:**
   - 3+ master nodes with etcd HA
   - MySQL replication (master-slave or Galera)
   - ReadWriteMany storage class for WordPress shared files

2. **Monitoring & Alerting:**
   - Prometheus + Grafana stack
   - AlertManager for critical alerts
   - Application-level metrics

3. **Backup Automation:**
   - Velero for cluster backups
   - Scheduled MySQL dumps to S3
   - Longhorn snapshot schedules

4. **CI/CD Integration:**
   - GitOps with ArgoCD or Flux
   - Automated testing pipeline
   - Blue/Green or Canary deployments

5. **Security Hardening:**
   - Pod Security Standards/Policies
   - Network policies between namespaces
   - Image scanning (Trivy/Clair)
   - Secrets encryption at rest

## Tradeoffs Summary

| Decision | Chosen | Alternative | Rationale |
|----------|--------|-------------|-----------|
| **Provisioning** | Terraform + Proxmox | Managed K8s | Cost, learning, control |
| **Storage** | Longhorn | NFS | Cloud-native, replication |
| **Load Balancer** | MetalLB L2 | BGP | Simplicity, no router config |
| **Ingress** | Contour | nginx | Performance, observability |
| **DNS** | External-DNS | Manual | Automation, GitOps |
| **Certificates** | cert-manager | Manual/Self-signed | Production-ready, automation |
| **Secrets** | SecretGen | Manual | Rotation, cross-namespace |
| **Database** | Dedicated MySQL | Embedded | Separation, shared resource |
| **WordPress Deploy** | Helm | Raw YAML | Reusability, templating |
| **RBAC** | Service Accounts | Admin | Security, least privilege |

## Getting Started

For complete installation instructions, see [INSTALL.md](INSTALL.md).

For RBAC and service account management, see the `rbac/` directory.

## Future Improvements

1. **Multi-tenancy**: Support multiple WordPress sites with tenant isolation
2. **Auto-scaling**: HPA for WordPress based on CPU/memory
3. **CDN Integration**: CloudFront or similar for static asset delivery
4. **Database HA**: MySQL replication or migration to managed RDS
5. **Object Storage**: S3 backend for WordPress media uploads
6. **Monitoring**: Full observability stack (Prometheus, Grafana, Loki)
7. **Disaster Recovery**: Cross-region backup and restore procedures
