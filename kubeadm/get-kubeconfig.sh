#!/bin/bash

# Fetch kubeconfig from master node using terraform outputs
# Usage: ./get-kubeconfig.sh [environment] [output-file]

set -e

ENVIRONMENT=${1:-"proxmox"}
OUTPUT_FILE=${2:-"./kubeconfig"}

# Change to environment directory
cd "${ENVIRONMENT}"

# Get master IP from terraform output
echo "Getting master IP from terraform outputs..."
MASTER_IP=$(terraform output -raw master_ip 2>/dev/null)

if [[ -z "$MASTER_IP" ]]; then
    echo "Error: Could not get master IP from terraform outputs"
    echo "Make sure you have deployed the infrastructure with terraform apply"
    exit 1
fi

echo "Fetching kubeconfig from master node at ${MASTER_IP}..."

# Return to kubeadm directory
cd ..

# Fetch the kubeconfig file from master
ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_IP} "sudo cat /etc/kubernetes/admin.conf" > ${OUTPUT_FILE}

# Update the server address to use the master IP instead of localhost
sed -i.bak "s|server: https://.*:6443|server: https://${MASTER_IP}:6443|g" ${OUTPUT_FILE}
rm -f ${OUTPUT_FILE}.bak

echo "Kubeconfig saved to: ${OUTPUT_FILE}"
echo ""
echo "To use this kubeconfig:"
echo "  export KUBECONFIG=${OUTPUT_FILE}"
echo "  kubectl get nodes"
echo ""
echo "Or merge with existing config:"
echo "  KUBECONFIG=~/.kube/config:${OUTPUT_FILE} kubectl config view --flatten > ~/.kube/config.new"
echo "  mv ~/.kube/config.new ~/.kube/config"