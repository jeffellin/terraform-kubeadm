# Client Certificate Authentication - Namespace Access

This guide demonstrates how to create namespace-scoped kubectl access using client certificates with fine-grained RBAC permissions. Client certificates provide user identity without requiring service accounts or bearer tokens.

## Overview

Client certificate authentication provides:
- User identities with namespace-specific permissions
- No need to manage or rotate bearer tokens
- Better audit trails (username appears in Kubernetes audit logs)
- Browser-based authentication for Dashboard access (optional)

## Prerequisites

- Kubernetes cluster running with client certificate authentication enabled
- Admin access to the cluster
- OpenSSL installed locally

## Apply RBAC Configuration

First, apply the RBAC roles and bindings to set up all permissions:

```bash
# Apply client certificate RBAC for wordpress namespace
kubectl apply -f rbac/wordpress-client-cert-rbac.yaml
```

This creates:
- **edit-existing-only** ClusterRole: Allows update/patch/delete but NOT create
- **wordpress-admins-binding** RoleBinding: Maps wordpress-admins group to admin ClusterRole (full access)
- **wordpress-editors-binding** RoleBinding: Maps wordpress-editors group to edit-existing-only ClusterRole (modify only)
- **wordpress-viewers-binding** RoleBinding: Maps wordpress-viewers group to view ClusterRole (read-only)

## Create User Certificates

Now generate certificates for each user. The script only creates certificates and CSRs - RBAC is managed separately in the YAML file above.

### Create alice-admin (full admin access to wordpress namespace)

```bash
cd infra/dashboard

# Create alice-admin certificate
./client-cert-namespace.sh alice-admin wordpress-admins wordpress admin

# This creates:
# - dashboard-client-certs/alice-admin.p12 (browser import)
# - dashboard-client-certs/alice-admin-cert.pem (client certificate)
# - dashboard-client-certs/alice-admin-key.pem (private key)
```

### Create carol-editor (edit existing resources only, cannot create new)

```bash
# Create carol-editor certificate
./client-cert-namespace.sh carol-editor wordpress-editors wordpress edit-existing-only

# This creates:
# - dashboard-client-certs/carol-editor.p12
# - dashboard-client-certs/carol-editor-cert.pem
# - dashboard-client-certs/carol-editor-key.pem
```

### Create bob-viewer (read-only access)

```bash
# Create bob-viewer certificate
./client-cert-namespace.sh bob-viewer wordpress-viewers wordpress view

# This creates:
# - dashboard-client-certs/bob-viewer.p12
# - dashboard-client-certs/bob-viewer-cert.pem
# - dashboard-client-certs/bob-viewer-key.pem
```

## Permission Levels

### alice-admin (admin role)
- Full access to all resources in wordpress namespace
- Can create, read, update, delete all resources
- Can manage roles and rolebindings within the namespace
- **Cannot** access other namespaces or cluster resources

### carol-editor (edit-existing-only role)
- Can view, update, patch, and delete existing resources
- **Cannot** create new resources (deployments, services, etc.)
- Useful for operators who modify configurations but don't deploy new apps
- **Cannot** access other namespaces

### bob-viewer (view role)
- Read-only access to all resources in wordpress namespace
- Can view pods, services, deployments, logs, etc.
- **Cannot** modify or delete anything
- **Cannot** access other namespaces

## Create Kubeconfig for CLI Access

Generate kubeconfig files for each user:

```bash
# Create kubeconfig for alice-admin
./access-with-client-cert-identity.sh alice-admin

# Create kubeconfig for carol-editor
./access-with-client-cert-identity.sh carol-editor

# Create kubeconfig for bob-viewer
./access-with-client-cert-identity.sh bob-viewer
```

This creates kubeconfig files in `dashboard-client-certs/`:
- `alice-admin-dashboard.kubeconfig`
- `carol-editor-dashboard.kubeconfig`
- `bob-viewer-dashboard.kubeconfig`

## Test User Permissions

### Test alice-admin (full admin)

```bash
# Set KUBECONFIG (use absolute path or ensure you're in project root)
export KUBECONFIG=$(pwd)/infra/dashboard/dashboard-client-certs/alice-admin-dashboard.kubeconfig

# Verify kubeconfig is set correctly
kubectl config current-context

# Should succeed - full access:
kubectl get pods -n wordpress
kubectl get deployments -n wordpress
kubectl create configmap test --from-literal=foo=bar -n wordpress
kubectl delete configmap test -n wordpress
kubectl scale deployment wordpress --replicas=2 -n wordpress

# Should fail - wrong namespace or cluster resources:
kubectl get pods -n default           # no (different namespace)
kubectl get nodes                      # no (cluster resource)
```

