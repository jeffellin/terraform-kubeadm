# Infrastructure Components Overview

This section documents all infrastructure components installed and configured on your Kubernetes cluster.

## Component Stack

### Core Kubernetes Infrastructure

The following components are automatically installed via the installation process:

1. **Longhorn** - Distributed block storage
2. **MetalLB** - Load balancer for bare metal clusters
3. **Contour** - Ingress controller
4. **Cert-Manager** - TLS certificate automation
5. **External-DNS** - Automatic DNS record management
6. **Kubernetes Dashboard** - Web-based cluster management

### Installation Order & Dependencies

Components must be installed in a specific order due to dependencies:

```
1. Longhorn (storage provider)
   └── Required by: MySQL, WordPress, and other applications

2. MetalLB (load balancer)
   └── Required by: Contour (for its LoadBalancer service)

3. Contour (ingress controller)
   └── Depends on: MetalLB
   └── Required by: Applications needing ingress

4. Secrets Namespace (shared namespace)
   └── Required by: SecretGen password management

5. SecretGen (secret generation controller)
   └── Required by: MySQL password generation

6. AWS Secrets (credentials)
   └── Required by: Cert-Manager, External-DNS

7. Cert-Manager (TLS certificates)
   └── Depends on: AWS Secrets

8. Dashboard (web UI)
   └── No hard dependencies

9. Let's Encrypt Issuers (certificate issuers)
   └── Depends on: Cert-Manager

10. External-DNS (DNS automation)
    └── Depends on: AWS Secrets, Cert-Manager
```

## Component Details

### Storage

#### Longhorn
- **Purpose**: Distributed block storage for persistent volumes
- **Replicas**: Configurable (default: 3)
- **Features**: Snapshots, backups, incremental recovery
- **Documentation**: [Longhorn Setup Guide](LONGHORN.md)
- **Namespace**: `longhorn-system`
- **UI Access**: `kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80`

### Load Balancing

#### MetalLB
- **Purpose**: Provides LoadBalancer service type support for bare metal
- **IP Pool**: 192.168.1.220-225 (configurable)
- **Namespace**: `metallb-system`
- **Required**: Must be installed before Contour

### Ingress

#### Contour
- **Purpose**: Ingress controller for HTTP/HTTPS routing
- **Type**: Envoy-based
- **Namespace**: `projectcontour`
- **Service Type**: LoadBalancer (via MetalLB)
- **Features**: Virtual hosts, TLS termination, load balancing

### Certificate Management

#### Cert-Manager
- **Purpose**: Automates TLS certificate provisioning and renewal
- **Issuers**: Let's Encrypt (staging and production)
- **DNS Challenge**: Route53 (AWS)
- **Namespace**: `cert-manager`
- **Requires**: AWS credentials for Route53 access

#### Let's Encrypt Issuers
- **Purpose**: Certificate authorities for TLS
- **Staging**: For testing (unlimited certificates, browser warnings)
- **Production**: For live environments (rate-limited, trusted)
- **Challenge Type**: DNS01 via Route53

### DNS Management

#### External-DNS
- **Purpose**: Automatically creates/updates DNS records in Route53
- **Watched Resources**: Services and Ingresses
- **Namespace**: `external-dns`
- **Requires**: AWS credentials and properly configured ClusterRole

### Cluster Management

#### Kubernetes Dashboard
- **Purpose**: Web-based UI for cluster management
- **Namespace**: `kubernetes-dashboard`
- **Access**: Through proxy or port-forward
- **Authentication**: Token-based or client certificates

### Secret Management

#### SecretGen Controller
- **Purpose**: Generates random passwords and manages secrets
- **Namespace**: `secretgen-controller`
- **Use Case**: MySQL password generation
- **Shared Namespace**: `secrets` (holds generated passwords)
- **Feature**: SecretImport for cross-namespace access

### AWS Integration

#### AWS Credentials
- **Purpose**: Enables integration with AWS services
- **Services Using**: Cert-Manager (Route53), External-DNS (Route53)
- **Storage**: Kubernetes secrets in respective namespaces
- **Location**:
  - `cert-manager` namespace: `aws-credentials` secret
  - `external-dns` namespace: `aws-credentials` secret

