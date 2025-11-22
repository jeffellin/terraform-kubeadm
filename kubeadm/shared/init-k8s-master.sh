#!/bin/bash

# Kubernetes master initialization script
# Parameters: MASTER_IP, CLUSTER_NAME (optional)

set -e

MASTER_IP=${1:-$(hostname -I | awk '{print $1}')}
CLUSTER_NAME=${2:-"k8s-cluster"}

echo "Initializing Kubernetes master with IP: $MASTER_IP"

# Wait for Docker to be ready
sleep 30

# Initialize Kubernetes cluster
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=${MASTER_IP} \
  --apiserver-cert-extra-sans=${MASTER_IP} \
  --node-name=${CLUSTER_NAME}-master

# Configure kubectl for ubuntu user
mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Install Calico CNI
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Wait for Calico to be ready
echo "Waiting for Calico pods to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s || true

# Create ConfigMap with cluster information
echo "Creating cluster ConfigMap..."
kubectl create configmap cluster-config --from-literal=cluster-name=${CLUSTER_NAME} --from-literal=master-ip=${MASTER_IP} -n kube-system || {
  echo "Warning: Failed to create cluster ConfigMap. This may be non-critical."
  true
}

# Generate join command and save it
sudo kubeadm token create --print-join-command > /tmp/join-command
sudo chmod 644 /tmp/join-command

echo "Kubernetes master initialized successfully"
echo "Join command saved to /tmp/join-command"

# Install Helm if not already installed
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install FluxCD
echo "Installing FluxCD..."
helm repo add fluxcd https://fluxcd-community.github.io/helm-charts
helm repo update
helm install flux2 fluxcd/flux2 \
  --namespace flux-system \
  --create-namespace

# Wait for Flux components to be ready
echo "Waiting for Flux components to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=flux2 -n flux-system --timeout=300s || true

echo "FluxCD installation completed successfully!"