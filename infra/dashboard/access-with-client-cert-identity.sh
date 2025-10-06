#!/bin/bash
set -e

# Access dashboard using client certificate identity for RBAC
# This preserves CN and O from certificate for Kubernetes RBAC

CERT_DIR="./dashboard-client-certs"
CLIENT_NAME="${1:-admin-user}"

if [ ! -f "$CERT_DIR/$CLIENT_NAME-cert.pem" ]; then
  echo "Error: Certificate not found at $CERT_DIR/$CLIENT_NAME-cert.pem"
  echo "Generate one first using: ./client-cert-namespace.sh <username> <group> <namespace> <role>"
  echo "Example: ./client-cert-namespace.sh alice-admin wordpress-admins wordpress admin"
  exit 1
fi

echo "Creating kubeconfig with client certificate..."

# Determine which kubeconfig to use
# Priority: KUBECONFIG env var, then terraform kubeconfig, then default
if [ -n "$KUBECONFIG" ]; then
  SOURCE_KUBECONFIG="$KUBECONFIG"
elif [ -f "/Users/jeff/dev/terraform-kubeadm/kubeadm/kubeconfig" ]; then
  SOURCE_KUBECONFIG="/Users/jeff/dev/terraform-kubeadm/kubeadm/kubeconfig"
  echo "Using terraform kubeconfig: $SOURCE_KUBECONFIG"
else
  SOURCE_KUBECONFIG="$HOME/.kube/config"
fi

# Get cluster info from the correct kubeconfig
CLUSTER_SERVER=$(kubectl --kubeconfig="$SOURCE_KUBECONFIG" config view --raw -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_NAME=$(kubectl --kubeconfig="$SOURCE_KUBECONFIG" config view --raw -o jsonpath='{.clusters[0].name}')
CA_DATA=$(kubectl --kubeconfig="$SOURCE_KUBECONFIG" config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Get absolute paths for certificates
CERT_ABSOLUTE_PATH="$(cd "$(dirname "$CERT_DIR")" && pwd)/$(basename "$CERT_DIR")/$CLIENT_NAME-cert.pem"
KEY_ABSOLUTE_PATH="$(cd "$(dirname "$CERT_DIR")" && pwd)/$(basename "$CERT_DIR")/$CLIENT_NAME-key.pem"

# Create kubeconfig with client cert using absolute paths
cat > "$CERT_DIR/$CLIENT_NAME-dashboard.kubeconfig" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CA_DATA
    server: $CLUSTER_SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $CLIENT_NAME
  name: $CLIENT_NAME@$CLUSTER_NAME
current-context: $CLIENT_NAME@$CLUSTER_NAME
users:
- name: $CLIENT_NAME
  user:
    client-certificate: $CERT_ABSOLUTE_PATH
    client-key: $KEY_ABSOLUTE_PATH
EOF

echo "✅ Kubeconfig created: $CERT_DIR/$CLIENT_NAME-dashboard.kubeconfig"
echo ""
echo "Start kubectl proxy using your certificate identity:"
echo ""
echo "  KUBECONFIG=$CERT_DIR/$CLIENT_NAME-dashboard.kubeconfig kubectl proxy"
echo ""
echo "Then access dashboard at:"
echo "  http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo ""
echo "This uses YOUR certificate identity (CN=$CLIENT_NAME) for all API calls."
echo "RBAC will be based on your certificate's CN and O fields."
echo ""
echo "To verify your permissions:"
echo "  KUBECONFIG=$CERT_DIR/$CLIENT_NAME-dashboard.kubeconfig kubectl auth can-i --list"
