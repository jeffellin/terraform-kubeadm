#!/bin/bash
set -e

echo "Installing Contour Ingress Controller..."

# Install Contour using the official manifest
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml

# Wait for Contour to be ready
echo "Waiting for Contour pods to be ready..."
kubectl wait --namespace projectcontour \
  --for=condition=ready pod \
  --selector=app=contour \
  --timeout=300s

kubectl wait --namespace projectcontour \
  --for=condition=ready pod \
  --selector=app=envoy \
  --timeout=300s

echo "Contour installation complete!"
echo ""
echo "To verify the installation:"
echo "  kubectl get pods -n projectcontour"
echo "  kubectl get services -n projectcontour"