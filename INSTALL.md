# Installation Guide

This guide covers the complete installation process from infrastructure provisioning to application deployment.

## Infrastructure Setup

### Step 0: Provision Kubernetes Cluster with Terraform

The Kubernetes cluster is created using Terraform on Proxmox with cloud-init automation.

**Cluster configuration:**
- 1 master node (k8s-master-1) at 192.168.1.200
- 2 worker nodes (k8s-worker-1, k8s-worker-2) at 192.168.1.201-202
- Automatic cluster initialization via cloud-init
- CNI and runtime configured automatically

**To deploy the cluster:**

```bash
cd kubeadm/proxmox

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox settings

# Deploy
terraform init
terraform plan
terraform apply
```

**To retrieve kubeconfig:**

```bash
# From the kubeadm directory
./get-kubeconfig.sh

# Or SSH to master and copy
ssh ubuntu@192.168.1.200
cat ~/.kube/config
```

See [kubeadm/README.md](kubeadm/README.md) for detailed Terraform configuration options.

---

## Post-Cluster Installation

After the Kubernetes cluster is running, install infrastructure components in the following order.

### Prerequisites

- Kubernetes cluster running and healthy
- `kubectl` configured with cluster admin access
- `helm` v3.x installed locally
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

### 4. Secrets Namespace

Create the shared secrets namespace used by SecretGen for password generation.

```bash
kubectl create namespace secrets
```

**Verify:**
```bash
kubectl get namespace secrets
```

---

### 5. SecretGen - Secret Generation Controller

SecretGen controller helps manage secret generation.

```bash
kubectl apply -f infra/secretgen/secretgen-controller-app.yaml
```

**Verify:**
```bash
kubectl get pods -n secretgen-controller
```

---

### 6. AWS Secrets - Credentials for AWS Services

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

### 7. Cert-Manager - TLS Certificate Management

Cert-manager automates TLS certificate provisioning and depends on AWS credentials for Route53 DNS challenges.

```bash
./infra/cert-manager/install.sh
```

**Verify:**
```bash
kubectl get pods -n cert-manager
```

---

### 8. Kubernetes Dashboard - Cluster Management UI

Install the Kubernetes Dashboard for web-based cluster management.

```bash
./infra/dashboard/install.sh
```

**Create admin user:**
```bash
kubectl apply -f infra/dashboard/dashboard-admin.yaml
```

**Get access token:**
```bash
kubectl -n kubernetes-dashboard create token admin-user
```

**Access dashboard:**
```bash
kubectl proxy
# Then open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

**Verify:**
```bash
kubectl get pods -n kubernetes-dashboard
```

---

### 9. Let's Encrypt ClusterIssuers - Certificate Issuers

Setup Let's Encrypt certificate issuers with Route53 DNS challenge.

```bash
./infra/cert-manager/setup-letsencrypt-issuer.sh
```

**Verify:**
```bash
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-prod
```

---

### 10. External-DNS - Automatic DNS Management

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

### Prerequisites for Application Deployment

Set your kubeconfig to use admin access:

```bash
export KUBECONFIG=~/dev/terraform-kubeadm/kubeadm/kubeconfig
```

### 11. MySQL - Database

MySQL is deployed in the `mysql` namespace and requires Longhorn for persistent storage.

**Features:**
- Password generated by SecretGen in `secrets` namespace
- Secret imported from `secrets` namespace to `mysql` namespace
- Persistent storage via Longhorn PVC
- Initialization ConfigMap for WordPress database setup

```bash
kubectl apply -f app/mysql/
```

This creates:
- `secrets` namespace with Password resource
- `mysql` namespace with MySQL deployment
- SecretImport to get the password from `secrets` namespace

**Wait for MySQL to be ready:**
```bash
kubectl get pods -n mysql -l app=wordpress,tier=mysql -w
```

**Verify:**
```bash
kubectl get pods -n mysql
kubectl get secret mysql-pass -n secrets  # Source secret
kubectl get secret mysql-pass -n mysql   # Imported secret
```

---

### 12. WordPress - Application

WordPress is deployed in the `wordpress` namespace using a Helm chart. It depends on MySQL running in the `mysql` namespace and requires storage from Longhorn.

**Features:**
- Deployed via Helm chart
- Connects to MySQL via cross-namespace service DNS (`wordpress-mysql.mysql.svc.cluster.local`)
- Imports MySQL password secret from `secrets` namespace
- Persistent storage for WordPress files (Longhorn)
- Service account with minimal permissions (`automountServiceAccountToken: false`)
- Optional ingress support

**Create namespace and apply RBAC:**

```bash
# Create the wordpress namespace
kubectl create namespace wordpress

# Apply RBAC for wordpress-deployer service account
kubectl apply -f rbac/wordpress-rbac.yaml

