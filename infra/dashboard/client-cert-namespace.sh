#!/bin/bash
set -e

# Generate client certificate with namespace-specific RBAC
# Use this for users who should only access specific namespace(s)

CERT_DIR="./dashboard-client-certs"
CLIENT_NAME="${1}"
GROUP="${2}"
NAMESPACE="${3}"
ROLE="${4:-view}"  # view, edit, or admin
DAYS_VALID="${5:-365}"

if [ -z "$CLIENT_NAME" ] || [ -z "$GROUP" ] || [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <username> <group> <namespace> [role] [days]"
  echo ""
  echo "Examples:"
  echo "  $0 bob-viewer wordpress-viewers wordpress view"
  echo "  $0 carol-editor wordpress-editors wordpress edit"
  echo "  $0 alice-admin wordpress-admins wordpress admin"
  echo ""
  echo "Role options: view, edit, admin"
  exit 1
fi

echo "Creating namespace-specific client certificate..."
echo "Username: $CLIENT_NAME"
echo "Group: $GROUP"
echo "Namespace: $NAMESPACE"
echo "Role: $ROLE"
echo "Valid for: $DAYS_VALID days"
echo ""

# Create directory for certificates
mkdir -p "$CERT_DIR"

# Generate private key for client
echo "Generating client private key..."
openssl genrsa -out "$CERT_DIR/$CLIENT_NAME-key.pem" 2048

# Create CSR with custom group
echo "Creating Certificate Signing Request (CSR)..."
openssl req -new -key "$CERT_DIR/$CLIENT_NAME-key.pem" \
  -out "$CERT_DIR/$CLIENT_NAME.csr" \
  -subj "/CN=$CLIENT_NAME/O=$GROUP"

# Create Kubernetes CertificateSigningRequest
echo "Creating Kubernetes CSR resource..."
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $CLIENT_NAME
spec:
  request: $(cat "$CERT_DIR/$CLIENT_NAME.csr" | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: $((DAYS_VALID * 86400))
  usages:
  - client auth
EOF

# Approve the CSR
echo "Approving CSR..."
kubectl certificate approve $CLIENT_NAME

# Wait for certificate to be issued
echo "Waiting for certificate to be issued..."
sleep 2

# Retrieve the signed certificate
echo "Retrieving signed certificate..."
kubectl get csr $CLIENT_NAME -o jsonpath='{.status.certificate}' | base64 -d > "$CERT_DIR/$CLIENT_NAME-cert.pem"

# Get CA certificate
echo "Retrieving cluster CA certificate..."
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "$CERT_DIR/ca.pem"

# Create PKCS12 file for browser import
echo "Creating PKCS12 file for browser..."
openssl pkcs12 -export \
  -out "$CERT_DIR/$CLIENT_NAME.p12" \
  -inkey "$CERT_DIR/$CLIENT_NAME-key.pem" \
  -in "$CERT_DIR/$CLIENT_NAME-cert.pem" \
  -certfile "$CERT_DIR/ca.pem" \
  -passout pass:kubernetes

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ Client certificate created successfully!"
echo ""
echo "Certificate mapping:"
echo "  Username (CN): $CLIENT_NAME"
echo "  Group (O): $GROUP"
echo "  Namespace: $NAMESPACE"
echo "  Expected Role: $ROLE"
echo ""
echo "Files created in $CERT_DIR/:"
echo "  - $CLIENT_NAME.p12 (Import this into your browser)"
echo "  - $CLIENT_NAME-cert.pem (Client certificate)"
echo "  - $CLIENT_NAME-key.pem (Client private key)"
echo "  - ca.pem (Cluster CA certificate)"
echo ""
echo "Password for .p12 file: kubernetes"
echo ""
echo "RBAC Configuration:"
echo "  ⚠️  RoleBinding must be created separately via YAML files"
echo "  Expected RoleBinding: $GROUP-binding (in namespace: $NAMESPACE)"
echo "  Should map group '$GROUP' to ClusterRole '$ROLE' in namespace '$NAMESPACE'"
echo ""
echo "To verify your permissions (after RoleBinding is created):"
echo "  kubectl auth can-i --list --as=$CLIENT_NAME --as-group=$GROUP -n $NAMESPACE"
echo ""
echo "To create kubeconfig:"
echo "  ./access-with-client-cert-identity.sh $CLIENT_NAME"
