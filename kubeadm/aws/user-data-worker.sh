#!/bin/bash

# Update system
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# Configure Docker daemon for Kubernetes
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl daemon-reload
systemctl restart docker

# Install Kubernetes components
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
systemctl enable kubelet

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure kernel modules
cat > /etc/modules-load.d/k8s.conf <<EOF
br_netfilter
EOF

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

modprobe br_netfilter
sysctl --system

# Wait for Docker to be ready and master to be initialized
sleep 120

# Function to get join command from master
get_join_command() {
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt to get join command from master..."

        # Try to get the join command from master
        join_cmd=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@${master_ip} 'cat /tmp/join-command' 2>/dev/null)

        if [ $? -eq 0 ] && [ ! -z "$join_cmd" ]; then
            echo "Successfully retrieved join command"
            echo "$join_cmd" > /tmp/join-command
            return 0
        fi

        echo "Failed to get join command, waiting 30 seconds before retry..."
        sleep 30
        attempt=$((attempt + 1))
    done

    echo "Failed to get join command after $max_attempts attempts"
    return 1
}

# Get and execute join command
if get_join_command; then
    echo "Joining cluster..."
    bash /tmp/join-command

    if [ $? -eq 0 ]; then
        echo "Successfully joined the cluster"
    else
        echo "Failed to join the cluster"
        exit 1
    fi
else
    echo "Could not retrieve join command from master"
    exit 1
fi

# Log completion
echo "Kubernetes worker node setup completed at $(date)" >> /var/log/k8s-init.log