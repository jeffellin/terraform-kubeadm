#!/bin/bash

# Common Kubernetes installation script
# Used by both Proxmox and AWS deployments

set -e

echo "Starting Kubernetes installation..."

# Wait for unattended-upgr to complete (can hold dpkg lock)
echo "Waiting for unattended-upgr and apt processes to complete..."
max_wait=300  # 5 minutes timeout
waited=0
while pgrep -x unattended-upgr > /dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
  echo "  Waiting for dpkg lock to be released... ($waited/$max_wait seconds)"
  if [ $waited -ge $max_wait ]; then
    echo "  Timeout waiting for dpkg lock, continuing anyway..."
    break
  fi
  sleep 5
  waited=$((waited + 5))
done

# Update system
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl open-iscsi

# Enable and start open-iscsi (required for Longhorn)
sudo systemctl enable iscsid
sudo systemctl start iscsid

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
sudo systemctl enable docker
sudo systemctl start docker

# Configure containerd for Kubernetes
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# Install Kubernetes components using new repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
sudo systemctl enable kubelet

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure kernel modules
sudo tee /etc/modules-load.d/k8s.conf > /dev/null <<EOF
br_netfilter
EOF

sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo modprobe br_netfilter
sudo sysctl --system

echo "Common Kubernetes components installed successfully"