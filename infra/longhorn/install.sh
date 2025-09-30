#!/bin/bash

# Install Longhorn distributed storage
# https://longhorn.io

set -e

echo "Installing Longhorn..."

# Apply Longhorn manifest
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/deploy/longhorn.yaml

echo "Waiting for Longhorn to be ready..."
kubectl wait --for=condition=ready pod -l app=longhorn-manager -n longhorn-system --timeout=300s

echo "Setting Longhorn as default storage class..."
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo ""
echo "Longhorn installation completed successfully!"
echo ""
echo "Storage class status:"
kubectl get storageclass
echo ""
echo "To access the Longhorn UI:"
echo "  kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
echo "  Then open http://localhost:8080"