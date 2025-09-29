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
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Wait for Calico to be ready
echo "Waiting for Calico pods to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s || true

# Generate join command and save it
sudo kubeadm token create --print-join-command > /tmp/join-command
sudo chmod 644 /tmp/join-command

echo "Kubernetes master initialized successfully"
echo "Join command saved to /tmp/join-command"