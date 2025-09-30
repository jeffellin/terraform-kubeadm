# Terraform Kubeadm

## RBAC Configurations

### WordPress Port-Forward Access

To port-forward to WordPress pods, use the dedicated service account with minimal permissions:

```bash
# Apply the RBAC configuration
kubectl apply -f rbac/wordpress-portforward-rbac.yaml

# Port-forward using the service account
kubectl port-forward --as=system:serviceaccount:default:wordpress-portforward pod/wordpress-xxx 8080:80
```

**Permissions granted:**
- `pods`: get, list (to identify target pods)
- `pods/portforward`: create, get (to establish port-forward)

### Creating Service Account Kubeconfig

To create a kubeconfig file for a specific service account:

```bash
# Usage: ./rbac/create-sa-kubeconfig.sh <namespace> <serviceaccount-name>
./rbac/create-sa-kubeconfig.sh default wordpress-portforward

# Export the generated kubeconfig
export KUBECONFIG=$(pwd)/wordpress-portforward.kubeconfig

# Verify access
kubectl auth can-i --list
```

The script generates a kubeconfig file named `<serviceaccount-name>.kubeconfig` with a token for the specified service account.