# Create kubeconfig for wordpress-deployer service account
./create-sa-kubeconfig.sh wordpress wordpress-deployer

# Use the wordpress-deployer kubeconfig for deployment
export KUBECONFIG=$(pwd)/wordpress-deployer.kubeconfig

# Verify you're using the correct service account
kubectl auth whoami
```

**Install WordPress using Helm:**

```bash
# Install WordPress using Helm
helm install wordpress ./app/wordpress -n wordpress

# Or install with custom values
helm install wordpress ./app/wordpress -n wordpress --values custom-values.yaml

# Or override specific values
helm install wordpress ./app/wordpress -n wordpress \
  --set image.tag=6.2.1-apache \
  --set persistence.size=5Gi \
  --set service.type=LoadBalancer
```

This creates:
- `wordpress` namespace (created separately)
- `wordpress-deployer` ServiceAccount with deployment permissions
- SecretImport to get MySQL password from `secrets` namespace
- WordPress deployment with PVC for persistent data
- Service (NodePort by default, configurable to LoadBalancer)
- ServiceAccount with restricted permissions

**Verify:**
```bash
kubectl get pods -n wordpress
kubectl get svc -n wordpress
kubectl get pvc -n wordpress
kubectl get secret mysql-pass -n wordpress  # Imported secret

# View Helm release status
helm status wordpress -n wordpress
helm list -n wordpress
```

**Access WordPress via Port-Forward with RBAC:**

```bash
# Switch back to admin kubeconfig
unset KUBECONFIG
export KUBECONFIG=/Users/jeff/dev/terraform-kubeadm/kubeadm/kubeconfig

# Apply wordpress-portforward RBAC
kubectl apply -f rbac/wordpress-portforward-rbac.yaml

# Create kubeconfig for wordpress-portforward service account
./create-sa-kubeconfig.sh wordpress wordpress-portforward

# Use the wordpress-portforward kubeconfig
export KUBECONFIG=$(pwd)/wordpress-portforward.kubeconfig

# Verify you're using the correct service account
kubectl auth whoami

# Port-forward to access WordPress
kubectl port-forward -n wordpress svc/wordpress 8080:80

# Access WordPress at http://localhost:8080
```

**Update WordPress Site URL for HTTPS:**

After verifying port-forward access and if you have TLS configured for your ingress, update the WordPress site URLs to use HTTPS:

```bash
# Switch back to admin kubeconfig
unset KUBECONFIG
export KUBECONFIG=/Users/jeff/dev/terraform-kubeadm/kubeadm/kubeconfig

# Get the MySQL pod name
MYSQL_POD=$(kubectl get pods -n mysql -l app=wordpress,tier=mysql -o jsonpath='{.items[0].metadata.name}')

# Update WordPress URLs to use HTTPS
kubectl exec -n mysql $MYSQL_POD -- sh -c 'mysql -uwordpress -p"$MYSQL_ROOT_PASSWORD" wordpress -e "UPDATE wp_options SET option_value=\"https://wordpress.ellin.net\" WHERE option_name IN (\"siteurl\", \"home\");"'

# Verify the URLs were updated
kubectl exec -n mysql $MYSQL_POD -- sh -c 'mysql -uwordpress -p"$MYSQL_ROOT_PASSWORD" wordpress -e "SELECT option_name, option_value FROM wp_options WHERE option_name IN (\"siteurl\", \"home\");"'
```

**Note:** Replace `wordpress.ellin.net` with your actual domain name.

**Upgrade WordPress:**
```bash
# Modify values and upgrade
helm upgrade wordpress ./app/wordpress -n wordpress

# Or upgrade with new values
helm upgrade wordpress ./app/wordpress -n wordpress --set replicaCount=2
```

**Uninstall:**
```bash
helm uninstall wordpress -n wordpress
```

---

### 13. WordPress Stats API (Optional)

A Go-based REST API that provides WordPress user statistics by querying the MySQL database directly.

**Features:**
- Queries WordPress database for user post statistics
- Containerized Go application
- Kubernetes deployment with LoadBalancer service
- Optional TLS certificate via cert-manager
- Optional ingress with external-dns

```bash
# Deploy the API application
kubectl apply -f app/api/k8s-configmap.yaml
kubectl apply -f app/api/k8s-deployment.yaml
kubectl apply -f app/api/k8s-service.yaml

# Optional: Deploy with TLS certificate
kubectl apply -f app/api/certificate.yaml

