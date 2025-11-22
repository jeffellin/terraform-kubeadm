#!/bin/bash
set -e

# Source configuration from aws-credentials file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDS_FILE="${SCRIPT_DIR}/../secrets/aws-credentials"

if [ -f "$CREDS_FILE" ]; then
  echo "Loading configuration from $CREDS_FILE..."
  source "$CREDS_FILE"
else
  echo "Warning: $CREDS_FILE not found. Using default IP range: 192.168.1.220-192.168.1.225"
  METALLB_IP_RANGE=${METALLB_IP_RANGE:-"192.168.1.220-192.168.1.225"}
fi

# Validate IP range is set
if [ -z "$METALLB_IP_RANGE" ]; then
  echo "Error: METALLB_IP_RANGE is not set. Please set it in $CREDS_FILE or as an environment variable."
  exit 1
fi

echo "Installing MetalLB with IP range: $METALLB_IP_RANGE..."

# Install MetalLB using the official manifest
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
echo "Waiting for MetalLB pods to be ready..."
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=300s

# Create IPAddressPool using the configured IP range
echo "Configuring IP address pool: $METALLB_IP_RANGE..."
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $METALLB_IP_RANGE
EOF

# Create L2Advertisement
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

# Verify IPAddressPool and L2Advertisement were created
echo "Verifying MetalLB configuration..."
kubectl get ipaddresspool -n metallb-system default-pool
kubectl get l2advertisement -n metallb-system default-l2

echo "MetalLB installation complete!"
echo ""
echo "IP Address Pool: $METALLB_IP_RANGE"
echo ""
echo "To verify the installation:"
echo "  kubectl get pods -n metallb-system"
echo "  kubectl get ipaddresspool -n metallb-system"
echo "  kubectl get l2advertisement -n metallb-system"