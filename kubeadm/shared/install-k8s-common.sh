#!/bin/bash

# Common Kubernetes installation script
# Used by both Proxmox and AWS deployments

set -e

# Set environment variables to prevent interactive prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFMISS=1

echo "Starting Kubernetes installation..."

# Disable unattended-upgr to prevent dpkg lock conflicts
echo "Stopping unattended-upgr service..."
sudo systemctl stop unattended-upgrades 2>/dev/null || true
sudo systemctl disable unattended-upgrades 2>/dev/null || true
sudo pkill -9 unattended-upgr 2>/dev/null || true

# Wait for the actual dpkg frontend lock to be released
echo "Waiting for dpkg lock to be free..."
for i in {1..60}; do
  if sudo flock -n /var/lib/dpkg/lock-frontend -c true 2>/dev/null; then
    echo "dpkg lock is free"
    break
  fi
  echo "  Attempt $i/60: dpkg lock still held, waiting..."
  sleep 5
done

apt_install() {
  local attempt
  for attempt in {1..5}; do
    if sudo -E apt-get install -y "$@"; then
      return 0
    fi
    echo "  apt-get install attempt $attempt failed, retrying in 10s..."
    sleep 10
  done
  echo "ERROR: apt-get install failed after 5 attempts: $*" >&2
  return 1
}

# Update system
sudo -E apt-get update
apt_install apt-transport-https ca-certificates curl open-iscsi

# Enable and start open-iscsi (required for Longhorn)
sudo systemctl enable iscsid
sudo systemctl start iscsid

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo -E sh get-docker.sh
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
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --batch --no-tty --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo -E apt-get update
apt_install kubelet kubeadm kubectl
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