#!/bin/bash
set -e

echo "Installing MetalLB..."

# Install MetalLB using the official manifest
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
echo "Waiting for MetalLB pods to be ready..."
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=300s

# Create IPAddressPool
echo "Configuring IP address pool..."
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.220-192.168.1.225
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
echo "IP Address Pool: 192.168.1.220-192.168.1.225"
echo ""
echo "To verify the installation:"
echo "  kubectl get pods -n metallb-system"
echo "  kubectl get ipaddresspool -n metallb-system"
echo "  kubectl get l2advertisement -n metallb-system"