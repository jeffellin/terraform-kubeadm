# WordPress RBAC Demo

This guide demonstrates how to use the `wordpress-deployer` and `wordpress-portforward` roles to deploy and access WordPress with proper RBAC permissions.

## Prerequisites

- Kubernetes cluster is running
- `kubectl` is configured with admin access
- WordPress namespace exists

## Step 1: Create WordPress Namespace

```bash
kubectl create namespace wordpress
```

## Step 2: Apply RBAC Configurations

```bash
# Apply the wordpress-deployer RBAC (for deployment)
kubectl apply -f wordpress-rbac.yaml

# Apply the wordpress-portforward RBAC (for port-forwarding)
kubectl apply -f wordpress-portforward-rbac.yaml
```

## Step 3: Create Kubeconfig for wordpress-deployer

```bash
# Generate kubeconfig for wordpress-deployer service account
./create-sa-kubeconfig.sh wordpress wordpress-deployer
```

This creates `wordpress-deployer.kubeconfig` file.

## Step 4: Deploy WordPress using wordpress-deployer Role

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

### Alternative: Deploy with Custom Values File

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

## Step 5: Create Kubeconfig for wordpress-portforward

```bash
# Switch back to admin kubeconfig
unset KUBECONFIG

# Generate kubeconfig for wordpress-portforward service account
./create-sa-kubeconfig.sh wordpress wordpress-portforward
```

This creates `wordpress-portforward.kubeconfig` file.

## Step 6: Access WordPress using Port-Forward

```bash
# Use the wordpress-portforward kubeconfig
export KUBECONFIG=$(pwd)/wordpress-portforward.kubeconfig

# Get the WordPress pod name
kubectl get pods -n wordpress

# Port-forward to access WordPress (replace POD_NAME with actual pod name)
kubectl port-forward -n wordpress POD_NAME 8080:80

# Access WordPress at http://localhost:8080
```

## Verification

### Test wordpress-deployer Permissions

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

### Test wordpress-portforward Permissions

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

## Cleanup

```bash
# Switch back to admin kubeconfig
unset KUBECONFIG

# Uninstall WordPress Helm release
helm uninstall wordpress -n wordpress

# Delete RBAC resources
kubectl delete -f wordpress-rbac.yaml
kubectl delete -f wordpress-portforward-rbac.yaml

# Delete namespace (optional - this will remove all resources)
kubectl delete namespace wordpress

# Remove kubeconfig files
rm -f wordpress-deployer.kubeconfig wordpress-portforward.kubeconfig

# Remove custom values file if created
rm -f custom-values.yaml
```

## RBAC Summary

### wordpress-deployer Role
- **Scope**: wordpress namespace only
- **Permissions**:
  - Full CRUD on: deployments, services, PVCs, configmaps, secrets
  - Read-only on: replicasets, pods, pod logs
- **Use case**: Deploy and manage WordPress applications

### wordpress-portforward Role
- **Scope**: wordpress namespace only
- **Permissions**:
  - Read-only on: pods
  - Port-forward access: pods/portforward
- **Use case**: Access WordPress via port-forwarding without deployment permissions

## Security Best Practices

1. **Least Privilege**: Each role has only the minimum permissions needed
2. **Namespace Isolation**: Roles are scoped to wordpress namespace only
3. **Separation of Duties**: Deployer and viewer roles are separate
4. **Token Rotation**: Service account tokens should be rotated periodically
5. **Audit**: Monitor usage of these service accounts in audit logs
