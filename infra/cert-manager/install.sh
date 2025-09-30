#!/bin/bash
set -e

echo "Installing cert-manager..."

# Install cert-manager using the official manifest
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml

# Wait for cert-manager to be ready
echo "Waiting for cert-manager pods to be ready..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=300s

echo "cert-manager installation complete!"
echo ""
echo "IMPORTANT: To use Route53 for DNS validation:"
echo "  1. Create AWS credentials secret: ../secrets/create-aws-secret.sh"
echo "  2. Create a ClusterIssuer with Route53 DNS01 solver"
echo ""
echo "To verify the installation:"
echo "  kubectl get pods -n cert-manager"
echo "  kubectl get crds | grep cert-manager"