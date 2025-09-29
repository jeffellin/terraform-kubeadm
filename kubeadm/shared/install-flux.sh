#!/bin/bash

# Install FluxCD using Helm
# Run this script on the master node after the cluster is initialized

set -e

echo "Installing FluxCD via Helm..."

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: kubectl is not configured. Please run this on the master node."
    exit 1
fi

# Install Helm if not already installed
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Add FluxCD Helm repository
echo "Adding FluxCD Helm repository..."
helm repo add fluxcd https://fluxcd-community.github.io/helm-charts
helm repo update

# Install Flux2
echo "Installing Flux2..."
helm install flux2 fluxcd/flux2 \
  --namespace flux-system \
  --create-namespace

# Wait for Flux components to be ready
echo "Waiting for Flux components to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=flux2 -n flux-system --timeout=300s

echo "FluxCD installation completed successfully!"
echo ""
echo "To verify the installation, run:"
echo "  kubectl get pods -n flux-system"
echo ""
echo "To bootstrap Flux with a Git repository, run:"
echo "  flux bootstrap git --url=<your-git-repo-url> --path=clusters/my-cluster"