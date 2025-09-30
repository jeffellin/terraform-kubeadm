#!/bin/bash
set -e

echo "Installing Kubernetes Dashboard..."

# Install Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Wait for dashboard to be ready
echo "Waiting for dashboard pods to be ready..."
kubectl wait --namespace kubernetes-dashboard \
  --for=condition=ready pod \
  --selector=k8s-app=kubernetes-dashboard \
  --timeout=300s

echo ""
echo "Kubernetes Dashboard installation complete!"
echo ""
echo "To access the dashboard:"
echo "  1. Create an admin service account:"
echo "     kubectl apply -f dashboard-admin.yaml"
echo ""
echo "  2. Get the access token:"
echo "     kubectl -n kubernetes-dashboard create token admin-user"
echo ""
echo "  3. Start kubectl proxy:"
echo "     kubectl proxy"
echo ""
echo "  4. Access the dashboard at:"
echo "     http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo ""
echo "To verify the installation:"
echo "  kubectl get pods -n kubernetes-dashboard"
echo "  kubectl get svc -n kubernetes-dashboard"