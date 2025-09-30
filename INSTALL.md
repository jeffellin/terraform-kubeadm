# Installation Guide

This guide covers the installation order for all components after the Kubernetes cluster has been initialized.

## Prerequisites

- Kubernetes cluster installed and configured
- `kubectl` configured to communicate with the cluster
- `helm` v3.x installed
- AWS credentials for Route53 (for cert-manager and external-dns)

## Installation Order

### 1. Longhorn - Storage Provider

Longhorn provides persistent storage via PVCs. Install this first as applications depend on it.

```bash
./infra/longhorn/install.sh
```

**Wait for Longhorn to be ready:**
```bash
kubectl get pods -n longhorn-system -w
```

---

### 2. MetalLB - Load Balancer

MetalLB provides LoadBalancer services for bare metal clusters.

```bash
./infra/metallb/install.sh
```

**Verify:**
```bash
kubectl get pods -n metallb-system
```

---

### 3. Contour - Ingress Controller

Contour provides ingress capabilities and depends on MetalLB for its LoadBalancer service.

```bash
./infra/contour/install.sh
```

**Verify:**
```bash
kubectl get pods -n projectcontour
kubectl get svc -n projectcontour envoy
```

---

### 4. SecretGen - Secret Generation Controller

SecretGen controller helps manage secret generation.

```bash
kubectl apply -f infra/secretgen/secretgen-controller-app.yaml
```

**Verify:**
```bash
kubectl get pods -n secretgen-controller
```

---

### 5. AWS Secrets - Credentials for AWS Services

Create secrets required by cert-manager and external-dns. First, configure your credentials:

```bash
cp infra/secrets/aws-credentials.example infra/secrets/aws-credentials
# Edit aws-credentials with your actual values
```

Then create the secrets and configmap:

```bash
./infra/secrets/create-aws-secret.sh
```

**Verify:**
```bash
kubectl get secret aws-credentials -n cert-manager
kubectl get secret aws-credentials -n external-dns
kubectl get configmap external-dns-config -n external-dns
```

---

### 6. Cert-Manager - TLS Certificate Management

Cert-manager automates TLS certificate provisioning and depends on AWS credentials for Route53 DNS challenges.

```bash
./infra/cert-manager/install.sh
```

**Verify:**
```bash
kubectl get pods -n cert-manager
```

---

### 7. External-DNS - Automatic DNS Management

External-DNS automatically manages DNS records in Route53 and depends on AWS credentials.

```bash
./infra/external-dns/install.sh
```

**Verify:**
```bash
kubectl get pods -n external-dns
```

---

## Application Deployment

After infrastructure components are ready, deploy applications.

### 8. RBAC Configuration

Apply RBAC configurations for applications:

```bash
kubectl apply -f rbac/wordpress-rbac.yaml
kubectl apply -f rbac/wordpress-portforward-rbac.yaml
```

---

### 9. MySQL - Database

MySQL requires Longhorn for persistent storage.

```bash
kubectl apply -f app/mysql/
```

**Wait for MySQL to be ready:**
```bash
kubectl get pods -l app=wordpress,tier=mysql -w
```

---

### 10. WordPress - Application

WordPress depends on MySQL and requires storage from Longhorn. WordPress is deployed using a Helm chart.

```bash
# Install WordPress using Helm
helm install wordpress ./app/wordpress

# Or install with custom values
helm install wordpress ./app/wordpress --values custom-values.yaml

# Or override specific values
helm install wordpress ./app/wordpress \
  --set image.tag=6.2.1-apache \
  --set persistence.size=5Gi \
  --set service.type=LoadBalancer
```

**Verify:**
```bash
kubectl get pods -l app=wordpress,tier=frontend
kubectl get svc wordpress

# View Helm release status
helm status wordpress
helm list
```

**Upgrade WordPress:**
```bash
# Modify values and upgrade
helm upgrade wordpress ./app/wordpress

# Or upgrade with new values
helm upgrade wordpress ./app/wordpress --set replicaCount=2
```

**Uninstall:**
```bash
helm uninstall wordpress
```

---

### 11. NGINX - Web Server

Deploy NGINX if needed:

```bash
kubectl apply -f app/nginx/
```

---

## Post-Installation

### Verify All Components

```bash
# Check all namespaces
kubectl get pods --all-namespaces

# Check storage classes
kubectl get storageclass

# Check ingress
kubectl get ingress --all-namespaces

# Check certificates
kubectl get certificates --all-namespaces
```

### Access WordPress

```bash
# Get NodePort
kubectl get svc wordpress

# Or use port-forward with restricted SA
./rbac/create-sa-kubeconfig.sh default wordpress-portforward
export KUBECONFIG=$(pwd)/wordpress-portforward.kubeconfig
kubectl port-forward svc/wordpress 8080:80
```

Then access WordPress at `http://localhost:8080`

---

## Troubleshooting

### Check Component Status

```bash
# Longhorn
kubectl get pods -n longhorn-system

# MetalLB
kubectl get pods -n metallb-system

# Contour
kubectl get pods -n projectcontour

# Cert-Manager
kubectl get pods -n cert-manager

# External-DNS
kubectl get pods -n external-dns
```

### Check Logs

```bash
kubectl logs -n <namespace> <pod-name>
```

### Verify RBAC

```bash
# Using a service account kubeconfig
kubectl auth can-i --list
```

---

## Key Dependencies

- **Longhorn** → Must be ready before deploying apps with PVCs
- **MetalLB** → Must be ready before Contour
- **AWS Secrets** → Must exist before cert-manager and external-dns
- **MySQL** → Must be ready before WordPress
- **Contour** → Depends on MetalLB for LoadBalancer service