# Optional: Deploy with ingress
kubectl apply -f app/api/k8s-ingress.yaml
```

**Verify:**
```bash
kubectl get pods -l app=wordpress-stats-api -n wordpress
kubectl get svc wordpress-stats-api -n wordpress
kubectl logs -l app=wordpress-stats-api -n wordpress
```

**Test the API:**
```bash
# Get service endpoint
kubectl get svc wordpress-stats-api -n wordpress
curl https://api.wordpress.ellin.net/api/userinfo
curl https://api.wordpress.ellin.net/api/userinfo?user=admin
```

See [api/README.md](api/README.md) for API documentation and configuration options.

---

### 14. RBAC Configuration (Optional)

This guide demonstrates how to use the `wordpress-deployer` and `wordpress-portforward` roles to deploy and access WordPress with proper RBAC permissions.

#### RBAC Roles Overview

**wordpress-deployer Role:**
- **Scope**: wordpress namespace only
- **Permissions**:
  - Full CRUD on: deployments, services, PVCs, configmaps, secrets
  - Read-only on: replicasets, pods, pod logs
- **Use case**: Deploy and manage WordPress applications

**wordpress-portforward Role:**
- **Scope**: wordpress namespace only
- **Permissions**:
  - Read-only on: pods
  - Port-forward access: pods/portforward
- **Use case**: Access WordPress via port-forwarding without deployment permissions

#### Apply RBAC Configurations

```bash
# Apply the wordpress-deployer RBAC (for deployment)
kubectl apply -f rbac/wordpress-rbac.yaml

# Apply the wordpress-portforward RBAC (for port-forwarding)
kubectl apply -f rbac/wordpress-portforward-rbac.yaml
```

#### Create Kubeconfig for wordpress-deployer

```bash
# Generate kubeconfig for wordpress-deployer service account
./create-sa-kubeconfig.sh wordpress wordpress-deployer
```

This creates `wordpress-deployer.kubeconfig` file.

#### Deploy WordPress using wordpress-deployer Role

```bash
# Use the wordpress-deployer kubeconfig
export KUBECONFIG=$(pwd)/wordpress-deployer.kubeconfig

# Verify you're using the correct context
kubectl config current-context

# Navigate to the WordPress Helm chart directory
cd ../app/wordpress

# Install WordPress using the custom Helm chart
helm install wordpress . \
  --namespace wordpress \
  --set database.host=wordpress-mysql.mysql.svc.cluster.local \
  --set database.name=wordpress \
  --set database.user=wordpress \
  --set database.secretName=mysql-pass \
  --set database.secretKey=password \
  --set persistence.storageClassName=longhorn \
  --set persistence.size=1Gi \
  --set service.type=NodePort

# Verify deployment
kubectl get deployments -n wordpress
kubectl get pods -n wordpress
kubectl get services -n wordpress
kubectl get pvc -n wordpress

# Check Helm release status
helm list -n wordpress
```

**Alternative: Deploy with Custom Values File**

Create a custom values file:

```bash
cat > custom-values.yaml <<EOF
replicaCount: 1

image:
  repository: wordpress
  tag: "6.2.1-apache"
  pullPolicy: IfNotPresent

service:
  type: NodePort
  port: 80

database:
  host: wordpress-mysql.mysql.svc.cluster.local
  name: wordpress
  user: wordpress
  secretName: mysql-pass
  secretKey: password

persistence:
  enabled: true
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  size: 1Gi
  mountPath: /var/www/html
EOF

# Install with custom values
helm install wordpress . -f custom-values.yaml --namespace wordpress
```

#### Create Kubeconfig for wordpress-portforward

```bash
# Switch back to admin kubeconfig
unset KUBECONFIG

# Generate kubeconfig for wordpress-portforward service account
./create-sa-kubeconfig.sh wordpress wordpress-portforward
```

This creates `wordpress-portforward.kubeconfig` file.

#### Access WordPress using Port-Forward

```bash
# Use the wordpress-portforward kubeconfig
export KUBECONFIG=$(pwd)/wordpress-portforward.kubeconfig

# Get the WordPress pod name
kubectl get pods -n wordpress

# Port-forward to access WordPress (replace POD_NAME with actual pod name)
kubectl port-forward -n wordpress POD_NAME 8080:80

# Access WordPress at http://localhost:8080
```

#### Verify RBAC Permissions

**Test wordpress-deployer Permissions:**

```bash
export KUBECONFIG=$(pwd)/wordpress-deployer.kubeconfig

# These should SUCCEED:
kubectl get deployments -n wordpress
kubectl get services -n wordpress
kubectl create configmap test-config --from-literal=key=value -n wordpress
kubectl delete configmap test-config -n wordpress

# These should FAIL (insufficient permissions):
kubectl get pods -n default  # Wrong namespace
kubectl get nodes  # Cluster-level resource
```

**Test wordpress-portforward Permissions:**

```bash
export KUBECONFIG=$(pwd)/wordpress-portforward.kubeconfig

# These should SUCCEED:
kubectl get pods -n wordpress
kubectl port-forward -n wordpress wordpress-xxxx 8080:80