## Network Configuration

### IP Ranges

- **Cluster Network**: 192.168.1.0/24
- **Master Node**: 192.168.1.200
- **Worker Nodes**: 192.168.1.201-202 (configurable)
- **MetalLB Pool**: 192.168.1.220-225 (configurable)
- **Gateway**: 192.168.1.1 (configurable)

### CNI (Container Network Interface)

- **Provider**: Calico (installed by kubeadm during cluster initialization)
- **Pod CIDR**: 10.244.0.0/16 (default)
- **Service CIDR**: 10.96.0.0/12 (default)

## Namespace Organization

| Namespace | Purpose | Components |
|-----------|---------|------------|
| `longhorn-system` | Storage | Longhorn |
| `metallb-system` | Load Balancing | MetalLB |
| `projectcontour` | Ingress | Contour, Envoy |
| `secretgen-controller` | Secrets | SecretGen |
| `secrets` | Shared Secrets | Generated passwords |
| `cert-manager` | Certificates | Cert-Manager, Issuers |
| `external-dns` | DNS | External-DNS |
| `kubernetes-dashboard` | Management | Dashboard UI |
| `kube-system` | System | Core Kubernetes |
| `kube-public` | System | Public resources |
| `default` | Applications | User applications |

## Storage Classes

After Longhorn installation, the following storage class becomes available:

```bash
kubectl get storageclass

# Output:
# NAME      PROVISIONER
# longhorn  driver.longhorn.io
```

Set Longhorn as default:
```bash
kubectl patch storageclass longhorn \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Verifying Installation

### Check All Components

```bash
# List all pods across all namespaces
kubectl get pods -A

# Should see running pods in:
# - longhorn-system
# - metallb-system
# - projectcontour
# - secretgen-controller
# - cert-manager
# - external-dns
# - kubernetes-dashboard
# - kube-system
```

### Verify Storage

```bash
# Check storage class
kubectl get storageclass

# Test PVC creation
kubectl create pvc test-pvc -n default --size=1Gi
```

### Verify Load Balancer

```bash
# Check MetalLB
kubectl get pods -n metallb-system
kubectl get svc -n projectcontour
# Should show External IP from pool
```

### Verify Certificates

```bash
# Check cert-manager
kubectl get pods -n cert-manager

# Check issuers
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### Verify DNS

```bash
# Check external-dns
kubectl get pods -n external-dns
kubectl logs -n external-dns -l app=external-dns | grep -i route53
```

## Troubleshooting

### Component Not Running

```bash
# Check pod status
kubectl get pods -n <namespace>

# View logs
kubectl logs -n <namespace> <pod-name>

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>
```

### Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager

# Check certificate status
kubectl get cert -A
kubectl describe cert <cert-name> -n <namespace>

# Check issuers
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### DNS Resolution

```bash
# Test DNS from a pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Inside pod:
nslookup wordpress.example.com
```

### MetalLB IP Pool Issues

```bash
# Check MetalLB config
kubectl get configmap -n metallb-system

# Check if IPs are available
kubectl get svc -A | grep LoadBalancer
# Check if EXTERNAL-IP is assigned
```

## Next Steps

After infrastructure is ready:

1. Deploy applications (MySQL, WordPress, etc.)
2. Configure ingress rules
3. Set up TLS certificates
4. Configure external DNS
5. Test end-to-end functionality

See [Installation Guide](../INSTALLATION.md#application-deployment) for application deployment instructions.

## Related Documentation

- [Longhorn Setup](LONGHORN.md) - Distributed storage configuration
- [Installation Guide](../INSTALLATION.md) - Complete infrastructure deployment
- [Getting Started](../GETTING_STARTED.md) - Quick start guide
- [Back to Main Docs](../../README.md) - Main documentation

## External References

- [Longhorn Documentation](https://longhorn.io/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Contour Documentation](https://projectcontour.io/)
- [Cert-Manager Documentation](https://cert-manager.io/)
- [External-DNS Documentation](https://kubernetes-sigs.github.io/external-dns/)
- [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