### Test carol-editor (edit existing only)

```bash
# Set KUBECONFIG (use absolute path or ensure you're in project root)
export KUBECONFIG=$(pwd)/infra/dashboard/dashboard-client-certs/carol-editor-dashboard.kubeconfig

# Verify kubeconfig is set correctly
kubectl config current-context

# Should succeed - can view and modify existing:
kubectl get pods -n wordpress
kubectl get deployments -n wordpress
kubectl scale deployment wordpress --replicas=3 -n wordpress
kubectl patch deployment wordpress -n wordpress -p '{"spec":{"replicas":2}}'
kubectl delete pod <pod-name> -n wordpress

# Should fail - cannot create new resources:
kubectl create configmap test --from-literal=foo=bar -n wordpress  # no
kubectl create deployment nginx --image=nginx -n wordpress         # no
kubectl get pods -n default                                        # no (different namespace)
```

### Test bob-viewer (read-only)

```bash
# Set KUBECONFIG (use absolute path or ensure you're in project root)
export KUBECONFIG=$(pwd)/infra/dashboard/dashboard-client-certs/bob-viewer-dashboard.kubeconfig

# Verify kubeconfig is set correctly
kubectl config current-context

# Should succeed - read-only access:
kubectl get pods -n wordpress
kubectl get deployments -n wordpress
kubectl get services -n wordpress
kubectl logs <pod-name> -n wordpress
kubectl describe pod <pod-name> -n wordpress

# Should fail - no write permissions:
kubectl delete pod <pod-name> -n wordpress                    # no
kubectl scale deployment wordpress --replicas=2 -n wordpress  # no
kubectl create configmap test --from-literal=foo=bar -n wordpress  # no
kubectl get pods -n default                                   # no (different namespace)
```

## Verify RBAC Permissions

Use `kubectl auth can-i` to verify permissions:

```bash
# Switch back to admin kubeconfig
unset KUBECONFIG

# Check alice-admin permissions
kubectl auth can-i --list --as=alice-admin --as-group=wordpress-admins -n wordpress
kubectl auth can-i create deployments --as=alice-admin --as-group=wordpress-admins -n wordpress  # yes
kubectl auth can-i delete pods --as=alice-admin --as-group=wordpress-admins -n wordpress  # yes

# Check carol-editor permissions
kubectl auth can-i --list --as=carol-editor --as-group=wordpress-editors -n wordpress
kubectl auth can-i update deployments --as=carol-editor --as-group=wordpress-editors -n wordpress  # yes
kubectl auth can-i create deployments --as=carol-editor --as-group=wordpress-editors -n wordpress  # no
kubectl auth can-i delete pods --as=carol-editor --as-group=wordpress-editors -n wordpress  # yes

# Check bob-viewer permissions
kubectl auth can-i --list --as=bob-viewer --as-group=wordpress-viewers -n wordpress
kubectl auth can-i get pods --as=bob-viewer --as-group=wordpress-viewers -n wordpress  # yes
kubectl auth can-i delete pods --as=bob-viewer --as-group=wordpress-viewers -n wordpress  # no
kubectl auth can-i create anything --as=bob-viewer --as-group=wordpress-viewers -n wordpress  # no
```

## Certificate Cleanup

Remove user access by deleting certificates and RBAC:

```bash
# Delete CSRs
kubectl delete csr alice-admin
kubectl delete csr carol-editor
kubectl delete csr bob-viewer

# Delete RBAC (removes all three users)
kubectl delete -f rbac/wordpress-client-cert-rbac.yaml

# Remove local certificate files
rm -rf infra/dashboard/dashboard-client-certs/
```

## Security Considerations

1. **Certificate Expiration**: Default 365 days (configurable with 5th parameter)
2. **Secure Storage**: Keep `.p12` and `.pem` files secure - they grant cluster access
3. **Namespace Isolation**: Users cannot access resources outside wordpress namespace
4. **Least Privilege**: Each role has minimum necessary permissions
5. **Audit Logging**: Username appears in Kubernetes audit logs for accountability
6. **No Token Management**: No need to retrieve or rotate bearer tokens

## Related Documentation

- [RBAC Guide](RBAC_GUIDE.md) - Service account-based access control
- [Installation Guide](../INSTALLATION.md) - Full cluster setup including security
- [Back to Main Docs](../../README.md) - Main documentation