# These should FAIL:
kubectl get deployments -n wordpress  # No permission
kubectl delete pod wordpress-xxxx -n wordpress  # No permission
kubectl get pods -n default  # Wrong namespace
```

#### RBAC Cleanup

```bash
# Switch back to admin kubeconfig
unset KUBECONFIG

# Uninstall WordPress Helm release
helm uninstall wordpress -n wordpress

# Delete RBAC resources
kubectl delete -f rbac/wordpress-rbac.yaml
kubectl delete -f rbac/wordpress-portforward-rbac.yaml

# Remove kubeconfig files
rm -f wordpress-deployer.kubeconfig wordpress-portforward.kubeconfig

# Remove custom values file if created
rm -f custom-values.yaml
```

#### Security Best Practices

1. **Least Privilege**: Each role has only the minimum permissions needed
2. **Namespace Isolation**: Roles are scoped to wordpress namespace only
3. **Separation of Duties**: Deployer and viewer roles are separate
4. **Token Rotation**: Service account tokens should be rotated periodically
5. **Audit**: Monitor usage of these service accounts in audit logs

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

**Option 1: Via NodePort**
```bash
kubectl get svc -n wordpress wordpress
# Access via http://<node-ip>:<node-port>
```

**Option 2: Via LoadBalancer** (if service type is LoadBalancer)
```bash
kubectl get svc -n wordpress wordpress
# Wait for EXTERNAL-IP (MetalLB assigns from pool 192.168.1.220-225)
# Access via http://<external-ip>
```

**Option 3: Via Port-Forward** (for local development)
```bash
kubectl port-forward -n wordpress svc/wordpress 8080:80
# Access at http://localhost:8080
```

**Option 4: Via Port-Forward with RBAC** (restricted access)
```bash
./create-sa-kubeconfig.sh wordpress wordpress-portforward
export KUBECONFIG=$(pwd)/wordpress-portforward.kubeconfig
kubectl port-forward -n wordpress svc/wordpress 8080:80
# Access at http://localhost:8080
```

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

## Installation Summary

### Complete Installation Order

1. **Infrastructure provisioning** (Terraform) - Creates Kubernetes cluster
2. **Longhorn** - Storage provider (required by MySQL, WordPress, and other apps)
3. **MetalLB** - Load balancer (required by Contour, optional for services)
4. **Contour** - Ingress controller (requires MetalLB)
5. **Secrets Namespace** - Shared namespace for SecretGen-managed secrets
6. **SecretGen** - Secret generation controller (used by MySQL)
7. **AWS Secrets** - Credentials (required by cert-manager and external-dns)
8. **Cert-Manager** - TLS certificates (requires AWS secrets)
9. **Dashboard** - Kubernetes Dashboard UI
10. **Let's Encrypt ClusterIssuers** - Certificate issuers (requires cert-manager)
11. **External-DNS** - Automatic DNS management (requires AWS secrets)
12. **MySQL** - Database (requires Longhorn, uses SecretGen)
13. **WordPress** - Application (requires MySQL and Longhorn)
14. **API** - WordPress Stats API (optional, requires MySQL)
15. **RBAC** - Access controls (optional)

### Key Dependencies

- **Terraform/Proxmox** → Creates the base Kubernetes cluster
- **Longhorn** → Must be ready before deploying apps with PVCs (MySQL, WordPress)
- **MetalLB** → Must be ready before Contour; provides LoadBalancer IPs (pool: 192.168.1.220-225)
- **Contour** → Depends on MetalLB for LoadBalancer service
- **AWS Secrets** → Must exist before cert-manager and external-dns
- **Cert-Manager** → Required for TLS certificates via Let's Encrypt
- **SecretGen** → Required for MySQL password generation in `secrets` namespace
- **MySQL** → Must be ready in `mysql` namespace before WordPress; imports secret from `secrets`
- **WordPress** → Depends on MySQL and imports secret from `secrets` namespace

### Network Configuration

- **Cluster Network**: 192.168.1.0/24
- **Master Node**: 192.168.1.200
- **Worker Nodes**: 192.168.1.201-202
- **MetalLB Pool**: 192.168.1.220-225
- **Gateway**: 192.168.1.1

### Namespace Organization

- `longhorn-system` - Longhorn storage provider
- `metallb-system` - MetalLB load balancer
- `projectcontour` - Contour ingress controller
- `secretgen-controller` - SecretGen controller
- `secrets` - Shared secrets managed by SecretGen (MySQL password)
- `cert-manager` - Certificate management
- `external-dns` - DNS automation
- `kubernetes-dashboard` - Dashboard UI
- `mysql` - MySQL database
- `wordpress` - WordPress application
- `default` - WordPress Stats API (if deployed)